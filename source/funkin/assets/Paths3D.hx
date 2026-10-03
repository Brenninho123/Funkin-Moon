package funkin.assets;

import funkin.assets.AssetResolver;

class Paths3D
{
  public static final MODEL_ROOTS:Array<String> = ['assets/gameplay/models', 'assets/ui/models', 'assets/models'];
  public static final MODEL_EXTENSIONS:Array<String> = ['glb', 'gltf', 'obj'];

  public static final TEXTURE_ROOTS:Array<String> = ['assets/gameplay/textures', 'assets/ui/textures', 'assets/textures'];
  public static final TEXTURE_EXTENSIONS:Array<String> = ['png', 'jpg', 'jpeg'];

  public static final SHADER_ROOTS:Array<String> = ['assets/gameplay/shaders3d', 'assets/ui/shaders3d', 'assets/shaders'];

  public static function resolveModel(key:String):Null<String>
  {
    return AssetResolver.resolve(key, MODEL_ROOTS, MODEL_EXTENSIONS, exists);
  }

  public static function resolveTexture(key:String):Null<String>
  {
    return AssetResolver.resolve(key, TEXTURE_ROOTS, TEXTURE_EXTENSIONS, exists);
  }

  public static function modelExists(key:String):Bool
  {
    return resolveModel(key) != null;
  }

  public static function listModels():Array<String>
  {
    return listKeys(MODEL_ROOTS, MODEL_EXTENSIONS);
  }

  public static function listTextures():Array<String>
  {
    return listKeys(TEXTURE_ROOTS, TEXTURE_EXTENSIONS);
  }

  static function listKeys(roots:Array<String>, extensions:Array<String>):Array<String>
  {
    var keys:Array<String> = [];

    for (assetPath in funkin.assets.Assets.list())
    {
      var key:Null<String> = AssetResolver.keyOf(assetPath.path, roots, extensions);

      if (key != null && extensions.indexOf(AssetResolver.extensionOf(assetPath.path)) >= 0 && keys.indexOf(key) < 0) keys.push(key);
    }

    keys.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));

    return keys;
  }

  static var bridged:Bool = false;

  public static function installFoxliteBridge():Void
  {
    #if FEATURE_3D_RENDERING
    if (bridged) return;

    bridged = true;

    foxlite.loaders.FoxLoaderUtil.imagePath = (name:String) ->
    {
      return resolveTexture(name) ?? 'assets/images/$name.png';
    };
    #end
  }

  static function exists(path:String):Bool
  {
    return openfl.utils.Assets.exists(path);
  }
}
