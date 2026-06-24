class_name VoteCounter extends Object

const LOGNAME = "ChatPlaysBuckshotRoulette:TwitchBot"

const VotingChoice = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/VotingChoice.gd")
const LeaderboardEntry = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/ui/LeaderboardEntry.gd")
const ActionLeaderboardEntry = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/ui/ActionLeaderboardEntry.gd")

var action_voting_open: bool
var voting_options: Dictionary
var name_votes_by_name: Dictionary
var name_votes_by_user: Dictionary
var action_votes_by_action: Dictionary
var action_votes_by_user: Dictionary

# TODO: Add vote percentage background bar

func _init():
	self.action_voting_open = false
	self.voting_options = {}
	self.name_votes_by_name = {}
	self.name_votes_by_user = {}
	self.action_votes_by_action = {}
	self.action_votes_by_user = {}
	
func OpenActionVoting(_voting_choices: Array[VotingChoice]):
	self.action_voting_open = true
	self.voting_options.clear()
	self.action_votes_by_action.clear()
	self.action_votes_by_user.clear()
	for voting_choice in _voting_choices:
		var key = voting_choice.voting_key
		self.voting_options[key] = voting_choice
		self.action_votes_by_action[key] = []
		
	ModLoaderLog.info("Opened action voting for choices: %s" % JSON.stringify(_voting_choices), LOGNAME)

func CloseActionVotingAndGetResults(cancel := false) -> Array[VotingChoice]:
	var actions_with_highest_votes: Array[VotingChoice] = []
	
	if cancel:
		ModLoaderLog.info("Cancelling voting prematurely. Not counting votes", LOGNAME)
	else:
		var highest_votes = 0
		for key in action_votes_by_action.keys():
			var votes = action_votes_by_action.get(key).size()
			var action_for_key = voting_options.get(key)
			if votes > highest_votes:
				highest_votes = votes
				actions_with_highest_votes.clear()
				actions_with_highest_votes.append(action_for_key)
			elif votes == highest_votes:
				actions_with_highest_votes.append(action_for_key)
		ModLoaderLog.info("Action votes concluded with winner(s): %s" % JSON.stringify(actions_with_highest_votes), LOGNAME)
	
	self.action_voting_open = false
	self.voting_options.clear()
	self.action_votes_by_action.clear()
	self.action_votes_by_user.clear()
	
	return actions_with_highest_votes
	
func AddPotentialActionVote(message: String, username: String):
	var voting_choice := _GetMatchingVotingChoice(message)
	if (voting_choice == null):
		return
	ModLoaderLog.debug("Recieved vote for action key [%s] (which is %s) from [%s]" % [voting_choice.voting_key, voting_choice.display_name, username], LOGNAME)
		
	# Erase existing vote, if applicable
	var user_vote = action_votes_by_user.get(username)
	if (user_vote != null):
		action_votes_by_action.get(user_vote).erase(username)
	
	# Add new vote to chosen option
	var key = voting_choice.voting_key
	var votes_for_action = action_votes_by_action.get(key)
	votes_for_action.append(username)
	action_votes_by_user[username] = key
	
func AddNameVote(name_vote: String, username: String):
	ModLoaderLog.debug("Recieved name vote for [%s] from [%s]" % [name_vote, username], LOGNAME)
	# Erase existing vote, if applicable
	var user_vote = name_votes_by_user.get(username)
	if (user_vote != null):
		var votes_for_this_name = name_votes_by_name.get(user_vote)
		votes_for_this_name.erase(username)
		if votes_for_this_name.size() == 0:
			# No one still voting for this name. Purge it
			name_votes_by_name.erase(user_vote)
	
	# Find existing votes for name
	var votes_for_name = name_votes_by_name.get(name_vote)
	if (votes_for_name == null):
		votes_for_name = []
		name_votes_by_name[name_vote] = votes_for_name
	
	# Add new vote to chosen option
	votes_for_name.append(username)
	name_votes_by_user[username] = name_vote

func GetNameVoteResults() -> Array[String]:
	var highest_votes = 0
	var names_with_highest_votes: Array[String] = []
	for name in name_votes_by_name.keys():
		var votes = name_votes_by_name.get(name).size()
		if votes > highest_votes:
			highest_votes = votes
			names_with_highest_votes.clear()
			names_with_highest_votes.append(name)
		elif votes == highest_votes:
			names_with_highest_votes.append(name)
	ModLoaderLog.info("Name results concluded with winner(s): %s" % JSON.stringify(names_with_highest_votes), LOGNAME)
	
	self.name_votes_by_name.clear()
	self.name_votes_by_user.clear()
	
	return names_with_highest_votes

func GetNameLeaderboard() -> Array[LeaderboardEntry]:
	var leaderboard: Array[LeaderboardEntry] = []
	var total_votes := name_votes_by_user.size()
	for name in name_votes_by_name.keys():
		var votes: int = name_votes_by_name.get(name).size()
		var percent_votes: float = (float(votes) / total_votes) * 100
		var leaderboard_entry := LeaderboardEntry.new(name, percent_votes)
		leaderboard.append(leaderboard_entry)
	leaderboard.sort_custom(_SortLeaderboardEntries)
	return leaderboard

func _SortLeaderboardEntries(a: LeaderboardEntry, b: LeaderboardEntry) -> bool:
	# If tied, sort alphabetically by key
	if a.vote_percent == b.vote_percent:
		return a.key < b.key
	# If not tied, sort by vote percent
	return a.vote_percent > b.vote_percent
	
func GetActionLeaderboard() -> Array[ActionLeaderboardEntry]:
	var leaderboard: Array[ActionLeaderboardEntry] = []
	var total_votes := _CountAllVotes(action_votes_by_action)
	for action_key in action_votes_by_action.keys():
		var action = voting_options.get(action_key)
		var vote_list = action_votes_by_action.get(action_key)
		var votes: int = 0 if vote_list == null else vote_list.size()
		var percent_votes: float = 0 if total_votes == 0 else (float(votes) / total_votes) * 100
		var leaderboard_entry := ActionLeaderboardEntry.new(action_key, action.display_name, percent_votes)
		leaderboard.append(leaderboard_entry)
	return leaderboard
	
func _GetMatchingVotingChoice(message: String) -> VotingChoice:
	if message == null || message == "":
		return null
	var first_word = message.get_slice(' ', 0)
	return self.voting_options.get(first_word)
	
func _CountAllVotes(votes: Dictionary) -> int:
	var vote_total := 0
	for vote in votes:
		vote_total += votes.get(vote).size()
	return vote_total
