extends CharacterBody3D

class_name SimpleEnemy

# ============ 基础配置 ============
@export_group("基础属性")
@export var max_health : float = 100.0
@export var move_speed : float = 5.0

@export_group("战斗属性")
@export var attack_range : float = 20.0
@export var sight_range : float = 60.0
@export var vision_fov : float = 90.0
@export var fire_rate : float = 0.1
@export var damage_body : float = 35.0
@export var damage_head : float = 100.0
@export var headshot_chance : float = 0.15  # 15%概率爆头

@export_group("精度设置")
@export var accuracy : float = 0.02  # 越小越准

@export_group("战术设置")
@export var role : EnemyRole = EnemyRole.ASSAULT  # 角色类型
@export var flank_distance : float = 15.0  # 包抄距离

@export_group("感知设置")
@export var hearing_range : float = 30.0  # 听力范围（米）
@export var footstep_sensitivity : float = 1.0  # 脚步声敏感度

# ============ 节点引用 ============
@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D
@onready var head : Node3D = $Head
@onready var weapon_pivot : Node3D = $Head/WeaponPivot
@onready var raycast : RayCast3D = $Head/WeaponPivot/AimRay
@onready var shoot_sound : AudioStreamPlayer3D = $ShootSound

# ============ 状态枚举 ============
enum State { IDLE, CHASE, ATTACK, FLANK }
enum EnemyRole { ASSAULT, FLANKER, SNIPER }  # 突击手、侧翼手、狙击手

# ============ 运行时变量 ============
var current_state : State = State.IDLE
var current_health : float
var target : Node3D = null
var fire_cooldown : float = 0.0
var last_seen_pos : Vector3 = Vector3.ZERO
var alerted : bool = false

# 战术配合变量
var flank_angle : float = 0.0  # 包抄角度
var is_suppressing : bool = false  # 是否在压制射击
var teammate_spotted : bool = false  # 队友是否发现了敌人

# 声音感知变量
var last_heard_pos : Vector3 = Vector3.ZERO  # 最后听到声音的位置
var sound_alert_level : float = 0.0  # 声音警戒级别 (0-1)

# 重力
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ============ 初始化 ============
func _ready():
	current_health = max_health
	
	# 寻找玩家
	target = get_tree().get_first_node_in_group("player")
	
	# 配置导航
	setup_navigation()
	
	# 配置射线
	setup_raycast()
	
	# 配置音效
	setup_sound()
	
	# 添加到敌人组
	add_to_group("enemies")
	
	# 侧翼手随机分配包抄角度
	if role == EnemyRole.FLANKER:
		flank_angle = randf_range(60, 120) * (1 if randf() > 0.5 else -1)
	
	# 连接玩家声音信号
	await get_tree().process_frame  # 等待玩家初始化
	if get_tree().root.has_signal("player_made_sound"):
		get_tree().root.connect("player_made_sound", _on_player_sound)
	
	print("敌人初始化完成: ", name, " 角色: ", get_role_name())

func setup_navigation():
	if nav_agent:
		nav_agent.path_desired_distance = 1.0
		nav_agent.target_desired_distance = 1.0

func setup_raycast():
	if raycast:
		raycast.add_exception(self)
		raycast.target_position = Vector3(0, 0, -100)

func setup_sound():
	if shoot_sound and not shoot_sound.stream:
		shoot_sound.stream = load("res://sounds/ttig34.mp3")

# ============ 主循环 ============
func _physics_process(delta):
	# 死亡检查
	if current_health <= 0 or not is_inside_tree():
		return
	
	# 重力
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# 视觉检测
	var can_see_player = check_player_visibility()
	
	# 状态机
	match current_state:
		State.IDLE:
			process_idle(delta, can_see_player)
		State.CHASE:
			process_chase(delta, can_see_player)
		State.ATTACK:
			process_attack(delta, can_see_player)
		State.FLANK:
			process_flank(delta, can_see_player)
	
	# 射击冷却
	if fire_cooldown > 0:
		fire_cooldown -= delta
	
	# 声音警戒衰减
	if sound_alert_level > 0:
		sound_alert_level = max(0, sound_alert_level - delta * 0.1)
	
	# 移动
	move_and_slide()

