import funkin.graphics.render3d.MeshGeometry;
import funkin.graphics.render3d.MeshGeometry.GeometryData;

class MeshGeometryTests
{
  static var checks:Int = 0;
  static var failures:Int = 0;

  static function check(name:String, condition:Bool, ?detail:String):Void
  {
    checks++;

    if (condition) return;

    failures++;
    Sys.println('FAIL: ' + name + (detail != null ? '  (' + detail + ')' : ''));
  }

  static function near(a:Float, b:Float, tolerance:Float = 0.0001):Bool
  {
    return Math.abs(a - b) <= tolerance;
  }

  static function consistent(data:GeometryData):Bool
  {
    var count:Int = MeshGeometry.vertexCount(data);

    if (data.normals.length != count * 3 || data.uvs.length != count * 2 || data.indices.length % 3 != 0) return false;

    for (index in data.indices)
    {
      if (index < 0 || index >= count) return false;
    }

    return true;
  }

  static function unitNormals(data:GeometryData):Bool
  {
    for (i in 0...MeshGeometry.vertexCount(data))
    {
      var x:Float = data.normals[i * 3];
      var y:Float = data.normals[i * 3 + 1];
      var z:Float = data.normals[i * 3 + 2];

      if (!near(Math.sqrt(x * x + y * y + z * z), 1.0, 0.001)) return false;
    }

    return true;
  }

  static function faceNormalAlignment(data:GeometryData, expectOutward:(Float, Float, Float) -> Bool):Int
  {
    var wrong:Int = 0;

    for (t in 0...MeshGeometry.triangleCount(data))
    {
      var a:Int = data.indices[t * 3] * 3;
      var b:Int = data.indices[t * 3 + 1] * 3;
      var c:Int = data.indices[t * 3 + 2] * 3;
      var ux:Float = data.vertices[b] - data.vertices[a];
      var uy:Float = data.vertices[b + 1] - data.vertices[a + 1];
      var uz:Float = data.vertices[b + 2] - data.vertices[a + 2];
      var vx:Float = data.vertices[c] - data.vertices[a];
      var vy:Float = data.vertices[c + 1] - data.vertices[a + 1];
      var vz:Float = data.vertices[c + 2] - data.vertices[a + 2];
      var fx:Float = uy * vz - uz * vy;
      var fy:Float = uz * vx - ux * vz;
      var fz:Float = ux * vy - uy * vx;
      var length:Float = Math.sqrt(fx * fx + fy * fy + fz * fz);

      if (length < 0.0000001) continue;

      var nx:Float = data.normals[a] + data.normals[b] + data.normals[c];
      var ny:Float = data.normals[a + 1] + data.normals[b + 1] + data.normals[c + 1];
      var nz:Float = data.normals[a + 2] + data.normals[b + 2] + data.normals[c + 2];

      if (fx * nx + fy * ny + fz * nz <= 0) wrong++;
    }

    return wrong;
  }

  static function main():Void
  {
    Sys.println('sphere');

    var sphere:GeometryData = MeshGeometry.sphere(2.0, 16);

    check('a sphere is consistent', consistent(sphere));
    check('a sphere has (rows + 1) x (columns + 1) vertices', MeshGeometry.vertexCount(sphere) == 9 * 17, Std.string(MeshGeometry.vertexCount(sphere)));
    check('a sphere has two triangles per cell', MeshGeometry.triangleCount(sphere) == 8 * 16 * 2);
    check('a sphere normal is a unit vector', unitNormals(sphere));

    var onSurface:Bool = true;

    for (i in 0...MeshGeometry.vertexCount(sphere))
    {
      var x:Float = sphere.vertices[i * 3];
      var y:Float = sphere.vertices[i * 3 + 1];
      var z:Float = sphere.vertices[i * 3 + 2];

      if (!near(Math.sqrt(x * x + y * y + z * z), 2.0)) onSurface = false;
    }

    check('every sphere vertex is on the surface', onSurface);
    check('the poles are on the Y axis', near(sphere.vertices[1], 2.0) && near(sphere.vertices[sphere.vertices.length - 2], -2.0));
    check('uvs stay between 0 and 1', Lambda.fold(sphere.uvs, (value, ok) -> ok && value >= 0 && value <= 1, true));
    check('sphere triangles face outwards', faceNormalAlignment(sphere, (x, y, z) -> true) == 0, Std.string(faceNormalAlignment(sphere, (x, y, z) -> true)));
    check('a tiny segment count is raised to the minimum', consistent(MeshGeometry.sphere(1, 0)) && MeshGeometry.vertexCount(MeshGeometry.sphere(1, 0)) == 3 * 4);
    check('a huge segment count is limited', MeshGeometry.fits(MeshGeometry.sphere(1, 100000)));
    check('the biggest sphere fits 16 bit indices', MeshGeometry.vertexCount(MeshGeometry.sphere(1, 100000)) <= MeshGeometry.MAX_VERTICES);

    Sys.println('cylinder');

    var cylinder:GeometryData = MeshGeometry.cylinder(1.0, 4.0, 12);

    check('a cylinder is consistent', consistent(cylinder));
    check('a cylinder normal is a unit vector', unitNormals(cylinder));
    check('a cylinder spans its height', near(Lambda.fold([for (i in 0...MeshGeometry.vertexCount(cylinder)) cylinder.vertices[i * 3 + 1]], (v, m) -> Math.max(v, m), -100), 2.0));
    check('a cylinder is as low as half its height', near(Lambda.fold([for (i in 0...MeshGeometry.vertexCount(cylinder)) cylinder.vertices[i * 3 + 1]], (v, m) -> Math.min(v, m), 100), -2.0));
    check('cylinder triangles face outwards', faceNormalAlignment(cylinder, (x, y, z) -> true) == 0, Std.string(faceNormalAlignment(cylinder, (x, y, z) -> true)));
    check('a cylinder has side and cap triangles', MeshGeometry.triangleCount(cylinder) == 12 * 2 + 12 * 2);

    Sys.println('torus');

    var torus:GeometryData = MeshGeometry.torus(3.0, 0.5, 16, 8);

    check('a torus is consistent', consistent(torus));
    check('a torus normal is a unit vector', unitNormals(torus));
    check('a torus has (rings + 1) x (sides + 1) vertices', MeshGeometry.vertexCount(torus) == 17 * 9);

    var tubeOk:Bool = true;

    for (i in 0...MeshGeometry.vertexCount(torus))
    {
      var x:Float = torus.vertices[i * 3];
      var y:Float = torus.vertices[i * 3 + 1];
      var z:Float = torus.vertices[i * 3 + 2];
      var fromRing:Float = Math.sqrt((Math.sqrt(x * x + z * z) - 3.0) * (Math.sqrt(x * x + z * z) - 3.0) + y * y);

      if (!near(fromRing, 0.5, 0.001)) tubeOk = false;
    }

    check('every torus vertex is one tube radius from the ring', tubeOk);
    check('torus triangles face outwards', faceNormalAlignment(torus, (x, y, z) -> true) == 0, Std.string(faceNormalAlignment(torus, (x, y, z) -> true)));

    Sys.println(failures == 0 ? '\nall ' + checks + ' checks passed' : '\n' + failures + ' of ' + checks + ' checks failed');
    Sys.exit(failures == 0 ? 0 : 1);
  }
}
