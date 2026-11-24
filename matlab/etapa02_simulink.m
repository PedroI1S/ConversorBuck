%% Etapa 2b - Conversor Buck no Simulink/Simscape (verificacao em simulador de circuitos)
% Projeto de Controle Automatico - UTFPR - Grupo com o Sinal 1
%
% O enunciado pede avaliar o conversor tambem em um simulador de circuitos.
% Este script monta por codigo o modelo etapa02_buck_simscape.slx (Simscape,
% biblioteca Foundation), roda:
%   1) os mesmos casos de regime da Etapa 2 com chave e diodo ideais, para
%      validar contra o modelo em espaco de estados do MATLAB;
%   2) os mesmos casos com as perdas das pecas reais (IRF9530, FCH20A20 e fio
%      do indutor), para saber o que esperar na bancada;
%   3) o Sinal 1 em malha aberta (d[k] = vref[k]/E), ideal e com perdas.
%
% Circuito (chave no lado alto, como no acionamento com o IRF9530):
%   E(+) --chave-- no_sw --sensor de i_L-- L (com r_L) -- vo -- C || R -- terra
%   diodo: anodo no terra, catodo em no_sw
% PWM: dente de serra de 0 a 1 em Ts comparado com d; chave fechada
% enquanto serra < d (pulso no inicio do periodo, como no CA08).

clear; clc; close all;

%% 1) Monta o modelo (antes dos parametros: o teste de compilacao usa
% valores provisorios no workspace base)
aqui = fileparts(mfilename('fullpath'));
if isempty(aqui), aqui = pwd; end
addpath(aqui);
mdl = 'etapa02_buck_simscape';

monta_modelo(mdl, aqui);

%% 2) Parametros
fs  = 10e3;  Ts = 1/fs;           % chaveamento = amostragem
N   = 400;                        % amostras por ciclo do Sinal 1
M   = 100;   h  = Ts/M;           % passo maximo do solver (1 us)

Lval = 17.71e-3;                  % [H] indutor do grupo (medido)
Cval = 4.7e-6 + 1e-6;             % [F] 4,7 uF + 1 uF

% Parametros de cada versao do circuito
ideal = struct('nome', 'ideal', 'Rload', 42.9, 'RL', 0, ...
               'Ron', 1e-3, 'Vf', 1e-6, 'Rd', 1e-3);   % Vf > 0 exigido pelo bloco
real_ = struct('nome', 'com perdas', ...
               'Rload', 1/(1/46.6 + 7/3900), ...   % 46,6 Ohm || 7 x 3k9 = 43,0 Ohm
               'RL', 0.07, ...                      % fio do indutor (medido)
               'Ron', 0.3, ...                      % IRF9530: RDS(on) maximo
               'Vf', 0.55, 'Rd', 0.03);             % FCH20A20 com ~0,4 A (estimado)


%% 3) Casos de regime: ideal (validacao) e com perdas
casos = [24 0.50; 24 0.25; 24 0.75; 30 0.20; 30 0.60; 18 0.50];   % [E d]
nc    = size(casos, 1);
Tsim  = 30e-3;                    % 300 periodos, como na Etapa 2
versoes = {ideal, real_};
res = zeros(nc, 6, 2);            % [Vo IL ILmin DiL/IL DVo/Vo erroVo_vs_MATLAB]
for v = 1:2
    p = versoes{v};
    for i = 1:nc
        E = casos(i, 1); d = casos(i, 2);
        o = roda(mdl, p, Lval, Cval, Ts, h, E, [0 d], Tsim);
        fim = o.t >= Tsim - 5*Ts;                    % ultimos 5 periodos
        iL = o.iL(fim); vo = o.vo(fim);
        res(i, 1:5, v) = [mean(vo), mean(iL), min(iL), ...
            100*(max(iL) - min(iL))/mean(iL), 100*(max(vo) - min(vo))/mean(vo)];
        % Referencia: mesmo caso no modelo de espaco de estados (Etapa 2)
        [Ad, Bd] = discretiza(Lval, Cval, p.Rload, h);
        us = repmat(E*((0:M-1)/M < d), 1, round(Tsim/Ts));
        x  = simula(Ad, Bd, us);
        res(i, 6, v) = mean(vo) - mean(x(2, end - 5*M + 1:end));
        if v == 1 && i == 1
            graf_reg.t = o.t(fim) - o.t(find(fim, 1)); graf_reg.iL = iL; graf_reg.vo = vo;
            tx = (0:5*M - 1)*h; graf_reg.tx = tx;
            graf_reg.iLx = x(1, end - 5*M + 1:end); graf_reg.vox = x(2, end - 5*M + 1:end);
        end
        if v == 2 && i == 1
            graf_reg.iLr = iL; graf_reg.vor = vo; graf_reg.tr = o.t(fim) - o.t(find(fim, 1));
        end
    end
