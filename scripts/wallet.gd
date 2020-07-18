extends Control

signal pin_confirmed(pin)
signal pin_canceled
signal error_dialog_closed
signal close_wallet

const tx_ui = preload("res://scenes/transaction.tscn")

onready var balance_label = $contents/card/Panel/h/v/balance
onready var address_label = $contents/card/Panel/h/v/addr/label
onready var address_copy_btn = $contents/card/Panel/h/v/addr/copy
onready var address_qr = $contents/card/Panel/h/addrreq
onready var refresh_btn = $contents/sep/refresh
onready var transaction_list = $contents/list/items
onready var transaction_loader = $contents/list_loader
onready var back_btn = $contents/buttons/back
onready var backup_btn = $contents/buttons/backup
onready var send_btn = $contents/buttons/send

onready var pin_action_label = $pin_panel/v/pin_action_label
onready var digit0_btn = $pin_panel/v/row1/digit0
onready var digit1_btn = $pin_panel/v/row1/digit1
onready var digit2_btn = $pin_panel/v/row1/digit2
onready var digit3_btn = $pin_panel/v/row2/digit3
onready var digit4_btn = $pin_panel/v/row2/digit4
onready var digit5_btn = $pin_panel/v/row2/digit5
onready var digit6_btn = $pin_panel/v/row3/digit6
onready var digit7_btn = $pin_panel/v/row3/digit7
onready var digit8_btn = $pin_panel/v/row3/digit8
onready var digit9_btn = $pin_panel/v/row4/digit9
onready var erase_btn = $pin_panel/v/row4/erase
onready var confirm_btn = $pin_panel/v/row4/confirm

onready var digit0_label = $pin_panel/v/pin_digits/digit0/Label
onready var digit1_label = $pin_panel/v/pin_digits/digit1/Label
onready var digit2_label = $pin_panel/v/pin_digits/digit2/Label
onready var digit3_label = $pin_panel/v/pin_digits/digit3/Label
onready var digit4_label = $pin_panel/v/pin_digits/digit4/Label
onready var digit5_label = $pin_panel/v/pin_digits/digit5/Label

var current_pin = ''
var current_keyboard_order = [1,2,3,4,5,6,7,8,9,0]

var _last_account_state = null
var _coin_name = 'NAS'
var _current_send_token = null
var _current_show_wallet_success = null
var wallet_loaded = false

func _ready():
	randomize()
	
	send_btn.connect("pressed", self, "show_send_dialog")
	back_btn.connect("pressed", self, "on_back_pressed")
	
	digit0_btn.connect("pressed", self, "put_pin_digit", [0])
	digit1_btn.connect("pressed", self, "put_pin_digit", [1])
	digit2_btn.connect("pressed", self, "put_pin_digit", [2])
	digit3_btn.connect("pressed", self, "put_pin_digit", [3])
	digit4_btn.connect("pressed", self, "put_pin_digit", [4])
	digit5_btn.connect("pressed", self, "put_pin_digit", [5])
	digit6_btn.connect("pressed", self, "put_pin_digit", [6])
	digit7_btn.connect("pressed", self, "put_pin_digit", [7])
	digit8_btn.connect("pressed", self, "put_pin_digit", [8])
	digit9_btn.connect("pressed", self, "put_pin_digit", [9])
	erase_btn.connect("pressed", self, "erase_digit")
	confirm_btn.connect("pressed", self, "confirm_pin")
	
	$error_panel/v/close.connect("pressed", self, "error_dialog_close")
	address_copy_btn.connect("pressed", self, "copy_address_to_clipboard")
	
	refresh_btn.connect("pressed", self, "update_tx_list")
	
	$send_panel/v/buttons/cancel_btn.connect("pressed", self, "hide_send_panel")
	$send_panel/v/buttons/send_btn.connect("pressed", self, "do_send")
	$send_panel/v/destination/paste_btn.connect("pressed", self, "paste_address_send")
	$send_panel/v/fee/fee_slider.connect("value_changed", self, "fee_rate_changed")
	$send_panel/v/amount/token_options.connect("item_selected", self, "token_changed")
	
	backup_btn.connect("pressed", self, "show_backup_dialog")
	$backup_panel/v/showpk.connect("pressed", self, "update_showpk_toggle")
	$backup_panel/v/h/close_pk.connect("pressed", self, "close_backup_dialog")
	$backup_panel/v/h/clipboard_pk.connect("pressed", self, "copy_backup_clipboard")
	
	if OS.has_feature('editor'):
		var st = $contents/buttons/show_tools
		st.visible = true
		st.connect("pressed", self, "show_tools")
		$contents/editor_tools/v/h/deploy_btn.connect("pressed", self, "tools_deploy_contract")
		
	NebulasWalletSingleton.connect("new_nrc20", self, "new_nrc20")
	for t in NebulasWalletSingleton.get_nrc20s():
		$send_panel/v/amount/token_options.add_item(t)
		
	NebulasWalletSingleton.register_wallet_ui_send(funcref(self, "invoke_ui_send"))

