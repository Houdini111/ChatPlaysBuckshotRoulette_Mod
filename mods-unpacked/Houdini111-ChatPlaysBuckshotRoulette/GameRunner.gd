class_name GameRunner extends Node

const LOGNAME = "ChatPlaysBuckshotRoulette:GameRunner"

const ChatPlaysModMain = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/mod_main.gd")
const TwitchBot = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/TwitchBot.gd")
const VotingChoice = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/VotingChoice.gd")
const DialogueManagerHook = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/extensions/scripts/DialogueManager.hooks.gd")
const CameraManagerHook = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/extensions/scripts/CameraManager.hooks.gd")

var mod_main: ChatPlaysModMain
var twitch_bot: TwitchBot
var main_scene: Node
var interaction_manager: InteractionManager
var item_manager: ItemManager
var round_manager: RoundManager
var shotgun_manager: ShotgunShooting
var item_interaction: ItemInteraction
var interaction_intake: InteractionBranch
var briefcase_manager: BriefcaseMachine
var camera_manager: CameraManager
var dealer_intelligence: DealerIntelligence
var hand_manager: HandManager
var medicine_manager: Medicine
var shell_spawn_manager: ShellSpawner
var dialogue_manager_hook: DialogueManagerHook # Should be set by mod_main.ChangeToSceneMain
var camera_manager_hook: CameraManagerHook # Also injected
var burner_phone_manager: BurnerPhone
var handcuff_manager: HandcuffManager
var death_manager: DeathManager
var segment_manager: SegmentManager

var action_vote_period: int
var action_vote_timer: Timer

var player_inventory:= {}

var enabled: bool = false

# TODO: Send messasge on round win?
# TODO: Restart hotkey isn't handled well. Makes overlapping actions still.
# TODO: If voting is happening, disable all actions to prevent accidental double actions
# TODO: Flip negative effects when ChatDealer. So shooting player triggers the dealer shot blood splat, for example
# TODO: Handle secret messages better? A window just for streamer for lens and phone, and messages in chat for the same?

func _init(_mod_main: ChatPlaysModMain, _twitch_bot: TwitchBot):
	self.mod_main = _mod_main
	self.twitch_bot = _twitch_bot
	self.action_vote_timer = Timer.new()
	self.action_vote_timer.name = "Action Vote Timer"
	self.add_child.call_deferred(action_vote_timer)

func Disable() -> void:
	self.enabled = false
	
func Enable() -> void:
	self.enabled = true

func RefreshSceneHooks(_main_scene: Node):
	ModLoaderLog.info("GameRunner refreshing scene hooks", LOGNAME)
	if !enabled: 
		ModLoaderLog.info("GameRunner disabled. Ignoring", LOGNAME)
		return
	self.main_scene = _main_scene
	self.interaction_manager = main_scene.find_child("interaction manager") as InteractionManager
	self.item_manager = main_scene.find_child("item manager") as ItemManager
	self.round_manager = main_scene.find_child("round manager") as RoundManager
	self.shotgun_manager = main_scene.find_child("shotgun shooting") as ShotgunShooting
	self.item_interaction = main_scene.find_child("item interaction") as ItemInteraction
	self.interaction_intake = main_scene.find_child("interaction branch_briefcase intake") as InteractionBranch
	self.briefcase_manager = main_scene.find_child("briefcase machine") as BriefcaseMachine
	self.camera_manager = main_scene.find_child("camera manager") as CameraManager
	self.dealer_intelligence = main_scene.find_child("dealer intelligence") as DealerIntelligence
	self.hand_manager = main_scene.find_child("hand manager") as HandManager
	self.medicine_manager = main_scene.find_child("medicine manager") as Medicine
	self.shell_spawn_manager = main_scene.find_child("shell spawner") as ShellSpawner
	self.burner_phone_manager = main_scene.find_child("burner phone manager") as BurnerPhone
	self.handcuff_manager = main_scene.find_child("handcuff manager") as HandcuffManager
	self.death_manager = main_scene.find_child("death manager") as DeathManager
	self.segment_manager = main_scene.find_child("segment manager") as SegmentManager
	
	# Init or clear inventory
	for i in range(8):
		# Pretty much all player item interaction stuff is 1 indexed. So I'm doing it too.
		player_inventory[i+1] = null; 
		
	action_vote_period = mod_main.mod_data.current_config.data.get("actionVotePeriod")
	
	_InjectChatDealerCameraPosition(_main_scene)

