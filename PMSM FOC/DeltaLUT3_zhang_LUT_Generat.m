%% —— 兼容护栏：如果只有小写变量，则映射到大写 ——
if ~exist('Lambda_log','var') && exist('lambda_log','var')
    Lambda_log = lambda_log;
end

%% ===== 0) 三路变量转 timetable（无函数版）=====
% --- T_log ---
if isa(T_log,'timeseries')
    TT_T = timetable(seconds(T_log.Time(:)), double(T_log.Data(:)), 'VariableNames',{'T'});
elseif isa(T_log,'Simulink.SimulationData.Signal')
    TT_T = timetable(seconds(T_log.Values.Time(:)), double(T_log.Values.Data(:)), 'VariableNames',{'T'});
elseif isstruct(T_log) && isfield(T_log,'time') && isfield(T_log,'signals') && isfield(T_log.signals,'values')
    TT_T = timetable(seconds(T_log.time(:)), double(T_log.signals.values(:)), 'VariableNames',{'T'});
elseif istimetable(T_log)
    TT_T = T_log(:,1); TT_T.Properties.VariableNames={'T'};
elseif istable(T_log)
    TT_T = timetable(seconds(T_log{:,1}), double(T_log{:,2}), 'VariableNames',{'T'});
elseif isnumeric(T_log)
    n = numel(T_log); TT_T = timetable(seconds((0:n-1)'), double(T_log(:)), 'VariableNames',{'T'});
else
    error('无法识别 T_log 类型：%s', class(T_log));
end

% --- Lambda_log（注意：现在全用大写 L 的变量名） ---
if isa(Lambda_log,'timeseries')
    TT_Lambda = timetable(seconds(Lambda_log.Time(:)), double(Lambda_log.Data(:)), 'VariableNames',{'Lambda'});
elseif isa(Lambda_log,'Simulink.SimulationData.Signal')
    TT_Lambda = timetable(seconds(Lambda_log.Values.Time(:)), double(Lambda_log.Values.Data(:)), 'VariableNames',{'Lambda'});
elseif isstruct(Lambda_log) && isfield(Lambda_log,'time') && isfield(Lambda_log,'signals') && isfield(Lambda_log.signals,'values')
    TT_Lambda = timetable(seconds(Lambda_log.time(:)), double(Lambda_log.signals.values(:)), 'VariableNames',{'Lambda'});
elseif istimetable(Lambda_log)
    TT_Lambda = Lambda_log(:,1); TT_Lambda.Properties.VariableNames={'Lambda'};
elseif istable(Lambda_log)
    TT_Lambda = timetable(seconds(Lambda_log{:,1}), double(Lambda_log{:,2}), 'VariableNames',{'Lambda'});
elseif isnumeric(Lambda_log)
    n = numel(Lambda_log); TT_Lambda = timetable(seconds((0:n-1)'), double(Lambda_log(:)), 'VariableNames',{'Lambda'});
else
    error('无法识别 Lambda_log 类型：%s', class(Lambda_log));
end

% --- Delta_log ---
if isa(Delta_log,'timeseries')
    TT_Delta = timetable(seconds(Delta_log.Time(:)), double(Delta_log.Data(:)), 'VariableNames',{'Delta'});
elseif isa(Delta_log,'Simulink.SimulationData.Signal')
    TT_Delta = timetable(seconds(Delta_log.Values.Time(:)), double(Delta_log.Values.Data(:)), 'VariableNames',{'Delta'});
elseif isstruct(Delta_log) && isfield(Delta_log,'time') && isfield(Delta_log,'signals') && isfield(Delta_log.signals,'values')
    TT_Delta = timetable(seconds(Delta_log.time(:)), double(Delta_log.signals.values(:)), 'VariableNames',{'Delta'});
elseif istimetable(Delta_log)
    TT_Delta = Delta_log(:,1); TT_Delta.Properties.VariableNames={'Delta'};
elseif istable(Delta_log)
    TT_Delta = timetable(seconds(Delta_log{:,1}), double(Delta_log{:,2}), 'VariableNames',{'Delta'});
elseif isnumeric(Delta_log)
    n = numel(Delta_log); TT_Delta = timetable(seconds((0:n-1)'), double(Delta_log(:)), 'VariableNames',{'Delta'});
else
    error('无法识别 Delta_log 类型：%s', class(Delta_log));
end

%% ===== 1) 对齐 + 自检 =====
ALLu = synchronize(TT_T, TT_Lambda, TT_Delta, 'union','nearest');
ALL  = ALLu(~(ismissing(ALLu.T)|ismissing(ALLu.Lambda)|ismissing(ALLu.Delta)), :);

t      = seconds(ALL.Time - ALL.Time(1));
T      = double(ALL.T);
Lambda = double(ALL.Lambda);
Delta  = double(ALL.Delta);

%% ===== 2) （可选）轻量筛选，留不下就跳过 =====
if numel(T)>=2, Ts=max(eps,median(diff(t))); else, Ts=1e-4; end
win = max(3, round(0.02/Ts));
stdT=movstd(T,win,0,'omitnan'); stdL=movstd(Lambda,win,0,'omitnan');
dT=[0;diff(T)]/Ts; dL=[0;diff(Lambda)]/Ts;

mask = (stdT < max(0.01*max(abs(T)),0.2)) & ...
       (stdL < max(0.01*max(abs(Lambda)),1e-3)) & ...
       (abs(dT) < max(0.05*max(abs(T)),1.0)) & ...
       (abs(dL) < max(0.05*max(abs(Lambda)),1e-2));

if nnz(mask) >= 50
    T=T(mask); Lambda=Lambda(mask); Delta=Delta(mask);
end

%% ===== 3) 生成 δ*(T,|λ|) LUT =====
S = sin(Delta); C = cos(Delta);
T_grid = linspace(-220, 220, 81);
L_grid = linspace(0.20, 0.45, 61);
[TTg,LLg] = meshgrid(T_grid, L_grid);

Fs = scatteredInterpolant(T, Lambda, S, 'natural','nearest');
Fc = scatteredInterpolant(T, Lambda, C, 'natural','nearest');
DeltaLUT = atan2(Fs(TTg,LLg), Fc(TTg,LLg));

%% ===== 4) 评估 + 保存 =====
Si = griddedInterpolant({L_grid, T_grid}, DeltaLUT, 'linear','nearest');
Delta_pred = Si(Lambda, T);
err  = angle(exp(1j*(Delta_pred - Delta)));
rmse = sqrt(mean(err.^2));
fprintf('RMSE = %.4g rad (%.2f°)\n', rmse, rmse*180/pi);

save('deltaLUT.mat','DeltaLUT','T_grid','L_grid','rmse');
disp('✅ 已生成 deltaLUT.mat（大写 Lambda_log 版）');
