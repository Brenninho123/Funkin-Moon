package funkin.graphics.render3d;

#if FEATURE_3D_RENDERING
import flixel.util.FlxColor;
import foxlite.FoxModel;
import foxlite.lights.FoxPointLight;

class MenuBackdrop3D
{
  static final ORB_COLORS:Array<FlxColor> = [0xFFFF4D9E, 0xFF4DD9FF, 0xFFFFD166, 0xFF7CF6CF, 0xFFB388FF, 0xFFFF8A5C];

  var gfx:Funkin3D;
  var ring:FoxModel;
  var core:FoxModel;
  var orbs:Array<FoxModel> = [];
  var pillars:Array<FoxModel> = [];
  var warm:FoxPointLight;
  var cool:FoxPointLight;
  var time:Float = 0;

  public function new(gfx:Funkin3D)
  {
    this.gfx = gfx;

    gfx.setAmbient(0xFF4A4D66);
    gfx.setFog(0xFF000000, 18, 40);
    gfx.setCameraPosition(0, 1.6, 9);
    gfx.setCameraFov(70);
    gfx.camera.setAngle(-6, 0, 0);

    gfx.addDirectionalLight(0xFFFFFFFF, 1.0, -48, 28);
    warm = gfx.addPointLight(-4.5, 2.5, 0, 0xFFFF4D9E, 2.4, 14);
    cool = gfx.addPointLight(4.5, 2.5, 0, 0xFF4DD9FF, 2.4, 14);

    gfx.addGrid(40, 40, 0x889B7BFF, -2.2, 'floor');

    ring = gfx.addTorus(3.0, 0.32, 0xFFFFD166, 56, 16, 5.5, 0.4, -7, 'ring');
    core = gfx.addSphere(1.1, 0xFFFFFFFF, 28, 5.5, 0.4, -7, 'core');

    for (i in 0...ORB_COLORS.length)
    {
      var orb:FoxModel = gfx.addSphere(0.42, ORB_COLORS[i], 20, 0, 0, -7);

      orbs.push(orb);
    }

    for (i in 0...5)
    {
      var height:Float = 3.0 + (i % 3) * 1.4;
      var pillar:FoxModel = gfx.addBox(0.9, height, 0.9, 0xFF2E3050, -9 + i * 1.1, -2.2 + height / 2, -12 - i * 2.2);

      pillars.push(pillar);
    }
  }

  public function update(elapsed:Float):Void
  {
    time += elapsed;

    var beat:Float = Conductor.instance.currentBeatTime;
    var pulse:Float = Math.pow(1.0 - (beat - Math.floor(beat)), 3);

    ring.angleY = time * 32;
    ring.angleX = 70 + Math.sin(time * 0.7) * 12;

    var coreScale:Float = 1.0 + pulse * 0.22;

    core.setScale(coreScale, coreScale, coreScale);

    for (i in 0...orbs.length)
    {
      var angle:Float = time * 0.9 + i * (Math.PI * 2 / orbs.length);
      var orbit:Float = 3.0 + pulse * 0.35;

      orbs[i].setPosition(5.5 + Math.cos(angle) * orbit, 0.4 + Math.sin(angle * 2.0) * 0.5, -7 + Math.sin(angle) * orbit);
    }

    for (i in 0...pillars.length)
    {
      var wave:Float = Math.sin(time * 1.4 + i) * 0.25 + pulse * 0.3;

      pillars[i].setScale(1, 1 + wave * 0.2, 1);
    }

    warm.energy = 2.0 + pulse * 1.6;
    cool.energy = 2.0 + (1.0 - pulse) * 0.8;

    gfx.camera.x = Math.sin(time * 0.25) * 0.6;
  }
}
#end
