extends VBoxContainer

## TikTok rows - the Upload card's TikTok rows ([YouTubeCard]), shown while TikTok is one of the card's targets: the account and
## the app's client, how the video goes up ([constant TikTok.MODES]) and, for a post, who may see it and what viewers may do.
## Its keys sit in the card's block beside the card's own (`tiktok_mode`, `tiktok_privacy`, ...).
##
## A post's rows follow TikTok's Direct Post rules: who may see it is picked from what the account offers ([method
## TikTok.creator_info], asked quietly once the account may post) and starts unpicked, comments, Duets and Stitches start off
## and gray out where the account turns them off, and the line TikTok's music terms ask for shows above the post. The video is
## labeled AI-generated unless cleared (the voice is synthesized, and pictures may be painted by a model). A draft needs none of
## that: the author finishes it in the TikTok app.
##
## The caption is the card's title, description and tags (as hashtags), [method TikTok.caption]. What keeps an upload from
## going up is [method why_not], which the card says under its title and the export refuses on before it renders. The sign-in
## runs in the exporter's TikTok node ([method Exporter.tiktok]), so it outlives the card. Loaded by path (no class_name).

const TikTok := preload("res://src/export/tiktok.gd")

## This section's keys in the card's block, and a new card's values.
const DEFAULTS := {"tiktok_mode": TikTok.MODE, "tiktok_privacy": "", "tiktok_comments": false, "tiktok_duet": false,
	"tiktok_stitch": false, "tiktok_aigc": true, "tiktok_brand_own": false, "tiktok_brand_paid": false}
## How long what the account allows a post is trusted before it is asked again, in seconds.
const CREATOR_FRESH := 600.0

var _card: YouTubeCard
var _account: Label
var _sign: Button
var _again: Button
var _out: Button
var _client: Button
var _mode: OptionButton
var _post_rows: VBoxContainer
var _privacy: OptionButton
var _comments: CheckBox
var _duet: CheckBox
var _stitch: CheckBox
var _aigc: CheckBox
var _brand_own: CheckBox
var _brand_paid: CheckBox
var _terms: LinkButton
var _state: Label
var _resume: Button
var _dialog: ConfirmationDialog
var _key: LineEdit
var _secret: LineEdit
var _privacy_want := ""         # the privacy the block names, kept while the account's options are not known
var _asking := false            # what the account allows is being asked
var _said := ""                 # what the last sign-in or question to TikTok said went wrong
var _seen := []


func _init(card: YouTubeCard) -> void:
	_card = card
	add_theme_constant_override("separation", 8)
	var head := Label.new()
	head.text = "TikTok"
	head.add_theme_font_size_override("font_size", 12)
	add_child(head)
	_account = _small("")
	add_child(_account)
	var arow := HFlowContainer.new()
	arow.add_theme_constant_override("h_separation", 6)
	add_child(arow)
	_sign = _button("Sign in", _on_sign)
	arow.add_child(_sign)
	_again = _button("Open the page again", func() -> void:
		var tt := _node()
		if tt != null:
			tt.reopen_sign_in())
	_again.tooltip_text = "The sign-in page may have opened behind another window."
	arow.add_child(_again)
	_out = _button("Sign out", _on_sign_out)
	_out.tooltip_text = "Forget the TikTok account here and ask TikTok to revoke the sign-in."
	arow.add_child(_out)
	_client = _button("Client…", _open_client)
	arow.add_child(_client)
	_mode = OptionButton.new()
	_mode.fit_to_longest_item = false
	var tips := PackedStringArray()
	for k in TikTok.MODES:
		_mode.add_item(Registry.label(TikTok.MODES, k))
		_mode.set_item_metadata(_mode.item_count - 1, k)
		tips.append("%s: %s" % [Registry.label(TikTok.MODES, k), Registry.blurb(TikTok.MODES, k)])
	_mode.tooltip_text = "\n\n".join(tips)
	_mode.item_selected.connect(func(_i: int) -> void: _changed())
	_row("Goes up as", _mode, self)
	_post_rows = VBoxContainer.new()
	_post_rows.add_theme_constant_override("separation", 8)
	add_child(_post_rows)
	_privacy = OptionButton.new()
	_privacy.fit_to_longest_item = false
	_privacy.tooltip_text = ("Who may see the post, from what the account allows now. TikTok asks that it be picked for "
		+ "each note, never set by default. An app TikTok has not audited may post only as Only me, to a private account.")
	_privacy.item_selected.connect(func(i: int) -> void:
		_privacy_want = String(_privacy.get_item_metadata(i))
		_changed())
	_row("Who sees it", _privacy, _post_rows)
	var allow := HFlowContainer.new()
	allow.add_theme_constant_override("h_separation", 12)
	_post_rows.add_child(allow)
	_comments = _check("Allow comments", "Let viewers comment on the post.", allow)
	_duet = _check("Allow Duets", "Let viewers make a Duet with the post.", allow)
	_stitch = _check("Allow Stitches", "Let viewers use part of the post in a Stitch.", allow)
	var marks := HFlowContainer.new()
	marks.add_theme_constant_override("h_separation", 12)
	_post_rows.add_child(marks)
	_aigc = _check("AI-generated", ("TikTok labels the post \"Creator labeled as AI-generated\": the voice is synthesized, "
		+ "and the pictures may be painted by a model."), marks)
	_aigc.set_pressed_no_signal(true)
	_brand_own = _check("Your brand", "The post promotes yourself or your own business: TikTok labels it Promotional content.", marks)
	_brand_paid = _check("Branded content", ("The post promotes another brand or a third party in return for something: "
		+ "TikTok labels it Paid partnership, and it cannot be Only me."), marks)
	_terms = LinkButton.new()
	_terms.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	_terms.add_theme_font_size_override("font_size", 11)
	_terms.uri = TikTok.MUSIC_TERMS
	_post_rows.add_child(_terms)
	_state = _small("")
	add_child(_state)
	_resume = _button("", _on_resume)
	_resume.clip_text = true
	_resume.tooltip_text = "An export's TikTok upload was cut off. It is sent again from the start."
	add_child(_resume)
	_build_client_dialog()


