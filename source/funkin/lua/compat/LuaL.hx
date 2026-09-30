package funkin.lua.compat;

#if FEATURE_LUA_SCRIPTS
import llua.State;

@:unreflective
class LuaL
{
  public static inline function newstate():State
  {
    return llua.LuaL.newstate();
  }

  public static inline function openlibs(l:State):Void
  {
    llua.LuaL.openlibs(l);
  }

  public static inline function dofile(l:State, path:String):Int
  {
    return llua.LuaL.dofile(l, path);
  }

  public static inline function dostring(l:State, code:String):Int
  {
    return llua.LuaL.dostring(l, code);
  }
}
#end
