extends Node

## TikTok - sign in to the author's TikTok account and send a finished export there: posted, or as a draft the author finishes
## in the TikTok app.
##
## The client is the author's own: a TikTok for Developers app with Login Kit (platform Desktop) and the Content Posting API,
## its Client key and Client secret entered once on the Upload card ([method set_client]) and kept owner read/write only in
## `user://tiktok/client.json`, never in the repository. The app registers [constant REDIRECT] as its redirect URI.
##
## Signing in is Login Kit for Desktop ([method sign_in]): the system browser opens TikTok's consent page, TikTok redirects to a
## one-shot listener on 127.0.0.1 with a code, and the code is traded for tokens with its PKCE verifier - whose challenge, for
## desktop, is the HEX of its SHA-256, not base64url ([method challenge]). One account is kept (`account.json`): an access
## token of hours, a refresh token of months, each refresh handing a new refresh token that replaces the old at once.
##
## What goes up is one of [constant MODES]: a draft (scope `video.upload`: the video lands in the TikTok app's inbox and the
## author writes, picks who sees it and posts it there), or a post (scope `video.publish`), which TikTok holds to its
## Direct Post rules: who may see it is picked from what the account allows ([method creator_info]), never by default, and an
## app TikTok has not audited may post only to a private account, and only as "Only me".
##
## An upload ([method resume]) waits in `pending.json` from [method queue] until TikTok has it: opened with its post's settings,
## sent in chunks ([method chunks_of]), then asked how it stands until TikTok says posted, in the inbox or failed. A cut-off
## upload starts over: TikTok's upload address lasts an hour and does not say how much it holds.
##
## A note's Upload card (tiktok_rows.gd) says how it goes up; [method post_of] turns the card's upload into the post. Loaded by
## path (no class_name), as youtube.gd is.

const OAuth := preload("res://src/export/oauth.gd")
const YouTube := preload("res://src/export/youtube.gd")

const ROOT := "user://tiktok"
## The redirect the TikTok app registers, as TikTok's Desktop rules allow it: any port of 127.0.0.1, this path.
const REDIRECT := "http://127.0.0.1:*/callback/"
const REDIRECT_PATH := "/callback/"
## What naming the account takes, and what each way of going up takes on top.
const BASIC_SCOPE := "user.info.basic"
const POST_SCOPE := "video.publish"
const DRAFT_SCOPE := "video.upload"
## How a video goes to TikTok, a draft unless the card says otherwise: a draft works for an app TikTok has not audited, and
## its author finishes it in the app.
const MODES := {
	"draft": {"label": "Draft in the TikTok app", "blurb": "The video lands in your TikTok app's inbox: open the notification there to write its caption, pick who sees it and post it. Nothing is public until you post it there. TikTok holds at most five drafts waiting a day.", "scope": DRAFT_SCOPE},
	"post": {"label": "Post", "blurb": "Posted straight to your account with the caption, privacy and settings below. An app TikTok has not audited may post only to a private account, and only as Only me.", "scope": POST_SCOPE},
}
const MODE := "draft"
## Who may see a post, in TikTok's words for each of its values; the account offers some of them ([method creator_info]).
const PRIVACIES := {"PUBLIC_TO_EVERYONE": "Everyone", "MUTUAL_FOLLOW_FRIENDS": "Friends", "FOLLOWER_OF_CREATOR": "Followers",
	"SELF_ONLY": "Only me"}
## What TikTok shows of a post's caption, counted in UTF-16 units; hashtags are part of it.
const CAPTION_MAX := 2200
## A chunk, in bytes: at least 5 MB and at most 64 MB as TikTok counts either way; the last takes the rest, up to 128 MB.
const CHUNK := 10000000
const MAX_CHUNKS := 1000
const CHUNK_TIMEOUT := 600.0
## Failures in a row before an upload stops (and waits to be resumed).
const MAX_TRIES := 6
const RETRY := [429, 500, 502, 503, 504]
## How long TikTok is asked how a sent video stands, in seconds, before it is left to finish on its own.
const PROCESS_WAIT := 600.0
const OWNER_FILE := FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER
const OWNER_DIR := OWNER_FILE | FileAccess.UNIX_EXECUTE_OWNER
## TikTok's music terms, which a post agrees to.
const MUSIC_TERMS := "https://www.tiktok.com/legal/page/global/music-usage-confirmation/en"

