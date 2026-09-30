package funkin.play.modcharts;

class ModchartEase
{
  public static final NAMES:Array<String> = [
    'linear', 'instant', 'smooth', 'quadIn', 'quadOut', 'quadInOut', 'cubicIn', 'cubicOut', 'cubicInOut', 'sineIn', 'sineOut', 'sineInOut', 'expoIn',
    'expoOut', 'backIn', 'backOut', 'bounceOut', 'elasticOut'
  ];

  public static function isValid(name:String):Bool
  {
    return NAMES.indexOf(name) >= 0;
  }

  public static function apply(name:String, t:Float):Float
  {
    var x:Float = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);

    return switch (name)
    {
      case 'instant': x >= 1.0 ? 1.0 : 0.0;
      case 'smooth': x * x * (3.0 - 2.0 * x);
      case 'quadIn': x * x;
      case 'quadOut': x * (2.0 - x);
      case 'quadInOut': x < 0.5 ? 2.0 * x * x : -1.0 + (4.0 - 2.0 * x) * x;
      case 'cubicIn': x * x * x;
      case 'cubicOut': 1.0 - Math.pow(1.0 - x, 3.0);
      case 'cubicInOut': x < 0.5 ? 4.0 * x * x * x : 1.0 - Math.pow(-2.0 * x + 2.0, 3.0) / 2.0;
      case 'sineIn': 1.0 - Math.cos(x * Math.PI / 2.0);
      case 'sineOut': Math.sin(x * Math.PI / 2.0);
      case 'sineInOut': -(Math.cos(Math.PI * x) - 1.0) / 2.0;
      case 'expoIn': x == 0.0 ? 0.0 : Math.pow(2.0, 10.0 * x - 10.0);
      case 'expoOut': x == 1.0 ? 1.0 : 1.0 - Math.pow(2.0, -10.0 * x);
      case 'backIn': 2.70158 * x * x * x - 1.70158 * x * x;
      case 'backOut': 1.0 + 2.70158 * Math.pow(x - 1.0, 3.0) + 1.70158 * Math.pow(x - 1.0, 2.0);
      case 'bounceOut': bounceOut(x);
      case 'elasticOut': x == 0.0 ? 0.0 : (x == 1.0 ? 1.0 : Math.pow(2.0, -10.0 * x) * Math.sin((x * 10.0 - 0.75) * (2.0 * Math.PI / 3.0)) + 1.0);
      default: x;
    };
  }

  static function bounceOut(value:Float):Float
  {
    var n1:Float = 7.5625;
    var d1:Float = 2.75;
    var x:Float = value;

    if (x < 1.0 / d1) return n1 * x * x;

    if (x < 2.0 / d1)
    {
      x -= 1.5 / d1;
      return n1 * x * x + 0.75;
    }

    if (x < 2.5 / d1)
    {
      x -= 2.25 / d1;
      return n1 * x * x + 0.9375;
    }

    x -= 2.625 / d1;

    return n1 * x * x + 0.984375;
  }
}
