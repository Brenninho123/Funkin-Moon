# Recording videos

Press **F5** to start recording the game window and press **F5** again to stop. The video is saved in the `videos` folder next to the game, the same way screenshots go to `screenshots`. **Shift+F5** opens the folder.

- While recording, the window title shows `[REC 0:12]`. A sound plays when the recording starts and when it is saved, and a message at the top left tells you where the file went and how long and big it is. The message only appears after the recording stopped, so it never shows up in the video.
- The recording is closed properly when you close the window or the game crashes.
- Editors that use F5 themselves (the Cosmic Editor and the Lua Script Editor) turn the recording key off while they are open. The hot reload of the assets is now **Ctrl+F5**.

## On Windows: MP4 with sound at 60 frames per second

- The file is an `.mp4` with **H.264 video at 60 frames per second** and **AAC audio**, in the size of the window when you pressed F5. It plays everywhere and can go straight to a video editor or a website.
- The **sound is the sound of the game only**, taken from the Windows audio engine. Music playing in another program is not recorded, and what you hear is not changed. Windows 11 and recent Windows 10 builds do this; on older Windows the whole sound of the computer is recorded instead. The message after saving says if the video has sound.
- The encoding is done by Media Foundation, which comes with Windows, so nothing has to be installed. It uses the video card encoder when there is one, and the processor otherwise. Set the environment variable `MOON_VIDEO_SOFTWARE=1` to force the processor if the video card encoder gives trouble.
- The quality follows the size of the window: up to about 10 Mbps for 1280x720 and 22 Mbps for 1920x1080, which is at most 75 MB or 165 MB per minute (quiet scenes take less).
- Frames are grabbed on the main thread and encoded on other threads, so the game keeps its frame rate. If the computer cannot keep up, the video repeats frames instead of getting shorter, and the message says that the game ran slower while recording. The picture and the sound stay in sync.
- The video needs an even width and height, so one pixel is cut from a window with an odd size. If the window changes size while recording, the picture keeps the starting size.

## On other systems: AVI without sound

Linux and macOS do not have the Windows encoder yet. They record a Motion JPEG `.avi` at 30 frames per second **without sound**, which plays in VLC and most players but is big, around 5 to 6 MB per second.

- An AVI file cannot pass 2 GB, so a long recording continues in `video-... (part 2).avi`, `(part 3)` and so on without losing a frame.
- The file is kept in a valid state once a second while recording, so even a power cut leaves a video that plays (without a seek index).
- The same thing is used on Windows if the encoder cannot start (the reason goes to the crash report journal).

## For developers

- `funkin.util.plugins.VideoRecorderPlugin.isRecording` tells if a recording is running, and `suspended` turns the F5 key off while a screen needs it.
- The Windows encoder is in `source/funkin/external/windows/video` (C++ with Media Foundation and WASAPI) and is on when `FEATURE_NATIVE_VIDEO_RECORDER` is. Process audio capture uses `ActivateAudioInterfaceAsync` with `PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE`.
