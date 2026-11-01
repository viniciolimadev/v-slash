class_name Tuning
extends RefCounted
## Todos os números de "feel" num lugar só. Ajuste aqui primeiro.
## Convenção: rede no plano z = 0. Você (time 0) joga em z > 0; o bot (time 1) em z < 0.

# --- Quadra (metros) ---
# (meia largura, fundo de cada lado) por modo; quem usa lê de CourtSpec
const COURT_1V1 := Vector2(3.5, 7.0)   # quadra de 7 m de largura (1v1 pede quadra menor que 9 m)
const COURT_2V2 := Vector2(4.0, 8.0)   # 8 × 8 por lado, como no vôlei de praia
const NET_HEIGHT := 2.43
const NET_OVERHANG := 0.7          # m que a rede passa das antenas, de cada lado
const LINE_TOLERANCE := 0.05       # bola na linha = dentro

# --- Visual (Fase 4) ---
const USE_MODEL_VIEWS := true      # false = formas simples das Fases 0–3 (PlayerViewSimple, quadra lisa)

# --- Partida ---
const SET_POINTS := 15
const SETS_TO_WIN := 2             # melhor de 3
const WIN_BY := 2                  # vantagem mínima para fechar o set
const POINT_PAUSE := 1.8           # s entre um ponto e o próximo saque
const SET_PAUSE := 3.0             # s de faixa "Fim do set" antes do saque seguinte
const MATCH_END_DELAY := 2.0       # s de comemoração antes da tela de resultado
const HINT_SECS := 4.0             # s da dica de primeira partida 2v2

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
const ATTACK_SPEED_MIN := 9.0      # m/s na horizontal com toque ruim
const ATTACK_SPEED_MAX := 14.0     # m/s na horizontal com toque perfeito
const NET_CLEARANCE := 0.12        # folga mínima acima da rede
const T_DINK := 0.9                # s de voo da largada (sobe até passar o bloqueio)
const DINK_DIST := 2.5             # m da rede: ataque mirado mais perto que isso vira largada
const DINK_APEX_MARGIN := 0.3      # m: a largada cruza a rede acima do alcance do bloqueio com esta folga

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
const SCATTER_DINK := 0.6

# --- Saque (índice = ServeType.Kind: POR BAIXO, FLUTUANTE, VIAGEM) ---
const SERVE_HAND_H := 1.5          # m: altura da mão que lança a bola para cima
const SERVE_TOSS_H := [0.0, 1.2, 2.6]        # m que a bola sobe acima da mão; 0 = sem lançamento
const SERVE_CONTACT_H := [1.05, 2.45, 3.0]   # m: altura do contato (centro da bola)
const SERVE_TIME := [1.45, 1.3, 1.05]        # s de voo até o alvo (por baixo = saque da Fase 1)
const SERVE_GRAV := [11.0, 11.0, 16.0]       # m/s²: a viagem tem "topspin" (= SPIKE_GRAVITY)
const SERVE_WINDOW := [1.0, 1.0, 0.7]        # multiplica WINDOW_EARLY/LATE, PERFECT e GOOD
const SERVE_SCATTER := [0.4, 0.8, 1.6]       # m de dispersão com qualidade 0
const SERVE_Q_UNDER := 0.9                   # por baixo não tem timing: qualidade fixa
const FLOAT_AMP := Vector2(0.35, 0.7)        # m de oscilação lateral do flutuante (qualidade 0 → 1)
const FLOAT_FREQ := 4.5                      # rad/s da oscilação (~1 balanço por saque)
const FLOAT_REVEAL := 0.45                   # s antes do contato em que o anel mostra a posição certa
const FLOAT_SLIDE := 0.15                    # s que o anel leva deslizando até a posição certa

# --- Bloqueio ---
const BLOCK_ZONE := 1.2            # m da rede: mais perto que isso, o botão vira BLOQUEAR
const BLOCK_DEPTH := 0.25          # m que as mãos passam da rede (do lado do atacante)
const BLOCK_HALF_W := 0.45         # m: meia largura das mãos
const BLOCK_REACH := 0.55          # m: topo das mãos acima da fita no pico do pulo
const BLOCK_RECOVER := 0.35        # s sem poder tocar depois de cair do bloqueio
const BLOCK_T_DOWN := 0.5          # s de voo do bloqueio PERFEITO (bola para baixo do lado do atacante)
const BLOCK_DOWN_DIST := Vector2(1.5, 3.0)   # m da rede onde cai o bloqueio PERFEITO
const BLOCK_T_SOFT := 1.5          # s de voo do bloqueio BOM (amortece e sobe do seu lado)
const BLOCK_SOFT_DIST := 3.0       # m da rede onde cairia o bloqueio BOM
const BLOCK_T_DEFLECT := 0.9       # s de voo do bloqueio ruim (desvia para fora)

