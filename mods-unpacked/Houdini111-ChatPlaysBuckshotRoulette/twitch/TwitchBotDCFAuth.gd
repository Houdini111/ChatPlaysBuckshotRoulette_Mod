class_name TwitchBotDCFAuth extends Node

const LOGNAME = "ChatPlaysBuckshotRoulette:TwitchBotDCFAuth"
const CLIENT_ID = "u65td6agnsa42f169ju0oz2770sgcc"

const TWITCH_DCF_INIT_ENDPOINT = "https://id.twitch.tv/oauth2/device"
const TWITCH_OAUTH_TOKEN_ENDPOINT = "https://id.twitch.tv/oauth2/token"
const TWITCH_VERIFY_ENDPOINT = "https://id.twitch.tv/oauth2/validate"
const TWITCH_USERS_ENDPOINT = "https://api.twitch.tv/helix/users"

const HttpClientWrapper = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/HttpClientWrapper.gd")
const SecretsManager = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/SecretsManager.gd")

var secrets_manager: SecretsManager
var twitch_endpoint_wrapper: TwitchEndpointWrapper

var oauth_body: Dictionary
var bot_user_id: String
var auth_status_listeners: Array[Callable] = []
var auth_expiration_timer: Timer

func _init(_http_client_wrapper: HttpClientWrapper):
	self.name = "TwitchBotDCFAuth"
	self.secrets_manager = SecretsManager.new()
	self.twitch_endpoint_wrapper = TwitchEndpointWrapper.new(_http_client_wrapper, self.secrets_manager, self)
	self.auth_expiration_timer = Timer.new()
	self.auth_expiration_timer.name = "auth_expiration_timer"
	add_child.call_deferred(self.auth_expiration_timer)
	
func GetClientId() -> String:
	return CLIENT_ID

func GetAccessToken() -> String:
	return secrets_manager.GetAccessToken()
	
func GetUserAuthData() -> Dictionary: 
	return self.oauth_body

func ListenToAuthStatus(callback: Callable) -> void:
	auth_status_listeners.append(callback)
	
func _SendStatusToAuthStatusListeners(authenticated: bool) -> void:
	for listener in auth_status_listeners:
		listener.call(authenticated)

func VerifyAuthentication(try_refresh: bool = false) -> bool:
	var success = await _TryVerify()
	if !success && try_refresh:
		success = await _TryRefresh()
	_SendStatusToAuthStatusListeners(success)
	return success

func IsAuthorized() -> bool:
	return self.oauth_body != null && self.oauth_body != {} && bot_user_id != null && bot_user_id != ""
	
func GetUserData(usernames: Array[String]):
	var resp_body = await twitch_endpoint_wrapper.MakeTwitchUsersGetCall(usernames)
	if resp_body == null || resp_body == {}:
		return null
	var data = resp_body.get("data")
	if data == null || data.size() == 0:
		return null
	var user_entries = {}
	for user_data in data:
		user_entries[user_data.get("login")] = user_data
	return user_entries
	
func _TryVerify() -> bool:
	var response_body = await twitch_endpoint_wrapper.MakeVerifyCall()
	if response_body == null:
		return false
	var user_id = response_body.get("user_id")
	var expires_in = response_body.get("expires_in")
	if user_id == null || expires_in == null:
		ModLoaderLog.error("user_id or expires_in not found on verify response body. Not Null: [%s, %s]" % [user_id != null,  expires_in != null], LOGNAME)
		self.oauth_body = {}
		self.bot_user_id = ""
		self.auth_expiration_timer.stop()
		return false
	self.oauth_body = response_body
	self.bot_user_id = user_id
	self.auth_expiration_timer.start(int(expires_in))
	return true
	
func _TryRefresh() -> bool:
	var response_body = await twitch_endpoint_wrapper.MakeRefreshCall()
	if response_body == null:
		ModLoaderLog.warning("Refresh response was not good. Failed refresh. User will need to reauthenticate", LOGNAME)
		return false
	var access_token = response_body.get("access_token")
	var refresh_token = response_body.get("refresh_token")
	if access_token == null || refresh_token == null:
		ModLoaderLog.error("access_token or refresh_token not found on refresh response body. Not Null: [%s, %s]" % [access_token != null,  refresh_token != null], LOGNAME)
		return false
	secrets_manager.UpdateSecrets(response_body)
	# Now verify that token works and get user data
	return await VerifyAuthentication()

