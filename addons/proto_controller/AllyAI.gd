extends CharacterBody3D

class_name AllyAI

# ============ 基础配置 ============
@export_group("基础属性")
@export var max_health : float = 100.0
@export var move_speed : float = 7.0
@export var follow_distance : float = 4.0  # 跟随玩家距离（更近）

@export_group("战斗属性")
@export var attack_range : float = 25.0  # 增加攻击范围
@export var sight_range : float = 60.0  # 增加视野
@export var vision_fov : float = 150.0  # 更宽的视野
@export var fire_rate : float = 0.1
@export var damage_body : float = 35.0
@export var damage_head : float = 100.0
@export var headshot_chance : float = 0.15

@export_group("精度设置")
@export var accuracy : float = 0.025

@export_group("战术设置")
@export var role : AllyRole = AllyRole.BREACHER
@export var aggression : float = 0.9  # 提高默认攻击性

# ============ 节点引用 ============
@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D
@onready var head : Node3D = $Head
@onready var weapon_pivot : Node3D = $Head/WeaponPivot
@onready var raycast : RayCast3D = $Head/WeaponPivot/AimRay
@onready var shoot_sound : AudioStreamPlayer3D = $ShootSound
@onready var mesh_instance : MeshInstance3D = $MeshInstance3D

# ============ 枚举 ============
enum State { FOLLOW, ENGAGE, COVER, PUSH }
enum AllyRole { BREACHER, RIFLEMAN, SUPPORT }  # 突破门手、步枪手、支援手

# ============ 运行时变量 ============
var current_state : State = State.FOLLOW
var current_health : float
var player : Node3D = null
var current_target : Node3D = null
var fire_cooldown : float = 0.0
var last_seen_target_pos : Vector3 = Vector3.ZERO

# 移动相关
var strafe_dir : float = 1.0
var strafe_timer : float = 0.0

# 重力
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ============ 初始化 ============
func _ready():
	current_health = max_health
	
	# 配置导航
	setup_navigation()
	
	# 配置射线
	setup_raycast()
	
	# 配置音效
	setup_sound()
	
	# 添加到友方组
	add_to_group("allies")
	
	# 设置外观颜色（区分敌我）
	setup_appearance()
	
	# 根据角色调整属性
	apply_role_modifiers()
	
	# 延迟寻找玩家（确保玩家已加载）
	await get_tree().create_timer(0.2).timeout
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("友军AI找到玩家: ", name)
	else:
		print("友军AI未找到玩家: ", name)
	
	print("友军AI初始化完成: ", name, " 角色: ", get_role_name())

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
		shoot_sound.stream = load("res://sounds/mcx半自动.mp3")

func setup_appearance():
	# 设置为蓝色/绿色以区分敌我
	if mesh_instance and mesh_instance.mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.5, 0.9)  # 蓝色
		mesh_instance.material_override = mat

func apply_role_modifiers():
	match role:
		AllyRole.BREACHER:
			# 突破门手：极高攻击性，快速突进
			aggression = 1.0
			move_speed *= 1.2
			fire_rate *= 0.85
		AllyRole.RIFLEMAN:
			# 步枪手：积极进攻
			aggression = 0.85
			move_speed *= 1.1
		AllyRole.SUPPORT:
			# 支援手：稳健但积极
			aggression = 0.6
			accuracy *= 0.75
			sight_range *= 1.3
			fire_rate *= 0.9

# ============ 主循环 ============
func _physics_process(delta):
	if current_health <= 0 or not is_inside_tree():
		return
	
	# 重力
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# 搜索敌人
	search_enemies()
	
	# 状态机
	match current_state:
		State.FOLLOW:
			process_follow(delta)
		State.ENGAGE:
			process_engage(delta)
		State.COVER:
			process_cover(delta)
		State.PUSH:
			process_push(delta)
	
	# 射击冷却
	if fire_cooldown > 0:
		fire_cooldown -= delta
	
	# 移动
	move_and_slide()

# ============ 敌人搜索 ============
func search_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest_enemy = null
	var nearest_dist = sight_range
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		
		var dist = global_position.distance_to(enemy.global_position)
		
		# 积极搜索：能看见 或者 距离15米内 或者 队友在交战
		var should_engage = can_see_target(enemy) or dist < 15.0
		if should_engage and dist < nearest_dist:
			nearest_dist = dist
			nearest_enemy = enemy
	
	if nearest_enemy:
		current_target = nearest_enemy
		last_seen_target_pos = nearest_enemy.global_position
		
		# 积极响应：发现敌人立即交战
		if nearest_dist < attack_range * 1.2:
			if current_state != State.ENGAGE:
				change_state(State.ENGAGE)
		else:
			# 主动追击
			if current_state == State.FOLLOW:
				change_state(State.PUSH)
	elif current_target:
		# 检查目标是否还有效
		if not is_instance_valid(current_target) or current_target.current_health <= 0:
			current_target = null
			change_state(State.FOLLOW)
		elif not can_see_target(current_target):
			# 失去目标，主动追击到最后位置
			if current_state == State.ENGAGE:
				change_state(State.PUSH)

