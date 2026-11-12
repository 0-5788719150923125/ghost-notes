extends HBoxContainer
class_name AgentPick

## AgentPick - who does one job, as one row: the agent (a CLI from a backend registry, [TextGen] for a
## writer, [ImageGen] for a painter), the model it runs and how hard it reasons - each list the chosen
## agent's own, read from its backend ([method TextGen.Backend.models], `efforts`). Every card that runs
## agents builds its choice from this, so an agent, its models and its levels read the same wherever
## they are chosen.
##
## The choice is the card's to keep: [method set_choice] puts a stored one on the row, and [signal changed]
## says a person changed it - the card reads [method choice] into its block. Another agent resets the
## model and the level to that agent's own defaults; another model keeps the level. A stored model or
## level the agent no longer offers stays on its list, marked, so a choice is never silently lost. An
## agent whose CLI is not installed is listed and not choosable; a level picker for an agent that takes
## no setting is grayed out.
##
## The assistant is chosen here too ([method assistant]): its agents are the CLIs [AssistantBackends]
## can hand a note to, each offering the models and levels of the writer it is, after an "Off"
## ([member none]).

## A person changed the agent, the model or the level.
signal changed

## "writer" ([TextGen]'s agents), "painter" ([ImageGen]'s) or "assistant" ([AssistantBackends]').
var role := "writer"
## The first agent listed where the job can go undone ([method assistant]: "Off"): its agent is "", with no model and no
## level. "" lists none.
var none := ""
## The backend registry the agents come from.
var registry: Dictionary = {}
var agent := ""
var model := ""
var effort := ""
var agents: OptionButton
var models: OptionButton
var efforts: OptionButton

var _keys: Array = []
var _syncing := false


## A writer's row (an agent from [TextGen]): [param what] says what it writes, and when a change
## takes effect.
static func writer(what: String, model_tip := "", effort_tip := "") -> AgentPick:
	var p := AgentPick.new()
	p.role = "writer"
	p._build("Writer", TextGen.REGISTRY, what,
		model_tip if not model_tip.is_empty() else "The model that writes. Default is the CLI's own choice per job.",
		effort_tip if not effort_tip.is_empty() else ("How hard the writer thinks before it writes - the CLI's own "
			+ "reasoning effort. Default is what each CLI does unasked. Higher is slower and spends more quota."))
	return p


## A row for who plays the players at a game's table (next/tabletop.md): writers too, asked often and briefly.
static func players(what: String, model_tip: String, effort_tip: String) -> AgentPick:
	var p := AgentPick.new()
	p.role = "writer"
	p._build("Players", TextGen.REGISTRY, what, model_tip, effort_tip)
	return p


## The assistant's row (the chat panel): Off, then every CLI [AssistantBackends] can hand a note to, each with the models and
## levels of the writer it is - and its own blurb, for it runs with tools in the repository, as no writer does.
static func assistant(what: String) -> AgentPick:
	var reg := {}
	for k in AssistantBackends.REGISTRY:
		var w := AssistantBackends.writer(k)
		reg[k] = {"label": AssistantBackends.label(k), "name": Registry.field(AssistantBackends.REGISTRY, k, "name", k),
			"blurb": Registry.blurb(AssistantBackends.REGISTRY, k), "backend": Registry.field(TextGen.REGISTRY, w, "backend")}
	var p := AgentPick.new()
	p.role = "assistant"
	p.none = "Off"
	p._build("Agent", reg, what, "The model the assistant runs on. Default is the one each CLI is shown with.",
		"How hard the assistant thinks before it acts. Higher is slower and spends more quota.")
	return p


## A painter's row (an agent from [ImageGen]).
static func painter(what: String, model_tip := "", effort_tip := "") -> AgentPick:
	var p := AgentPick.new()
	p.role = "painter"
	p._build("Painter", ImageGen.REGISTRY, what,
		model_tip if not model_tip.is_empty() else "The model of the agent that asks for each picture.",
		effort_tip if not effort_tip.is_empty() else "How hard the agent that asks for each picture thinks.")
	return p


## Put a stored choice on the row, without [signal changed]: the agent, its models with [param m]
## selected, its levels with [param e]. An unknown agent is the registry's first.
func set_choice(a: String, m: String, e: String) -> void:
	agent = a if registry.has(a) else String(_keys[0]) if not _keys.is_empty() else ""
	model = m
	effort = e
	_syncing = true
	agents.select(maxi(0, _keys.find(agent)))
	_syncing = false
	fill_models()
	fill_efforts()


## {agent, model, effort} as chosen now.
func choice() -> Dictionary:
	return {"agent": agent, "model": model, "effort": effort}


