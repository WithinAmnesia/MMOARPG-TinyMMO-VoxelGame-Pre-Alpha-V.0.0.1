class_name WorldManagerServer
extends BaseServer


@export var authentication_manager: AuthenticationManager
@export var gateway_manager: GatewayManagerServer
@export var database: MasterDatabase

# Active Connections
var next_world_id: int = 0
var connected_worlds: Dictionary

func _ready() -> void:
	load_server_configuration("world-manager-server", "res://test_config/master_server_config.cfg")
	start_server()


func _on_peer_connected(peer_id: int) -> void:
	print("Gateway: %d is connected to GatewayManager." % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("Gateway: %d is disconnected to GatewayManager." % peer_id)


@rpc("any_peer")
func fetch_server_info(info: Dictionary) -> void:
	var game_server_id := multiplayer_api.get_remote_sender_id()
	connected_worlds[game_server_id] = info
	gateway_manager.update_worlds_info.rpc(connected_worlds)
	print(connected_worlds)


@rpc("authority")
func fetch_token(_auth_token: String, _username: String, _character_id: int) -> void:
	pass


@rpc("any_peer")
func player_disconnected(username: String) -> void:
	database.account_collection.collection[username].peer_id = 0


@rpc("authority")
func create_player_character_request(_gateway_id: int, _peer_id: int, _username: String, _character_data: Dictionary) -> void:
	pass


@rpc("any_peer")
func player_character_creation_result(gateway_id: int, peer_id: int, username: String, result_code: int) -> void:
	var world_id := multiplayer_api.get_remote_sender_id()
	if result_code:
		var auth_token := authentication_manager.generate_random_token()
		fetch_token.rpc_id(world_id, auth_token, username, result_code)
		gateway_manager.player_character_creation_result.rpc_id(
			gateway_id, peer_id, result_code
		)
		await get_tree().create_timer(0.5).timeout
		gateway_manager.fetch_auth_token.rpc_id(
			gateway_id, peer_id, auth_token,
			connected_worlds[world_id]["address"],
			connected_worlds[world_id]["port"]
		)
	else:
		gateway_manager.player_character_creation_result.rpc_id(
			gateway_id, peer_id, result_code
		)


@rpc("any_peer")
func request_player_characters(_gateway_id: int, _peer_id: int, _username: String) -> void:
	pass


@rpc("any_peer")
func request_login(_gateway_id: int, _peer_id: int, _username: String, _character_id: int) -> void:
	pass


@rpc("any_peer")
func result_login(result_code: int, gateway_id: int, peer_id: int, username: String, character_id: int) -> void:
	var world_id := multiplayer_api.get_remote_sender_id()
	if result_code == OK:
		var auth_token := authentication_manager.generate_random_token()
		fetch_token.rpc_id(world_id, auth_token, username, character_id)
		await get_tree().create_timer(0.5).timeout
		gateway_manager.fetch_auth_token.rpc_id(
			gateway_id, peer_id, auth_token,
			connected_worlds[world_id]["address"],
			connected_worlds[world_id]["port"]
		)


@rpc("any_peer")
func receive_player_characters(player_characters: Dictionary, gateway_id: int, peer_id: int) -> void:
	gateway_manager.receive_player_characters.rpc_id(
		gateway_id, peer_id, player_characters
	)