func _InjectChatDealerCameraPosition(_main_scene: Node) -> void:
	var camera_manager := _main_scene.find_child("camera manager") as CameraManager
	
	var home_socket: CameraSocket
	var player_enemy_socket: CameraSocket
	var player_health_socket: CameraSocket
	var player_grow_barrel_socket: CameraSocket
	for socket in camera_manager.socketArray:
		if socket.socketName == "home":
			home_socket = socket
		elif socket.socketName == "enemy":
			player_enemy_socket = socket
		elif socket.socketName == "health counter":
			player_health_socket = socket
		elif socket.socketName == "grow barrel":
			player_grow_barrel_socket = socket
	
	var dealer_view_home := home_socket.duplicate()
	dealer_view_home.socketName = "ChatDealerViewHome"
	_FlipCameraSocketAcrossTable(dealer_view_home)
	camera_manager.socketArray.append(dealer_view_home)
	
	var dealer_view_enemy = player_enemy_socket.duplicate()
	dealer_view_enemy.socketName = "ChatDealerViewEnemy"
	_FlipCameraSocketAcrossTable(dealer_view_enemy)
	camera_manager.socketArray.append(dealer_view_enemy)
	
	var dealer_view_down = dealer_view_home.duplicate()
	dealer_view_down.socketName = "ChatDealerViewDown"
	# Just make it look further down
	dealer_view_down.rot = Vector3(dealer_view_down.rot.x-15, dealer_view_down.rot.y, dealer_view_down.rot.z)
	camera_manager.socketArray.append(dealer_view_down)
	
	var dealer_health_view := player_health_socket.duplicate()
	dealer_health_view.socketName = "ChatDealerHealthCounter"
	_FlipCameraSocketAcrossTable(dealer_health_view)
	camera_manager.socketArray.append(dealer_health_view)
	
	var dealer_grow_barrel := player_grow_barrel_socket.duplicate()
	dealer_grow_barrel.socketName = "ChatDealerGrowBarrel"
	_FlipCameraSocketAcrossTable(dealer_grow_barrel)
	camera_manager.socketArray.append(dealer_grow_barrel)
	
	
	
func _FlipCameraSocketAcrossTable(socket_to_change: CameraSocket) -> void:
	var table_x := -1.75
	var distance_to_table: float = socket_to_change.pos.x - table_x
	var new_x_pos = socket_to_change.pos.x - (distance_to_table * 2)
	socket_to_change.pos = Vector3(new_x_pos, socket_to_change.pos.y, socket_to_change.pos.z)
	# -180 is towards health indicator
	var rot_distance = -180 - socket_to_change.rot.y
	var new_y_rot: float = socket_to_change.rot.y + (rot_distance * 2)
	socket_to_change.rot = Vector3(socket_to_change.rot.x, new_y_rot, socket_to_change.rot.z)
	
func ReadyForItemGrabbing():
	ModLoaderLog.info("Ready to grab player items", LOGNAME)
	if !enabled: 
		ModLoaderLog.info("GameRunner disabled. Ignoring", LOGNAME)
		return
	var numItemsToGrab = round_manager.roundArray[round_manager.currentRound].numberOfItemsToGrab
	ModLoaderLog.info("Player has %s items to grab" % str(numItemsToGrab), LOGNAME)
	while (item_manager.numberOfItemsGrabbed < numItemsToGrab):
		# Wait until interactable
		while (!interaction_intake.interactionAllowed):
			await main_scene.get_tree().create_timer(0.1).timeout
		await item_manager.GrabItem()
		var next_spot = _GetNextEmptySpot()
		if (next_spot == null):
			ModLoaderLog.info("No more free spots. Game will abort", LOGNAME)
			# No free space means we can't keep this. 
			#  After some dialog the game will continue without further action. 
			#  So end here GrabbingItems here.
			return
		# The ONE time player inventory stuff is 0 indexed. 
		await item_manager.PlaceDownItem(next_spot - 1)
		player_inventory[next_spot] = item_manager.activeItem
	ModLoaderLog.info("Done grabbing items", LOGNAME)

