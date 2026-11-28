extends RefCounted
class_name PopupStudio

## PopupStudio - a pop-up book's spread photographed for whoever designs it ([PopupTools]): the book drawn from [param doc]
## (the reading's document - its words, its design, its desk and its light) in a viewport of its own, open on the scene's spread
## with nothing moving, and taken from the views asked: as the show sees it (`front`, its wide camera), from straight above
## (`above`: where every foot stands) and from its right side (`side`: what stands upright, what leans, what is in front of
## what). The book's own medium draws it ([PopupMedium]), so what is seen is what plays.
##
## One at a time; nothing is drawn where this session can take no pictures ([method PropStudio.can_see]).

const SIZE := Vector2i(1024, 576)
const VIEWS := PopupTools.VIEWS
static var _busy := false


## The views [param views] of scene [param scene] of the book [param doc] draws: an Image each, in that order ([] where none
## can be taken).
static func look(doc: Dictionary, scene: int, views: Array) -> Array:
	if not PropStudio.can_see():
		return []
	var tree := PropStudio.tree()
	while _busy:
		await tree.process_frame
	_busy = true
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(vp)
	var med := PopupMedium.new()
	med.feed = StudioFeed.new()
	med.mount(vp)
	# by path at the moment it is wanted: the subtitles read the show's clock, which a bare gate has none of
	var subs: Node = (load("res://src/show/subtitles.gd") as GDScript).new()
	subs.set("words", [])
	subs.set("document", doc)
	subs.set("overlay_hidden", true)
	vp.add_child(subs)
	med.bind_captions(subs)
	med.begin_session()
	med.advance(null, 0.1, 1.0)
	var lay := med._layout as PopupLayout
	var out: Array = []
	if lay != null:
		var s := lay.scene_of.find(scene)
		med._spread = maxi(s, 0)
		med._snap = true
		for i in 4:
			med.advance(null, 0.1, 1.0)
		for v in views:
			if String(v) != "front":
				_aim(med, String(v))
			var img: Image = await PropStudio.render(vp, PropStudio.FRAMES)
			if img != null:
				out.append(img)
	vp.queue_free()
	_busy = false
	return out


## The camera of [param med] put where view [param view] looks from (the book's middle, in the world).
static func _aim(med: PopupMedium, view: String) -> void:
	var w := PopupMedium.BOOK_M
	var mid := med._book.position + Vector3(0.0, 0.05, -0.1) * w
	var cam: Camera3D = med._cam
	if view == "above":
		cam.position = mid + Vector3(0.0, 5.6 * w, 0.001)
		cam.look_at(mid, Vector3(0.0, 0.0, -1.0))
	else:
		# from the right and a little in front, above the desk's things (a candle low beside the book would fill the picture)
		cam.position = mid + Vector3(5.2 * w, 1.9 * w, 1.6 * w)
		cam.look_at(mid + Vector3(0.0, 0.14 * w, -0.05 * w), Vector3.UP)


## The show's clock for a still: long open, with no end in sight, so the book stands open and nothing turns.
class StudioFeed:
	extends ShowFeed

	func session_seed() -> int:
		return 1

	func show_time() -> float:
		return 1000.0

	func lead() -> float:
		return 0.0