end

%% 4) Sinal 1 em malha aberta: d[k] = vref[k]/E, E = 24 V
E  = 24;
nciclos = 3;
k  = 0:nciclos*N - 1;
dk = referencia_sinal1(k)/E;
Tsim1 = nciclos*N*Ts;
sinal = struct();
for v = 1:2
    o = roda(mdl, versoes{v}, Lval, Cval, Ts, h, E, [k(:)*Ts dk(:)], Tsim1);
    tu = (0:round(Tsim1/h) - 1)*h;               % grade uniforme de 1 us
    vo = interp1(o.t, o.vo, tu, 'linear', 'extrap');
    sinal(v).t = tu; sinal(v).vo = vo;
end
% Modelo medio do MATLAB (Etapa 2), mesmo R ideal
[Ad, Bd] = discretiza(Lval, Cval, ideal.Rload, h);
u  = repelem(referencia_sinal1(k), M);
x  = simula(Ad, Bd, u);
vmed = x(2, :);
vid  = referencia_sinal1(tu/Ts);                 % referencia continua (ideal)
ult  = tu >= (nciclos - 1)*N*Ts;                 % ultimo ciclo
Lf   = round(Ts/h);                              % media movel de um periodo
for v = 1:2
    vf = movmean(sinal(v).vo, Lf);               % tira o ripple para comparar
    e  = vf(ult) - vid(ult);
    sinal(v).erms = sqrt(mean(e.^2)); sinal(v).emax = max(abs(e));
    sinal(v).vpk  = max(vf(ult));     sinal(v).vmin = min(vf(ult));
    sinal(v).dif_medio = sqrt(mean((vf(ult) - vmed(ult)).^2));
end

%% 5) Resultados numericos
fprintf('Simscape: L = %.2f mH, C = %.1f uF, fs = %g kHz\n', Lval*1e3, Cval*1e6, fs/1e3);
for v = 1:2
    p = versoes{v};
    fprintf('\n Regime, %s (R = %.2f Ohm, rL = %g Ohm, Ron = %g Ohm, Vf = %g V)\n', ...
        p.nome, p.Rload, p.RL, p.Ron, p.Vf);
    fprintf('   E [V]   d    Vo [V]  IL [A]  ILmin [A]  DiL/IL [%%]  DVo/Vo [%%]  Vo - Vo(MATLAB ideal) [V]\n');
    for i = 1:nc
        fprintf('   %4g  %.2f  %6.3f  %6.3f  %8.3f  %9.1f  %10.2f  %12.3f\n', casos(i, :), res(i, :, v));
    end
    fprintf('   CCM: %d | ripple de corrente < 50 %%: %d | ripple de tensao < 2 %%: %d\n', ...
        all(res(:, 3, v) > 0), all(res(:, 4, v) < 50), all(res(:, 5, v) < 2));
end
fprintf('\n Sinal 1 em malha aberta (E = 24 V, ultimo ciclo, Vo filtrado em um periodo)\n');
fprintf('   versao       erro RMS [V]  erro max [V]  Vo max [V]  Vo min [V]  RMS vs modelo medio [V]\n');
for v = 1:2
    fprintf('   %-11s  %10.3f  %11.3f  %10.2f  %10.2f  %14.3f\n', versoes{v}.nome, ...
        sinal(v).erms, sinal(v).emax, sinal(v).vpk, sinal(v).vmin, sinal(v).dif_medio);
end

%% 6) Graficos
pasta = fullfile(aqui, 'figuras');
if ~exist(pasta, 'dir'), mkdir(pasta); end

