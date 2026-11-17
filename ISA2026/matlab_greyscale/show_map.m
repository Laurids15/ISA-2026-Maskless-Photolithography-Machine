function show_map(M, ttl, clim, usableMask, fmt)
%SHOW_MAP  Tile map as a colour image with the value written in every tile.
%   show_map(M, ttl, clim, usableMask, fmt)
%   usableMask (optional): logical, same size as M; tiles outside it are outlined.
if nargin < 3 || isempty(clim), clim = [min(M(:)) max(M(:))]; end
if nargin < 5, fmt = '%.0f'; end
[r, c] = size(M);
imagesc(1:c, 1:r, M); axis image; caxis(clim); colorbar;
n = 64; a = linspace(0, 1, n/2)';
cmap = [[0.15+0.85*a, 0.35+0.65*a, 0.75+0.25*a]; [1-0.25*a(2:end), 1-0.85*a(2:end), 1-0.85*a(2:end)]; [0.75 0.15 0.15]];
colormap(gca, cmap);
hold on;
fs = max(4, min(7, round(150/c)));         % smaller numbers on fine grids
for i = 1:r
    for j = 1:c
        if isnan(M(i,j))                   % no data: grey tile
            fill([j-0.5 j+0.5 j+0.5 j-0.5], [i-0.5 i-0.5 i+0.5 i+0.5], [0.6 0.6 0.6], 'EdgeColor', 'none');
            continue;
        end
        text(j, i, sprintf(fmt, M(i,j)), 'HorizontalAlignment', 'center', 'FontSize', fs);
    end
end
if nargin >= 4 && ~isempty(usableMask)
    for i = 1:r
        for j = 1:c
            if ~usableMask(i,j)
                plot([j-0.5 j+0.5 j+0.5 j-0.5 j-0.5], [i-0.5 i-0.5 i+0.5 i+0.5 i-0.5], 'k-', 'LineWidth', 0.5);
            end
        end
    end
end
hold off;
title(ttl, 'Interpreter', 'none'); xlabel('tile column (screen x \rightarrow)'); ylabel('tile row (screen y \downarrow)');
end