func new_nrc20(token):
	$send_panel/v/amount/token_options.add_item(token.token_symbol)

func show_tools():
	$contents/editor_tools.visible = true
	
func on_back_pressed():
	emit_signal("close_wallet")

func show_wallet(show_wallet_success=null):
	_current_show_wallet_success = show_wallet_success
	if !NebulasWalletSingleton.wallet_exists():
		create_wallet()
	elif !wallet_loaded:
		try_unlock_wallet()
	else:
		update_wallet_status()

func try_unlock_wallet():
	ask_pin("Unlock your wallet", funcref(self, "unlock_wallet"))
		
func unlock_wallet(error, pin):
	if !error:
		var res = NebulasWalletSingleton.load_wallet(pin)
		if res != null:
			update_wallet_status()
		else:
			show_error("Wrong PIN", "Retry", self, "try_unlock_wallet")
	else:
		show_error("Wrong PIN", "Retry", self, "try_unlock_wallet")

func _short_address(a):
	return a.substr(0, 6) + '...' + a.substr(len(a) - 7, 7)

func update_wallet_status():
	wallet_loaded = true
	var addr = NebulasWalletSingleton.get_address()
	address_label.text = _short_address(addr)
	var t: QRCodeTexture = address_qr.texture
	t.text = addr
	var state = yield(NebulasWalletSingleton.get_account_state(), "account_state")

	_last_account_state = state
	if state.result != null:
		balance_label.text = NebulasWalletSingleton.num_to_printable(state.result.result.balance) + ' ' + _coin_name
	
	update_tx_list()
	
	if _current_show_wallet_success != null:
			_current_show_wallet_success.call_func()
	
var currently_updating = false
func update_tx_list():
	if currently_updating:
		return
	currently_updating = true
	refresh_btn.disabled = true
	var tlparent = transaction_list.get_parent()
	tlparent.visible = false
	transaction_loader.visible = true
	
	transaction_loader.get_child(0).text = 'Loading transactions...'
	
	var addr = NebulasWalletSingleton.get_address()
	var info = yield(NebulasWalletSingleton.get_address_info(), "address_info")
	if info.has('error') and info.error != null:
		transaction_loader.get_child(0).text = 'Couldn\'t retrieve transactions list'
	else:
		for i in range(transaction_list.get_child_count()):
			transaction_list.remove_child(transaction_list.get_child(0))
		for i in range(len(info.result.data.txList)):
			var dets = info.result.data.txList[i]
			var tx = tx_ui.instance()
			transaction_list.add_child(tx)
			tx.init(addr, dets)
		transaction_loader.visible = false
		tlparent.visible = true
	currently_updating = false
	refresh_btn.disabled = false

func copy_address_to_clipboard():
	OS.clipboard = NebulasWalletSingleton.get_address()

func error_dialog_close():
	$error_panel.hide()
	emit_signal("error_dialog_closed")

var currently_confirmed_pin = ''
func create_wallet():
	currently_confirmed_pin = ''
	bring_pin_popup("Create your pin")
	connect("pin_confirmed", self, "_create_wallet_confirm_pin")
	connect("pin_canceled", self, "_create_wallet_cancel_pin")

func _create_wallet_must_create():
	show_error('You need to create a PIN', 'Retry', self, 'create_wallet')

func _create_wallet_confirm_pin(pin):
	if currently_confirmed_pin == '':
		currently_confirmed_pin = pin
		bring_pin_popup("Confirm your pin")
	else:
		_create_wallet_cleanup()
		if currently_confirmed_pin == pin:
			if NebulasWalletSingleton.new_wallet(pin):
				update_wallet_status()
			else:
				show_error('Failed to create wallet, device not supported', 'Ok', self, 'bailout')
		else:
			show_error('Your PIN confirmation must match', 'Retry', self, 'create_wallet')

func bailout():
	get_tree().quit()

func _create_wallet_cancel_pin():
	_create_wallet_cleanup()
	show_error('You need to create a PIN', 'Retry', self, 'create_wallet')
	
func show_error(message, action, target=null, method=null, args=[]):
	$error_panel/v/Label.text = message
	$error_panel/v/close.text = action
	$error_panel.popup_centered()
	if target != null:
		connect("error_dialog_closed", target, method, args, CONNECT_ONESHOT)

