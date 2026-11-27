# Roteiro de montagem e testes na bancada

Montar um bloco por vez e só passar ao próximo quando a verificação bater. Anotar os valores medidos nos espaços `____`; eles entram no artigo e na calibração.

Os blocos 1 a 4 não precisam de firmware: o PWM vem do gerador de funções. Os blocos 5 e 6 precisam do firmware do Black Pill (ainda a escrever).

| Bloco | O que é | Precisa de |
|---|---|---|
| 0 | Medir e identificar as peças | Multímetro, LCR |
| 1 | Fonte de 5 V do acionamento (L7805) | Fonte de bancada |
| 2 | Acionamento: 6N137 + BC547 + IRF9530 | Fonte, gerador, osciloscópio |
| 3 | Estágio de potência (Buck em malha aberta) | Fonte, gerador, osciloscópio |
| 4 | CCS sozinho | Black Pill só como fonte de 3,3 V e 5 V, fonte de bancada, gerador |
| 5 | Black Pill: referência, PWM e ADC | Firmware |
| 6 | Tudo junto | Firmware |


Os valores esperados em cada ponto, simulados com o circuito completo (opto, transistores, LM324 e firmware), estão em [circuito_completo_simulink.md](circuito_completo_simulink.md).

## Regras de segurança

- **Fonte de bancada sempre com limite de corrente.** Use 0,1 A nos blocos 1 e 2 e 0,6 A no bloco 3.
- **Desligar a fonte antes de mexer na protoboard.**
- **Resistor de carga de 46,6 Ω / 10 W:**
  - Com Vo = 18 V ele dissipa 7 W e fica **muito quente**: não encostar e manter longe dos fios.
  - Não deixar Vo acima de ~20 V por mais que alguns segundos.
- **Osciloscópio:** o terra da ponta é o terra da tomada. Só prender o jacaré da ponta no **terra de potência** (negativo da fonte). Para ver o VGS, medir gate e source em dois canais e usar a função CH1 − CH2.
- **Terras:** o terra do Black Pill e o terra de potência se ligam em **um único ponto**: o negativo do capacitor de saída. Até o bloco 6 eles ficam separados; quem liga o PA8 ao acionamento é o 6N137.
- **Eletrolíticos:** confira a polaridade (faixa = negativo) antes de ligar.

## Pinagens (conferir sempre no datasheet do fabricante da peça)

| Peça | Pinos |
|---|---|
| IRF9530 (TO-220, letras viradas para você, pernas para baixo) | 1 Gate, 2 Dreno (e a aba), 3 Source |
| FCH20A20 (TO-220, Schottky duplo, catodo comum) | 1 Ânodo, 2 Catodo (e a aba), 3 Ânodo |
| L7805 (TO-220, letras para você) | 1 Entrada, 2 GND, 3 Saída |
| BC547 (face plana para você, pernas para baixo) | C, B, E (esquerda → direita) |
| 6N137 (DIP-8, marca do pino 1 à esquerda em cima) | 2 ânodo do LED, 3 catodo do LED, 5 GND, 6 saída, 7 enable, 8 VCC (1 e 4 sem ligação) |
| LM324 (DIP-14) | 4 VCC, 11 GND; ampop A: 1 saída, 2 (−), 3 (+); B: 7 saída, 6 (−), 5 (+); C: 8 saída, 9 (−), 10 (+); D: 14 saída, 13 (−), 12 (+) |
| Zener 15 V | Faixa = catodo |

---

## Bloco 0 — Medir e identificar as peças

| Item | Esperado | Medido |
|---|---|---|
| Indutor: L (LCR) | 17,71 mH | ____ |
| Indutor: resistência | 0,07 Ω | ____ |
| Os dois capacitores de 4,7 µF (LCR); usar o mais próximo de 4,7 | 4,7 µF ± 20 % | ____ / ____ |
| Capacitor de 1 µF da saída | 1 µF | ____ |
| C de saída total (4,7 + 1 em paralelo) | 5,7 µF | ____ |
| Resistor de carga (só o de potência, sem os 3k9) | 46,6 Ω | 46,6 Ω |
| Os 8 resistores de 100 kΩ: medir e separar os 4 mais parecidos | 100 kΩ | ____ |

