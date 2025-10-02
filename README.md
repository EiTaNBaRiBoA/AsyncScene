# AsyncScene - Asynchronous Scene Loader for Godot 4

This tool facilitates non-blocking scene loading in Godot. 
It allows you to load scenes in the background, monitor their progress, pass data to them, and transition smoothly, preventing the game from freezing.

## Features

  * **Threaded Scene Loading**: Load scenes without freezing the main thread, keeping your game responsive.
  * **Flexible Loading Operations**: Replace the current scene or add a new scene additively.
  * **Immediate or Manual Control**: Choose to switch scenes immediately upon loading or trigger the change manually.
  * **Progress Tracking**: Use the `OnProgressUpdate` signal to easily connect the loader to a progress bar or UI element.
  * **Robust Error Handling**: The `OnError` signal provides specific error codes and messages for easy debugging.
  * **Parameter Passing**: Send a parameters of data to the new scene's root script.
  * **Built-in Transitions**: Includes a simple, configurable fade-to-black transition.


## How to Use

### 1\. Create and Configure the Loader

In the script that will initiate the scene change, create a new `AsyncScene` instance. Use the methods `with_parameters()` and `with_transition()` to configure it.

**In the script that initiates the scene load, e.g., `LevelManager.gd`**

```gdscript
# In the script that initiates the scene load, e.g., LevelManager.gd

func _load_next_level() -> void:
    # 1. Create the loader and configure it
    var loader: AsyncScene = AsyncScene.new(
        "res://path/to/your/scene.tscn",
        AsyncScene.LoadingOperation.Replace,
		self # reference of the current scene for replacement (optional)
    )
    # optional: Sending parameters to the new scene when changed
    loader.with_parameters({"player_score": 1000, "entry_point": "west_gate"})
    loader.with_transition(AsyncScene.TransitionType.Fade, 1.0, Color.BLACK)

    # 2. Connect to its signals
    loader.OnProgressUpdate.connect(func(p: float) -> void: $ProgressBar.value = p)
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
```

### 2\. Receive Parameters in the New Scene

In the root script of the scene being loaded (`your/scene.tscn`), create a function named `on_scene_loaded` to receive any data you passed.

**In the script of the root node of `your/scene.tscn`**

```gdscript
func on_scene_loaded(...params: Array) -> void:
	print("Scene loaded with parameters: ", params)
	# Prints [{"player_score": 1000, "entry_point": "west_gate"}]
```


## API Reference

### Enums

  * `LoadingOperation`: `Replace`, `ReplaceImmediate`, `Additive`, `AdditiveImmediate`
  * `ErrorCode`: `OK`, `InvalidPath`, `LoadFailed`, `InvalidResource`
  * `TransitionType`: `None`, `Fade`

### Signals

  * `OnComplete(loader_instance: AsyncScene)`: Emitted when loading succeeds.
  * `OnError(err_code: ErrorCode, err_message: String)`: Emitted when loading fails.
  * `OnProgressUpdate(progress: float)`: Emitted frequently during loading. The progress value is between `0.0` and `100.0`.

### Methods

  * `with_parameters(...params: Array) -> void`: Sets data to pass to the new scene.
  * `with_transition(type: TransitionType, duration: float, color: Color) -> void`: Configures a visual transition.
  * `change_scene() -> void`: Manually triggers the scene change for `Replace` and `Additive` operations.
  * `cleanup() -> void`: Removes the loader instance from the tree. This is called automatically after a transition.
