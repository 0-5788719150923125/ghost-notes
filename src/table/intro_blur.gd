extends Node2D
class_name IntroBlur

## IntroBlur - THE INTRO'S BLUR: the whole stage read back through the intro's shader
## ([constant ShowOpening.INTRO_SHADER]), drawn over the picture and under the channel's name - and
## not drawn at all while it is off. The card table's and the desk's ([ShowOpening]).

var _mat := ShaderMaterial.new()

func _init(shader: Shader) -> void:
	_mat.shader = shader
	material = _mat
	visible = false

## The blur's sigma, as a share of the frame's height; 0 takes it off.
func set_sigma(sigma: float) -> void:
	_mat.set_shader_parameter("sigma", sigma)
	visible = sigma > 0.0

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color.WHITE)
