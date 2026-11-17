TEST PATTERNS - MASKLESS LITHOGRAPHY (Stemi 2000-C, DMD in the camera-port image plane)
====================================================================================
All files: 1024 x 768 px, strictly binary (0 and 255 only), native for the InFocus IN124 DMD.
The viewer generates every pattern itself, so the fill can be chosen freely. The PNG files in
this folder are the same patterns at the default 80 % fill. Any other fill can be downloaded
from the menu (PNG button next to each pattern).

USE viewer.html
---------------
Open viewer.html in a browser on the projector output, press F for fullscreen.
The menu checks that the window is exactly 1024 x 768 at devicePixelRatio 1
(display scaling 100 %, browser zoom 100 %). Otherwise every pixel is resampled.

The menu itself is projected. Keep the UV LED off (or the green FBH550-40 filter in)
while the menu is open.

Workflow:
  1. Set exposure time, dose-ladder step time, delay, PATTERN FILL and corner-text position.
  2. Press a pattern key (or click it). The screen goes BLACK ("armed") with a few lines
     of status text in the chosen corner.
  3. Put the UV in, press SPACE. After the delay (default 2 s, lets vibrations settle)
     the pattern is shown for exactly the set time, then the screen goes black again.
     A beep marks start and end. The result (set and measured time) is shown in the
     corner text and written to the session log in the menu.
  4. Change pattern and time directly from the armed screen. No need to go back to the menu.

Keys on the armed screen:
  SPACE           start exposure
  ESC             abort a running exposure immediately / back to the menu
  Up / Down       time +-1 s      PgUp / PgDn  +-10 s      Left / Right  +-0.1 s
  T               type a time, ENTER to set, ESC to cancel
  P               type a fill in percent (70-100), ENTER to set
  M               dose ladder: type the base (minimum) time all cells get first
  + / -           fill +-5 %
  V               preview the pattern while the key is held (UV off / green filter in!)
  O               FOCUS MODE: pattern stays on until O or ESC; the on-time goes in the log
  1-9 A B C L G D change pattern
  H               hide / show the corner text
  S               sound on / off
  F               fullscreen

Timing: the pattern is switched on and off on display frames, so the resolution is one
frame (about 17 ms at 60 Hz). The measured time is reported after every exposure.

Corner text: it is drawn in the outer band of the screen (inside the area above ~85 % fill), and it IS
projected. With the UV on while armed it exposes that corner of the wafer. Put it in the
corner that the housing blocks, or switch it off with H.

SCALE ON THE WAFER
------------------
Nominal 2.2 um/px at 5x zoom (10.8 um DMD pixel / 4.9). Calibrate with pattern 02.
  Full field      1024 x 768 px  = about 2.25 x 1.7 mm
Optical resolution of the Stemi at 5x is roughly 3.5-7 um, so single pixels are below
what the optics can resolve. Expect the smallest reliable features at roughly 5-10 um.

LAYOUT AND FILL
---------------
Patterns marked "fill" (01, 03, 04, 13 and the dose ladder; 07 only uses it for the
crosshair) are drawn inside a centred area of FILL % of the screen in each direction,
70-100 %, default 80 %. L-shaped marks show the corners of the area; the small square
inside the top-left mark gives the orientation.
  70 %   717 x 538 px   about 1.6 x 1.2 mm
  80 %   819 x 614 px   about 1.8 x 1.35 mm
  90 %   922 x 691 px   about 2.0 x 1.5 mm
 100 %  1024 x 768 px   about 2.25 x 1.7 mm
Line widths, gaps and squares are always the same exact pixel sizes. Only the layout grows
with the fill: longer lines, larger patches, a larger Siemens star, larger dose cells.
Patterns used to judge uniformity or the whole field (02, 05, 06, 08-12) always use the
full screen.
Above about 85 % fill the corner text of the armed screen lies inside the pattern area.

THE PATTERNS
------------
01_resolution_ladder      fill
    Dense vertical lines, dense horizontal lines, isolated lines. Width 1-16 px.
    The finest group where lines and spaces are still separate is the resolution limit.
    Dense vs isolated shows the proximity effect.