fig1 = figure('Name', 'Etapa 2b - Regime no Simscape', 'Color', 'w', 'Position', [80 80 950 600]);
if exist('theme', 'file'), theme(fig1, 'light'); end
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
plot(graf_reg.t*1e3, graf_reg.iL*1e3, 'LineWidth', 1.3); hold on; grid on;
plot(graf_reg.tx*1e3, graf_reg.iLx*1e3, 'k--', 'LineWidth', 1);
plot(graf_reg.tr*1e3, graf_reg.iLr*1e3, 'LineWidth', 1.3);
xlabel('Tempo [ms]'); ylabel('i_L [mA]');
title('Corrente no indutor (E = 24 V, d = 0,5)');
legend('Simscape ideal', 'MATLAB (espaco de estados)', 'Simscape com perdas', 'Location', 'eastoutside');
nexttile;
plot(graf_reg.t*1e3, graf_reg.vo, 'LineWidth', 1.3); hold on; grid on;
plot(graf_reg.tx*1e3, graf_reg.vox, 'k--', 'LineWidth', 1);
plot(graf_reg.tr*1e3, graf_reg.vor, 'LineWidth', 1.3);
xlabel('Tempo [ms]'); ylabel('v_o [V]');
title('Tensao de saida (E = 24 V, d = 0,5)');
legend('Simscape ideal', 'MATLAB (espaco de estados)', 'Simscape com perdas', 'Location', 'eastoutside');
exportgraphics(fig1, fullfile(pasta, 'etapa02b_regime_simscape.png'), 'Resolution', 150);
exportgraphics(fig1, fullfile(pasta, 'etapa02b_regime_simscape.pdf'), 'ContentType', 'vector');

fig2 = figure('Name', 'Etapa 2b - Sinal 1 no Simscape', 'Color', 'w', 'Position', [100 100 1100 650]);
if exist('theme', 'file'), theme(fig2, 'light'); end
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ic = find(ult); ic = ic(1:5:end);                % 1 ponto a cada 5 us (figura leve)
tc = (tu(ic) - (nciclos - 1)*N*Ts)*1e3;
nexttile;
plot(tc, sinal(1).vo(ic), 'LineWidth', 1); hold on; grid on;
plot(tc, sinal(2).vo(ic), 'LineWidth', 1);
plot(tc, vmed(ic), 'k:', 'LineWidth', 1.2);
plot(tc, vid(ic), 'k--', 'LineWidth', 1);
ylim([0 24]); yticks(0:6:24);
xlabel('Tempo [ms]'); ylabel('v_o [V]');
title('Sinal 1 em malha aberta no Simscape (E = 24 V, d[k] = v_{ref}[k]/E, um ciclo em regime)');
legend('Simscape ideal', 'Simscape com perdas', 'MATLAB (modelo medio)', 'referencia', ...
    'Location', 'northeast', 'NumColumns', 2);
nexttile;
jan = ult & tu >= (nciclos - 1)*N*Ts + 4.5e-3 & tu <= (nciclos - 1)*N*Ts + 9e-3;
ij = find(jan); ij = ij(1:2:end);
tj = (tu(ij) - (nciclos - 1)*N*Ts)*1e3;
plot(tj, sinal(1).vo(ij), 'LineWidth', 1.1); hold on; grid on;
plot(tj, sinal(2).vo(ij), 'LineWidth', 1.1);
plot(tj, vmed(ij), 'k:', 'LineWidth', 1.2);
plot(tj, vid(ij), 'k--', 'LineWidth', 1);
xlabel('Tempo [ms]'); ylabel('v_o [V]');
title('Detalhe da rampa 12 V \rightarrow 18 V');
legend('Simscape ideal', 'Simscape com perdas', 'MATLAB (modelo medio)', 'referencia', 'Location', 'southeast');
exportgraphics(fig2, fullfile(pasta, 'etapa02b_sinal1_simscape.png'), 'Resolution', 150);
exportgraphics(fig2, fullfile(pasta, 'etapa02b_sinal1_simscape.pdf'), 'ContentType', 'vector');

%% Funcoes locais
function o = roda(mdl, p, Lval, Cval, Ts, h, E, dsig, Tsim)
% Roda o modelo com os parametros da versao p e o sinal de razao ciclica dsig
% ([t d], mantido constante entre amostras).
in = Simulink.SimulationInput(mdl);
vars = {'E', E; 'Ts', Ts; 'Lval', Lval; 'Cval', Cval; 'RL', p.RL; ...
        'Rload', p.Rload; 'Ron', p.Ron; 'Vf', p.Vf; 'Rd', p.Rd; 'dsig', dsig};
for j = 1:size(vars, 1)
    in = in.setVariable(vars{j, 1}, vars{j, 2});
end
in = in.setModelParameter('StopTime', num2str(Tsim), 'MaxStep', num2str(h));
out = sim(in);
o.t  = out.iL.Time;
o.iL = squeeze(out.iL.Data);
o.vo = squeeze(out.vo.Data);
end

