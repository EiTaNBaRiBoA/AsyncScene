extends Control

# Create an AsyncScene instance to handle the loading process
var scene: AsyncScene = null

# Export the path to the scene you want to load
@export var scene_path: String = 'res://AsyncScene/addons/AsyncSceneManager/Examples/scene_to_load.tscn'

func _ready() -> void:
	# 1. Create the loader and configure it
	var loader: AsyncScene = AsyncScene.new(
		scene_path,
		AsyncScene.LoadingOperation.ReplaceImmediate
		, self
	)

	loader.with_parameters({"player_score": 1000, "entry_point": "west_gate"})
	loader.with_transition(AsyncScene.TransitionType.WipeLeft, 1.0, Color.BLACK)

	# 2. Connect to its signals
	loader.OnProgressUpdate.connect(func(p: float) -> void: $ProgressBar.value = p * 100)
	loader.OnComplete.connect(on_load_complete)
	loader.OnError.connect(on_load_error)

	# 3. Add the loader to the scene tree to start the process
	loader.start()

func on_load_complete(loader: AsyncScene) -> void:
	print("Load complete! Changing scene now.")
	# For non-immediate operations (Replace, Additive), we must call change_scene()
	loader.change_scene()

func on_load_error(err_code: AsyncScene.ErrorCode, err_msg: String) -> void:
	print("Failed to load scene. Error %s: %s" % [err_code, err_msg])
	# Handle the error, e.g., show an error message to the user
	
	
	# Create a new AsyncScene instance, specifying the scene path and loading operation
func complete() -> void:
	# If using Replace or Additive operations, call ChangeScene() to finalize the scene change
	scene.ChangeScene()
	
	print("Loading complete")
	
	# Unload the scene (optional):
	scene.UnloadScene()
