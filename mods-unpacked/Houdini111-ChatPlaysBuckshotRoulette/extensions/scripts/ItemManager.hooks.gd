class_name ItemManagerHook extends Object

const HOOK_TARGET = "res://scripts/ItemManager.gd"

const GameRunner = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/GameRunner.gd")

var game_runner: GameRunner

func _init(_game_runner: GameRunner):
	self.game_runner = _game_runner
	ModLoaderMod.add_hook(BeginItemGrabbing, HOOK_TARGET, "BeginItemGrabbing")
	ModLoaderMod.add_hook(EndItemGrabbing, HOOK_TARGET, "EndItemGrabbing")
	ModLoaderMod.add_hook(Counter, HOOK_TARGET, "Counter")
	ModLoaderMod.add_hook(SetupItemSteal, HOOK_TARGET, "SetupItemSteal")

func BeginItemGrabbing(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	game_runner.StartGrabbingItems()

func EndItemGrabbing(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	game_runner.StartRound()

func Counter(chain: ModLoaderHookChain, starting: bool):
	# Do NOT call chain. 
	# We want to avoid the adrenaline timeout explicitly 
	# Because chat needs time to decide what to steal
	pass

func SetupItemSteal(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	# Switching to checking for ItemInteraction.stealing in StartPlayerTurn
#	game_runner.HandleAdrenalineUse()

