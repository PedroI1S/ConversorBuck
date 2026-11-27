%% Etapa 4 - Analise em malha aberta do conversor Buck e do CCS
% Projeto de Controle Automatico - UTFPR - Grupo com o Sinal 1
%
% Item 4 do enunciado, com os componentes que foram montados:
%   1) tempo de subida e de acomodacao (respostas ao degrau);
%   2) ganho e fase em funcao da frequencia (Bode);
%   3) tensoes de entrada e saida, atenuacao de harmonicas e ruido de medida;
%   4) resposta a sinais variantes no tempo: Sinal 1 (definicao do grupo) e,
%      para comparacao, senoidal, quadrada e triangular com a mesma faixa.
%
% Modelos medios (continuos). O chaveamento entra so como harmonica de
% 10 kHz no item 3. Requer a Control System Toolbox.

clear; clc; close all;
aqui = fileparts(mfilename('fullpath'));
pasta = fullfile(aqui, 'figuras');
if ~exist(pasta, 'dir'), mkdir(pasta); end

%% 1) Parametros do circuito montado
fs = 10e3;  Ts = 1/fs;          % chaveamento = amostragem
f1 = 25;    N  = 400;           % fundamental da referencia e amostras por ciclo
E  = 24;                        % [V] fonte nominal (18 a 30 V)

L  = 17.71e-3;  rL = 0.07;      % indutor medido
C  = 4.7e-6 + 1e-6;             % capacitores de saida
R  = 46.6;                      % resistor de potencia (medido), sem os 3k9

% CCS (valores do catalogo, roteiro bloco 4)
K_ccs  = 0.08251;               % ganho CC da cadeia (divisor x subtrator x offset)
V_off  = 0.389;                 % [V] offset
Rsk = 1.5e3; C1sk = 220e-9; C2sk = 22e-9;          % Sallen-Key de ganho unitario
wsk = 1/(Rsk*sqrt(C1sk*C2sk));  zsk = sqrt(C2sk/C1sk);
n_adc = 12; Vfs_adc = 3.3;      % ADC do STM32F411
LSB = Vfs_adc/2^n_adc;          % [V]

s = tf('s');
G_vd = E/(L*C*s^2 + (L/R + rL*C)*s + 1 + rL/R);   % Vo/d (modelo medio)
G    = G_vd/E;                                    % Vo/vref com d = vref/E (malha aberta)
F    = wsk^2/(s^2 + 2*zsk*wsk*s + wsk^2);         % Sallen-Key
H    = K_ccs*F;                                   % v_ADC - V_off em funcao de Vo
G_sw = 1/(L*C*s^2 + (L/R + rL*C)*s + 1 + rL/R);   % Vo / tensao no no de chaveamento
Gm   = G*F;                                       % Vo medido (reconstruido) / vref

wn = 1/sqrt(L*C); zLC = (L/R + rL*C)*wn/2;
fprintf('Buck:       f_LC = %.1f Hz, zeta = %.3f, ganho CC (Vo/vref) = %.4f\n', wn/2/pi, zLC, dcgain(G));
fprintf('Sallen-Key: f_PB = %.0f Hz, zeta = %.3f\n', wsk/2/pi, zsk);
fprintf('CCS:        v_ADC = %.3f + %.5f*Vo, 1 codigo = %.3f mV no ADC = %.1f mV de Vo\n\n', ...
    V_off, K_ccs, LSB*1e3, LSB/K_ccs*1e3);

%% 2) Respostas ao degrau
sis  = {G, F, Gm};
nome = {'Buck (Vo/vref)', 'Sallen-Key', 'Buck + CCS (Vo medido)'};
tdeg = linspace(0, 6e-3, 6001);
fprintf('Respostas ao degrau (subida 10-90 %%, acomodacao 2 %%)\n');
fprintf('%-24s %10s %12s %12s %10s\n', 'Sistema', 'Subida', 'Acomodacao', 'Sobressinal', 'Pico em');
ydeg = zeros(numel(sis), numel(tdeg));
for i = 1:numel(sis)
    ydeg(i, :) = step(sis{i}/dcgain(sis{i}), tdeg);
    in = stepinfo(ydeg(i, :), tdeg, 1, 'SettlingTimeThreshold', 0.02, 'RiseTimeLimits', [0.1 0.9]);
    fprintf('%-24s %8.3f ms %10.3f ms %10.1f %% %8.3f ms\n', nome{i}, in.RiseTime*1e3, ...
        in.SettlingTime*1e3, in.Overshoot, in.PeakTime*1e3);
    di(i) = in; %#ok<SAGROW>
