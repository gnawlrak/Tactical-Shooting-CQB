extends Control

# ============ 菜单系统 ============

var main_menu: VBoxContainer
var settings_scroll: ScrollContainer
var settings_menu: VBoxContainer
var difficulty_label: Label
var title_label: Label
var blur_overlay: ColorRect
var blur_material: ShaderMaterial

# 难度选项
enum Difficulty { EASY, NORMAL, HARD, INSANE }
var current_difficulty : Difficulty = Difficulty.NORMAL
var difficulty_names = ["简单", "普通", "困难", "疯狂"]

# 设置
var settings = {
	"quality": 2,
	"sound_enabled": true,
	"sound_volume": 1.0,
	"mouse_sensitivity": 0.002,
	"key_forward": KEY_W,
	"key_back": KEY_S,
	"key_left": KEY_A,
	"key_right": KEY_D,
	"key_reload": KEY_R,
	"key_lean_left": KEY_Q,
	"key_lean_right": KEY_E,
	"key_crouch": KEY_C,
	"key_prone": KEY_V,
	"key_weapon1": KEY_1,
	"key_weapon2": KEY_2
}

func _ready():
	# 获取节点引用
	main_menu = get_node_or_null("MainMenu")
	settings_scroll = get_node_or_null("SettingsScroll")
	if settings_scroll:
		settings_menu = settings_scroll.get_node_or_null("SettingsMenu")
	title_label = get_node_or_null("Title")
	blur_overlay = get_node_or_null("BlurOverlay")
	
	# 获取模糊材质
	if blur_overlay and blur_overlay.material:
		blur_material = blur_overlay.material as ShaderMaterial
	
	if main_menu:
		var diff_container = main_menu.get_node_or_null("DifficultyContainer")
		if diff_container:
			difficulty_label = diff_container.get_node_or_null("DifficultyLabel")
	
	load_settings()
	apply_key_bindings()
	show_main_menu()
	print("主菜单初始化完成")

# ============ 主菜单 ============

func show_main_menu():
	if main_menu:
		main_menu.visible = true
	if settings_scroll:
		settings_scroll.visible = false
	if title_label:
		title_label.visible = true
	update_difficulty_label()

func update_difficulty_label():
	if not difficulty_label and main_menu:
		var diff_container = main_menu.get_node_or_null("DifficultyContainer")
		if diff_container:
			difficulty_label = diff_container.get_node_or_null("DifficultyLabel")
	
	if difficulty_label:
		difficulty_label.text = "难度: " + difficulty_names[current_difficulty]

func _on_difficulty_left_pressed():
	current_difficulty = (current_difficulty - 1 + 4) % 4
	update_difficulty_label()
	print("难度: ", difficulty_names[current_difficulty])

func _on_difficulty_right_pressed():
	current_difficulty = (current_difficulty + 1) % 4
	update_difficulty_label()
	print("难度: ", difficulty_names[current_difficulty])

func _on_start_pressed():
	# 设置难度
	if get_node_or_null("/root/GlobalSave"):
		match current_difficulty:
			Difficulty.EASY:
				get_node("/root/GlobalSave").threat_level = 0.5
			Difficulty.NORMAL:
				get_node("/root/GlobalSave").threat_level = 1.0
			Difficulty.HARD:
				get_node("/root/GlobalSave").threat_level = 2.0
			Difficulty.INSANE:
				get_node("/root/GlobalSave").threat_level = 3.0
	
	save_settings()
	apply_key_bindings()
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_settings_pressed():
	if main_menu:
		main_menu.visible = false
	if settings_scroll:
		settings_scroll.visible = true
	if title_label:
		title_label.visible = false
	await get_tree().process_frame
	update_settings_ui()

func _on_quit_pressed():
	get_tree().quit()

# ============ 设置菜单 ============

var quality_label: Label
var sound_toggle: CheckBox
var volume_slider: HSlider
var sensitivity_slider: HSlider

var quality_names = ["低", "中", "高"]

func update_settings_ui():
	if not settings_menu:
		return
	
	quality_label = settings_menu.get_node_or_null("QualityContainer/QualityLabel")
	sound_toggle = settings_menu.get_node_or_null("SoundToggle")
	volume_slider = settings_menu.get_node_or_null("VolumeSlider")
	sensitivity_slider = settings_menu.get_node_or_null("SensitivitySlider")
	
	if quality_label:
		quality_label.text = "画质: " + quality_names[settings.quality]
	if sound_toggle:
		sound_toggle.button_pressed = settings.sound_enabled
		sound_toggle.text = "开启" if settings.sound_enabled else "关闭"
	if volume_slider:
		volume_slider.value = settings.sound_volume * 100
	if sensitivity_slider:
		sensitivity_slider.value = settings.mouse_sensitivity * 1000
	update_key_buttons()

