extends Node2D

func on_scene_loaded(...params: Array) -> void:
	print("Scene loaded with parameters: ", params)
	# Prints [{"player_score": 1000, "entry_point": "west_gate"}]
