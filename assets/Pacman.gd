extends CharacterBody2D
class_name Pacman

@onready var gamenode = get_node("/root/Game")
@onready var animation:AnimatedSprite2D = $AnimatedSprite2D
@onready var img_sprite:Sprite2D = $ImgSprite
@export var speed := 175
@export var current_dir:String = "none"
@export var movement_direction:Vector2 = Vector2.ZERO
var movement_enabled:bool = false
signal player_reset

var vel:Vector2 = Vector2()
var inputs:Dictionary = {
	"right": Vector2.RIGHT,
	"left": Vector2.LEFT,
	"up": Vector2.UP,
	"down": Vector2.DOWN}


func _ready() -> void:
	animation.play("crouch")
	var sprite_size:Vector2 = img_sprite.texture.get_size()
	var max_dimension:int = sprite_size.max_axis_index()
	await gamenode.ready
	var div_factor:float = (gamenode.tile_size[max_dimension]*2)/sprite_size[max_dimension]
	img_sprite.scale = Vector2(div_factor, div_factor)


func get_input():
	if movement_enabled:
		vel = Vector2()
		for input in inputs:
			if Input.is_action_just_pressed(input):
				current_dir = input
				movement_direction = inputs[input]
		vel = movement_direction * speed


func animate_movement():
	if velocity.is_zero_approx():
		animation.play("stand")
	else:
		animation.play("run")
		if velocity.x > 0:
			animation.flip_h = false
		elif velocity.x < 0:
			animation.flip_h = true


func die():
	movement_enabled = false
	animation.play("fall")
	$Dead.play()
	var _d = animation.connect("animation_finished", Callable(self, "reset"))


func _physics_process(delta:float):
	if !movement_enabled:
		return

	get_input()
	set_velocity(vel)
	animate_movement()
	move_and_slide()

	vel = vel # TODO: wtf?
	if vel.length() < 1 and movement_direction != Vector2.ZERO:
		movement_direction = Vector2.ZERO
		current_dir = "none"
		animation.play("stand")


func warp_to(pos):
	global_position = pos


func reset():
	if animation.is_connected("animation_finished", Callable(self, "reset")):
		animation.disconnect("animation_finished", Callable(self, "reset"))
	position = Vector2(264, 212)
	animation.play("crouch")
	current_dir = "none"
	movement_direction = Vector2.ZERO
	emit_signal("player_reset")
