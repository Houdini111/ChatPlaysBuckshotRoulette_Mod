class_name DealerIntelligenceHook extends Object

const HOOK_TARGET = "res://scripts/DealerIntelligence.gd"

const LOGNAME = "ChatPlaysBuckshotRoulette:DealerIntelligenceHook"

const ChatPlaysModMain = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/mod_main.gd")
const GameRunner = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/GameRunner.gd")

var mod_main: ChatPlaysModMain
var game_runner: GameRunner

var enabled := false

func _init(_mod_main: ChatPlaysModMain, _game_runner: GameRunner):
	self.mod_main = _mod_main
	self.game_runner = _game_runner
	ModLoaderMod.add_hook(DealerChoice, HOOK_TARGET, "DealerChoice")
	ModLoaderMod.add_hook(EndTurnMain, HOOK_TARGET, "EndTurnMain")
	
func DealerChoice(chain: ModLoaderHookChain):
	ModLoaderLog.info("Dealer making a choice", LOGNAME)
	if !enabled:
		ModLoaderLog.info("Hook disabled. Continuing as normal", LOGNAME)
		await chain.execute_next_async()
		return
	if self.mod_main.game_mode == self.mod_main.GAME_MODE.STREAMER_VS_CHAT:
		# If chat is controlling dealer, do chat turn
		game_runner.StartChatDealerTurn()
	else:
		# If vanilla or chat controls player, let dealer act as normal
		await chain.execute_next_async()

func EndTurnMain(chain: ModLoaderHookChain):
	ModLoaderLog.info("Ending dealer turn", LOGNAME)
	if enabled:
		game_runner.EndingDealerTurn()
	await chain.execute_next_async()
	
