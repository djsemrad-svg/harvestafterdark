class_name UIKit
extends RefCounted
## Builds the game's look: warm wood-and-parchment panels with light wear
## (nails, tape, scuffs), plus small helpers for labels, buttons and slots.

const PARCH := Color("#f8d9a0")
const PARCH_2 := Color("#efc584")
const PARCH_3 := Color("#d9a35f")
const WOOD := Color("#a8561b")
const WOOD_DARK := Color("#5a2c0e")
const OUTLINE := Color("#2e1607")
const INK := Color("#4a2a12")
const INK_SOFT := Color("#5c3a1c")
const MOSS := Color("#3f7a2c")
const EMBER := Color("#c8642a")
const DANGER := Color("#b3392e")
const GOLD := Color("#e8b83a")
const PAPER_INK := Color("#f2e6d0")

## True when the pack interface art is installed (art/ui/) and high contrast is off: panels,
## buttons and slots then use Kenney's wood-and-parchment frames and the PostApocalypse slate cells.
static var textured := false

static func ui_tex(name: String) -> Texture2D:
	return Art.override("ui/%s.png" % name)

## Frame widths (pixels) of the Modern User Interface pieces cut by tools/mui_ui.py. When that art is
## installed these win over the width a caller passes, since every piece has its own border.
## Values are [left, top, right, bottom] or one number for all four sides.
const FRAMES := {
	"window": 8, "panel_plain": 6, "panel": 6, "hud_panel": 6, "portrait": 6, "panel_danger": 6,
	"tooltip": 3, "row": 4, "slot": 4, "slot_hover": 4, "slot_selected": 4,
	"button": [4, 4, 4, 5], "button_hover": [4, 4, 4, 5], "button_pressed": [4, 5, 4, 4], "button_disabled": [4, 4, 4, 5],
	"button_green": [4, 4, 4, 5], "button_green_hover": [4, 4, 4, 5], "button_red": [4, 4, 4, 5], "button_red_hover": [4, 4, 4, 5],
	"badge": 4, "badge_bad": 4, "badge_good": 4, "bar_track": [4, 3, 4, 4], "slider_track": [5, 4, 5, 4],
}
static var _modern = null

## True when the Modern User Interface pieces are installed (art/ui/window.png).
static func modern() -> bool:
	if _modern == null:
		_modern = ui_tex("window") != null
	return _modern

## A nine-slice style from an interface picture: m = the frame's width in pixels.
static func tsb(name: String, m: int, pad := -1) -> StyleBoxTexture:
	var t := ui_tex(name)
	if t == null:
		return null
	var s := StyleBoxTexture.new()
	s.texture = t
	if modern() and FRAMES.has(name):
		var f = FRAMES[name]
		var e: Array = f if f is Array else [f, f, f, f]
		s.texture_margin_left = e[0]; s.texture_margin_top = e[1]
		s.texture_margin_right = e[2]; s.texture_margin_bottom = e[3]
		m = maxi(m, int(e.max()) - 1)
	else:
		s.set_texture_margin_all(m)
	s.set_content_margin_all(m if pad < 0 else pad)
	return s

