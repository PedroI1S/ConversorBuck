%% Etapa 1 - Sinal de referencia para a tensao de saida do conversor Buck
% Projeto de Controle Automatico - UTFPR - Grupo com o Sinal 1 (WP2, slide 9)
%
% Gera o sinal de referencia periodico em tempo discreto, confere com os
% pontos do slide, calcula a razao ciclica ideal e o conteudo harmonico.
% Nao requer toolboxes. Execute pelo botao Run.

clear; clc; close all;

%% 1) Definicoes
fs  = 10e3;             % [Hz] frequencia de amostragem = chaveamento (slide 9)
Ts  = 1/fs;             % [s]  periodo de amostragem
T1  = 40e-3;            % [s]  periodo do sinal de referencia
f1  = 1/T1;             % [Hz] frequencia fundamental (25 Hz)
N   = round(T1/Ts);     % amostras por ciclo (400)
E   = 24;               % [V]  tensao nominal da fonte CC
nciclos = 3;            % ciclos a simular

%% 2) Geracao da referencia
k    = 0:nciclos*N - 1;         % indice das amostras
t    = k*Ts;                    % [s]
vref = referencia_sinal1(k);    % [V]
d    = vref/E;                  % razao ciclica ideal em malha aberta (Vo = d*E)

%% 3) Conferencia com os pontos marcados no slide 9
t_slide = [0 5 6 15 16 25 26 35 36 40]*1e-3;    % [s]
v_slide = [12 12 18 18 12 12 6 6 12 12];        % [V]
erro = referencia_sinal1(round(t_slide/Ts)) - v_slide;
assert(all(abs(erro) < 1e-9), 'A referencia nao passa pelos pontos do slide.');

%% 4) Conteudo harmonico (um ciclo exato -> sem vazamento espectral)
V   = fft(vref(1:N))/N;
Vcc = abs(V(1));                    % [V] valor medio
h   = 1:N/2 - 1;                    % ordem das harmonicas
Ah  = 2*abs(V(h + 1));              % [V] amplitude de cada harmonica
pot = cumsum(Ah.^2)/sum(Ah.^2);     % fracao acumulada da potencia CA
h95 = find(pot >= 0.95, 1);
h99 = find(pot >= 0.99, 1);

%% 5) Resultados numericos
fprintf('fs = %g Hz, Ts = %g ms, f1 = %g Hz, N = %d amostras/ciclo\n', fs, Ts*1e3, f1, N);
fprintf('Vref: min = %g V, max = %g V, medio = %.3f V\n', min(vref), max(vref), Vcc);
fprintf('Razao ciclica ideal (E = %g V): %.2f a %.2f\n', E, min(d), max(d));
fprintf('Rampas: %g V em 1 ms = %d amostras (%.1f V/amostra)\n', 6, 10, 0.6);
fprintf('\n Harm.  Freq [Hz]  Amplitude [V]  Pot. CA acumulada\n');
for n = 1:2:15
    fprintf('  %3d   %8g   %10.4f   %10.2f %%\n', n, n*f1, Ah(n), 100*pot(n));
end
fprintf('95 %% da potencia CA ate a harmonica %d (%g Hz)\n', h95, h95*f1);
fprintf('99 %% da potencia CA ate a harmonica %d (%g Hz)\n', h99, h99*f1);

%% 6) Graficos
fig = figure('Name', 'Etapa 1 - Referencia', 'Color', 'w', 'Position', [100 100 1000 800]);
if exist('theme', 'file'), theme(fig, 'light'); end
tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile([1 2]);
stairs(t*1e3, vref, 'LineWidth', 1.3); hold on;
plot(t_slide*1e3, v_slide, 'o', 'MarkerSize', 6, 'LineWidth', 1.2);
grid on; ylim([0 24]); yticks(0:6:24);
xlabel('Tempo [ms]'); ylabel('v_{ref} [V]');
title(sprintf('Sinal 1: referencia em tempo discreto (f_s = %g kHz, f_1 = %g Hz, N = %d)', fs/1e3, f1, N));
legend('v_{ref}[k]', 'pontos do slide 9', 'Location', 'northeast');

nexttile;
ik = 46:64;                         % amostras em torno da primeira rampa
stem(t(ik + 1)*1e3, vref(ik + 1), 'filled', 'MarkerSize', 4);
grid on; ylim([11 19]);
xlabel('Tempo [ms]'); ylabel('v_{ref} [V]');
title('Detalhe da rampa 12 V \rightarrow 18 V (10 amostras)');

nexttile;
stairs(t*1e3, d, 'LineWidth', 1.3);
grid on; ylim([0 1]);
xlabel('Tempo [ms]'); ylabel('d = v_{ref}/E');
title(sprintf('Razao ciclica ideal (E = %g V)', E));

nexttile([1 2]);
hmax = 60;                          % ate 1,5 kHz
stem(h(1:hmax)*f1, Ah(1:hmax), 'filled', 'MarkerSize', 4);
grid on;
xlabel('Frequencia [Hz]'); ylabel('Amplitude [V]');
title(sprintf('Harmonicas da referencia (valor medio = %g V)', Vcc));

%% 7) Salvar a figura
aqui = fileparts(mfilename('fullpath'));
if isempty(aqui), aqui = pwd; end
pasta = fullfile(aqui, 'figuras');
if ~exist(pasta, 'dir'), mkdir(pasta); end
exportgraphics(fig, fullfile(pasta, 'etapa01_referencia.pdf'), 'ContentType', 'vector');
exportgraphics(fig, fullfile(pasta, 'etapa01_referencia.png'), 'Resolution', 150);
