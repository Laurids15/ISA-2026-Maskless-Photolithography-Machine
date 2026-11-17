%% ANALYZE_PROBE  Field uniformity from the probe (key Q in the test viewer) + greyscale correction
% Log the power meter while the viewer runs the probe (tiles covering 100 % of the screen,
% row by row from the top left). This script
%   1. finds every tile in the log and averages it (dark level subtracted),
%   2. optionally removes source drift with the reference tiles (viewer setting
%      "drift reference tile after every N tiles"),
%   3. optionally divides out a correction overlay that was ON during the probe,
%   4. makes the map from the tile values with light smoothing by their neighbours (default), or
%      from a smooth 2-D polynomial (mapMode 'fit'); the 3rd-order fit is always printed for reference,
%   5. writes the map for the viewer / expose.html and the grey overlay (1024 x 768 PNG)
%      computed exactly as the viewer does it, and predicts the corrected field.
% Run analyze_grey_ramp.m first (it writes results/grey_curve.mat); otherwise the
% built-in grey curve below is used.
clear; close all;

% ------------------------------------------------------------------ settings
file        = 'rawtest_lowband_highres.csv';   % power-meter log of the probe
cols        = 32;  rows = 24;          % "Probe: grid" in the viewer (tiles cover 100 %)
refEvery    = 16;                      % reference tile (centre of the usable area) first and after every 16 tiles; 0 = none
usable      = [0 896 0 768];           % usable area [x0 x1 y0 y1] in DMD px (x1, y1 exclusive)
fitOrder    = 3;                       % order of the 2-D polynomial
mapMode     = 'neighbours';            % 'neighbours' = tile values, light smoothing by the neighbours; 'fit' = smooth polynomial
sigma       = 0.6;                     % width of the neighbour weights in tiles (0.6: tile itself ~45 %, sides ~11 %, diagonals ~3 %)
target      = [];                      % "Target level" (% of the map mean); [] = automatic: lowest map value in the usable area
overlayUsed = '';                      % PNG of the grey overlay that was ON during the probe ('' = probe without correction)
greyFile    = fullfile('results', 'grey_curve.mat');
defaultGrey = [50 2.2; 60 5.5; 70 9.7; 80 17.0; 90 26.3; 100 35.8; 110 37.6; 120 38.6; 130 41.7; ...
               140 43.0; 150 56.9; 155 64.0; 160 69.8; 255 69.8];   % fine ramp 3 Nov 17:30
outDir      = 'results';
W = 1024; H = 768;
% ------------------------------------------------------------------

if ~exist(outDir, 'dir'), mkdir(outDir); end
if exist(greyFile, 'file')
    G = load(greyFile); C = G.C; greySrc = G.file;
else
    C = grey_curve(defaultGrey(:,1), defaultGrey(:,2)); greySrc = 'built-in curve (3 Nov 17:30)';
end

% ---------------- sequence shown by the viewer
kinds = {};
if refEvery > 0, kinds{end+1} = 'ref'; end
for n = 1:cols*rows
    kinds{end+1} = 'tile'; %#ok<SAGROW>
    if refEvery > 0 && mod(n, refEvery) == 0, kinds{end+1} = 'ref'; end %#ok<SAGROW>
end
isRef = strcmp(kinds, 'ref');

% ---------------- find and average the pulses
[t, P, startText] = pm_read(file);
S = pm_steps(t, P, numel(kinds));
S = resolve_start(t, P, S, isRef, file);
v = S.mean*1e6; tm = (S.tOn + S.tOff)/2;            % uW, mid time of each pulse
tileV = v(~isRef); tileT = tm(~isRef); tileSE = S.se(~isRef)*1e6;
fprintf('\nProbe  %s  (start %s)\n', file, startText);
fprintf('%d x %d tiles, %d pulses, period %.2f s, on %.2f s, dark %.3f uW, %d detected, %d at predicted time\n', ...
        cols, rows, numel(kinds), S.period, S.onDur, S.dark*1e6, sum(S.detected), sum(~S.detected));
fprintf('sum of all tiles = %.0f uW (= full white with the same setting)%s\n', sum(tileV(isfinite(tileV))), repmat(' - some tiles missing', 1, any(~isfinite(tileV))));

drift = ones(size(tileV));
if refEvery > 0
    refV = v(isRef); refT = tm(isRef);
    okr = isfinite(refV); refV = refV(okr); refT = refT(okr);   % reference tiles lost in invalid data are skipped
    % smooth drift: 2nd-order fit in time (single reference tiles are noisy, ~3 %)
    if numel(refV) >= 4, pd = polyfit(refT, refV, 2); else, pd = polyfit(refT, refV, numel(refV) - 1); end
    drift = polyval(pd, tileT)/mean(polyval(pd, refT));
    fprintf('reference tile: %.2f ... %.2f uW (%.1f %% peak-to-peak drift), tiles divided by it\n', ...
            min(refV), max(refV), 100*(max(refV) - min(refV))/mean(refV));
end
Vmeas = reshape(tileV./drift, cols, rows)';          % rows x cols, row 1 = top of the screen