## Moved aside under test, so a gate never touches the author's client, sign-in or uploads.
static var root := ROOT
## Where requests go: TikTok's, unless a gate stands in for it.
static var auth_url := "https://www.tiktok.com/v2/auth/authorize/"
static var api := "https://open.tiktokapis.com/v2"
static var chunk := CHUNK
## Seconds per step of the wait between failures, and between asking how a sent video stands; a gate shortens them.
static var backoff_unit := 1.0
static var status_every := 5.0
## How the consent page is opened: the system browser, unless a gate plays the browser.
static var open_url: Callable = Callable()

## "" | "signing_in" | "uploading" | "processing"
var phase := ""
## How much of the file TikTok has taken, 0..1.
var progress := 0.0
## The consent page of the sign-in waiting now, "" when none.
var sign_in_url := ""
## What the account allows a post now, as last asked ([method creator_info]): {} until asked.
var creator := {}
var _wait := 0
var _cancelled := -1
var _stop := false


# --- the client ----------------------------------------------------------------------------------

## The app's `{client_key, client_secret}`, or {} when none is kept.
static func client() -> Dictionary:
	var c := _read_json(_path("client.json"))
	return c if not str(c.get("client_key", "")).is_empty() and not str(c.get("client_secret", "")).is_empty() else {}


static func has_client() -> bool:
	return not client().is_empty()


## Keep the app's [param key] and [param secret] (spaces trimmed): "" once kept, else why not. A new client forgets the account
## signed in through the old one.
static func set_client(key: String, secret: String) -> String:
	var k := key.strip_edges()
	var s := secret.strip_edges()
	if k.is_empty() or s.is_empty():
		return "both the Client key and the Client secret are needed"
	for t in [k, s]:
		if String(t).contains(" ") or String(t).contains("\n"):
			return "a Client key or secret has no spaces in it - copy it again from TikTok for Developers"
	if k != str(client().get("client_key", "")):
		_forget_account()
	return _write(_path("client.json"), JSON.stringify({"client_key": k, "client_secret": s}, "\t"), true)


static func forget_client() -> void:
	DirAccess.remove_absolute(_path("client.json"))
	_forget_account()


# --- the account ---------------------------------------------------------------------------------

## The account signed in: `{open_id, name, username, scope, ...}` with its tokens, or {}.
static func account() -> Dictionary:
	return _read_json(_path("account.json"))


## Is an account signed in whose refresh token has not lapsed?
static func signed_in() -> bool:
	var a := account()
	return not str(a.get("refresh_token", "")).is_empty() and _now() < float(a.get("refresh_expires_at", 0.0))


## The account's name as TikTok shows it: its display name, else its @username, else "".
static func name_of(a: Dictionary) -> String:
	var n := str(a.get("name", "")).strip_edges()
	if not n.is_empty():
		return n
	var u := str(a.get("username", "")).strip_edges()
	return ("@" + u) if not u.is_empty() else ""


## May the account signed in do [param scope]?
static func granted(scope: String) -> bool:
	return signed_in() and Array(str(account().get("scope", "")).split(",", false)).has(scope)


## What a sign-in asks for to go up as [param mode]: the account's name, the mode's scope, and what was granted before.
static func scopes_for(mode: String) -> Array:
	var out := [BASIC_SCOPE, str(Registry.field(MODES, mode if MODES.has(mode) else MODE, "scope", DRAFT_SCOPE))]
	for s in str(account().get("scope", "")).split(",", false):
		if not out.has(String(s)):
			out.append(String(s))
	return out


static func _forget_account() -> void:
	DirAccess.remove_absolute(_path("account.json"))


# --- the sign-in ---------------------------------------------------------------------------------

## A PKCE code verifier: 64 hex characters from the system's cryptographic randomness (TikTok takes 43 to 128 unreserved).
static func verifier() -> String:
	return Crypto.new().generate_random_bytes(32).hex_encode()


