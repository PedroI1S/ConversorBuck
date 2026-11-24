%% Etapa 2 - Projeto do conversor Buck (filtro LC + carga R)
% Projeto de Controle Automatico - UTFPR - Grupo com o Sinal 1
%
% Metodo da banda passante (WP2, slide 4):
%   f_LC = sqrt(f1*fs)      zeta_LC = (1/(2R))*sqrt(L/C)
%
% O professor orientou partir de zeta = 0,5 e testar; o grupo escolheu
% zeta = 0,65. O indutor e o do grupo (L = 17,71 mH), entao para cada zeta
% saem R = L*wLC/(2*zeta) e C = 1/(L*wLC^2). Este script:
%   1) projeta R e C para varios valores de zeta, com L fixo;
%   2) compara resposta ao degrau, resposta em frequencia e o seguimento
%      do Sinal 1 em malha aberta (modelo medio, u = d*E);
%   3) simula o conversor chaveado com os valores comerciais escolhidos e
%      confere conducao continua, ripple de corrente e ripple de tensao.
%
% Nao requer toolboxes: a planta e simulada por espaco de estados
% discretizado de forma exata (expm) com 100 pontos por periodo Ts.

clear; clc; close all;

%% 1) Definicoes
fs  = 10e3;                 % [Hz] chaveamento = amostragem
Ts  = 1/fs;                 % [s]
f1  = 25;                   % [Hz] fundamental da referencia
N   = 400;                  % amostras por ciclo da referencia
E   = 24;                   % [V]  fonte CC nominal
Lind = 17.71e-3;            % [H] indutor do grupo (medido em 2026-11-24)
M   = 100;                  % pontos pseudocontinuos por amostra
h   = Ts/M;                 % [s]  passo de simulacao (1 us)

fLC = sqrt(f1*fs);          % [Hz] frequencia de corte do filtro LC (500 Hz)
wLC = 2*pi*fLC;             % [rad/s]

zetas = [0.5 0.6 0.65 0.7]; % amortecimentos testados (0,65 = escolha do grupo)
nz    = numel(zetas);

% Valores comerciais adotados (zeta = 0,65)
Lc = Lind;                  % [H]
Cc = 4.7e-6 + 1e-6;         % [F] 4,7 uF + 1 uF em paralelo (catalogo do DAINF)
Rc = 39 + 3.9;              % [Ohm] 39 Ohm + 3,9 Ohm em serie (carga de potencia)

%% 2) Projeto de R e C para cada zeta, com L fixo
L = Lind*ones(1, nz);
R = L*wLC./(2*zetas);       % de zeta = (1/2R)*sqrt(L/C) e wLC = 1/sqrt(LC)
C = 1./(L*wLC^2);

%% 3) Resposta ao degrau unitario (modelo medio)
tdeg = (0:round(8e-3/h))*h;                 % 8 ms
ydeg = zeros(nz, numel(tdeg));
Mp = zeros(1, nz); tr = Mp; ts = Mp;
for i = 1:nz
    [Ad, Bd] = discretiza(L(i), C(i), R(i), h);
    x = simula(Ad, Bd, ones(size(tdeg)));
    y = x(2, :);
    ydeg(i, :) = y;
    Mp(i) = 100*(max(y) - 1);                               % [%] sobressinal
    tr(i) = tdeg(find(y >= 0.9, 1)) - tdeg(find(y >= 0.1, 1)); % [s] 10-90 %
    fora  = find(abs(y - 1) > 0.02, 1, 'last');
    ts(i) = tdeg(fora + 1);                                 % [s] criterio de 2 %
end

%% 4) Resposta em frequencia: G(jw) = wLC^2/((jw)^2 + 2*zeta*wLC*jw + wLC^2)
f  = logspace(0, log10(2*fs), 2000);        % 1 Hz a 20 kHz
jw = 1j*2*pi*f;
G  = zeros(nz, numel(f));
for i = 1:nz
    G(i, :) = wLC^2./(jw.^2 + 2*zetas(i)*wLC*jw + wLC^2);
end
resp  = @(z, fx) wLC^2./((1j*2*pi*fx).^2 + 2*z*wLC*(1j*2*pi*fx) + wLC^2);
fh    = [25 125 325];                       % fundamental, 5a e 13a harmonicas
pico  = 20*log10(max(abs(G), [], 2)).';     % [dB] pico de ressonancia
at_fs = zeros(1, nz); ganho = zeros(nz, 3); fase = ganho;
for i = 1:nz
    at_fs(i)    = 20*log10(abs(resp(zetas(i), fs)));
    ganho(i, :) = 20*log10(abs(resp(zetas(i), fh)));
    fase(i, :)  = angle(resp(zetas(i), fh))*180/pi;
end

