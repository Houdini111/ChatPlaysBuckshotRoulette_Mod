class_name Scripter extends Node

const LOGNAME = "ChatPlaysBuckshotRoulette:IntroInterface"

const ALPHABET = "abcdefghijklmnopqrstuvwxyz"

const ChatPlaysModMain = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/mod_main.gd")
const TwitchBot = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/TwitchBot.gd")

var mod_main: ChatPlaysModMain
var twitch_bot: TwitchBot
var intro_manager: IntroManager
var signature_manager: Signature
var interaction_manager: InteractionManager
var waiver_button_interaction_branches := {}
var dealer_name_label: Label3D

var enabled: bool = false

func _init(_mod_main: ChatPlaysModMain, _twitch_bot: TwitchBot): 
	self.mod_main = _mod_main
	self.twitch_bot = _twitch_bot

func Disable() -> void:
	self.enabled = false

func Enable() -> void:
	self.enabled = true

# TODO: Make option of automated game handling outside of decisions. One for Chat vs Dealer, one for Streamer vs Chat

func HandleSceneChange(scene_root: Node):
	ModLoaderLog.info("Scripter handling scene change", LOGNAME)
	if !enabled: 
		ModLoaderLog.info("Scripter disabled. Ignoring", LOGNAME)
		return
	if (scene_root.name == "main"):
		intro_manager = scene_root.find_child("intro manager") as IntroManager
		signature_manager = scene_root.find_child("signature manager") as Signature
		interaction_manager = scene_root.find_child("interaction manager") as InteractionManager
		dealer_name_label = scene_root.find_child("text_dealer") as Label3D
		
		FindWaiverButtons(scene_root)
	
		# Check if intro already happened
		if (intro_manager.btn_bathroomdoor.visible):
			ModLoaderLog.info("Script's HandleSceneChange was slow. Detected that bathroom load cutscene already complete. Starting intro script", LOGNAME)
			StartGameFromBathroom()
	
func FindWaiverButtons(scene_root):
	if !enabled: 
		ModLoaderLog.info("Scripter disabled. Ignoring", LOGNAME)
		return
	var waiver_buttons_root = scene_root.find_child("signature machine main parent").find_child("button colliders parent") as Node
	for letter in ALPHABET:
		var interaction_branch = waiver_buttons_root.find_child("interaction branch_%s" % letter) as InteractionBranch
		waiver_button_interaction_branches[letter] = interaction_branch
	var interaction_branch_backspace = waiver_buttons_root.find_child("interaction branch_backspace") as InteractionBranch
	waiver_button_interaction_branches["backspace"] = interaction_branch_backspace
	var interaction_branch_enter = waiver_buttons_root.find_child("interaction branch_enter") as InteractionBranch
	waiver_button_interaction_branches["enter"] = interaction_branch_enter
	
func StartGameFromBathroom():
	if !enabled: 
		ModLoaderLog.info("Scripter disabled. Ignoring", LOGNAME)
		return
	ModLoaderLog.info("Bathroom loading cutscene complete", LOGNAME)
	if (!intro_manager.allowingPills):
		ModLoaderLog.info("Endless mode NOT allowed. No automation will happen", LOGNAME)
		return
	ModLoaderLog.info("Endless mode allowed. Beginning automation.", LOGNAME)
	await intro_manager.Interaction_PillBottle();
	ModLoaderLog.info("Pills interacted. Now handling prompt and waiting for reload", LOGNAME)
	await intro_manager.SelectedPill(true)
	ModLoaderLog.info("Bathroom reloaded. Now leaving bathroom", LOGNAME)
	await intro_manager.Interaction_BathroomDoor()
	ModLoaderLog.info("Hallway entered. Now entering backroom", LOGNAME)
	await intro_manager.Interaction_BackroomDoor()
	# Next is waiting for a hook trigger from SignatureManager.AwaitPickup, which will call PickupWaiverAndEnterName
	
func PickupWaiverAndEnterName():
	if !enabled: 
		ModLoaderLog.info("Scripter disabled. Ignoring", LOGNAME)
		return
	ModLoaderLog.info("Now in back room. Picking up waiver", LOGNAME)
	await signature_manager.PickUpWaiver()
	if mod_main.game_mode == mod_main.GAME_MODE.CHAT_VS_DEALER:
		ModLoaderLog.info("Waiver picked up. Finding player name", LOGNAME)
		var settings = ModLoaderConfig.get_current_config(mod_main.MOD_ID)
		var default_name: String = settings.data["defaultName"]
		var voted_name := twitch_bot.GetVotedName()
		var player_name = voted_name if voted_name != null && voted_name != "" else default_name
		ModLoaderLog.info("Using player name %s" % player_name, LOGNAME)
		await _EnterName(player_name)
	elif mod_main.game_mode == mod_main.GAME_MODE.STREAMER_VS_CHAT:
		ModLoaderLog.info("Waiver picked up. Waiting for streamer to enter name", LOGNAME)
	
func _EnterName(player_name: String):
	# Could go directly to signature_manager.Input_Letter or signature_manager.GetInput and the like
	#  but then the sound and animation would be skipped
	for letter in player_name:
		var button_interaction_branch = waiver_button_interaction_branches[letter.to_lower()]
		interaction_manager.activeInteractionBranch = button_interaction_branch
		# There is no speed limit on pressing different buttons at a time, but there is for pressing the same button over and over.
		# But speeding through in a single frame isn't as cool, I think. So I'm enforcing a "wait until previous button done" speed limit.
		
		# Wait until interactable to make sure we're good
		while (!button_interaction_branch.interactionAllowed):
			await get_tree().process_frame
		# Press the button
		await interaction_manager.InteractWith("signature machine button")
		# See it become uninteractable
		while (button_interaction_branch.interactionAllowed):
			await get_tree().process_frame
		# Then wait until it becomes interactable again
		while (!button_interaction_branch.interactionAllowed):
			await get_tree().process_frame
	
	interaction_manager.activeInteractionBranch = waiver_button_interaction_branches["enter"]
	await interaction_manager.InteractWith("signature machine button")

func WaiverNameEntered() -> void:
	ModLoaderLog.info("Waiver name has been entered", LOGNAME)
	if mod_main.game_mode == mod_main.GAME_MODE.STREAMER_VS_CHAT:
		ModLoaderLog.info("Playing against chat. Getting chat name for dealer", LOGNAME)
		var settings = ModLoaderConfig.get_current_config(mod_main.MOD_ID)
		var default_name: String = settings.data["defaultName"]
		var voted_name := twitch_bot.GetVotedName()
		var dealer_name = voted_name if voted_name != null && voted_name != "" else default_name
		dealer_name = dealer_name.to_upper()
		ModLoaderLog.info("Going with dealer name '%s'" % dealer_name, LOGNAME)
		dealer_name_label.text = dealer_name
