extends Node

## NOT a gate. A MODEL LOOKED AT ([AssemblyModel], [ModelStudio]): what a design written by hand comes to, in words and from four sides.
##
##   GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/assembly_model_probe.gd 200 --model <file.json> --out <file.png> [--upto N]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var path := ""
	var out := ""
	var upto := -1
	for i in args.size() - 1:
		match args[i]:
			"--model": path = args[i + 1]
			"--out": out = args[i + 1]
			"--upto": upto = int(args[i + 1])
	var t0 := Time.get_ticks_msec()
	var m := AssemblyModel.make(JSON.parse_string(FileAccess.get_file_as_string(path)))
	print("assembly_model_probe: made in %d ms" % (Time.get_ticks_msec() - t0))
	print(AssemblyModel.report(m))
	var kinds := {}
	for p in m["parts"]:
		var k := "%s %dx%d" % [p["kind"], p["w"], p["d"]]
		kinds[k] = int(kinds.get(k, 0)) + 1
	print(kinds)
	if args.has("--floats"):
		print("\n".join(PackedStringArray(m["floating"])))
	if not out.is_empty():
		var got: Dictionary = await ModelStudio.views(m, upto)
		if got.has("image"):
			(got["image"] as Image).save_png(out)
			print("assembly_model_probe: -> %s" % out)
		else:
			print("assembly_model_probe: %s" % String(got["error"]))
	get_tree().quit(0)
