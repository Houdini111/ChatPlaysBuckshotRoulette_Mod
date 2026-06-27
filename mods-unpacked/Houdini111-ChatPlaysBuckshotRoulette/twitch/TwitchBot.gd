class_name TwitchBot extends Node

const LOGNAME = "ChatPlaysBuckshotRoulette:TwitchBot"

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const INSTRUCTIONS_MESSASGE = "You can vote for a name at any time with the !name command. Limited to 6 letters. When action voting is open just type the number beside the action to vote for it."

const ChatPlaysModMain = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/mod_main.gd")
const StatusMessages = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/ui/StatusMessages.gd")
const HttpClientWrapper = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/HttpClientWrapper.gd")
const TwitchBotDCFAuth = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/TwitchBotDCFAuth.gd")
const TwitchBotChatInterface = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/TwitchBotChatInterface.gd")
const VoteCounter = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/VoteCounter.gd")
const VoteUI = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/ui/VoteUI.gd")
const VotingChoice = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/VotingChoice.gd")

var mod_main: ChatPlaysModMain
var status_messages: StatusMessages
var http_client_wrapper: HttpClientWrapper
var auth: TwitchBotDCFAuth
var chat_interface: TwitchBotChatInterface
var vote_counter: VoteCounter
var vote_ui: VoteUI
var ui_update_timer: Timer

var channel_name: String
var bot_user_id: String
var channel_user_id: String
var instructions_message_cooldown_seconds: int
var instructions_message_cooldown: float

var connection_error_shown := false
var connection_error_status_message_id: int

var enabled: bool = false
var bot_connected: bool = false

# TODO: Add silent bot option

func _init(_mod_main: ChatPlaysModMain):
	self.mod_main = _mod_main
	self.status_messages = Engine.get_singleton("StatusMessages")
	
	var current_config := ModLoaderConfig.get_current_config(mod_main.MOD_ID)
	self.channel_name = current_config.data.get("channel")
	instructions_message_cooldown = 0
	self.instructions_message_cooldown_seconds = current_config.data.get("instructionsCooldown")
	
	self.http_client_wrapper = HttpClientWrapper.new()
	self.http_client_wrapper.name = "HttpClientWrapper"
	add_child.call_deferred(http_client_wrapper)
	
	self.auth = TwitchBotDCFAuth.new(http_client_wrapper)
	add_child(auth)
	
	self.chat_interface = TwitchBotChatInterface.new(self.auth, http_client_wrapper, _WebsocketConnected, _HandleMessage)
	self.chat_interface.name = "TwitchBotChatInterface"
	add_child(self.chat_interface)
	
	self.vote_counter = VoteCounter.new()
	
	vote_ui = VoteUI.new()
	self.add_child.call_deferred(vote_ui)
	ui_update_timer = Timer.new()
	ui_update_timer.name = "UIUpdateTimer"
	add_child.call_deferred(ui_update_timer)
	ui_update_timer.timeout.connect(_UpdateLeaderboards)
	vote_ui.z_index = 100
	
	ListenToAuthStatus(ShowAuthSuccessMessage)

func Disable() -> void:
	self.enabled = false
	self.vote_ui.Disable()
	self.ui_update_timer.paused = true
	# TODO: Disconnect bot chat interface
	# TODO: Make bot only connect after choosing a chat mode? But auth first to make sure it can.
	# TODO: Disable chat plays mode buttons if bot isn't authenticated

func Enable() -> void:
	self.enabled = true
	self.vote_ui.Enable()
	self.ui_update_timer.paused = false

func _ready():
	ModLoader.current_config_changed.connect(_ConfigUpdated)
	await self.auth.VerifyAuthentication(true)
	if IsAuthorized():
		_PrepareChatbotData()

func _process(delta):
	if instructions_message_cooldown > 0:
		instructions_message_cooldown = max(0, instructions_message_cooldown - delta)

