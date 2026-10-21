# Fellwell waterfall

Self-contained Godot 4.3 waterfall: one scene, four flow states, day and night.
Works in the Compatibility renderer. Nothing is frame-animated: the plate is a
static painting, the water is a shader on a ribbon mesh, foam and mist are
shaders, spray and drips are CPUParticles2D.

## Files

| Path | What it is |
|---|---|
| `waterfall.tscn` | The scene to instance in a level. Local coordinates = plate pixels (2560 x 1440). |
| `waterfall.gd` | `FellwellWaterfall` controller: states, timing, signals. |
| `waterfall_ribbon.gd` | `@tool` mesh builder. Drag `Ribbon/FlowPath` in the editor to reshape the curtain. |
| `shaders/water_curtain.gdshader` | The falling water. |
| `shaders/water_wet.gdshader` | Darkens rock under the water; dries out after it stops. |
| `shaders/water_foam.gdshader` | Foam boiling at the impact point. |
| `shaders/water_mist.gdshader` | Mist at the plunge pool. |
| `textures/` | Small tileable noise textures (procedural, regenerable). |
| `art/waterfall_plate_day_interim.png` | **Temporary** background (crop of the old plate). Replace with the repainted plate. |

## Node tree

```
Waterfall (Node2D, waterfall.gd)
├─ Plate (Sprite2D)                 static painting, dry rock, cave painted in
├─ Ribbon (Node2D, waterfall_ribbon.gd)
│  ├─ FlowPath (Path2D)             brink -> pool centreline, edit in editor
│  ├─ WetRock (MeshInstance2D)      multiply blend
│  └─ Curtain (MeshInstance2D)
├─ ImpactFoam (ColorRect, mouse ignored)
├─ Mist (ColorRect, mouse ignored)
├─ Spray (CPUParticles2D)
├─ Drips (CPUParticles2D)
└─ CaveEntrance (Area2D)            collision enabled only when the cave is open
```

## API

```gdscript
@onready var waterfall: FellwellWaterfall = $Waterfall

waterfall.set_flow_state(FellwellWaterfall.FlowState.SLOWING)   # beavers start the dam
waterfall.set_flow_state(FellwellWaterfall.FlowState.STOPPED)   # dam complete
waterfall.set_flow_state(FellwellWaterfall.FlowState.RESTARTING) # dam released
waterfall.jump_to(FellwellWaterfall.FlowState.STOPPED)          # loading a save, no transition
waterfall.cave_available_changed.connect(_on_cave_available)    # enable cave hotspot/exit
waterfall.night = true          # also set the level's CanvasModulate to waterfall.night_tint
waterfall.on_twos = true        # optional 12 fps hand-animated cadence
```

RESTARTING returns to NORMAL by itself and emits `state_changed`.

## Fitting a new plate

1. Replace `art/waterfall_plate_day_interim.png` (or point `Plate.texture` at the new file).
2. Select `Ribbon/FlowPath`, drag the top point onto the painted brink and the bottom point onto the pool surface.
3. Adjust `Ribbon.top_width` / `bottom_width` so the edges sit on the rock either side.
4. Move `ImpactFoam`, `Mist`, `Spray`, `CaveEntrance` and `drip_points` to match.

## Rules

- The plate is the **dry** state: no water, no dam, no characters, cave lantern unlit.
- The dam, the lit lantern and any beavers are separate sprites.
- Never bake water into the plate. Never frame-animate the curtain.