Se o C ou a carga real ficarem longe do esperado, anotar: eu recalculo o ζ.

---

## Bloco 1 — Fonte de 5 V do acionamento (L7805)

Montagem:

- **Entrada do L7805:** ligada em E, com 10 µF + 100 nF entre a entrada e o terra de potência.
- **Saída do L7805:** 10 µF + 100 nF entre a saída e o terra de potência.

Teste: fonte em 24 V com limite de 0,1 A.

| Verificação | Esperado | Medido |
|---|---|---|
| Saída do L7805 | 5,0 V (4,8 a 5,2) | ____ |
| Corrente da fonte, sem carga | < 10 mA | ____ |
| Saída com E = 18 V e E = 30 V | 5,0 V nos dois | ____ / ____ |

---

## Bloco 2 — Acionamento (6N137 → Q1 → Q2 → IRF9530)

Ligações (detalhes e cálculos em [acionamento_chave.md](acionamento_chave.md)):

| De | Para |
|---|---|
| Entrada do sinal (gerador; depois o PA8) | R_LED 180 Ω → pino 2 do 6N137 |
| Entrada do sinal | R_PD 10 kΩ → terra do sinal (terra do gerador; depois o GND do Black Pill) |
| Pino 3 do 6N137 | terra do sinal |
| Pinos 8 e 7 do 6N137 | +5 V do L7805 |
| Pino 5 do 6N137 | terra de potência; 100 nF entre os pinos 8 e 5, colado no CI |
| Pino 6 do 6N137 | R_P 1 kΩ → +5 V; R_1 4,7 kΩ → base de Q1 |
| Base de Q1 | R_BE1 10 kΩ → terra de potência; emissor de Q1 no terra de potência |
| Coletor de Q1 | R_P2 1 kΩ → +5 V; R_B 2,2 kΩ → base de Q2 |
| Base de Q2 | R_BE2 10 kΩ → terra de potência; emissor de Q2 no terra de potência |
| Coletor de Q2 | R_C 1,2 kΩ → gate do IRF9530 |
| Gate do IRF9530 | R_GS 1,5 kΩ → E; zener 15 V com **catodo em E** e ânodo no gate |
| Source do IRF9530 | E |
| Dreno do IRF9530 | por enquanto, **resistor de teste de 4,7 kΩ** até o terra de potência (no lugar do Buck) |

### 2a. Estático (sem sinal)

Fonte em 24 V, limite de 0,1 A. Entrada do sinal desconectada.

| Verificação | Esperado | Medido |
|---|---|---|
| 5 V do L7805 | 5,0 V | ____ |
| Pino 6 do 6N137 (LED apagado) | ~5 V | ____ |
| Coletor de Q1 | ~0,1 V (Q1 conduz) | ____ |
| Gate do IRF9530 (Q2 cortado) | = E (24 V): **chave desligada** | ____ |
| Dreno | ~0 V | ____ |

Agora ligar a entrada em 3,3 V CC (a fonte de 3,3 V do Black Pill ou o gerador em nível alto, sempre com o terra do sinal):

| Verificação | Esperado | Medido |
|---|---|---|
| Pino 6 do 6N137 (LED aceso) | < 0,6 V | ____ |
| Coletor de Q1 | ~5 V | ____ |
| Gate do IRF9530 | ~10,7 V (VGS ≈ −13,3 V) | ____ |
| Dreno | ≈ E (24 V): **chave ligada** | ____ |

Se a chave ligar com a entrada desconectada, há algo invertido (Q1 ou o 6N137): **parar e conferir**.

### 2b. Com PWM do gerador

Gerador de funções: onda quadrada de **0 a 3,3 V** (amplitude 3,3 Vpp, offset 1,65 V), **10 kHz**, ciclo de 50 %. Conferir no osciloscópio **antes** de ligar no circuito.

| Verificação (osciloscópio) | Esperado | Medido |
|---|---|---|
| Pino 6 do 6N137 | quadrada de 0 a 5 V, **invertida** em relação à entrada | ok? ____ |
| Coletor de Q1 | quadrada de 0 a 5 V, **em fase** com a entrada | ok? ____ |
| Dreno | quadrada de 0 a E, em fase com a entrada | ok? ____ |
| Tempo de subida do dreno (ligar) | ≈ 1,4 µs | ____ |
| Tempo de descida do dreno (desligar) | ≈ 5,7 µs | ____ |
| Atraso total da entrada até o dreno | alguns µs | ____ |