func StartRound():
	ModLoaderLog.info("Starting a round of gameplay now", LOGNAME)
	if !enabled: 
		ModLoaderLog.info("GameRunner disabled. Ignoring", LOGNAME)
		return
	
func StartPlayerTurn():
	ModLoaderLog.info("Start of player turn", LOGNAME)
	if !enabled: 
		ModLoaderLog.info("GameRunner disabled. Ignoring", LOGNAME)
		return
	if mod_main.game_mode == mod_main.GAME_MODE.STREAMER_VS_CHAT:
		ModLoaderLog.info("Streamer in control of player. Chat not taking a turn", LOGNAME)
		return
	if item_interaction.stealing:
		HandleAdrenalineUse()
		return
	ModLoaderLog.info("Starting a player turn now", LOGNAME)
	var voting_choices = _GetVotingChoices(true, true)
	var action_taken := false
	while !action_taken:
		twitch_bot.OpenActionVoting(voting_choices)
		ModLoaderLog.info("Opened action voting. Now waiting for the configured %s seconds" % action_vote_period, LOGNAME)
		action_vote_timer.start(action_vote_period)
		await action_vote_timer.timeout
		var vote_winner: VotingChoice = twitch_bot.CloseActionVotingAndGetResults()
		
		if vote_winner != null:
			var action = vote_winner.interaction
			match action:
				"opponent":
					_ShootDealer()
				"self":
					_ShootSelf()
				_:
					_UseItemWithName(action)
			action_taken = true
		else:
			ModLoaderLog.info("No action taken. Will restart voting", LOGNAME)
	
	
func _GetNextEmptySpot():
	for i in range(8):
		var offsetIndex = i+1
		var item_at_spot = player_inventory.get(offsetIndex)
		if (item_at_spot == null):
			ModLoaderLog.debug("Next free player inventory spot: %s" % str(offsetIndex), LOGNAME)
			return offsetIndex
	ModLoaderLog.info("Player inventory full. Game will abort", LOGNAME)

func _ShootSelf():
	ModLoaderLog.info("Player shooting self", LOGNAME)
	await shotgun_manager.GrabShotgun()
	# InteractWith doesn't wait but it's fine because after shooting it'll trigger StartPlayerTurn again regardless
	await interaction_manager.InteractWith("text you")

func _ShootDealer():
	ModLoaderLog.info("Player shooting dealer", LOGNAME)
	await shotgun_manager.GrabShotgun()
	# InteractWith doesn't wait but it's fine because after shooting it'll trigger StartPlayerTurn again regardless
	await interaction_manager.InteractWith("text dealer")

func _UseItemWithName(interaction_name: String):
	ModLoaderLog.info("Player using item %s" % interaction_name, LOGNAME)
	# Don't have to reverse. I just want it to use from the end if there's more than one
	var keys_reversed := player_inventory.keys()
	keys_reversed.reverse()
	for item_slot in keys_reversed:
		var item = player_inventory.get(item_slot)
		if item != null:
			var inter_branch := item.find_child("interaction branch") as InteractionBranch
			var item_name = inter_branch.itemName
			if item_name == interaction_name:
				ModLoaderLog.info("Located item at slot %s" % item_slot, LOGNAME)
				_UseItemAtSlot(item_slot)
				return

func _StealDealerItemWithName(interaction_name: String):
	ModLoaderLog.info("Player stealing dealer item with name %s" % interaction_name, LOGNAME)
	# Don't have to reverse. I just want it to use from the end if there's more than one
	var dealer_item_instances = item_manager.itemArray_instances_dealer
	var dealer_item_interaction_branches = dealer_item_instances.map(func(inst): return inst.find_child("interaction branch")) as Array[InteractionBranch]
	var interaction_branches_reversed = dealer_item_interaction_branches.duplicate()
	interaction_branches_reversed.reverse()
	for interaction_branch in interaction_branches_reversed:
		var item_name = interaction_branch.itemName
		if item_name == interaction_name:
			ModLoaderLog.info("Located dealer item", LOGNAME)
			interaction_manager.activeInteractionBranch = interaction_branch
			interaction_manager.InteractWith("item")
			item_manager.RevertItemSteal()
			return