# ============ 视觉检测系统 ============
func check_player_visibility() -> bool:
	# 空值检查
	if not target or not is_inside_tree():
		return false
	if not target.is_inside_tree():
		return false
	
	# 距离检查
	var dist = global_position.distance_to(target.global_position)
	if dist > sight_range:
		return false
	
	# FOV检查（已警觉时视野扩大到360度，靠听觉和感知）
	var to_target = (target.global_position - global_position).normalized()
	var forward = -global_transform.basis.z
	var angle = rad_to_deg(forward.angle_to(to_target))
	
	# 受惊觉状态下大幅扩大视野（270度）
	var effective_fov = 270.0 if alerted else vision_fov
	if angle > effective_fov / 2.0:
		return false
	
	# 射线检测（检查墙壁遮挡）
	if not has_line_of_sight_to_target():
		return false
	
	# 更新最后看到的位置
	last_seen_pos = target.global_position
	
	# 发现玩家，设置警觉
	if not alerted:
		alerted = true
		print(name, ": 发现玩家！")
		# 通知队友
		alert_teammates()
	
	return true

func has_line_of_sight_to_target() -> bool:
	if not target or not is_inside_tree():
		return false
	
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return false
	
	# 多点检测：头部、身体、武器位置（解决探头问题）
	var check_points = [
		get_target_head_position(),                          # 头部
		target.global_position + Vector3(0, 1.0, 0),        # 身体中心
		target.global_position + Vector3(0, 0.5, 0),        # 腰部
	]
	
	# 检测玩家可能的武器/探头位置
	var weapon_positions = get_target_weapon_positions()
	for wp in weapon_positions:
		check_points.append(wp)
	
	for point in check_points:
		var query = PhysicsRayQueryParameters3D.create(
			head.global_position,
			point
		)
		query.exclude = [self]
		query.collision_mask = 1  # 只检测静态物体
		
		var result = space_state.intersect_ray(query)
		
		# 没有碰撞，或者碰撞到玩家，都算可见
		if not result:
			return true
		if is_part_of_target(result.collider):
			return true
	
	return false

# 获取玩家可能的武器/探头位置
func get_target_weapon_positions() -> Array:
	var positions = []
	if not target:
		return positions
	
	var base = target.global_position
	
	# 常见探头位置（左右探头时枪口位置）
	positions.append(base + Vector3(0.5, 1.2, 0.3))    # 右探头
	positions.append(base + Vector3(-0.5, 1.2, 0.3))   # 左探头
	positions.append(base + Vector3(0.4, 1.0, 0.5))    # 低姿右探
	positions.append(base + Vector3(-0.4, 1.0, 0.5))   # 低姿左探
	
	return positions

func get_target_head_position() -> Vector3:
	if not target:
		return global_position
	
	# 获取目标高度
	var target_height = 1.3
	if "current_height" in target:
		target_height = target.current_height
	elif "stance_height" in target:
		target_height = target.stance_height
	
	# 头部位置（头顶下方0.15米）
	return target.global_position + Vector3(0, target_height - 0.15, 0)

func is_part_of_target(collider: Node) -> bool:
	if not collider:
		return false
	
	# 直接匹配
	if collider == target:
		return true
	
	# 向上查找父节点
	var node = collider
	while node:
		if node == target:
			return true
		node = node.get_parent()
	
	return false

# ============ 状态处理 ============
func process_idle(delta: float, can_see: bool):
	# 发现玩家，切换到追击
	if can_see and target:
		change_state(State.CHASE)
		print(name, ": 开始追击玩家！")
	# 被惊动后朝最后位置移动
	elif alerted and last_seen_pos != Vector3.ZERO:
		var dist_to_last = global_position.distance_to(last_seen_pos)
		if dist_to_last > 2.0:
			nav_agent.target_position = last_seen_pos
			move_towards_target(delta)
			look_at_target(last_seen_pos, delta)
		else:
			alerted = false
			last_seen_pos = Vector3.ZERO

