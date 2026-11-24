# Disponibilidade no catálogo do DAINF (sala de apoio)

Conferido em 2026-11-23 no sistema da sala de apoio do DAINF (UTFPR-PB), item a item contra a [lista de componentes](lista_componentes.md). Quantidades são as do catálogo nesse dia. O catálogo não informa potência dos resistores (os comuns são de 1/4 W) nem o dielétrico dos capacitores.

## Resumo: o que falta conseguir fora

| Item | Por quê |
|---|---|
| ~~Indutor~~ | **Resolvido em 2026-11-24:** o grupo tem um de 17,71 mH (o do catálogo é de 1 mH, inviável) |
| **Resistor de carga de potência** (39 Ω ≥ 10 W + 3,9 Ω ≥ 2 W, ou 43 Ω ≥ 10 W) | Só há resistores comuns; o único de potência (frenagem 50 W, 12 Ω) está esgotado |
| **Diodo de roda livre rápido** (SB560, MBR1060 ou UF5408) | Só há 1N4001/1N4004/1N4007, lentos demais para 10 kHz |
| **Optoacoplador 6N137** | Não existe no catálogo (4N35 esgotado e lento; MOC3021 é para triac). O IR2110 e o UF4007 foram dispensados: o grupo escolheu 6N137 + IRF9530 ([acionamento_chave.md](acionamento_chave.md)) |
| **Ampop rail-to-rail (MCP6004)** | Não existe. Dá para usar o LM324 do catálogo (ver abaixo) |
| Dissipadores TO-220 | Não aparecem no catálogo |

## Item a item

### Potência

| Item da lista | No catálogo | Situação |
|---|---|---|
| Indutor 22 mH | Indutor 1000 µH (1 un.) | **Falta** |
| Capacitor de saída 4,7 µF filme | 4,7 µF / 63 V (89 un.), provavelmente eletrolítico | Serve provisoriamente; medir o valor real no LCR (tolerância de 20 % muda o ζ) |
| Carga 47 Ω + 5,6 Ω de potência | 47 Ω e 5,6 Ω só em 1/4 W | **Falta** a versão de potência |
| MOSFET IRF540N | **IRF530** (34 un.) / IRF530N (1 un.) | Substituto direto (100 V, 14 A) |
| Diodo SB560/MBR1060 | só 1N400x | **Falta** |
| 470 µF / 50 V | sim (119 un.) | OK |
| 1 µF / 63 V | sim (149 un.) | OK (conferir se é filme; se for eletrolítico, usar junto um 100 nF cerâmico) |

### Acionamento

| Item da lista | No catálogo | Situação |
|---|---|---|
| 6N137 | não | **Falta** |
| IR2110 | não | **Falta** |
| LM7812 / LM7805 | L7812CV (19), L7805CV (10) | OK |
| UF4007 | não | **Falta** |
| 180 Ω, 1 kΩ, 22 Ω, 10 kΩ | sim | OK |
| 100 nF cerâmico | sim (48 + 100 un.) | OK |
| 10 µF / 50 V | sim (14 un.; e 10 µF / 63 V, 79 un.) | OK |

**Escolhido pelo grupo (2026-11-23):** 6N137 (de fora) + dois BC547 + MOSFET canal P **IRF9530** (20 un.) + zener de 15 V + L7805 do catálogo. Dimensionamento em [acionamento_chave.md](acionamento_chave.md).

### CCS

| Item da lista | No catálogo | Situação / adaptação |
|---|---|---|
| MCP6004-I/P | não | **Usar LM324** (9 un.) alimentado em 5 V. A entrada e a saída chegam a 0 V; o máximo da saída fica em ~3,5 V. A faixa útil (0,39 a 2,86 V) cabe. Pôr o resistor de 100 Ω em série com PA1 para limitar corrente se a saída passar de 3,3 V |
| 11 kΩ | não | 10 kΩ + 1 kΩ em série (exato) |
| 1 kΩ, 100 kΩ, 10 kΩ, 100 Ω | sim | OK |
| 910 Ω | não | 820 Ω + 82 Ω em série (902 Ω) |
| Sallen-Key: 3,0 kΩ, 120 nF e 10 nF | 120 nF não existe | **Trocar para R = 1,5 kΩ, C1 = 220 nF / 250 V e C2 = 22 nF / 250 V** (os de 250 V são de filme). Dá f_PB = 1525 Hz e ζ = 0,316, praticamente igual ao projeto (1531 Hz, 0,289) |
| 9,1 kΩ | não | 8,2 kΩ + 820 Ω (9,02 kΩ) |
| 7,5 kΩ | não | 6,8 kΩ + 680 Ω (7,48 kΩ) |

