extends SceneTree

var _checks: int
var _failures: int


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var eventsub_script: Script = load("res://addons/twitcher/eventsub/twitch_eventsub.gd")
	_check(eventsub_script != null, "EventSub script loads")
	if eventsub_script == null:
		quit(1)
		return
	_check(TwitchEventsubDefinition.CHANNEL_FOLLOW.response_script is Script, "definition resolves response script")

	var never_entered: TwitchEventsub = eventsub_script.new()
	var never_entered_client: WebsocketClient = never_entered.get_client()
	var never_entered_test_client: WebsocketClient = never_entered.get_test_client()
	never_entered.free()
	_check(not is_instance_valid(never_entered_client), "never-entered active client freed")
	_check(not is_instance_valid(never_entered_test_client), "never-entered test client freed")

	var reattached: TwitchEventsub = eventsub_script.new()
	var reattached_client: WebsocketClient = reattached.get_client()
	var reattached_test_client: WebsocketClient = reattached.get_test_client()
	root.add_child(reattached)
	await process_frame
	root.remove_child(reattached)
	root.add_child(reattached)
	await process_frame
	_check(is_instance_valid(reattached_client) and reattached_client.get_parent() == reattached, "active client survives reattach")
	_check(is_instance_valid(reattached_test_client), "test client survives reattach")
	reattached.free()
	_check(not is_instance_valid(reattached_client), "parented active client freed")
	_check(not is_instance_valid(reattached_test_client), "unparented test client freed")

	var test_mode: TwitchEventsub = eventsub_script.new()
	test_mode.use_test_server = true
	var parented_test_client: WebsocketClient = test_mode.get_test_client()
	root.add_child(test_mode)
	await process_frame
	_check(parented_test_client.get_parent() == test_mode, "test-mode client parented")
	test_mode.free()
	_check(not is_instance_valid(parented_test_client), "parented test client freed once")

	var pending_client := WebsocketClient.new()
	pending_client.connection_url = "ws://127.0.0.1:1/ws"
	root.add_child(pending_client)
	pending_client.open_connection()
	await process_frame
	var cancelled_wait := pending_client._connection_wait
	pending_client.close()
	_check(not pending_client._is_already_connecting, "close cancels pending connection wait")
	pending_client.open_connection()
	_check(pending_client._connection_wait != null and pending_client._connection_wait != cancelled_wait, "reopen starts a fresh connection wait")
	pending_client.close()
	pending_client.free()
	await create_timer(1.2).timeout

	var listener := TCPServer.new()
	if listener.listen(0, "127.0.0.1") == OK:
		var stale_client := WebsocketClient.new()
		stale_client.connection_url = "ws://127.0.0.1:%d/ws" % listener.get_local_port()
		root.add_child(stale_client)
		stale_client.open_connection()
		await process_frame
		stale_client.close()
		stale_client._tries = 1
		stale_client.open_connection()
		await create_timer(1.2).timeout
		_check(not listener.is_connection_available() and stale_client._is_already_connecting, "cancelled timer cannot dial during a later wait")
		stale_client.free()
		listener.stop()
	else:
		_check(false, "stale-timer fixture binds loopback")

	var unclosed_client := WebsocketClient.new()
	unclosed_client.connection_url = "ws://127.0.0.1:1/ws"
	root.add_child(unclosed_client)
	unclosed_client.open_connection()
	await process_frame
	unclosed_client.free()
	await create_timer(1.2).timeout
	_check(not is_instance_valid(unclosed_client), "tree exit cancels pending wait without explicit close")

	print("TWITCHER LIFECYCLE %s: %d/%d checks" % ["PASS" if _failures == 0 else "FAIL", _checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures += 1
		print("FAIL: ", description)
