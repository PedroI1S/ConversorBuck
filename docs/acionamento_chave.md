# Acionamento da chave: 6N137 + MOSFET canal P (IRF9530)

Decisões do grupo em 2026-11-23:

- **Chave:** MOSFET canal P IRF9530 do catálogo do DAINF, no lugar de IR2110 + IRF540N, que não estão disponíveis (ver [disponibilidade_dainf.md](disponibilidade_dainf.md)).
- **Isolação:** optoacoplador **6N137** entre o Black Pill e o acionamento. Ele aparece no diagrama do professor na Atividade 1 ("DRIVE (IR2110/Optoisolador)") e protege o PA8 se o MOSFET falhar em curto. O 6N137 vem de fora do DAINF: o 4N35 do catálogo está esgotado e é lento para 10 kHz.

## Circuito

```
PA8 ─► [6N137] ─► Q1 (BC547, desfaz a inversão) ─► Q2 (BC547) ─► gate do IRF9530 (canal P, lado alto)
     isolação      │                                  │
  (terra do        └──────── +5 V do L7805, alimentado por E, terra de potência ──────────┘
   Black Pill)
```

Ligações, nó a nó:

| Nó | Ligações |
|---|---|
| PA8 | R_LED 180 Ω → pino 2 do 6N137; R_PD 10 kΩ do PA8 ao terra do Black Pill |
| Pino 3 do 6N137 | terra do Black Pill |
| +5 V (saída do L7805) | pinos 8 e 7 do 6N137; R_P 1 kΩ; R_P2 1 kΩ |
| Saída do opto (pino 6) | R_P 1 kΩ ao +5 V; R_1 4,7 kΩ à base de Q1 |
| Base de Q1 | R_1; R_BE1 10 kΩ ao terra de potência |
| Coletor de Q1 | R_P2 1 kΩ ao +5 V; R_B 2,2 kΩ à base de Q2 |
| Base de Q2 | R_B; R_BE2 10 kΩ ao terra de potência |
| Coletor de Q2 | R_C 1,2 kΩ ao gate |
| Gate do IRF9530 | R_C; R_GS 1,5 kΩ a E; zener de 15 V com ânodo no gate e cátodo em E |
| Source do IRF9530 | E |
| Dreno do IRF9530 | nó de chaveamento (indutor e cátodo do diodo de roda livre) |
| Emissores de Q1 e Q2, pino 5 do 6N137, GND do L7805 | terra de potência |
| L7805 | entrada em E; 10 µF + 100 nF na entrada e na saída; 100 nF entre os pinos 8 e 5 do 6N137 |

| Pino do 6N137 | Ligação |
|---|---|
| 2 (ânodo do LED) | PA8 via R_LED = 180 Ω |
| 3 (cátodo do LED) | terra do Black Pill |
| 8 (VCC) e 7 (enable) | +5 V do lado da potência |
| 5 (GND) | terra de potência, com capacitor cerâmico de 100 nF entre os pinos 8 e 5, bem perto do CI |
| 6 (saída, coletor aberto) | pull-up R_P = 1 kΩ para +5 V; vai à base de Q1 por R_1 = 4,7 kΩ |

### Sequência lógica (não inverte)

| PA8 | LED | Saída do 6N137 | Q1 | Q2 | IRF9530 |
|---|---|---|---|---|---|
| Alto | aceso | baixa | corta | conduz | **liga** |
| Baixo | apagado | alta | conduz | corta | **desliga** |
| Flutuando (reset/boot) | apagado | alta | conduz | corta | **desliga** |

- **Por que Q1:** o 6N137 inverte o sinal (LED aceso → saída baixa). O Q1 desfaz essa inversão.
- **Firmware:** a polaridade do PWM fica normal.
- **Segurança no boot:** enquanto o Black Pill reinicia, o PA8 fica flutuando e o R_PD de 10 kΩ mantém o LED apagado. Nessa condição a chave fica **desligada**. Sem o Q1, o 6N137 deixaria a chave ligada com d = 1 durante o boot.

## Dimensionamento

### Lado do Black Pill

| Grandeza | Valor |
|---|---|
| Corrente no LED | (3,3 − 1,5)/180 = 10 mA. O 6N137 garante comutação a partir de 5 mA; o pino do STM32 fornece até 25 mA |

### Lado da potência

