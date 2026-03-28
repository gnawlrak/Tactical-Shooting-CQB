extends CharacterBody3D

enum Stance { STANDING, CROUCHING, PRONE }

## --- 基础配置 ---
@export var can_move : bool = true
@export var has_gravity : bool = true
@export var can_jump : bool = true
@export var can_sprint : bool = false

@export_group("Speeds")
@export var look_speed : float = 0.002
@export var ads_look_speed : float = 0.001 
@export var base_speed : float = 7.0
@export var jump_velocity : float = 4.5
@export var sprint_speed : float = 10.0
@export var ads_lerp_speed : float = 20.0
@export var shell_scene : PackedScene = preload("res://addons/proto_controller/bullet_shell.tscn")
@export var bullet_hole_scene : PackedScene = preload("res://addons/proto_controller/bullet_hole.tscn")

@export_group("Weapon Settings")
@export var wall_avoid_speed : float = 12.0
@export var weapon_down_angle : float = -50.0
@export var weapon_back_offset : float = 0.65
@export var primary_wall_dist : float = 1.3 # 增加探测深度，防止长枪管穿墙
@export var secondary_wall_dist : float = 0.6

@export_group("Shooting - Primary (MCX)")
@export var primary_fire_rate : float = 0.1 # 10 rounds per second
@export var primary_recoil_strength : float = 0.35
@export var primary_hip_spread : float = 2.0
@export var primary_damage : float = 25.0

@export_group("Shooting - Secondary (Glock)")
@export var secondary_fire_rate : float = 0.2 # 5 rounds per second
@export var secondary_recoil_strength : float = 0.5
@export var secondary_hip_spread : float = 3.5
@export var secondary_damage : float = 15.0

@export_group("Visual Recoil Settings")
@export var recoil_recovery_speed : float = 10.0
@export var recoil_snap_speed : float = 20.0
@export var max_recoil_x : float = 5.0

@export_group("Sound Settings")
@export var primary_single_fire_sound : AudioStream  # 单发音效
@export var primary_auto_fire_sound : AudioStream    # 连发音效
@export var secondary_fire_sound : AudioStream
@export var reload_sound : AudioStream
@export var dry_fire_sound : AudioStream
@export var shell_eject_sound : AudioStream
@export var footstep_sound : AudioStream
@export var impact_sound : AudioStream

@export_group("Ammo Settings")
@export var primary_mag_capacity : int = 30
@export var primary_mag_count : int = 4  # 3+1 (3备用+1装填)
@export var secondary_mag_capacity : int = 21
@export var secondary_mag_count : int = 4
@export var max_health : float = 100.0

@export var primary_reload_time : float = 2.0
@export var secondary_reload_time : float = 1.5

@export_group("Secondary Weapon ADS")
@export var secondary_ads_pos : Vector3 = Vector3(-0.206, -0.15, 0.1)
@export var secondary_ads_fov : float = 40.0

@export_group("Lean Settings")
@export var lean_angle : float = 15.0
@export var lean_offset : float = 0.3
@export var lean_speed : float = 8.0

@export_group("Stance Settings")
@export var standing_height : float = 1.3
@export var crouching_height : float = 0.9
@export var prone_height : float = 0.4
@export var crouch_speed_mult : float = 0.4
@export var crouch_sprint_mult : float = 0.7
@export var prone_speed_mult : float = 0.3
@export var stance_transition_speed : float = 8.0

## --- 核心组件引用 ---
@onready var head: Node3D = $Head
@onready var main_camera: Camera3D = $"Head/主视角"
@onready var ads_camera: Camera3D = $"Head/瞄准视角"
@onready var collision_shape: CollisionShape3D = $Collider
@onready var character_mesh: MeshInstance3D = $Mesh
@onready var wall_detector: RayCast3D = $"Head/主视角/WallDetector"
@onready var weapon_holder: Node3D = $Head/WeaponPivot
@onready var primary_weapon: Node3D = $Head/WeaponPivot/mcx
@onready var secondary_weapon: Node3D = $Head/WeaponPivot/glock
@onready var aim_ray: RayCast3D = $"Head/主视角/AimRay"

@onready var primary_muzzle = $Head/WeaponPivot/mcx/Muzzle
@onready var primary_eject = $Head/WeaponPivot/mcx/Eject
@onready var secondary_muzzle = $Head/WeaponPivot/glock/Muzzle
@onready var secondary_eject = $Head/WeaponPivot/glock/Eject

@onready var gunfire_sound : AudioStreamPlayer3D = $GunfireSound
@onready var reload_sound_player : AudioStreamPlayer3D = $ReloadSound
@onready var dry_fire_sound_player : AudioStreamPlayer3D = $DryFireSound
@onready var shell_eject_sound_player : AudioStreamPlayer3D = $ShellEjectSound
@onready var footstep_sound_player : AudioStreamPlayer = $FootstepSound
@onready var impact_sound_player : AudioStreamPlayer3D = $ImpactSound

