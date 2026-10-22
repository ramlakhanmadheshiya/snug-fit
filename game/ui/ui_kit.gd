class_name UIKit
extends RefCounted
## Snug Fit's design system: one rounded typeface (Nunito) and chunky "block"
## buttons with a soft lip under them, like the pieces themselves. Everything is
## built in code from the active palette.

const FONT_PATH: String = "res://assets/fonts/Nunito-Variable.ttf"
const ICON_DIR: String = "res://assets/icons/"
## Small Noto subsets (SIL OFL) for glyphs Nunito lacks: ★ ♥, currency signs such
## as ₹ in Google Play prices, and ৳. Without them the web build shows boxes.
const FALLBACK_FONTS: Array[String] = [
	"res://assets/fonts/NotoSans-Currency.ttf",
	"res://assets/fonts/NotoSansSymbols2-Subset.ttf",
	"res://assets/fonts/NotoSansBengali-Taka.ttf",
]
const RADIUS: int = 24
const LIP: int = 6

static var _fonts: Dictionary = {}
static var _icons: Dictionary = {}


static func font(weight: int = 400) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var base: FontFile = load(FONT_PATH) as FontFile
	if base.fallbacks.is_empty():
		var chain: Array[Font] = []
		for path: String in FALLBACK_FONTS:
			chain.append(load(path) as Font)
		base.fallbacks = chain
	var fv: FontVariation = FontVariation.new()
	fv.base_font = base
	var ts: TextServer = TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	_fonts[weight] = fv
	return fv


static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		_icons[name] = load(ICON_DIR + name + ".svg") as Texture2D
	return _icons[name]


