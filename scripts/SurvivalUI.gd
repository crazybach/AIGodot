class_name SurvivalUI
extends RefCounted
## Shared visual language for the survivor HUD and inventory screens.

const ASSET_ROOT := "res://assets/ui/dark_dwellers/"
const PANEL_TEXTURE := "20251029darkDwellers9SlicesA.png"
const INNER_PANEL_TEXTURE := "20251029darkDwellers9SlicesE.png"
const HEADER_TEXTURE := "20251117darkDwellersHeaderA.png"
const EMPTY_SLOT_TEXTURE := "20251124emptyFrameA1-Sheet.png"

const INK := Color("#0b0814")
const PANEL := Color("#171126")
const GOLD := Color("#f0b45b")
const GOLD_BRIGHT := Color("#ffd889")
const LAVENDER := Color("#aaa3d9")
const MUTED := Color("#777091")
const DANGER := Color("#d55758")


static func panel_style(inner := false) -> StyleBoxTexture:

	var style := StyleBoxTexture.new()
	style.texture = load(ASSET_ROOT + (INNER_PANEL_TEXTURE if inner else PANEL_TEXTURE))
	style.texture_margin_left = 28.0
	style.texture_margin_right = 28.0
	style.texture_margin_top = 28.0
	style.texture_margin_bottom = 28.0
	return style


static func flat_style(background: Color, border: Color, width := 1, radius := 3) -> StyleBoxFlat:

	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


static func atlas_texture(file_name: String, frame: int, frame_size := Vector2(32, 32)) -> AtlasTexture:

	var texture := AtlasTexture.new()
	texture.atlas = load(ASSET_ROOT + file_name)
	texture.region = Rect2(frame_size.x * frame, 0.0, frame_size.x, frame_size.y)
	return texture


static func slot_style(file_name: String, frame: int) -> StyleBoxTexture:

	var style := StyleBoxTexture.new()
	style.texture = atlas_texture(file_name, frame)
	style.texture_margin_left = 7.0
	style.texture_margin_right = 7.0
	style.texture_margin_top = 7.0
	style.texture_margin_bottom = 7.0
	return style


static func equipment_frame(slot: StringName) -> String:

	match slot:
		&"head": return "20251124helmetFrameA1-Sheet.png"
		&"face": return "20251124neckFrameA1-Sheet.png"
		&"torso": return "20251124chestFrameA1-Sheet.png"
		&"legs": return "20251124pantsFrameA1-Sheet.png"
		&"feet": return "20251124bootsFrameA1-Sheet.png"
		&"left_hand": return "20251124shieldFrameA1-Sheet.png"
		&"right_hand": return "20251124weaponFrameA1-Sheet.png"
		&"accessory_1", &"accessory_2": return "20251124ringFrameA1-Sheet.png"
		_: return EMPTY_SLOT_TEXTURE


static func make_header(text: String) -> Control:

	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(0, 38)
	var texture := TextureRect.new()
	texture.texture = load(ASSET_ROOT + HEADER_TEXTURE)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(texture)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", GOLD_BRIGHT)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(label)
	return wrapper
