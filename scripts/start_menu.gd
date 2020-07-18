extends Control

onready var start_btn = $start
onready var changeship_btn = $change_ship
onready var wallet_btn = $wallet
onready var options_btn = $options
onready var exit_btn = $exit
onready var playfield = $"../gameview/viewport/playfield"
onready var gameview = $"../gameview"

var shake_remain = 0
var shake_amplitude = 0

func _ready():
	start_btn.connect("pressed", self, "on_start_pressed")
	changeship_btn.connect("pressed", self, "on_change_ship_pressed")
	wallet_btn.connect("pressed", self, "on_wallet_pressed")
	options_btn.connect("pressed", self, "on_options_pressed")
	exit_btn.connect("pressed", self, "on_exit_pressed")
	playfield.connect("shake", self, "shake_gameview")
	playfield.connect("game_over", self, "on_back_to_menu_from_play")
	$"../wallet".connect("close_wallet", self, "on_back_to_menu_from_wallet")
	$"../ship_pick/v/buttons/back".connect("pressed", self, "on_back_to_menu_from_pick_ship")
	$"../ship_pick/v/h/refresh".connect("pressed", self, "on_refresh_ship_list")
	var list = $"../ship_pick/v/item_list/v"
	for i in range(list.get_child_count()):
		var itm = list.get_child(i)
		itm.connect("selected", self, "ship_selected")

func _process(delta):
	if shake_remain > 0:
		shake_remain -= delta
		gameview.margin_left = round(randf() * shake_amplitude)
		gameview.margin_top = round(randf() * shake_amplitude)
	else:
		gameview.margin_left = 0
		gameview.margin_top = 0

func shake_gameview(strength):
	shake_remain = strength
	shake_amplitude = strength * 50

func on_back_to_menu_from_play():
	visible = true
	$"../gameview/viewport".gui_disable_input = true
	$"../music".stop()
	
func on_back_to_menu_from_wallet():
	visible = true
	$"../wallet".visible = false
	
func on_start_pressed():
	visible = false
	$"../gameview/viewport".gui_disable_input = false
	$"../gameview/viewport/playfield".start()
	$"../music".play()

func on_change_ship_pressed():
	visible = false
	$"../ship_pick".visible = true

func on_wallet_pressed():
	visible = false
	var wlt = $"../wallet"
	wlt.visible = true
	wlt.show_wallet()

func on_back_to_menu_from_pick_ship():
	visible = true
	$"../ship_pick".visible = false

func ship_selected(ship_name):
	visible = false
	$"../ship_pick".visible = false
	$"../gameview/viewport".gui_disable_input = false
	$"../gameview/viewport/playfield".start(ship_name)
	$"../music".play()

func on_refresh_ship_list():
	if !NebulasWalletSingleton.updating_nrc721s:
		NebulasWalletSingleton.update_nrc721s_balances()

func on_options_pressed():
	pass

func on_exit_pressed():
	get_tree().quit()
