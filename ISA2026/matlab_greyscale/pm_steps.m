function S = pm_steps(t, P, nSteps, opts)
%PM_STEPS  Find nSteps equally timed light pulses in a power-meter log and average each one.
%   S = pm_steps(t, P, nSteps, opts)
%   t, P     from pm_read (s, W)
%   nSteps   number of pulses the viewer showed (grey levels, tiles, reference tiles ...)
%   opts     optional struct:
%     .thr        threshold (W) between dark and lit; default dark + 20 % of the bright level
%     .trim       seconds cut off at both ends of every pulse (default: 0.25 s, less for short
%                 pulses: 20 % of the on-time, at least 0.08 s, so a 0.6 s pulse keeps ~3 samples)
%     .firstStart time (s) of the first pulse if it is too dim to be detected
%
%   The bright pulses fix the timing (start of the first one, period, on-time);
%   pulses too dim to detect (dark corner, low grey levels) are taken at their
%   predicted time. Each detected pulse re-anchors the timing, so slow drift of
%   the browser timing does not accumulate.
%
%   S.mean, S.sd, S.se, S.n   per pulse, dark level subtracted (W)
%   S.tOn, S.tOff             averaging window (s)
%   S.detected                true if the pulse was found, false if predicted
%   S.dark, S.period, S.onDur, S.thr
%   S.altStarts               possible start times that fit (almost) as well; more than one means the
%                             first step is ambiguous (e.g. corner text on) - see probe_tiles

if nargin < 4, opts = struct(); end
autoTrim = ~isfield(opts, 'trim');
t = t(:); P = P(:);

% fill NaN with the previous value for the detection only
Pf = P;
for i = 1:numel(Pf)
    if isnan(Pf(i))
        if i == 1, Pf(i) = 0; else, Pf(i) = Pf(i-1); end
    end
end
Pm = movmedian(Pf, 3);

Ps = sort(Pm); pct = @(q) Ps(max(1, round(q/100*numel(Ps))));   % percentile without the Statistics Toolbox
darkEst = pct(5); hiEst = pct(95);
if isfield(opts, 'thr'), thr = opts.thr; else, thr = darkEst + 0.2*(hiEst - darkEst); end

% lit segments
on = Pm > thr;
d = diff([0; on; 0]);
iS = find(d == 1); iE = find(d == -1) - 1;
k = iS > 1 & iE < numel(t);               % ignore segments cut by the start or end of the log
iS = iS(k); iE = iE(k);
segS = t(iS); segE = t(iE);
dur = segE - segS;
k = dur > 0.3;
segS = segS(k); segE = segE(k); dur = dur(k);
if isempty(segS), error('pm_steps: no light pulses found (threshold %.3g W).', thr); end
onDur = median(dur);
k = abs(dur - onDur) < 0.35*onDur;        % drop odd segments (armed-screen text, merged pulses)
segS = segS(k); segE = segE(k); %#ok<NASGU>
if numel(segS) < 2, error('pm_steps: fewer than two clean pulses found.'); end
if autoTrim, opts.trim = min(0.25, max(0.08, 0.2*onDur)); end

dd = diff(segS);
p0 = median(dd);
period = median(dd(abs(dd - p0) < 0.2*p0));
if isnan(period), period = p0; end

if isfield(opts, 'firstStart')
    cands = opts.firstStart;
else
    % first clean pulse that is followed by another one one period later; the true first step may lie
    % up to 3 periods earlier if it merged with the armed-screen text or was too dim -> try those too
    j = find(abs(diff(segS) - period) < 0.2*period, 1);
    if isempty(j), j = 1; end
    cands = segS(j) - (0:3)*period;
    cands = cands(cands > t(1) - 0.2*period);
end
best = -1; score = zeros(size(cands));
for c = 1:numel(cands)                    % keep the start that matches the most detected pulses
    [tOn_c, det_c] = walk(cands(c), segS, period, nSteps);
    score(c) = sum(det_c);
    if score(c) > best, best = score(c); tOn = tOn_c; detected = det_c; end
end
S.altStarts = cands(score >= best - 1);    % starts that fit almost as well (ambiguous first step)
S.tie = sum(score == best) > 1;
tOff = tOn + onDur;
if segS(end) > tOn(end) + 0.5*period && ~isfield(opts, 'quiet')
    warning('pm_steps: there are pulses after the last expected one - the log may hold more steps than nSteps (%d), or the first pulse was missed (set opts.firstStart).', nSteps);
end

% dark level: samples well inside the gaps
inGap = true(size(t));
for kk = 1:nSteps
    inGap(t > tOn(kk) - 0.15 & t < tOff(kk) + 0.15) = false;
end
inGap = inGap & t > tOn(1) - period & t < tOff(end) + period & Pm < thr;
dark = median(P(inGap & ~isnan(P)));
if isnan(dark), dark = darkEst; end

S.mean = zeros(nSteps,1); S.sd = S.mean; S.se = S.mean; S.n = S.mean;
for kk = 1:nSteps
    wAll = t >= tOn(kk) + opts.trim & t <= tOff(kk) - opts.trim;
    w = wAll & ~isnan(P);
    v = P(w);
    S.n(kk) = numel(v);
    % less than half of the window valid (e.g. the meter overloaded): no reliable value
    if isempty(v) || numel(v) < 0.5*nnz(wAll), S.mean(kk) = NaN; S.sd(kk) = NaN; S.se(kk) = NaN; continue; end
    S.mean(kk) = mean(v) - dark;
    S.sd(kk) = std(v);
    S.se(kk) = std(v)/sqrt(numel(v));
end
% log stopped before the sequence ended: the steps after the last detected pulse cannot be told apart
% from dark tiles, so they are dropped
if tOff(end) > t(end) + 0.5
    lastDet = find(detected, 1, 'last');
    cut = (1:nSteps)' > lastDet;
    S.mean(cut) = NaN; S.sd(cut) = NaN; S.se(cut) = NaN;
    if ~isfield(opts, 'quiet'), warning('pm_steps: the log ends %.0f s before the last expected pulse; the last %d steps (after the last detected pulse) are left out.', tOff(end) - t(end), nnz(cut)); end
end
% overload / invalid stretch (e.g. the meter range exceeded at the end): drop every step after its start
bad = isnan(P); tBad = Inf;
if any(bad)
    nb = movmean(double(bad), max(3, round(3/median(diff(t)))));   % ~3 s window
    kb = find(nb > 0.5, 1);
    if ~isempty(kb), tBad = t(kb) - 1.5; end
end
lost = tOff > tBad;
if any(lost)
    S.mean(lost) = NaN; S.sd(lost) = NaN; S.se(lost) = NaN;
    if ~isfield(opts, 'quiet'), warning('pm_steps: invalid data from t = %.0f s on; the last %d steps are left out.', tBad, nnz(lost)); end
end
S.tOn = tOn + opts.trim; S.tOff = tOff - opts.trim; S.detected = detected;
S.dark = dark; S.period = period; S.onDur = onDur; S.thr = thr; S.trim = opts.trim;
end

function [tOn, detected] = walk(t0, segS, period, nSteps)
% expected pulse times; each detected pulse re-anchors the timing
tOn = zeros(nSteps,1); detected = false(nSteps,1); offset = 0;
for kk = 0:nSteps-1
    tp = t0 + kk*period + offset;
    [dmin, j] = min(abs(segS - tp));
    if ~isempty(dmin) && dmin < 0.3*period
        tOn(kk+1) = segS(j); detected(kk+1) = true;
        offset = segS(j) - (t0 + kk*period);
    else
        tOn(kk+1) = tp;
    end
end
end
