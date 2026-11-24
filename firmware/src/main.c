/*
 * Conversor Buck - firmware de bancada para o Black Pill (STM32F411CE)
 * Projeto de Controle Automatico - UTFPR - Grupo com o Sinal 1
 *
 * TIM1 gera um PWM de 10 kHz alinhado no inicio do periodo (contagem
 * crescente, saida alta enquanto CNT < CCR), como no modelo do CA08 e no
 * Simscape. No inicio de cada periodo o evento de update dispara uma
 * conversao do ADC1 (PA1); a interrupcao de fim de conversao le a amostra,
 * calcula a proxima razao ciclica e escreve no CCR (com preload, vale no
 * periodo seguinte: uma amostra de atraso, como no modelo).
 *
 *   PA0   KEY    botao da placa: liga / desliga a chave (comeca DESLIGADA)
 *   PA1   ADC    saida do CCS (via 100 Ohm)
 *   PA2   TX     USART2, 115200 8N1: leituras para calibracao (10 por segundo)
 *   PA8   TIM1_CH1  PWM da chave -> R_LED 180 Ohm -> 6N137
 *   PA9   TIM1_CH2  referencia do Sinal 1 em PWM, d = vref/24 V (Etapa 1b)
 *   PB0   debug  alto enquanto a interrupcao roda (tempo de calculo no osciloscopio)
 *   PC13  LED    aceso = chave habilitada; pisca devagar = desligada;
 *                pisca rapido = protecao de sobretensao atuou
 *
 * Modos (escolhidos na compilacao, ver platformio.ini):
 *   MODO_D_FIXO        d = D_FIXO_PERMIL/1000
 *   MODO_MALHA_ABERTA  d[k] = vref[k]/E_NOM (Sinal 1 em malha aberta)
 *
 * Codigo direto nos registradores, so com os cabecalhos CMSIS, no mesmo
 * estilo do firmware da Atividade 1.
 */
#include <stdint.h>
#include "stm32f4xx.h"

/* ---- Modo de operacao -------------------------------------------------- */
#define MODO_D_FIXO        0
#define MODO_MALHA_ABERTA  1

#ifndef MODO
#define MODO               MODO_D_FIXO
#endif
#ifndef D_FIXO_PERMIL
#define D_FIXO_PERMIL      500u      /* [1/1000] razao ciclica do modo d fixo */
#endif

/* ---- Parametros do projeto --------------------------------------------- */
#define F_PWM          10000u        /* [Hz] chaveamento = amostragem */
#define E_NOM_MV       24000u        /* [mV] tensao nominal da fonte */
#define N_REF          400u          /* amostras por ciclo do Sinal 1 (40 ms) */

/* Calibracao do CCS: v_ADC = A + B*Vo (Etapa 3; trocar pelos valores
 * medidos no bloco 4 do roteiro de montagem) */
#define ADC_A_UV       389000        /* [uV] v_ADC com Vo = 0 */
#define ADC_B_X1E5     8251          /* B*1e5 (B = 0,08251 V/V) */

/* Protecao: desliga a chave se Vo passar disto por PROT_AMOSTRAS seguidas */
#ifndef PROTECAO
#define PROTECAO       1
#endif
#define VO_MAX_MV      25000
#define PROT_AMOSTRAS  20u           /* 2 ms */

/* ---- Relogio: cristal de 25 MHz -> PLL -> 100 MHz ------------------------ */
#define SYSCLK_HZ      100000000u
#define PCLK1_HZ       (SYSCLK_HZ / 2u)
#define TIM1_PERIODO   (SYSCLK_HZ / F_PWM)   /* 10000 contagens por periodo */

/* ---- Variaveis compartilhadas com a interrupcao -------------------------- */
volatile uint16_t adc_codigo;        /* ultima amostra, 12 bits */
volatile int32_t  vo_mv;             /* Vo reconstruido [mV] */
volatile uint32_t d_contagens;       /* razao ciclica aplicada [contagens de TIM1] */
volatile uint32_t ticks;             /* numero de periodos desde o reset */
volatile uint8_t  chave_habilitada;  /* 0 ate apertar o KEY */
volatile uint8_t  falha;             /* 1 se a protecao atuou */
volatile uint32_t soma_codigo, n_soma;   /* media para a calibracao */

