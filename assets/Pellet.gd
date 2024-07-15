extends Area2D
class_name Pellet

signal pellet_eaten


func _on_Pellet_body_entered(body):
	if body is Pacman:
		emit_signal("pellet_eaten")
		queue_free()
