class_name VoteUI extends Control

const LOGNAME = "ChatPlaysBuckshotRoulette:VoteUI"

const vote_ui_scene = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/ui/vote_ui.tscn")

const CircleSliceTimer = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/ui/CircleSliceTimer.gd")
const VotingChoice = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/VotingChoice.gd")
const LeaderboardEntry = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/ui/LeaderboardEntry.gd")
const ActionLeaderboardEntry = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/ui/ActionLeaderboardEntry.gd")

var vote_ui_root: Node
var left_pane_node: Control
var action_list_node: Node
var action_num_labels: Dictionary
var action_name_labels: Dictionary
var action_percent_labels: Dictionary
var right_pane_node: Control
var name_list_node: Node
var name_entry_nodes: Dictionary
var vote_countdown_circle: CircleSliceTimer

func _init():
	self.name = "VoteUI"
	action_num_labels = {}
	action_name_labels = {}
	action_percent_labels = {}
	
	self.set_anchors_preset(PRESET_FULL_RECT)
	
	vote_ui_root = vote_ui_scene.instantiate()
	vote_ui_root.name = "VoteUI Interface"
	add_child.call_deferred(vote_ui_root)

func _ready():
	_LocateElements()
	_PurgePlaceholderData()
	HideNameVoting()
	CloseActionVoting()

func OpenActionVoting(choices: Array[VotingChoice], duration: float):
	ModLoaderLog.warning("Opening action voting for %s choices" % choices.size(), LOGNAME)
	var untouched_rows: Array = range(10).map(func(val): return str(val+1))
	for choice in choices:
		_UpdateActionLeaderboardEntry(choice.voting_key, choice.display_name, 0)
		untouched_rows.erase(choice.voting_key)
	for untouched_row in untouched_rows:
		_HideActionLeaderboardEntry(untouched_row)
	vote_countdown_circle.Start(duration)
	left_pane_node.visible = true

func CloseActionVoting():
	left_pane_node.visible = false

func ShowNameVoting():
	right_pane_node.visible = true

func HideNameVoting():
	right_pane_node.visible = false

func ClearNameEntries():
	for key in name_entry_nodes.keys():
		var node = name_entry_nodes.get(key) as Node
		node.queue_free()
	name_entry_nodes.clear()

func _LocateElements():
	left_pane_node = vote_ui_root.find_child("Left Pane") as Control
	action_list_node = left_pane_node.find_child("ActionList") as Node
	right_pane_node = vote_ui_root.find_child("Right Pane") as Control
	name_list_node = right_pane_node.find_child("NameList") as Node
	for i in range(10):
		var key = str(i+1)
		var num_label := action_list_node.find_child("KeyNum%s" % key) as Label
		var action_label := action_list_node.find_child("ActionDisplayName%s" % key) as Label
		var percent_label := action_list_node.find_child("Percent%s" % key) as Label
		action_num_labels[key] = num_label
		action_name_labels[key] = action_label
		action_percent_labels[key] = percent_label
	vote_countdown_circle = left_pane_node.find_child("VoteCountdownCircle") as CircleSliceTimer
		
func _PurgePlaceholderData():
	for i in range(10):
		_UpdateActionLeaderboardEntry(str(i+1), "", 0)
		
func UpdateNameLeaderboard(name_entries: Array[LeaderboardEntry]): 
	if !right_pane_node.visible:
		return
#	ModLoaderLog.debug("Updating name leaderboard", LOGNAME)
	for node_key in name_entry_nodes.keys():
		if name_entries.all(func(entry: LeaderboardEntry): return node_key != entry.key):
			var node = name_entry_nodes.get(node_key) as Label
			node.queue_free()
			name_entry_nodes.erase(node_key)
	var sort_ind := 0
	for entry in name_entries:
		var node = name_entry_nodes.get(entry.key) as Label
		if node == null:
			node = Label.new()
			node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			name_list_node.add_child(node)
			name_entry_nodes[entry.key] = node
		node.text = _FormatNameLeaderboard(entry)
		name_list_node.move_child(node, sort_ind)
		sort_ind += 1
		
func UpdateActionLeaderboard(action_entries: Array[ActionLeaderboardEntry]): 
	if !left_pane_node.visible:
		return
#	ModLoaderLog.debug("Updating action leaderboard", LOGNAME)
	for entry in action_entries:
		_UpdateActionLeaderboardEntry(entry.key, entry.display_name, entry.vote_percent)

func _UpdateActionLeaderboardEntry(key: String, display_name: String, vote_percent: float):
	var num_label: Label = action_num_labels.get(key)
	var display_name_label: Label = action_name_labels.get(key)
	var percent_label: Label = action_percent_labels.get(key)
	num_label.visible = true
	display_name_label.visible = true
	percent_label.visible = true
	display_name_label.text = display_name
	percent_label.text = "| %1d%%" % vote_percent

func _HideActionLeaderboardEntry(key: String):
	var num_label: Label = action_num_labels.get(key)
	var display_name_label: Label = action_name_labels.get(key)
	var percent_label: Label = action_percent_labels.get(key)
	num_label.visible = false
	display_name_label.visible = false
	percent_label.visible = false

func _FormatNameLeaderboard(name_leaderboard: LeaderboardEntry) -> String:
	var vote_percent_str = "%3d%%" % name_leaderboard.vote_percent
	var key_padded_str = "%6s" % name_leaderboard.key
	return "%s | %s" % [vote_percent_str, key_padded_str]