function monta_modelo(mdl, pasta)
% Monta o modelo do Buck com blocos da Simscape Foundation Library.
% Como a API nao informa o nome das portas Simscape, testa as combinacoes
% possiveis da porta de controle da chave e da saida dos sensores e fica
% com a que compila.
load_system('fl_lib'); load_system('nesl_utility'); load_system('simulink');
ok = false;
for cs = 1:3            % qual das 3 portas da chave e o controle
    for ss = 1:2        % qual porta da direita dos sensores e a saida PS
        if bdIsLoaded(mdl), close_system(mdl, 0); end
        if exist(fullfile(pasta, [mdl '.slx']), 'file'), delete(fullfile(pasta, [mdl '.slx'])); end
        try
            constroi(mdl, cs, ss);   % add_line recusa ligar dominios diferentes
            assignin('base', 'E', 24); assignin('base', 'Ts', 1e-4); assignin('base', 'Lval', 1e-2);
            assignin('base', 'Cval', 1e-6); assignin('base', 'RL', 0); assignin('base', 'Rload', 40);
            assignin('base', 'Ron', 1e-3); assignin('base', 'Vf', 1e-6); assignin('base', 'Rd', 1e-3);
            assignin('base', 'dsig', [0 0.5]);
            set_param(mdl, 'SimulationCommand', 'update');
            ok = true;
        catch err
            fprintf('  tentativa chave=%d sensor=%d: %s\n', cs, ss, strtok(err.message, newline));
            if ~contains(err.message, 'connection rules')
                for c = 1:numel(err.cause), fprintf('    causa: %s\n', err.cause{c}.message); end
            end
        end
        if ok, break; end
    end
    if ok, break; end
end
if ~ok, error('Nao foi possivel ligar o modelo Simscape.'); end
save_system(mdl, fullfile(pasta, [mdl '.slx']));
fprintf('Modelo salvo em %s.slx (controle da chave: porta %d, sensores: porta %d)\n', mdl, cs, ss);
end

function constroi(mdl, cs, ss)
new_system(mdl); open_system(mdl, 'loadonly');
el = 'fl_lib/Electrical/';
b = @(src, nome, pos) add_block(src, [mdl '/' nome], 'Position', pos);
src  = b([el 'Electrical Sources/DC Voltage Source'], 'E', [60 120 100 160]);
sw   = b([el 'Electrical Elements/Switch'], 'Chave IRF9530', [160 60 200 100]);
dio  = b([el 'Electrical Elements/Diode'], 'Diodo FCH20A20', [240 140 280 180]);
isen = b([el 'Electrical Sensors/Current Sensor'], 'Sensor iL', [300 60 340 100]);
ind  = b([el 'Electrical Elements/Inductor'], 'L', [380 60 420 100]);
cap  = b([el 'Electrical Elements/Capacitor'], 'C', [470 140 510 180]);
res  = b([el 'Electrical Elements/Resistor'], 'R carga', [550 140 590 180]);
vsen = b([el 'Electrical Sensors/Voltage Sensor'], 'Sensor vo', [630 140 670 180]);
gnd  = b([el 'Electrical Elements/Electrical Reference'], 'Terra', [300 240 340 270]);
slv  = b(sprintf('nesl_utility/Solver\nConfiguration'), 'Solver', [140 230 180 260]);
spsc = b(sprintf('nesl_utility/Simulink-PS\nConverter'), 'S-PS', [100 0 130 30]);
psi  = b(sprintf('nesl_utility/PS-Simulink\nConverter'), 'PS-S iL', [360 0 390 30]);
psv  = b(sprintf('nesl_utility/PS-Simulink\nConverter'), 'PS-S vo', [710 140 740 170]);

set_param(src, 'v0', 'E');
set_param(sw, 'R_closed', 'Ron', 'G_open', '1e-9', 'Threshold', '0.5');
set_param(dio, 'Vf', 'Vf', 'Ron', 'Rd', 'Goff', '1e-9');
set_param(ind, 'l', 'Lval', 'r', 'RL', 'g', '0');
set_param(cap, 'c', 'Cval', 'r', '0', 'g', '0');
set_param(res, 'R', 'Rload');
set_param(spsc, 'FilteringAndDerivatives', 'zero');
set_param(psi, 'Unit', 'A'); set_param(psv, 'Unit', 'V');

