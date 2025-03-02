extends CharacterBody2D
class_name Ghost

enum GhostColor {
	RED,
	PINK,
	BLUE,
	ORANGE
}
enum States {
	IN_PEN,
	CHASE,
	CORNER,
	SCARED,
	EATEN
}

@onready var gamenode = get_node("/root/Game")
@onready var map:RID = get_world_2d().navigation_map
@onready var animation:AnimatedSprite2D = $Animation
@onready var agent:NavigationAgent2D = $NavigationAgent2D
@export var color:GhostColor
@export var scatter_corner:Node2D
var speed:float = 173.0
var state_speed:float = 1.0
var state:States = States.IN_PEN
var start_pos
var mod_x:float = randf()

signal player_ate_ghost
signal ghost_ate_player
signal ghost_became_vulnerable
signal ghost_restored


func _ready() -> void:
	assert(color != null, "Assign the instance's GhostColor in the inspector")
	assert(scatter_corner, "Assign the instance's Scatter Corner in the inspector")
	start_pos = global_position
	animation.play("crouch")
	if OS.is_debug_build(): # Make sure to uncheck "Debug" when exporting.
		agent.debug_enabled = true
		agent.debug_use_custom = true
		match color:
			GhostColor.RED:
				agent.debug_path_custom_color = Color.RED
			GhostColor.PINK:
				agent.debug_path_custom_color = Color.DEEP_PINK
			GhostColor.BLUE:
				agent.debug_path_custom_color = Color.AQUA
			GhostColor.ORANGE:
				agent.debug_path_custom_color = Color.DARK_ORANGE
	await gamenode.ready
	call_deferred("nav_setup")


func nav_setup() -> void:
	await get_tree().physics_frame # wait for navserver to sync
	agent.target_position = global_position


func _physics_process(delta:float):
	if agent.is_navigation_finished():
		if state == States.EATEN:
			state = States.CHASE
			emit_signal("ghost_restored")
		return

	var speed_multiplier = 1
	match state:
		States.EATEN:
			speed_multiplier = 2
		States.SCARED:
			speed_multiplier = 0.6
			mod_x += delta
			set_modulate(Color(0, cos(8*mod_x)+1, 1, 1))
		_:
			set_modulate(Color(1, 1, 1, 1))
	velocity = global_position.direction_to(agent.get_next_path_position()) * speed * speed_multiplier
	animate(velocity)
	set_velocity(velocity)
	move_and_slide()


func start() -> void:
	state = States.CHASE


func chase() -> void:
	if state == States.CORNER or state == States.SCARED:
		state = States.CHASE


func corner() -> void:
	if state == States.CHASE or state == States.SCARED:
		state = States.CORNER


func scared() -> void:
	if state != States.IN_PEN and state != States.EATEN:
		state = States.SCARED
		emit_signal("ghost_became_vulnerable")


func random_scared_path() -> void:
	var target_position := global_position
	var dirs := [Vector2(1,0), Vector2(0,1), Vector2(-1,0), Vector2(0,-1)]
	var current_dir := velocity.normalized()
	var dir := current_dir
	var i := 0
	while dir == current_dir or (not Game.point_on_navmesh(map, target_position)):
		dir = dirs[randi() % dirs.size()]
		target_position = (global_position + (dir*gamenode.tile_size*8)).snapped(gamenode.tile_size)
		i+=1
		if i >= dirs.size()-1:
			break # INF loop safeguard
	agent.target_position = target_position


func animate(vel:Vector2) -> void:
	match state:
		States.IN_PEN, States.CHASE, States.CORNER:
			animation.rotation = 0
			animation.play("run")
			if abs(vel.x) > abs(vel.y):
				if vel.x > 0:
					animation.flip_h = false # right
				else:
					animation.flip_h = true # left
		States.EATEN:
			animation.play("flying")
			animation.rotate(PI/16)
		States.SCARED:
			animation.play("scared")
			if vel.x > 0:
				animation.flip_h = false # right
			else:
				animation.flip_h = true # left


func reset() -> void:
	global_position = start_pos
	agent.target_position = start_pos
	state = States.IN_PEN
	mod_x = randf()
	animation.play("crouch")


func warp_to(pos:Vector2) -> void:
	global_position = pos
	#path.resize(0) # TODO: how to translate to NavigationAgent2D?


func _on_Area_body_entered(body) -> void:
	if body is Pacman:
		if not body.collider.disabled:
			if state == States.SCARED:
				emit_signal("player_ate_ghost", self)
				state = States.EATEN
			elif state == States.CHASE or state == States.CORNER:
				emit_signal("ghost_ate_player", self)