func process_chase(delta: float, can_see: bool):
	if not target:
		change_state(State.IDLE)
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	# 进入攻击范围，切换到攻击
	if dist <= attack_range and can_see:
		change_state(State.ATTACK)
		return
	
	# 失去视野
	if not can_see:
		# 使用最后已知位置继续移动
		if last_seen_pos != Vector3.ZERO:
			var dist_to_last = global_position.distance_to(last_seen_pos)
			if dist_to_last < 2.0:
				# 到达最后位置，返回待机
				change_state(State.IDLE)
				last_seen_pos = Vector3.ZERO
			else:
				# 移动到上次看到的位置
				nav_agent.target_position = last_seen_pos
				move_towards_target(delta)
				look_at_target(last_seen_pos, delta)
		return
	
	# 设置导航目标为玩家位置
	nav_agent.target_position = target.global_position
	
	# 移动
	move_towards_target(delta)
	
	# 朝向玩家
	look_at_target(target.global_position, delta)

func process_attack(delta: float, can_see: bool):
	if not target:
		change_state(State.IDLE)
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	# 玩家太远，切换到追击
	if dist > attack_range * 1.5:
		change_state(State.CHASE)
		return
	
	# 失去视野，切换到追击
	if not can_see:
		change_state(State.CHASE)
		return
	
	# 朝向玩家（使用预测）
	var predicted_pos = predict_target_position()
	look_at_target(predicted_pos, delta)
	
	# 根据角色执行不同战术
	match role:
		EnemyRole.FLANKER:
			# 侧翼手：队友压制时尝试包抄
			if has_teammate_suppressing() and dist > 10.0:
				change_state(State.FLANK)
				return
			perform_combat_movement(delta)
		EnemyRole.SNIPER:
			# 狙击手：保持距离，精准射击
			if dist < 15.0:
				# 太近了，后退
				var retreat_dir = -global_transform.basis.z
				velocity.x = move_toward(velocity.x, retreat_dir.x * move_speed, 15.0 * delta)
				velocity.z = move_toward(velocity.z, retreat_dir.z * move_speed, 15.0 * delta)
			is_suppressing = false
		_:
			# 突击手：压制射击，为队友创造机会
			is_suppressing = true
			perform_combat_movement(delta)
	
	# 射击
	if fire_cooldown <= 0:
		shoot()
	
	# 射击
	if fire_cooldown <= 0:
		shoot()

# 攻击时的移动（侧移/调整距离）
var strafe_dir : float = 1.0
var strafe_timer : float = 0.0

func perform_combat_movement(delta: float):
	if not target:
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	# 定期改变侧移方向
	strafe_timer -= delta
	if strafe_timer <= 0:
		strafe_timer = randf_range(1.0, 3.0)
		strafe_dir = 1.0 if randf() > 0.5 else -1.0
	
	# 计算移动方向
	var move_dir = Vector3.ZERO
	
	# 侧移
	move_dir += global_transform.basis.x * strafe_dir
	
	# 保持合适距离
	if dist < attack_range * 0.5:
		# 太近了，后退
		move_dir -= global_transform.basis.z * 0.5
	elif dist > attack_range * 0.9:
		# 太远了，前进
		move_dir += global_transform.basis.z * 0.3
	
	# 添加分散力
	var separation = get_separation_force()
	move_dir += separation * separation_force * 0.5
	
	# 应用移动
	if move_dir.length() > 0:
		move_dir = move_dir.normalized()
		velocity.x = move_toward(velocity.x, move_dir.x * move_speed * 0.5, 15.0 * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * move_speed * 0.5, 15.0 * delta)

