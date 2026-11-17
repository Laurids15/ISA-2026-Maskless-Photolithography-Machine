@echo off
rem cam_dialog_windows.bat - opens the camera driver settings (Video Proc Amp / Camera Control).
rem Usage: cam_dialog_windows.bat ["camera name"]   default: HD Pro Webcam C920
rem Needs ffmpeg:  winget install Gyan.FFmpeg
rem Run it BEFORE starting camera.html (Windows may not let two programs open the camera).

where ffmpeg >nul 2>nul || (echo ffmpeg not found. Install with:  winget install Gyan.FFmpeg & pause & exit /b 1)

echo Video devices:
ffmpeg -hide_banner -f dshow -list_devices true -i dummy 2>&1 | findstr /i "(video)"

set "CAM=%~1"
if "%CAM%"=="" set "CAM=HD Pro Webcam C920"
echo.
echo Opening settings for: %CAM%
echo  Video Proc Amp: Gain 0 (untick Auto), Sharpness 0, White Balance untick Auto (4000),
echo                  Backlight Comp 0, PowerLine Frequency 50 Hz, Brightness/Contrast/Saturation default.
echo  Camera Control: Exposure untick Auto, Focus untick Auto, Zoom 100, Low Light Compensation OFF.
echo Close the dialog with OK. ffmpeg then grabs one frame and exits.
ffmpeg -hide_banner -loglevel error -f dshow -show_video_device_dialog true -i video="%CAM%" -frames:v 1 -f null -
echo Done. Now open camera.html in Chrome or Edge.
pause
