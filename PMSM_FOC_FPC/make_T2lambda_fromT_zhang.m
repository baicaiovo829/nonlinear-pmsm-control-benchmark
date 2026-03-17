%% make_T2lambda.m  —— 一键生成 MTPA 的 T->lambda 查表
% 使用说明：
% 1) 直接运行本脚本即可。
% 2) 脚本会优先使用工作区中的变量：imd(1xNid), imq(1xNiQ), Psid(Nid x NiQ), Psiq(Nid x NiQ)
%    若不存在，则尝试从当前目录加载 motor_tables.mat（需包含上述变量）。
% 3) 生成文件：MTPA_T2lambda.mat（含 Tgrid, lambda_tbl, id_tbl, iq_tbl）
% 4) 自动绘图预览 λ(T)

%% 0) 数据准备：读取/加载 imd, imq, Psid, Psiq
needLoad = ~(exist('imd','var') && exist('imq','var') && exist('Psid','var') && exist('Psiq','var'));
if needLoad
    if isfile('motor_tables.mat')
        Sload = load('motor_tables.mat');
        fns = fieldnames(Sload);
        req = {'imd','imq','Psid','Psiq'};
        for k=1:numel(req)
            if ~ismember(req{k}, fns)
                error('motor_tables.mat 中缺少变量 "%s"。请提供 imd, imq, Psid, Psiq。', req{k});
            end
            assignin('base', req{k}, Sload.(req{k}));
        end
        imd  = Sload.imd;  %#ok<NODEF>
        imq  = Sload.imq;  %#ok<NODEF>
        Psid = Sload.Psid; %#ok<NODEF>
        Psiq = Sload.Psiq; %#ok<NODEF>
        fprintf('[INFO] 已从 motor_tables.mat 载入 imd/imq/Psid/Psiq。\n');
    else
        error(['未在工作区找到 imd/imq/Psid/Psiq，也未找到 motor_tables.mat。\n' ...
               '请先在工作区提供这些变量，或将它们打包到 motor_tables.mat（同目录）。']);
    end
end

%% 1) 自动配置参数（无需手动设置）
p         = 4;  % 极对数（默认 4，对很多电机都能先跑起来；需要可改）
IdGrid    = imd(:);                     % d轴电流网格（列向量）
IqGrid    = imq(:);                     % q轴电流网格（列向量）
PsiDTable = Psid;                       % size ~ [numel(IdGrid) x numel(IqGrid)] 或转置
PsiQTable = Psiq;

% 确保插值使用 {Iq, Id} 顺序，表尺寸为 [numel(Iq) x numel(Id)]
if ~isequal(size(PsiDTable), [numel(IqGrid), numel(IdGrid)])
    PsiDTable = PsiDTable.'; 
    PsiQTable = PsiQTable.';
end
F_PsiD = griddedInterpolant({IqGrid, IdGrid}, PsiDTable, 'linear', 'nearest');
F_PsiQ = griddedInterpolant({IqGrid, IdGrid}, PsiQTable, 'linear', 'nearest');

% 自动估算 Imax：取网格最大幅值
Imax_guess = max([abs(IdGrid(:)); abs(IqGrid(:))]);

% 自动估算 Tmax：在网格上直接用转矩真式扫一遍，取绝对值最大
[ID, IQ] = ndgrid(IdGrid, IqGrid);  % 注意：这里是 (Id, Iq) 网格
% 为了用插值器（Iq, Id）顺序，逐点取值
Te_max = 0;
for ii = 1:numel(IdGrid)
    for jj = 1:numel(IqGrid)
        id = IdGrid(ii); iq = IqGrid(jj);
        psi_d = F_PsiD(iq, id);
        psi_q = F_PsiQ(iq, id);
        Te = 1.5 * p * (psi_d * iq - psi_q * id);
        if abs(Te) > Te_max
            Te_max = abs(Te);
        end
    end
end
Tmax_guess = 0.98 * Te_max;  % 留一点裕度

