extends SceneTree

var _checks: int
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var eventsub := TwitchEventsub.new()
	root.add_child(eventsub)
	var now := Time.get_ticks_msec()
	eventsub.session = TwitchEventsub.Session.new({"id": "fixture", "status": "connected", "keepalive_timeout_seconds": 10, "reconnect_url": null, "connected_at": "now"})
	eventsub.last_keepalive = now
	_check(not eventsub._keepalive_timed_out(now + 10000), "welcome interval does not time out early")
	_check(eventsub._keepalive_timed_out(now + 10001), "silent interval expires after welcome timeout")
	var timestamp := Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system())) + "Z"
	eventsub._data_received(JSON.stringify({"metadata": {"message_id": "keepalive-1", "message_type": "session_keepalive", "message_timestamp": timestamp}, "payload": {}}).to_utf8_buffer())
	_check(not eventsub._keepalive_timed_out(Time.get_ticks_msec() + 9000), "valid keepalive resets silence timer")
	eventsub.last_keepalive = 1
	eventsub._data_received(JSON.stringify({"metadata": {"message_id": "keepalive-1", "message_type": "session_keepalive", "message_timestamp": timestamp}, "payload": {}}).to_utf8_buffer())
	_check(eventsub.last_keepalive > 1, "duplicate valid keepalive still proves socket liveness")
	_check(eventsub._keepalive_timed_out(Time.get_ticks_msec() + 11000), "silence after keepalive expires")

	var baseline: Dictionary = {}
	var baseline_start := Time.get_ticks_usec()
	for index: int in 10000:
		baseline["id-%d" % index] = index
		for key: Variant in baseline.keys():
			if int(baseline[key]) < index - 5000:
				baseline.erase(key)
	var baseline_usec := Time.get_ticks_usec() - baseline_start
	var optimized_start := Time.get_ticks_usec()
	for index: int in 10000:
		eventsub._remember_message("id-%d" % index, index)
	var optimized_usec := Time.get_ticks_usec() - optimized_start
	_check(eventsub.eventsub_messages.size() == 5000, "message ID retention has hard 5000-entry bound")
	_check(eventsub._message_order.size() <= 6024, "incremental expiry queue remains bounded")
	_check(not eventsub._message_got_processed("id-0") and eventsub._message_got_processed("id-9999"), "oldest IDs evict before newest")
	print("UP05_BENCHMARK old_scan_usec=%d incremental_usec=%d workload=10000 unique IDs" % [baseline_usec, optimized_usec])
	await _test_silent_socket(eventsub)

	var reconnect := TwitchReconnectMessage.new({"metadata": {"message_id": "reconnect-1", "message_type": "session_reconnect", "message_timestamp": timestamp}, "payload": {"session": {"id": "fixture", "status": "reconnecting", "keepalive_timeout_seconds": 10, "reconnect_url": "ws://127.0.0.1:1/ws", "connected_at": "now"}}})
	eventsub._should_connect = true
	eventsub._handle_reconnect(reconnect)
	_check(eventsub._swap_over_client != null and eventsub._swap_over_client.connection_closed.is_connected(eventsub._on_connection_closed.bind(eventsub._swap_over_client)), "replacement socket has close callback")
	eventsub.session = TwitchEventsub.Session.new({"id": "old-live", "status": "connected", "keepalive_timeout_seconds": 10, "reconnect_url": null, "connected_at": "now"})
	var failed_pending := eventsub._swap_over_client
	failed_pending.connection_closed.emit()
	_check(eventsub.session != null and eventsub.session.id == "old-live", "failed pending socket preserves live old session")
	_check(eventsub._swap_over_client == null and not eventsub._swap_over_process, "failed pending socket clears handover for retry")
	eventsub._data_received(JSON.stringify({"metadata": {"message_id": "late-failed-welcome", "message_type": "session_welcome", "message_timestamp": timestamp}, "payload": {"session": {"id": "failed", "status": "connected", "keepalive_timeout_seconds": 10, "reconnect_url": null, "connected_at": "now"}}}).to_utf8_buffer(), failed_pending)
	_check(eventsub.session.id == "old-live", "late failed-socket welcome cannot replace old session")
	await process_frame
	_check(not is_instance_valid(failed_pending), "failed pending socket is freed")
	eventsub._handle_reconnect(reconnect)
	_check(eventsub._swap_over_client != null, "handover can retry after pending socket failure")
	var pending_after_retry := eventsub._swap_over_client
	eventsub._client.connection_closed.emit()
	_check(eventsub.session == null and eventsub._swap_over_client == null and not eventsub._swap_over_process, "active socket close cancels pending handover for ordinary resubscription")
	await process_frame
	_check(not is_instance_valid(pending_after_retry), "active close frees pending replacement")
	eventsub.close_connection()
	_check(eventsub._swap_over_client == null and eventsub.session == null and not eventsub._should_connect, "stop cancels handover and clears session")
	await create_timer(1.2).timeout
	_check(eventsub._swap_over_client == null and not eventsub._client.auto_reconnect, "late reconnect timer cannot reopen after stop")
	eventsub._should_connect = true
	var old_client := eventsub.get_client()
	eventsub._handle_reconnect(reconnect)
	var replacement := eventsub._swap_over_client
	eventsub._data_received(JSON.stringify({"metadata": {"message_id": "welcome-replacement", "message_type": "session_welcome", "message_timestamp": timestamp}, "payload": {"session": {"id": "replacement", "status": "connected", "keepalive_timeout_seconds": 10, "reconnect_url": null, "connected_at": "now"}}}).to_utf8_buffer(), replacement)
	await process_frame
	_check(eventsub.get_client() == replacement and eventsub._swap_over_client == null, "successful handover promotes replacement socket")
	_check(not is_instance_valid(old_client) and replacement.connection_closed.is_connected(eventsub._on_connection_closed.bind(replacement)), "handover frees old socket and retains close callback")
	_check(replacement.connection_url == eventsub.eventsub_live_server_url, "later reconnect uses standard EventSub URL, not temporary handover URL")
	replacement.connection_closed.emit()
	_check(eventsub.session == null, "replacement-socket disconnect clears session")
	eventsub.close_connection()
	eventsub.queue_free()
	await process_frame
	_finish()


