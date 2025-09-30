class_name AsyncScene extends Node

#region Enums and Signals

## Defines the different operations that can be performed with the scene loader.
enum LoadingOperation {
	Replace, ## Doesn't replace the scene immediately; call change_scene() to replace.
	ReplaceImmediate, ## Replaces the current scene immediately upon loading.
	Additive, ## Doesn't add the scene immediately; call change_scene() to add as a child of root.
	AdditiveImmediate ## Adds the new scene as a child to the root node immediately upon loading.
}

## Defines error codes for loading failures.
enum ErrorCode {
	OK, ## No error.
	InvalidPath, ## The provided scene path does not exist.
	LoadFailed, ## The resource loader failed to start or complete the request.
	InvalidResource ## The loaded resource is invalid or not a PackedScene.
}

## Defines transition types for scene changes.
enum TransitionType {
	None, ## No transition effect.
	Fade ## A simple fade-to-color-and-back transition.
}


## Emitted when the scene has been successfully loaded.
## [param loader_instance] A reference to this AsyncScene instance.
signal OnComplete(loader_instance: AsyncScene)

## Emitted when an error occurs during loading.
## [param err_code] The ErrorCode representing the failure.
## [param err_message] A descriptive string of the error.
signal OnError(err_code: ErrorCode, err_message: String)

## Emitted periodically during loading to report progress.
## [param progress] The loading progress as a value from 0.0 to 1.0.
signal OnProgressUpdate(progress: float)

#endregion

#region Public Properties

## The current loading progress from 0.0 to 1.0.
var progress: float = 0.0:
	get: return _progress

## Returns true if the scene has been successfully loaded.
var is_completed: bool = false:
	get: return _is_completed

## The error code if loading failed.
var error_code: ErrorCode = ErrorCode.OK:
	get: return _error_code

#endregion

#region Private Properties

# Configuration
var _packed_scene_path: String
var _operation: LoadingOperation
var _scene_parameters: Array = []
var _transition_type: TransitionType = TransitionType.None
var _transition_duration: float = 0.5
var _transition_color: Color = Color.BLACK
var _current_scene: Node = null

# State
var _loaded_resource: PackedScene
var _is_completed: bool = false
var _progress: float = 0.0
var _error_code: ErrorCode = ErrorCode.OK
var _has_changed_scene: bool = false

#endregion

#region Constructor & Lifecycle

## Initializes the scene loader. Must be added to the scene tree to start loading.
## [param tscn_path] Path to the packed scene file.
## [param set_operation] The loading operation to perform (default: Replace).
func _init(tscn_path: String, set_operation: LoadingOperation = LoadingOperation.Replace, current_scene: Node = null) -> void:
	_packed_scene_path = tscn_path
	_operation = set_operation
	_current_scene = current_scene


func start() -> void:
	# Start loading only when added to the scene tree.
	# This ensures timers and tweens can be created correctly.
	Engine.get_main_loop().root.add_child.call_deferred(self)
	_start_loading()

#endregion

#region Public Methods

## Manually triggers the scene change for non-immediate operations.
## This method should only be called after the 'OnComplete' signal has been emitted.
func change_scene() -> void:
	if not _is_completed:
		push_error("Cannot change scene: Loading is not complete.")
		return

	if _has_changed_scene:
		return

	_has_changed_scene = true

	if _operation == LoadingOperation.Replace or _operation == LoadingOperation.Additive:
		_perform_scene_change()


## Sets custom parameters to be passed to the new scene.
## The new scene's root node should have a function `on_scene_loaded(params: Dictionary)`
## to receive these parameters. Returns self to allow for method chaining.
func with_parameters(...params: Array) -> void:
	_scene_parameters = params


## Configures a transition effect for the scene change.
## Returns self to allow for method chaining.
func with_transition(type: TransitionType, duration: float = 0.5, color: Color = Color.BLACK) -> void:
	_transition_type = type
	_transition_duration = duration
	_transition_color = color


## Cleans up the loader instance. Typically called after the scene change is complete.
func cleanup() -> void:
	queue_free()

#endregion

#region Private Methods

