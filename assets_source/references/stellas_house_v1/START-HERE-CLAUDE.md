# Stella’s House — Claude Code handover

Implement this art pack in the EXISTING Fellwell Island Godot project. Inspect AGENTS.md, current scenes, character controller, scene transition system, save format and art-direction notes first. Adapt to the installed Godot version. Preserve existing working functionality and local changes. This archive is artwork and implementation guidance; it is not a runnable Godot project.

## Outcome
Stella, carrying Lemon using the existing character states, can walk around her bedroom, go downstairs to the entrance hall, explore the kitchen/living room, leave through the front door, walk into the garden, and return. Connect the garden gate to an existing island location if one exists. If none exists, leave a clearly documented integration hook and report that limitation; do not claim the wider world is implemented.

## Artwork
Eight full-colour PNG backgrounds in art/: bedroom, kitchen_living, entrance_hall and exterior, each in day/night versions. Use these files, not older competing art. Check asset-manifest.json for original dimensions. Import as textures; preserve aspect ratio and use one consistent logical canvas transform for background, navigation, hotspots and spawn points. Never stretch axes independently. These are flattened paintings: no transparent foreground layers, door animations, fire animations, character sprites, audio or depth maps are supplied. Do not attempt to animate by sliding an entire background. Keep closed painted doors; approach-and-fade transitions are sufficient for this version. Frame-by-frame door opening requires additional assets.

Day/night paintings closely match but are not guaranteed pixel-identical. Reuse logical geometry, then visually check every interaction and route in both versions. Do not independently reroll geometry for night. Do not present these illustrations as measured architectural drawings.

## House and continuity
This is Grandad’s old house, now Stella’s home. Keep inherited belongings meaningful and naturally embedded. Upstairs is the approved attic bedroom, with the grandfather’s telescope facing the sea. Downstairs are a modest entrance hall and a combined kitchen/living room. The hall is the circulation hub: stairs to bedroom, side doorway to kitchen, front door to garden. Kitchen fireplace belongs on the chimney side of the cottage. These views establish room adjacency and consistent materials, rather than a dimensioned construction plan. Do not add extra rooms or a second staircase.

Bedroom ↔ entrance hall ↔ kitchen/living room.
Entrance hall ↔ cottage exterior ↔ existing world route (if available).

The right-hand kitchen doorway connects to the left-hand hall doorway. Hall staircase connects via a short fade to the existing bedroom door/landing; a separate upstairs landing scene is unnecessary. Front door connects to the door of the exterior cottage. Use the foreground garden gate as the onward exit. Never route the hall window, kitchen window or telescope outside as a walk exit.

## Character continuity
Reuse the CURRENT approved Stella/Lemon sprites and animation/controller architecture already in the repository. This ZIP contains no replacement character art. Stella: shoulder-length brown hair, yellow/white striped shirt, denim shorts, pink high-top trainers. Lemon is her soft golden toy Labrador, blue collar/tag when present. Preserve carrying, put-down and pickup behaviour if already supported, and Lemon’s state across every transition. Do not substitute a generic dog or reintroduce older character designs. Do not build a new walk cycle from these background paintings.

## Navigation and transitions
Use the project’s existing click-to-walk/navigation system. Trace floor boundaries and furniture obstacles from the actual paintings; normalized coordinates in scene-guide.json are APPROXIMATE authoring hints, not tested collision meshes. Fit walking space to Stella’s actual foot anchor and scale. Do not allow clipping through sofa, table, hearth, chests, stairs rail, walls or garden beds. Prefer a lower connected walking corridor; interact with distant furniture from reachable approach points. At the hall stair foot trigger an upstairs transition; do not make Stella climb a flat painting as if it were a 3D stair model.

Transitions: walk to a reachable approach point, lock new movement, fade out, load destination, place character at destination’s named arrival anchor facing into the scene, preserve Lemon and time of day, fade in, restore controls. Prevent immediate bounce-back by requiring exit trigger release/new interaction. Return spawns must be on reachable floor, not inside the door graphic. Resolve the player’s requested exit only after the approach completes. Disconnect/clear outgoing scene interaction signals and queued movement.

Keep time-of-day in existing world state. Change paired textures together without resetting position or story state. Test saving/loading in every added room using the existing save schema. If the current project lacks a save system, report that rather than silently creating an unrelated one.

## Interactions and writing
Make a few purposeful Look interactions: kitchen kettle, Grandad’s crockery, sofa/blanket, coat and boots, boat picture. Names should appear on hover as in the existing game, not permanently painted labels. Keep writing brief and provisional for Sam to author. Do not add arbitrary pickups, chores, puzzle gates or new story flags merely because objects are painted. Keep the opening curious, warm and funny, with no forced tutorial.

Preserve the accepted bedroom telescope/offshore-light trigger. Preserve island-map observation dialogue:
“Grandad drew all over this map.”
“He said maps are only useful once someone’s ruined them with notes.”
“I still don’t know what the little red cross means.”
The red cross is observation only: no active puzzle or story flag.
The lighthouse is intended to be derelict in the story, although these accepted paintings show a lit beam. Preserve the supplied artwork for this integration; do not derive a functioning-lighthouse story flag from it. Record this existing art/story discrepancy for a later art decision.

## Verification and delivery
Run the repository’s existing relevant checks and the installed Godot headless import/parser check if available. Then play through bedroom → hall → kitchen → hall → garden and reverse, in day and night. Test exit clicking from a distance, repeated clicks, resize/aspect ratio, foreground occlusion, inventory/Lemon state, time-of-day persistence and existing bedroom story interactions. Check that Stella’s feet sit on the floor and she can reach every exit without furniture clipping. Test save/load when supported.

Do not describe headless import as visual gameplay verification. If the engine or interactive playtest is unavailable, clearly say what was and was not checked. Deliver a concise report of changed scenes/scripts/assets, checks, screenshots where possible and remaining issues. Follow the user’s repository workflow for commits/pushes; this handover does not independently authorise a remote push.
