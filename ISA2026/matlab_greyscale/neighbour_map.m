function M = neighbour_map(V, valid, usableMask, XC, YC, sigma)
%NEIGHBOUR_MAP  Correction map from the tile values with light smoothing by their neighbours.
%   M = neighbour_map(V, valid, usableMask, XC, YC, sigma)
%   V           rows x cols tile values (e.g. % of mean)
%   valid       tiles with good data (logical, same size)
%   usableMask  tiles inside the usable area
%   XC, YC      tile centres (DMD px), used for tiles outside the usable area
%   sigma       width of the Gaussian weights in tiles (default 0.6):
%               weight = exp(-d^2/(2 sigma^2)), d = distance in tiles.
%               sigma 0.6 -> the tile itself ~45 %, each side neighbour ~11 %, each diagonal ~3 %.
%               sigma 0 = no smoothing (only gaps filled).
%   Every usable tile becomes the weighted mean of the valid tiles around it (weights renormalised
%   at edges and next to missing tiles). Usable tiles without data get the weighted mean of their
%   valid neighbours (the window grows until it finds some). Tiles outside the usable area copy the
%   nearest usable tile (no extrapolation).
if nargin < 6 || isempty(sigma), sigma = 0.6; end
[rows, cols] = size(V);
ok = valid & usableMask & isfinite(V);
M = nan(rows, cols);
for i = 1:rows
    for j = 1:cols
        if ~usableMask(i,j), continue; end
        k = max(1, ceil(2*sigma));
        while true
            ii = max(1, i-k):min(rows, i+k); jj = max(1, j-k):min(cols, j+k);
            [JJ, II] = meshgrid(jj, ii);
            d2 = (II - i).^2 + (JJ - j).^2;
            if sigma > 0, w = exp(-d2/(2*sigma^2)); else, w = double(d2 == 0); end
            if ~ok(i,j), w = exp(-d2/(2*max(sigma, 0.6)^2)); end      % gap: interpolate from neighbours
            w = w.*ok(ii, jj);
            if sum(w(:)) > 0 || k > max(rows, cols), break; end
            k = k + 1;
        end
        vv = V(ii, jj); vv(~ok(ii, jj)) = 0;
        M(i,j) = sum(w(:).*vv(:))/sum(w(:));
    end
end
idxU = find(usableMask);
for q = find(~usableMask)'
    [~, j] = min((XC(idxU) - XC(q)).^2 + (YC(idxU) - YC(q)).^2);
    M(q) = M(idxU(j));
end
end
