class_name ActionLeaderboardEntry extends Object

@export var key: String
@export var display_name: String
@export var vote_percent: float

func _init(_key: String, _display_name: String, _vote_percent: float):
	self.key = _key
	self.display_name = _display_name
	self.vote_percent = _vote_percent
	
func _to_string():
	return "%s| '%s' %s" % [self.key, self.display_name, self.vote_percent]
