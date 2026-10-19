extends SceneTree

var _checks: int
var _failures: int


class StubHTTPClient extends BufferedHTTPClient:
	var response: ResponseData

	func request(_path: String, _method: int, _headers: Dictionary, _body: String) -> RequestData:
		return RequestData.new()

	func wait_for_request(_request_data: RequestData) -> ResponseData:
		return response


class TokenHandler extends TwitchTokenHandler:
	var refreshes: int

	func refresh_tokens() -> void:
		refreshes += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var client := StubHTTPClient.new()
	var handler := TokenHandler.new()
	handler._http_client = client
	var stored := OAuthToken.new()
	stored.resource_name = "offline-validation-fixture"
	stored._cache_path = "user://offline-validation-fixture.conf"
	handler.token = stored
	var unauthenticated: Array[bool] = []
	handler.unauthenticated.connect(func() -> void: unauthenticated.append(true))
	for status: int in [0, 400, 429, 500, 503, 200, 401]:
		stored.update_values("fixture-access", "fixture-refresh", 3600, [], OAuthToken.USER_ACCESS_TOKEN)
		var before := FileAccess.get_file_as_bytes(stored._cache_path)
		unauthenticated.clear()
		client.response = BufferedHTTPClient.ResponseData.new()
		client.response.response_code = status
		client.response.error = status == 0
		client.response.result = HTTPRequest.RESULT_CANT_RESOLVE if status == 0 else HTTPRequest.RESULT_SUCCESS
		client.response.response_data = ('{"expires_in":3600}' if status == 200 else 'unavailable').to_utf8_buffer()
		var response := await handler.validate_token()
		_check(response == client.response, "HTTP %d returns the original response" % status)
		if status == 401:
			_check(stored.get_access_token().is_empty() and stored.get_refresh_token().is_empty(), "401 removes credentials")
			_check(unauthenticated.size() == 1, "401 emits unauthenticated exactly once")
			stored.load_tokens()
			_check(not stored.has_refresh_token(), "401 removes persisted refresh token")
		else:
			_check(stored.get_access_token() == "fixture-access" and stored.get_refresh_token() == "fixture-refresh", "HTTP %d preserves credentials" % status)
			_check(unauthenticated.is_empty(), "HTTP %d does not signal deauthorization" % status)
			_check(FileAccess.get_file_as_bytes(stored._cache_path) == before, "HTTP %d preserves stored bytes" % status)
			stored.load_tokens()
			_check(stored.get_refresh_token() == "fixture-refresh", "HTTP %d refresh token survives reload" % status)
	stored.update_values("fixture-access", "fixture-refresh", 3600, [], OAuthToken.USER_ACCESS_TOKEN)
	client.response.response_code = 200
	client.response.response_data = '{"expires_in":0}'.to_utf8_buffer()
	await handler.validate_token()
	_check(handler.refreshes == 1, "200 with expired access token still refreshes")
	handler.free()
	client.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stored._cache_path))
	print("TWITCHER TOKEN VALIDATION %s: %d/%d checks" % ["PASS" if _failures == 0 else "FAIL", _checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures += 1
		print("FAIL: ", description)
