class_name VotingChoice extends Object

@export var display_name: String
@export var interaction: String
@export var voting_key: String

func _init(_display_name: String, _interaction: String, _voting_key: String):
	self.display_name = _display_name
	self.interaction = _interaction
	self.voting_key = _voting_key

func _to_string():
	return "[%s] '%s' (%s)" % [self.voting_key, self.display_name, self.interaction]