end
fprintf('Degrau de 6 V (amplitude dos degraus do Sinal 1): pico de Vo %.2f V acima do patamar\n\n', ...
    6*di(1).Overshoot/100);

%% 3) Diagramas de Bode
f = logspace(0, 5, 2000); w = 2*pi*f;
[mG, pG]  = bode(G, w);  mG = squeeze(mG); pG = squeeze(pG);
[mF, pF]  = bode(F, w);  mF = squeeze(mF); pF = squeeze(pF);
[mM, pM]  = bode(Gm, w); mM = squeeze(mM); pM = squeeze(pM);
fprintf('Resposta em frequencia\n');
fprintf('%9s | %9s %9s | %9s %9s | %9s %9s\n', 'f [Hz]', 'Buck dB', 'fase', 'SK dB', 'fase', 'B+CCS dB', 'fase');
ft = [25 75 125 250 500 1000 1525 5000 10000];
for x = ft
    [a, b] = bode(G, 2*pi*x); [c, d] = bode(F, 2*pi*x); [e, g] = bode(Gm, 2*pi*x);
    fprintf('%9.0f | %9.2f %8.1f° | %9.2f %8.1f° | %9.2f %8.1f°\n', x, 20*log10(a), b, 20*log10(c), d, 20*log10(e), g);
end
fbw = bandwidth(G)/2/pi;
fprintf('Banda passante (-3 dB) do Buck: %.0f Hz; do Buck + CCS: %.0f Hz\n\n', fbw, bandwidth(Gm)/2/pi);

%% 4) Tensoes de entrada e saida
fprintf('Tensoes de entrada e saida (d = Vo/E, saturada em 1)\n');
fprintf('%6s %6s | %7s | %9s %9s %7s\n', 'E [V]', 'Vo', 'd', 'divisor', 'v_ADC', 'codigo');
for Ee = [18 24 30]
    for Vo = [6 12 18]
        d = min(1, Vo/Ee); Vreal = d*Ee*R/(R + rL);
        vadc = V_off + K_ccs*Vreal;
        fprintf('%6.0f %6.0f | %7.3f | %8.3f V %8.3f V %7.0f\n', Ee, Vo, d, Vreal/12, vadc, round(vadc/Vfs_adc*4095));
    end
end
fprintf('Faixa do ADC: Vo = 0 -> %.3f V; Vo = 30 V -> %.3f V (limite 3,3 V)\n\n', V_off, V_off + 30*K_ccs);

%% 5) Harmonicas do Sinal 1 e do chaveamento
k  = 0:N-1;
vr = referencia_sinal1(k);
X  = fft(vr)/N;
nh = 1:40;
A  = 2*abs(X(nh + 1));                         % amplitude de cada harmonica [V]
% A referencia e retida por Ts (ZOH): corrige o espectro do sinal continuo
fh = nh*f1;
A  = A.*abs(sinc(fh/fs));
[mGh, pGh] = bode(G, 2*pi*fh); mGh = squeeze(mGh).'; pGh = squeeze(pGh).';
Aout = A.*mGh;
fprintf('Harmonicas do Sinal 1 (valor medio %.2f V)\n', real(X(1)));
fprintf('%4s %8s %10s %10s %10s %10s\n', 'n', 'f [Hz]', 'entrada', '|G| [dB]', 'fase', 'saida');
for i = [1:10 15 20 30 40]
    fprintf('%4d %8.0f %8.3f V %10.2f %9.1f° %8.3f V\n', nh(i), fh(i), A(i), 20*log10(mGh(i)), pGh(i), Aout(i));
end
thd_in  = sqrt(sum(A(2:end).^2))/A(1);
fprintf('Conteudo harmonico acima da fundamental (ate n = 40): entrada %.1f %%, saida %.1f %% da fundamental\n\n', ...
    100*thd_in, 100*sqrt(sum(Aout(2:end).^2))/Aout(1));

