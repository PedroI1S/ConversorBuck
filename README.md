# Conversor Buck com controle digital — Grupo do Sinal 1

Projeto da disciplina Controle Automático (UTFPR, Prof. Emerson Carati). Este arquivo é a memória do projeto: especificações, decisões, andamento e pendências. Cada etapa tem um documento próprio em `docs/`.

Enunciado: [Projeto.MD](Projeto.MD) · Slides: `WP2 - Projeto e Análise do conversor e do CCS.pdf`

## Especificações

| Item | Valor | Origem |
|---|---|---|
| Sinal de referência | Sinal 1: degraus com rampas, 6 / 12 / 18 V | WP2, slide 9 |
| Período / fundamental | 40 ms / f₁ = 25 Hz | WP2, slide 9 |
| Chaveamento = amostragem | fₛ = 10 kHz (Tₛ = 0,1 ms, N = 400 amostras/ciclo) | WP2, slide 9 |
| Tensão de entrada | E = 24 V nominal, distúrbio de ±6 V (18 a 30 V) | Enunciado, item 9 |
| Ripple de corrente | < 50 % | Enunciado, item 2 |
| Ripple de tensão | < 2 % | Enunciado, item 2 |
| Condução | Contínua (CCM) | Enunciado, item 2 |
| Perturbação de modelo | +30 % no amortecimento da planta | Enunciado, item 9 |
| Pseudocontínuo | ≥ 100 pontos por amostra discreta | Enunciado, item 5 |
| Carga R | 43,0 Ω: resistor de cimento de 46,6 Ω (10 W) em paralelo com 7 × 3k9 (1/4 W) | ζ = 0,648 e f_LC = 500 Hz |

## Decisões

| Decisão | Escolha |
|---|---|
| Linguagem da simulação | MATLAB (R2026a), script final único dividido em seções |
| Simulação de circuito | Simulink |
| Microcontrolador | STM32 Black Pill (F411CE, 100 MHz, ADC de 12 bits, 0–3,3 V) |
| Níveis do CCS | 0–30 V → divisor 1/12 → offset de 0,39 V → ADC em 0,39–2,86 V. Ampops: **LM324 em 5 V** (catálogo do DAINF), saída limitada a ~3,5 V, com 100 Ω em série com o PA1 |
| Sallen-Key | Segue o **slide 7** (decisão do grupo em 2026-11-24): α = 0,7 e ζ_PB = 0,3. Valores do catálogo: R1 = R2 = 1,5 kΩ, C1 = 220 nF, C2 = 22 nF → f_PB = 1525 Hz, ζ = 0,316 (pico de +4,4 dB perto de 1,4 kHz) |
| Montagem | **Só componentes PTH (sem SMD)**. Sequência de montagem e testes em [docs/roteiro_montagem.md](docs/roteiro_montagem.md) |
| Artigo | LaTeX com template do grupo; só começa quando o grupo pedir |
| Amortecimento do filtro LC | **ζ = 0,65**, escolhido pelo grupo em 2026-11-10 para reduzir o sobressinal. O professor orientou partir de ζ = 0,5 e testar; a varredura da Etapa 2 é a justificativa. Com ζ = 0,65 e f_LC = 500 Hz: R = 2417·L e C = 1,013×10⁻⁷/L (L em henry). Com L = 17,71 mH: R = 42,9 Ω e C = 5,7 µF. |
| Acionamento da chave | Optoacoplador **6N137** + 2× BC547 + MOSFET canal P **IRF9530** com zener de 15 V (escolha do grupo em 2026-11-23). Não inverte o PWM, chave desligada durante o boot, permite d = 1. Ver [docs/acionamento_chave.md](docs/acionamento_chave.md) |
| Saturação com E = 18 V | **Esperada** (decisão do grupo em 2026-11-24): no patamar de 18 V da referência com a fonte em 18 V, d satura em 1 e Vo fica um pouco abaixo de 18 V |
| PWM | Pulso **alinhado no início do período** (CA08), no firmware e em todas as simulações |
| Firmware | CMSIS + PlatformIO em [firmware/](firmware/README.md): modos d fixo e malha aberta, KEY, proteção e serial |
| Atividade 1 | Serve de consulta (firmware e CCS), mas o projeto recomeça do zero |

## Andamento