# ============ 移动系统 ============
# 分散设置
@export var separation_distance : float = 3.0  # 敌人间距
@export var separation_force : float = 2.0     # 分散力度

func move_towards_target(delta: float):
	var direction : Vector3
	
	# 尝试使用导航代理
	if nav_agent and nav_agent.is_target_reachable():
		var next_pos = nav_agent.get_next_path_position()
		direction = global_position.direction_to(next_pos)
	else:
		# 备选方案：直接朝目标移动
		if target:
			direction = global_position.direction_to(target.global_position)
		else:
			return
	
	# 只保留水平方向
	direction.y = 0
	direction = direction.normalized()
	
	# 添加分散力（避开其他敌人）
	var separation = get_separation_force()
	direction = (direction + separation * separation_force).normalized()
	
	# 平滑移动
	velocity.x = move_toward(velocity.x, direction.x * move_speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 20.0 * delta)

# 计算分散力（避开周围的敌人）
func get_separation_force() -> Vector3:
	var force = Vector3.ZERO
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearby_count = 0
	
	for enemy in enemies:
		if enemy == self:
			continue
		
		var dist = global_position.distance_to(enemy.global_position)
		if dist < separation_distance and dist > 0.1:
			# 计算远离方向
			var away = (global_position - enemy.global_position).normalized()
			# 距离越近，力越大
			force += away / dist
			nearby_count += 1
	
	# 归一化
	if force.length() > 0:
		force = force.normalized()
	
	return force

func look_at_target(pos: Vector3, delta: float):
	if not is_inside_tree():
		return
	
	# 水平旋转（身体）
	var direction = global_position.direction_to(pos)
	direction.y = 0
	
	if direction.length_squared() > 0.001:
		var target_basis = Basis.looking_at(direction)
		var target_rot_y = target_basis.get_euler().y
		rotation.y = lerp_angle(rotation.y, target_rot_y, 8.0 * delta)
	
	# 垂直旋转（武器）
	if weapon_pivot and head:
		var local_pos = weapon_pivot.to_local(pos)
		var target_rot_x = atan2(local_pos.y, -local_pos.z)
		target_rot_x = clamp(target_rot_x, deg_to_rad(-60), deg_to_rad(60))
		weapon_pivot.rotation.x = lerp_angle(weapon_pivot.rotation.x, target_rot_x, 10.0 * delta)

# ============ 射击系统 ============
func predict_target_position() -> Vector3:
	if not target:
		return global_position
	
	var base_pos = target.global_position
	
	# 简化版预测：假设子弹飞行时间0.15秒
	if target is CharacterBody3D:
		var bullet_time = 0.15
		base_pos = base_pos + target.velocity * bullet_time
	
	return base_pos

func shoot():
	fire_cooldown = fire_rate
	
	# 播放射击音效
	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.9, 1.1)
		shoot_sound.play()
	
	# 执行射击
	if not raycast or not target or not is_inside_tree():
		return
	
	# 随机决定是否爆头
	var is_targeting_head = randf() < headshot_chance
	
	# 获取瞄准点
	var aim_point : Vector3
	if is_targeting_head:
		aim_point = get_target_head_position()
	else:
		# 身体中心
		aim_point = target.global_position + Vector3(0, 0.8, 0)
	
	# 添加精度偏移
	var spread = get_accuracy_spread()
	aim_point += spread
	
	# 设置射线方向
	raycast.look_at(aim_point)
	raycast.force_raycast_update()
	
	# 检测命中
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		var hit_point = raycast.get_collision_point()
		
		# 检查是否命中友军（敌人组成员）
		if is_teammate(collider):
			print(name, ": 差点打中队友！")
			spawn_impact(hit_point)
			return
		
		# 判断是否爆头
		var is_headshot = check_headshot(collider)
		
		# 造成伤害
		deal_damage(collider, is_headshot)
		
		# 生成命中效果（可选）
		spawn_impact(hit_point)

