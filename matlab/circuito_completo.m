%% Circuito completo do conversor Buck no Simulink/Simscape
% Monta circuito_completo.slx com os mesmos componentes e ligacoes do
% roteiro de montagem (docs/roteiro_montagem.md), um subsistema por bloco:
%
%   1 Fonte E e L7805 | 2 Acionamento (6N137, Q1, Q2) | 3 Potencia (IRF9530,
%   FCH20A20, L, C, carga) | 4a Divisor (perto do C de saida) | 4 CCS
%   (subtrator, Sallen-Key, offset no LM324) | 5 Black Pill (ADC, firmware, PWM)
%
% Depois roda dois casos (d fixo = 0,5 e Sinal 1 em malha aberta), mostra os
% valores esperados em cada ponto de medida do roteiro e salva as figuras.
% Componentes de Simscape Electrical (ee_lib) e da Foundation Library.

clear; clc; close all;
aqui = fileparts(mfilename('fullpath'));
cd(aqui);
fig = fullfile(aqui, 'figuras');
if ~exist(fig, 'dir'), mkdir(fig); end
mdl = 'buck_circuito_completo';

%% 1. Monta o modelo
monta(mdl, aqui);

%% 2. Caso 1: d fixo = 0,5 com E = 24 V
circuito_completo_parametros;
MODO = 0; T_KEY = 1e-3; %#ok<NASGU>
r1 = roda(mdl, 12e-3);
relatorio_d_fixo(r1, Ts);
figura_d_fixo(r1, Ts, fig);

%% 3. Caso 2: Sinal 1 em malha aberta
circuito_completo_parametros;
MODO = 1; T_KEY = 0; %#ok<NASGU>
r2 = roda(mdl, 45e-3);
relatorio_sinal1(r2);
figura_sinal1(r2, fig);

%% 4. Imagens do diagrama (para o roteiro)
imagens_do_modelo(mdl, fig);
close_system(mdl, 0);

%% ======================================================================
function r = roda(mdl, Tf)
load_system(mdl);
set_param(mdl, 'StopTime', num2str(Tf));
tic; out = sim(mdl); fprintf('Simulacao de %.0f ms: %.0f s\n', Tf*1e3, toc);
nomes = {'med_bp', 'med_acion', 'med_pot', 'med_ccs'};
for i = 1:numel(nomes)
    ts = out.(nomes{i});
    r.(nomes{i}).t = ts.Time;
    y = squeeze(ts.Data);
    if size(y, 1) ~= numel(ts.Time), y = y.'; end
    r.(nomes{i}).y = y;
end
end

function v = media(t, y, t0, t1)
k = t >= t0 & t < t1;
tk = t(k); v = trapz(tk, y(k)) / (tk(end) - tk(1));
end

function relatorio_d_fixo(r, Ts)
% Valores em regime (ultimos 2 ms) nos pontos de medida do roteiro
t0 = 10e-3; t1 = 12e-3;
bp = r.med_bp; ac = r.med_acion; po = r.med_pot; cc = r.med_ccs;
fprintf('\n=== d fixo = 0,5, E = 24 V (regime, %g a %g ms) ===\n', t0*1e3, t1*1e3);
% Niveis durante a chave ligada e desligada: amostra no meio de cada meio periodo
tl = t1 - Ts + 0.25*Ts; td = t1 - Ts + 0.75*Ts;
val = @(s, tt) interp1u(s.t, s.y, tt);
a_l = val(ac, tl); a_d = val(ac, td); p_l = val(po, tl); p_d = val(po, td);
fprintf('Bloco 2  pino 6 do 6N137: %.2f V (ligada) / %.2f V (desligada)\n', a_l(1), a_d(1));
fprintf('         coletor de Q2:   %.2f V / %.2f V\n', a_l(2), a_d(2));
fprintf('         VGS do IRF9530:  %.2f V / %.2f V\n', a_l(3), a_d(3));
fprintf('Bloco 3  no de chaveamento: %.2f V / %.2f V\n', p_l(1), p_d(1));
k = po.t >= t0 & po.t < t1;
fprintf('         iL media %.3f A, ripple %.3f A pp\n', media(po.t, po.y(:, 2), t0, t1), ...
    max(po.y(k, 2)) - min(po.y(k, 2)));
fprintf('         Vo media %.3f V, ripple %.1f mV pp\n', media(po.t, po.y(:, 3), t0, t1), ...
    1e3*(max(po.y(k, 3)) - min(po.y(k, 3))));
nm = {'divisor', 'subtrator', 'Sallen-Key', 'offset (pino 8)', 'PA1'};
for i = 1:5
    fprintf('Bloco 4  %-16s %.3f V\n', nm{i}, media(cc.t, cc.y(:, i), t0, t1));
end
fprintf('Bloco 5  codigo do ADC %.0f, Vo reconstruido %.3f V, d = %.3f\n', ...
    bp.y(end, 5), bp.y(end, 4), bp.y(end, 2));
% Tempos de comutacao no no de chaveamento (10 % a 90 % de E)
v = po.y(:, 1); t = po.t; kk = t > t1 - 2*Ts;
tt = t(kk); vv = v(kk); E = max(vv);
up = find(diff(vv > 0.5*E) == 1, 1); dn = find(diff(vv > 0.5*E) == -1, 1);
if ~isempty(up) && ~isempty(dn)
    tr = tempo_borda(tt, vv, up, 0.1*E, 0.9*E); tf = tempo_borda(tt, vv, dn, 0.9*E, 0.1*E);
    fprintf('Bloco 3  subida %.2f us, descida %.2f us no no de chaveamento\n', tr*1e6, tf*1e6);
end
end

function v = interp1u(t, y, tt)
[tu, iu] = unique(t, 'last');
v = interp1(tu, y(iu, :), tt);
end

function dt = tempo_borda(t, v, k, a, b)
j = max(1, k - 400):min(numel(t), k + 400);
ta = interp_cruz(t(j), v(j), a); tb = interp_cruz(t(j), v(j), b);
dt = abs(tb - ta);
end

function tc = interp_cruz(t, v, nivel)
s = sign(v - nivel); k = find(s(1:end-1) ~= s(2:end), 1);
if isempty(k), tc = NaN; return; end
tc = t(k) + (nivel - v(k))*(t(k+1) - t(k))/(v(k+1) - v(k));
end

function relatorio_sinal1(r)
bp = r.med_bp; po = r.med_pot;
fprintf('\n=== Sinal 1 em malha aberta, E = 24 V ===\n');
pat = [2e-3 5e-3 12; 10e-3 15e-3 18; 20e-3 25e-3 12; 30e-3 35e-3 6];   % janelas de patamar [t0 t1 vref]
for i = 1:size(pat, 1)
    vo = media(po.t, po.y(:, 3), pat(i, 1), pat(i, 2));
    vr = media(bp.t, bp.y(:, 4), pat(i, 1), pat(i, 2));
    fprintf('vref = %4.1f V: Vo = %.2f V (erro %.2f V), Vo lido pelo ADC = %.2f V\n', ...
        pat(i, 3), vo, vo - pat(i, 3), vr);
end
end

