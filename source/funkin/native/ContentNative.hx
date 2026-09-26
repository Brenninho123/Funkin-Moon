package funkin.native;

@:buildXml('
<files id="haxe">
  <compilerflag value="-Isource/funkin" />
  <compilerflag value="-std=c++17" />
  <file name="source/funkin/Content.cpp" />
</files>
')
@:include("Content.hpp")
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
