package;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
#end

#if (linux && !macro)
@:image('art/icons/iconOG.png')
class ApplicationIcon extends lime.graphics.Image {}
#end

@:dox(hide)
@:access(lime.app.Application)
@:access(lime.system.System)
@:access(openfl.display.Stage)
@:access(openfl.events.UncaughtErrorEvents)
#if (static_link || ios)
@:cppFileCode("\nextern \"C\" int lime_register_prims ();\n::foreach ndlls::::if (registerStatics)::extern \"C\" int ::nameSafe::_register_prims ();::end::::end::")
#end
class ApplicationMain
{
  #if !macro
  public static function main():Void
  {
    #if (static_link || ios)
    untyped __cpp__("lime_register_prims ()");
    ::foreach ndlls::::if (registerStatics)::untyped __cpp__("::nameSafe::_register_prims ()");::end::::end::
    #end

    #if (windows && cpp)
    funkin.external.windows.WinAPI.disableWindowsGhosting();
    funkin.external.windows.WinAPI.disableErrorReporting();
    #end

    lime.system.System.__registerEntryPoint("::APP_FILE::", create);

    #if !html5
    create(null);
    #end
  }

  public static function create(config:Dynamic):Void
  {
    #if (linux && cpp)
    hxgamemode.GamemodeClient.request_start();
    #end

    ::if (WIN_ORIENTATION != "auto")::
    lime.system.System.setHint("ORIENTATIONS", ::if (WIN_ORIENTATION == "portrait")::"Portrait PortraitUpsideDown"::else::"LandscapeLeft LandscapeRight"::end::);
    ::end::

    final appMeta:Map<String, String> = [
      "build" => "::meta.buildNumber::",
      "company" => "::meta.company::",
      "file" => "::APP_FILE::",
      "name" => "::meta.title::",
      "packageName" => "::meta.packageName::",
      "version" => "::meta.version::"
    ];

    var app = new openfl.display.Application(appMeta);

    #if linux
    app.onCreateWindow.add(function(window:lime.ui.Window):Void
    {
      window.setIcon(new ApplicationIcon());
    });
    #end

    ::foreach windows::
    {
      var attributes:lime.ui.WindowAttributes = {
        allowHighDPI: ::allowHighDPI::,
        alwaysOnTop: ::alwaysOnTop::,
        transparent: ::transparent::,
        borderless: ::borderless::,
        element: null,
        frameRate: ::fps::,
        #if !web
        fullscreen: ::fullscreen::,
        #end
        height: ::height::,
        hidden: ::hidden::,
        maximized: ::maximized::,
        minimized: ::minimized::,
        parameters: ::parameters::,
        resizable: ::resizable::,
        title: "::title::",
        width: ::width::,
        x: ::x::,
        y: ::y::,
      };

      attributes.context = {
        antialiasing: ::antialiasing::,
        background: ::background::,
        colorDepth: ::colorDepth::,
        depth: ::depthBuffer::,
        hardware: ::hardware::,
        #if (html5 && FEATURE_SCREENSHOTS)
        preserveDrawingBuffer: true,
        #end
        stencil: ::stencilBuffer::,
        type: null,
        vsync: ::vsync::
      };

      if (app.window == null)
      {
        applyConfig(attributes, config);
      }

      app.createWindow(attributes);
    }
    ::end::

    var preloader = getPreloader();

    app.preloader.onProgress.add(function(loaded, total)
    {
      @:privateAccess preloader.update(loaded, total);
    });

    app.preloader.onComplete.add(function()
    {
      @:privateAccess preloader.start();
    });

    preloader.onComplete.add(start.bind((cast app.window:openfl.display.Window).stage));

    #if !disable_preloader_assets
    ManifestResources.init(config);

    for (library in ManifestResources.preloadLibraries)
    {
      app.preloader.addLibrary(library);
    }

    for (name in ManifestResources.preloadLibraryNames)
    {
      app.preloader.addLibraryName(name);
    }
    #end

    app.preloader.load();

    shutdown(app.exec());
  }

  public static function start(stage:openfl.display.Stage):Void
  {
    if (stage.__uncaughtErrorEvents.__enabled)
    {
      try
      {
        launch(stage);
      }
      catch (e:Dynamic)
      {
        #if !display
        stage.__handleError(e);
        #end
      }
    }
    else
    {
      launch(stage);
    }
  }

  static function launch(stage:openfl.display.Stage):Void
  {
    ApplicationMain.getEntryPoint();

    stage.dispatchEvent(new openfl.events.Event(openfl.events.Event.RESIZE, false, false));

    if (stage.window.fullscreen)
    {
      stage.dispatchEvent(new openfl.events.FullScreenEvent(openfl.events.FullScreenEvent.FULL_SCREEN, false, false, true, true));
    }
  }

  static function applyConfig(attributes:lime.ui.WindowAttributes, config:Dynamic):Void
  {
    if (config == null) return;

    for (field in Reflect.fields(config))
    {
      if (Reflect.hasField(attributes, field))
      {
        Reflect.setField(attributes, field, Reflect.field(config, field));
      }
      else if (Reflect.hasField(attributes.context, field))
      {
        Reflect.setField(attributes.context, field, Reflect.field(config, field));
      }
    }
  }

  static function shutdown(result:Int):Void
  {
    #if (linux && cpp)
    hxgamemode.GamemodeClient.request_end();
    #end

    #if (sys && !ios && !nodejs)
    lime.system.System.exit(result);
    #end
  }
  #end

  #if macro
  static function extendsOpenFLPreloader(classType:haxe.macro.Type.ClassType):Bool
  {
    var current:Null<haxe.macro.Type.ClassType> = classType;

    while (current != null)
    {
      if (current.pack.length == 2 && current.pack[0] == "openfl" && current.pack[1] == "display" && current.name == "Preloader")
      {
        return true;
      }

      current = current.superClass != null ? current.superClass.t.get() : null;
    }

    return false;
  }
  #end

  macro public static function getEntryPoint()
  {
    switch (Context.follow(Context.getType("::APP_MAIN::")))
    {
      case TInst(t, _):
        var type = t.get();

        for (method in type.statics.get())
        {
          if (method.name == "main")
          {
            return Context.parse("@:privateAccess ::APP_MAIN::.main()", Context.currentPos());
          }
        }

        if (type.constructor != null)
        {
          return macro
          {
            var current = stage.getChildAt(0);

            if (current == null || !(current is openfl.display.DisplayObjectContainer))
            {
              current = new openfl.display.MovieClip();
              stage.addChild(current);
            }

            new DocumentClass(cast current);
          };
        }

        Context.fatalError("Main class \"::APP_MAIN::\" has neither a static main nor a constructor.", Context.currentPos());

      default:
        Context.fatalError("Main class \"::APP_MAIN::\" isn't a class.", Context.currentPos());
    }

    return null;
  }

  macro public static function getPreloader()
  {
    ::if (PRELOADER_NAME != "")::
    switch (Context.getType("::PRELOADER_NAME::"))
    {
      case TInst(classType, _) if (extendsOpenFLPreloader(classType.get())):
        return macro new ::PRELOADER_NAME::();

      default:
    }

    return macro new openfl.display.Preloader(new ::PRELOADER_NAME::());
    ::else::
    return macro new openfl.display.Preloader(new openfl.display.Preloader.DefaultPreloader());
    ::end::
  }

  #if !macro
  @:noCompletion @:dox(hide) public static function __init__()
  {
    var init = lime.app.Application;
  }
  #end
}
