package funkin.graphics.render3d;

import foxlite.FoxScene;
import foxlite.FoxCamera;
import foxlite.FoxModel;
import foxlite.FoxObject;
import foxlite.loaders.FoxGLTFLoader;
import foxlite.loaders.FoxGLTFLoader.GLTFData;
import foxlite.group.FoxObjectGroup;
import flixel.util.FlxSignal.FlxTypedSignal;

class Funkin3D
{
  public var scene(default, null):FoxScene;

  public var camera(default, null):FoxCamera;

  public var onModelLoaded:FlxTypedSignal<FoxObjectGroup->Void> = new FlxTypedSignal<FoxObjectGroup->Void>();

  var loadedGroups:Array<FoxObjectGroup> = [];

  public function new(width:Int, height:Int)
  {
    scene = new FoxScene(width, height);
    scene.setupBuffers(width, height);

    camera = new FoxCamera(0, 0, -10);
    scene.foxCameras.push(camera);

    scene.setOutputDisplay('default');
  }

  public function loadGLTFModel(assetPath:String, ?extraShaderFlags:Array<String>, ?customShaderPath:String):Array<FoxObjectGroup>
  {
    var gltf:GLTFData = FoxGLTFLoader.load(assetPath, extraShaderFlags, customShaderPath);
    return addGLTFScenes(gltf);
  }

  public function loadGLTFBinary(assetPath:String, ?extraShaderFlags:Array<String>, ?customShaderPath:String):Array<FoxObjectGroup>
  {
    var gltf:GLTFData = FoxGLTFLoader.loadBinary(assetPath, extraShaderFlags, customShaderPath);
    return addGLTFScenes(gltf);
  }

  function addGLTFScenes(gltf:GLTFData):Array<FoxObjectGroup>
  {
    var groups:Array<FoxObjectGroup> = FoxGLTFLoader.buildScenes(gltf);

    for (group in groups)
    {
      scene.add(group);
      loadedGroups.push(group);
      onModelLoaded.dispatch(group);
    }

    return groups;
  }

  public function addModel(model:FoxModel):FoxModel
  {
    scene.add(model);
    return model;
  }

  public function removeModel(model:FoxModel):Void
  {
    scene.remove(model);
  }

  public function setCameraPosition(x:Float, y:Float, z:Float):Void
  {
    camera.setPosition(x, y, z);
  }

  public function setCameraAngle(x:Float, y:Float, z:Float):Void
  {
    camera.setAngle(x, y, z);
  }

  public function setCameraFov(fov:Float):Void
  {
    camera.fov = fov;
  }

  public function findObjectByName(name:String):Null<FoxObject>
  {
    for (group in loadedGroups)
    {
      var found:Null<FoxObject> = group.getFirstByName(name);
      if (found != null) return found;
    }

    return null;
  }

  public function findObjectsByName(name:String):Array<FoxObject>
  {
    var result:Array<FoxObject> = [];

    for (group in loadedGroups)
    {
      result = result.concat(group.getByName(name));
    }

    return result;
  }

  public function resize(width:Int, height:Int):Void
  {
    scene.setupBuffers(width, height);
  }

  public function destroy():Void
  {
    scene.disposeBuffers();
    loadedGroups = [];
  }
}