function figura_d_fixo(r, Ts, pasta)
bp = r.med_bp; ac = r.med_acion; po = r.med_pot; cc = r.med_ccs;
t1 = 12e-3; z = @(s) s.t > t1 - 2*Ts;
f = figure('Visible', 'off', 'Theme', 'light', 'Position', [0 0 1000 1100]);
tl = tiledlayout(f, 4, 1, 'TileSpacing', 'compact');
title(tl, 'Circuito completo, d = 0,5 e E = 24 V: dois períodos em regime');
ax = nexttile; k = z(bp); plot(ax, (bp.t(k) - bp.t(find(k,1)))*1e6, bp.y(k, 1), 'LineWidth', 1.2); hold(ax, 'on');
k = z(ac); plot(ax, (ac.t(k) - ac.t(find(k,1)))*1e6, ac.y(k, 1), 'LineWidth', 1.2);
ylabel(ax, 'V'); legend(ax, 'PA8 (Black Pill)', 'pino 6 do 6N137', 'Location', 'eastoutside'); grid(ax, 'on');
ax = nexttile; plot(ax, (ac.t(k) - ac.t(find(k,1)))*1e6, ac.y(k, 2:3), 'LineWidth', 1.2);
ylabel(ax, 'V'); legend(ax, 'coletor de Q2', 'V_{GS} do IRF9530', 'Location', 'eastoutside'); grid(ax, 'on');
ax = nexttile; k = z(po); tt = (po.t(k) - po.t(find(k,1)))*1e6;
yyaxis(ax, 'left'); plot(ax, tt, po.y(k, 1), 'LineWidth', 1.2); ylabel(ax, 'nó de chaveamento [V]');
yyaxis(ax, 'right'); plot(ax, tt, po.y(k, 2), 'LineWidth', 1.2); ylabel(ax, 'i_L [A]'); grid(ax, 'on');
ax = nexttile; k = z(cc); plot(ax, (cc.t(k) - cc.t(find(k,1)))*1e6, cc.y(k, :), 'LineWidth', 1.2);
ylabel(ax, 'V'); xlabel(ax, 't [\mus]'); grid(ax, 'on');
legend(ax, 'divisor', 'subtrator', 'Sallen-Key', 'offset', 'PA1', 'Location', 'eastoutside');
exportgraphics(f, fullfile(pasta, 'circuito_completo_d_fixo.png'), 'Resolution', 150);
close(f);

f = figure('Visible', 'off', 'Theme', 'light', 'Position', [0 0 1000 500]);
plot(po.t*1e3, po.y(:, 3), 'LineWidth', 1); hold on;
stairs(bp.t*1e3, bp.y(:, 4), 'LineWidth', 1);
xline(1, '--', 'KEY'); grid on; xlabel('t [ms]'); ylabel('V');
legend('Vo', 'Vo lido pelo Black Pill (ADC)', 'Location', 'southeast');
title('Partida com d = 0,5: chave desligada até o KEY em 1 ms');
exportgraphics(f, fullfile(pasta, 'circuito_completo_partida.png'), 'Resolution', 150);
close(f);
end

function figura_sinal1(r, pasta)
bp = r.med_bp; po = r.med_pot;
f = figure('Visible', 'off', 'Theme', 'light', 'Position', [0 0 1000 700]);
tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact');
title(tl, 'Circuito completo: Sinal 1 em malha aberta, d[k] = v_{ref}[k]/24 V');
ax = nexttile; plot(ax, po.t*1e3, po.y(:, 3), 'LineWidth', 1); hold(ax, 'on');
stairs(ax, bp.t*1e3, bp.y(:, 3), 'LineWidth', 1); stairs(ax, bp.t*1e3, bp.y(:, 4), 'LineWidth', 1);
ylabel(ax, 'V'); grid(ax, 'on'); legend(ax, 'Vo', 'v_{ref}', 'Vo lido pelo ADC', 'Location', 'eastoutside');
ax = nexttile; stairs(ax, bp.t*1e3, bp.y(:, 2), 'LineWidth', 1);
ylabel(ax, 'd'); xlabel(ax, 't [ms]'); grid(ax, 'on');
exportgraphics(f, fullfile(pasta, 'circuito_completo_sinal1.png'), 'Resolution', 150);
close(f);
end

function imagens_do_modelo(mdl, pasta)
load_system(mdl);
alvos = {mdl, [mdl '/1 Fonte E e L7805'], [mdl '/1 Fonte E e L7805/L7805'], [mdl '/2 Acionamento'], [mdl '/2 Acionamento/6N137'], ...
         [mdl '/3 Potencia'], [mdl '/4a Divisor'], [mdl '/4 CCS'], [mdl '/5 Black Pill']};
arq = {'modelo_topo', 'modelo_fonte', 'modelo_l7805', 'modelo_acionamento', 'modelo_6n137', 'modelo_potencia', ...
       'modelo_divisor', 'modelo_ccs', 'modelo_black_pill'};
for i = 1:numel(alvos)
    try
        print(['-s' alvos{i}], '-dpng', '-r150', fullfile(pasta, ['circuito_completo_' arq{i} '.png']));
    catch err
        fprintf('Nao gerou a imagem de %s: %s\n', alvos{i}, err.message);
    end
end
end

%% ======================================================================
%  Montagem do modelo
%  Ordem das portas (conferida com circuitos de teste):
%    Diodo: L1 anodo, R1 catodo          Ampop: L1 (+), L2 (-), R1 saida
%    NPN: L1 base, R1 coletor, R2 emissor  MOSFET P: L1 gate, R1 source, R2 dreno
%    Opto: L1 anodo, L2 catodo do LED; R2 fotocorrente (para a base), R1 retorno
%    Fonte DC: L1 (+), R1 (-). Fonte controlada e sensores: L1 (+), R2 (-), R1 entrada/saida PS
%  ======================================================================
function monta(mdl, pasta)
load_system('ee_lib'); load_system('fl_lib'); load_system('nesl_utility'); load_system('simulink');
if bdIsLoaded(mdl), close_system(mdl, 0); end
arq = fullfile(pasta, [mdl '.slx']);
if exist(arq, 'file'), delete(arq); end
new_system(mdl); open_system(mdl, 'loadonly');
set_param(mdl, 'PreLoadFcn', 'circuito_completo_parametros;', ...
    'Solver', 'ode23t', 'RelTol', '1e-4', 'MaxStep', '1e-6', 'StopTime', '12e-3', ...
    'ReturnWorkspaceOutputs', 'on', 'SignalLogging', 'off');
evalin('base', 'circuito_completo_parametros;');

s1 = subsistema(mdl, '1 Fonte E e L7805', [60 260 200 380], [1 .95 .8]);
s5 = subsistema(mdl, '5 Black Pill', [60 60 200 200], [.85 .9 1]);
s2 = subsistema(mdl, '2 Acionamento', [330 120 480 300], [1 .85 .85]);
s3 = subsistema(mdl, '3 Potencia', [620 180 760 320], [.85 1 .85]);
s4 = subsistema(mdl, '4 CCS', [960 20 1100 140], [.95 .85 1]);
s6 = subsistema(mdl, '4a Divisor', [820 200 900 280], [1 1 .75]);

monta_fonte(s1); monta_black_pill(s5); monta_acionamento(s2); monta_potencia(s3); monta_ccs(s4); monta_divisor(s6);

% Ligacoes entre os blocos (mesmos nomes do roteiro)
W(porta(s1, 'E'), porta(s2, 'E')); W(porta(s1, 'E'), porta(s3, 'E'));
W(porta(s1, '5V'), porta(s2, '5V'));
W(porta(s5, 'PA8'), porta(s2, 'PA8'));
W(porta(s2, 'GATE'), porta(s3, 'GATE'));
W(porta(s3, 'Vo'), porta(s6, 'Vo')); W(porta(s6, 'Vdiv'), porta(s4, 'Vdiv'));
W(porta(s5, '3V3'), porta(s4, '3V3')); W(porta(s5, '5V USB'), porta(s4, '5V USB'));
W(porta(s4, 'PA1'), porta(s5, 'PA1'));

