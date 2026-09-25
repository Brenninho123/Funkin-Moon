package funkin.modding.module;

import flixel.FlxG;
import funkin.data.BaseRegistry.LoadEntriesResult;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEventDispatcher;
import funkin.modding.module.Module;
import funkin.modding.PolymodHandler;
import funkin.util.SortUtil;
import funkin.util.tasks.TaskHandler;
import hx.concurrent.collection.SynchronizedArray;
import lime.app.Future;
import lime.app.Promise;
#if FEATURE_MULTITHREADING
import hx.concurrent.collection.SynchronizedMap;
#end
#if FEATURE_LUA_SCRIPTS
import funkin.lua.module.LuaModule;
#end

/**
 * Utility functions for loading and manipulating active modules.
 */
@:nullSafety
class ModuleHandler
{
  #if FEATURE_MULTITHREADING
  static final moduleCache:SynchronizedMap<String, Module> = SynchronizedMap.newStringMap();
  static var modulePriorityOrder:SynchronizedArray<String> = new SynchronizedArray<String>();
  #else
  static final moduleCache:Map<String, Module> = new Map<String, Module>();
  static var modulePriorityOrder:Array<String> = [];
  #end

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

    var scriptedModuleClassNames:Array<String> = Module.listScriptClasses();

    trace(' Instantiating ${scriptedModuleClassNames.length} modules...');

