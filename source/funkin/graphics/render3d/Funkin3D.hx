package funkin.graphics.render3d;

#if FEATURE_3D_RENDERING
import flixel.util.FlxColor;
import flixel.util.FlxSignal.FlxTypedSignal;
import foxlite.FoxCamera;
import foxlite.FoxModel;
import foxlite.FoxObject;
import foxlite.FoxScene;
import foxlite.extras.FoxOrbitCamera;
import foxlite.group.FoxObjectGroup;
import foxlite.lights.FoxBaseLight;
import foxlite.lights.FoxDirectionalLight;
import foxlite.lights.FoxPointLight;
import foxlite.loaders.FoxGLTFLoader;
import foxlite.loaders.FoxGLTFLoader.GLTFData;
import foxlite.material.FoxMaterial;
import foxlite.mesh.FoxCubeMesh;
import foxlite.mesh.FoxLineMesh;
import foxlite.mesh.FoxMesh;
import foxlite.mesh.FoxQuadFace;
import foxlite.mesh.FoxQuadMesh;
import foxlite.renderer.FoxRenderer;
import funkin.graphics.render3d.Mesh3D;
import openfl.geom.Vector3D;

class Funkin3D
{
  public var scene(default, null):FoxScene;

  public var camera(default, null):FoxCamera;

  public var width(default, null):Int;

  public var height(default, null):Int;

  public var sun(default, null):Null<FoxDirectionalLight> = null;

  public var models(default, null):Array<FoxModel> = [];

  public var lights(default, null):Array<FoxBaseLight> = [];

  public var onModelLoaded:FlxTypedSignal<FoxObjectGroup->Void> = new FlxTypedSignal<FoxObjectGroup->Void>();

  var loadedGroups:Array<FoxObjectGroup> = [];
  var named:Map<String, FoxObject> = new Map();
  var destroyed:Bool = false;

  public function new(width:Int, height:Int, background:FlxColor = 0x00000000)
  {
    this.width = width;
    this.height = height;

    funkin.assets.Paths3D.installFoxliteBridge();

    if (!FoxRenderer.initialized) FoxRenderer.initLibs();

    scene = new FoxScene(width, height);

    camera = new FoxCamera(0, 1.5, -8, background);
    scene.foxCameras.push(camera);
    scene.setOutputDisplay('default');
    scene.environment.ambientLight = 0xFF3A3F55;
  }

  public function setBackground(color:FlxColor):Void
  {
    camera.bgColor = color;
  }

  public function setAmbient(color:FlxColor):Void
  {
    scene.environment.ambientLight = color;
  }

