class_name RoomArrival
extends Marker2D
## Where Stella appears when she enters a room through an exit, named by the
## node (e.g. `FromHall`), and which way she faces. Put it on reachable floor a
## step into the room, never on the exit's own approach point or in the doorway
## art, facing into the room.

@export_enum("Left:-1", "Right:1") var facing: int = 1