func can_see_target(target_node: Node3D) -> bool:
	if not target_node or not is_inside_tree():
		return false
	
	var dist = global_position.distance_to(target_node.global_position)
	if dist > sight_range:
		return false
	
	# FOV检查
	var to_target = (target_node.global_position - global_position).normalized()
	var forward = -global_transform.basis.z
	var angle = rad_to_deg(forward.angle_to(to_target))
	
	if angle > vision_fov / 2.0:
		return false
	
	# 射线检测
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return false
	
	var query = PhysicsRayQueryParameters3D.create(
		head.global_position,
		target_node.global_position + Vector3(0, 1.0, 0)
	)
	query.exclude = [self]
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	
	if not result:
		return true
	
	# 检查是否命中目标
	var node = result.collider
	while node:
		if node == target_node:
			return true
		node = node.get_parent()
	
	return false

# ============ 状态处理 ============
func process_follow(delta: float):
	if not player:
		return
	
	var dist_to_player = global_position.distance_to(player.global_position)
	
	# 紧密跟随玩家
	if dist_to_player > follow_distance:
		nav_agent.target_position = player.global_position
		move_towards_target(delta)
	
	# 保持面朝玩家前方或威胁方向
	if current_target:
		look_at_target(current_target.global_position, delta)
	else:
		# 面向玩家前方，随时准备战斗
		var look_pos = player.global_position - player.global_transform.basis.z * 10
		look_at_target(look_pos, delta)

func process_engage(delta: float):
	if not current_target:
		change_state(State.FOLLOW)
		return
	
	var dist = global_position.distance_to(current_target.global_position)
	
	# 太远了，积极追击
	if dist > attack_range * 1.5:
		change_state(State.PUSH)
		return
	
	# 失去目标，主动追击而不是放弃
	if not can_see_target(current_target):
		change_state(State.PUSH)
		return
	
	# 面向目标
	look_at_target(current_target.global_position, delta)
	
	# 战斗移动
	perform_combat_movement(delta)
	
	# 射击
	if fire_cooldown <= 0:
		shoot()

func process_cover(delta: float):
	if not player:
		return
	
	# 移动到玩家附近提供掩护
	var cover_pos = player.global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
	nav_agent.target_position = cover_pos
	move_towards_target(delta)
	
	# 面向威胁方向
	if current_target:
		look_at_target(current_target.global_position, delta)

func process_push(delta: float):
	if not current_target and last_seen_target_pos == Vector3.ZERO:
		change_state(State.FOLLOW)
		return
	
	# 向目标位置快速推进
	var target_pos = current_target.global_position if current_target else last_seen_target_pos
	nav_agent.target_position = target_pos
	move_towards_target(delta)
	
	# 面向目标
	look_at_target(target_pos, delta)
	
	# 推进时积极射击
	if current_target:
		if fire_cooldown <= 0:
			shoot()
	
	# 接近后转为交战
	var dist = global_position.distance_to(target_pos)
	if dist < attack_range:
		if current_target:
			change_state(State.ENGAGE)
		elif dist < 5.0:
			# 到达最后位置找不到目标
			last_seen_target_pos = Vector3.ZERO
			change_state(State.FOLLOW)

# ============ 移动系统 ============
@export var separation_distance : float = 3.0
@export var separation_force : float = 1.5

func move_towards_target(delta: float):
	var direction : Vector3
	var target_pos : Vector3
	
	# 确定目标位置
	if current_target:
		target_pos = current_target.global_position
	elif player:
		target_pos = player.global_position
	else:
		return
	
	# 尝试使用导航代理
	if nav_agent and nav_agent.is_target_reachable():
		var next_pos = nav_agent.get_next_path_position()
		direction = global_position.direction_to(next_pos)
	else:
		# 备选方案：直接朝目标移动
		direction = global_position.direction_to(target_pos)
	
	direction.y = 0
	direction = direction.normalized()
	
	# 分散力
	var separation = get_separation_force()
	direction = (direction + separation * separation_force).normalized()
	
	velocity.x = move_toward(velocity.x, direction.x * move_speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 20.0 * delta)

func get_separation_force() -> Vector3:
	var force = Vector3.ZERO
	var allies = get_tree().get_nodes_in_group("allies")
	
	for ally in allies:
		if ally == self:
			continue
		var dist = global_position.distance_to(ally.global_position)
		if dist < 3.0 and dist > 0.1:
			force += (global_position - ally.global_position).normalized() / dist
	
	if force.length() > 0:
		force = force.normalized() * 0.5
	
	return force

func perform_combat_movement(delta: float):
	if not current_target:
		return
	
	var dist = global_position.distance_to(current_target.global_position)
	
	strafe_timer -= delta
	if strafe_timer <= 0:
		strafe_timer = randf_range(1.0, 2.5)
		strafe_dir = 1.0 if randf() > 0.5 else -1.0
	
	var move_dir = Vector3.ZERO
	move_dir += global_transform.basis.x * strafe_dir
	
	if dist < attack_range * 0.4:
		move_dir -= global_transform.basis.z * 0.5
	elif dist > attack_range * 0.8:
		move_dir += global_transform.basis.z * 0.3
	
	# 分散
	move_dir += get_separation_force()
	
	if move_dir.length() > 0:
		move_dir = move_dir.normalized()
		velocity.x = move_toward(velocity.x, move_dir.x * move_speed * 0.5, 15.0 * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * move_speed * 0.5, 15.0 * delta)

