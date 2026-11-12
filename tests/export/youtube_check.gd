extends SceneTree

## youtube_check - the YouTube upload's pieces that hold without a network: the client file, the sign-in's parts, what a
## video says, the records, the table episode's upload notes and the YouTube card.
##
##   godot --headless --path . --script res://tests/export/youtube_check.gd
##
## - the client file: a "Desktop app" client is read; a Web client, a file with no secret, non-JSON and non-Google endpoints are
##   refused, each saying why. Import keeps it owner read/write only and a bad file leaves the kept one alone. A channel keeps
##   the client it signed in with. Every client is kept, named by its Cloud project; a sign-in goes through the note's pick, else
##   the channel's own, else the last imported (control: with no channel, the last imported); what a machine already held is
##   listed where it lies without writing; the card's list shows the channel's own and a pick is kept by key, never id.
## - the channels: each sign-in kept under its channel, owner-only, in order, named by handle else title; each may do only what
##   it was granted; signed in again keeps its place; a lapsed one keeps its channel; one forgotten is off the list; an odd id
##   cannot name a file outside the folder.
## - the sign-in's parts: PKCE against RFC 7636's example, the consent URL (upload scope only, S256, offline, account chooser,
##   consent screen, loopback redirect, all encoded), the redirect's query decoded. The wire: the next offset from a 308's
##   `Range`, headers in any case, Google's error shapes in words.
## - what a video says: `<`/`>` made safe, title one line of at most 100 characters cut at a word, description at most 5000
##   bytes, tags split, deduplicated, counted as YouTube counts them and fitted to 500; private, not for kids, synthetic, no paid
##   promotion and People & Blogs unless asked otherwise (unknown privacy or category falls back); the playlist is named and
##   linked between the description and the chapters (control: no playlist, no line).
## - records: an upload recorded and read back; a queued upload pending with its channel, owner-only; a missing file refused; one
##   queued with no channel is aimed at the channel its sign-in lands on, one that names a channel keeps it.
## - the table episode: upload notes from the plan with a chapter per card timed from a take's word timings (an hour on, `h:mm:ss`),
##   the close "The close", and `upload.md` with the show's tags first. `fit_chapters`: the first at 0 and never dropped, each at
##   least ten seconds to the next one kept, the last ten from the video's end (control: far-apart chapters are kept whole). The
##   reader's chapters: a passage opening on `<!-- chapter: name -->` names its own chapter, a mark inside a passage starts one at
##   its word's time, one under ten seconds gives way to the next.
## - the export menu says nothing of YouTube; an upload whose title cannot be made is refused at the click, saying why.
## - the note's names are its Script card's: a card no panel bound fills nothing and nothing goes up (control); bound, it shows
##   Title, Episode, Author and Book and reads them; an empty Episode leaves the Title alone; an export's values are laid over the
##   note's. The tooltip names only the macros the note fills, `%seed%` on a note with no episodes is refused (control: a panel that
##   adds the seed fills it), and the tooltip stays wrapped across the card's refresh (control: changed values re-make it).
## - the YouTube card: a new one goes up nothing and privately; its block round-trips; unticked it describes no upload, ticked it
##   lays its title, privacy, category, playlist and channel over the panel's part. Channel toggles per channel kept, the note's
##   pressed; a channel not kept here shows dimmed with its name kept; another's toggle clears the playlist; a resume goes to its
##   channel; `title_shape` marks the episode's title in the template.
## - the tag field (tag_field.gd): chips, comma/Enter/paste splitting, × and Backspace removal, each tag once, fixed tags first,
##   dimmed chip with a reason, read-only has no ×, a long tag cannot widen the field.
## - the table panel's fields are the show's global values (description, tags, title, byline); a new episode shows them at once; an
##   upload is described from them once the note has a YouTube card with its box ticked; a note read as it is written shows its own
##   description box once it has a YouTube card (control: not before).
## - each episode's tags ([YouTubeTags], an [EpisodeStep]): the writer's answer is cleaned and deduplicated, a bare list taken, no
##   JSON or too few tags not kept; a tag whose every word is in the show's name, title or description is left out and said on
##   the row (control: one with a word of its own is kept). The prompt renders whole. The step exists only while the card's box
##   is ticked, waits for the episode's words, is refused read-only with a reason, is kept in the episode's folder with the words'
##   fingerprint, replaces the note's tags, goes stale when the words change, and fails with a reason when the note cannot keep
##   them (control). It is a row of the Pipeline card ([PipelineCard]) in a YouTube section, with ✓, the tags and ⟳ once made.
## - a note read as it is written is its own episode: its export is named after it (control: with no title, the exporter's own);
##   its YouTube card shows a description box (hidden where the show describes its episodes), the upload takes it first, then the
##   component's, then the note's tags; the tags step runs only for an export that goes up (control: one that does not).
## - a real show file: tags and byline land as top-level lines above ghost's block, the block holds the show's title and
##   description and no record per episode, the rest of the file is untouched, and a panel opening it fills a new episode from it.
## - the thumbnail is the card's choice: a new card's is YouTube's, its block keeps the choice and the painter's picks; the title
##   screen's frame is taken at its moment where the take opened on its title, not where it opened on nothing (control); a painted
##   one goes up once painted for the episode. The painted step ([YouTubeThumbnail]): wanted only while Painted; the writer is told
##   the episode and shown its numbered pictures (control: none where it has none); its answer is kept with the words and the
##   pictures it named, each once and only those that exist; the painter is told the words exactly (or no text), the pictures' look
##   and the frame's shape; the painting is cut to 1280x720 (720x1280 portrait), kept with the words' fingerprint, and goes up.
##   Matching: ticked, writer and painter are given pictures to follow; cleared, none (control). Every painting is kept as a
##   version: painted again, the writer is shown the earlier briefs (control: none the first time); the card steps between versions;
##   ✕ asks, then deletes the shown one; nothing paints over a choice (with none left, they paint one: control); the full-size
##   window holds the chosen version.
## - the title screen's moment and ffmpeg's arguments for taking a frame.

## By path, not by class name: a new class is unknown to `--script` runs until the editor rescans.
const YouTube := preload("res://src/export/youtube.gd")
const ROOT := "user://youtube_check"
const TAROT := "user://youtube_check_tarot"

var _fails := 0


func _init() -> void:
	# deferred: the exporter needs the autoloads, which are only up once the tree is
	_run.call_deferred()


