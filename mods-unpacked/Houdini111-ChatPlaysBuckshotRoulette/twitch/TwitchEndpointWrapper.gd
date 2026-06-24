class_name TwitchEndpointWrapper extends Node

const LOGNAME = "ChatPlaysBuckshotRoulette:TwitchEndpointWrapper"

const TWITCH_DCF_INIT_ENDPOINT = "https://id.twitch.tv/oauth2/device"
const TWITCH_OAUTH_TOKEN_ENDPOINT = "https://id.twitch.tv/oauth2/token"
const TWITCH_VERIFY_ENDPOINT = "https://id.twitch.tv/oauth2/validate"
const TWITCH_USERS_ENDPOINT = "https://api.twitch.tv/helix/users"

const HttpClientWrapper = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/HttpClientWrapper.gd")
const SecretsManager = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/SecretsManager.gd")
const TwitchBotDCFAuth = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/TwitchBotDCFAuth.gd")

var http_client_wrapper: HttpClientWrapper
var secrets_manager: SecretsManager
var twitch_bot_auth: TwitchBotDCFAuth

var csrf_token: String

func _init(_http_client_wrapper: HttpClientWrapper, _secrets_manager: SecretsManager, _twitch_bot_auth: TwitchBotDCFAuth):
	self.http_client_wrapper = _http_client_wrapper
	self.secrets_manager = _secrets_manager
	self.twitch_bot_auth = _twitch_bot_auth

func MakeInitialDCFlowCall():
	var headers = [
		_GetFormEncodedHeader()
	]
	var request_body = [
		"client_id=%s" % self.twitch_bot_auth.GetClientId(),
		"scopes=%s" % _GetScopesStr()
	]
	var request_body_str = '&'.join(request_body)
	var response = await http_client_wrapper.MakeHttpRequest(HTTPClient.METHOD_POST, TWITCH_DCF_INIT_ENDPOINT, headers, request_body_str)
	if response == null:
		ModLoaderLog.error("Failed during initial DCFlow call. Null response", LOGNAME)
		return null
	if response.status_code != 200:
		ModLoaderLog.error("Recieved non-200 response from Twitch initial DCF POST. Status code: [%s] Response Body: \n%s" % [response.status_code, response.body], LOGNAME)
		return null
	
	var response_body = JSON.parse_string(response.body)
	if (response_body == null):
		ModLoaderLog.error("Failed to parse initial DCFlow response body?", LOGNAME)
		return null
	return response_body

# Unlike the other _Make...Call methods, this one will return the response object so we can check the status_code ourselves 
func MakeAccessTokenDCFlowCall(device_code: String):
	var headers = [
		_GetFormEncodedHeader()
	]
	var request_body = [
		"client_id=%s" % self.twitch_bot_auth.GetClientId(),
		"scopes=%s" % _GetScopesStr(),
		"device_code=%s" % device_code,
		"grant_type=urn:ietf:params:oauth:grant-type:device_code"
	]
	var request_body_str = '&'.join(request_body)
	return await http_client_wrapper.MakeHttpRequest(HTTPClient.METHOD_POST, TWITCH_OAUTH_TOKEN_ENDPOINT, headers, request_body_str)
	
func MakeVerifyCall():
	var auth_token = secrets_manager.GetAccessToken()
	if auth_token == null:
		ModLoaderLog.warning("No auth token found. Nothing to verify", LOGNAME)
		return null
	var request_headers = [
		"Authorization: OAuth %s" % auth_token
	]
	var http_response = await http_client_wrapper.MakeHttpRequest(HTTPClient.METHOD_GET, TWITCH_VERIFY_ENDPOINT, request_headers)
	if http_response == null:
		ModLoaderLog.error("Failed to make Twitch OAuth verify GET", LOGNAME)
		return null
	if http_response.status_code != 200:
		ModLoaderLog.error("Recieved non-200 response from Twitch OAuth verify GET. Status code: [%s] Response Body: \n%s" % [http_response.status_code, http_response.body], LOGNAME)
		return null
	
	var oauth_body = JSON.parse_string(http_response.body)
	if (oauth_body == null):
		ModLoaderLog.error("Failed to parse OAuth verify GET response body?", LOGNAME)
		return null
	
	return oauth_body
	
func MakeRefreshCall():
	var refresh_token = secrets_manager.GetRefreshToken()
	if refresh_token == null:
		ModLoaderLog.warning("No refresh token found. Nothing to refresh with", LOGNAME)
		return null
	var request_headers = [
		_GetFormEncodedHeader()
	]
	var body = [
		"client_id=%s" % self.twitch_bot_auth.GetClientId(),
		"refresh_token=%s" % refresh_token,
		"grant_type=refresh_token"
	]
	var body_str = "&".join(body)
	var http_response = await http_client_wrapper.MakeHttpRequest(HTTPClient.METHOD_POST, TWITCH_VERIFY_ENDPOINT, request_headers, body_str)
	if http_response == null:
		ModLoaderLog.error("Failed to make Twitch OAuth refresh POST", LOGNAME)
		return null
	if http_response.status_code != 200:
		ModLoaderLog.error("Recieved non-200 response from Twitch OAuth refresh POST. Status code: [%s] Response Body: \n%s" % [http_response.status_code, http_response.body], LOGNAME)
		return null
	
	var oauth_body = JSON.parse_string(http_response.body)
	if (oauth_body == null):
		ModLoaderLog.error("Failed to parse OAuth refresh POST response body?", LOGNAME)
		return null
	
	return oauth_body
	
func MakeTwitchUsersGetCall(usernames: Array[String]):
	if !twitch_bot_auth.IsAuthorized():
		return null
	var headers = [
		"Authorization: Bearer %s" % secrets_manager.GetAccessToken(),
		"Client-Id: %s" % twitch_bot_auth.GetClientId()
	]
	var username_params = '&login='.join(usernames)
	var endpoint_with_parameters = "%s?login=%s" % [TWITCH_USERS_ENDPOINT, username_params]
	var httpResponse = await http_client_wrapper.MakeHttpRequest(HTTPClient.METHOD_GET, endpoint_with_parameters, headers)
	if httpResponse == null:
		ModLoaderLog.error("Failed to make Twitch Users GET", LOGNAME)
		return null
	if httpResponse.status_code != 200:
		ModLoaderLog.error("Recieved non-200 response from Twitch Users GET. Status code: [%s] Response Body: \n%s" % [httpResponse.status_code, httpResponse.body], LOGNAME)
		return null
	
	var get_body = JSON.parse_string(httpResponse.body)
	if (get_body == null):
		ModLoaderLog.error("Failed to parse Users GET response body?", LOGNAME)
		return null
	
	return get_body
	
func _GetFormEncodedHeader() -> String:
	return "Content-Type: application/x-www-form-urlencoded"
	
func _GetScopesStr() -> String:
	var scopes := [
		"user:read:chat",
		"user:write:chat"
	]
	return (" ".join(scopes)).uri_encode()

func _GenerateCsrfToken() -> String:
	var bytes := PackedByteArray()
	bytes.resize(16)
	var temp = 0
	for i in range(16):
		# 16 values for 10 numbers and 6 numbers
		temp = randi()%16
		#
		bytes[i] = temp + 48 if temp < 10 else temp + 55
	return bytes.get_string_from_ascii()
