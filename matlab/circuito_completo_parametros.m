% Parametros do modelo circuito_completo.slx (roda sozinho ao abrir o modelo).
% Mude aqui o modo do firmware, a fonte E e os componentes.

% Firmware (mesmos nomes do firmware/src/main.c)
MODO          = 0;        % 0 = d fixo, 1 = malha aberta com o Sinal 1
D_FIXO_PERMIL = 500;      % d = 0,500 no modo d fixo
ADC_A_UV      = 389000;   % calibracao do CCS: v_ADC = A + B*Vo
ADC_B_X1E5    = 8251;
T_KEY         = 1e-3;     % instante em que o botao KEY e apertado [s]

% Fonte e chaveamento
E  = 24;                  % [V] fonte de entrada (18 a 30 V)
Ts = 1e-4;                % [s] periodo do PWM e da amostragem (10 kHz)

% Potencia
L_ind  = 17.71e-3;  r_ind = 0.07;     % indutor medido
C_out1 = 4.7e-6;    C_out2 = 1e-6;    % capacitores de saida
R_pot  = 46.6;                         % resistor de potencia medido
R_par  = 3900/7;                       % 7 x 3k9 em paralelo
