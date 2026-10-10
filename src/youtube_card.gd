extends VBoxContainer
class_name YouTubeCard

## YouTubeCard - the YouTube component's card (2026-10-07, the user: "add a little '+' button near
## those labels... 'youtube' should be an option. When we add it, a new card is created"): whether
## an export goes up, what it is called, who may see it and the playlist it joins - and the Google
## client and the sign-in an upload needs, which used to live in the export button's menu. Its block
## in a document is `youtube:`.
##
## THE TITLE IS A TEMPLATE ([method YouTube.expand_title]): `%title%` is the note's title (a show's,
## in the Cards mode), `%episode%` the episode's, `%date%` today's - so one note makes many videos,
## each named as it goes up. The panel says what the macros are worth ([member values]) and adds
## what it alone knows (a show's description and tags, its thumbnail's moment) through [member extra],
## a slot under the card's own rows, and [method meta].
##
## TICKING "UPLOAD AFTER EXPORT" SETS UPLOADS UP as far as they need, visibly: the Google client file
## the first time, then the sign-in - and the box ticks once both are done (a cancel leaves it clear).
## A PLAYLIST takes more of the account than an upload, so the wider sign-in is asked for only when
## the list is first loaded ([constant YouTube.PLAYLIST_SCOPE]). The dialogs are the exporter's,
## beside the upload that waits on them (see [method Exporter.youtube_sign_in]).

const YouTube := preload("res://src/youtube.gd")

## The block this card keeps under a document's `ghost:` key.
const KEY := "youtube"
## A new card's block: nothing goes up until the box is ticked, and then privately.
const DEFAULTS := {"upload": false, "title": YouTube.TITLE_TEMPLATE, "privacy": YouTube.PRIVACY,
	"playlist": "", "playlist_title": ""}
const TITLE_TIP := ("The video's title. %title% is the note's title, %episode% the episode's, %seed% its seed, %date% "
	+ "today's; what a missing one leaves (a dangling \": \") goes, and a name is never said twice. "
	+ "YouTube takes 100 characters.")

signal noted(msg: String)

## Set by the panel: () -> Dictionary, what the title's macros are worth now (`title`, `episode`).
var values: Callable
## Where the panel puts rows of its own (a show's description and tags), under the card's.
var extra: VBoxContainer
## The exporter whose sign-in and upload this card drives: Chrome's, unless a gate hands it one.
var exporter: Node

var _upload: CheckBox
var _title: LineEdit
var _preview: Label
var _privacy: OptionButton
var _playlist: OptionButton
var _reload: Button
var _account: Label
var _sign: Button
var _client: Button
var _resume: Button
var _state: Label
## The playlist the block names, kept whole even before the list is loaded: `{id, title}`.
var _list := {"id": "", "title": ""}
var _lists: Array = []          # the channel's playlists, as last loaded
var _loading := false
var _poll := 0.0
var _seen := []                 # what the account rows were last drawn for