/* ---- Relogio ------------------------------------------------------------ */
static void relogio_init(void)
{
    RCC->CR |= RCC_CR_HSEON;
    while (!(RCC->CR & RCC_CR_HSERDY)) {}

    RCC->APB1ENR |= RCC_APB1ENR_PWREN;
    PWR->CR = (PWR->CR & ~PWR_CR_VOS) | PWR_CR_VOS_1 | PWR_CR_VOS_0;
    FLASH->ACR = FLASH_ACR_ICEN | FLASH_ACR_DCEN | FLASH_ACR_PRFTEN | FLASH_ACR_LATENCY_3WS;

    /* 25 MHz / 25 * 200 / 2 = 100 MHz */
    RCC->PLLCFGR = (25u << RCC_PLLCFGR_PLLM_Pos) | (200u << RCC_PLLCFGR_PLLN_Pos)
                 | (0u << RCC_PLLCFGR_PLLP_Pos) | (4u << RCC_PLLCFGR_PLLQ_Pos)
                 | RCC_PLLCFGR_PLLSRC_HSE;
    RCC->CR |= RCC_CR_PLLON;
    while (!(RCC->CR & RCC_CR_PLLRDY)) {}

    /* AHB = 100 MHz, APB1 = 50 MHz (USART2), APB2 = 100 MHz (TIM1, ADC1) */
    RCC->CFGR = RCC_CFGR_HPRE_DIV1 | RCC_CFGR_PPRE1_DIV2 | RCC_CFGR_PPRE2_DIV1 | RCC_CFGR_SW_PLL;
    while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL) {}
    SystemCoreClockUpdate();
}

/* ---- GPIO --------------------------------------------------------------- */
enum { ENTRADA, SAIDA, ALTERNATIVA, ANALOGICA };

static void gpio_modo(GPIO_TypeDef *p, uint32_t pino, uint32_t modo)
{
    p->MODER = (p->MODER & ~(3u << (2u * pino))) | (modo << (2u * pino));
}

static void gpio_af(GPIO_TypeDef *p, uint32_t pino, uint32_t af)
{
    uint32_t s = 4u * (pino % 8u);
    p->AFR[pino / 8u] = (p->AFR[pino / 8u] & ~(0xFu << s)) | (af << s);
    p->OSPEEDR |= 3u << (2u * pino);
    gpio_modo(p, pino, ALTERNATIVA);
}

/* PA8 fica como entrada (alta impedancia) ate o TIM1 estar configurado com
 * CCR1 = 0: nesse intervalo o R_PD de 10 kOhm mantem a chave desligada. */
static void gpio_init(void)
{
    RCC->AHB1ENR |= RCC_AHB1ENR_GPIOAEN | RCC_AHB1ENR_GPIOBEN | RCC_AHB1ENR_GPIOCEN;
    (void)RCC->AHB1ENR;

    gpio_modo(GPIOA, 0u, ENTRADA);                  /* KEY: aperta = nivel baixo */
    GPIOA->PUPDR = (GPIOA->PUPDR & ~(3u << 0)) | (1u << 0);  /* pull-up */
    gpio_modo(GPIOA, 1u, ANALOGICA);                /* PA1 = ADC1_IN1 */
    gpio_af(GPIOA, 2u, 7u);                         /* PA2 = USART2_TX */
    gpio_modo(GPIOB, 0u, SAIDA);                    /* PB0 = debug */
    GPIOC->BSRR = 1u << 13;                         /* LED apagado (ativo em nivel baixo) */
    gpio_modo(GPIOC, 13u, SAIDA);
}

/* ---- USART2: so transmissao, 115200 8N1 --------------------------------- */
static void uart_init(void)
{
    RCC->APB1ENR |= RCC_APB1ENR_USART2EN;
    (void)RCC->APB1ENR;
    USART2->BRR = (PCLK1_HZ + 115200u / 2u) / 115200u;   /* 434 -> 115207 baud */
    USART2->CR1 = USART_CR1_TE | USART_CR1_UE;
}

static void uart_putc(char c)
{
    while (!(USART2->SR & USART_SR_TXE)) {}
    USART2->DR = (uint8_t)c;
}

static void uart_puts(const char *s)
{
    while (*s) uart_putc(*s++);
}

/* Escreve v/10^casas com "casas" decimais (v pode ser negativo) */
static void uart_num(int32_t v, uint32_t casas)
{
    char buf[12];
    int i = 0;
    uint32_t u;
    if (v < 0) { uart_putc('-'); u = (uint32_t)(-v); } else { u = (uint32_t)v; }
    do {
        buf[i++] = (char)('0' + u % 10u);
        u /= 10u;
        if ((uint32_t)i == casas) buf[i++] = '.';
    } while (u > 0u || (uint32_t)i < casas + (casas ? 2u : 1u));   /* garante o 0 antes do ponto */
    while (i > 0) uart_putc(buf[--i]);
}