% Chaveamento: fundamental de 10 kHz da tensao no no de chaveamento
fprintf('Harmonica do chaveamento (10 kHz) com d = 0,5 (maior ripple)\n');
fprintf('%6s %6s | %10s %12s %12s %12s\n', 'E [V]', 'd', 'no SW', 'Vo', 'saida CCS', 'em codigos');
for Ee = [18 24 30]
    d = 0.5;                                                % pior ripple: d = 0,5
    Asw = 2*Ee/pi*sin(pi*d);                                % fundamental do PWM
    aVo = Asw*abs(squeeze(freqresp(G_sw, 2*pi*fs)));         % amplitude em Vo
    aAD = aVo*abs(squeeze(freqresp(H, 2*pi*fs)));            % amplitude no ADC
    fprintf('%6.0f %6.2f | %8.2f V %9.1f mV %9.3f mV %10.3f\n', Ee, d, Asw, aVo*1e3, aAD*1e3, aAD/LSB);
end
fprintf('Atenuacao em 10 kHz: LC %.1f dB, Sallen-Key %.1f dB, total ate o ADC %.1f dB (com K = 1/12)\n\n', ...
    20*log10(abs(freqresp(G_sw, 2*pi*fs))), 20*log10(abs(freqresp(F, 2*pi*fs))), ...
    20*log10(abs(freqresp(G_sw*H, 2*pi*fs))));

% Ruido de medida
enbw = pi/2*(wsk/2/pi)/(2*zsk);       % [Hz] banda equivalente de ruido de um passa-baixas de 2a ordem
q_rms = LSB/sqrt(12);                 % ruido de quantizacao
fprintf('Ruido de medida\n');
fprintf('Quantizacao: 1 LSB = %.3f mV (%.1f mV de Vo); ruido RMS = %.3f mV (%.2f mV de Vo)\n', ...
    LSB*1e3, LSB/K_ccs*1e3, q_rms*1e3, q_rms/K_ccs*1e3);
fprintf('Banda equivalente de ruido do Sallen-Key: %.0f Hz (ruido branco acima dela e cortado)\n', enbw);
fprintf('Ruido entre terras de 0,4 V pp com CMRR de 34 dB (pior caso, 1 %%): %.1f mV na saida do subtrator\n', ...
    400*10^(-34/20));
fprintf('  -> em 10 kHz o Sallen-Key ainda atenua %.0f dB: %.2f mV no ADC (%.2f codigo)\n\n', ...
    -20*log10(abs(freqresp(F, 2*pi*fs))), 400*10^(-34/20)*abs(freqresp(F, 2*pi*fs)), ...
    400*10^(-34/20)*abs(freqresp(F, 2*pi*fs))*1e-3/LSB);

%% 6) Resposta a sinais variantes no tempo (2 ciclos)
h = Ts/100;                                    % passo de 1 us
t = (0:round(2*N*Ts/h) - 1)*h;
kk = floor(t/Ts);                              % amostra do sistema discreto
tk = kk*Ts;                                    % instante da amostra (ZOH)
sinais = { ...
    'Sinal 1 (trapezoidal)', referencia_sinal1(kk); ...
    'Senoidal',              12 + 6*sin(2*pi*f1*tk); ...
    'Quadrada',              12 + 6*sign(sin(2*pi*f1*tk) + eps); ...
    'Triangular',            12 + 6*(2/pi)*asin(sin(2*pi*f1*tk))};
x0 = zeros(order(G), 1);
fprintf('Resposta a sinais de 25 Hz, 6 a 18 V, retidos por Ts (2o ciclo, regime)\n');
fprintf('%-22s %10s %10s %12s %12s\n', 'Sinal', 'erro RMS', 'erro max', 'atraso', 'erro medida');
ysim = cell(size(sinais, 1), 2);
for i = 1:size(sinais, 1)
    u = sinais{i, 2};
    % parte do regime: comeca em 12 V
    yo = lsim(G, u - 12, t) + 12*dcgain(G);
    ym = lsim(Gm, u - 12, t) + 12*dcgain(Gm);
    c2 = t >= N*Ts;
    e  = yo(c2).' - u(c2);
    em = ym(c2).' - yo(c2).';
    [xc, lag] = xcorr(yo(c2) - mean(yo(c2)), u(c2).' - mean(u(c2)), round(2e-3/h));
    [~, j] = max(xc);
    fprintf('%-22s %8.3f V %8.3f V %9.0f us %10.3f V\n', sinais{i, 1}, rms(e), max(abs(e)), lag(j)*h*1e6, rms(em));
    ysim{i, 1} = yo; ysim{i, 2} = ym;
end
fprintf('(erro medida = Vo medido pelo CCS menos Vo: atraso do Sallen-Key)\n');

%% 7) Figuras
cor = lines(4);