% Portas: chave (1 de controle + 2 eletricas)
P  = @(h) get_param(h, 'PortHandles');
ps = P(sw); swp = [ps.LConn ps.RConn];
ctrl = swp(cs); swe = swp(setdiff(1:3, cs));
pis = P(isen); pvs = P(vsen);
iout = pis.RConn(ss); ineg = pis.RConn(3 - ss); ipos = pis.LConn(1);
vout = pvs.RConn(ss); vneg = pvs.RConn(3 - ss); vpos = pvs.LConn(1);
pe = P(src); pd = P(dio); pl = P(ind); pc = P(cap); pr = P(res); pg = P(gnd);
psl = P(slv); pspsc = P(spsc); ppsi = P(psi); ppsv = P(psv);

L = @(a, c) add_line(mdl, a, c, 'autorouting', 'on');
% No E: + da fonte -> chave
L(pe.LConn(1), swe(1));
% No de chaveamento: chave -> catodo do diodo -> + do sensor de corrente
L(swe(2), pd.RConn(1)); L(swe(2), ipos);
% Sensor de corrente -> indutor
L(ineg, pl.LConn(1));
% Saida vo: indutor -> C, R, + do sensor de tensao
L(pl.RConn(1), pc.LConn(1)); L(pl.RConn(1), pr.LConn(1)); L(pl.RConn(1), vpos);
% Terra: - da fonte, anodo do diodo, C, R, - do sensor de tensao, solver
L(pe.RConn(1), pg.LConn(1)); L(pd.LConn(1), pg.LConn(1)); L(pc.RConn(1), pg.LConn(1));
L(pr.RConn(1), pg.LConn(1)); L(vneg, pg.LConn(1)); L(psl.RConn(1), pg.LConn(1));
% Sinais fisicos
L(pspsc.RConn(1), ctrl); L(iout, ppsi.LConn(1)); L(vout, ppsv.LConn(1));

% PWM: serra 0..1 em Ts comparada com d[k]
sl = 'simulink/';
serra = add_block([sl 'Sources/Repeating Sequence'], [mdl '/Serra'], 'Position', [-260 -60 -220 -20], ...
    'rep_seq_t', '[0 Ts]', 'rep_seq_y', '[0 1]');
dk = add_block([sl 'Sources/From Workspace'], [mdl '/d[k]'], 'Position', [-280 10 -200 40], ...
    'VariableName', 'dsig', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
cmp = add_block([sl 'Logic and Bit Operations/Relational Operator'], [mdl '/serra < d'], ...
    'Position', [-150 -30 -110 10], 'Operator', '<');
cnv = add_block([sl 'Signal Attributes/Data Type Conversion'], [mdl '/double'], ...
    'Position', [-60 -30 -10 10], 'OutDataTypeStr', 'double');
add_line(mdl, [get_param(serra, 'Name') '/1'], 'serra < d/1', 'autorouting', 'on');
add_line(mdl, 'd[k]/1', 'serra < d/2', 'autorouting', 'on');
add_line(mdl, 'serra < d/1', 'double/1', 'autorouting', 'on');
L(P(cnv).Outport(1), pspsc.Inport(1));

% Saidas para o workspace
twi = add_block([sl 'Sinks/To Workspace'], [mdl '/iL'], 'Position', [440 0 500 30], ...
    'VariableName', 'iL', 'SaveFormat', 'Timeseries');
twv = add_block([sl 'Sinks/To Workspace'], [mdl '/vo'], 'Position', [780 140 840 170], ...
    'VariableName', 'vo', 'SaveFormat', 'Timeseries');
L(ppsi.Outport(1), P(twi).Inport(1)); L(ppsv.Outport(1), P(twv).Inport(1));

set_param(mdl, 'Solver', 'ode23t', 'RelTol', '1e-4', 'MaxStep', '1e-6', ...
    'ReturnWorkspaceOutputs', 'on', 'SignalLogging', 'off');
end

function [Ad, Bd] = discretiza(L, C, R, h)
% Filtro LC + carga R em espaco de estados, x = [iL; vC], ZOH exato.
A  = [0 -1/L; 1/C -1/(R*C)];
B  = [1/L; 0];
Ad = expm(A*h);
Bd = A\((Ad - eye(2))*B);
end

function x = simula(Ad, Bd, u)
x = zeros(2, numel(u));
for n = 1:numel(u) - 1
    x(:, n + 1) = Ad*x(:, n) + Bd*u(n);
end
end
