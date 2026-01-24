extends Control


## Export the path to the scene you want to load
## Recommended to use @export_file("*.tscn") to get a reference that is not easily
## lost if the scene file is moved.
@export_file("*.tscn") var scene_ref: String = "uid://dqojfek3b58la"

## How long to wait after loading completed, before changing the scene. 
## Nicer to look at.
@export var complete_wait_time: float = 1.0

@export_group("Transition Settings")
@export var transition_type: AsyncScene.TransitionType = AsyncScene.TransitionType.WipeLeft
@export var transition_duration: float = 1.0
@export var transition_color: Color = Color.BLACK
@export var transition_pause_duration: float = 2.0


func _ready() -> void:
	var scene_path: String = ResourceUID.uid_to_path(scene_ref)
	if !scene_path:
		printerr("UID not recognized. Check the export variable.")
		return
	
	# 1. Create the loader and configure it
	var loader: AsyncScene = AsyncScene.new(
			scene_path,
			AsyncScene.LoadingOperation.Replace,
			self
	)

	loader.with_parameters({"player_score": 1000, "entry_point": "west_gate"})
	loader.with_transition(transition_type, transition_duration, transition_color)
	loader.with_pause(transition_pause_duration)

	# 2. Connect to its signals
	loader.progress_changed.connect(func(p: float) -> void: $ProgressBar.value = p * 100)
	loader.loading_completed.connect(on_load_complete)
	loader.loading_error.connect(on_load_error)

	# 3. Add the loader to the scene tree to start the process
	loader.start()


func on_load_complete(loader: AsyncScene) -> void:
	print("Load complete! Changing scene now.")
	
	await get_tree().create_timer(complete_wait_time).timeout
	
	# For non-immediate operations (Replace, Additive), we must call change_scene()
	loader.change_scene()


func on_load_error(err_code: AsyncScene.ErrorCode, err_msg: String) -> void:
	# Handle the error, e.g., show an error message to the user
	print("Failed to load scene. Error %s: %s" % [err_code, err_msg])
