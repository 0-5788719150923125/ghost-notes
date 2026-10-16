extends HBoxContainer
class_name AgentPick

## AgentPick - who does one job, as one row: the AGENT (a CLI from a backend registry, [TextGen] for a
## writer, [ImageGen] for a painter), the MODEL it runs and how hard it REASONS - each list the chosen
## agent's own, read from its backend ([method TextGen.Backend.models], `efforts`). Every card that
## runs agents builds its choice of them from this (Cards' episode, Proof's), so an agent, its models
## and its levels read the same wherever they are chosen (the user, 2026-10-15: "We need to unify
## agent selection under a single codebase").
##
## THE CHOICE IS THE CARD'S TO KEEP: [method set_choice] puts a stored one on the row, and [signal changed]
## says a person changed it - the card reads [method choice] into its block. Another agent resets the
## model and the level to that agent's own defaults; another model keeps the level. A stored model or
## level the agent no longer offers stays on its list, marked, so a show's choice is never silently
## lost. An agent whose CLI is not installed is listed and not choosable; a level picker for an agent
## that takes no setting is grayed out.

## A person changed the agent, the model or the level.
signal changed

## "writer" ([TextGen]'s agents) or "painter" ([ImageGen]'s).
var role := "writer"
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
	var fallback: GDScript = TextGen.Claude if role == "writer" else ImageGen.Codex
	return Registry.field(registry, k, "backend", fallback) as GDScript


func _available(k: String) -> bool:
	return TextGen.make(k).available() if role == "writer" else ImageGen.make(k).available()


func _build(title: String, reg: Dictionary, what: String, model_tip: String, effort_tip: String) -> void:
	registry = reg
	_keys = reg.keys()
	add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = title
	l.custom_minimum_size = Vector2(56, 0)
	l.add_theme_font_size_override("font_size", 12)
	add_child(l)
	agents = _picker()
	var tips := PackedStringArray([what])
	for i in _keys.size():
		var k := String(_keys[i])
		var here := _available(k)
		# the CLI's own name in the row (its full label is in the tooltip): the row is shared with the model
		agents.add_item(k.capitalize() + ("" if here else "  (not installed)"))
		agents.set_item_disabled(i, not here)
		tips.append("%s: %s" % [Registry.label(reg, k), Registry.blurb(reg, k)])
	agents.tooltip_text = "\n\n".join(tips)
	add_child(agents)
	models = _picker()
	models.tooltip_text = model_tip
	add_child(models)
	# THE REASONING EFFORT, from the chosen agent's own levels for the chosen model
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


## SIZED BY THE ROW, NOT ITS ITEMS: a picker as wide as its longest item pushed the whole panel out.
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