func _on_quality_left_pressed():
	settings.quality = (settings.quality - 1 + 3) % 3
	if quality_label:
		quality_label.text = "画质: " + quality_names[settings.quality]
	apply_quality_settings()

func _on_quality_right_pressed():
	settings.quality = (settings.quality + 1) % 3
	if quality_label:
		quality_label.text = "画质: " + quality_names[settings.quality]
	apply_quality_settings()

func apply_quality_settings():
	match settings.quality:
		0:
			RenderingServer.viewport_set_msaa_3d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_DISABLED)
		1:
			RenderingServer.viewport_set_msaa_3d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_2X)
		2:
			RenderingServer.viewport_set_msaa_3d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_4X)
	print("画质: ", quality_names[settings.quality])

func _on_sound_toggled(button_pressed):
	settings.sound_enabled = button_pressed
	if sound_toggle:
		sound_toggle.text = "开启" if button_pressed else "关闭"
	AudioServer.set_bus_mute(0, !button_pressed)

func _on_volume_changed(value):
	settings.sound_volume = value / 100.0
	AudioServer.set_bus_volume_db(0, linear_to_db(settings.sound_volume))

func _on_sensitivity_changed(value):
	settings.mouse_sensitivity = value / 1000.0

func _on_back_pressed():
	show_main_menu()

func apply_key_bindings():
	# 更新输入映射
	update_input_action("ui_up", settings.key_forward)
	update_input_action("ui_down", settings.key_back)
	update_input_action("ui_left", settings.key_left)
	update_input_action("ui_right", settings.key_right)
	update_input_action("reload", settings.key_reload)
	update_input_action("lean_left", settings.key_lean_left)
	update_input_action("lean_right", settings.key_lean_right)
	update_input_action("crouch", settings.key_crouch)
	update_input_action("prone", settings.key_prone)
	update_input_action("weapon_1", settings.key_weapon1)
	update_input_action("weapon_2", settings.key_weapon2)
	print("按键绑定已更新")

func update_input_action(action_name: String, keycode: int):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	
	# 清除现有的事件
	var events = InputMap.action_get_events(action_name)
	for event in events:
		if event is InputEventKey:
			InputMap.action_erase_event(action_name, event)
	
	# 添加新的按键事件
	var key_event = InputEventKey.new()
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)

# ============ 键位设置 ============
var key_forward_btn: Button
var key_back_btn: Button
var key_left_btn: Button
var key_right_btn: Button

var waiting_for_key = false
var current_key_button = null
var current_key_name = ""

func update_key_buttons():
	if not settings_menu:
		return
	
	key_forward_btn = settings_menu.get_node_or_null("KeyForward")
	key_back_btn = settings_menu.get_node_or_null("KeyBack")
	key_left_btn = settings_menu.get_node_or_null("KeyLeft")
	key_right_btn = settings_menu.get_node_or_null("KeyRight")
	var key_reload_btn = settings_menu.get_node_or_null("KeyReload")
	var key_lean_left_btn = settings_menu.get_node_or_null("KeyLeanLeft")
	var key_lean_right_btn = settings_menu.get_node_or_null("KeyLeanRight")
	var key_crouch_btn = settings_menu.get_node_or_null("KeyCrouch")
	var key_prone_btn = settings_menu.get_node_or_null("KeyProne")
	var key_weapon1_btn = settings_menu.get_node_or_null("KeyWeapon1")
	var key_weapon2_btn = settings_menu.get_node_or_null("KeyWeapon2")
	
	if key_forward_btn:
		key_forward_btn.text = "前进: " + OS.get_keycode_string(settings.key_forward)
	if key_back_btn:
		key_back_btn.text = "后退: " + OS.get_keycode_string(settings.key_back)
	if key_left_btn:
		key_left_btn.text = "左移: " + OS.get_keycode_string(settings.key_left)
	if key_right_btn:
		key_right_btn.text = "右移: " + OS.get_keycode_string(settings.key_right)
	if key_reload_btn:
		key_reload_btn.text = "换弹: " + OS.get_keycode_string(settings.key_reload)
	if key_lean_left_btn:
		key_lean_left_btn.text = "左探头: " + OS.get_keycode_string(settings.key_lean_left)
	if key_lean_right_btn:
		key_lean_right_btn.text = "右探头: " + OS.get_keycode_string(settings.key_lean_right)
	if key_crouch_btn:
		key_crouch_btn.text = "蹲下: " + OS.get_keycode_string(settings.key_crouch)
	if key_prone_btn:
		key_prone_btn.text = "趴下: " + OS.get_keycode_string(settings.key_prone)
	if key_weapon1_btn:
		key_weapon1_btn.text = "主武器: " + OS.get_keycode_string(settings.key_weapon1)
	if key_weapon2_btn:
		key_weapon2_btn.text = "副武器: " + OS.get_keycode_string(settings.key_weapon2)

func _on_key_forward_pressed():
	start_key_bind("KeyForward", "key_forward")