02_calibration_grid       full field
    Cross every 64 px with 1 px arms, plus isolated 1 px dots. Measures the real
    um/px, distortion and fall-off towards the corners. Expose this first.

03_features               fill
    Isolated squares and square arrays, 90 deg elbows, line ends, crosses, duty cycles.
    Corner rounding and line-end shortening.

04_siemens_star_edges     fill
    Siemens star, 36 spokes. Resolution = 2*pi*r / 72 where the spokes merge.
    Edge blocks at 0, 5, 45 and 95 deg (5 deg slanted edge = ISO 12233 MTF method).

05_white / 06_black       full field
    Uniformity and contrast. Expose 06 at 10x the normal dose: if anything develops,
    there is a stray-light problem.

W  17 white usable area   usable area (viewer key W, no PNG)
    White only inside the usable area (default x 0-896). Use it with the power meter for the
    power density where you expose: choose "lit area = usable area" next to the power box,
    and the dose text uses power / 0.0333 cm2 instead of the full field 0.0381 cm2.

07_centred_ladder         centre
    Compact ladder 1-10 px in the middle of the field. Pure on-axis resolution.

08_field_map              full field
    The same block at 9 places (NW N NE / W C E / SW S SE). Compare centre with the
    corners in one exposure.

09_defocus_dots           full field
    16 x 16 px dots in the centre and 72 px from each corner. Defocus test: the blurred
    dots show the illumination filling the pupil. All five should be round and equal.

10_pupil_horizontal / 11_pupil_vertical / 12_na_single_dot
    Two dots 512 px apart / one dot, 32 px diameter. Pupil position and NA:
    a = z * L0 / (L - L0),   NA = (D2 - D1) / (2 * dz).

13_line_gaps              fill   (key L)
    Lines exactly 1 px wide, 5 per group, gap 1-14 px between them
    (2.2-30.8 um nominal at 5x). Top half vertical lines, bottom half horizontal lines,
    plus one isolated 1 px line (ISO) of each orientation.
    Big number = gap in px, small number = gap in um at 2.2 um/px.
    Read off the smallest gap where the 5 lines are still separate, in both directions.

dose_ladder/step_1..8     fill   (key D)
    Dose ladder in one session. The viewer shows step 1 to 8 automatically, each for the
    set step time t, with 0.4 s black in between. Cell n is lit in steps 1..n and gets
    n x t. Each cell contains dense V and H lines 1-8 px, squares 1-8 px, isolated
    1-3 px lines and two 1 px line pairs (gap 2 and 4 px).
    The index dots (n dots above each cell) and the frame around the block are lit in
    ALL steps, so every cell can be identified even if the lowest doses do not develop.
    Example: t = 10 s gives 10, 20, ... 80 s.
    BASE TIME: set "Dose ladder, base time for all cells" (or press M on the armed screen).
    Step 1, where all cells are lit, is then shown for base + t. Cell n gets base + n x t.
    Example: base 20 s, t = 10 s gives 30, 40, ... 100 s. Use it to start the ladder
    just below the expected threshold dose instead of at zero.

14_focus_target            centre, small   (key G)
    Small Siemens star (r = 48 px) with 1 px lines, gap 1-3 px, vertical (left) and
    horizontal (right), plus crosshair arms. About 0.75 x 0.55 mm at 5x, so only a small
    area is pre-exposed while focusing.

FOCUSING AT LOW INTENSITY
-------------------------
1. Turn the LED down to about 0.01 mW on the sample (all white, power meter at 405 nm).
   Enter that value under "Measured power on sample" in the menu; the log then shows
   the dose of every exposure and every focus view.
2. Arm 14 (G), press O. Turn the focus knob through best focus in both directions,
   note where the 1 px gap-1 lines and the star centre blur, and set the middle.
   The criterion is the projected pattern being sharp on the wafer.
3. Press O to switch off. Move the wafer sideways to a fresh area (do not touch focus),
   turn the LED up and expose.
At 0.01 mW (about 0.26 mW/cm2) focusing for 10 s gives about 2.6 mJ/cm2 on the target
area, 1 min gives about 16 mJ/cm2. Focus on an area you do not need, or keep it short.

