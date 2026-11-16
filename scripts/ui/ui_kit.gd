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
const INK_SOFT := Color("#7a5434")
const MOSS := Color("#3f7a2c")
const EMBER := Color("#c8642a")
const DANGER := Color("#b3392e")
const GOLD := Color("#e8b83a")

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

static func make_theme(large_text: bool, high_contrast: bool) -> Theme:
	var t := Theme.new()
	t.default_font = ThemeDB.fallback_font
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
	t.set_constant("separation", "VBoxContainer", 3)
	t.set_constant("separation", "HBoxContainer", 4)
	t.set_constant("h_separation", "GridContainer", 2)
	t.set_constant("v_separation", "GridContainer", 2)
	return t

## A parchment panel with nails in the corners and a strip of tape: "lightly worn".
class WornPanel extends PanelContainer:
	var tape := true
	func _draw() -> void:
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
	return p

static func label(text: String, size := 0, color = null, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
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

static func title(text: String, size := 12) -> Label:
	var l := label(text, size, WOOD_DARK)
	return l

static func button(text: String, cb: Callable, kind := "", min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = min_w
	if kind == "big":
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

static func row_box(color := PARCH_2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(color, PARCH_3, 1, 2, Color(0, 0, 0, 0), 0, 3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## An item slot: icon + quantity. on_click(button_index) gets 1 for left, 2 for right.
static func slot(stack, on_click = null, tier := 0, selected := false, locked := false, size := 20) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
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
		b.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and (ev.button_index == MOUSE_BUTTON_LEFT or ev.button_index == MOUSE_BUTTON_RIGHT):
				Sfx.play("menu")
				on_click.call(1 if ev.button_index == MOUSE_BUTTON_LEFT else 2)
				b.accept_event())
	return b

static func hearts(n: int) -> String:
	var s := ""
	for i in Balance.friendship.max_hearts:
		s += "[color=#e0405a]♥[/color]" if i < n else "[color=#c8a888]♥[/color]"
	return s
