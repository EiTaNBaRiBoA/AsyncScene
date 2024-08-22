## AsyncScene - Asynchronous Scene Loader

This Godot tool simplifies loading scenes asynchronously, improving game loading times and enhancing the user experience.

### Features

- **Background Loading:** Load scenes without freezing the main thread, keeping your game responsive.
- **Flexible Loading Options:** Replace the current scene, add the loaded scene additively, or control loading behavior using different operation types.
- **Control over Scene Changes:** Choose to switch scenes immediately after loading or manually initiate the scene change.
- **Progress Tracking:** Monitor the loading progress with a percentage value to provide feedback to the player.
- **Load Completion Notifications:** Receive signals when scene loading is complete, successful, or failed, allowing for flexible handling.

### Usage

**1. Initializing the AsyncScene:**

```gdscript
extends Node2D

var scene : AsyncScene

func _ready() -> void:
	# Replace the current scene immediately after loading:
	scene = AsyncScene.new("res://path/to/your/scene.tscn", AsyncScene.LoadingSceneOperation.ReplaceImmediate)

	# Replace the current scene manually after loading (call scene.ChangeScene() later):
	# scene = AsyncScene.new("res://path/to/your/scene.tscn", AsyncScene.LoadingSceneOperation.Replace) 

	# Add the loaded scene to the current scene tree:
	# scene = AsyncScene.new("res://path/to/your/scene.tscn", AsyncScene.LoadingSceneOperation.Additive)

	# Add the loaded scene to the current scene tree immediately:
	# scene = AsyncScene.new("res://path/to/your/scene.tscn", AsyncScene.LoadingSceneOperation.AdditiveImmediate)

	# Connect to the OnComplete signal to get notified when loading is finished:
	scene.OnComplete.connect(on_scene_load_complete)
```

**2. Handling Scene Changes (Replace and Additive Operations):**

```gdscript
func on_scene_load_complete():
	# If using Replace or Additive operations, call ChangeScene() to finalize the scene change
	scene.ChangeScene()

	# Do something after the scene is loaded, e.g., hide loading screen.
	pass
```


```gdscript
func _process(delta):
	if scene and scene.isCompleted:
		scene.ChangeScene()
```


**3. Monitoring Loading Progress:**

```gdscript
func _process(delta):
	if scene:
		print("Loading progress: ", scene.progress, "%")
```

**4. Unloading the Loaded Scene:**

```gdscript
scene.UnloadScene()
```

**5. Checking Loading Status:**

```gdscript
var status = scene.GetStatus()  # Returns a string like "THREAD_LOAD_IN_PROGRESS", "THREAD_LOAD_LOADED", etc.
```

### Example

Check the `example` folder for a practical demonstration of how to use the `AsyncScene` tool.

### Additional Notes

- This tool can be further customized and extended to fit your specific needs.
- You can incorporate loading bars, progress indicators, or other visual elements to provide a better loading experience for your players.
- Consider using `LoadingSceneOperation.ReplaceImmediate` for smooth transitions between scenes, while `LoadingSceneOperation.Replace` allows for more control over when the scene change occurs.
- Remember to call `ChangeScene()` only if you're using `LoadingSceneOperation.Replace` or `LoadingSceneOperation.Additive` for the scene change to take effect.