@onready var primary_flash = $Head/WeaponPivot/mcx/Muzzle/Flash
@onready var secondary_flash = $Head/WeaponPivot/glock/Muzzle/Flash

@onready var ammo_hud : CanvasLayer = null

## --- 内部变量 ---
var mouse_captured : bool = false
var look_rotation : Vector2
var is_ads : bool = false 

var current_health : float = 100.0

var weapon_normal_pos : Vector3
var weapon_normal_rot : Vector3

var ads_weight : float = 0.0
var default_fov : float
var target_ads_fov : float
var ads_camera_pos : Vector3
var current_ads_pos : Vector3

var lean_weight : float = 0.0 # -1.0 (Q) to 1.0 (E)
var hand_side_weight : float = 0.0 # 0.0 (Left) to 1.0 (Right)
var head_base_pos : Vector3

var current_weapon_index : int = 1 # 1: Primary, 2: Secondary
var is_switching : bool = false
var switch_weight : float = 0.0 # 0 (Up) to 1 (Down)
var weapon_list : Array = []
var next_weapon_index : int = 1

var primary_ads_pos : Vector3
var primary_ads_fov : float

var lean_target_state : int = 0 # 0: None, -1: Left (Q), 1: Right (E)

var fire_cooldown : float = 0.0
var current_recoil : Vector3 = Vector3.ZERO
var recoil_pivot : Vector3 = Vector3.ZERO # The target recoil rotation
var has_fired_this_click : bool = false
var is_first_shot_in_burst : bool = true

var primary_magazines : Array[int] = []  # 弹匣数组，每个元素是该弹匣的当前弹药数
var primary_current_mag_index : int = 0  # 当前装填的弹匣索引
var secondary_magazines : Array[int] = []
var secondary_current_mag_index : int = 0
var is_reloading : bool = false

var current_stance : int = Stance.STANDING
var target_stance : int = Stance.STANDING
var stance_height : float = 1.8
var initial_collision_height : float = 1.8

var footstep_timer : float = 0.0
var footstep_interval : float = 0.4

# Sound emission signal for AI
signal player_made_sound(position: Vector3, sound_type: String, volume: float)

func _ready() -> void:
	current_health = max_health
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	head_base_pos = head.position
	initial_collision_height = collision_shape.shape.height
	stance_height = standing_height
	
	# 确保资源唯一，防止干扰其他实例
	if character_mesh and character_mesh.mesh:
		character_mesh.mesh = character_mesh.mesh.duplicate()
	if collision_shape and collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()
	
	if weapon_holder:
		weapon_normal_pos = weapon_holder.position
		weapon_normal_rot = weapon_holder.rotation
	
	default_fov = main_camera.fov
	target_ads_fov = ads_camera.fov
	ads_camera_pos = ads_camera.position
	
	main_camera.make_current()
	
	# 初始化武器库
	weapon_list = [primary_weapon, secondary_weapon]
	primary_ads_pos = ads_camera.position
	primary_ads_fov = ads_camera.fov
	
	# 初始状态：显示主武器，隐藏副武器
	primary_weapon.visible = true
	secondary_weapon.visible = false
	
	# 连接声音信号到场景树根节点
	if not get_tree().root.has_signal("player_made_sound"):
		get_tree().root.add_user_signal("player_made_sound", [{"name": "position", "type": TYPE_VECTOR3}, {"name": "sound_type", "type": TYPE_STRING}, {"name": "volume", "type": TYPE_FLOAT}])
	
	# 修复：确保 WallDetector 朝向正前方，探测起点稍微下移
	if wall_detector:
		wall_detector.position.x = -0.1 
		wall_detector.position.y = -0.2 
		wall_detector.position.z = 0.0 
		wall_detector.rotation_degrees.x = 90 # 确保 -Y 轴朝向正前方
		wall_detector.target_position = Vector3(0, -1.8, 0) # 加长探测线
	
	if aim_ray:
		aim_ray.add_exception(self) # 核心修复：防止射线撞击自己导致弹孔出现在枪膛里
		aim_ray.position.z = 0.0
		aim_ray.target_position = Vector3(0, -100, 0) # 长距离射击线
	
	# 初始化弹药（弹匣系统）
	primary_magazines.clear()
	for i in range(primary_mag_count):
		primary_magazines.append(primary_mag_capacity)
	primary_current_mag_index = 0
	
	secondary_magazines.clear()
	for i in range(secondary_mag_count):
		secondary_magazines.append(secondary_mag_capacity)
	secondary_current_mag_index = 0
	
	# 加载并实例化 HUD
	var hud_scene = load("res://addons/proto_controller/ammo_hud.tscn")
	if hud_scene:
		ammo_hud = hud_scene.instantiate()
		add_child(ammo_hud)
		update_ammo_display()
	
	capture_mouse()

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
	
	# 武器切换快捷键
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1 and current_weapon_index != 1 and not is_switching:
			start_weapon_switch(1)
		elif event.keycode == KEY_2 and current_weapon_index != 2 and not is_switching:
			start_weapon_switch(2)
		
		# 探头切换逻辑
		if event.keycode == KEY_Q:
			lean_target_state = -1 if lean_target_state != -1 else 0
		elif event.keycode == KEY_E:
			lean_target_state = 1 if lean_target_state != 1 else 0
		
		# 换弹快捷键
		elif event.keycode == KEY_R:
			if not is_reloading:
				reload()
		
		# 姿态切换
		elif event.keycode == KEY_C:
			if current_stance == Stance.CROUCHING:
				target_stance = Stance.STANDING
			else:
				target_stance = Stance.CROUCHING
		elif event.keycode == KEY_V:
			if current_stance == Stance.PRONE:
				target_stance = Stance.STANDING
			else:
				target_stance = Stance.PRONE
	
	# 右键瞄准逻辑 (修复被删掉的部分)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			# 只有在没撞墙的情况下按右键才立刻开镜
			if not wall_detector.is_colliding():
				toggle_camera(true)
		else:
			toggle_camera(false)

