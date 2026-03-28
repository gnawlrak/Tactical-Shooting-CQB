extends Control

# ============ 菜单系统 ============

var main_menu: VBoxContainer
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
	"key_right": KEY_D
}

func _ready():
	# 获取节点引用
	main_menu = get_node_or_null("MainMenu")
	settings_menu = get_node_or_null("SettingsMenu")
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
	show_main_menu()
	print("主菜单初始化完成")

# ============ 主菜单 ============

func show_main_menu():
	if main_menu:
		main_menu.visible = true
	if settings_menu:
		settings_menu.visible = false
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
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_settings_pressed():
	if main_menu:
		main_menu.visible = false
	if settings_menu:
		settings_menu.visible = true
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
	
	if key_forward_btn:
		key_forward_btn.text = "前进: " + OS.get_keycode_string(settings.key_forward)
	if key_back_btn:
		key_back_btn.text = "后退: " + OS.get_keycode_string(settings.key_back)
	if key_left_btn:
		key_left_btn.text = "左移: " + OS.get_keycode_string(settings.key_left)
	if key_right_btn:
		key_right_btn.text = "右移: " + OS.get_keycode_string(settings.key_right)

func _on_key_forward_pressed():
	start_key_bind("KeyForward", "key_forward")

func _on_key_back_pressed():
	start_key_bind("KeyBack", "key_back")

func _on_key_left_pressed():
	start_key_bind("KeyLeft", "key_left")

func _on_key_right_pressed():
	start_key_bind("KeyRight", "key_right")

func start_key_bind(node_name, key_name):
	if not settings_menu:
		return
	var btn = settings_menu.get_node_or_null(node_name)
	if btn:
		waiting_for_key = true
		current_key_button = btn
		current_key_name = key_name
		btn.text = "按下按键..."

func _input(event):
	if waiting_for_key and event is InputEventKey and event.pressed:
		settings[current_key_name] = event.keycode
		if current_key_button:
			current_key_button.text = OS.get_keycode_string(event.keycode)
		waiting_for_key = false
		current_key_button = null
		current_key_name = ""
		get_viewport().set_input_as_handled()

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
		AudioServer.set_bus_mute(0, !settings.sound_enabled)
		AudioServer.set_bus_volume_db(0, linear_to_db(settings.sound_volume))
		print("设置已加载")
