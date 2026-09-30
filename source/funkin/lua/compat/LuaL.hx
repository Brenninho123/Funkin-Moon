package funkin.lua.compat;

#if (FEATURE_LUA_SCRIPTS && FEATURE_LINC_LUAJIT_MIGRATION)
import llua.State;

@:unreflective
class LuaL
{
  public static inline function newstate():State return llua.LuaL.newstate();

  public static function openlibs(l:State):Void llua.LuaL.openlibs(l);

  public static function dofile(l:State, path:String):Int return llua.LuaL.dofile(l, path);
}
#end
