extends SceneTree

## tiktok_check - the TikTok target end to end, against a stand-in for TikTok on 127.0.0.1 (no network or account), and the
## Upload card's targets. The stand-in speaks the protocol as TikTok documents it: Login Kit for Desktop (PKCE with a HEX
## SHA-256 challenge), the token endpoint with rotating refresh tokens, creator info, Direct Post and inbox init, chunked PUTs
## with `Content-Range` (206, then 201), and the status fetch.
##
##   godot --headless --path . --script res://tests/export/tiktok_check.gd
##
## - pieces: the challenge is the hex SHA-256 of the verifier (control: base64url is not); the consent URL asks for the scopes
##   comma-separated at a loopback redirect on /callback/; chunks: one under two chunks, else whole chunks with the last taking
##   the rest; hashtags run words together, each once; the caption is title, description, hashtags, cut to 2200 UTF-16 units,
##   the description first; a post starts with comments, Duets and Stitches off and labeled AI-generated; refusals name a
##   privacy not picked or not offered, branded content as Only me, a video too long; TikTok's error codes read as words.
## - the client: kept owner read/write only; one missing its secret is refused and leaves the kept one alone.
## - sign-in: the "browser" (TikTok.open_url) knocks on the wrong path first (turned away), then answers; the code is traded
##   once for the right client, redirect and verifier; the account is named. A spent access token renews, and the old refresh
##   token stops working (control: refused, the account is read as signed out).
## - post: the file arrives whole through a dropped chunk, with the caption and settings as the card said them, a privacy the
##   account offers and its turned-off Duets turned off; the post's link is made and recorded, nothing left pending. Control: a
##   privacy the account does not offer is refused before a byte is sent, and the upload still waits.
## - draft: an inbox upload carries no post settings and ends in the inbox; through the exporter, a TikTok-only export goes up
##   once saved and its line says so.
## - the card: a new card goes to YouTube alone, its TikTok rows hidden; targets and TikTok's rows round-trip through the block;
##   TikTok picked and not ready is refused, saying why (no client, not signed in, a post's privacy unpicked); ready, the upload
##   carries TikTok's part (control: YouTube alone carries none); no target at all is refused.

const TikTok := preload("res://src/export/tiktok.gd")
const ROOT := "user://tiktok_check"
const CHUNK := 64 * 1024

