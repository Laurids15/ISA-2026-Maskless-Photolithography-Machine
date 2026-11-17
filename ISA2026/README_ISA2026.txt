ISA2026 - DMD maskless lithography (InFocus IN124 DMD, Stemi 2000-C, M405L3, SU-8 TF 6000.5)
Newest versions, 17 Nov 2026.

maskwriter/         designer.html (draw masks, grid, JSON/PNG export) and expose.html (exposure:
                    own mask, time, greyscale correction on/off, dose helper; W = white in the
                    usable area for power density, Shift+W = whole DMD). Final 32x24 map installed.
test_patterns/      viewer.html (calibration patterns, grey ramp, uniformity probe Q, pattern W),
                    camera.html and the PNG test patterns.
matlab_greyscale/   MATLAB/Octave: grey curve, probe maps (neighbour weights), compare_correction
                    (without | with correction), refine_map; all CSV logs of 10 Nov incl. the
                    corrected 32x24 run Greyscale_highres_1435.csv (refEvery 32).
masks/              mask1 (5x, 2.2 um/px), mask2 (2.5x, 4.4 um/px), mask_scaled_2.5x_4.4um
                    (1 mm pads, 1.5 mm apart, 1 mm legs, 88 um gap, 1 px alignment squares).
calibration_guide/  LaTeX calibration guide (tex, pdf, figures). Written before the final
                    32x24 map: the map/target numbers in expose.html are the current ones.

Key numbers: usable area x 0-896, y 0-768 px; 5x = 2.2 um/px (0.0333 cm2 usable),
2.5x = 4.4 um/px. Target dose last time: 5 s at 0.7 mW (whole DMD, correction on) = 92 mJ/cm2.
Correction: sd 4.4 % -> 1.6 % over the usable area (10 Nov).