% Terras: dois barramentos (fios), como na protoboard
TP = 'terra de potencia'; TS = 'terra de sinal';
W(porta(s3, TP), porta(s1, TP)); W(porta(s3, TP), porta(s2, TP));
W(porta(s3, TP), porta(s6, TP)); W(porta(s3, TP), porta(s4, TP));
W(porta(s5, TS), porta(s2, TS)); W(porta(s5, TS), porta(s4, TS));
% Ponto unico: o unico fio entre os dois terras, no negativo do C de saida
W(porta(s5, TS), porta(s3, TP));
ref = B(mdl, 'GND', 'referencia do simulador (0 V)', 700, 420, 'right');
slv = B(mdl, 'SOLV', 'Solver', 620, 420, 'right');
W(P(ref, 'L', 1), porta(s3, TP)); W(P(slv, 'R', 1), porta(s3, TP));

% Medidas: um To Workspace e um Scope por bloco
md = {s5, 'med_bp', 'Osc. Black Pill: PA8, d, vref, Vo lido, codigo';
      s2, 'med_acion', 'Osc. acionamento: pino 6, coletor Q2, VGS';
      s3, 'med_pot', 'Osc. potencia: no SW, iL, Vo';
      s4, 'med_ccs', 'Osc. CCS: divisor, subtrator, SK, offset, PA1'};
for i = 1:size(md, 1)
    pos = get_param(md{i, 1}, 'Position');
    x = 1220; y = 40 + (i - 1)*110;
    tw = add_block('simulink/Sinks/To Workspace', [mdl '/' md{i, 2}], 'VariableName', md{i, 2}, ...
        'SaveFormat', 'Timeseries', 'Position', [x y x + 70 y + 30]);
    sc = add_block('simulink/Sinks/Scope', [mdl '/' md{i, 3}], 'Position', [x y + 45 x + 40 y + 75]);
    po = get_param(md{i, 1}, 'PortHandles');
    add_line(mdl, po.Outport(1), get_param(tw, 'PortHandles').Inport(1), 'autorouting', 'smart');
    add_line(mdl, po.Outport(1), get_param(sc, 'PortHandles').Inport(1), 'autorouting', 'smart');
    pos(1) = pos(1); %#ok<ASGSL>
end

nota(mdl, 60, 430, sprintf([ ...
    'Conversor Buck completo, um bloco por etapa do roteiro de montagem (docs/roteiro_montagem.md).\n' ...
    'Clique duas vezes num bloco para ver os componentes. Os nomes dos componentes sao os do roteiro.\n' ...
    'Parametros e modo do firmware: circuito_completo_parametros.m (MODO = 0 d fixo, 1 malha aberta).\n' ...
    'Terras: dois barramentos, como na protoboard. "terra de potencia" (negativo da fonte E) e "terra de sinal"\n' ...
    '(GND do Black Pill) so se encontram no fio do ponto unico, ligado no negativo do C de saida (bloco 3).\n' ...
    'O 6N137 (PA8) e o subtrator do CCS (medida de Vo) atravessam de um terra para o outro.']));

save_system(mdl, arq);
fprintf('Modelo salvo em %s\n', arq);
end

function nota(sys, x, y, txt)
a = Simulink.Annotation(sys, txt);
a.Position = [x y x + 600 y + 60];
a.HorizontalAlignment = 'left';
end

function s = subsistema(mdl, nome, pos, cor)
s = [mdl '/' nome];
add_block('simulink/Ports & Subsystems/Subsystem', s, 'Position', pos, ...
    'BackgroundColor', sprintf('[%g %g %g]', cor));
delete_line(s, 'In1/1', 'Out1/1'); delete_block([s '/In1']); delete_block([s '/Out1']);
end

% ---- Ajudantes de montagem ------------------------------------------------
function h = B(sub, tipo, nome, x, y, ori, varargin)
% Coloca um bloco centrado em (x, y). ori: 'right' (horizontal) ou 'down' (vertical)
lib = struct( ...
    'R',    'fl_lib/Electrical/Electrical Elements/Resistor', ...
    'C',    'fl_lib/Electrical/Electrical Elements/Capacitor', ...
    'L',    'fl_lib/Electrical/Electrical Elements/Inductor', ...
    'GND',  'fl_lib/Electrical/Electrical Elements/Electrical Reference', ...
    'DC',   'fl_lib/Electrical/Electrical Sources/DC Voltage Source', ...
    'CVS',  'fl_lib/Electrical/Electrical Sources/Controlled Voltage Source', ...
    'VS',   'fl_lib/Electrical/Electrical Sensors/Voltage Sensor', ...
    'IS',   'fl_lib/Electrical/Electrical Sensors/Current Sensor', ...
    'D',    'ee_lib/Semiconductors & Converters/Diode', ...
    'NPN',  'ee_lib/Semiconductors & Converters/NPN Bipolar Transistor', ...
    'PMOS', 'ee_lib/Semiconductors & Converters/P-Channel MOSFET', ...
    'OPTO', 'ee_lib/Semiconductors & Converters/Optocoupler', ...
    'AMP',  'ee_lib/Integrated Circuits/Finite-Gain Op-Amp', ...
    'PS2S', sprintf('nesl_utility/PS-Simulink\nConverter'), ...
    'S2PS', sprintf('nesl_utility/Simulink-PS\nConverter'), ...
    'SOLV', sprintf('nesl_utility/Solver\nConfiguration'), ...
    'CP',   'nesl_utility/Connection Port');
tam = struct('R', [40 20], 'C', [40 20], 'L', [50 20], 'GND', [20 20], 'DC', [30 30], 'CVS', [30 30], ...
    'VS', [30 30], 'IS', [30 30], 'D', [30 20], 'NPN', [30 40], 'PMOS', [30 40], 'OPTO', [50 50], ...
    'AMP', [40 40], 'PS2S', [25 20], 'S2PS', [25 20], 'SOLV', [30 30], 'CP', [25 15]);
w = tam.(tipo); if any(strcmp(ori, {'down', 'up'})), w = fliplr(w); end
h = add_block(lib.(tipo), [sub '/' nome], 'Position', [x - w(1)/2, y - w(2)/2, x + w(1)/2, y + w(2)/2], ...
    'Orientation', ori, varargin{:});
end

function p = P(h, lado, i)
ph = get_param(h, 'PortHandles');
switch lado
    case 'L', p = ph.LConn(i);
    case 'R', p = ph.RConn(i);
    case 'I', p = ph.Inport(i);
    case 'O', p = ph.Outport(i);
end
end

function W(a, b)
add_line(get_param(get_param(a, 'Parent'), 'Parent'), a, b, 'autorouting', 'smart');
end

function c = CP(sub, nome, x, y, lado)
c = B(sub, 'CP', nome, x, y, 'right', 'Side', lado);
end

