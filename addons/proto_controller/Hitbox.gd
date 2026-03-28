extends Area3D

@export var damage_multiplier : float = 1.0
@export var is_weak_spot : bool = false

func _ready():
	# 自动检测是否是头部 Hitbox
	if "Head" in name or "head" in name:
		is_weak_spot = true
		damage_multiplier = 2.0

func hit(damage : float, _is_headshot : bool = false):
	var final_damage = damage * damage_multiplier
	var parent = get_parent()
	while parent:
		if parent.has_method("hit"):
			parent.hit(final_damage, is_weak_spot)
			return
		parent = parent.get_parent()
