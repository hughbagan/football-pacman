extends CharacterBody2D
class_name Ghost

signal player_ate_ghost
signal ghost_ate_player
signal ghost_became_vulnerable
signal ghost_restored

@onready var gamenode = get_node("/root/Game")
@onready var animation:AnimatedSprite2D = $Animation
@onready var agent:NavigationAgent2D = $NavigationAgent2D
@export var scatter_corner:Node2D
@export var corner_points:Array[Vector2]
@export var speed:float = 176.0
@export var state_speed:float = 1.0
@export var color:String = "Red"
var state = IN_PEN
var start_pos

enum {
	IN_PEN,
	CHASE,
	CORNER,
	SCARED,
	EATEN
}


func _ready() -> void:
	assert(scatter_corner, "Assign the instance's Scatter Corner in the inspector")
	start_pos = global_position
	animation.play("idle")
	await gamenode.ready
	call_deferred("nav_setup")


func nav_setup() -> void:
	await get_tree().physics_frame # wait for navserver to sync
	agent.target_position = global_position


func _physics_process(_delta:float):
	if agent.is_navigation_finished():
		if state == EATEN:
			state = CHASE
			emit_signal("ghost_restored")
		return

	var speed_multiplier = 1
	match state:
		EATEN:
			speed_multiplier = 2
		SCARED:
			speed_multiplier = 0.6
	velocity = global_position.direction_to(agent.get_next_path_position()) * speed * speed_multiplier
	animate(velocity)
	set_velocity(velocity)
	move_and_slide()


func start() -> void:
	state = CHASE


func chase() -> void:
	if state == CORNER or state == SCARED:
		state = CHASE


func corner() -> void:
	if state == CHASE or state == SCARED:
		state = CORNER


func scared() -> void:
	if state != IN_PEN and state != EATEN:
		state = SCARED
		emit_signal("ghost_became_vulnerable")


func animate(vel:Vector2) -> void:
	match state:
		IN_PEN, CHASE, CORNER:
			animation.rotation = 0
			animation.play("run")
			if abs(vel.x) > abs(vel.y):
				if vel.x > 0:
					animation.flip_h = false # right
				else:
					animation.flip_h = true # left
		EATEN:
			animation.play("flying")
			animation.rotate(PI/16)
		SCARED:
			animation.play("scared")
			if vel.x > 0:
				animation.flip_h = false # right
			else:
				animation.flip_h = true # left


func reset() -> void:
	global_position = start_pos
	agent.target_position = start_pos
	state = IN_PEN
	animation.play("idle")


func warp_to(pos:Vector2) -> void:
	global_position = pos
	#path.resize(0) # TODO: how to translate to NavigationAgent2D?


func _on_Area_body_entered(_body) -> void:
	if state == SCARED:
		emit_signal("player_ate_ghost", self)
		state = EATEN
	elif state == CHASE or state == CORNER:
		emit_signal("ghost_ate_player", self)
