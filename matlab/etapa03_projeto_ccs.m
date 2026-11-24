%% Etapa 3 - Projeto do circuito de condicionamento de sinais (CCS)
% Projeto de Controle Automatico - UTFPR - Grupo com o Sinal 1
%
% Cadeia de medicao da tensao de saida (WP2, slides 5 a 7):
%
%   Vo --[divisor K]--[subtrator S]--[Sallen-Key F]--[offset O]--> ADC (PA1)
%         R1, R2       ampop 1        ampop 2         ampop 3
%
% Os niveis sao escolhidos pelo grupo (nao seguem o slide 6):
%   0-30 V na saida do Buck -> 0-2,5 V no divisor -> +0,4 V de offset
%   -> 0,4-2,9 V na entrada do ADC (0-3,3 V, 12 bits).
% Ampops rail-to-rail alimentados em 3,3 V (sugestao: MCP6004), de modo
% que a entrada do ADC nunca sai da faixa 0-3,3 V.
%
% O script projeta cada circuito com valores comerciais (resistores E24,
% capacitores E12), varre alfa e zeta do Sallen-Key, e simula a cadeia
% completa com o conversor chaveado em malha aberta, incluindo o ruido de
% modo comum entre o terra de potencia e o terra de sinal.
% Nao requer toolboxes.

clear; clc; close all;

%% 1) Definicoes
fs  = 10e3;                 % [Hz] chaveamento = amostragem
Ts  = 1/fs;                 % [s]
f1  = 25;                   % [Hz] fundamental da referencia
N   = 400;                  % amostras por ciclo da referencia
E   = 24;                   % [V]  fonte CC nominal
M   = 100;                  % pontos pseudocontinuos por amostra
h   = Ts/M;                 % [s]  passo de simulacao (1 us)

% Conversor Buck (Etapa 2). PROVISORIO: L e C saem de zeta = 0,65 e
% R = 47 Ohm ate o grupo definir o indutor. So afeta a simulacao no tempo.
fLC     = sqrt(f1*fs);      % [Hz] 500 Hz
wLC     = 2*pi*fLC;
zeta_lc = 0.65;
Rc      = 47;               % [Ohm] carga
Lc      = 2*zeta_lc*Rc/wLC; % [H]
Cc      = 1/(2*zeta_lc*Rc*wLC); % [F]

% Black Pill: ADC de 12 bits, 0-3,3 V, amostrado no vale do PWM
adc.bits = 12;
adc.Vref = 3.3;             % [V]
adc.n    = 2^adc.bits;      % 4096 niveis
Vcc      = 3.3;             % [V] alimentacao dos ampops e referencia do offset

% Requisitos escolhidos pelo grupo
req.Vo_max   = 30;          % [V] maior tensao a medir (fonte maxima)
req.Vdiv_max = 2.5;         % [V] saida do divisor em Vo_max
req.Voff     = 0.4;         % [V] offset antes do ADC
req.Zin_min  = 10e3;        % [Ohm] impedancia minima do subtrator (slide 6)
req.tol      = 0.01;        %       tolerancia dos resistores (1 %)

% Sallen-Key (slide 7): f_PB = alfa*sqrt(fs*f_LC), 0,5 < alfa < 1, zeta 0,1-0,4
alfa    = 0.7;              % escolha de partida
zeta_pb = 0.3;              % escolha de partida
C2_sk   = 10e-9;            % [F] capacitor para o terra (fixado)
alfas    = [0.5 0.7 1.0];   % varredura
zetas_pb = [0.1 0.2 0.3 0.4];

% Perturbacao de modo comum: diferenca entre o terra de potencia e o terra
% de sinal (queda no fio durante a conducao da chave + ruido)
Vgb   = 0.2;                % [V] degrau durante a conducao
sig_g = 0.02;               % [V] ruido gaussiano (desvio padrao)

%% 2) Atenuacao: divisor resistivo (K)
div.k_alvo = req.Vdiv_max/req.Vo_max;           % 1/12
div.R2  = 1e3;
div.R1  = e24(div.R2*(1/div.k_alvo - 1));       % 11 kOhm
div.k   = div.R2/(div.R1 + div.R2);
div.Rth = div.R1*div.R2/(div.R1 + div.R2);      % resistencia de Thevenin no tap
div.P1  = (req.Vo_max*(1 - div.k))^2/div.R1;    % [W] potencia em R1 com 30 V

