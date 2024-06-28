extends Node
class_name AsyncScene


enum LoadingSceneOperation {
	ReplaceImmediate, ## Replaces scene as soon as it loads
	Replace, ## Doesn't Replace scene immediate, and need to call ChangeScene(using the same path)
	Additive ## Adding to the tree another scene
}
var status_names = {
	ResourceLoader.THREAD_LOAD_IN_PROGRESS: "THREAD_LOAD_IN_PROGRESS",
	ResourceLoader.THREAD_LOAD_FAILED: "THREAD_LOAD_FAILED",
	ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: "THREAD_LOAD_INVALID_RESOURCE",
	ResourceLoader.THREAD_LOAD_LOADED: "THREAD_LOAD_LOADED"
}

var timer : Timer = Timer.new()
signal OnComplete
var packedScenePath : String = ""
var myRes : PackedScene = null
var currentSceneNode : Node = null
var progress : float = 0
var isCompleted : bool = false
var typeOperation : LoadingSceneOperation = LoadingSceneOperation.ReplaceImmediate

func _init(tscnPath : String, setOperation : LoadingSceneOperation = LoadingSceneOperation.ReplaceImmediate ) -> void:
	packedScenePath = tscnPath
	typeOperation = setOperation
	if not ResourceLoader.exists(tscnPath):
		printerr("Invalid scene path " + tscnPath)
		return
	ResourceLoader.load_threaded_request(tscnPath,"",true)
	call_deferred("_setupUpdateSeconds")



func ChangeScene() -> void:
	if not isCompleted: 
		printerr("Scene hasn't been loaded yet")
		return
	_changeImmediate()

func GetStatus() -> String:
	return status_names.get(_getStatus())

#region Private

func _additiveScene() -> void:
	currentSceneNode = myRes.instantiate()
	Engine.get_main_loop().root.call_deferred("add_child",currentSceneNode)

func _changeImmediate() -> void:
	currentSceneNode = Engine.get_main_loop().root.get_tree().current_scene
	currentSceneNode.queue_free()
	_additiveScene()
	

## Unloading
func UnloadScene() -> void:
	if not isCompleted: 
		printerr("Scene hasn't been loaded yet")
		return
	if currentSceneNode:
		currentSceneNode.queue_free()
	queue_free()


func _setupUpdateSeconds() -> void:
	Engine.get_main_loop().root.add_child(timer)
	timer.one_shot = false
	timer.autostart = true
	timer.set_wait_time(0.1)
	timer.timeout.connect(_check_status)
	timer.start()


func _getStatus() -> ResourceLoader.ThreadLoadStatus:
	return ResourceLoader.load_threaded_get_status(packedScenePath)


func _check_status() -> void:
	if isCompleted : return
	if _getStatus() == ResourceLoader.THREAD_LOAD_LOADED:
		myRes = ResourceLoader.load_threaded_get(packedScenePath)
		if typeOperation == LoadingSceneOperation.ReplaceImmediate:
			_changeImmediate()
		elif typeOperation == LoadingSceneOperation.Additive:
			_additiveScene()
		_complete(false)
	elif _getStatus() == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_complete(true)
	elif _getStatus() == ResourceLoader.THREAD_LOAD_FAILED:
		_complete(true)
	elif _getStatus() == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var progressArr : Array = []
		ResourceLoader.load_threaded_get_status(packedScenePath,progressArr)
		progress = progressArr.front() * 100



func _complete(isFailed : bool) -> void:
	isCompleted = !isFailed
	progress = 100
	timer.queue_free()
	OnComplete.emit()
#endregion
