function S = resolve_start(t, P, S, isRef, file)
%RESOLVE_START  Fix an ambiguous first step of a probe run (e.g. corner text on, so the first pulse
%   merges with the text light). With reference tiles the start is chosen for which the reference
%   tiles agree best; without them a warning is given.
if numel(S.altStarts) <= 1, return; end
if any(isRef)
    best = Inf; S0 = S;
    for t0 = S0.altStarts
        Sc = pm_steps(t, P, numel(isRef), struct('firstStart', t0, 'quiet', true));
        rv = Sc.mean(isRef); cv = std(rv)/mean(rv);
        if cv < best, best = cv; S = Sc; end
    end
elseif S.tie
    warning('The first step of %s is ambiguous (corner text on?). Check the trace plot; if the map is shifted by one tile, set the start with pm_steps(..., struct(''firstStart'', t0)).', file);
end
end
