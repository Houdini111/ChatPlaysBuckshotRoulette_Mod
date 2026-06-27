class_name DialogueManagerHook extends Object

const HOOK_TARGET = "res://scripts/DialogueManager.gd"

const LOGNAME = "ChatPlaysBuckshotRoulette:DialogueManagerHook"

const ChatPlaysModMain = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/mod_main.gd")

var mod_main: ChatPlaysModMain
var enabled := false
var new_message := ""

func _init(_mod_main: ChatPlaysModMain):
	self.mod_main = _mod_main
	ModLoaderMod.add_hook(ShowText_Forever, HOOK_TARGET, "ShowText_Forever")

func ShowText_Forever(chain: ModLoaderHookChain, text: String) -> void:
	ModLoaderLog.info("DialogueManager showing text forever '%s'" % text, LOGNAME)
	if !enabled:
		ModLoaderLog.info("DialogueManagerHook disabled. Just going as normal", LOGNAME)
		await chain.execute_next_async([text])
		return
	if mod_main.game_mode == mod_main.GAME_MODE.STREAMER_VS_CHAT:
		if text == tr("INTERESTING"):
			var new_text = new_message if new_message != "" else "ERROR. NO NEW MESSAGE."
			await chain.execute_next_async([new_text])
			new_text = ""
			return
	await chain.execute_next_async([text])
	