func _init() -> void:
	add_theme_constant_override("separation", 8)
	_upload = CheckBox.new()
	_upload.text = "Upload after export"
	_upload.add_theme_font_size_override("font_size", 12)
	_upload.tooltip_text = ("Once an export of this note is saved, upload it to your YouTube channel. "
		+ "Ticking it the first time asks for your Google OAuth client file (the JSON from Google Cloud), "
		+ "then opens your browser to sign in.")
	_upload.toggled.connect(_on_tick)
	add_child(_upload)
	_title = LineEdit.new()
	_title.placeholder_text = YouTube.TITLE_TEMPLATE
	_title.tooltip_text = TITLE_TIP
	_title.text = YouTube.TITLE_TEMPLATE
	_title.text_changed.connect(func(_t: String) -> void: refresh())
	_row("Title", _title)
	_preview = _small("")
	add_child(_preview)
	_privacy = OptionButton.new()
	_privacy.fit_to_longest_item = false
	_privacy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in YouTube.PRIVACIES:
		_privacy.add_item(String(YouTube.PRIVACIES[k]))
		_privacy.set_item_metadata(_privacy.item_count - 1, k)
	_privacy.tooltip_text = ("Who may see the video: only you (Private), anyone with the link (Unlisted), "
		+ "or everyone (Public). A Google Cloud project YouTube has not audited keeps every upload "
		+ "private whatever this says.")
	_privacy.item_selected.connect(func(_i: int) -> void: refresh())
	_row("Visibility", _privacy)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	_playlist = OptionButton.new()
	_playlist.fit_to_longest_item = false
	_playlist.clip_text = true
	_playlist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_playlist.tooltip_text = ("The playlist the video is added to once it is up. ↻ loads your channel's "
		+ "playlists - the first time, that signs in again, asking to see and manage them.")
	_playlist.item_selected.connect(_on_playlist)
	prow.add_child(_playlist)
	_reload = Button.new()
	_reload.text = "↻"
	_reload.tooltip_text = "Load your channel's playlists."
	_reload.focus_mode = Control.FOCUS_NONE
	_reload.pressed.connect(load_playlists)
	prow.add_child(_reload)
	_row("Playlist", prow)
	_fill_playlists()
	extra = VBoxContainer.new()
	extra.add_theme_constant_override("separation", 8)
	add_child(extra)
	add_child(HSeparator.new())
	_account = _small("")
	add_child(_account)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 6)
	add_child(arow)
	_sign = Button.new()
	_sign.focus_mode = Control.FOCUS_NONE
	_sign.add_theme_font_size_override("font_size", 12)
	_sign.pressed.connect(_on_sign)
	arow.add_child(_sign)
	_client = Button.new()
	_client.focus_mode = Control.FOCUS_NONE
	_client.add_theme_font_size_override("font_size", 12)
	_client.pressed.connect(_on_client)
	arow.add_child(_client)
	_resume = Button.new()
	_resume.focus_mode = Control.FOCUS_NONE
	_resume.add_theme_font_size_override("font_size", 12)
	_resume.clip_text = true
	_resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resume.tooltip_text = ("An export's upload was cut off - by a quit, a lapsed sign-in or a dropped "
		+ "connection. It carries on from where YouTube says it stopped.")
	_resume.pressed.connect(_on_resume)
	add_child(_resume)
	_state = _small("")
	add_child(_state)


func _ready() -> void:
	refresh()


func _row(label: String, field: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 11)
	l.modulate = Color(1, 1, 1, 0.7)
	return l


## THE ACCOUNT ROWS FOLLOW THE FILES BY LOOKING, twice a second: a sign-in finishes in the exporter's
## dialog, an upload waits or goes up from any note, and none of it signals this card.
func _process(dt: float) -> void:
	_poll -= dt
	if _poll > 0.0:
		return
	_poll = 0.5
	refresh()


## The block for a document.
func capture() -> Dictionary:
	return {"upload": _upload.button_pressed, "title": _title.text, "privacy": _privacy_key(),
		"playlist": String(_list["id"]), "playlist_title": String(_list["title"])}


## ...and back. A key the block does not name keeps the card's default; a privacy YouTube does not
## know is Private.
func apply(block: Dictionary) -> void:
	var b := DEFAULTS.duplicate()
	b.merge(block, true)
	_upload.set_pressed_no_signal(bool(b["upload"]))
	if _title.text != str(b["title"]):
		_title.text = str(b["title"])
	var p := str(b["privacy"])
	for i in _privacy.item_count:
		if String(_privacy.get_item_metadata(i)) == p:
			_privacy.select(i)
	if not YouTube.PRIVACIES.has(p):
		_privacy.select(0)
	_list = {"id": str(b["playlist"]), "title": str(b["playlist_title"])}
	_fill_playlists()
	refresh()


func _privacy_key() -> String:
	return String(_privacy.get_item_metadata(maxi(0, _privacy.selected))) if _privacy.item_count > 0 else YouTube.PRIVACY


## Is an export of this note to go up?
func ticked() -> bool:
	return _upload.button_pressed


## The title as it goes up: the template, its macros filled from [param given] - else from
## [member values], as the panel stands now.
func title_now(given := {}) -> String:
	var v: Variant = given if not given.is_empty() else (values.call() if values.is_valid() else {})
	var t := _title.text if not _title.text.strip_edges().is_empty() else YouTube.TITLE_TEMPLATE
	return YouTube.fit_title(YouTube.expand_title(t, v if v is Dictionary else {}))


