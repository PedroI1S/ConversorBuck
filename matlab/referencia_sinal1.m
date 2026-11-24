function vref = referencia_sinal1(k)
%REFERENCIA_SINAL1 Referencia de tensao do Sinal 1 (WP2, slide 9), em volts.
%
%   vref = referencia_sinal1(k) devolve a tensao de referencia na amostra k
%   (escalar ou vetor de inteiros >= 0), para fs = 10 kHz (Ts = 0,1 ms).
%
%   Um ciclo tem N = 400 amostras (40 ms, f1 = 25 Hz), dividido em etapas:
%
%     k =   0 ...  49   patamar 12 V            (0 a 5 ms)
%     k =  50 ...  59   rampa   12 V -> 18 V    (5 a 6 ms)
%     k =  60 ... 149   patamar 18 V            (6 a 15 ms)
%     k = 150 ... 159   rampa   18 V -> 12 V    (15 a 16 ms)
%     k = 160 ... 249   patamar 12 V            (16 a 25 ms)
%     k = 250 ... 259   rampa   12 V ->  6 V    (25 a 26 ms)
%     k = 260 ... 349   patamar  6 V            (26 a 35 ms)
%     k = 350 ... 359   rampa    6 V -> 12 V    (35 a 36 ms)
%     k = 360 ... 399   patamar 12 V            (36 a 40 ms)
%
%   A logica e a mesma que vai para o microcontrolador: um contador k que
%   reinicia a cada N amostras e uma condicional por etapa.

N      = 400;       % amostras por ciclo
Vmed   = 12;        % [V] patamar central
dV     = 6;         % [V] degrau de cada rampa
Nrampa = 10;        % amostras por rampa (1 ms)
passo  = dV/Nrampa; % [V/amostra] = 0,6 V

k = mod(k, N);                  % contador reinicia ao fim de cada ciclo
vref = Vmed*ones(size(k));      % patamares de 12 V (valor padrao)

i = k >=  50 & k <  60;  vref(i) = Vmed      + passo*(k(i) -  50);  % sobe p/ 18 V
i = k >=  60 & k < 150;  vref(i) = Vmed + dV;                       % patamar 18 V
i = k >= 150 & k < 160;  vref(i) = Vmed + dV - passo*(k(i) - 150);  % desce p/ 12 V
i = k >= 250 & k < 260;  vref(i) = Vmed      - passo*(k(i) - 250);  % desce p/ 6 V
i = k >= 260 & k < 350;  vref(i) = Vmed - dV;                       % patamar 6 V
i = k >= 350 & k < 360;  vref(i) = Vmed - dV + passo*(k(i) - 350);  % sobe p/ 12 V
end