% 其他扫描与求解参数（稳妥默认）
cfg = struct;
cfg.p      = p;
cfg.Imax   = Imax_guess;   % 峰值A
cfg.Tmax   = Tmax_guess;   % Nm
cfg.TN     = 80;           % T 采样点数
cfg.isN    = 240;          % is 分辨率
cfg.betaN  = 241;          % beta 分辨率（-90°~+90°）
cfg.dTtol  = 0.01 * cfg.Tmax; % 转矩容差，1% Tmax
cfg.mode   = 'psi';        % 使用磁链表

cfg.IdGrid    = IdGrid;
cfg.IqGrid    = IqGrid;
cfg.PsiDTable = PsiDTable;
cfg.PsiQTable = PsiQTable;

fprintf('[INFO] 自动设置：p=%d, Imax=%.3f A(peak), Tmax=%.3f Nm, TN=%d, isN=%d, betaN=%d\n',...
    cfg.p, cfg.Imax, cfg.Tmax, cfg.TN, cfg.isN, cfg.betaN);

%% 2) 生成 T->lambda 表（核心）
[Tgrid, lambda_tbl, id_tbl, iq_tbl] = local_gen_T2lambda(cfg);

%% 3) 保存与可视化
save('MTPA_T2lambda.mat','Tgrid','lambda_tbl','id_tbl','iq_tbl');
fprintf('[OK] 已保存：MTPA_T2lambda.mat（含 Tgrid, lambda_tbl, id_tbl, iq_tbl）\n');

figure('Name','MTPA 参考磁链 λ(T)','Color','w');
plot(Tgrid, lambda_tbl, 'LineWidth', 1.8); grid on;
xlabel('Torque T (Nm)'); ylabel('\lambda (Wb)'); title('MTPA: \lambda^* vs T');


%% ===== 本文件内的本地函数（无需关心，直接可用） =====
function [Tgrid, lambda_tbl, id_tbl, iq_tbl] = local_gen_T2lambda(cfg)
% 生成 MTPA 情况下的一维查表：T → λ（使用 Ψ 表或 L 表）
p      = cfg.p;
Imax   = cfg.Imax;
Tmax   = cfg.Tmax;
TN     = cfg.TN;
isN    = cfg.isN;
betaN  = cfg.betaN;
dTtol  = cfg.dTtol;
mode   = cfg.mode;

Tgrid  = linspace(-Tmax, Tmax, TN);     %转矩做表范围
isVec  = linspace(-Tmax, Imax, isN);
bVec   = linspace(-pi/2, pi/2, betaN);

lambda_tbl = nan(size(Tgrid));
id_tbl     = nan(size(Tgrid));
iq_tbl     = nan(size(Tgrid));

IdGrid = cfg.IdGrid(:);
IqGrid = cfg.IqGrid(:);

if strcmpi(mode, 'psi')
    PsiDTable = cfg.PsiDTable;
    PsiQTable = cfg.PsiQTable;
    if ~isequal(size(PsiDTable), [numel(IqGrid), numel(IdGrid)])
        PsiDTable = PsiDTable.'; 
        PsiQTable = PsiQTable.';
    end
    F_PsiD = griddedInterpolant({IqGrid, IdGrid}, PsiDTable, 'linear', 'nearest');
    F_PsiQ = griddedInterpolant({IqGrid, IdGrid}, PsiQTable, 'linear', 'nearest');
elseif strcmpi(mode, 'L')
    LdTable = cfg.LdTable;
    LqTable = cfg.LqTable;
    psi_f   = cfg.psi_f;
    if ~isequal(size(LdTable), [numel(IqGrid), numel(IdGrid)])
        LdTable = LdTable.'; 
        LqTable = LqTable.';
    end
    F_Ld = griddedInterpolant({IqGrid, IdGrid}, LdTable, 'linear', 'nearest');
    F_Lq = griddedInterpolant({IqGrid, IdGrid}, LqTable, 'linear', 'nearest');
else
    error('cfg.mode must be "psi" or "L".');
end

