%% ANALYZE_GREY_RAMP  Projector grey response from the grey ramp (key R in the test viewer)
% Log the power meter (Optical Parameter Monitor, CSV) while the viewer shows the
% ramp: a centre square at each grey level in turn, dark in between.
% Output:
%   results/grey_curve.mat              levels, power, curve (used by analyze_probe.m)
%   results/grey_curve_for_viewer.txt   'level:power, ...' -> paste into the viewer /
%                                       expose.html field "Grey curve, level:power"
%   results/grey_ramp_trace.png, results/grey_ramp_curve.png
clear; close all;

% ------------------------------------------------------------------ settings
file   = 'grey_scale.csv';             % power-meter log of the ramp
levels = [255 200 195 190 185 180 175 170 165 160 155 150 145 140 135 130 125 120 115 110 105 100 95 90 85 80 75 70 65 60 55 50];  % "Grey ramp levels" in the viewer, in order
outDir = 'results';
% ------------------------------------------------------------------

if ~exist(outDir, 'dir'), mkdir(outDir); end
[t, P, startText] = pm_read(file);
S = pm_steps(t, P, numel(levels));
uW = S.mean*1e6; se = S.se*1e6;
C = grey_curve(levels, uW);
top = C.pts(end, 2);

fprintf('\nGrey ramp  %s  (start %s)\n', file, startText);
fprintf('period %.2f s, on %.2f s, dark %.3f uW, %d of %d pulses detected (rest at predicted times)\n', ...
        S.period, S.onDur, S.dark*1e6, sum(S.detected), numel(levels));
fprintf('\n grey    power (uW)        %% of full\n');
tags = {'', '(predicted time)'};
for k = 1:numel(levels)
    fprintf(' %4d   %7.2f +- %5.2f    %6.1f %s\n', levels(k), uW(k), se(k), 100*uW(k)/top, tags{2 - S.detected(k)});
end
kn = C.knee;
fprintf('\nKnee: full light (plateau, within 2 %% noise) from grey %d upwards. Slope over the 10 levels below: %.1f %% per grey level\n', ...
        kn, 100*(C.L(kn+1) - C.L(max(1, kn-9)))/10);
fprintf('\nPaste into the viewer / expose.html "Grey curve, level:power":\n%s\n\n', C.lutString);

% ---------------- plots
f1 = figure('Name', 'ramp trace');
plot(t, P*1e6, 'Color', [0.3 0.45 0.8]); hold on;
for k = 1:numel(levels)
    col = [0.85 0.2 0.1]; if ~S.detected(k), col = [0.95 0.6 0.1]; end
    plot([S.tOn(k) S.tOff(k)], [uW(k) uW(k)] + S.dark*1e6, '-', 'Color', col, 'LineWidth', 2.5);
    text((S.tOn(k) + S.tOff(k))/2, uW(k) + S.dark*1e6 + 0.04*top, sprintf('%d', levels(k)), 'HorizontalAlignment', 'center', 'FontSize', 8);
end
hold off; grid on;
xlabel('time (s)'); ylabel('power (\muW)');
title(sprintf('Grey ramp: averaging windows (red = detected, orange = predicted)  %s', strrep(file, '_', '\_')));
print(f1, fullfile(outDir, 'grey_ramp_trace.png'), '-dpng', '-r110');

f2 = figure('Name', 'grey curve', 'Position', [100 100 1100 420]);
for sp = 1:2
    subplot(1, 2, sp);
    errorbar(levels, 100*uW/top, 100*se/top, 'o'); hold on;
    plot(0:255, 100*C.L, '-', 'Color', [0.85 0.3 0.1], 'LineWidth', 1.2);
    plot([C.knee C.knee], [0 105], ':k'); hold off; grid on;
    xlabel('grey level'); ylabel('% of full light');
    if sp == 1
        xlim([0 260]); ylim([0 110]); title('Projector grey response (dots: measured, line: curve used)');
    else
        xlim([max(0, C.knee-40) min(255, C.knee+30)]); ylim([40 105]);
        title(sprintf('Zoom around the knee (grey %d)', C.knee));
    end
end
print(f2, fullfile(outDir, 'grey_ramp_curve.png'), '-dpng', '-r110');

save(fullfile(outDir, 'grey_curve.mat'), 'levels', 'uW', 'se', 'C', 'file');
fid = fopen(fullfile(outDir, 'grey_curve_for_viewer.txt'), 'w'); fprintf(fid, '%s\n', C.lutString); fclose(fid);
fprintf('Saved in %s/: grey_curve.mat, grey_curve_for_viewer.txt, grey_ramp_trace.png, grey_ramp_curve.png\n', outDir);
