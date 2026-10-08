extends Node

## YouTube - sign in to the author's YouTube channel and upload a finished export to it.
##
## THE GOOGLE CLIENT IS THE AUTHOR'S OWN: a Google Cloud project's "Desktop app" OAuth client, as
## the JSON file Google hands out for it. It is imported once ([method import_client]) and kept in
## `user://youtube/` - never in the repository - and every later sign-in uses that copy.
##
## SIGNING IN is Google's flow for installed apps ([method sign_in]): the system browser opens
## Google's consent page, Google sends the browser back to a one-shot listener on 127.0.0.1 (a port
## the system picks) with a code, and the code is traded for tokens together with its PKCE verifier.
## Only the upload scope is asked for, until a note's YouTube card wants a playlist: listing the
## channel's playlists and adding a video to one take the wider [constant PLAYLIST_SCOPE], asked
## for by a sign-in of its own at that moment and never before ([method granted]). The refresh
## token is kept beside the client, owner read/write only, with the scopes Google granted, so later
## uploads need no browser until it lapses - after 7 days while the Cloud project's consent screen
## is in "Testing".
##
## AN UPLOAD IS RESUMABLE ([method resume], Google's protocol): a session is opened with the video's
## metadata, the file goes up in chunks, a chunk that fails asks YouTube how much arrived and carries
## on from there, and an access token that expires part way is renewed. The upload waits in
## `pending.json` from the moment it is queued ([method queue]) until the video is up, so one cut
## off by a quit or a dropped connection is resumed rather than repeated.
##
## It knows nothing of any mode: a note's YouTube card ([YouTubeCard]) and its panel say what the
## video is called, what it says, who may see it and the playlist it joins (see
## [member Exporter.upload_provider]), and [method video_body] turns that into the request. Loaded
## by path (no class_name), so a launch from a terminal never waits on the editor's class cache.

const SCOPE := "https://www.googleapis.com/auth/youtube.upload"
## What a playlist needs on top: `playlists.list` (mine) and `playlistItems.insert` take nothing
## narrower than managing the account.
const PLAYLIST_SCOPE := "https://www.googleapis.com/auth/youtube"
const ROOT := "user://youtube"
## Every upload goes up private unless the note's card says otherwise, says it is not made for kids,
## declares itself altered or synthetic content (the voice is synthesized, and a mode's pictures may
## be painted by a model), and declares NO PAID PROMOTION - left unsaid, YouTube Studio showed the
## question unanswered (2026-10-06). The category is People & Blogs.
const PRIVACY := "private"
## Who may see an upload, in the order the card offers them: YouTube's own words, and ours.
const PRIVACIES := {"private": "Private", "unlisted": "Unlisted", "public": "Public"}
## THE TITLE A NEW YOUTUBE CARD STARTS WITH: macros the panel fills ([method expand_title]).
const TITLE_TEMPLATE := "%title%: %episode%"
const CATEGORY := "22"
const PAID_PROMOTION := false
## YouTube's limits: the title in characters, the description in bytes of UTF-8, and the tags in
## characters counted as YouTube counts them (see [method tags_length]).
const TITLE_MAX := 100
const DESCRIPTION_MAX := 5000
const TAGS_MAX := 500
## A chunk: a multiple of 256 KiB, as the protocol requires of every chunk but the last.
const CHUNK := 8 * 1024 * 1024
## Seconds the browser's answer is waited for, and one chunk may take.
const SIGN_IN_TIMEOUT := 600.0
const CHUNK_TIMEOUT := 600.0
## Failures in a row before an upload stops (and waits to be resumed); the waits between them
## double, to a minute.
const MAX_TRIES := 8
const RETRY := [500, 502, 503, 504]
const OWNER_FILE := FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER
const OWNER_DIR := OWNER_FILE | FileAccess.UNIX_EXECUTE_OWNER

## Moved aside under test, so a gate never touches the author's client, sign-in or uploads.
static var root := ROOT
## Where uploads and revocations go: Google's, unless a gate stands in for it.
static var upload_url := "https://www.googleapis.com/upload/youtube/v3/videos"
static var revoke_url := "https://oauth2.googleapis.com/revoke"
static var thumbnail_url := "https://www.googleapis.com/upload/youtube/v3/thumbnails/set"
static var playlists_url := "https://www.googleapis.com/youtube/v3/playlists"
static var playlist_items_url := "https://www.googleapis.com/youtube/v3/playlistItems"
static var chunk := CHUNK
## Seconds per step of the wait between failures; a gate shortens it.
static var backoff_unit := 1.0
## How the consent page is opened: the system browser, unless a gate plays the browser.
static var open_url: Callable = Callable()

## "" | "signing_in" | "uploading"
var phase := ""
## How much of the upload YouTube has confirmed, 0..1.
var progress := 0.0
## The consent page of the sign-in waiting now, "" when none: to open again, or to copy.
var sign_in_url := ""
var _stop := false
## Which sign-in may still finish: a newer one, or a cancel, moves it on.
var _wait := 0
var _cancelled := -1


# --- the client ----------------------------------------------------------------------------------

