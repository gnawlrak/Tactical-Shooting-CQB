extends Node3D

class_name EnemySpawner

@export var enemy_scene : PackedScene = preload("res://addons/proto_controller/Enemy.tscn")
@export var spawn_radius : float = 20.0
@export var max_enemies : int = 15
@export var spawn_interval : float = 5.0
@export var spawn_points : Array[Node3D] = []

var active_enemies : Array[Node] = []
var timer : float = 0.0

func _ready():
	# Count existing enemies manually placed in the scene
	var existing = get_tree().get_nodes_in_group("enemies")
	print("Spawner: Found ", existing.size(), " existing enemies in scene.")
	for e in existing:
		if not e in active_enemies:
			active_enemies.append(e)

func _process(delta):
	timer += delta
	if timer >= spawn_interval:
		timer = 0
		check_and_spawn()

func check_and_spawn():
	# Cleanup dead enemies from list
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion())
	
	if active_enemies.size() < max_enemies:
		spawn_enemy()

func spawn_enemy():
	if not enemy_scene: return
	
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	
	var pos = global_position
	if not spawn_points.is_empty():
		pos = spawn_points.pick_random().global_position
	else:
		# Random position within radius
		var angle = randf() * TAU
		var dist = randf() * spawn_radius
		pos += Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	
	enemy.global_position = pos
	active_enemies.append(enemy)
	print("Spawner: Enemy spawned at ", pos)