% Degrau
fig1 = figure('Visible', 'off', 'Theme', 'light', 'Position', [0 0 900 450]);
plot(tdeg*1e3, ydeg, 'LineWidth', 1.3); grid on; hold on;
yline([0.98 1.02], ':', 'HandleVisibility', 'off');
xlabel('t [ms]'); ylabel('resposta normalizada');
legend(nome, 'Location', 'southeast');
title(sprintf('Respostas ao degrau: Buck com \\zeta = %.2f e f_{LC} = %.0f Hz; Sallen-Key com f_{PB} = %.0f Hz', ...
    zLC, wn/2/pi, wsk/2/pi));
salva(fig1, pasta, 'etapa04_degrau');

% Bode
fig2 = figure('Visible', 'off', 'Theme', 'light', 'Position', [0 0 900 700]);
tl = tiledlayout(fig2, 2, 1, 'TileSpacing', 'compact');
ax1 = nexttile; semilogx(f, 20*log10([mG mF mM]), 'LineWidth', 1.3); grid on; ylabel('ganho [dB]');
ylim([-100 20]);
ax2 = nexttile; semilogx(f, [pG pF pM], 'LineWidth', 1.3); grid on; ylabel('fase [°]'); xlabel('f [Hz]');
ylim([-380 10]); yticks(-360:90:0);
for ax = [ax1 ax2]
    xline(ax, [f1 500 1525 fs/2 fs], ':', {'25 Hz', 'f_{LC}', 'f_{PB}', 'f_s/2', 'f_s'}, 'HandleVisibility', 'off');
end
legend(ax1, {'Buck (Vo/v_{ref})', 'Sallen-Key', 'Buck + CCS'}, 'Location', 'southwest');
title(tl, 'Diagramas de Bode em malha aberta');
salva(fig2, pasta, 'etapa04_bode');

% Harmonicas
fig3 = figure('Visible', 'off', 'Theme', 'light', 'Position', [0 0 900 450]);
stem(fh, 20*log10(A), 'filled', 'LineWidth', 1.1); hold on;
stem(fh, 20*log10(Aout), 'filled', 'LineWidth', 1.1);
set(gca, 'XScale', 'log'); grid on; xlim([20 1200]);
xlabel('f [Hz]'); ylabel('amplitude [dBV]');
legend('referência (Sinal 1)', 'Vo (malha aberta)', 'Location', 'southwest');
title('Harmônicas do Sinal 1 na entrada e na saída do Buck');
salva(fig3, pasta, 'etapa04_harmonicas');

% Sinais variantes no tempo
fig4 = figure('Visible', 'off', 'Theme', 'light', 'Position', [0 0 1000 900]);
tl = tiledlayout(fig4, 4, 1, 'TileSpacing', 'compact');
for i = 1:4
    ax = nexttile;
    plot(ax, t*1e3, sinais{i, 2}, 'k', 'LineWidth', 0.8); hold(ax, 'on');
    plot(ax, t*1e3, ysim{i, 1}, 'LineWidth', 1.2, 'Color', cor(1, :));
    plot(ax, t*1e3, ysim{i, 2}, '--', 'LineWidth', 1.1, 'Color', cor(2, :));
    grid(ax, 'on'); ylabel(ax, 'V'); title(ax, sinais{i, 1}); ylim(ax, [3 21]);
end
xlabel(ax, 't [ms]');
legend(nexttile(1), 'v_{ref}', 'Vo', 'Vo medido (CCS)', 'Location', 'eastoutside');
title(tl, 'Malha aberta, d = v_{ref}/E com E = 24 V');
salva(fig4, pasta, 'etapa04_sinais');

fprintf('\nFiguras salvas em %s\n', pasta);

function salva(fig, pasta, nome)
exportgraphics(fig, fullfile(pasta, [nome '.png']), 'Resolution', 150);
exportgraphics(fig, fullfile(pasta, [nome '.pdf']), 'ContentType', 'image', 'Resolution', 300);
close(fig);
end
