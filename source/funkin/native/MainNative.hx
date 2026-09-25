package funkin.native;

@:buildXml('
<files id="haxe">
  <compilerflag value="-Isource" />
  <file name="source/Main.cpp" />
</files>
')
@:include("Main.hpp")
extern class MainNative
{
  @:native("funkin_native_getProcessMemoryBytes")
  public static function getProcessMemoryBytes():Float;

  @:native("funkin_native_getTotalSystemMemoryBytes")
  public static function getTotalSystemMemoryBytes():Float;

  @:native("funkin_native_installCrashHandler")
  public static function installCrashHandler():Void;

  @:native("funkin_native_hadNativeCrash")
  public static function hadNativeCrash():Bool;

  @:native("funkin_native_getLastCrashSignalName")
  public static function getLastCrashSignalName():cpp.ConstCharStar;
}
