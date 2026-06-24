class_name HttpResponse extends Object

@export var status_code: int
@export var headers: Dictionary
@export var body: String

func _init(_status_code: int, _headers: Dictionary, _body: String):
	self.status_code = _status_code
	self.headers = _headers
	self.body = _body
