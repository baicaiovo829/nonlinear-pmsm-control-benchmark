%% ==== 1) 从 To Workspace (Structure with time) 读取数据 ====
ref = T_ref_FPC;       % 参考信号
act = T_act_FPC;  % 实际信号
exr = FPC_Duty1;

t = ref.time; % 假设两者时间相同
%t = T_break_801;
y1 = ref.signals.values;
y2 = act.signals.values;
y3 = exr.signals.values;

% 若为多通道信号，只取第1列
if ~isvector(y1), y1 = y1(:,1); end
if ~isvector(y2), y2 = y2(:,1); end

%% ==== 2) 画图 ====
fig = figure('Name','Reference Voltage ','Color','w');

% 画参考信号
plot(t, y2, 'b-', 'LineWidth', 1.2); hold on;   % 蓝色实线
% 画实际信号
plot(t, y1, 'r-',  'LineWidth', 1.5); hold on    % 红色实线

%plot(t, y3, 'g-',  'LineWidth', 1.5);           % 绿色实线

xlabel('Time (s)', 'FontWeight','bold', 'FontSize',10);
ylabel(['Torque ', '(Nm)'], 'FontWeight','bold', 'FontSize',10);
%title('Three-phase PWM duty cycles', 'FontWeight','bold', 'FontSize',13);

legend({'act','ref'}, 'Location','northwest', 'Box','on');

xlim([1.6, 2.0]);
ylim([165, 200])

set(gca, ...
    'FontName','Arial', 'FontSize',17, ...
    'LineWidth',1.2, ...
    'Box','on', ...
    'TickDir','in', ...
    'Layer','bottom', ...
    'YGrid','on', ...
    'XGrid','on', ...
    'GridColor',[0.7 0.7 0.7]);


%% ==== 3) 调用你自己的导出函数 ====
% 论文用 pdf，PPT 顺手也来个 png：
%export_all_figs('fig_out_paper', {'pdf','eps'}, [5 3]);
%exportgraphics(fig, fullfile(folder, sprintf('%s.pdf', string(fname))), 'ContentType','vector');
%export_all_figs('Voltage_SVPWM_FPC', {"pdf"}, [5 3]);


% 导出答辩 / PPT 图（展示版）
%export_all_figs('fig_out_ppt_FPC_speed4_gama0.98_dam0.707_worst_19T', {'emf'}, [6 4]);


%% 需要画其它信号 只需要改这里
%s = Te_FOC;        % 改变量名
%fig = figure('Name','Te_FOC','Color','w');  % 改图名
%ylabel('Torque / Nm', ...);                % 改纵轴


%% 可视化输出
function export_all_figs(outDir, formats, sz_in)
%EXPORT_ALL_FIGS  Export all open figures as crisp vector images (paper/PPT ready).
%   export_all_figs(outDir, formats, sz_in)
%   - outDir  : 输出文件夹（不存在会自动创建）
%   - formats : 导出格式 cell，例如 {'pdf','svg','eps','emf'}
%               建议：论文(PDF/SVG/EPS)，PPT(EMF/PNG)
%   - sz_in   : 图幅大小 [W H]（英寸, 默认 [6 4]）
%
%   特性：
%   - 统一样式（字体、字号、线宽、背景）
%   - R2020a+ 优先用 exportgraphics 矢量；否则自动回退到 print -painters
%   - Windows 下可导出 EMF 供 PPT 矢量插入

    if nargin < 1 || isempty(outDir), outDir = fullfile(pwd,'fig_out'); end
    if nargin < 2 || isempty(formats), formats = {'pdf','svg'}; end
    if nargin < 3 || isempty(sz_in),   sz_in = [6 4]; end

    if ~exist(outDir,'dir'), mkdir(outDir); end

    % ---- 全局统一样式（对当前会话生效） ----
    set(0,'DefaultFigureColor','w');
    set(0,'DefaultAxesFontName','Arial');
    set(0,'DefaultTextFontName','Arial');
    set(0,'DefaultAxesFontSize',10);
    set(0,'DefaultTextFontSize',10);
    set(0,'DefaultLineLineWidth',1.2);
    set(0,'DefaultAxesLineWidth',0.8);
    set(0,'DefaultAxesBox','on');
    set(0,'DefaultAxesTickDir','out');

    % 收集图窗
    figs = findall(groot,'Type','figure');
    if isempty(figs)
        warning('No open figures to export.');
        return;
    end
    figs = flipud(figs); % 保持创建顺序

    for i = 1:numel(figs)
        fig = figs(i);
        try
            % 统一尺寸 & 矢量渲染
            set(fig,'InvertHardcopy','off');            % 保持背景
            set(fig,'Renderer','painters');             % 矢量渲染
            set(fig,'Units','inches');
            pos = get(fig,'Position');
            pos(3:4) = sz_in;                            % [W H] inches
            set(fig,'Position',pos);

            base = get(fig,'Name');
            if isempty(base)
                base = sprintf('Figure_%02d', i);
            else
                base = sanitize_filename(base);
            end
            fname = fullfile(outDir, base);

            % 尝试用 exportgraphics（R2020a+）
            useExportGraphics = ~isempty(which('exportgraphics'));

            for f = 1:numel(formats)
                fmt = lower(formats{f});
                switch fmt
                    % case 'pdf'
                    %     if useExportGraphics
                    %         exportgraphics(fig, [fname '.pdf'], ...
                    %             'ContentType','vector','BackgroundColor','none');
                    %     else
                    %         set(fig,'PaperPositionMode','auto');
                    %         print(fig, [fname '.pdf'], '-dpdf','-painters');
                    %     end
                    case 'pdf'
    if useExportGraphics
        exportgraphics(fig, [fname '.pdf'], ...
            'ContentType','vector', 'BackgroundColor','white');
    else
        set(fig,'PaperPositionMode','auto');
        print(fig, [fname '.pdf'], '-dpdf','-vector');
    end

                    case 'svg'
                        if useExportGraphics
                            exportgraphics(fig, [fname '.svg'], ...
                                'ContentType','vector','BackgroundColor','none');
                        else
                            % 需要 MATLAB 支持 -dsvg（R2020a 前可能没有）
                            try
                                print(fig, [fname '.svg'], '-dsvg','-painters');
                            catch
                                warning('SVG not supported on this MATLAB. Skipped.');
                            end
                        end
                    case 'eps'
                        set(fig,'PaperPositionMode','auto');
                        print(fig, [fname '.eps'], '-depsc','-painters'); % 彩色EPS
                    case 'emf'
                        % 仅 Windows: 矢量 for PowerPoint
                        if ispc
                            print(fig, [fname '.emf'], '-dmeta','-painters');
                        else
                            warning('EMF export is Windows-only. Skipped.');
                        end
                    case 'png' % 万一需要光栅版（海报/PPT），用高分辨率
                        if useExportGraphics
                            exportgraphics(fig, [fname '.png'], 'Resolution',300, ...
                                'BackgroundColor','white');
                        else
                            print(fig, [fname '.png'], '-dpng','-r300');
                        end

                    otherwise
                        warning('Unknown format: %s (skipped)', fmt);
                end
            end
        catch ME
            warning('Export failed for figure %d: %s', i, ME.message);
        end
    end
    fprintf('Export done. Output dir: %s\n', outDir);
end

function s = sanitize_filename(s)
    % 把 fig 名里的非法字符替换掉，便于跨平台保存
    s = regexprep(s, '[^\w\s\-\(\)\[\]\.]', '_');
    s = strtrim(s);
    if isempty(s), s = 'Figure'; end
end