% ---------------- tile geometry (same rounding as the viewer)
xe = round((0:cols)*W/cols); ye = round((0:rows)*H/rows);
xc = (xe(1:end-1) + xe(2:end))/2; yc = (ye(1:end-1) + ye(2:end))/2;
[XC, YC] = meshgrid(xc, yc);
us = XC >= usable(1) & XC < usable(2) & YC >= usable(3) & YC < usable(4);
usGeom = us; us = us & isfinite(Vmeas);              % tiles without valid data are left out
if any(usGeom(:) & ~us(:)), fprintf('%d usable tiles have no valid data; the map fills them from their neighbours\n', nnz(usGeom & ~us)); end

% ---------------- divide out a correction that was ON during the probe
V = Vmeas;
if ~isempty(overlayUsed)
    g0 = double(imread(overlayUsed)); if size(g0,3) > 1, g0 = g0(:,:,1); end
    Lpix = C.L(g0 + 1); Lt = zeros(rows, cols);
    for i = 1:rows, for j = 1:cols, Lt(i,j) = mean(mean(Lpix(ye(i)+1:ye(i+1), xe(j)+1:xe(j+1)))); end, end
    V = Vmeas./Lt;
    r = 100*Vmeas/mean(Vmeas(us));
    fprintf('AS MEASURED (correction on): usable %.0f-%.0f %%, sd %.1f %%\n', min(r(us)), max(r(us)), std(r(us)));
end
Vn = 100*V/mean(V(us));
fprintf('Field without correction, usable area: %.0f-%.0f %% of mean, sd %.1f %% (tile noise ~%.1f %%)\n', ...
        min(Vn(us)), max(Vn(us)), std(Vn(us)), 100*median(tileSE(isfinite(tileSE)))/mean(V(us)));

% ---------------- 2-D polynomial fit on the usable tiles
ux = (usable(1) + usable(2))/2; uy = (usable(3) + usable(4))/2;
hx = (usable(2) - usable(1))/2; hy = (usable(4) - usable(3))/2;
X = (XC - ux)/hx; Y = (YC - uy)/hy;                 % -1 .. +1 over the usable area
fprintf('\nresidual sd of the fit:');
for o = 1:4
    Fo = poly2d(X(us), Y(us), Vn(us), o, X, Y);
    fprintf('  order %d: %.2f %%', o, std(Vn(us) - Fo(us)));
end
fprintf('\n');
[F, coef, terms] = poly2d(X(us), Y(us), Vn(us), fitOrder, X, Y);
fprintf('order %d coefficients (%% of mean), X = (x - %g)/%g, Y = (y - %g)/%g:\n', fitOrder, ux, hx, uy, hy);
for k = 1:numel(coef), fprintf('   X^%d Y^%d : %+8.2f\n', terms(k,1), terms(k,2), coef(k)); end

% the correction map
if strcmp(mapMode, 'fit')                            % smooth polynomial; outside the usable area: nearest usable tile
    Fm = F; idxU = find(usGeom);
    for k = find(~usGeom)'
        [~, j] = min((XC(idxU) - XC(k)).^2 + (YC(idxU) - YC(k)).^2);
        Fm(k) = Fm(idxU(j));
    end
else                                                 % tile values, light smoothing by the neighbours (default)
    Fm = neighbour_map(Vn, us, usGeom, XC, YC, sigma);
end
mapOut = 100*Fm/mean(Fm(usGeom));
if isempty(target), target = floor(min(100*mapOut(usGeom)/mean(mapOut(:)))); fprintf('target set automatically to %d %%\n', target); end

% ---------------- grey overlay, exactly as the viewer computes it
[xx, yy] = meshgrid(0:W-1, 0:H-1);
fx = min(cols-1, max(0, (xx + 0.5)*cols/W - 0.5));
fy = min(rows-1, max(0, (yy + 0.5)*rows/H - 0.5));
vpix = interp2(0:cols-1, 0:rows-1, mapOut, fx, fy, 'linear');
rel = 100*vpix/mean(mapOut(:));                     % the viewer uses the mean of all map values
c = min(1, target./rel);
g = C.inv(round(c*1000) + 1);
g = reshape(g, H, W);
Lg = reshape(C.L(g + 1), H, W);
Lt = zeros(rows, cols);
for i = 1:rows, for j = 1:cols, Lt(i,j) = mean(mean(Lg(ye(i)+1:ye(i+1), xe(j)+1:xe(j+1)))); end, end
Pred = V.*Lt; Pn = 100*Pred/mean(Pred(us)); Fn = 100*(F.*Lt)/mean(F(us).*Lt(us));
inU = xx >= usable(1) & xx < usable(2) & yy >= usable(3) & yy < usable(4);
fprintf('\nCorrection, target %g %%, grey curve: %s (knee %d)\n', target, greySrc, C.knee);
fprintf('grey levels in the usable area: %d-%d; light kept %.1f %% -> exposure time x %.2f\n', ...
        min(g(inU)), max(g(inU)), 100*mean(Pred(us))/mean(V(us)), mean(V(us))/mean(Pred(us)));