## WHAT AN UPLOAD SAYS (see [member Exporter.upload_provider]): [param base] - the panel's own part,
## its description, tags, thumbnail moment and record, and the macros' `values` when they are not the
## panel's as it stands now (an episode an export rendered) - with this card's title, privacy and
## playlist (its id and title, which the description names) laid over it. {} when nothing is to go
## up: the box is clear, or the panel has nothing ({}).
func meta(base: Dictionary) -> Dictionary:
	if not ticked() or base.is_empty():
		return {}
	var out := base.duplicate()
	var given: Variant = out.get("values", {})
	out.erase("values")
	out["title"] = title_now(given if given is Dictionary else {})
	out["privacy"] = _privacy_key()
	out["playlist"] = String(_list["id"])
	out["playlist_title"] = String(_list["title"])
	return out


## The line under the title: how it goes up, and where this note's episode already is.
func refresh() -> void:
	if _preview == null:
		return
	var t := title_now()
	_preview.text = ("Goes up as \"%s\"" % t) if not t.is_empty() else "The title is empty: the export's file name is used."
	_refresh_account()


func _refresh_account() -> void:
	var ex := _exporter()
	var has_client := YouTube.has_client()
	var signed := YouTube.signed_in()
	var lists := YouTube.granted(YouTube.PLAYLIST_SCOPE)
	var p := YouTube.pending()
	var busy := ex != null and bool(ex.youtube_busy())
	var yt: Node = ex.youtube() if ex != null else null
	var phase := String(yt.phase) if yt != null else ""
	var pct := int(round(float(yt.progress) * 100.0)) if yt != null else 0
	var now := [has_client, signed, lists, p.get("file", ""), busy, phase, pct, ex != null, _loading]
	if now == _seen:
		return
	_seen = now
	if ex == null:
		_account.text = "Uploads are made by the export, which this window does not have."
	elif not has_client:
		_account.text = ("No Google client yet: uploads go through your own Google Cloud project's "
			+ "\"Desktop app\" OAuth client. Import its JSON file once; Ghost Notes keeps it.")
	elif not signed:
		_account.text = "Not signed in to YouTube. Signing in opens your browser."
	else:
		_account.text = "Signed in to YouTube%s." % (", playlists too" if lists else " (uploads only)")
	_sign.visible = ex != null and has_client
	_sign.text = "Sign out" if signed else "Sign in"
	_sign.tooltip_text = ("Forget the sign-in and ask Google to revoke it. The client file stays." if signed
		else "Open your browser to sign in to the YouTube channel uploads go to.")
	_client.visible = ex != null
	_client.text = "Replace client…" if has_client else "Import client…"
	_client.tooltip_text = ("Import another Google OAuth client file (a \"Desktop app\" client's JSON). It "
		+ "replaces the one Ghost Notes keeps; a sign-in made with a different client is forgotten."
		if has_client else "Import your Google OAuth client file (a \"Desktop app\" client's JSON from "
		+ "Google Cloud). It stays on this machine, readable only by you.")
	var waiting := not p.is_empty() and FileAccess.file_exists(str(p.get("file", "")))
	_resume.visible = ex != null and waiting and not busy
	_resume.text = "Resume the upload of %s" % str(p.get("file", "")).get_file()
	_reload.disabled = _loading or ex == null
	if busy and phase == "uploading":
		_state.text = "Uploading … %d%%" % pct
	elif busy:
		_state.text = "An upload waits for its sign-in."
	elif _loading:
		_state.text = "Loading your playlists…"
	else:
		_state.text = ""
	_state.visible = not _state.text.is_empty()


func _exporter() -> Node:
	if exporter != null:
		return exporter
	var ch := Chrome.of(self)
	return ch.exporter if ch != null and ch.exporter != null and ch.exporter.has_method("youtube_sign_in") else null


