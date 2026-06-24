class_name StatusMessages extends Control

const StatusMessage = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/ui/StatusMessage.gd")

const LOGNAME = "ChatPlaysBuckshotRoulette:StatusMessages"

@export var messages: Dictionary = {}
var layout: VBoxContainer

func _init():
	self.set_anchors_preset(Control.PRESET_FULL_RECT)
	self.layout = VBoxContainer.new()
	self.layout.name = "MessagesContainer"
	self.add_child.call_deferred(self.layout)
	self.layout.set_anchors_preset(Control.PRESET_FULL_RECT)

func ShowMessageForTime(message: String, time: float) -> int:
	ModLoaderLog.debug("Showing message [%s] for %s" % [message, time], LOGNAME)
	return _AddMessage(message, time)
	
func ShowMessageForever(message: String) -> int:
	ModLoaderLog.debug("Showing message [%s] forever" % message, LOGNAME)
	return _AddMessage(message, -1)

func _AddMessage(message: String, time: float):
	var status_message = StatusMessage.new(message, time)
	messages[status_message.id] = status_message
	self.layout.add_child.call_deferred(status_message)
	status_message.ListenToHide(RemoveMessage)
	return status_message.id

func RemoveMessage(id: int):
	var message = messages.get(id)
	if message != null:
		message.queue_free()
	messages.erase(id)