function p = porta(sub, nome)
% Porta fisica do subsistema que corresponde ao Connection Port "nome"
cps = find_system(sub, 'SearchDepth', 1, 'BlockType', 'PMIOPort');
alvo = [sub '/' nome]; lado = get_param(alvo, 'Side');
mesmo = cps(strcmp(get_param(cps, 'Side'), lado));
num = cellfun(@(c) str2double(get_param(c, 'Port')), mesmo);
[~, ordem] = sort(num); mesmo = mesmo(ordem);
k = find(strcmp(mesmo, alvo));
ph = get_param(sub, 'PortHandles');
if strcmpi(lado, 'Left'), p = ph.LConn(k); else, p = ph.RConn(k); end
end

function g = T(sub, x, y, nome)
% Simbolo de terra
persistent n
if isempty(n), n = 0; end
n = n + 1;
if nargin < 4, nome = sprintf('terra %d', n); else, nome = sprintf('%s %d', nome, n); end
g = B(sub, 'GND', nome, x, y, 'right');
end

function med = medidas(sub, sinais, x0, y0)
% sinais: celulas {handle do sensor (saida PS em R1), unidade}; junta tudo num Mux
n = numel(sinais);
mx = add_block('simulink/Signal Routing/Mux', [sub '/Mux medidas'], 'Inputs', num2str(n), ...
    'Position', [x0 + 80, y0, x0 + 85, y0 + 30*n]);
out = add_block('simulink/Sinks/Out1', [sub '/medidas'], 'Position', [x0 + 130, y0 + 15*n - 7, x0 + 150, y0 + 15*n + 7]);
add_line(sub, [get_param(mx, 'Name') '/1'], 'medidas/1');
for i = 1:n
    h = sinais{i}{1};
    c = add_block(sprintf('nesl_utility/PS-Simulink\nConverter'), [sub sprintf('/PS-S %d', i)], ...
            'Position', [x0, y0 + 30*(i - 1) + 5, x0 + 25, y0 + 30*(i - 1) + 25], 'Unit', sinais{i}{2});
        add_line(sub, P(h, 'R', 1), P(c, 'L', 1), 'autorouting', 'smart');
        add_line(sub, P(c, 'O', 1), P(mx, 'I', i), 'autorouting', 'smart');
end
med = mx;
end

function L(sub, a, b)
add_line(sub, a, b, 'autorouting', 'smart');
end

% ---- Bloco 1: fonte de bancada e L7805 ------------------------------------
function monta_fonte(s)
pE = CP(s, 'E', 900, 60, 'Right'); p5 = CP(s, '5V', 900, 160, 'Right');
pT = CP(s, 'terra de potencia', 900, 320, 'Right');
gnd = P(pT, 'R', 1);

% Fonte de bancada: + e - (o borne verde de terra nao e usado)
e  = B(s, 'DC', 'Fonte de bancada E', 60, 150, 'down', 'v0', 'E');
rf = B(s, 'R', 'fios da fonte 0,1 ohm', 130, 60, 'right', 'R', '0.1');
L(s, P(e, 'L', 1), P(rf, 'L', 1)); L(s, P(rf, 'R', 1), P(pE, 'R', 1)); L(s, P(e, 'R', 1), gnd);

% L7805 como um CI de 3 pinos: 1 entrada, 2 GND, 3 saida
rg = [s '/L7805'];
add_block('simulink/Ports & Subsystems/Subsystem', rg, 'Position', [430 110 530 210], 'BackgroundColor', '[1 1 1]');
delete_line(rg, 'In1/1', 'Out1/1'); delete_block([rg '/In1']); delete_block([rg '/Out1']);
a1 = CP(rg, 'pino 1 entrada', 40, 60, 'Left'); a3 = CP(rg, 'pino 3 saida', 360, 60, 'Right');
a2 = CP(rg, 'pino 2 GND', 360, 200, 'Right');
rq = B(rg, 'R', 'consumo interno (~5 mA)', 120, 130, 'down', 'R', '4.7e3');
v5 = B(rg, 'DC', 'regulador 5 V', 220, 130, 'down', 'v0', '5');
ro = B(rg, 'R', 'R de saida 0,05', 290, 60, 'right', 'R', '0.05');
L(rg, P(a1, 'R', 1), P(rq, 'L', 1)); L(rg, P(rq, 'R', 1), P(a2, 'R', 1));
L(rg, P(v5, 'L', 1), P(ro, 'L', 1)); L(rg, P(ro, 'R', 1), P(a3, 'R', 1)); L(rg, P(v5, 'R', 1), P(a2, 'R', 1));
nota(rg, 40, 260, sprintf('L7805 simplificado: 5 V na saida (pino 3) e ~5 mA de consumo na entrada (pino 1).\nPinagem: letras para voce, 1 entrada, 2 GND, 3 saida.'));

% Capacitores do L7805 (10 uF eletrolitico + 100 nF ceramico na entrada e na saida)
ci1 = B(s, 'C', 'C 10 uF (entrada)', 220, 240, 'down', 'c', '10e-6', 'r', '0.3');
ci2 = B(s, 'C', 'C 100 nF (entrada)', 340, 240, 'down', 'c', '100e-9');
co1 = B(s, 'C', 'C 10 uF (saida)', 620, 240, 'down', 'c', '10e-6', 'r', '0.3');
co2 = B(s, 'C', 'C 100 nF (saida)', 740, 240, 'down', 'c', '100e-9');
L(s, P(rf, 'R', 1), porta(rg, 'pino 1 entrada'));
L(s, porta(rg, 'pino 3 saida'), P(p5, 'R', 1)); L(s, porta(rg, 'pino 2 GND'), gnd);
for h = [ci1 ci2], L(s, porta(rg, 'pino 1 entrada'), P(h, 'L', 1)); L(s, P(h, 'R', 1), gnd); end
for h = [co1 co2], L(s, porta(rg, 'pino 3 saida'), P(h, 'L', 1)); L(s, P(h, 'R', 1), gnd); end
nota(s, 60, 380, sprintf([ ...
    'E: fonte de bancada, 18 a 30 V (24 V nominal), so os bornes + e -.\n' ...
    'L7805 com a entrada em E. 10 uF + 100 nF colados nos pinos, na entrada e na saida (faixa do eletrolitico no terra).\n' ...
    'Tudo aqui vai no terra de potencia.']));
end

% ---- Bloco 5: Black Pill (ADC, firmware e PWM) ----------------------------
function monta_black_pill(s)
pA = CP(s, 'PA1', 40, 120, 'Left');
p8 = CP(s, 'PA8', 900, 300, 'Right'); p3 = CP(s, '3V3', 900, 400, 'Right');
pU = CP(s, '5V USB', 900, 480, 'Right'); pT = CP(s, 'terra de sinal', 900, 560, 'Right');
gnd = @() P(pT, 'R', 1);   % todos os terras aqui sao o GND do Black Pill

% Medida do PA1 (o ADC nao puxa corrente)
vs = B(s, 'VS', 'tensao no PA1', 120, 120, 'right');
L(s, P(pA, 'R', 1), P(vs, 'L', 1)); L(s, P(vs, 'R', 2), gnd());
ps = B(s, 'PS2S', 'PS-S PA1', 180, 120, 'right', 'Unit', 'V');
L(s, P(vs, 'R', 1), P(ps, 'L', 1));

% ADC: amostra no inicio do periodo (TIM1 TRGO), 12 bits de 0 a 3,3 V
sl = 'simulink/';
zoh = add_block([sl 'Discrete/Zero-Order Hold'], [s '/ADC amostra no TRGO do TIM1'], 'SampleTime', 'Ts', ...
    'Position', [230 105 270 135]);