%% 5) Seguimento do Sinal 1 em malha aberta (modelo medio)
% A acao de controle e a propria referencia: d[k] = vref[k]/E, mantida
% constante durante cada periodo Ts (ZOH), e a entrada do filtro e d*E.
nciclos = 3;
k     = 0:nciclos*N - 1;
u     = repelem(referencia_sinal1(k), M);   % [V] entrada media do filtro LC
tsim  = (0:numel(u) - 1)*h;
vid   = referencia_sinal1(tsim/Ts);         % [V] referencia ideal (continua)
ult   = tsim >= (nciclos - 1)*N*Ts;         % ultimo ciclo (regime)
vo    = zeros(nz, numel(u));
erms  = zeros(1, nz); emax = erms; vpk = erms;
for i = 1:nz
    [Ad, Bd] = discretiza(L(i), C(i), R(i), h);
    x = simula(Ad, Bd, u);
    vo(i, :) = x(2, :);
    e = vo(i, ult) - vid(ult);
    erms(i) = sqrt(mean(e.^2));             % [V] erro RMS em um ciclo
    emax(i) = max(abs(e));                  % [V] erro maximo
    vpk(i)  = max(vo(i, ult));              % [V] pico da saida
end

%% 6) Conversor chaveado com os valores comerciais: CCM e ripples
zc  = sqrt(Lc/Cc)/(2*Rc);                    % zeta obtido
fc  = 1/(2*pi*sqrt(Lc*Cc));                 % f_LC obtida
casos = [24 0.50; 24 0.25; 24 0.75; 30 0.20; 30 0.60; 18 0.50];  % [E d]
nc  = size(casos, 1);
np  = 300;                                  % periodos simulados (30 ms)
port = (0:M - 1)/M;                         % portadora dente de serra
[Ad, Bd] = discretiza(Lc, Cc, Rc, h);
res = zeros(nc, 7);
for i = 1:nc
    Ei = casos(i, 1); di = casos(i, 2);
    us = repmat(Ei*(port < di), 1, np);     % tensao no no de chaveamento
    x  = simula(Ad, Bd, us);
    fim = (np - 5)*M + 1:np*M;              % ultimos 5 periodos
    iL = x(1, fim); v = x(2, fim);
    res(i, :) = [mean(v), mean(iL), min(iL), ...
                 100*(max(iL) - min(iL))/mean(iL), ...      % ripple de corrente [%]
                 100*(max(v) - min(v))/mean(v), ...         % ripple de tensao [%]
                 100*Ei*di*(1 - di)/(Lc*fs)/(Ei*di/Rc), ...  % teorico: DiL/IL
                 100*(1 - di)/(8*Lc*Cc*fs^2)];              % teorico: DVo/Vo
    if i == 1, xs = x(:, fim); tsw = (0:numel(fim) - 1)*h; end
end

%% 7) Resultados numericos
fprintf('f_LC = sqrt(f1*fs) = %.0f Hz, L = %g mH, E = %g V\n\n', fLC, Lind*1e3, E);
fprintf(' zeta   R [Ohm] C [uF]   Mp [%%]  tr [ms]  ts2%% [ms]  pico [dB]  |G(fs)| [dB]\n');
for i = 1:nz
    fprintf(' %.2f  %6.2f  %6.2f  %6.1f  %7.3f  %8.3f  %8.2f  %10.1f\n', zetas(i), ...
        R(i), C(i)*1e6, Mp(i), tr(i)*1e3, ts(i)*1e3, pico(i), at_fs(i));
end
fprintf('\n zeta   ganho [dB] em 25/125/325 Hz     fase [graus] em 25/125/325 Hz\n');
for i = 1:nz
    fprintf(' %.2f   %6.3f  %6.3f  %6.3f        %7.2f  %7.2f  %7.2f\n', zetas(i), ganho(i, :), fase(i, :));
end
fprintf('\n Seguimento do Sinal 1 em malha aberta (modelo medio, ultimo ciclo)\n');
fprintf(' zeta   erro RMS [V]  erro max [V]  pico de Vo [V]\n');
for i = 1:nz
    fprintf(' %.2f   %9.3f   %10.3f   %11.3f\n', zetas(i), erms(i), emax(i), vpk(i));
end
fprintf('\n Valores comerciais: L = %g mH, C = %g uF, R = %g Ohm -> f_LC = %.1f Hz, zeta = %.3f\n', Lc*1e3, Cc*1e6, Rc, fc, zc);
fprintf('   E [V]   d    Vo [V]  IL [A]  ILmin [A]  DiL/IL [%%] (teor.)  DVo/Vo [%%] (teor.)\n');
for i = 1:nc
    fprintf('   %4g  %.2f  %6.2f  %6.3f  %8.3f  %8.1f (%5.1f)  %9.2f (%5.2f)\n', casos(i, :), res(i, 1:4), res(i, 6), res(i, 5), res(i, 7));
end
fprintf(' CCM em todos os casos: %d | ripple de corrente < 50 %%: %d | ripple de tensao < 2 %%: %d\n', ...
    all(res(:, 3) > 0), all(res(:, 4) < 50), all(res(:, 5) < 2));

%% 8) Graficos: comparacao dos amortecimentos
aqui = fileparts(mfilename('fullpath'));
if isempty(aqui), aqui = pwd; end
pasta = fullfile(aqui, 'figuras');
if ~exist(pasta, 'dir'), mkdir(pasta); end
leg = arrayfun(@(z) sprintf('\\zeta = %.2f', z), zetas, 'UniformOutput', false);

