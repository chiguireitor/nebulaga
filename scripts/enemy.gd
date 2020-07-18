extends KinematicBody2D

const explosion = preload("res://effects/explosion1.tscn")
const acid = preload("res://effects/acid.tscn")

onready var sprite = $sprite
var time = 0

export(int) var points = 1
export(float) var frame_time = 0.1
export(float) var speed = 10000
export(float) var decision_delay = 1
export(float) var percent_drop = 0.05
export(float) var percent_fire = 0.15
export(float) var bullet_speed = 200
export(float) var bullet_delay = 2
export(Texture) var elite_variant
export(float) var probability_elite = 0

var rest_position: Position2D
var state = 'seeking_rest'
var decision_time = 0
var is_alive = true
var current_bullet = acid
var bullet_time = 0
var phase = 0
var amplitude = 20
var drop_amplitude = 0
var orbit_direction = 1
var wobble_frequency = 4
var shots = 1
var lives = 1

func _ready():
	WaveInfo.enemy_spawned()
	decision_time = randf() * decision_delay
	phase = randf() * PI
	orbit_direction = randf() * 2 + 0.5
	if randf() < 0.5:
		orbit_direction = -orbit_direction
		
	if randf() < probability_elite:
		lives = 3
		speed *= 1.25
		decision_delay *= 0.75
		percent_drop *= 2
		percent_fire *= 2
		bullet_speed *= 1.25
		bullet_delay *= 0.5
		drop_amplitude = 1.5
		shots = 3
		points += 2
		$sprite.texture = elite_variant

func blowup():
	if is_alive:
		lives -= 1
		var expl = explosion.instance()
		get_parent().add_child(expl)
		expl.transform.origin = transform.origin
			
		if lives <= 0:
			is_alive = false
			queue_free()
			
			if state == 'drop':
				WaveInfo.end_trample()
			WaveInfo.enemy_dead(points)

func flee():
	WaveInfo.end_trample()
	state = 'flee_offscreen'

func fire():
	if shots == 1:
		instance_bullet(Vector2(0, bullet_speed))
	else:
		for i in range(shots):
			instance_bullet(Vector2(randf() * 5 - 2.5, 5).normalized() * bullet_speed)
		
func instance_bullet(v):
	var bullet = current_bullet.instance()
	get_parent().add_child(bullet)
	var origin_sz = sprite.get_rect().size * sprite.scale
	var bullet_sz = bullet.get_node('sprite').get_rect().size
	bullet.transform.origin = transform.origin + Vector2(0, origin_sz.y/2 + bullet_sz.y/2)
	bullet.velocity = v
	bullet.collision_layer = 2
	bullet.collision_mask = 1
	bullet.rotation = randf() * PI
	bullet_time = bullet_delay

var total_time = 0
func _process(delta):
	total_time += delta
	if state == 'seeking_rest':
		var orbit = Vector2(cos((total_time + phase) * orbit_direction), sin((total_time + phase) * orbit_direction)) * amplitude
		var direction: Vector2 = rest_position.global_transform.origin - transform.origin + orbit
		var ls = direction.length_squared()
		if ls > 1:
			move_and_slide(direction.normalized() * speed * delta)
			frame_time = 0.1 - 0.07 * min(ls / 10000, 1.0)
		else:
			frame_time = 0.1
	elif state == 'drop':
		var tetha = (total_time + phase) * wobble_frequency
		move_and_slide(Vector2(cos(tetha) * drop_amplitude, 1) * speed * delta * 2)
		var slide_count = get_slide_count()
		if slide_count > 0:
			for i in range(slide_count):
				var kc = get_slide_collision(i)
				if kc.collider.has_method('blowup'):
					kc.collider.blowup()
			blowup()
			
		frame_time = 0.03
		if transform.origin.y > 1500:
			transform.origin = Vector2(transform.origin.x, -100)
			state = 'seeking_rest'
			WaveInfo.end_trample()
	elif state == 'flee_offscreen':
		move_and_slide(Vector2(orbit_direction, 0) * speed * delta * 2)
		if transform.origin.x < -50 or transform.origin.x > 1000:
			queue_free()

	# Decide
	decision_time += delta
	if bullet_time > 0:
		bullet_time -= delta
	if decision_time > decision_delay:
		decision_time -= decision_delay
		if state == 'seeking_rest' and WaveInfo.player_alive:
			var r = randf()
			if r < percent_drop:
				state = 'drop'
				WaveInfo.begin_trample()
			elif r < percent_fire and bullet_time <= 0:
				fire()

	# Animate
	time += delta
	if time >= frame_time:
		time -= frame_time
		sprite.frame = (sprite.frame + 1) % sprite.hframes