func _build_client_dialog() -> void:
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Your TikTok app"
	_dialog.ok_button_text = "Keep"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(460, 0)
	_dialog.add_child(box)
	var how := Label.new()
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.text = ("Uploads go through your own app on TikTok for Developers (developers.tiktok.com): add Login Kit "
		+ "with the Desktop platform and the Content Posting API to it, and register this redirect URI:\n\n    %s\n\n"
		% TikTok.REDIRECT + "Then copy its Client key and Client secret here. They stay on this machine, readable only by you.")
	box.add_child(how)
	var copy := Button.new()
	copy.text = "Copy the redirect URI"
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(TikTok.REDIRECT))
	box.add_child(copy)
	_key = LineEdit.new()
	_key.placeholder_text = "Client key"
	box.add_child(_key)
	_secret = LineEdit.new()
	_secret.placeholder_text = "Client secret"
	_secret.secret = true
	box.add_child(_secret)
	_dialog.confirmed.connect(_keep_client)
	add_child(_dialog)


## This section's part of the card's block.
func capture() -> Dictionary:
	return {"tiktok_mode": mode(), "tiktok_privacy": privacy(), "tiktok_comments": _comments.button_pressed,
		"tiktok_duet": _duet.button_pressed, "tiktok_stitch": _stitch.button_pressed, "tiktok_aigc": _aigc.button_pressed,
		"tiktok_brand_own": _brand_own.button_pressed, "tiktok_brand_paid": _brand_paid.button_pressed}


## ...and back: a key the block does not name keeps a new card's value; a mode TikTok does not know is a draft.
func apply(block: Dictionary) -> void:
	var b := DEFAULTS.duplicate()
	for k in DEFAULTS:
		if block.has(k):
			b[k] = block[k]
	var m := str(b["tiktok_mode"])
	YouTubeCard._select(_mode, m if TikTok.MODES.has(m) else TikTok.MODE)
	var p := str(b["tiktok_privacy"])
	_privacy_want = p if TikTok.PRIVACIES.has(p) else ""
	_comments.set_pressed_no_signal(bool(b["tiktok_comments"]))
	_duet.set_pressed_no_signal(bool(b["tiktok_duet"]))
	_stitch.set_pressed_no_signal(bool(b["tiktok_stitch"]))
	_aigc.set_pressed_no_signal(bool(b["tiktok_aigc"]))
	_brand_own.set_pressed_no_signal(bool(b["tiktok_brand_own"]))
	_brand_paid.set_pressed_no_signal(bool(b["tiktok_brand_paid"]))
	_seen = []
	refresh()


func mode() -> String:
	return String(_mode.get_item_metadata(_mode.selected)) if _mode.selected >= 0 else TikTok.MODE