# 检查是否是队友
func is_teammate(collider: Node) -> bool:
	if not collider:
		return false
	
	# 直接检查是否在敌人组
	if collider.is_in_group("enemies"):
		return true
	
	# 向上查找父节点
	var node = collider
	while node:
		if node.is_in_group("enemies"):
			return true
		node = node.get_parent()
	
	return false

func get_accuracy_spread() -> Vector3:
	return Vector3(
		randf_range(-1, 1),
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized() * (randf() * accuracy * 50.0)

func check_headshot(collider: Node) -> bool:
	if not collider:
		return false
	
	# 方法1：检查节点名
	if "HeadHitbox" in collider.name or "Head" in collider.name:
		return true
	
	# 方法2：检查Hitbox属性
	if collider.has_method("hit") and "is_weak_spot" in collider:
		return collider.is_weak_spot
	
	# 方法3：向上查找
	var node = collider
	while node:
		if "HeadHitbox" in node.name or "Head" in node.name:
			return true
		if node.has_method("hit") and "is_weak_spot" in node:
			if node.is_weak_spot:
				return true
		node = node.get_parent()
	
	return false

func deal_damage(collider: Node, is_headshot: bool):
	if not collider:
		return
	
	var damage = damage_head if is_headshot else damage_body
	
	# 尝试调用hit方法
	if collider.has_method("hit"):
		collider.hit(damage, is_headshot)
	# 如果是玩家组的成员
	elif collider.is_in_group("player"):
		if collider.has_method("hit"):
			collider.hit(damage, is_headshot)

func spawn_impact(pos: Vector3):
	# 简化版：可以留空或添加简单的命中特效
	pass

# ============ 状态管理 ============
func change_state(new_state: State):
	if current_state == new_state:
		return
	
	current_state = new_state
	print(name, " 切换状态到: ", State.keys()[new_state])

# ============ 受击系统 ============
func hit(dmg: float, is_headshot: bool = false):
	# 受击后立即警觉
	alerted = true
	
	# 受击时自动感知攻击方向（即使看不到）
	if target:
		last_seen_pos = target.global_position
		print(name, ": 受到攻击！感知到敌人方向！")
	
	# 爆头秒杀
	if is_headshot:
		current_health = 0
		print(name, " 被爆头击杀！")
		die()
		return
	
	# 普通伤害
	current_health -= dmg
	print(name, " 受到伤害: ", dmg, " 剩余血量: ", current_health)
	
	# 受击后立即切换到追击状态
	if current_state == State.IDLE:
		change_state(State.CHASE)
	
	# 血量耗尽
	if current_health <= 0:
		die()

func die():
	current_health = 0
	
	# 停止音效
	if shoot_sound:
		shoot_sound.stop()
	
	print(name, " 死亡")
	
	# 从场景树移除
	queue_free()

# ============ 声音感知系统 ============

# 接收玩家声音信号
func _on_player_sound(pos: Vector3, sound_type: String, volume: float):
	if not is_inside_tree() or current_health <= 0:
		return
	
	var dist = global_position.distance_to(pos)
	var effective_hearing = hearing_range
	
	# 脚步声敏感度加成
	if sound_type == "footstep":
		effective_hearing *= footstep_sensitivity
	
	# 检查是否能听到
	if dist > effective_hearing:
		return
	
	# 计算声音强度（距离越近越清晰）
	var intensity = 1.0 - (dist / effective_hearing)
	
	# 处理不同类型的声音
	match sound_type:
		"footstep":
			handle_footstep(pos, intensity)
		"gunshot":
			handle_gunshot(pos, intensity)
		"reload":
			handle_reload(pos, intensity)

# 处理脚步声
func handle_footstep(pos: Vector3, intensity: float):
	# 脚步声需要一定强度才能引起注意
	if intensity < 0.2:
		return
	
	last_heard_pos = pos
	sound_alert_level = min(1.0, sound_alert_level + intensity * 0.3)
	
	print(name, ": 听到脚步声！强度: ", snappedf(intensity, 0.1))
	
	# 如果还没警觉，根据声音强度决定反应
	if not alerted:
		if intensity > 0.6:
			# 很近，立即警觉
			alerted = true
			last_seen_pos = pos
			if current_state == State.IDLE:
				change_state(State.CHASE)
				print(name, ": 脚步声很近！立即响应！")
		elif intensity > 0.3:
			# 中等距离，转头查看
			look_at_target(pos, 0.5)
			print(name, ": 听到可疑声音，转头查看...")
	# 已警觉状态下，更新最后位置
	elif current_state == State.IDLE or current_state == State.CHASE:
		last_seen_pos = pos

# 处理枪声
func handle_gunshot(pos: Vector3, intensity: float):
	last_heard_pos = pos
	sound_alert_level = 1.0
	
	print(name, ": 听到枪声！")
	
	if not alerted:
		alerted = true
		last_seen_pos = pos
		if current_state == State.IDLE:
			change_state(State.CHASE)
	
	# 通知队友
	alert_teammates()

# 处理换弹声
func handle_reload(pos: Vector3, intensity: float):
	if intensity < 0.3:
		return
	
	print(name, ": 听到换弹声...")
	# 可以在这里添加激进进攻逻辑

# ============ 辅助函数 ============
# 状态名称（用于调试）
func get_state_name(state: State) -> String:
	match state:
		State.IDLE:
			return "待机"
		State.CHASE:
			return "追击"
		State.ATTACK:
			return "攻击"
		State.FLANK:
			return "包抄"
		_:
			return "未知"

# 角色名称（用于调试）
func get_role_name() -> String:
	match role:
		EnemyRole.ASSAULT:
			return "突击手"
		EnemyRole.FLANKER:
			return "侧翼手"
		EnemyRole.SNIPER:
			return "狙击手"
		_:
			return "未知"

# ============ 战术配合系统 ============

# 发现敌人时通知队友
func alert_teammates():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy != self and enemy.has_method("on_teammate_alert"):
			enemy.on_teammate_alert(last_seen_pos)

# 接收队友的警报
func on_teammate_alert(player_pos: Vector3):
	if alerted:
		return  # 已经警觉了
	
	alerted = true
	teammate_spotted = true
	last_seen_pos = player_pos
	print(name, ": 收到队友警报！前往支援！")
	
	# 根据角色选择行动
	match role:
		EnemyRole.FLANKER:
			# 侧翼手：尝试包抄
			if current_state == State.IDLE:
				change_state(State.FLANK)
		EnemyRole.SNIPER:
			# 狙击手：原地架枪
			if current_state == State.IDLE:
				change_state(State.ATTACK)
		_:
			# 突击手：直接冲锋
			if current_state == State.IDLE:
				change_state(State.CHASE)

# 包抄状态处理
func process_flank(delta: float, can_see: bool):
	if not target:
		change_state(State.IDLE)
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	# 进入攻击范围或被发现，转为攻击
	if dist < flank_distance or can_see:
		change_state(State.ATTACK)
		return
	
	# 计算包抄位置
	var to_player = (target.global_position - global_position).normalized()
	var flank_dir = to_player.rotated(Vector3.UP, deg_to_rad(flank_angle))
	var flank_pos = target.global_position - flank_dir * flank_distance
	
	# 移动到包抄位置
	nav_agent.target_position = flank_pos
	move_towards_target(delta)
	
	# 朝向玩家
	if can_see:
		look_at_target(target.global_position, delta)
	else:
		look_at_target(flank_pos, delta)

# 检查是否有队友在压制
func has_teammate_suppressing() -> bool:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy != self and enemy.has_method("is_suppressing_target"):
			if enemy.is_suppressing_target():
				return true
	return false

# 检查自己是否在压制（用于队友判断）
func is_suppressing_target() -> bool:
	return is_suppressing and current_state == State.ATTACK
