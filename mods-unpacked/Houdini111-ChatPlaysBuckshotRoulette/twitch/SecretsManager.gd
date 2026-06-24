class_name SecretsManager extends Object

const LOGNAME = "ChatPlaysBuckshotRoulette:SecretsManager"

const TOKEN_SECRETS_PATH := "user://chatplays_tokens.dat"

var token_secrets_pass: PackedByteArray
var token_secrets: Dictionary

func _init():
	# Godot warns against using get_unique_id for encryption.
	#  However, this is a low stakes usage. The user can just re-auth if needed. 
	#  As such, I'm ignoring the warning.
	self.token_secrets_pass = OS.get_unique_id().to_ascii_buffer()
	LoadSecrets()
	
func LoadSecrets():
	if FileAccess.file_exists(TOKEN_SECRETS_PATH):
		var token_secrets_file = FileAccess.open_encrypted(TOKEN_SECRETS_PATH, FileAccess.READ, token_secrets_pass)
		var error = error_string(FileAccess.get_open_error())
		if token_secrets_file != null:
			var token_secrets_str = token_secrets_file.get_as_text()
			if token_secrets_str != null && token_secrets_str != "":
				self.token_secrets = JSON.parse_string(token_secrets_str)
	else:
		ModLoaderLog.error("No auth tokens found. User will need to authorize before use", LOGNAME)
		self.token_secrets = {}

func _SaveTokens():
	# WRITE_READ purges the file if it already exists
	# However, open_encrypted does not support WRITE_READ mode, 
	#  so we have to purge the file ourselves
	# This was fixed in Godot 4.3
	ModLoaderLog.info("Saving token secrets to file", LOGNAME)
	if FileAccess.file_exists(TOKEN_SECRETS_PATH):
		DirAccess.remove_absolute(TOKEN_SECRETS_PATH)
	var secrets_file = FileAccess.open_encrypted(TOKEN_SECRETS_PATH, FileAccess.WRITE, token_secrets_pass)
	secrets_file.store_string(JSON.stringify(token_secrets))
	ModLoaderLog.info("Successfully saved token secrets to file", LOGNAME)
	
func UpdateSecrets(oAuthResponse: Dictionary) -> bool:
	if oAuthResponse == null:
		return false
	var access_token = oAuthResponse.get("access_token")
	var refresh_token = oAuthResponse.get("refresh_token")
	if (access_token == null || refresh_token == null):
		ModLoaderLog.error("Response body did not contain access_token or refresh_token. Not Null?: [%s, %s]" % [access_token != null, refresh_token != null], LOGNAME)
		return false
	token_secrets["accessToken"] = access_token
	token_secrets["refreshToken"] = refresh_token
	ModLoaderLog.info("Updated config secrets. Saving now", LOGNAME)
	_SaveTokens()
	return true

func GetAccessToken() -> String:
	return token_secrets.get("accessToken", "")
	
func GetRefreshToken() -> String:
	return token_secrets.get("refreshToken", "")
