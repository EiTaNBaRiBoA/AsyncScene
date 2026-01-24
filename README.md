# AsyncScene - Asynchronous Scene Loader for Godot 4

This tool facilitates non-blocking scene loading in Godot. It allows you to load scenes in the background, monitor their progress, pass data to them, and transition smoothly, preventing the game from freezing.

## Features

* **Threaded Scene Loading**: Load scenes without freezing the main thread, keeping your game responsive.
* **Flexible Operations**: Supports replacing the Root scene, replacing a specific child node, or adding scenes additively.
* **Manual or Immediate Switching**: Choose to switch immediately upon load completion or wait for a signal (e.g., "Press any key").
* **Progress Tracking**: Use the `progress_changed` signal to easily connect the loader to a progress bar.
* **Robust Error Handling**: The `loading_error` signal provides specific error codes and messages for easy debugging.
* **Parameter Passing**: Pass data (arguments) directly to the new scene's `on_scene_loaded` method.
* **Rich Transitions**: Built-in support for `Fade`, `Wipe` (directional), `Slide` (directional), and `Iris` effects.
* **Pausable Transitions**: Pause transitions at their midpoint (screen covered) to wait for user input or timed events. *(Supported by Fade, Wipe, and Iris)*.
* **Customizable Visuals**: Use solid colors or `Texture2D` images for transition patterns.

## Installation

1.  Copy the `async_scene.gd` script into your project.

## How to Use

### 1. Basic Scene Loading (Replace current scene)

Create an `AsyncScene` instance, connect signals, and call `start()`. For non-immediate operations (default), you must call `change_scene()` when loading completes.

```gdscript
# MainMenu.gd

func _load_next_level() -> void:
    # 1. Create the loader
    # Arguments: Path, Operation, Parent (null = Root), NodeToReplace (null = Root)
    var loader = AsyncScene.new("res://levels/level_1.tscn")

    # 2. Connect to its signals
    loader.progress_changed.connect(func(p: float): $ProgressBar.value = p)
    loader.loading_completed.connect(on_load_complete)
    loader.loading_error.connect(on_load_error)

    # 3. Start the loading process
    loader.start()

func on_load_complete(loader: AsyncScene) -> void:
    print("Load complete! Changing scene now.")
    # Trigger the actual scene swap and transition
    loader.change_scene()

func on_load_error(err_code: AsyncScene.ErrorCode, err_msg: String) -> void:
    print("Failed to load scene. Error %s: %s" % [err_code, err_msg])
    # Handle the error, e.g., show an error message

```

### 2. Replacing a Specific Node & Method Chaining

You can replace a specific child node (e.g., swapping levels inside a `LevelManager` node) and use method chaining for configuration.

```gdscript
func _swap_level_child() -> void:
    var wipe_texture = load("res://assets/transitions/wipe_mask.png")
    
    # We want to add the new scene to 'self' and remove '$CurrentLevel'
    var loader := AsyncScene.new(
        "res://levels/level_2.tscn", 
        AsyncScene.LoadingOperation.Replace, 
        self,          # Parent for the new scene
        $CurrentLevel  # The specific node to remove upon replacing
    ) \
    .with_parameters("start_checkpoint", 2, "difficulty", "hard") \
    .with_transition(AsyncScene.TransitionType.WipeRight, 1.0, wipe_texture)

    loader.loading_completed.connect(func(l): l.change_scene())
    
    # Passing 'true' adds the Loader node as a child of 'self' instead of Root.
    # Useful if you want the loader's lifecycle tied to this node.
    loader.start(true)

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
    
	# Note: Even with a transition, we must call change_scene() to swap the nodes.
    # We do this when loading completes.
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

### Public Properties (Read-Only)

These properties allow you to poll the loader's status if you prefer not to use signals.

* `progress` (float): The current loading progress, normalized between `0.0` and `1.0`.
* `is_completed` (bool): Returns `true` if the resource loading has finished successfully.
* `error_code` (ErrorCode): Holds the last error code encountered. Defaults to `ErrorCode.OK`.

### Signals

* **loading_completed(loader_instance: AsyncScene)**
    Emitted when the resource is fully loaded and ready.
* **loading_error(err_code: ErrorCode, err_message: String)**
    Emitted if the loading process fails.
* **progress_changed(progress: float)**
    Emitted periodically. **Note:** Returns a percentage value between `0.0` and `100.0` (unlike the `progress` property which is 0-1).
* **transition_midpoint_reached(loader_instance: AsyncScene)**
    Emitted when a pausable transition (Fade/Wipe/Iris) covers the screen completely.

### Enums

#### LoadingOperation
Determines how the new scene is handled relative to the scene tree.
* `Replace`: Removes the old scene but waits for `change_scene()` to swap them.
* `ReplaceImmediate`: Swaps scenes immediately upon load completion.
* `Additive`: Instantiates the new scene but waits for `change_scene()` to add it.
* `AdditiveImmediate`: Adds the new scene immediately upon load completion.

#### ErrorCode
* `OK` (0): No error.
* `InvalidPath` (1): The path provided to `new()` does not exist.
* `LoadFailed` (2): `ResourceLoader` failed to start or complete the thread.
* `InvalidResource` (3): The loaded file is not a valid `PackedScene`.

#### TransitionType
* `None`
* `Fade`
* `WipeLeft`, `WipeRight`, `WipeUp`, `WipeDown`
* `SlideLeft`, `SlideRight`, `SlideUp`, `SlideDown` *(Not Pausable)*
* `Iris`

### Methods

* `new(path: String, operation: LoadingOperation, parent: Node, current_scene: Node)`: Constructor.
* `start(add_to_parent: bool)`: Starts the background thread.
* `change_scene()`: Finalizes the scene swap/add.
* `with_parameters(...args)`: Passes data to the new scene.
* `with_transition(type, duration, visual)`: Configures the transition.
* `with_pause(duration)`: Configures the transition pause (Fade/Wipe/Iris only).
* `resume_transition()`: Resumes a manually paused transition.
* `cleanup()`: Frees the loader. Called automatically after transition/loading ends.