func _physics_process(delta: float) -> void:
	handle_ads_animation(delta)
	handle_leaning(delta)
	handle_weapon_avoidance(delta)
	handle_stance(delta) # 先算姿态和高度
	handle_weapon_switching(delta)
	handle_shooting(delta) # 后算射击，保证位置准确
	handle_recoil_physics(delta)
	
	# 移动逻辑保持不变
	handle_movement(delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Fall Reset
	if global_position.y < -30.0:
		die()
		
	move_and_slide()

## --- 避墙逻辑实现（含自动恢复开镜） ---
func handle_weapon_avoidance(delta: float):
	if not wall_detector or not weapon_holder: return

	if wall_detector.is_colliding():
		var collision_normal = wall_detector.get_collision_normal()
		var is_floor = collision_normal.y > 0.7
		
		# 非趴姿忽略地面
		if is_floor and current_stance != Stance.PRONE:
			# 恢复正常姿态
			var side_shift = lerp(0.0, -ads_camera_pos.x * 2.0, hand_side_weight)
			var current_base_pos = weapon_normal_pos + Vector3(side_shift, -switch_weight * 0.5, 0)
			
			weapon_holder.rotation.x = lerp_angle(weapon_holder.rotation.x, weapon_normal_rot.x, wall_avoid_speed * delta)
			weapon_holder.position = weapon_holder.position.lerp(current_base_pos, wall_avoid_speed * delta)
			return

		# 1. 触发避让：如果是开镜状态，强制收回
		if is_ads:
			toggle_camera(false)
		
		var target_rot_x : float
		var target_pos : Vector3
		var side_shift = lerp(0.0, -ads_camera_pos.x * 2.0, hand_side_weight)
		var current_base_pos = weapon_normal_pos + Vector3(side_shift, 0, 0)
		
		if is_floor and current_stance == Stance.PRONE:
			# 趴下撞地：枪支停在地面，不再跟随视角下移（抵消头部下移角度）
			target_rot_x = -head.rotation.x 
			# 稍微上升并后移，模仿枪支“架”在地面上的感觉，防止弹匣深入地下
			target_pos = current_base_pos + Vector3(0, 0.15, 0.1) 
		else:
			# 正常撞墙：muzzle up + sinking
			target_rot_x = weapon_normal_rot.x - deg_to_rad(weapon_down_angle)
			var x_offset = lerp(0.05, -0.05, hand_side_weight)
			target_pos = current_base_pos + Vector3(x_offset, -0.3 - (switch_weight * 0.5), weapon_back_offset * 1.2)
		
		weapon_holder.rotation.x = lerp_angle(weapon_holder.rotation.x, target_rot_x, wall_avoid_speed * delta)
		weapon_holder.position = weapon_holder.position.lerp(target_pos, wall_avoid_speed * delta)
	else:
		# 2. 离开墙壁：回到正常姿态
		# 计算基础侧向偏移（切手逻辑）
		var side_shift = lerp(0.0, -ads_camera_pos.x * 2.0, hand_side_weight)
		var current_base_pos = weapon_normal_pos + Vector3(side_shift, -switch_weight * 0.5, 0)
		
		weapon_holder.rotation.x = lerp_angle(weapon_holder.rotation.x, weapon_normal_rot.x, wall_avoid_speed * delta)
		weapon_holder.position = weapon_holder.position.lerp(current_base_pos, wall_avoid_speed * delta)
		
		# 【关键改动】：如果玩家一直按着右键，且当前不是开镜状态，且枪已经快抬起来了，就自动恢复开镜
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not is_ads:
			# 检查枪管是否已经基本抬起（避免视角瞬间切换太突兀）
			if abs(weapon_holder.rotation.x - weapon_normal_rot.x) < 0.1:
				toggle_camera(true)

func rotate_look(rot_input : Vector2):
	var current_look_speed = ads_look_speed if is_ads else look_speed
	look_rotation.x -= rot_input.y * current_look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * current_look_speed
	
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)