static func sb(bg: Color, border: Color, bw := 2, radius := 3, shadow := OUTLINE, shadow_size := 2, pad := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.shadow_color = shadow
	s.shadow_size = shadow_size
	s.set_content_margin_all(pad)
	s.anti_aliasing = false
	return s

static var _ui_font: Font = null
## The game's text font: art/fonts/ui.ttf (Tiny5, a free pixel font) drawn crisp at whole-pixel sizes, or
## Godot's built-in font if it's missing. Sizes under 16 draw at the font's own 8 px size; 16+ at twice that.
static func ui_font() -> Font:
	if _ui_font != null: return _ui_font
	_ui_font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://art/fonts/ui.ttf"):
		var f = load("res://art/fonts/ui.ttf")
		if f is FontFile:
			f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			f.hinting = TextServer.HINTING_NONE
			f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			f.fixed_size = 8
			f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
			_ui_font = f
	return _ui_font

static func make_theme(large_text: bool, high_contrast: bool) -> Theme:
	var t := Theme.new()
	t.default_font = ui_font()
	t.default_font_size = 9 if large_text else 7
	var parch := Color.WHITE if high_contrast else PARCH
	var ink := Color.BLACK if high_contrast else INK
	t.set_color("font_color", "Label", ink)
	t.set_color("default_color", "RichTextLabel", ink)
	t.set_stylebox("panel", "PanelContainer", sb(parch, Color.BLACK if high_contrast else WOOD, 2, 3, OUTLINE, 2, 6))
	t.set_stylebox("panel", "Panel", sb(parch, WOOD))
	# buttons: varnished wood plank
	var bn := sb(Color("#b8682a"), WOOD_DARK, 1, 2, OUTLINE, 1, 3)
	bn.content_margin_left = 6; bn.content_margin_right = 6
	var bh := bn.duplicate(); bh.bg_color = Color("#cf7c34")
	var bp := bn.duplicate(); bp.bg_color = Color("#8e4c1c")
	var bd := bn.duplicate(); bd.bg_color = Color("#9a7a60")
	for st in [["normal", bn], ["hover", bh], ["pressed", bp], ["disabled", bd], ["focus", StyleBoxEmpty.new()]]:
		t.set_stylebox(st[0], "Button", st[1])
	t.set_color("font_color", "Button", Color("#fff1d6"))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color("#ffe7b8"))
	t.set_color("font_disabled_color", "Button", Color("#e8d8c0"))
	t.set_constant("outline_size", "Button", 2)
	t.set_color("font_outline_color", "Button", Color(0.18, 0.08, 0.02, 0.8))
	t.set_stylebox("normal", "LineEdit", sb(Color("#fff6e4"), WOOD, 1, 2, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("focus", "LineEdit", sb(Color("#fff6e4"), GOLD, 1, 2, Color(0, 0, 0, 0), 0, 3))
	t.set_color("font_color", "LineEdit", ink)
	t.set_color("font_color", "CheckBox", ink)
	t.set_stylebox("panel", "TooltipPanel", sb(Color("#fff1d0"), WOOD, 1, 2, OUTLINE, 1, 3))
	t.set_color("font_color", "TooltipLabel", ink)
	t.set_font_size("font_size", "TooltipLabel", 7)
	t.set_stylebox("scroll", "VScrollBar", sb(PARCH_3, PARCH_3, 0, 2, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("grabber", "VScrollBar", sb(WOOD, WOOD, 0, 2, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", sb(EMBER, EMBER, 0, 2, Color(0, 0, 0, 0), 0, 0))
	textured = not high_contrast and ui_tex("panel") != null
	if textured:
		t.set_stylebox("panel", "PanelContainer", tsb("panel_plain", 5, 7))
		t.set_stylebox("panel", "Panel", tsb("panel_plain", 5, 7))
		for st in [["normal", "button"], ["hover", "button_hover"], ["pressed", "button_pressed"], ["disabled", "button_disabled"]]:
			var b := tsb(st[1], 4, 3)
			b.content_margin_left = 7; b.content_margin_right = 7
			t.set_stylebox(st[0], "Button", b)
		t.set_stylebox("panel", "TooltipPanel", tsb("tooltip", 4, 4))
		if modern():
			# Modern UI buttons are light cards: dark lettering reads better than outlined white.
			t.set_color("font_color", "Button", INK)
			t.set_color("font_hover_color", "Button", WOOD_DARK)
			t.set_color("font_pressed_color", "Button", INK_SOFT)
			t.set_color("font_disabled_color", "Button", Color("#6a6a6a"))
			t.set_constant("outline_size", "Button", 0)
			var on := ui_tex("switch_on")
			if on != null:
				for k in ["checked", "checked_disabled"]:
					t.set_icon(k, "CheckBox", on)
				for k in ["unchecked", "unchecked_disabled"]:
					t.set_icon(k, "CheckBox", ui_tex("switch_off"))
				t.set_constant("h_separation", "CheckBox", 4)
			if ui_tex("slider_track") != null:
				var tr := tsb("slider_track", 4, 0)
				tr.content_margin_top = 3; tr.content_margin_bottom = 3
				t.set_stylebox("slider", "HSlider", tr)
				var fill := tsb("slider_track", 4, 0)
				fill.modulate_color = Color(1.25, 1.1, 0.8)
				fill.content_margin_top = 3; fill.content_margin_bottom = 3
				t.set_stylebox("grabber_area", "HSlider", fill)
				t.set_stylebox("grabber_area_highlight", "HSlider", fill)
				t.set_icon("grabber", "HSlider", ui_tex("slider_knob"))
				t.set_icon("grabber_highlight", "HSlider", ui_tex("slider_knob"))
			t.set_stylebox("scroll", "VScrollBar", sb(Color("#a88c70"), Color("#3a3a50"), 1, 2, Color(0, 0, 0, 0), 0, 0))
			t.set_stylebox("grabber", "VScrollBar", sb(Color("#d89a4e"), Color("#3a3a50"), 1, 2, Color(0, 0, 0, 0), 0, 0))
			t.set_stylebox("grabber_highlight", "VScrollBar", sb(Color("#f0b860"), Color("#3a3a50"), 1, 2, Color(0, 0, 0, 0), 0, 0))
			t.set_stylebox("normal", "LineEdit", tsb("slot", 4, 3))
			t.set_stylebox("focus", "LineEdit", tsb("slot_selected", 4, 3))
	t.set_constant("separation", "VBoxContainer", 3)
	t.set_constant("separation", "HBoxContainer", 4)
	t.set_constant("h_separation", "GridContainer", 2)
	t.set_constant("v_separation", "GridContainer", 2)
	return t

## A parchment panel with nails in the corners and a strip of tape: "lightly worn".
class WornPanel extends PanelContainer:
	var tape := true
	func _draw() -> void:
		if UIKit.textured:
			return
		var s := size
		for p in [Vector2(3, 3), Vector2(s.x - 5, 3), Vector2(3, s.y - 5), Vector2(s.x - 5, s.y - 5)]:
			draw_rect(Rect2(p, Vector2(2, 2)), Color("#6a6a72"))
			draw_rect(Rect2(p, Vector2(1, 1)), Color("#b8b8c0"))
		if tape and s.x > 120:
			draw_rect(Rect2(s.x * 0.72, -3, 22, 6), Color(0.93, 0.88, 0.72, 0.85))
			draw_rect(Rect2(s.x * 0.72, -3, 22, 1), Color(1, 1, 1, 0.4))
		# scuffs
		draw_rect(Rect2(8, s.y - 3, 10, 1), Color(0.55, 0.3, 0.1, 0.35))
		draw_rect(Rect2(s.x - 30, 2, 8, 1), Color(0.55, 0.3, 0.1, 0.25))

static func panel(min_w := 0.0, min_h := 0.0) -> WornPanel:
	var p := WornPanel.new()
	p.custom_minimum_size = Vector2(min_w, min_h)
	if textured and modern():
		p.add_theme_stylebox_override("panel", tsb("window", 8, 9))
	return p

## The pixel font is drawn on a 7 px grid. Sizes in between (8, 10, 12...) stretch some
## pixel columns and not others, which makes letters look smeared, so snap to 7, 14, 21 or 28.
static func crisp_size(size: int) -> int:
	if size <= 7: return size
	return clampi(int(round(size / 7.0)) * 7, 7, 28)

static func label(text: String, size := 0, color = null, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	if size > 0:
		l.add_theme_font_size_override("font_size", crisp_size(size))
	if color != null:
		l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func rich(bbcode: String, size := 0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size > 0:
		r.add_theme_font_size_override("normal_font_size", size)
		r.add_theme_font_size_override("bold_font_size", size)
	return r

static func title(text: String, size := 14) -> Label:
	var l := label(text, size, WOOD_DARK)
	return l

## Single-symbol buttons that become Modern UI icon buttons when that art is installed.
const GLYPH_BUTTONS := {"✕": ["close", "Close"], "◀": ["left", "Previous"], "▶": ["right", "Next"]}

## A square icon button from the Modern UI pack (art/ui/ib_<name>.png); brighter on hover, dimmer when pressed.
static func icon_button(name: String, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.icon = ui_tex("ib_" + name)
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(16, 16)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_color_override("icon_hover_color", Color(1.18, 1.14, 1.08))
	b.add_theme_color_override("icon_pressed_color", Color(0.85, 0.82, 0.8))
	b.add_theme_color_override("icon_disabled_color", Color(0.6, 0.6, 0.6, 0.7))
	b.pressed.connect(func():
		Sfx.play("menu")
		cb.call())
	return b

## Puts a small dark symbol (art/ui/glyph_<name>.png) in front of a text button's label.
static func with_glyph(b: Button, name: String) -> Button:
	if textured and modern() and ui_tex("glyph_" + name) != null:
		b.icon = ui_tex("glyph_" + name)
		b.add_theme_constant_override("h_separation", 3)
	return b

static func button(text: String, cb: Callable, kind := "", min_w := 0.0) -> Button:
	if textured and modern() and GLYPH_BUTTONS.has(text) and ui_tex("ib_" + GLYPH_BUTTONS[text][0]) != null:
		return icon_button(GLYPH_BUTTONS[text][0], cb, GLYPH_BUTTONS[text][1])
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = min_w
	if textured and kind in ["big", "danger"]:
		var nm := "button_green" if kind == "big" else "button_red"
		for st in [["normal", nm], ["hover", nm + "_hover"], ["pressed", nm]]:
			var ts := tsb(st[1], 4, 3)
			ts.content_margin_left = 10 if kind == "big" else 7; ts.content_margin_right = ts.content_margin_left
			if kind == "big": ts.content_margin_top = 4; ts.content_margin_bottom = 4
			b.add_theme_stylebox_override(st[0], ts)
		if kind == "big": b.add_theme_font_size_override("font_size", 9)
		if modern():
			b.add_theme_color_override("font_color", Color("#fff6e4"))
			b.add_theme_color_override("font_hover_color", Color.WHITE)
			b.add_theme_color_override("font_pressed_color", Color("#fff6e4"))
			b.add_theme_constant_override("outline_size", 2)
			b.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.12, 0.85))
	elif kind == "big":
		var s := sb(Color("#5e9a44"), Color("#2c5a1c"), 1, 2, OUTLINE, 1, 4)
		s.content_margin_left = 10; s.content_margin_right = 10
		b.add_theme_stylebox_override("normal", s)
		var h := s.duplicate(); h.bg_color = Color("#6eae52"); b.add_theme_stylebox_override("hover", h)
		var p := s.duplicate(); p.bg_color = Color("#4a8434"); b.add_theme_stylebox_override("pressed", p)
		b.add_theme_font_size_override("font_size", 9)
	elif kind == "danger":
		var s := sb(Color("#a8443a"), Color("#5a1a14"), 1, 2, OUTLINE, 1, 3)
		s.content_margin_left = 6; s.content_margin_right = 6
		b.add_theme_stylebox_override("normal", s)
		var h := s.duplicate(); h.bg_color = Color("#bc5448"); b.add_theme_stylebox_override("hover", h)
	elif kind == "small":
		b.add_theme_font_size_override("font_size", 6)
	b.pressed.connect(func():
		Sfx.play("menu")
		cb.call())
	return b

## A conversation portrait that blinks now and then (Portrait Generator heads only).
static func blinking(look: Dictionary, px: int) -> TextureRect:
	var t := icon(Art.get_portrait(look), px)
	if MiChars.pg_available() and not look.get("infected", false):
		var open_tex := Art.get_portrait(look)
		var shut := Art.get_portrait(look, 2)
		var tw := t.create_tween().set_loops()
		tw.tween_interval(2.6)
		tw.tween_callback(func(): t.texture = shut)
		tw.tween_interval(0.14)
		tw.tween_callback(func(): t.texture = open_tex)
	return t

static func icon(tex: Texture2D, px := 16) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

static func hbox(sep := -1) -> HBoxContainer:
	var h := HBoxContainer.new()
	if sep >= 0: h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

static func vbox(sep := -1) -> VBoxContainer:
	var v := VBoxContainer.new()
	if sep >= 0: v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

static func scroll(child: Control, h: float) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size.y = h
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

## A pack frame tinted toward a colour (base = the frame's own fill colour), or null without pack art.
static func tinted(name: String, m: int, pad: int, color: Color, base := PARCH_2) -> StyleBoxTexture:
	var ts := tsb(name, m, pad)
	if ts != null and color != base:
		ts.modulate_color = Color(color.r / maxf(base.r, 0.01), color.g / maxf(base.g, 0.01), color.b / maxf(base.b, 0.01), color.a)
	return ts

static func row_box(color := PARCH_2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", tinted("row", 3, 3, color) if textured else sb(color, PARCH_3, 1, 2, Color(0, 0, 0, 0), 0, 3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## An item slot: icon + quantity. on_click(button_index) gets 1 for left, 2 for right.
static func slot(stack, on_click = null, tier := 0, selected := false, locked := false, size := 20) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	if textured:
		var ts := tsb("slot_selected" if selected else "slot", 4, 1)
		b.add_theme_stylebox_override("normal", ts)
		b.add_theme_stylebox_override("pressed", ts)
		b.add_theme_stylebox_override("hover", tsb("slot_selected" if selected else "slot_hover", 4, 1))
	else:
		var bg := Color("#fbe3b4") if selected else Color("#f0c88a")
		var s := sb(bg, Color("#e8402a") if selected else Color("#c0803e"), 1, 1, Color(0, 0, 0, 0), 0, 1)
		b.add_theme_stylebox_override("normal", s)
		var h := s.duplicate(); h.border_color = GOLD; b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if stack != null and Data.items.has(stack.id):
		var it: Dictionary = Data.items[stack.id]
		var ic := icon(Art.get_icon(stack.id, tier), size - 4)
		ic.position = Vector2(2, 2)
		ic.size = Vector2(size - 4, size - 4)
		if locked or (it.has("tool") and Game.tool_busy(it.tool) != null) or Game.is_broken(stack):
			ic.modulate = Color(1, 1, 1, 0.35)
		b.add_child(ic)
		# rarity corner, durability bar and loaded rounds for weapons and gear
		var rar: String = it.get("rarity", "")
		if rar != "" and rar != "Normal":
			var rc := ColorRect.new()
			rc.color = Color(Arsenal.rarity_color(rar))
			rc.size = Vector2(3, 3)
			rc.position = Vector2(1, 1)
			rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(rc)
		var ql := Game.quality_of(stack)
		if ql > 0:
			# crop quality: a small silver or gold star in the bottom-left corner
			var qc := Color(FarmCare.QUALITY_COLOR[ql])
			for pt in [[2, size - 6, 3, 1], [3, size - 7, 1, 3], [2, size - 5, 1, 1], [4, size - 5, 1, 1]]:
				var st := ColorRect.new()
				st.color = qc
				st.position = Vector2(pt[0], pt[1]); st.size = Vector2(pt[2], pt[3])
				st.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(st)
		var md := Game.max_dur(stack.id)
		if md > 0 and (stack.has("dur") or Game.is_broken(stack)):
			var frac: float = clampf(float(Game.stack_dur(stack)) / float(md), 0.0, 1.0)
			var bg2 := ColorRect.new()
			bg2.color = Color(0, 0, 0, 0.5)
			bg2.size = Vector2(size - 4, 2)
			bg2.position = Vector2(2, size - 3)
			bg2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(bg2)
			var fg := ColorRect.new()
			fg.color = Color("#e04030") if frac < 0.25 else (Color("#e8c030") if frac < 0.6 else Color("#60c040"))
			fg.size = Vector2(maxf(1.0, (size - 4) * frac), 2)
			fg.position = Vector2(2, size - 3)
			fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(fg)
		if Data.weapons.has(stack.id):
			var wd: Dictionary = Data.weapons[stack.id]
			if int(wd.mag) > 1 and wd.mode in ["shoot", "throw", "saw"]:
				var ml := label(str(int(Game.mag_of(stack))), 5, Color("#ffe080"))
				ml.add_theme_constant_override("outline_size", 2)
				ml.add_theme_color_override("font_outline_color", Color.BLACK)
				ml.position = Vector2(size - 4 - 3 * str(int(Game.mag_of(stack))).length(), size - 11)
				ml.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(ml)
		if int(stack.qty) > 1:
			var q := label(str(stack.qty), 6, Color.WHITE)
			q.add_theme_constant_override("outline_size", 2)
			q.add_theme_color_override("font_outline_color", Color.BLACK)
			q.position = Vector2(size - 4 - 4 * str(stack.qty).length(), size - 10)
			b.add_child(q)
		b.tooltip_text = Game.item_display_name(stack.id) + ("" if it.price <= 0 else "  (%d gold each)" % it.price) + ("  [BROKEN]" if Game.is_broken(stack) else "") + "\n" + it.desc
	if on_click != null:
		# Right-click acts on press; left-click on release over the slot, so a press can still start a drag.
		b.gui_input.connect(func(ev):
			if not (ev is InputEventMouseButton):
				return
			var right: bool = ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed
			var left: bool = ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed and Rect2(Vector2.ZERO, b.size).has_point(ev.position)
			if right or left:
				Sfx.play("menu")
				on_click.call(1 if left else 2)
				b.accept_event())
	return b

static func hearts(n: int) -> String:
	var s := ""
	for i in Balance.friendship.max_hearts:
		s += "[color=#e0405a]♥[/color]" if i < n else "[color=#c8a888]♥[/color]"
	return s

## A HUD bar from the PostApocalypse pack: an icon, then a framed track with a coloured fill.
class HudBar extends Control:
	var kind := "health"
	var frac := 1.0
	var text := ""  # the bar's name, shown as its tooltip
	func _init(k: String, f: float, w := 52.0) -> void:
		kind = k
		text = k.capitalize()
		tooltip_text = text
		frac = clampf(f, 0.0, 1.0)
		custom_minimum_size = Vector2(15 + w, 13 if UIKit.modern() else 12)
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _draw() -> void:
		var h := size.y
		var ic := UIKit.ui_tex("icon_" + kind)
		if ic != null:
			draw_texture(ic, Vector2(0, roundf((h - ic.get_height()) / 2.0)))
		var tw := size.x - 15
		var tr := UIKit.tsb("bar_track", 4, 0)
		var fill := UIKit.ui_tex("bar_" + kind)
		if UIKit.modern():
			# Modern UI: dark track with an orange rim; the glossy fill sits in the dark part (3 px in, rows 2-7).
			draw_style_box(tr, Rect2(15, 0, tw, 13))
			var mw := roundf((tw - 6) * frac)
			if fill != null and mw > 0:
				var fs := StyleBoxTexture.new()
				fs.texture = fill
				fs.texture_margin_left = 2; fs.texture_margin_right = 2
				draw_style_box(fs, Rect2(18, 2, maxf(mw, 4), 6))
			return
		tr.texture_margin_top = 4; tr.texture_margin_bottom = 4; tr.texture_margin_left = 3; tr.texture_margin_right = 3
		draw_style_box(tr, Rect2(15, 0, tw, 12))
		var fw := roundf((tw - 4) * frac)
		if fill != null and fw > 0:
			draw_texture_rect(fill, Rect2(17, 4, fw, 4), false)
