extends Node2D

# Create an AsyncScene instance to handle the loading process
var scene : AsyncScene = null

# Export the path to the scene you want to load
@export var scenePath : String = 'res://addons/AsyncSceneManager/Examples/scene_to_load.tscn'

func _ready() -> void:
	# Create a new AsyncScene instance, specifying the scene path and loading operation
	scene = AsyncScene.new(scenePath, AsyncScene.LoadingSceneOperation.Replace)  # Load and later change using scene.ChangeScene()
	# scene = AsyncScene.new(scenePath, AsyncScene.LoadingSceneOperation.ReplaceImmediate) # Immediately change the scene after loading
	# scene = AsyncScene.new(scenePath, AsyncScene.LoadingSceneOperation.Additive) # Load additively to another scene 
	# scene = AsyncScene.new(scenePath, AsyncScene.LoadingSceneOperation.AdditiveImmediate) # Immediately add additively to another scene 

	# Connect the OnComplete signal to the complete function
	scene.OnComplete.connect(complete)

func complete() -> void:
	# If using Replace or Additive operations, call ChangeScene() to finalize the scene change
	scene.ChangeScene()

	# Unload the scene (optional):
	# scene.UnloadScene() 
	
	print("Loading complete")
