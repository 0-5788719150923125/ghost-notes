extends SceneTree

## youtube_check - the YouTube upload's pieces that hold without a network: the client file, the
## sign-in's parts, what a video says, the records, the tarot episode's upload notes and the
## YouTube card.
##
##   godot --headless --path . --script res://tests/export/youtube_check.gd
##
## - THE CLIENT FILE: a "Desktop app" client is read; a Web client, a file with no secret, one that
##   is not JSON and one whose endpoints are not Google's are refused, each saying why. Imported, it
##   is kept owner read/write only, and a bad file leaves the kept one alone. A CHANNEL KEEPS THE
##   CLIENT IT SIGNED IN WITH: another client imported is the one new sign-ins use, and neither it nor
##   the client forgotten costs a channel its sign-in.
## - THE CHANNELS (2026-10-17, the user: "target different channels for different kinds of
##   project"): each sign-in kept under its channel, owner-only, listed in the order signed in to and
##   named by its handle, else its title; each may do what it was granted and only that; one signed in
##   to again keeps its place; a lapsed one keeps its channel; one forgotten is off the list; an odd id
##   cannot name a file outside the folder.
## - THE SIGN-IN'S PARTS: PKCE against RFC 7636's own example, the consent URL (upload scope only,
##   S256, offline, the account chooser and the consent screen, the loopback redirect - all encoded),
##   the redirect's query decoded.
## - THE WIRE: the next offset from a 308's `Range`, headers in any case, Google's error shapes in
##   words.
## - WHAT A VIDEO SAYS: `<`/`>` made safe, the title one line of at most 100 characters cut at a
##   word, the description at most 5000 bytes, tags split as a document writes them, each once,
##   counted as YouTube counts them and fitted to 500; private unless asked otherwise (a privacy
##   YouTube does not know is private), not for kids, synthetic, no paid promotion, People & Blogs
##   unless another category is asked for (one an upload cannot take is People & Blogs).
##   The playlist a video joins is named and linked between the description and the chapters (the
##   control: no playlist, no line).
## - RECORDS: an upload recorded and read back; a queued upload pending with its channel, owner-only;
##   a missing file refused; one queued with no channel is aimed at the channel its sign-in lands on,
##   one that names a channel keeps it.
## - THE TAROT EPISODE: its upload notes from the plan, with a chapter per card timed from a take's
##   word timings (an hour on, `h:mm:ss`), and `upload.md` with the show's tags first.
## - THE EXPORT MENU says nothing of YouTube (2026-10-07: the upload moved to a component's card), and AN
##   UPLOAD WHOSE TITLE CANNOT BE MADE is refused at the click, saying why, before anything is asked.
## - THE NOTE'S NAMES ARE ITS SCRIPT CARD'S (2026-10-25, the user: "nowhere is an episode title actually an
##   option here ... It shouldn't be possible to use the YouTube card if the underlying macros we claim to
##   support would not even work here"): a card no panel bound fills nothing and nothing goes up (the
##   control); bound, it shows Title and Episode on a Script card that had neither, and reads them; an empty
##   Episode leaves the Title alone. WHAT IT CLAIMS IS WHAT THE NOTE FILLS: its tooltip names only those
##   macros, and %seed% on a note with no episodes is said under the title and refused (the control: a
##   panel that adds the seed fills it, and the same title goes up).
## - THE YOUTUBE CARD: a new one goes up nothing and privately, its block round-trips (an unknown
##   privacy reads as private, an unknown category as People & Blogs); unticked it describes no upload
##   whatever the panel has, ticked it lays its title - the template's macros filled, nothing
##   dangling, no name twice - privacy, category and playlist
##   and channel over the panel's part, and nothing when the panel has nothing. ITS CHANNEL: a toggle
##   per channel kept, named as YouTube names it, the note's pressed; a block with none takes the
##   first kept; another channel's toggle makes it the note's and clears the playlist (the other
##   channel's); the block's channel when it is not kept here shows dimmed and pressed, its name kept,
##   with Sign in and no Remove; a lapsed one offers both. A channel that may only upload lacks the
##   playlists' scope; a resume - to its channel - while an upload waits on a file that exists, not
##   once it is gone; Import / Replace follows the client file. THE LINE A TITLE GOES UP IN
##   (`title_shape`): the template with the episode's title marked, handed to the Cards producer from
##   the card's own template - none when the episode's title stands alone or is left out.
## - THE TAG FIELD (tag_field.gd, 2026-10-06, the user: "show all of the tags, with the ability to
##   click an 'x' to remove them on each one... comma-delimited splits the tags into the button with
##   the x"): a chip per tag, filled without a change signal; a comma, Enter or a paste of "a, b, c"
##   makes chips and leaves the rest typed; × and Backspace in the empty box remove; each tag once
##   whatever its case; fixed tags first with no ×; a dimmed chip says why; read-only has no ×; a long
##   tag cannot widen the field.
## - THE TAROT PANEL'S FIELDS ARE THE SHOW'S GLOBAL VALUES (the user: "it should have been grabbed
##   immediately, since that stuff is global"): the description and the tags the show's, the title
##   one value the picked episode overwrites (and an edit writes into its plan; an emptied one is
##   not); a show with none takes the picked episode's once; a NEW EPISODE shows them at once; the
##   byline on the document card right under Title (the user: "right under the title field"); the
##   upload described from all that - once the note has a YouTube card and its box is ticked -
##   with the title screen's thumbnail moment, for the episode an export rendered even after another
##   is picked. The description and tags are the YouTube card's; THE TITLE IS THE SCRIPT CARD'S EPISODE,
##   handed the picked episode's: an edit written into its plan, an emptied one not, none kept in the block,
##   and a new episode's empty and waiting for its plan. A Proof note's Episode is its framer's title, an
##   edit written into its problem; a note read as it is written shows its own once it has a YouTube card
##   (the control: not before), and goes up with it.
## - EACH EPISODE'S TAGS (2026-10-18, the user: "allow the 'Generate' button to override/rewrite those
##   tags ... it would not be okay to tightly-couple the two cards"): the writer's answer is cleaned (no
##   hashtag sign, no comma inside), each tag once, a bare list taken too - and no JSON, no list or too few
##   usable tags are not kept. Its prompt renders whole with the show, the episode's title, description and
##   words, the note's tags and YouTube's limit, and says nothing of what an episode does not have. The
##   step ([YouTubeTags], an [EpisodeStep]) is one only while the card's box is ticked; it waits for the
##   episode's words (neither Generate nor ⟳ starts it before); started in a read-only gate it says why
##   it cannot; a job that ended is kept in the episode's folder with the fingerprint of the words it was
##   sent and REPLACES THE NOTE'S TAGS (2026-10-19: "I never know which tags are truly going to be
##   applied ... just one, unified list"); a note that cannot keep them fails the step, saying why (the
##   control); a run that fails past its retry says why and leaves the note's as they were; words written
##   again make it stale and the same words again make it made once more. On the card: its block keeps the
##   box, the upload takes the panel's tags ticked or not, the card holds no list of its own, and the line
##   under the panel's says what the writer does to it - or, with nothing listing the step, that nothing
##   on the note makes episodes. THE HOSTS NEVER NAME THE CARD: the panel holds the step the YouTube card
##   offers; the Episode card lists it as a Tags row under the Close only while the box is ticked, says
##   which episode it shows, waits for the reading (its words with the marks out), makes it once its own
##   steps are done (here refused, read-only, said on the row), shows ✓, the tags and ⟳ once made - and
##   what it wrote is the show's one list, on the card and going up, for any episode's upload. The Proof
##   card shows the note's tags as one list too, lists the step under the Script, hands it the note's tags
##   with the framer's, and uploads the note's list alone - the framer's go into an empty one, once, and
##   never in a read-only process (the control) - until the step writes over it.
## - A NOTE READ AS IT IS WRITTEN IS ITS OWN EPISODE (2026-10-23, of an actor's note: "I don't see anywhere
##   it would be possible to write a description ... be sure that the auto-tagging mechanism should work as
##   well"): its YouTube card shows a description box (hidden on a card whose show describes its episodes -
##   the control - and nothing of it going up while hidden), kept in its block lines and all, and the note's
##   tags as one list; the upload takes the description first, then the component's (an actor's says how
##   they were made - splats for Gaussian, their pixels bent for 2D), and the note's tags with any of its own.
##   The tags step is listed on the card with the note as its episode, in the note's own folder, reading its
##   words with the marks out, the title as it goes up, the description and the component's writer; only an
##   export that goes up starts it (the control: one that does not starts nothing), refused here, said on its
##   row; while its job runs the export waits; landed, it is ✓ with its ⟳ and replaces the note's tags on the
##   card and going up; words written again make it stale.
## - A REAL SHOW FILE: the tags and the byline land as top-level lines above ghost's block - the
##   chapter format - the block holds the show's title and description and no record per episode, the
##   rest of the file is untouched, and a panel opening it fills a new episode from it at once.
## - THE THUMBNAIL'S MOMENT and ffmpeg's arguments for taking it.

