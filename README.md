# AsyncScene - Asynchronous Scene Loader for Godot 4

This tool facilitates non-blocking scene loading in Godot. It allows you to load scenes in the background, monitor their progress, pass data to them, and transition smoothly, preventing the game from freezing.

## Features

* **Threaded Scene Loading**: Load scenes without freezing the main thread, keeping your game responsive.
* **Flexible Loading Operations**: Replace the current scene (Root or Sub-scene) or add a new scene additively.
* **Immediate or Manual Control**: Choose to switch scenes immediately upon loading or trigger the change manually after loading is complete.
* **Progress Tracking**: Use the `progress_changed` signal to easily connect the loader to a progress bar.
* **Robust Error Handling**: The `loading_error` signal provides specific error codes and messages for easy debugging.
* **Parameter Passing**: Send data to the new scene's root script.
* **Rich Transition Library**: A rich library of configurable transitions, including `Fade`, directional `Wipe`, directional `Slide`, and `Iris` effects.
* **Customizable Transition Visuals**: Use solid colors or images (`Texture2D`) for transition effects like `Fade` and `Wipe`.
* **Pausable Transitions**: Pause transitions at their midpoint for a set duration or until manually resumed, allowing for more complex loading sequences.

## How to Use

### 1. Basic Scene Loading

Create an `AsyncScene` instance, connect to its signals, and call `start()` to begin loading. For non-immediate operations, you must call `change_scene()` when the `loading_completed` signal is fired.

```gdscript
# In the script that initiates the scene load, e.g., MainMenu.gd

# Load the next level, replacing the current scene root
func _load_next_level() -> void:
    # 1. Create the loader instance
    # Defaults: Replace operation, no parent (replaces Root), no current_scene reference needed for Root replacement.
    var loader: AsyncScene = AsyncScene.new(
			scene_path,
			AsyncScene.LoadingOperation.Replace,
			self
	)

    # 2. Connect to its signals
    loader.progress_changed.connect(func(p: float): $ProgressBar.value = p)
    loader.loading_completed.connect(on_load_complete)
    loader.loading_error.connect(on_load_error)

    # 3. Start the loading process
    loader.start()

func on_load_complete(loader: AsyncScene) -> void:
    print("Load complete! Changing scene now.")
    # For Replace/Additive (non-immediate), we must call change_scene() to trigger the change
    loader.change_scene()

func on_load_error(err_code: AsyncScene.ErrorCode, err_msg: String) -> void:
    print("Failed to load scene. Error %s: %s" % [err_code, err_msg])
    # Handle the error, e.g., show an error message

```

### 2. Method Chaining & Advanced Configuration

You can chain configuration methods for a cleaner setup.

```gdscript
# Load a level with a custom wipe transition and pass parameters
func _load_with_options() -> void:
    var transition_image = load("res://assets/transition_texture.png")
    
    # Example: Replacing a specific child node (current_level) within a LevelManager
    # Signature: new(path, operation, parent_node, node_to_replace)
    var loader := AsyncScene.new(
        "res://level_2.tscn", 
        AsyncScene.LoadingOperation.Replace, 
        self, 
        $CurrentLevel
    ) \
    .with_parameters("player_score", 1000, "entry_point", "west_gate") \
    .with_transition(AsyncScene.TransitionType.WipeDown, 1.5, transition_image)

    loader.loading_completed.connect(on_load_complete)
    loader.start(true) # Pass true to add the loader to 'self' (the parent defined in new())

```

### 3. Using Pausable Transitions

You can pause transitions at their midpoint, which occurs after the new scene is loaded but before the transition-out animation begins. This is useful for showing tips or waiting for player input.

#### Example A: Timed Pause

Pause for 2 seconds to display a "Level Start" message.

```gdscript
func _load_level_with_timed_pause() -> void:
    var loader := AsyncScene.new("res://level_3.tscn") \
        .with_transition(AsyncScene.TransitionType.Iris, 2.0, Color.BLACK) \
        .with_pause(2.0) # Pause for 2 seconds at the midpoint

    # The midpoint signal fires when the screen is black and the new scene is ready
    loader.transition_midpoint_reached.connect(func(_l): 
        $LevelStartLabel.text = "Level 3"
        $LevelStartLabel.show()
    )
    
    # The loader automatically cleans itself up, so no need to call change_scene() here if it's automatic?
    # Note: If operation is Replace (default), you still need to call change_scene() 
    # usually inside loading_completed. The transition handles the visual, 
    # but change_scene() swaps the nodes.
    loader.loading_completed.connect(func(l): l.change_scene())
    
    loader.start()

```

#### Example B: Manual Pause

Pause indefinitely and wait for the player to press a key.

```gdscript
var manual_loader: AsyncScene

func _load_level_with_manual_pause() -> void:
    $PressAnyKeyLabel.hide()
    manual_loader = AsyncScene.new("res://hub_world.tscn") \
        .with_transition(AsyncScene.TransitionType.Fade, 1.0) \
        .with_pause(-1.0) # Pause indefinitely

    manual_loader.transition_midpoint_reached.connect(func(_l): $PressAnyKeyLabel.show())
    manual_loader.loading_completed.connect(func(l): l.change_scene())
    manual_loader.start()

func _input(event):
    # Check if the loader exists and is waiting for input
    if event.is_action_pressed("ui_accept") and is_instance_valid(manual_loader):
        $PressAnyKeyLabel.hide()
        manual_loader.resume_transition()

```

### 4. Receiving Parameters in the New Scene

In the root script of the scene being loaded, create a function named `on_scene_loaded` to receive any data you passed. The data is passed as a single Array argument.

```gdscript
# In the script of the root node of your new scene

func on_scene_loaded(params: Array) -> void:
    print("Scene loaded with parameters: ", params)
    # If you called: .with_parameters("score", 100)
    # params is: ["score", 100]
    
    var param_key = params[0]
    var param_value = params[1]

```

## API Reference

### Enums

* `LoadingOperation`: `Replace`, `ReplaceImmediate`, `Additive`, `AdditiveImmediate`
* `ErrorCode`: `OK`, `InvalidPath`, `LoadFailed`, `InvalidResource`
* `TransitionType`: `None`, `Fade`, `WipeLeft`, `WipeRight`, `WipeUp`, `WipeDown`, `SlideLeft`, `SlideRight`, `SlideUp`, `SlideDown`, `Iris`

### Signals

* `loading_completed(loader_instance: AsyncScene)`: Emitted when loading succeeds.
* `loading_error(err_code: ErrorCode, err_message: String)`: Emitted when loading fails.
* `progress_changed(progress: float)`: Emitted frequently during loading. The progress value is between `0.0` and `100.0`.
* `transition_midpoint_reached(loader_instance: AsyncScene)`: Emitted when a pausable transition reaches its midpoint, after the new scene is loaded but before the screen is revealed.

### Methods

* `with_parameters(...params: Array) -> AsyncScene`: Sets data to pass to the new scene. Returns `self` for method chaining.
* `with_transition(type: TransitionType, duration: float, visual: Variant) -> AsyncScene`: Configures a visual transition. `visual` can be a `Color` or a `Texture2D`. Returns `self`.
* `with_pause(duration: float = -1.0) -> AsyncScene`: Makes the transition pausable. A `duration < 0` requires a manual call to `resume_transition()`. Returns `self`.
* `resume_transition() -> void`: Resumes a transition that was manually paused.
* `change_scene() -> void`: Manually triggers the scene change for `Replace` and `Additive` operations.
* `cleanup() -> void`: Removes the loader instance. This is called automatically by the loader after its work is done.
