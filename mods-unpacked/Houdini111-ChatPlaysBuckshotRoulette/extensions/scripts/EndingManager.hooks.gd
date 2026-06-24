class_name EndingManagerHook extends Object

const HOOK_TARGET = "res://scripts/EndingManager.gd"

const LOGNAME = "ChatPlaysBuckshotRoulette:EndingManagerHook"

func _init():
	ModLoaderMod.add_hook(BeginEnding, HOOK_TARGET, "BeginEnding")
	
func BeginEnding(chain: ModLoaderHookChain):
	ModLoaderLog.info("Starting ending", LOGNAME)
	await chain.execute_next_async()
	ModLoaderLog.debug("Ending cutscene finished. Waiting for EndingManager to be awaiting input", LOGNAME)
	var manager = chain.reference_object as EndingManager
	while !manager.waitingForInput:
		await manager.get_tree().create_timer(0.1).timeout
	ModLoaderLog.debug("EndingManager waiting for input. Sending input to it now", LOGNAME)
	var custom_input = InputEventAction.new()
	custom_input.pressed = true
	manager._unhandled_input(custom_input)
	ModLoaderLog.debug("Ending finish key sent", LOGNAME)
