extends Object

# For "res://scripts/IntroManager.gd"
#  Cannot extend directly because IntroManager is a declared class_name and so can't be a script extension
#  As such, we need to use script hooks, and those use different method signatures

const HOOK_TARGET = "res://scripts/IntroManager.gd"

const LOGNAME = "ChatPlaysBuckshotRoulette:IntroInterface"

func _init() -> void:
	ModLoaderMod.add_hook(my_ready, HOOK_TARGET, "_ready")
	ModLoaderMod.add_hook(MainBathroomStart, HOOK_TARGET, "MainBathroomStart")

func my_ready(chain: ModLoaderHookChain):
	ModLoaderLog.info("IntroInterface my_read START", LOGNAME)
	chain.execute_next()
	ModLoaderLog.info("IntroInterface my_read END", LOGNAME)

func MainBathroomStart(chain: ModLoaderHookChain):
	ModLoaderLog.info("MainBathroomStart START", LOGNAME)
	chain.execute_next()
	ModLoaderLog.info("MainBathroomStart END", LOGNAME)
