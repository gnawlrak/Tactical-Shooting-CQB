extends CanvasLayer

# ============ 暂停菜单 ============

var pause_menu: VBoxContainer
var blur_overlay: ColorRect
var is_paused: bool = false

func _ready():
	pause_menu = get_node_or_null("PauseMenu")
	blur_overlay = get_node_or_null("BlurOverlay")
	
	# 初始状态隐藏
	if pause_menu:
		pause_menu.visible = false
	if blur_overlay:
		blur_overlay.visible = false
	
	# 确保此节点在暂停时仍能处理输入
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC键
		toggle_pause()

func toggle_pause():
	if is_paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	is_paused = true
	get_tree().paused = true
	if pause_menu:
		pause_menu.visible = true
	if blur_overlay:
		blur_overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("游戏暂停")

func resume_game():
	is_paused = false
	get_tree().paused = false
	if pause_menu:
		pause_menu.visible = false
	if blur_overlay:
		blur_overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("游戏继续")

func _on_resume_pressed():
	resume_game()

func _on_main_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _on_quit_pressed():
	get_tree().quit()
