class_name ScreenBackdrop
extends Control
## Fundo ilustrado das telas de menu: céu de fim de tarde, sol, mar, areia e dois coqueiros,
## tudo com draw_* (escala com a tela, nenhum arquivo).

const SKY_TOP := Color(0.1, 0.36, 0.56)
const SKY_LOW := Color(0.98, 0.72, 0.48)
const SEA := Color(0.1, 0.5, 0.6)
const SAND := Color(0.86, 0.73, 0.52)
const INK := Color(0.05, 0.12, 0.2)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * 0.56
	_grad(Rect2(0.0, 0.0, w, horizon), SKY_TOP, SKY_LOW)
	draw_circle(Vector2(w * 0.68, horizon - h * 0.02), h * 0.11, Color(1.0, 0.86, 0.55))
	_grad(Rect2(0.0, horizon, w, h * 0.16), SEA.lightened(0.15), SEA.darkened(0.15))
	for i in 7:
		var y := horizon + h * (0.02 + 0.02 * i)
		var x0 := w * fposmod(0.13 * i * 3.7, 1.0)
		draw_line(Vector2(x0, y), Vector2(x0 + w * 0.12, y), Color(1.0, 1.0, 1.0, 0.22), 2.0)
	_grad(Rect2(0.0, horizon + h * 0.16, w, h), SAND.lightened(0.08), SAND.darkened(0.08))
	_palm(Vector2(w * 0.07, h * 1.02), h, 1.0)
	_palm(Vector2(w * 0.95, h * 1.04), h * 0.85, -1.0)


func _grad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([top, top, bottom, bottom]))


## Silhueta de coqueiro: tronco curvo e folhas em leque.
func _palm(base: Vector2, h: float, lean: float) -> void:
	var top := base + Vector2(lean * h * 0.12, -h * 0.62)
	var pts := PackedVector2Array()
	for k in 9:
		var u := k / 8.0
		pts.append(base.lerp(top, u) + Vector2(lean * sin(u * PI) * h * 0.05, 0.0))
	draw_polyline(pts, INK, h * 0.022, true)
	for k in 7:
		var ang := PI * (1.05 + 0.15 * k) if lean > 0.0 else PI * (1.05 + 0.15 * k)
		var dir := Vector2(cos(ang), sin(ang) * 0.6 + 0.15)
		var tip := top + dir * h * 0.2
		var mid := top + dir * h * 0.1 + Vector2(0.0, -h * 0.03)
		var n := dir.orthogonal() * h * 0.02
		draw_colored_polygon(PackedVector2Array([top, mid + n, tip, mid - n]), INK)
