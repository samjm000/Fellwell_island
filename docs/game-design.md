# Fellwell Island: Game Design

> The game architect owns this document. Only the brief points the code
> depends on are recorded here so far.

## Tone

Warm, funny, mysterious and character-driven. It draws on classic
LucasArts-style adventures for atmosphere and humour, but uses direct character
movement and modern quality-of-life design.

Avoid strictly linear "one available path at a time" design. Systems should
support many interactable objects, optional observations, a changing world state
and, later, several puzzle threads running at once.

## Stella

- A young girl, born on Fellwell Island.
- Her parents are absent for reasons that are not yet revealed.
- She lives in a small house on the mountainside. Her room overlooks the sea and
  holds her grandfather's telescope.

## Lemon

- Stella's soft, golden, fluffy dog, with a blue collar and a yellow LEMON tag.
  She often carries Lemon with her.
- Lemon is actually a toy dog, but Stella sincerely treats her as alive. The game
  never says so outright.
- In the implementation, Lemon is a companion state (in the room or carried), not
  an AI.

## World threads introduced so far

- **The offshore light**: an unexplained light out at sea, visible only at night
  through Grandad's telescope. Seeing it sets the `seen_offshore_light` story flag.
  No puzzle has been built on it yet.

## Bedroom preparation and the wardrobe mouse

Stella's first departure requires opening the trunk, taking her yellow backpack
(with a blue flower, per the 22 October video reference), and picking up Lemon.
Opening and taking are separate clicks. Specific dialogue names what is missing.
The departure flag is set once both are ready. Subsequent visits do not trap Stella
if Lemon was put down in another room. The backpack cannot be dropped.

The front-left low cupboard is provisionally the wardrobe hotspot. Opening it
shows an interior close-up with a mouse hole, slowly coloured disco beams, music,
and a formally dressed mouse periodically stepping out and back in. This is an
optional discovery only: no mouse dialogue, item exchange or puzzle yet.

Backpack controls approved on 22 October: corner button and I; Esc closes.
Inventory currently supports collecting, removing and inspecting authored items,
with distinct ownership for Stella and Max. No arbitrary starter items are added.
Lemon is a companion, not a slot. World-item use and combination remain undecided.