| # | Etapa (item do enunciado) | Situação | Documento |
|---|---|---|---|
| 1 | Sinal de referência em MATLAB | Feito em simulação | [etapa01](docs/etapa01_referencia.md) |
| 1b | Referência no Black Pill + filtro RC + osciloscópio | Pendente (bancada) | — |
| 2 | Projeto do conversor Buck (L, C) | Feito em MATLAB e no Simulink/Simscape com as peças reais (falta conferir saturação do indutor na bancada) | [etapa02](docs/etapa02_projeto_buck.md) |
| 3 | Projeto do CCS (atenuação, subtração, filtro, offset) | Feito em MATLAB e no Simulink/Simscape com o LM324 e os valores do catálogo (circuito completo) | [etapa03](docs/etapa03_projeto_ccs.md), [circuito completo](docs/circuito_completo_simulink.md) |
| 4 | Análise em malha aberta (degrau, Bode, harmônicas) | Feito em MATLAB | [etapa04](docs/etapa04_malha_aberta.md) |
| 5 | Discretização pseudocontínua | Pendente | — |
| 6 | Modelos de PWM, CCS e ADC | Pendente | — |
| 7 | Script de simulação em malha aberta | Pendente | — |
| 8 | Controladores digitais (P, PI, PID, feedforward) | Pendente | — |
| 9 | Malha fechada com perturbações | Pendente | — |
| 10 | Implementação experimental | Pendente | — |
| — | Artigo | Não iniciar ainda | — |

## Pendências com o grupo

Roteiro de montagem e testes: [docs/roteiro_montagem.md](docs/roteiro_montagem.md). Lista de compras/checagem: [docs/lista_componentes.md](docs/lista_componentes.md) (2026-11-23). Conferência no catálogo do DAINF: [docs/disponibilidade_dainf.md](docs/disponibilidade_dainf.md). Fora do catálogo: já conseguidos o indutor (17,71 mH), o diodo FCH20A20, o 6N137 e o resistor de carga de 10 W (46,6 Ω medido).


1. ~~Indutor~~: resolvido em 2026-11-24. **L = 17,71 mH, C = 5,7 µF (4,7 µF + 1 µF) e R = 43,0 Ω (46,6 Ω ‖ 7 × 3k9)**, ζ = 0,648 e f_LC = 500,9 Hz. Resistência do fio: 0,07 Ω (efeito desprezível no ζ). Falta confirmar no osciloscópio que o indutor não satura até 0,7 A.
2. ~~Demais componentes~~: resolvido em 2026-11-24. Todos retirados (LM324, IRF9530, FCH20A20, 6N137, BC547). Ver [docs/disponibilidade_dainf.md](docs/disponibilidade_dainf.md).
3. ~~Materiais de discretização e modelagem~~: resolvido em 2026-11-17. São o CA07 a CA10 em `Slides de aula/` (ver "Convenções do professor").
4. ~~Fonte em 18 V~~: resolvido em 2026-11-24. A saturação de d em 1 nesse trecho é esperada.
5. ~~Conflito nos slides do Sallen-Key~~: resolvido em 2026-11-24. Segue o slide 7 (ζ de 0,1 a 0,4).

## Convenções do professor (CA07 a CA10)

Seguir isto nas Etapas 5 a 9 para o script ficar no formato que o professor espera:

- **Superdiscretização (CA08):** dois laços aninhados. O laço externo é o controle digital (índice k, Tsd = 0,1 ms). O interno tem P = 100 iterações da planta e do CCS (índice kc = k·P + cc, Tsc = Tsd/P).
- **Planta e CCS como equações a diferenças**, obtidas com `c2d(G, Tsc)` (ZOH): y(kc) = −a1·y(kc−1) − a2·y(kc−2) + b1·u(kc−1) + b2·u(kc−2).
- **PWM no slide:** razão cíclica em contagens, d(k) = u(k)·P/E, com saída E enquanto cc ≤ d(k) (pulso alinhado no início do período). Decidido: alinhado no início, como no slide e no firmware novo (o da Atividade 1 era centrado).
- **ADC:** retenção da amostra, quantização com `round(v·2^n/E_AD)` e reconstrução ym(k+1) = (ymQ/2^n·E_AD − offset)/K, com uma amostra de atraso.
- **Ferramentas disponíveis:** Control System Toolbox, Signal Processing, Simulink, Simscape e Simscape Electrical (MATLAB R2026a).
- Os scripts das Etapas 2 e 3 discretizaram com `expm` (equivale ao ZOH do `c2d`, sem precisar de toolbox). Para o script final, usar `c2d` e equações a diferenças, como no CA08.

## Pastas

- `matlab/` — scripts de cada etapa e figuras geradas (`matlab/figuras/`)
- `docs/` — um markdown por etapa, com o raciocínio, os resultados e o que falta

## Diário

