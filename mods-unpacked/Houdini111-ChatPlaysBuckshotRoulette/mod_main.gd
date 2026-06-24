class_name ChatPlaysModMain extends Node

const MOD_ID = "Houdini111-ChatPlaysBuckshotRoulette"
const LOGNAME = "ChatPlaysBuckshotRoulette:mod_main"

var mod_dir_path := ""

var manifest: ModManifest
var mod_data: ModData

const SceneChangeHook = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/extensions/scripts/SceneChangeNotification.hooks.gd")
const IntroManagerHook = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/extensions/scripts/IntroManager.hooks.gd")
const SignatureManagerHook = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/extensions/scripts/SignatureManager.hooks.gd")
const ItemManagerHook = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/extensions/scripts/ItemManager.hooks.gd")
const RoundManagerHook = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/extensions/scripts/RoundManager.hooks.gd")
const ChatPlaysOptionsMenu = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/ui/options_menu.gd")
const Scripter = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/Scripter.gd")
const GameRunner = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/GameRunner.gd")
const TwitchBot = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/TwitchBot.gd")
const MenuManager = preload("res://scripts/MenuManager.gd")
const StatusMessages = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/ui/StatusMessages.gd")
const BreifcaseMachineHook = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/extensions/scripts/BriefcaseMachine.hooks.gd")
const EndingManagerHook = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/extensions/scripts/EndingManager.hooks.gd")


var scene_change_hook: SceneChangeHook
var intro_manager_hook: IntroManagerHook
var signature_manager_hook: SignatureManagerHook
var item_manager_hook: ItemManagerHook
var round_manager_hook: RoundManagerHook
var breifcase_machine_hook: BreifcaseMachineHook
var ending_manager_hook: EndingManagerHook

var options_menu: ChatPlaysOptionsMenu

var scripter: Scripter
var game_runner: GameRunner
var twitch_bot: TwitchBot
var status_messages: StatusMessages

var dialogueListeners:= {}

func _init() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir()+(MOD_ID)
	mod_data = ModLoaderMod.get_mod_data(MOD_ID)
	if (ModLoaderConfig.has_config(MOD_ID, "user")):
		var userConfig = ModLoaderConfig.get_config(MOD_ID, "user")
		ModLoaderConfig.set_current_config(userConfig)
	
	Engine.register_singleton("ChatPlaysModMain", self)

	status_messages = StatusMessages.new()
	status_messages.name = "StatusMessages"
	self.add_child.call_deferred(status_messages)
	status_messages.z_index = 1000
	Engine.register_singleton("StatusMessages", status_messages)

	scene_change_hook = await SceneChangeHook.new(self)

	twitch_bot = TwitchBot.new(self)
	twitch_bot.name = "TwitchBot"
	self.add_child.call_deferred(twitch_bot)
	
	await PrepareScenes()
	ModLoaderLog.info("ChatPlaysBuckshotRoulette init done", LOGNAME)

func PrepareScenes():
	await PrepareMenu()
	await PrepareMain()

func HandleSceneChange(scene_name: String, scene_root: Node) -> void:
	ModLoaderLog.info("ChatPlays detected scene change to '%s'" % scene_name, LOGNAME)
	game_runner.HandleSceneChange(scene_name)
	twitch_bot.HandleSceneChange(scene_name)
	match scene_name:
		"menu":
			ChangeToSceneMenu(scene_root)
		"main":
			ChangeToSceneMain(scene_root)

func PrepareMenu():
	if (options_menu == null):
		options_menu = ChatPlaysOptionsMenu.new(self, twitch_bot)
		options_menu.name = "ChatPlaysOptionsMenu"
		add_child.call_deferred(options_menu)

func PrepareMain():
	if (scripter == null):
		scripter = await Scripter.new(self, twitch_bot)
		scripter.name = "Scripter"
		add_child.call_deferred(scripter)
	if (game_runner == null):
		game_runner = await GameRunner.new(self, twitch_bot)
		game_runner.name = "GameRunner"
		add_child.call_deferred(game_runner)
	if (intro_manager_hook == null):
		intro_manager_hook = await IntroManagerHook.new(scripter)
	if (signature_manager_hook == null):
		signature_manager_hook = await SignatureManagerHook.new(scripter)
	if (item_manager_hook == null):
		item_manager_hook = await ItemManagerHook.new(game_runner)
	if (round_manager_hook == null):
		round_manager_hook = await RoundManagerHook.new(game_runner)
	if (breifcase_machine_hook == null):
		breifcase_machine_hook = await BreifcaseMachineHook.new(game_runner)
	if (ending_manager_hook == null):
		ending_manager_hook = await EndingManagerHook.new()

func ChangeToSceneMain(scene_root: Node):
	ModLoaderLog.info("Doing changes to prepare for main scene", LOGNAME)
	game_runner.RefreshSceneHooks(scene_root)
	scripter.HandleSceneChange(scene_root)

func ChangeToSceneMenu(scene_root: Node):
	ModLoaderLog.info("Doing changes to prepare for menu scene", LOGNAME)
	options_menu.MakeMenuModifications(scene_root)