/* ---- ADC1: uma conversao do PA1 por periodo, disparada pelo TIM1 -------- */
static void adc1_init(void)
{
    RCC->APB2ENR |= RCC_APB2ENR_ADC1EN;
    (void)RCC->APB2ENR;

    ADC->CCR    = ADC_CCR_ADCPRE_0;                 /* ADC = 100/4 = 25 MHz */
    ADC1->SMPR2 = 4u << ADC_SMPR2_SMP1_Pos;         /* 84 ciclos: 3,4 us de amostragem */
    ADC1->JSQR  = 1u << ADC_JSQR_JSQ4_Pos;          /* grupo injetado, 1 conversao, canal 1 */
    ADC1->CR1   = ADC_CR1_JEOCIE;
    ADC1->CR2   = (1u << ADC_CR2_JEXTEN_Pos)        /* borda de subida do ... */
                | (1u << ADC_CR2_JEXTSEL_Pos)       /* ... TIM1_TRGO */
                | ADC_CR2_ADON;
    for (volatile uint32_t i = 0; i < 1000u; i++) {}  /* estabilizacao do ADC */

    ADC1->SR = 0u;
    NVIC_SetPriority(ADC_IRQn, 0u);
    NVIC_EnableIRQ(ADC_IRQn);
}

/* ---- TIM1: PWM de 10 kHz alinhado no inicio do periodo ------------------ */
static void tim1_init(void)
{
    RCC->APB2ENR |= RCC_APB2ENR_TIM1EN;
    (void)RCC->APB2ENR;

    TIM1->PSC  = 0u;
    TIM1->ARR  = TIM1_PERIODO - 1u;                 /* 0 ... 9999 */
    TIM1->CCR1 = 0u;                                /* chave desligada */
    TIM1->CCR2 = 0u;

    /* CH1 (PA8) e CH2 (PA9): modo PWM 1 (alto enquanto CNT < CCR), com preload */
    TIM1->CCMR1 = (6u << TIM_CCMR1_OC1M_Pos) | TIM_CCMR1_OC1PE
                | (6u << TIM_CCMR1_OC2M_Pos) | TIM_CCMR1_OC2PE;
    TIM1->CCER  = TIM_CCER_CC1E | TIM_CCER_CC2E;
    TIM1->BDTR  = TIM_BDTR_MOE;
    TIM1->CR2   = 2u << TIM_CR2_MMS_Pos;            /* TRGO = update (inicio do periodo) -> ADC */
    TIM1->CR1   = TIM_CR1_ARPE;                     /* contagem crescente */
    TIM1->EGR   = TIM_EGR_UG;
    TIM1->SR    = 0u;
    TIM1->CR1  |= TIM_CR1_CEN;

    gpio_af(GPIOA, 8u, 1u);                         /* so agora PA8 vira saida do TIM1 (em 0) */
    gpio_af(GPIOA, 9u, 1u);
}

/* ---- Referencia do Sinal 1 [mV], mesma logica de referencia_sinal1.m ---- */
static uint32_t referencia_mv(uint32_t k)
{
    const uint32_t vmed = 12000u, dv = 6000u, passo = 600u;   /* 0,6 V por amostra */
    if (k >= 50u  && k < 60u)  return vmed + passo * (k - 50u);
    if (k >= 60u  && k < 150u) return vmed + dv;
    if (k >= 150u && k < 160u) return vmed + dv - passo * (k - 150u);
    if (k >= 250u && k < 260u) return vmed - passo * (k - 250u);
    if (k >= 260u && k < 350u) return vmed - dv;
    if (k >= 350u && k < 360u) return vmed - dv + passo * (k - 350u);
    return vmed;
}

/* Razao ciclica em contagens a partir de uma tensao desejada (d = v/E_NOM) */
static uint32_t contagens_de_mv(uint32_t mv)
{
    uint32_t c = mv * (TIM1_PERIODO / 100u) / (E_NOM_MV / 100u);
    return c > TIM1_PERIODO ? TIM1_PERIODO : c;
}

