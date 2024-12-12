class_name GatewayClient
extends BaseClient


signal auth_failed
signal player_characters_received(player_characters: Dictionary)
signal login_succeeded(account_data: Dictionary, worlds_info: Dictionary)
signal authentication_token_received(_auth_token: String, _address: String, _port: int)
signal login_result_received(result: bool, message: String)
signal account_creation_result_received(result: bool, message: String)
signal player_character_creation_result_received(result: bool, message: String)
signal connection_changed(connected_to_server: bool)


var gateway: GatewayClient
var world_id: int

var config_file: ConfigFile
var secret_key := "super_secure_key"
var peer_id: int

var is_connected_to_server: bool = false:
	set(value):
		is_connected_to_server = value
		connection_changed.emit(value)


func _ready() -> void:
	GatewayUIComponent.gateway = self
	authentication_callback = auth_call
	load_client_configuration("gateway-client", "res://test_config/client_config.cfg")
	start_client()


func close_connection() -> void:
	multiplayer.set_multiplayer_peer(null)
	client.close()
	is_connected_to_server = false


func _on_connection_succeeded() -> void:
	print("Succesfuly connected to the gateway server as %d!" % multiplayer.get_unique_id())
	peer_id = multiplayer.get_unique_id()
	is_connected_to_server = true
	if OS.has_feature("debug"):
		DisplayServer.window_set_title("Gateway client - %d" % peer_id)


func _on_connection_failed() -> void:
	print("Failed to connect to the server.")
	close_connection()


func _on_server_disconnected() -> void:
	print("Server disconnected.")
	close_connection()
	get_tree().paused = true


func _on_peer_authenticating(_peer_id: int) -> void:
	print("Trying to authenticate to the server.")


func _on_peer_authentication_failed(_peer_id: int) -> void:
	print("Authentification to the server failed.")
	auth_failed.emit()
	close_connection()


func auth_call(_peer_id: int, data: PackedByteArray) -> void:
	var challenge: String = data.get_string_from_ascii()
	print("Authentification call from gateway with challenge: \"%s\"." % challenge)
	var version: String = ProjectSettings.get_setting("application/config/version")
	var response := {
		"challenge": challenge,
		"version": version,
		# Minimal security to avoid fake check version
		"signature": hash(challenge + version + secret_key)
	}
	multiplayer.send_auth(1, var_to_bytes(response))
	multiplayer.complete_auth(1)


@rpc("authority")
func fetch_auth_token(_auth_token: String, _address: String, _port: int) -> void:
	close_connection()
	authentication_token_received.emit(_auth_token, _address, _port)


@rpc("any_peer")
func login_request(_username: String, _password: String) -> void:
	pass


@rpc("authority")
func login_result(result_code: int) -> void:
	login_result_received.emit(result_code)


@rpc("any_peer")
func create_account_request(_username: String, _password: String, _is_guest: bool) -> void:
	pass


@rpc("authority")
func account_creation_result(result_code: int) -> void:
	account_creation_result_received.emit(result_code)


@rpc("any_peer")
func create_player_character_request(_character_data: Dictionary, _world_id: int) -> void:
	pass


@rpc("authority")
func player_character_creation_result(result_code: int) -> void:
	player_character_creation_result_received.emit(result_code)


@rpc("authority")
func successful_login(account_data: Dictionary, worlds_info: Dictionary) -> void:
	login_succeeded.emit(account_data, worlds_info)


@rpc("any_peer")
func request_player_characters(_world_id: int) -> void:
	pass
	

@rpc("any_peer")
func request_login(_c, _character_id: int) -> void:
	pass


@rpc("authority")
func receive_player_characters(player_characters: Dictionary) -> void:
	player_characters_received.emit(player_characters)


static func get_error_message(error_code: int) -> String:
	var message := ""
	if error_code == 1:
		message = "Username cannot be empty."
	elif error_code == 2:
		message = "Username too short. Minimum 3 characters."
	elif error_code == 3:
		message = "Username too long. Maximum 12 characters."
	elif error_code == 4:
		message = "Password cannot be empty."
	elif error_code == 5:
		message = "Password too short. Minimum 6 characters."
	elif error_code == 6:
		message = "Password too long. Max 30 characters."
	elif error_code == 7:
		message = "Please create an account first."
	elif error_code == 8:
		message = "Wrong class. Please choose a valid class."
	elif error_code == 9:
		message = "Invalid data format received."
	elif error_code == 30:
		message = "Username already exists."
	elif error_code == 50:
		message = "Invalid credentials."
	elif error_code == 51:
		message = "Account already in use."
	else:
		message = "Unknown error code: %d" % error_code
	return message