for k = 1:numel(Tgrid)
    Tk = Tgrid(k);
    bestJ  = inf;
    bestid = 0; bestiq = 0;

    for ii = 1:numel(isVec)
        is = isVec(ii);
        if is^2 > bestJ, break; end

        for jj = 1:numel(bVec)
            beta = bVec(jj);
            id   = is*cos(beta);
            iq   = is*sin(beta);

            if strcmpi(mode, 'psi')
                psi_d = F_PsiD(iq, id);
                psi_q = F_PsiQ(iq, id);
            else
                Ld = F_Ld(iq, id);
                Lq = F_Lq(iq, id);
                psi_d = psi_f + Ld*id;
                psi_q = Lq*iq;
            end

            Te = 1.5 * p * ( psi_d * iq - psi_q * id );

            if abs(Te - Tk) <= dTtol
                J = id^2 + iq^2;
                if J < bestJ
                    bestJ  = J;
                    bestid = id; bestiq = iq;
                end
            end
        end
    end

    id_tbl(k) = bestid;
    iq_tbl(k) = bestiq;

    if isfinite(bestJ)
        if strcmpi(mode, 'psi')
            psi_d = F_PsiD(bestiq, bestid);
            psi_q = F_PsiQ(bestiq, bestid);
        else
            Ld = F_Ld(bestiq, bestid);
            Lq = F_Lq(bestiq, bestid);
            psi_d = psi_f + Ld*bestid;
            psi_q = Lq*bestiq;
        end
        lambda_tbl(k) = hypot(psi_d, psi_q);
    else
        lambda_tbl(k) = NaN;
    end
end

% 修补缺失 + 平滑
firstValid = find(~isnan(lambda_tbl), 1, 'first');
lastValid  = find(~isnan(lambda_tbl), 1, 'last');
if isempty(firstValid)
    error('未找到有效 MTPA 点：检查 Imax/Tmax/dTtol 与 (IdGrid,IqGrid) 覆盖范围。');
end
lambda_tbl(1:firstValid-1) = lambda_tbl(firstValid);
lambda_tbl(lastValid+1:end) = lambda_tbl(lastValid);
lambda_tbl = smoothdata(lambda_tbl, 'movmean', max(3, round(numel(lambda_tbl)/30)));
end
function make_T2lambda_fromPsi()
% 一键：基于 Psid/Psiq & imd/imq 生成 MTPA 的 T->lambda 查表
% 需要的工作区变量（已按你的命名）：
%   imd (1xNid)   d轴电流网格（建议峰值A）
%   imq (1xNiQ)   q轴电流网格（建议峰值A）
%   Psid (Nid x NiQ 或 NiQ x Nid)   ψd 表
%   Psiq (Nid x NiQ 或 NiQ x Nid)   ψq 表
% 可选：p（极对数）。若未提供，默认 p=4 并提示。

%% 0) 读取数据 & 基本检查
req = {'imd','imq','Psid','Psiq'};
for k=1:numel(req)
    assert(evalin('base',sprintf('exist(''%s'',''var'')==1',req{k})), ...
        '缺少变量 %s（应在工作区）', req{k});
end
imd  = evalin('base','imd');   imq  = evalin('base','imq');
Psid = evalin('base','Psid');  Psiq = evalin('base','Psiq');

if evalin('base','exist(''p'',''var'')==1')
    p = evalin('base','p');       % 极对数
else
    p = 4; % 默认
    warning('未在工作区找到极对数 p，临时使用 p=4。');
end

IdGrid = imd(:);   IqGrid = imq(:);

% 构造 {Iq,Id} 顺序的插值器；若尺寸不匹配则转置一次
PsiDTable = Psid;  PsiQTable = Psiq;
if ~isequal(size(PsiDTable), [numel(IqGrid), numel(IdGrid)])
    PsiDTable = PsiDTable.'; 
    PsiQTable = PsiQTable.';
end
Fpsi_d = griddedInterpolant({IqGrid, IdGrid}, PsiDTable, 'linear','nearest');
Fpsi_q = griddedInterpolant({IqGrid, IdGrid}, PsiQTable, 'linear','nearest');

