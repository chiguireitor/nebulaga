extends Node2D

signal death

const laser_bullet = preload("res://effects/laser.tscn")
const explosion = preload("res://effects/hero_explosion1.tscn")

onready var sprite: Sprite = $sprite
var time = 0
var alive = true
var firing = false
var fire_time = 0
export(float) var fire_wait = 0.5
export(float) var random_fire_spread = 0
export(float) var frame_time = 0.05
export(int) var num_frames = 4

var target_position = 300
export(float) var speed = 300

func blowup():
	if alive:
		alive = false
		queue_free()
		var ex = explosion.instance()
		get_parent().add_child(ex)
		ex.transform.origin = transform.origin
		emit_signal("death")
		WaveInfo.player_alive = false

func _ready():
	WaveInfo.player_alive = true
	
func _input(event):
	if event is InputEventMouseMotion:
		target_position = event.position.x
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == 1:
			firing = mb.pressed

var total_time = 0
func _process(delta):
	# Fire
	if fire_time < fire_wait:
		fire_time += delta
	else:
		if firing:
			fire_time = 0
			var bullet = laser_bullet.instance()
			get_parent().add_child(bullet)
			var origin_sz = sprite.get_rect().size * sprite.scale
			var bullet_sz = bullet.get_node('sprite').get_rect().size
			bullet.transform.origin = transform.origin - Vector2(0, origin_sz.y/2 + bullet_sz.y/2)
			bullet.velocity = Vector2(randf() * random_fire_spread - random_fire_spread/2, -1000)
	# Animate
	time += delta
	total_time += delta
	if time >= frame_time:
		time -= frame_time
		sprite.frame = (sprite.frame + 1) % num_frames
	#$light.energy = (cos(total_time * 3/frame_time * PI) + 1.0)/4.0 + 1.25
	if transform.origin.x < target_position - 5:
		transform.origin.x += delta * speed
	elif transform.origin.x > target_position + 5:
		transform.origin.x -= delta * speed