## The challenge for [param v] as Login Kit for Desktop asks it: the hex of its SHA-256.
static func challenge(v: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(v.to_utf8_buffer())
	return ctx.finish().hex_encode()


## TikTok's consent page for client key [param key], answered at [param redirect], asking for [param scopes].
static func consent_url(key: String, redirect: String, code_challenge: String, state: String, scopes: Array) -> String:
	return auth_url + "?" + OAuth.form({"client_key": key, "scope": ",".join(PackedStringArray(scopes)),
		"response_type": "code", "redirect_uri": redirect, "state": state, "code_challenge": code_challenge,
		"code_challenge_method": "S256"})


## Sign in through the browser, asking for [param scopes], and keep the account: `{account}`, or `{error}`. A newer sign-in
## replaces one still waiting; [method stop_sign_in] ends the wait.
func sign_in(scopes: Array) -> Dictionary:
	var c := client()
	if c.is_empty():
		return {"error": "no TikTok client yet - enter your app's Client key and secret on the Upload card"}
	_wait += 1
	var mine := _wait
	var tcp := TCPServer.new()
	if tcp.listen(0, "127.0.0.1") != OK:
		return {"error": "Ghost Notes could not listen on 127.0.0.1 for TikTok's answer"}
	var redirect := "http://127.0.0.1:%d%s" % [tcp.get_local_port(), REDIRECT_PATH]
	var v := verifier()
	var state := Crypto.new().generate_random_bytes(16).hex_encode()
	sign_in_url = consent_url(str(c["client_key"]), redirect, challenge(v), state, scopes)
	phase = "signing_in"
	reopen_sign_in()
	print("ghost: TikTok - signing in through the browser (TikTok answers on %s)" % redirect)
	var still := func() -> String:
		if mine == _wait:
			return ""
		return "the sign-in was cancelled" if _cancelled == mine else "the sign-in was replaced by a newer one"
	var got: Dictionary = await OAuth.await_code(tcp, state, still, "TikTok",
		"TikTok refused access: the consent page was declined, or this account may not use the app yet (a sandbox app's target users)",
		REDIRECT_PATH)
	tcp.stop()
	if mine != _wait:
		return {"error": str(got.get("error", "the sign-in was replaced by a newer one"))}
	sign_in_url = ""
	if got.has("error"):
		phase = ""
		return {"error": str(got["error"])}
	var out: Dictionary = await _trade(c, str(got["code"]), redirect, v, scopes)
	if mine == _wait:
		phase = ""
	return out


func _trade(c: Dictionary, code: String, redirect: String, v: String, ask: Array) -> Dictionary:
	var res: Dictionary = await _send(api + "/oauth/token/", _form_headers(), HTTPClient.METHOD_POST,
		OAuth.form({"client_key": c["client_key"], "client_secret": c["client_secret"], "code": code,
			"grant_type": "authorization_code", "redirect_uri": redirect, "code_verifier": v}).to_utf8_buffer(), 30.0)
	if res.has("error"):
		return {"error": "TikTok could not be reached to finish the sign-in (%s)" % res["error"]}
	var j: Variant = res.get("json")
	if int(res["code"]) != 200 or not (j is Dictionary) or str((j as Dictionary).get("refresh_token", "")).is_empty():
		return {"error": error_text(int(res["code"]), res["body"])}
	var a := _tokens({}, j)
	a["open_id"] = str((j as Dictionary).get("open_id", ""))
	a["scope"] = str((j as Dictionary).get("scope", ",".join(PackedStringArray(ask))))
	var err := _write(_path("account.json"), JSON.stringify(a, "\t"), true)
	if not err.is_empty():
		return {"error": err}
	creator = {}
	var who: Dictionary = await _whose(str(a["access_token"]))
	if not who.is_empty():
		a.merge(who, true)
		_write(_path("account.json"), JSON.stringify(a, "\t"), true)
	print("ghost: TikTok - signed in as %s (%s)" % [name_of(a), a["scope"]])
	return {"account": a}


## [param a] with the tokens of token reply [param j] laid over it, each with when it lapses.
static func _tokens(a: Dictionary, j: Dictionary) -> Dictionary:
	var out := a.duplicate()
	out["access_token"] = str(j.get("access_token", ""))
	out["expires_at"] = _now() + float(j.get("expires_in", 7200)) - 60.0
	if not str(j.get("refresh_token", "")).is_empty():
		out["refresh_token"] = str(j["refresh_token"])
		out["refresh_expires_at"] = _now() + float(j.get("refresh_expires_in", 15552000)) - 60.0
	if not str(j.get("scope", "")).is_empty():
		out["scope"] = str(j["scope"])
	return out


## Whose sign-in this is: `{name, username}` as TikTok gives them, or {} when it will not say.
func _whose(access: String) -> Dictionary:
	var r: Dictionary = await _send(api + "/user/info/?fields=open_id,display_name", PackedStringArray([
		"Authorization: Bearer " + access]), HTTPClient.METHOD_GET, PackedByteArray(), 30.0)
	var d := _data(r)
	var u: Variant = d.get("user")
	if not (u is Dictionary):
		return {}
	return {"name": str((u as Dictionary).get("display_name", "")).strip_edges()}


## Open the waiting sign-in's page again. False when none is waiting.
func reopen_sign_in() -> bool:
	if sign_in_url.is_empty():
		return false
	if open_url.is_valid():
		open_url.call(sign_in_url)
	elif OS.shell_open(sign_in_url) != OK:
		print("ghost: TikTok - no browser opened; open this address to sign in: " + sign_in_url)
	return true


func stop_sign_in() -> void:
	if phase != "signing_in":
		return
	_cancelled = _wait
	_wait += 1
	phase = ""
	sign_in_url = ""


## A live access token: `{token}`, renewed from the refresh token when it has run out, or `{error}` - with `signed_out` when
## only signing in again can help (the account's sign-in is forgotten then).
func access_token() -> Dictionary:
	var a := account()
	if not signed_in():
		return {"error": "not signed in to TikTok", "signed_out": true}
	if not str(a.get("access_token", "")).is_empty() and _now() < float(a.get("expires_at", 0.0)):
		return {"token": str(a["access_token"])}
	var c := client()
	if c.is_empty():
		return {"error": "no TikTok client is kept - enter it on the Upload card", "signed_out": true}
	var res: Dictionary = await _send(api + "/oauth/token/", _form_headers(), HTTPClient.METHOD_POST,
		OAuth.form({"client_key": c["client_key"], "client_secret": c["client_secret"], "grant_type": "refresh_token",
			"refresh_token": a["refresh_token"]}).to_utf8_buffer(), 30.0)
	if res.has("error"):
		return {"error": "TikTok could not be reached (%s)" % res["error"]}
	var j: Variant = res.get("json")
	if int(res["code"]) != 200 or not (j is Dictionary) or str((j as Dictionary).get("access_token", "")).is_empty():
		if YouTube.oauth_error(res["body"]) in ["invalid_grant", "invalid_client", "unauthorized_client"]:
			_forget_account()
			return {"error": "the TikTok sign-in has lapsed or was revoked - sign in again", "signed_out": true}
		return {"error": error_text(int(res["code"]), res["body"])}
	a = _tokens(a, j)
	_write(_path("account.json"), JSON.stringify(a, "\t"), true)
	return {"token": str(a["access_token"])}


## Sign out: forget the account and ask TikTok to revoke its token, best effort.
func sign_out() -> void:
	var a := account()
	var c := client()
	_forget_account()
	creator = {}
	if str(a.get("access_token", "")).is_empty() or c.is_empty():
		return
	await _send(api + "/oauth/revoke/", _form_headers(), HTTPClient.METHOD_POST, OAuth.form({"client_key": c["client_key"],
		"client_secret": c["client_secret"], "token": a["access_token"]}).to_utf8_buffer(), 15.0)
	print("ghost: TikTok - signed out of %s" % name_of(a))


## What the account allows a post now (TikTok asks that it be asked before each): `{privacy_level_options, comment_disabled,
## duet_disabled, stitch_disabled, max_video_post_duration_sec, creator_nickname, creator_username}`, kept in [member creator]
## - or `{error}`.
func creator_info() -> Dictionary:
	var tok: Dictionary = await access_token()
	if tok.has("error"):
		return tok
	var r: Dictionary = await _send(api + "/post/publish/creator_info/query/", _json_headers(str(tok["token"])),
		HTTPClient.METHOD_POST, "{}".to_utf8_buffer(), 30.0)
	if r.has("error"):
		return {"error": "TikTok could not be reached (%s)" % r["error"]}
	if int(r["code"]) != 200:
		return {"error": error_text(int(r["code"]), r["body"])}
	creator = _data(r)
	creator["at"] = _now()
	var a := account()
	var nick := str(creator.get("creator_nickname", "")).strip_edges()
	var user := str(creator.get("creator_username", "")).strip_edges()
	if not a.is_empty() and (nick != str(a.get("name", "")) or user != str(a.get("username", ""))):
		if not nick.is_empty():
			a["name"] = nick
		if not user.is_empty():
			a["username"] = user
		_write(_path("account.json"), JSON.stringify(a, "\t"), true)
	return creator


func stop() -> void:
	_stop = true
	stop_sign_in()


# --- the upload ----------------------------------------------------------------------------------

## The upload waiting to be made: `{file, size, post, record, at}`, or {}.
static func pending() -> Dictionary:
	return _read_json(_path("pending.json"))


static func forget_pending() -> void:
	DirAccess.remove_absolute(_path("pending.json"))


## Queue [param file] to go up as [param post] ([method post_of]), its result recorded in [param record]: the pending upload,
## or `{error}`. Queued before anything is sent, so an upload stopped at any point waits to be resumed.
static func queue(file: String, post: Dictionary, record := "") -> Dictionary:
	var size := _size_of(file)
	if size <= 0:
		return {"error": "the video file is missing or empty"}
	var p := {"file": file, "size": size, "post": post, "record": record, "at": _now()}
	var err := _write(_path("pending.json"), JSON.stringify(p, "\t"), true)
	return {"error": err} if not err.is_empty() else p


## What goes up, from the card's part of an upload ([param meta]'s `tiktok`) and the video's title, description, tags and
## thumbnail moment: `{mode, caption, privacy, disable_comment, disable_duet, disable_stitch, is_aigc, brand_organic,
## brand_content, cover_ms, length}`. [param length] is the video's, in seconds.
static func post_of(meta: Dictionary, length := 0.0) -> Dictionary:
	var t: Dictionary = meta.get("tiktok", {}) if meta.get("tiktok") is Dictionary else {}
	var mode := str(t.get("mode", MODE))
	var out := {"mode": mode if MODES.has(mode) else MODE, "caption": caption(meta),
		"privacy": str(t.get("privacy", "")), "disable_comment": not bool(t.get("comments", false)),
		"disable_duet": not bool(t.get("duet", false)), "disable_stitch": not bool(t.get("stitch", false)),
		"is_aigc": bool(t.get("aigc", true)), "brand_organic": bool(t.get("brand_own", false)),
		"brand_content": bool(t.get("brand_paid", false)), "length": length}
	var at := float(meta.get("thumbnail_at", -1.0))
	if at >= 0.0:
		out["cover_ms"] = int(round(at * 1000.0))
	return out


## The caption: the title, the description (its own words: no playlist or chapters, which TikTok cannot link) and the tags as
## hashtags, fitted to [constant CAPTION_MAX]; the description is cut first, then the last hashtags.
static func caption(meta: Dictionary) -> String:
	var title := YouTube.fit_title(str(meta.get("title", "")))
	var desc := _clean(str(meta.get("description", ""))).strip_edges()
	var raw: Variant = meta.get("tags", [])
	var tags := hashtags(Array(raw) if raw is Array or raw is PackedStringArray else [])
	var head := title
	while true:
		var tail := " ".join(tags)
		var fixed := _units(head) + (_units(tail) + (2 if not head.is_empty() else 0) if not tail.is_empty() else 0)
		if fixed <= CAPTION_MAX or tags.is_empty():
			var room := CAPTION_MAX - fixed - (2 if not head.is_empty() or not tail.is_empty() else 0)
			var body := _fit_units(desc, room) if room > 0 else ""
			var parts := PackedStringArray()
			for s in [head, body, tail]:
				if not String(s).is_empty():
					parts.append(s)
			return _fit_units("\n\n".join(parts), CAPTION_MAX)
		tags.resize(tags.size() - 1)
	return ""


## [param tags] as TikTok hashtags: each `#` and its words run together (letters, digits and `_` only, each word after the first
## capitalized), each once whatever its case.
static func hashtags(tags: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	var rx := RegEx.create_from_string("[^\\p{L}\\p{N}_]+")
	for t in tags:
		var words := rx.sub(str(t), " ", true).split(" ", false)
		var tag := ""
		for i in words.size():
			var w := String(words[i])
			tag += w if i == 0 else w.left(1).to_upper() + w.substr(1)
		if tag.is_empty() or seen.has(tag.to_lower()):
			continue
		seen[tag.to_lower()] = true
		out.append("#" + tag)
	return out


## How a file of [param size] bytes goes up: `{chunk_size, count}` - one chunk under two of [member chunk], else chunks of
## [member chunk] with the last taking what is left over (under two chunks, as TikTok's last may be).
static func chunks_of(size: int) -> Dictionary:
	if size < 2 * chunk:
		return {"chunk_size": size, "count": 1}
	@warning_ignore("integer_division")
	var n := mini(size / chunk, MAX_CHUNKS)
	return {"chunk_size": chunk, "count": n}


## Send the pending upload: `{publish_id, status, url, ...}` once TikTok has it, or `{error}`, and then it still waits.
func resume() -> Dictionary:
	if phase in ["uploading", "processing"]:
		return {"error": "an upload is already going to TikTok"}
	var p := pending()
	if p.is_empty():
		return {"error": "there is no TikTok upload to resume"}
	if _size_of(str(p.get("file", ""))) != int(p.get("size", -1)):
		forget_pending()
		return {"error": "the video file has changed or gone since - export it again"}
	phase = "uploading"
	_stop = false
	progress = 0.0
	var out: Dictionary = await _send_post(p)
	phase = ""
	if out.has("error"):
		print("ghost: TikTok - the upload stopped: %s" % out["error"])
	return out


func _send_post(p: Dictionary) -> Dictionary:
	var post: Dictionary = p.get("post", {}) if p.get("post") is Dictionary else {}
	var mode := str(post.get("mode", MODE))
	var size := int(p["size"])
	var plan := chunks_of(size)
	var body := {"source_info": {"source": "FILE_UPLOAD", "video_size": size, "chunk_size": int(plan["chunk_size"]),
		"total_chunk_count": int(plan["count"])}}
	var url := api + "/post/publish/inbox/video/init/"
	if mode == "post":
		var info: Dictionary = await creator_info()
		if info.has("error"):
			return info
		var why := refusal(post, info)
		if not why.is_empty():
			return {"error": why}
		var pi := {"title": str(post.get("caption", "")), "privacy_level": str(post["privacy"]),
			"disable_comment": bool(post.get("disable_comment", true)) or bool(info.get("comment_disabled", false)),
			"disable_duet": bool(post.get("disable_duet", true)) or bool(info.get("duet_disabled", false)),
			"disable_stitch": bool(post.get("disable_stitch", true)) or bool(info.get("stitch_disabled", false)),
			"brand_content_toggle": bool(post.get("brand_content", false)),
			"brand_organic_toggle": bool(post.get("brand_organic", false)), "is_aigc": bool(post.get("is_aigc", true))}
		if post.has("cover_ms"):
			pi["video_cover_timestamp_ms"] = int(post["cover_ms"])
		body["post_info"] = pi
		url = api + "/post/publish/video/init/"
	var opened: Dictionary = await _api_post(url, body)
	if opened.has("error"):
		return opened
	var id := str(opened.get("publish_id", ""))
	var dest := str(opened.get("upload_url", ""))
	if id.is_empty() or dest.is_empty():
		return {"error": "TikTok opened no upload"}
	var sent: Dictionary = await _send_chunks(str(p["file"]), size, plan, dest)
	if sent.has("error"):
		return sent
	phase = "processing"
	var st: Dictionary = await _until_done(id)
	if st.has("error"):
		forget_pending()            # TikTok has the file: a resume would send it twice
		return st
	return _finish(p, id, st)


## Why the account cannot take [param post] as [param info] (its [method creator_info]) says, "" when it can.
static func refusal(post: Dictionary, info: Dictionary) -> String:
	var options: Variant = info.get("privacy_level_options", [])
	var privacy := str(post.get("privacy", ""))
	if privacy.is_empty():
		return "pick who may see the TikTok post on the Upload card"
	if options is Array and not (options as Array).is_empty() and not (options as Array).has(privacy):
		return "this TikTok account does not offer \"%s\" now - pick another on the Upload card" % str(PRIVACIES.get(privacy, privacy))
	if bool(post.get("brand_content", false)) and privacy == "SELF_ONLY":
		return "branded content cannot be Only me on TikTok"
	var most := float(info.get("max_video_post_duration_sec", 0))
	var length := float(post.get("length", 0.0))
	if most > 0.0 and length > most:
		return "the video is %s long, and this TikTok account may post %s at most" % [Clock.text(length), Clock.text(most)]
	return ""


func _send_chunks(file: String, size: int, plan: Dictionary, dest: String) -> Dictionary:
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null:
		return {"error": "the video file could not be read"}
	var count := int(plan["count"])
	var each := int(plan["chunk_size"])
	for i in count:
		var first := i * each
		var last := size - 1 if i == count - 1 else first + each - 1
		f.seek(first)
		var data := f.get_buffer(last - first + 1)
		var tries := 0
		while true:
			if _stop:
				return {"error": "the upload was stopped"}
			if tries > MAX_TRIES:
				return {"error": "a chunk kept failing - resume it from the Upload card"}
			if tries > 0:
				await get_tree().create_timer(minf(60.0, pow(2.0, tries)) * backoff_unit).timeout
			var r: Dictionary = await _send(dest, PackedStringArray(["Content-Type: video/mp4",
				"Content-Range: bytes %d-%d/%d" % [first, last, size]]), HTTPClient.METHOD_PUT, data, CHUNK_TIMEOUT)
			var code := int(r.get("code", 0))
			if r.has("error") or code in RETRY:
				tries += 1
				continue
			if code == 201 or code == 206 or code == 200:
				progress = float(last + 1) / float(size)
				break
			if code == 403:
				return {"error": "TikTok's upload address lapsed (it lasts an hour) - resume it from the Upload card"}
			return {"error": "TikTok refused a chunk (HTTP %d)" % code}
	return {}


## Ask how upload [param id] stands until TikTok has it: `{status, post_ids}`, or `{error}`.
func _until_done(id: String) -> Dictionary:
	var t0 := _now()
	var fails := 0
	while _now() - t0 < PROCESS_WAIT:
		await get_tree().create_timer(status_every).timeout
		var d: Dictionary = await _api_post(api + "/post/publish/status/fetch/", {"publish_id": id})
		if d.has("error"):
			fails += 1
			if fails > MAX_TRIES:
				return {"status": "UNKNOWN", "post_ids": []}
			continue
		var s := str(d.get("status", ""))
		match s:
			"PUBLISH_COMPLETE", "SEND_TO_USER_INBOX":
				return {"status": s, "post_ids": post_ids(str(d.get("_body", "")))}
			"FAILED":
				return {"error": fail_text(str(d.get("fail_reason", "")))}
	return {"status": "PROCESSING", "post_ids": []}


## The ids of the posts a status reply's raw [param body] names, as text: they are 64-bit, past what a parsed JSON number keeps.
static func post_ids(body: String) -> Array:
	var at := body.find("\"publicaly_available_post_id\"")
	if at < 0:
		return []
	var open := body.find("[", at)
	var close := body.find("]", open)
	if open < 0 or close < 0:
		return []
	var out := []
	for m in RegEx.create_from_string("\\d+").search_all(body.substr(open, close - open)):
		out.append(m.get_string())
	return out


## The upload is TikTok's: forget it, record it and say what became of it.
func _finish(p: Dictionary, id: String, st: Dictionary) -> Dictionary:
	forget_pending()
	var post: Dictionary = p.get("post", {}) if p.get("post") is Dictionary else {}
	var a := account()
	var ids: Array = st.get("post_ids", [])
	var url := ""
	if not ids.is_empty() and not str(a.get("username", "")).is_empty():
		url = "https://www.tiktok.com/@%s/video/%s" % [str(a["username"]), str(ids[0])]
	var out := {"site": "tiktok", "publish_id": id, "status": str(st.get("status", "")), "url": url,
		"mode": str(post.get("mode", MODE)), "privacy": str(post.get("privacy", "")), "account": name_of(a),
		"file": str(p.get("file", "")), "at": Time.get_datetime_string_from_system(true)}
	var rec := str(p.get("record", ""))
	if not rec.is_empty():
		var err := YouTube.record_upload(rec, out)
		if not err.is_empty():
			push_warning("ghost: TikTok - the upload could not be recorded: " + err)
	print("ghost: TikTok - %s (%s)" % [out["status"], url if not url.is_empty() else id])
	return out


## A POST of [param body] as JSON to one of TikTok's endpoints, signed in: its `data`, or `{error}`; a refused sign-in is
## renewed and a busy TikTok waited for, a few times.
func _api_post(url: String, body: Dictionary) -> Dictionary:
	var why := ""
	for tries in MAX_TRIES:
		if tries > 0:
			await get_tree().create_timer(minf(60.0, pow(2.0, tries)) * backoff_unit).timeout
		var tok: Dictionary = await access_token()
		if tok.has("error"):
			if tok.has("signed_out"):
				return tok
			why = str(tok["error"])
			continue
		var r: Dictionary = await _send(url, _json_headers(str(tok["token"])), HTTPClient.METHOD_POST,
			JSON.stringify(body).to_utf8_buffer(), 60.0)
		if r.has("error"):
			why = str(r["error"])
			continue
		var code := int(r["code"])
		if code == 401 and api_error(r["body"]) == "access_token_invalid":
			var a := account()
			a["expires_at"] = 0.0
			_write(_path("account.json"), JSON.stringify(a, "\t"), true)
			why = "TikTok refused the sign-in"
			continue
		if code in RETRY:
			why = error_text(code, r["body"])
			continue
		if code != 200:
			return {"error": error_text(code, r["body"])}
		var d := _data(r)
		d["_body"] = (r["body"] as PackedByteArray).get_string_from_utf8()
		return d
	return {"error": "TikTok kept failing (%s)" % why}


# --- the wire ------------------------------------------------------------------------------------

## The error code in a TikTok API reply (`{error: {code}}`), "" when it says "ok" or nothing.
static func api_error(body: PackedByteArray) -> String:
	var j := JSON.new()
	if j.parse(body.get_string_from_utf8()) != OK or not (j.data is Dictionary):
		return ""
	var e: Variant = (j.data as Dictionary).get("error")
	if e is Dictionary:
		var c := str((e as Dictionary).get("code", ""))
		return "" if c == "ok" else c
	return str(e) if e is String else ""


## What went wrong, in words, from a TikTok reply ([param code], [param body]): the API's `{error: {code, message}}` or the
## token endpoint's `{error, error_description}`.
static func error_text(code: int, body: PackedByteArray) -> String:
	var e := api_error(body)
	match e:
		"unaudited_client_can_only_post_to_private_accounts":
			return "an app TikTok has not audited may post only to a private account - make the account private, send it as a draft, or have the app audited"
		"privacy_level_option_mismatch":
			return "TikTok does not offer that privacy to this account now - pick another"
		"spam_risk_too_many_posts":
			return "this account has posted as much as TikTok allows today"
		"spam_risk_too_many_pending_share":
			return "five drafts already wait in the TikTok app today - post or delete some there"
		"spam_risk_user_banned_from_posting":
			return "TikTok does not let this account post now"
		"reached_active_user_cap":
			return "the TikTok app has reached its daily number of accounts"
		"scope_not_authorized":
			return "the sign-in may not do this - sign in again on the Upload card"
		"access_token_invalid":
			return "TikTok refused the sign-in - sign in again on the Upload card"
		"rate_limit_exceeded":
			return "TikTok asks for a moment between requests"
		"invalid_client", "invalid_grant", "invalid_request", "unauthorized_client":
			var j := JSON.new()
			var said := ""
			if j.parse(body.get_string_from_utf8()) == OK and j.data is Dictionary:
				said = str((j.data as Dictionary).get("error_description", ""))
			return "TikTok said: %s%s" % [e, (" - " + said) if not said.is_empty() else ""]
	if not e.is_empty():
		var j := JSON.new()
		var msg := ""
		if j.parse(body.get_string_from_utf8()) == OK and j.data is Dictionary and (j.data as Dictionary).get("error") is Dictionary:
			msg = str(((j.data as Dictionary)["error"] as Dictionary).get("message", ""))
		return "TikTok said: %s%s (HTTP %d)" % [e, (" - " + msg) if not msg.is_empty() else "", code]
	return "TikTok answered HTTP %d" % code


## Why TikTok failed a sent video, in words.
static func fail_text(reason: String) -> String:
	match reason:
		"file_format_check_failed":
			return "TikTok could not read the video's format"
		"duration_check_failed":
			return "the video is too long or too short for this account"
		"frame_rate_check_failed":
			return "TikTok takes 23 to 60 frames a second"
		"picture_size_check_failed":
			return "TikTok takes 360 to 4096 pixels a side"
		"spam_risk_too_many_posts":
			return "this account has posted as much as TikTok allows today"
		"spam_risk_text":
			return "TikTok refused the caption"
		"auth_removed":
			return "the account took the app's access away - sign in again"
	return "TikTok failed the video (%s)" % (reason if not reason.is_empty() else "it did not say why")


## The `data` of a TikTok reply `r` ([method _send]), {} when it has none.
static func _data(r: Dictionary) -> Dictionary:
	var j: Variant = r.get("json")
	if not (j is Dictionary):
		return {}
	var d: Variant = (j as Dictionary).get("data")
	return d if d is Dictionary else {}


static func _form_headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])