gq = add_block([sl 'Math Operations/Gain'], [s '/x 4095 por 3,3 V'], 'Gain', '4095/3.3', 'Position', [300 105 340 135]);
rq = add_block([sl 'Math Operations/Rounding Function'], [s '/round'], 'Operator', 'round', 'Position', [360 105 390 135]);
sq = add_block([sl 'Discontinuities/Saturation'], [s '/0 a 4095'], 'UpperLimit', '4095', 'LowerLimit', '0', ...
    'Position', [410 105 440 135]);
add_line(s, P(ps, 'O', 1), P(zoh, 'I', 1)); add_line(s, P(zoh, 'O', 1), P(gq, 'I', 1));
add_line(s, P(gq, 'O', 1), P(rq, 'I', 1)); add_line(s, P(rq, 'O', 1), P(sq, 'I', 1));

% Botao KEY e constantes do firmware
key = add_block([sl 'Sources/Step'], [s '/botao KEY'], 'Time', 'T_KEY', 'Before', '0', 'After', '1', ...
    'SampleTime', 'Ts', 'Position', [410 170 440 200]);
cst = {'MODO', 'D_FIXO_PERMIL', 'ADC_A_UV', 'ADC_B_X1E5'};
for i = 1:numel(cst)
    add_block([sl 'Sources/Constant'], [s '/' cst{i}], 'Value', cst{i}, ...
        'Position', [380 200 + 35*i 460 225 + 35*i]);
end

% Firmware: mesma conta da ADC_IRQHandler do firmware/src/main.c
fw = [s '/Firmware ADC_IRQHandler'];
add_block([sl 'User-Defined Functions/MATLAB Function'], fw, 'Position', [520 100 660 300]);
ch = sfroot().find('-isa', 'Stateflow.EMChart', 'Path', fw);
ch.Script = codigo_firmware();
ph = get_param(fw, 'PortHandles');
add_line(s, P(sq, 'O', 1), ph.Inport(1)); add_line(s, P(key, 'O', 1), ph.Inport(2));
for i = 1:numel(cst), add_line(s, [cst{i} '/1'], sprintf('Firmware ADC_IRQHandler/%d', i + 2)); end

% CCR1 com preload: o d calculado vale no periodo seguinte
ud = add_block([sl 'Discrete/Unit Delay'], [s '/preload do CCR1'], 'SampleTime', 'Ts', 'Position', [700 105 740 135]);
add_line(s, ph.Outport(1), P(ud, 'I', 1));
serra = add_block([sl 'Sources/Repeating Sequence'], [s '/TIM1 contador 0 a 9999'], ...
    'rep_seq_t', '[0 Ts]', 'rep_seq_y', '[0 1]', 'Position', [700 30 740 60]);
cmp = add_block([sl 'Logic and Bit Operations/Relational Operator'], [s '/CNT < CCR1'], 'Operator', '<', ...
    'Position', [780 40 810 120]);
dbl = add_block([sl 'Signal Attributes/Data Type Conversion'], [s '/double'], 'OutDataTypeStr', 'double', ...
    'Position', [830 65 860 95]);
g33 = add_block([sl 'Math Operations/Gain'], [s '/3,3 V'], 'Gain', '3.3', 'Position', [880 65 910 95]);
add_line(s, P(serra, 'O', 1), P(cmp, 'I', 1)); add_line(s, P(ud, 'O', 1), P(cmp, 'I', 2));
add_line(s, P(cmp, 'O', 1), P(dbl, 'I', 1)); add_line(s, P(dbl, 'O', 1), P(g33, 'I', 1));

% Pino PA8: fonte controlada 0 / 3,3 V
sp = B(s, 'S2PS', 'S-PS PA8', 760, 300, 'right', 'Unit', 'V', 'FilteringAndDerivatives', 'zero');
cv = B(s, 'CVS', 'saida PA8', 830, 300, 'right');
add_line(s, P(g33, 'O', 1), P(sp, 'I', 1));
L(s, P(sp, 'R', 1), P(cv, 'R', 1));      % entrada PS da fonte controlada
L(s, P(cv, 'L', 1), P(p8, 'R', 1)); L(s, P(cv, 'R', 2), gnd());

% 3,3 V da placa (para o offset do CCS)
v3 = B(s, 'DC', 'regulador 3,3 V da placa', 830, 420, 'down', 'v0', '3.3');
L(s, P(v3, 'L', 1), P(p3, 'R', 1)); L(s, P(v3, 'R', 1), gnd());

% 5 V do USB (pino 5V da placa), para o LM324
vu = B(s, 'DC', 'USB 5 V', 760, 520, 'down', 'v0', '5');
ru = B(s, 'R', 'cabo USB 0,2 ohm', 830, 480, 'right', 'R', '0.2');
L(s, P(vu, 'L', 1), P(ru, 'L', 1)); L(s, P(ru, 'R', 1), P(pU, 'R', 1)); L(s, P(vu, 'R', 1), gnd());

% Medidas: PA8 [V], d, vref [V], Vo lido [V], codigo
vp = B(s, 'VS', 'tensao no PA8', 900, 230, 'down');
L(s, P(vp, 'L', 1), P(p8, 'R', 1)); L(s, P(vp, 'R', 2), gnd());
mx = add_block('simulink/Signal Routing/Mux', [s '/Mux medidas'], 'Inputs', '5', 'Position', [1050 100 1055 260]);
out = add_block('simulink/Sinks/Out1', [s '/medidas'], 'Position', [1100 170 1120 184]); %#ok<NASGU>
add_line(s, 'Mux medidas/1', 'medidas/1');
cv2 = add_block(sprintf('nesl_utility/PS-Simulink\nConverter'), [s '/PS-S PA8'], 'Unit', 'V', 'Position', [980 105 1005 125]);
L(s, P(vp, 'R', 1), P(cv2, 'L', 1));
add_line(s, P(cv2, 'O', 1), P(mx, 'I', 1), 'autorouting', 'smart');
add_line(s, P(ud, 'O', 1), P(mx, 'I', 2), 'autorouting', 'smart');
add_line(s, ph.Outport(2), P(mx, 'I', 3), 'autorouting', 'smart');
add_line(s, ph.Outport(3), P(mx, 'I', 4), 'autorouting', 'smart');
add_line(s, P(sq, 'O', 1), P(mx, 'I', 5), 'autorouting', 'smart');

nota(s, 60, 520, sprintf([ ...
    'Black Pill: TIM1 a 10 kHz, pulso no inicio do periodo (PWM modo 1). O update do TIM1 dispara o ADC no PA1;\n' ...
    'a interrupcao calcula o proximo d, que vale no periodo seguinte (preload). Firmware: firmware/src/main.c.\n' ...
    'Antes do KEY a chave fica desligada (d = 0). O PA9 (referencia para o filtro RC) nao esta no modelo.']));
end