fprintf('predicted field after correction (measured tiles x overlay): %.0f-%.0f %%, sd %.1f %%\n', min(Pn(us)), max(Pn(us)), std(Pn(us)));
if strcmp(mapMode, 'fit'), fprintf('smooth part only (fit x overlay): %.1f-%.1f %%\n', min(Fn(us)), max(Fn(us))); end

% ---------------- outputs
imwrite(uint8(g), fullfile(outDir, 'correction_overlay_1024x768.png'));
fid = fopen(fullfile(outDir, sprintf('map_%dx%d_for_viewer.txt', cols, rows)), 'w');
for i = 1:rows
    fprintf(fid, '%s\n', strjoin(arrayfun(@(a) sprintf('%.1f', a), mapOut(i,:), 'UniformOutput', false), ', '));
end
fclose(fid);
save(fullfile(outDir, 'probe_result.mat'), 'Vmeas', 'V', 'Vn', 'F', 'mapOut', 'g', 'Pred', 'coef', 'terms', 'usable', 'target', 'file');
fprintf('\nSaved in %s/: map_%dx%d_for_viewer.txt (paste into "correction map", target %g), correction_overlay_1024x768.png,\n', outDir, cols, rows, target);
fprintf('probe_result.mat and the figures probe_*.png\n\n');

% ---------------- plots
f1 = figure('Name', 'probe trace');
plot(t, P*1e6, 'Color', [0.3 0.45 0.8]); hold on;
for k = 1:numel(kinds)
    col = [0.85 0.2 0.1]; if isRef(k), col = [0.1 0.6 0.2]; elseif ~S.detected(k), col = [0.95 0.6 0.1]; end
    plot([S.tOn(k) S.tOff(k)], [v(k) v(k)] + S.dark*1e6, '-', 'Color', col, 'LineWidth', 2);
end
hold off; grid on; xlabel('time (s)'); ylabel('power (\muW)');
title('Probe: averaging windows (red = tile, orange = predicted time, green = reference)');
print(f1, fullfile(outDir, 'probe_trace.png'), '-dpng', '-r110');

f2 = figure('Name', 'probe maps', 'Position', [50 50 1400 900]);
lim = [80 120];
if isempty(overlayUsed), ttl1 = 'Measured (without correction)'; else, ttl1 = 'Field without correction (measured / overlay)'; end
subplot(2, 2, 1); show_map(Vn, sprintf('%s, %% of mean: %.0f-%.0f, sd %.1f', ttl1, min(Vn(us)), max(Vn(us)), std(Vn(us))), lim, us);
if ~strcmp(mapMode, 'fit'), ttl2 = sprintf('Correction map (tiles, neighbour smoothing, sigma %.1f)', sigma); else, ttl2 = sprintf('Order-%d fit = correction map', fitOrder); end
subplot(2, 2, 2); show_map(mapOut, ttl2, lim, usGeom, '%.0f');
if strcmp(mapMode, 'fit'), Rm = Vn - F; ttl3 = 'Measured - fit'; else, Rm = Vn - mapOut; ttl3 = 'Measured - map (removed by the smoothing)'; end
subplot(2, 2, 3); show_map(Rm, sprintf('%s: sd %.2f %%', ttl3, std(Rm(us))), [-10 10], us, '%.1f');
subplot(2, 2, 4); show_map(Pn, sprintf('Predicted with correction: %.0f-%.0f, sd %.1f', min(Pn(us)), max(Pn(us)), std(Pn(us))), lim, us);
print(f2, fullfile(outDir, 'probe_maps.png'), '-dpng', '-r110');

f3 = figure('Name', 'overlay', 'Position', [80 80 1300 450]);
subplot(1, 2, 1); imagesc(0:W-1, 0:H-1, g); axis image; colormap(gca, gray); colorbar;
hold on; plot(usable([1 2 2 1 1]) - 0.5, usable([3 3 4 4 3]) - 0.5, 'r--'); hold off;
title(sprintf('Grey overlay (target %g %%): grey %d-%d in the usable area', target, min(g(inU)), max(g(inU))));
xlabel('DMD x (px)'); ylabel('DMD y (px)');
subplot(1, 2, 2); imagesc(0:W-1, 0:H-1, 100*Lg); axis image; colorbar;
hold on; plot(usable([1 2 2 1 1]) - 0.5, usable([3 3 4 4 3]) - 0.5, 'r--'); hold off;
title('Light let through by the overlay (% of full)'); xlabel('DMD x (px)'); ylabel('DMD y (px)');
print(f3, fullfile(outDir, 'probe_overlay.png'), '-dpng', '-r110');

if refEvery > 0
    f4 = figure('Name', 'drift');
    plot(refT, refV, 'o-', tileT, drift*mean(refV), '-'); grid on;
    xlabel('time (s)'); ylabel('reference tile (\muW)'); title('Source drift from the reference tile');
    legend('reference tile', 'smooth drift (2nd order)');
    print(f4, fullfile(outDir, 'probe_drift.png'), '-dpng', '-r110');
end