## Who may see a post, "" while none is picked.
func privacy() -> String:
	return _privacy_want


## The card's upload's TikTok part ([method TikTok.post_of] reads it).
func part() -> Dictionary:
	var c := capture()
	return {"mode": c["tiktok_mode"], "privacy": c["tiktok_privacy"], "comments": c["tiktok_comments"],
		"duet": c["tiktok_duet"], "stitch": c["tiktok_stitch"], "aigc": c["tiktok_aigc"],
		"brand_own": c["tiktok_brand_own"], "brand_paid": c["tiktok_brand_paid"]}


## Why nothing can go to TikTok as the rows stand, "" when it can.
func why_not() -> String:
	if not TikTok.has_client():
		return "TikTok needs your app's Client key and secret first (Client…, under TikTok)."
	if not TikTok.signed_in():
		return "Sign in to TikTok first (under TikTok)."
	var scope := str(Registry.field(TikTok.MODES, mode(), "scope", TikTok.DRAFT_SCOPE))
	if not TikTok.granted(scope):
		return "The TikTok sign-in may not %s yet: sign in again (under TikTok)." % (
			"post" if mode() == "post" else "send drafts")
	if mode() == "post":
		if privacy().is_empty():
			return "Pick who may see the TikTok post (Who sees it, under TikTok)."
		if _brand_paid.button_pressed and privacy() == "SELF_ONLY":
			return "Branded content cannot be Only me on TikTok."
	return ""


## The rows follow the account, its sign-in and a waiting upload; the card calls it twice a second.
func refresh() -> void:
	var tt := _node()
	var phase := String(tt.phase) if tt != null else ""
	var creator: Dictionary = tt.creator if tt != null else {}
	var a := TikTok.account()
	var p := TikTok.pending()
	var busy := tt != null and phase in ["uploading", "processing"]
	var pct := int(round(float(tt.progress) * 100.0)) if tt != null else 0
	_ask_quietly(tt)
	var now := [TikTok.has_client(), a.get("name", ""), a.get("username", ""), a.get("scope", ""), TikTok.signed_in(), phase,
		pct, creator.hash(), p.get("file", ""), mode(), _privacy_want, _brand_paid.button_pressed, _asking, _said, tt != null]
	if now == _seen:
		return
	_seen = now
	var signed := TikTok.signed_in()
	var named := TikTok.name_of(a)
	var scope := str(Registry.field(TikTok.MODES, mode(), "scope", TikTok.DRAFT_SCOPE))
	var lacks := signed and not TikTok.granted(scope)
	if tt == null:
		_account.text = "Uploads are made by the export, which this window does not have."
	elif not TikTok.has_client():
		_account.text = ("No TikTok app yet: uploads go through your own app on TikTok for Developers. Client… says how, "
			+ "and keeps its key and secret here.")
	elif phase == "signing_in":
		_account.text = "TikTok's sign-in is open in your browser: allow Ghost Notes there."
	elif not signed:
		_account.text = "Not signed in to TikTok here. Signing in opens your browser."
	else:
		_account.text = "Goes to %s on TikTok%s." % [named if not named.is_empty() else "your account",
			" - sign in again to let it %s" % ("post" if mode() == "post" else "send drafts") if lacks else ""]
	_sign.visible = tt != null and TikTok.has_client() and (not signed or lacks or phase == "signing_in")
	_sign.text = "Cancel" if phase == "signing_in" else ("Sign in again" if lacks else "Sign in")
	_sign.tooltip_text = "Open your browser to sign in to TikTok, asking to %s." % ("post" if mode() == "post" else "send drafts")
	_again.visible = phase == "signing_in"
	_out.visible = tt != null and signed and phase != "signing_in"
	_client.visible = tt != null
	_client.tooltip_text = ("Your app's Client key and secret, from TikTok for Developers." if not TikTok.has_client()
		else "Enter another app's Client key and secret. A new app signs in afresh.")
	_post_rows.visible = mode() == "post"
	_fill_privacy(creator)
	_comments.disabled = bool(creator.get("comment_disabled", false))
	_duet.disabled = bool(creator.get("duet_disabled", false))
	_stitch.disabled = bool(creator.get("stitch_disabled", false))
	_terms.text = ("By posting, you agree to TikTok's Branded Content Policy and Music Usage Confirmation"
		if _brand_paid.button_pressed else "By posting, you agree to TikTok's Music Usage Confirmation")
	var waiting := not p.is_empty() and FileAccess.file_exists(str(p.get("file", "")))
	_resume.visible = tt != null and waiting and not busy
	_resume.text = "Send %s to TikTok again" % str(p.get("file", "")).get_file()
	if phase == "uploading":
		_state.text = "Sending to TikTok … %d%%" % pct
	elif phase == "processing":
		_state.text = "TikTok is processing it - this can take a few minutes."
	elif _asking:
		_state.text = "Asking TikTok what the account allows…"
	else:
		_state.text = _said
	_state.visible = not _state.text.is_empty()


