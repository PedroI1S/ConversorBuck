# Firmware — Black Pill (STM32F411CE)

Firmware de bancada do conversor Buck. Está em CMSIS, direto nos registradores, no mesmo estilo da Atividade 1. O código fica em [`src/main.c`](src/main.c).

## Como funciona

- O relógio sai do cristal de 25 MHz e passa pelo PLL até 100 MHz. O TIM1 e o ADC1 rodam no APB2 a 100 MHz; a USART2 roda no APB1 a 50 MHz.
- O **TIM1** conta de 0 a 9999, o que dá 10 kHz. Ele usa o modo PWM 1, que deixa a saída alta enquanto CNT < CCR. Por isso o pulso fica no início do período, como no CA08 e no Simscape.
- O update do TIM1 (início do período, TRGO) dispara **uma conversão injetada do ADC1 no PA1**, com 84 ciclos de amostragem.
- A interrupção de fim de conversão faz, a cada período:
  1. Lê o código.
  2. Reconstrói Vo = (v_ADC − a)/b.
  3. Calcula a referência do Sinal 1.
  4. Confere a proteção.
  5. Escreve a próxima razão cíclica no CCR1. Com o preload, ela vale no período seguinte, o que dá um atraso de uma amostra.
- O cálculo é só com inteiros. O PB0 fica alto enquanto a interrupção roda.

## Pinos

| Pino | Função |
|---|---|
| PA0 | KEY da placa: liga/desliga a chave (começa **desligada**) |
| PA1 | ADC1_IN1 ← saída do CCS (via 100 Ω) |
| PA2 | USART2_TX, 115200 8N1 → RX do adaptador USB-serial (terra comum) |
| PA8 | TIM1_CH1: PWM da chave → R_LED 180 Ω → 6N137 |
| PA9 | TIM1_CH2: referência do Sinal 1 em PWM, d = vref/24 V (Etapa 1b, filtro RC) |
| PB0 | Debug: alto durante a interrupção |
| PC13 | LED: aceso = chave ligada; pisca 1 Hz = desligada; pisca 5 Hz = proteção atuou |

No boot, o PA8 fica em alta impedância até o TIM1 estar configurado com CCR1 = 0. Durante esse tempo, o R_PD de 10 kΩ mantém a chave desligada.

## Modos (um ambiente do PlatformIO para cada)

| Ambiente | Razão cíclica no PA8 |
|---|---|
| `d_fixo` | d = `D_FIXO_PERMIL`/1000 (padrão 500, ajustar no `platformio.ini`) |
| `malha_aberta` | d[k] = vref[k]/24 V: Sinal 1 em malha aberta (0,50 / 0,75 / 0,25) |

Nas Etapas 8 e 9 o controlador digital entra no ponto marcado em `ADC_IRQHandler`, com d = f(vref, vo).

## Compilar, gravar e ler

```bash
pio run -e d_fixo
```

```bash
pio run -e d_fixo -t upload
```

Sem ST-Link, dá para gravar pelo USB-C (DFU):

1. Troque `upload_protocol = stlink` por `upload_protocol = dfu` no `platformio.ini`.
2. Na placa, segure BOOT0, aperte NRST e solte BOOT0.
3. Rode o mesmo comando de upload.

```bash
pio device monitor -b 115200
```

A serial mostra uma linha a cada 0,1 s, com o código médio do ADC, v_ADC, Vo e d:

```
codigo=1856.3 vADC=1.495 V Vo=13.41 V d=0.500 LIGADA
```

As variáveis globais `adc_codigo`, `vo_mv` e `d_contagens` também podem ser vistas ao vivo pelo depurador ou pelo STM32CubeMonitor.

## Calibração do ADC

A Etapa 3 deu v_ADC = 0,389 + 0,08251·Vo. Esses valores estão em `ADC_A_UV` (389000 µV) e `ADC_B_X1E5` (8251).

Para trocar pelos valores medidos (roteiro, blocos 4 e 5):

1. Aplique dois Vo conhecidos no CCS, por exemplo 6 V e 18 V.
2. Leia o v_ADC na serial em cada um.
3. Calcule b = Δv_ADC/ΔVo e a = v_ADC − b·Vo.
4. Troque os dois `#define` e grave de novo.

## Proteção

Se o Vo reconstruído passar de 25 V por 20 amostras seguidas (2 ms), a chave é desligada, o LED pisca rápido e a serial mostra `FALHA(sobretensao)`. Um novo aperto no KEY religa. Para desativar a proteção, use `-D PROTECAO=0`.