func toggle_camera(should_ads: bool):
	is_ads = should_ads

func handle_ads_animation(delta: float):
	# 计算权重
	var target_weight = 1.0 if is_ads else 0.0
	ads_weight = lerp(ads_weight, target_weight, ads_lerp_speed * delta)
	
	# FOV 缩放
	main_camera.fov = lerp(default_fov, target_ads_fov, ads_weight)
	
	# 获取当前的瞄准目标点（已考虑姿态偏移和倾斜）
	var target_pos = ads_camera.position
	var target_rot_z = ads_camera.rotation.z
	
	# 插值位置和 Z 轴旋转 (开镜倾斜)
	main_camera.position = main_camera.position.lerp(target_pos * ads_weight, ads_lerp_speed * delta)
	main_camera.rotation.z = lerp(main_camera.rotation.z, target_rot_z * ads_weight, ads_lerp_speed * delta)

func handle_leaning(delta: float):
	# 疾跑或趴下时打断探头
	if can_sprint and Input.is_action_pressed("sprint"):
		lean_target_state = 0
	if current_stance == Stance.PRONE:
		lean_target_state = 0
	
	var target_lean = float(lean_target_state)
	var target_hand_side = 1.0 if lean_target_state == 1 else 0.0
	
	lean_weight = lerp(lean_weight, target_lean, lean_speed * delta)
	hand_side_weight = lerp(hand_side_weight, target_hand_side, lean_speed * delta)
	
	# 应用位移和旋转到头部
	# Z 轴旋转 (探头角度)
	head.rotation.z = -lean_weight * deg_to_rad(lean_angle)
	
	# X 轴位移 (探头位移) + Y 轴微调 (保持真实感)
	var lean_pos_offset = Vector3(lean_weight * lean_offset, -abs(lean_weight) * 0.1, 0)
	head.position = head_base_pos + lean_pos_offset

func handle_stance(delta: float):
	# 疾跑时如果正在趴着，强制站立；蹲着时允许疾跑
	if can_sprint and Input.is_action_pressed("sprint") and current_stance == Stance.PRONE:
		target_stance = Stance.STANDING
	
	# 平滑过渡姿态
	if current_stance != target_stance:
		current_stance = target_stance
	
	# 根据姿态设置目标高度
	var target_height : float
	match current_stance:
		Stance.STANDING:
			target_height = standing_height
		Stance.CROUCHING:
			target_height = crouching_height
		Stance.PRONE:
			target_height = prone_height
		_:
			target_height = standing_height
	
	# 平滑调整高度
	stance_height = lerp(stance_height, target_height, stance_transition_speed * delta)
	
	# 更新碰撞体高度
	if collision_shape and collision_shape.shape:
		collision_shape.shape.height = stance_height
		collision_shape.position.y = stance_height / 2.0
	
	# 更新视觉模型高度
	if character_mesh and character_mesh.mesh is CapsuleMesh:
		character_mesh.mesh.height = stance_height
		character_mesh.position.y = stance_height / 2.0
	
	# 更新相机高度 (相对于脚底，即 y=0)
	# 假设眼睛高度在头顶下方 0.1m
	var eye_height = stance_height - 0.1
	head.position.y = eye_height
	
	# 趴下时提升武器高度并微斜防止穿模
	var weapon_pos_correction = 0.0
	var weapon_rot_correction = 0.0
	if current_stance == Stance.PRONE:
		weapon_pos_correction = 0.22 # 稍微再抬高一点
		weapon_rot_correction = deg_to_rad(-30) # 倾斜角度增加，更好地避开长弹匣
	elif current_stance == Stance.CROUCHING:
		weapon_pos_correction = 0.05 # 蹲姿微调
	
	# 应用到武器挂载点
	weapon_holder.position.y = weapon_normal_pos.y + weapon_pos_correction
	weapon_holder.rotation.z = weapon_normal_rot.z + weapon_rot_correction
	
	# 重要：同步瞄准相机，保证瞄准线不乱
	if ads_camera:
		# 1. 计算基础位置（考虑左右手镜像）
		var ads_offset = ads_camera_pos
		ads_offset.x = lerp(ads_camera_pos.x, -ads_camera_pos.x, hand_side_weight)
		
		# 2. 绕 Z 轴旋转该位置，以匹配武器的倾斜 arc
		# Vector3.BACK 是 (0,0,1)，绕 +Z 轴旋转
		var rotated_offset = ads_offset.rotated(Vector3.BACK, weapon_rot_correction)
		
		# 3. 应用高度补偿和旋转
		ads_camera.position = rotated_offset + Vector3(0, weapon_pos_correction, 0)
		ads_camera.rotation.z = weapon_rot_correction
		
		# 实时更新开镜目标点，防止姿态切换时瞄准跳变
		current_ads_pos = ads_camera.position
		
		# 重要：同步避墙检测点 X 轴，防止探头时枪身由于检测点没跟过去而穿墙
		if wall_detector:
			wall_detector.position.x = ads_camera.position.x

