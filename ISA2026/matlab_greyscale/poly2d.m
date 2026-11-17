function [Z, coef, terms] = poly2d(X, Y, Zdata, order, Xeval, Yeval)
%POLY2D  Least-squares 2-D polynomial with all terms X^i*Y^j, i + j <= order.
%   [Z, coef, terms] = poly2d(X, Y, Zdata, order, Xeval, Yeval)
%   X, Y, Zdata   fit points (vectors)
%   Xeval, Yeval  where to evaluate the fitted surface (any shape; default = X, Y)
%   terms(k,:) = [i j] for coef(k)
%   Order 3 has 10 terms: 1, Y, Y^2, Y^3, X, XY, XY^2, X^2, X^2Y, X^3.

if nargin < 5, Xeval = X; Yeval = Y; end
terms = zeros(0, 2);
for i = 0:order
    for j = 0:order-i
        terms(end+1, :) = [i j]; %#ok<AGROW>
    end
end
A = zeros(numel(X), size(terms,1));
for k = 1:size(terms,1)
    A(:,k) = X(:).^terms(k,1) .* Y(:).^terms(k,2);
end
coef = A \ Zdata(:);
Z = zeros(size(Xeval));
for k = 1:size(terms,1)
    Z = Z + coef(k) * Xeval.^terms(k,1) .* Yeval.^terms(k,2);
end
end