fig1 = figure('Name', 'Etapa 2 - Amortecimento', 'Color', 'w', 'Position', [80 80 1100 850]);
if exist('theme', 'file'), theme(fig1, 'light'); end
tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(tdeg*1e3, ydeg, 'LineWidth', 1.2); grid on; hold on;
yline([0.98 1.02], 'k:');
xlabel('Tempo [ms]'); ylabel('v_o / (d \cdot E)');
title('Resposta ao degrau unitario'); legend(leg, 'Location', 'southeast');

nexttile;
jan = tsim >= (nciclos - 1)*N*Ts + 4.5e-3 & tsim <= (nciclos - 1)*N*Ts + 9e-3;
tj  = (tsim(jan) - (nciclos - 1)*N*Ts)*1e3;
plot(tj, vo(:, jan), 'LineWidth', 1.2); grid on; hold on;
plot(tj, vid(jan), 'k--', 'LineWidth', 1.1);
xlabel('Tempo [ms]'); ylabel('v_o [V]');
title('Malha aberta: detalhe da rampa 12 V \rightarrow 18 V');
legend([leg, {'referencia'}], 'Location', 'southeast');

nexttile;
semilogx(f, 20*log10(abs(G)), 'LineWidth', 1.2); grid on; hold on;
xline([f1 325 fLC fs], 'k:', {'f_1', '13 f_1', 'f_{LC}', 'f_s'}, 'LabelVerticalAlignment', 'bottom');
xlim([1 2*fs]); ylim([-70 10]);
xlabel('Frequencia [Hz]'); ylabel('Ganho [dB]'); title('Diagrama de Bode: ganho');

nexttile;
semilogx(f, unwrap(angle(G), [], 2)*180/pi, 'LineWidth', 1.2); grid on; hold on;
xline([f1 325 fLC fs], 'k:');
xlim([1 2*fs]); ylim([-180 0]); yticks(-180:45:0);
xlabel('Frequencia [Hz]'); ylabel('Fase [graus]'); title('Diagrama de Bode: fase');

nexttile([1 2]);
ic = find(ult); ic = ic(1:10:end);          % 1 ponto a cada 10 (figura mais leve)
tc = (tsim(ic) - (nciclos - 1)*N*Ts)*1e3;
plot(tc, vo(:, ic), 'LineWidth', 1.1); grid on; hold on;
plot(tc, vid(ic), 'k--', 'LineWidth', 1.1);
ylim([0 24]); yticks(0:6:24);
xlabel('Tempo [ms]'); ylabel('v_o [V]');
title('Seguimento do Sinal 1 em malha aberta (modelo medio, um ciclo em regime)');
legend([leg, {'referencia'}], 'Location', 'northeast', 'NumColumns', 5);

exportgraphics(fig1, fullfile(pasta, 'etapa02_amortecimento.pdf'), 'ContentType', 'vector');
exportgraphics(fig1, fullfile(pasta, 'etapa02_amortecimento.png'), 'Resolution', 150);

%% 9) Graficos: conversor chaveado (valores comerciais, E = 24 V, d = 0,5)
fig2 = figure('Name', 'Etapa 2 - Ripple', 'Color', 'w', 'Position', [120 120 900 550]);
if exist('theme', 'file'), theme(fig2, 'light'); end
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(tsw*1e3, xs(1, :)*1e3, 'LineWidth', 1.2); grid on;
xlabel('Tempo [ms]'); ylabel('i_L [mA]');
title(sprintf('Corrente no indutor: \\Deltai_L/I_L = %.1f %% (E = 24 V, d = 0,5, L = %g mH)', res(1, 4), Lc*1e3));

nexttile;
plot(tsw*1e3, xs(2, :), 'LineWidth', 1.2); grid on;
xlabel('Tempo [ms]'); ylabel('v_o [V]');
title(sprintf('Tensao de saida: \\Deltav_o/V_o = %.2f %% (C = %g \\muF, R = %g \\Omega)', res(1, 5), Cc*1e6, Rc));

exportgraphics(fig2, fullfile(pasta, 'etapa02_ripple.pdf'), 'ContentType', 'vector');
exportgraphics(fig2, fullfile(pasta, 'etapa02_ripple.png'), 'Resolution', 150);

%% Funcoes locais
function [Ad, Bd] = discretiza(L, C, R, h)
% Modelo do filtro LC + carga R em espaco de estados, x = [iL; vC]:
%   L*diL/dt = u - vC          C*dvC/dt = iL - vC/R
% discretizado de forma exata para entrada constante durante o passo h.
A  = [0 -1/L; 1/C -1/(R*C)];
B  = [1/L; 0];
Ad = expm(A*h);
Bd = A\((Ad - eye(2))*B);
end

function x = simula(Ad, Bd, u)
% Equacao de diferencas x[n+1] = Ad*x[n] + Bd*u[n], com x[0] = 0.
x = zeros(2, numel(u));
for n = 1:numel(u) - 1
    x(:, n + 1) = Ad*x(:, n) + Bd*u(n);
end
end
