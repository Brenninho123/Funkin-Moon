package funkin.graphics.render3d;

typedef GeometryData =
{
  var vertices:Array<Float>;
  var normals:Array<Float>;
  var uvs:Array<Float>;
  var indices:Array<Int>;
}

class MeshGeometry
{
  public static inline var MAX_VERTICES:Int = 65535;

  public static function sphere(radius:Float, segments:Int):GeometryData
  {
    var columns:Int = clamp(segments, 3, 128);
    var rows:Int = clamp(Std.int(segments / 2), 2, 128);
    var data:GeometryData = empty();

    for (row in 0...rows + 1)
    {
      var v:Float = row / rows;
      var phi:Float = v * Math.PI;

      for (column in 0...columns + 1)
      {
        var u:Float = column / columns;
        var theta:Float = u * Math.PI * 2;
        var nx:Float = Math.sin(phi) * Math.cos(theta);
        var ny:Float = Math.cos(phi);
        var nz:Float = Math.sin(phi) * Math.sin(theta);

        push(data, nx * radius, ny * radius, nz * radius, nx, ny, nz, u, v);
      }
    }

    grid(data, 0, rows, columns);

    return data;
  }

  public static function cylinder(radius:Float, height:Float, segments:Int):GeometryData
  {
    var sides:Int = clamp(segments, 3, 128);
    var half:Float = height / 2;
    var data:GeometryData = empty();

    for (side in 0...sides + 1)
    {
      var u:Float = side / sides;
      var angle:Float = u * Math.PI * 2;
      var nx:Float = Math.cos(angle);
      var nz:Float = Math.sin(angle);

      push(data, nx * radius, half, nz * radius, nx, 0, nz, u, 0);
      push(data, nx * radius, -half, nz * radius, nx, 0, nz, u, 1);
    }

    for (side in 0...sides)
    {
      var a:Int = side * 2;

      data.indices.push(a);
      data.indices.push(a + 2);
      data.indices.push(a + 1);
      data.indices.push(a + 1);
      data.indices.push(a + 2);
      data.indices.push(a + 3);
    }

    cap(data, radius, half, sides, 1);
    cap(data, radius, -half, sides, -1);

    return data;
  }

  static function cap(data:GeometryData, radius:Float, y:Float, sides:Int, direction:Int):Void
  {
    var center:Int = Std.int(data.vertices.length / 3);

    push(data, 0, y, 0, 0, direction, 0, 0.5, 0.5);

    for (side in 0...sides + 1)
    {
      var angle:Float = side / sides * Math.PI * 2;

      push(data, Math.cos(angle) * radius, y, Math.sin(angle) * radius, 0, direction, 0, 0.5 + Math.cos(angle) * 0.5, 0.5 + Math.sin(angle) * 0.5);
    }

    for (side in 0...sides)
    {
      data.indices.push(center);

      if (direction > 0)
      {
        data.indices.push(center + side + 2);
        data.indices.push(center + side + 1);
      }
      else
      {
        data.indices.push(center + side + 1);
        data.indices.push(center + side + 2);
      }
    }
  }

  public static function torus(radius:Float, tube:Float, rings:Int, sides:Int):GeometryData
  {
    var major:Int = clamp(rings, 3, 128);
    var minor:Int = clamp(sides, 3, 128);
    var data:GeometryData = empty();

    for (ring in 0...major + 1)
    {
      var u:Float = ring / major;
      var theta:Float = u * Math.PI * 2;

      for (side in 0...minor + 1)
      {
        var v:Float = side / minor;
        var phi:Float = v * Math.PI * 2;
        var nx:Float = Math.cos(theta) * Math.cos(phi);
        var ny:Float = Math.sin(phi);
        var nz:Float = Math.sin(theta) * Math.cos(phi);

        push(data, Math.cos(theta) * (radius + tube * Math.cos(phi)), tube * Math.sin(phi), Math.sin(theta) * (radius + tube * Math.cos(phi)), nx, ny, nz, u, v);
      }
    }

    grid(data, 0, major, minor);

    return data;
  }

  public static function vertexCount(data:GeometryData):Int
  {
    return Std.int(data.vertices.length / 3);
  }

  public static function fits(data:GeometryData):Bool
  {
    return vertexCount(data) <= MAX_VERTICES;
  }

  public static function triangleCount(data:GeometryData):Int
  {
    return Std.int(data.indices.length / 3);
  }

  static function empty():GeometryData
  {
    return {
      vertices: [],
      normals: [],
      uvs: [],
      indices: []
    };
  }

  static function push(data:GeometryData, x:Float, y:Float, z:Float, nx:Float, ny:Float, nz:Float, u:Float, v:Float):Void
  {
    data.vertices.push(x);
    data.vertices.push(y);
    data.vertices.push(z);
    data.normals.push(nx);
    data.normals.push(ny);
    data.normals.push(nz);
    data.uvs.push(u);
    data.uvs.push(v);
  }

  static function grid(data:GeometryData, first:Int, rows:Int, columns:Int):Void
  {
    var stride:Int = columns + 1;

    for (row in 0...rows)
    {
      for (column in 0...columns)
      {
        var a:Int = first + row * stride + column;
        var b:Int = a + stride;

        data.indices.push(a);
        data.indices.push(a + 1);
        data.indices.push(b);
        data.indices.push(a + 1);
        data.indices.push(b + 1);
        data.indices.push(b);
      }
    }
  }

  static function clamp(value:Int, low:Int, high:Int):Int
  {
    return value < low ? low : (value > high ? high : value);
  }
}
