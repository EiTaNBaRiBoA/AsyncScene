extends Node2D

var scene : AsyncScene = null
@export var scenePath : String = 'res://addons/AsyncSceneManager/Examples/scene_to_load.tscn'


func _ready() -> void:
	scene = AsyncScene.new(scenePath,AsyncScene.LoadingSceneOperation.Replace) #loading and later changing using scene.ChangeScene()
	#scene = AsyncScene.new(scenePath,AsyncScene.LoadingSceneOperation.ReplaceImmediate) #Immediately changing the scene after loading
	#scene = AsyncScene.new(scenePath,AsyncScene.LoadingSceneOperation.Additive) #Loading Scene additively to another scene 
	scene.OnComplete.connect(complete) #Binding to signal after complete loading
	
func complete() -> void:
	scene.ChangeScene() #Changing the main scene manually
	#scene.UnloadScene() #Unloading scene 
	print("Loading complete")
	pass
	
	