func StartAuthFlow() -> void:
	self.auth.StartDCFlow()

func IsAuthorized() -> bool:
	return self.auth.IsAuthorized()

func ListenToAuthStatus(listener: Callable):
	self.auth.ListenToAuthStatus(listener)

func ShowAuthSuccessMessage(success: bool):
	ModLoaderLog.info("Auth success: %s" % success, LOGNAME)
	if success:
		if connection_error_shown:
			status_messages.RemoveMessage(connection_error_status_message_id)
			connection_error_shown = false
			status_messages.ShowMessageForTime("Bot successfully authorized", 7)
	else:
		connection_error_status_message_id = status_messages.ShowMessageForever("Bot failed to authenticate with Twitch. Please reauthenticate")
		connection_error_shown = true

func HandleSceneChange(scene_name: String):
	# On any scene change, close bot action voting.
	#  If we're changing to main, then no actions are available. 
	#  If we're changing away from main then actions are no longer available.
	if vote_counter.action_voting_open:
		self.CloseActionVotingAndGetResults(true)
	if enabled:
		if scene_name == "main":
			if IsAuthorized():
				ConnectChatListener()
		else:
			pass
			# TODO: Stop showing vote_ui
			# TODO: Stop taking votes

func _PrepareChatbotData():
	ModLoaderLog.info("Attempting to start Twitch chatbot", LOGNAME)
	if !IsAuthorized():
		ModLoaderLog.error("Tried to start chatbot but was not authorized yet", LOGNAME)
		return
	var authorization_data = self.auth.GetUserAuthData()
	if authorization_data == null || authorization_data == {}:
		ModLoaderLog.error("Tried to start chatbot but was not auth data found", LOGNAME)
		return
	bot_user_id = authorization_data.get("user_id")
	if channel_name == null || channel_name == "":
		ModLoaderLog.error("Tried to start chatbot but not target channel set", LOGNAME)
		return
	if channel_user_id == null || channel_user_id == "":
		var user_ids = await self.auth.GetUserData([channel_name])
		if user_ids == null || user_ids.size() == 0:
			ModLoaderLog.error("Tried to start chatbot but could not get target channel user ID", LOGNAME)
			return
		var target_channel_login = user_ids.keys()[0]
		channel_user_id = user_ids.get(target_channel_login).get("id")
	ModLoaderLog.info("Twitch bot authenticated. Can now send messages.", LOGNAME)
	status_messages.ShowMessageForTime("Bot successfully authenticated. Should be ready to go.", 10)

func ConnectChatListener() -> void:
	self.chat_interface.StartWebsocketClient(bot_user_id, channel_user_id)
	
func OpenActionVoting(voting_choices: Array[VotingChoice]):
	var action_vote_period = mod_main.mod_data.current_config.data.get("actionVotePeriod")
	self.vote_ui.OpenActionVoting(voting_choices, action_vote_period)
	self.vote_counter.OpenActionVoting(voting_choices)
	chat_interface.SendMessage("Voting for next action now open! You have %s seconds." % action_vote_period)

func CloseActionVotingAndGetResults(cancel := false) -> VotingChoice:
	self.vote_ui.CloseActionVoting()
	var voting_winners := self.vote_counter.CloseActionVotingAndGetResults(cancel)
	if cancel:
		ModLoaderLog.info("Cancellilng action voting prematurely. Not worrying about results", LOGNAME)
		return
	var voting_winner: VotingChoice = null
	if voting_winners.size() > 1:
		voting_winner = voting_winners.pick_random()
		ModLoaderLog.info("Voting results tied. Options: [%s]. Randomly chosen winner: %s" % [JSON.stringify(voting_winners), voting_winner.display_name], LOGNAME)
		chat_interface.SendMessage("Action voting results had a %s-way tie. Randomly chosen winner: '%s'" % [voting_winners.size(), voting_winner.display_name])
	elif voting_winners.size() == 1:
		voting_winner = voting_winners[0]
		ModLoaderLog.info("Voting results had a winner of %s" %  voting_winner.display_name, LOGNAME)
		chat_interface.SendMessage("Winner of action voting: '%s'" % voting_winner.display_name)
	return voting_winner
	
