class_name BreifcaseMachineHook extends Object

const HOOK_TARGET = "res://scripts/BriefcaseMachine.gd"

const GameRunner = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/GameRunner.gd")

const LOGNAME = "ChatPlaysBuckshotRoulette:BreifcaseMachineHook"

var game_runner: GameRunner

var enabled := false

func _init(_game_runner: GameRunner):
	self.game_runner = _game_runner
	ModLoaderMod.add_hook(MainRoutine, HOOK_TARGET, "MainRoutine")
	ModLoaderMod.add_hook(CheckLatches, HOOK_TARGET, "CheckLatches")
	
func MainRoutine(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	if enabled:
		game_runner.HandleBreifcase()
	
func CheckLatches(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	if enabled:
		game_runner.CheckLatches()
