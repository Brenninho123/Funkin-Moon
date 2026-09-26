package funkin.native;

@:build(funkin.util.macro.LinkerMacro.xml('ContentBuild.xml'))
@:include("Content.hpp")
@:unreflective
extern class ContentNative
{
  @:native("funkin_content_scanSubdirectories")
  public static function scanSubdirectories(assetsRoot:cpp.ConstCharStar, relativePath:cpp.ConstCharStar):cpp.ConstCharStar;

  @:native("funkin_content_scanJsonFiles")
  public static function scanJsonFiles(assetsRoot:cpp.ConstCharStar, relativePath:cpp.ConstCharStar):cpp.ConstCharStar;

  @:native("funkin_content_scanSongs")
  public static function scanSongs(assetsRoot:cpp.ConstCharStar):cpp.ConstCharStar;

  @:native("funkin_content_scanWeeks")
  public static function scanWeeks(assetsRoot:cpp.ConstCharStar):cpp.ConstCharStar;

  @:native("funkin_content_scanCharacters")
  public static function scanCharacters(assetsRoot:cpp.ConstCharStar):cpp.ConstCharStar;
}
