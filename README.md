# ISA-2026-Maskless-Photolithography-Machine

This repository contains the software, calibration data, documentation, masks, and test patterns for a student-built maskless photolithography machine developed at SDU during an ISA project in 2026.

The machine uses an InFocus IN124 DMD, a Stemi 2000-C microscope, an M405L3 405 nm UV LED, and SU-8 TF 6000.5 photoresist. The DMD projects binary or greyscale patterns directly onto the wafer, removing the need for a physical photolithography mask.

## What this repository provides

- Browser-based mask design, mask viewing, camera control, and exposure tools.
- Calibration patterns for resolution, focus, dose, illumination uniformity, and alignment.
- A calibration guide covering the optical setup and measurement procedure.
- MATLAB/Octave scripts for grey-response analysis, power-meter probe analysis, flat-field correction, and correction-map refinement.
- Example masks, measurement logs, processed results, and the final correction data used by the exposure tools.

## Quick start

1. Open [`ISA2026/test_patterns/viewer.html`](ISA2026/test_patterns/viewer.html) in Chrome or Edge on the projector computer. Use the calibration grid, black field, dose ladder, and resolution patterns to verify the setup.
2. Open [`ISA2026/maskwriter/designer.html`](ISA2026/maskwriter/designer.html) to draw a mask on the 1024 x 768 DMD grid. Export a PNG or send the design directly to the exposure page.
3. Open [`ISA2026/maskwriter/expose.html`](ISA2026/maskwriter/expose.html), load the mask, select the exposure time, and expose it using the armed-screen workflow.
4. For new calibration data, place the power-meter CSV logs in [`ISA2026/matlab_greyscale`](ISA2026/matlab_greyscale), update the settings at the top of the relevant MATLAB scripts, and run `run_all.m`.

The detailed operating instructions are in the [maskwriter documentation](ISA2026/maskwriter/README.txt), [test-pattern documentation](ISA2026/test_patterns/README.txt), [MATLAB analysis documentation](ISA2026/matlab_greyscale/README.txt), and [calibration guide](ISA2026/calibration_guide/calibration_guide.pdf).

## Important operating requirements

- The projector output must be exactly 1024 x 768 pixels at device pixel ratio 1. Use 100% display scaling, 100% browser zoom, and fullscreen mode. Any resampling changes the projected feature sizes.
- White pixels represent lit DMD mirrors. With the negative SU-8 process, lit areas are the areas that remain after development.
- At 5x magnification, the nominal scale is 2.2 um per DMD pixel. At 2.5x, it is 4.4 um per pixel. Confirm the actual scale with the calibration grid.
- The default usable area is x = 0-896 and y = 0-768. The exposure page can black out the unused part of the DMD and calculate dose from the usable area.
- Keep the UV LED off, or use the green filter, while previewing patterns and focusing. Use the low-intensity focus procedure in the test-pattern documentation before exposing a fresh area of the wafer.

## Recommended calibration workflow

1. Verify pixel scale and distortion with the calibration grid.
2. Check for stray light with the black-field pattern at an increased dose.
3. Find a suitable working dose with the dose ladder.
4. Measure line gaps, resolution, field uniformity, and focus with the test patterns.
5. Run the grey ramp and uniformity probe when the optics, projector settings, or alignment change.
6. Use the MATLAB scripts to generate a correction map and grey curve, then paste the results into the exposure/viewer settings.

The repository includes a final 32 x 24 power-meter correction map and measured grey curve in the web tools. The recorded 10 November 2026 measurements reduced usable-area variation from about 4.4% standard deviation without correction to about 1.6% with correction. These values are reference results, not a substitute for recalibration after changing the optical setup.

## Use of AI

Parts of this repository were developed with the help of generative AI (Claude, Anthropic):

- **Web tools** (`maskwriter/designer.html`, `maskwriter/expose.html`, `test_patterns/viewer.html`,
  `test_patterns/camera.html`) and the test patterns
- **MATLAB scripts** for the power-meter analysis, grey curve and greyscale correction (`matlab_greyscale/`)
- **Documentation**: drafts of the user guides (quick guide, calibration guide, assembly guide) in LaTeX

The setup, the measurements and the experiments were done by the authors. All AI-assisted code and text was
reviewed, tested on the setup and edited by the authors, who take full responsibility for the content.
Calibration values and results in the guides come from our own measurements.


## Repository contents

### Root files

- [Ballast bypass schematic](BallastBypassSchematic.pdf)
- [Ballast emulator](ballast_emu.cpp)
- [Camera interface](camera.html)
- [Mask designer](designer.html)
- [Exposure interface](expose.html)
- [Mask viewer](viewer.html)

### ISA2026 documentation

