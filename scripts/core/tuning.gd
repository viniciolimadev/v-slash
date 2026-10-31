class_name Tuning
extends RefCounted
## Todos os números de "feel" num lugar só. Ajuste aqui primeiro.
## Convenção: rede no plano z = 0. Você (time 0) joga em z > 0; o bot (time 1) em z < 0.

# --- Quadra (metros) ---
const COURT_HALF_W := 3.5          # meia largura: quadra de 7 m (1v1 pede quadra menor que 9 m)
const COURT_DEPTH := 7.0           # fundo de cada lado
const NET_HEIGHT := 2.43
const NET_HALF_LEN := 4.2          # a rede passa um pouco das antenas
const LINE_TOLERANCE := 0.05       # bola na linha = dentro

# --- Bola ---
const BALL_RADIUS := 0.16          # maior que a real (0,105) p/ ler na tela do celular
const GRAVITY := 11.0              # acima de 9,8 = jogo mais ágil
const SPIKE_GRAVITY := 16.0        # cortada "com topspin": passa alto na rede e mergulha
const NET_BOUNCE := 0.25           # fração da velocidade que volta ao bater na rede
const FLOOR_BOUNCE := 0.45

# --- Alturas de contato (centro da bola) ---
const H_RECEIVE := 0.9             # manchete
const H_SET := 2.25                # toque acima da cabeça
const H_ATTACK := 3.05             # cortada no alto do pulo

# --- Tempos de voo (s) ---
const T_RECEIVE := 1.35
const T_SET_HIGH := 1.15
const T_SET_QUICK := 0.75
const T_FREEBALL := 1.5
const T_SERVE := 1.45
const ATTACK_SPEED_MIN := 9.0      # m/s na horizontal com toque ruim
const ATTACK_SPEED_MAX := 14.0     # m/s na horizontal com toque perfeito
const NET_CLEARANCE := 0.12        # folga mínima acima da rede

# --- Timing do toque (s) ---
const WINDOW_EARLY := 0.35         # quanto antes do ideal ainda vale
const WINDOW_LATE := 0.15          # quanto depois do ideal ainda vale
const PERFECT := 0.07
const GOOD := 0.16
const EARLY_SNAP := 0.06           # toque adiantado só executa perto do ponto ideal
const RING_LEAD := 1.0             # o anel começa a fechar 1 s antes
const WHIFF_COOLDOWN := 0.4
const MAX_TOUCHES := 3           # toques por lado (no 1v1, todos do mesmo jogador)

# --- Dispersão do alvo (m) quando a qualidade é 0 ---
const SCATTER_RECEIVE := 1.8
const SCATTER_SET := 1.2
const SCATTER_ATTACK := 2.2
const SCATTER_SERVE := 0.7

# --- Jogador ---
const MOVE_SPEED := 6.2
const ACCEL := 45.0
const REACH := 1.5                 # alcance horizontal até a bola (generoso: é celular)
const JUMP_HEIGHT := 0.75
const JUMP_TIME_UP := 0.42
const JUMP_DRIFT := 2.5            # m/s de correção no ar (assistência)
const MAGNET_RADIUS := 0.7         # assistência: puxa p/ o anel se você largar o joystick perto
const MAGNET_SPEED := 2.2

# --- Mira ---
const AIM_SENS := 0.028            # metros por pixel arrastado
const AIM_DEEP := 5.5              # posição inicial da mira de saque/ataque: fundo da quadra adversária (m da rede)
const SET_MAGNET_RADIUS := 1.3
# assistência de mira (só para o humano)
const AIM_MARGIN := 0.5            # a mira não sai da quadra: fica 0,5 m para dentro das linhas
const AIM_MAGNET_RADIUS := 1.2     # saque/ataque: a mira gruda na zona mais próxima
const RECEIVE_MAGNET_RADIUS := 1.8 # recepção: gruda no levantador
const ASSIST_KEEP_IN_Q := 0.7      # toque BOM ou melhor: a bola não sai da quadra
# zonas de saque/ataque na quadra adversária: (x, distância da rede); x > 0 = sua direita
const ATTACK_ZONES := [
	["FUNDO", Vector2(0.0, 5.8)],
	["FUNDO ESQ", Vector2(-2.6, 5.8)],
	["FUNDO DIR", Vector2(2.6, 5.8)],
	["MEIO", Vector2(0.0, 3.4)],
	["CURTA ESQ", Vector2(-2.2, 1.8)],
	["CURTA DIR", Vector2(2.2, 1.8)],
]
const SETTER_SPOT := Vector2(0.8, 1.6)   # (x, z) do levantamento do time 0; o bot usa o espelho

# --- Bot: índice 0 = fácil, 1 = médio, 2 = difícil ---
const BOT_NAMES := ["Fácil", "Médio", "Difícil"]
const BOT_SPEED := [4.6, 5.4, 6.0]
const BOT_REACTION := [0.4, 0.3, 0.22]
const BOT_TIMING_SIGMA := [0.13, 0.08, 0.045]
const BOT_POWER := [0.0, 0.5, 0.75]
const BOT_READS_OUT := [0.4, 0.7, 0.9]
