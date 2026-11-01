class_name Icons
extends RefCounted
## Ícones vetoriais desenhados com draw_* (sem textura): um por ação do botão (B4-5: ícone
## além do texto, não no lugar) e o da pausa. `s` = meia altura do ícone em pixels.


static func draw_act(ci: CanvasItem, act: int, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(2.0, s * 0.16)
	match act:
		Game.Act.SERVE:
			# bola subindo com seta
			ci.draw_circle(c + Vector2(0.0, -s * 0.45), s * 0.38, col)
			ci.draw_line(c + Vector2(0.0, s * 0.95), c + Vector2(0.0, s * 0.05), col, w, true)
			_head(ci, c + Vector2(0.0, s * 0.02), Vector2.UP, s * 0.35, col, w)
		Game.Act.RECEIVE, Game.Act.FREEBALL:
			# manchete: bola sobre os antebraços juntos (V)
			ci.draw_circle(c + Vector2(0.0, -s * 0.5), s * 0.34, col)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.8, s * 0.1), c + Vector2(0.0, s * 0.85),
					c + Vector2(s * 0.8, s * 0.1)]), col, w * 1.3, true)
		Game.Act.SET_BALL:
			# toque: duas mãos abertas sob a bola
			ci.draw_circle(c + Vector2(0.0, -s * 0.55), s * 0.34, col)
			for sx: float in [-1.0, 1.0]:
				var base := c + Vector2(sx * s * 0.45, s * 0.75)
				ci.draw_line(base, base + Vector2(sx * s * 0.1, -s * 0.85), col, w, true)
				ci.draw_line(base + Vector2(sx * s * 0.1, -s * 0.85), base + Vector2(sx * s * 0.4, -s * 0.6), col, w, true)
		Game.Act.ATTACK:
			# raio
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.2, -s), c + Vector2(-s * 0.55, s * 0.12),
					c + Vector2(-s * 0.02, s * 0.12), c + Vector2(-s * 0.25, s), c + Vector2(s * 0.55, -s * 0.18),
					c + Vector2(s * 0.02, -s * 0.18)]), col)
		Game.Act.BLOCK:
			# duas mãos (palmas) lado a lado
			for sx: float in [-1.0, 1.0]:
				var r := Rect2(c + Vector2(sx * s * 0.42 - s * 0.32, -s * 0.85), Vector2(s * 0.64, s * 1.5))
				ci.draw_rect(r, col)
		Game.Act.DINK:
			# arco curto por cima de uma barra (o bloqueio)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.15, -s * 0.1), Vector2(s * 0.3, s * 1.0)), col)
			ci.draw_arc(c + Vector2(0.0, s * 0.1), s * 0.75, PI, TAU, 16, col, w, true)
			_head(ci, c + Vector2(s * 0.75, s * 0.1), Vector2.DOWN, s * 0.3, col, w)
		Game.Act.DIVE:
			# corpo esticado no chão alcançando a bola
			ci.draw_circle(c + Vector2(-s * 0.7, -s * 0.25), s * 0.3, col)
			ci.draw_line(c + Vector2(-s * 0.35, s * 0.25), c + Vector2(s * 0.9, s * 0.55), col, w * 1.6, true)
			ci.draw_line(c + Vector2(-s * 0.95, s * 0.75), c + Vector2(s * 0.95, s * 0.75), col, w * 0.8, true)


static func draw_pause(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		ci.draw_rect(Rect2(c + Vector2(sx * s * 0.35 - s * 0.16, -s * 0.6), Vector2(s * 0.32, s * 1.2)), col)


static func _head(ci: CanvasItem, tip: Vector2, dir: Vector2, size: float, col: Color, w: float) -> void:
	var side := dir.orthogonal()
	ci.draw_line(tip, tip - dir * size + side * size * 0.8, col, w, true)
	ci.draw_line(tip, tip - dir * size - side * size * 0.8, col, w, true)