%% 1) 自动估算 Imax 与 Tmax（免填参数）
Imax = max([abs(IdGrid(:)); abs(IqGrid(:))]);   % 电流幅值上限（由网格给出）

% 粗扫网格估算最大可达转矩（用真公式）
Te_max = 0;
for ii = 1:numel(IdGrid)
    id = IdGrid(ii);
    for jj = 1:numel(IqGrid)
        iq = IqGrid(jj);
        psi_d = Fpsi_d(iq,id);
        psi_q = Fpsi_q(iq,id);
        Te = 1.5 * p * (psi_d*iq - psi_q*id);
        if abs(Te) > Te_max, Te_max = abs(Te); end
    end
end
Tmax = 0.98*Te_max;   % 留一点裕度

fprintf('[INFO] p=%d, Imax=%.3f A(peak), Tmax≈%.3f Nm\n', p, Imax, Tmax);

%% 2) 扫描参数（可按需调整）
TN    = 80;                   % 转矩点数（50~100）
isN   = 260;                  % 电流半径分辨率（≥200）
betaN = 241;                  % 电流角分辨率（-90°~+90°）
dTtol = 0.01*Tmax;            % 转矩容差（~1%% Tmax）

Tgrid = linspace(-Tmax, Tmax, TN);   %转矩取值范围
isVec = linspace(-Tmax, Imax, isN);  %电流取值范围
bVec  = linspace(-pi/2, pi/2, betaN);

lambda_tbl = nan(1,TN);
id_tbl = nan(1,TN);  iq_tbl = nan(1,TN);

%% 3) 核心：对每个 Tk 扫描 (is, beta)，找满足 Te≈Tk 的最小电流点（MTPA）
for k = 1:TN
    Tk = Tgrid(k);
    bestJ = inf;  bestid = 0; bestiq = 0;

    for ii = 1:isN
        is = isVec(ii);
        if is^2 > bestJ, break; end  % 半径已超当前最优

        for jj = 1:betaN
            beta = bVec(jj);
            id = is*cos(beta);
            iq = is*sin(beta);

            psi_d = Fpsi_d(iq,id);
            psi_q = Fpsi_q(iq,id);
            Te = 1.5 * p * (psi_d*iq - psi_q*id);

            if abs(Te - Tk) <= dTtol
                J = id^2 + iq^2;
                if J < bestJ
                    bestJ = J;  bestid = id;  bestiq = iq;
                end
            end
        end
    end

    id_tbl(k) = bestid;  iq_tbl(k) = bestiq;
    if isfinite(bestJ)
        psi_d = Fpsi_d(bestiq,bestid);
        psi_q = Fpsi_q(bestiq,bestid);
        lambda_tbl(k) = hypot(psi_d, psi_q);
    else
        lambda_tbl(k) = NaN;   % 超出能力/覆盖不足
    end
end

%% 4) 缺失修补 + 轻度平滑（仅 λ）
firstValid = find(~isnan(lambda_tbl), 1, 'first');
lastValid  = find(~isnan(lambda_tbl),  1, 'last');
if isempty(firstValid)
    error('未得到有效点：检查 p/Imax/Tmax/dTtol 与 (imd,imq) 覆盖范围。');
end
lambda_tbl(1:firstValid-1)   = lambda_tbl(firstValid);
lambda_tbl(lastValid+1:end)  = lambda_tbl(lastValid);
lambda_tbl = smoothdata(lambda_tbl,'movmean',max(3,round(TN/30)));

%% 5) 保存 + 快速预览
save('MTPA_T2lambda.mat','Tgrid','lambda_tbl','id_tbl','iq_tbl');
fprintf('[OK] 已保存：MTPA_T2lambda.mat（Tgrid, lambda_tbl, id_tbl, iq_tbl）\n');

figure('Name','T → λ (MTPA from Ψ)','Color','w');
plot(Tgrid, lambda_tbl,'LineWidth',1.8); grid on;
xlabel('Torque T (Nm)'); ylabel('\lambda (Wb)');
title('MTPA: \lambda^* vs T (from \Psi tables)');

end
