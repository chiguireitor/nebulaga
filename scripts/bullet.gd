extends KinematicBody2D

export(float) var frame_delay = 0.1

var velocity: Vector2 = Vector2(0, 0)
var frame_base = 0
var frame_time = 0

func _ready():
	$spawn_sound.play()
	frame_base = $sprite.frame
	if randf() < 0.5:
		$sprite.frame += 1
	
func _process(delta):
	var col = move_and_collide(velocity * delta)
	
	if col:
		if col.collider.has_method('blowup'):
			col.collider.blowup()
		queue_free()
	
	# Animate
	frame_time += delta
	if frame_time >= frame_delay:
		frame_time -= frame_delay
		$sprite.frame = ($sprite.frame - frame_base + 1) % 2 + frame_base
		
	# Border condition
	if transform.origin.y < -100 or transform.origin.y > 1100:
		queue_free()
