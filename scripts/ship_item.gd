extends Node

signal selected(name)
signal send(name)

export(String) var asset_name

onready var panel = $panel
onready var title = $data/title
onready var description = $data/description
onready var select_btn = $v/select
onready var send_btn = $v/send

var _panel_initialized = false

func _ready():
	select_btn.connect("pressed", self, "on_select")
	send_btn.connect("pressed", self, "on_send")
	NebulasWalletSingleton.watch_nft_by_name(asset_name, funcref(self, "token_update"))

func token_update(token):
	title.text = token.asset_title
	description.text = token.asset_description
	if !_panel_initialized:
		_panel_initialized = true
		var asset = token.wallet_asset.instance()
		panel.add_child(asset)
	select_btn.disabled = token.balance == 0
	send_btn.disabled = token.balance == 0

func on_select():
	emit_signal("selected", asset_name)

func on_send():
	NebulasWalletSingleton.invoke_ui_send(asset_name, '1')
	emit_signal("send", asset_name)
