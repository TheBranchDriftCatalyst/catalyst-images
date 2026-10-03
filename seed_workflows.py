#!/usr/bin/env python3
"""Convert the shim's API-format pipelines into ComfyUI UI workflows and seed them.

WHY THIS EXISTS. The shim ships 15 pipelines, but opening ComfyUI's own editor on the rig
shows an empty "Unsaved Workflow" and nothing to load — because
``user/default/workflows/`` is empty. The pipelines are in the container the whole time,
they are just in the wrong *format*: the shim submits **API format**
(``{"1": {"class_type", "inputs"}}``, a flat node dict), while the workflow browser reads
**UI format** (``nodes`` + ``links`` + positions). One is what ComfyUI executes; the other
is what it draws. Dropping the API files into the workflows directory does not work.

WHY IT RUNS AT BOOT RATHER THAN AT BUILD TIME. The conversion needs each node's input
ORDER and output types, which only ``/object_info`` knows, and that is served by a running
ComfyUI. Doing it at build time would mean booting ComfyUI inside the Docker build (it
needs ``--cpu`` there, since model_management calls torch.cuda.current_device() at import)
for a result that would then go stale the moment the pinned ComfyUI version moved. Reading
it from the ComfyUI that is actually about to serve is both simpler and more correct.

IT IS BEST-EFFORT BY DESIGN. A pipeline that cannot be converted is skipped with a reason
on stderr and the others still land; the rig's actual job is the shim's /v1/images API,
which does not use these files at all. Never let a convenience feature take down a box
that bills by the hour.
"""
from __future__ import annotations

import json
import sys
import urllib.request
from pathlib import Path

COMFY = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8188"
SRC = Path(sys.argv[2] if len(sys.argv) > 2 else "/opt/comfyui-shim/pipelines")
DST = Path(sys.argv[3] if len(sys.argv) > 3 else "/opt/ComfyUI/user/default/workflows")

# Laid out in dependency columns. Generous spacing because ComfyUI does not re-layout on
# open — whatever positions we write are what the user sees, and overlapping nodes are
# worse than no workflow at all.
COL_W, ROW_H, X0, Y0 = 420, 190, 40, 40


def fetch_object_info(base: str) -> dict:
    with urllib.request.urlopen(f"{base}/object_info", timeout=60) as r:
        return json.loads(r.read())


