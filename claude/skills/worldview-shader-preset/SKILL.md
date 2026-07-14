---
name: worldview-shader-preset
category: Research & OSINT
description: Scaffold a new post-processing visual style preset for the WorldView GEOINT dashboard. Use when a developer wants to add a new rendering mode (CRT, NVG, FLIR, etc.) that appears in the bottom STYLE PRESETS toolbar, exposes adjustable parameters in the right panel, persists its settings per mode, and integrates with the SCENES shot-sequencer.
---

# WorldView Shader Preset Scaffold

## Workflow

Execute this workflow in order.

1. Gather preset details from the developer (name, icon, visual description, parameter schema).
2. Define the preset manifest: id, display name, icon, parameter schema with defaults and ranges.
3. Implement the CesiumJS post-processing stage (GLSL fragment shader).
4. Expose shader uniforms as the named parameters in the right-panel PARAMETERS section.
5. Add the preset icon button to the bottom STYLE PRESETS toolbar.
6. Implement per-preset parameter persistence: save/restore slider values on mode switch.
7. Register the preset in the SCENES panel serialization format.
8. Apply the top-left active style name badge and classification header update on mode switch.
9. Verify the preset renders correctly with every active data layer.
10. Update `docs/PRD.md` FR-3 table if a new entry is needed.

Use `references/shader-checklist.md` as the completion gate.

## Required Preset Artifacts

Every new preset must produce:

- `src/shaders/<preset-name>/stage.glsl` — GLSL fragment shader (CesiumJS post-processing stage)
- `src/shaders/<preset-name>/preset.js` — JS module: uniform bindings, parameter schema, stage registration
- `src/shaders/<preset-name>/manifest.json` — preset metadata (id, displayName, icon, paramSchema)
- Updated `src/ui/stylePresetsPanel.js` — new icon button entry
- Updated `src/state/presetRegistry.js` — preset registration

## Preset Manifest Schema

```json
{
  "id": "<snake_case_id>",
  "displayName": "<Human Readable Name>",
  "icon": "<emoji or icon identifier>",
  "paramSchema": [
    {
      "name": "<ParamName>",
      "uniform": "u_<paramName>",
      "type": "float",
      "min": 0.0,
      "max": 1.0,
      "default": 0.5,
      "label": "<Right-panel slider label>"
    }
  ]
}
```

## Parameter Schemas

WorldView uses two observed parameter schemas. Match one or define a custom set:

**Sensor-style schema** (used by NVG, FLIR and similar modes):
| Uniform | Label | Range | Default |
|---------|-------|-------|---------|
| `u_sensitivity` | Sensitivity | 0–1 | 0.5 |
| `u_bloom` | Bloom | 0–1 | 0.3 |
| `u_bwot` | BWOT/BNOT | 0–1 | 0.0 |
| `u_pixelation` | Pixelation | 0–1 | 0.0 |

**Signal-degradation schema** (used by CRT and cinematic modes):
| Uniform | Label | Range | Default |
|---------|-------|-------|---------|
| `u_pixelation` | Pixelation | 0–1 | 0.2 |
| `u_distortion` | Distortion | 0–1 | 0.3 |
| `u_instability` | Instability | 0–1 | 0.1 |

Custom schemas are valid; keep to ≤6 parameters for right-panel fit.

## STYLE PRESETS Toolbar Position

The eight canonical presets occupy fixed positions. New presets are appended after position 8.
Toolbar order: `Normal | CRT | NVG | FLIR | Anime | Noir | Snow | AI | <new…>`

The active preset name is reflected in:
- The bottom STYLE PRESETS panel `STYLE` label
- The top-left classification block active-style name badge

## Per-Preset Parameter Persistence

On switching away from a preset: save all current slider values into the preset's state store keyed by `presetId`.
On switching to a preset: restore saved values or fall back to `manifest.json` defaults.
This allows independent tuning of each mode without interference.

## SCENES Panel Integration

The SCENES shot-sequencer serializes the active preset as part of each shot. Each shot row stores:
```
<preset-id> • <status> • <transition-in-seconds> • <hold-seconds>
```
Example: `CRT • OFF • 4.0s • 1.0s`

A new preset must be serializable and deserializable from this format. The preset `id` (from manifest) is the canonical token stored in shot data.

## GLSL Skeleton

```glsl
// <preset-name>/stage.glsl
// CesiumJS post-processing stage fragment shader skeleton.

uniform sampler2D colorTexture;
uniform float u_param1;   // TODO: rename to match paramSchema
uniform float u_param2;

in vec2 v_textureCoordinates;

void main() {
    vec4 color = texture(colorTexture, v_textureCoordinates);

    // TODO: implement visual effect

    out_FragColor = color;
}
```

## Commands

Run from repo root. Replace `<PRESET_NAME>` with the snake_case preset id.

1. Generate preset scaffold:
```powershell
powershell -ExecutionPolicy Bypass -File `
  "skills/worldview-shader-preset/scripts/new-preset.ps1" `
  -PresetName "<PRESET_NAME>" `
  -DisplayName "<Display Name>" `
  -Icon "<emoji>" `
  -Schema "sensor"
```
`-Schema` accepts `sensor`, `degradation`, or `custom`.

2. Verify preset checklist:
```powershell
powershell -ExecutionPolicy Bypass -File `
  "skills/worldview-shader-preset/scripts/verify-preset.ps1" `
  -PresetName "<PRESET_NAME>"
```

## PRD Update Requirement

After adding a new preset:
- Add a row to the FR-3 style preset table in `docs/PRD.md` if the preset is externally visible.
- Update section 12 Modification Summary table.

## Diagram

[View diagram](diagram.html)
