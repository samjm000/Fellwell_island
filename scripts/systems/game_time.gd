class_name GameTime
extends RefCounted
## Shared time-of-day vocabulary.
##
## Lives apart from the TimeManager autoload so scripts and resources can use the
## enum as a type. Later phases (morning, evening...) are added here; anything that
## stores a set of phases should use `phase_bit()` masks so it keeps working.

enum Phase { DAY, NIGHT }


static func phase_bit(phase: Phase) -> int:
	return 1 << phase


static func phase_name(phase: Phase) -> String:
	return Phase.keys()[phase]