function c = codigo_firmware()
c = sprintf(['function [d, vref, vo] = firmware(codigo, key, MODO, D_FIXO_PERMIL, ADC_A_UV, ADC_B_X1E5)\n' ...
'%% Mesma conta da ADC_IRQHandler (firmware/src/main.c), em inteiros.\n' ...
'%% Saidas: d (0 a 1), vref [V] do Sinal 1, vo [V] reconstruido do ADC.\n' ...
'persistent k n_acima falha\n' ...
'if isempty(k), k = 0; n_acima = 0; falha = false; end\n' ...
'\n' ...
'%% Vo = (v_ADC - A)/B\n' ...
'v_uv  = floor(codigo*33000/4095)*100;\n' ...
'vo_mv = fix((v_uv - ADC_A_UV)*100/ADC_B_X1E5);\n' ...
'\n' ...
'%% Referencia do Sinal 1 [mV]: 400 amostras por ciclo (40 ms)\n' ...
'vref_mv = referencia_mv(k);\n' ...
'k = k + 1; if k == 400, k = 0; end\n' ...
'\n' ...
'%% Protecao: Vo > 25 V por 20 amostras desliga a chave\n' ...
'if vo_mv > 25000, n_acima = n_acima + 1; else, n_acima = 0; end\n' ...
'if n_acima >= 20, falha = true; end\n' ...
'\n' ...
'%% Razao ciclica em contagens do TIM1 (0 a 10000)\n' ...
'cont = 0;\n' ...
'if key > 0.5 && ~falha\n' ...
'    if MODO == 1\n' ...
'        cont = min(10000, floor(vref_mv*100/240));   %% d = vref/24 V\n' ...
'    else\n' ...
'        cont = D_FIXO_PERMIL*10;\n' ...
'    end\n' ...
'    %% Etapas 8 e 9: o controlador entra aqui, cont = f(vref_mv, vo_mv)\n' ...
'end\n' ...
'd = cont/10000; vref = vref_mv/1000; vo = vo_mv/1000;\n' ...
'end\n' ...
'\n' ...
'function v = referencia_mv(k)\n' ...
'vmed = 12000; dv = 6000; passo = 600;\n' ...
'if k >= 50 && k < 60,       v = vmed + passo*(k - 50);\n' ...
'elseif k >= 60 && k < 150,  v = vmed + dv;\n' ...
'elseif k >= 150 && k < 160, v = vmed + dv - passo*(k - 150);\n' ...
'elseif k >= 250 && k < 260, v = vmed - passo*(k - 250);\n' ...
'elseif k >= 260 && k < 350, v = vmed - dv;\n' ...
'elseif k >= 350 && k < 360, v = vmed - dv + passo*(k - 350);\n' ...
'else,                       v = vmed;\n' ...
'end\n' ...
'end\n']);
end

% ---- Bloco 2: acionamento (6N137, Q1, Q2, gate do IRF9530) ----------------
function monta_acionamento(s)
p8 = CP(s, 'PA8', 40, 200, 'Left'); p5 = CP(s, '5V', 40, 60, 'Left'); pE = CP(s, 'E', 40, 20, 'Left');
pG = CP(s, 'GATE', 1000, 200, 'Right');
pS = CP(s, 'terra de sinal', 40, 380, 'Left'); pT = CP(s, 'terra de potencia', 1000, 380, 'Right');
gnd = @() P(pT, 'R', 1);    % terra de potencia (lado da saida do 6N137)
gsn = P(pS, 'R', 1);            % terra de sinal (lado do LED)

% Lado do Black Pill
rl = B(s, 'R', 'R_LED 180', 140, 200, 'right', 'R', '180');
rpd = B(s, 'R', 'R_PD 10k', 90, 260, 'down', 'R', '10e3');
L(s, P(p8, 'R', 1), P(rl, 'L', 1)); L(s, P(p8, 'R', 1), P(rpd, 'L', 1));
L(s, P(rpd, 'R', 1), gsn);

% 6N137 como um CI com os pinos 2, 3, 6 e 5
op = [s '/6N137'];
add_block('simulink/Ports & Subsystems/Subsystem', op, 'Position', [200 150 340 290], 'BackgroundColor', '[1 1 1]');
delete_line(op, 'In1/1', 'Out1/1'); delete_block([op '/In1']); delete_block([op '/Out1']);
a2 = CP(op, 'pino 2 anodo', 40, 60, 'Left'); a3 = CP(op, 'pino 3 catodo', 40, 140, 'Left');
a8 = CP(op, 'pino 8 VCC', 400, 20, 'Right'); a7 = CP(op, 'pino 7 enable', 400, 60, 'Right');
a6 = CP(op, 'pino 6 saida', 400, 100, 'Right'); a5 = CP(op, 'pino 5 GND', 400, 160, 'Right');
ri = B(op, 'R', 'consumo 10 mA', 220, 190, 'down', 'R', '500');
L(op, P(a8, 'R', 1), P(ri, 'L', 1)); L(op, P(ri, 'R', 1), P(a5, 'R', 1)); L(op, P(a7, 'R', 1), P(a8, 'R', 1));
oc = B(op, 'OPTO', 'LED e fotodetector', 150, 100, 'right', 'CTR', '0.01', 'I12', '[1e-3 10e-3]', 'V12', '[1.3 1.5]');
qo = B(op, 'NPN', 'transistor de saida', 280, 100, 'right');
L(op, P(a2, 'R', 1), P(oc, 'L', 1)); L(op, P(a3, 'R', 1), P(oc, 'L', 2));
L(op, P(oc, 'R', 2), P(qo, 'L', 1)); L(op, P(oc, 'R', 1), P(qo, 'R', 2));
L(op, P(qo, 'R', 1), P(a6, 'R', 1)); L(op, P(qo, 'R', 2), P(a5, 'R', 1));
nota(op, 40, 220, sprintf([ ...
    'O 6N137 tem fotodiodo + amplificador + transistor de coletor aberto.\n' ...
    'Aqui: LED com 1,5 V em 10 mA e fotocorrente na base de um transistor (saida coletor aberto).\n' ...
    'Pinos 8 (VCC) e 7 (enable) vao no +5 V; 100 nF entre 8 e 5.']));
L(s, P(rl, 'R', 1), porta(op, 'pino 2 anodo'));
L(s, porta(op, 'pino 3 catodo'), gsn);
L(s, P(p5, 'R', 1), porta(op, 'pino 8 VCC')); L(s, P(p5, 'R', 1), porta(op, 'pino 7 enable'));
cop = B(s, 'C', 'C 100 nF (pinos 8-5)', 400, 40, 'right', 'c', '100e-9');
L(s, porta(op, 'pino 8 VCC'), P(cop, 'L', 1)); L(s, P(cop, 'R', 1), porta(op, 'pino 5 GND'));

% Lado da potencia: pull-up, Q1 (desfaz a inversao) e Q2
rp = B(s, 'R', 'R_P 1k', 360, 120, 'down', 'R', '1e3');
L(s, P(p5, 'R', 1), P(rp, 'L', 1)); L(s, porta(op, 'pino 6 saida'), P(rp, 'R', 1));
L(s, porta(op, 'pino 5 GND'), gnd());
r1 = B(s, 'R', 'R_1 4k7', 430, 200, 'right', 'R', '4.7e3');
L(s, P(rp, 'R', 1), P(r1, 'L', 1));
q1 = B(s, 'NPN', 'Q1 BC547', 520, 200, 'right');
rbe1 = B(s, 'R', 'R_BE1 10k', 480, 260, 'down', 'R', '10e3');
L(s, P(r1, 'R', 1), P(q1, 'L', 1)); L(s, P(r1, 'R', 1), P(rbe1, 'L', 1));
L(s, P(rbe1, 'R', 1), gnd()); L(s, P(q1, 'R', 2), gnd());
rp2 = B(s, 'R', 'R_P2 1k', 560, 120, 'down', 'R', '1e3');
L(s, P(p5, 'R', 1), P(rp2, 'L', 1)); L(s, P(q1, 'R', 1), P(rp2, 'R', 1));
rb = B(s, 'R', 'R_B 2k2', 640, 200, 'right', 'R', '2.2e3');
L(s, P(rp2, 'R', 1), P(rb, 'L', 1));
q2 = B(s, 'NPN', 'Q2 BC547', 730, 200, 'right');
rbe2 = B(s, 'R', 'R_BE2 10k', 690, 260, 'down', 'R', '10e3');
L(s, P(rb, 'R', 1), P(q2, 'L', 1)); L(s, P(rb, 'R', 1), P(rbe2, 'L', 1));
L(s, P(rbe2, 'R', 1), gnd()); L(s, P(q2, 'R', 2), gnd());

