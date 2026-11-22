extends RefCounted

## OAuth - what every upload site's sign-in and requests share: the one-shot listener on 127.0.0.1 that catches the browser's
## redirect ([method await_code]), the page it answers with, and one HTTP exchange ([method send]).
##
## A site's own script (youtube.gd, tiktok.gd) builds its consent page and trades the code; this only waits for it. Loaded by
## path (no class_name), as those are.

## How long the browser is waited for, in seconds.
const SIGN_IN_TIMEOUT := 600.0


## The browser's answer at [param tcp] for the sign-in sent with [param state]: `{code}`, or `{error}`. Anything else that
## knocks (a favicon, a stale tab) is turned away and the wait goes on while [param still] returns "" - its text, once not, is
## the error (a newer sign-in, a cancel). [param site] names who the person signed in to on the page that closes it;
## [param denied] is the error when the person declined (`access_denied`). [param path] is the redirect's path, "" for any.
static func await_code(tcp: TCPServer, state: String, still: Callable, site: String, denied: String,
		path := "") -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var conns: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	while true:
		var stop := str(still.call())
		if not stop.is_empty():
			drop(conns)
			return {"error": stop}
		if Time.get_ticks_msec() - t0 > int(SIGN_IN_TIMEOUT * 1000.0):
			drop(conns)
			return {"error": "the sign-in timed out - nothing came back from the browser in %d minutes"
				% int(SIGN_IN_TIMEOUT / 60.0)}
		while tcp.is_connection_available():
			var peer := tcp.take_connection()
			if peer != null:
				conns.append({"peer": peer, "buf": PackedByteArray()})
		for c in conns.duplicate():
			var conn: Dictionary = c
			var peer: StreamPeerTCP = conn["peer"]
			peer.poll()
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				conns.erase(conn)
				continue
			var n := peer.get_available_bytes()
			if n > 0:
				var part: Array = peer.get_partial_data(n)
				if int(part[0]) == OK:
					var buf: PackedByteArray = conn["buf"]
					buf.append_array(part[1] as PackedByteArray)
					conn["buf"] = buf
			var req := AgentTools.parse_request(conn["buf"])
			if req.is_empty():
				continue
			conns.erase(conn)
			var at := str(req.get("path", ""))
			var q := query_of(at)
			if req.has("error") or str(req.get("method", "")) != "GET" or not q.has("state") \
					or (not path.is_empty() and at.get_slice("?", 0).trim_suffix("/") != path.trim_suffix("/")):
				answer(peer, 404, "Nothing here.")
				continue
			if str(q["state"]) != state:
				answer(peer, 400, "This is not the sign-in Ghost Notes is waiting for. Start it again from Ghost Notes.")
				continue
			if q.has("error"):
				answer(peer, 200, "The sign-in was not completed. You can close this tab.")
				drop(conns)
				if q["error"] == "access_denied":
					return {"error": denied}
				var said := str(q.get("error_description", ""))
				return {"error": "%s said: %s%s" % [site, q["error"], (" - " + said) if not said.is_empty() else ""]}
			if str(q.get("code", "")).is_empty():
				answer(peer, 400, "%s sent no code. Start the sign-in again from Ghost Notes." % site)
				continue
			answer(peer, 200, "Ghost Notes is signed in to %s. You can close this tab." % site)
			drop(conns)
			return {"code": str(q["code"]), "query": q}
		await tree.process_frame
	return {}


## The query of a request path (`/?a=1&b=two+words`), decoded.
static func query_of(path: String) -> Dictionary:
	var out := {}
	if not path.contains("?"):
		return out
	for pair in path.get_slice("?", 1).get_slice("#", 0).split("&", false):
		var s := String(pair)
		var k := s.get_slice("=", 0)
		out[k.replace("+", " ").uri_decode()] = s.substr(k.length() + 1).replace("+", " ").uri_decode() \
			if s.contains("=") else ""
	return out


## [param fields] as `application/x-www-form-urlencoded` - also a URL's query - in their order.
static func form(fields: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in fields:
		parts.append("%s=%s" % [str(k).uri_encode(), str(fields[k]).uri_encode()])
	return "&".join(parts)


static func answer(peer: StreamPeerTCP, status: int, text: String) -> void:
	var page := ("<!doctype html><html><head><meta charset=\"utf-8\"><title>Ghost Notes</title></head>"
		+ "<body style=\"margin:0;height:100vh;display:grid;place-items:center;background:#111;"
		+ "color:#ddd;font:16px system-ui,sans-serif\"><p>%s</p></body></html>") % text.xml_escape()
	peer.put_data(AgentTools.http_response(status, page,
		{"Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store"}))
	peer.disconnect_from_host()


static func drop(conns: Array) -> void:
	for c in conns:
		((c as Dictionary)["peer"] as StreamPeerTCP).disconnect_from_host()
	conns.clear()


## One HTTP exchange, its request a child of [param owner] (in the tree): `{code, headers, body, json}` (`json` when the body
## parses), or `{error}` when no answer came at all.
static func send(owner: Node, url: String, headers: PackedStringArray, method: HTTPClient.Method, body: PackedByteArray,
		timeout: float) -> Dictionary:
	var h := HTTPRequest.new()
	h.use_threads = true
	h.timeout = timeout
	var proxy := Provision.https_proxy()
	if not proxy.is_empty():
		h.set_https_proxy(String(proxy[0]), int(proxy[1]))
	owner.add_child(h)
	var all := PackedStringArray(["User-Agent: Ghost Notes (Godot %s)" % str(Engine.get_version_info().get("string", "4"))])
	all.append_array(headers)
	var err := h.request_raw(url, all, method, body)
	if err != OK:
		h.queue_free()
		return {"error": "the request could not start (%s)" % error_string(err)}
	var r: Array = await h.request_completed
	h.queue_free()
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"error": result_text(int(r[0]))}
	var out := {"code": int(r[1]), "headers": r[2] as PackedStringArray, "body": r[3] as PackedByteArray}
	var j := JSON.new()
	if j.parse((r[3] as PackedByteArray).get_string_from_utf8()) == OK:
		out["json"] = j.data
	return out


static func result_text(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE:
			return "no connection"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "a secure connection could not be made"
		HTTPRequest.RESULT_TIMEOUT:
			return "it timed out"
		HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_NO_RESPONSE:
			return "the connection dropped"
	return "error %d" % result
