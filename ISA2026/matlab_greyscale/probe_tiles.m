function R = probe_tiles(file, cols, rows, refEvery, W, H)
%PROBE_TILES  Tile powers of one probe run (test viewer key Q, tiles covering 100 %).
%   R = probe_tiles(file, cols, rows, refEvery)
%   refEvery = the viewer setting "drift reference tile after every N tiles" (0 = off);
%              with reference tiles the source drift is divided out.
%   R.V      rows x cols tile power in uW (row 1 = top of the screen)
%   R.se     rows x cols standard error of each tile (uW)
%   R.XC, R.YC  tile centres in DMD px;  R.xe, R.ye tile edges
%   R.S      pulse info from pm_steps;  R.drift  drift factor per tile (1 = none)
if nargin < 4, refEvery = 0; end
if nargin < 5, W = 1024; H = 768; end

kinds = {};
if refEvery > 0, kinds{end+1} = 'ref'; end
for n = 1:cols*rows
    kinds{end+1} = 'tile'; %#ok<AGROW>
    if refEvery > 0 && mod(n, refEvery) == 0, kinds{end+1} = 'ref'; end %#ok<AGROW>
end
isRef = strcmp(kinds, 'ref');

[t, P, startText] = pm_read(file);
S = pm_steps(t, P, numel(kinds));
S = resolve_start(t, P, S, isRef, file);
v = S.mean*1e6; tm = (S.tOn + S.tOff)/2;
tileV = v(~isRef); tileT = tm(~isRef); tileSE = S.se(~isRef)*1e6;
drift = ones(size(tileV));
if refEvery > 0
    refV = v(isRef); refT = tm(isRef);
    okr = isfinite(refV); refV = refV(okr); refT = refT(okr);   % reference tiles lost in invalid data are skipped
    % smooth drift: 2nd-order fit in time (single reference tiles are noisy, ~3 %)
    if numel(refV) >= 4, pd = polyfit(refT, refV, 2); else, pd = polyfit(refT, refV, numel(refV) - 1); end
    drift = polyval(pd, tileT)/mean(polyval(pd, refT));
end
R.V = reshape(tileV./drift, cols, rows)';
R.se = reshape(tileSE./drift, cols, rows)';
R.drift = reshape(drift, cols, rows)';
R.xe = round((0:cols)*W/cols); R.ye = round((0:rows)*H/rows);
xc = (R.xe(1:end-1) + R.xe(2:end))/2; yc = (R.ye(1:end-1) + R.ye(2:end))/2;
[R.XC, R.YC] = meshgrid(xc, yc);
R.S = S; R.file = file; R.start = startText; R.sumAll = sum(tileV(isfinite(tileV)));
R.nMissing = sum(~isfinite(tileV));
if R.nMissing > 0
    warning('probe_tiles: %d tiles of %s have no valid data (e.g. meter overload); they are left out (NaN).', R.nMissing, file);
end
fprintf('%s (start %s): %d pulses, %d detected, dark %.3f uW, sum of tiles %.0f uW%s\n', file, startText, ...
        numel(kinds), sum(S.detected), S.dark*1e6, R.sumAll, ...
        ifelse_str(refEvery > 0, sprintf(', drift %.1f %% p-p (divided out)', 100*(max(drift) - min(drift))), ''));
end

function s = ifelse_str(c, a, b)
if c, s = a; else, s = b; end
end