# !!!One indexed!!!
#  It's what both players and the game uses, so I'm keeping it instead of translating to and from for no reason
func _UseItemAtSlot(item_slot: int):
	ModLoaderLog.info("Player using item at position %s" % item_slot, LOGNAME)
	var selected_player_item = player_inventory[item_slot]
	var item_interaction_branch = selected_player_item.find_child("interaction branch") as InteractionBranch
	interaction_manager.activeInteractionBranch = item_interaction_branch
	interaction_manager.InteractWith("item")

# TODO: Using adrenaline after win and restart doesn't work? The is_instance_valid checks are an attempt to fix that. 
func HandleAdrenalineUse():
	ModLoaderLog.info("Player used adrenaline! Getting vote for what to steal", LOGNAME)
	if !enabled: 
		ModLoaderLog.info("GameRunner disabled. Ignoring", LOGNAME)
		return
	if mod_main.game_mode == mod_main.GAME_MODE.STREAMER_VS_CHAT:
		ModLoaderLog.info("Streamer playing as player. Script not handling adrenaline", LOGNAME)
		return

	var vote_winner = null
	var voting_choices = _GetVotingChoices(false, false)
	if voting_choices.size() == 0:
		# Nothing to use. Just immediately cancel.
		item_manager.RevertItemSteal_Timeout()
		return
	elif voting_choices.size() == 1:
		# Only one choice. Take that immediately.
		vote_winner = voting_choices[0]
		
	while vote_winner == null:
		twitch_bot.OpenActionVoting(voting_choices)
		ModLoaderLog.info("Opened adrenaline item voting. Now waiting for the configured %s seconds" % action_vote_period, LOGNAME)
		action_vote_timer.start(action_vote_period)
		await action_vote_timer.timeout
		vote_winner = twitch_bot.CloseActionVotingAndGetResults()
	
	_StealDealerItemWithName(vote_winner.interaction)

func HandleDoubleOrNothing():
	# TODO: Make auto-double or nothing option
	ModLoaderLog.info("Set over! Now being prompted for double or nothing. Opening to vote", LOGNAME)
	if !enabled: 
		ModLoaderLog.info("GameRunner disabled. Ignoring", LOGNAME)
		return
	if mod_main.game_mode == mod_main.GAME_MODE.STREAMER_VS_CHAT:
		ModLoaderLog.info("Streamer in control. Don't get chat opinions on Double or Nothing", LOGNAME)
		return
	var yes_choice = VotingChoice.new("Yes", "yes", "1")
	var no_choice = VotingChoice.new("No", "no", "2")
	var voting_choices: Array[VotingChoice] = [yes_choice, no_choice]
	twitch_bot.OpenActionVoting(voting_choices)
	action_vote_timer.start(action_vote_period)
	await action_vote_timer.timeout
	var vote_winner: VotingChoice = twitch_bot.CloseActionVotingAndGetResults()
	
	var choice_key = "yes"
	if vote_winner != null:
		choice_key = vote_winner.interaction
	else:
		ModLoaderLog.info("Double or nothing reponse was nothing. Defaulting to yes", LOGNAME)
	var yes = choice_key == "yes"
	interaction_manager.activeInteractionBranch = round_manager.intbranch_yes if yes else round_manager.intbranch_yes
	interaction_manager.InteractWith("double %s" % choice_key)
	
func HandleBreifcase():
	ModLoaderLog.info("Breifcase presented. Opening", LOGNAME)
	if !enabled: 
		ModLoaderLog.info("GameRunner disabled. Ignoring", LOGNAME)
		return
	if mod_main.game_mode == mod_main.GAME_MODE.STREAMER_VS_CHAT:
		ModLoaderLog.info("Streamer playing as player. Script not handling breifcase", LOGNAME)
		return
	briefcase_manager.OpenLatch("L")
	# I don't think I *need* to wait, but am I am anways. because I don't want it instant
	await main_scene.get_tree().create_timer(0.5).timeout
	briefcase_manager.OpenLatch("R")

