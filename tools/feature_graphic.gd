extends Control
## The Google Play feature graphic (1024 x 500): the logo's three pieces settling
## into their square on the brand night, the name and a plain line about the game.
## Rendered by `godot --path . --resolution 1024x500 res://tools/render_feature_graphic.tscn`.

const TOP: Color = Color("#3A2F7A")
const BOTTOM: Color = Color("#15122F")
const WHITE: Color = Color("#F4F1FF")


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([TOP, BOTTOM, BOTTOM, TOP]))
	# A scatter of faint blocks, like the game's backdrop.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for i: int in 22:
		var p: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var s: float = rng.randf_range(8.0, 20.0)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, rng.randf_range(0.03, 0.08))
		sb.set_corner_radius_all(int(s * 0.35))
		draw_set_transform(p, rng.randf() * TAU, Vector2.ONE)
		draw_style_box(sb, Rect2(-Vector2(s, s), Vector2(s, s) * 2.0))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# The logo: two pieces in, the third just about to land.
	var cs: float = 112.0
	var grid: Vector2 = Vector2(92, 82)
	var plate: Dictionary = {}
	for y: int in 3:
		for x: int in 3:
			plate[Vector2i(x, y)] = true
	BlockStyles._blob(self, plate, grid, cs, -cs * 0.12, cs * 0.3, BlockStyles.solid(TOP.lerp(BOTTOM, 0.5), Color(1, 1, 1, 0.08)))
	var pal: Dictionary = {"ink": WHITE, "top": TOP, "dark": true}
	for i: int in Splash.PIECES.size():
		var lift: Vector2 = Vector2(cs * 0.55, -cs * 0.35) if i == 2 else Vector2.ZERO
		BlockStyles.draw_piece(self, "soft", FitSim.to_cells(Splash.PIECES[i]), grid + lift, cs, Splash.COLORS[i], pal, 1.0 if i == 2 else 0.0)
	# Name and line.
	draw_string(UIKit.font(900), Vector2(540, 236), "Snug Fit", HORIZONTAL_ALIGNMENT_LEFT, -1, 86, WHITE)
	var body: Font = UIKit.font(700)
	draw_string(body, Vector2(546, 298), "A calm shape puzzle.", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 1, 1, 0.75))
	draw_string(body, Vector2(546, 346), "Every piece. One snug fit.", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#FFCD7A"))