## By path, not by class name: a new class is unknown to `--script` runs until the editor rescans.
const YouTube := preload("res://src/export/youtube.gd")
const ROOT := "user://youtube_check"
const TAROT := "user://youtube_check_tarot"

var _fails := 0


func _init() -> void:
	# deferred: the exporter needs the autoloads, which are only up once the tree is
	_run.call_deferred()


func _run() -> void:
	# A GATE NEVER WRITES THE SETTINGS OF WHOEVER RUNS IT: a --script run is not read-only by itself,
	# and the panel built below binds its controls to them
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	var keep_root: String = YouTube.root
	var keep_tarot := CardEpisode.root
	YouTube.root = ROOT
	CardEpisode.root = TAROT
	_wipe(ROOT)
	_wipe(TAROT)
	_wipe(ROOT + "_files")
	for check in [_client, _import, _channels, _pkce, _auth_url, _query, _wire, _fit, _body, _records, _episode_notes,
			_menu, _card, _episode_tags, _tag_field, _panel_fields, _proof_steps, _note_steps, _doc_file]:
		if not bool(check.call()):
			_ok(false, "a check stopped part way (script error?)")
	_wipe(ROOT)
	_wipe(TAROT)
	_wipe(ROOT + "_files")
	YouTube.root = keep_root
	CardEpisode.root = keep_tarot
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
	var kept := ProjectSettings.globalize_path(ROOT.path_join("client.json"))
	_ok(YouTube.has_client() and YouTube.client()["client_id"] == "123-abc.apps.googleusercontent.com",
		"the imported client is what is read from then on")
	_ok(_owner_only(kept), "the kept client is owner read/write only (%o)" % FileAccess.get_unix_permissions(kept))
	_ok(OS.get_name() == "Windows" or FileAccess.get_unix_permissions(ProjectSettings.globalize_path(ROOT)) == YouTube.OWNER_DIR,
		"its folder is owner-only too")
	_ok(not FileAccess.get_file_as_string(kept).contains("redirect_uris"), "only what the flow needs is kept")
	# A CHANNEL KEEPS THE CLIENT IT SIGNED IN WITH
	YouTube._keep({"id": "UC-a", "handle": "@a", "title": "A"}, YouTube.client(), {"refresh_token": "rt"}, YouTube.SCOPE)
	_ok(YouTube.import_client(good) == "" and YouTube.signed_in("UC-a"), "re-importing the same client keeps the channel's sign-in")
	_ok(YouTube.import_client(_file("web.json", _client_json("x", "web"))) != ""
		and YouTube.client()["client_id"] == "123-abc.apps.googleusercontent.com" and YouTube.signed_in("UC-a"),
		"a bad file leaves the kept client and sign-in alone")
	_ok(YouTube.import_client(_file("other.json", _client_json("456-def.apps.googleusercontent.com"))) == ""
		and YouTube.client()["client_id"] == "456-def.apps.googleusercontent.com" and YouTube.signed_in("UC-a")
		and YouTube._token("UC-a")["client"]["client_id"] == "123-abc.apps.googleusercontent.com",
		"another client is the one new sign-ins use; the channel keeps the client it signed in with")
	var at := YouTube._channel_path("UC-a")
	_ok(_owner_only(at) and (OS.get_name() == "Windows"
		or FileAccess.get_unix_permissions(at.get_base_dir()) == YouTube.OWNER_DIR),
		"a channel's sign-in is owner read/write only, its folder too")
	YouTube.forget_client()
	_ok(not YouTube.has_client() and YouTube.signed_in("UC-a"), "forgetting the client costs no channel its sign-in")
	YouTube.forget_channel("UC-a")
	_ok(YouTube.channels().is_empty() and not YouTube.signed_in("UC-a"), "a channel forgotten is off the list")
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
	# THE PLAYLIST, BEFORE THE TIMESTAMPS: the stand-in for the end screen the API cannot write
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


