#ifndef FUNKIN_MAIN_NATIVE_H
#define FUNKIN_MAIN_NATIVE_H

extern "C" double funkin_native_getProcessMemoryBytes();
extern "C" double funkin_native_getTotalSystemMemoryBytes();
extern "C" void funkin_native_installCrashHandler();
extern "C" bool funkin_native_hadNativeCrash();
extern "C" const char *funkin_native_getLastCrashSignalName();

#endif
