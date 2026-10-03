package funkin.lua;

#if (FEATURE_LUA_SCRIPTS && FEATURE_3D_RENDERING)
import flixel.util.FlxColor;
import foxlite.FoxModel;
import foxlite.FoxObject;
import foxlite.group.FoxObjectGroup;
import foxlite.lights.FoxBaseLight;
import foxlite.lights.FoxPointLight;
import funkin.graphics.render3d.Funkin3D;
import funkin.play.PlayState;

class LuaScene3D
{
  public static inline var PREFIX:String = '3d:';
  public static inline var MAX_OBJECTS:Int = 512;

  var objects:Map<String, FoxObject> = new Map();

  public function new()
  {
  }

  public function scene():Null<Funkin3D>
  {
    return PlayState.instance?.stage3D;
  }

  public function enable(layer:Int = 1):Bool
  {
    var play:Null<PlayState> = PlayState.instance;

    if (play == null) return false;

    play.enable3D(layer);

    return true;
  }

  public function disable():Void
  {
    clear();
    PlayState.instance?.disable3DStage();
  }

  public function count():Int
  {
    return [for (key in objects.keys()) key].length;
  }

  public function get(id:String):Null<FoxObject>
  {
    return objects.get(id);
  }

  public function ids():Array<String>
  {
    return [for (key in objects.keys()) key];
  }

  function register(id:String, object:Null<FoxObject>):Bool
  {
    if (object == null || id == '') return false;

    if (!objects.exists(id) && count() >= MAX_OBJECTS)
    {
      discard(object);
      return false;
    }

    remove(id);
    objects.set(id, object);

    return true;
  }

  function discard(object:FoxObject):Void
  {
    var gfx:Null<Funkin3D> = scene();

    if (gfx == null) return;

    if (Std.isOfType(object, FoxModel)) gfx.removeModel(cast object);
    else
      gfx.scene.remove(object);
  }

  public function box(id:String, width:Float, height:Float, depth:Float, color:FlxColor, x:Float, y:Float, z:Float):Bool
  {
    var gfx:Null<Funkin3D> = scene();

    return gfx != null && register(id, gfx.addBox(width, height, depth, color, x, y, z));
  }

  public function sphere(id:String, radius:Float, color:FlxColor, x:Float, y:Float, z:Float, segments:Int):Bool
  {
    var gfx:Null<Funkin3D> = scene();

    return gfx != null && register(id, gfx.addSphere(radius, color, segments, x, y, z));
  }

  public function plane(id:String, width:Float, depth:Float, color:FlxColor, x:Float, y:Float, z:Float):Bool
  {
    var gfx:Null<Funkin3D> = scene();

    return gfx != null && register(id, gfx.addPlane(width, depth, color, x, y, z));
  }

  public function cylinder(id:String, radius:Float, height:Float, color:FlxColor, x:Float, y:Float, z:Float):Bool
  {
    var gfx:Null<Funkin3D> = scene();

    return gfx != null && register(id, gfx.addCylinder(radius, height, color, 24, x, y, z));
  }

  public function torus(id:String, radius:Float, tube:Float, color:FlxColor, x:Float, y:Float, z:Float):Bool
  {
    var gfx:Null<Funkin3D> = scene();

    return gfx != null && register(id, gfx.addTorus(radius, tube, color, 32, 16, x, y, z));
  }

  public function grid(id:String, size:Float, divisions:Int, color:FlxColor, y:Float):Bool
  {
    var gfx:Null<Funkin3D> = scene();

    return gfx != null && register(id, gfx.addGrid(size, Std.int(Math.max(1, Math.min(200, divisions))), color, y));
  }

  public function model(id:String, key:String, x:Float, y:Float, z:Float, size:Float):Bool
  {
    var gfx:Null<Funkin3D> = scene();

    if (gfx == null) return false;

    var groups:Array<FoxObjectGroup> = gfx.loadModel(key);

    if (groups.length == 0) return false;

    var group:FoxObjectGroup = groups[0];

    group.setPosition(x, y, z);
    group.setScale(size, size, size);

    return register(id, group);
  }

  public function light(id:String, kind:String, color:FlxColor, energy:Float, x:Float, y:Float, z:Float, range:Float):Bool
  {
    var gfx:Null<Funkin3D> = scene();

    if (gfx == null) return false;

    if (kind.toLowerCase() == 'point') return register(id, gfx.addPointLight(x, y, z, color, energy, range));

    return register(id, gfx.addDirectionalLight(color, energy, x, y));
  }

  public function remove(id:String):Void
  {
    var object:Null<FoxObject> = objects.get(id);

    if (object == null) return;

    discard(object);
    objects.remove(id);
  }

  public function clear():Void
  {
    for (id in ids())
      remove(id);
  }

  public function setPosition(id:String, x:Float, y:Float, z:Float):Void
  {
    objects.get(id)?.setPosition(x, y, z);
  }

  public function setRotation(id:String, x:Float, y:Float, z:Float):Void
  {
    objects.get(id)?.setAngle(x, y, z);
  }

  public function setScale(id:String, x:Float, y:Float, z:Float):Void
  {
    objects.get(id)?.setScale(x, y, z);
  }

  public function setVisible(id:String, visible:Bool):Void
  {
    var object:Null<FoxObject> = objects.get(id);

    if (object != null) object.visible = visible;
  }

  public function setColor(id:String, color:FlxColor):Void
  {
    var object:Null<FoxObject> = objects.get(id);

    if (object == null) return;

    if (Std.isOfType(object, FoxModel))
    {
      var model:FoxModel = cast object;

      for (i in 0...model.meshes.length)
        model.getMaterial(i)?.setColor(color);
    }
    else if (Std.isOfType(object, FoxBaseLight))
    {
      (cast object : FoxBaseLight).colorHex = color;
    }
  }

  public function setEnergy(id:String, energy:Float):Void
  {
    var object:Null<FoxObject> = objects.get(id);

    if (object != null && Std.isOfType(object, FoxBaseLight)) (cast object : FoxBaseLight).energy = energy;
  }

  public function setRange(id:String, range:Float):Void
  {
    var object:Null<FoxObject> = objects.get(id);

    if (object != null && Std.isOfType(object, FoxPointLight)) (cast object : FoxPointLight).range = range;
  }

  public function position(id:String):Array<Float>
  {
    var object:Null<FoxObject> = objects.get(id);

    return object == null ? [] : [object.x, object.y, object.z];
  }

  public function rotation(id:String):Array<Float>
  {
    var object:Null<FoxObject> = objects.get(id);

    return object == null ? [] : [object.angleX, object.angleY, object.angleZ];
  }
}
#end
