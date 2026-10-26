extends RefCounted
# Helpers for loading sprite sheets and tiled textures.
# Week 5: added texture / SpriteFrames caching and counters for the performance report.

# [WEEK5-OPT] When true, identical sprites share one SpriteFrames resource instead of
# each building its own copy. main.gd switches this with its OPTIMIZE flag.
static var use_cache := true
static var frames_built := 0          # SpriteFrames resources created (shown in the F3 overlay)
static var atlas_built := 0           # AtlasTexture resources created
static var _frames_cache := {}
static var _tex_cache := {}


static func reset_stats() -> void:
	frames_built = 0
	atlas_built = 0
	_frames_cache.clear()


# [WEEK5-OPT] Each texture file is loaded once and reused.
static func get_texture(path: String) -> Texture2D:
	if use_cache and _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load(path)
	if use_cache:
		_tex_cache[path] = t
	return t


# Builds an AnimatedSprite2D from a horizontal sprite sheet.
# anims = { "name": [first_frame, frame_count, fps, loops] }
static func build_sprite(sheet_path: String, fw: int, fh: int, anims: Dictionary) -> AnimatedSprite2D:
	var key := sheet_path + str(anims)
	var frames: SpriteFrames
	if use_cache and _frames_cache.has(key):
		frames = _frames_cache[key]                       # [WEEK5-OPT] reuse
	else:
		frames = _make_frames(sheet_path, fw, fh, anims)
		if use_cache:
			_frames_cache[key] = frames
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.play(anims.keys()[0])
	return spr


static func _make_frames(sheet_path: String, fw: int, fh: int, anims: Dictionary) -> SpriteFrames:
	var sheet: Texture2D = get_texture(sheet_path)
	var frames := SpriteFrames.new()
	frames_built += 1
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for anim_name in anims:
		var a: Array = anims[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, a[2])
		frames.set_animation_loop(anim_name, a[3])
		for i in range(a[1]):
			var at := AtlasTexture.new()
			atlas_built += 1
			at.atlas = sheet
			at.region = Rect2((a[0] + i) * fw, 0, fw, fh)
			frames.add_frame(anim_name, at)
	return frames


# A TextureRect that repeats (tiles) a texture over the given rectangle.
static func tile_rect(tex_path: String, pos: Vector2, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = get_texture(tex_path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.position = pos
	t.size = size
	return t
