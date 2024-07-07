extends Node2D

const tile_size:int = 8

@export var pellet_prefab:Resource
@export var vulnerable_time:float = 7.0

var starting_pellets:int
var pellets_left:int
var current_ghost:int = 0
var ghost_names:Array[String] = ["Red", "Pink", "Blue", "Orange"]
var lives:int = 5
var vulnearable_ghosts:int = 0
var eaten_ghosts:int = 0
var ghost_bonus:int = 200
var mortal:bool = true
var scattering:bool = false

@onready var ghosts:Array[Node] = [$Enemies/Red, $Enemies/Pink, $Enemies/Blue, $Enemies/Orange]
@onready var player:PacMan = $"Pac-Man"
@onready var map:RID = get_world_2d().navigation_map


func _init() -> void:
	Console.add_command("toggle_navigation_draw", self, "toggle_debug_draw").register()
	Console.add_command("skip_level", self, "level_won").register()
	Console.add_command("invulnerability", self, "toggle_invulnerability").register()


func _ready() -> void:
	randomize()
	reset()
	player.movement_enabled = true # TODO: REMOVE ONCE WE HAVE A NEW INTRO SONG


func level_won() -> void:
	$UI.level_won()
	reset()


func reset() -> void:
	stop_ghost_audio()
	for ghost in ghosts:
		ghost.reset()
		ghost.player_ate_ghost.connect(_on_player_ate_ghost)
		ghost.ghost_ate_player.connect(_on_ghost_ate_player)
		ghost.ghost_became_vulnerable.connect(_on_ghost_became_vulnerable)
		ghost.ghost_restored.connect(_on_ghost_restored)
	vulnearable_ghosts = 0
	eaten_ghosts = 0
	$Pellets.queue_free()
	await get_tree().create_timer(1.0).timeout
	player.reset()
	await get_tree().create_timer(0.10).timeout
	var pellets = pellet_prefab.instantiate()
	add_child(pellets)
	pellets.connect("pellet_eaten", Callable(self, "_on_Pellet_eaten"))
	pellets.connect("power_pellet_eaten", Callable(self, "_on_Power_Pellet_eaten"))
	pellets_left = pellets.get_children().size()
	starting_pellets = pellets_left


func _process(_delta) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()


func ghost_repath() -> void:
	# Select the next ghost.
	current_ghost += 1
	if current_ghost >= ghosts.size():
		current_ghost = 0

	# Re-process pathfinding for the next ghost
	var ghost: Ghost = ghosts[current_ghost]

	match ghost.state:
		Ghost.CHASE:
			var target_position
			match ghost_names[current_ghost]:
				"Red":
					target_position = player.global_position
					#new_path = NavigationServer2D.map_get_path(map, ghost.position, player.position, false)
					#print(ghost.position, " ", player.position, " ", "apply path ", new_path)
				"Pink":
					target_position = player.global_position + (player.velocity.normalized() * 4 * tile_size)
					#new_path = NavigationServer2D.map_get_path(map, ghost.position, target_position, false)
				"Blue":
					var player_heading = player.global_position + (player.velocity.normalized() * 2 * tile_size)
					var blinky_vector = ($Enemies/Red.global_position - player_heading)
					target_position = player_heading - blinky_vector
					#new_path = NavigationServer2D.map_get_path(map, ghost.position, target_position, false)
				"Orange":
					var distance = ghost.global_position.distance_to(player.global_position)
					if distance > 8 * tile_size:
						target_position = player.global_position
						#new_path = NavigationServer2D.map_get_path(map, ghost.position, player.position, false)
					else:
						target_position = player.global_position + (player.velocity.normalized() * -10 * tile_size)
						#new_path = NavigationServer2D.map_get_path(map, ghost.position, target_position, false)
			# Apply the path.
			ghost.agent.target_position = target_position
			#ghost.path = new_path
		Ghost.CORNER:
			# When the current target_position is pretty much reached
			if abs(ghost.agent.get_current_navigation_path_index() - ghost.agent.get_current_navigation_path().size()) < 3:
				# Pick a random assigned point in the corner of the map to go to
				var scatter_points:Array[Node] = ghost.scatter_corner.get_children()
				var new_pos:Vector2 = ghost.agent.target_position
				while new_pos == ghost.agent.target_position:
					new_pos = scatter_points[randi() % scatter_points.size()].global_position
				ghost.agent.target_position = new_pos
		Ghost.SCARED:
			ghost.agent.target_position = Vector2(randf_range(156, 372), randf_range(24, 270))
			#var new_path := NavigationServer2D.map_get_path(map, ghost.position, new_pos, false)
			#ghost.path = new_path
		Ghost.EATEN:
			pass
		Ghost.IN_PEN:
			pass


