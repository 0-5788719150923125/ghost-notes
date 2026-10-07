extends RefCounted
class_name Capabilities

## Capabilities - what this platform can do, and what is ready now (next/notes.md, "Platforms:
## desktop and Android"). One table, two questions per entry, each answered with a reason:
##
##   POSSIBLE here at all - decided by the platform (`Deps.platform()`, feature tags) and by
##   `Provision.unsupported` for what ghost downloads. A phone can start no program ghost fetches:
##   Android 10 and later refuse to execute a file from an app's own storage.
##
##   READY now - asked again whenever the Environment panel rescans. What ghost installs itself
##   (FFmpeg, its Python environments) is ready wherever it is possible: it is built the first time
##   a feature asks. What only the user can install (an agent's command-line tool) is ready when it
##   is there.
##
## A component declares the capabilities it needs ([Components]); "+" leaves out what is impossible
## here and grays what is not ready, with the reason. The table is ALSO checked where programs
## start ([method Subprocess.start] and its siblings), so a component that forgets to declare still
## cannot launch anything on a phone.
##
## Static and free of autoload names on purpose: [Subprocess] asks it, and gates run it under a bare
## `--script`. `Deps.platform_override` lets a gate ask as another platform would ("android").

## The table. `label` reads in a sentence ("needs ..."); `where` says on what it is possible.
const TABLE := {
	"subprocess": {"label": "starting programs", "where": "desktop"},
	"ffmpeg": {"label": "FFmpeg", "where": "desktop", "dep": "ffmpeg"},
	"python:voice": {"label": "the voice environment", "where": "desktop", "dep": "voice_venv"},
	"python:download": {"label": "the download environment", "where": "desktop", "dep": "ytdlp_venv"},
	"python:capture": {"label": "the page-capture environment", "where": "desktop", "dep": "capture_venv"},
	"python:face": {"label": "the body and face-tracking environment", "where": "desktop", "dep": "face_venv"},
	"agent:writer": {"label": "an AI writer", "where": "desktop", "role": "writer"},
	"agent:painter": {"label": "an AI painter", "where": "desktop", "role": "painter"},
	"movie_export": {"label": "rendering a video", "where": "desktop"},
	"checkout": {"label": "running from the repository", "where": "checkout"},
	"forward_plus": {"label": "the desktop renderer", "where": "desktop"},
	# THE SHOW ITSELF - a clock, a transport, a stage that plays: what a song or a voice feeds. A phone
	# has none ("On Android a note has one component, its text, and there is no stage, transport,
	# Chrome furniture or agent"), so a component that feeds the show asks for it.
	"stage": {"label": "the show (a stage that plays)", "where": "desktop"},
	"mic": {"label": "a microphone", "where": "desktop"},
}

## The agent registry behind [param role] - the same ones the notes list gates its templates on. By
## class name, not preload: [TextGen] starts its agents through [Subprocess], which asks this file.
static func registry(role: String) -> GDScript:
	return TextGen if role == "writer" else ImageGen


## Is this a desktop, where ghost may start programs? A phone, a tablet and a browser are not.
static func desktop() -> bool:
	return Deps.platform() in ["linux", "macos", "windows"]


## Why [param cap] is impossible on this platform, "" when it is possible. An unknown capability is
## impossible, and says so - a typo must not read as "works everywhere".
static func impossible(cap: String) -> String:
	if not TABLE.has(cap):
		return "'%s' is not a capability Ghost Notes knows" % cap
	var row: Dictionary = TABLE[cap]
	match String(row["where"]):
		"desktop":
			if not desktop():
				return "%s is not possible on %s" % [String(row["label"]).capitalize(), _platform_name()]
		"checkout":
			if not desktop() or not OS.has_feature("editor"):
				return "Only a copy of Ghost Notes run from its repository has this"
	if row.has("dep"):
		var why := Provision.unsupported(String(row["dep"]))
		if not why.is_empty():
			return "%s: %s" % [String(row["label"]).capitalize(), why]
	# THE PROJECT'S renderer, not the running one: a headless gate renders with a dummy, and the
	# question is what this build draws with (a phone's override is `mobile`)
	var method := String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	if cap == "forward_plus" and method != "forward_plus":
		return "This copy is set to draw with the %s renderer, not the desktop one" % method
	return ""


## Why [param cap] is not ready now, "" when it is. Impossible is never ready. What ghost installs
## itself is ready wherever it is possible (built when first asked for); an agent is ready when one
## of its role's command-line tools is installed.
static func not_ready(cap: String) -> String:
	var why := impossible(cap)
	if not why.is_empty():
		return why
	var row: Dictionary = TABLE[cap]
	if row.has("role"):
		var reg: GDScript = registry(String(row["role"]))
		for k in (reg.REGISTRY as Dictionary).keys():
			if reg.make(k).available():
				return ""
		return "No %s is installed - see the Environment panel (⚙)" % String(row["label"]).trim_prefix("an ")
	return ""


