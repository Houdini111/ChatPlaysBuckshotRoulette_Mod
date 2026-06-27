class_name HealthCounterHook extends Object

const HOOK_TARGET = "res://scripts/HealthCounter.gd"

const LOGNAME = "ChatPlaysBuckshotRoulette:HealthCounterHook"

var enabled := false

func _init():
	ModLoaderMod.add_hook(UpdateDisplayRoutineCigarette_Enemy, HOOK_TARGET, "UpdateDisplayRoutineCigarette_Enemy")
	
func UpdateDisplayRoutineCigarette_Enemy(chain: ModLoaderHookChain):
	await chain.execute_next_async()
