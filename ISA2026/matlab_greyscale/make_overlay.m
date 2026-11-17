function [g, Lg] = make_overlay(mapOut, target, C, W, H)
%MAKE_OVERLAY  Grey level of every DMD pixel, computed exactly as the viewer / expose.html do it.
%   [g, Lg] = make_overlay(mapOut, target, C)
%   mapOut  rows x cols light map (any unit; tile centres spread evenly over the DMD)
%   target  "Target level" in % of the mean of all map values
%   C       grey curve from grey_curve.m
%   g       H x W grey levels;  Lg  H x W relative light let through (C.L(g+1))
if nargin < 4, W = 1024; H = 768; end
[rows, cols] = size(mapOut);
[xx, yy] = meshgrid(0:W-1, 0:H-1);
fx = min(cols-1, max(0, (xx + 0.5)*cols/W - 0.5));
fy = min(rows-1, max(0, (yy + 0.5)*rows/H - 0.5));
vpix = interp2(0:cols-1, 0:rows-1, mapOut, fx, fy, 'linear');
rel = 100*vpix/mean(mapOut(:));
c = min(1, target./rel);
g = reshape(C.inv(round(c*1000) + 1), H, W);
Lg = reshape(C.L(g + 1), H, W);
end
