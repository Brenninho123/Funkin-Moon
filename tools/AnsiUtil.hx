package tools;

@SuppressWarnings(["checkstyle:FieldDocComment", "checkstyle:MemberName", "checkstyle:TypeDocComment"])
enum abstract AnsiCode(String) from String to String
{
  public var RESET = '\x1b[0m';
  public var BOLD = '\x1b[1m';
  public var DIM = '\x1b[2m';
  public var UNDERLINE = '\x1b[4m';
  public var BLINK = '\x1b[5m';
  public var INVERSE = '\x1b[7m';
  public var HIDDEN = '\x1b[8m';
  public var STRIKETHROUGH = '\x1b[9m';
  public var BLACK = '\x1b[30m';
  public var RED = '\x1b[31m';
  public var GREEN = '\x1b[32m';
  public var YELLOW = '\x1b[33m';
  public var BLUE = '\x1b[34m';
  public var MAGENTA = '\x1b[35m';
  public var CYAN = '\x1b[36m';
  public var WHITE = '\x1b[37m';
  public var ORANGE = '\x1b[38;5;208m';
  public var NOTE_LEFT = '\x1b[38;2;255;34;170m';
  public var NOTE_DOWN = '\x1b[38;2;0;238;255m';
  public var NOTE_UP = '\x1b[38;2;0;204;0m';
  public var NOTE_RIGHT = '\x1b[38;2;204;17;17m';
  public var BG_BLACK = '\x1b[40m';
  public var BG_RED = '\x1b[41m';
  public var BG_GREEN = '\x1b[42m';
  public var BG_YELLOW = '\x1b[43m';
  public var BG_BLUE = '\x1b[44m';
  public var BG_MAGENTA = '\x1b[45m';
  public var BG_CYAN = '\x1b[46m';
  public var BG_WHITE = '\x1b[47m';
  public var BG_SEA_GREEN = '\x1b[48;5;50m';
  public var BG_PIST = '\x1b[48;5;112m';
  public var BG_BRONZE = '\x1b[48;5;137m';
  public var BG_BRIGHT_LAVENDER = '\x1b[48;5;141m';
  public var BG_LIME = '\x1b[48;5;154m';
  public var BG_MINT_GREEN = '\x1b[48;5;156m';
  public var BG_HOPBUSH = '\x1b[48;5;169m';
  public var BG_BRIGHT_LILAC = '\x1b[48;5;177m';
  public var BG_GOLDENROD = '\x1b[48;5;178m';
  public var BG_CORN = '\x1b[48;5;184m';
  public var BG_TEA_GREEN = '\x1b[48;5;193m';
  public var BG_LIGHT_RED = '\x1b[48;5;196m';
  public var BG_STRAWBERRY = '\x1b[48;5;204m';
  public var BG_SHOCKING_PINK = '\x1b[48;5;207m';
  public var BG_ORANGE = '\x1b[48;5;208m';
  public var BG_SALMON = '\x1b[48;5;209m';
  public var BG_LIGHT_PINK = '\x1b[48;5;213m';
  public var BG_PURPLE = '\x1b[48;2;121;37;199m';
  public var BG_NOTE_LEFT = '\x1b[48;2;255;34;170m';
  public var BG_NOTE_DOWN = '\x1b[48;2;0;238;255m';
  public var BG_NOTE_UP = '\x1b[48;2;0;204;0m';
  public var BG_NOTE_RIGHT = '\x1b[48;2;204;17;17m';
  public var BRIGHT_BLACK = '\x1b[90m';
  public var BRIGHT_RED = '\x1b[91m';
  public var BRIGHT_GREEN = '\x1b[92m';
  public var BRIGHT_YELLOW = '\x1b[93m';
  public var BRIGHT_BLUE = '\x1b[94m';
  public var BRIGHT_MAGENTA = '\x1b[95m';
  public var BRIGHT_CYAN = '\x1b[96m';
  public var BRIGHT_WHITE = '\x1b[97m';
  public var BG_BRIGHT_BLACK = '\x1b[100m';
  public var BG_BRIGHT_RED = '\x1b[101m';
  public var BG_BRIGHT_GREEN = '\x1b[102m';
  public var BG_BRIGHT_YELLOW = '\x1b[103m';
  public var BG_BRIGHT_BLUE = '\x1b[104m';
  public var BG_BRIGHT_MAGENTA = '\x1b[105m';
  public var BG_BRIGHT_CYAN = '\x1b[106m';
  public var BG_BRIGHT_WHITE = '\x1b[107m';
}

