package funkin.mobile.util;

class HapticUtil
{
  public static function tap():Void
  {
    #if FEATURE_HAPTICS
    extension.haptics.Haptic.vibrateOneShot(0.01, 0.4, 0.5);
    #end
  }

  public static function select():Void
  {
    #if FEATURE_HAPTICS
    extension.haptics.Haptic.vibrateOneShot(0.015, 0.6, 0.6);
    #end
  }

  public static function success():Void
  {
    #if FEATURE_HAPTICS
    extension.haptics.Haptic.vibrateOneShot(0.025, 0.9, 0.8);
    #end
  }

  public static function warning():Void
  {
    #if FEATURE_HAPTICS
    extension.haptics.Haptic.vibratePattern([0.02, 0.04, 0.02], [0.8, 0.0, 0.8], [0.5, 0.0, 0.5]);
    #end
  }
}