## TICKED: set uploads up first - the box shows ticked only once the client is kept and the sign-in
## may do what this card asks (a playlist chosen asks for more). Cleared: simply cleared.
func _on_tick(on: bool) -> void:
	if not on:
		refresh()
		return
	var scopes := _scopes()
	if YouTube.has_client() and YouTube.signed_in() and YouTube.missing_scopes(scopes).is_empty():
		refresh()
		return
	_upload.set_pressed_no_signal(false)
	var ex := _exporter()
	if ex == null:
		noted.emit("Uploads are made by the export, which this window does not have.")
		return
	var done := func() -> void:
		if is_instance_valid(self):
			_upload.set_pressed_no_signal(true)
			refresh()
	ex.youtube_sign_in(done, scopes)


func _scopes() -> Array:
	return [YouTube.SCOPE, YouTube.PLAYLIST_SCOPE] if not String(_list["id"]).is_empty() else [YouTube.SCOPE]


func _on_sign() -> void:
	var ex := _exporter()
	if ex == null:
		return
	if YouTube.signed_in():
		ex.youtube_sign_out()
	else:
		ex.youtube_sign_in(Callable(), _scopes())
	_seen = []


func _on_client() -> void:
	var ex := _exporter()
	if ex != null:
		ex.youtube_import_client(func() -> void: _seen = [])


func _on_resume() -> void:
	var ex := _exporter()
	if ex != null:
		ex.youtube_resume()
	_seen = []


# --- the playlist --------------------------------------------------------------------------------

## THE CHANNEL'S PLAYLISTS, loaded on ↻: a sign-in that may see them first, when the kept one may
## only upload. The one the block names stays picked; one that has gone from the channel stays
## listed, marked, until another is picked.
func load_playlists() -> void:
	var ex := _exporter()
	if ex == null or _loading:
		return
	if not YouTube.granted(YouTube.PLAYLIST_SCOPE):
		var again := func() -> void:
			if is_instance_valid(self):
				load_playlists()
		ex.youtube_sign_in(again, [YouTube.SCOPE, YouTube.PLAYLIST_SCOPE])
		return
	_loading = true
	_seen = []
	var got: Dictionary = await ex.youtube().playlists()
	if not is_instance_valid(self):
		return
	_loading = false
	_seen = []
	if got.has("error"):
		noted.emit("⚠  The playlists could not be loaded: %s" % got["error"])
		return
	_lists = got["playlists"]
	_fill_playlists()
	noted.emit("%d playlist%s on the channel." % [_lists.size(), "" if _lists.size() == 1 else "s"])


## The dropdown: None, the loaded playlists, and the block's own when it is not among them.
func _fill_playlists() -> void:
	_playlist.clear()
	_playlist.add_item("None")
	_playlist.set_item_metadata(0, {"id": "", "title": ""})
	var at := 0
	var listed := false
	for pl in _lists:
		var d: Dictionary = pl
		var extra_words := " (%s)" % String(d.get("privacy", "")) if String(d.get("privacy", "")) not in ["", "public"] else ""
		_playlist.add_item(String(d.get("title", "")) + extra_words)
		_playlist.set_item_metadata(_playlist.item_count - 1, {"id": String(d["id"]), "title": String(d.get("title", ""))})
		if String(d["id"]) == String(_list["id"]):
			at = _playlist.item_count - 1
			listed = true
	if not String(_list["id"]).is_empty() and not listed:
		var name := String(_list["title"]) if not String(_list["title"]).is_empty() else String(_list["id"])
		_playlist.add_item(name + ("  (not on the channel)" if not _lists.is_empty() else ""))
		_playlist.set_item_metadata(_playlist.item_count - 1, _list.duplicate())
		at = _playlist.item_count - 1
	_playlist.select(at)


func _on_playlist(i: int) -> void:
	var d: Variant = _playlist.get_item_metadata(i)
	_list = (d as Dictionary).duplicate() if d is Dictionary else {"id": "", "title": ""}
	# a playlist needs the wider sign-in at upload time: ask for it now, while the person is here
	if ticked() and not YouTube.missing_scopes(_scopes()).is_empty():
		var ex := _exporter()
		if ex != null:
			ex.youtube_sign_in(Callable(), _scopes())
	refresh()
