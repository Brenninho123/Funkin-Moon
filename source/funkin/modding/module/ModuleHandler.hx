package funkin.modding.module;

import funkin.util.SortUtil;
import funkin.modding.events.ScriptEvent.UpdateScriptEvent;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEventDispatcher;
import funkin.modding.module.Module;
import funkin.modding.module.ScriptedModule;
import funkin.modding.PolymodHandler;
import flixel.FlxG;
#if FEATURE_LUA_SCRIPTS
import funkin.lua.module.LuaModule;
#end

/**
 * Utility functions for loading and manipulating active modules.
 */
@:nullSafety
class ModuleHandler
{
  static final moduleCache:Map<String, Module> = new Map<String, Module>();
  static var modulePriorityOrder:Array<String> = [];

  /**
   * Parses and preloads the game's modules and scripts when the game starts.
   *
   * If you want to force modules to be reloaded, you can just call this function again.
   */
  public static function loadModuleCache():Void
  {
    // Clear any modules that are cached if there were any.
    clearModuleCache();

    trace('[MODULEHANDLER] Loading module cache...');

    // ---------------------------------------------------------
    // HSCRIPT MODULES
    // ---------------------------------------------------------

    var scriptedModuleClassNames:Array<String> = ScriptedModule.listScriptClasses();

    trace(' Instantiating ${scriptedModuleClassNames.length} HScript modules...');

    for (moduleCls in scriptedModuleClassNames)
    {
      var module:Module = ScriptedModule.scriptInit(moduleCls, moduleCls);

      if (module != null)
      {
        trace('   Loaded HScript module: ${moduleCls}');
        addToModuleCache(module);
      }
      else
      {
        trace('   Failed to instantiate HScript module: ${moduleCls}');
      }
    }

    // ---------------------------------------------------------
    // LUA MODULES
    // ---------------------------------------------------------

    #if FEATURE_LUA_SCRIPTS
    loadLuaModules();
    #end

    reorderModuleCache();

    trace('[MODULEHANDLER] Module cache loaded.');
  }

  #if FEATURE_LUA_SCRIPTS
  /**
   * Finds every Lua script inside every currently loaded mod.
   *
   * Lua files can be placed anywhere inside the mod folder.
   *
   * Example:
   *
   * mods/MyMod/test.lua
   * mods/MyMod/scripts/test.lua
   * mods/MyMod/data/test.lua
   * mods/MyMod/anything/deep/test.lua
   */
  static function loadLuaModules():Void
  {
    #if sys
    var loadedMods:Array<String> = PolymodHandler.loadedModDirs;
    var modRoot:String = PolymodHandler.getModFolder();

    trace(' Loading Lua modules from ${loadedMods.length} enabled mods...');

    for (modDir in loadedMods)
    {
      var modPath:String = '$modRoot/$modDir';

      if (!sys.FileSystem.exists(modPath))
      {
        trace('[MODULEHANDLER] Lua mod directory not found: $modPath');
        continue;
      }

      if (!sys.FileSystem.isDirectory(modPath))
      {
        continue;
      }

      scanLuaDirectory(modPath, modDir);
    }
    #end
  }

  #if sys
  /**
   * Recursively scans a directory for .lua files.
   */
  static function scanLuaDirectory(path:String, modDir:String):Void
  {
    if (!sys.FileSystem.exists(path) || !sys.FileSystem.isDirectory(path))
    {
      return;
    }

    for (entry in sys.FileSystem.readDirectory(path))
    {
      var fullPath:String = '$path/$entry';

      if (sys.FileSystem.isDirectory(fullPath))
      {
        scanLuaDirectory(fullPath, modDir);
      }
      else if (StringTools.endsWith(entry.toLowerCase(), '.lua'))
      {
        loadLuaModule(fullPath, modDir);
      }
    }
  }
  #end