%% 3) Subtracao: medicao diferencial com ganho 0 dB (S)
% Vin2 = tap do divisor (via Ra), Vin1 = terra de potencia (via Ri).
% Para ganho 0 dB e rejeicao de modo comum: Rf/Ri = Rb/(Ra + Rth).
% Como Ra ja enxerga Rth do divisor, Ri recebe Rcomp ~ Rth em serie.
sub.R     = 100e3;
sub.Ra    = sub.R;  sub.Rb = sub.R;  sub.Rf = sub.R;
sub.Rcomp = e24(div.Rth);                       % 910 Ohm
sub.Ri    = sub.R + sub.Rcomp;
[sub.a, sub.b] = ganhos_sub(div.Rth, sub.Ra, sub.Rb, sub.Rf, sub.Ri);
% v_sub = (vg + k*Vo)*a - vg*b  ->  diferencial: a*k*Vo,  modo comum: (a-b)*vg
sub.Adm  = sub.a;
sub.Acm  = sub.a - sub.b;
sub.CMRR = 20*log10(sub.Adm/abs(sub.Acm));
sub.Zin1 = sub.Ri;                              % [Ohm] vista pelo terra de potencia
sub.Zin2 = sub.Ra + sub.Rb;                     % [Ohm] vista pelo tap
% Pior caso com resistores de 1 % (16 combinacoes de extremos)
cantos = dec2bin(0:15) - '0';
sub.CMRR_pior = Inf;
for i = 1:size(cantos, 1)
    fr = 1 + req.tol*(2*cantos(i, :) - 1);      % [Ra Rb Rf Ri]
    [a_, b_] = ganhos_sub(div.Rth, sub.Ra*fr(1), sub.Rb*fr(2), sub.Rf*fr(3), sub.Ri*fr(4));
    sub.CMRR_pior = min(sub.CMRR_pior, 20*log10(a_/abs(a_ - b_)));
end

%% 4) Filtragem: Sallen-Key passa-baixas de 2a ordem, ganho unitario (F)
% Slide 6: G(s) = (1/R1C1R2C2) / (s^2 + (1/R2C1 + 1/R1C1)s + 1/R1C1R2C2)
% Com R1 = R2 = R: wn = 1/(R*sqrt(C1*C2)) e zeta = sqrt(C2/C1)
sk.fpb_alvo = alfa*sqrt(fs*fLC);                % [Hz]
sk.C2 = C2_sk;
sk.C1 = e12(sk.C2/zeta_pb^2);
sk.R  = e24(1/(2*pi*sk.fpb_alvo*sqrt(sk.C1*sk.C2)));
sk.R1 = sk.R;  sk.R2 = sk.R;
sk.wn   = 1/sqrt(sk.R1*sk.R2*sk.C1*sk.C2);
sk.zeta = (sk.R1 + sk.R2)/(sk.R1*sk.R2*sk.C1)/(2*sk.wn);
sk.fpb  = sk.wn/(2*pi);

%% 5) Offset: somador nao inversor (O)
% Vo = Voffset + Vin2 - Vin1 (slide 6, direita), com Vin1 no terra de sinal
% e Voffset vindo do divisor Rx/Ry na alimentacao de 3,3 V.
off.R   = 10e3;
off.Ry  = 1e3;
off.Rx  = e24(off.Ry*(Vcc/req.Voff - 1));       % 7,5 kOhm
off.Vth = Vcc*off.Ry/(off.Rx + off.Ry);         % [V] Thevenin do offset
off.Rth = off.Rx*off.Ry/(off.Rx + off.Ry);
off.Ra  = off.R;  off.Rf = off.R;  off.Ri = off.R;
off.Rb  = e24(off.R - off.Rth);                 % compensa a Rth do offset
Rbe     = off.Rb + off.Rth;
off.g   = (1 + off.Rf/off.Ri)*Rbe/(off.Ra + Rbe);          % ganho do sinal
off.V0  = (1 + off.Rf/off.Ri)*off.Vth*off.Ra/(off.Ra + Rbe); % [V] offset obtido

