# AsyncScene - Asynchronous Scene Loader for Godot 4

This tool facilitates non-blocking scene loading in Godot. It allows you to load scenes in the background, monitor their progress, pass data to them, and transition smoothly, preventing the game from freezing.

## Features

  * **Threaded Scene Loading**: Load scenes without freezing the main thread, keeping your game responsive.
  * **Flexible Loading Operations**: Replace the current scene or add a new scene additively.
  * **Immediate or Manual Control**: Choose to switch scenes immediately upon loading or trigger the change manually after loading is complete.
  * **Progress Tracking**: Use the `OnProgressUpdate` signal to easily connect the loader to a progress bar.
  * **Robust Error Handling**: The `OnError` signal provides specific error codes and messages for easy debugging.
  * **Parameter Passing**: Send an array of data to the new scene's root script.
  * **Rich Transition Library**: A rich library of configurable transitions, including `Fade`, directional `Wipe`, directional `Slide`, and `Iris` effects.
  * **Customizable Transition Visuals**: Use solid colors or images (`Texture2D`) for transition effects like `Fade` and `Wipe`.
  * **Pausable Transitions**: Pause transitions at their midpoint for a set duration or until manually resumed, allowing for more complex loading sequences.

## How to Use

### 1\. Basic Scene Loading

Create an `AsyncScene` instance, connect to its signals, and call `start()` to begin loading. For non-immediate operations, you must call `change_scene()` when the `OnComplete` signal is fired.

```gdscript
# In the script that initiates the scene load, e.g., LevelManager.gd

# Load the next level, replacing the current scene
func _load_next_level() -> void:
	# 1. Create the loader instance
	# Pass a reference to the current scene (`self`) for easy replacement
	var loader: AsyncScene = AsyncScene.new(
		"res://path/to/your/scene.tscn",
		AsyncScene.LoadingOperation.Replace,
		self
	)

	# 2. Connect to its signals
	loader.OnProgressUpdate.connect(func(p: float): $ProgressBar.value = p)
	loader.OnComplete.connect(on_load_complete)
	loader.OnError.connect(on_load_error)

	# 3. Start the loading process
	loader.start()

func on_load_complete(loader: AsyncScene) -> void:
	print("Load complete! Changing scene now.")
	# For Replace/Additive, we must call change_scene() to trigger the change
	loader.change_scene()

func on_load_error(err_code: AsyncScene.ErrorCode, err_msg: String) -> void:
	print("Failed to load scene. Error %s: %s" % [err_code, err_msg])
	# Handle the error, e.g., show an error message
```

### 2\. Method Chaining & Advanced Configuration

You can chain configuration methods for a cleaner setup.

```gdscript
# Load a level with a custom wipe transition and pass parameters
func _load_with_options() -> void:
	var transition_image = load("res://assets/transition_texture.png")
	
	var loader := AsyncScene.new("res://level_2.tscn", AsyncScene.LoadingOperation.Replace, self) \
		.with_parameters({"player_score": 1000, "entry_point": "west_gate"}) \
		.with_transition(AsyncScene.TransitionType.WipeDown, 1.5, transition_image)

	loader.OnComplete.connect(on_load_complete)
	loader.start()
```

### 3\. Using Pausable Transitions

You can pause transitions at their midpoint, which occurs after the new scene is loaded but before the transition-out animation begins. This is useful for showing tips or waiting for player input.

#### Example A: Timed Pause

Pause for 2 seconds to display a "Level Start" message.

```gdscript
func _load_level_with_timed_pause() -> void:
	var loader := AsyncScene.new("res://level_3.tscn", AsyncScene.LoadingOperation.Replace, self) \
		.with_transition(AsyncScene.TransitionType.Iris, 2.0, Color.BLACK) \
		.with_pause(2.0) # Pause for 2 seconds at the midpoint

	# The midpoint signal fires when the screen is black and the new scene is ready
	loader.OnTransitionMidpoint.connect(func(_l): $LevelStartLabel.text = "Level 3"; $LevelStartLabel.show())
	
	# The loader automatically cleans itself up, so no need to call change_scene() here
	loader.OnComplete.connect(func(_l): $LevelStartLabel.hide())

	loader.start()
```

#### Example B: Manual Pause

Pause indefinitely and wait for the player to press a key.

```gdscript
var manual_loader: AsyncScene

func _load_level_with_manual_pause() -> void:
	$PressAnyKeyLabel.hide()
	manual_loader = AsyncScene.new("res://hub_world.tscn", AsyncScene.LoadingOperation.Replace, self) \
		.with_transition(AsyncScene.TransitionType.Fade, 1.0) \
		.with_pause(-1.0) # Pause indefinitely

	manual_loader.OnTransitionMidpoint.connect(func(_l): $PressAnyKeyLabel.show())
	manual_loader.start()

func _input(event):
	# Check if the loader exists and is waiting for input
	if event.is_action_pressed("ui_accept") and is_instance_valid(manual_loader):
		$PressAnyKeyLabel.hide()
		manual_loader.resume_transition()
```

### 4\. Receiving Parameters in the New Scene

In the root script of the scene being loaded, create a function named `on_scene_loaded` to receive any data you passed.

```gdscript
# In the script of the root node of your new scene

func on_scene_loaded(...params: Array) -> void:
	print("Scene loaded with parameters: ", params)
	# Prints: [{"player_score": 1000, "entry_point": "west_gate"}]
	var data = params[0] # Access the dictionary
	var score = data.get("player_score")
```

## API Reference

### Enums

  * `LoadingOperation`: `Replace`, `ReplaceImmediate`, `Additive`, `AdditiveImmediate`
  * `ErrorCode`: `OK`, `InvalidPath`, `LoadFailed`, `InvalidResource`
  * `TransitionType`: `None`, `Fade`, `WipeLeft`, `WipeRight`, `WipeUp`, `WipeDown`, `SlideLeft`, `SlideRight`, `SlideUp`, `SlideDown`, `Iris`

### Signals

  * `OnComplete(loader_instance: AsyncScene)`: Emitted when loading succeeds.
  * `OnError(err_code: ErrorCode, err_message: String)`: Emitted when loading fails.
  * `OnProgressUpdate(progress: float)`: Emitted frequently during loading. The progress value is between `0.0` and `100.0`.
  * `OnTransitionMidpoint(loader_instance: AsyncScene)`: Emitted when a pausable transition reaches its midpoint, after the new scene is loaded but before the screen is revealed.

### Methods

  * `with_parameters(...params: Array) -> AsyncScene`: Sets data to pass to the new scene. Returns `self` for method chaining.
  * `with_transition(type: TransitionType, duration: float, visual: Variant) -> AsyncScene`: Configures a visual transition. `visual` can be a `Color` or a `Texture2D`. Returns `self`.
  * `with_pause(duration: float = -1.0) -> AsyncScene`: Makes the transition pausable. A `duration < 0` requires a manual call to `resume_transition()`. Returns `self`.
  * `resume_transition() -> void`: Resumes a transition that was manually paused.
  * `change_scene() -> void`: Manually triggers the scene change for `Replace` and `Additive` operations.
  * `cleanup() -> void`: Removes the loader instance. This is called automatically by the loader after its work is done.