% Gate do IRF9530: R_C ate o coletor de Q2, R_GS e zener ate E
rc = B(s, 'R', 'R_C 1k2', 820, 170, 'down', 'R', '1.2e3');
L(s, P(q2, 'R', 1), P(rc, 'R', 1)); L(s, P(rc, 'L', 1), P(pG, 'R', 1));
rgs = B(s, 'R', 'R_GS 1k5', 880, 80, 'down', 'R', '1.5e3');
dz = B(s, 'D', 'zener 15 V', 940, 80, 'up', 'ZenerEnable', 'true', 'BV', '15', 'Rz', '1', 'Vf', '0.7', 'Ron', '0.5');
L(s, P(pE, 'R', 1), P(rgs, 'L', 1)); L(s, P(rgs, 'R', 1), P(pG, 'R', 1));
L(s, P(dz, 'R', 1), P(pE, 'R', 1)); L(s, P(dz, 'L', 1), P(pG, 'R', 1));

% Medidas: pino 6, coletor de Q2, VGS (gate - E)
v6 = B(s, 'VS', 'V pino 6', 400, 420, 'down'); L(s, P(v6, 'L', 1), P(rp, 'R', 1)); L(s, P(v6, 'R', 2), gnd());
vc = B(s, 'VS', 'V coletor Q2', 760, 420, 'down'); L(s, P(vc, 'L', 1), P(q2, 'R', 1)); L(s, P(vc, 'R', 2), gnd());
vg = B(s, 'VS', 'VGS', 960, 260, 'down'); L(s, P(vg, 'L', 1), P(pG, 'R', 1)); L(s, P(vg, 'R', 2), P(pE, 'R', 1));
medidas(s, {{v6, 'V'}, {vc, 'V'}, {vg, 'V'}}, 1060, 380);
end

% ---- Bloco 3: potencia ------------------------------------------------------
function monta_potencia(s)
pE = CP(s, 'E', 40, 60, 'Left'); pG = CP(s, 'GATE', 40, 160, 'Left'); pV = CP(s, 'Vo', 800, 100, 'Right');
pT = CP(s, 'terra de potencia', 800, 300, 'Right');
gnd = @() P(pT, 'R', 1);

% Barramento de entrada: 470 uF eletrolitico + 1 uF, colados no source do MOSFET e nos anodos do diodo
cb1 = B(s, 'C', 'C 470 uF', 70, 230, 'down', 'c', '470e-6', 'r', '0.1');
cb2 = B(s, 'C', 'C 1 uF (entrada)', 170, 230, 'down', 'c', '1e-6');
for h = [cb1 cb2], L(s, P(pE, 'R', 1), P(h, 'L', 1)); L(s, P(h, 'R', 1), gnd()); end
m = B(s, 'PMOS', 'IRF9530', 160, 100, 'right', 'Rds', '0.3', 'Id', '-7', 'Vgs', '-10', 'Vth', '-3', ...
    'C_iss', '760', 'C_rss', '140');
L(s, P(pE, 'R', 1), P(m, 'R', 1)); L(s, P(pG, 'R', 1), P(m, 'L', 1));
d = B(s, 'D', 'FCH20A20 (roda livre)', 240, 200, 'up', 'Vf', '0.55', 'Ron', '0.03', 'Goff', '1e-8');
is = B(s, 'IS', 'sensor iL (shunt)', 320, 140, 'right');
ind = B(s, 'L', 'L 17,71 mH', 420, 140, 'right', 'l', 'L_ind', 'r', 'r_ind', 'g', '0');
L(s, P(m, 'R', 2), P(d, 'R', 1)); L(s, P(m, 'R', 2), P(is, 'L', 1));
L(s, P(d, 'L', 1), gnd());
L(s, P(is, 'R', 2), P(ind, 'L', 1));
c1 = B(s, 'C', 'C 4,7 uF', 520, 200, 'down', 'c', 'C_out1');
c2 = B(s, 'C', 'C 1 uF', 580, 200, 'down', 'c', 'C_out2');
rr = B(s, 'R', 'R47 46,6 ohm', 640, 200, 'down', 'R', 'R_pot');
for h = [c1 c2 rr]
    L(s, P(ind, 'R', 1), P(h, 'L', 1)); L(s, P(h, 'R', 1), gnd());
end
L(s, P(ind, 'R', 1), P(pV, 'R', 1));

% Medidas: no de chaveamento, iL, Vo
vs = B(s, 'VS', 'V no SW', 300, 380, 'down'); L(s, P(vs, 'L', 1), P(m, 'R', 2)); L(s, P(vs, 'R', 2), gnd());
vo = B(s, 'VS', 'V saida', 760, 380, 'down'); L(s, P(vo, 'L', 1), P(ind, 'R', 1)); L(s, P(vo, 'R', 2), gnd());
medidas(s, {{vs, 'V'}, {is, 'A'}, {vo, 'V'}}, 880, 300);
nota(s, 40, 480, sprintf([ ...
    'IRF9530: canal P no lado alto (source em E). FCH20A20: Schottky, anodos (pinos 1 e 3) no terra e catodo (pino 2) no no SW.\n' ...
    '470 uF + 1 uF: entre E e o terra, perto do MOSFET e do diodo. O sensor iL fica onde vai o shunt do bloco 3d.\n' ...
    'A porta "terra de potencia" e o negativo do C de saida: o ponto unico onde chega o fio do terra de sinal.']));
end

% ---- Bloco 4a: divisor de tensao (fica perto do C de saida) ----------------
function monta_divisor(s)
pV = CP(s, 'Vo', 40, 100, 'Left'); pD = CP(s, 'Vdiv', 400, 100, 'Right');
pT = CP(s, 'terra de potencia', 400, 260, 'Right');
ra = B(s, 'R', 'R1a 10k', 120, 100, 'right', 'R', '10e3');
rb = B(s, 'R', 'R1b 1k', 220, 100, 'right', 'R', '1e3');
r2 = B(s, 'R', 'R2 1k', 300, 180, 'down', 'R', '1e3');
L(s, P(pV, 'R', 1), P(ra, 'L', 1)); L(s, P(ra, 'R', 1), P(rb, 'L', 1));
L(s, P(rb, 'R', 1), P(r2, 'L', 1)); L(s, P(rb, 'R', 1), P(pD, 'R', 1));
L(s, P(r2, 'R', 1), P(pT, 'R', 1));
nota(s, 40, 320, sprintf([ ...
    'Divisor 1/12: R1 = 10k + 1k em serie, R2 = 1k. Vo de 0 a 30 V vira 0 a 2,5 V.\n' ...
    'Montar perto do C de saida: a ponta de cima de R1 no + do C e o R2 no - do C (terra de potencia).\n' ...
    'O ponto medio (Vdiv) vai ao Ra 100k do subtrator; o fio do terra de potencia vai ao Ri do subtrator.']));
end

