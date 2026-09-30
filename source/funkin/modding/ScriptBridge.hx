package funkin.modding;

import funkin.memory.MemoryManager;
import funkin.modding.module.ModuleHandler;
import funkin.ui.Codex;
#if FEATURE_LUA_SCRIPTS
import funkin.lua.FunkinLua;
#end
#if FEATURE_ONLINE
import funkin.online.DiscordAuth;
import funkin.online.FunkinOnline;
import funkin.online.FunkinUser;
#end

class ScriptBridge
{
  static inline var LINE_PREFIX:String = 'hscript:';

  public static function log(message:Dynamic):Void
  {
    FlxG.log.add(Std.string(message));
  }

  public static function warn(message:Dynamic):Void
  {
    FlxG.log.warn(Std.string(message));
  }

  public static function error(message:Dynamic):Void
  {
    FlxG.log.error(Std.string(message));
  }

  public static function callLua(script:String, functionName:String, ?args:Array<Dynamic>):Dynamic
  {
    #if FEATURE_LUA_SCRIPTS
    return FunkinLua.callScriptByName(script, functionName, args ?? []);
    #else
    return null;
    #end
  }

  public static function hasLua(script:String):Bool
  {
    #if FEATURE_LUA_SCRIPTS
    return FunkinLua.hasScriptNamed(script);
    #else
    return false;
    #end
  }

  public static function getLuaScripts():Array<String>
  {
    #if FEATURE_LUA_SCRIPTS
    return FunkinLua.getLoadedScriptNames();
    #else
    return [];
    #end
  }

  public static function setShared(name:String, value:Dynamic):Void
  {
    #if FEATURE_LUA_SCRIPTS
    FunkinLua.setSharedValue(name, value);
    #end
  }

  public static function getShared(name:String):Dynamic
  {
    #if FEATURE_LUA_SCRIPTS
    return FunkinLua.getSharedValue(name);
    #else
    return null;
    #end
  }

  public static function hasShared(name:String):Bool
  {
    #if FEATURE_LUA_SCRIPTS
    return FunkinLua.hasSharedValue(name);
    #else
    return false;
    #end
  }

  public static function removeShared(name:String):Void
  {
    #if FEATURE_LUA_SCRIPTS
    FunkinLua.removeSharedValue(name);
    #end
  }

  public static function getMemoryInfo():MemorySnapshot
  {
    return MemoryManager.instance.getSnapshot();
  }

  public static function getMemoryPressure():String
  {
    return MemoryManager.instance.pressure.getName();
  }

  public static function requestGarbageCollection(major:Bool = false):Bool
  {
    return MemoryManager.instance.requestCollect(major);
  }

  public static function callModule(moduleId:String, functionName:String, ?args:Array<Dynamic>):Dynamic
  {
    return invokeModule(moduleId, functionName, args ?? []);
  }

  static function invokeModule(moduleId:String, functionName:String, args:Array<Dynamic>):Dynamic
  {
    var module:Null<Dynamic> = ModuleHandler.getModule(moduleId);

    if (module == null) return null;

    var scriptCall:Dynamic = Reflect.field(module, 'scriptCall');

    if (Reflect.isFunction(scriptCall)) return Reflect.callMethod(module, scriptCall, [functionName, args]);

    var direct:Dynamic = Reflect.field(module, functionName);

    return Reflect.isFunction(direct) ? Reflect.callMethod(module, direct, args) : null;
  }

  public static function setDebugLine(id:String, text:String):Void
  {
    if (Main.debugDisplay != null && id != '') Main.debugDisplay.setCustomLine(LINE_PREFIX + id, text);
  }

  public static function removeDebugLine(id:String):Void
  {
    if (Main.debugDisplay != null) Main.debugDisplay.removeCustomLine(LINE_PREFIX + id);
  }

  public static function clearDebugLines():Void
  {
    if (Main.debugDisplay != null) Main.debugDisplay.removeCustomLinesWithPrefix(LINE_PREFIX);
  }

  public static function getCodexPage():String
  {
    return Codex.current?.getCurrentPageName() ?? '';
  }

  public static function getCodexPages():Array<String>
  {
    return Codex.current?.getPageNames() ?? [];
  }

  public static function setCodexPage(name:String):Bool
  {
    return Codex.current?.requestPage(name) ?? false;
  }

  public static function isOnline():Bool
  {
    #if FEATURE_ONLINE
    return FunkinOnline.instance.isConnected();
    #else
    return false;
    #end
  }

  public static function getOnlinePlayers():Array<String>
  {
    #if FEATURE_ONLINE
    return [for (user in FunkinUser.instance.getActiveUsers()) user.username];
    #else
    return [];
    #end
  }

  public static function getDiscordName():Null<String>
  {
    #if FEATURE_ONLINE
    return DiscordAuth.instance.isLoggedIn() ? DiscordAuth.instance.profile.username : null;
    #else
    return null;
    #end
  }
}