%% 6) Cadeia completa (regime CC)
cad.Ga   = off.g*sub.a*div.k;                   % [V/V] v_ADC por volt de Vo
cad.V0   = off.V0;                              % [V]   v_ADC com Vo = 0
cad.Vo_max_med = (adc.Vref - cad.V0)/cad.Ga;    % [V] maior Vo medivel
cad.LSB_vo = adc.Vref/adc.n/cad.Ga;             % [V] resolucao em Vo
cad.vadc_30 = cad.V0 + cad.Ga*req.Vo_max;       % [V] v_ADC com Vo = 30 V

%% 7) Resposta em frequencia
f  = logspace(0, log10(5e4), 3000);
s  = 1j*2*pi*f;
GLC = wLC^2./(s.^2 + 2*zeta_lc*wLC*s + wLC^2);
Gpb = @(wn, z, ss) wn^2./(ss.^2 + 2*z*wn*ss + wn^2);
GSK = Gpb(sk.wn, sk.zeta, s);
em  = @(G, fx) G(find(f >= fx, 1));             % valor de G na frequencia fx

% Varredura de alfa e zeta (valores ideais)
nv = numel(alfas)*numel(zetas_pb);
tab = zeros(nv, 8);  i = 0;
for ia = 1:numel(alfas)
    for iz = 1:numel(zetas_pb)
        i  = i + 1;
        wn = 2*pi*alfas(ia)*sqrt(fs*fLC);
        G  = Gpb(wn, zetas_pb(iz), s);
        tab(i, :) = [alfas(ia), zetas_pb(iz), wn/(2*pi), ...
            20*log10(max(abs(G))), ...                  % pico de ressonancia
            20*log10(abs(Gpb(wn, zetas_pb(iz), 1j*2*pi*fs))), ...
            20*log10(abs(Gpb(wn, zetas_pb(iz), 1j*2*pi*fs)*wLC^2/((1j*2*pi*fs)^2 + 2*zeta_lc*wLC*1j*2*pi*fs + wLC^2))), ...
            angle(Gpb(wn, zetas_pb(iz), 1j*2*pi*325))*180/pi, ...
            angle(Gpb(wn, zetas_pb(iz), 1j*2*pi*fLC))*180/pi];
    end
end

%% 8) Resposta ao degrau do Sallen-Key
tdeg = (0:round(3e-3/h))*h;
ydeg = zeros(numel(zetas_pb) + 1, numel(tdeg));
wn07 = 2*pi*0.7*sqrt(fs*fLC);
for i = 1:numel(zetas_pb) + 1
    if i <= numel(zetas_pb), wn = wn07; z = zetas_pb(i); else, wn = sk.wn; z = sk.zeta; end
    [Ad, Bd] = c2d_exato([0 1; -wn^2 -2*z*wn], [0; wn^2], h);
    xs = zeros(2, 1);
    for n = 1:numel(tdeg)
        ydeg(i, n) = xs(1);
        xs = Ad*xs + Bd;
    end
end
yk = ydeg(end, :);
sk.Mp = 100*(max(yk) - 1);
sk.tr = tdeg(find(yk >= 0.9, 1)) - tdeg(find(yk >= 0.1, 1));
sk.ts = tdeg(find(abs(yk - 1) > 0.02, 1, 'last') + 1);
sk.atraso = 2*sk.zeta/sk.wn;                    % [s] atraso em baixas frequencias

%% 9) Simulacao da cadeia com o conversor chaveado (malha aberta)
nciclos = 2;
Nk = nciclos*N;  Nt = Nk*M;
rng(3, 'twister');
vref = referencia_sinal1(0:Nk - 1);             % [V]
d    = vref/E;                                  % acao de controle = referencia
% PWM centrado (contador up-down, vale em p = 0): a chave fica ligada para
% p < d/2 e p > 1 - d/2. Com so 100 passos por periodo, comparar o
% contador passo a passo limitaria a resolucao do PWM a 2 %; por isso cada
% passo usa a fracao exata do tempo em que a chave esteve ligada.
lo   = mod(0:Nt - 1, M)/M;                      % inicio de cada passo no periodo
hi   = lo + 1/M;                                % fim de cada passo
dt   = repelem(d, M);
sw   = M*(max(0, min(hi, dt/2) - lo) + max(0, hi - max(lo, 1 - dt/2)));  % 0 a 1
vg   = Vgb*sw + sig_g*randn(1, Nt);             % [V] terra de potencia - terra de sinal