func _on_key_back_pressed():
	start_key_bind("KeyBack", "key_back")

func _on_key_left_pressed():
	start_key_bind("KeyLeft", "key_left")

func _on_key_right_pressed():
	start_key_bind("KeyRight", "key_right")

func _on_key_reload_pressed():
	start_key_bind("KeyReload", "key_reload")

func _on_key_lean_left_pressed():
	start_key_bind("KeyLeanLeft", "key_lean_left")

func _on_key_lean_right_pressed():
	start_key_bind("KeyLeanRight", "key_lean_right")

func _on_key_crouch_pressed():
	start_key_bind("KeyCrouch", "key_crouch")

func _on_key_prone_pressed():
	start_key_bind("KeyProne", "key_prone")

func _on_key_weapon1_pressed():
	start_key_bind("KeyWeapon1", "key_weapon1")

func _on_key_weapon2_pressed():
	start_key_bind("KeyWeapon2", "key_weapon2")

func start_key_bind(node_name, key_name):
	if not settings_menu:
		return
	var btn = settings_menu.get_node_or_null(node_name)
	if btn:
		waiting_for_key = true
		current_key_button = btn
		current_key_name = key_name
		var display_name = get_key_display_name(key_name.replace("key_", ""))
		btn.text = display_name + ": 按下按键..."

func _input(event):
	if waiting_for_key and event is InputEventKey and event.pressed:
		settings[current_key_name] = event.keycode
		if current_key_button:
			var key_name = current_key_name.replace("key_", "")
			current_key_button.text = get_key_display_name(key_name) + ": " + OS.get_keycode_string(event.keycode)
		waiting_for_key = false
		current_key_button = null
		current_key_name = ""
		get_viewport().set_input_as_handled()

func get_key_display_name(key_name: String) -> String:
	match key_name:
		"forward": return "前进"
		"back": return "后退"
		"left": return "左移"
		"right": return "右移"
		"reload": return "换弹"
		"lean_left": return "左探头"
		"lean_right": return "右探头"
		"crouch": return "蹲下"
		"prone": return "趴下"
		"weapon1": return "主武器"
		"weapon2": return "副武器"
		_: return key_name

# ============ 保存/加载 ============

func save_settings():
	var config = ConfigFile.new()
	config.set_value("game", "difficulty", current_difficulty)
	config.set_value("graphics", "quality", settings.quality)
	config.set_value("audio", "enabled", settings.sound_enabled)
	config.set_value("audio", "volume", settings.sound_volume)
	config.set_value("controls", "sensitivity", settings.mouse_sensitivity)
	config.set_value("controls", "key_forward", settings.key_forward)
	config.set_value("controls", "key_back", settings.key_back)
	config.set_value("controls", "key_left", settings.key_left)
	config.set_value("controls", "key_right", settings.key_right)
	config.set_value("controls", "key_reload", settings.key_reload)
	config.set_value("controls", "key_lean_left", settings.key_lean_left)
	config.set_value("controls", "key_lean_right", settings.key_lean_right)
	config.set_value("controls", "key_crouch", settings.key_crouch)
	config.set_value("controls", "key_prone", settings.key_prone)
	config.set_value("controls", "key_weapon1", settings.key_weapon1)
	config.set_value("controls", "key_weapon2", settings.key_weapon2)
	config.save("user://settings.cfg")
	print("设置已保存")

func load_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		current_difficulty = config.get_value("game", "difficulty", Difficulty.NORMAL)
		settings.quality = config.get_value("graphics", "quality", 2)
		settings.sound_enabled = config.get_value("audio", "enabled", true)
		settings.sound_volume = config.get_value("audio", "volume", 1.0)
		settings.mouse_sensitivity = config.get_value("controls", "sensitivity", 0.002)
		settings.key_forward = config.get_value("controls", "key_forward", KEY_W)
		settings.key_back = config.get_value("controls", "key_back", KEY_S)
		settings.key_left = config.get_value("controls", "key_left", KEY_A)
		settings.key_right = config.get_value("controls", "key_right", KEY_D)
		settings.key_reload = config.get_value("controls", "key_reload", KEY_R)
		settings.key_lean_left = config.get_value("controls", "key_lean_left", KEY_Q)
		settings.key_lean_right = config.get_value("controls", "key_lean_right", KEY_E)
		settings.key_crouch = config.get_value("controls", "key_crouch", KEY_C)
		settings.key_prone = config.get_value("controls", "key_prone", KEY_V)
		settings.key_weapon1 = config.get_value("controls", "key_weapon1", KEY_1)
		settings.key_weapon2 = config.get_value("controls", "key_weapon2", KEY_2)
		AudioServer.set_bus_mute(0, !settings.sound_enabled)
		AudioServer.set_bus_volume_db(0, linear_to_db(settings.sound_volume))
		print("设置已加载")