- [ISA2026 documentation](ISA2026/README_ISA2026.txt)

#### Calibration guide

- [Calibration guide PDF](ISA2026/calibration_guide/calibration_guide.pdf)
- [Calibration guide LaTeX source](ISA2026/calibration_guide/calibration_guide.tex)
- [Dose ladder figure](ISA2026/calibration_guide/figures/dose_ladder.jpg)
- [Grey ramp figure](ISA2026/calibration_guide/figures/grey_ramp.png)
- [Probe maps figure](ISA2026/calibration_guide/figures/probe_maps.png)
- [Siemens star figure](ISA2026/calibration_guide/figures/siemens_star.jpg)
- [Uniformity map overlay](ISA2026/calibration_guide/figures/uniformity_map_overlay.png)

#### Masks

- [Mask 1: 5x, 2.2 um per pixel](ISA2026/masks/mask1_5x_2.2um_px.png)
- [Mask 2: 2.5x, 4.4 um per pixel](ISA2026/masks/mask2_2.5x_4.4um_px.png)
- [Scaled mask metadata](ISA2026/masks/mask_scaled_2.5x_4.4um.json)
- [Scaled mask: 2.5x, 4.4 um per pixel](ISA2026/masks/mask_scaled_2.5x_4.4um_px.png)
- [Scaled mask preview](ISA2026/masks/mask_scaled_preview.png)
- [Masks preview](ISA2026/masks/masks_preview.png)

#### Maskwriter

- [Maskwriter documentation](ISA2026/maskwriter/README.txt)
- [Mask designer](ISA2026/maskwriter/designer.html)
- [Exposure interface](ISA2026/maskwriter/expose.html)
- [Mask 1: 5x, 2.2 um per pixel](ISA2026/maskwriter/mask1_5x_2.2um_px.png)
- [Mask 2: 2.5x, 4.4 um per pixel](ISA2026/maskwriter/mask2_2.5x_4.4um_px.png)

#### MATLAB greyscale analysis

- [Greyscale high-resolution data](ISA2026/matlab_greyscale/Greyscale_highres_1435.csv)
- [Greyscale analysis documentation](ISA2026/matlab_greyscale/README.txt)
- [Grey ramp analysis](ISA2026/matlab_greyscale/analyze_grey_ramp.m)
- [Probe analysis](ISA2026/matlab_greyscale/analyze_probe.m)
- [Correction comparison](ISA2026/matlab_greyscale/compare_correction.m)
- [Grey curve](ISA2026/matlab_greyscale/grey_curve.m)
- [Grey scale data](ISA2026/matlab_greyscale/grey_scale.csv)
- [Overlay generation](ISA2026/matlab_greyscale/make_overlay.m)
- [Neighbour map](ISA2026/matlab_greyscale/neighbour_map.m)
- [Photometer reader](ISA2026/matlab_greyscale/pm_read.m)
- [Photometer steps](ISA2026/matlab_greyscale/pm_steps.m)
- [2D polynomial helper](ISA2026/matlab_greyscale/poly2d.m)
- [Probe tiles](ISA2026/matlab_greyscale/probe_tiles.m)
- [Raw low-band high-resolution data](ISA2026/matlab_greyscale/rawtest_lowband_highres.csv)
- [Raw warmed-up low-band 5x data](ISA2026/matlab_greyscale/rawtest_warmedup_lowband_5x.csv)
- [Map refinement](ISA2026/matlab_greyscale/refine_map.m)
- [Start-point resolution](ISA2026/matlab_greyscale/resolve_start.m)
- [Run all analysis](ISA2026/matlab_greyscale/run_all.m)
- [Map display](ISA2026/matlab_greyscale/show_map.m)
- [Warmed-up low-band correction data](ISA2026/matlab_greyscale/warmedup_lowband_correction_1.csv)
- [Warmed-up low-band high-resolution data](ISA2026/matlab_greyscale/warmedup_lowband_highres_32x24.csv)

##### MATLAB example results

