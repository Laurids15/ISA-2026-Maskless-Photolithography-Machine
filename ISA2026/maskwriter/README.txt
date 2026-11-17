MASK WRITER - designer + exposure viewer for the DMD lithography setup
=====================================================================

Two pages. Keep them in the same folder and open them in Chrome (or Edge).

designer.html   draw your own structures and export them as 1024 x 768 masks
expose.html     load a mask, set the exposure time, greyscale correction on/off, expose

The old test viewer (test_patterns/viewer.html) is still the tool for calibration:
probe (Q), grey ramp (R), dose ladder (D) and the other test patterns.


DESIGNER (designer.html)
------------------------
- Everything sits on the 1024 x 768 DMD pixel grid and is exported 1:1
  (white = lit mirror = exposed = SU-8 stays).
- Scale: 2.2 um/px at 5x (default), 4.4 um/px at 2.5x, or custom. Objects are stored in
  pixels; changing the scale changes their size in um.
- Coordinates in um from the centre of the usable area (x right, y down). All positions and
  sizes are rounded to whole pixels; lines of odd pixel width sit on pixel centres so both
  edges fall on pixel borders.
- Tools: V select/move, R rectangle, C circle, L line/path (width, flat or square ends),
  P polygon, T text (5 x 7 pixel font), H pan.
  Lines and polygons: click the points, double-click or Enter to finish, Shift = 0/45/90 deg.
- Every object either ADDS light or CUTS it away (holes, gaps). Objects lower in the list
  are drawn later.
- Selection panel: exact centre/size in um (pixels shown next to it), points as text,
  duplicate, delete, order, mirror copy about the centre lines, array copies with a pitch.
- Keys: Ctrl+Z / Ctrl+Y undo/redo, Ctrl+D duplicate, Ctrl+A select all, Del delete,
  arrows move 1 px (Shift 10 px), 0 fit, + / - zoom, wheel zoom, middle button or Space-drag pan.
- Design grid (Shift+G): green lines every N um from the centre of the usable area, optional
  snap to grid for new points, corners, centres, handle drags and moves.
- Checks: lit px outside the usable area, lit features under 3 px (may not print),
  cut features under 4 px (dark gaps this narrow tend to close at ~165 mJ/cm2).
- Files: Save design (.mask.json, re-open with Open), Import image (a PNG as a 1:1 object),
  Export PNG (1024 x 768, optionally inverted). The current design is auto-saved in the browser.
- Examples: figure 1 (the electrode drawing, identical to mask1_5x_2.2um_px.png) and
  alignment marks with a label.
- "Send to exposure window" opens expose.html the first time (allow pop-ups for the file if
  Chrome asks). Drag that window to the projector and press F there. Later sends replace the
  mask in the same window. If sending does not work, use Export PNG and load the file in expose.html.


EXPOSURE (expose.html)
----------------------
- Load a PNG (or send it from the designer). 1024 x 768 images are used as they are; smaller
  images are centred in the usable area. Brightness >= 128 = lit. Nothing is scaled.
- Options: invert, black outside the usable area (default on), greyscale correction (default on).
- Enter (or the ARM button) goes to the black armed screen. Space exposes: delay, mask for the
  set time, black again. Esc aborts immediately.
- Armed keys: arrows / PgUp / PgDn / T change the time, X correction on/off, O alignment view
  (mask on until O/Esc - UV off or green filter in), W white in the USABLE AREA only until
  W/Esc (power meter), Shift+W white on the whole DMD, V hold to preview, H corner text,
  S sound, F fullscreen.
- The small status text sits in the top-right corner, in the strip right of the usable area
  (the dark corner), so it does not touch the pattern.
- Dose helper / power density: put the sensor where you expose, press W (white only in the
  usable area, 896 x 768 px = 1.97 x 1.69 mm = 0.0333 cm2 at 2.2 um/px) with the correction set
  as you will expose, and type the reading. Irradiance = power / 0.0333 cm2 = the power density
  in the area you actually use. "Lit area" = "whole DMD" (Shift+W, 1024 x 768 = 0.0381 cm2)
  gives the old full-field method; with the same mW the usable-area method gives 1.14x more
  mW/cm2, so measure the power with the same pattern you select.
  Example: 0.62 mW, usable area, correction on -> 18.6 mW/cm2 -> 165 mJ/cm2 in 8.9 s.
- Calibration data (fold-out): usable area (default x 0-896), correction target (90 %), light
  map (mean of two 32 x 24 power-meter probes 10 Nov, neighbour-smoothed) and grey curve
  (ramp 10 Nov, knee at grey 160). Re-measure both with the test viewer after any change of the optics.
- Log of every exposure (time set/measured, correction, dose) with a copy button.

Window check: the exposure page must be 1024 x 768 at devicePixelRatio 1 on the projector
(display scaling 100 %, browser zoom 100 %, fullscreen). The menu shows red if not.
