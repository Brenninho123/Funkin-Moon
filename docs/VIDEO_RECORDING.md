# Recording videos

Press **F5** to start recording the game window and press **F5** again to stop. The video is saved in the `videos` folder next to the game, the same way screenshots go to `screenshots`. **Shift+F5** opens the folder.

- While recording, the window title shows `[REC 0:12]`. A sound plays when the recording starts and when it is saved, and a message at the top left tells you where the file went. The message only appears after the recording stopped, so it never shows up in the video.
- The file is an `.avi` with Motion JPEG video at 30 frames per second, in the size of the window when you pressed F5. It plays in VLC and in most players. It has **no sound**.
- The frames are compressed on a second thread, so the game keeps its speed. If the computer cannot keep up, frames are repeated instead of the video running short, so the video always lasts as long as the recording did.
- Motion JPEG files are big, around 4 to 8 MB per second at 720p, depending on what is on screen. An AVI file cannot pass 2 GB, so a long recording continues in `video-... (part 2).avi`, `(part 3)` and so on without losing a frame. Convert the video with a tool such as HandBrake or ffmpeg if you want it smaller.
- The recording is closed properly when you close the window or the game crashes. The file is also kept in a valid state once a second while recording, so even a power cut leaves a video that plays (without a seek index).
- Editors that use F5 themselves (the Cosmic Editor and the Lua Script Editor) turn the recording key off while they are open. The hot reload of the assets is now **Ctrl+F5**.

Mods and tools can read `funkin.util.plugins.VideoRecorderPlugin.isRecording`, and set `VideoRecorderPlugin.suspended = true` while a screen needs F5 for something else.
