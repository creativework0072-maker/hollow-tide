extends RefCounted
# Small helpers for loading sprite sheets and tiled textures (Week 3 asset integration).

# Builds an AnimatedSprite2D from a horizontal sprite sheet.
# anims = { "name": [first_frame, frame_count, fps, loops] }
static func build_sprite(sheet_path: String, fw: int, fh: int, anims: Dictionary) -> AnimatedSprite2D:
	var sheet: Texture2D = load(sheet_path)
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for anim_name in anims:
		var a: Array = anims[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, a[2])
		frames.set_animation_loop(anim_name, a[3])
		for i in range(a[1]):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2((a[0] + i) * fw, 0, fw, fh)
			frames.add_frame(anim_name, at)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.play(anims.keys()[0])
	return spr


# A TextureRect that repeats (tiles) a texture over the given rectangle.
static func tile_rect(tex_path: String, pos: Vector2, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(tex_path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.position = pos
	t.size = size
	return t
