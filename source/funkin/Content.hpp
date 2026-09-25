#ifndef FUNKIN_CONTENT_NATIVE_H
#define FUNKIN_CONTENT_NATIVE_H

extern "C" const char *funkin_content_scanSubdirectories(const char *assetsRoot, const char *relativePath);
extern "C" const char *funkin_content_scanJsonFiles(const char *assetsRoot, const char *relativePath);
extern "C" const char *funkin_content_scanSongs(const char *assetsRoot);
extern "C" const char *funkin_content_scanWeeks(const char *assetsRoot);
extern "C" const char *funkin_content_scanCharacters(const char *assetsRoot);

#endif
