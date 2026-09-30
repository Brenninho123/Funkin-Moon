package funkin.lua.compat;

#if (FEATURE_LUA_SCRIPTS && FEATURE_LINC_LUAJIT_MIGRATION)
import llua.State;
import llua.State.StatePointer;

@:unreflective
class Lua
{
  public static inline var TBOOLEAN:Int = 1;
  public static inline var TNUMBER:Int = 3;
  public static inline var TSTRING:Int = 4;
  public static inline var TTABLE:Int = 5;

  /**
   * Keeps a normal linc_luajit Lua state as State.
   */
  public static inline function st(l:State):State
  {
    return l;
  }

  /**
   * Gets the raw Lua state pointer.
   *
   * StatePointer is only used where linc_luajit expects
   * the native callback signature.
   */
  public static inline function raw(s:State):StatePointer
  {
    return cast s;
  }

  /**
   * Registers a native callback as a Lua global function.
   *
   * Delegates directly to linc_luajit's callback registration
   * system so the native lua_State pointer is preserved correctly.
   */
  public static function register(l:State, name:String, f:Dynamic):Void
  {
    llua.Lua.register(l, name, f);
  }

  public static inline function gettop(l:State):Int
  {
    return llua.Lua.gettop(l);
  }

  public static inline function pop(l:State, n:Int):Void
  {
    llua.Lua.pop(l, n);
  }

  public static inline function type(l:State, i:Int):Int
  {
    return llua.Lua.type(l, i);
  }

  public static inline function tostring(l:State, i:Int):String
  {
    return llua.Lua.tostring(l, i);
  }

  public static inline function tonumber(l:State, i:Int):Float
  {
    return llua.Lua.tonumber(l, i);
  }

  public static inline function toboolean(l:State, i:Int):Int
  {
    return llua.Lua.toboolean(l, i) ? 1 : 0;
  }

  public static inline function isfunction(l:State, i:Int):Int
  {
    return llua.Lua.isfunction(l, i) ? 1 : 0;
  }

  public static inline function pushnil(l:State):Void
  {
    llua.Lua.pushnil(l);
  }

  public static inline function pushnumber(l:State, n:Float):Void
  {
    llua.Lua.pushnumber(l, n);
  }

  public static inline function pushstring(l:State, s:String):Void
  {
    llua.Lua.pushstring(l, s);
  }

  public static inline function pushboolean(l:State, b:Int):Void
  {
    llua.Lua.pushboolean(l, b != 0);
  }

  public static inline function newtable(l:State):Void
  {
    llua.Lua.newtable(l);
  }

  public static inline function setglobal(l:State, name:String):Void
  {
    llua.Lua.setglobal(l, name);
  }

  public static inline function getglobal(l:State, name:String):Void
  {
    llua.Lua.getglobal(l, name);
  }

  public static inline function rawseti(l:State, idx:Int, n:Int):Void
  {
    llua.Lua.rawseti(l, idx, n);
  }

  public static inline function rawgeti(l:State, idx:Int, n:Int):Void
  {
    llua.Lua.rawgeti(l, idx, n);
  }

  public static inline function rawlen(l:State, idx:Int):Int
  {
    return llua.Lua.objlen(l, idx);
  }

  public static inline function absindex(l:State, i:Int):Int
  {
    return (i > 0 || i <= llua.Lua.LUA_REGISTRYINDEX) ? i : llua.Lua.gettop(l) + i + 1;
  }

  public static inline function pcall(l:State, nargs:Int, nresults:Int, errfunc:Int):Int
  {
    return llua.Lua.pcall(l, nargs, nresults, errfunc);
  }

  public static inline function close(l:State):Void
  {
    llua.Lua.close(l);
  }
}
#end
