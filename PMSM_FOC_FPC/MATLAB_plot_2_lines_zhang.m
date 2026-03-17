t = T_ref_FOC.time;
y = T_ref_FOC.signals.values;
y_FOC_act = T_act_FPC.signals.values;
y_FPC_act = T_act_FOC.signals.values;
%t_ref = PLECStorque.TimeS;
%y_ref = PLECStorque.MotorSpeed;

figure;
plot(t, y, 'Color', "b", 'LineWidth', 1.5);    % 实际电流 id_act（蓝色）
hold on;
plot(t, y_FPC_act, 'Color', "r", 'LineWidth', 1.5); % 参考电流 id_ref（红色）
grid on;
plot(t, y_FOC_act, 'Color', "g", 'LineWidth', 1.5); % 参考电流 id_ref（红色）
grid on;

set(gca, 'Color', [1 1 1]);
set(gca, 'GridColor', [0.6 0.6 0.6]);
set(gca, 'MinorGridColor', [0.8 0.8 0.8]);
set(gca, 'XColor', 'k', 'YColor', 'k');
set(gca, 'LineWidth', 0.8);
set(gca, 'FontSize', 10);
set(gca, 'Box', 'on');

xlabel('Time / s', "FontSize", 22, "FontWeight", "bold",'Color', 'k');
ylabel('Torque / Nm', "FontSize", 22, "FontWeight", "bold", 'Color', 'k');
title('Torque Response', 'FontSize', 22, 'FontWeight', 'bold', 'Color', 'k');
set(gca, "FontSize", 18, "FontWeight", "bold")

set(gca, 'GridAlpha', 0.4);
set(gcf, 'Color', [1 1 1]);
axis tight;

% === 坐标范围 ===
ylim([-300 300]); 
xlim([0 2.4]);

% === 网格样式 ===
set(gca, "GridLineStyle", ":")
set(gca, "GridColor", [0.5 0.5 0.5])

% === ★ 添加图例 ===
legend({'T_{ref}','T_{FOC,act}', 'T_{FPC,act}'}, ...
       'FontSize',16, ...
       'FontWeight','bold', ...
       'TextColor','k', ...
       'Location','southeast');   % 固定右上角
legend boxoff;   % 可选：去掉边框


%% ==== 3) 调用你自己的导出函数 ====
% 论文用 pdf，PPT 顺手也来个 png：
%export_all_figs('fig_out_paper', {'pdf','eps'}, [5 3]);

% 导出答辩 / PPT 图（展示版）
export_all_figs('fig_out_ppt_FOC_FPC_speed3_gama0.96_dam0.707', {'emf'}, [6 4]);


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
                    case 'pdf'
                        if useExportGraphics
                            exportgraphics(fig, [fname '.pdf'], ...
                                'ContentType','vector','BackgroundColor','none');
                        else
                            set(fig,'PaperPositionMode','auto');
                            print(fig, [fname '.pdf'], '-dpdf','-painters');
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