Os tempos calculados valem para o Buck. Com o resistor de teste de 4,7 kΩ, a descida do dreno pode ser mais lenta, porque só esse resistor descarrega a capacitância do dreno. O que importa aqui é a forma e a polaridade; os tempos se medem de novo no bloco 3.

### 2c. Faixa de E

| E | VGS com a chave ligada (gate − source) | Medido |
|---|---|---|
| 18 V | ≈ −10 V | ____ |
| 24 V | ≈ −13,3 V | ____ |
| 30 V | −15 V (limitado pelo zener) | ____ |

Mudar o ciclo do gerador para 10 % e 90 % e confirmar que o dreno acompanha. Depois **tirar o resistor de teste de 4,7 kΩ**.

---

## Bloco 3 — Estágio de potência (Buck em malha aberta)

Ligações:

| De | Para |
|---|---|
| E (+) | source do IRF9530; 470 µF / 50 V + 1 µF entre E e o terra de potência, **perto do MOSFET e do diodo** |
| Dreno do IRF9530 (nó de chaveamento) | catodo do FCH20A20 (pino do meio); indutor |
| Ânodos do FCH20A20 (pinos 1 e 3 juntos) | terra de potência |
| Outra ponta do indutor (= Vo) | capacitor de 4,7 µF (+) e de 1 µF; carga de 46,6 Ω |
| Negativos de C e da carga | terra de potência (este é o **ponto único de terra**) |

Usar fios curtos e grossos no caminho E → MOSFET → indutor → carga → terra → diodo. Lembrar que cada contato da protoboard aguenta ~1 A.

Os valores esperados vêm da simulação no Simscape com perdas ([etapa02](etapa02_projeto_buck.md)).

### 3a. Primeira energização (tensão baixa)

Gerador em 10 kHz e 50 %. Fonte em **12 V** com limite de 0,3 A. Não usar menos de ~10 V, porque abaixo disso o L7805 não regula e o VGS não liga o MOSFET direito.

| Verificação | Esperado | Medido |
|---|---|---|
| Vo (multímetro) | ~5,7 V | ____ |
| Corrente da fonte (Buck + ~23 mA do acionamento) | ~90 mA | ____ |
| Algo esquentando? | nada | ____ |

### 3b. Pontos de operação

Fonte com limite de 0,6 A. Medir Vo no multímetro e o ripple de Vo no osciloscópio (acoplamento AC).

| E | d (gerador) | Vo ideal | Vo esperado com perdas | Vo medido | Ripple de Vo esperado |
|---|---|---|---|---|---|
| 24 V | 0,25 | 6,0 V | 5,6 V | ____ | ~60 mV pp |
| 24 V | 0,50 | 12,0 V | 11,7 V | ____ | ~75 mV pp |
| 24 V | 0,75 | 18,0 V | 17,7 V | ____ | ~55 mV pp |
| 30 V | 0,60 | 18,0 V | 17,7 V | ____ | ~90 mV pp |
| 18 V | 0,50 | 9,0 V | 8,7 V | ____ | ~60 mV pp |

- **Nó de chaveamento (dreno):** a onda deve ser quadrada, de ~−0,5 V (diodo conduzindo) a ~E. Se aparecer patamar intermediário, a corrente está zerando (condução descontínua): não deveria acontecer.
- **Resistor de carga:** não deixar mais de 1 minuto nos casos de 18 V; esperar esfriar entre um e outro.

### 3c. Resposta ao degrau (opcional, bom para o artigo)

Gerador em modo burst ou alternando o ciclo entre 25 % e 75 %, com E = 24 V. Ver Vo no osciloscópio: sobe de ~6 para ~18 V com **sobressinal de ~10 %** e acomodação em ~2 ms (ζ = 0,60).

| Verificação | Esperado | Medido |
|---|---|---|
| Sobressinal | ~10 % | ____ |
| Tempo de subida (10–90 %) | ~0,59 ms | ____ |

### 3d. Saturação do indutor

Separar o terra de potência em dois lados e ligar um resistor shunt de 1 Ω entre eles:

- **Lado 1:** negativo da fonte, negativo dos capacitores de entrada e ânodos do diodo.
- **Lado 2:** negativo do C de saída e da carga.

Pelo shunt passa exatamente i_L. Ponta sobre o shunt, com o jacaré no lado 1; o sinal aparece invertido, e 1 V na tela equivale a 1 A. Com E = 24 V e d = 0,75 (0,39 A): a corrente deve ser um triângulo com **rampas retas**. Se a rampa de subida entortar para cima, o núcleo está saturando: anotar a corrente.

Teste de 0,64 A (E = 30 V, d = 1): **só por 2 a 3 segundos**, porque a carga dissipa ~19 W. Tirar o shunt depois.

---

## Bloco 4 — CCS sozinho (sem o Buck ligado)

Alimentação:

- **LM324:** 5 V do Black Pill (pino 5V, via USB). 100 nF entre os pinos 4 e 11, colado no CI.
- **Offset:** usa o 3,3 V do Black Pill.
- **Terra de sinal:** GND do Black Pill.

Ligações (valores do catálogo; "+" quer dizer em série):

| Bloco | Ligações |
|---|---|
| Divisor | Entrada "Vo" → R1 = **10 kΩ + 1 kΩ** → ponto médio → R2 = 1 kΩ → "terra de potência" |
| Subtrator (ampop A) | Ponto médio → Ra 100 kΩ → (+) pino 3; Rb 100 kΩ do pino 3 ao terra de sinal. "Terra de potência" → Ri = **100 kΩ + 820 Ω + 82 Ω** → (−) pino 2; Rf 100 kΩ do pino 2 ao pino 1 (saída) |
| Sallen-Key (ampop B) | Pino 1 → R 1,5 kΩ → nó X → R 1,5 kΩ → (+) pino 5. C1 = **220 nF** do nó X ao pino 7 (saída). C2 = **22 nF** do pino 5 ao terra de sinal. Pino 6 ligado ao pino 7 |
| Offset (ampop C) | Pino 7 → Ra 10 kΩ → (+) pino 10. Divisor do 3,3 V: Rx = **6,8 kΩ + 680 Ω** até um nó; Ry 1 kΩ desse nó ao terra de sinal. Desse nó → Rb = **8,2 kΩ + 820 Ω** → pino 10. (−) pino 9: Ri 10 kΩ ao terra de sinal e Rf 10 kΩ ao pino 8 (saída) |
| Saída para o ADC | Pino 8 → 100 Ω → PA1 (no bloco 4 só medir o pino 8) |
| Ampop D (pinos 12, 13 e 14) | Não usado: pino 12 no terra de sinal e pino 13 ligado ao 14 |

Neste bloco o "terra de potência" do divisor e do subtrator fica ligado ao terra de sinal.

### 4a. Níveis em CC

A fonte de bancada faz o papel de Vo, com o negativo no terra de sinal.

| Vo aplicado | Divisor (÷12) | Saída do subtrator | Saída do Sallen-Key | Saída do offset (ADC) | Medido no ADC |
|---|---|---|---|---|---|
| 0 V | 0 | ~0 | ~0 | 0,389 V | ____ |
| 6 V | 0,500 | 0,496 | 0,496 | 0,884 V | ____ |
| 12 V | 1,000 | 0,991 | 0,991 | 1,379 V | ____ |
| 18 V | 1,500 | 1,487 | 1,487 | 1,874 V | ____ |
| 24 V | 2,000 | 1,982 | 1,982 | 2,369 V | ____ |
| 30 V | 2,500 | 2,478 | 2,478 | 2,864 V | ____ |

Com a fonte em 0 V, o LM324 não chega a exatamente 0 V na saída (fica em alguns mV): é normal.

Com os pontos medidos, ajustar uma reta v_ADC = a + b·Vo. O projeto dá a = 0,389 V e b = 0,08251: anotar **a = ____ e b = ____**. São esses os números que vão para o firmware.

### 4b. Filtro Sallen-Key em frequência

Gerador senoidal de **1 Vpp com offset de 1,25 V** direto no pino 1 do circuito, com a saída do subtrator desligada desse nó. Medir a saída no pino 7.