RECOMMENDED ORDER
-----------------
1. 02 calibration grid     -> um/px, distortion
2. 06 black at 10x dose    -> stray light
3. dose ladder (D)         -> working dose
4. 13 line gaps            -> smallest gap between 1 px lines, V and H
5. 07 centred ladder       -> on-axis resolution limit
6. 08 field map            -> how much of the field is usable
7. 01, 04, 03              -> full ladder, Siemens star/MTF, feature fidelity

WINDOWS
-------
viewer.html and camera.html work the same in Chrome or Edge on Windows. Set display scaling
to 100 % and the projector to 1024 x 768 (extended desktop).
camera.html can set exposure, focus, white balance, sharpness and zoom. Gain, backlight
compensation, power-line frequency and Logitech "Low Light Compensation" are set in the
driver dialog: run cam_dialog_windows.bat (needs ffmpeg: winget install Gyan.FFmpeg) BEFORE
starting camera.html. The camera LED cannot be switched off on Windows: cover it with black tape.
On Windows the exposure time usually moves in steps of 2x (e.g. 15.6 / 31.3 / 62.5 ms);
check the value shown top right in camera.html.

CUSTOM IMAGES (key U)
---------------------
Load any image under "Custom image" in the viewer menu. It is shown 1:1 and centred,
thresholded at 128 (white = mirror ON). 1024 x 768 PNG files give exact placement.
Press U to arm it; timer, delay and dose log work as for the other patterns.
fun/ holds three just-for-fun 1024 x 768 masks (outline, filled, tiled size series).
SU-8 is negative: lit (white) areas stay after development.

15_parfocal_split_v / 16_parfocal_split_h   (keys K / J)
    Half the field white, fine 1 px lines and a small star right next to the split.
    Used to make the camera parfocal with the projection without any z read-out:
    put an old developed pattern under the white half, ROI marker 1 on the old pattern
    and marker 2 on the projected lines, both close to the split. Then alternate:
      a) turn the focus knob until marker 2 (projected lines) peaks,
      b) move the camera in the tube until marker 1 (old pattern) peaks.
    Each round halves the error; after 3-4 rounds both peak together and the camera
    is parfocal. Use V or H split so the two markers lie across, not along, the 6 deg tilt.

uniformity_probe/probe_RC_*.png   (load with Custom image, key U)
    One 96 x 96 px white square at 9 positions (3 x 3, rows top/mid/bot, columns
    left/centre/right in DMD coordinates). Show them one at a time and read the
    power meter. The power meter has no vignetting and no tone curve, so the 9 readings
    give the true irradiance map; dividing the camera ROI values by them gives the
    camera's own fall-off.

UNIFORMITY PROBE (key Q, built into the viewer)
    Default: the screen is cut into 16 x 12 tiles of 64 x 64 px that together cover 100 %
    of the DMD (every pixel lit exactly once). Tiles are shown one at a time, row by row
    from the DMD's top-left corner, 0.6 s each with 0.3 s dark between: about 3 min.
    Untick "tiles cover 100 %" to use small separate squares instead (size setting),
    still reaching the very edges. Optional full-white reference at start and end.
    Beeps: short at each tile, higher at the start of each row.
    "Download last probe run (CSV)" gives every tile's position, size and on/off time,
    both from the start beep and as PC clock time, to match a power meter log on the same PC.
    A 64 x 64 tile is 0.52 % of the screen: about 5.2 uW when full white is 1 mW.