    for (moduleCls in scriptedModuleClassNames)
    {
      var module:Null<Module> = Module.scriptInit(moduleCls, moduleCls);

      if (module != null)
      {
        onModuleLoaded(module, moduleCls);
      }
      else
      {
        trace('   Failed to instantiate module: ${moduleCls}');
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

  #if FEATURE_MULTITHREADING
  public static function loadModuleCacheAsync():Future<LoadEntriesResult>
  {
    // Clear module cache first.
    clearModuleCache();

    var scriptedModuleClassNames:SynchronizedArray<String> = new SynchronizedArray(Module.listScriptClasses());

    var promise:Promise<LoadEntriesResult> = new Promise<LoadEntriesResult>();

    // We don't have any modules to load so we can just immediately complete the promise.
    if (scriptedModuleClassNames.length == 0)
    {
      #if FEATURE_LUA_SCRIPTS
      loadLuaModules();
      #end

      reorderModuleCache();

      promise.complete({
        entriesLoaded: 0,
        entriesFailed: 0,
      });

      return promise.future;
    }

    var entryErrors:SynchronizedArray<
      {
        moduleId:String,
        error:Any,
        ?moduleCls:String
      }> = new SynchronizedArray();

    var moduleCount:Int = scriptedModuleClassNames.length;

    var perf:funkin.util.logging.Perf = new funkin.util.logging.Perf('loadModuleCacheAsync()');

    var checkAsyncProgress:Void->Void = () ->
    {
      var completedCount = getModuleCount() + entryErrors.length;

      if (completedCount == moduleCount)
      {
        // ---------------------------------------------------------
        // LUA MODULES
        // ---------------------------------------------------------
        // HScript modules have finished loading at this point,
        // so now scan the enabled mods for Lua modules.
        #if FEATURE_LUA_SCRIPTS
        loadLuaModules();
        #end

        promise.complete({
          entriesLoaded: getModuleCount(),
          entriesFailed: entryErrors.length
        });

        trace('Finished loading modules ($completedCount / $moduleCount)');

        perf.print();

        reorderModuleCache();
      }
    };

    // Called when an error occurs while a module was being loaded.
    var onError:(String,
      {error:Any, moduleCls:Null<String>}) -> Void = (moduleId, state) ->
      {
        entryErrors.push({
          moduleId: moduleId,
          error: state.error
        });

        trace('  Failed to load module (${moduleId}): ${state.error}');

        checkAsyncProgress();
      };

    // Called once a module's task has been completed.
    var onModuleLoadedAsync:(String,
      {module:Module, moduleCls:String}) -> Void = (_, state) ->
      {
        onModuleLoaded(state.module, state.moduleCls);
        checkAsyncProgress();
      };

    // Task for loading a single module.
    var loadModuleAsync:Task = (currentState:State, workOutput:WorkOutput) ->
    {
      var moduleCls:String = currentState.moduleCls;

      try
      {
        var module:Null<Module> = funkin.util.tasks.ScriptLock.run(() -> Module.scriptInit(moduleCls, moduleCls));

        if (module != null)
        {
          workOutput.sendComplete({
            moduleCls: moduleCls,
            module: module
          }, []);
        }
        else
        {
          workOutput.sendError({
            moduleCls: moduleCls,
            error: 'Failed to create module (${moduleCls})'
          });
        }
      }
      catch (e)
      {
        workOutput.sendError({
          moduleCls: moduleCls,
          error: e,
        });
      }
    };

    // Perform a task to load each module.
    trace(' Instantiating ${scriptedModuleClassNames.length} modules...');

    for (moduleCls in scriptedModuleClassNames)
    {
      var loadModuleFuture = TaskHandler.performTask({
        task: loadModuleAsync,
        initialState: {
          moduleCls: moduleCls
        }
      }, new Promise<
        {module:Module, moduleCls:String}>());

      loadModuleFuture.onError(onError.bind(moduleCls));
      loadModuleFuture.onComplete(onModuleLoadedAsync.bind(moduleCls));
    }

    return promise.future;
  }
  #end

  /**
   * Loads every Lua script inside every currently loaded mod.
   *
   * Lua scripts can be placed anywhere inside the mod folder.
   *
   * Examples:
   *
   * mods/MyMod/test.lua
   * mods/MyMod/scripts/test.lua
   * mods/MyMod/data/test.lua
   * mods/MyMod/anything/deep/test.lua
   */
  #if FEATURE_LUA_SCRIPTS
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

  static function onModuleLoaded(module:Module, moduleCls:String):Void
  {
    addToModuleCache(module);
    trace('   Loaded module: ${moduleCls}');
  }

  static function getModuleCount():Int
  {
    return moduleCache.size();
  }

  static function onStateSwitchComplete():Void
  {
    var event:StateChangeScriptEvent = StateChangeScriptEvent.get(STATE_CHANGE_END, FlxG.state, true);

    callEvent(event);

    event.finish();
  }

  static function addToModuleCache(module:Module):Void
  {
    moduleCache.set(module.moduleId, module);
  }

  static function reorderModuleCache():Void
  {
    #if FEATURE_MULTITHREADING
    var sortedArray:Array<String> = moduleCache.keys().array();

    sortedArray.sort(sortByPriority);

    modulePriorityOrder = new SynchronizedArray<String>(sortedArray);
    #else
    modulePriorityOrder = moduleCache.keys().array();

    modulePriorityOrder.sort(sortByPriority);
    #end
  }

  /**
   * Given two module IDs, sort them by priority.
   *
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
      var event = ScriptEvent.get(DESTROY);

      // Note: Ignore stopPropagation()
      for (key => value in moduleCache)
      {
        ScriptEventDispatcher.callEvent(value, event);
      }

      moduleCache.clear();

      #if FEATURE_MULTITHREADING
      modulePriorityOrder.clear();
      #else
      modulePriorityOrder = [];
      #end

      event.finish();
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
        // Only call the event if the module's state is active.
        if (!isStateActive(module.state)) continue;

        ScriptEventDispatcher.callEvent(module, event);
      }
    }
  }

  static function isStateActive(stateToFind:Null<Class<Dynamic>>):Bool
  {
    if (stateToFind == null) return true;

    var state:Null<flixel.FlxState> = FlxG.state;

    while (state != null && !Std.isOfType(state, stateToFind))
    {
      state = state?.subState;
    }

    return state != null;
  }

  public static inline function callOnCreate():Void
  {
    var event:ScriptEvent = ScriptEvent.get(CREATE);

    callEvent(event);

    event.finish();
  }
}
