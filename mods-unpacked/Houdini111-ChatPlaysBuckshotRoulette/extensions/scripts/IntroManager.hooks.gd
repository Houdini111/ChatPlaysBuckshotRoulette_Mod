class_name IntroManagerHook extends Object
# For "res://scripts/IntroManager.gd"
#  Cannot extend directly because IntroManager is a declared class_name and so can't be a script extension
#  As such, we need to use script hooks, and those use different method signatures

const HOOK_TARGET = "res://scripts/IntroManager.gd"

const LOGNAME = "ChatPlaysBuckshotRoulette:IntroInterface"

const Scripter = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/Scripter.gd")

var scripter: Scripter

var enabled := false

func _init(_scripter: Scripter) -> void:
	self.scripter = _scripter
	ModLoaderMod.add_hook(MainBathroomStart, HOOK_TARGET, "MainBathroomStart")

func MainBathroomStart(chain: ModLoaderHookChain):
	ModLoaderLog.info("IntroManager MainBathroom Start hook triggered", LOGNAME)
	await chain.execute_next_async()
	if enabled:
		scripter.StartGameFromBathroom()
