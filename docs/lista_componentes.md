# Lista de componentes (ideal)

Todos PTH, para protoboard. Gerada em 2026-11-23 a partir das Etapas 2 e 3 (ζ_LC = 0,65, f_LC = 500 Hz, fₛ = 10 kHz, E = 18 a 30 V).

**Indutor definido em 2026-11-24: L = 17,71 mH** (o que o grupo tem). Com ζ = 0,65 e f_LC = 500 Hz saem R = 42,8 Ω e C = 5,72 µF, montados assim:

| Item | Especificação | Qtd | Obs. |
|---|---|---|---|
| Indutor | 17,71 mH, corrente ≥ 0,7 A (pico de 0,44 A em operação; 0,70 A com d = 1 e E = 30 V) | 1 | Já tem. Falta medir a resistência do fio |
| Capacitor de saída | **4,7 µF + 1 µF em paralelo = 5,7 µF**, ≥ 63 V | 1 de cada | DAINF. Medir no LCR e ficar com o 4,7 µF mais próximo do nominal |
| Resistor de carga, parte maior | **39 Ω**, fio ou cimento, **≥ 10 W (20 W se houver)** | 1 | 6,9 W com Vo = 18 V; ~19 W se d travar em 1 com 30 V (testar por pouco tempo) |
| Resistor de carga, parte menor | **3,9 Ω, ≥ 2 W** | 1 | Total 42,9 Ω → ζ = 0,650. Alternativa: um único 43 Ω ≥ 10 W |
| Diodo de roda livre | **SB560** ou **MBR1060** (Schottky 60 V). Alternativa: UF5408 (ultrarrápido 3 A) | 1 | **Não** usar 1N4007/1N5408: são lentos demais para 10 kHz |
| Capacitor de entrada (barramento) | eletrolítico 470 µF, ≥ 50 V | 1 | Perto do MOSFET e do diodo |
| Capacitor de entrada (alta frequência) | filme 1 µF, ≥ 63 V | 1 | Em paralelo com o de 470 µF |

## 2. Acionamento da chave

**Atualizado em 2026-11-23:** isolação com **6N137**, seguida de dois BC547 e do MOSFET canal P **IRF9530** do lado alto. Substitui o IR2110, o UF4007, o 7812 e o IRF540N. Circuito e cálculos em [acionamento_chave.md](acionamento_chave.md).

| Item | Valor | Qtd | Origem |
|---|---|---|---|
| Optoacoplador | 6N137 (DIP-8) | 1 (+1 reserva) | **Comprar fora** |
| MOSFET canal P | IRF9530 | 1 (+1 reserva) | DAINF |
| Transistor NPN | BC547 | 2 | DAINF |
| Zener | 15 V | 1 | DAINF |
| Regulador | L7805CV | 1 | DAINF |
| Resistores 1/4 W | 180 Ω; 1 kΩ (×2); 1,2 kΩ; 1,5 kΩ; 2,2 kΩ; 4,7 kΩ; 10 kΩ (×3) | — | DAINF |
| Capacitores | 100 nF cerâmico (×3); 10 µF / 63 V (×2) | — | DAINF |

## 3. Condicionamento de sinais (CCS) — Etapa 3

Resistores de filme metálico 1 %, 1/4 W. Alimentação dos ampops nos 3,3 V do Black Pill.

| Bloco | Item | Valor | Qtd |
|---|---|---|---|
| Ampops | **MCP6004-I/P** (DIP-14, rail-to-rail, 4 ampops). Alternativa: 2× MCP6002-I/P (DIP-8) | — | 1 |
| Divisor | R1 | 11 kΩ | 1 |
| Divisor | R2 | 1 kΩ | 1 |
| Subtrator | Ra, Rb, Rf, Ri | 100 kΩ | 4 (comprar 8 para parear os mais próximos) |
| Subtrator | compensação em série com Ri | 910 Ω | 1 |
| Sallen-Key | R1 = R2 | 3,0 kΩ (ou 2,7 kΩ + 330 Ω) | 2 |
| Sallen-Key | C1 (realimentação) | **120 nF filme** | 1 |
| Sallen-Key | C2 (para o terra) | **10 nF filme** | 1 |
| Offset | Ra, Rf, Ri | 10 kΩ | 3 |
| Offset | Rb | 9,1 kΩ | 1 |
| Offset | Rx (do 3,3 V) | 7,5 kΩ | 1 |
| Offset | Ry (para o terra) | 1 kΩ | 1 |
| Desacoplamento | cerâmico 100 nF | — | 1 |
| Saída para o ADC (opcional) | resistor em série com PA1 | 100 Ω | 1 |

## 4. Teste da Etapa 1 na bancada (referência em PWM → osciloscópio)

Filtro RC de 2ª ordem para ver a referência de 25 Hz no PWM de 10 kHz (cada seção com corte ≈ 1 kHz):

| Item | Valor | Qtd |
|---|---|---|
| Resistor | 3,3 kΩ e 33 kΩ | 1 de cada |
| Capacitor (filme ou cerâmico) | 47 nF e 4,7 nF | 1 de cada |

## 5. Geral e instrumentos

| Item | Obs. |
|---|---|
| Black Pill STM32F411 + ST-Link | Já tem |
| 2 protoboards + jumpers grossos | Para a potência, usar fios grossos e curtos; protoboard aguenta ~1 A por contato |
| Fonte de bancada 0–30 V com limite de corrente | Limitar a ~1 A nos testes |
| Osciloscópio (2 canais) e multímetro | |
| Medidor LCR, se houver | Para medir L, a resistência do fio do indutor e o C real |
| Dissipadores TO-220 | Opcional para o IRF9530 (perda ≈ 0,4 W) |

## Ligação dos terras

O divisor mede Vo direto, então os terras de potência e de sinal acabam ligados pelo CCS. Ligar os dois **em um único ponto** (no negativo do capacitor de saída), com os fios de potência separados dos de sinal. O 6N137 isola o PA8 do acionamento: uma falha no MOSFET não chega ao Black Pill.
