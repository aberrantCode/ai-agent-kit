---
name: worldview-layer-scaffold
category: Research & OSINT
description: Scaffold a new real-time data layer for the WorldView GEOINT dashboard. Use when a developer wants to add a new independently-toggleable data source (flights, sensors, feeds, etc.) that follows the established WorldView layer pattern — DATA LAYERS panel row, health/freshness tracking, CesiumJS entity rendering, and compositing with existing layers.
---

# WorldView Layer Scaffold

## Workflow

Execute this workflow in order.

1. Gather data source details from the developer (API endpoint, entity schema, update cadence).
2. Define the layer manifest: name, icon, entity color, count label, source attribution.
3. Implement the data-fetch module (polling, error handling, freshness timestamp).
4. Implement the CesiumJS entity renderer (point, billboard, polyline, or custom primitive).
5. Integrate the layer toggle into the DATA LAYERS panel (row with count, ON/OFF, source + age).
6. Wire health/status states: `OK`, `LOADING`, `DEGRADED`, `ERROR`.
7. Register the layer in the global HUD state so PANOPTIC/SPARSE density and CLEAN UI affect it.
8. Add sequential entity-ID labeling (`<PREFIX>-XXXX`) if entities are anonymous.
9. Verify the layer composes correctly with all existing layers in every style preset.
10. Update `docs/PRD.md` with any new data source in sections 4 and 7.

Use `references/layer-checklist.md` as the completion gate.

## Required Layer Artifacts

Every new layer must produce:

- `src/layers/<layer-name>/fetcher.js` — data fetch + polling logic
- `src/layers/<layer-name>/renderer.js` — CesiumJS entity creation and update
- `src/layers/<layer-name>/manifest.json` — layer metadata (name, icon, color, source, cadence)
- Updated `src/ui/dataLayersPanel.js` — new panel row entry
- Updated `src/state/layerRegistry.js` — layer registration

## Layer Manifest Schema

```json
{
  "id": "<snake_case_id>",
  "displayName": "<Human Readable Name>",
  "icon": "<emoji or icon identifier>",
  "entityColor": "#RRGGBB",
  "entityIdPrefix": "XYZ",
  "source": {
    "name": "<Data Source Name>",
    "url": "<endpoint or homepage>",
    "license": "<Free / ODbL / Paid / etc.>"
  },
  "cadenceSeconds": 30,
  "densityModes": ["PANOPTIC", "SPARSE"]
}
```

## DATA LAYERS Panel Row Specification

Each layer row must render as:

```
[Icon]  Layer Name          [COUNT]  [ON/OFF toggle]
        Source name · X ago
        [optional health/status message]
```

Health state values: `OK` | `LOADING` | `DEGRADED` | `ERROR`

Freshness text format: `just now` | `Xs ago` | `never`

On upstream failure: preserve prior entity set, show stale indicator, surface status text inline — do **not** remove the row or reset the count.

## CesiumJS Rendering Notes

- Use `Cesium.CustomDataSource` per layer so layers are independently removable.
- Entity visibility must respect the global `PANOPTIC` / `SPARSE` toggle.
- Entities must remain visible across all eight style presets (Normal, CRT, NVG, FLIR, Anime, Noir, Snow, AI).
- Use `Cesium.PointPrimitive` (via `PointPrimitiveCollection`) for high-count layers (>1 000 entities) to preserve frame rate.
- Assign each entity a deterministic ID: `<PREFIX>-<NORAD/index padded to 4 digits>`.

## Sequential Road / Large-Graph Loading

For layers that ingest graph or polygon data (e.g., street networks):

Load in priority order to prevent browser OOM:
1. Trunk / primary ways
2. Secondary / arterial ways
3. Local / residential ways

Emit a `LAYER_LOAD_PROGRESS` event after each stage so the DATA LAYERS panel count updates incrementally.

## Commands

Run from repo root. Replace `<LAYER_NAME>` with the snake_case layer id.

1. Generate layer scaffold from template:
```powershell
powershell -ExecutionPolicy Bypass -File `
  "skills/worldview-layer-scaffold/scripts/new-layer.ps1" `
  -LayerName "<LAYER_NAME>" `
  -DisplayName "<Display Name>" `
  -EntityColor "#RRGGBB" `
  -EntityIdPrefix "<PREFIX>" `
  -SourceName "<Data Source>" `
  -CadenceSeconds 30
```

2. Verify layer manifest and checklist:
```powershell
powershell -ExecutionPolicy Bypass -File `
  "skills/worldview-layer-scaffold/scripts/verify-layer.ps1" `
  -LayerName "<LAYER_NAME>"
```

## PRD Update Requirement

After scaffolding a new layer:
- Add a `FR-N — <Layer Name>` requirement block to `docs/PRD.md` section 4 under the appropriate subsection.
- Add the data source row to `docs/PRD.md` section 7 (Data Sources Summary).
- Add an entry to the section 12 Modification Summary table.

## Diagram

[View diagram](diagram.html)
