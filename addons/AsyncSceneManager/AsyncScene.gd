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
	Fade, ## A simple fade-to-color-and-back transition.
	WipeLeft, ## A color bar wipes from right to left, revealing the new scene.
	WipeRight, ## A color bar wipes from left to right, revealing the new scene.
	WipeUp, ## A color bar wipes from bottom to top, revealing the new scene.
	WipeDown, ## A color bar wipes from top to bottom, revealing the new scene.
	SlideLeft, ## The old scene slides out to the left as the new one slides in.
	SlideRight, ## The old scene slides out to the right as the new one slides in.
	SlideUp, ## The old scene slides out to the top as the new one slides in.
	SlideDown, ## The old scene slides out to the bottom as the new one slides in.
	Iris ## A circular iris opens to reveal the new scene.
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
	match _transition_type:
		TransitionType.Fade:
			_fade_out_and_change()
		TransitionType.WipeLeft, TransitionType.WipeRight, TransitionType.WipeUp, TransitionType.WipeDown:
			_wipe_and_change()
		TransitionType.SlideLeft, TransitionType.SlideRight, TransitionType.SlideUp, TransitionType.SlideDown:
			_slide_and_change()
		TransitionType.Iris:
			_iris_and_change()
		_: # This handles TransitionType.None
			_change_scene_logic()
			# The loader's job is done for non-transition changes.
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

#region Transitions

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
	cleanup()


func _wipe_and_change() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 128
	var rect: ColorRect = ColorRect.new()
	rect.color = _transition_color
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	rect.size = viewport_size
	canvas.add_child(rect)
	get_tree().root.add_child(canvas)

	var start_pos: Vector2
	var mid_pos: Vector2 = Vector2.ZERO
	var end_pos: Vector2

	match _transition_type:
		TransitionType.WipeLeft:
			start_pos = Vector2(viewport_size.x, 0)
			end_pos = Vector2(-viewport_size.x, 0)
		TransitionType.WipeRight:
			start_pos = Vector2(-viewport_size.x, 0)
			end_pos = Vector2(viewport_size.x, 0)
		TransitionType.WipeUp:
			start_pos = Vector2(0, viewport_size.y)
			end_pos = Vector2(0, -viewport_size.y)
		TransitionType.WipeDown:
			start_pos = Vector2(0, -viewport_size.y)
			end_pos = Vector2(0, viewport_size.y)

	rect.position = start_pos

	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(rect, "position", mid_pos, _transition_duration / 2.0)
	tween.tween_callback(_change_scene_logic)
	tween.tween_interval(0.05) # Give a moment for the scene change to register
	tween.tween_property(rect, "position", end_pos, _transition_duration / 2.0)

	await tween.finished
	canvas.queue_free()
	cleanup()


func _slide_and_change() -> void:
	var old_scene_tex: Texture2D = get_viewport().get_texture()

	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 128
	
	var old_scene_rect: TextureRect = TextureRect.new()
	old_scene_rect.texture = old_scene_tex
	old_scene_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(old_scene_rect)
	
	var new_scene_rect: TextureRect = TextureRect.new()
	new_scene_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(new_scene_rect)
	
	get_tree().root.add_child(canvas)

	_change_scene_logic()
	await get_tree().process_frame
	
	var new_scene_tex: Texture2D = get_viewport().get_texture()
	new_scene_rect.texture = new_scene_tex

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var old_scene_end_pos: Vector2
	var new_scene_start_pos: Vector2
	var new_scene_end_pos: Vector2 = Vector2.ZERO

	match _transition_type:
		TransitionType.SlideLeft:
			old_scene_end_pos = Vector2(-viewport_size.x, 0)
			new_scene_start_pos = Vector2(viewport_size.x, 0)
		TransitionType.SlideRight:
			old_scene_end_pos = Vector2(viewport_size.x, 0)
			new_scene_start_pos = Vector2(-viewport_size.x, 0)
		TransitionType.SlideUp:
			old_scene_end_pos = Vector2(0, -viewport_size.y)
			new_scene_start_pos = Vector2(0, viewport_size.y)
		TransitionType.SlideDown:
			old_scene_end_pos = Vector2(0, viewport_size.y)
			new_scene_start_pos = Vector2(0, -viewport_size.y)
	
	new_scene_rect.position = new_scene_start_pos

	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(old_scene_rect, "position", old_scene_end_pos, _transition_duration)
	tween.tween_property(new_scene_rect, "position", new_scene_end_pos, _transition_duration)
	
	await tween.finished
	
	canvas.queue_free()
	cleanup()


func _iris_and_change() -> void:
	var iris_shader_code: String = """
shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float progress : hint_range(0.0, 1.0); // 0.0 = transparent, 1.0 = opaque
uniform float smoothness : hint_range(0.0, 0.5) = 0.05;

void fragment() {
	float dist_from_center = distance(UV, vec2(0.5));
	float radius = (1.0 - progress) * 0.75; // 0.75 is slightly > diagonal dist
	float value = smoothstep(radius, radius + smoothness, dist_from_center);
	COLOR = vec4(color.rgb, value);
}
"""
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 128
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var shader: Shader = Shader.new()
	shader.code = iris_shader_code
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	
	material.set_shader_parameter("color", _transition_color)
	material.set_shader_parameter("progress", 0.0)
	rect.material = material
	
	canvas.add_child(rect)
	get_tree().root.add_child(canvas)

	var tween_close: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_close.tween_property(material, "shader_parameter/progress", 1.0, _transition_duration / 2.0)
	await tween_close.finished

	_change_scene_logic()
	await get_tree().process_frame

	var tween_open: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_open.tween_property(material, "shader_parameter/progress", 0.0, _transition_duration / 2.0)
	await tween_open.finished

	canvas.queue_free()
	cleanup()

#endregion
