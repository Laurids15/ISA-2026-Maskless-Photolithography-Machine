%% COMPARE_CORRECTION  Effect of the greyscale correction: probe without vs. probe with correction
% Load two probe runs (test viewer key Q, same grid, tiles covering 100 %):
%   fileBefore  probe WITHOUT correction  -> deviation from the mean
%   fileAfter   probe WITH the correction -> deviation from the mean
% Two maps side by side on the same colour scale. Only what was measured.
% Output: results/compare_correction.png and a printed summary.
clear; close all;

% ------------------------------------------------------------------ settings
fileBefore     = 'rawtest_lowband_highres.csv';        % probe without correction
fileAfter      = 'Greyscale_highres_1435.csv';         % probe with the final greyscale correction on
cols = 32; rows = 24;                    % probe grid (same for both)
refEveryBefore = 16;                     % reference tile (centre) first and after every 16 tiles; 0 = none
refEveryAfter  = 32;                     % this run: reference tile after every 32 tiles (793 pulses)
usable   = [0 896 0 768];                % usable area [x0 x1 y0 y1] in DMD px
clim     = [];                           % colour scale in %, e.g. [-20 20]; [] = automatic, symmetric
outDir   = 'results';
% ------------------------------------------------------------------

if ~exist(outDir, 'dir'), mkdir(outDir); end
fprintf('\n');
B = probe_tiles(fileBefore, cols, rows, refEveryBefore);
A = probe_tiles(fileAfter,  cols, rows, refEveryAfter);
usGeom = B.XC >= usable(1) & B.XC < usable(2) & B.YC >= usable(3) & B.YC < usable(4);
us = usGeom & isfinite(B.V) & isfinite(A.V);         % tiles without valid data in either run are left out

% deviation from the mean of the usable area, in %
Db = 100*B.V/mean(B.V(us)) - 100;
Da = 100*A.V/mean(A.V(us)) - 100;

% within-row spread: free of slow source drift (rows are measured one after the other)
rowMean = @(D) sum(D.*us, 2)./sum(us, 2);
Db0 = Db; Db0(~us) = 0; Da0 = Da; Da0(~us) = 0;
Wb = bsxfun(@minus, Db, rowMean(Db0)); Wa = bsxfun(@minus, Da, rowMean(Da0));

nb = 100*median(B.se(us))/mean(B.V(us)); na = 100*median(A.se(us))/mean(A.V(us));
fprintf('\nUsable area (%d tiles), deviation from the mean:\n', nnz(us));
fprintf('                               min .. max        sd     within-row sd   tile noise\n');
fprintf('  without correction        %+6.1f .. %+5.1f %%  %5.1f %%     %5.1f %%        %4.1f %%\n', min(Db(us)), max(Db(us)), std(Db(us)), std(Wb(us)), nb);
fprintf('  WITH correction           %+6.1f .. %+5.1f %%  %5.1f %%     %5.1f %%        %4.1f %%\n', min(Da(us)), max(Da(us)), std(Da(us)), std(Wa(us)), na);
fprintf('\nMean tile power in the usable area: %.2f uW without, %.2f uW with correction (ratio %.2f;\n', mean(B.V(us)), mean(A.V(us)), mean(A.V(us))/mean(B.V(us)));
fprintf('includes any change of the LED power between the two runs)\n\n');

% ---------------- plot: without | with correction, same colour scale
if isempty(clim)
    m = ceil(max(abs([Db(us); Da(us)]))/5)*5; clim = [-m m];
end
Dbp = Db; Dbp(usGeom & ~us) = NaN; Dap = Da; Dap(usGeom & ~us) = NaN;
f = figure('Name', 'greyscale correction', 'Position', [40 60 1300 500]);
subplot(1, 2, 1);
show_map(Dbp, sprintf('Without correction: %+.1f .. %+.1f %%, sd %.1f %%', min(Db(us)), max(Db(us)), std(Db(us))), clim, usGeom, '%.0f');
subplot(1, 2, 2);
show_map(Dap, sprintf('With correction: %+.1f .. %+.1f %%, sd %.1f %%', min(Da(us)), max(Da(us)), std(Da(us))), clim, usGeom, '%.0f');
print(f, fullfile(outDir, 'compare_correction.png'), '-dpng', '-r110');
fprintf('Saved %s\n', fullfile(outDir, 'compare_correction.png'));