func _backend(k: String) -> GDScript:
	var fallback: GDScript = ImageGen.Codex if role == "painter" else TextGen.Claude
	return Registry.field(registry, k, "backend", fallback) as GDScript


func _available(k: String) -> bool:
	match role:
		"painter":
			return ImageGen.make(k).available()
		"assistant":
			return AssistantBackends.installed().has(k)
	return TextGen.make(k).available()


## Which agents can be chosen, asked again - an install a rescan found lights its row up. One whose CLI is not installed
## stays listed, grayed and saying so.
func mark_available() -> void:
	for i in _keys.size():
		var k := String(_keys[i])
		if k.is_empty():
			continue
		var here := _available(k)
		# the CLI's own name in the row (its full label is in the tooltip): the row is shared with the model
		agents.set_item_text(i, String(Registry.field(registry, k, "name", k.capitalize())) + ("" if here else "  (not installed)"))
		agents.set_item_disabled(i, not here)


func _build(title: String, reg: Dictionary, what: String, model_tip: String, effort_tip: String) -> void:
	registry = reg
	_keys = ([""] if not none.is_empty() else []) + reg.keys()
	add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = title
	l.custom_minimum_size = Vector2(56, 0)
	l.add_theme_font_size_override("font_size", 12)
	add_child(l)
	agents = _picker()
	var tips := PackedStringArray([what])
	for k in _keys:
		agents.add_item(none if String(k).is_empty() else String(k))
		if not String(k).is_empty():
			tips.append("%s: %s" % [Registry.label(reg, k), Registry.blurb(reg, k)])
	mark_available()
	agents.tooltip_text = "\n\n".join(tips)
	add_child(agents)
	models = _picker()
	models.tooltip_text = model_tip
	add_child(models)
	# The reasoning effort, from the chosen agent's own levels for the chosen model
	efforts = _picker()
	efforts.size_flags_stretch_ratio = 0.7
	efforts.tooltip_text = effort_tip
	add_child(efforts)
	agents.item_selected.connect(func(i: int) -> void:
		if _syncing or i < 0 or i >= _keys.size():
			return
		agent = String(_keys[i])
		# another agent, another list of models and levels: its own defaults until chosen
		model = ""
		effort = ""
		fill_models()
		fill_efforts()
		changed.emit())
	models.item_selected.connect(func(i: int) -> void:
		if _syncing:
			return
		model = String(models.get_item_metadata(i))
		# another model, perhaps other levels: the chosen one stays, marked if it is not offered
		fill_efforts()
		changed.emit())
	efforts.item_selected.connect(func(i: int) -> void:
		if _syncing:
			return
		effort = String(efforts.get_item_metadata(i))
		changed.emit())
	set_choice(String(_keys[0]) if not _keys.is_empty() else "", "", "")


## Sized by the row, not its items: a picker as wide as its longest item would push the whole panel out.
func _picker() -> OptionButton:
	var p := OptionButton.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.fit_to_longest_item = false
	p.clip_text = true
	p.focus_mode = Control.FOCUS_NONE
	return p


## The agent's models, the chosen one selected - kept on the list (marked) when this agent no
## longer offers it.
func fill_models() -> void:
	var listed: Array = _backend(agent).models() if not agent.is_empty() else []
	_syncing = true
	models.clear()
	var at := 0
	for m in listed:
		models.add_item(String((m as Dictionary)["label"]))
		models.set_item_metadata(models.item_count - 1, String((m as Dictionary)["key"]))
		if String((m as Dictionary)["key"]) == model:
			at = models.item_count - 1
	if not model.is_empty() and at == 0:
		models.add_item("%s  (not offered)" % model)
		models.set_item_metadata(models.item_count - 1, model)
		at = models.item_count - 1
	if models.item_count > 0:
		models.select(at)
	models.disabled = models.item_count == 0
	_syncing = false


## The levels the agent offers for the chosen model, the chosen one selected - kept on the list
## (marked) when it is not offered; grayed out where the agent takes no setting.
func fill_efforts() -> void:
	var levels: Array = _backend(agent).efforts(model) if not agent.is_empty() else []
	_syncing = true
	efforts.clear()
	var at := 0
	for e in levels:
		efforts.add_item(String((e as Dictionary)["label"]))
		efforts.set_item_metadata(efforts.item_count - 1, String((e as Dictionary)["key"]))
		if String((e as Dictionary)["key"]) == effort:
			at = efforts.item_count - 1
	if not effort.is_empty() and at == 0:
		efforts.add_item("%s  (not offered)" % TextGen.effort_label(effort))
		efforts.set_item_metadata(efforts.item_count - 1, effort)
		at = efforts.item_count - 1
	if efforts.item_count > 0:
		efforts.select(at)
	efforts.disabled = levels.size() <= 1 and effort.is_empty()
	_syncing = false