static func label(text: String, size: int, color: Color, weight: int = 400, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The "no refunds" line under every buy button: small, muted, centred, wrapped.
const REFUND_NOTE: String = "Purchases are made through Google Play. Sorry, we can't refund or undo a purchase."


static func refund_note(pal: Dictionary) -> Label:
	var l: Label = label(REFUND_NOTE, 16, pal["muted"], 500)
	l.name = "RefundNote"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	return l


## The solid surface cards and buttons sit on, and the lip under them.
static func surface(pal: Dictionary) -> Color:
	var top: Color = pal["top"]
	return top.lightened(0.09) if bool(pal.get("dark", false)) else top.lerp(Color.WHITE, 0.62)


static func lip(pal: Dictionary, fill: Color) -> Color:
	return fill.darkened(0.3) if bool(pal.get("dark", false)) else fill.darkened(0.11).lerp(pal["ink"], 0.05)


## A rounded box with a darker lip along the bottom. `pressed` sinks it.
static func lip_box(fill: Color, lip_c: Color, radius: int = RADIUS, lip_h: int = LIP, pad: Vector2 = Vector2(26, 10), pressed: bool = false, outline: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.anti_aliasing = true
	s.border_color = lip_c
	var h: int = 2 if pressed else lip_h
	s.border_width_bottom = h
	if outline.a > 0.0:
		s.border_color = outline
		s.set_border_width_all(3)
		s.border_width_bottom = h
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y + (lip_h - h)
	s.content_margin_bottom = pad.y
	s.expand_margin_top = -float(lip_h - h)
	return s


## The floating card used by every overlay (settings, shop, results...).
static func card_style(pal: Dictionary) -> StyleBoxFlat:
	var fill: Color = surface(pal)
	var sb: StyleBoxFlat = lip_box(fill, lip(pal, fill), 36, 8, Vector2(40, 34))
	sb.shadow_color = Color(0, 0, 0, 0.14)
	sb.shadow_size = 26
	sb.shadow_offset = Vector2(0, 8)
	return sb


## Small uppercase caption with letter spacing, e.g. "MADE BY".
static func caption(text: String, pal: Dictionary, size: int = 18, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l: Label = label(text.to_upper(), size, pal["muted"], 800, align)
	var fv: FontVariation = (font(800) as FontVariation).duplicate()
	fv.spacing_glyph = 2
	l.add_theme_font_override("font", fv)
	return l


static func icon_rect(name: String, size: float, color: Color) -> TextureRect:
	var ic: TextureRect = TextureRect.new()
	ic.texture = icon(name)
	ic.custom_minimum_size = Vector2(size, size)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.modulate = color
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


## Text that reads on the accent colour: white, or a deep ink on light accents.
static func on_accent(pal: Dictionary) -> Color:
	var a: Color = pal["accent"]
	return Color("#1F1B3A") if a.get_luminance() > 0.62 else Color.WHITE


## Colours for a button style: [fill, text].
static func _colours(style: String, pal: Dictionary) -> Array:
	var ink: Color = pal["ink"]
	match style:
		"primary", "accent":
			return [pal["accent"], on_accent(pal)]
		"dark":
			return [ink, pal["top"]]
		"soft", "ghost":
			return [surface(pal), ink]
		"text":
			return [Color(ink, 0.0), Color(ink, 0.6)]
	return [surface(pal), ink]


## A chunky block button. style: "primary" (accent), "dark", "soft"/"ghost"
## (surface card) or "text" (no box).
static func pill(text: String, pal: Dictionary, style: String = "primary", min_size: Vector2 = Vector2(280, 84), font_size: int = 30) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", font(800))
	b.add_theme_font_size_override("font_size", font_size)
	var c: Array = _colours(style, pal)
	var fill: Color = c[0]
	var text_c: Color = c[1]
	var radius: int = mini(RADIUS, int(min_size.y * 0.42))
	if style == "text":
		var empty: StyleBoxFlat = StyleBoxFlat.new()
		empty.bg_color = Color.TRANSPARENT
		for key: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(key, empty)
	else:
		var l: Color = lip(pal, fill)
		b.add_theme_stylebox_override("normal", lip_box(fill, l, radius))
		b.add_theme_stylebox_override("hover", lip_box(fill.lightened(0.04), l, radius))
		b.add_theme_stylebox_override("pressed", lip_box(fill.darkened(0.04), l, radius, LIP, Vector2(26, 10), true))
		b.add_theme_stylebox_override("hover_pressed", lip_box(fill.darkened(0.04), l, radius, LIP, Vector2(26, 10), true))
		b.add_theme_stylebox_override("disabled", lip_box(Color(fill, 0.5), Color(l, 0.5), radius))
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.set_corner_radius_all(radius + 6)
	focus.border_color = Color(pal["accent"], 0.9)
	focus.set_border_width_all(3)
	focus.expand_margin_left = 6
	focus.expand_margin_right = 6
	focus.expand_margin_top = 6
	focus.expand_margin_bottom = 6
	b.add_theme_stylebox_override("focus", focus)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, text_c)
	b.add_theme_color_override("font_disabled_color", Color(text_c, 0.45))
	for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(key, text_c)
	add_press_feel(b)
	return b


## A rounded-square icon button on a surface block. `backed` false = bare icon.
static func icon_button(icon_name: String, pal: Dictionary, diameter: float = 72.0, backed: bool = true) -> Button:
	var b: Button = Button.new()
	b.icon = icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_ALL
	var ink: Color = pal["ink"]
	var fill: Color = surface(pal) if backed else Color.TRANSPARENT
	var l: Color = lip(pal, surface(pal)) if backed else Color.TRANSPARENT
	var pad: float = diameter * 0.27
	var r: int = int(diameter * 0.32)
	var lip_h: int = 5 if backed else 0
	b.add_theme_stylebox_override("normal", lip_box(fill, l, r, lip_h, Vector2(pad, pad - 2.0)))
	b.add_theme_stylebox_override("hover", lip_box(fill.lightened(0.04) if backed else fill, l, r, lip_h, Vector2(pad, pad - 2.0)))
	b.add_theme_stylebox_override("pressed", lip_box(fill.darkened(0.04) if backed else Color(ink, 0.08), l, r, lip_h, Vector2(pad, pad - 2.0), true))
	b.add_theme_stylebox_override("hover_pressed", lip_box(fill.darkened(0.04) if backed else Color(ink, 0.08), l, r, lip_h, Vector2(pad, pad - 2.0), true))
	b.add_theme_stylebox_override("disabled", lip_box(Color(fill, fill.a * 0.5), l, r, lip_h, Vector2(pad, pad - 2.0)))
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.set_corner_radius_all(r + 4)
	focus.border_color = Color(pal["accent"], 0.9)
	focus.set_border_width_all(3)
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	b.add_theme_stylebox_override("focus", focus)
	for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(key, ink)
	b.add_theme_color_override("icon_disabled_color", Color(ink, 0.3))
	b.add_theme_font_override("font", font(800))
	b.add_theme_font_size_override("font_size", 22)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, ink)
	add_press_feel(b)
	return b


## A small rounded tag ("FREE", "30", "∞") pinned to a button's corner.
static func badge(text: String, pal: Dictionary, fill: Color = Color.TRANSPARENT) -> Label:
	var l: Label = label(text, 17, Color.WHITE, 900)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill if fill.a > 0.0 else pal["accent"]
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", sb)
	return l


## A gold coin with a soft rim and a star, drawn at c with radius r.
static func draw_coin(c: CanvasItem, at: Vector2, r: float) -> void:
	c.draw_circle(at + Vector2(0, r * 0.12), r, Color("#C98A1E"), true, -1.0, true)
	c.draw_circle(at, r, Color("#F7BE45"), true, -1.0, true)
	c.draw_arc(at, r * 0.74, 0.0, TAU, 32, Color("#E0A12C"), maxf(1.5, r * 0.12), true)
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in 10:
		var a: float = -PI * 0.5 + TAU * float(k) / 10.0
		pts.append(at + Vector2(cos(a), sin(a)) * r * (0.42 if k % 2 == 0 else 0.19))
	c.draw_colored_polygon(pts, Color("#FFF3C9"))


## Squash on press, springy release, and a soft tap sound.
static func add_press_feel(c: Control) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	if c is BaseButton:
		var b: BaseButton = c
		b.button_down.connect(func() -> void:
			var tw: Tween = b.create_tween()
			tw.tween_property(b, "scale", Vector2(0.95, 0.95), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			Haptics.tap(6)
		)
		b.button_up.connect(func() -> void:
			var tw: Tween = b.create_tween()
			tw.tween_property(b, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)
		b.pressed.connect(func() -> void: AudioManager.play_ui("ui_tap"))


## A three-way choice on one track (Appearance: Auto / Dark / Light).
static func segmented(options: Array, current: int, pal: Dictionary, on_change: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in options.size():
		var on: bool = i == current
		var b: Button = pill(str(options[i]), pal, "primary" if on else "soft", Vector2(0, 64), 22)
		b.name = "Option_" + str(options[i])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = on
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			AudioManager.play_ui("ui_toggle")
			on_change.call(i)
		)
		row.add_child(b)
	return row


## A labelled on/off row used by the settings sheet.
## `on_info` (optional) makes the label tappable, with a small info mark, to explain
## what the setting does.
static func toggle_row(text: String, value: bool, pal: Dictionary, on_change: Callable, on_info: Callable = Callable()) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 76)
	if on_info.is_valid():
		var info: Button = Button.new()
		info.name = "Info"
		info.flat = true
		info.text = text
		info.icon = icon("info")
		info.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		info.alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.add_theme_constant_override("icon_max_width", 22)
		info.add_theme_constant_override("h_separation", 10)
		info.add_theme_font_override("font", font(500))
		info.add_theme_font_size_override("font_size", 28)
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			info.add_theme_color_override(key, pal["ink"])
		for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			info.add_theme_color_override(key, Color(pal["ink"], 0.4))
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		for key: String in ["normal", "hover", "pressed", "focus"]:
			info.add_theme_stylebox_override(key, empty)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.pressed.connect(on_info)
		row.add_child(info)
	else:
		var l: Label = label(text, 28, pal["ink"], 500, HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
	var sw: CheckButton = CheckButton.new()
	sw.button_pressed = value
	sw.focus_mode = Control.FOCUS_ALL
	sw.add_theme_icon_override("checked", _switch_texture(true, pal))
	sw.add_theme_icon_override("unchecked", _switch_texture(false, pal))
	sw.add_theme_icon_override("checked_disabled", _switch_texture(true, pal))
	sw.add_theme_icon_override("unchecked_disabled", _switch_texture(false, pal))
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for key: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		sw.add_theme_stylebox_override(key, empty)
	sw.toggled.connect(func(on: bool) -> void:
		AudioManager.play_ui("ui_toggle")
		Haptics.tap(8)
		on_change.call(on)
	)
	row.add_child(sw)
	return row


## A labelled 0..1 volume slider. Plays a tick while dragging so you hear the level.
static func slider_row(text: String, value: float, pal: Dictionary, on_change: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 76)
	row.add_theme_constant_override("separation", 20)
	var l: Label = label(text, 28, pal["ink"], 500, HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	var s: HSlider = slider(pal)
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		AudioManager.play("ui_toggle", 1.0)
	)
	row.add_child(s)
	return row


## An HSlider in the house style (accent fill, round knob). Range is up to the caller.
static func slider(pal: Dictionary) -> HSlider:
	var s: HSlider = HSlider.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(pal["ink"], 0.14)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = pal["accent"]
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob: Texture2D = _knob_texture(pal, false)
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", _knob_texture(pal, true))
	s.add_theme_icon_override("grabber_disabled", knob)
	return s


static func _knob_texture(pal: Dictionary, focused: bool) -> Texture2D:
	var d: int = 40
	var img: Image = Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c: Vector2 = Vector2(d, d) * 0.5
	for y: int in d:
		for x: int in d:
			var dist: float = Vector2(x + 0.5, y + 0.5).distance_to(c)
			var ring: float = clampf(d * 0.5 - dist + 0.5, 0.0, 1.0)
			var inner: float = clampf(d * 0.5 - 5.0 - dist + 0.5, 0.0, 1.0)
			var edge: Color = pal["accent"] if focused else Color(pal["ink"], 0.18)
			var col: Color = Color(edge, edge.a * ring).blend(Color(1, 1, 1, inner))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Draws a minimal switch into an image so CheckButton can use it as an icon.
static func _switch_texture(on: bool, pal: Dictionary) -> Texture2D:
	var w: int = 92
	var h: int = 52
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track: Color = pal["accent"] if on else Color(pal["ink"], 0.18)
	var knob: Color = Color.WHITE
	var r: float = h * 0.5
	for y: int in h:
		for x: int in w:
			var px: Vector2 = Vector2(x + 0.5, y + 0.5)
			var cx: float = clampf(px.x, r, w - r)
			var d: float = px.distance_to(Vector2(cx, r))
			var a: float = clampf(r - d + 0.5, 0.0, 1.0)
			var c: Color = Color(track, track.a * a)
			var kc: Vector2 = Vector2(w - r if on else r, r)
			var kd: float = px.distance_to(kc)
			var ka: float = clampf(r - 5.0 - kd + 0.5, 0.0, 1.0)
			c = c.blend(Color(knob, ka))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
