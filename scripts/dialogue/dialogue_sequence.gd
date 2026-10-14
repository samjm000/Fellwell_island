class_name DialogueSequence
extends Resource
## A short run of lines from one speaker, authored as a .tres file so writing can
## be edited without touching scripts. Leave `speaker` empty for narration.

@export var speaker: String = ""
@export var lines: PackedStringArray = []