  /**
   * Creates a LuaModule from a Lua script.
   */
  static function loadLuaModule(scriptPath:String, modDir:String):Void
  {
    #if sys
    var normalizedPath:String = scriptPath.split('\\').join('/');

    var modRoot:String = PolymodHandler.getModFolder();
    var modPrefix:String = '$modRoot/$modDir/';

    var relativePath:String = normalizedPath;

    if (StringTools.startsWith(relativePath, modPrefix))
    {
      relativePath = relativePath.substr(modPrefix.length);
    }

    // Remove the .lua extension.
    if (StringTools.endsWith(relativePath.toLowerCase(), '.lua'))
    {
      relativePath = relativePath.substr(0, relativePath.length - 4);
    }

    // Make the module ID unique to the mod.
    var moduleId:String = 'lua:$modDir:$relativePath';

    // Avoid loading the same Lua script twice.
    if (moduleCache.exists(moduleId))
    {
      trace('[MODULEHANDLER] Lua module already loaded: $moduleId');
      return;
    }

    try
    {
      var module:LuaModule = new LuaModule(normalizedPath, moduleId);

      addToModuleCache(module);

      trace('   Loaded Lua module: $normalizedPath');
    }
    catch (e:Dynamic)
    {
      trace('[MODULEHANDLER] Failed to load Lua module: $normalizedPath');
      trace('[MODULEHANDLER] Error: $e');
    }
    #end
  }
  #end

  public static function buildModuleCallbacks():Void
  {
    FlxG.signals.postStateSwitch.add(onStateSwitchComplete);
  }

  static function onStateSwitchComplete():Void
  {
    callEvent(new StateChangeScriptEvent(STATE_CHANGE_END, FlxG.state, true));
  }

  static function addToModuleCache(module:Module):Void
  {
    moduleCache.set(module.moduleId, module);
  }

  static function reorderModuleCache():Void
  {
    modulePriorityOrder = moduleCache.keys().array();
    modulePriorityOrder.sort(sortByPriority);
  }

  /**
   * Given two module IDs, sort them by priority.
   * @return 1 or -1 depending on which module has a higher priority.
   */
  static function sortByPriority(a:String, b:String):Int
  {
    var aModule:Null<Module> = getModule(a);
    var bModule:Null<Module> = getModule(b);

    if (aModule == null || bModule == null)
    {
      return 0;
    }

    if (aModule.priority != bModule.priority)
    {
      return aModule.priority - bModule.priority;
    }
    else
    {
      return SortUtil.alphabetically(a, b);
    }
  }

  public static function getModule(moduleId:String):Null<Module>
  {
    return moduleCache.get(moduleId);
  }

  public static function activateModule(moduleId:String):Void
  {
    var module:Null<Module> = getModule(moduleId);

    if (module != null)
    {
      module.active = true;
    }
  }

  public static function deactivateModule(moduleId:String):Void
  {
    var module:Null<Module> = getModule(moduleId);

    if (module != null)
    {
      module.active = false;
    }
  }

  /**
   * Clear the module cache, forcing all modules to call shutdown events.
   */
  public static function clearModuleCache():Void
  {
    if (moduleCache != null)
    {
      var event = new ScriptEvent(DESTROY, false);

      // Note: Ignore stopPropagation()
      for (key => value in moduleCache)
      {
        ScriptEventDispatcher.callEvent(value, event);
      }

      moduleCache.clear();
      modulePriorityOrder = [];
    }
  }

  public static function callEvent(event:ScriptEvent):Void
  {
    for (moduleId in modulePriorityOrder)
    {
      var module:Null<Module> = moduleCache.get(moduleId);

      // The module needs to be active to receive events.
      if (module != null && module.active)
      {
        if (module.state != null)
        {
          // Only call the event if the current state is what the module's state is.
          if (!(Type.getClass(FlxG.state) == module.state) && !(Type.getClass(FlxG.state?.subState) == module.state))
          {
            continue;
          }
        }

        ScriptEventDispatcher.callEvent(module, event);
      }
    }
  }

  public static inline function callOnCreate():Void
  {
    callEvent(new ScriptEvent(CREATE, false));
  }
}