func handle_shooting(delta: float):
	if fire_cooldown > 0:
		fire_cooldown -= delta
	
	var is_trigger_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	# 重置半自动触发和连发标志
	if not is_trigger_pressed:
		has_fired_this_click = false
		is_first_shot_in_burst = true
		return
		
	# 正在切枪、撞墙或换弹中不可开火
	if is_switching or wall_detector.is_colliding() or is_reloading:
		return
	
	# 检查弹药
	var current_mags = primary_magazines if current_weapon_index == 1 else secondary_magazines
	var current_mag_idx = primary_current_mag_index if current_weapon_index == 1 else secondary_current_mag_index
	if current_mags[current_mag_idx] <= 0:
		# 播放空枪点击声
		if not has_fired_this_click and dry_fire_sound_player and dry_fire_sound:
			dry_fire_sound_player.stream = dry_fire_sound
			dry_fire_sound_player.play()
			has_fired_this_click = true
		return
	
	# 射击逻辑区分
	if current_weapon_index == 1: # 步枪：全自动
		if fire_cooldown <= 0:
			fire()
	else: # 手枪：半自动
		if not has_fired_this_click and fire_cooldown <= 0:
			fire()
			has_fired_this_click = true

func fire():
	var fire_rate = primary_fire_rate if current_weapon_index == 1 else secondary_fire_rate
	fire_cooldown = fire_rate
	
	# 0. 计算散布 (Spread)
	var spread = primary_hip_spread if current_weapon_index == 1 else secondary_hip_spread
	# 散布随瞄准权重减小
	var current_spread = lerp(spread, 0.0, ads_weight)
	
	# 应用散布到 AimRay 的角度
	var spread_h = randf_range(-current_spread, current_spread)
	var spread_v = randf_range(-current_spread, current_spread)
	
	# --- 视差修正逻辑 (Parallax Correction) ---
	# 1. 首先从相机中心点发射一条虚拟射线，确定玩家究竟在看哪里（目标点）
	var camera_aim_dist = 100.0
	var aim_target_point = main_camera.global_position - main_camera.global_transform.basis.z * camera_aim_dist
	
	# 创建一个临时射线检测
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(main_camera.global_position, aim_target_point)
	query.exclude = [self] # 排除玩家自己
	query.collision_mask = 7 # 检测所有层
	var result = space_state.intersect_ray(query)
	
	# 重要：只接受敌人或 Hitbox 作为目标点，不接受地图
	if result:
		var collider = result.collider
		# 如果击中敌人或 Hitbox，使用该点
		if collider is Area3D or (collider is CharacterBody3D and collider.has_method("hit")):
			aim_target_point = result.position
		# 否则，继续使用原始的目标点（不修改）
	
	# 2. 将实际射击射线起点移动到枪口，并使其"看向"目标点
	var muzzle = primary_muzzle if current_weapon_index == 1 else secondary_muzzle
	if muzzle:
		aim_ray.global_position = muzzle.global_position
		# 使 AimRay 指向目标点 (-Z 轴指向目标)
		aim_ray.look_at(aim_target_point, Vector3.UP)
		
		# 3. 视差修正：由于 AimRay 默认投射轴是 -Y，我们要把它旋转 90 度对齐到 -Z
		aim_ray.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
		
		# 4. 在此基础上叠加随机散布
		aim_ray.rotate_object_local(Vector3.RIGHT, deg_to_rad(spread_v))
		aim_ray.rotate_object_local(Vector3.UP, deg_to_rad(-spread_h))
	
	aim_ray.force_raycast_update()
	
	# 调试：打印 AimRay 是否检测到东西
	if aim_ray.is_colliding():
		print("AimRay hit: ", aim_ray.get_collider().name, " at ", aim_ray.get_collision_point())
	else:
		print("AimRay hit nothing")
	
	# --------------------------
	# 使用 direct_space_state 做精确的双重检测
	# --------------------------
	# 直接使用从枪口到目标的方向，而不是依赖 aim_ray 的旋转（muzzle 已在上面声明）
	var from = muzzle.global_position if muzzle else aim_ray.global_position
	var shoot_dir = (aim_target_point - from).normalized()
	var to = from + shoot_dir * 100.0
	
	# 调试：打印射线方向
	print("Shoot from: ", from, " direction: ", shoot_dir, " to: ", to)
	print("aim_target_point: ", aim_target_point)
	
	var is_headshot = false
	var final_hit_collider = null
	var final_hit_point = Vector3.ZERO
	var final_hit_normal = Vector3.ZERO
	var hit_something = false
	
	# 第一次检测：检测所有层（包括 Hitbox 和物理碰撞体）
	var query_all = PhysicsRayQueryParameters3D.create(from, to)
	query_all.exclude = [self]
	query_all.collision_mask = 7  # layer 1+2+4
	query_all.collide_with_areas = true
	query_all.collide_with_bodies = true
	var result_all = space_state.intersect_ray(query_all)
	
	print("All result: ", result_all)
	if result_all:
		print("All collider: ", result_all.collider, " name: ", result_all.collider.name)
	
	# 判断命中的是什么
	if result_all:
		var hit_collider = result_all.collider
		final_hit_point = result_all.position
		final_hit_normal = result_all.normal
		
		# 检查是否是 Hitbox（Area3D）
		if hit_collider is Area3D:
			# 命中了 Hitbox！
			hit_something = true
			final_hit_collider = hit_collider
			
			# 检测是否是头部 Hitbox
			var check_node = final_hit_collider
			while check_node:
				if "Head" in check_node.name or "head" in check_node.name:
					is_headshot = true
					break
				check_node = check_node.get_parent()
			
			# 造成伤害
			if final_hit_collider.has_method("hit"):
				var dmg = 35.0 if current_weapon_index == 1 else 20.0
				final_hit_collider.hit(dmg, is_headshot)
				print("Hit Hitbox: ", final_hit_collider.name, " is_headshot: ", is_headshot)
		else:
			# 命中了物理碰撞体（敌人身体或地图）
			# 检查这个碰撞体是否属于敌人
			if hit_collider.has_method("hit"):
				# 是敌人！造成身体伤害
				hit_something = true
				final_hit_collider = hit_collider
				hit_collider.hit(35.0 if current_weapon_index == 1 else 20.0, false)
				print("Hit Enemy Body: ", hit_collider.name)
			else:
				# 是地图或其他环境
				print("Hit Environment: ", hit_collider.name)
	
	# --------------------------
	
	# 播放枪声（区分单发/连发）
	if gunfire_sound:
		var sound_to_play : AudioStream
		if current_weapon_index == 1:
			# 主武器：根据是否首发选择音效
			sound_to_play = primary_single_fire_sound if is_first_shot_in_burst else primary_auto_fire_sound
			if sound_to_play == null:  # 如果没设置连发音效，回退到单发
				sound_to_play = primary_single_fire_sound if primary_single_fire_sound else primary_auto_fire_sound
		else:
			# 副武器：使用通用音效
			sound_to_play = secondary_fire_sound
		
		if sound_to_play:
			# 只在音效改变时才设置 stream，避免打断正在播放的音效
			if gunfire_sound.stream != sound_to_play:
				gunfire_sound.stream = sound_to_play
			gunfire_sound.pitch_scale = randf_range(0.95, 1.05)
			gunfire_sound.play()
		
		# 发射声音信号，让 AI 能听到枪声
		emit_signal("player_made_sound", global_position, "gunshot", 1.0)
	
	# 标记不再是首发
	is_first_shot_in_burst = false
	
	# 调试输出
	if is_headshot:
		print("HEADSHOT! Enemy should die instantly!")
	
	# 播放击中音效
	if hit_something and impact_sound_player and impact_sound:
		impact_sound_player.global_position = final_hit_point
		if impact_sound_player.stream != impact_sound:
			impact_sound_player.stream = impact_sound
		impact_sound_player.pitch_scale = randf_range(0.9, 1.1)
		impact_sound_player.play()
	
	# 2. 应用程序化后坐力 (Recoil)
	var strength = primary_recoil_strength if current_weapon_index == 1 else secondary_recoil_strength
	# 随机水平/垂直后坐力，垂直力加强
	var recoil_h = randf_range(-strength * 0.3, strength * 0.3)
	var recoil_v = strength * randf_range(0.8, 1.2)
	
	recoil_pivot += Vector3(recoil_v, recoil_h, 0)
	
	# 3. 产生抛壳
	spawn_shell()
	
	# 4. 枪口闪光
	show_flash()
	
	# 5. 消耗弹药
	if current_weapon_index == 1:
		primary_magazines[primary_current_mag_index] -= 1
	else:
		secondary_magazines[secondary_current_mag_index] -= 1
	
	update_ammo_display()