| Grandeza | Valor |
|---|---|
| Corrente de saída do 6N137 em nível baixo | 5 mA |
| Base de Q1 com saída alta | 0,68 mA para 5 mA de coletor: saturado |
| Base de Q1 com saída baixa (~0,4 V) | 0,27 V: cortado |
| Base de Q2 | (5 − 0,7)/(1 k + 2,2 k) = 1,3 mA para até 12,5 mA de coletor: saturado |
| Consumo do lado da potência | ≈ 23 mA |
| Dissipação no L7805 | 0,44 W com E = 24 V; 0,58 W com E = 30 V (sobe ~30 °C sem dissipador; aceitável) |

### Gate do IRF9530 (mesmo divisor de antes)

| E | VGS | Corrente em R_C | Potência em R_C | Potência em R_GS |
|---|---|---|---|---|
| 18 V | −10,0 V | 6,7 mA | 0,05 W | 0,07 W |
| 24 V | −13,3 V | 8,9 mA | 0,10 W | 0,12 W |
| 30 V | −15 V (zener) | 12,5 mA | 0,19 W | 0,15 W |

- **VGS mínimo:** |VGS| ≥ 10 V garante condução plena com E = 18 V.
- **Zener:** limita o VGS a 15 V (o máximo do IRF9530 é ±20 V).
- **Q2:** precisa ser BC547 (45 V) ou BD135, e não BC548 (30 V), porque o coletor fica em E quando a chave está desligada.

## Tempos de comutação e perdas

O 6N137 atrasa cerca de 0,1 µs e o Q1 menos de 1 µs. Quem domina os tempos é o gate do MOSFET (Qgd ≈ 21 nC):

| Grandeza | Valor |
|---|---|
| Ligar (corrente pelo R_C) | ≈ 1,4 µs |
| Desligar (corrente pelo R_GS) | ≈ 5,7 µs |
| Perda de comutação (E = 30 V, I = 0,34 A) | ≈ 0,36 W |
| Perda de condução (RDS(on) = 0,3 Ω) | ≈ 0,04 W |

O desligamento lento (cerca de 6 % do período) aumenta um pouco a razão cíclica efetiva. A malha fechada corrige isso. Vamos medir no osciloscópio e, se valer a pena, incluir no modelo do PWM da Etapa 6.

## Consequências para o projeto

- **d = 1 é possível:** não há bootstrap.
- **Fonte em 18 V com saída em 18 V:** continua no limite por causa das quedas no MOSFET e no indutor. A pergunta ao professor continua válida.
- **Terras:**
  - O 6N137 separa o comando, mas o divisor de medição liga Vo ao CCS, que é alimentado pelo Black Pill.
  - Manter os terras unidos em um único ponto, no negativo do capacitor de saída.
  - A proteção que o opto garante é esta: se o MOSFET ou o Q2 falharem, a tensão da potência não chega ao PA8.

## Peças do acionamento

| Item | Valor | Qtd | Origem |
|---|---|---|---|
| Optoacoplador | **6N137** (DIP-8) | 1 (+1 reserva) | **Comprar fora** |
| MOSFET canal P | IRF9530 | 1 (+1 reserva) | DAINF |
| Transistores NPN | BC547 (Q2 pode ser BD135) | 2 | DAINF |
| Zener | 15 V | 1 | DAINF |
| Regulador | L7805CV | 1 | DAINF |
| Resistores 1/4 W | 180 Ω; 1 kΩ (×2); 1,2 kΩ; 1,5 kΩ; 2,2 kΩ; 4,7 kΩ; 10 kΩ (×3) | — | DAINF |
| Capacitores | 100 nF cerâmico (×3: 6N137, entrada e saída do 7805); 10 µF / 63 V (×2: entrada e saída do 7805) | — | DAINF |

## Teste na bancada antes de fechar o conversor

1. **Só o lado da potência do acionamento:** fonte em 24 V com limite de 0,2 A. Conferir os 5 V do L7805. Com o PA8 desligado do circuito, o gate deve ficar em E (chave desligada).
2. **PWM de 10 kHz com d = 0,5:** ver no osciloscópio o pino 6 do 6N137, o coletor de Q2 e o gate em relação a E. Usar um resistor de 1 kΩ no dreno no lugar do indutor e da carga.
3. **Tempos:** medir subida e descida no dreno e comparar com a tabela.
4. **Faixa de E:** repetir em 18 V e 30 V, conferindo |VGS| entre 10 e 15 V.
5. **Boot:** reiniciar o Black Pill e confirmar que a chave não liga durante o boot.