func _create_wallet_cleanup():
	disconnect("pin_confirmed", self, "_create_wallet_confirm_pin")
	disconnect("pin_canceled", self, "_create_wallet_cancel_pin")

var _ask_pin_callback: FuncRef
func ask_pin(reason, fref):
	bring_pin_popup(reason)
	_ask_pin_callback = fref
	connect("pin_confirmed", self, "_ask_pin_confirm")
	connect("pin_canceled", self, "_ask_pin_cancel")
	
func _cleanup_ask_pin():
	disconnect("pin_confirmed", self, "_ask_pin_confirm")
	disconnect("pin_canceled", self, "_ask_pin_cancel")
	
func _ask_pin_confirm(pin):
	_cleanup_ask_pin()
	_ask_pin_callback.call_func(false, pin)
	
func _ask_pin_cancel():
	_cleanup_ask_pin()
	_ask_pin_callback.call_func(true, null)

func show_pin():
	bring_pin_popup("Enter your pin")
	
func confirm_pin():
	$pin_panel.hide()
	if len(current_pin) == 6:
		emit_signal("pin_confirmed", current_pin)
	else:
		emit_signal("pin_canceled")
	
func erase_digit():
	current_pin = current_pin.substr(0, len(current_pin) - 1)
	update_pin_label()
	
func bring_pin_popup(action):
	pin_action_label.text = action
	current_keyboard_order.shuffle()
	digit0_btn.text = str(current_keyboard_order[0])
	digit1_btn.text = str(current_keyboard_order[1])
	digit2_btn.text = str(current_keyboard_order[2])
	digit3_btn.text = str(current_keyboard_order[3])
	digit4_btn.text = str(current_keyboard_order[4])
	digit5_btn.text = str(current_keyboard_order[5])
	digit6_btn.text = str(current_keyboard_order[6])
	digit7_btn.text = str(current_keyboard_order[7])
	digit8_btn.text = str(current_keyboard_order[8])
	digit9_btn.text = str(current_keyboard_order[9])
	current_pin = ''
	update_pin_label()
	$pin_panel.popup_centered()

func update_pin_label():
	var echo_char = '*'
	digit0_label.text = echo_char if len(current_pin) >= 1 else ''
	digit1_label.text = echo_char if len(current_pin) >= 2 else ''
	digit2_label.text = echo_char if len(current_pin) >= 3 else ''
	digit3_label.text = echo_char if len(current_pin) >= 4 else ''
	digit4_label.text = echo_char if len(current_pin) >= 5 else ''
	digit5_label.text = echo_char if len(current_pin) >= 6 else ''

func put_pin_digit(num):
	if len(current_pin) < 6:
		current_pin += str(current_keyboard_order[num])
		update_pin_label()
		if len(current_pin) == 6:
			confirm_pin()

func show_backup_dialog():
	$backup_panel/v/showpk.pressed = false
	$backup_panel/v/hexedit.text = ''
	$backup_panel.popup_centered()

func update_showpk_toggle():
	if $backup_panel/v/showpk.pressed:
		$backup_panel/v/hexedit.text = NebulasWalletSingleton.get_private_key()
	else:
		$backup_panel/v/hexedit.text = ''
	
func close_backup_dialog():
	$backup_panel.hide()
	
func copy_backup_clipboard():
	OS.clipboard = NebulasWalletSingleton.get_private_key()

var estimated_bytes = 200
func show_send_dialog(send_token=null, send_amount=''):
	estimated_bytes = 200
	$send_panel/v/destination/address_edit.text = ''
	$send_panel/v/amount/amount_edit.editable = send_amount == ''
	$send_panel/v/amount/amount_edit.text = send_amount
	if send_token == null:
		$send_panel/v/amount/token_options.visible = true
		$send_panel/v/token_name.visible = false
		$send_panel/v/amount/token_options.selected = 0
		_current_send_token = null
	else:
		$send_panel/v/amount/token_options.visible = false
		$send_panel/v/token_name.visible = true
		var tok = NebulasWalletSingleton.get_token_by_name(send_token)
		_current_send_token = tok
		$send_panel/v/token_name.text = tok.asset_title
	$send_panel/v/fee/fee_slider.value = 0
	$send_panel/v/buttons/send_btn.disabled = false
	$send_panel/v/buttons/cancel_btn.disabled = false

	fee_rate_changed(0)
	$send_panel.popup_centered()