## The Google client file's fields: `{client_id, client_secret, project_id, auth_uri, token_uri}`,
## or `{error}` saying what is wrong with it. Only a "Desktop app" client works here: the flow
## needs the loopback redirect Google gives installed apps.
static func parse_client(text: String) -> Dictionary:
	var j := JSON.new()
	if text.strip_edges().is_empty() or j.parse(text) != OK or not (j.data is Dictionary):
		return {"error": "that file is not a Google OAuth client (it is not JSON)"}
	var d: Dictionary = j.data
	if not (d.get("installed") is Dictionary):
		if d.get("web") is Dictionary:
			return {"error": "that is a \"Web application\" client - in Google Cloud, create an OAuth "
				+ "client of type \"Desktop app\" and import its file"}
		return {"error": "that file is not a Google OAuth client (it has no \"installed\" section)"}
	var c: Dictionary = d["installed"]
	var out := {"client_id": str(c.get("client_id", "")).strip_edges(),
		"client_secret": str(c.get("client_secret", "")).strip_edges(),
		"project_id": str(c.get("project_id", "")).strip_edges(),
		"auth_uri": str(c.get("auth_uri", "https://accounts.google.com/o/oauth2/auth")).strip_edges(),
		"token_uri": str(c.get("token_uri", "https://oauth2.googleapis.com/token")).strip_edges()}
	if String(out["client_id"]).is_empty() or String(out["client_secret"]).is_empty():
		return {"error": "the client file has no client_id or client_secret"}
	for k in ["auth_uri", "token_uri"]:
		if not _google_endpoint(String(out[k])):
			return {"error": "the client file's %s is not a Google address" % k}
	return out


## Whether [param url] may receive the client's secret and a sign-in code: Google's own hosts over
## https, or this machine over http (a gate standing in for Google).
static func _google_endpoint(url: String) -> bool:
	if not url.contains("://"):
		return false
	var host := url.get_slice("://", 1).get_slice("/", 0).get_slice("?", 0).get_slice(":", 0).to_lower()
	if url.begins_with("https://"):
		return host in ["google.com", "googleapis.com"] or host.ends_with(".google.com") \
			or host.ends_with(".googleapis.com")
	return url.begins_with("http://") and host in ["127.0.0.1", "localhost"]


## The imported client, as [method parse_client] reads it.
static func client() -> Dictionary:
	var raw := _read(_path("client.json"))
	if raw.is_empty():
		return {"error": "no Google client file has been imported"}
	return parse_client(raw)


static func has_client() -> bool:
	return not client().has("error")