@:nullSafety
class AnsiUtil
{
  #if sys
  @:noCompletion
  static final REGEX_TEAMCITY_VERSION:EReg = ~/^9\.(0*[1-9]\d*)\.|\d{2,}\./;
  @:noCompletion
  static final REGEX_TERM_256:EReg = ~/(?i)-256(color)?$/;
  @:noCompletion
  static final REGEX_TERM_TYPES:EReg = ~/(?i)^screen|^xterm|^vt100|^vt220|^rxvt|color|ansi|cygwin|linux/;
  #end
  @:noCompletion
  static final REGEX_ANSI_CODES:EReg = ~/\x1b\[[0-9;]*m/g;
  @:noCompletion
  static var codesSupported:Null<Bool> = null;

  static function getEnvSafe(name:String):Null<String>
  {
    #if sys
    return Sys.getEnv(name);
    #else
    return null;
    #end
  }

  public static inline function error(str:String):String return AnsiUtil.bold(AnsiUtil.bg_note_right(str));

  public static inline function warning(str:String):String return AnsiUtil.bold(AnsiUtil.bg_yellow(str));

  public static inline function info(str:String):String return AnsiUtil.bold(AnsiUtil.bg_blue(str));

  public static inline function debug(str:String):String return AnsiUtil.bold(AnsiUtil.bg_lime(str));

  public static inline function bold(str:String):String return apply(str, AnsiCode.BOLD);

  public static inline function dim(str:String):String return apply(str, AnsiCode.DIM);

  public static inline function underline(str:String):String return apply(str, AnsiCode.UNDERLINE);

  public static inline function blink(str:String):String return apply(str, AnsiCode.BLINK);

  public static inline function inverse(str:String):String return apply(str, AnsiCode.INVERSE);

  public static inline function hidden(str:String):String return apply(str, AnsiCode.HIDDEN);

  public static inline function strikethrough(str:String):String return apply(str, AnsiCode.STRIKETHROUGH);

  public static inline function black(str:String):String return apply(str, AnsiCode.BLACK);

  public static inline function red(str:String):String return apply(str, AnsiCode.RED);

  public static inline function green(str:String):String return apply(str, AnsiCode.GREEN);

  public static inline function yellow(str:String):String return apply(str, AnsiCode.YELLOW);

  public static inline function blue(str:String):String return apply(str, AnsiCode.BLUE);

  public static inline function magenta(str:String):String return apply(str, AnsiCode.MAGENTA);

  public static inline function cyan(str:String):String return apply(str, AnsiCode.CYAN);

  public static inline function white(str:String):String return apply(str, AnsiCode.WHITE);

  public static inline function orange(str:String):String return apply(str, AnsiCode.ORANGE);

  public static inline function note_left(str:String):String return apply(str, AnsiCode.NOTE_LEFT);

  public static inline function note_down(str:String):String return apply(str, AnsiCode.NOTE_DOWN);

  public static inline function note_up(str:String):String return apply(str, AnsiCode.NOTE_UP);

  public static inline function note_right(str:String):String return apply(str, AnsiCode.NOTE_RIGHT);

  public static inline function bg_black(str:String):String return apply(str, AnsiCode.BG_BLACK);

  public static inline function bg_red(str:String):String return apply(str, AnsiCode.BG_RED);

  public static inline function bg_green(str:String):String return apply(str, AnsiCode.BG_GREEN);

  public static inline function bg_yellow(str:String):String return apply(str, AnsiCode.BG_YELLOW);

  public static inline function bg_blue(str:String):String return apply(str, AnsiCode.BG_BLUE);

  public static inline function bg_magenta(str:String):String return apply(str, AnsiCode.BG_MAGENTA);

  public static inline function bg_cyan(str:String):String return apply(str, AnsiCode.BG_CYAN);

  public static inline function bg_white(str:String):String return apply(str, AnsiCode.BG_WHITE);

  public static inline function bg_orange(str:String):String return apply(str, AnsiCode.BG_ORANGE);

  public static inline function bg_purple(str:String):String return apply(str, AnsiCode.BG_PURPLE);

  public static inline function bg_sea_green(str:String):String return apply(str, AnsiCode.BG_SEA_GREEN);

  public static inline function bg_pist(str:String):String return apply(str, AnsiCode.BG_PIST);

  public static inline function bg_bronze(str:String):String return apply(str, AnsiCode.BG_BRONZE);

  public static inline function bg_bright_lavender(str:String):String return apply(str, AnsiCode.BG_BRIGHT_LAVENDER);

  public static inline function bg_bright_lilac(str:String):String return apply(str, AnsiCode.BG_BRIGHT_LILAC);

  public static inline function bg_lime(str:String):String return apply(str, AnsiCode.BG_LIME);

  public static inline function bg_mint_green(str:String):String return apply(str, AnsiCode.BG_MINT_GREEN);

  public static inline function bg_hopbush(str:String):String return apply(str, AnsiCode.BG_HOPBUSH);

  public static inline function bg_goldenrod(str:String):String return apply(str, AnsiCode.BG_GOLDENROD);

  public static inline function bg_corn(str:String):String return apply(str, AnsiCode.BG_CORN);

  public static inline function bg_tea_green(str:String):String return apply(str, AnsiCode.BG_TEA_GREEN);

  public static inline function bg_light_red(str:String):String return apply(str, AnsiCode.BG_LIGHT_RED);

  public static inline function bg_strawberry(str:String):String return apply(str, AnsiCode.BG_STRAWBERRY);

  public static inline function bg_shocking_pink(str:String):String return apply(str, AnsiCode.BG_SHOCKING_PINK);

  public static inline function bg_salmon(str:String):String return apply(str, AnsiCode.BG_SALMON);

  public static inline function bg_light_pink(str:String):String return apply(str, AnsiCode.BG_LIGHT_PINK);

  public static inline function bg_note_left(str:String):String return apply(str, AnsiCode.BG_NOTE_LEFT);

  public static inline function bg_note_down(str:String):String return apply(str, AnsiCode.BG_NOTE_DOWN);

  public static inline function bg_note_up(str:String):String return apply(str, AnsiCode.BG_NOTE_UP);

  public static inline function bg_note_right(str:String):String return apply(str, AnsiCode.BG_NOTE_RIGHT);

  public static inline function bright_black(str:String):String return apply(str, AnsiCode.BRIGHT_BLACK);

  public static inline function bright_red(str:String):String return apply(str, AnsiCode.BRIGHT_RED);

  public static inline function bright_green(str:String):String return apply(str, AnsiCode.BRIGHT_GREEN);

  public static inline function bright_yellow(str:String):String return apply(str, AnsiCode.BRIGHT_YELLOW);

  public static inline function bright_blue(str:String):String return apply(str, AnsiCode.BRIGHT_BLUE);

  public static inline function bright_magenta(str:String):String return apply(str, AnsiCode.BRIGHT_MAGENTA);

  public static inline function bright_cyan(str:String):String return apply(str, AnsiCode.BRIGHT_CYAN);

  public static inline function bright_white(str:String):String return apply(str, AnsiCode.BRIGHT_WHITE);

  public static inline function bg_bright_black(str:String):String return apply(str, AnsiCode.BG_BRIGHT_BLACK);

  public static inline function bg_bright_red(str:String):String return apply(str, AnsiCode.BG_BRIGHT_RED);

  public static inline function bg_bright_green(str:String):String return apply(str, AnsiCode.BG_BRIGHT_GREEN);

  public static inline function bg_bright_yellow(str:String):String return apply(str, AnsiCode.BG_BRIGHT_YELLOW);

  public static inline function bg_bright_blue(str:String):String return apply(str, AnsiCode.BG_BRIGHT_BLUE);

  public static inline function bg_bright_magenta(str:String):String return apply(str, AnsiCode.BG_BRIGHT_MAGENTA);

  public static inline function bg_bright_cyan(str:String):String return apply(str, AnsiCode.BG_BRIGHT_CYAN);

  public static inline function bg_bright_white(str:String):String return apply(str, AnsiCode.BG_BRIGHT_WHITE);

  public static function rgb(str:String, r:Int, g:Int, b:Int):String
  {
    return wrap(str, '\x1b[38;2;${clampByte(r)};${clampByte(g)};${clampByte(b)}m');
  }

  public static function bgRgb(str:String, r:Int, g:Int, b:Int):String
  {
    return wrap(str, '\x1b[48;2;${clampByte(r)};${clampByte(g)};${clampByte(b)}m');
  }

  public static function color256(str:String, code:Int):String
  {
    return wrap(str, '\x1b[38;5;${clampByte(code)}m');
  }

  public static function bgColor256(str:String, code:Int):String
  {
    return wrap(str, '\x1b[48;5;${clampByte(code)}m');
  }

  public static function applyAll(str:String, codes:Array<AnsiCode>):String
  {
    if (codes.length == 0) return str;

    var prefix:String = '';

    for (code in codes) prefix += (code : String);

    return wrap(str, prefix);
  }

  static inline function clampByte(value:Int):Int
  {
    return value < 0 ? 0 : (value > 255 ? 255 : value);
  }

  public static function apply(str:String, code:AnsiCode):String
  {
    return wrap(str, code);
  }

  static function wrap(str:String, code:String):String
  {
    if (str.indexOf(AnsiCode.RESET) != -1) str = StringTools.replace(str, AnsiCode.RESET, "");

    return stripCodes(code + str + AnsiCode.RESET);
  }

  public static function strip(str:String):String
  {
    return REGEX_ANSI_CODES.replace(str, '');
  }

  public static function resetSupportCache():Void
  {
    codesSupported = null;
  }

  @SuppressWarnings([
    "checkstyle:SimplifyBooleanExpression"
  ])
  public static function isColorCodesSupported():Bool
  {
    if (codesSupported == null)
    {
      #if macro
      if (haxe.macro.Context.defined("message.no-color"))
      {
        codesSupported = false;
      }
      #end

      #if sys
      if (codesSupported == null)
      {
        if (getEnvSafe('NO_COLOR') != null)
        {
          codesSupported = false;
        }
        else if (getEnvSafe('FORCE_COLOR') != null)
        {
          codesSupported = getEnvSafe('FORCE_COLOR') != '0';
        }
      }

      if (codesSupported == null)
      {
        final term:Null<String> = getEnvSafe('TERM');

        if (term == 'dumb')
        {
          codesSupported = false;
        }
        else
        {
          if (codesSupported != true && term != null)
          {
            codesSupported = REGEX_TERM_256.match(term) || REGEX_TERM_TYPES.match(term);
          }

          if (getEnvSafe('CI') != null)
          {
            final ciEnvNames:Array<String> = [
              "GITHUB_ACTIONS", "GITEA_ACTIONS",    "TRAVIS", "CIRCLECI",
                    "APPVEYOR",     "GITLAB_CI", "BUILDKITE",    "DRONE"
            ];

            for (ci in ciEnvNames)
            {
              if (getEnvSafe(ci) != null)
              {
                codesSupported = true;
                break;
              }
            }

            if (codesSupported != true && getEnvSafe("CI_NAME") == "codeship")
            {
              codesSupported = true;
            }
          }

          final teamCity:Null<String> = getEnvSafe("TEAMCITY_VERSION");

          if (codesSupported != true && teamCity != null)
          {
            codesSupported = REGEX_TEAMCITY_VERSION.match(teamCity);
          }

          if (codesSupported != true)
          {
            codesSupported = getEnvSafe('TERM_PROGRAM') == 'iTerm.app'
              || getEnvSafe('TERM_PROGRAM') == 'Apple_Terminal'
              || getEnvSafe('COLORTERM') != null
              || getEnvSafe('ANSICON') != null
              || getEnvSafe('ConEmuANSI') != null
              || getEnvSafe('WT_SESSION') != null;
          }
        }
      }
      #else
      codesSupported = false;
      #end
    }

    return codesSupported == true;
  }

  @:noCompletion
  static function stripCodes(output:String):String
  {
    return isColorCodesSupported() ? output : REGEX_ANSI_CODES.replace(output, '');
  }
}