/* ---- Interrupcao: fim de conversao do ADC, uma vez por periodo ----------- */
void ADC_IRQHandler(void)
{
    static uint32_t k;               /* amostra do Sinal 1, reinicia em N_REF */
    static uint32_t n_acima;

    ADC1->SR = ~ADC_SR_JEOC;
    GPIOB->BSRR = 1u << 0;           /* PB0 alto */

    /* Amostra e reconstrucao de Vo: Vo = (v_ADC - A)/B */
    uint32_t codigo = ADC1->JDR1;
    int32_t v_uv = (int32_t)(codigo * 33000u / 4095u) * 100;
    int32_t vo = (v_uv - ADC_A_UV) * 100 / ADC_B_X1E5;
    adc_codigo = (uint16_t)codigo;
    vo_mv = vo;
    soma_codigo += codigo;
    n_soma++;

    /* Referencia do Sinal 1 */
    uint32_t vref = referencia_mv(k);
    if (++k == N_REF) k = 0u;
    TIM1->CCR2 = contagens_de_mv(vref);             /* PA9: referencia para o osciloscopio */

    /* Protecao de sobretensao */
#if PROTECAO
    n_acima = (vo > VO_MAX_MV) ? n_acima + 1u : 0u;
    if (n_acima >= PROT_AMOSTRAS) { falha = 1u; chave_habilitada = 0u; }
#endif

    /* Razao ciclica do proximo periodo */
    uint32_t d = 0u;
    if (chave_habilitada) {
#if MODO == MODO_MALHA_ABERTA
        d = contagens_de_mv(vref);
#else
        d = D_FIXO_PERMIL * (TIM1_PERIODO / 1000u);
#endif
        /* Etapas 8 e 9: o controlador digital entra aqui, d = f(vref, vo) */
    }
    TIM1->CCR1 = d;
    d_contagens = d;

    ticks++;
    GPIOB->BSRR = 1u << 16;          /* PB0 baixo */
}

/* ---- Laco principal: botao, LED e relatorio na serial -------------------- */
int main(void)
{
    relogio_init();
    gpio_init();
    uart_init();
    adc1_init();
    tim1_init();

    uart_puts("\r\nConversor Buck - ");
    uart_puts(MODO == MODO_MALHA_ABERTA ? "malha aberta (Sinal 1)" : "d fixo");
    uart_puts(". Chave DESLIGADA: aperte KEY para ligar.\r\n");

    uint32_t t_botao = 0u, t_led = 0u, t_rel = 0u;
    uint8_t solto = 1u;

    for (;;) {
        uint32_t t = ticks;          /* 1 tick = 0,1 ms */

        /* KEY com debounce de 30 ms: cada aperto alterna a chave */
        uint8_t apertado = !(GPIOA->IDR & 1u);
        if (apertado && solto && (t - t_botao) > 300u) {
            solto = 0u;
            t_botao = t;
            if (chave_habilitada) {
                chave_habilitada = 0u;
            } else {
                falha = 0u;
                chave_habilitada = 1u;
            }
            uart_puts(chave_habilitada ? "Chave LIGADA\r\n" : "Chave DESLIGADA\r\n");
        } else if (!apertado && (t - t_botao) > 300u) {
            solto = 1u;
        }

        /* LED: aceso se ligada; pisca 1 Hz desligada; 5 Hz em falha */
        if (chave_habilitada) {
            GPIOC->BSRR = 1u << (13 + 16);
        } else if ((t - t_led) >= (falha ? 1000u : 5000u)) {
            t_led = t;
            GPIOC->ODR ^= 1u << 13;
        }

        /* Relatorio a cada 0,1 s: media do codigo, v_ADC, Vo e d */
        if ((t - t_rel) >= 1000u) {
            t_rel = t;
            __disable_irq();
            uint32_t soma = soma_codigo, n = n_soma;
            soma_codigo = 0u; n_soma = 0u;
            __enable_irq();
            if (n == 0u) continue;
            uint32_t cod_x10 = soma * 10u / n;                      /* codigo medio x10 */
            int32_t v_uv = (int32_t)(cod_x10 * 3300u / 4095u) * 100;  /* uV */
            int32_t vo = (v_uv - ADC_A_UV) * 100 / ADC_B_X1E5;       /* mV */
            uart_puts("codigo="); uart_num((int32_t)cod_x10, 1);
            uart_puts(" vADC="); uart_num(v_uv / 1000, 3);
            uart_puts(" V Vo="); uart_num(vo / 10, 2);
            uart_puts(" V d="); uart_num((int32_t)(d_contagens / 10u), 3);
            uart_puts(chave_habilitada ? " LIGADA" : (falha ? " FALHA(sobretensao)" : " desligada"));
            uart_puts("\r\n");
        }
    }
}
