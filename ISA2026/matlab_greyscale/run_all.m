%% RUN_ALL  Complete greyscale calibration from the logs of 10 Nov 2026
% 1. grey ramp            -> grey curve                       (analyze_grey_ramp.m)
% 2. probe, no correction -> map (tiles + neighbour smoothing), overlay (analyze_probe.m, 32 x 24 run)
% 3. probe, correction on -> before/after comparison           (compare_correction.m: 32 x 24 raw run vs
%                           Greyscale_highres_1435.csv, final map on, reference every 32 tiles)
% 4. several probes       -> map: mean of the runs, neighbour smoothing (refine_map.m: both raw 32 x 24 runs
%                           + the corrected run divided by the overlay that was on)
% Edit the settings block at the top of each script for new logs. Each script can also be run alone
% (run 1 before 2, and 2 before 4: they use results/grey_curve.mat and results/correction_overlay_1024x768.png).
% Each script starts with "clear", so it is run with run() here.
run('analyze_grey_ramp.m');   close all;
run('analyze_probe.m');       close all;
run('compare_correction.m');  close all;
run('refine_map.m');          close all;