func CheckLatches():
	ModLoaderLog.info("Checking breifcase latches", LOGNAME)
	if !enabled: 
		ModLoaderLog.info("GameRunner disabled. Ignoring", LOGNAME)
		return
	if mod_main.game_mode == mod_main.GAME_MODE.STREAMER_VS_CHAT:
		ModLoaderLog.info("Streamer playing as player. Script not checking latches", LOGNAME)
		return
	if briefcase_manager.intbranch_lid.interactionAllowed:
		ModLoaderLog.info("Breifcase lid ready to open. Opening", LOGNAME)
		briefcase_manager.OpenLid()

func HandleSceneChange(scene_name: String):
	# If scene changes, votes are cancelled
	if action_vote_timer != null:
		action_vote_timer.stop()

func _GetVotingChoices(standard_turn: bool, player_inventory: bool) -> Array[VotingChoice]:
	# standard_turn meaning allow shooting, allow choosing adrenaline
	#  If not standard_turn then they're using adrenaline so they're stealing. 
	#  They can't shoot gun and they can't steal
	var choices: Array[VotingChoice] = []
	if standard_turn:
		choices.append(VotingChoice.new("Shoot Opponent", "opponent", str(choices.size() + 1)))
		choices.append(VotingChoice.new("Shoot Self", "self", str(choices.size() + 1)))
	if player_inventory:
		choices = _GetPlayerItemVotingChoices(standard_turn, choices)
	else:
		choices = _GetDealerItemVotingChoices(standard_turn, choices)

	return choices
	
func _GetPlayerItemVotingChoices(standard_turn: bool, choices: Array[VotingChoice]) -> Array[VotingChoice]:
	var found_items: Array[String] = []
	for item_slot in player_inventory.keys():
		var item = player_inventory.get(item_slot)
		if item != null:
			var inter_branch := item.find_child("interaction branch") as InteractionBranch
			var item_name = inter_branch.itemName
			if !standard_turn && item_name == "adrenaline":
				continue
			if !found_items.has(item_name):
				found_items.append(item_name)
				choices.append(VotingChoice.new(item_name.capitalize(), item_name, str(choices.size() + 1)))
	return choices

func _GetDealerItemVotingChoices(standard_turn: bool, choices: Array[VotingChoice] = []) -> Array[VotingChoice]:
	var found_items: Array[String] = []
	var dealer_item_instances = item_manager.itemArray_instances_dealer
	var dealer_item_interaction_branches = dealer_item_instances.map(func(inst): return inst.find_child("interaction branch")) as Array[InteractionBranch]
	
	for dealer_interaction_branch in dealer_item_interaction_branches:
		var item_name = dealer_interaction_branch.itemName
		if !standard_turn && item_name == "adrenaline":
			# Cannot steal adrenaline
			continue
		if !found_items.has(item_name):
			found_items.append(item_name)
			choices.append(VotingChoice.new(item_name.capitalize(), item_name, str(choices.size() + 1)))
	return choices
	