static func _json_headers(token: String) -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer " + token, "Content-Type: application/json; charset=UTF-8"])


func _send(url: String, headers: PackedStringArray, method: HTTPClient.Method, body: PackedByteArray,
		timeout: float) -> Dictionary:
	return await OAuth.send(self, url, headers, method, body, timeout)


# --- text ----------------------------------------------------------------------------------------

## [param text] without control characters other than line breaks and tabs.
static func _clean(text: String) -> String:
	var out := ""
	for ch in text:
		if ch.unicode_at(0) >= 32 or ch == "\n" or ch == "\t":
			out += ch
	return out


## The length of [param text] as TikTok counts it, in UTF-16 units.
static func _units(text: String) -> int:
	return text.to_utf16_buffer().size() >> 1


## [param text] cut to [param most] UTF-16 units, at a word when it can be, with "…" when cut.
static func _fit_units(text: String, most: int) -> String:
	if _units(text) <= most:
		return text
	if most <= 1:
		return ""
	var lo := 0
	var hi := text.length()
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if _units(text.substr(0, mid)) <= most - 1:
			lo = mid
		else:
			hi = mid - 1
	var cut := text.substr(0, lo)
	var at := cut.rfind(" ")
	if at > lo >> 1:
		cut = cut.substr(0, at)
	return cut.strip_edges() + "…"


# --- files ---------------------------------------------------------------------------------------

static func _path(name: String) -> String:
	return ProjectSettings.globalize_path(root.path_join(name))


static func _read_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	return j.data if j.parse(FileAccess.get_file_as_string(path)) == OK and j.data is Dictionary else {}


## [param text] into [param path] atomically, and with [param private] owner read/write only (its folder too) before a byte of
## it is written: "" once written, else why not.
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