func show_flash():
	var flash = primary_flash if current_weapon_index == 1 else secondary_flash
	flash.visible = true
	await get_tree().create_timer(0.05).timeout
	flash.visible = false

func reload():
	if is_reloading:
		return
	
	var mags = primary_magazines if current_weapon_index == 1 else secondary_magazines
	var current_idx = primary_current_mag_index if current_weapon_index == 1 else secondary_current_mag_index
	
	# 收集所有非空的备用弹匣索引
	var available_mags : Array[int] = []
	for i in range(mags.size()):
		if i != current_idx and mags[i] > 0:
			available_mags.append(i)
	
	# 没有可用弹匣
	if available_mags.is_empty():
		return
	
	# 播放换弹音效
	if reload_sound_player and reload_sound:
		reload_sound_player.stream = reload_sound
		reload_sound_player.play()
	
	# 发射换弹声音信号，让 AI 能听到
	emit_signal("player_made_sound", global_position, "reload", 0.8)
	
	# 随机选择一个弹匣
	var next_mag_idx = available_mags[randi() % available_mags.size()]
	
	is_reloading = true
	
	var reload_time = primary_reload_time if current_weapon_index == 1 else secondary_reload_time
	await get_tree().create_timer(reload_time).timeout
	
	# 切换到新弹匣
	if current_weapon_index == 1:
		primary_current_mag_index = next_mag_idx
	else:
		secondary_current_mag_index = next_mag_idx
	
	is_reloading = false
	
	update_ammo_display()

