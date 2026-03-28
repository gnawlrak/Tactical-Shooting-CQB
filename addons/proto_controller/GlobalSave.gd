extends Node

const SAVE_PATH = "user://player_stats.cfg"

var total_kills : int = 0
var total_deaths : int = 0
var threat_level : float = 1.0

func _ready():
	load_data()
	update_threat_level()

func add_kill():
	total_kills += 1
	update_threat_level()
	save_data()
	print("GlobalSave: Kill added. Current K/D: ", float(total_kills)/(max(1, total_deaths)))

func add_death():
	total_deaths += 1
	update_threat_level()
	save_data()
	print("GlobalSave: Death added. Current K/D: ", float(total_kills)/(max(1, total_deaths)))

func update_threat_level():
	# Threat level calculation: KD centered around 1.0
	# Range: 0.5 (low skill) to 2.5 (pro)
	var kd = float(total_kills + 1) / float(total_deaths + 1)
	threat_level = clamp(kd, 0.5, 2.5)
	print("GlobalSave: New Threat Level calculated: ", threat_level)

func save_data():
	var config = ConfigFile.new()
	config.set_value("Stats", "kills", total_kills)
	config.set_value("Stats", "deaths", total_deaths)
	config.save(SAVE_PATH)

func load_data():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		total_kills = config.get_value("Stats", "kills", 0)
		total_deaths = config.get_value("Stats", "deaths", 0)
		update_threat_level()
