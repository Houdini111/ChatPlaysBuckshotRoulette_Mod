class_name TwitchBotChatInterface extends Node

const EVENTSUB_WEBSOCKET_URL = 'wss://eventsub.wss.twitch.tv/ws';
const TWITCH_BASE_URL = "https://api.twitch.tv"
const REGISTER_EVENT_SUB_ENDPOINT = "/helix/eventsub/subscriptions"
const SEND_MESSAGE_ENDPOINT = "/helix/chat/messages"

const LOGNAME = "ChatPlaysBuckshotRoulette:TwitchBotChatter"

const TwitchBotDCFAuth = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/TwitchBotDCFAuth.gd")
const HttpClientWrapper = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/HttpClientWrapper.gd")

var auth: TwitchBotDCFAuth
var http_client_wrapper: HttpClientWrapper
var web_socket: WebSocketPeer
var bot_user_id: String
var channel_user_id: String
var websocket_session_id: String
var websocket_connected_listener: Callable
var message_listener: Callable

var first_connection := true
var keepalive_timeout_seconds: int
var timeout_timer_running: bool
var timeout_timer: float

func _init(_auth: TwitchBotDCFAuth, _http_client_wrapper: HttpClientWrapper, _websocket_connected_listener: Callable, _message_listener: Callable):
	self.auth = _auth
	self.http_client_wrapper = _http_client_wrapper
	self.websocket_connected_listener = _websocket_connected_listener
	self.message_listener = _message_listener
	
	self.timeout_timer = false
	self.timeout_timer = 0
	
	self.web_socket = WebSocketPeer.new()
	var sleep_method = func(): get_tree().process_frame
	
	set_process(false)

func _process(delta):
	if timeout_timer_running:
		timeout_timer = maxf(0, timeout_timer - delta)
		if timeout_timer <= 0:
			timeout_timer_running = false
			_WebsocketTimerDisconnect()
	web_socket.poll()
	var socket_state = web_socket.get_ready_state()
	if socket_state == WebSocketPeer.STATE_OPEN:
		while web_socket.get_available_packet_count() > 0:
			var packet = web_socket.get_packet()
			if web_socket.was_string_packet():
				var packet_text = packet.get_string_from_utf8()
#				ModLoaderLog.debug("< Got text data from server: %s" % packet_text, LOGNAME)
				_SocketMessage(packet_text)
			else:
				pass
				#ModLoaderLog.debug("< Got binary data from server: %d bytes" % packet.size(), LOGNAME)

	elif socket_state == WebSocketPeer.STATE_CLOSING:
		pass
	elif socket_state == WebSocketPeer.STATE_CLOSED:
		# The code will be `-1` if the disconnection was not properly notified by the remote peer.
		var code = web_socket.get_close_code()
		print("WebSocket closed with code: %d. Clean: %s" % [code, code != -1])
		set_process(false) 
			
func StartWebsocketClient(_bot_user_id: String, _channel_user_id: String, socket_url: String = EVENTSUB_WEBSOCKET_URL):
	# TODO: Check if already connected before trying again
	ModLoaderLog.info("Starting websocket client", LOGNAME)
	self.bot_user_id = _bot_user_id
	self.channel_user_id = _channel_user_id
	if (self.bot_user_id == null || self.bot_user_id == "" || self.channel_user_id == null || self.channel_user_id == ""):
		ModLoaderLog.error("Cannot start websocket. Missing user IDs. IDs (bot, channel): [%s, %s]" % [self.bot_user_id, self.channel_user_id], LOGNAME)
		return
	var socket_code = web_socket.connect_to_url(socket_url)
	if socket_code != OK:
		ModLoaderLog.error("Failed to connect to websocket: %s" % error_string(socket_code), LOGNAME)
		return
	set_process(true)
	
func CloseWebsocketClient():
	web_socket.close()
	set_process(false)

func SendMessage(message: String):
	var response = await _MakeMessagePostCall(message)
	if response == null:
		ModLoaderLog.error("Failed to send message to channel", LOGNAME)

