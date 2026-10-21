class_name FarmAmbientArt
extends ArtSlot
## Approved farm painting with localized pond ripples and plant sway.
## ArtSlot retains the original anchor, texture path and character separation.
const ENVIRONMENT_SECONDS := 40.0
const DETAIL_SECONDS := 55.0
const AMBIENT_SHADER := preload("res://art/shaders/farm_ambient.gdshader")
@export_range(0.0, 1.0) var strength := 1.0
@export var enabled := true
var environment_clock := 0.0
var detail_clock := 17.0
var ambient_material: ShaderMaterial

func _ready() -> void:
	super._ready()
	ambient_material = ShaderMaterial.new()
	ambient_material.shader = AMBIENT_SHADER
	ambient_material.set_shader_parameter("environment_mask", preload("res://art/backgrounds/farm/environment.png"))
	ambient_material.set_shader_parameter("detail_mask", preload("res://art/backgrounds/farm/detail.png"))
	_sprite.material = ambient_material
	_update_ambient()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if enabled:
		environment_clock = fposmod(environment_clock + delta, ENVIRONMENT_SECONDS)
		detail_clock = fposmod(detail_clock + delta, DETAIL_SECONDS)
	_update_ambient()

func set_elapsed(seconds: float) -> void:
	environment_clock = fposmod(seconds, ENVIRONMENT_SECONDS)
	detail_clock = fposmod(seconds + 17.0, DETAIL_SECONDS)
	_update_ambient()

func _update_ambient() -> void:
	if ambient_material:
		ambient_material.set_shader_parameter("environment_phase", environment_clock / ENVIRONMENT_SECONDS)
		ambient_material.set_shader_parameter("detail_phase", detail_clock / DETAIL_SECONDS)
		ambient_material.set_shader_parameter("strength", strength if enabled else 0.0)