func update_ammo_display():
	if not ammo_hud:
		return
	
	var mags = primary_magazines if current_weapon_index == 1 else secondary_magazines
	var current_idx = primary_current_mag_index if current_weapon_index == 1 else secondary_current_mag_index
	var mag_capacity = primary_mag_capacity if current_weapon_index == 1 else secondary_mag_capacity
	
	var container = ammo_hud.get_node("AmmoContainer/VBoxContainer/MagazineContainer")
	
	# 清除旧的弹匣图标
	for child in container.get_children():
		child.queue_free()
	
	# 遍历所有弹匣，创建图标
	for i in range(mags.size()):
		var fill_percent = float(mags[i]) / float(mag_capacity)
		var is_current = (i == current_idx)
		var mag_icon = create_magazine_icon(fill_percent, is_current)
		container.add_child(mag_icon)

func create_magazine_icon(fill_percent: float, is_current: bool) -> Control:
	var mag = ColorRect.new()
	mag.custom_minimum_size = Vector2(12, 40)
	
	# 量化填充百分比到几个档位（更真实的战场感知）
	var display_fill : float
	if fill_percent > 0.85:
		display_fill = 1.0  # 满
	elif fill_percent > 0.6:
		display_fill = 0.75 # 大半
	elif fill_percent > 0.35:
		display_fill = 0.5  # 一半
	elif fill_percent > 0.1:
		display_fill = 0.25 # 少量
	else:
		display_fill = 0.0  # 空
	
	# 根据填充百分比和是否为当前弹匣设置颜色
	if is_current:
		if display_fill >= 0.75:
			mag.color = Color(0.2, 1.0, 0.3, 1) # 绿色 - 当前弹匣充足
		elif display_fill >= 0.35:
			mag.color = Color(1.0, 0.8, 0.2, 1) # 黄色 - 当前弹匣中等
		else:
			mag.color = Color(1.0, 0.3, 0.2, 1) # 红色 - 当前弹匣不足
	else:
		if fill_percent >= 1.0:
			mag.color = Color(0.7, 0.7, 0.7, 0.8) # 灰白色 - 满弹匣
		else:
			mag.color = Color(0.5, 0.5, 0.5, 0.6) # 深灰色 - 部分弹匣
	
	# 添加边框
	var border = ColorRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.color = Color(0.2, 0.2, 0.2, 1)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mag.add_child(border)
	
	# 填充指示器（使用量化后的值）
	if display_fill > 0:
		var fill = ColorRect.new()
		fill.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		fill.anchor_top = 1.0 - display_fill
		fill.offset_top = 2
		fill.offset_bottom = -2
		fill.offset_left = 2
		fill.offset_right = -2
		fill.color = mag.color
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border.add_child(fill)
	
	return mag

func spawn_shell():
	if not shell_scene: return
	
	# 播放抛壳音效
	if shell_eject_sound_player and shell_eject_sound:
		shell_eject_sound_player.stream = shell_eject_sound
		shell_eject_sound_player.pitch_scale = randf_range(0.9, 1.1)
		shell_eject_sound_player.play()
	
	var eject_marker = primary_eject if current_weapon_index == 1 else secondary_eject
	var shell = shell_scene.instantiate()
	get_tree().root.add_child(shell)
	
	shell.global_transform = eject_marker.global_transform
	# 向侧后上方弹射 (修正力度和方向)
	# 此时 eject_marker 随着枪旋转，所以侧向应该是 global_transform.basis.y? 不，
	# 我们的模型是 X-forward (MCX) 或 -Z-forward (Glock)
	# 这里的 eject_marker.global_transform.basis.x 是 MCX 的前方，所以 y 是上方，z 是侧方
	var right_dir = eject_marker.global_transform.basis.z 
	var up_dir = eject_marker.global_transform.basis.y
	var back_dir = -eject_marker.global_transform.basis.x if current_weapon_index == 1 else eject_marker.global_transform.basis.z
	
	if current_weapon_index == 2: # Glock 是 180度反的
		right_dir = -eject_marker.global_transform.basis.x
		up_dir = eject_marker.global_transform.basis.y
		back_dir = eject_marker.global_transform.basis.z

	var impulse = right_dir * randf_range(1.5, 2.5) + up_dir * randf_range(0.5, 1.5) + back_dir * randf_range(0.5, 1.0)
	shell.apply_impulse(impulse)
	shell.apply_torque_impulse(Vector3(randf(), randf(), randf()) * 0.1)


