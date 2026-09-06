package funkin.graphics.away3d;

#if FEATURE_AWAY3D
import away3d.containers.View3D;
import away3d.containers.Scene3D;
import away3d.cameras.Camera3D;
import away3d.loaders.Loader3D;
import openfl.net.URLRequest;
import openfl.events.Event;
import openfl.geom.Vector3D;

class FunkinAway3D
{
  public var view(default, null):View3D;
  public var scene(default, null):Scene3D;
  public var camera(default, null):Camera3D;

  var attachedToStage:Bool = false;
  var loaders:Array<Loader3D> = [];

  public function new(width:Int, height:Int)
  {
    scene = new Scene3D();
    camera = new Camera3D();
    view = new View3D(scene, camera);
    view.width = width;
    view.height = height;
  }

  public function attachToStage():Void
  {
    if (attachedToStage) return;

    openfl.Lib.current.stage.addChild(view);
    openfl.Lib.current.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);

    attachedToStage = true;
  }

  public function detachFromStage():Void
  {
    if (!attachedToStage) return;

    openfl.Lib.current.stage.removeEventListener(Event.ENTER_FRAME, onEnterFrame);

    if (view.parent != null) view.parent.removeChild(view);

    attachedToStage = false;
  }

  function onEnterFrame(event:Event):Void
  {
    view.render();
  }

  public function loadModel(url:String, useAssetLibrary:Bool = true):Loader3D
  {
    var loader:Loader3D = new Loader3D(useAssetLibrary);

    scene.addChild(loader);
    loader.load(new URLRequest(url));

    loaders.push(loader);

    return loader;
  }

  public function setViewPosition(x:Float, y:Float):Void
  {
    view.x = x;
    view.y = y;
  }

  public function setCameraPosition(x:Float, y:Float, z:Float):Void
  {
    camera.x = x;
    camera.y = y;
    camera.z = z;
  }

  public function pointCameraAt(x:Float, y:Float, z:Float):Void
  {
    camera.lookAt(new Vector3D(x, y, z));
  }

  public function resize(width:Int, height:Int):Void
  {
    view.width = width;
    view.height = height;
  }

  public function dispose():Void
  {
    detachFromStage();

    for (loader in loaders)
    {
      loader.stopLoad();
    }

    loaders = [];

    view.dispose();
  }
}
#end