var _fails := 0
var _fake: FakeTikTok
var _tt: Node
var _turned_away := 0
var _page := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("tiktok_check: TIMED OUT")
		quit(1))
	var keep := {"root": TikTok.root, "auth": TikTok.auth_url, "api": TikTok.api, "chunk": TikTok.chunk,
		"backoff": TikTok.backoff_unit, "every": TikTok.status_every, "open": TikTok.open_url}
	TikTok.root = ROOT
	_wipe(ROOT)
	_wipe(ROOT + "_files")
	_fake = FakeTikTok.new()
	root.add_child(_fake)
	var port := _fake.start()
	TikTok.api = "http://127.0.0.1:%d/v2" % port
	TikTok.auth_url = "http://127.0.0.1:%d/auth" % port
	TikTok.chunk = CHUNK
	TikTok.backoff_unit = 0.01
	TikTok.status_every = 0.05
	TikTok.open_url = _browser
	_tt = TikTok.new()
	root.add_child(_tt)
	_pieces()
	_client()
	if await _sign_in():
		await _refresh()
		await _post()
		await _draft()
		await _exporter()
	_card()
	TikTok.root = keep["root"]
	TikTok.auth_url = keep["auth"]
	TikTok.api = keep["api"]
	TikTok.chunk = keep["chunk"]
	TikTok.backoff_unit = keep["backoff"]
	TikTok.status_every = keep["every"]
	TikTok.open_url = keep["open"]
	_wipe(ROOT)
	_wipe(ROOT + "_files")
	print("tiktok_check: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _wipe(path: String) -> void:
	var dir := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		_wipe(path.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _video(name: String, size: int) -> String:
	var path := ProjectSettings.globalize_path(ROOT + "_files").path_join(name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(Crypto.new().generate_random_bytes(size))
	f.close()
	return path


func _until(cond: Callable, ms := 8000) -> bool:
	var t0 := Time.get_ticks_msec()
	while not bool(cond.call()) and Time.get_ticks_msec() - t0 < ms:
		await process_frame
	return bool(cond.call())


# --- the browser ---------------------------------------------------------------------------------

func _browser(url: String) -> void:
	var q := TikTok.OAuth.query_of(url)
	_fake.challenge = str(q.get("code_challenge", ""))
	_fake.redirect = str(q.get("redirect_uri", ""))
	_fake.asked = str(q.get("scope", ""))
	var back := _fake.redirect
	var at := back.get_slice("://", 1).get_slice("/", 0)
	await process_frame
	var r: Dictionary = await _fetch("http://%s/favicon.ico?state=%s&code=x" % [at, str(q.get("state", ""))])
	_turned_away = int(r["status"])
	r = await _fetch(back + "?code=%s&scopes=%s&state=%s" % [_fake.code, _fake.asked.uri_encode(), str(q.get("state", ""))])
	_page = int(r["status"])


func _fetch(url: String) -> Dictionary:
	var hostport := url.get_slice("://", 1).get_slice("/", 0)
	var path := url.get_slice("://", 1).substr(hostport.length())
	var c := StreamPeerTCP.new()
	c.connect_to_host("127.0.0.1", int(hostport.get_slice(":", 1)))
	var t0 := Time.get_ticks_msec()
	while c.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() - t0 < 3000:
		c.poll()
		await process_frame
	c.put_data(("GET %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n" % [path, hostport]).to_utf8_buffer())
	var got := PackedByteArray()
	while Time.get_ticks_msec() - t0 < 5000:
		c.poll()
		if c.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		var n := c.get_available_bytes()
		if n > 0:
			got.append_array(c.get_partial_data(n)[1] as PackedByteArray)
		await process_frame
	var text := got.get_string_from_utf8()
	return {"status": int(text.get_slice(" ", 1)) if text.begins_with("HTTP/") else 0}


# --- the checks ----------------------------------------------------------------------------------

func _pieces() -> void:
	var v := "the-verifier-of-forty-three-or-more-characters"
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(v.to_utf8_buffer())
	var digest := ctx.finish()
	_ok(TikTok.challenge(v) == digest.hex_encode() and TikTok.challenge(v).length() == 64
		and TikTok.challenge(v) != Marshalls.raw_to_base64(digest).replace("+", "-").replace("/", "_").replace("=", ""),
		"the challenge is the hex SHA-256 of the verifier, as Login Kit for Desktop asks (control: not base64url)")
	var vf := TikTok.verifier()
	_ok(vf.length() >= 43 and vf.length() <= 128 and vf.is_valid_hex_number(), "a verifier is 43 to 128 unreserved characters")
	var q := TikTok.OAuth.query_of(TikTok.consent_url("ck", "http://127.0.0.1:5/callback/", "abc", "st", ["user.info.basic", "video.upload"]))
	_ok(q.get("client_key") == "ck" and q.get("scope") == "user.info.basic,video.upload" and q.get("response_type") == "code"
		and q.get("redirect_uri") == "http://127.0.0.1:5/callback/" and q.get("code_challenge_method") == "S256"
		and q.get("state") == "st", "the consent URL: the client key, scopes comma-separated, the loopback redirect, PKCE")
	_ok(TikTok.chunks_of(1000) == {"chunk_size": 1000, "count": 1} and TikTok.chunks_of(CHUNK * 2 - 1) == {"chunk_size": CHUNK * 2 - 1, "count": 1}
		and TikTok.chunks_of(CHUNK * 3 + 7) == {"chunk_size": CHUNK, "count": 3},
		"chunks: one under two chunks, else whole chunks with the last taking the rest")
	_ok(TikTok.hashtags(["tarot", "Tarot", "pick a card", "late-night radio", "", "#already"]) == PackedStringArray(
		["#tarot", "#pickACard", "#lateNightRadio", "#already"]), "hashtags run words together, each once whatever its case")
	var cap := TikTok.caption({"title": "Night Shift: The Tower", "description": "A reading.", "tags": ["tarot", "night shift"]})
	_ok(cap == "Night Shift: The Tower\n\nA reading.\n\n#tarot #nightShift", "the caption: title, description, hashtags (%s)" % cap)
	var long := TikTok.caption({"title": "T", "description": "word ".repeat(1000), "tags": ["kept"]})
	_ok(TikTok._units(long) <= TikTok.CAPTION_MAX and long.ends_with("#kept") and long.contains("…"),
		"a long description is cut first, the hashtags kept, within 2200 units (%d)" % TikTok._units(long))
	var wide := TikTok.caption({"title": "T", "description": "😀".repeat(1500)})
	_ok(TikTok._units(wide) <= TikTok.CAPTION_MAX and wide.length() < TikTok.CAPTION_MAX,
		"counted as TikTok counts it, in UTF-16 units: an emoji is two (%d)" % TikTok._units(wide))
	var p := TikTok.post_of({"title": "A", "thumbnail_at": 1.25, "tiktok": {"mode": "post", "privacy": "SELF_ONLY"}}, 42.0)
	_ok(p["mode"] == "post" and p["privacy"] == "SELF_ONLY" and p["disable_comment"] and p["disable_duet"] and p["disable_stitch"]
		and p["is_aigc"] and not p["brand_content"] and not p["brand_organic"] and p["cover_ms"] == 1250 and p["length"] == 42.0,
		"a post starts with comments, Duets and Stitches off, labeled AI-generated, its cover at the title's moment (%s)" % str(p))
	_ok(TikTok.post_of({"tiktok": {"mode": "odd"}})["mode"] == "draft", "a mode TikTok does not know is a draft")
	var info := {"privacy_level_options": ["FOLLOWER_OF_CREATOR", "SELF_ONLY"], "max_video_post_duration_sec": 60}
	_ok(TikTok.refusal({"privacy": ""}, info).contains("pick who") and TikTok.refusal({"privacy": "PUBLIC_TO_EVERYONE"}, info).contains("Everyone")
		and TikTok.refusal({"privacy": "SELF_ONLY", "brand_content": true}, info).contains("branded")
		and TikTok.refusal({"privacy": "SELF_ONLY", "length": 61.0}, info).contains("at most")
		and TikTok.refusal({"privacy": "SELF_ONLY", "length": 59.0}, info).is_empty(),
		"refused: no privacy, one not offered, branded content as Only me, too long (control: a fit post passes)")
	var err := JSON.stringify({"data": {}, "error": {"code": "unaudited_client_can_only_post_to_private_accounts", "message": "x"}})
	_ok(TikTok.error_text(403, err.to_utf8_buffer()).contains("private account")
		and TikTok.error_text(400, '{"error":"invalid_grant","error_description":"gone"}'.to_utf8_buffer()) == "TikTok said: invalid_grant - gone",
		"TikTok's errors read as words")


func _client() -> void:
	_ok(not TikTok.has_client() and TikTok.set_client("ck", "").contains("both"), "a client missing its secret is refused")
	_ok(TikTok.set_client(" ck-1 ", " secret-1 ").is_empty() and TikTok.client() == {"client_key": "ck-1", "client_secret": "secret-1"},
		"a client is kept, its spaces trimmed")
	_ok(OS.get_name() == "Windows" or FileAccess.get_unix_permissions(TikTok._path("client.json")) == TikTok.OWNER_FILE,
		"the client is owner read/write only")
	_ok(not TikTok.set_client("other", "").is_empty() and TikTok.client()["client_key"] == "ck-1",
		"control: a bad client leaves the kept one alone")


func _sign_in() -> bool:
	var got: Dictionary = await _tt.sign_in(TikTok.scopes_for("post") + [TikTok.DRAFT_SCOPE])
	_ok(not got.has("error"), "the sign-in completes through the browser (%s)" % got.get("error", ""))
	_ok(_turned_away == 404, "a knock on another path is turned away while the wait goes on (%d)" % _turned_away)
	_ok(await _until(func() -> bool: return _page != 0) and _page == 200, "the browser is told the sign-in worked")
	_ok(_fake.traded == 1 and str(_fake.redirect).ends_with("/callback/"),
		"the code was traded once, for the right client, redirect and verifier")
	_ok(TikTok.signed_in() and TikTok.name_of(TikTok.account()) == "Nightshift" and TikTok.granted(TikTok.POST_SCOPE)
		and TikTok.granted(TikTok.DRAFT_SCOPE), "the account is kept, named, with what it was granted")
	return TikTok.signed_in()


func _refresh() -> void:
	var a := TikTok.account()
	var old := str(a["refresh_token"])
	a["expires_at"] = 0.0
	TikTok._write(TikTok._path("account.json"), JSON.stringify(a), true)
	var tok: Dictionary = await _tt.access_token()
	_ok(not tok.has("error") and str(TikTok.account()["refresh_token"]) != old and not _fake.refresh.has(old),
		"a spent access token renews, and the new refresh token replaces the old")


func _post() -> void:
	var file := _video("post.mp4", CHUNK * 3 + 777)
	var meta := {"title": "Night Shift", "description": "One night.", "tags": ["radio"], "thumbnail_at": 2.0,
		"tiktok": {"mode": "post", "privacy": "PUBLIC_TO_EVERYONE", "comments": true, "duet": true}}
	var rec := ProjectSettings.globalize_path(ROOT + "_files/episode/tiktok.json")
	TikTok.queue(file, TikTok.post_of(meta, 30.0), rec)
	var res: Dictionary = await _tt.resume()
	_ok(res.has("error") and res["error"].contains("Everyone") and _fake.inits == 0 and not TikTok.pending().is_empty(),
		"control: a privacy the account does not offer is refused before a byte is sent, and the upload waits (%s)" % res.get("error", ""))
	meta["tiktok"]["privacy"] = "FOLLOWER_OF_CREATOR"
	TikTok.queue(file, TikTok.post_of(meta, 30.0), rec)
	_fake.faults = {1: true}
	res = await _tt.resume()
	_ok(not res.has("error") and res.get("status") == "PUBLISH_COMPLETE", "posted through a dropped chunk (%s)" % res.get("error", ""))
	var u: Dictionary = _fake.uploads.get(str(res.get("publish_id", "")), {})
	_ok(u.get("data", PackedByteArray()) == FileAccess.get_file_as_bytes(file) and int(u.get("puts", 0)) == 4,
		"the file arrived whole, in three chunks and one sent again")
	var pi: Dictionary = u.get("post_info", {})
	_ok(pi.get("title") == "Night Shift\n\nOne night.\n\n#radio" and pi.get("privacy_level") == "FOLLOWER_OF_CREATOR"
		and pi.get("disable_comment") == false and pi.get("disable_duet") == true and pi.get("disable_stitch") == true
		and pi.get("is_aigc") == true and int(pi.get("video_cover_timestamp_ms", 0)) == 2000,
		"the post says what the card said; the account's turned-off Duets stay off (%s)" % str(pi))
	_ok(str(res.get("url", "")) == "https://www.tiktok.com/@night/video/7300000000000000001"
		and YouTube_uploads(rec).size() == 1 and TikTok.pending().is_empty(), "its link is made and recorded, nothing left pending")


static func YouTube_uploads(path: String) -> Array:
	return load("res://src/export/youtube.gd").uploads_in(path)


func _draft() -> void:
	var file := _video("draft.mp4", 5000)
	TikTok.queue(file, TikTok.post_of({"title": "A draft", "tiktok": {"mode": "draft"}}), "")
	var res: Dictionary = await _tt.resume()
	var u: Dictionary = _fake.uploads.get(str(res.get("publish_id", "")), {})
	_ok(not res.has("error") and res.get("status") == "SEND_TO_USER_INBOX" and u.get("inbox") == true
		and not u.has("post_info") and u.get("data", PackedByteArray()).size() == 5000,
		"a draft goes to the inbox whole, with no post settings (%s)" % res.get("error", ""))


func _exporter() -> void:
	var ex = load("res://src/export/exporter.gd").new()
	ex._build_ui()
	ex.tiktok().free()
	ex._tk = _tt
	var file := _video("export.mp4", 9000)
	ex._out = file
	ex._song_dur = 12.0
	ex._upload_meta = {"title": "Exported", "targets": ["tiktok"], "tiktok": {"mode": "draft"}}
	ex._set_status("✓  Saved  " + file, Color.WHITE)
	ex._queue_upload()
	_ok(await _until(func() -> bool: return ex._state == "done") and ex._status.text.contains("inbox")
		and ex._status.text.begins_with("✓  Saved") and TikTok.pending().is_empty(),
		"through the exporter, a TikTok-only export goes up once saved and the line says so (%s)" % ex._status.text)
	ex._tk = null
	ex.free()


func _card() -> void:
	var YouTube = load("res://src/export/youtube.gd")
	var yt_root: String = YouTube.root
	YouTube.root = ROOT + "_youtube"
	var ex = load("res://src/export/exporter.gd").new()
	ex._build_ui()
	var card = load("res://src/export/youtube_card.gd").new()
	card.exporter = ex
	root.add_child(card)
	var cap: Dictionary = card.capture()
	_ok(cap["targets"] == ["youtube"] and cap["tiktok_mode"] == "draft" and cap["tiktok_privacy"] == "" and cap["tiktok_aigc"] == true
		and cap["channel"] == "" and not card._tt.visible and card._yt_box.visible,
		"a new card goes to YouTube alone, TikTok's rows hidden, a draft (%s)" % str(cap))
	var names = load("res://src/ui/script_writer.gd").new()
	names.setup("tiktok_check", PackedStringArray(), "")
	names.doc._sync = false
	names.doc._fields = {"title": "Night Shift", "episode": "One"}
	card.name_from(names)
	var block := cap.duplicate()
	block.merge({"upload": true, "targets": ["youtube", "tiktok"], "tiktok_mode": "post", "tiktok_privacy": "SELF_ONLY",
		"tiktok_comments": true, "tiktok_brand_own": true}, true)
	card.apply(block)
	_ok(card.capture() == block and card._tt.visible, "targets and TikTok's rows round-trip through the block (%s)" % str(card.capture()))
	TikTok.forget_client()
	_ok(str(card.meta({"tags": []}).get("refused", "")).contains("Client key"), "TikTok with no client is refused, saying so")
	TikTok.set_client("ck-1", "secret-1")
	_ok(str(card.meta({"tags": []}).get("refused", "")).contains("Sign in"), "...not signed in, refused, saying so")
	TikTok._write(TikTok._path("account.json"), JSON.stringify({"refresh_token": "r", "refresh_expires_at": TikTok._now() + 999,
		"access_token": "a", "expires_at": TikTok._now() + 999, "scope": "user.info.basic,video.publish"}), true)
	card.apply(block.merged({"tiktok_privacy": ""}, true))
	_ok(str(card.meta({"tags": []}).get("refused", "")).contains("Who sees it"), "...a post with no privacy picked, refused")
	card.apply(block)
	var m: Dictionary = card.meta({"tags": ["a"]})
	_ok(not m.has("refused") and m.get("targets") == ["youtube", "tiktok"] and (m.get("tiktok", {}) as Dictionary).get("privacy") == "SELF_ONLY"
		and (m.get("tiktok", {}) as Dictionary).get("comments") == true, "ready, the upload carries TikTok's part (%s)" % str(m))
	card.apply(block.merged({"targets": ["youtube"]}, true))
	_ok(not card.meta({"tags": []}).has("tiktok") and not card._tt.visible, "control: YouTube alone carries no TikTok part")
	card.apply(block.merged({"targets": []}, true))
	_ok(str(card.meta({"tags": []}).get("refused", "")).contains("Goes to"), "no target at all is refused")
	card.queue_free()
	ex.free()
	names.free()
	YouTube.root = yt_root
	_wipe(ROOT + "_youtube")


# --- the stand-in --------------------------------------------------------------------------------

class FakeTikTok extends Node:
	var challenge := ""
	var redirect := ""
	var asked := ""
	var code := "the-code"
	var traded := 0
	var inits := 0
	var faults := {}              # chunk number -> drop it
	var uploads := {}             # publish id -> {data, puts, post_info, inbox}
	var refresh := {}             # refresh tokens it honors -> scope
	var _live := {}               # access tokens it honors
	var _issued := 0
	var _chunks := 0
	var port := 0
	var _tcp := TCPServer.new()
	var _conns: Array = []

	func start() -> int:
		_tcp.listen(0, "127.0.0.1")
		port = _tcp.get_local_port()
		return port

	func _process(_dt: float) -> void:
		while _tcp.is_connection_available():
			_conns.append({"peer": _tcp.take_connection(), "buf": PackedByteArray()})
		for c in _conns.duplicate():
			var conn: Dictionary = c
			var peer: StreamPeerTCP = conn["peer"]
			peer.poll()
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				_conns.erase(conn)
				continue
			var n := peer.get_available_bytes()
			if n > 0:
				var buf: PackedByteArray = conn["buf"]
				buf.append_array(peer.get_partial_data(n)[1] as PackedByteArray)
				conn["buf"] = buf
			var req := AgentTools.parse_request(conn["buf"])
			if req.is_empty():
				continue
			_conns.erase(conn)
			var out := _route(req)
			peer.put_data(AgentTools.http_response(int(out["status"]), str(out.get("body", "")), out.get("headers", {})))
			peer.disconnect_from_host()

	func _json(status: int, body: Dictionary) -> Dictionary:
		return {"status": status, "body": JSON.stringify(body), "headers": {"Content-Type": "application/json"}}

	func _ok_data(d: Dictionary) -> Dictionary:
		return _json(200, {"data": d, "error": {"code": "ok", "message": "", "log_id": "x"}})

	func _tokens(scope: String) -> Dictionary:
		_issued += 1
		var at := "at-%d" % _issued
		var rt := "rt-%d" % _issued
		_live[at] = scope
		refresh[rt] = scope
		return _json(200, {"access_token": at, "expires_in": 7200, "refresh_token": rt, "refresh_expires_in": 15552000,
			"open_id": "open-1", "scope": scope, "token_type": "Bearer"})

	func _route(req: Dictionary) -> Dictionary:
		var path := str(req.get("path", ""))
		var method := str(req.get("method", ""))
		var headers: Dictionary = req.get("headers", {})
		var body: PackedByteArray = req.get("body", PackedByteArray())
		if method == "POST" and path == "/v2/oauth/token/":
			var f := TikTok.OAuth.query_of("/?" + body.get_string_from_utf8())
			if f.get("client_key") != "ck-1" or f.get("client_secret") != "secret-1":
				return _json(401, {"error": "invalid_client", "error_description": "no such client"})
			if f.get("grant_type") == "authorization_code":
				if f.get("code") != code or f.get("redirect_uri") != redirect or TikTok.challenge(str(f.get("code_verifier", ""))) != challenge:
					return _json(400, {"error": "invalid_grant", "error_description": "bad code"})
				traded += 1
				return _tokens(asked)
			if f.get("grant_type") == "refresh_token":
				var rt := str(f.get("refresh_token", ""))
				if not refresh.has(rt):
					return _json(400, {"error": "invalid_grant", "error_description": "spent"})
				var scope := str(refresh[rt])
				refresh.erase(rt)
				return _tokens(scope)
			return _json(400, {"error": "unsupported_grant_type"})
		if path.begins_with("/upload/"):
			return _put(path.trim_prefix("/upload/"), headers, body)
		var tok := str(headers.get("authorization", "")).trim_prefix("Bearer ")
		if not _live.has(tok):
			return _json(401, {"data": {}, "error": {"code": "access_token_invalid", "message": "", "log_id": "x"}})
		var scopes := str(_live[tok]).split(",")
		if method == "GET" and path.begins_with("/v2/user/info/"):
			return _ok_data({"user": {"open_id": "open-1", "display_name": "Nightshift"}})
		var j := JSON.new()
		var data: Dictionary = j.data if j.parse(body.get_string_from_utf8()) == OK and j.data is Dictionary else {}
		if method == "POST" and path == "/v2/post/publish/creator_info/query/":
			if not scopes.has("video.publish"):
				return _json(401, {"data": {}, "error": {"code": "scope_not_authorized", "message": "", "log_id": "x"}})
			return _ok_data({"creator_nickname": "Nightshift", "creator_username": "night",
				"privacy_level_options": ["FOLLOWER_OF_CREATOR", "MUTUAL_FOLLOW_FRIENDS", "SELF_ONLY"],
				"comment_disabled": false, "duet_disabled": true, "stitch_disabled": false, "max_video_post_duration_sec": 600})
		if method == "POST" and (path == "/v2/post/publish/video/init/" or path == "/v2/post/publish/inbox/video/init/"):
			var inbox := path.contains("/inbox/")
			if not scopes.has("video.upload" if inbox else "video.publish"):
				return _json(401, {"data": {}, "error": {"code": "scope_not_authorized", "message": "", "log_id": "x"}})
			var si: Dictionary = data.get("source_info", {})
			if si.get("source") != "FILE_UPLOAD" or int(si.get("total_chunk_count", 0)) < 1:
				return _json(400, {"data": {}, "error": {"code": "invalid_param", "message": "source", "log_id": "x"}})
			inits += 1
			var id := "v_pub_%d" % inits
			var u := {"data": PackedByteArray(), "puts": 0, "size": int(si.get("video_size", 0)), "inbox": inbox,
				"count": int(si.get("total_chunk_count", 0)), "chunk_size": int(si.get("chunk_size", 0))}
			if not inbox:
				u["post_info"] = data.get("post_info", {})
			uploads[id] = u
			return _ok_data({"publish_id": id, "upload_url": "http://127.0.0.1:%d/upload/%s" % [port, id]})
		if method == "POST" and path == "/v2/post/publish/status/fetch/":
			var u2: Dictionary = uploads.get(str(data.get("publish_id", "")), {})
			if u2.is_empty():
				return _json(400, {"data": {}, "error": {"code": "invalid_param", "message": "", "log_id": "x"}})
			if (u2["data"] as PackedByteArray).size() < int(u2["size"]):
				return _ok_data({"status": "PROCESSING_UPLOAD", "uploaded_bytes": (u2["data"] as PackedByteArray).size()})
			if u2["inbox"]:
				return _ok_data({"status": "SEND_TO_USER_INBOX"})
			return _ok_data({"status": "PUBLISH_COMPLETE", "publicaly_available_post_id": [7300000000000000001]})
		return _json(404, {"data": {}, "error": {"code": "not_found", "message": path, "log_id": "x"}})

	func _put(id: String, headers: Dictionary, body: PackedByteArray) -> Dictionary:
		var u: Dictionary = uploads.get(id, {})
		if u.is_empty():
			return {"status": 404}
		u["puts"] = int(u["puts"]) + 1
		_chunks += 1
		if faults.has(_chunks):
			faults.erase(_chunks)
			return {"status": 503}
		var range := str(headers.get("content-range", ""))      # bytes A-B/N
		var a := int(range.get_slice(" ", 1).get_slice("-", 0))
		var b := int(range.get_slice("-", 1).get_slice("/", 0))
		var n := int(range.get_slice("/", 1))
		var have: PackedByteArray = u["data"]
		if str(headers.get("content-type", "")) != "video/mp4" or n != int(u["size"]) or a != have.size() or b - a + 1 != body.size():
			return {"status": 416}
		have.append_array(body)
		u["data"] = have
		return {"status": 201 if have.size() == int(u["size"]) else 206,
			"headers": {"Content-Range": "bytes 0-%d/%d" % [have.size() - 1, n]}}