## An episode on disk: a plan, a draw of two cards, a script with their marks, and a take whose
## words put the spread past the hour.
func _episode_notes() -> bool:
	var ep := CardEpisode.open("youtube-check", 7)
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
		_ok(RegEx.create_from_string("^1:0\\d:\\d\\d The spread$").search(ch[3]) != null, "an hour on it reads h:mm:ss (%s)" % ch[3])
	_ok(CardEpisode.chapter_clock(0) == "0:00" and CardEpisode.chapter_clock(65) == "1:05"
		and CardEpisode.chapter_clock(3725) == "1:02:05", "chapter clocks read as YouTube reads them")
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
		"playlist_title": "", "channel": "", "channel_name": "", "write_tags": false, "description": ""},
		"a new card uploads nothing, privately, as People & Blogs, titled by the template, to no channel yet (%s)" % str(cap))
	var names = _names({"title": "Truthful Tarot", "episode": "The Tower"})
	_ok(not names.shows_field("title") and not names.shows_field("episode"), "a Voice lab's Script card shows no Title or Episode of its own")
	card.name_from(names)
	_ok(names.shows_field("title") and names.shows_field("episode") and card.values_now() == {"title": "Truthful Tarot", "episode": "The Tower"},
		"bound, the card shows both on it and reads the note's names from there (%s)" % str(card.values_now()))
	_ok(card.meta({"tags": ["a"]}).is_empty(), "unticked, it describes no upload whatever the panel has")
	card.apply({"upload": true, "title": "%title% - %episode% (%date%)", "privacy": "unlisted", "category": "27",
		"playlist": "PL1", "playlist_title": "Readings", "channel": "UC-x", "channel_name": "@x", "write_tags": true,
		"description": "Line one.\n\nLine two."})
	_ok(card.capture() == {"upload": true, "title": "%title% - %episode% (%date%)", "privacy": "unlisted",
		"category": "27", "playlist": "PL1", "playlist_title": "Readings", "channel": "UC-x", "channel_name": "@x",
		"write_tags": true, "description": "Line one.\n\nLine two."},
		"its block round-trips, the description's lines and all (%s)" % str(card.capture()))
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
	_ok(card.meta({"values": {"title": "Show", "episode": "Rendered One"}}).get("title").begins_with("Show - Rendered One")
		and not card.meta({"values": {"title": "S"}}).has("values"),
		"the values a panel hands with its part (the episode an export rendered) win, and do not go up")
	# WHAT IT CLAIMS IS WHAT THE NOTE FILLS
	card._title.text = "%title% #%seed%"
	card.refresh()
	_ok(card.why_not().contains("%seed%") and card.meta({"tags": []}).has("refused") and not card.meta({"tags": []}).has("title")
		and card._preview.text.begins_with("⚠  The title names %seed%"),
		"a title naming %%seed%% on a note with no episodes is said under it and does not go up (%s)" % card._preview.text)
	_ok(card._title.tooltip_text.contains("%title%") and card._title.tooltip_text.contains("%episode%")
		and card._title.tooltip_text.contains("%date%") and not card._title.tooltip_text.contains("%seed%"),
		"the title's tooltip names only the macros the note fills (%s)" % card._title.tooltip_text)
	card.values = func() -> Dictionary: return {"seed": "7"}
	card.refresh()
	_ok(card.why_not().is_empty() and card.meta({"tags": []}).get("title") == "Truthful Tarot #7" and card._title.tooltip_text.contains("%seed%"),
		"control: a panel that adds the seed fills it, and the same title goes up")
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
	# THE CHANNEL AND THE ACCOUNT ROWS
	YouTube.forget_client()
	card.apply({})
	card._seen = []
	card._refresh_account()
	_ok(card._client.text == "Import client…" and not card._sign.visible and not card._remove.visible
		and card.capture()["channel"] == "" and _chips(card).is_empty() and card._add.get_parent() == card._chips,
		"with no client and no channel, it offers to import a client, and + alone")
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
	_ok(card._client.text == "Replace client…" and card._account.text.contains("@the-arc") and card._account.text.contains("uploads only")
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
	# A CHANNEL NOT SIGNED IN HERE: a note from another machine, or one whose channel was removed
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
	YouTube.forget_client()
	card.free()
	names.free()
	ex.free()
	return true


## THE PROOF CARD lists the step too: under its Script, the note's tags with the framer's handed to it.
func _proof_steps() -> bool:
	var keep := ProofEpisode.root
	ProofEpisode.root = ROOT + "_proof"
	var ed = load("res://src/reading/reading_panel.gd").new()
	ed.workspace = "proof"
	ed._build_panel()
	ed._doc._sync = false
	ed._doc._fields = {"title": "Proofs", "tags": "math"}
	var proof = ed._block_cards["proof"]
	ed._attach("youtube")
	_ok(ed._note_upload == null and not ed._youtube._desc.visible,
		"control: a note whose card makes its episodes shows no description box of the YouTube card's, and lists no step there")
	ed._youtube._upload.set_pressed_no_signal(true)
	ed._youtube._write_tags.button_pressed = true
	proof._open_episode()
	proof._refresh()
	var step = ed._youtube.episode_steps()[0]
	_ok(proof._step_rows.has(step.key) and proof._step_box.get_index() > (proof._rows["script"]["state"] as Label).get_parent().get_index(),
		"its row stands under the Script")
	proof._tick_steps()
	_ok(step.host == "the Proof card" and step.shown == proof._feed, "the Proof card says it lists the step, and which episode it shows")
	proof._episode.write_json("problem", {"episode_title": "Why Two Is Prime", "description": "Two is prime.", "tags": ["primes", "math"]})
	proof._episode.write_text("script", "Two has no divisors but one and itself.")
	_ok(Array(proof._feed.tags()) == ["math", "primes"] and proof._feed.episode_title() == "Why Two Is Prime"
		and proof._feed.words() == "Two has no divisors but one and itself.", "it hands the step the note's tags with the framer's, and the lesson")
	var named: LineEdit = ed._writer._field_edits["episode"]
	ed._writer._refresh_handed()
	_ok(named.text == "Why Two Is Prime" and named.editable, "the Script card's Episode is the framer's title")
	named.text = "Two Is Prime"
	ed._writer._commit_field("episode")
	var problem: Dictionary = proof._episode.read_json("problem")
	_ok(proof.episode_title() == "Two Is Prime" and problem.get("description") == "Two is prime."
		and ed._youtube.title_now() == "Proofs: Two Is Prime",
		"an edit is written into its problem, the rest kept, and is its %%episode%% (%s)" % ed._youtube.title_now())
	named.text = "Why Two Is Prime"
	ed._writer._commit_field("episode")
	proof._refresh_tags()
	_ok(_tag_fields(ed._youtube) == 1 and Array(proof._tags_field.get_tags()) == ["math"]
		and ed.upload_meta("").get("tags") == ["math"],
		"the YouTube card shows the note's tags as one list, and the upload takes it alone - the framer's are not added unseen")
	AgentJobs._ended["text-youtube-check-proof"] = {"ok": true, "text": "{\"tags\": [\"prime numbers\", \"two\", \"proof\"]}"}
	step._jobs[proof._feed.folder()] = {"id": "text-youtube-check-proof", "feed": proof._feed, "stamp": proof._feed.stamp()}
	step.tick()
	proof._refresh()
	var r: Dictionary = proof._step_rows[step.key]
	_ok((r["state"] as Label).text == "✓ 3 tags: prime numbers, two, proof" and not (r["redo"] as Button).disabled,
		"made: its ✓, its tags, and its ⟳ (%s)" % (r["state"] as Label).text)
	_ok(ed._doc.field("tags") == "prime numbers, two, proof" and Array(proof._tags_field.get_tags()) == ["prime numbers", "two", "proof"]
		and ed.upload_meta("").get("tags") == ["prime numbers", "two", "proof"],
		"landed, they replace the note's tags: the one list on the card, and what goes up (%s)" % ed._doc.field("tags"))
	ed._youtube._write_tags.button_pressed = false
	proof._refresh()
	_ok(not proof._step_rows.has(step.key) and ed.upload_meta("").get("tags") == ["prime numbers", "two", "proof"],
		"box cleared: the row goes, and the list stays as it was written")
	# A NOTE WITH NO TAGS TAKES THE FRAMER'S, once
	ed._doc._fields.erase("tags")
	proof._seed_tags()
	_ok(ed._doc.field("tags").is_empty(), "control: a read-only process does not fill an empty list")
	proof._seed_from_problem()
	_ok(ed._doc.field("tags") == "primes, math" and Array(proof._tags_field.get_tags()) == ["primes", "math"],
		"a note with no tags takes the framer's, on the card (%s)" % ed._doc.field("tags"))
	ed._doc._fields["tags"] = "mine"
	proof._seed_from_problem()
	_ok(ed._doc.field("tags") == "mine", "and a note with tags keeps its own")
	ed.free()
	_wipe(ProofEpisode.root)
	ProofEpisode.root = keep
	return true


## A NOTE READ AS IT IS WRITTEN IS ITS OWN EPISODE (2026-10-23, of an actor's note: "I don't see anywhere it
## would be possible to write a description ... be sure that the auto-tagging mechanism should work as well").
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
	ed._doc._fields["episode"] = "Part One"
	_ok(ed.upload_meta("").get("title") == "A Reading: Part One", "its Episode, on the Script card, is the %episode% it goes up with")
	ed._youtube._title.text = "%title% #%seed%"
	_ok(ed.upload_meta("").has("refused") and ed._youtube.why_not().contains("%seed%"),
		"control: %seed%, which a note read as it is written does not have, stops the upload, saying why")
	ed._youtube._title.text = YouTube.TITLE_TEMPLATE
	ed._doc._fields.erase("episode")
	var said: String = load("res://src/likeness/actor_card.gd").disclosure("Someone", "gaussian")
	var bent: String = load("res://src/likeness/actor_card.gd").disclosure("Someone", "2d")
	_ok(said.contains("Gaussian splats") and not said.contains("pixel") and bent.contains("Every pixel of them is a real one"),
		"an actor's upload says how they were made: splats for Gaussian, their own pixels bent for 2D (control)")
	# THE TAGS STEP, listed here with the note as its episode
	var step = ed._youtube.episode_steps()[0]
	up.refresh()
	_ok(step.host.is_empty() and up._step_rows.is_empty(), "control: with the box clear, the step is not listed")
	ed._youtube._write_tags.button_pressed = true
	up.refresh()
	var folder: String = up._feed.folder()
	_ok(step.host == "this card" and step.shown == up._feed and up._step_rows.has(step.key)
		and folder.begins_with(ProjectSettings.globalize_path(ROOT + "_readings")) and folder.get_file().begins_with("a-reading-"),
		"ticked, it is listed on this card, the note its episode, kept in the note's own folder (%s)" % folder.get_file())
	_ok(up._feed.words() == "The quick brown fox  jumps over the lazy dog." and up._feed.episode_title() == "A Reading"
		and up._feed.description().begins_with("What this video is.") and Array(up._feed.tags()) == ["readings", "voice"]
		and up._feed.writer()["agent"] == "codex",
		"the step reads the note's words with the marks out, the title as it goes up, the description, the tags and the component's writer")
	ed._youtube._refresh_tags()
	_ok(ed._youtube._tags_note.text.ends_with("and so does an export that goes up."),
		"the card says an export that goes up writes them (%s)" % ed._youtube._tags_note.text)
	ed._youtube._upload.set_pressed_no_signal(false)
	up.start()
	_ok(step.state(up._feed) == "missing", "control: an export that does not go up starts nothing")
	ed._youtube._upload.set_pressed_no_signal(true)
	up.start()
	up.refresh()
	var r: Dictionary = up._step_rows[step.key]
	_ok(step.state(up._feed) == "failed" and not up._busy() and (r["state"] as Label).text.contains("read-only"),
		"one that goes up starts it - here refused, read-only, and said on its row (%s)" % (r["state"] as Label).text)
	step._errors.clear()
	AgentJobs._ended["text-youtube-check-note"] = {"ok": true, "text": "{\"tags\": [\"quick brown fox\", \"lazy dog\", \"reading\"]}"}
	step._jobs[folder] = {"id": "text-youtube-check-note", "feed": up._feed, "stamp": up._feed.stamp()}
	_ok(up._busy(), "while its job runs, an export waits for it")
	up.refresh()
	r = up._step_rows[step.key]
	_ok(not up._busy() and (r["state"] as Label).text == "✓ 3 tags: quick brown fox, lazy dog, reading" and not (r["redo"] as Button).disabled,
		"landed: its ✓, its tags, its ⟳ (%s)" % (r["state"] as Label).text)
	_ok(ed._doc.field("tags") == "quick brown fox, lazy dog, reading" and Array(up._tags_field.get_tags()) == ["quick brown fox", "lazy dog", "reading"]
		and ed.upload_meta("").get("tags") == ["quick brown fox", "lazy dog", "reading", "theirs"],
		"they replace the note's tags: on the card, and going up (%s)" % ed._doc.field("tags"))
	ed._text.text = "Words written again."
	up.refresh()
	_ok(step.state(up._feed) == "missing" and (up._step_rows[step.key]["state"] as Label).text.contains("written again"),
		"words written again make them stale: the next export that goes up writes new ones")
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
func _step_row(show: Node) -> Dictionary:
	for w in show._row_widgets:
		if (w as Dictionary).get("step") != null:
			return w
	return {}


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
	ed.workspace = "cards"
	ed._build_panel()
	var show = ed._block_cards["cards"]      # the episode's card ([EpisodeCard])
	_ok(ed._youtube == null and show._yt_desc == null and ed.upload_meta("").is_empty(),
		"a show with no YouTube card has no description or tags to edit, and uploads nothing")
	ed._panel.plus.about_to_popup.emit()
	var pop: PopupMenu = ed._panel.plus.get_popup()
	# "+" lists what a note can have; on a show of cards the clock and the presentation are taken,
	# so YouTube is the one thing it can be given, and the rest is grayed with its reason
	var at := -1
	var lit: Array = []
	for i in pop.item_count:
		var key := str(pop.get_item_metadata(i))
		if key == "youtube":
			at = i
		if not key.is_empty() and not pop.is_item_disabled(i):
			lit.append(key)
	_ok(at >= 0 and lit == ["youtube"], "its \"+\" offers YouTube, and nothing else that can be attached to a show of cards (%s)" % str(lit))
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
	_ok(not twice and left.is_empty(), "and \"+\" does not offer it twice - nothing it lists can be attached now (%s)" % str(left))
	ed._youtube._upload.set_pressed_no_signal(true)
	# NOT THE AUTHOR'S SHOW. A panel comes up synced to whatever document the person running
	# this has open, and DocSource.set_field writes a synced document at once - so this gate read
	# the author's real show (and failed on its tags) and could have written into it.
	ed._doc._sync = false
	ed._doc._fields = {}
	var ep := CardEpisode.open("panel-check", 21)
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
	var doc: Dictionary = ed._doc_capture()["cards"]
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
	_ok(is_equal_approx(float(meta.get("thumbnail_at", -1.0)), show.thumbnail_moment(show._take_intro(""))),
		"and the title screen's moment for its thumbnail")
	ed._doc._fields["title"] = "Truthful Tarot"
	_ok(ed.upload_meta("").get("title") == "Truthful Tarot: My Own Title" and ed.export_name() == "My Own Title",
		"the upload's title is the show's name, then the episode's - the file keeps the episode's alone")
	show._refresh_upload_note()
	_ok(ed._youtube._preview.text.begins_with("Goes up as \"Truthful Tarot: My Own Title\""), "the card shows the title as it goes up")
	# THE PRODUCER IS SHOWN THAT LINE before it names the next episode
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
	# THE BYLINE, on the document card right under Title
	var card = ed._writer
	var edits: Array = card._field_edits.keys()
	_ok(edits.find("byline") == edits.find("title") + 1, "the byline is the card's field right under Title (%s)" % str(edits))
	(card._field_edits["byline"] as LineEdit).text = "with Pen & Ink"
	card._commit_field("byline")
	_ok(ed._doc.field("byline") == "with Pen & Ink" and ed.book_document()["byline"] == "with Pen & Ink",
		"it is the show's `byline:`, handed to the title screen")
	# A NEW EPISODE: the show's values at once
	show._knobs["seed"] = 22
	show._open_episode()
	ed._writer._refresh_handed()
	_ok(show._yt_desc.text == "Mine." and Array(show._yt_tags.get_tags()) == ["tarot", "satire"] and show._yt_desc.editable,
		"a new episode shows the show's description and tags at once")
	_ok(episode.text.is_empty() and not episode.editable and episode.placeholder_text == "named with the episode",
		"its Episode waits for its plan, saying so - never the last episode's")
	var other := CardEpisode.open("panel-check", 23)
	other.write_json("plan", {"episode_title": "Another Episode"})
	var take := ProjectSettings.globalize_path(ROOT + "_files/take_9.wav")
	show._taken = {"take": take, "episode": ep}
	show._knobs["seed"] = 23
	show._open_episode()
	ed._writer._refresh_handed()
	_ok(episode.text == "Another Episode" and not ed._doc_capture()["cards"].has("episode_title")
		and show._yt_desc.text == "Mine.", "an episode with a plan shows its own title; the description stays the show's")
	_ok(ed.upload_meta(take).get("title") == "My Own Title" and ed.upload_meta("").get("title") == "Another Episode",
		"an export's upload describes the episode it rendered, not the one picked since")
	_ok(not DirAccess.dir_exists_absolute(CardEpisode.open("panel-check", 22).dir), "nothing was written for the new episode")
	# THE STEPS THE NOTE'S OTHER CARDS ADD: the YouTube card's tags, on the Episode card, neither naming the other
	var tags_step = ed._youtube.episode_steps()[0]
	_ok(ed.episode_steps() == [tags_step], "the panel holds the step the YouTube card offers")
	show._refresh_rows()
	_ok(_step_row(show).is_empty(), "box clear, the Episode card lists no tags")
	ed._youtube._write_tags.button_pressed = true
	show._refresh_rows()
	var row := _step_row(show)
	_ok(not row.is_empty() and show._row_widgets.back() == row and String(show._row_widgets[show._row_widgets.size() - 2]["kind"]) == "Close",
		"ticked, its row stands under the Close")
	show._tick_steps()
	_ok(tags_step.host == "the Episode card" and tags_step.shown == show._feed and tags_step.shown.folder() == show._episode.dir,
		"the card says it lists the step, and which episode it shows")
	show._refresh_rows()
	_ok((row["status"] as Label).text == "·" and (row["text"] as Label).text == tags_step.waits and (row["redo"] as MenuButton).disabled
		and show._steps_missing(), "before the reading is written the row waits, its ⟳ too")
	show._episode.write_text("script", "<!-- table: draw 1 -->\nThe first card is the moon.")
	_ok(show._feed.words() == "The first card is the moon.", "the step reads the reading as it is said, its marks out (%s)" % show._feed.words())
	show._steps_asked = true
	show._tick_steps()
	show._refresh_rows()
	_ok(not show._steps_asked and tags_step.state(show._feed) == "failed" and (row["status"] as Label).text == "✗"
		and (row["text"] as Label).text.contains("read-only"),
		"once the card's own steps are done, Generate makes it - here refused, read-only, and said on its row")
	tags_step._errors.clear()
	_ok(_tag_fields(ed._youtube) == 1 and ed.upload_meta("").get("tags") == ["tarot", "satire"],
		"the YouTube card shows one list of tags, and it is what goes up")
	AgentJobs._ended["text-youtube-check-cards"] = {"ok": true, "text": "{\"tags\": [\"the moon\", \"night\", \"cards\"]}"}
	tags_step._jobs[show._feed.folder()] = {"id": "text-youtube-check-cards", "feed": show._feed, "stamp": show._feed.stamp()}
	tags_step.tick()
	show._refresh_rows()
	_ok((row["status"] as Label).text == "✓" and (row["text"] as Label).text == "3 tags: the moon, night, cards"
		and not (row["redo"] as MenuButton).disabled and (row["redo"] as MenuButton).get_popup().get_item_text(0) == tags_step.again
		and not show._steps_missing(), "made: its ✓, its tags and its ⟳ to write them again")
	_ok(ed._doc.field("tags") == "the moon, night, cards" and Array(show._yt_tags.get_tags()) == ["the moon", "night", "cards"]
		and _tag_fields(ed._youtube) == 1 and ed.upload_meta("").get("tags") == ["the moon", "night", "cards"],
		"landed, they replace the show's tags: still one list on the card, and what goes up (%s)" % ed._doc.field("tags"))
	_ok(ed.upload_meta(take).get("tags") == ["the moon", "night", "cards"], "an export of another episode goes up with the same list")
	ed._youtube._write_tags.button_pressed = false
	show._refresh_rows()
	_ok(_step_row(show).is_empty() and ed.upload_meta("").get("tags") == ["the moon", "night", "cards"],
		"box cleared: the row goes, and the list stays as it was written")
	_ok(show.thumbnail_moment(9.0) == 3.6 and show.thumbnail_moment(3.0) == 1.5 and show.thumbnail_moment(0.5) == 1.5,
		"the thumbnail is taken with the name up and the table still out of focus")
	var args: PackedStringArray = load("res://src/export/exporter.gd").thumbnail_args("/v/a b.mp4", "/v/a b.thumbnail.jpg", 3.6)
	_ok(Array(args) == ["-y", "-nostdin", "-loglevel", "error", "-ss", "3.600", "-i", "/v/a b.mp4", "-frames:v", "1",
		"-vf", "scale=1280:720:flags=lanczos", "-q:v", "2", "/v/a b.thumbnail.jpg"], "one frame, at the moment, 1280x720")
	ed.free()
	return true


## EACH EPISODE'S OWN TAGS: the step the YouTube card adds to the episodes a note makes, and the box.
func _episode_tags() -> bool:
	var Tags: GDScript = load("res://src/export/youtube_tags.gd")
	# THE ANSWER, LANDED
	var got: Variant = Tags.land(TextGen.extract_json("```json\n{\"tags\": [\"#Readings\", \"readings\", \"the tower\", \"a, b\", \" \"]}\n```"))
	_ok(got is Dictionary and (got as Dictionary)["tags"] == ["Readings", "the tower", "a b"],
		"an answer's tags are cleaned - no hashtag sign, no comma inside - each kept once whatever its case (%s)" % str(got))
	_ok(Tags.land(["one", "two", "three"]) is Dictionary, "a bare list is an answer too")
	_ok(Tags.land(null) is String and Tags.land({"tags": "one, two, three"}) is String and Tags.land({"tags": ["one", "#", "two"]}) is String,
		"the controls: no JSON, no list, and too few usable tags are not kept")
	# WHAT THE WRITER IS TOLD
	Rules.clear()
	var p: Dictionary = Tags.prompt("The Show", "The Tower Falls", "A reading of three.", PackedStringArray(["readings", "cards"]),
		"The first card is the tower.")
	var text := String(p["prompt"])
	_ok(Rules.missing.is_empty() and not text.contains("{{") and not String(p["system"]).is_empty()
		and text.contains("The first card is the tower.") and text.contains("THIS VIDEO'S TITLE: The Tower Falls")
		and text.contains("ITS DESCRIPTION: A reading of three.") and text.contains("readings, cards")
		and text.contains("THE SHOW'S TAGS NOW, which yours replace: readings, cards") and text.contains(str(YouTube.TAGS_MAX)),
		"the writer is told the show, the episode's title, description and words, the note's tags (which its answer replaces) and YouTube's limit (%s)" % str(Rules.missing))
	var bare := String(Tags.prompt("", "", "", PackedStringArray(), "Words.")["prompt"])
	_ok(not bare.contains("THE SHOW:") and not bare.contains("TAGS NOW") and not bare.contains("DESCRIPTION") and bare.contains("Words."),
		"the control: what an episode does not have is not said")
	# THE STEP
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
	# THE CONTROL: a note that cannot keep tags - the answer is not landed, and the step says why
	feed.refuse = "the note is gone"
	AgentJobs._ended["text-youtube-check-0"] = {"ok": true, "text": "{\"tags\": [\"the tower\", \"cards\", \"readings\"]}"}
	step._jobs[feed.folder()] = {"id": "text-youtube-check-0", "feed": feed, "stamp": feed.stamp()}
	step._tries[feed.folder()] = 2
	step.tick()
	_ok(step.state(feed) == "failed" and step.said(feed) == "the note is gone" and Array(feed.note_tags) == ["the note's"]
		and not FileAccess.file_exists(feed.folder().path_join("youtube_tags.json")),
		"the control: a note that cannot keep them fails the step, saying why, and nothing is kept (%s)" % step.said(feed))
	step._errors.clear()
	step._tries.clear()
	feed.refuse = ""
	AgentJobs._ended["text-youtube-check-1"] = {"ok": true, "text": "{\"tags\": [\"the tower\", \"cards\", \"readings\", \"fortune\"]}"}
	step._jobs[feed.folder()] = {"id": "text-youtube-check-1", "feed": feed, "stamp": feed.stamp()}
	_ok(step.busy(feed) and step.state(feed) == "queued", "while its job is out, it is being made")
	step.tick()
	_ok(step.state(feed) == "ready" and step.fresh(feed) and Array(feed.note_tags) == ["the tower", "cards", "readings", "fortune"]
		and step.said(feed) == "4 tags: the tower, cards, readings, fortune" and not step.busy(feed),
		"a job that ended replaces the note's tags, and the step is made (%s)" % step.said(feed))
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
	# THE BOX ON THE CARD
	var ex = load("res://src/export/exporter.gd").new()
	ex._build_ui()
	var card = load("res://src/export/youtube_card.gd").new()
	card.exporter = ex
	var names = _names({"title": "The Show", "episode": "The Tower Falls"})
	card.name_from(names)
	card.apply({"upload": true})
	var mine = card.episode_steps()[0] if card.episode_steps().size() == 1 else null
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
	mine.listed("the Episode card", feed)
	card._refresh_tags()
	_ok(card._tags_note.text.contains("replaced the tags above") and card._tags_note.text.contains("the Episode card"),
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


## A real show file: opened, seeded, its byline set on the card, written by the document's own writer, read
## back - and opened again by another panel, whose new episode is filled from it at once.
func _doc_file() -> bool:
	var ed = load("res://src/reading/reading_panel.gd").new()
	ed.workspace = "cards"
	ed._build_panel()
	var epi = ed._block_cards["cards"]      # the episode's card ([EpisodeCard])
	ed._attach("youtube")
	var ep := CardEpisode.open("doc-check", 31)
	ep.write_json("plan", {"episode_title": "Episode Thirty-One", "description": "First paragraph.\n\nSecond: with a colon.",
		"tags": ["tarot", "pick a card"], "spread": {"positions": [{"name": "Past"}]}})
	var body := "# The brief\n\nWhat the show is.\n"
	var path := _file("show.md", "---\ntitle: Doc Check Show\nghost:\n  cards:\n    show: doc-check\n    seed: 31\n---\n" + body)
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
	var show: Dictionary = (data as Dictionary).get("cards", {}) if data is Dictionary else {}
	_ok(not show.has("episode_title") and show.get("description") == "First paragraph.\n\nSecond: with a colon."
		and not show.has("youtube"), "the block holds the show's description, whole, and no episode's title or record")
	var yt: Variant = (data as Dictionary).get("youtube") if data is Dictionary else null
	_ok(yt is Dictionary and (yt as Dictionary).get("privacy") == "private" and (yt as Dictionary).get("upload") == false,
		"the YouTube card's block is the file's too, beside the show's (%s)" % str(yt))
	_ok(raw.ends_with("---\n" + body), "the body is untouched")
	ed.free()
	# ANOTHER PANEL OPENS THE FILE, AND MAKES A NEW EPISODE: filled from the file at once
	var again = load("res://src/reading/reading_panel.gd").new()
	again.workspace = "cards"
	again._build_panel()
	var again_show = again._block_cards["cards"]
	again._attach("youtube")
	again._doc._on_picked(path)
	again_show._knobs["seed"] = 99
	again_show._open_episode()
	_ok(again._writer.field_value("episode").is_empty() and again_show._yt_desc.text == "First paragraph.\n\nSecond: with a colon."
		and Array(again_show._yt_tags.get_tags()) == ["tarot", "pick a card"] and again._writer._field_edits["byline"].text == "with Pen & Ink",
		"a new episode is filled from the file at once: description, tags, byline - its Episode its own plan's")
	again.free()
	return true