[AdL, BdL] = c2d_exato([0 -1/Lc; 1/Cc -1/(Rc*Cc)], [1/Lc; 0], h);
[AdS, BdS] = c2d_exato([0 1; -sk.wn^2 -2*sk.zeta*sk.wn], [0; sk.wn^2], h);
sat = @(v) min(max(v, 0), Vcc);                 % saida rail-to-rail em 0-3,3 V

xl = zeros(2, 1);  xs = zeros(2, 1);
[vo, vtap, vsub, vsk, vadc] = deal(zeros(1, Nt));
carga = sub.Zin2/(div.Rth + sub.Zin2);          % carregamento do tap pelo subtrator
for n = 1:Nt
    vo(n)   = xl(2);
    vtap(n) = (vg(n) + div.k*vo(n))*carga;      % tap medido em relacao ao terra de sinal
    vsub(n) = sat((vg(n) + div.k*vo(n))*sub.a - vg(n)*sub.b);
    vsk(n)  = sat(xs(1));
    vadc(n) = sat(off.g*vsk(n) + off.V0);
    xl = AdL*xl + BdL*(E*sw(n));
    xs = AdS*xs + BdS*vsub(n);
end
t = (0:Nt - 1)*h;

% ADC: uma amostra por periodo, no vale do contador
ia_   = 1:M:Nt;
code  = min(floor(vadc(ia_)/adc.Vref*adc.n), adc.n - 1);
vo_med = ((code + 0.5)*adc.Vref/adc.n - cad.V0)/cad.Ga;     % reconstrucao no firmware
tk    = t(ia_);

% Indicadores no ultimo ciclo. O valor de interesse para o controle e o
% valor medio de vo em cada periodo de chaveamento (sem o ripple), entao o
% erro e medido contra a media movel de vo em uma janela de Ts centrada na
% amostra.
vo_media = movmean(vo, M);
ult  = tk >= (nciclos - 1)*N*Ts;
emed = vo_med(ult) - vo_media(ia_(ult));
res.erms = sqrt(mean(emed.^2));
res.emax = max(abs(emed));
% Ripple no patamar de 18 V (10 a 14 ms do ultimo ciclo)
t0  = (nciclos - 1)*N*Ts;
pat = t >= t0 + 10e-3 & t < t0 + 14e-3;
pp  = @(v) max(v(pat)) - min(v(pat));
res.pp_vo   = pp(vo);
res.pp_sub  = pp(vsub);
res.pp_sk   = pp(vsk);
res.pp_adc  = pp(vadc);
res.pp_vg   = pp(vg);
res.pp_cm   = pp(vsub - sub.a*div.k*vo);        % residuo do modo comum apos o subtrator
patk = tk >= t0 + 10e-3 & tk < t0 + 14e-3;
res.codigos = max(code(patk)) - min(code(patk));

%% 10) Resultados numericos
fprintf('=== Atenuacao (divisor) ===\n');
fprintf('R1 = %g k, R2 = %g k -> k = %.5f (alvo %.5f), Rth = %.0f Ohm, P(R1) = %.0f mW a 30 V\n', ...
    div.R1/1e3, div.R2/1e3, div.k, div.k_alvo, div.Rth, 1e3*div.P1);
fprintf('\n=== Subtrator ===\n');
fprintf('Ra = Rb = Rf = %g k, Ri = %g k + %g Ohm\n', sub.R/1e3, sub.R/1e3, sub.Rcomp);
fprintf('Ganho diferencial = %.5f (%.3f dB), CMRR nominal = %.0f dB, pior caso (1 %%) = %.0f dB\n', ...
    sub.Adm, 20*log10(sub.Adm), sub.CMRR, sub.CMRR_pior);
