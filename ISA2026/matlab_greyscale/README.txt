MATLAB: GREYSCALE / UNIFORMITY ANALYSIS AND CORRECTION
=====================================================
QUICK START: put this folder on the MATLAB path (or cd into it) and run  run_all
All maps are made from the tile values with light neighbour smoothing (neighbour_map.m), not from a
polynomial fit (the 3rd-order fit is only printed for reference). It analyses the logs of 10 Nov 2026:
  grey_scale.csv                       grey ramp, 32 levels 255..50, 1 s on / 0.5 s off
  rawtest_warmedup_lowband_5x.csv      probe 16 x 12 WITHOUT correction, reference tile every 16 tiles
  warmedup_lowband_correction_1.csv    the same probe WITH the correction on (map of 10:00, target 91)
  warmedup_lowband_highres_32x24.csv   probe 32 x 24, 2 s on, reference every 16 tiles, correction OFF
                                       (meter overloaded after 30 min: the last 43 steps are left out)
  rawtest_lowband_highres.csv          probe 32 x 24, 1.5 s on, reference every 16 tiles, correction OFF, complete
All three: LED warmed up, PM100A low bandwidth, averaging 30, fixed 19 uW range (probe), zeroed dark.
Results go to results/ and results_refined/; example_results/ holds the same output as a reference (final_* = the map now in expose.html / viewer).
For new logs, change the settings block at the top of each script.

Works in MATLAB R2016b or newer (no toolboxes) and in GNU Octave.
Put the power-meter CSV logs in this folder, edit the settings block at the top of each
script, and run them. Results go to the subfolder results/.

1) analyze_grey_ramp.m   - grey ramp (test viewer key R) -> projector grey response
   settings: file, levels (the "Grey ramp levels" of the viewer, in order)
   prints a table (power, % of full light), the knee, and the "level:power" string for
   the viewer / expose.html; saves results/grey_curve.mat (used by step 2) and
   grey_ramp_trace.png (averaging windows on the log), grey_ramp_curve.png.

2) analyze_probe.m       - probe (test viewer key Q) -> field map -> 3rd-order fit -> correction
   settings: file, cols/rows (probe grid, tiles covering 100 %), refEvery (drift reference
   tile setting of the viewer, 0 = off), usable area, fitOrder (3), target (86 %),
   overlayUsed (PNG of the overlay if the probe ran WITH the correction on, '' otherwise)
   - averages every tile (dark subtracted); dim tiles are taken at their predicted time
   - divides out the source drift if reference tiles were used
   - fits I(X,Y) = sum a_ij X^i Y^j, i+j <= 3 (10 terms) to the tiles in the usable area,
     X = (x - 448)/448, Y = (y - 384)/384; prints the residual for orders 1-4 and the coefficients
   - tiles outside the usable area get the value of the nearest usable tile (no extrapolation)
   - mapMode 'fit' (default) = smooth polynomial map; 'tiles' = tile values with light 3 x 3
     smoothing, for fine grids such as 32 x 24 (tiles without data use the fit)
   - steps after the meter overloads, and windows with less than half valid samples, are left out
   - computes the grey overlay exactly like the viewer: bilinear map -> rel = 100*v/mean(map),
     c = min(1, target/rel), grey = inverse of the measured grey curve
   outputs: results/map_16x12_for_viewer.txt (paste into the correction-map field, set the same
   target), correction_overlay_1024x768.png (grey level per DMD pixel), probe_result.mat,
   probe_trace.png, probe_maps.png (measured / fit / residual / predicted), probe_overlay.png,
   probe_drift.png (with reference tiles).

3) compare_correction.m  - effect of the correction, measured only (no predictions)
   settings: fileBefore (probe WITHOUT correction), fileAfter (probe WITH the correction on),
   cols/rows, refEvery for each run, usable area, sigma, colour scale
   one figure, three maps on the same colour scale (deviation from the mean of the usable area):
   without correction | its neighbour-smoothed map | with correction; prints min..max, sd, within-row
   sd (free of slow LED drift), tile noise and the mean tile power of both runs.
   Run both probes with the same grid and time per tile, corner text off.

4) refine_map.m         - correction map from SEVERAL runs of the same grid (default: the two 32 x 24 runs)
   settings: rawFiles (probes without correction), corrFiles + corrOverlay (probes with the correction
   on and the overlay PNG that was on), refEvery, grid, sigma, target ([] = auto)
   every run gives an estimate of the field without correction (corrected run / overlay); they are
   averaged tile by tile and lightly smoothed by the neighbours (neighbour_map.m). Prints how well the
   runs agree, writes the map, the overlay and refine_map.png to results_refined/.

MAP FROM THE NEIGHBOURS (default): analyze_probe.m (mapMode 'neighbours') and refine_map.m make the map
from the tile values, each tile replaced by a Gaussian-weighted mean of itself and its neighbours
(sigma 0.6 tiles: itself ~45 %, side neighbours ~11 % each, diagonals ~3 %). Gaps are filled from the
neighbours. The 3rd-order fit is still printed for reference; mapMode 'fit' uses it as the map.

Helper functions: neighbour_map.m (neighbour-weighted map), make_overlay.m (grey overlay exactly as the viewer), probe_tiles.m (tile powers of one probe run, drift reference), pm_read.m (reads the Optical Parameter Monitor CSV), pm_steps.m (finds and
averages the pulses), grey_curve.m (monotone curve, plateau, inverse), poly2d.m (2-D polynomial
least squares), show_map.m (tile map with numbers).

Tested on the logs of 3 Nov: greyscale1730.csv (knee at grey 160, 1.8 %/level below it) and
PowerDistr1705.csv (usable area 84-124 %, order-3 residual 2.06 %, overlay grey 146-160,
predicted 95-109 % / sd 2.1 % with correction, 87 % of the light kept). The overlay agrees with
the one the viewer computes to within 1 grey level.
Tip: switch the corner text off (H) during probe and ramp runs.

UPDATE 10 Nov, 15:00 run (Greyscale_highres_1435.csv, final map ON, 32 x 24, 0.6 s on / 0.3 s off,
reference tile after every 32 tiles = 793 pulses):
- usable area: 4.4 % sd without correction -> 1.6 % sd with it (-4.7 .. +4.1 %);
  the runs themselves differ by 1.5-1.9 % sd, so this is at the reproducibility limit.
- refEvery MUST match the viewer setting: with 16 instead of 32 the tiles slip one place per row.
- pm_steps: short pulses are trimmed less (20 % of the on-time, min 0.08 s; was always 0.25 s,
  which left no samples in a 0.6 s pulse), and steps after the end of the log are dropped.
- refine_map now takes the reference interval per run (rawRef, corrRef) and includes the 15:00 run.
  The 3-run map (example_results/option_3run_*) is expected to give 1.0-1.3 % - no clear gain over
  the installed final map, so expose.html / viewer.html keep the final map.
