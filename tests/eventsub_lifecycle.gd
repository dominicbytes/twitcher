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

	var listener := TCPServer.new()
	_check(listener.listen(0, "127.0.0.1") == OK, "reattach fixture binds loopback")
	var peers: Array[WebSocketPeer] = []
	var local_url := "ws://127.0.0.1:%d/ws" % listener.get_local_port()
	var reattached: TwitchEventsub = eventsub_script.new()
	var reattached_client: WebsocketClient = reattached.get_client()
	var reattached_test_client: WebsocketClient = reattached.get_test_client()
	reattached_client.connection_url = local_url
	root.add_child(reattached)
	reattached.open_connection()
	_check(await _wait_connected(reattached_client, listener, peers), "EventSub connects before detach")
	_welcome(reattached, "before-detach")
	root.remove_child(reattached)
	_check(not reattached_client._is_already_connecting and not reattached_client.auto_reconnect, "detach cancels waits and disables polling reconnect")
	root.add_child(reattached)
	await process_frame
	_check(await _wait_connected(reattached_client, listener, peers) and peers.size() == 2, "active EventSub resumes with a new connection after reattach")
	_welcome(reattached, "after-reattach")
	_check(reattached._should_connect, "EventSub restores connection intent")
	reattached.close_connection()
	root.remove_child(reattached)
	root.add_child(reattached)
	await create_timer(1.2).timeout
	_check(not reattached._should_connect and not reattached_client.auto_reconnect and not listener.is_connection_available(), "explicitly stopped EventSub stays stopped after reattach")
	_check(is_instance_valid(reattached_client) and reattached_client.get_parent() == reattached, "active client survives reattach")
	_check(is_instance_valid(reattached_test_client), "test client survives reattach")
	reattached.free()
	_check(not is_instance_valid(reattached_client), "parented active client freed")
	_check(not is_instance_valid(reattached_test_client), "unparented test client freed")

	var active := WebsocketClient.new()
	active.connection_url = local_url
	root.add_child(active)
	active.open_connection()
	_check(await _wait_connected(active, listener, peers), "standalone IRC transport connects")
	for cycle: int in 3:
		var connections := peers.size()
		root.remove_child(active)
		root.add_child(active)
		_check(await _wait_connected(active, listener, peers) and peers.size() == connections + 1, "standalone transport reconnects after reattach %d" % cycle)
	root.remove_child(active)
	active.close()
	root.add_child(active)
	await create_timer(1.2).timeout
	_check(not active.auto_reconnect and not listener.is_connection_available(), "off-tree explicit close cancels standalone resume intent")
	active.free()
	for peer: WebSocketPeer in peers:
		peer.close(-1)
	listener.stop()

	var test_mode: TwitchEventsub = eventsub_script.new()
	test_mode.use_test_server = true
	var parented_test_client: WebsocketClient = test_mode.get_test_client()
	root.add_child(test_mode)
	await process_frame
	_check(parented_test_client.get_parent() == test_mode, "test-mode client parented")
	test_mode.free()
	_check(not is_instance_valid(parented_test_client), "parented test client freed once")

	var unsetup := TwitchEventsub.new()
	root.add_child(unsetup)
	# Hold action execution so unsubscribe requests can be inspected without HTTP.
	unsetup._executing_action_stack = true
	var subscriptions: Array[TwitchEventsubConfig] = []
	for index: int in 4:
		var config := TwitchEventsubConfig.new()
		config.type = TwitchEventsubDefinition.Type.CHANNEL_FOLLOW
		subscriptions.append(config)
		unsetup._subscriptions.append(config)
	unsetup.do_unsetup()
	_check(unsetup.get_subscriptions().is_empty(), "unsetup removes every subscription")
	_check(unsetup._action_stack.size() == subscriptions.size(), "unsetup queues every unsubscribe")
	var all_queued := true
	for subscription: TwitchEventsubConfig in subscriptions:
		var occurrences := 0
		for action: TwitchEventsub.SubscriptionAction in unsetup._action_stack:
			if not action.subscribe and action.subscription == subscription: occurrences += 1
		all_queued = all_queued and occurrences == 1
	_check(all_queued, "unsetup queues each original subscription exactly once")
	unsetup.free()

	var pending_client := WebsocketClient.new()
	pending_client.connection_url = "ws://127.0.0.1:1/ws"
	root.add_child(pending_client)
	pending_client.open_connection()
	await process_frame
	var detached_wait := pending_client._connection_wait
	root.remove_child(pending_client)
	_check(not pending_client._is_already_connecting and pending_client._connection_wait == null, "detach cancels a pending backoff")
	root.add_child(pending_client)
	_check(pending_client._is_already_connecting and pending_client._connection_wait != detached_wait, "reattach starts a fresh backoff")
	var cancelled_wait := pending_client._connection_wait
	pending_client.close()
	_check(not pending_client._is_already_connecting, "close cancels pending connection wait")
	pending_client.open_connection()
	_check(pending_client._connection_wait != null and pending_client._connection_wait != cancelled_wait, "reopen starts a fresh connection wait")
	pending_client.abort()
	_check(not pending_client._is_already_connecting and not pending_client.auto_reconnect, "abort cancels pending wait and reconnect intent")
	pending_client.open_connection()
	_check(pending_client._connection_wait != null, "reopen after abort starts a fresh wait")
	pending_client.close()
	pending_client.free()
	await create_timer(1.2).timeout

	listener = TCPServer.new()
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

	# Exercise real SceneTree shutdown with live pending waits, without explicit close.
	var shutdown_eventsub := TwitchEventsub.new()
	shutdown_eventsub.get_client().connection_url = "ws://127.0.0.1:1/ws"
	root.add_child(shutdown_eventsub)
	shutdown_eventsub.open_connection()
	var shutdown_transport := WebsocketClient.new()
	shutdown_transport.connection_url = "ws://127.0.0.1:1/ws"
	root.add_child(shutdown_transport)
	shutdown_transport.open_connection()

	print("TWITCHER LIFECYCLE %s: %d/%d checks" % ["PASS" if _failures == 0 else "FAIL", _checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)


func _welcome(eventsub: TwitchEventsub, id: String) -> void:
	# Finish the session wait started by connection_established, as Twitch would.
	eventsub._data_received(JSON.stringify({"metadata": {"message_id": id, "message_type": "session_welcome", "message_timestamp": Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system())) + "Z"}, "payload": {"session": {"id": id, "status": "connected", "keepalive_timeout_seconds": 10, "reconnect_url": null, "connected_at": "now"}}}).to_utf8_buffer())


func _wait_connected(client: WebsocketClient, server: TCPServer, peers: Array[WebSocketPeer]) -> bool:
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		if server.is_connection_available():
			var peer := WebSocketPeer.new()
			peer.accept_stream(server.take_connection())
			peers.append(peer)
		for peer: WebSocketPeer in peers:
			peer.poll()
		if client.is_open and client.connection_state == WebSocketPeer.STATE_OPEN and not peers.is_empty() and peers.back().get_ready_state() == WebSocketPeer.STATE_OPEN:
			return true
		await process_frame
	return false


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures += 1
		print("FAIL: ", description)