fprintf('Impedancias de entrada: %.0f k (terra de potencia), %.0f k (tap)\n', sub.Zin1/1e3, sub.Zin2/1e3);
fprintf('\n=== Sallen-Key: varredura (valores ideais) ===\n');
fprintf(' alfa  zeta  f_PB [Hz]  pico [dB]  |F(fs)| [dB]  |LC*F(fs)| [dB]  fase 325 Hz  fase 500 Hz\n');
fprintf(' %.1f   %.1f   %7.0f   %8.2f   %10.1f   %12.1f   %9.1f   %9.1f\n', tab.');
fprintf('\nEscolha: alfa = %.1f, zeta = %.1f -> R1 = R2 = %g k, C1 = %g nF, C2 = %g nF\n', ...
    alfa, zeta_pb, sk.R/1e3, sk.C1*1e9, sk.C2*1e9);
fprintf('Obtido: f_PB = %.0f Hz (alvo %.0f), zeta = %.3f, pico = %.2f dB, |F(fs)| = %.1f dB\n', ...
    sk.fpb, sk.fpb_alvo, sk.zeta, 20*log10(max(abs(GSK))), 20*log10(abs(em(GSK, fs))));
fprintf('Degrau: sobressinal = %.1f %%, subida = %.0f us, acomodacao 2 %% = %.0f us, atraso = %.0f us\n', ...
    sk.Mp, 1e6*sk.tr, 1e6*sk.ts, 1e6*sk.atraso);
fprintf('Fase: %.1f graus em 25 Hz, %.1f em 325 Hz, %.1f em 500 Hz\n', ...
    angle(em(GSK, 25))*180/pi, angle(em(GSK, 325))*180/pi, angle(em(GSK, fLC))*180/pi);
fprintf('\n=== Offset ===\n');
fprintf('R = %g k, Rx = %g k, Ry = %g k, Rb = %g k -> ganho = %.4f, offset = %.4f V (alvo %.2f V)\n', ...
    off.R/1e3, off.Rx/1e3, off.Ry/1e3, off.Rb/1e3, off.g, off.V0, req.Voff);
fprintf('\n=== Cadeia completa ===\n');
fprintf('v_ADC = %.3f V + %.5f*Vo  ->  Vo = 30 V da %.3f V no ADC\n', cad.V0, cad.Ga, cad.vadc_30);
fprintf('Faixa medivel: 0 a %.1f V, resolucao de %.1f mV por codigo\n', cad.Vo_max_med, 1e3*cad.LSB_vo);
fprintf('\n=== Simulacao com o conversor chaveado (ultimo ciclo) ===\n');
fprintf('Erro de medicao (Vo reconstruido - media de Vo no periodo): RMS = %.3f V, max = %.3f V\n', res.erms, res.emax);
fprintf('Patamar de 18 V, pico a pico: Vo = %.1f mV | subtrator = %.2f mV | Sallen-Key = %.3f mV | ADC = %.3f mV (%d codigos)\n', ...
    1e3*res.pp_vo, 1e3*res.pp_sub, 1e3*res.pp_sk, 1e3*res.pp_adc, res.codigos);
fprintf('Modo comum: %.0f mV entre os terras -> %.3f mV na saida do subtrator\n', 1e3*res.pp_vg, 1e3*res.pp_cm);

%% 11) Figura 1: projeto do Sallen-Key
aqui = fileparts(mfilename('fullpath'));
if isempty(aqui), aqui = pwd; end
pasta = fullfile(aqui, 'figuras');
if ~exist(pasta, 'dir'), mkdir(pasta); end
db  = @(G) 20*log10(abs(G));
fas = @(G) unwrap(angle(G))*180/pi;

fig1 = figure('Name', 'Etapa 3 - Sallen-Key', 'Color', 'w', 'Position', [80 80 1100 850]);
if exist('theme', 'file'), theme(fig1, 'light'); end
tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
semilogx(f, db(GLC), 'k--', 'LineWidth', 1.2); hold on;
for ia = 1:numel(alfas)
    semilogx(f, db(Gpb(2*pi*alfas(ia)*sqrt(fs*fLC), zeta_pb, s)), 'LineWidth', 1.2);
end
xline([f1 fLC fs], 'k:', {'f_1', 'f_{LC}', 'f_s'}, 'LabelVerticalAlignment', 'bottom');
grid on; xlim([10 5e4]); ylim([-80 15]);
xlabel('Frequencia [Hz]'); ylabel('Ganho [dB]');
title(sprintf('Efeito de \\alpha (\\zeta_{PB} = %.1f)', zeta_pb));
legend([{'filtro LC'}, arrayfun(@(a) sprintf('\\alpha = %.1f', a), alfas, 'UniformOutput', false)], 'Location', 'southwest');