def convert(api: dict, oi: dict) -> dict:
    """API-format graph -> UI-format workflow. Raises on anything it cannot represent."""
    nodes_api = {k: v for k, v in api.items() if k != "_meta" and isinstance(v, dict)}

    # ── link inputs vs widget values ────────────────────────────────────────────
    # An input whose value is ["<node_id>", slot] is a LINK; anything else is a widget.
    # The distinction matters because UI format puts them in two different places, and
    # widgets_values is POSITIONAL — it must follow the required-input order from
    # object_info, skipping the ones that turned out to be links.
    links: list[list] = []
    link_id = 0
    node_inputs: dict[str, list] = {}
    node_widgets: dict[str, list] = {}

    for nid, node in nodes_api.items():
        cls = node.get("class_type")
        spec = oi.get(cls)
        if spec is None:
            raise ValueError(f"node {nid}: unknown class_type {cls!r} (not in /object_info)")
        required = (spec.get("input") or {}).get("required") or {}
        optional = (spec.get("input") or {}).get("optional") or {}
        order = list(required.keys()) + list(optional.keys())
        ins, widgets = [], []
        for name in order:
            if name not in node.get("inputs", {}):
                # Absent optional input, or a widget ComfyUI will default. Only a
                # REQUIRED absence is a problem, and that is the graph's bug, not ours.
                if name in required and name not in node.get("inputs", {}):
                    pass
                continue
            val = node["inputs"][name]
            if isinstance(val, list) and len(val) == 2 and isinstance(val[1], int):
                ins.append({"name": name, "src": str(val[0]), "slot": val[1]})
            else:
                widgets.append(val)
        node_inputs[nid] = ins
        node_widgets[nid] = widgets

    # ── topological columns, so the graph reads left to right ───────────────────
    depth: dict[str, int] = {}

    def depth_of(nid: str, seen: frozenset = frozenset()) -> int:
        if nid in depth:
            return depth[nid]
        if nid in seen:  # cycle: ComfyUI graphs are DAGs, but never recurse forever
            return 0
        d = 0
        for i in node_inputs.get(nid, []):
            if i["src"] in nodes_api:
                d = max(d, depth_of(i["src"], seen | {nid}) + 1)
        depth[nid] = d
        return d

    for nid in nodes_api:
        depth_of(nid)

    rows: dict[int, int] = {}
    pos: dict[str, list[int]] = {}
    for nid in sorted(nodes_api, key=lambda n: (depth[n], int(n) if n.isdigit() else 0)):
        c = depth[nid]
        r = rows.get(c, 0)
        rows[c] = r + 1
        pos[nid] = [X0 + c * COL_W, Y0 + r * ROW_H]

    # ── emit ────────────────────────────────────────────────────────────────────
    ui_nodes = []
    for nid, node in nodes_api.items():
        cls = node["class_type"]
        spec = oi[cls]
        out_types = spec.get("output") or []
        out_names = spec.get("output_name") or out_types
        ui_in, ui_out = [], []
        for i in node_inputs[nid]:
            link_id += 1
            src_types = (oi.get(nodes_api[i["src"]]["class_type"], {}).get("output") or [])
            ltype = src_types[i["slot"]] if i["slot"] < len(src_types) else "*"
            links.append([link_id, int(i["src"]), i["slot"], int(nid), len(ui_in), ltype])
            ui_in.append({"name": i["name"], "type": ltype, "link": link_id})
        for si, t in enumerate(out_types):
            consumers = [
                lk[0] for lk in links if lk[1] == int(nid) and lk[2] == si
            ]
            ui_out.append({
                "name": out_names[si] if si < len(out_names) else str(t),
                "type": t,
                "links": consumers,
                "slot_index": si,
            })
        ui_nodes.append({
            "id": int(nid),
            "type": cls,
            "pos": pos[nid],
            "size": [380, 120],
            "flags": {},
            "order": depth[nid],
            "mode": 0,
            "inputs": ui_in,
            "outputs": ui_out,
            "properties": {"Node name for S&R": cls},
            "widgets_values": node_widgets[nid],
        })

    # outputs[].links is filled above as links are created, but a consumer discovered
    # AFTER a producer was emitted would be missed — recompute once at the end so the
    # graph is correct regardless of dict iteration order.
    by_id = {n["id"]: n for n in ui_nodes}
    for n in ui_nodes:
        for o in n["outputs"]:
            o["links"] = []
    for lk in links:
        lid, src, slot, _dst, _dslot, _t = lk
        node = by_id.get(src)
        if node and slot < len(node["outputs"]):
            node["outputs"][slot]["links"].append(lid)

    return {
        "last_node_id": max((n["id"] for n in ui_nodes), default=0),
        "last_link_id": link_id,
        "nodes": ui_nodes,
        "links": links,
        "groups": [],
        "config": {},
        "extra": {},
        "version": 0.4,
    }


def main() -> int:
    try:
        oi = fetch_object_info(COMFY)
    except Exception as exc:  # noqa: BLE001 - reported, never fatal
        print(f"seed-workflows: cannot reach {COMFY}/object_info: {exc}", file=sys.stderr)
        return 0

    DST.mkdir(parents=True, exist_ok=True)
    ok = skipped = 0
    for src in sorted(SRC.glob("*.json")):
        try:
            api = json.loads(src.read_text())
            name = (api.get("_meta") or {}).get("name") or src.stem
            wf = convert(api, oi)
            (DST / f"{name}.json").write_text(json.dumps(wf, indent=1))
            ok += 1
        except Exception as exc:  # noqa: BLE001 - one bad pipeline must not stop the rest
            print(f"seed-workflows: skipped {src.name}: {exc}", file=sys.stderr)
            skipped += 1
    print(f"seed-workflows: wrote {ok} workflow(s) to {DST}" + (f", skipped {skipped}" if skipped else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
