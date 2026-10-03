package funkin.lua.compat;

#if FEATURE_LUA_SCRIPTS
import llua.State;

@:unreflective
class Lua
{
  public static inline var TNIL:Int = 0;
  public static inline var TBOOLEAN:Int = 1;
  public static inline var TNUMBER:Int = 3;
  public static inline var TSTRING:Int = 4;
  public static inline var TTABLE:Int = 5;
  public static inline var TFUNCTION:Int = 6;
  public static inline var REGISTRYINDEX:Int = -10000;

  public static inline function setCallbackHandler(handler:cpp.Callable<State->String->Int>):Void
  {
    llua.Lua.set_callbacks_function(handler);
  }

  public static inline function addCallback(l:State, name:String):Void
  {
    llua.Lua.add_callback_function(l, name);
  }

  public static inline function removeCallback(l:State, name:String):Void
  {
    llua.Lua.remove_callback_function(l, name);
  }

  public static inline function gettop(l:State):Int
  {
    return llua.Lua.gettop(l);
  }

  public static inline function settop(l:State, idx:Int):Void
  {
    llua.Lua.settop(l, idx);
  }

  public static inline function pop(l:State, n:Int):Void
  {
    llua.Lua.pop(l, n);
  }

  public static inline function checkstack(l:State, n:Int):Bool
  {
    return llua.Lua.checkstack(l, n) != 0;
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

  public static inline function tointeger(l:State, i:Int):Int
  {
    return llua.Lua.tointeger(l, i);
  }

  public static inline function toboolean(l:State, i:Int):Bool
  {
    return llua.Lua.toboolean(l, i);
  }

  public static inline function isfunction(l:State, i:Int):Bool
  {
    return llua.Lua.isfunction(l, i) != 0;
  }

  public static inline function pushnil(l:State):Void
  {
    llua.Lua.pushnil(l);
  }

  public static inline function pushnumber(l:State, n:Float):Void
  {
    llua.Lua.pushnumber(l, n);
  }

  public static inline function pushinteger(l:State, n:Int):Void
  {
    llua.Lua.pushinteger(l, n);
  }

  public static inline function pushstring(l:State, s:String):Void
  {
    llua.Lua.pushstring(l, s);
  }

  public static inline function pushboolean(l:State, b:Bool):Void
  {
    llua.Lua.pushboolean(l, b);
  }

  public static inline function pushvalue(l:State, idx:Int):Void
  {
    llua.Lua.pushvalue(l, idx);
  }

  public static inline function newtable(l:State):Void
  {
    llua.Lua.newtable(l);
  }

  public static inline function createtable(l:State, narr:Int, nrec:Int):Void
  {
    llua.Lua.createtable(l, narr, nrec);
  }

  public static inline function next(l:State, idx:Int):Bool
  {
    return llua.Lua.next(l, idx) != 0;
  }

  public static inline function setglobal(l:State, name:String):Void
  {
    llua.Lua.setglobal(l, name);
  }

  public static inline function getglobal(l:State, name:String):Void
  {
    llua.Lua.getglobal(l, name);
  }

  public static inline function setfield(l:State, idx:Int, name:String):Void
  {
    llua.Lua.setfield(l, idx, name);
  }

  public static inline function getfield(l:State, idx:Int, name:String):Void
  {
    llua.Lua.getfield(l, idx, name);
  }

  public static inline function rawseti(l:State, idx:Int, n:Int):Void
  {
    llua.Lua.rawseti(l, idx, n);
  }

  public static inline function rawgeti(l:State, idx:Int, n:Int):Void
  {
    llua.Lua.rawgeti(l, idx, n);
  }

  public static inline function objlen(l:State, idx:Int):Int
  {
    return llua.Lua.objlen(l, idx);
  }

  public static inline function absindex(l:State, i:Int):Int
  {
    return (i > 0 || i <= REGISTRYINDEX) ? i : llua.Lua.gettop(l) + i + 1;
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
