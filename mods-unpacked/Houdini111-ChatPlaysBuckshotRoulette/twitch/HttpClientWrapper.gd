class_name HttpClientWrapper extends Node

const LOGNAME = "ChatPlaysBuckshotRoulette:HttpClientWrapper"

const HttpResponse = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/HttpResponse.gd")

var httpClient: HTTPClient

func _init(): 
	self.httpClient = HTTPClient.new()

func MakeHttpRequest(http_verb: HTTPClient.Method, endpoint: String, headers: PackedStringArray, body: String = "") -> HttpResponse:
	# Largely based on https://docs.godotengine.org/en/stable/tutorials/networking/http_client_class.html
	var endpoint_full_split = endpoint.split("//")
	var protocol = endpoint_full_split[0]
	var endpoint_without_protocol = endpoint_full_split[1]
	var endpoint_split = endpoint_without_protocol.split("/")
	var base_url = "%s//%s" % [protocol, endpoint_split[0]]
	
	var gdClientCode = httpClient.connect_to_host(base_url)
	if (gdClientCode != OK):
		ModLoaderLog.info("HttpClient connect code not okay. Was '%s'. Exiting" % error_string(gdClientCode), LOGNAME)
		return null
		
	while httpClient.get_status() == HTTPClient.STATUS_CONNECTING || httpClient.get_status() == HTTPClient.STATUS_CONNECTING || httpClient.get_status() == HTTPClient.STATUS_RESOLVING || httpClient.get_status() == HTTPClient.STATUS_REQUESTING:
		httpClient.poll()
#		print("Connecting...")
		await _sleep()
	if (httpClient.get_status() != HTTPClient.STATUS_CONNECTED):
		ModLoaderLog.info("Failed to connect to site. Client status code: '%s'. Exiting" % httpClient.get_status(), LOGNAME)
		return null
	
	var response = await _SendRequest(http_verb, endpoint, headers, body)
	
	if response == null && httpClient.get_status() == HTTPClient.STATUS_CONNECTED:
		ModLoaderLog.info("Had no response but client status is still just connected. Trying to send again", LOGNAME)
		response = await _SendRequest(http_verb, endpoint, headers, body)
	return response
	
func _SendRequest(http_verb: HTTPClient.Method, endpoint: String, headers: PackedStringArray, body: String = ""):
	var gdClientCode = httpClient.request(http_verb, endpoint, headers, body)
	if (gdClientCode != OK):
		ModLoaderLog.info("HttpClient request code not okay. Was '%s'. Exiting" % error_string(gdClientCode), LOGNAME)
		return null
	
	while httpClient.get_status() == HTTPClient.STATUS_REQUESTING || httpClient.get_status() == HTTPClient.STATUS_CONNECTING:
		httpClient.poll()
#		print("POSTing...")
		await _sleep()
	if (!(httpClient.get_status() == HTTPClient.STATUS_BODY || httpClient.get_status() == HTTPClient.STATUS_CONNECTED)):
		ModLoaderLog.info("Failed to make request to site. Client status code: '%s'. Exiting" % httpClient.get_status(), LOGNAME)
		return null
	
	if httpClient.has_response():
		var response_headers = httpClient.get_response_headers_as_dictionary()
		var response_code = httpClient.get_response_code()
		ModLoaderLog.info("Recieved HTTP response code %s from site" % str(response_code), LOGNAME)
		var response_body_raw = await ReadBody()
		# Technically this is an assumption. I'm not checking if the headers say it's a different encoding
		var response_body_str = response_body_raw.get_string_from_utf8()
		var response = HttpResponse.new(response_code, response_headers, response_body_str)
		return response
	ModLoaderLog.info("Request had no response. httpClient code: '%s'" % httpClient.get_status(), LOGNAME)
	return null

func ReadBody() -> PackedByteArray:
	var rb = PackedByteArray()
	while httpClient.get_status() == HTTPClient.STATUS_BODY:
		# While there is body left to be read
		httpClient.poll()
		# Get a chunk.
		var chunk = httpClient.read_response_body_chunk()
		if chunk.size() == 0:
			await _sleep()
		else:
			rb = rb + chunk # Append to read buffer.
	return rb
	
func _sleep():
	await get_tree().process_frame