GREYSCALE FLAT-FIELD CORRECTION (key X, settings in the menu)
    Paste a measured map (e.g. the probe's power per tile, rows from the DMD top) in the
    menu. When the correction is on, every lit pixel brighter than the target level is
    dimmed with grey level 255 x (target / measured)^(1/gamma); darker pixels stay at 255.
    Applies to every pattern, including the probe, so the effect can be measured directly.
    1. Find the projector's gamma: run the probe with "Probe grey level" 255, 200, 150
       (light ~ (level/255)^gamma).
    2. Turn the correction on (X) and run the probe again: the tiles should be flat at the
       target level. The dose time must be scaled by 100 / target (e.g. x1.16 at 86 %).
    Patterns are no longer strictly binary when the correction is on (the DMD makes grey
    with time modulation within each frame); exposures of seconds average this out.

GREY RAMP (key R) and MAX GREY LEVEL
    The ramp shows a centre square (256 px) at each listed grey level in turn, with the
    probe's on/dark times, and the CSV lists the level of every step. Log the power meter
    during it: power versus level is the projector's real response. Many projectors clip
    the top of the range (all levels above a knee give full light) or use limited RGB range
    (16-235). Set "Max grey level used" to the top of the range where the power still
    changes, and the gamma to the fitted value; the correction then works inside that range.

MEASURED GREY CURVE (default on, replaces gamma)
    "Measured curve, level:power" takes the ramp result as pairs, e.g.
    30:0, 50:2.1, 70:9.0, 90:21.5, 110:38.3, 130:50.2, 150:61.7, 170:73.3, 255:73.3
    (power in any unit). The curve is made non-decreasing, interpolated linearly, and the
    correction picks for each pixel the grey level that gives the wanted fraction of light.
    Prefilled with the IN124 ramp of 3 Nov 2026: flat (clipped) above grey ~170, roughly
    linear from ~60 to ~170, noisy below ~100 (time dithering). Re-run R after any change
    of projector picture settings and paste the new pairs.

USABLE AREA (menu, default x 0-896, y 0-768)
    Blacks out everything outside the chosen rectangle and centres all fill-based patterns
    and custom images in it, so the dark corner (right side of the screen, top-right in the
    power-meter map) is never used. Fill % is now % of the usable area. 05 White, 06 Black,
    the probe and the ramp stay full field for measurements.
    Custom masks: make them exactly the usable size (896 x 768 px by default), 1 px = 1 DMD
    pixel = ~2.2 um at 5x, black/white PNG. A full 1024 x 768 image is used as is (then keep
    the right 128 px black yourself). Change the usable area before loading the image (U).

CAMERA-BASED CORRECTION MAP (pre-filled since alignment v4)
    The correction map is now a 64 x 48 grid (16 px cells, % of mean) from a C920 white-field
    image: blue channel, black level subtracted, rectified to 1024 x 768, outer 20 px replaced by
    values 20 px inside (camera blur), smoothed, flipped vertically to screen orientation.
    Target 92 %: predicted 99-101 % over the usable area, ~92 % of the light kept (dose x 1.09).
    It is a camera estimate; check with the probe (Q) and power meter with X on.

POWER-METER MAP REPLACES THE CAMERA MAP (3 Nov, 16:16 run)
    The 16 x 12 probe with the camera map on showed the camera map does not predict the light at
    the wafer (r ~ 0.2). Default map is now a smooth 2nd-order fit of the power-meter field
    (without correction), target 94 %. Single 1 s tiles have ~4-5 % noise: use 3 s tiles or
    average two runs when checking.

DRIFT REFERENCE IN THE PROBE (pRefEvery, default 16 = once per row of 16)
    The probe shows the same reference tile (the tile at the centre of the usable area) at the start
    and after every N tiles (kind 'ref' in the CSV, its own beep). The power of the reference over
    time gives the source drift, so each tile can be divided by the interpolated reference.
    Needed because rows are measured in time order: LED drift otherwise looks like a top-bottom gradient.

MAP FROM THE UNCORRECTED PROBE (3 Nov 17:05) - current default, target 86 %
    16 x 12 tiles, 3.3 s each, no correction: usable area 84-124 % (sd 9 %): top-middle lowest,
    bottom and right edge highest. Agrees with the 16:45 run (r = 0.91). Smoothed with a 3rd-order fit
    (residual 2 % = noise). Predicted with correction: ~96-108 % per tile (sd 2 %, mostly noise),
    87 % of the light kept: scale dose time by ~1.15.

FINE GREY RAMP (3 Nov 17:30) - measured curve updated
    Full light down to grey 160, then steep: 155 = 91 %, 150 = 81 %, 140 = 61 %, a shelf at 100-140
    (51-61 %), then 90 = 37 %, 70 = 14 %, 50 = 3 %. The knee is at ~160, not 170. With the old curve the
    17:05 map would have used greys 138-170 and over-dimmed the bright side (predicted 81-115 %).
    With the new curve the same map uses greys 147-160 (target 86 %).
