# Approved art and HD presentation

All artwork is unchanged. The game renders at a native 1920×1080 default desktop
window, with 1280×720 logical authoring coordinates. Canvas-item stretching keeps
input, walking geometry, character proportions and layout aligned while drawing
at the larger window size. Background sampling uses Catmull-Rom reconstruction
for enlargement, and existing mipmaps for reduction. It does not invent detail.

| Location | Original visible pixels | Approximate pixels displayed at 1080p | Status |
| --- | --- | --- | --- |
| Island overview | 1448×1086 | 1440×1080 | Almost native, no meaningful enlargement |
| Bedroom, hall, kitchen, garden | 1672×941 each | 1920×1080 | Mild enlargement, existing source retained |
| Waterfall | 2560×1440 | 1920×1080 | Already above target; original approved module untouched |
| Harbour | 1672×941 | 1920×1080 | Mild enlargement |
| Farm, cave entrance and interior | 1672×941 each | 1920×1080 | Newly supplied correct originals, mild enlargement |
| Marketplace day/night | 606×522 panel each | about 1254×1080 | Main source-resolution bottleneck; about 2× enlargement |

The supplied marketplace PNG is 1448×1086, but contains an overview plus two
small street paintings. Its overall file size is not the street's resolution.
A full street original at least **1254×1080** per phase would remove the current
panel enlargement at this framing; **1920×1080** separate location paintings
with the same approved composition would be better for a future widescreen
layout. Such files have not been found among the supplied approved originals.
No AI upscale, redraw, new painting, false detail or stretched aspect ratio was
introduced. AtlasTextures continue to use the exact original board.

The image-quality shader is an ArtSlot option, so characters, UI and the custom
waterfall effects keep their established sampling and rendering logic. Source
PNGs and the waterfall module can still be verified byte-for-byte against their
originals. Standard Godot references:
[multiple resolutions](https://docs.godotengine.org/en/4.3/tutorials/rendering/multiple_resolutions.html)
and [navigation obstruction outlines](https://docs.godotengine.org/en/4.3/classes/class_navigationmeshsourcegeometrydata2d.html).
