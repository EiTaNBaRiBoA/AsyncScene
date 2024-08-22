extends Node
class_name AsyncScene

# Defines the different operations that can be performed with the scene loader
enum LoadingSceneOperation {
	ReplaceImmediate, # Replaces the current scene immediately upon loading
	Replace, # Doesn't replace the scene immediately; call ChangeScene() to replace
	AdditiveImmediate, # Adds the new scene as a child to the root node immediately upon loading
	Additive # Doesn't add the scene immediately; call ChangeScene() to add
}

# Maps ResourceLoader.ThreadLoadStatus values to human-readable strings
var status_names = {
	ResourceLoader.THREAD_LOAD_IN_PROGRESS: "THREAD_LOAD_IN_PROGRESS",
	ResourceLoader.THREAD_LOAD_FAILED: "THREAD_LOAD_FAILED",
	ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: "THREAD_LOAD_INVALID_RESOURCE",
	ResourceLoader.THREAD_LOAD_LOADED: "THREAD_LOAD_LOADED"
}

# Timer for checking the loading status
var timer: Timer = Timer.new()

# Signal emitted when the scene loading is complete
signal OnComplete

# Path to the packed scene file
var packedScenePath: String = ""

# Loaded PackedScene resource
var myRes: PackedScene = null

# Instance of the loaded scene
var currentSceneNode: Node = null

# Loading progress (0-100)
var progress: float = 0

# Flag indicating if the scene has been loaded successfully
var isCompleted: bool = false

# Selected operation type for loading the scene
var typeOperation: LoadingSceneOperation = LoadingSceneOperation.ReplaceImmediate

# Flag to prevent multiple scene changes (for Replace and Additive operations)
var changed: bool = false

# Constructor for the AsyncScene class
#
# Args:
#     tscnPath (String): Path to the packed scene file
#     setOperation (LoadingSceneOperation): Type of operation to perform with the scene (default: ReplaceImmediate)
func _init(tscnPath: String, setOperation: LoadingSceneOperation = LoadingSceneOperation.ReplaceImmediate) -> void:
	packedScenePath = tscnPath
	typeOperation = setOperation

	# Check if the scene file exists
	if not ResourceLoader.exists(tscnPath):
		printerr("Invalid scene path: " + tscnPath)
		return

	# Request the scene to be loaded in a separate thread
	ResourceLoader.load_threaded_request(tscnPath, "", true)

	# Call _setupUpdateSeconds() after the current frame is finished
	call_deferred("_setupUpdateSeconds")

# Changes the current scene to the loaded scene
#
# This method should only be called after the scene is fully loaded.
func ChangeScene() -> void:
	# Check if the scene has been loaded
	if not isCompleted:
		printerr("Scene hasn't been loaded yet.")
		return

	# Prevent multiple scene changes for Replace and Additive operations
	if changed:
		return

	# Perform the appropriate scene change based on the selected operation type
	if typeOperation == LoadingSceneOperation.Replace:
		_changeImmediate()
	elif typeOperation == LoadingSceneOperation.Additive:
		_additiveScene()

	# Mark the scene as changed
	changed = true

# Returns the current status of the scene loading as a human-readable string
func GetStatus() -> String:
	return status_names.get(_getStatus())

#region Private Methods

# Adds the loaded scene as a child of the root node
func _additiveScene() -> void:
	# Instantiate the loaded scene
	currentSceneNode = myRes.instantiate()

	# Add the scene to the root node
	Engine.get_main_loop().root.call_deferred("add_child", currentSceneNode)

# Replaces the current scene with the loaded scene
func _changeImmediate() -> void:
	# Get the current scene
	currentSceneNode = Engine.get_main_loop().root.get_tree().current_scene

	# Queue the current scene for deletion if it exists
	if currentSceneNode:
		currentSceneNode.queue_free()

	# Add the loaded scene to the tree
	_additiveScene()

# Unloads the loaded scene and cleans up the AsyncScene instance
func UnloadScene() -> void:
	# Check if the scene has been loaded
	if not isCompleted:
		printerr("Scene hasn't been loaded yet.")
		return

	# Delete the scene instance if it exists
	if currentSceneNode:
		currentSceneNode.queue_free()

	# Delete the AsyncScene instance
	queue_free()

# Sets up the timer to check the loading status
func _setupUpdateSeconds() -> void:
	# Add the timer as a child of the root node
	Engine.get_main_loop().root.add_child(timer)

	# Set timer properties
	timer.one_shot = false
	timer.autostart = true
	timer.set_wait_time(0.1)

	# Connect the timer timeout signal to _check_status
	timer.timeout.connect(_check_status)

	# Start the timer
	timer.start()

# Returns the current status of the scene loading
func _getStatus() -> ResourceLoader.ThreadLoadStatus:
	return ResourceLoader.load_threaded_get_status(packedScenePath)

# Checks the loading status of the scene
func _check_status() -> void:
	# Check if the scene is already loaded
	if isCompleted:
		return

	# Get the loading status
	var status = _getStatus()

	# Handle the different loading statuses
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		# Get the loaded PackedScene resource
		myRes = ResourceLoader.load_threaded_get(packedScenePath)

		# Handle the different operation types
		if typeOperation == LoadingSceneOperation.ReplaceImmediate:
			_changeImmediate()
		elif typeOperation == LoadingSceneOperation.AdditiveImmediate:
			_additiveScene()

		# Mark the scene as loaded and stop the timer
		_complete(false)
	elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		# Mark the scene loading as failed and stop the timer
		_complete(true)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		# Mark the scene loading as failed and stop the timer
		_complete(true)
	elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# Get the loading progress
		var progressArr: Array = []
		ResourceLoader.load_threaded_get_status(packedScenePath, progressArr)
		progress = progressArr.front() * 100

# Called when the scene loading is complete
func _complete(isFailed: bool) -> void:
	# Set the loading status
	isCompleted = !isFailed

	# Set the loading progress to 100%
	progress = 100

	# Delete the timer
	timer.queue_free()

	# Emit the OnComplete signal
	OnComplete.emit()
#endregion