func StartDCFlow():
	ModLoaderLog.info("Starting DCFlow for authentication", LOGNAME)
	var dcf_response = await twitch_endpoint_wrapper.MakeInitialDCFlowCall()
	if dcf_response == null:
		ModLoaderLog.error("Twitch DCFlow call failed", LOGNAME)
		return
	var dcf_dict := dcf_response as Dictionary
	var device_code = dcf_dict.get("device_code")
	var user_code = dcf_dict.get("user_code")
	var verification_uri = dcf_dict.get("verification_uri")
	
	ModLoaderLog.info("Recieved user_code for user: %s" % user_code, LOGNAME)
	
	OS.shell_open(verification_uri)
	var options_menu = Engine.get_singleton("ChatPlaysOptionsMenu") as ChatPlaysOptionsMenu
	if is_instance_valid(options_menu):
		options_menu.ShowUserCodePopup(user_code)
	
	_WaitForValidAccessTokenResponse(device_code)

func _WaitForValidAccessTokenResponse(device_code: String) -> void:
	while true:
		var response = await self.twitch_endpoint_wrapper.MakeAccessTokenDCFlowCall(device_code)
		if response == null:
			ModLoaderLog.error("Recieved a null response object from DCF access call. Call didn't even make it through. Cancelling", LOGNAME)
			return
		var response_body = JSON.parse_string(response.body)
		if response.status_code == 200:
			ModLoaderLog.info("User has authorized app. Finalizing auth", LOGNAME)
			# Got a successful response
			_HandleNewUserAuth(response_body)
			return
		if response.status_code == 400:
			# Check which kind of bad response
			var message = response_body.get("message")
			if message == "authorization_pending":
				ModLoaderLog.debug("User hasn't finished authorizing app yet. Waiting", LOGNAME)
				# All good. User just hasn't completed the popup yet.
				#   Sleep for a second before trying again.
				await get_tree().create_timer(1).timeout
				continue
			elif message == "invalid devicecode":
				# Uh oh. Our device code is invalid. We have to start the flow from scratch
				# Should never happen unless the user changes the data on the webpage?
				ModLoaderLog.error("Recieved 'invalid device code' response. Something went wrong with DCflow. Will need to retry from start", LOGNAME)
				# TODO: Handle restarting auth flow
				return
			elif message == "Invalid refresh token":
				# The token has already been exchanged for a user token? 
				ModLoaderLog.error("Recieved 'Invalid refresh token' response. Duplicate processes? Will need to retry from start", LOGNAME)
				return
			else:
				ModLoaderLog.error("Unhandled error message '%s'" % message, LOGNAME)
				return
		else:
			ModLoaderLog.error("Unhandled status code '%s'" % response.status_code, LOGNAME)

func _HandleNewUserAuth(response_body: Dictionary) -> void:
	if response_body == null:
		ModLoaderLog.error("Given a null New User Auth. Cancelling", LOGNAME)
		return
	var saved_successfully := secrets_manager.UpdateSecrets(response_body)
	if saved_successfully:
		var expires_in = response_body.get("expires_in")
		self.auth_expiration_timer.start(int(expires_in))
	else:
		ModLoaderLog.error("Secrets failed to be saved. See previous message. Authentication calls will fail", LOGNAME)
	var success = await VerifyAuthentication()
	if success:
		var options_menu = Engine.get_singleton("ChatPlaysOptionsMenu") as ChatPlaysOptionsMenu
		if is_instance_valid(options_menu):
			options_menu.HideUserCodePopup()

func _AuthExpired() -> void:
	var success = await _TryRefresh()
	# TODO: Make status message?
	if success:
		ModLoaderLog.info("Token expired but auto refresh worked. Continuing on as normal", LOGNAME)
	else:
		ModLoaderLog.error("Token expired and auto refresh did not work", LOGNAME)
		self.oauth_body = {}
		self.bot_user_id = ""
		self.auth_expiration_timer.stop()