- [Correction comparison](ISA2026/matlab_greyscale/example_results/compare_correction.png)
- [Correction comparison: 1435, 32x24](ISA2026/matlab_greyscale/example_results/compare_correction_1435_32x24.png)
- [Correction overlay: 1024x768](ISA2026/matlab_greyscale/example_results/correction_overlay_1024x768.png)
- [Final correction overlay: 1024x768](ISA2026/matlab_greyscale/example_results/final_correction_overlay_1024x768.png)
- [Final map: 32x24 viewer format](ISA2026/matlab_greyscale/example_results/final_map_32x24_for_viewer.txt)
- [Final refined map](ISA2026/matlab_greyscale/example_results/final_refine_map.png)
- [Grey curve: viewer format](ISA2026/matlab_greyscale/example_results/grey_curve_for_viewer.txt)
- [Grey ramp curve](ISA2026/matlab_greyscale/example_results/grey_ramp_curve.png)
- [Grey ramp trace](ISA2026/matlab_greyscale/example_results/grey_ramp_trace.png)
- [Map: 32x24 viewer format](ISA2026/matlab_greyscale/example_results/map_32x24_for_viewer.txt)
- [Option 3-run map: 32x24 viewer format](ISA2026/matlab_greyscale/example_results/option_3run_map_32x24_for_viewer.txt)
- [Option 3-run refined map](ISA2026/matlab_greyscale/example_results/option_3run_refine_map.png)
- [Probe drift](ISA2026/matlab_greyscale/example_results/probe_drift.png)
- [Probe maps](ISA2026/matlab_greyscale/example_results/probe_maps.png)
- [Probe overlay](ISA2026/matlab_greyscale/example_results/probe_overlay.png)
- [Probe trace](ISA2026/matlab_greyscale/example_results/probe_trace.png)

#### Test patterns

- [Test pattern documentation](ISA2026/test_patterns/README.txt)
- [Camera interface](ISA2026/test_patterns/camera.html)
- [Windows camera dialog launcher](ISA2026/test_patterns/cam_dialog_windows.bat)
- [Dose ladder overview](ISA2026/test_patterns/dose_ladder_overview.png)
- [Resolution ladder](ISA2026/test_patterns/01_resolution_ladder.png)
- [Calibration grid](ISA2026/test_patterns/02_calibration_grid.png)
- [Features](ISA2026/test_patterns/03_features.png)
- [Siemens star edges](ISA2026/test_patterns/04_siemens_star_edges.png)
- [White field](ISA2026/test_patterns/05_white.png)
- [Black field](ISA2026/test_patterns/06_black.png)
- [Centred ladder](ISA2026/test_patterns/07_centred_ladder.png)
- [Field map](ISA2026/test_patterns/08_field_map.png)
- [Defocus dots](ISA2026/test_patterns/09_defocus_dots.png)
- [Horizontal pupil](ISA2026/test_patterns/10_pupil_horizontal.png)
- [Vertical pupil](ISA2026/test_patterns/11_pupil_vertical.png)
- [Single-dot NA pattern](ISA2026/test_patterns/12_na_single_dot.png)
- [Line gaps](ISA2026/test_patterns/13_line_gaps.png)
- [Focus target](ISA2026/test_patterns/14_focus_target.png)
- [Parfocal split, vertical](ISA2026/test_patterns/15_parfocal_split_v.png)
- [Parfocal split, horizontal](ISA2026/test_patterns/16_parfocal_split_h.png)
- [Test-pattern viewer](ISA2026/test_patterns/viewer.html)

##### Dose ladder patterns

- [Dose ladder step 1](ISA2026/test_patterns/dose_ladder/step_1.png)
- [Dose ladder step 2](ISA2026/test_patterns/dose_ladder/step_2.png)
- [Dose ladder step 3](ISA2026/test_patterns/dose_ladder/step_3.png)
- [Dose ladder step 4](ISA2026/test_patterns/dose_ladder/step_4.png)
- [Dose ladder step 5](ISA2026/test_patterns/dose_ladder/step_5.png)
- [Dose ladder step 6](ISA2026/test_patterns/dose_ladder/step_6.png)
- [Dose ladder step 7](ISA2026/test_patterns/dose_ladder/step_7.png)
- [Dose ladder step 8](ISA2026/test_patterns/dose_ladder/step_8.png)

##### Uniformity probe patterns

- [Probe 11: top left](ISA2026/test_patterns/uniformity_probe/probe_11_top_left.png)
- [Probe 12: top centre](ISA2026/test_patterns/uniformity_probe/probe_12_top_centre.png)
- [Probe 13: top right](ISA2026/test_patterns/uniformity_probe/probe_13_top_right.png)
- [Probe 21: middle left](ISA2026/test_patterns/uniformity_probe/probe_21_mid_left.png)
- [Probe 22: middle centre](ISA2026/test_patterns/uniformity_probe/probe_22_mid_centre.png)
- [Probe 23: middle right](ISA2026/test_patterns/uniformity_probe/probe_23_mid_right.png)
- [Probe 31: bottom left](ISA2026/test_patterns/uniformity_probe/probe_31_bot_left.png)
- [Probe 32: bottom centre](ISA2026/test_patterns/uniformity_probe/probe_32_bot_centre.png)
- [Probe 33: bottom right](ISA2026/test_patterns/uniformity_probe/probe_33_bot_right.png)