func _on_ExitL_body_entered(body) -> void:
	if body is PacMan or body is Ghost:
		body.warp_to($"Arena/Exit-R".global_position)


func _on_ExitR_body_entered(body) -> void:
	if body is PacMan or body is Ghost:
		body.warp_to($"Arena/Exit-L".global_position)


func _on_Power_Pellet_eaten() -> void:
	$Sounds/Ghost_Woo.stop()
	ghost_bonus = 200
	$UI.add_score(50)
	for ghost in ghosts:
		ghost.scared()
	for _i in 4:
		ghost_repath()
	scattering = true
	$Scatter_Timer.start(vulnerable_time)
	pellets_left -= 1
	if pellets_left == 0:
		level_won()


func _on_Pellet_eaten() -> void:
	$UI.add_score(10)
	pellets_left -= 1
	if pellets_left % 2 == 1:
		$Sounds/Dot_1.play()
	else:
		$Sounds/Dot_2.play()
	if pellets_left == starting_pellets - 1:
		play_appropriate_ghost_audio()
		ghosts[0].start()
		ghosts[1].start()
	if pellets_left == starting_pellets - 30:
		ghosts[2].start()
	if pellets_left == starting_pellets - 90:
		ghosts[3].start()
	if pellets_left == 0:
		level_won()


func _on_Ai_Timer_timeout() -> void:
	ghost_repath()


func _on_Scatter_Timer_timeout() -> void:
	scattering = !scattering
	if vulnearable_ghosts != 0:
		vulnearable_ghosts = 0
		play_appropriate_ghost_audio()
	if scattering:
		$Scatter_Timer.start(7)
		for ghost in ghosts:
			ghost.corner()
	else:
		$Scatter_Timer.start(20)
		for ghost in ghosts:
			ghost.chase()


func _on_ghost_ate_player(_ghost) -> void:
	if not mortal:
		return
	stop_ghost_audio()
	lives -= 1
	$UI.draw_lives(lives)
	player.die()
	for ghost in ghosts:
		ghost.reset()
	await get_tree().create_timer(0.10).timeout
	starting_pellets = pellets_left
	if lives < 0:
		$UI.game_over()
		await get_tree().create_timer(5.0).timeout
		lives = 5
		$UI.reset()
		$UI.draw_lives(lives)
		$Sounds/Intro.play()
		reset()


func toggle_debug_draw() -> void:
	for ghost in ghosts:
		ghost.agent.debug_enabled = !ghost.agent.debug_enabled


func _on_player_ate_ghost(ghost) -> void:
	print("player ate ", ghost)
	$UI.add_score(ghost_bonus)
	ghost_bonus *= 2
	ghost.agent.target_position = $GhostRespawn.global_position
	print($GhostRespawn.global_position, " ", ghost.agent.target_position)
	vulnearable_ghosts -= 1
	eaten_ghosts += 1
	$Sounds/Bwahhh.play()
	play_appropriate_ghost_audio()


func _on_ghost_became_vulnerable() -> void:
	vulnearable_ghosts += 1
	play_appropriate_ghost_audio()


func _on_ghost_restored() -> void:
	eaten_ghosts -= 1
	play_appropriate_ghost_audio()


func play_appropriate_ghost_audio() -> void:
	if eaten_ghosts > 0:
		$Sounds/Ghost_wahwah.stop()
		$Sounds/Ghost_Woo.stop()
		$Sounds/Ghost_ewweww.play()
	elif vulnearable_ghosts > 0:
		$Sounds/Ghost_Woo.stop()
		$Sounds/Ghost_ewweww.stop()
		$Sounds/Ghost_wahwah.play()
	else:
		$Sounds/Ghost_ewweww.stop()
		$Sounds/Ghost_wahwah.stop()
		$Sounds/Ghost_Woo.play()


func stop_ghost_audio() -> void:
	$Sounds/Ghost_Woo.stop()
	$Sounds/Ghost_ewweww.stop()
	$Sounds/Ghost_wahwah.stop()


func _on_Intro_finished() -> void:
	player.movement_enabled = true


func _on_PacMan_player_reset() -> void:
	if lives >= 0:
		player.movement_enabled = true


func toggle_invulnerability() -> void:
	mortal = !mortal


func point_on_navmesh(point:Vector2) -> bool:
	return (NavigationServer2D.map_get_closest_point(map, point) - point).is_zero_approx()