func GetVotedName() -> String:
	var results := self.vote_counter.GetNameVoteResults()
	var winner := ""
	if results.size() > 1:
		winner = results.pick_random()
		ModLoaderLog.info("Name voting results tied. Options: [%s]. Randomly chosen winner: %s" % [JSON.stringify(results), winner], LOGNAME)
		chat_interface.SendMessage("Name voting results had a %s-way tie. Randomly chosen winner: '%s'" % [results.size(), winner])
	elif results.size() == 1:
		winner = results[0]
		ModLoaderLog.info("Name voting results had a winner of %s" %  winner, LOGNAME)
		chat_interface.SendMessage("Winning name vote: '%s'" % winner)
	vote_ui.ClearNameEntries()
	return winner
	
func _UpdateLeaderboards():
	vote_ui.UpdateActionLeaderboard(self.vote_counter.GetActionLeaderboard())
	vote_ui.UpdateNameLeaderboard(self.vote_counter.GetNameLeaderboard())
	
func _WebsocketConnected(first_connection := true):
	vote_ui.Enable()
	vote_ui.ShowNameVoting()
	# TODO: Make configurable ui update rate
	# var ui_update_seconds = ModLoaderConfig.get_current_config(mod_main.MOD_ID).get("") 
	ui_update_timer.start(0.5)
	
	ModLoaderLog.info("Succesfully started Twitch chatbot", LOGNAME)
	if first_connection:
		chat_interface.SendMessage("ChatPlaysBuckshotRoulette is connected and ready!")
		status_messages.ShowMessageForTime("Successfully connected bot to Twitch and ready to go", 10)
	else: 
		chat_interface.SendMessage("ChatPlaysBuckshotRoulette successfully reconnected")
		status_messages.ShowMessageForTime("ChatPlaysBuckshotRoulette was disconnected but successfully reconnected", 10)

func _HandleMessage(message: String, from_user: String):
	if (message.begins_with("!name ")):
		_HandleNameVote(message, from_user)
	elif (message.begins_with("!instructions")):
		_HandleInstructionsMessage()
	else:
		self.vote_counter.AddPotentialActionVote(message, from_user)

func _HandleNameVote(message: String, from_user: String):
	var prefix_removed = message.trim_prefix("!name ")
	if prefix_removed == null || prefix_removed == "":
		return
	var message_split = prefix_removed.split(" ")
	if message_split == null || message_split.size() < 1:
		return
	var name = message_split[0]
	var normalized_name = _NormalizeNameVote(name)
	if normalized_name == null || normalized_name.length() < 1:
		return
	self.vote_counter.AddNameVote(normalized_name, from_user)

func _NormalizeNameVote(name_vote: String):
	var upper_case := name_vote.to_upper()
	var alpha := ""
	for char in upper_case:
		if ALPHABET.contains(char):
			alpha += char
	return alpha.substr(0, 6)

func _ConfigUpdated(config: ModConfig):
	if config.mod_id == mod_main.MOD_ID:
		ModLoaderConfig.info("Mod config changed. Twitch bot updating", LOGNAME)
		self.channel_name = config.data.get("channel")
		self.instructions_message_cooldown_seconds = config.data.get("instructionsCooldown")

func _HandleInstructionsMessage():
	if instructions_message_cooldown <= 0:
		ModLoaderLog.info("Instructions message recieved and was off cooldown. Sending message", LOGNAME)
		chat_interface.SendMessage(INSTRUCTIONS_MESSASGE)
		instructions_message_cooldown = instructions_message_cooldown_seconds
	else:
		ModLoaderLog.info("Instructions message recieved but was on cooldown. Ignoring", LOGNAME)