- **2026-11-10** — Leitura do enunciado e dos slides. Definições do grupo registradas. Etapa 1 feita em MATLAB: referência gerada e conferida com os pontos do slide 9. Professor orientou ζ = 0,5 como partida. Etapa 2 provisória: varredura de ζ (0,4 a 0,7) e verificação de CCM e ripples com R = 47 Ω, L = 15 mH, C = 6,8 µF.
- **2026-11-17** — Etapa 3 em MATLAB: CCS completo com valores comerciais, varredura de α e ζ do Sallen-Key (escolhidos α = 0,7 e ζ = 0,3) e simulação da cadeia com o Buck chaveado e ruído entre terras.
- **2026-11-17** — Grupo adicionou CA07 (Controle Digital), CA08 (Modelagem PWM e ADC), CA09 e CA10 em `Slides de aula/`. Convenções de simulação do CA08 registradas.
- **2026-11-23** — Lista de componentes ideais (todos PTH) enviada para o grupo checar no laboratório: potência (22 mH / 4,7 µF / 52,6 Ω como 1ª opção), driver 6N137 + IR2110 + IRF540N, CCS e itens de bancada.
- **2026-11-23** — Lista conferida no catálogo do DAINF. Falta: indutor, carga de potência, diodo rápido, IR2110, 6N137, UF4007, ampop rail-to-rail e dissipadores. Adaptações propostas: IRF530 no lugar do IRF540N, LM324 em 5 V no CCS, Sallen-Key com 1,5 kΩ / 220 nF / 22 nF e alternativa de chave com IRF9530 (canal P).
- **2026-11-23** — Grupo escolheu o acionamento com IRF9530 (canal P) + BC547 + zener 15 V. Dimensionado: R_GS = 1,5 kΩ, R_C = 1,2 kΩ, R_B = 2,2 kΩ, R_BE = 10 kΩ; ligar ≈ 1,4 µs, desligar ≈ 5,7 µs, perda ≈ 0,4 W. Sem bootstrap, d = 1 passa a ser possível.
- **2026-11-23** — Grupo decidiu manter a isolação com 6N137 (diagrama do professor na Atividade 1 e proteção do PA8). Inserido Q1 (BC547) para desfazer a inversão do opto e garantir chave desligada no boot. Falta comprar fora: indutor, carga de potência, diodo rápido e 6N137.
- **2026-11-24** — Itens do DAINF colocados no carrinho do sistema da sala de apoio (31 itens, lista em docs/disponibilidade_dainf.md). Reserva ainda não criada.
- **2026-11-24** — Indutor do grupo: 17,71 mH. Etapa 2 refeita com L fixo: R = 42,9 Ω (39 + 3,9 Ω) e C = 5,7 µF (4,7 + 1 µF), ζ = 0,650, f_LC = 500,9 Hz. No carrinho, aumentar o 1 µF / 63 V para 2.
- **2026-11-24** — Grupo conseguiu: resistor de cimento 10 W "R47" (conferir se é 47 Ω ou 0,47 Ω), diodo FCH20A20 e 6N137. Carga proposta: 47 Ω ‖ 8 × 3k9 = 42,9 Ω. Carrinho do DAINF refeito sem protoboard (reserva nº 40 já existia).
- **2026-11-24** — Resistor de potência medido: 46,6 Ω. Carga final: 46,6 Ω ‖ 7 × 3k9 = 43,0 Ω → ζ = 0,648.
- **2026-11-24** — Etapa 2 verificada no Simulink/Simscape (etapa02_simulink.m monta etapa02_buck_simscape.slx). Versão ideal bate com o MATLAB (≤ 1 mV); com as perdas do IRF9530, FCH20A20 e fio do indutor, Vo cai 0,26 a 0,46 V e todos os critérios continuam atendidos.
- **2026-11-24** — Componentes retirados. Roteiro de montagem e testes por blocos (L7805, acionamento, potência, CCS, Black Pill, integração) em docs/roteiro_montagem.md.
- **2026-11-24** — Firmware de bancada da Black Pill em firmware/ (CMSIS, PlatformIO): PWM 10 kHz no PA8, ADC no PA1 disparado pelo TIM1, referência do Sinal 1 no PA9, modos d fixo e malha aberta, KEY liga/desliga, proteção Vo > 25 V e leitura na serial (PA2). Compila sem avisos; ainda não testado na placa. Roteiro, blocos 5 e 6, atualizado.
- **2026-11-24** — Circuito completo no Simulink/Simscape (matlab/circuito_completo.m → buck_circuito_completo.slx): fonte, acionamento com 6N137/BC547/IRF9530, potência, CCS no LM324 e Black Pill com a conta do firmware. Valores esperados por ponto de medida em docs/circuito_completo_simulink.md. d = 0,5: Vo = 12,07 V, ADC reconstrói 12,04 V; Sinal 1 em malha aberta com erro ≤ 0,14 V.
- **2026-11-24** — Decisões do grupo: a saturação de d com E = 18 V é esperada e o Sallen-Key segue o slide 7. README atualizado (LM324, Sallen-Key do catálogo, pendências resolvidas). Etapa 4 iniciada.
- **2026-11-24** — Etapa 4 em MATLAB (etapa04_malha_aberta.m): Buck com subida de 0,63 ms, acomodação de 1,9 ms e sobressinal de 6,9 %; banda de 542 Hz; 106 dB de atenuação do chaveamento até o ADC (< 0,12 código); Sinal 1 em malha aberta com 0,76 V RMS de erro, quase todo atraso de ~0,4 ms nas rampas.
