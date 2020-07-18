extends Node2D

var direction = 1
var limit = 400
var speed = 100

func _process(delta):
	if direction == 1:
		if transform.origin.x < 400:
			transform.origin += Vector2(1, 0) * delta * speed
		else:
			direction = -1
	elif direction == -1:
		if transform.origin.x > 200:
			transform.origin += Vector2(-1, 0) * delta * speed
		else:
			direction = 1
