extends Camera3D

# 环绕摄像机设置
@export var orbit_speed : float = 0.3  # 旋转速度
@export var orbit_radius : float = 20.0  # 环绕半径
@export var orbit_height : float = 10.0  # 高度
@export var look_at_center : Vector3 = Vector3(0, 0, 0)  # 看向的中心点

var orbit_angle : float = 0.0

func _ready():
	# 初始位置
	update_position()

func _process(delta):
	# 持续旋转
	orbit_angle += orbit_speed * delta
	if orbit_angle > TAU:
		orbit_angle -= TAU
	
	update_position()

func update_position():
	# 计算圆形轨道位置
	var x = cos(orbit_angle) * orbit_radius
	var z = sin(orbit_angle) * orbit_radius
	
	global_position = Vector3(x, orbit_height, z)
	look_at(look_at_center)
