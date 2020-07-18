extends Node2D

signal spawned
signal game_over
signal shake(strength)

const formation_basic = preload("res://formations/formation_basic.tscn")
const enemy1 = preload("res://enemies/enemy1.tscn")
const player1 = preload("res://players/player1.tscn")
const heart_texture = preload("res://textures/full_heart.png")

var active_wave = 0
var current_wave_active = false
var current_formation = null
var current_model = player1
var current_player = null
var heart_sprites = []
var game_started = false
var current_points = 0

func _ready():
	WaveInfo.connect("all_enemies_dead", self, "all_enemies_dead")
	WaveInfo.connect("enemy_died", self, "enemy_died")
	
func start(ship=""):
	current_points = 0
	$points_text.text = str(current_points)
	current_model = player1
	if ship != "":
		var token = NebulasWalletSingleton.get_token_by_name(ship)
		if token != null:
			current_model = token.ingame_asset
			print('Using ingame asset for ', ship, ' ', current_model)
		else:
			print('Token was null!')
	
	active_wave = 0
	for i in range(3):
		add_heart()
	spawn()
	game_started = true

func add_heart():
	var i = len(heart_sprites)
	var heart = Sprite.new()
	add_child(heart)
	heart.transform.origin = Vector2(i * 40 + 24, 20)
	heart.scale = Vector2(2, 2)
	heart.texture = heart_texture
	heart_sprites.append(heart)
	
func spawn():
	current_player = current_model.instance()
	add_child(current_player)
	current_player.connect("death", self, "death")
	emit_signal("spawned")

func enemy_died(points):
	emit_signal("shake", 0.1 + float(points) / 10.0)
	current_points += points
	$points_text.text = str(current_points)
	
func death():
	emit_signal("shake", 0.3)
	if len(heart_sprites) > 0:
		heart_sprites.pop_back().queue_free()
		if WaveInfo.num_enemies_trampling > 0:
			yield(WaveInfo, "no_enemies_trampling")
			
		var t = $notification_text
		t.text = 'Wave ' + str(active_wave)
		t.visible = true
		yield(get_tree().create_timer(1.0), "timeout")
		t.visible = false
		spawn()
	else:
		for i in range(get_child_count()):
			var chld = get_child(i)
			if chld.has_method("flee"):
				chld.flee()
				
		var t = $notification_text
		t.text = 'Game Over'
		t.visible = true
		yield(get_tree().create_timer(3.0), "timeout")
		t.visible = false
		game_started = false
		current_wave_active = false
		emit_signal("game_over")

func all_enemies_dead():
	if !WaveInfo.player_alive:
		yield(self, "spawned")
	if len(heart_sprites) < 5:
		add_heart()
	start_wave()

func spawn_formation():
	current_formation = formation_basic.instance()
	add_child(current_formation)
	current_formation.transform.origin = Vector2(300, 300);
	
	var positions = current_formation.get_children()
	for i in range(len(positions)):
		var p: Node2D = positions[i]
		var ene = enemy1.instance()
		ene.probability_elite = (float(p.editor_description) - 1) / 5.0
		add_child(ene)
		var x = 100
		var orgx = 700
		if i % 2 == 0:
			x = -100
			orgx = -100
		ene.transform.origin = Vector2(orgx + floor(i/2) * x, 600)
		ene.rest_position = p

func start_wave():
	current_wave_active = true
	active_wave += 1
	var t = $notification_text
	t.text = 'Wave ' + str(active_wave)
	t.visible = true
	yield(get_tree().create_timer(1.0), "timeout")
	t.visible = false
	spawn_formation()
		
func _process(delta):
	if !current_wave_active and game_started:
		start_wave()
