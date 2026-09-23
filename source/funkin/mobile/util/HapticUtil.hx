package funkin.mobile.util;

class HapticUtil
{
  public static function tap():Void
  {
    #if (FEATURE_HAPTICS && android)
    extension.haptics.Haptics.vibrate(10);
    #elseif (FEATURE_HAPTICS && ios)
    extension.haptics.Haptics.impact(Light);
    #end
  }

  public static function select():Void
  {
    #if (FEATURE_HAPTICS && android)
    extension.haptics.Haptics.vibrate(15);
    #elseif (FEATURE_HAPTICS && ios)
    extension.haptics.Haptics.impact(Medium);
    #end
  }

  public static function success():Void
  {
    #if (FEATURE_HAPTICS && android)
    extension.haptics.Haptics.vibrate(25);
    #elseif (FEATURE_HAPTICS && ios)
    extension.haptics.Haptics.impact(Heavy);
    #end
  }

  public static function warning():Void
  {
    #if (FEATURE_HAPTICS && android)
    extension.haptics.Haptics.vibrate([0, 20, 40, 20]);
    #elseif (FEATURE_HAPTICS && ios)
    extension.haptics.Haptics.notification(Warning);
    #end
  }
}