func _SocketMessage(message):
	var message_json = JSON.parse_string(message)
	var metadata = message_json.get("metadata")
	var payload = message_json.get("payload")
	# Any message trigger keepalive timer to be reset
	timeout_timer = keepalive_timeout_seconds
	match metadata.message_type:
		"session_welcome":
			websocket_session_id = payload.session.id
			# Probably due to lag, keepalive messages don't always make it in time
			#  So I'm adding a bit of buffer
			keepalive_timeout_seconds = round(payload.session.keepalive_timeout_seconds * 1.25) 
			_RegisterEventSubListeners()
		"session_keepalive":
			# Already handled by above
			pass
		"notification":
			_HandleChatMessage(metadata, payload)
		"session_reconnect":
			ModLoaderLog.error("Twitch requested session reconnect. Not currently handled", LOGNAME)
			var new_socket_url = payload.session.reconnect_url
			# TODO: Switch to new socket URL
			pass
		"revocation":
			ModLoaderLog.error("Twitch revoking websocket connection. Closing", LOGNAME)
			CloseWebsocketClient()
		_:
			ModLoaderLog.warning("Unknown and unhandled socket message type [%s]" % metadata.message_type, LOGNAME)


func _HandleChatMessage(metadata: Dictionary, payload: Dictionary):
	if payload == null:
		return
	var event = payload.get("event")
	if event == null:
		return
	var username = event.get("chatter_user_name")
	var message = event.get("message")
	if username == null || message == null:
		return
	var message_text = message.get("text")
	if message_text == null:
		return
	ModLoaderLog.debug("RECIEVED MESSAGE FROM USER [%s] SAYING [%s]" % [username, message_text], LOGNAME)
	message_listener.call(message_text, username)
	
func _RegisterEventSubListeners():
	ModLoaderLog.info("Attempting to register event sub listener with websocket", LOGNAME)
	if (self.bot_user_id == null || self.bot_user_id == "" || self.channel_user_id == null || self.channel_user_id == ""):
		ModLoaderLog.error("Attempting to register event sub listeners but missing user IDs. IDs (bot, channel): [%s, %s]" % [self.bot_user_id, self.channel_user_id], LOGNAME)
		return
	var event_sub_type = "channel.chat.message"
	var headers = [
		"Authorization: Bearer %s" % auth.GetAccessToken(),
		"Client-Id: %s" % auth.GetClientId(),
		"Content-Type: application/json"
	]
	var body = JSON.stringify({
		"type": event_sub_type,
		"version": "1",
		"condition": {
			"broadcaster_user_id": channel_user_id,
			"user_id": bot_user_id
		},
		"transport": {
			"method": "websocket",
			"session_id": websocket_session_id
		}
	})
	var httpResponse = await http_client_wrapper.MakeHttpRequest(HTTPClient.METHOD_POST, TWITCH_BASE_URL + REGISTER_EVENT_SUB_ENDPOINT, headers, body)
	if httpResponse == null:
		ModLoaderLog.error("Failed to make Twitch Event Sub POST", LOGNAME)
	if httpResponse.status_code != 202:
		ModLoaderLog.error("Recieved non-200 response from Twitch Event Sub POST. Status code: [%s] Response Body: \n%s" % [httpResponse.status_code, httpResponse.body], LOGNAME)
		return null
	
	var event_sub_response = JSON.parse_string(httpResponse.body)
	if (event_sub_response == null):
		ModLoaderLog.error("Failed to parse EventSub response body?", LOGNAME)
	
	ModLoaderLog.info("Successfully subscribed to event_sub %s" % event_sub_type, LOGNAME)
	websocket_connected_listener.call(first_connection)
	first_connection = false
	timeout_timer_running = true
	timeout_timer = keepalive_timeout_seconds
	return event_sub_response

func _MakeMessagePostCall(message: String):
	var headers = [
		'Authorization: Bearer %s' % auth.GetAccessToken(),
		'Client-Id: %s' % auth.GetClientId(),
		'Content-Type: application/json'
	]
	var body_raw = {
		"broadcaster_id": channel_user_id,
		"sender_id": bot_user_id,
		"message": message
	}
	var body_str = JSON.stringify(body_raw)
	return await http_client_wrapper.MakeHttpRequest(HTTPClient.METHOD_POST, TWITCH_BASE_URL + SEND_MESSAGE_ENDPOINT, headers, body_str)

func _WebsocketTimerDisconnect() -> void:
	ModLoaderLog.info("Websocket keepalive ended. Attempting to re-register websocket", LOGNAME)
	# Make sure connection is closed
	web_socket.close()
	while web_socket.get_ready_state() != web_socket.STATE_CLOSED:
		web_socket.poll()
		await get_tree().process_frame
	# And then try opening again
	StartWebsocketClient(self.bot_user_id, self.channel_user_id)
