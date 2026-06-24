class_name RoundManagerHook extends Object

const HOOK_TARGET = "res://scripts/RoundManager.gd"

const GameRunner = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/GameRunner.gd")

var game_runner: GameRunner

func _init(_game_runner: GameRunner):
	self.game_runner = _game_runner
	ModLoaderMod.add_hook(SetupDeskUI, HOOK_TARGET, "SetupDeskUI")
	ModLoaderMod.add_hook(BeginScoreLerp, HOOK_TARGET, "BeginScoreLerp")

func SetupDeskUI(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	game_runner.StartPlayerTurn()

func BeginScoreLerp(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	game_runner.HandleDoubleOrNothing()
