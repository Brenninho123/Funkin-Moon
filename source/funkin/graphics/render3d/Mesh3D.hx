package funkin.graphics.render3d;

#if FEATURE_3D_RENDERING
import foxlite.material.FoxMaterial;
import foxlite.mesh.FoxMesh;
import funkin.graphics.render3d.MeshGeometry.GeometryData;

class Mesh3D
{
  public static function sphere(radius:Float, segments:Int, material:FoxMaterial):FoxMesh
  {
    return fromGeometry(MeshGeometry.sphere(radius, segments), material);
  }

  public static function cylinder(radius:Float, height:Float, segments:Int, material:FoxMaterial):FoxMesh
  {
    return fromGeometry(MeshGeometry.cylinder(radius, height, segments), material);
  }

  public static function torus(radius:Float, tube:Float, rings:Int, sides:Int, material:FoxMaterial):FoxMesh
  {
    return fromGeometry(MeshGeometry.torus(radius, tube, rings, sides), material);
  }

  public static function fromGeometry(data:GeometryData, material:FoxMaterial):FoxMesh
  {
    var mesh:FoxMesh = new FoxMesh();

    mesh.setArrays(data.vertices, data.uvs, data.indices, material, data.normals);
    mesh.calculateBounds(data.vertices);

    return mesh;
  }
}
#end