nexttile;
for iz = 1:numel(zetas_pb)
    semilogx(f, db(Gpb(wn07, zetas_pb(iz), s)), 'LineWidth', 1.2); hold on;
end
xline([fLC fs], 'k:', {'f_{LC}', 'f_s'}, 'LabelVerticalAlignment', 'bottom');
grid on; xlim([10 5e4]); ylim([-80 15]);
xlabel('Frequencia [Hz]'); ylabel('Ganho [dB]');
title('Efeito de \zeta_{PB} (\alpha = 0,7)');
legend(arrayfun(@(z) sprintf('\\zeta_{PB} = %.1f', z), zetas_pb, 'UniformOutput', false), 'Location', 'southwest');

nexttile;
semilogx(f, db(GLC), 'k--', f, db(GSK), f, db(GLC.*GSK), 'LineWidth', 1.2);
xline([f1 325 fLC fs], 'k:', {'f_1', '13 f_1', 'f_{LC}', 'f_s'}, 'LabelVerticalAlignment', 'bottom');
grid on; xlim([1 5e4]); ylim([-120 15]);
xlabel('Frequencia [Hz]'); ylabel('Ganho [dB]');
title(sprintf('Valores comerciais: f_{PB} = %.0f Hz, \\zeta_{PB} = %.2f', sk.fpb, sk.zeta));
legend('LC', 'Sallen-Key', 'LC \times Sallen-Key', 'Location', 'southwest');

nexttile;
semilogx(f, fas(GLC), 'k--', f, fas(GSK), f, fas(GLC.*GSK), 'LineWidth', 1.2);
xline([f1 325 fLC fs], 'k:');
grid on; xlim([1 5e4]); ylim([-360 0]); yticks(-360:45:0);
xlabel('Frequencia [Hz]'); ylabel('Fase [graus]');
title('Fase: o Sallen-Key quase nao atrasa ate f_{LC}');
legend('LC', 'Sallen-Key', 'LC \times Sallen-Key', 'Location', 'southwest');

nexttile([1 2]);
plot(tdeg*1e6, ydeg(1:end - 1, :), 'LineWidth', 1.1); hold on;
plot(tdeg*1e6, yk, 'k', 'LineWidth', 1.6);
yline([0.98 1.02], 'k:');
grid on; xlim([0 2000]);
xlabel('Tempo [\mus]'); ylabel('Saida / entrada');
title('Resposta ao degrau do Sallen-Key');
legend([arrayfun(@(z) sprintf('\\zeta_{PB} = %.1f (\\alpha = 0,7)', z), zetas_pb, 'UniformOutput', false), ...
    {sprintf('comercial (\\zeta = %.2f)', sk.zeta)}], 'Location', 'southeast');

exportgraphics(fig1, fullfile(pasta, 'etapa03_sallen_key.pdf'), 'ContentType', 'image', 'Resolution', 300);
exportgraphics(fig1, fullfile(pasta, 'etapa03_sallen_key.png'), 'Resolution', 150);

%% 12) Figura 2: sinais ao longo da cadeia
fig2 = figure('Name', 'Etapa 3 - Cadeia', 'Color', 'w', 'Position', [100 60 1100 950]);
if exist('theme', 'file'), theme(fig2, 'light'); end
tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
tu  = (t - t0)*1e3;                             % [ms] tempo no ultimo ciclo
cic = t >= t0;  dec = find(cic);  dec = dec(1:10:end);
zw  = t >= t0 + 12e-3 & t < t0 + 12.5e-3;       % janela de 0,5 ms no patamar de 18 V

nexttile;
plot(tu(dec), vo(dec), 'LineWidth', 1.1); hold on;
stairs((tk(ult) - t0)*1e3, vref(ult), 'k--');
grid on; ylim([0 24]); yticks(0:6:24);
xlabel('Tempo [ms]'); ylabel('[V]'); title('Saida do Buck v_o e referencia');
legend('v_o', 'v_{ref}', 'Location', 'northeast');

nexttile;
plot(tu(zw), vo(zw), 'LineWidth', 1.1); grid on;
xlabel('Tempo [ms]'); ylabel('v_o [V]');
title(sprintf('Ripple em v_o: %.0f mV pico a pico', 1e3*res.pp_vo));

