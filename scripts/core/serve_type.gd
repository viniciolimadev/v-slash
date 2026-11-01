class_name ServeType
extends RefCounted
## Tipos de saque. Os números de cada um ficam em Tuning (arrays indexados por Kind).

enum Kind { UNDER, FLOAT, JUMP }
const NAMES := ["POR BAIXO", "FLUTUANTE", "VIAGEM"]


## Tipos com lançamento da bola e anel de timing (POR BAIXO saca direto).
static func is_tossed(kind: int) -> bool:
	return float(Tuning.SERVE_TOSS_H[kind]) > 0.0
