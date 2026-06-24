class_name GameRunner extends Node

const LOGNAME = "ChatPlaysBuckshotRoulette:GameRunner"

const ChatPlaysModMain = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/mod_main.gd")
const TwitchBot = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/TwitchBot.gd")
const VotingChoice = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/VotingChoice.gd")

var mod_main
var twitch_bot: TwitchBot
var main_scene: Node
var interaction_manager: InteractionManager
var item_manager: ItemManager
var round_manager: RoundManager
var shotgun_manager: ShotgunShooting
var item_interaction: ItemInteraction
var interaction_intake: InteractionBranch
var briefcase_manager: BriefcaseMachine

var action_vote_period: int
var action_vote_timer: Timer

var player_inventory:= {}

# TODO: Send messasge on round win?
# TODO: Restart hotkey isn't handled well. Makes overlapping actions still.

func _init(_mod_main: ChatPlaysModMain, _twitch_bot: TwitchBot):
	self.mod_main = _mod_main
	self.twitch_bot = _twitch_bot
	self.action_vote_timer = Timer.new()
	self.action_vote_timer.name = "Action Vote Timer"
	self.add_child.call_deferred(action_vote_timer)

func RefreshSceneHooks(_main_scene: Node):
	self.main_scene = _main_scene
	self.interaction_manager = main_scene.find_child("interaction manager") as InteractionManager
	self.item_manager = main_scene.find_child("item manager") as ItemManager
	self.round_manager = main_scene.find_child("round manager") as RoundManager
	self.shotgun_manager = main_scene.find_child("shotgun shooting") as ShotgunShooting
	self.item_interaction = main_scene.find_child("item interaction") as ItemInteraction
	self.interaction_intake = main_scene.find_child("interaction branch_briefcase intake") as InteractionBranch
	self.briefcase_manager = main_scene.find_child("briefcase machine") as BriefcaseMachine
	
	# Init or clear inventory
	for i in range(8):
		# Pretty much all player item interaction stuff is 1 indexed. So I'm doing it too.
		player_inventory[i+1] = null; 
		
	action_vote_period = mod_main.mod_data.current_config.data.get("actionVotePeriod")
	
func StartGrabbingItems():
	ModLoaderLog.info("Grabbing player items", LOGNAME)
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
	
func StartPlayerTurn():
	if item_interaction.stealing:
		HandleAdrenalineUse()
		return
	ModLoaderLog.info("Starting a player turn now", LOGNAME)
	var voting_choices = _GetVotingChoices()
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
				"dealer":
					ShootDealer()
				"self":
					ShootSelf()
				_:
					UseItemWithName(action)
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

func ShootSelf():
	ModLoaderLog.info("Player shooting self", LOGNAME)
	await shotgun_manager.GrabShotgun()
	# InteractWith doesn't wait but it's fine because after shooting it'll trigger StartPlayerTurn again regardless
	await interaction_manager.InteractWith("text you")

func ShootDealer():
	ModLoaderLog.info("Player shooting dealer", LOGNAME)
	await shotgun_manager.GrabShotgun()
	# InteractWith doesn't wait but it's fine because after shooting it'll trigger StartPlayerTurn again regardless
	await interaction_manager.InteractWith("text dealer")

func UseItemWithName(interaction_name: String):
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
				UseItemAtSlot(item_slot)
				return

func StealDealerItemWithName(interaction_name: String):
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
func UseItemAtSlot(item_slot: int):
	ModLoaderLog.info("Player using item at position %s" % item_slot, LOGNAME)
	var selected_player_item = player_inventory[item_slot]
	var item_interaction_branch = selected_player_item.find_child("interaction branch") as InteractionBranch
	interaction_manager.activeInteractionBranch = item_interaction_branch
	interaction_manager.InteractWith("item")

# TODO: Using adrenaline after win and restart doesn't work? The is_instance_valid checks are an attempt to fix that. 
func HandleAdrenalineUse():
	ModLoaderLog.info("Player used adrenaline! Getting vote for what to steal", LOGNAME)
	# Find opponent possible items
	var dealer_item_instances = item_manager.itemArray_instances_dealer
	var dealer_item_interaction_branches: Array[InteractionBranch] = []
	for dealer_item_instance in dealer_item_instances:
		if is_instance_valid(dealer_item_instance):
			var int_branch = dealer_item_instance.find_child("interaction branch")
			if is_instance_valid(int_branch):
				dealer_item_interaction_branches.append(int_branch as InteractionBranch)
	
	var vote_winner = null
	var voting_choices = _GetAdrenalineVotingChoices()
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
	
	StealDealerItemWithName(vote_winner.interaction)

func HandleDoubleOrNothing():
	# TODO: Make auto-double or nothing option
	ModLoaderLog.info("Set over! Now being prompted for double or nothing. Opening to vote", LOGNAME)
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
	briefcase_manager.OpenLatch("L")
	# I don't think I *need* to wait, but am I am anways. because I don't want it instant
	await main_scene.get_tree().create_timer(0.5).timeout
	briefcase_manager.OpenLatch("R")

func CheckLatches():
	ModLoaderLog.info("Checking breifcase latches", LOGNAME)
	if briefcase_manager.intbranch_lid.interactionAllowed:
		ModLoaderLog.info("Breifcase lid ready to open. Opening", LOGNAME)
		briefcase_manager.OpenLid()

func HandleSceneChange(scene_name: String):
	# If scene changes, votes are cancelled
	action_vote_timer.stop()

func _GetVotingChoices() -> Array[VotingChoice]:
	var choices: Array[VotingChoice] = []
	choices.append(VotingChoice.new("Shoot Dealer", "dealer", str(choices.size() + 1)))
	choices.append(VotingChoice.new("Shoot Self", "self", str(choices.size() + 1)))
	var found_items: Array[String] = []
	for item_slot in player_inventory.keys():
		var item = player_inventory.get(item_slot)
		if item != null:
			var inter_branch := item.find_child("interaction branch") as InteractionBranch
			var item_name = inter_branch.itemName
			if !found_items.has(item_name):
				found_items.append(item_name)
				choices.append(VotingChoice.new(item_name.capitalize(), item_name, str(choices.size() + 1)))
	return choices

func _GetAdrenalineVotingChoices() -> Array[VotingChoice]:
	var choices: Array[VotingChoice] = []
	var found_items: Array[String] = []
	
	var dealer_item_instances = item_manager.itemArray_instances_dealer
	var dealer_item_interaction_branches = dealer_item_instances.map(func(inst): return inst.find_child("interaction branch")) as Array[InteractionBranch]
	
	for dealer_interaction_branch in dealer_item_interaction_branches:
		var item_name = dealer_interaction_branch.itemName
		if item_name == "adrenaline":
			# Cannot steal adrenaline
			continue
		if !found_items.has(item_name):
			found_items.append(item_name)
			choices.append(VotingChoice.new(item_name.capitalize(), item_name, str(choices.size() + 1)))
	return choices