| Frequência | Ganho esperado | Medido |
|---|---|---|
| 100 Hz | 1,00 (0 dB) | ____ |
| 500 Hz | ~1,09 | ____ |
| 1,4 kHz | ~1,67 (pico, +4,4 dB) | ____ |
| 10 kHz | ~0,024 (−32 dB) | ____ |

Com os valores do catálogo (1,5 kΩ, 220 nF e 22 nF), f_PB = 1525 Hz e ζ = 0,316.

---

## Bloco 5 — Black Pill (firmware em [`firmware/`](../firmware/README.md))

Gravar com `pio run -e d_fixo -t upload` (ou `-e malha_aberta`). A chave começa **desligada**: o botão **KEY** liga e desliga, e o LED da placa fica aceso com a chave ligada, pisca devagar desligada e pisca rápido se a proteção de sobretensão (Vo > 25 V) atuou. Um adaptador USB-serial no **PA2** (115200 baud, terra comum) mostra 10 vezes por segundo o código do ADC, v_ADC, Vo e d.

Neste bloco a Black Pill ainda fica **fora** do conversor (só USB e, para o ADC, o CCS do bloco 4).

| Teste | Como | Esperado |
|---|---|---|
| Referência (Etapa 1b) | **PA9** (PWM de 10 kHz, d = vref/24 V, sempre ativo) → filtro RC 15 kΩ + 10 nF → 150 kΩ + 1 nF → osciloscópio | Forma do Sinal 1 em escala 3,3/24: 1,65 / 2,48 / 1,65 / 0,83 / 1,65 V, período de 40 ms |
| PWM do PA8 (`d_fixo`) | Osciloscópio no PA8; apertar KEY | Antes do KEY: 0 V (também no reset e na gravação). Depois: 10 kHz, 0 a 3,3 V, pulso no início do período, d = 0,500 |
| PWM do PA8 (`malha_aberta`) | Osciloscópio no PA8 com trigger no PA9 | d variando 0,50 → 0,75 → 0,50 → 0,25 → 0,50 a cada 10 ms |
| Tempo de cálculo | Osciloscópio no **PB0** | Pulso curto (poucos µs) a cada 100 µs, logo depois do início do período |
| ADC e calibração | CCS do bloco 4 com Vo de 6 V e de 18 V vindos da fonte; ler a serial | v_ADC da serial ≈ multímetro na saída do CCS. Com os dois pontos calcular a e b e trocar `ADC_A_UV` e `ADC_B_X1E5` no `main.c`; regravar e conferir que Vo da serial bate com o multímetro |
| Proteção | No mesmo arranjo, subir o Vo da fonte acima de 25 V com a chave ligada | LED passa a piscar rápido, serial mostra `FALHA(sobretensao)` e PA8 vai a 0 |

## Bloco 6 — Tudo junto

1. **Terras:** ligar o terra de potência ao terra de sinal no **ponto único** (negativo do C de saída). Ligar a entrada "Vo" do divisor nesse capacitor (+) e o "terra de potência" do subtrator no negativo dele.
2. **Comando da chave:** trocar o gerador pelo PA8 (R_LED e R_PD continuam). Gravar `d_fixo` **antes** de ligar a fonte de potência; ligar a fonte com a chave desligada (LED piscando devagar).
3. **Malha aberta, d fixo:** E = 24 V, apertar KEY (d = 0,5). Vo do multímetro ~11,7 V e o Vo da serial igual a ele (±0,1 V depois da calibração). Para outro d, mudar `D_FIXO_PERMIL` no `platformio.ini`.
4. **Sinal 1 em malha aberta:** gravar `malha_aberta`, apertar KEY. Canal 1 no Vo, canal 2 na referência filtrada do PA9 (trigger nele). Comparar com a figura do Simscape ([etapa02](etapa02_projeto_buck.md)); com perdas o esperado é ~0,35 V abaixo da referência.
5. **Malha fechada:** só depois das Etapas 8 e 9; o controlador entra no ponto marcado na `ADC_IRQHandler`.

## O que me trazer depois da bancada

- Os valores anotados nos blocos 0, 2, 3 e 4. Com eles eu recalculo o ζ real e coloco a calibração do ADC (a, b) e os tempos de comutação no modelo.
- Fotos das formas de onda do bloco 3: nó de chaveamento, ripple de Vo, degrau e corrente no shunt. Elas servem para o artigo.