func _run() -> void:
	# a gate never writes the settings of whoever runs it: a --script run is not read-only by itself, and the panel built below
	# binds its controls to them
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	var keep_root: String = YouTube.root
	var keep_tarot := TableEpisode.root
	YouTube.root = ROOT
	TableEpisode.root = TAROT
	_wipe(ROOT)
	_wipe(TAROT)
	_wipe(ROOT + "_files")
	for check in [_client, _import, _clients, _channels, _pkce, _auth_url, _query, _wire, _fit, _body, _records, _episode_notes,
			_menu, _card, _episode_tags, _thumbnails, _tag_field, _panel_fields, _note_steps, _doc_file]:
		if not bool(check.call()):
			_ok(false, "a check stopped part way (script error?)")
	_wipe(ROOT)
	_wipe(TAROT)
	_wipe(ROOT + "_files")
	YouTube.root = keep_root
	TableEpisode.root = keep_tarot
	print("youtube_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _wipe(path: String) -> void:
	var dir := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		_wipe(path.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


## A file under the scratch folder, written whole; its absolute path.
func _file(name: String, text: String) -> String:
	var path := ProjectSettings.globalize_path(ROOT + "_files").path_join(name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return path


func _client_json(id := "123-abc.apps.googleusercontent.com", kind := "installed", extra := {}) -> String:
	var c := {"client_id": id, "project_id": "ghost-check", "auth_uri": "https://accounts.google.com/o/oauth2/auth",
		"token_uri": "https://oauth2.googleapis.com/token",
		"auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
		"client_secret": "GOCSPX-not-a-real-secret", "redirect_uris": ["http://localhost"]}
	c.merge(extra, true)
	return JSON.stringify({kind: c})


## No client kept, wherever it lies: what a fresh machine has.
func _no_clients() -> void:
	for c in YouTube.clients():
		YouTube.forget_client(String((c as Dictionary)["key"]))


func _owner_only(path: String) -> bool:
	return OS.get_name() == "Windows" or FileAccess.get_unix_permissions(path) == YouTube.OWNER_FILE


func _client() -> bool:
	var c: Dictionary = YouTube.parse_client(_client_json())
	_ok(not c.has("error") and c["client_id"] == "123-abc.apps.googleusercontent.com"
		and c["client_secret"] == "GOCSPX-not-a-real-secret" and c["project_id"] == "ghost-check"
		and c["token_uri"] == "https://oauth2.googleapis.com/token", "a Desktop app client file is read")
	var web: Dictionary = YouTube.parse_client(_client_json("x", "web"))
	_ok(String(web.get("error", "")).contains("Desktop app"), "a Web application client is refused, naming the kind wanted")
	var bare: Dictionary = YouTube.parse_client(_client_json("x", "installed", {"client_secret": ""}))
	_ok(String(bare.get("error", "")).contains("client_secret"), "a client file with no secret is refused")
	_ok(YouTube.parse_client("not json at all").has("error") and YouTube.parse_client("").has("error")
		and YouTube.parse_client("[1, 2]").has("error"), "a file that is not a client is refused")
	var evil: Dictionary = YouTube.parse_client(_client_json("x", "installed", {"token_uri": "https://evil.example/token"}))
	_ok(String(evil.get("error", "")).contains("token_uri"), "a token endpoint that is not Google's is refused")
	var lookalike: Dictionary = YouTube.parse_client(_client_json("x", "installed",
		{"token_uri": "https://oauth2.googleapis.com.evil.example/token"}))
	_ok(lookalike.has("error"), "a host that only begins like Google's is refused")
	var plain: Dictionary = YouTube.parse_client(_client_json("x", "installed", {"token_uri": "http://oauth2.googleapis.com/token"}))
	_ok(plain.has("error"), "Google over plain http is refused")
	var local: Dictionary = YouTube.parse_client(_client_json("x", "installed", {"token_uri": "http://127.0.0.1:9/token"}))
	_ok(not local.has("error"), "this machine over http is allowed (a gate standing in for Google)")
	var defaults: Dictionary = YouTube.parse_client(JSON.stringify({"installed": {"client_id": "a", "client_secret": "b"}}))
	_ok(defaults.get("auth_uri") == "https://accounts.google.com/o/oauth2/auth"
		and defaults.get("token_uri") == "https://oauth2.googleapis.com/token", "missing endpoints default to Google's")
	return true


func _import() -> bool:
	_ok(not YouTube.has_client() and String(YouTube.client().get("error", "")).contains("imported"),
		"no client before one is imported")
	_ok(YouTube.import_client(_file("nope/missing.json", "")) != "", "an empty file is refused")
	_ok(YouTube.import_client(ProjectSettings.globalize_path(ROOT + "_files/absent.json")) == "that file does not exist",
		"a missing file is refused")
	var good := _file("client_secret_123.json", _client_json())
	_ok(YouTube.import_client(good) == "", "a good client file imports")
	var kept := YouTube._client_path(YouTube.client_key("123-abc.apps.googleusercontent.com"))
	_ok(YouTube.has_client() and YouTube.client()["client_id"] == "123-abc.apps.googleusercontent.com",
		"the imported client is what is read from then on")
	_ok(_owner_only(kept), "the kept client is owner read/write only (%o)" % FileAccess.get_unix_permissions(kept))
	_ok(OS.get_name() == "Windows" or FileAccess.get_unix_permissions(ProjectSettings.globalize_path(ROOT)) == YouTube.OWNER_DIR,
		"its folder is owner-only too")
	_ok(not FileAccess.get_file_as_string(kept).contains("redirect_uris"), "only what the flow needs is kept")
	# a channel keeps the client it signed in with
	YouTube._keep({"id": "UC-a", "handle": "@a", "title": "A"}, YouTube.client(), {"refresh_token": "rt"}, YouTube.SCOPE)
	_ok(YouTube.import_client(good) == "" and YouTube.signed_in("UC-a"), "re-importing the same client keeps the channel's sign-in")
	_ok(YouTube.import_client(_file("web.json", _client_json("x", "web"))) != ""
		and YouTube.client()["client_id"] == "123-abc.apps.googleusercontent.com" and YouTube.signed_in("UC-a"),
		"a bad file leaves the kept client and sign-in alone")
	_ok(YouTube.import_client(_file("other.json", _client_json("456-def.apps.googleusercontent.com"))) == ""
		and YouTube.client()["client_id"] == "456-def.apps.googleusercontent.com" and YouTube.signed_in("UC-a")
		and YouTube._token("UC-a")["client"]["client_id"] == "123-abc.apps.googleusercontent.com",
		"another client is the one imported last; the channel keeps the client it signed in with")
	var at := YouTube._channel_path("UC-a")
	_ok(_owner_only(at) and (OS.get_name() == "Windows"
		or FileAccess.get_unix_permissions(at.get_base_dir()) == YouTube.OWNER_DIR),
		"a channel's sign-in is owner read/write only, its folder too")
	var first := YouTube.client_key("123-abc.apps.googleusercontent.com")
	YouTube.forget_client(YouTube.client_key("456-def.apps.googleusercontent.com"))
	YouTube.forget_client(first)
	_ok(YouTube.signed_in("UC-a") and YouTube.client(first)["client_id"] == "123-abc.apps.googleusercontent.com",
		"forgetting a client costs no channel its sign-in, and the channel's copy keeps it on the list")
	YouTube.forget_channel("UC-a")
	_ok(YouTube.channels().is_empty() and not YouTube.signed_in("UC-a"), "a channel forgotten is off the list")
	_ok(YouTube.client(first)["client_id"] == "123-abc.apps.googleusercontent.com" and _owner_only(YouTube._client_path(first)),
		"its client is not: that copy may have been the only one, and it is kept owner-only")
	_no_clients()
	_ok(not YouTube.has_client() and YouTube.clients().is_empty(), "forgotten with no channel holding it, a client is gone")
	return true


## Every client is kept, and a sign-in goes through the one it should (see the header).
func _clients() -> bool:
	var a := "111-aaa111.apps.googleusercontent.com"
	var b := "222-bbb222.apps.googleusercontent.com"
	var c := "333-ccc333.apps.googleusercontent.com"
	var ka := YouTube.client_key(a)
	var kb := YouTube.client_key(b)
	var names := func() -> Array: return YouTube.clients().map(func(d: Dictionary) -> String: return d["name"])
	var id_of := func(d: Dictionary) -> String: return str(d.get("client_id", ""))
	_ok(YouTube.clients().is_empty() and YouTube.client_for("", "").has("error"), "no client kept: none to go through")
	var file_a := _file("a.json", _client_json(a, "installed", {"project_id": "project-a"}))
	_ok(YouTube.import_client(file_a) == "" and YouTube.import_client(_file("b.json", _client_json(b, "installed", {"project_id": "project-b"}))) == "",
		"two clients import")
	_ok(names.call() == ["project-a", "project-b"], "both are kept, named by their projects, the one imported last at the end (%s)" % str(names.call()))
	_ok(id_of.call(YouTube.client()) == b and id_of.call(YouTube.client(ka)) == a and YouTube.client("gone").has("error"),
		"with nothing to go on the last imported is read, and a key reads its own")
	_ok(ka != a and YouTube.client_key("") == "" and FileAccess.file_exists(YouTube._client_path(ka)),
		"a client is kept and named by a key, not its id")
	_ok((MiniYaml.parse(MiniYaml.emit({"client": "123e45678901"}))["data"] as Dictionary).get("client") == "123e45678901",
		"a key that reads as a number comes back from a note's YAML as it went in")
	# the report: @the-ink signed in through one project, a client imported since for @the-arc, and @the-ink lapsed
	YouTube._keep({"id": "UC-ink", "handle": "@the-ink", "title": "Ink"}, YouTube.client(ka), {"refresh_token": "rt"}, YouTube.SCOPE)
	YouTube._keep({"id": "UC-arc", "handle": "@the-arc", "title": "Arc"}, YouTube.client(kb), {"refresh_token": "rt2"}, YouTube.SCOPE)
	_ok(YouTube.signed_in("UC-ink") and YouTube.signed_in("UC-arc") and YouTube.channel_client("UC-ink") == ka and YouTube.channel_client("UC-arc") == kb,
		"two channels signed in at once, each through its own client")
	YouTube._drop_sign_in("UC-ink")
	_ok(id_of.call(YouTube.client()) == b and id_of.call(YouTube.client_for("", "UC-ink")) == a,
		"THE REPORT: a lapsed channel goes back through its own client, whatever was imported since")
	_ok(id_of.call(YouTube.client_for(kb, "UC-ink")) == b, "a note's pick goes first")
	_ok(id_of.call(YouTube.client_for("not-here", "UC-ink")) == a, "a pick not kept here is passed over")
	_ok(id_of.call(YouTube.client_for("", "UC-new")) == b and id_of.call(YouTube.client_for("", "")) == b,
		"the control: with no channel's own to go by, the last imported")
	var listed: Array = YouTube.clients().map(func(d: Dictionary) -> Array: return d["channels"])
	_ok(listed == [["@the-ink"], ["@the-arc"]], "each lists the channels that signed in through it, a lapsed one too (%s)" % str(listed))
	_ok(YouTube.import_client(file_a) == "" and YouTube.clients().size() == 2 and id_of.call(YouTube.client()) == a,
		"a file imported again replaces its own, and is the last imported")
	YouTube.import_client(_file("c.json", _client_json(c, "installed", {"project_id": "project-a"})))
	var told: Array = names.call()
	_ok(told.size() == 3 and told.count("project-a") == 0 and told[1] != told[2] and String(told[2]).begins_with("project-a"),
		"two clients of one project are told apart (%s)" % str(told))
	YouTube.forget_channel("UC-ink")
	YouTube.forget_channel("UC-arc")
	_no_clients()
	_ok(YouTube.clients().is_empty(), "nothing left")
	# what this machine already held: the one slot, and a channel's copy of a client that slot since lost
	var old := "1048-gu0.apps.googleusercontent.com"
	_wipe(ROOT)
	YouTube._write(YouTube._path(YouTube.OLD_CLIENT), _client_json(b, "installed", {"project_id": "annular"}), true)
	YouTube._write(YouTube._channel_path("UC-ink"), JSON.stringify({"channel": {"id": "UC-ink", "handle": "@the-ink", "title": "Ink"}, "added": 5.0,
		"client": {"client_id": old, "client_secret": "s", "token_uri": YouTube.TOKEN_URI}}), true)
	var files := func() -> Array:
		var out: Array = []
		for dir in ["", YouTube.CHANNELS, YouTube.CLIENTS]:
			if DirAccess.dir_exists_absolute(YouTube._path(dir)):
				for f in DirAccess.get_files_at(YouTube._path(dir)):
					out.append("%s/%s@%d" % [dir, f, FileAccess.get_modified_time(YouTube._path(dir).path_join(f))])
		return out
	var before: Array = files.call()
	_ok(names.call() == ["project 1048", "annular"], "they are listed where they lie, a copy with no project by its number (%s)" % str(names.call()))
	_ok(id_of.call(YouTube.client()) == b and id_of.call(YouTube.client_for("", "UC-ink")) == old
		and YouTube.client_for("", "UC-ink")["auth_uri"] == YouTube.AUTH_URI,
		"the old slot is the last imported, the channel's copy takes it to Google's own consent page")
	_ok(files.call() == before and not DirAccess.dir_exists_absolute(YouTube._path(YouTube.CLIENTS)), "reading them writes nothing")
	_ok(YouTube.import_client(_file("old.json", _client_json(old, "installed", {"project_id": "ghost-notes"}))) == ""
		and names.call().has("ghost-notes") and not names.call().has("project 1048"),
		"its file imported names the project")
	YouTube.forget_client(kb)
	_ok(not FileAccess.file_exists(YouTube._path(YouTube.OLD_CLIENT)) and YouTube.client(kb).has("error"), "the old slot can be forgotten")
	YouTube.forget_channel("UC-ink")
	_no_clients()
	return true


func _channels() -> bool:
	var c := {"client_id": "x", "client_secret": "y", "token_uri": "https://oauth2.googleapis.com/token"}
	_ok(YouTube.channels().is_empty() and YouTube.channel("").is_empty() and not YouTube.signed_in(""),
		"no channels before a sign-in, and none is \"\"")
	YouTube._keep({"id": "UC-ink", "handle": "@the-ink", "title": "The Ink"}, c, {"refresh_token": "r1"},
		YouTube.SCOPE + " " + YouTube.READ_SCOPE)
	YouTube._keep({"id": "UC-arc", "handle": "", "title": "The Arc"}, c, {"refresh_token": "r2"},
		YouTube.SCOPE + " " + YouTube.PLAYLIST_SCOPE)
	var names := func() -> Array: return YouTube.channels().map(func(ch: Dictionary) -> String: return ch["name"])
	_ok(names.call() == ["@the-ink", "The Arc"], "in the order signed in to, named by the handle, else the title (%s)" % str(names.call()))
	_ok(YouTube.granted(YouTube.PLAYLIST_SCOPE, "UC-arc") and not YouTube.granted(YouTube.PLAYLIST_SCOPE, "UC-ink")
		and YouTube.granted(YouTube.SCOPE, "UC-ink") and YouTube.missing_scopes([YouTube.SCOPE, YouTube.PLAYLIST_SCOPE], "UC-ink")
		== [YouTube.PLAYLIST_SCOPE], "each channel's sign-in may do what it was granted, and only that")
	_ok(not YouTube.granted(YouTube.SCOPE, "UC-gone") and YouTube.channel("UC-gone").is_empty(),
		"control: a channel not kept here may do nothing")
	YouTube._keep({"id": "UC-ink", "handle": "@the-ink", "title": "The Ink"}, c, {"refresh_token": "r3"}, YouTube.SCOPE)
	_ok(names.call() == ["@the-ink", "The Arc"] and YouTube._token("UC-ink")["refresh_token"] == "r3",
		"a channel signed in to again keeps its place on the list")
	YouTube._drop_sign_in("UC-ink")
	var ink: Dictionary = YouTube.channel("UC-ink")
	_ok(not YouTube.signed_in("UC-ink") and ink.get("signed_in") == false and ink.get("name") == "@the-ink"
		and YouTube.channels().size() == 2, "a lapsed sign-in keeps its channel, to sign in again")
	YouTube.forget_channel("UC-ink")
	YouTube.forget_channel("UC-arc")
	_ok(YouTube.channels().is_empty(), "forgotten, both are off the list")
	_ok(YouTube._channel_path("../x").get_base_dir() == YouTube._path(YouTube.CHANNELS),
		"a channel's file stays in its folder whatever its id says (%s)" % YouTube._channel_path("../x"))
	return true


func _pkce() -> bool:
	_ok(YouTube.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
		"the S256 challenge matches RFC 7636's example")
	var v: String = YouTube.verifier()
	var allowed := RegEx.create_from_string("^[A-Za-z0-9._~-]{43,128}$")
	_ok(allowed.search(v) != null, "a verifier is 43-128 characters of the unreserved alphabet (%d)" % v.length())
	_ok(YouTube.verifier() != v, "each verifier is fresh")
	_ok(YouTube.base64url(PackedByteArray([251, 255, 254])) == "-__-", "base64url swaps + and / and drops the padding")
	return true


func _auth_url() -> bool:
	var c: Dictionary = YouTube.parse_client(_client_json())
	var url: String = YouTube.auth_url(c, "http://127.0.0.1:5555", "CHALLENGE", "st4te")
	_ok(url.begins_with("https://accounts.google.com/o/oauth2/auth?"), "the consent URL is the client's auth_uri")
	var q: Dictionary = YouTube.query_of(url)
	_ok(q.get("client_id") == "123-abc.apps.googleusercontent.com" and q.get("response_type") == "code"
		and q.get("redirect_uri") == "http://127.0.0.1:5555" and q.get("state") == "st4te"
		and q.get("code_challenge") == "CHALLENGE" and q.get("code_challenge_method") == "S256",
		"it carries the client, the loopback redirect, the state and the S256 challenge")
	_ok(q.get("scope") == YouTube.SCOPE and YouTube.SCOPE == "https://www.googleapis.com/auth/youtube.upload",
		"it asks for the upload scope and nothing else")
	_ok(q.get("access_type") == "offline" and q.get("prompt") == "select_account consent",
		"offline access, the account chooser and the consent screen shown")
	_ok(url.contains("redirect_uri=http%3A%2F%2F127.0.0.1%3A5555")
		and url.contains("scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fyoutube.upload&"),
		"every value is encoded")
	return true


func _query() -> bool:
	var q: Dictionary = YouTube.query_of("/?state=abc&code=4%2F0AQlEd8x-yz_W&scope=a+b%20c&empty=&flag")
	_ok(q.get("state") == "abc" and q.get("code") == "4/0AQlEd8x-yz_W", "a redirect's code is decoded")
	_ok(q.get("scope") == "a b c" and q.get("empty") == "" and q.has("flag"), "+ and %20 are spaces; empty and bare keys kept")
	_ok(YouTube.query_of("/favicon.ico").is_empty(), "a path with no query has none")
	var f: String = YouTube.form({"a b": "c&d=e", "token": "1/x+y"})
	_ok(f == "a%20b=c%26d%3De&token=1%2Fx%2By", "a form body encodes keys and values")
	_ok(YouTube.query_of("?" + f) == {"a b": "c&d=e", "token": "1/x+y"}, "and decodes back")
	return true


func _wire() -> bool:
	_ok(YouTube.next_offset(PackedStringArray(["Content-Length: 0", "Range: bytes=0-262143"])) == 262144,
		"a 308's Range says where to carry on")
	_ok(YouTube.next_offset(PackedStringArray(["range: bytes=0-0"])) == 1, "header names in any case")
	_ok(YouTube.next_offset(PackedStringArray(["Content-Length: 0"])) == 0, "no Range: nothing is held yet")
	_ok(YouTube.header(PackedStringArray(["LOCATION: https://x/y?upload_id=1"]), "location") == "https://x/y?upload_id=1",
		"a header is found whatever its case")
	var quota := JSON.stringify({"error": {"code": 403, "message": "The request cannot be completed because you have exceeded your quota.",
		"errors": [{"reason": "quotaExceeded", "domain": "youtube.quota"}]}}).to_utf8_buffer()
	_ok(String(YouTube.error_text(403, quota)).contains("quota is used up"), "a spent quota is said plainly")
	var odd := JSON.stringify({"error": {"code": 400, "message": "Bad thing", "errors": [{"reason": "weird"}]}}).to_utf8_buffer()
	_ok(YouTube.error_text(400, odd) == "YouTube said: Bad thing (HTTP 400, weird)", "any other API error keeps its message and reason")
	var oauth := JSON.stringify({"error": "invalid_grant", "error_description": "Token has been expired or revoked."}).to_utf8_buffer()
	_ok(YouTube.error_text(400, oauth) == "Google said: invalid_grant - Token has been expired or revoked."
		and YouTube.oauth_error(oauth) == "invalid_grant", "the token endpoint's errors are read")
	_ok(YouTube.error_text(502, "<html>".to_utf8_buffer()) == "YouTube answered HTTP 502" and YouTube.oauth_error(quota) == "",
		"a reply that is not JSON still says its status")
	return true


func _fit() -> bool:
	var chaptered := func(c: Array, end := -1.0) -> String:
		return ", ".join(PackedStringArray(YouTube.fit_chapters(c, end).map(func(d: Dictionary) -> String:
			return "%s@%d" % [String(d["label"]), int(d["t"])])))
	_ok(chaptered.call([{"t": 0.0, "label": "A"}, {"t": 30.0, "label": "B"}, {"t": 60.0, "label": "C"}], 100.0) == "A@0, B@30, C@60",
		"the control: chapters ten seconds apart and from the end are kept whole")
	_ok(chaptered.call([{"t": 0.0, "label": "A"}, {"t": 50.0, "label": "B"}, {"t": 55.0, "label": "C"}, {"t": 100.0, "label": "D"}], 200.0)
		== "A@0, C@55, D@100", "a chapter under ten seconds gives way to the one after it")
	_ok(chaptered.call([{"t": 0.0, "label": "A"}, {"t": 5.0, "label": "B"}, {"t": 30.0, "label": "C"}]) == "A@0, C@30",
		"the first is never dropped: what begins too soon after it goes")
	_ok(chaptered.call([{"t": 3.0, "label": "A"}, {"t": 40.0, "label": "B"}]) == "A@0, B@40", "the first chapter starts at 0")
	_ok(chaptered.call([{"t": 0.0, "label": "A"}, {"t": 50.0, "label": "B"}, {"t": 95.0, "label": "C"}], 100.0) == "A@0, B@50",
		"a last chapter under ten seconds from the end goes")
	_ok(chaptered.call([{"t": 40.0, "label": "B"}, {"t": 0.0, "label": "A\nsplit"}, {"t": 20.0, "label": " "}]) == "A split@0, B@40",
		"in time order, a label one line, an empty one dropped")
	_ok(YouTube.clean("a <b> c\u0007\r\n\td") == "a ‹b› c\n\td", "< and > are made safe; control characters but breaks and tabs go")
	_ok(YouTube.fit_title("  Why <you> keep\nwaking   up  ") == "Why ‹you› keep waking up", "a title is one clean line")
	var words := "word ".repeat(30)
	var t: String = YouTube.fit_title(words)
	_ok(t.length() <= 100 and t.ends_with("word") and not t.ends_with(" "), "a long title is cut at a word, within 100 (%d)" % t.length())
	var unbroken := "x".repeat(150)
	_ok(YouTube.fit_title(unbroken).length() == 100, "a title with no space is cut at 100")
	_ok(YouTube.fit_title("Ünïcödé · 🜁 tarot") == "Ünïcödé · 🜁 tarot", "a title keeps what it says")
	var para := ("é".repeat(40) + "\n").repeat(80)
	var d: String = YouTube.fit_description(para)
	_ok(d.to_utf8_buffer().size() <= 5000 and d.ends_with("é") and para.begins_with(d), "a long description fits 5000 bytes, cut at a line (%d bytes)" % d.to_utf8_buffer().size())
	_ok(YouTube.fit_description("short\n\n0:00 Intro") == "short\n\n0:00 Intro", "a short description is untouched")
	_ok(Array(YouTube.split_tags("\"Oregon, Nexpo, Down the Rabbit Hole, Hilbert's hotel\"")) == ["Oregon", "Nexpo", "Down the Rabbit Hole", "Hilbert's hotel"],
		"tags split as a document's tags: line holds them")
	_ok(Array(YouTube.split_tags("[tarot, 'pick a card', \"\", ]")) == ["tarot", "pick a card"], "a YAML list too; empties dropped")
	_ok(YouTube.split_tags("").is_empty(), "no tags from nothing")
	_ok(YouTube.tags_length(PackedStringArray(["ab", "c d"])) == 2 + 1 + 3 + 2, "length counts the commas and the quotes round a spaced tag")
	var fitted: PackedStringArray = YouTube.fit_tags(["Tarot", "tarot", " pick   a card ", "a, b", "say \"hi\"", "<3", ""])
	_ok(Array(fitted) == ["Tarot", "pick a card", "a b", "say hi", "‹3"], "tags are cleaned, each once whatever its case (%s)" % str(fitted))
	var many: Array = []
	for i in 60:
		many.append("tag number %02d" % i)
	many.append("tiny")
	var fit: PackedStringArray = YouTube.fit_tags(many)
	_ok(YouTube.tags_length(fit) <= 500 and fit.size() > 20 and fit[fit.size() - 1] == "tiny",
		"tags fill 500 characters, and a short one after the room ran out still fits (%d)" % YouTube.tags_length(fit))
	return true


func _body() -> bool:
	var b: Dictionary = YouTube.video_body({"title": "A <title>", "description": "Hello\n\n0:00 Intro",
		"tags": PackedStringArray(["tarot", "TAROT", "pick a card"])})
	_ok(b["snippet"]["title"] == "A ‹title›" and b["snippet"]["description"] == "Hello\n\n0:00 Intro"
		and b["snippet"]["tags"] == ["tarot", "pick a card"] and b["snippet"]["categoryId"] == "22",
		"the snippet is fitted, the category People & Blogs")
	_ok(b.get("paidProductPlacementDetails") == {"hasPaidProductPlacement": false},
		"no paid promotion is declared, not left unanswered")
	_ok(b["status"] == {"privacyStatus": "private", "selfDeclaredMadeForKids": false, "containsSyntheticMedia": true},
		"private, not made for kids, disclosed as synthetic")
	_ok(YouTube.video_body({"privacy": "public"})["status"]["privacyStatus"] == "public"
		and YouTube.video_body({"privacy": "unlisted"})["status"]["privacyStatus"] == "unlisted"
		and YouTube.video_body({"privacy": "everyone"})["status"]["privacyStatus"] == "private",
		"the privacy asked for, and private for one YouTube does not know")
	_ok(YouTube.video_body({"category": "27"})["snippet"]["categoryId"] == "27"
		and YouTube.video_body({"category": "44"})["snippet"]["categoryId"] == "22"
		and YouTube.video_body({"category": "Education"})["snippet"]["categoryId"] == "22",
		"the category asked for, and People & Blogs for one an upload cannot take (Trailers) or that is not an id")
	_ok(YouTube.video_body({}, "Episode 7")["snippet"]["title"] == "Episode 7"
		and YouTube.video_body({})["snippet"]["title"] == "Untitled", "a video always has a title")
	_ok(YouTube.video_body({"tags": ["a", "b"]})["snippet"]["tags"] == ["a", "b"], "tags as an Array too")
	# the playlist, before the timestamps: the stand-in for the end screen the API cannot write
	var listed: String = YouTube.video_body({"description": "Hello", "playlist": "PL-1", "playlist_title": "Truthful <Tarot>",
		"chapters": PackedStringArray(["0:00 Intro", "0:40 The Tower"])})["snippet"]["description"]
	_ok(listed == "Hello\n\nPlaylist: Truthful ‹Tarot›\nhttps://www.youtube.com/playlist?list=PL-1\n\n0:00 Intro\n0:40 The Tower",
		"the playlist is named and linked between the description and the chapters (%s)" % listed)
	_ok(YouTube.video_body({"description": "Hello", "chapters": ["0:00 Intro"]})["snippet"]["description"] == "Hello\n\n0:00 Intro",
		"no playlist, no line")
	_ok(YouTube.video_body({"playlist": "PL-1"})["snippet"]["description"] == "Playlist: https://www.youtube.com/playlist?list=PL-1",
		"a video with nothing else to say still links its playlist, by its link alone while its title is unknown")
	return true


func _records() -> bool:
	var rec := ProjectSettings.globalize_path(ROOT + "_files/ep/youtube.json")
	_ok(YouTube.uploads_in(rec).is_empty() and YouTube.uploads_in("").is_empty(), "no record, no uploads")
	_ok(YouTube.record_upload(rec, {"id": "a", "url": "https://youtu.be/a"}) == ""
		and YouTube.record_upload(rec, {"id": "b", "url": "https://youtu.be/b"}) == "", "uploads are recorded")
	var ups: Array = YouTube.uploads_in(rec)
	_ok(ups.size() == 2 and ups[0]["id"] == "a" and ups[1]["id"] == "b", "and read back oldest first")
	_ok(YouTube.queue(ProjectSettings.globalize_path(ROOT + "_files/none.mp4"), {}, "UC-a").has("error")
		and YouTube.pending().is_empty(), "a missing video is not queued")
	var video := _file("video.mp4", "0123456789")
	var p: Dictionary = YouTube.queue(video, {"snippet": {"title": "T"}}, "UC-a", rec)
	var back: Dictionary = YouTube.pending()
	_ok(not p.has("error") and back.get("file") == video and int(back.get("size", 0)) == 10 and back.get("channel") == "UC-a"
		and back.get("record") == rec and back.get("session") == "" and back["body"]["snippet"]["title"] == "T",
		"a queued upload waits in pending.json with its channel, no session yet")
	_ok(_owner_only(YouTube._path("pending.json")), "pending.json is owner read/write only (it will hold the session)")
	YouTube.aim_pending("UC-b")
	_ok(YouTube.pending().get("channel") == "UC-a", "a waiting upload that names its channel keeps it")
	YouTube.queue(video, {}, "")
	YouTube.aim_pending("UC-b")
	_ok(YouTube.pending().get("channel") == "UC-b", "one queued with no channel goes to the one its sign-in lands on")
	YouTube.forget_pending()
	_ok(YouTube.pending().is_empty(), "and is forgotten")
	return true


## The reader's chapters, on an episode of its own (a script is read again only once its file's time moves on, in whole
## seconds): one card out of a box, its work, the close - the passages naming theirs.
func _named_chapters() -> bool:
	var ep := TableEpisode.open("youtube-check", 8)
	DirAccess.make_dir_recursive_absolute(ep.dir)
	ep.write_json("plan", {"episode_title": "A Brew", "description": "", "spread": {"name": "One", "positions": [{"name": "The Card", "asks": ""}]}})
	ep.write_json("draw", {"cards": [{"name": "The Tower", "reversed": false}]})
	ep.write_text("script", "<!-- table: open -->\n\nHello my loves welcome back.\n\n<!-- table: draw 1 -->\n\n"
		+ "<!-- chapter: The recipe -->\nThe Tower is here.\n\n<!-- table: work 1 -->\n\n<!-- chapter: First the resin -->\n"
		+ "One two three. <!-- chapter: A moment --> Four five six. <!-- chapter: Then the stir --> seven eight.\n\n"
		+ "<!-- table: spread -->\n\n<!-- chapter: Bottling it -->\nThat is the end.\n")
	var words: Array = []
	var at := {0: 1.0, 5: 60.0, 9: 120.0, 12: 200.0, 15: 204.0, 17: 300.0}
	var t := 1.0
	var i := 0
	for w in "Hello my loves welcome back The Tower is here One two three Four five six seven eight That is the end".split(" "):
		t = float(at.get(i, t))
		words.append({"text": w, "t0": t, "t1": t + 0.4})
		t += 0.5
		i += 1
	var take := ProjectSettings.globalize_path(ROOT + "_files/take_named.wav")
	var side := FileAccess.open(take.get_basename() + ".json", FileAccess.WRITE)
	side.store_string(JSON.stringify({"words": words, "bookend": {"in": 0.0, "out": 9.0}}))
	side.close()
	var ch: PackedStringArray = ep.upload_notes(take)["chapters"]
	var labels := Array(ch).map(func(c: String) -> String: return c.substr(c.find(" ") + 1))
	_ok(labels == ["Intro", "The recipe", "First the resin", "Then the stir", "Bottling it"],
		"each passage's opening mark names its chapter, a card's work one, a mark inside one at its word; one too short gives way (%s)" % str(ch))
	_ok(ch.size() == 5 and ch[3] == "3:24 Then the stir" and ch[2].begins_with("1:5"), "a chapter starts where its words do (%s)" % str(ch))
	return true


## An episode on disk: a plan, a draw of two cards, a script with their marks, and a take whose
## words put the spread past the hour.
func _episode_notes() -> bool:
	var ep := TableEpisode.open("youtube-check", 7)
	DirAccess.make_dir_recursive_absolute(ep.dir)
	ep.write_json("plan", {"episode_title": "Why You Keep Waking Up At 4AM",
		"description": "Hello, my loves.\n\nThis one is for you.", "premise": "unused",
		"tags": ["tarot", "4am", "timeless reading"],
		"spread": {"name": "Two", "positions": [{"name": "Past", "asks": ""}, {"name": "Future", "asks": ""}]}})
	ep.write_json("draw", {"cards": [{"name": "The Tower", "reversed": true}, {"name": "The Star", "reversed": false}]})
	ep.write_text("script", "<!-- table: shuffle -->\n\nHello my loves welcome back.\n\n<!-- table: draw 1 -->\n\n"
		+ "The Tower is here.\n\n<!-- table: draw 2 -->\n\nThen the Star.\n\n<!-- table: spread -->\n\nThat is the spread.\n")
	var words: Array = []
	var at := {0: 1.0, 5: 70.0, 9: 130.0, 12: 3700.0}
	var t := 1.0
	var i := 0
	for w in "Hello my loves welcome back The Tower is here Then the Star That is the spread".split(" "):
		t = float(at.get(i, t))
		words.append({"text": w, "t0": t, "t1": t + 0.4})
		t += 0.5
		i += 1
	var take := ProjectSettings.globalize_path(ROOT + "_files/take_1.wav")
	var side := FileAccess.open(take.get_basename() + ".json", FileAccess.WRITE)
	side.store_string(JSON.stringify({"words": words, "bookend": {"in": 0.0, "out": 9.0}}))
	side.close()
	# ...and one with no outro after its last word: the close starts under ten seconds from its end
	var cut := ProjectSettings.globalize_path(ROOT + "_files/take_cut.wav")
	side = FileAccess.open(cut.get_basename() + ".json", FileAccess.WRITE)
	side.store_string(JSON.stringify({"words": words}))
	side.close()

	var bare: Dictionary = ep.upload_notes()
	_ok(bare["title"] == "Why You Keep Waking Up At 4AM" and bare["description"] == "Hello, my loves.\n\nThis one is for you."
		and Array(bare["tags"]) == ["tarot", "4am", "timeless reading"] and (bare["chapters"] as PackedStringArray).is_empty(),
		"the upload notes are the plan's title, description and tags; no take, no chapters")
	var n: Dictionary = ep.upload_notes(take)
	var ch: PackedStringArray = n["chapters"]
	_ok(ch.size() == 4 and ch[0] == "0:00 Intro", "a chapter per card and the spread, from 0:00 (%s)" % str(ch))
	if ch.size() == 4:
		_ok(ch[1].ends_with(" Past - The Tower (reversed)") and ch[1].begins_with("1:0"), "a card's chapter names its position and how it fell (%s)" % ch[1])
		_ok(ch[2].ends_with(" Future - The Star") and ch[2].begins_with("2:0"), "in the order drawn (%s)" % ch[2])
		_ok(RegEx.create_from_string("^1:0\\d:\\d\\d The close$").search(ch[3]) != null, "an hour on it reads h:mm:ss, the close by no card word (%s)" % ch[3])
	_ok((ep.upload_notes(cut)["chapters"] as PackedStringArray).size() == 3, "a close under ten seconds from the take's end goes (%s)"
		% str(ep.upload_notes(cut)["chapters"]))
	_ok(_named_chapters(), "the reader's chapters")
	_ok(TableEpisode.chapter_clock(0) == "0:00" and TableEpisode.chapter_clock(65) == "1:05"
		and TableEpisode.chapter_clock(3725) == "1:02:05", "chapter clocks read as YouTube reads them")
	ep.write_json("plan", {"episode_title": "T", "description": "", "premise": "The premise."})
	_ok(ep.upload_notes()["description"] == "The premise.", "no description: the premise stands in")
	ep.write_json("plan", {"episode_title": "Why You Keep Waking Up At 4AM", "description": "Hello.",
		"tags": ["tarot", "Truthful Tarot", "4am"],
		"spread": {"name": "Two", "positions": [{"name": "Past", "asks": ""}, {"name": "Future", "asks": ""}]}})
	_ok(ep.write_upload_notes(take, PackedStringArray(["Truthful Tarot", "satire"])) == "", "upload.md is written")
	var md := ep.read_text("upload")
	_ok(md.begins_with("# Why You Keep Waking Up At 4AM\n\nHello.\n\nChapters\n0:00 Intro\n"), "upload.md: title, description, chapters")
	_ok(md.contains("\nTags: Truthful Tarot, satire\n"), "its tags are the show's, as they go up")
	_ok(ep.write_upload_notes(ProjectSettings.globalize_path(ROOT + "_files/no_take.wav")) != "", "no take's sidecar, no notes")
	_ok(ep.uploads().is_empty(), "an episode never uploaded has no uploads")
	YouTube.record_upload(ep.file_of("youtube"), {"id": "v1", "url": "https://youtu.be/v1"})
	_ok(ep.uploads().size() == 1 and ep.file_of("youtube").ends_with("/youtube.json"), "its uploads are recorded in its folder")
	return true


func _menu() -> bool:
	var ex = load("res://src/export/exporter.gd").new()
	ex._build_ui()            # not added to the tree: its _ready would clear a live render's override.cfg
	var menu: PopupMenu = ex._quality_menu
	ex.upload_provider = func(_take: String) -> Dictionary: return {"title": "An Episode"}
	ex._label_qualities()
	var said: Array = []
	for i in menu.item_count:
		said.append(menu.get_item_text(i))
	_ok(not said.any(func(t: String) -> bool: return t.contains("YouTube") or t.contains("Google")),
		"the export menu says nothing of YouTube, whatever the mode describes (%s)" % str(said))
	if Deps.has("ffmpeg"):
		ex.take_provider = func() -> String: return ""
		ex.upload_provider = func(_take: String) -> Dictionary: return {"refused": "The title names %seed%."}
		ex._on_export()
		_ok(ex._status.text.begins_with("⚠  The title names %seed%.") and not ex._quality_menu.visible and not ex._dialog.visible,
			"an upload whose title cannot be made is refused at the click, saying why, before anything is asked (%s)" % ex._status.text)
	ex.free()
	return true


func _card() -> bool:
	var ex = load("res://src/export/exporter.gd").new()
	ex._build_ui()
	var card = load("res://src/export/youtube_card.gd").new()
	card.exporter = ex
	var cap: Dictionary = card.capture()
	_ok(cap == {"upload": false, "title": "%title%: %episode%", "privacy": "private", "category": "22", "playlist": "",
		"playlist_title": "", "channel": "", "channel_name": "", "client": "", "write_tags": false, "description": "",
		"thumbnail": "youtube", "thumbnail_writer": "claude", "thumbnail_writer_model": "", "thumbnail_writer_effort": "",
		"thumbnail_painter": "codex", "thumbnail_painter_model": "", "thumbnail_painter_effort": "", "thumbnail_match": true},
		"a new card uploads nothing, privately, as People & Blogs, titled by the template, to no channel yet, with YouTube's thumbnail - matched to the video's pictures once painted (%s)" % str(cap))
	var names = _names({"title": "Truthful Tarot", "episode": "The Tower", "author": "Pen", "book": "Major Arcana"})
	_ok(not names.shows_field("title") and not names.shows_field("episode") and not names.shows_field("author")
		and not names.shows_field("book"), "a Voice lab's Script card shows no Title, Episode, Author or Book of its own")
	card.name_from(names)
	_ok(names.shows_field("title") and names.shows_field("episode") and names.shows_field("author") and names.shows_field("book")
		and card.values_now() == {"title": "Truthful Tarot", "episode": "The Tower", "author": "Pen", "book": "Major Arcana"},
		"bound, the card shows all four on it and reads the note's names from there (%s)" % str(card.values_now()))
	_ok(card.meta({"tags": ["a"]}).is_empty(), "unticked, it describes no upload whatever the panel has")
	var block := {"upload": true, "title": "%title% - %episode% (%date%)", "privacy": "unlisted", "category": "27",
		"playlist": "PL1", "playlist_title": "Readings", "channel": "UC-x", "channel_name": "@x", "client": "a1b2c3d4e5f6", "write_tags": true,
		"description": "Line one.\n\nLine two.", "thumbnail": "painted", "thumbnail_writer": "claude",
		"thumbnail_writer_model": "m1", "thumbnail_writer_effort": "high", "thumbnail_painter": "grok",
		"thumbnail_painter_model": "", "thumbnail_painter_effort": "", "thumbnail_match": false}
	card.apply(block)
	_ok(card.capture() == block, "its block round-trips, the description's lines and all (%s)" % str(card.capture()))
	card.apply(block.merged({"thumbnail": "youtube"}, true))
	_ok(not card._desc.visible and card.description().is_empty() and card.meta({"tags": [], "description": "Theirs."}).get("description") == "Theirs.",
		"control: its description box is hidden until the panel shows it, and then nothing of it goes up")
	card.describe()
	_ok(card._desc.visible and card.meta({"tags": [], "description": "Theirs."}).get("description") == "Line one.\n\nLine two.\n\nTheirs."
		and card.meta({"tags": []}).get("description") == "Line one.\n\nLine two.",
		"shown, what is written there goes up first, then the panel's (%s)" % str(card.meta({"tags": [], "description": "Theirs."}).get("description")))
	card.apply({"upload": true, "title": "%title% - %episode% (%date%)", "privacy": "unlisted", "category": "27",
		"playlist": "PL1", "playlist_title": "Readings", "channel": "UC-x", "channel_name": "@x", "write_tags": true})
	var m: Dictionary = card.meta({"tags": ["a"], "record": "r.json"})
	_ok(m.get("title") == "Truthful Tarot - The Tower (%s)" % Time.get_date_string_from_system() and m.get("privacy") == "unlisted"
		and m.get("category") == "27" and YouTube.video_body(m)["snippet"]["categoryId"] == "27"
		and m.get("playlist") == "PL1" and m.get("playlist_title") == "Readings" and m.get("tags") == ["a"]
		and m.get("channel") == "UC-x" and m.get("channel_name") == "@x" and m.get("record") == "r.json",
		"ticked, it lays its title, privacy, category, playlist and channel over the panel's part (%s)" % str(m))
	_ok(card.meta({}).is_empty(), "...and describes nothing when the panel has nothing")
	card._title.text = "%book% %episode% by %author%"
	card.refresh()
	_ok(card.why_not().is_empty() and card.title_now() == "Major Arcana The Tower by Pen"
		and card._title.tooltip_text.contains("%author%") and card._title.tooltip_text.contains("%book%"),
		"%%author%% and %%book%% are the Script card's Author and Book, and the tooltip names them (%s)" % card.title_now())
	_ok(card.meta({"tags": [], "values": {"title": "Show", "episode": "Rendered One", "seed": "7"}}).get("title")
		== "Major Arcana Rendered One by Pen",
		"an export's own values are laid over the note's: its episode, the note's author and book")
	names.doc._fields["author"] = ""
	_ok(card.why_not().is_empty() and card.title_now().begins_with("Major Arcana The Tower"),
		"an empty Author is filled, and nothing is refused (%s)" % card.title_now())
	names.doc._fields["author"] = "Pen"
	card.apply({"upload": true, "title": "%title% - %episode% (%date%)", "privacy": "unlisted", "category": "27",
		"playlist": "PL1", "playlist_title": "Readings", "channel": "UC-x", "channel_name": "@x", "write_tags": true})
	_ok(card.meta({"values": {"title": "Show", "episode": "Rendered One"}}).get("title").begins_with("Show - Rendered One")
		and not card.meta({"values": {"title": "S"}}).has("values"),
		"the values a panel hands with its part (the episode an export rendered) win, and do not go up")
	# what it claims is what the note fills
	card._title.text = "%title% #%seed%"
	card.refresh()
	_ok(card.why_not().contains("%seed%") and card.meta({"tags": []}).has("refused") and not card.meta({"tags": []}).has("title")
		and card._preview.text.begins_with("⚠  The title names %seed%"),
		"a title naming %%seed%% on a note with no episodes is said under it and does not go up (%s)" % card._preview.text)
	_ok(card._title.tooltip_text.contains("%title%") and card._title.tooltip_text.contains("%episode%")
		and card._title.tooltip_text.contains("%date%") and not card._title.tooltip_text.contains("%seed%"),
		"the title's tooltip names only the macros the note fills (%s)" % card._title.tooltip_text)
	# the tooltip stays wrapped: Boot folds it on hover, and the card's refresh must not unfold it
	var folded: String = load("res://src/platform/boot.gd").wrap_tip(card._title.tooltip_text)
	card._title.tooltip_text = folded
	card.refresh()
	card.refresh()
	_ok(folded.contains("\n") and card._title.tooltip_text == folded,
		"folded on hover, the title's tooltip stays folded through the card's refresh (%d lines)" % folded.count("\n"))
	card.values = func() -> Dictionary: return {"seed": "7"}
	card.refresh()
	_ok(card.why_not().is_empty() and card.meta({"tags": []}).get("title") == "Truthful Tarot #7" and card._title.tooltip_text.contains("%seed%")
		and card._title.tooltip_text != folded,
		"control: a panel that adds the seed fills it, the same title goes up, and the tooltip is made again")
	card.values = Callable()
	card._title.text = YouTube.TITLE_TEMPLATE
	names.doc._fields["episode"] = ""
	_ok(card.title_now() == "Truthful Tarot", "an empty Episode leaves the Title alone (%s)" % card.title_now())
	var unbound = load("res://src/export/youtube_card.gd").new()
	unbound.apply({"upload": true})
	_ok(unbound.values_now().is_empty() and unbound.meta({"tags": []}).has("refused") and unbound._preview.text.begins_with("⚠"),
		"control: a card no panel bound fills nothing, says so, and nothing goes up")
	unbound.free()
	_ok(YouTube.unfilled("%title%: %episode% (%date%)", {"title": "", "episode": ""}).is_empty()
		and Array(YouTube.unfilled("%title% #%seed% %what%", {"title": "T"})) == ["seed"],
		"a value filled empty is filled, the date always is, and an unknown macro is no claim")
	_ok(card._playlist.get_item_text(card._playlist.selected) == "Readings", "the block's playlist is shown before the list is loaded")
	card.apply({"privacy": "everyone"})
	_ok(card.capture()["privacy"] == "private", "a privacy YouTube does not know reads as private")
	_ok(card.capture()["category"] == "22", "and a block that names no category is People & Blogs, as every upload was")
	card.apply({"category": "30"})
	_ok(card.capture()["category"] == "22", "the control: a category an upload cannot take (Movies) reads as People & Blogs")
	# the title's macros
	var v := {"title": "Truthful Tarot", "episode": "The Tower"}
	_ok(YouTube.expand_title("%title%: %episode%", v) == "Truthful Tarot: The Tower", "the default template")
	_ok(YouTube.expand_title("%title%: %episode%", {"title": "A Note"}) == "A Note", "no episode leaves nothing dangling")
	_ok(YouTube.expand_title("%title%: %episode%", {"episode": "Bare"}) == "Bare", "no title neither")
	_ok(YouTube.expand_title("%title%: %episode%", {"title": "Truthful Tarot", "episode": "truthful tarot: Named"})
		== "truthful tarot: Named", "a name is never said twice")
	_ok(YouTube.expand_title("%title% - %episode% - %date%", {"title": "T", "date": "D"}) == "T - D",
		"a gap in the middle closes up (%s)" % YouTube.expand_title("%title% - %episode% - %date%", {"title": "T", "date": "D"}))
	_ok(YouTube.expand_title("%title% #%seed% %what%", {"title": "T", "seed": "7"}) == "T #7 %what%", "an unknown macro is left as written")
	# the line an episode's title goes up in, shown to whoever names the episode
	_ok(YouTube.title_shape("%title%: %episode%", {"title": "Truthful Tarot"}, "[x]") == "Truthful Tarot: [x]", "the default template's line")
	_ok(YouTube.title_shape("%episode% | %title% #%seed% (%date%)", {"title": "T", "seed": "7"}, "[x]") == "[x] | T #7 ([date])",
		"every macro in its place, the date marked (%s)" % YouTube.title_shape("%episode% | %title% #%seed% (%date%)", {"title": "T", "seed": "7"}, "[x]"))
	_ok(YouTube.title_shape("%title%: %episode%", {}, "[x]") == "" and YouTube.title_shape("%title% #%seed%", {"title": "T", "seed": "7"}, "[x]") == "",
		"control: no line when the episode's title stands alone, or is left out")
	# the channel and the account rows
	_no_clients()
	card.apply({})
	card._seen = []
	card._refresh_account()
	_ok(card._client.text == "Import client…" and not card._sign.visible and not card._remove.visible
		and card.capture()["channel"] == "" and _chips(card).is_empty() and card._add.get_parent() == card._chips,
		"with no client and no channel, it offers to import a client, and + alone")
	_ok(card._clients.disabled and card._clients.get_item_text(0) == "None yet" and not card._client_del.visible, "the list has nothing to pick")
	YouTube.import_client(_file("card_client.json", _client_json()))
	YouTube._keep({"id": "UC-arc", "handle": "@the-arc", "title": "The Arc"}, YouTube.client(), {"refresh_token": "rt"},
		YouTube.SCOPE + " " + YouTube.READ_SCOPE)
	YouTube._keep({"id": "UC-ink", "handle": "@the-ink", "title": "The Ink"}, YouTube.client(), {"refresh_token": "rt2"},
		YouTube.SCOPE + " " + YouTube.PLAYLIST_SCOPE)
	card.apply({"upload": true, "playlist": "PL1", "playlist_title": "Readings"})
	_ok(card.capture()["channel"] == "UC-arc" and card.capture()["channel_name"] == "@the-arc",
		"a block that names no channel takes the first one kept (%s)" % card.capture()["channel"])
	card._seen = []
	card._refresh_account()
	_ok(_chips(card).map(func(b: Button) -> String: return b.text) == ["@the-arc", "@the-ink"] and _pressed(card) == "@the-arc"
		and card._chips.get_child(card._chips.get_child_count() - 1) == card._add,
		"a toggle per channel, named as YouTube names it, the note's pressed, + last")
	_ok(card._client.text == "Import another…" and card._account.text.contains("through ghost-check") and card._account.text.contains("@the-arc") and card._account.text.contains("uploads only")
		and card._remove.visible and not card._sign.visible, "signed in, it says where uploads go and what the sign-in may do (%s)" % card._account.text)
	var ink: Button = _chips(card)[1]
	ink.pressed.emit()
	_ok(card.capture()["channel"] == "UC-ink" and card.capture()["channel_name"] == "@the-ink" and card.capture()["playlist"] == ""
		and card.meta({"tags": []}).get("channel") == "UC-ink",
		"another channel's toggle makes it the note's, and clears the playlist - the other channel's")
	card._seen = []
	card._refresh_account()
	_ok(_pressed(card) == "@the-ink" and card._account.text.contains("playlists too"), "the rows speak for the channel picked")
	_ok(YouTube.granted(YouTube.PLAYLIST_SCOPE, "UC-ink") and not YouTube.granted(YouTube.PLAYLIST_SCOPE, "UC-arc"),
		"one channel may see playlists while the other may only upload")
	_ok(ex.scopes_for({"playlist": "PL1"}) == [YouTube.SCOPE, YouTube.PLAYLIST_SCOPE] and ex.scopes_for({}) == [YouTube.SCOPE],
		"an upload joining a playlist asks for the playlists' scope, one without asks for uploads alone")
	# the client is picked from those kept
	var own_key := YouTube.client_key("123-abc.apps.googleusercontent.com")
	var other_id := "456-def.apps.googleusercontent.com"
	var other_key := YouTube.client_key(other_id)
	YouTube.import_client(_file("card_other.json", _client_json(other_id, "installed", {"project_id": "other-project"})))
	card.apply({"upload": true, "channel": "UC-ink", "channel_name": "@the-ink"})
	card._seen = []
	card._refresh_account()
	_ok(card._clients.item_count == 2 and card._clients.get_item_text(0) == "ghost-check (@the-arc, @the-ink)"
		and card._clients.get_item_text(1) == "other-project" and not card._clients.disabled,
		"the list holds each client by its project and channels (%s)" % card._clients.get_item_text(0))
	_ok(card._clients.selected == 0 and card.capture()["client"] == "" and card.meta({"tags": []}).get("client") == own_key
		and not card._client_del.visible and not card._sign.visible,
		"it shows the channel's own, though another was imported since; the block picks nothing, and one a channel holds cannot be forgotten")
	card._clients.select(1)
	card._on_client_picked(1)
	_ok(card.capture()["client"] == other_key and not str(card.capture()).contains(other_id) and card.meta({"tags": []}).get("client") == other_key,
		"another picked is kept in the block by its key, never its id, and an upload's sign-in would go through it")
	_ok(YouTube.signed_in("UC-ink") and YouTube.channel_client("UC-ink") == own_key and card._sign.visible and card._sign.text == "Sign in again"
		and card._account.text.contains("through ghost-check") and card._account.text.contains("moves it to other-project") and card._client_del.visible,
		"the channel stays signed in as it was, and the card offers to sign in again (%s)" % card._account.text)
	card.apply(card.capture())
	card._seen = []
	card._refresh_account()
	_ok(card._clients.selected == 1, "the pick comes back with the block")
	card._clients.select(0)
	card._on_client_picked(0)
	_ok(card.capture()["client"] == "" and not card._sign.visible, "the channel's own picked again is no pick at all")
	card._clients.select(1)
	card._on_client_picked(1)
	(_chips(card)[0] as Button).pressed.emit()
	card._seen = []
	card._refresh_account()
	_ok(card.capture()["client"] == "" and card.capture()["channel"] == "UC-arc" and card._clients.selected == 0,
		"another channel's toggle clears the pick: the row follows that channel's own")
	card.apply({"upload": true, "channel": "UC-ink", "client": "not-here"})
	card._seen = []
	card._refresh_account()
	_ok(card._clients.selected == 0 and card.capture()["client"] == "not-here" and card.meta({"tags": []}).get("client") == own_key and not card._sign.visible,
		"a pick not kept here shows the channel's own, and the block keeps it for the machine that has it")
	card.apply({"channel": "UC-ink", "client": other_key})
	card._seen = []
	card._refresh_account()
	card._forget_client()
	_ok(YouTube.client(other_key).has("error") and card.capture()["client"] == "" and card._clients.item_count == 1 and card._clients.selected == 0,
		"✕ forgets the client shown, and the row goes back to the channel's own")
	# a channel not signed in here: a note from another machine, or one whose channel was removed
	card.apply({"channel": "UC-gone", "channel_name": "@gone"})
	card._seen = []
	card._refresh_account()
	var gone: Button = _chips(card).back() if not _chips(card).is_empty() else null
	_ok(gone != null and gone.text == "@gone" and gone.button_pressed and gone.modulate.a < 1.0 and _chips(card).size() == 3
		and card.capture()["channel"] == "UC-gone" and card.capture()["channel_name"] == "@gone",
		"the block's channel, not signed in here, shows dimmed and pressed, its name kept")
	_ok(card._sign.visible and card._sign.text == "Sign in" and not card._remove.visible and card._account.text.contains("not signed in here"),
		"it offers to sign in, and nothing to remove (%s)" % card._account.text)
	YouTube._drop_sign_in("UC-arc")
	card.apply({"channel": "UC-arc"})
	card._seen = []
	card._refresh_account()
	_ok(card._account.text.contains("lapsed") and card._sign.visible and card._remove.visible and _chips(card)[0].modulate.a < 1.0,
		"a lapsed sign-in keeps its channel: dimmed, to sign in again or remove (%s)" % card._account.text)
	var video := _file("card.mp4", "abc")
	YouTube.queue(video, {}, "UC-ink")
	card._seen = []
	card._refresh_account()
	_ok(card._resume.visible and card._resume.text.ends_with("card.mp4 to @the-ink"), "a waiting upload can be resumed, to its channel (%s)" % card._resume.text)
	DirAccess.remove_absolute(video)
	card._seen = []
	card._refresh_account()
	_ok(not card._resume.visible, "not once its file is gone")
	YouTube.forget_pending()
	YouTube.forget_channel("UC-arc")
	YouTube.forget_channel("UC-ink")
	_no_clients()
	card.free()
	names.free()
	ex.free()
	return true


## A note read as it is written is its own episode.
func _note_steps() -> bool:
	var keep: String = load("res://src/reading/note_upload.gd").root
	load("res://src/reading/note_upload.gd").root = ROOT + "_readings"
	var ed = load("res://src/reading/reading_panel.gd").new()
	ed.workspace = "reading"
	ed._build_panel()
	ed._doc._sync = false
	ed._doc._fields = {"title": "A Reading", "tags": "readings, voice"}
	ed.note_path = ROOT + "_files/A Reading.md"
	ed._text.text = "The quick brown fox <!-- a mark --> jumps over the lazy dog."
	ed.publish = _own_publish()
	var hid: bool = not ed._writer.shows_field("episode")
	ed._attach("youtube")
	_ok(hid and ed._writer.shows_field("episode") and ed._writer.shows_field("title"),
		"its Script card shows the Episode once it has a YouTube card (the control: not before)")
	var up = ed._note_upload
	_ok(up != null and ed._youtube._desc.visible and _tag_fields(ed._youtube) == 1,
		"on the YouTube card: a description box, and the note's tags as one list")
	ed._youtube._upload.set_pressed_no_signal(true)
	ed._youtube._desc.text = "What this video is.\n\nA second paragraph."
	var m: Dictionary = ed.upload_meta("")
	_ok(m.get("description") == "What this video is.\n\nA second paragraph.\n\nA likeness of Someone, said."
		and m.get("tags") == ["readings", "voice", "theirs"] and m.get("title") == "A Reading",
		"the upload goes with the description written there, then the component's, and the note's tags with its own (%s)" % str(m))
	_ok(ed.export_name() == "A Reading", "its export is named after the note's Title (%s), never the exporter's own" % ed.export_name())
	ed._doc._fields["episode"] = "Part One"
	_ok(ed.upload_meta("").get("title") == "A Reading: Part One", "its Episode, on the Script card, is the %episode% it goes up with")
	_ok(ed.export_name() == "Part One", "...and names the export, as a show's episode does (%s)" % ed.export_name())
	ed._doc._fields.erase("episode")
	ed._doc._fields.erase("title")
	_ok(ed.export_name() == "", "control: a note with no Title, kept in no file, leaves the exporter its own name")
	ed._doc._fields["title"] = "A Reading"
	ed._doc._fields["episode"] = "Part One"
	ed._youtube._title.text = "%title% #%seed%"
	_ok(ed.upload_meta("").has("refused") and ed._youtube.why_not().contains("%seed%"),
		"control: %seed%, which a note read as it is written does not have, stops the upload, saying why")
	ed._youtube._title.text = YouTube.TITLE_TEMPLATE
	ed._doc._fields.erase("episode")
	var said: String = load("res://src/likeness/actor_card.gd").disclosure("Someone", "gaussian")
	var bent: String = load("res://src/likeness/actor_card.gd").disclosure("Someone", "2d")
	_ok(said.contains("Gaussian splats") and not said.contains("pixel") and bent.contains("Every pixel of them is a real one"),
		"an actor's upload says how they were made: splats for Gaussian, their own pixels bent for 2D (control)")
	# the tags step, listed here with the note as its episode
	var step = ed._youtube.episode_steps()[0]
	var pipe = ed.pipeline()
	up.refresh()
	pipe.refresh()
	_ok(step.shown == null and pipe.row(step.key).is_empty(), "control: with the box clear, the step is not listed")
	_ok(ed.episode_feed() == up.feed() and ed._youtube._write_tags.text == "Write the note's tags",
		"no card shows another episode: the note is its own, and the box says the note's tags")
	ed._youtube._write_tags.button_pressed = true
	up.refresh()
	pipe.refresh()
	var folder: String = up._feed.folder()
	_ok(step.shown == up._feed and not pipe.row(step.key, "YouTube").is_empty()
		and folder.begins_with(ProjectSettings.globalize_path(ROOT + "_readings")) and folder.get_file().begins_with("a-reading-"),
		"ticked, it is on the Pipeline card, the note its episode, kept in the note's own folder (%s)" % folder.get_file())
	_ok(up._feed.words() == "The quick brown fox  jumps over the lazy dog." and up._feed.episode_title() == "A Reading"
		and up._feed.description().begins_with("What this video is.") and Array(up._feed.tags()) == ["readings", "voice"]
		and up._feed.writer()["agent"] == "codex",
		"the step reads the note's words with the marks out, the title as it goes up, the description, the tags and the component's writer")
	ed._youtube._refresh_tags()
	_ok(ed._youtube._tags_note.text.ends_with("and so does Generate, or an export that goes up."),
		"the card says Generate and an export that goes up write them (%s)" % ed._youtube._tags_note.text)
	ed._youtube._upload.set_pressed_no_signal(false)
	up.start()
	_ok(step.state(up._feed) == "missing", "control: an export that does not go up starts nothing")
	ed._youtube._upload.set_pressed_no_signal(true)
	up.start()
	up.refresh()
	pipe.refresh()
	var r: Dictionary = pipe.row(step.key)
	_ok(step.state(up._feed) == "failed" and not up._steps.busy_on(up._feed) and (r["text"] as Label).text.contains("read-only"),
		"one that goes up starts it - here refused, read-only, and said on its row (%s)" % (r["text"] as Label).text)
	step._errors.clear()
	AgentJobs._ended["text-youtube-check-note"] = {"ok": true, "text": "{\"tags\": [\"quick brown fox\", \"lazy dog\", \"fable\"]}"}
	step._jobs[folder] = {"id": "text-youtube-check-note", "feed": up._feed, "stamp": up._feed.stamp()}
	_ok(up._steps.busy_on(up._feed), "while its job runs, an export waits for it")
	up.refresh()
	pipe.refresh()
	r = pipe.row(step.key)
	_ok(not up._steps.busy_on(up._feed) and (r["glyph"] as Label).text == "✓" and (r["text"] as Label).text == "3 tags: quick brown fox, lazy dog, fable" and not (r["redo"] as Button).disabled,
		"landed: its ✓, its tags, its ⟳ (%s)" % (r["text"] as Label).text)
	_ok(ed._doc.field("tags") == "quick brown fox, lazy dog, fable" and Array(up._tags_field.get_tags()) == ["quick brown fox", "lazy dog", "fable"]
		and ed.upload_meta("").get("tags") == ["quick brown fox", "lazy dog", "fable", "theirs"],
		"they replace the note's tags: on the card, and going up (%s)" % ed._doc.field("tags"))
	ed._text.text = "Words written again."
	up.refresh()
	pipe.refresh()
	_ok(step.state(up._feed) == "missing" and (pipe.row(step.key)["text"] as Label).text.contains("written again"),
		"words written again make them stale: the next export that goes up writes new ones")
	# its own pictures, for a thumbnail painted in their look
	var painted := _file("pictures/harbor.png", "")
	Image.create(8, 8, false, Image.FORMAT_RGB8).save_png(painted)
	ed._text.text = "Words. <!-- image: A harbor at dawn. --> More. <!-- image: A storm not yet painted. --> <!-- image: A harbor at dawn. -->"
	Illustrations.use_for_test({"index": {Manuscript.image_key("A harbor at dawn."): {"versions": [{"file": painted, "sig": ""}], "current": 0}}}, true)
	# as its presentation shows them (the Pictures card's list, Medium.pictures_of): a novel prints them
	var pin := RefCounted.new()
	root.get_node("Director").pin_medium("book", pin)
	_ok(Array(up._feed.pictures()) == [painted], "the note hands the step its painted pictures, each once - one not painted, none (%s)" % str(up._feed.pictures()))
	root.get_node("Director").pin_medium("full", pin)
	_ok(up._feed.pictures().is_empty(), "the control: shown in a medium that shows no pictures, the video has none to hand (%s)" % str(up._feed.pictures()))
	root.get_node("Director").unpin_medium(pin)
	ed.free()
	_wipe(ROOT + "_readings")
	load("res://src/reading/note_upload.gd").root = keep
	return true


## A component's publish with a part of its own in an upload, as an Actor's is - made here, not named: the
## reading's scripts need the autoloads, which are only up by now.
func _own_publish() -> Object:
	var g := GDScript.new()
	g.source_code = "\n".join(PackedStringArray([
		"extends \"res://src/reading/reading_publish.gd\"",
		"func upload_base(_take: String) -> Dictionary:",
		"\treturn {\"tags\": [\"theirs\"], \"description\": \"A likeness of Someone, said.\"}",
		"func writer() -> Dictionary:",
		"\treturn {\"agent\": \"codex\", \"model\": \"\", \"effort\": \"\"}"]))
	g.reload()
	return g.new()


## A Script card of the gate's own, in a Voice lab's mode (no Title or Episode of its own) and kept in no
## file: the note's names are [param fields].
func _names(fields: Dictionary):
	var w = load("res://src/ui/script_writer.gd").new()
	w.setup("youtube_check", PackedStringArray(), "synthesis")
	w.doc._sync = false
	w.doc._fields = fields
	return w


## The Episode card's row of the step another card added, {} for none.
## How many lists of tags [param node] shows, itself and all under it.
func _tag_fields(node: Node) -> int:
	var n := 1 if node.get_script() == load("res://src/ui/tag_field.gd") else 0
	for c in node.get_children():
		n += _tag_fields(c)
	return n


## An episode as a step reads it, made up: its folder under the scratch folder, its words as set, and
## the note's tags it keeps - or why it cannot ([member refuse]).
class FakeFeed extends "res://src/notes/episode_feed.gd":
	var dir := ""
	var said := ""
	var note_tags := PackedStringArray()
	var refuse := ""
	var pics := PackedStringArray()

	func pictures() -> PackedStringArray:
		return pics

	func replace_tags(tags: PackedStringArray) -> String:
		if refuse.is_empty():
			note_tags = tags
		return refuse

	func folder() -> String:
		return dir

	func show_title() -> String:
		return "The Show"

	func episode_title() -> String:
		return "The Tower Falls"

	func words() -> String:
		return said


## A card's channel toggles, in order ("+" left out).
func _chips(card: Node) -> Array:
	return card._chips.get_children().filter(func(c: Node) -> bool: return c != card._add)


## The pressed toggle's text, "" for none.
func _pressed(card: Node) -> String:
	for b in _chips(card):
		if (b as Button).button_pressed:
			return (b as Button).text
	return ""


## Built by hand, as panel_fit_check builds it: its _ready would start the voice host.
func _panel_fields() -> bool:
	# loaded here, not named: the panel's scripts need the autoloads, which are only up by now
	var ed = load("res://src/reading/reading_panel.gd").new()
	ed.workspace = "table"
	ed._build_panel()
	var show = ed._block_cards["table"]      # the episode's card ([EpisodeCard])
	_ok(ed._youtube == null and show._yt_desc == null and ed.upload_meta("").is_empty(),
		"a show with no YouTube card has no description or tags to edit, and uploads nothing")
	ed._panel.plus.about_to_popup.emit()
	var pop: PopupMenu = ed._panel.plus.get_popup()
	# "+" lists what a note can have; on a show of cards the clock and the presentation are taken,
	# so what takes neither is all it can be given - YouTube, Voice training (its reader can be
	# taught someone's voice) and a Direction (where to take the next episode) - and the rest is grayed with its reason
	var at := -1
	var lit: Array = []
	for i in pop.item_count:
		var key := str(pop.get_item_metadata(i))
		if key == "youtube":
			at = i
		if not key.is_empty() and not pop.is_item_disabled(i):
			lit.append(key)
	_ok(at >= 0 and lit == ["direction", "voice_training", "youtube"],
		"its \"+\" offers YouTube, Voice training and a Direction, and nothing that takes the show's clock or presentation (%s)" % str(lit))
	if at >= 0:
		pop.id_pressed.emit(pop.get_item_id(at))
	_ok(ed._youtube != null and show._yt_desc != null and show._yt_desc.get_parent() == ed._youtube.extra,
		"attached, the YouTube card holds the show's description and tags")
	ed._panel.plus.about_to_popup.emit()
	var left: Array = []
	var twice := false
	for i in pop.item_count:
		var key := str(pop.get_item_metadata(i))
		twice = twice or key == "youtube"
		if not key.is_empty() and not pop.is_item_disabled(i):
			left.append(key)
	_ok(not twice and left == ["direction", "voice_training"], "and \"+\" does not offer it twice - Voice training and a Direction are all it can be given now (%s)" % str(left))
	ed._youtube._upload.set_pressed_no_signal(true)
	# not the author's show: a panel comes up synced to whatever document the person running this has open, and
	# DocSource.set_field writes a synced document at once
	ed._doc._sync = false
	ed._doc._fields = {}
	var ep := TableEpisode.open("panel-check", 21)
	ep.write_json("plan", {"episode_title": "The Producer's Title", "description": "The producer's words.",
		"tags": ["tarot", "4am"], "premise": "p", "spread": {"positions": [{"name": "Past"}]}})
	show._knobs["show"] = "panel-check"
	show._knobs["seed"] = 21
	show._open_episode()
	var episode: LineEdit = ed._writer._field_edits["episode"]
	ed._writer._refresh_handed()
	_ok(ed._writer.shows_field("episode") and episode.text == "The Producer's Title" and episode.editable,
		"the Script card's Episode is the picked episode's title")
	_ok(show._yt_desc.text.is_empty() and show._yt_tags.get_tags().is_empty(), "a show with no description or tags shows none yet")
	show._seed_from_plan()
	_ok(show._yt_desc.text == "The producer's words." and Array(show._yt_tags.get_tags()) == ["tarot", "4am"]
		and ed._doc.field("tags") == "tarot, 4am", "...and takes the picked episode's once, as the show's own")
	var before := ep.read_text("plan")
	show._flush_upload_fields()
	_ok(ep.read_text("plan") == before, "nothing is written without an edit")
	episode.text = "  My Own Title  "
	ed._writer._commit_field("episode")
	var plan: Dictionary = ep.read_json("plan")
	_ok(plan["episode_title"] == "My Own Title" and plan["premise"] == "p" and (plan["spread"] as Dictionary).has("positions")
		and episode.text == "My Own Title", "an edited Episode is written into the episode's plan, the rest of it kept")
	show._yt_desc.text = "Mine."
	show._upload_edited()
	_ok(show._yt_dirty > 0.0, "an edit of the description waits a moment before it is kept")
	show._flush_upload_fields(true)
	var doc: Dictionary = ed._doc_capture()["table"]
	_ok(not doc.has("episode_title") and doc.get("description") == "Mine." and not doc.has("youtube"),
		"the block holds the show's description - no episode's title, no record per episode")
	_ok(ed.export_name() == "My Own Title", "and the title names the export")
	episode.text = "   "
	ed._writer._commit_field("episode")
	_ok(String((ep.read_json("plan") as Dictionary)["episode_title"]) == "My Own Title" and episode.text == "My Own Title"
		and ed._writer._note.text.contains("needs a title"), "an emptied Episode is not written, and the card says why")
	show._yt_tags._input.text = "satire, "
	show._yt_tags._on_typed(show._yt_tags._input.text)
	show._yt_tags.remove("4am")
	_ok(ed._doc.field("tags") == "tarot, satire", "the chips write the show's tags line (%s)" % ed._doc.field("tags"))
	var meta: Dictionary = ed.upload_meta("")
	_ok(meta.get("title") == "My Own Title" and meta.get("description") == "Mine." and meta.get("chapters") == []
		and meta.get("tags") == ["tarot", "satire"] and String(meta.get("record", "")).ends_with("/21/youtube.json"),
		"the upload: the episode's title, the show's description and tags")
	_ok(not meta.has("thumbnail_at") and not meta.has("thumbnail") and not meta.has("folder"),
		"and no thumbnail the episode card chose: the YouTube card's is YouTube's, and the folder stays off the wire")
	ed._doc._fields["title"] = "Truthful Tarot"
	_ok(ed.upload_meta("").get("title") == "Truthful Tarot: My Own Title" and ed.export_name() == "My Own Title",
		"the upload's title is the show's name, then the episode's - the file keeps the episode's alone")
	show._refresh_upload_note()
	_ok(ed._youtube._preview.text.begins_with("Goes up as \"Truthful Tarot: My Own Title\""), "the card shows the title as it goes up")
	# the producer is shown that line before it names the next episode
	_ok(show._spec().get("uploads_as") == "Truthful Tarot: [episode_title]", "the producer is not handed the line a title goes up in (%s)" % str(show._spec().get("uploads_as")))
	ed._youtube._title.text = "%episode% | %title% #%seed%"
	_ok(show._spec().get("uploads_as") == "[episode_title] | Truthful Tarot #21", "the line is not the card's own template (%s)" % str(show._spec().get("uploads_as")))
	ed._youtube._title.text = "%title% #%seed%"
	_ok(show._spec().get("uploads_as") == "", "control: a template without the episode's title still made a line")
	ed._youtube._title.text = YouTube.TITLE_TEMPLATE
	_ok(show.upload_title("Truthful Tarot", "truthful tarot: Already Named") == "truthful tarot: Already Named"
		and show.upload_title("", "Bare") == "Bare" and show.upload_title("Show", "") == "Show",
		"no name twice, none when the show has no title, the name alone when the episode has none")
	var long_title: String = YouTube.fit_title(show.upload_title("Truthful Tarot", "word ".repeat(30)))
	_ok(long_title.begins_with("Truthful Tarot: ") and long_title.length() <= 100, "cut to 100 characters, the name stands")
	ed._doc._fields.erase("title")
	_ok(show._spec().get("uploads_as") == "", "control: a show with no name has no line round its episode's title")
	# the byline, on the document card right under Title: shown, with the brief's marks and its name; the card is in the table's
	# mode, never its settings section
	var card = ed._writer
	var edits: Array = card._field_edits.keys()
	_ok(edits.find("byline") == edits.find("title") + 1, "the byline is the card's field right under Title (%s)" % str(edits))
	var marks: GDScript = load("res://src/notes/script_marks.gd")
	_ok(card.shows_field("byline") and card._mode == "table" and marks.for_mode(card._mode).has("speaker")
		and card._wording("window", "") == "Brief" and ed._cast._hesitate.get_parent().visible,
		"it is shown on a table's Script card, which offers a brief's marks and calls it a Brief - and the Voice card its Hesitate row")
	_ok(ed.section() == "cards" and marks.for_mode(ed.section()).is_empty()
		and String((card.WORDING.get(ed.section(), {}) as Dictionary).get("window", "")).is_empty()
		and not (card.FIELDS["byline"]["modes"] as Array).has(ed.section()),
		"the control: the table's settings section names no marks, no wording and no Byline - a card set up in it shows none of them")
	(card._field_edits["byline"] as LineEdit).text = "with Pen & Ink"
	card._commit_field("byline")
	_ok(ed._doc.field("byline") == "with Pen & Ink" and ed.book_document()["byline"] == "with Pen & Ink",
		"it is the show's `byline:`, handed to the title screen")
	# a new episode: the show's values at once
	show._knobs["seed"] = 22
	show._open_episode()
	ed._writer._refresh_handed()
	_ok(show._yt_desc.text == "Mine." and Array(show._yt_tags.get_tags()) == ["tarot", "satire"],
		"a new episode shows the show's description and tags at once")
	_ok(episode.text.is_empty() and not episode.editable and episode.placeholder_text == "named with the episode",
		"its Episode waits for its plan, saying so - never the last episode's")
	var other := TableEpisode.open("panel-check", 23)
	other.write_json("plan", {"episode_title": "Another Episode"})
	var take := ProjectSettings.globalize_path(ROOT + "_files/take_9.wav")
	show._taken = {"take": take, "episode": ep}
	show._knobs["seed"] = 23
	show._open_episode()
	ed._writer._refresh_handed()
	_ok(episode.text == "Another Episode" and not ed._doc_capture()["table"].has("episode_title")
		and show._yt_desc.text == "Mine.", "an episode with a plan shows its own title; the description stays the show's")
	_ok(ed.upload_meta(take).get("title") == "My Own Title" and ed.upload_meta("").get("title") == "Another Episode",
		"an export's upload describes the episode it rendered, not the one picked since")
	_ok(not DirAccess.dir_exists_absolute(TableEpisode.open("panel-check", 22).dir), "nothing was written for the new episode")
	# the steps the note's other cards add: the YouTube card's tags, on the Episode card, neither naming the other
	var tags_step = ed._youtube.episode_steps()[0]
	var pipe = ed.pipeline()
	var youtube_rows = ed._youtube.pipeline()
	_ok(ed._youtube.episode_steps().size() == 2 and pipe.sections().has(youtube_rows),
		"the YouTube card hands the Pipeline card its own section: the tags and the thumbnail")
	pipe.refresh()
	_ok(pipe.row(tags_step.key).is_empty(), "box clear, no tags are listed")
	ed._youtube._write_tags.button_pressed = true
	pipe.refresh()
	var row: Dictionary = pipe.row(tags_step.key, "YouTube")
	var listed: Array = pipe.names()
	_ok(not row.is_empty() and listed.find("Tags") > listed.find("Close") and pipe.row(tags_step.key, "Episode").is_empty(),
		"ticked, its row stands under the Close, in the YouTube section, never the Episode's: %s" % str(listed))
	_ok(tags_step.shown == show._feed and tags_step.shown.folder() == show._episode.dir,
		"the step is told which episode is shown")
	_ok((row["glyph"] as Label).text == "·" and (row["text"] as Label).text == tags_step.waits and (row["redo"] as Button).disabled
		and youtube_rows.missing(), "before the reading is written the row waits, its ⟳ too")
	show._episode.write_text("script", "<!-- table: draw 1 -->\nThe first card is the moon.")
	_ok(show._feed.words() == "The first card is the moon.", "the step reads the reading as it is said, its marks out (%s)" % show._feed.words())
	youtube_rows.make()
	pipe.refresh()
	row = pipe.row(tags_step.key)
	_ok(tags_step.state(show._feed) == "failed" and (row["glyph"] as Label).text == "✗"
		and (row["text"] as Label).text.contains("read-only"),
		"once the words are written, Generate makes it - here refused, read-only, and said on its row")
	tags_step._errors.clear()
	_ok(_tag_fields(ed._youtube) == 1 and ed.upload_meta("").get("tags") == ["tarot", "satire"],
		"the YouTube card shows one list of tags, and it is what goes up")
	AgentJobs._ended["text-youtube-check-cards"] = {"ok": true, "text": "{\"tags\": [\"lunar omens\", \"nocturne\", \"divination\"]}"}
	tags_step._jobs[show._feed.folder()] = {"id": "text-youtube-check-cards", "feed": show._feed, "stamp": show._feed.stamp()}
	pipe.refresh()
	row = pipe.row(tags_step.key)
	_ok((row["glyph"] as Label).text == "✓" and (row["text"] as Label).text == "3 tags: lunar omens, nocturne, divination"
		and not (row["redo"] as Button).disabled and (row["redo"] as Button).tooltip_text == tags_step.again
		and not youtube_rows.missing(), "made: its ✓, its tags and its ⟳ to write them again")
	_ok(ed._doc.field("tags") == "lunar omens, nocturne, divination" and Array(show._yt_tags.get_tags()) == ["lunar omens", "nocturne", "divination"]
		and _tag_fields(ed._youtube) == 1 and ed.upload_meta("").get("tags") == ["lunar omens", "nocturne", "divination"],
		"landed, they replace the show's tags: still one list on the card, and what goes up (%s)" % ed._doc.field("tags"))
	_ok(ed.upload_meta(take).get("tags") == ["lunar omens", "nocturne", "divination"], "an export of another episode goes up with the same list")
	ed._youtube._write_tags.button_pressed = false
	pipe.refresh()
	_ok(pipe.row(tags_step.key).is_empty() and ed.upload_meta("").get("tags") == ["lunar omens", "nocturne", "divination"],
		"box cleared: the row goes, and the list stays as it was written")
	_ok(Openings.title_moment(9.0) == 3.6 and Openings.title_moment(3.0) == 1.5 and Openings.title_moment(0.5) == 1.5,
		"the title screen's frame is taken with the name up and the table still out of focus")
	var args: PackedStringArray = load("res://src/export/exporter.gd").thumbnail_args("/v/a b.mp4", "/v/a b.thumbnail.jpg", 3.6)
	_ok(Array(args) == ["-y", "-nostdin", "-loglevel", "error", "-ss", "3.600", "-i", "/v/a b.mp4", "-frames:v", "1",
		"-vf", "scale=1280:720:flags=lanczos", "-q:v", "2", "/v/a b.thumbnail.jpg"], "one frame, at the moment, 1280x720")
	ed.free()
	return true


## Each episode's own tags: the step the YouTube card adds to the episodes a note makes, and the box.
func _episode_tags() -> bool:
	var Tags: GDScript = load("res://src/export/youtube_tags.gd")
	# the answer, landed
	var got: Variant = Tags.land(TextGen.extract_json("```json\n{\"tags\": [\"#Readings\", \"readings\", \"the tower\", \"a, b\", \" \"]}\n```"))
	_ok(got is Dictionary and (got as Dictionary)["tags"] == ["Readings", "the tower", "a b"],
		"an answer's tags are cleaned - no hashtag sign, no comma inside - each kept once whatever its case (%s)" % str(got))
	_ok(Tags.land(["one", "two", "three"]) is Dictionary, "a bare list is an answer too")
	_ok(Tags.land(null) is String and Tags.land({"tags": "one, two, three"}) is String and Tags.land({"tags": ["one", "#", "two"]}) is String,
		"the controls: no JSON, no list, and too few usable tags are not kept")
	var already := "The Show\nThe Tower Falls\nA reading of three cards, and what they say."
	var trimmed: Variant = Tags.land({"tags": ["The Tower Falls", "falls tower", "the show", "three cards", "tower card",
		"tarot spread", "fortune telling", "major arcana"]}, already)
	_ok(trimmed is Dictionary and (trimmed as Dictionary)["tags"] == ["tower card", "tarot spread", "fortune telling", "major arcana"]
		and (trimmed as Dictionary)["said"] == ["The Tower Falls", "falls tower", "the show", "three cards"]
		and Tags.new().summary(trimmed).ends_with("left out, as the title or description says them: The Tower Falls, falls tower, the show, three cards"),
		"a tag whose every word the show's name, the title or the description says is left out, and said; one with a word of its own is kept (%s)" % str(trimmed))
	var few: Variant = Tags.land({"tags": ["the tower", "three cards", "major arcana"]}, already)
	_ok(few is String and String(few).contains("2 more only said what the title or description says")
		and Tags.land({"tags": ["the tower", "three cards", "major arcana"]}) is Dictionary,
		"left with too few, the answer is refused saying why - and with nothing said already, all three are tags (%s)" % str(few))
	# what the writer is told
	Rules.clear()
	var p: Dictionary = Tags.prompt("The Show", "The Tower Falls", "A reading of three.", PackedStringArray(["readings", "cards"]),
		"The first card is the tower.")
	var text := String(p["prompt"])
	_ok(Rules.missing.is_empty() and not text.contains("{{") and not String(p["system"]).is_empty()
		and text.contains("The first card is the tower.") and text.contains("THIS VIDEO'S TITLE: The Tower Falls")
		and text.contains("ITS DESCRIPTION: A reading of three.") and text.contains("readings, cards")
		and text.contains("THE SHOW'S TAGS NOW, which yours replace: readings, cards") and text.contains(str(YouTube.TAGS_MAX))
		and text.contains("YouTube searches them already"),
		"the writer is told the show, the episode's title, description and words, the note's tags (which its answer replaces), YouTube's limit and to leave out what they say already (%s)" % str(Rules.missing))
	var bare := String(Tags.prompt("", "", "", PackedStringArray(), "Words.")["prompt"])
	_ok(not bare.contains("THE SHOW:") and not bare.contains("TAGS NOW") and not bare.contains("DESCRIPTION") and bare.contains("Words."),
		"the control: what an episode does not have is not said")
	# the step
	var on := [false]
	var step = Tags.new(func() -> bool: return bool(on[0]))
	var feed := FakeFeed.new()
	feed.dir = ProjectSettings.globalize_path(ROOT + "_files").path_join("episode_1")
	feed.note_tags = PackedStringArray(["the note's"])
	_ok(not step.wanted() and EpisodeStep.listed_of([step]).is_empty(), "with the box clear, the step is not one")
	on[0] = true
	_ok(step.wanted() and EpisodeStep.listed_of([step, "not a step"]) == [step], "ticked, it is listed (and nothing that is not a step)")
	_ok(step.state(feed) == "missing" and step.said(feed) == step.waits and not step.generate(feed) and not step.redo(feed),
		"before the episode's words are written it waits for them, and neither Generate nor ⟳ starts it")
	feed.said = "The first card is the tower."
	_ok(step.generate(feed) and step.state(feed) == "failed" and step.said(feed).contains("read-only"),
		"once they are, Generate starts it - in a read-only gate it stops, saying why (%s)" % step.said(feed))
	step._errors.clear()
	# control: a note that cannot keep tags - the answer is not landed, and the step says why
	feed.refuse = "the note is gone"
	AgentJobs._ended["text-youtube-check-0"] = {"ok": true, "text": "{\"tags\": [\"tarot\", \"cards\", \"readings\"]}"}
	step._jobs[feed.folder()] = {"id": "text-youtube-check-0", "feed": feed, "stamp": feed.stamp()}
	step._tries[feed.folder()] = 2
	step.tick()
	_ok(step.state(feed) == "failed" and step.said(feed) == "the note is gone" and Array(feed.note_tags) == ["the note's"]
		and not FileAccess.file_exists(feed.folder().path_join("youtube_tags.json")),
		"the control: a note that cannot keep them fails the step, saying why, and nothing is kept (%s)" % step.said(feed))
	step._errors.clear()
	step._tries.clear()
	feed.refuse = ""
	AgentJobs._ended["text-youtube-check-1"] = {"ok": true, "text": "{\"tags\": [\"the tower\", \"tarot\", \"cards\", \"readings\", \"fortune\"]}"}
	step._jobs[feed.folder()] = {"id": "text-youtube-check-1", "feed": feed, "stamp": feed.stamp()}
	_ok(step.busy(feed) and step.state(feed) == "queued", "while its job is out, it is being made")
	step.tick()
	_ok(step.state(feed) == "ready" and step.fresh(feed) and Array(feed.note_tags) == ["tarot", "cards", "readings", "fortune"]
		and step.said(feed) == "4 tags: tarot, cards, readings, fortune - left out, as the title or description says them: the tower"
		and not step.busy(feed),
		"a job that ended replaces the note's tags - less the one its title says already - and the step is made (%s)" % step.said(feed))
	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(feed.folder().path_join("youtube_tags.json")))
	_ok(kept is Dictionary and (kept as Dictionary).get("from") == feed.stamp(), "kept in the episode's folder, with the fingerprint of the words it was sent")
	feed.note_tags = PackedStringArray(["edited by hand"])
	AgentJobs._ended["text-youtube-check-2"] = {"ok": false, "error": "the quota ran out"}
	step._jobs[feed.folder()] = {"id": "text-youtube-check-2", "feed": feed, "stamp": feed.stamp()}
	step._tries[feed.folder()] = 2
	step.tick()
	_ok(step.state(feed) == "failed" and step.said(feed) == "the quota ran out" and Array(feed.note_tags) == ["edited by hand"],
		"a run that fails past its retry says why, and leaves the note's tags as they are")
	step._errors.clear()
	feed.said = "The first card is the moon."
	_ok(step.state(feed) == "missing" and step.said(feed).contains("written again"),
		"once the words are written again the step is not made for them")
	feed.said = "The first card is the tower."
	_ok(step.state(feed) == "ready", "the same words again, and it is made once more")
	# the box on the card
	var ex = load("res://src/export/exporter.gd").new()
	ex._build_ui()
	var card = load("res://src/export/youtube_card.gd").new()
	card.exporter = ex
	var names = _names({"title": "The Show", "episode": "The Tower Falls"})
	card.name_from(names)
	card.apply({"upload": true})
	var mine = card.episode_steps()[0] if card.episode_steps().size() == 2 else null
	_ok(mine != null and not mine.wanted() and not card.capture()["write_tags"], "the card offers its step, not wanted while the box is clear")
	var base := {"tags": ["the note's"]}
	_ok(card.meta(base).get("tags") == ["the note's"], "box clear: the panel's tags go up")
	card._write_tags.button_pressed = true
	_ok(card.capture()["write_tags"] and mine.wanted(), "ticked, its block says so and its step is wanted")
	_ok(card.meta(base).get("tags") == ["the note's"] and _tag_fields(card) == 0,
		"ticked too: the card lays no tags of its own over the panel's, and holds no list of its own")
	card._refresh_tags()
	_ok(card._tags_note.visible and card._tags_note.text.begins_with("Nothing on this note makes episodes"),
		"with nothing listing the step, it says nothing on the note makes episodes")
	mine.listed(feed)
	card._refresh_tags()
	_ok(card._tags_note.text.contains("replaced the tags above") and card._tags_note.text.contains("in the Pipeline"),
		"listed and made, it says the tags above were written over, and where they are written again (%s)" % card._tags_note.text)
	feed.said = "Other words."
	card._refresh_tags()
	_ok(card._tags_note.text.contains("written again") and card._tags_note.text.contains("over the tags above"),
		"words written again: it says new ones are written over the list (%s)" % card._tags_note.text)
	card._write_tags.button_pressed = false
	card._refresh_tags()
	_ok(not card._tags_note.visible, "box clear: nothing of them")
	card.free()
	names.free()
	ex.free()
	return true


## The thumbnail: the card's choice, what an upload of a take takes, and the step that paints one.
func _thumbnails() -> bool:
	var Thumb: GDScript = load("res://src/export/youtube_thumbnail.gd")
	var Ex: GDScript = load("res://src/export/exporter.gd")
	var ex = Ex.new()
	ex._build_ui()
	var card = load("res://src/export/youtube_card.gd").new()
	card.exporter = ex
	var names = _names({"title": "The Show", "episode": "The Tower Falls"})
	card.name_from(names)
	card.apply({"upload": true})
	var files := ProjectSettings.globalize_path(ROOT + "_files")
	var dir := files.path_join("thumb_episode")
	DirAccess.make_dir_recursive_absolute(dir)
	var m: Dictionary = card.meta({"tags": [], "folder": dir})
	_ok(card.thumbnail() == "youtube" and card.capture()["thumbnail"] == "youtube" and not m.has("thumbnail")
		and not m.has("thumbnail_at") and not m.has("thumbnail_why") and not m.has("folder") and not card._thumb_writer.visible,
		"a new card's thumbnail is YouTube's choice: its upload names none, and the episode's folder stays off the wire")
	# the block
	card.apply({"upload": true, "thumbnail": "painted", "thumbnail_writer": "claude", "thumbnail_writer_model": "m1",
		"thumbnail_writer_effort": "high", "thumbnail_painter": "grok"})
	var c: Dictionary = card.capture()
	_ok(c["thumbnail"] == "painted" and c["thumbnail_writer"] == "claude" and c["thumbnail_writer_model"] == "m1"
		and c["thumbnail_writer_effort"] == "high" and c["thumbnail_painter"] == "grok" and card._thumb_writer.visible
		and card._thumb_painter.visible, "its block keeps the choice and a painted one's writer and painter, shown only then")
	card.apply({"upload": true, "thumbnail": "sparkles"})
	_ok(card.thumbnail() == "youtube" and card.capture()["thumbnail_painter"] == "codex",
		"a thumbnail it does not know is YouTube's, and a block naming no painter has the card's own")
	# the title screen, asked of the take
	card._select(card._thumbnail, "title")
	var titled := _file("takes/titled.json", JSON.stringify({"bookend": {"in": 9.0, "out": 6.0}, "opening": "title"})).get_basename() + ".wav"
	var bare := _file("takes/bare.json", JSON.stringify({"bookend": {"in": 9.0, "out": 6.0}, "opening": "none"})).get_basename() + ".wav"
	var mt: Dictionary = card.meta({"tags": []}, titled)
	_ok(is_equal_approx(float(mt.get("thumbnail_at", -1.0)), Openings.title_moment(9.0)) and not mt.has("thumbnail_why"),
		"Title screen: a frame of a take that opened on its title, at its moment (%.1f s)" % float(mt.get("thumbnail_at", -1.0)))
	var mb: Dictionary = card.meta({"tags": []}, bare)
	_ok(not mb.has("thumbnail_at") and String(mb.get("thumbnail_why", "")).contains("does not open on its title"),
		"the control: a take that opened on nothing has no title screen, and the upload says so (%s)" % mb.get("thumbnail_why", ""))
	# painted, asked of the episode's folder
	card._select(card._thumbnail, "painted")
	var step = card.episode_steps()[1]
	_ok(step.wanted() and step.key == "youtube_thumbnail", "Painted: the card's thumbnail step is wanted")
	_ok(String(card.meta({"tags": [], "folder": dir}, titled).get("thumbnail_why", "")).contains("no thumbnail is painted")
		and String(card.meta({"tags": []}, titled).get("thumbnail_why", "")).contains("nothing on this note makes an episode"),
		"until it is painted the upload says so - and on a note with no episode, that nothing makes one")
	card._select(card._thumbnail, "youtube")
	_ok(not step.wanted() and EpisodeStep.listed_of([step]).is_empty(), "the control: on YouTube's choice the step is not one")
	card._select(card._thumbnail, "painted")
	# what the writer answers, landed
	var pics := PackedStringArray(["/p/one.png", "/p/two.png", "/p/three.png"])
	var got: Variant = Thumb.land(JSON.parse_string("{\"picture\": \"A lantern on a dark table.\", \"words\": \" \\\"THE LAST CARD\\\" \", \"after\": [2, \"1\", 2, 9, 0]}"), pics)
	_ok(got is Dictionary and got["picture"] == "A lantern on a dark table." and got["words"] == "THE LAST CARD"
		and got["after"] == ["/p/two.png", "/p/one.png"],
		"the writer's answer is kept: what to paint, the words trimmed, the pictures it named - each once, only those there (%s)" % str(got))
	_ok(Thumb.land({"picture": " ", "words": "x"}, pics) is String and Thumb.land(null, pics) is String
		and (Thumb.land({"picture": "A lantern."}, pics) as Dictionary)["after"] == [],
		"the controls: nothing to paint and no JSON are refused; naming no picture follows none")
	# what the writer is told
	Rules.clear()
	var p: Dictionary = Thumb.prompt("The Show", "The Tower Falls", "A reading of three.", "The first card is the tower.", pics)
	var text := String(p["prompt"])
	var images: Array = p["images"]
	_ok(Rules.missing.is_empty() and not text.contains("{{") and not String(p["system"]).is_empty()
		and text.contains("The first card is the tower.") and text.contains("printed under the thumbnail: The Tower Falls")
		and text.contains("numbered 1 to 3") and text.contains("\"after\"") and images.size() == 3
		and (images[1] as Dictionary)["path"] == "/p/two.png" and (images[1] as Dictionary)["label"] == "Picture 2:",
		"the writer is told the episode and shown its pictures, numbered (%s)" % str(Rules.missing))
	var none: Dictionary = Thumb.prompt("", "", "", "Words.", PackedStringArray())
	_ok(not String(none["prompt"]).contains("attached") and not String(none["prompt"]).contains("\"after\"")
		and not String(none["prompt"]).contains("THE SHOW:") and (none["images"] as Array).is_empty() and Rules.missing.is_empty(),
		"the control: an episode with no pictures and no name is told of neither")
	# what the painter is told
	var said: String = Thumb.painting(got, false)
	_ok(Rules.missing.is_empty() and said.contains("A lantern on a dark table.") and said.contains("exactly these and no others: \"THE LAST CARD\"")
		and said.contains("frames of the video itself") and ImageGen.Bedrock.ratio_in(said) == "16:9",
		"the painter is told what to paint, the words exactly, the pictures' look, and 16:9 first")
	var plain: String = Thumb.painting({"picture": "A lantern.", "words": "", "after": []}, true)
	_ok(plain.contains("No text, letters or numbers") and not plain.contains("frames of the video") and ImageGen.Bedrock.ratio_in(plain) == "9:16",
		"the control: no words is no text at all, no pictures no look to follow, and a portrait video's is 9:16")
	# the painting, cut
	var src := files.path_join("painted.png")
	var img := Image.create(1536, 1024, false, Image.FORMAT_RGB8)
	img.fill(Color.GREEN)
	img.fill_rect(Rect2i(0, 0, 1536, 70), Color.RED)
	img.fill_rect(Rect2i(0, 1024 - 70, 1536, 70), Color.RED)
	img.save_png(src)
	var jpg := files.path_join("cut.jpg")
	var err: String = Thumb.fit(src, jpg, false)
	var cut := Image.load_from_file(jpg) if err.is_empty() else null
	_ok(cut != null and cut.get_size() == Vector2i(1280, 720) and cut.get_pixel(640, 2).g > 0.8 and cut.get_pixel(640, 717).g > 0.8
		and cut.get_pixel(640, 2).r < 0.3, "a 3:2 painting is cut about its middle to 1280x720, what was painted past 16:9 gone (%s)" % err)
	_ok(Thumb.fit(src, jpg, true).is_empty() and Image.load_from_file(jpg).get_size() == Vector2i(720, 1280),
		"a portrait video's, to 720x1280")
	_ok(not Thumb.fit(src + ".none", jpg, false).is_empty(), "the control: no painting, no thumbnail, and why")
	# the step: the writer, then the painter, then kept
	var feed := FakeFeed.new()
	feed.dir = dir
	feed.said = "The first card is the tower."
	feed.pics = pics
	_ok(step._writer(feed) == card._thumb_writer.choice(), "its writer is the card's")
	var job: Dictionary = step._after({"picture": "A lantern.", "words": "", "after": ["/p/one.png"]}, feed)
	_ok(job.get("kind") == "image" and job.get("backend") == card._thumb_painter.choice()["agent"] and job.get("refs") == ["/p/one.png"]
		and job.get("target") == dir.path_join("youtube_thumbnail_1.png") and String(job.get("prompt")).contains("A lantern."),
		"the writer's answer is the card's painter's job, into the episode's folder")
	# matched to the video's pictures
	var eight := PackedStringArray(["/p/0", "/p/1", "/p/2", "/p/3", "/p/4", "/p/5", "/p/6", "/p/7"])
	_ok(Thumb.spread(eight, 4) == ["/p/0", "/p/2", "/p/5", "/p/7"] and Thumb.spread(pics, 4) == Array(pics),
		"a few spread through the pictures: the first and the last among them, in order (%s)" % str(Thumb.spread(eight, 4)))
	var told: Dictionary = step._prompt(feed)
	var free: Dictionary = step._after({"picture": "A lantern.", "words": "", "after": []}, feed)
	_ok(step.matching() and (told["images"] as Array).size() == 3
		and String(told["prompt"]).contains("look like one more of them") and String(told["prompt"]).contains("in the pictures' own colors")
		and not String(told["prompt"]).contains("colors that stand apart") and free.get("refs") == Array(pics)
		and String(free.get("prompt")).contains("frames of the video itself"),
		"matching, the writer is told to design one more of the video's pictures, and the painter handed some of them though none were named")
	card._thumb_match.button_pressed = false
	told = step._prompt(feed)
	free = step._after({"picture": "A lantern.", "words": "", "after": []}, feed)
	_ok(not step.matching() and (told["images"] as Array).is_empty() and not String(told["prompt"]).contains("attached")
		and String(told["prompt"]).contains("colors that stand apart") and (free.get("refs") as Array).is_empty()
		and not String(free.get("prompt")).contains("frames of the video") and card.capture()["thumbnail_match"] == false,
		"the control: cleared, the writer is shown none and the painter handed none")
	card._thumb_match.button_pressed = true
	feed.pics = PackedStringArray()
	step.listed(feed)
	card._refresh_thumbnail()
	_ok(card._thumb_match.visible and card._thumb_note.text.contains("no pictures of its own yet"),
		"with none to match, the card says so (%s)" % card._thumb_note.text)
	feed.pics = pics
	AgentJobs._ended["text-youtube-check-thumb"] = {"ok": true, "text": "{\"picture\": \"A lantern.\", \"words\": \"\", \"after\": [1]}"}
	step._jobs[dir] = {"id": "text-youtube-check-thumb", "feed": feed, "stamp": feed.stamp(), "who": "writer"}
	step._tries[dir] = 2
	step.tick()
	_ok(step.state(feed) == "failed" and step.said(feed).contains("read-only") and Thumb.image_in(dir).is_empty()
		and not FileAccess.file_exists(dir.path_join("youtube_thumbnail.json")),
		"the writer's answer starts the painter - here refused, read-only, and said - and nothing is kept before the painting")
	step._errors.clear()
	var painted := String(job["target"])
	img.save_png(painted)
	AgentJobs._ended["image-youtube-check-thumb"] = {"ok": true, "path": painted}
	step._jobs[dir] = {"id": "image-youtube-check-thumb", "feed": feed, "stamp": feed.stamp(), "who": "painter",
		"got": {"picture": "A lantern.", "words": "THE LAST CARD", "after": ["/p/one.png"]}}
	step.tick()
	var made: String = Thumb.image_in(dir)
	var want := Vector2i(720, 1280) if Thumb._portrait() else Vector2i(1280, 720)
	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("youtube_thumbnail.json")))
	_ok(step.state(feed) == "ready" and made == dir.path_join("youtube_thumbnail_1.jpg") and Image.load_from_file(made).get_size() == want
		and step.said(feed).begins_with("painted with \"THE LAST CARD\": A lantern.") and kept is Dictionary
		and ((kept as Dictionary).get("versions", []) as Array).size() == 1 and step.made(feed).get("from") == feed.stamp(),
		"the painting landed is cut beside it and the step made, with the fingerprint of the words (%s)" % step.said(feed))
	step.listed(feed)
	card._refresh_thumbnail()
	_ok(card._thumb_note.text.contains("goes up with it") and card._thumb_note.text.contains("in the Pipeline") and card._thumb_view.visible,
		"the card shows it, and says it goes up (%s)" % card._thumb_note.text)
	_ok(card.meta({"tags": [], "folder": dir}, titled).get("thumbnail") == made, "and it goes up")
	feed.said = "Other words."
	card._refresh_thumbnail()
	_ok(card._thumb_note.text.contains("before the episode's words were written again")
		and card.meta({"tags": [], "folder": dir}, titled).get("thumbnail") == made,
		"words written again: it says so, and goes up as it is until another is painted")
	# nothing paints over a choice
	_ok(step.generate(feed) and not step.busy(feed) and step.state(feed) == "missing" and not step.owed(feed)
		and not step.to_make(feed) and step.said(feed).contains("and kept")
		and not card._thumb_note.text.contains("an export") and not card._thumb_note.text.contains("making the episode"),
		"...and Generate, or an export that goes up, paints none over it - only its ⟳ paints another (%s)" % step.said(feed))
	var video := files.path_join("v.mp4")
	_ok(Ex._beside(made, video) == files.path_join("v.thumbnail.jpg") and FileAccess.file_exists(files.path_join("v.thumbnail.jpg")),
		"the exporter puts a painted thumbnail beside the video it goes up with")
	# another, kept beside it
	feed.said = "The first card is the tower."
	var again: String = step._prompt(feed)["prompt"]
	_ok(Rules.missing.is_empty() and again.contains("ALREADY PAINTED") and again.contains("1. A lantern.")
		and again.contains("Its words: \"THE LAST CARD\"") and not again.contains("{{"),
		"painted again, the writer is shown the thumbnail kept - its brief and its words - and told to make another (%s)" % str(Rules.missing))
	_ok(not text.contains("ALREADY PAINTED"), "the control: the first time, it is shown none")
	var job2: Dictionary = step._after({"picture": "A tower.", "words": "", "after": []}, feed)
	var painted2 := String(job2.get("target", ""))
	_ok(painted2 == dir.path_join("youtube_thumbnail_2.png"), "the next painting has files of its own (%s)" % painted2)
	img.save_png(painted2)
	AgentJobs._ended["image-youtube-check-thumb-2"] = {"ok": true, "path": painted2}
	step._jobs[dir] = {"id": "image-youtube-check-thumb-2", "feed": feed, "stamp": feed.stamp(), "who": "painter",
		"got": {"picture": "A tower.", "words": "", "after": []}}
	step.tick()
	var second: String = Thumb.image_in(dir)
	_ok(step.versions(feed).size() == 2 and step.chosen(feed) == 1 and second == dir.path_join("youtube_thumbnail_2.jpg")
		and FileAccess.file_exists(made) and card.meta({"tags": [], "folder": dir}, titled).get("thumbnail") == second
		and step.said(feed).begins_with("painted: A tower."),
		"the one painted after it is kept beside the first, and goes up (%s)" % step.said(feed))
	card._refresh_thumbnail()
	_ok(card._thumb_steps.visible and card._thumb_at.text == "v2/2" and not card._thumb_back.disabled and card._thumb_on.disabled
		and card._thumb_note.text.contains("2 painted"), "the card steps between them, the latest shown (%s)" % card._thumb_note.text)
	card._fill_thumb_window()
	var big: Array = card._thumb_window.find_children("*", "TextureRect", true, false)
	var said_big := " ".join(card._thumb_window.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text))
	_ok(card._thumb_view.mouse_filter == Control.MOUSE_FILTER_STOP and big.size() == 1 and (big[0] as TextureRect).texture != null
		and Vector2i((big[0] as TextureRect).texture.get_size()) == want and said_big.contains("No words on it.")
		and said_big.contains("A tower.") and said_big.contains("version 2 of 2"),
		"a click opens it full size: the one chosen, its brief, and which version it is (%s)" % said_big)
	var back: Array = card._thumb_window.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "‹ previous")
	back[0].pressed.emit()
	_ok(step.chosen(feed) == 0 and Thumb.image_in(dir) == made and card._thumb_at.text == "v1/2" and card._thumb_back.disabled
		and step.said(feed).contains("THE LAST CARD"), "‹ there chooses the first: it goes up again, and the step says so")
	card._fill_thumb_window()
	said_big = " ".join(card._thumb_window.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text))
	_ok(said_big.contains("Its words: \"THE LAST CARD\"") and said_big.contains("version 1 of 2"), "and the window shows it (%s)" % said_big)
	card._choose_thumb(-1)
	_ok(step.chosen(feed) == 0, "the control: there is nothing before the first")
	card._thumb_del.pressed.emit()
	_ok(step.versions(feed).size() == 2 and card._thumb_del.text == "Delete?", "✕ pressed once only asks")
	card._thumb_del.pressed.emit()
	_ok(step.versions(feed).size() == 1 and step.chosen(feed) == 0 and Thumb.image_in(dir) == second
		and not FileAccess.file_exists(made) and not FileAccess.file_exists(painted) and not card._thumb_back.visible
		and card._thumb_del.text == "✕", "pressed again, the one shown is deleted with its painting, and the other goes up")
	_ok(step.delete(feed, 0).is_empty() and step.versions(feed).is_empty() and Thumb.image_in(dir).is_empty()
		and not FileAccess.file_exists(dir.path_join("youtube_thumbnail.json")) and step.state(feed) == "missing"
		and step.owed(feed) and step.to_make(feed),
		"the last one deleted, the episode has none - and Generate, or an export, paints one (the control)")
	card._fill_thumb_window()
	_ok(card._thumb_window.get_child_count() == 0, "the control: with none left the window holds nothing")
	img.save_jpg(dir.path_join("youtube_thumbnail.jpg"))
	var f := FileAccess.open(dir.path_join("youtube_thumbnail.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"picture": "Kept before.", "words": "", "after": [], "from": feed.stamp(),
		"image": "youtube_thumbnail.jpg"}))
	f.close()
	_ok(step.versions(feed).size() == 1 and step.state(feed) == "ready" and Thumb.image_in(dir) == dir.path_join("youtube_thumbnail.jpg")
		and Thumb._next_in(dir) == "youtube_thumbnail_1", "a record kept before there were versions is one, its files named in it")
	card.free()
	names.free()
	ex.free()
	return true


