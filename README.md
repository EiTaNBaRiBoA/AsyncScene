## AsyncScene - Asynchronous Scene Loader

This Godot tool provides a simple way to load scenes asynchronously, improving your game's loading times and user experience.

### Features

- Load scenes in the background without freezing the main thread.
- Replace the current scene or add the loaded scene additively.
- Choose between immediate or manual scene switching after loading.
- Track loading progress with a percentage value.
- Receive notifications upon successful or failed scene loading.

### Installation

1. Copy the `AsyncScene.gd` script into your project. 
2. Optionally, you can create a new resource type for easier access:
    - Go to **Project > Project Settings > Plugins > Resource** and click "Create a Resource Type".
    - Choose a name (e.g., "AsyncScene") and link it to the `AsyncScene.gd` script.

### Usage

**1. Loading a scene:**

```gdscript
extends Node2D

var scene : AsyncScene

func _ready() -> void:
	# Replace the current scene immediately after loading:
	scene = AsyncScene.new( "res://path/to/your/scene.tscn", AsyncScene.LoadingSceneOperation.ReplaceImmediate) 

	# Replace the current scene manually after loading (call scene.ChangeScene() later):
	# scene = AsyncScene.new("res://path/to/your/scene.tscn", AsyncScene.LoadingSceneOperation.Replace) 

	# Add the loaded scene to the current scene tree:
	# scene = AsyncScene.new("res://path/to/your/scene.tscn", AsyncScene.LoadingSceneOperation.Additive)

	# Connect to the OnComplete signal to get notified when loading is finished:
	scene.OnComplete.connect(on_scene_load_complete)

func on_scene_load_complete():
	# Do something after the scene is loaded, e.g., hide loading screen.
	pass
```

**2. Manually switching to the loaded scene (if using Replace mode):**

```gdscript
func _process(delta):
	if scene and scene.isCompleted:
		scene.ChangeScene()
```

**3. Accessing loading progress:**

```gdscript
func _process(delta):
	if scene:
		print("Loading progress: ", scene.progress, "%")
```

**4. Unloading the loaded scene:**

```gdscript
scene.UnloadScene()
```

**5. Getting the loading status:**

```gdscript
var status = scene.GetStatus() # Returns a string like "THREAD_LOAD_IN_PROGRESS", "THREAD_LOAD_LOADED", etc.
```

### Example

Check the provided `example.tscn` scene for a practical demonstration of how to use the AsyncScene tool.


This readme provides a basic overview of the AsyncScene tool and its usage. You can further customize and extend this tool to suit your specific needs. 