func _start_loading() -> void:
	if not ResourceLoader.exists(_packed_scene_path):
		_fail(ErrorCode.InvalidPath, "Scene path does not exist: %s" % _packed_scene_path)
		return

	var error: Error = ResourceLoader.load_threaded_request(_packed_scene_path, "", true)
	if error != OK:
		_fail(ErrorCode.LoadFailed, "Failed to start threaded request for: %s (Error %s)" % [_packed_scene_path, error])
		return

	# Start a timer to check the status periodically.
	var timer: Timer = Timer.new()
	timer.wait_time = 0.05
	timer.timeout.connect(_check_status.bind(timer))
	self.add_child.call_deferred(timer)
	timer.autostart = 1


func _check_status(timer: Timer) -> void:
	var progress_array: Array[float] = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_packed_scene_path, progress_array)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress_array.is_empty():
				var new_progress: float = progress_array[0]
				if not is_equal_approx(new_progress, _progress):
					_progress = new_progress
					OnProgressUpdate.emit(_progress * 100)

		ResourceLoader.THREAD_LOAD_FAILED:
			_fail(ErrorCode.LoadFailed, "ResourceLoader failed to load the scene resource.")
			timer.queue_free()

		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail(ErrorCode.InvalidResource, "The loaded resource is invalid.")
			timer.queue_free()

		ResourceLoader.THREAD_LOAD_LOADED:
			_loaded_resource = ResourceLoader.load_threaded_get(_packed_scene_path)
			if not _loaded_resource is PackedScene:
				_fail(ErrorCode.InvalidResource, "Loaded resource is not a PackedScene.")
				timer.queue_free()
				return

			_complete()
			timer.queue_free()


func _complete() -> void:
	if _is_completed: return

	_is_completed = true
	_progress = 1.0
	OnProgressUpdate.emit(_progress * 100)
	OnComplete.emit(self)

	if _operation == LoadingOperation.ReplaceImmediate or _operation == LoadingOperation.AdditiveImmediate:
		_perform_scene_change()


func _fail(err_code: ErrorCode, err_message: String) -> void:
	if _is_completed: return # Already completed or failed

	_is_completed = true # Mark as "completed" to stop processing
	_error_code = err_code
	printerr(err_message)
	OnError.emit(_error_code, err_message)

	# Self-destruct after error
	queue_free()


func _perform_scene_change() -> void:
	if _transition_type == TransitionType.Fade:
		_fade_out_and_change()
	else:
		_change_scene_logic()
		# For non-transition changes, the loader can be cleaned up.
		# The calling script is responsible for this if it needs the loader instance.


func _fade_out_and_change() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 128 # High layer to render on top of everything
	var rect: ColorRect = ColorRect.new()
	rect.color = _transition_color
	rect.color.a = 0.0 # Start transparent
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(rect)
	get_tree().root.add_child(canvas)

	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(rect, "color:a", 1.0, _transition_duration / 2.0)
	await tween.finished

	_change_scene_logic()

	# Await one frame to ensure the new scene is rendered before fading in
	await get_tree().process_frame

	tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(rect, "color:a", 0.0, _transition_duration / 2.0)
	await tween.finished

	canvas.queue_free()
	# The loader's job is done after the transition.
	cleanup()


func _change_scene_logic() -> void:
	# For replacement, it's safer and cleaner to use the built-in tree method.
	if _operation == LoadingOperation.Replace or _operation == LoadingOperation.ReplaceImmediate:
		if _current_scene:
			_current_scene.queue_free()
		var new_scene_instance: Node = _loaded_resource.instantiate()
		get_tree().root.call_deferred("add_child", new_scene_instance)
		if not _scene_parameters.is_empty() and new_scene_instance.has_method("on_scene_loaded"):
			new_scene_instance.on_scene_loaded(_scene_parameters)

	# For additive, instantiate and add it to the root.
	elif _operation == LoadingOperation.Additive or _operation == LoadingOperation.AdditiveImmediate:
		var new_scene_instance: Node = _loaded_resource.instantiate()
		if not _scene_parameters.is_empty() and new_scene_instance.has_method("on_scene_loaded"):
			new_scene_instance.on_scene_loaded(_scene_parameters)
		get_tree().root.call_deferred("add_child", new_scene_instance)

#endregion