## Import the client file at [param path]: checked, then kept - owner read/write only - for every
## later sign-in. "" on success, else why not. A different client ends the sign-in made with the
## old one, which Google would refuse anyway.
static func import_client(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "that file does not exist"
	var c := parse_client(FileAccess.get_file_as_string(path))
	if c.has("error"):
		return String(c["error"])
	var was := client()
	var keep := {"installed": {"client_id": c["client_id"], "client_secret": c["client_secret"],
		"project_id": c["project_id"], "auth_uri": c["auth_uri"], "token_uri": c["token_uri"]}}
	var err := _write(_path("client.json"), JSON.stringify(keep, "\t"), true)
	if not err.is_empty():
		return err
	if str(was.get("client_id", "")) != String(c["client_id"]):
		forget_token()
	print("ghost: YouTube - imported the Google client of project %s" % c["project_id"])
	return ""


static func forget_client() -> void:
	DirAccess.remove_absolute(_path("client.json"))
	forget_token()


# --- the sign-in ---------------------------------------------------------------------------------

## Whether a sign-in is kept. It may still have lapsed: [method access_token] finds out.
static func signed_in() -> bool:
	return not str(_token().get("refresh_token", "")).is_empty()


static func forget_token() -> void:
	DirAccess.remove_absolute(_path("token.json"))


## WHETHER THE KEPT SIGN-IN MAY DO [param scope]: Google says which scopes it granted with every
## token, and they are kept with it. A sign-in kept before that was written down asked for the
## upload scope alone, so that is all it has.
static func granted(scope: String) -> bool:
	if not signed_in():
		return false
	var t := _token()
	var have := str(t.get("scope", SCOPE)).split(" ", false)
	return have.has(scope)


## [param scopes] that the kept sign-in lacks.
static func missing_scopes(scopes: Array) -> Array:
	return scopes.filter(func(s: String) -> bool: return not granted(s))


static func _token() -> Dictionary:
	return _read_json(_path("token.json"))


## A PKCE code verifier: 64 characters of base64url from the system's cryptographic randomness
## (RFC 7636 asks for 43 to 128 from that alphabet).
static func verifier() -> String:
	return base64url(Crypto.new().generate_random_bytes(48))


## The S256 challenge for [param v]: base64url of its SHA-256.
static func challenge(v: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(v.to_utf8_buffer())
	return base64url(ctx.finish())


static func base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")


## Google's consent page for client [param c], answered at [param redirect], asking for
## [param scopes]. Offline access with the consent screen always shown, because only that returns a
## refresh token every time.
static func auth_url(c: Dictionary, redirect: String, code_challenge: String, state: String,
		scopes: Array = [SCOPE]) -> String:
	return String(c["auth_uri"]) + "?" + form({"client_id": c["client_id"], "redirect_uri": redirect,
		"response_type": "code", "scope": " ".join(PackedStringArray(scopes)), "code_challenge": code_challenge,
		"code_challenge_method": "S256", "state": state, "access_type": "offline", "prompt": "consent"})


## [param fields] as `application/x-www-form-urlencoded` - also a URL's query - in their order.
static func form(fields: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in fields:
		parts.append("%s=%s" % [str(k).uri_encode(), str(fields[k]).uri_encode()])
	return "&".join(parts)


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


## Sign in through the browser, asking for [param scopes] (the upload's alone unless a playlist is
## wanted), and keep the tokens: "" once signed in, else why not. The browser is waited for up to
## [constant SIGN_IN_TIMEOUT]; [method stop_sign_in] ends the wait.
##
## A NEWER SIGN-IN REPLACES ONE STILL WAITING. Google's "Access blocked" page (an account that is
## not one of a Testing project's test users) is a dead end that never comes back here, and a page
## can open behind another window - refusing a second attempt left nothing to do but wait out the
## first one.
func sign_in(scopes: Array = [SCOPE]) -> String:
	var c := client()
	if c.has("error"):
		return String(c["error"])
	_wait += 1
	var mine := _wait
	var tcp := TCPServer.new()
	if tcp.listen(0, "127.0.0.1") != OK:
		phase = ""
		sign_in_url = ""
		return "Ghost Notes could not listen on 127.0.0.1 for Google's answer"
	var redirect := "http://127.0.0.1:%d" % tcp.get_local_port()
	var v := verifier()
	var state := Crypto.new().generate_random_bytes(16).hex_encode()
	sign_in_url = auth_url(c, redirect, challenge(v), state, scopes)
	phase = "signing_in"
	reopen_sign_in()
	print("ghost: YouTube - signing in through the browser (Google answers on %s)" % redirect)
	var got: Dictionary = await _await_answer(tcp, state, mine)
	tcp.stop()
	if mine != _wait:
		return String(got.get("error", "the sign-in was replaced by a newer one"))
	sign_in_url = ""
	if got.has("error"):
		phase = ""
		return String(got["error"])
	var res: Dictionary = await _send(String(c["token_uri"]), _form_headers(), HTTPClient.METHOD_POST,
		form({"code": got["code"], "client_id": c["client_id"], "client_secret": c["client_secret"],
			"redirect_uri": redirect, "grant_type": "authorization_code", "code_verifier": v}).to_utf8_buffer(), 30.0)
	if mine == _wait:
		phase = ""
	if res.has("error"):
		return "Google could not be reached to finish the sign-in (%s)" % res["error"]
	var j: Variant = res.get("json")
	if int(res["code"]) != 200 or not (j is Dictionary):
		return error_text(int(res["code"]), res["body"])
	var tok: Dictionary = j
	if str(tok.get("refresh_token", "")).is_empty():
		return "Google signed in without a refresh token - sign in again"
	# what Google granted, which may be less than was asked: the consent page lets a scope be unticked
	var err := _write(_path("token.json"), JSON.stringify({"refresh_token": tok["refresh_token"],
		"access_token": str(tok.get("access_token", "")),
		"scope": str(tok.get("scope", " ".join(PackedStringArray(scopes)))),
		"expires_at": _now() + float(tok.get("expires_in", 0)) - 60.0}, "\t"), true)
	if err.is_empty():
		print("ghost: YouTube - signed in")
	return err


## Open the waiting sign-in's page again - it may have opened behind a window, or Google may have
## blocked it until the account was made a test user. False when no sign-in is waiting.
func reopen_sign_in() -> bool:
	if sign_in_url.is_empty():
		return false
	if open_url.is_valid():
		open_url.call(sign_in_url)
	elif OS.shell_open(sign_in_url) != OK:
		print("ghost: YouTube - no browser opened; open this address to sign in: " + sign_in_url)
	return true


## Stop waiting for the browser.
func stop_sign_in() -> void:
	if phase != "signing_in":
		return
	_cancelled = _wait
	_wait += 1
	phase = ""
	sign_in_url = ""


## The browser's answer at the listener: `{code}`, or `{error}`. Anything else that knocks - a
## favicon, a stale tab from an earlier sign-in - is turned away and the wait goes on, until the
## sign-in [param mine] is replaced or stopped.
func _await_answer(tcp: TCPServer, state: String, mine: int) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var conns: Array = []
	while true:
		if mine != _wait:
			_drop(conns)
			return {"error": "the sign-in was cancelled" if _cancelled == mine else "the sign-in was replaced by a newer one"}
		if Time.get_ticks_msec() - t0 > int(SIGN_IN_TIMEOUT * 1000.0):
			_drop(conns)
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
			var q := query_of(str(req.get("path", "")))
			if req.has("error") or str(req.get("method", "")) != "GET" or not q.has("state"):
				_answer(peer, 404, "Nothing here.")
				continue
			if str(q["state"]) != state:
				_answer(peer, 400, "This is not the sign-in Ghost Notes is waiting for. Start it again from Ghost Notes.")
				continue
			if q.has("error"):
				_answer(peer, 200, "The sign-in was not completed. You can close this tab.")
				_drop(conns)
				return {"error": ("Google refused access (access_denied): the consent screen was declined, or "
					+ "this Google account is not one of the Cloud project's test users") if q["error"] == "access_denied"
					else "Google said: %s" % q["error"]}
			if str(q.get("code", "")).is_empty():
				_answer(peer, 400, "Google sent no code. Start the sign-in again from Ghost Notes.")
				continue
			_answer(peer, 200, "Ghost Notes is signed in to YouTube. You can close this tab.")
			_drop(conns)
			return {"code": str(q["code"])}
		await get_tree().process_frame
	return {}


static func _answer(peer: StreamPeerTCP, status: int, text: String) -> void:
	var page := ("<!doctype html><html><head><meta charset=\"utf-8\"><title>Ghost Notes</title></head>"
		+ "<body style=\"margin:0;height:100vh;display:grid;place-items:center;background:#111;"
		+ "color:#ddd;font:16px system-ui,sans-serif\"><p>%s</p></body></html>") % text.xml_escape()
	peer.put_data(AgentTools.http_response(status, page,
		{"Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store"}))
	peer.disconnect_from_host()


static func _drop(conns: Array) -> void:
	for c in conns:
		((c as Dictionary)["peer"] as StreamPeerTCP).disconnect_from_host()
	conns.clear()


## A live access token: `{token}`, renewed from the kept refresh token when it has run out. Else
## `{error}`, with `signed_out` when only signing in again can help - the refresh token has lapsed
## or was revoked, and is forgotten - and `bad_client` when Google no longer knows the client (it is
## forgotten too, so the next upload asks for a new file).
func access_token() -> Dictionary:
	var t := _token()
	var refresh := str(t.get("refresh_token", ""))
	if refresh.is_empty():
		return {"error": "not signed in to YouTube", "signed_out": true}
	if not str(t.get("access_token", "")).is_empty() and _now() < float(t.get("expires_at", 0.0)):
		return {"token": str(t["access_token"])}
	var c := client()
	if c.has("error"):
		return {"error": String(c["error"]), "bad_client": true}
	var res: Dictionary = await _send(String(c["token_uri"]), _form_headers(), HTTPClient.METHOD_POST,
		form({"client_id": c["client_id"], "client_secret": c["client_secret"], "refresh_token": refresh,
			"grant_type": "refresh_token"}).to_utf8_buffer(), 30.0)
	if res.has("error"):
		return {"error": "Google could not be reached (%s)" % res["error"]}
	var j: Variant = res.get("json")
	if int(res["code"]) != 200 or not (j is Dictionary) or str((j as Dictionary).get("access_token", "")).is_empty():
		match oauth_error(res["body"]):
			"invalid_grant":
				forget_token()
				return {"error": "the YouTube sign-in has lapsed or was revoked - sign in again", "signed_out": true}
			"invalid_client", "unauthorized_client":
				forget_client()
				return {"error": "Google no longer accepts the imported client file - import it again", "bad_client": true}
		return {"error": error_text(int(res["code"]), res["body"])}
	t["access_token"] = str(j["access_token"])
	t["expires_at"] = _now() + float(j.get("expires_in", 3600)) - 60.0
	if not str(j.get("refresh_token", "")).is_empty():
		t["refresh_token"] = str(j["refresh_token"])
	if not str(j.get("scope", "")).is_empty():
		t["scope"] = str(j["scope"])
	_write(_path("token.json"), JSON.stringify(t, "\t"), true)
	return {"token": str(t["access_token"])}


## The kept access token, marked spent: the next [method access_token] renews it.
static func _expire() -> void:
	var t := _token()
	if t.is_empty():
		return
	t["expires_at"] = 0.0
	_write(_path("token.json"), JSON.stringify(t, "\t"), true)


## Forget the sign-in, and ask Google to revoke it - best effort: it is forgotten here either way.
func sign_out() -> void:
	var refresh := str(_token().get("refresh_token", ""))
	forget_token()
	if refresh.is_empty():
		return
	await _send(revoke_url, _form_headers(), HTTPClient.METHOD_POST, form({"token": refresh}).to_utf8_buffer(), 15.0)
	print("ghost: YouTube - signed out")


## End a sign-in's wait, or an upload after its current chunk (it stays resumable).
func stop() -> void:
	_stop = true
	stop_sign_in()


# --- the upload ----------------------------------------------------------------------------------

## The upload waiting to be made or finished: `{file, size, body, record, session, at}`, or {}.
static func pending() -> Dictionary:
	return _read_json(_path("pending.json"))


static func forget_pending() -> void:
	DirAccess.remove_absolute(_path("pending.json"))


## Queue [param file] to go up as [param body] (see [method video_body]), its result recorded in
## [param record], [param thumbnail] (an image) set as its thumbnail and the video added to the
## playlist [param playlist], when those are given: the pending upload, or `{error}`. Queued before
## anything is sent, so an upload stopped at any point - even before the sign-in - waits to be
## resumed.
static func queue(file: String, body: Dictionary, record := "", thumbnail := "", playlist := "") -> Dictionary:
	var size := _size_of(file)
	if size <= 0:
		return {"error": "the video file is missing or empty"}
	var p := {"file": file, "size": size, "body": body, "record": record, "thumbnail": thumbnail,
		"playlist": playlist, "session": "", "at": _now()}
	var err := _write(_path("pending.json"), JSON.stringify(p, "\t"), true)
	return {"error": err} if not err.is_empty() else p


## Queue and upload (see [method queue] and [method resume]).
func upload(file: String, body: Dictionary, record := "") -> Dictionary:
	var p := queue(file, body, record)
	if p.has("error"):
		return p
	return await resume()


## Send the pending upload: from where YouTube says it stopped, or from the start in a new session
## when the old one has lapsed (they last about a week). The finished video's
## `{id, url, privacy, title, channel, file, at}`, or `{error}` - and then it still waits.
func resume() -> Dictionary:
	if phase == "uploading":
		return {"error": "an upload is already running"}
	var p := pending()
	if p.is_empty():
		return {"error": "there is no upload to resume"}
	if _size_of(str(p.get("file", ""))) != int(p.get("size", -1)):
		forget_pending()
		return {"error": "the video file has changed or gone since - export it again"}
	phase = "uploading"
	_stop = false
	progress = 0.0
	var out: Dictionary = await _send_chunks(p)
	phase = ""
	if out.has("error"):
		print("ghost: YouTube - the upload stopped: %s (it can be resumed)" % out["error"])
	return out


func _send_chunks(p: Dictionary) -> Dictionary:
	var size := int(p["size"])
	var f := FileAccess.open(str(p["file"]), FileAccess.READ)
	if f == null:
		return {"error": "the video file could not be read"}
	var session := str(p.get("session", ""))
	var offset := 0
	var ask := not session.is_empty()       # where YouTube stands, before anything is sent
	var tries := 0
	var why := ""
	while true:
		if _stop:
			return {"error": "the upload was stopped"}
		if tries > MAX_TRIES:
			return {"error": "the upload kept failing (%s)" % why}
		if tries > 0:
			await get_tree().create_timer(minf(60.0, pow(2.0, tries)) * backoff_unit).timeout
		if session.is_empty():
			var s: Dictionary = await _open_session(p)
			if s.has("retry"):
				tries += 1
				why = str(s["error"])
				continue
			if s.has("error"):
				return s
			session = str(s["session"])
			p["session"] = session
			_write(_path("pending.json"), JSON.stringify(p, "\t"), true)
			offset = 0
			ask = false
		if ask:
			var st: Dictionary = await _status(session, size)
			if st.has("done"):
				return await _finish(p, st["done"])
			if st.has("gone"):
				session = ""
				continue
			if st.has("retry"):
				tries += 1
				why = str(st["error"])
				continue
			if st.has("error"):
				return st
			offset = int(st["offset"])
			progress = float(offset) / float(size)
			ask = false
		if offset >= size:
			# every byte is there and the video is not finished: ask again rather than send nothing
			ask = true
			tries += 1
			why = "YouTube holds the whole file but has not finished the video"
			continue
		var tok: Dictionary = await access_token()
		if tok.has("error"):
			if tok.has("signed_out") or tok.has("bad_client"):
				return tok
			tries += 1
			why = str(tok["error"])
			continue
		var n := mini(chunk, size - offset)
		f.seek(offset)
		var data := f.get_buffer(n)
		var r: Dictionary = await _send(session, PackedStringArray(["Authorization: Bearer " + str(tok["token"]),
			"Content-Type: video/mp4", "Content-Range: bytes %d-%d/%d" % [offset, offset + n - 1, size]]),
			HTTPClient.METHOD_PUT, data, CHUNK_TIMEOUT)
		var code := int(r.get("code", 0))
		if r.has("error") or code in RETRY:
			tries += 1
			why = str(r["error"]) if r.has("error") else "YouTube answered HTTP %d" % code
			ask = true
			continue
		match code:
			308:
				var next := next_offset(r["headers"])
				if next > offset:
					tries = 0
				else:
					tries += 1
					why = "YouTube kept none of a chunk"
				offset = next
				progress = float(offset) / float(size)
			200, 201:
				progress = 1.0
				return await _finish(p, r.get("json"))
			401:
				_expire()
				tries += 1
				why = "YouTube refused the sign-in"
			404, 410:
				session = ""
			_:
				return {"error": error_text(code, r["body"])}
	return {}


## Open an upload session for [param p] with its metadata: `{session}` (its address), or `{error}`
## - with `retry` when trying again may help.
func _open_session(p: Dictionary) -> Dictionary:
	var tok: Dictionary = await access_token()
	if tok.has("error"):
		return tok if tok.has("signed_out") or tok.has("bad_client") else {"retry": true, "error": tok["error"]}
	# the parts named are exactly the body's, so a part added to video_body is written, never dropped
	var parts := ",".join(PackedStringArray((p["body"] as Dictionary).keys()))
	var r: Dictionary = await _send(upload_url + "?uploadType=resumable&part=" + parts, PackedStringArray([
		"Authorization: Bearer " + str(tok["token"]), "Content-Type: application/json; charset=UTF-8",
		"X-Upload-Content-Length: %d" % int(p["size"]), "X-Upload-Content-Type: video/mp4"]),
		HTTPClient.METHOD_POST, JSON.stringify(p["body"]).to_utf8_buffer(), 60.0)
	if r.has("error"):
		return {"retry": true, "error": r["error"]}
	var code := int(r["code"])
	if code == 401:
		_expire()
		return {"retry": true, "error": "YouTube refused the sign-in"}
	if code in RETRY:
		return {"retry": true, "error": "YouTube answered HTTP %d" % code}
	if code != 200:
		return {"error": error_text(code, r["body"])}
	var at := header(r["headers"], "location")
	if at.is_empty():
		return {"error": "YouTube opened no upload session"}
	return {"session": at}


## Where an upload stands: `{offset}` (YouTube holds that many bytes), `{done: video}`, `{gone}` (the
## session has lapsed), or `{error}` - with `retry` when asking again may help.
func _status(session: String, size: int) -> Dictionary:
	var tok: Dictionary = await access_token()
	if tok.has("error"):
		return tok if tok.has("signed_out") or tok.has("bad_client") else {"retry": true, "error": tok["error"]}
	var r: Dictionary = await _send(session, PackedStringArray(["Authorization: Bearer " + str(tok["token"]),
		"Content-Length: 0", "Content-Range: bytes */%d" % size]), HTTPClient.METHOD_PUT, PackedByteArray(), 60.0)
	if r.has("error"):
		return {"retry": true, "error": r["error"]}
	var code := int(r["code"])
	match code:
		308:
			return {"offset": next_offset(r["headers"])}
		200, 201:
			return {"done": r.get("json")}
		404, 410:
			return {"gone": true}
		401:
			_expire()
			return {"retry": true, "error": "YouTube refused the sign-in"}
	if code in RETRY:
		return {"retry": true, "error": "YouTube answered HTTP %d" % code}
	return {"error": error_text(code, r["body"])}


## The upload is done: forget it, set its thumbnail, add it to its playlist, record it, and say what
## YouTube made of it - `thumbnail_error` and `playlist_error` saying why a thumbnail was not set or
## the playlist not joined (the video is up either way).
func _finish(p: Dictionary, video: Variant) -> Dictionary:
	forget_pending()
	var v: Dictionary = video if video is Dictionary else {}
	var id := str(v.get("id", ""))
	if id.is_empty():
		return {"error": "YouTube finished the upload but named no video - look in YouTube Studio"}
	var snip: Dictionary = v.get("snippet", {}) if v.get("snippet") is Dictionary else {}
	var stat: Dictionary = v.get("status", {}) if v.get("status") is Dictionary else {}
	var out := {"id": id, "url": "https://youtu.be/" + id, "privacy": str(stat.get("privacyStatus", "")),
		"title": str(snip.get("title", "")), "channel": str(snip.get("channelTitle", "")),
		"file": str(p.get("file", "")), "at": Time.get_datetime_string_from_system(true)}
	var thumb := str(p.get("thumbnail", ""))
	if not thumb.is_empty():
		out["thumbnail_error"] = await set_thumbnail(id, thumb)
		out["thumbnail"] = String(out["thumbnail_error"]).is_empty()
	var list := str(p.get("playlist", ""))
	if not list.is_empty():
		out["playlist_error"] = await add_to_playlist(id, list)
		out["playlist"] = list if String(out["playlist_error"]).is_empty() else ""
	var rec := str(p.get("record", ""))
	if not rec.is_empty():
		var err := record_upload(rec, out)
		if not err.is_empty():
			push_warning("ghost: YouTube - the upload could not be recorded: " + err)
	print("ghost: YouTube - uploaded %s (%s, %s)" % [out["url"], out["privacy"], out["channel"]])
	return out


## Set the image at [param path] (JPEG or PNG) as video [param video_id]'s thumbnail: "" when it is
## set, else why not. A channel YouTube has not verified (youtube.com/verify) may not set custom
## thumbnails at all.
func set_thumbnail(video_id: String, path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	if bytes.is_empty():
		return "the thumbnail image is missing"
	for attempt in 2:
		var tok: Dictionary = await access_token()
		if tok.has("error"):
			return str(tok["error"])
		var r: Dictionary = await _send(thumbnail_url + "?uploadType=media&videoId=" + video_id.uri_encode(),
			PackedStringArray(["Authorization: Bearer " + str(tok["token"]),
				"Content-Type: " + ("image/png" if path.get_extension().to_lower() == "png" else "image/jpeg")]),
			HTTPClient.METHOD_POST, bytes, 120.0)
		if r.has("error"):
			return "YouTube could not be reached (%s)" % r["error"]
		var code := int(r["code"])
		if code == 401 and attempt == 0:
			_expire()
			continue
		if code == 200:
			print("ghost: YouTube - thumbnail set for %s" % video_id)
			return ""
		var said := error_text(code, r["body"])
		if code == 403 and not said.contains("quota"):
			print("ghost: YouTube - the thumbnail was refused: " + said)
			return "custom thumbnails need a verified channel (youtube.com/verify)"
		return said
	return "YouTube refused the sign-in"


## THE CHANNEL'S PLAYLISTS, every page of them: `{playlists: [{id, title, privacy, count}]}` in
## YouTube's order, or `{error}` - with `scope` when the kept sign-in may not list them (sign in
## again with [constant PLAYLIST_SCOPE]) and `signed_out` when there is no sign-in at all.
func playlists() -> Dictionary:
	if not granted(PLAYLIST_SCOPE):
		return {"error": "the YouTube sign-in may upload but not see playlists", "scope": true,
			"signed_out": not signed_in()}
	var out: Array = []
	var page := ""
	for attempt in 40:              # 50 a page: two thousand playlists is past any channel's
		var tok: Dictionary = await access_token()
		if tok.has("error"):
			return tok
		var url := playlists_url + "?" + form({"part": "snippet,status,contentDetails", "mine": "true",
			"maxResults": 50}) + (("&pageToken=" + page.uri_encode()) if not page.is_empty() else "")
		var r: Dictionary = await _send(url, PackedStringArray(["Authorization: Bearer " + str(tok["token"])]),
			HTTPClient.METHOD_GET, PackedByteArray(), 30.0)
		if r.has("error"):
			return {"error": "YouTube could not be reached (%s)" % r["error"]}
		var code := int(r["code"])
		if code == 401:
			_expire()
			continue
		if code == 403 and error_text(code, r["body"]).contains("insufficient"):
			return {"error": "the YouTube sign-in may upload but not see playlists", "scope": true}
		var j: Variant = r.get("json")
		if code != 200 or not (j is Dictionary):
			return {"error": error_text(code, r["body"])}
		for item in (j as Dictionary).get("items", []):
			if not (item is Dictionary):
				continue
			var it: Dictionary = item
			var snip: Dictionary = it.get("snippet", {}) if it.get("snippet") is Dictionary else {}
			var stat: Dictionary = it.get("status", {}) if it.get("status") is Dictionary else {}
			var det: Dictionary = it.get("contentDetails", {}) if it.get("contentDetails") is Dictionary else {}
			out.append({"id": str(it.get("id", "")), "title": str(snip.get("title", "")),
				"privacy": str(stat.get("privacyStatus", "")), "count": int(det.get("itemCount", 0))})
		page = str((j as Dictionary).get("nextPageToken", ""))
		if page.is_empty():
			return {"playlists": out}
	return {"playlists": out}


## Add video [param video_id] to the end of playlist [param playlist_id]: "" when it is there, else
## why not.
func add_to_playlist(video_id: String, playlist_id: String) -> String:
	if not granted(PLAYLIST_SCOPE):
		return "the YouTube sign-in may upload but not add to playlists - sign in again from the YouTube card"
	var body := JSON.stringify({"snippet": {"playlistId": playlist_id,
		"resourceId": {"kind": "youtube#video", "videoId": video_id}}}).to_utf8_buffer()
	for attempt in 2:
		var tok: Dictionary = await access_token()
		if tok.has("error"):
			return str(tok["error"])
		var r: Dictionary = await _send(playlist_items_url + "?part=snippet", PackedStringArray([
			"Authorization: Bearer " + str(tok["token"]), "Content-Type: application/json; charset=UTF-8"]),
			HTTPClient.METHOD_POST, body, 60.0)
		if r.has("error"):
			return "YouTube could not be reached (%s)" % r["error"]
		var code := int(r["code"])
		if code == 401 and attempt == 0:
			_expire()
			continue
		if code == 200:
			print("ghost: YouTube - %s added to playlist %s" % [video_id, playlist_id])
			return ""
		return error_text(code, r["body"])
	return "YouTube refused the sign-in"


## The uploads recorded in [param path] - a mode's record file - oldest first:
## `[{id, url, privacy, title, channel, file, at}]`.
static func uploads_in(path: String) -> Array:
	var d := _read_json(path)
	return d["uploads"] if d.get("uploads") is Array else []


static func record_upload(path: String, entry: Dictionary) -> String:
	var all := uploads_in(path)
	all.append(entry)
	return _write(path, JSON.stringify({"uploads": all}, "\t"))


# --- what the video says -------------------------------------------------------------------------

## The upload's `video` resource from a mode's `{title, description, tags, privacy}`: fitted to
## YouTube's limits, with the constants above (a privacy YouTube does not know is [constant PRIVACY]).
## [param fallback] is the title when the mode gives none.
static func video_body(meta: Dictionary, fallback := "") -> Dictionary:
	var title := fit_title(str(meta.get("title", "")))
	if title.is_empty():
		title = fit_title(fallback)
	var raw: Variant = meta.get("tags", [])
	var tags: Array = Array(raw) if raw is Array or raw is PackedStringArray else []
	var privacy := str(meta.get("privacy", PRIVACY))
	return {
		"snippet": {"title": title if not title.is_empty() else "Untitled",
			"description": fit_description(str(meta.get("description", ""))),
			"tags": Array(fit_tags(tags)), "categoryId": CATEGORY},
		"status": {"privacyStatus": privacy if PRIVACIES.has(privacy) else PRIVACY,
			"selfDeclaredMadeForKids": false, "containsSyntheticMedia": true},
		"paidProductPlacementDetails": {"hasPaidProductPlacement": PAID_PROMOTION},
	}


## THE TITLE FROM ITS TEMPLATE: each `%name%` in [param template] replaced by [param values]'
## `name` - `%title%` the note's (a show's) title, `%episode%` the episode's, `%seed%` its seed,
## `%date%` today's - and an unknown one left as written. What a missing value leaves dangling (": " at either end, a
## doubled space) goes, so "%title%: %episode%" on a note with no episode is the title alone. NO
## NAME TWICE: an episode whose title already begins with the show's ("Truthful Tarot: ...") stands
## for both (the user, 2026-10-06).
static func expand_title(template: String, values: Dictionary) -> String:
	var v := {"title": "", "episode": "", "seed": "", "date": Time.get_date_string_from_system()}
	v.merge(values, true)
	var name := str(v.get("title", "")).strip_edges()
	var ep := str(v.get("episode", "")).strip_edges()
	if not name.is_empty() and ep.to_lower().begins_with(name.to_lower()) and template.contains("%episode%"):
		v["title"] = ""
	var out := template
	for k in v:
		out = out.replace("%" + str(k) + "%", str(v[k]).strip_edges())
	# a separator left between two (a gap where a value was) stands once
	out = RegEx.create_from_string("([:|·–-])(\\s*[:|·–-])+").sub(out, "$1", true)
	out = " ".join(out.split(" ", false))
	var trim := " :-|·–,/"
	while not out.is_empty() and trim.contains(out[0]):
		out = out.substr(1)
	while not out.is_empty() and trim.contains(out[out.length() - 1]):
		out = out.left(-1)
	return out.strip_edges()


## [param text] as YouTube takes it: `<` and `>` (which it refuses) become `‹` and `›`, and control
## characters other than line breaks and tabs go.
static func clean(text: String) -> String:
	var out := ""
	for ch in text.replace("<", "‹").replace(">", "›"):
		if ch.unicode_at(0) >= 32 or ch == "\n" or ch == "\t":
			out += ch
	return out


## One line, at most [constant TITLE_MAX] characters, cut at a word when it can be.
static func fit_title(title: String) -> String:
	var t := " ".join(clean(title).replace("\t", " ").replace("\n", " ").split(" ", false))
	if t.length() > TITLE_MAX:
		var cut := t.substr(0, TITLE_MAX)
		var at := cut.rfind(" ")
		t = cut.substr(0, at) if at > TITLE_MAX >> 1 else cut
	return t.strip_edges()


## At most [constant DESCRIPTION_MAX] bytes of UTF-8, cut at a line - else a word - when it can be.
static func fit_description(text: String) -> String:
	var t := clean(text).strip_edges()
	if t.to_utf8_buffer().size() <= DESCRIPTION_MAX:
		return t
	var lo := 0
	var hi := t.length()
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if t.substr(0, mid).to_utf8_buffer().size() <= DESCRIPTION_MAX:
			lo = mid
		else:
			hi = mid - 1
	var cut := t.substr(0, lo)
	var at := cut.rfind("\n")
	if at < lo >> 1:
		at = cut.rfind(" ")
	return (cut.substr(0, at) if at > lo >> 1 else cut).strip_edges()


## Tags written as one line - `a, b, "c d"`, optionally in YAML brackets, the way a document's
## `tags:` field holds them - as a list.
static func split_tags(text: String) -> PackedStringArray:
	var s := _unquote(text.strip_edges())
	if s.begins_with("[") and s.ends_with("]"):
		s = s.substr(1, s.length() - 2)
	var out := PackedStringArray()
	for part in s.split(","):
		var t := _unquote(String(part).strip_edges()).strip_edges()
		if not t.is_empty():
			out.append(t)
	return out


static func _unquote(s: String) -> String:
	if s.length() >= 2 and (s[0] == "\"" or s[0] == "'") and s[s.length() - 1] == s[0]:
		return s.substr(1, s.length() - 2)
	return s


## [param tags] as YouTube takes them: cleaned (no commas or quotes inside a tag), each once whatever
## its case, in order, and as many as fit in [constant TAGS_MAX] - one too long for the room left is
## skipped, and a shorter one after it may still fit.
static func fit_tags(tags: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	for raw in tags:
		var t := clean_tag(str(raw))
		if t.is_empty() or seen.has(t.to_lower()):
			continue
		var trial := out.duplicate()
		trial.append(t)
		if tags_length(trial) > TAGS_MAX:
			continue
		seen[t.to_lower()] = true
		out = trial
	return out


## One tag as it goes up: cleaned (see [method clean]), no commas or quotes inside, single spaces.
static func clean_tag(raw: String) -> String:
	return " ".join(clean(raw).replace(",", " ").replace("\"", "").replace("\n", " ").replace("\t", " ")
		.split(" ", false))


## The length YouTube counts for [param tags]: each tag, the commas between them, and the quotes it
## puts round a tag with a space in it.
static func tags_length(tags: PackedStringArray) -> int:
	var n := maxi(0, tags.size() - 1)
	for t in tags:
		n += String(t).length() + (2 if String(t).contains(" ") else 0)
	return n


# --- the wire ------------------------------------------------------------------------------------

## The value of header [param name] in [param headers] (`Name: value` lines, any case), "" if absent.
static func header(headers: PackedStringArray, name: String) -> String:
	var want := name.to_lower() + ":"
	for h in headers:
		if String(h).to_lower().begins_with(want):
			return String(h).substr(want.length()).strip_edges()
	return ""


## Where an upload carries on: one past the last byte YouTube's `Range` says it holds
## (`Range: bytes=0-N`), 0 when it holds nothing.
static func next_offset(headers: PackedStringArray) -> int:
	var r := header(headers, "range")
	if not r.contains("-"):
		return 0
	var last := r.get_slice("-", 1).strip_edges()
	return int(last) + 1 if last.is_valid_int() else 0


## What went wrong, in words, from a Google reply ([param code], [param body]): the YouTube API's
## error shape or the token endpoint's.
static func error_text(code: int, body: PackedByteArray) -> String:
	var j := JSON.new()
	if j.parse(body.get_string_from_utf8()) == OK and j.data is Dictionary:
		var d: Dictionary = j.data
		var e: Variant = d.get("error")
		if e is Dictionary:
			var reason := ""
			var errs: Variant = (e as Dictionary).get("errors")
			if errs is Array and not (errs as Array).is_empty() and (errs as Array)[0] is Dictionary:
				reason = str(((errs as Array)[0] as Dictionary).get("reason", ""))
			match reason:
				"quotaExceeded":
					return "the Google Cloud project's YouTube quota is used up for today"
				"uploadLimitExceeded":
					return "the channel has reached YouTube's upload limit for now"
				"youtubeSignupRequired":
					return "this Google account has no YouTube channel yet"
				"invalidTitle", "invalidDescription", "invalidTags":
					return "YouTube refused the video's %s" % reason.trim_prefix("invalid").to_lower()
			return "YouTube said: %s (HTTP %d%s)" % [str((e as Dictionary).get("message", "")), code,
				(", " + reason) if not reason.is_empty() else ""]
		if e is String:
			var said := str(d.get("error_description", ""))
			return "Google said: %s%s" % [e, (" - " + said) if not said.is_empty() else ""]
	return "YouTube answered HTTP %d" % code


## The OAuth error code in a token endpoint's reply (`invalid_grant`, ...), "" when there is none.
static func oauth_error(body: PackedByteArray) -> String:
	var j := JSON.new()
	if j.parse(body.get_string_from_utf8()) == OK and j.data is Dictionary and (j.data as Dictionary).get("error") is String:
		return str((j.data as Dictionary)["error"])
	return ""


static func _form_headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])


## One HTTP exchange: `{code, headers, body, json}` (`json` when the body parses), or `{error}` when
## no answer came at all.
func _send(url: String, headers: PackedStringArray, method: HTTPClient.Method, body: PackedByteArray,
		timeout: float) -> Dictionary:
	var h := HTTPRequest.new()
	h.use_threads = true
	h.timeout = timeout
	var proxy := Provision.https_proxy()
	if not proxy.is_empty():
		h.set_https_proxy(String(proxy[0]), int(proxy[1]))
	add_child(h)
	var all := PackedStringArray(["User-Agent: Ghost Notes (Godot %s)" % str(Engine.get_version_info().get("string", "4"))])
	all.append_array(headers)
	var err := h.request_raw(url, all, method, body)
	if err != OK:
		h.queue_free()
		return {"error": "the request could not start (%s)" % error_string(err)}
	var r: Array = await h.request_completed
	h.queue_free()
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"error": _result_text(int(r[0]))}
	var out := {"code": int(r[1]), "headers": r[2] as PackedStringArray, "body": r[3] as PackedByteArray}
	var j := JSON.new()
	if j.parse((r[3] as PackedByteArray).get_string_from_utf8()) == OK:
		out["json"] = j.data
	return out


static func _result_text(result: int) -> String:
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


# --- files ---------------------------------------------------------------------------------------

static func _path(name: String) -> String:
	return ProjectSettings.globalize_path(root.path_join(name))


static func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if not path.is_empty() and FileAccess.file_exists(path) else ""


static func _read_json(path: String) -> Dictionary:
	var raw := _read(path)
	var j := JSON.new()
	return j.data if not raw.is_empty() and j.parse(raw) == OK and j.data is Dictionary else {}


## [param text] into [param path] ATOMICALLY - a temp file beside it, renamed over - and with
## [param private], owner read/write only (its folder too) before a byte of it is written.
static func _write(path: String, text: String, private := false) -> String:
	var dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	if not DirAccess.dir_exists_absolute(dir):
		return "could not make the folder %s" % dir
	if private:
		FileAccess.set_unix_permissions(dir, OWNER_DIR)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "could not write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())]
	if private:
		FileAccess.set_unix_permissions(tmp, OWNER_FILE)
	f.store_string(text)
	f.close()
	if DirAccess.rename_absolute(tmp, path) != OK:
		DirAccess.remove_absolute(tmp)
		return "could not write %s" % path
	return ""


static func _size_of(path: String) -> int:
	if path.is_empty() or not FileAccess.file_exists(path):
		return -1
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var n := f.get_length()
	f.close()
	return n


static func _now() -> float:
	return Time.get_unix_time_from_system()