  public function setFog(color:FlxColor, start:Float, end:Float):Void
  {
    scene.environment.fogColor = color;
    scene.environment.fogStart = start;
    scene.environment.fogEnd = end;
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

  public function lookAt(x:Float, y:Float, z:Float):Void
  {
    var dx:Float = x - camera.x;
    var dy:Float = y - camera.y;
    var dz:Float = z - camera.z;
    var flat:Float = Math.sqrt(dx * dx + dz * dz);

    camera.setAngle(Math.atan2(dy, flat) * 180 / Math.PI, Math.atan2(-dx, -dz) * 180 / Math.PI, 0);
  }

  public function useOrbitCamera(distance:Float = -8):FoxOrbitCamera
  {
    var orbit:FoxOrbitCamera = new FoxOrbitCamera(distance, camera.x, camera.y, camera.z, camera.bgColor);
    var index:Int = scene.foxCameras.indexOf(camera);

    orbit.fov = camera.fov;

    if (index >= 0) scene.foxCameras[index] = orbit;
    else
      scene.foxCameras.push(orbit);

    camera.destroy();
    camera = orbit;

    return orbit;
  }

  public function createMaterial(color:FlxColor = 0xFFFFFFFF, lit:Bool = true, roughness:Float = 0.6, metallic:Float = 0.0, emissive:FlxColor = 0xFF000000):FoxMaterial
  {
    var material:FoxMaterial = lit ? FoxMaterial.createBasic(['SOLID']) : FoxMaterial.createMinimal(['SOLID']);

    material.setColor(color);

    if (lit)
    {
      material.setRoughness(roughness);
      material.setMetallic(metallic);
      material.setEmissiveColor(emissive);
    }

    return material;
  }

  public function addMesh(mesh:FoxMesh, x:Float = 0, y:Float = 0, z:Float = 0, ?name:String):FoxModel
  {
    var model:FoxModel = new FoxModel(x, y, z);

    model.frustumCulling = false;
    model.addMesh(mesh);
    scene.add(model);
    models.push(model);

    if (name != null) named.set(name, model);

    return model;
  }

  public function addBox(width:Float, height:Float, depth:Float, color:FlxColor = 0xFFFFFFFF, x:Float = 0, y:Float = 0, z:Float = 0, ?name:String):FoxModel
  {
    return addMesh(new FoxCubeMesh(width, height, depth, createMaterial(color)), x, y, z, name);
  }

  public function addPlane(width:Float, depth:Float, color:FlxColor = 0xFFFFFFFF, x:Float = 0, y:Float = 0, z:Float = 0, ?name:String):FoxModel
  {
    var material:FoxMaterial = createMaterial(color);

    material.culling = foxlite.material.FoxTriangleFace.NONE;

    return addMesh(new FoxQuadMesh(width, depth, material, FoxQuadFace.Y), x, y, z, name);
  }

  public function addSphere(radius:Float, color:FlxColor = 0xFFFFFFFF, segments:Int = 24, x:Float = 0, y:Float = 0, z:Float = 0, ?name:String):FoxModel
  {
    return addMesh(Mesh3D.sphere(radius, segments, createMaterial(color)), x, y, z, name);
  }

  public function addCylinder(radius:Float, height:Float, color:FlxColor = 0xFFFFFFFF, segments:Int = 24, x:Float = 0, y:Float = 0, z:Float = 0, ?name:String):FoxModel
  {
    return addMesh(Mesh3D.cylinder(radius, height, segments, createMaterial(color)), x, y, z, name);
  }

  public function addTorus(radius:Float, tube:Float, color:FlxColor = 0xFFFFFFFF, rings:Int = 32, sides:Int = 16, x:Float = 0, y:Float = 0, z:Float = 0,
      ?name:String):FoxModel
  {
    return addMesh(Mesh3D.torus(radius, tube, rings, sides, createMaterial(color)), x, y, z, name);
  }

  public function addGrid(size:Float, divisions:Int, color:FlxColor = 0xFF8888FF, y:Float = 0, ?name:String):FoxModel
  {
    var lines:FoxLineMesh = new FoxLineMesh(FoxMaterial.createLine());
    var half:Float = size / 2;
    var step:Float = size / divisions;

    for (i in 0...divisions + 1)
    {
      var offset:Float = -half + i * step;

      lines.addLine(new Vector3D(offset, 0, -half), new Vector3D(offset, 0, half), color, color);
      lines.addLine(new Vector3D(-half, 0, offset), new Vector3D(half, 0, offset), color, color);
    }

    lines.build();
    lines.calculateBounds(lines.linePositions);

    var model:FoxModel = addMesh(lines, 0, y, 0, name);

    model.frustumCulling = false;

    return model;
  }

  public function addDirectionalLight(color:FlxColor = 0xFFFFFFFF, energy:Float = 1, pitch:Float = -45, yaw:Float = 30, shadow:Bool = false):FoxDirectionalLight
  {
    var light:FoxDirectionalLight = new FoxDirectionalLight(0, 0, 0, color, energy, shadow);

    light.setAngle(pitch, yaw, 0);
    scene.add(light);
    lights.push(light);

    if (sun == null) sun = light;

    return light;
  }

  public function addPointLight(x:Float, y:Float, z:Float, color:FlxColor = 0xFFFFFFFF, energy:Float = 1, range:Float = 8):FoxPointLight
  {
    var light:FoxPointLight = new FoxPointLight(x, y, z, color, energy, range);

    scene.add(light);
    lights.push(light);

    return light;
  }

  public function loadModel(key:String):Array<FoxObjectGroup>
  {
    var path:Null<String> = funkin.assets.Paths3D.resolveModel(key);

    if (path == null)
    {
      FlxG.log.warn('[Funkin3D] Model "$key" was not found.');
      return [];
    }

    return switch (haxe.io.Path.extension(path).toLowerCase())
    {
      case 'glb': addGLTFScenes(FoxGLTFLoader.loadBinary(path));
      case 'gltf': addGLTFScenes(FoxGLTFLoader.load(path));
      case 'obj': addOBJ(path);
      default: [];
    };
  }

  public function loadGLTFModel(assetPath:String, ?extraShaderFlags:Array<String>, ?customShaderPath:String):Array<FoxObjectGroup>
  {
    return addGLTFScenes(FoxGLTFLoader.load(assetPath, extraShaderFlags, customShaderPath));
  }

  public function loadGLTFBinary(assetPath:String, ?extraShaderFlags:Array<String>, ?customShaderPath:String):Array<FoxObjectGroup>
  {
    return addGLTFScenes(FoxGLTFLoader.loadBinary(assetPath, extraShaderFlags, customShaderPath));
  }

  function addOBJ(path:String):Array<FoxObjectGroup>
  {
    var data = foxlite.loaders.FoxOBJLoader.load(path);
    var group:FoxObjectGroup = new FoxObjectGroup();

    for (mesh in data.meshes)
    {
      var model:FoxModel = new FoxModel();

      model.frustumCulling = false;
      model.addMesh(mesh);
      group.add(model);
      models.push(model);
    }

    scene.add(group);
    loadedGroups.push(group);
    onModelLoaded.dispatch(group);

    return [group];
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
    models.push(model);

    return model;
  }

  public function removeModel(model:FoxModel):Void
  {
    scene.remove(model);
    models.remove(model);

    for (key => value in named)
    {
      if (value == model) named.remove(key);
    }
  }

  public function get(name:String):Null<FoxObject>
  {
    return named.get(name) ?? findObjectByName(name);
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
    this.width = width;
    this.height = height;

    scene.setupBuffers(width, height);
  }

  public function destroy():Void
  {
    if (destroyed) return;

    destroyed = true;

    onModelLoaded.removeAll();
    scene.disposeBuffers();

    loadedGroups = [];
    models = [];
    lights = [];
    named.clear();
    sun = null;
  }
}
#end