% ---- Bloco 4: CCS no LM324 -------------------------------------------------
function monta_ccs(s)
pV = CP(s, 'Vdiv', 200, 100, 'Left'); p3 = CP(s, '3V3', 40, 400, 'Left'); pA = CP(s, 'PA1', 1300, 260, 'Right');
pU = CP(s, '5V USB', 40, 560, 'Left'); pS = CP(s, 'terra de sinal', 40, 640, 'Left');
pT = CP(s, 'terra de potencia', 40, 300, 'Left');
gnd = @() P(pS, 'R', 1);    % terra de sinal (GND do Black Pill)

% Alimentacao do LM324: pino 4 no 5V do Black Pill, pino 11 no terra de sinal, 100 nF colado
cl = B(s, 'C', 'C 100 nF (pinos 4-11)', 120, 600, 'down', 'c', '100e-9');
rl = B(s, 'R', 'consumo LM324 1 mA', 300, 600, 'down', 'R', '5e3');
for h = [cl rl], L(s, P(pU, 'R', 1), P(h, 'L', 1)); L(s, P(h, 'R', 1), gnd()); end
amp = {'A', '1e5', 'Rin', '1e9', 'Rout', '100', 'Vmin', '0.02', 'Vmax', '3.5'};   % LM324 em 5 V

% Entrada: ponto medio do divisor (bloco 4a)

% Subtrator (ampop A, pinos 1-2-3)
sa = B(s, 'R', 'Ra 100k', 300, 100, 'right', 'R', '100e3');
sb = B(s, 'R', 'Rb 100k', 350, 170, 'down', 'R', '100e3');
si1 = B(s, 'R', 'Ri 100k', 300, 300, 'right', 'R', '100e3');
si2 = B(s, 'R', 'Ri 820', 360, 300, 'right', 'R', '820');
si3 = B(s, 'R', 'Ri 82', 420, 300, 'right', 'R', '82');
sf = B(s, 'R', 'Rf 100k', 500, 230, 'right', 'R', '100e3');
aa = B(s, 'AMP', 'LM324 A (subtrator)', 500, 120, 'right', amp{:});
L(s, P(pV, 'R', 1), P(sa, 'L', 1)); L(s, P(sa, 'R', 1), P(aa, 'L', 1)); L(s, P(sa, 'R', 1), P(sb, 'L', 1));
L(s, P(sb, 'R', 1), gnd());
L(s, P(pT, 'R', 1), P(si1, 'L', 1));                 % fio do terra de potencia (negativo do C)
L(s, P(si1, 'R', 1), P(si2, 'L', 1)); L(s, P(si2, 'R', 1), P(si3, 'L', 1));
L(s, P(si3, 'R', 1), P(aa, 'L', 2)); L(s, P(si3, 'R', 1), P(sf, 'L', 1)); L(s, P(sf, 'R', 1), P(aa, 'R', 1));

% Sallen-Key (ampop B, pinos 5-6-7): 1k5, 1k5, C1 220n na realimentacao, C2 22n ao terra
k1 = B(s, 'R', 'R 1k5 (1)', 620, 120, 'right', 'R', '1.5e3');
k2 = B(s, 'R', 'R 1k5 (2)', 700, 120, 'right', 'R', '1.5e3');
kc1 = B(s, 'C', 'C1 220 nF', 700, 40, 'right', 'c', '220e-9');
kc2 = B(s, 'C', 'C2 22 nF', 750, 190, 'down', 'c', '22e-9');
ab = B(s, 'AMP', 'LM324 B (Sallen-Key)', 820, 130, 'right', amp{:});
L(s, P(aa, 'R', 1), P(k1, 'L', 1)); L(s, P(k1, 'R', 1), P(k2, 'L', 1)); L(s, P(k1, 'R', 1), P(kc1, 'L', 1));
L(s, P(k2, 'R', 1), P(ab, 'L', 1)); L(s, P(k2, 'R', 1), P(kc2, 'L', 1)); L(s, P(kc2, 'R', 1), gnd());
L(s, P(ab, 'R', 1), P(ab, 'L', 2)); L(s, P(kc1, 'R', 1), P(ab, 'R', 1));

% Offset (ampop C, pinos 8-9-10): 0,389 V tirados do 3,3 V
oa = B(s, 'R', 'Ra 10k', 940, 130, 'right', 'R', '10e3');
ox1 = B(s, 'R', 'Rx 6k8', 110, 400, 'right', 'R', '6.8e3');
ox2 = B(s, 'R', 'Rx 680', 180, 400, 'right', 'R', '680');
oy = B(s, 'R', 'Ry 1k', 230, 470, 'down', 'R', '1e3');
ob1 = B(s, 'R', 'Rb 8k2', 860, 400, 'right', 'R', '8.2e3');
ob2 = B(s, 'R', 'Rb 820', 930, 400, 'right', 'R', '820');
oi = B(s, 'R', 'Ri 10k', 1000, 330, 'down', 'R', '10e3');
of = B(s, 'R', 'Rf 10k', 1100, 330, 'right', 'R', '10e3');
ac = B(s, 'AMP', 'LM324 C (offset)', 1100, 220, 'right', amp{:});
L(s, P(ab, 'R', 1), P(oa, 'L', 1)); L(s, P(oa, 'R', 1), P(ac, 'L', 1));
L(s, P(p3, 'R', 1), P(ox1, 'L', 1)); L(s, P(ox1, 'R', 1), P(ox2, 'L', 1)); L(s, P(ox2, 'R', 1), P(oy, 'L', 1));
L(s, P(oy, 'R', 1), gnd());
L(s, P(ox2, 'R', 1), P(ob1, 'L', 1)); L(s, P(ob1, 'R', 1), P(ob2, 'L', 1)); L(s, P(ob2, 'R', 1), P(ac, 'L', 1));
L(s, P(ac, 'L', 2), P(oi, 'L', 1)); L(s, P(oi, 'R', 1), gnd());
L(s, P(ac, 'L', 2), P(of, 'L', 1)); L(s, P(of, 'R', 1), P(ac, 'R', 1));
r100 = B(s, 'R', '100 ohm para o PA1', 1220, 260, 'right', 'R', '100');
L(s, P(ac, 'R', 1), P(r100, 'L', 1)); L(s, P(r100, 'R', 1), P(pA, 'R', 1));

% Medidas: divisor, subtrator, Sallen-Key, offset, PA1
nos = {P(pV, 'R', 1), P(aa, 'R', 1), P(ab, 'R', 1), P(ac, 'R', 1), P(pA, 'R', 1)};
sens = cell(1, 5);
for i = 1:5
    v = B(s, 'VS', sprintf('V medida %d', i), 200 + 200*i, 640, 'down');
    L(s, P(v, 'L', 1), nos{i}); L(s, P(v, 'R', 2), gnd());
    sens{i} = {v, 'V'};
end
medidas(s, sens, 1400, 560);
nota(s, 40, 760, sprintf([ ...
    'CCS com os valores do catalogo (roteiro, bloco 4). LM324 em 5 V: saida limitada a 0,02-3,5 V.\n' ...
    'Medidas na ordem: 1 ponto medio do divisor, 2 pino 1, 3 pino 7, 4 pino 8, 5 PA1.\n' ...
    'Ampop D (pinos 12-14) nao usado: 12 no terra de sinal e 13 ligado ao 14.\n' ...
    'Terras: so o Ri do subtrator vai no terra de potencia; todo o resto vai no terra de sinal.']));
end