## The first reason any of [param caps] is impossible, "" when all are possible.
static func impossible_any(caps: Array) -> String:
	for c in caps:
		var why := impossible(String(c))
		if not why.is_empty():
			return why
	return ""


## The first reason any of [param caps] is not ready, "" when all are ready.
static func not_ready_any(caps: Array) -> String:
	for c in caps:
		var why := not_ready(String(c))
		if not why.is_empty():
			return why
	return ""


static func _platform_name() -> String:
	return {"android": "Android", "ios": "iOS", "web": "the web"}.get(Deps.platform(), Deps.platform())


# --- the agents: what a component can need that ghost cannot install for it ---------------------
#
# An AI agent in a ROLE. The agent CLIs keep their own logins, so they stay the user's to install
# (see [constant Deps.TOOLS]). A role is a backend registry ([method registry]), filled when ANY ONE
# of its backends is installed - availability is the backend's own `available()`, the same resolver
# its jobs launch through, so a template is never lit for an agent its jobs cannot find. These were
# the home screen's (Splash) until step 8 retired it; the notes list's New menu asks them now.

## What every gate tells a person to do about a missing agent.
const INSTALL_HINT := ("Install one or several of them, then press rescan in the Environment panel. "
	+ "Click an agent's row there for the command that installs it.")


## The roles [param caps] ask for (`agent:writer` -> "writer"), in order.
static func roles_of(caps: Array) -> Array:
	var out: Array = []
	for c in caps:
		if String(c).begins_with("agent:"):
			out.append(String(c).trim_prefix("agent:"))
	return out


## The keys of [param role]'s agents this machine has, in registry order.
static func installed_agents(role: String) -> Array:
	var reg := registry(role)
	return (reg.REGISTRY as Dictionary).keys().filter(func(k: String) -> bool: return reg.make(k).available())


## The roles in [param needs] that no installed agent fills.
static func missing_roles(needs: Array) -> Array:
	return needs.filter(func(r: String) -> bool: return installed_agents(r).is_empty())


## "an AI painter", "an AI writer and painter".
static func role_phrase(roles: Array) -> String:
	return "an AI " + join_words(roles, "and")


## A gated template's tooltip. With nothing [param missing], which installed agents fill each role
## in [param needs]. Otherwise: what is not installed; for each unfilled role, EVERY agent its
## registry supports; the agents that would fill all of them alone (a key names the same CLI in
## every registry - `codex` writes and paints); and what to do about it. Written as PARAGRAPHS: Boot
## re-flows every tooltip to a width, folding a single newline into the line, so only a blank line
## survives as a break.
static func agents_tooltip(needs: Array, missing: Array) -> String:
	var paras := PackedStringArray()
	if missing.is_empty():
		for role in needs:
			paras.append("%ss installed: %s." % [String(role).capitalize(),
				join_words(agent_labels(role, installed_agents(role)), "and")])
		return "\n\n".join(paras)
	paras.append("No AI %s is installed." % join_words(missing, "or"))
	for role in missing:
		paras.append("Supported %ss: %s." % [role,
			join_words(agent_labels(role, (registry(role).REGISTRY as Dictionary).keys()), "and")])
	if missing.size() > 1:
		var every: Array = (registry(missing[0]).REGISTRY as Dictionary).keys()
		for role in missing.slice(1):
			var reg: Dictionary = registry(role).REGISTRY
			every = every.filter(func(k: String) -> bool: return reg.has(k))
		if not every.is_empty():
			paras.append("%s can do %s." % [join_words(agent_labels(missing[0], every), "or"),
				"both" if missing.size() == 2 else "all of them"])
	paras.append(INSTALL_HINT)
	return "\n\n".join(paras)


## Display labels for [param keys] of [param role]'s registry, each held together with no-break
## spaces so a tooltip's re-flow never splits an agent's name across two lines.
static func agent_labels(role: String, keys: Array) -> Array:
	var labels: Dictionary = registry(role).LABELS
	return keys.map(func(k: String) -> String: return String(labels.get(k, k)).replace(" ", "\u00a0"))


## "a", "a and b", "a, b and c".
static func join_words(words: Array, conj: String) -> String:
	var w := PackedStringArray(words)
	if w.size() < 2:
		return "".join(w)
	return "%s %s %s" % [", ".join(w.slice(0, w.size() - 1)), conj, w[w.size() - 1]]

