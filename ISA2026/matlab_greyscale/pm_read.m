function [t, P, startText] = pm_read(file)
%PM_READ  Read a Thorlabs Optical Parameter Monitor CSV log (PM100A + S120C).
%   [t, P, startText] = pm_read(file)
%   t          time in seconds from the first sample (from the "Time of day" column)
%   P          power in W. Invalid samples become NaN and are ignored later: the meter's LOW /
%              under-range code (logged as -1.7215E+38 or -3.443E+38), inf, overload codes (1E+43)
%              and unreadable entries. Small negative values (zero-offset noise in the dark) are kept.
%   startText  the "Start of Measurement" text from the header, if present
%
%   Expected data lines:  0, 11/3/2026, 17:05:12.345,4.2161E-06

txt = fileread(file);
startText = '';
s = regexp(txt, 'Start of Measurement\s*,\s*([^\r\n]*)', 'tokens', 'once');
if ~isempty(s), startText = strtrim(s{1}); end

tok = regexp(txt, '^\s*\d+\s*,\s*[^,]*,\s*(\d+):(\d+):([\d.]+)\s*,\s*([^,\r\n]*)', 'tokens', 'lineanchors');
if isempty(tok)
    error('pm_read: no data lines found in %s', file);
end
n = numel(tok);
hh = zeros(n,1); mm = zeros(n,1); ss = zeros(n,1); P = zeros(n,1);
for i = 1:n
    hh(i) = str2double(tok{i}{1});
    mm(i) = str2double(tok{i}{2});
    ss(i) = str2double(tok{i}{3});
    P(i)  = str2double(tok{i}{4});
end
t = hh*3600 + mm*60 + ss;
% midnight wrap
jump = find(diff(t) < -43200);
for j = jump(:)'
    t(j+1:end) = t(j+1:end) + 86400;
end
t = t - t(1);
bad = ~isfinite(P) | abs(P) > 1;          % LOW (-1.7e38/-3.4e38), inf, 1e43 overload codes
P(bad) = NaN;
if any(bad)
    fprintf('%s: %d of %d samples invalid (LOW / overload), ignored (%.1f %%)\n', file, nnz(bad), numel(P), 100*mean(bad));
end
end
