class_name WardrobeView
extends CanvasLayer
## Inspectable wardrobe interior, with a quiet disco and a formally dressed mouse.
## Node-drawn prototype art; replace the illustration without changing its state.
var illustration: WardrobeIllustration

func _ready() -> void:
	layer = 16
	PlayerControl.acquire(&"wardrobe")
	illustration = WardrobeIllustration.new()
	illustration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(illustration)
	var title := Label.new()
	title.text = "BEHIND THE WARDROBE DOORS"
	title.position = Vector2(335, 65)
	title.add_theme_font_size_override("font_size", 30)
	illustration.add_child(title)
	var caption := Label.new()
	caption.text = '"He has a better social life than I do. And a waistcoat."'
	caption.position = Vector2(305, 605)
	illustration.add_child(caption)
	var close_button := Button.new()
	close_button.text = "Close wardrobe  [Esc]"
	close_button.position = Vector2(495, 650)
	close_button.size = Vector2(290, 45)
	close_button.pressed.connect(close)
	illustration.add_child(close_button)
	AudioManager.push_music_override(&"wardrobe", &"mouse_disco", 0.6)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	queue_free()

func _exit_tree() -> void:
	AudioManager.pop_music_override(&"wardrobe", 0.6)
	PlayerControl.release(&"wardrobe")

class WardrobeIllustration extends Control:
	var elapsed := 0.0
	var mouse_out := false

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()

	func box(rect: Rect2, colour: Color, radius: int = 8) -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = colour
		style.set_corner_radius_all(radius)
		draw_style_box(style, rect)

	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color(0.025,0.035,0.05,0.94))
		box(Rect2(220,115,840,470),Color("714b32"),18)
		box(Rect2(248,138,784,414),Color("302a29"))
		for x in range(260,1020,55):
			draw_line(Vector2(x,145),Vector2(x,550),Color("43322b"),2)
		draw_line(Vector2(280,194),Vector2(1000,194),Color("ba8a50"),7,true)
		# Clothes hang above a tiny skirting-board doorway.
		for i in 5:
			var x := 320.0+i*110
			draw_arc(Vector2(x,194),12,PI,TAU+PI/2,16,Color("be9c6e"),2,true)
			draw_polyline(PackedVector2Array([Vector2(x,207),Vector2(x-38,230),Vector2(x+38,230),Vector2(x,207)]),Color("be9c6e"),2,true)
			var colours := [Color("69858b"),Color("b5776e"),Color("cbb982"),Color("778965"),Color("938499")]
			draw_colored_polygon(PackedVector2Array([Vector2(x-26,228),Vector2(x-51,256),Vector2(x-37,280),Vector2(x-23,267),Vector2(x-26,376),Vector2(x+26,376),Vector2(x+23,267),Vector2(x+37,280),Vector2(x+51,256),Vector2(x+26,228)]),colours[i])
			draw_line(Vector2(x,238),Vector2(x,370),Color(1,1,1,0.13),2)
		box(Rect2(250,488,780,64),Color("91633f"),0)
		for x in range(260,1030,84):
			draw_line(Vector2(x,491),Vector2(x+25,550),Color("68432d"),2)
		# The black arch is cut into the wardrobe's back wall.
		box(Rect2(684,409,94,99),Color("c49a65"),44)
		box(Rect2(692,417,78,91),Color("131a28"),38)
		draw_rect(Rect2(692,455,78,53),Color("131a28"))
		for i in 3:
			var glow := Color.from_hsv(fmod(elapsed*0.08+i*0.33,1.0),0.55,1.0,0.18)
			var end_x := 600.0+i*110+sin(elapsed*0.8+i)*25
			draw_colored_polygon(PackedVector2Array([Vector2(726,460),Vector2(end_x-40,541),Vector2(end_x+45,541)]),glow)
		for i in 9:
			var p := Vector2(705+(i%3)*19,435+(i/3)*18)
			draw_circle(p,3,Color.from_hsv(fmod(elapsed*0.12+i*0.13,1.0),0.6,1.0,0.7))
		# A twelve-second stroll: emerge, admire cuffs, return; hidden inside between visits.
		var phase := fmod(elapsed,12.0)
		mouse_out = phase > 1.0 and phase < 10.0
		if mouse_out:
			var distance := 110.0 * smoothstep(1.0,3.5,phase) * (1.0-smoothstep(7.5,10.0,phase))
			var walking := phase < 3.5 or phase > 7.5
			var bob := sin(elapsed*12)*1.5 if walking else sin(elapsed*2)*0.6
			draw_set_transform(Vector2(729-distance,499+bob),0,Vector2(-1 if phase > 7.5 else 1,1))
			# Tail, polished shoes, trousers, fitted jacket, ivory shirt and bow tie.
			draw_arc(Vector2(23,-9),21,-0.5,2.7,22,Color("c29d96"),3,true)
			box(Rect2(-13,-18,10,18),Color("252e3e"),3)
			box(Rect2(4,-18,10,18),Color("252e3e"),3)
			box(Rect2(-19,-3,17,6),Color("101621"),3)
			box(Rect2(3,-3,18,6),Color("101621"),3)
			box(Rect2(-17,-47,35,34),Color("284f58"),9)
			draw_colored_polygon(PackedVector2Array([Vector2(-8,-45),Vector2(8,-45),Vector2(0,-22)]),Color("f1e5c8"))
			draw_colored_polygon(PackedVector2Array([Vector2(-10,-43),Vector2(0,-39),Vector2(10,-43),Vector2(10,-35),Vector2(0,-39),Vector2(-10,-35)]),Color("b75365"))
			for y in [-29,-22]:
				draw_circle(Vector2(4,y),1.5,Color("dfbd65"))
			draw_circle(Vector2(-11,-60),13,Color("aa9185"))
			draw_circle(Vector2(12,-60),13,Color("aa9185"))
			draw_circle(Vector2(-11,-60),8,Color("d4aba3"))
			draw_circle(Vector2(12,-60),8,Color("d4aba3"))
			draw_circle(Vector2(0,-51),15,Color("b9a397"))
			draw_circle(Vector2(-13,-48),7,Color("c8b3a5"))
			draw_circle(Vector2(-19,-49),3,Color("554350"))
			draw_circle(Vector2(-6,-55),2,Color("151a24"))
			draw_arc(Vector2(-6,-55),5,0,TAU,16,Color("d7bb6f"),1,true)
			draw_line(Vector2(-16,-45),Vector2(-29,-49),Color("e9cfb2"),1,true)
			draw_line(Vector2(-16,-43),Vector2(-29,-41),Color("e9cfb2"),1,true)
			box(Rect2(-11,-83,23,16),Color("243343"),3)
			draw_line(Vector2(-17,-67),Vector2(19,-67),Color("243343"),5,true)
			draw_line(Vector2(-10,-71),Vector2(12,-71),Color("b75365"),3,true)
			draw_set_transform(Vector2.ZERO)
		# Doors swing open rather than disappearing; interaction remains modal.
		var open := smoothstep(0.0,0.8,elapsed)
		var width := lerpf(392,46,open)
		box(Rect2(248-width*0.3,138,width,414),Color("a16e45"),5)
		box(Rect2(1032-width*0.7,138,width,414),Color("a16e45"),5)
		draw_line(Vector2(255-width*0.3,154),Vector2(255-width*0.3,530),Color("c89962"),3)