nexttile;
plot(tu(zw), vtap(zw), tu(zw), vsub(zw), 'LineWidth', 1.1); grid on;
xlabel('Tempo [ms]'); ylabel('[V]');
title('Divisor (com o ruido entre terras) e saida do subtrator');
legend('tap do divisor', 'subtrator', 'Location', 'east');

nexttile;
plot(tu(zw), vsub(zw), tu(zw), vsk(zw), 'LineWidth', 1.1); grid on;
xlabel('Tempo [ms]'); ylabel('[V]');
title(sprintf('Sallen-Key: %.2f mV \\rightarrow %.3f mV pico a pico', 1e3*res.pp_sub, 1e3*res.pp_sk));
legend('subtrator', 'Sallen-Key', 'Location', 'east');

nexttile;
plot(tu(dec), vadc(dec), 'LineWidth', 1.1); hold on;
yline([0 adc.Vref], 'r--', {'0 V', '3,3 V'});
grid on; ylim([-0.2 3.5]);
xlabel('Tempo [ms]'); ylabel('v_{ADC} [V]'); title('Entrada do ADC (apos o offset)');

nexttile;
vx = 0:0.1:36;
plot(vx, sat(cad.V0 + cad.Ga*vx), 'LineWidth', 1.3); hold on;
yline(adc.Vref, 'r--', '3,3 V'); xline(req.Vo_max, 'k:', '30 V');
grid on; xlim([0 36]); ylim([0 3.5]);
xlabel('v_o [V]'); ylabel('v_{ADC} [V]');
title(sprintf('Transferencia estatica: v_{ADC} = %.3f + %.4f v_o', cad.V0, cad.Ga));

nexttile;
plot(tu(dec), vo(dec), 'LineWidth', 1.1); hold on;
stairs((tk(ult) - t0)*1e3, vo_med(ult), 'LineWidth', 1.1);
grid on; ylim([0 24]); yticks(0:6:24);
xlabel('Tempo [ms]'); ylabel('[V]'); title('v_o reconstruido a partir do codigo do ADC');
legend('v_o', 'medido (ADC)', 'Location', 'northeast');

nexttile;
stairs((tk(ult) - t0)*1e3, emed, 'LineWidth', 1.1); grid on;
xlabel('Tempo [ms]'); ylabel('[V]');
title(sprintf('Erro de medicao: RMS = %.3f V (atraso de %.0f \\mus do filtro)', res.erms, 1e6*sk.atraso));

exportgraphics(fig2, fullfile(pasta, 'etapa03_cadeia.pdf'), 'ContentType', 'image', 'Resolution', 300);
exportgraphics(fig2, fullfile(pasta, 'etapa03_cadeia.png'), 'Resolution', 150);

%% Funcoes locais
function [a, b] = ganhos_sub(Rth, Ra, Rb, Rf, Ri)
% Subtrator alimentado pelo tap (Thevenin Rth) e pelo terra de potencia:
% v_out = v_tap_th*a - v_terra*b
a = Rb/(Rth + Ra + Rb)*(1 + Rf/Ri);
b = Rf/Ri;
end

function [Ad, Bd] = c2d_exato(A, B, h)
% Discretizacao exata com entrada constante durante o passo h (ZOH)
n = size(A, 1);  m = size(B, 2);
Me = expm([A B; zeros(m, n + m)]*h);
Ad = Me(1:n, 1:n);
Bd = Me(1:n, n + 1:end);
end

function v = e24(x)
% Valor comercial E24 mais proximo (escala logaritmica)
v = serie_mais_proxima(x, [1.0 1.1 1.2 1.3 1.5 1.6 1.8 2.0 2.2 2.4 2.7 3.0 ...
                           3.3 3.6 3.9 4.3 4.7 5.1 5.6 6.2 6.8 7.5 8.2 9.1]);
end

function v = e12(x)
% Valor comercial E12 mais proximo (escala logaritmica)
v = serie_mais_proxima(x, [1.0 1.2 1.5 1.8 2.2 2.7 3.3 3.9 4.7 5.6 6.8 8.2]);
end

function v = serie_mais_proxima(x, serie)
cand = serie(:)*10.^(-13:7);
cand = cand(:);
[~, i] = min(abs(log(cand/x)));
v = cand(i);
end