const gas_multipliers = [1, 3, 5, 10]
const gas_priorities = ['Slow', 'Normal', 'Fast', 'Urgent']
func fee_rate_changed(v):
	var type_label = $send_panel/v/fee/fee_type
	var fee_label = $send_panel/v/fee_label
	var fee_value = 0
	var nebulas_price = 0.41
	var nebulas_price_symbol = '$'
		
	var wei_per_byte = 1000
	type_label.text = gas_priorities[int(v)]
	fee_value = gas_multipliers[int(v)]
	
	var nas_price = fee_value * int(NebulasWalletSingleton._current_gas_price) * estimated_bytes * wei_per_byte
	var nas_price_txt = NebulasWalletSingleton.num_to_printable(nas_price)
	
	var dec_mult = 10000
	var fiat_price = nebulas_price * nas_price
	var fiat_price_txt = nebulas_price_symbol + NebulasWalletSingleton.num_to_printable(round(fiat_price * dec_mult) / dec_mult)
	
	fee_label.text = nas_price_txt + 'NAS (~' + fiat_price_txt + ')'

func token_changed(idx):
	var tn = $send_panel/v/token_name
	tn.visible = false
	if idx == 0:
		estimated_bytes = 200
	else:
		estimated_bytes = 8000
		
	var tkopt = $send_panel/v/amount/token_options
	var itm = tkopt.get_item_text(idx)
	var tok = NebulasWalletSingleton.get_token(itm)
	if tok != null:
		tn.text = tok.token_name
		tn.visible = true
	fee_rate_changed($send_panel/v/fee/fee_slider.value)

func hide_send_panel():
	$send_panel.hide()

func do_send():
	var token_index = $send_panel/v/amount/token_options.selected
	$send_panel/v/buttons/send_btn.disabled = true
	$send_panel/v/buttons/cancel_btn.disabled = true
		
	var address = $send_panel/v/destination/address_edit.text
	var t = NebulasWalletSingleton.new_transaction()
	if _current_send_token != null:
		_current_send_token.create_transfer(t, address)
	elif token_index != 0:
		var token_symbol = $send_panel/v/amount/token_options.get_item_text(token_index)
		var token = NebulasWalletSingleton.get_token(token_symbol)
		t.contract = token.create_send(t, address, $send_panel/v/amount/amount_edit.text)
	else:
		t.to = address
		t.value = NebulasWalletSingleton.printable_to_num($send_panel/v/amount/amount_edit.text)
	t.estimate_gas()
	var result = yield(t, 'tx_result')

	if result:
		if t.send_tx(gas_multipliers[int($send_panel/v/fee/fee_slider.value)]):
			var tx_result: Dictionary = yield(t, 'tx_result')
			#print('Tx can go: ', txhash)
			if tx_result.has("result") and tx_result.result.has("result"):
				var txhash =  tx_result.result.result.txhash
				show_error("Tx sent succesfully: \n " + txhash, "Ok", self, "hide_send_panel")
		else:
			show_error("Couldn't send transaction, try again later", "Ok")
	else:
		show_error("Couldn't estimate transaction gas, try again later", "Ok")
	$send_panel/v/buttons/send_btn.disabled = false
	$send_panel/v/buttons/cancel_btn.disabled = false

func paste_address_send():
	$send_panel/v/destination/address_edit.text = OS.clipboard

func tools_deploy_contract():
	var t = NebulasWalletSingleton.new_transaction()
	t.to = NebulasWalletSingleton.get_address()
	t.value = 0
	t.contract = {
		"sourceType": "js",
		"source": $contents/editor_tools/v/code_edit.text, #.split("\n").join(""),
		"args": JSON.print(["My Awesome Game Token 2", "MAGT2", 2, "10000"])
	}
	t.estimate_gas()
	var result = yield(t, 'tx_result')

	if result:
		t.contract = {
			"SourceType": "js",
			"Source": $contents/editor_tools/v/code_edit.text, #.split("\n").join(""),
			"Args": JSON.print(["My Awesome Game Token 2", "MAGT2", 2, "10000"])
		}
		if t.send_tx(gas_multipliers[0]):
			var tx_result: Dictionary = yield(t, 'tx_result')
			if tx_result.has("result") and tx_result.result.has("result"):
				var txhash =  tx_result.result.result.txhash
				var contract_address = tx_result.result.result.contract_address
				show_error("Tx sent succesfully: \n ", txhash, "Ok")
		else:
			show_error("Couldn't send transaction, try again later", "Ok")
	else:
		show_error("Couldn't estimate transaction gas, try again later", "Ok")

var _current_invoke_token = ''
var _current_invoke_amount = ''
func invoke_ui_send(token, amount):
	_current_invoke_token = token
	_current_invoke_amount = amount
	show_wallet(funcref(self, "_finish_invoke_ui_send"))
	
func _finish_invoke_ui_send():
	show_send_dialog(_current_invoke_token, _current_invoke_amount)