# --- Jogador ---
const MOVE_SPEED := 6.2
const ACCEL := 45.0
const REACH := 1.5                 # alcance horizontal até a bola (generoso: é celular)
const DIVE_REACH := 2.1            # m: entre REACH e isto, o toque vira peixinho (automático)
const DIVE_Q_MAX := 0.35            # qualidade máxima do peixinho
const DIVE_RECOVER := 0.9          # s no chão depois do peixinho (sem andar)
const JUMP_HEIGHT := 0.75
const JUMP_TIME_UP := 0.42
const JUMP_DRIFT := 2.5            # m/s de correção no ar (assistência)
const MAGNET_RADIUS := 0.7         # assistência: puxa p/ o anel se você largar o joystick perto
const MAGNET_SPEED := 2.2

# --- Stamina (experimento, DP-03: só fica ligada se o teste no celular aprovar) ---
const STAMINA_ENABLED := false
const STAMINA_COST_JUMP_SERVE := 0.15   # fração da barra por saque viagem
const STAMINA_COST_ATTACK := 0.08       # por cortada, vezes a força (0..1)
const STAMINA_COST_BLOCK := 0.05        # por pulo de bloqueio
const STAMINA_COST_DIVE := 0.2          # por peixinho
const STAMINA_REGEN := 0.04             # por segundo com a bola em jogo
const STAMINA_POINT_BONUS := 0.25       # recupera a cada ponto
const STAMINA_TIRED := 0.3              # abaixo disto o jogador está cansado
const TIRED_SPEED := 0.85               # cansado: multiplica a velocidade
const TIRED_JUMP := 0.8                 # cansado: multiplica JUMP_HEIGHT
const TIRED_ATTACK := 0.9               # cansado: multiplica ATTACK_SPEED_MAX

# --- Mira ---
const AIM_SENS := 0.028            # metros por pixel arrastado
const AIM_DEEP := 5.5              # posição inicial da mira de saque/ataque: fundo da quadra adversária (m da rede)
const SET_MAGNET_RADIUS := 1.3
# assistência de mira (só para o humano)
const AIM_MARGIN := 0.5            # a mira não sai da quadra: fica 0,5 m para dentro das linhas
const AIM_MAGNET_RADIUS := 1.2     # saque/ataque: a mira gruda na zona mais próxima
const RECEIVE_MAGNET_RADIUS := 1.8 # recepção: gruda no levantador
const ASSIST_KEEP_IN_Q := 0.7      # toque BOM ou melhor: a bola não sai da quadra
# zonas de saque/ataque na quadra adversária: (x, distância da rede, largada?); x > 0 = sua direita.
# Em metros da quadra do 1v1 (CourtSpec.scaled leva para a quadra do modo).
const ATTACK_ZONES := [
	["FUNDO", Vector2(0.0, 5.8), false],
	["FUNDO ESQ", Vector2(-2.6, 5.8), false],
	["FUNDO DIR", Vector2(2.6, 5.8), false],
	["MEIO", Vector2(0.0, 3.4), false],
	["CURTA ESQ", Vector2(-2.2, 1.8), true],
	["CURTA DIR", Vector2(2.2, 1.8), true],
]
const SETTER_SPOT := Vector2(0.8, 1.6)   # (x, z) do levantamento do time 0 no 1v1; o bot usa o espelho

# --- Bot: índice 0 = fácil, 1 = médio, 2 = difícil ---
const BOT_NAMES := ["Fácil", "Médio", "Difícil"]
const PARTNER_LEVEL := 1           # seu parceiro no 2v2 joga como o Médio
const BOT_SPEED_2V2 := 0.9         # multiplica BOT_SPEED no 2v2 (dois cobrem a quadra; rally menor)
const BOT_SPEED := [4.6, 5.4, 6.0]
const BOT_REACTION := [0.4, 0.3, 0.22]
const BOT_TIMING_SIGMA := [0.13, 0.08, 0.045]
const BOT_POWER := [0.0, 0.5, 0.75]
const BOT_READS_OUT := [0.4, 0.7, 0.9]
const BOT_SERVE_MIX := [[1.0, 0.0, 0.0], [0.7, 0.3, 0.0], [0.3, 0.4, 0.3]]   # chance de POR BAIXO, FLUTUANTE, VIAGEM
const BOT_BLOCK_CHANCE := [0.0, 0.4, 0.75]   # chance de subir para bloquear quando você vai atacar
const BOT_BLOCK_SIGMA := [0.1, 0.1, 0.06]    # s de erro (desvio) no pulo do bloqueio
const BOT_DINK_CHANCE := [0.0, 0.15, 0.25]   # chance de largar em vez de cortar (Difícil: quando você bloqueia)
