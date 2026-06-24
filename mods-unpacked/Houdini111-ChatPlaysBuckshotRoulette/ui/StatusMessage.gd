class_name StatusMessage extends Label

@export var id: int
@export var timer: Timer
@export var background_rect: ColorRect

@export var time_to_show: float
@export var hide_listeners: Array[Callable] = []

func _init(_message: String, time: float = -1):
	id = randi()
	self.name = "MessageText"
	self.set_anchors_preset(PRESET_TOP_WIDE)
	self.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	self.text = _message
	
	self.background_rect = ColorRect.new()
	self.background_rect.name = "background_rect"
	self.add_child.call_deferred(self.background_rect)
	self.background_rect.set_anchors_preset(PRESET_FULL_RECT)
	self.background_rect.color = Color(0, 0, 0, 0.75)
	self.background_rect.show_behind_parent = true
	
	if time > 0:
		timer = Timer.new()
		timer.name = "MessageTimer"
		add_child.call_deferred(timer)
		time_to_show = time
		timer.timeout.connect(HideMessage)
	self.name = "StatusMessage %s" % id

func _ready():
	if timer != null && timer.is_stopped() && time_to_show > 0:
		timer.start(time_to_show)

func HideMessage():
	for hide_listener in hide_listeners:
		hide_listener.call(id)
	queue_free()

func ListenToHide(callback: Callable):
	hide_listeners.append(callback)
