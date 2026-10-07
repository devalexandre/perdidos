extends Node

const AUTH_SCREEN_SCRIPT: GDScript = preload("res://scripts/client/android_auth_screen.gd")

var _failures: int = 0
var _out_dir: String = "/tmp"


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var auth := AUTH_SCREEN_SCRIPT.new("https://accounts.example.test") as AndroidAuthScreen
	add_child(auth)
	await get_tree().process_frame
	await get_tree().process_frame
	var viewport: Rect2 = get_viewport().get_visible_rect()
	var google: Button = auth.get("_google_login")
	var email: LineEdit = auth.get("_email")
	var password: LineEdit = auth.get("_password")
	var confirm: LineEdit = auth.get("_confirm")
	var show_passwords: CheckBox = auth.get("_show_passwords")
	var register_tab: Button = auth.get("_register_tab")
	_check(google != null and google.visible, "botão Google visível")
	_check(email != null and email.visible and password != null and password.visible, "campos de login visíveis")
	_check(register_tab != null and register_tab.visible, "aba Criar conta visível")
	_check(confirm != null and not confirm.get_parent().visible, "confirmação de senha oculta no modo Entrar")
	_check(show_passwords != null and show_passwords.visible, "controle Mostrar senha visível")
	_check(show_passwords != null and show_passwords.text == tr("ANDROID_AUTH_SHOW_PASSWORD"),
			"legenda Mostrar senha traduzida")
	_check(password != null and password.secret and confirm != null and confirm.secret, "senhas começam ocultas")
	if show_passwords != null:
		show_passwords.button_pressed = true
		show_passwords.toggled.emit(true)
		_check(password != null and not password.secret and confirm != null and not confirm.secret,
				"Mostrar senha revela os dois campos")
		show_passwords.button_pressed = false
		show_passwords.toggled.emit(false)
		_check(password != null and password.secret and confirm != null and confirm.secret,
				"ocultar senha mascara os dois campos novamente")
	if google != null:
		_check(viewport.encloses(google.get_global_rect()), "botão Google dentro da viewport inicial")
		_check(google.custom_minimum_size.y >= 56.0, "alvo de toque Google tem pelo menos 56 px")
	var image: Image = get_viewport().get_texture().get_image()
	var suffix: String = "%dx%d" % [int(viewport.size.x), int(viewport.size.y)]
	image.save_png(_out_dir.path_join("android_auth_%s.png" % suffix))
	auth.call("_set_register_mode", true)
	await get_tree().process_frame
	_check(confirm != null and confirm.visible and confirm.get_parent().visible, "confirmação aparece no modo Criar conta")
	_check(google != null and viewport.encloses(google.get_global_rect()), "Google continua visível ao criar conta")
	var error_label: Label = auth.get("_error")
	if email != null and password != null and confirm != null:
		email.text = "ana@example.com"
		password.text = "senha123"
		confirm.text = "senha456"
		auth.call("_submit_auth")
		_check(error_label.text == tr("ANDROID_AUTH_PASSWORD_MISMATCH"), "senhas diferentes mostram erro específico")
		confirm.text = password.text
		auth.call("_submit_auth")
		_check(error_label.text != tr("ANDROID_AUTH_PASSWORD_MISMATCH"), "senhas iguais passam pela validação local")
		(auth.get("_request") as HTTPRequest).cancel_request()
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	print(("ok   " if condition else "FAIL ") + description)
	if not condition:
		_failures += 1