extends RefCounted
class_name TuneSection

## TuneSection - numbers a show may be paced by, handed to the panel's Pacing card ([PacingCard]) by
## whatever reads them, as a card hands the Pipeline card a section. No component names the card and the
## card names no component; the rows a section offers are the ones that apply to what is being shown now
## (a table show's: the numbers that pace the laws its agents' acts use, [method TableTune.fields]), and
## with none offered anywhere there is no card. These defaults offer nothing.


## The rows that apply now, as a form draws them ([SchemaForm]: key -> field), {} for none.
func rows() -> Dictionary:
	return {}


## What the show tells of them now (key -> value); a row it does not tell stands at its default.
func values() -> Dictionary:
	return {}


## [param key] set to [param value] (null unsets it, back to its default). "" written, else why not.
func set_value(_key: String, _value: Variant) -> String:
	return "nothing here keeps it"
