%% REFINE_MAP  Correction map from several probe runs (same grid), averaged tile by tile
% Every run gives an estimate of the field WITHOUT correction:
%   run without correction:  E = measured tiles
%   run with correction on:  E = measured tiles / light let through by the overlay that was used
% The estimates are normalised, averaged tile by tile (missing tiles skipped) and lightly smoothed
% by their neighbours (neighbour_map.m). Averaging several runs removes run-to-run errors (LED,
% mounts, sensor position), which are larger than the noise of a single run.
% Writes a new map and overlay for the viewer / expose.html.
clear; close all;

% ------------------------------------------------------------------ settings
rawFiles    = {'rawtest_lowband_highres.csv', 'warmedup_lowband_highres_32x24.csv'};   % probes WITHOUT correction
rawRef      = [16 16];                               % reference tile every N tiles in each raw run
corrFiles   = {'Greyscale_highres_1435.csv'};        % probes WITH the correction on (may be empty)
corrOverlay = {fullfile('example_results', 'final_correction_overlay_1024x768.png')};  % overlay that was on in each
corrRef     = [32];                                  % reference tile every N tiles in each corrected run
cols = 32; rows = 24;                                % same grid for all runs
usable      = [0 896 0 768];
sigma       = 0.6;      % width of the neighbour weights in tiles (0 = none, 0.6 = light)
target      = [];       % [] = automatic: lowest value of the new map in the usable area, rounded down
greyFile    = fullfile('results', 'grey_curve.mat');
outDir      = 'results_refined';
W = 1024; H = 768;
% ------------------------------------------------------------------

if ~exist(outDir, 'dir'), mkdir(outDir); end
G = load(greyFile); C = G.C;
fprintf('\n');
Es = {}; names = {};
for k = 1:numel(rawFiles)
    R = probe_tiles(rawFiles{k}, cols, rows, rawRef(k));
    Es{end+1} = R.V; names{end+1} = [rawFiles{k} ' (no correction)']; %#ok<SAGROW>
end
for k = 1:numel(corrFiles)
    R = probe_tiles(corrFiles{k}, cols, rows, corrRef(k));
    g0 = double(imread(corrOverlay{k})); if size(g0,3) > 1, g0 = g0(:,:,1); end
    L0 = C.L(g0 + 1); Lt0 = zeros(rows, cols);
    for i = 1:rows, for j = 1:cols, Lt0(i,j) = mean(mean(L0(R.ye(i)+1:R.ye(i+1), R.xe(j)+1:R.xe(j+1)))); end, end
    Es{end+1} = R.V./Lt0; names{end+1} = [corrFiles{k} ' / overlay']; %#ok<SAGROW>
end
us = R.XC >= usable(1) & R.XC < usable(2) & R.YC >= usable(3) & R.YC < usable(4);
n = numel(Es);
for k = 1:n
    ok = us & isfinite(Es{k}); Es{k} = 100*Es{k}/mean(Es{k}(ok));
end

% agreement between the runs
fprintf('\nEstimates of the field without correction (usable area):\n');
for k = 1:n
    ok = us & isfinite(Es{k});
    fprintf('  run %d: %-50s sd %.1f %%, %d tiles\n', k, names{k}, std(Es{k}(ok)), nnz(ok));
end
for a = 1:n-1
    for b = a+1:n
        ok = us & isfinite(Es{a}) & isfinite(Es{b});
        rr = corrcoef(Es{a}(ok), Es{b}(ok));
        fprintf('  run %d vs run %d: r = %.3f, differ by sd %.2f %%\n', a, b, rr(1,2), std(Es{a}(ok) - Es{b}(ok)));
    end
end

% tile-by-tile mean of the available estimates, then neighbour smoothing
stack = cat(3, Es{:}); cnt = sum(isfinite(stack), 3); stack(~isfinite(stack)) = 0;
E = sum(stack, 3)./cnt; E(cnt == 0) = NaN;
S = neighbour_map(E, isfinite(E), us, R.XC, R.YC, sigma);
mapOut = 100*S/mean(S(us));
if isempty(target), target = floor(min(100*mapOut(us)/mean(mapOut(:)))); end

[g, Lg] = make_overlay(mapOut, target, C, W, H);
Lt = zeros(rows, cols);
for i = 1:rows, for j = 1:cols, Lt(i,j) = mean(mean(Lg(R.ye(i)+1:R.ye(i+1), R.xe(j)+1:R.xe(j+1)))); end, end
inU = false(H, W); inU(usable(3)+1:usable(4), usable(1)+1:usable(2)) = true;
okE = us & isfinite(E);
fprintf('\nNew map from %d run(s), sigma %.1f, target %d %%: grey %d-%d, light kept %.1f %% -> time x %.2f\n', n, sigma, target, ...
        min(g(inU)), max(g(inU)), 100*mean(E(okE).*Lt(okE))/mean(E(okE)), mean(E(okE))/mean(E(okE).*Lt(okE)));
for k = 1:n
    ok = us & isfinite(Es{k}); P = Es{k}.*Lt; P = 100*P/mean(P(ok));
    fprintf('  expected with the new map, judged on run %d: sd %.1f %%\n', k, std(P(ok)));
end

imwrite(uint8(g), fullfile(outDir, 'correction_overlay_1024x768.png'));
fid = fopen(fullfile(outDir, sprintf('map_%dx%d_for_viewer.txt', cols, rows)), 'w');
for i = 1:rows
    fprintf(fid, '%s\n', strjoin(arrayfun(@(a) sprintf('%.1f', a), mapOut(i,:), 'UniformOutput', false), ', '));
end
fclose(fid);
fprintf('Saved in %s/: map_%dx%d_for_viewer.txt (target %d), correction_overlay_1024x768.png, refine_map.png\n\n', outDir, cols, rows, target);

f = figure('Name', 'refined map', 'Position', [40 60 1400 900]);
lim = [85 115];
for k = 1:min(n, 2)
    subplot(2, 2, k); show_map(Es{k}, sprintf('Run %d: %s', k, names{k}), lim, us);
end
subplot(2, 2, 3); show_map(mapOut, sprintf('New map: mean of %d run(s), neighbour smoothing sigma %.1f', n, sigma), lim, us);
if n >= 2
    ok = us & isfinite(Es{1}) & isfinite(Es{2});
    Dd = Es{1} - Es{2}; Dd(~ok) = NaN;
    subplot(2, 2, 4); show_map(Dd, sprintf('Run 1 - run 2 (sd %.2f %%): run-to-run differences', std(Dd(ok))), [-5 5], us, '%.1f');
end
print(f, fullfile(outDir, 'refine_map.png'), '-dpng', '-r110');
