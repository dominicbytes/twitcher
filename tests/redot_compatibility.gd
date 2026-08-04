extends SceneTree

const REQUIRED_SCRIPTS: PackedStringArray = [
	"res://addons/twitcher/plugin.gd",
]

const REQUIRED_SCENES: PackedStringArray = [
	"res://addons/twitcher/editor/setup/page_game_authorization.tscn",
	"res://addons/twitcher/editor/setup/page_overlay_authorization.tscn",
	"res://addons/twitcher/twitch_service.tscn",
]


func _init() -> void:
	call_deferred(&"_run_probe")


func _run_probe() -> void:
	await process_frame
	for path: String in REQUIRED_SCRIPTS:
		if load(path) == null:
			push_error("Failed to load required Twitcher script: %s" % path)
			quit(1)
			return

	for path: String in REQUIRED_SCENES:
		var scene: PackedScene = load(path)
		if scene == null:
			push_error("Failed to load required Twitcher scene: %s" % path)
			quit(1)
			return
		if path.ends_with("twitch_service.tscn"):
			var instance: Node = scene.instantiate()
			if instance.get_script() == null:
				push_error("Twitcher runtime scene root has no script: %s" % path)
				instance.free()
				quit(1)
				return
			root.add_child(instance)
			instance.queue_free()
			await process_frame
		else:
			var state: SceneState = scene.get_state()
			var root_script: Script = null
			for property_index: int in state.get_node_property_count(0):
				if state.get_node_property_name(0, property_index) == &"script":
					root_script = state.get_node_property_value(0, property_index)
					break
			if root_script == null:
				push_error("Twitcher editor scene root has no script: %s" % path)
				quit(1)
				return

	print("Twitcher Redot compatibility probe passed on Redot %s." % Engine.get_version_info().string)
	await create_timer(3.0).timeout
	quit()
