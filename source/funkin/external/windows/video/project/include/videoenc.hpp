#pragma once

bool VIDEOENC_Start(const char *path, int width, int height, int fps, int bitrateKbps, bool wantAudio);
bool VIDEOENC_WriteFrame(const unsigned char *pixels, int width, int height, bool rgba, int startIndex, int repeat);
int VIDEOENC_QueuedFrames();
bool VIDEOENC_HasAudio();
const char *VIDEOENC_AudioKind();
const char *VIDEOENC_Stop();
const char *VIDEOENC_LastError();
