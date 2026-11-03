extends PipelineSection

## pipeline_stub_section - a section of the gate's own: what it lists and whether it is busy are set by hand, and it counts
## what it is asked. A fixture of pipeline_check.

var listed: Array = []
var is_busy := false
var has_missing := true
var made := 0
var stopped := 0


func _init(named := "") -> void:
	title = named


func shown() -> bool:
	return not listed.is_empty()


func rows() -> Array:
	return listed


func make() -> void:
	made += 1
	is_busy = true


func make_tip() -> String:
	return "Make this alone."


func stop() -> void:
	stopped += 1
	is_busy = false


func busy() -> bool:
	return is_busy


func missing() -> bool:
	return has_missing
