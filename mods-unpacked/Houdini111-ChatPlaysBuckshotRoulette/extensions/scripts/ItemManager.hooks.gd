class_name ItemManagerHook extends Object

const HOOK_TARGET = "res://scripts/ItemManager.gd"

const ChatPlaysModMain = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/mod_main.gd")
const GameRunner = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/GameRunner.gd")

var mod_main: ChatPlaysModMain
var game_runner: GameRunner

var enabled := false

func _init(_mod_main: ChatPlaysModMain, _game_runner: GameRunner):
	self.mod_main = _mod_main
	self.game_runner = _game_runner
	ModLoaderMod.add_hook(BeginItemGrabbing, HOOK_TARGET, "BeginItemGrabbing")
	ModLoaderMod.add_hook(EndItemGrabbing, HOOK_TARGET, "EndItemGrabbing")
	ModLoaderMod.add_hook(Counter, HOOK_TARGET, "Counter")

func BeginItemGrabbing(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	if enabled:
		game_runner.ReadyForItemGrabbing()

func EndItemGrabbing(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	if enabled:
		game_runner.StartRound()

func Counter(chain: ModLoaderHookChain, starting: bool):
	if !enabled || mod_main.game_mode == mod_main.GAME_MODE.STREAMER_VS_CHAT:
		# If disabled (vanilla) or Streamer vs Chatter (and thus streamer playing)
		#   then execute adrenaline timer as normal
		chain.execute_next_async()
	# But if chat is in control of player (Chat vs Dealer) then do not call chain to avoid adrenaline timer