func handle_recoil_physics(delta: float):
	# 后坐力回复
	recoil_pivot = recoil_pivot.lerp(Vector3.ZERO, recoil_recovery_speed * delta)
	current_recoil = current_recoil.lerp(recoil_pivot, recoil_snap_speed * delta)
	
	# 应用到相机旋转 (累加到 look_rotation)
	# 开镜时后坐力表现更明显/稳定
	main_camera.rotation.x = deg_to_rad(current_recoil.x)
	main_camera.rotation.z = deg_to_rad(current_recoil.y) # 轻微侧偏

	
	# 武器视觉后退 (Kickback)
	var kickback_amount = current_recoil.x * 0.05
	weapon_holder.position.z = lerp(weapon_holder.position.z, weapon_normal_pos.z + kickback_amount, recoil_snap_speed * delta)

func start_weapon_switch(index: int):
	is_switching = true
	if is_ads: toggle_camera(false) # 切枪时强制关镜
	
	# 切枪打断换弹
	if is_reloading:
		is_reloading = false
		if reload_sound_player:
			reload_sound_player.stop()
		if ammo_hud:
			var label = ammo_hud.get_node_or_null("AmmoContainer/ReloadLabel")
			if label: label.visible = false
	
	next_weapon_index = index

func handle_weapon_switching(delta: float):
	if not is_switching:
		switch_weight = move_toward(switch_weight, 0.0, delta * 4.0)
		return
	
	# 下沉动画
	switch_weight = move_toward(switch_weight, 1.0, delta * 4.0)
	
	if switch_weight >= 1.0:
		# 交换武器
		for i in range(len(weapon_list)):
			weapon_list[i].visible = (i + 1 == next_weapon_index)
		
		current_weapon_index = next_weapon_index
		
		# 更新 ADS 参数
		if current_weapon_index == 1:
			ads_camera_pos = primary_ads_pos
			target_ads_fov = primary_ads_fov
			if wall_detector: wall_detector.target_position.y = -primary_wall_dist
		else:
			ads_camera_pos = secondary_ads_pos
			target_ads_fov = secondary_ads_fov
			if wall_detector: wall_detector.target_position.y = -secondary_wall_dist
			
		is_switching = false # 切换完成，开始升起
		update_ammo_display() # 更新弹药显示

func handle_movement(delta):
	# 计算基础速度（考虑疾跑和姿态）
	var stance_mult : float = 1.0
	match current_stance:
		Stance.CROUCHING:
			stance_mult = crouch_speed_mult
		Stance.PRONE:
			stance_mult = prone_speed_mult
	
	var move_speed = base_speed * stance_mult
	
	# 站立或蹲下时可以疾跑
	if can_sprint and Input.is_action_pressed("sprint") and current_stance != Stance.PRONE:
		var sprint_mult = 1.0 if current_stance == Stance.STANDING else crouch_sprint_mult
		move_speed = sprint_speed * sprint_mult
	
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
	
	# 计算水平速度用于脚步音效
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	
	if horizontal_speed > 0.1 and is_on_floor():
		footstep_timer -= delta
		if footstep_timer <= 0:
			# 播放脚步声
			if footstep_sound_player and footstep_sound:
				footstep_sound_player.stream = footstep_sound
				footstep_sound_player.pitch_scale = randf_range(0.9, 1.1)
				footstep_sound_player.play()
			
			# 发射脚步声音信号，让 AI 能听到
			emit_signal("player_made_sound", global_position, "footstep", 0.5)
			
			# 根据移动速度调整脚步间隔，跑得越快音效越密集
			var speed_factor = horizontal_speed / sprint_speed
			footstep_interval = lerp(0.5, 0.3, speed_factor)
			footstep_timer = footstep_interval
	else:
		# 不在移动时重置计时器
		footstep_timer = 0.3
	
	if can_jump and is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_velocity
		target_stance = Stance.STANDING # 跳跃打断蹲趴
		lean_target_state = 0 # 跳跃打断探头

func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

func check_input_mappings():
	var actions = ["ui_left", "ui_right", "ui_up", "ui_down"]
	for action in actions:
		if not InputMap.has_action(action):
			push_warning("未找到输入映射: " + action)

func hit(damage : float, is_headshot : bool = false):
	# 爆头直接秒杀
	if is_headshot:
		current_health = 0
		print("Player HEADSHOT! Instant death.")
	else:
		current_health -= damage
		print("Player HIT! Damage: ", damage, " Health: ", current_health)
	
	# 播放受击音效
	if impact_sound_player and impact_sound:
		impact_sound_player.stream = impact_sound
		impact_sound_player.pitch_scale = randf_range(0.8, 1.2)
		impact_sound_player.play()
	
	if current_health <= 0:
		die()

func die():
	print("Player DIED!")
	# Simple restart or game over logic
	get_tree().reload_current_scene()
