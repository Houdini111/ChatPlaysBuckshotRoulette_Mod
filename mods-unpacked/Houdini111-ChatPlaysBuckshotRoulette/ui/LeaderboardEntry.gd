class_name LeaderboardEntry extends Object

@export var key: String
@export var vote_percent: float

func _init(_key: String, _vote_percent: float):
	self.key = _key
	self.vote_percent = _vote_percent
	
func _to_string():
	return "%s: %s" % [self.key, self.vote_percent]