func _tag_field() -> bool:
	var f = load("res://src/ui/tag_field.gd").new()
	var changes := [0]
	f.changed.connect(func() -> void: changes[0] += 1)
	var chips := func() -> Array:
		return f.get_children().filter(func(c: Node) -> bool: return c is PanelContainer)
	f.set_tags(PackedStringArray(["tarot", "Tarot", "  4am "]))
	_ok(Array(f.get_tags()) == ["tarot", "4am"] and changes[0] == 0 and (chips.call() as Array).size() == 2,
		"filled: a chip per tag, each once, trimmed - and no change signal")
	_ok(f.get_child(f.get_child_count() - 1) == f._input, "the typing box comes after the chips")
	f._input.text = "pick a card, timeless"
	f._on_typed(f._input.text)
	_ok(Array(f._tags) == ["tarot", "4am", "pick a card"] and f._input.text == "timeless" and changes[0] == 1,
		"a comma makes a chip of what came before it, and the rest stays typed")
	_ok(Array(f.get_tags()).back() == "timeless", "what is still typed counts as a tag")
	f.commit()
	_ok(Array(f._tags).back() == "timeless" and f._input.text.is_empty(), "Enter (or leaving the box) makes it a chip")
	f._input.text = "x, \"y\", , TAROT, z,"
	f._on_typed(f._input.text)
	_ok(Array(f._tags).slice(-3) == ["x", "y", "z"] and f._input.text.is_empty(),
		"a pasted list splits into chips, quotes and empties dropped, a tag already there not doubled")
	var before: int = changes[0]
	var row: Control = (chips.call() as Array)[1]
	var x: Button = row.find_children("*", "Button", true, false)[0]
	x.pressed.emit()
	_ok(not f._has(f._tags, "4am") and changes[0] == before + 1, "× removes its tag")
	var k := InputEventKey.new()
	k.keycode = KEY_BACKSPACE
	k.pressed = true
	f._on_key(k)
	_ok(not f._has(f._tags, "z"), "Backspace in the empty box removes the last chip")
	f.set_fixed(PackedStringArray(["Truthful Tarot"]), "The show's own tag.")
	var first: Control = (chips.call() as Array)[0]
	_ok(first.find_children("*", "Button", true, false).is_empty() and first.tooltip_text.contains("show's own"),
		"a fixed tag comes first, with no ×, saying where it is kept")
	f.mark({"X": "it is already there"})
	var marked: Control = null
	for c in chips.call():
		if ((c as Control).find_children("*", "Label", true, false)[0] as Label).text == "x":
			marked = c
	_ok(marked != null and marked.modulate.a < 1.0 and marked.tooltip_text.contains("it is already there"),
		"a chip that will not go up is dimmed, saying why")
	f.editable = false
	var buttons := 0
	for c in chips.call():
		buttons += (c as Control).find_children("*", "Button", true, false).size()
	_ok(buttons == 0 and not f._input.editable, "read-only: no × and no typing")
	f.editable = true
	f.set_tags(PackedStringArray(["a very long tag ".repeat(12).strip_edges()]))
	var long_chip: Control = (chips.call() as Array).back()
	_ok(long_chip.get_combined_minimum_size().x <= f.MAX_CHIP + 40.0,
		"a long tag is cut with an ellipsis instead of widening the field (%.0f px)" % long_chip.get_combined_minimum_size().x)
	f.free()
	return true


