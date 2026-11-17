function C = grey_curve(levels, power, plateauTol)
%GREY_CURVE  Projector grey response from a grey ramp: monotone curve, knee and inverse.
%   C = grey_curve(levels, power, plateauTol)
%   levels  grey levels (0-255) of the ramp steps
%   power   measured power of each step (any unit)
%   plateauTol (default 0.02): all points within this fraction of the maximum, from the first
%           such level upwards, are averaged into one flat plateau (removes plateau noise)
%
%   Same method as the viewer: the points are made non-decreasing with
%   pool-adjacent-violators (noise on the plateau must not create fake slopes),
%   interpolated linearly, extended to 0 at grey 0 and flat above the last point,
%   and normalised to the plateau.
%   C.L(g+1)     relative light at grey g (0..1), g = 0..255
%   C.knee       lowest grey that gives full light (L >= 0.999, as the viewer)
%   C.knee99     lowest grey within 1 % of full light
%   C.inv(q+1)   grey level that gives the fraction q/1000 of full light, q = 0..1000
%   C.pts        [level, pooled power] used for the curve
%   C.lutString  'level:power, ...' for the viewer / expose "grey curve" field (plateau averaged)

[lv, o] = sort(levels(:)); pw = power(:); pw = max(0, pw(o));
ok = isfinite(pw); lv = lv(ok); pw = pw(ok);
if nargin < 3 || isempty(plateauTol), plateauTol = 0.02; end
% plateau: from the first level whose (monotone) value is within plateauTol of the top, average everything above
cm = cummax(pw);
kp = find(cm >= (1 - plateauTol)*max(pw), 1);
pw(kp:end) = mean(pw(kp:end));

% pool adjacent violators
bx = num2cell(lv); bs = pw; bn = ones(size(pw));
i = 2;
while i <= numel(bs)
    if bs(i)/bn(i) < bs(i-1)/bn(i-1)
        bx{i-1} = [bx{i-1}; bx{i}]; bs(i-1) = bs(i-1) + bs(i); bn(i-1) = bn(i-1) + bn(i);
        bx(i) = []; bs(i) = []; bn(i) = [];
        i = max(2, i-1);
    else
        i = i + 1;
    end
end
X = []; Y = [];
for b = 1:numel(bs)
    X = [X; bx{b}]; Y = [Y; repmat(bs(b)/bn(b), numel(bx{b}), 1)]; %#ok<AGROW>
end
top = Y(end);

g = (0:255)';
L = zeros(256,1);
for k = 1:256
    gg = g(k);
    if gg <= X(1)
        if X(1) > 0, L(k) = Y(1)*gg/X(1); else, L(k) = Y(1); end
    elseif gg >= X(end)
        L(k) = top;
    else
        j = find(X >= gg, 1);
        if X(j) > X(j-1), L(k) = Y(j-1) + (Y(j) - Y(j-1))*(gg - X(j-1))/(X(j) - X(j-1)); else, L(k) = Y(j); end
    end
end
L = cummax(L/top);
knee = find(L >= 0.999, 1) - 1;          % same definition as the viewer
knee99 = find(L >= 0.99, 1) - 1;         % within 1 % of full light (plateau noise)

inv = zeros(1001,1);
for q = 0:1000
    f = q/1000;
    if f >= 1, inv(q+1) = knee; continue; end
    j = find(L >= f, 1);                    % first grey with enough light
    if j > 1 && (f - L(j-1)) < (L(j) - f), j = j - 1; end   % take the nearer one
    inv(q+1) = j - 1;
end

C.L = L; C.knee = knee; C.knee99 = knee99; C.inv = inv; C.pts = [X Y];
parts = arrayfun(@(a, b) sprintf('%d:%.1f', round(a), b), lv, pw, 'UniformOutput', false);
C.lutString = strjoin(parts', ', ');
end
