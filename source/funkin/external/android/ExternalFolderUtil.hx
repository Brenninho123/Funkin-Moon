package funkin.external.android;

#if android
class ExternalFolderUtil
{
  public static function openDataFolder():Void
  {
    final jni:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/ExternalFolderUtil', 'openDataFolder', '(I)V');
    if (jni == null) return;

    jni(CallbackUtil.DATA_FOLDER_CLOSED);
  }

  public static function openExternalFolder():Void
  {
    final jni:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/ExternalFolderUtil', 'openExternalFolder', '(I)V');
    if (jni == null) return;

    jni(CallbackUtil.DATA_FOLDER_CLOSED);
  }

  /**
   * Opens the data folder or the external folder depending on the current
   * `Preferences.storageType` value ("data" or "external"). This is the
   * function most callers (e.g. the Options menu) should use.
   */
  public static function openFolder():Void
  {
    final jni:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/ExternalFolderUtil', 'openFolderForType', '(Ljava/lang/String;I)V');
    if (jni == null) return;

    jni(funkin.Preferences.storageType, CallbackUtil.DATA_FOLDER_CLOSED);
  }

  public static function isExternalStorageAvailable():Bool
  {
    final jni:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/ExternalFolderUtil', 'isExternalStorageAvailable', '()Z');
    if (jni == null) return false;

    return jni();
  }

  public static function isExternalStorageReadOnly():Bool
  {
    final jni:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/ExternalFolderUtil', 'isExternalStorageReadOnly', '()Z');
    if (jni == null) return false;

    return jni();
  }

  public static function hasExternalFolder():Bool
  {
    final jni:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/ExternalFolderUtil', 'hasExternalFolder', '()Z');
    if (jni == null) return false;

    return jni();
  }

  public static function getExternalFolderPath():String
  {
    final jni:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/ExternalFolderUtil', 'getExternalFolderPath', '()Ljava/lang/String;');
    if (jni == null) return '';

    var result:Dynamic = jni();
    return result == null ? '' : Std.string(result);
  }

  public static function getExternalFolderFreeSpaceBytes():Float
  {
    final jni:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/ExternalFolderUtil', 'getExternalFolderFreeSpaceBytes', '()J');
    if (jni == null) return 0;

    return jni();
  }

  public static function getExternalFolderTotalSpaceBytes():Float
  {
    final jni:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/ExternalFolderUtil', 'getExternalFolderTotalSpaceBytes', '()J');
    if (jni == null) return 0;

    return jni();
  }
}
#end