## A real show file: opened, seeded, its byline set on the card, written by the document's own writer, read back, and opened
## again by another panel, whose new episode is filled from it at once.
func _doc_file() -> bool:
	var ed = load("res://src/reading/reading_panel.gd").new()
	ed.workspace = "table"
	ed._build_panel()
	var epi = ed._block_cards["table"]      # the episode's card ([EpisodeCard])
	ed._attach("youtube")
	var ep := TableEpisode.open("doc-check", 31)
	ep.write_json("plan", {"episode_title": "Episode Thirty-One", "description": "First paragraph.\n\nSecond: with a colon.",
		"tags": ["tarot", "pick a card"], "spread": {"positions": [{"name": "Past"}]}})
	var body := "# The brief\n\nWhat the show is.\n"
	var path := _file("show.md", "---\ntitle: Doc Check Show\nghost:\n  table:\n    show: doc-check\n    seed: 31\n---\n" + body)
	ed._doc._on_picked(path)
	_ok(ed._doc.is_sync() and int(epi._knobs["seed"]) == 31 and ed._writer.field_value("episode") == "Episode Thirty-One",
		"the show file opens on its episode")
	epi._seed_from_plan()
	(ed._writer._field_edits["byline"] as LineEdit).text = "with Pen & Ink"
	ed._writer._commit_field("byline")
	_ok(ed._doc.save(), "the panel's block is written into the show file")
	var raw := FileAccess.get_file_as_string(path)
	var head := raw.substr(0, raw.find("\n---\n", 4))
	_ok(head.begins_with("---\ntitle: Doc Check Show\n") and head.contains("\ntags: tarot, pick a card\n")
		and head.contains("\nbyline: with Pen & Ink\n") and head.find("tags:") < head.find("ghost:")
		and head.find("byline:") < head.find("ghost:"),
		"the tags and the byline are the file's own lines, above ghost's block, as a chapter keeps them:\n%s" % head)
	var data: Variant = FrontMatter.read_block(raw).get("data")
	var show: Dictionary = (data as Dictionary).get("table", {}) if data is Dictionary else {}
	_ok(not show.has("episode_title") and show.get("description") == "First paragraph.\n\nSecond: with a colon."
		and not show.has("youtube"), "the block holds the show's description, whole, and no episode's title or record")
	var yt: Variant = (data as Dictionary).get("youtube") if data is Dictionary else null
	_ok(yt is Dictionary and (yt as Dictionary).get("privacy") == "private" and (yt as Dictionary).get("upload") == false,
		"the YouTube card's block is the file's too, beside the show's (%s)" % str(yt))
	_ok(raw.ends_with("---\n" + body), "the body is untouched")
	ed.free()
	# another panel opens the file, and makes a new episode: filled from the file at once
	var again = load("res://src/reading/reading_panel.gd").new()
	again.workspace = "table"
	again._build_panel()
	var again_show = again._block_cards["table"]
	again._attach("youtube")
	again._doc._on_picked(path)
	again_show._knobs["seed"] = 99
	again_show._open_episode()
	_ok(again._writer.field_value("episode").is_empty() and again_show._yt_desc.text == "First paragraph.\n\nSecond: with a colon."
		and Array(again_show._yt_tags.get_tags()) == ["tarot", "pick a card"] and again._writer._field_edits["byline"].text == "with Pen & Ink",
		"a new episode is filled from the file at once: description, tags, byline - its Episode its own plan's")
	again.free()
	return true