## The privacy list: what the account offers once known, else every privacy TikTok has, and "Choose…" until one is picked.
func _fill_privacy(creator: Dictionary) -> void:
	var offered: Variant = creator.get("privacy_level_options", [])
	var keys: Array = (offered as Array).duplicate() if offered is Array and not (offered as Array).is_empty() \
		else TikTok.PRIVACIES.keys()
	_privacy.clear()
	_privacy.add_item("Choose…")
	_privacy.set_item_metadata(0, "")
	for k in keys:
		_privacy.add_item(str(TikTok.PRIVACIES.get(str(k), str(k))))
		_privacy.set_item_metadata(_privacy.item_count - 1, str(k))
	_privacy.select(0)
	for i in _privacy.item_count:
		if String(_privacy.get_item_metadata(i)) == _privacy_want:
			_privacy.select(i)


## What the account allows a post, asked once it may post and when last asked long ago: nothing is said unless it fails.
func _ask_quietly(tt: Node) -> void:
	if tt == null or not tt.is_inside_tree() or _asking or not is_visible_in_tree() or mode() != "post" or not TikTok.granted(TikTok.POST_SCOPE):
		return
	var c: Dictionary = tt.creator
	if not c.is_empty() and TikTok._now() - float(c.get("at", 0.0)) < CREATOR_FRESH:
		return
	if not _said.is_empty() and c.is_empty():
		return                      # it failed: ↻ is signing in again, not asking every half second
	_asking = true
	var got: Dictionary = await tt.creator_info()
	if not is_instance_valid(self):
		return
	_asking = false
	_said = ("TikTok: " + str(got["error"])) if got.has("error") else ""
	_seen = []


func _on_sign() -> void:
	var tt := _node()
	if tt == null:
		return
	if tt.phase == "signing_in":
		tt.stop_sign_in()
		_seen = []
		return
	_said = ""
	_seen = []
	var got: Dictionary = await tt.sign_in(TikTok.scopes_for(mode()))
	if not is_instance_valid(self):
		return
	_said = ("The TikTok sign-in did not finish: %s." % got["error"]) if got.has("error") else ""
	_seen = []
	_card.refresh()


func _on_sign_out() -> void:
	var tt := _node()
	if tt == null:
		return
	await tt.sign_out()
	if is_instance_valid(self):
		_said = ""
		_seen = []
		_card.refresh()


func _on_resume() -> void:
	var ex := _card._exporter()
	if ex != null:
		ex.tiktok_resume()
	_seen = []


func _open_client() -> void:
	var c := TikTok.client()
	_key.text = str(c.get("client_key", ""))
	_secret.text = ""
	_secret.placeholder_text = "Client secret (kept - leave empty to keep it)" if not c.is_empty() else "Client secret"
	_dialog.popup_centered()


func _keep_client() -> void:
	var secret := _secret.text
	if secret.strip_edges().is_empty():
		secret = str(TikTok.client().get("client_secret", ""))
	var err := TikTok.set_client(_key.text, secret)
	_secret.text = ""
	_said = ("The TikTok client was not kept: %s." % err) if not err.is_empty() else ""
	_seen = []
	_card.refresh()


func _changed() -> void:
	_seen = []
	_card.refresh()


func _node() -> Node:
	var ex := _card._exporter()
	return ex.tiktok() if ex != null and ex.has_method("tiktok") else null


func _row(label: String, field: Control, into: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	into.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(72, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)


func _check(text: String, tip: String, into: Control) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.tooltip_text = tip
	c.add_theme_font_size_override("font_size", 12)
	c.toggled.connect(func(_on: bool) -> void: _changed())
	into.add_child(c)
	return c


func _button(text: String, act: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(act)
	return b


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 11)
	l.modulate = Color(1, 1, 1, 0.7)
	return l
