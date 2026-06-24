class_name TwitchOAuthServer extends Node

const LOGNAME = "ChatPlaysBuckshotRoulette:TwitchOAuthServer"

var port: int
var server: TCPServer
var callback: Callable

# Made based on https://github.com/Kermer/Godot/blob/master/Tutorials/tut_tcp_connection.md
func _init(_port: int, _callback: Callable):
	self.port = _port
	self.callback = _callback
	self.server = TCPServer.new()
	
	var listen_open_code = self.server.listen(port)
	if (listen_open_code != OK):
		ModLoaderLog.error("Failed to open TCPServer on port %s" % port, LOGNAME)
	
	
func _process(delta):
	if server.is_connection_available():
		ModLoaderLog.info("Recieved request to connect", LOGNAME)
		WebSocketPeer
		var client = server.take_connection()
		ModLoaderLog.info("Connected to client at [%s:%s]" % [client.get_connected_host(), client.get_connected_port()], LOGNAME)
		
		# I'm only handling GET requests. So take the request and handle it immediately
		var client_bytes_available = client.get_available_bytes()
		var request_data = []
		if client_bytes_available > 0:
			request_data = client.get_utf8_string(client_bytes_available)
		
		var auth_code = null
		var csrf = null
		var response = ""
		
		var request_data_split = request_data.split(' ')
		var http_method = request_data_split[0]
		if http_method != "GET":
			response = "ERROR. Expected a GET request but recieved a %s" % http_method
		else:
			response = "Authorized. You may now close this window."
			# /?code=qn8jqx98cr7ecwtr7cxxs2kep9vyse&scope=user%3Aread%3Achat+user%3Awrite%3Achat
			var url_string = request_data_split[1]
			url_string = url_string.trim_prefix("/?")
			var url_parameters = _ParseUrlParameters(url_string)
			if url_parameters.has("error"):
				response = "ERROR: %s" % url_parameters.get("error_description")
			else:
				auth_code = url_parameters.get("code")
				csrf = url_parameters.get("state")
		
		var response_bytes = response.to_utf8_buffer()
		client.put_data(response_bytes)
		
		callback.call(auth_code, csrf)

func _ParseUrlParameters(url_string: String) -> Dictionary:
	var url_parameters_raw = url_string.split("&")
	var url_parameters = {}
	for url_param_raw in url_parameters_raw:
		var param_split = url_param_raw.split('=')
		var param_name = param_split[0]
		var param_value = param_split[1]
		url_parameters[param_name] = param_value
	return url_parameters

func CloseServer():
	server.stop()