func StartChatDealerTurn():
	ModLoaderLog.info("Starting chat's turn as dealer", LOGNAME)
	if !enabled:
		# Shouldn't happen but should check anyways
		ModLoaderLog.info("GameRunner disabled. Ignoring", LOGNAME)
		return
	# TODO: Give streamer an avatar? Will probably need to be shown/hid dynamically
	
	# Disallow movement to player positions when I know it's the dealer's turn
	camera_manager_hook.dealer_turn = true
	
	await _MoveCameraToChatDealerHome()
	
	ModLoaderLog.info("Starting a chat as dealer turn now", LOGNAME)
	var voting_choices = _GetVotingChoices(true, false)
	twitch_bot.OpenActionVoting(voting_choices)
	ModLoaderLog.info("Opened action voting. Now waiting for the configured %s seconds" % action_vote_period, LOGNAME)
	action_vote_timer.start(action_vote_period)
	await action_vote_timer.timeout
	var vote_winner: VotingChoice = twitch_bot.CloseActionVotingAndGetResults()
	
	if vote_winner != null:
		var action = vote_winner.interaction
		if action == "opponent" || action == "self":
			var target_name = action
			if target_name == "opponent":
				target_name = "player"
			var shell_live = shell_spawn_manager.sequenceArray[0] == "live"
			
			await dealer_intelligence.GrabShotgun()
			ModLoaderLog.debug("Moving camera for ChatDealer starting to use shotgun", LOGNAME)
			if action == "opponent":
				camera_manager.BeginLerp("ChatDealerViewEnemy")
			else: 
				# Look extra far down so we can see the gun
				camera_manager.BeginLerp("ChatDealerViewDown")
			await dealer_intelligence.Shoot(target_name)
			ModLoaderLog.debug("Moving camera for ChatDealer going back to home after shooting", LOGNAME)
			camera_manager.BeginLerp("ChatDealerViewHome")
			dealer_intelligence.animator_shotgun.play("enemy put down shotgun")
			dealer_intelligence.shellLoader.DealerHandsDropShotgun()
		else:
			# This is the special action handling. 
			#   Not every item just works with PickupItemFromTable. This fills in the blanks
			match action:
				"expired medicine":
					medicine_manager.dealerDying = medicine_manager.GetFlip()
				"magnifying glass":
					var next_shell_live = shell_spawn_manager.sequenceArray[0]
					if is_instance_valid(dialogue_manager_hook):
						dialogue_manager_hook.new_message = "THE NEXT SHELL IS %s" % next_shell_live
				"burner phone":
					# Because the dealer just takes the phone, uses it, that's all that happens visually
					#   I can just use the same player phone dialog code
					burner_phone_manager.SendDialogue()
				"handcuffs":
					round_manager.playerCuffed = true
				"inverter":
					var next_live := shell_spawn_manager.sequenceArray[0] == "live"
					# This is inverting it
					shell_spawn_manager.sequenceArray[0] = "blank" if next_live else "live"
				"handsaw":
					round_manager.barrelSawedOff = true
					round_manager.currentShotgunDamage = 2
			# Cigarettes and beer work fine here
			
			await _ChatDealerUseItem(action)
			# Maybe look at ending player turn for more?
			
			if action == "expired medicine":
				# If using expired medicine, check to see if dealer health reached 0
				if round_manager.health_opponent == 0:
					ModLoaderLog.debug("ChatDealer died to medicine. Releasing camera lock", LOGNAME)
					# If dealer died, release camera
					camera_manager_hook.dealer_turn = false
					# TODO: Do I need to check for defib status for the TrueDeath flag here?
					death_manager.Kill("dealer", false, false)
					return
			# TODO: When health changes (cig, med, shot) wait until anim is finished
			
			# Any item besides a killing expired medicine is guaranteed to allow another turn
			dealer_intelligence.EndDealerTurn(true)
	
	# TODO: Handle adrenaline
	# TODO: Handle camera? Might end up whipping back if it's still dealer turn
	
func _ChatDealerUseItem(item_name: String) -> void:
	# TODO: Maybe have an ever lower looking angle to better see item in use? 
	await hand_manager.PickupItemFromTable(item_name)
	_ChatDealerEraseItem(item_name)
	
func _ChatDealerEraseItem(item_name: String) -> void:
	# Switch this erase to RemoveItem_Remote but that involves finding the item to remove
#	await hand_manager.RemoveItem_Remote()
	item_manager.itemArray_dealer.erase(item_name)
		
func _MoveCameraToChatDealerHome() -> void:
	# Wait for camera to stop moving for things like health changing
	while camera_manager.moving:
		await get_tree().process_frame
	
	# TODO: Take full control over camera during ChatDealer turn to prevent rapid flashing of position
	#     Seems to mostly happen if health changes. So maybe hook that specifically? 
	# Move camera
	ModLoaderLog.debug("Moving camera for ChatDealer going back to home to start dealer turn", LOGNAME)
	await camera_manager.BeginLerp("ChatDealerViewHome")
	# And wait for camera to finish moving
	while camera_manager.moving:
		await get_tree().process_frame

func EndingDealerTurn() -> void:
	camera_manager_hook.dealer_turn = false
		