func look_at_target(pos: Vector3, delta: float):
	if not is_inside_tree():
		return
	
	var direction = global_position.direction_to(pos)
	direction.y = 0
	
	if direction.length_squared() > 0.001:
		var target_basis = Basis.looking_at(direction)
		var target_rot_y = target_basis.get_euler().y
		rotation.y = lerp_angle(rotation.y, target_rot_y, 8.0 * delta)
	
	if weapon_pivot and head:
		var local_pos = weapon_pivot.to_local(pos)
		var target_rot_x = atan2(local_pos.y, -local_pos.z)
		target_rot_x = clamp(target_rot_x, deg_to_rad(-60), deg_to_rad(60))
		weapon_pivot.rotation.x = lerp_angle(weapon_pivot.rotation.x, target_rot_x, 10.0 * delta)

# ============ 射击系统 ============
func shoot():
	fire_cooldown = fire_rate
	
	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.9, 1.1)
		shoot_sound.play()
	
	if not raycast or not current_target or not is_inside_tree():
		return
	
	# 瞄准点
	var is_targeting_head = randf() < headshot_chance
	var aim_point : Vector3
	
	if is_targeting_head:
		aim_point = get_target_head_position()
	else:
		aim_point = current_target.global_position + Vector3(0, 0.8, 0)
	
	# 精度偏移
	var spread = get_accuracy_spread()
	aim_point += spread
	
	raycast.look_at(aim_point)
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		var hit_point = raycast.get_collision_point()
		
		# 检查是否命中友军
		if is_ally(collider):
			return
		
		# 检查是否命中敌人
		if is_enemy(collider):
			var is_headshot = check_headshot(collider)
			deal_damage(collider, is_headshot)

func get_target_head_position() -> Vector3:
	if not current_target:
		return global_position
	
	var target_height = 1.3
	if "current_height" in current_target:
		target_height = current_target.current_height
	
	return current_target.global_position + Vector3(0, target_height - 0.15, 0)

func get_accuracy_spread() -> Vector3:
	return Vector3(
		randf_range(-1, 1),
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized() * (randf() * accuracy * 50.0)

func is_ally(collider: Node) -> bool:
	if not collider:
		return false
	
	if collider.is_in_group("allies") or collider.is_in_group("player"):
		return true
	
	var node = collider
	while node:
		if node.is_in_group("allies") or node.is_in_group("player"):
			return true
		node = node.get_parent()
	
	return false

func is_enemy(collider: Node) -> bool:
	if not collider:
		return false
	
	if collider.is_in_group("enemies"):
		return true
	
	var node = collider
	while node:
		if node.is_in_group("enemies"):
			return true
		node = node.get_parent()
	
	return false

func check_headshot(collider: Node) -> bool:
	if not collider:
		return false
	
	if "HeadHitbox" in collider.name or "Head" in collider.name:
		return true
	
	if collider.has_method("hit") and "is_weak_spot" in collider:
		return collider.is_weak_spot
	
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
	
	if collider.has_method("hit"):
		collider.hit(damage, is_headshot)

# ============ 状态管理 ============
func change_state(new_state: State):
	if current_state == new_state:
		return
	
	current_state = new_state
	print(name, " [友军] 切换状态: ", get_state_name(new_state))

# ============ 受击系统 ============
func hit(dmg: float, is_headshot: bool = false):
	if is_headshot:
		current_health = 0
		print(name, " [友军] 被爆头！")
		die()
		return
	
	current_health -= dmg
	print(name, " [友军] 受伤！剩余血量: ", current_health)
	
	# 受伤后更保守
	if current_health < max_health * 0.3:
		aggression = max(0.2, aggression - 0.2)
	
	if current_health <= 0:
		die()

func die():
	current_health = 0
	
	if shoot_sound:
		shoot_sound.stop()
	
	print(name, " [友军] 阵亡！")
	queue_free()

# ============ 辅助函数 ============
func get_state_name(state: State) -> String:
	match state:
		State.FOLLOW:
			return "跟随"
		State.ENGAGE:
			return "交战"
		State.COVER:
			return "掩护"
		State.PUSH:
			return "推进"
		_:
			return "未知"

func get_role_name() -> String:
	match role:
		AllyRole.BREACHER:
			return "破门手"
		AllyRole.RIFLEMAN:
			return "步枪手"
		AllyRole.SUPPORT:
			return "支援手"
		_:
			return "未知"

# 接收队友（玩家）信号
func on_player_in_combat(enemy_pos: Vector3):
	if current_state == State.FOLLOW:
		last_seen_target_pos = enemy_pos
		change_state(State.PUSH)