Os desvios de 902 Ω, 9,02 kΩ e 7,48 kΩ mudam o offset em poucos mV; a calibração em dois pontos na bancada absorve isso.

### Teste da Etapa 1 (filtro RC)

47 nF está esgotado. Trocar por: 1ª seção **15 kΩ + 10 nF / 250 V**, 2ª seção **150 kΩ + 1 nF / 250 V** (as duas com corte de ~1,06 kHz; a 2ª tem impedância 10 vezes maior para não carregar a 1ª). Todos disponíveis.

### Bancada

| Item | No catálogo |
|---|---|
| Protoboard | 830 furos (17 un.) e 1280 pontos (5 un.) |
| Fonte com limite de corrente | Tektronix PWS2323 (0–32 V, 3 A), várias unidades |
| Cabos banana | sim |

## Carrinho montado no sistema (2026-11-24)

31 itens no carrinho da sala de apoio, **sem criar a reserva** (o botão "Criar Reserva" fica para o grupo, com as datas de reserva e retirada).

| Bloco | Itens (quantidade) |
|---|---|
| Semicondutores | IRF9530 (2), BC547 (2), Diodo ZENER 15V (1), L7805CV (1), LM324 (1) |
| Resistores | 180 Ω (1), 1k (5), 1k2 (1), 1k5 (3), 2k2 (1), 4k7 (1), 10k (7), 100k (8), 820 (2), 82 (1), 8k2 (1), 6k8 (1), 680 (1), 100 (1), 15k (1), 150k (1) |
| Capacitores | cerâmico 100 nF (4), 10 µF/63 V (2), 4,7 µF/63 V (2, para escolher o mais próximo no LCR), 470 µF/50 V (1), 1 µF/63 V (1; **aumentar para 2** — o C de saída virou 4,7 µF + 1 µF), 220 nF/250 V (1), 22 nF/250 V (1), 10 nF/250 V (1), 1 nF/250 V (1) |
| Bancada | Protoboard 830 furos (2) |

De onde vêm as quantidades: 1k = 2 do acionamento + divisor + parte do 11k + Ry do offset; 10k = 3 do acionamento + parte do 11k + 3 do offset; 1k5 = R_GS + 2 do Sallen-Key; 820 = partes do 910 e do 9,1k; 100 nF = 6N137, entrada e saída do 7805 e desacoplamento do LM324.

## Carrinho refeito (2026-11-24, tarde)

Já existe a reserva nº 40 (criada pelo grupo em 24/11). O carrinho foi montado de novo com 31 itens, **sem protoboard** e ainda sem reserva:

| Bloco | Itens (quantidade) |
|---|---|
| Semicondutores | IRF9530 (2), BC547 (2), Diodo ZENER 15V (1), L7805CV (1), LM324 (1) |
| Resistores | 180 Ω (1), 1k (5), 1k2 (1), 1k5 (3), 2k2 (1), 4k7 (1), 10k (7), 100k (8), 820 (2), 82 (1), 8k2 (1), 6k8 (1), 680 (1), 100 (1), 15k (1), 150k (1), **3k9 (8)** |
| Capacitores | cerâmico 100 nF (4), 10 µF/63 V (2), 4,7 µF/63 V (2), 470 µF/50 V (1), **1 µF/63 V (2)**, 220 nF/250 V (1), 22 nF/250 V (1), 10 nF/250 V (1), 1 nF/250 V (1) |

Os 8 × 3k9 em paralelo (487,5 Ω) vão em paralelo com o resistor de carga de 47 Ω: 47 ‖ 487,5 = 42,9 Ω → ζ = 0,650. Cada 3k9 dissipa 0,08 W com Vo = 18 V e 0,23 W com 30 V (1/4 W aguenta).

## Conseguido fora do DAINF (2026-11-24)

| Item | Peça | Observação |
|---|---|---|
| Indutor | 17,71 mH, 0,07 Ω | Saturação a conferir no osciloscópio |
| Carga | resistor de cimento 10 W marcado "R47", **medido: 46,6 Ω** | Com **7 × 3k9 em paralelo** (557 Ω): 46,6 ‖ 557 = 43,0 Ω → ζ = 0,648. O 8º 3k9 do carrinho fica de reserva (com 8: 42,5 Ω, ζ = 0,655) |
| Diodo de roda livre | FCH20A20 (Schottky duplo, 200 V, 20 A, TO-220, catodo comum) | Serve com folga. Usar um dos ânodos ou os dois em paralelo; conferir a pinagem no datasheet |
| Optoacoplador | 6N137 (1) | Sem reserva |