func _test_silent_socket(eventsub: TwitchEventsub) -> void:
	var server := TCPServer.new()
	if server.listen(0, "127.0.0.1") != OK:
		_check(false, "silent WebSocket fixture binds loopback")
		return
	eventsub._client.connection_url = "ws://127.0.0.1:%d/ws" % server.get_local_port()
	eventsub.open_connection()
	var accepted: WebSocketPeer = null
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline and not eventsub._client.is_open:
		if server.is_connection_available():
			accepted = WebSocketPeer.new()
			accepted.accept_stream(server.take_connection())
		if accepted != null:
			accepted.poll()
		await process_frame
	_check(eventsub._client.is_open, "silent loopback WebSocket reaches open state")
	if eventsub._client.is_open:
		eventsub.session = TwitchEventsub.Session.new({"id": "silent", "status": "connected", "keepalive_timeout_seconds": 10, "reconnect_url": null, "connected_at": "now"})
		var timestamp := Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system())) + "Z"
		var reconnect := TwitchReconnectMessage.new({"metadata": {"message_id": "silent-reconnect", "message_type": "session_reconnect", "message_timestamp": timestamp}, "payload": {"session": {"id": "silent", "status": "reconnecting", "keepalive_timeout_seconds": 10, "reconnect_url": "ws://127.0.0.1:1/reconnect", "connected_at": "now"}}})
		eventsub._handle_reconnect(reconnect)
		eventsub.last_keepalive = Time.get_ticks_msec()
		eventsub._check_keepalive(eventsub.last_keepalive + 11000)
		_check(eventsub.session == null and eventsub._client.auto_reconnect and eventsub._swap_over_client == null and not eventsub._swap_over_process, "silent open WebSocket cancels handover and triggers ordinary resubscription path")
	eventsub.close_connection()
	if accepted != null:
		accepted.close()
	server.stop()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + label)
	else:
		_failures.append(label)


func _finish() -> void:
	for failure: String in _failures:
		push_error("UP05 FAIL: " + failure)
	print("TWITCHER UP05 %s: %d/%d checks" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	quit(0 if _failures.is_empty() else 1)
