package funkin.assets;

class AssetResolver
{
  public static function normalize(key:String):Null<String>
  {
    if (key == null) return null;

    var path:String = StringTools.trim(StringTools.replace(key, '\\', '/'));

    while (StringTools.startsWith(path, './'))
      path = path.substr(2);

    while (path.indexOf('//') >= 0)
      path = StringTools.replace(path, '//', '/');

    if (path == '' || path.charAt(0) == '/') return null;

    for (part in path.split('/'))
    {
      if (part == '..') return null;
    }

    if (path.indexOf(':') >= 0)
    {
      var colon:Int = path.indexOf(':');

      if (colon == 1) return null;

      path = path.substr(colon + 1);
    }

    return path;
  }

  public static function extensionOf(path:String):String
  {
    var slash:Int = path.lastIndexOf('/');
    var dot:Int = path.lastIndexOf('.');

    return dot > slash && dot >= 0 ? path.substr(dot + 1).toLowerCase() : '';
  }

  public static function candidates(key:String, roots:Array<String>, extensions:Array<String>):Array<String>
  {
    var path:Null<String> = normalize(key);

    if (path == null) return [];

    var result:Array<String> = [];
    var ext:String = extensionOf(path);
    var hasKnownExtension:Bool = ext != '' && extensions.indexOf(ext) >= 0;
    var rooted:Bool = StringTools.startsWith(path, 'assets/');

    if (rooted)
    {
      if (hasKnownExtension) return [path];

      for (extension in extensions)
        result.push(path + '.' + extension);

      return result;
    }

    for (root in roots)
    {
      var base:String = root == '' ? path : trimSlashes(root) + '/' + path;

      if (hasKnownExtension)
      {
        result.push(base);
      }
      else
      {
        for (extension in extensions)
          result.push(base + '.' + extension);
      }
    }

    return result;
  }

  public static function resolve(key:String, roots:Array<String>, extensions:Array<String>, exists:String->Bool):Null<String>
  {
    for (candidate in candidates(key, roots, extensions))
    {
      if (exists(candidate)) return candidate;
    }

    return null;
  }

  public static function resolveAll(key:String, roots:Array<String>, extensions:Array<String>, exists:String->Bool):Array<String>
  {
    return [for (candidate in candidates(key, roots, extensions)) if (exists(candidate)) candidate];
  }

  public static function keyOf(path:String, roots:Array<String>, extensions:Array<String>):Null<String>
  {
    var normalized:Null<String> = normalize(path);

    if (normalized == null) return null;

    for (root in roots)
    {
      var prefix:String = trimSlashes(root) + '/';

      if (StringTools.startsWith(normalized, prefix))
      {
        var rest:String = normalized.substr(prefix.length);
        var ext:String = extensionOf(rest);

        return ext != '' && extensions.indexOf(ext) >= 0 ? rest.substr(0, rest.length - ext.length - 1) : rest;
      }
    }

    return null;
  }

  static function trimSlashes(value:String):String
  {
    var result:String = value;

    while (StringTools.endsWith(result, '/'))
      result = result.substr(0, result.length - 1);

    return result;
  }
}
