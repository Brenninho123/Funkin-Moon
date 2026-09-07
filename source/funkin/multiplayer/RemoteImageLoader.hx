package funkin.multiplayer;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Loader;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.URLRequest;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;

/**
 * Helper pra carregar uma imagem de uma URL (avatar do Discord, etc)
 * direto numa FlxSprite. Usa openfl.display.Loader por baixo — funciona
 * em qualquer plataforma que o V-Slice já roda (cpp/hl/html5), desde
 * que a URL seja https e o host permita a request (o CDN do Discord,
 * cdn.discordapp.com, permite sem problema).
 *
 * Cacheia por URL pra não rebaixar o mesmo avatar toda vez que um card
 * de convite/resultado de busca reaparece com o mesmo usuário.
 */
class RemoteImageLoader
{
  static var cache:Map<String, FlxGraphic> = new Map();

  /**
   * Carrega `url` dentro de `sprite`. `sprite` já deve existir com algum
   * placeholder (ex: `makeGraphic`) — isso troca o graphic dele quando
   * (e se) a imagem terminar de baixar, de forma assíncrona.
   */
  public static function loadInto(sprite:FlxSprite, url:String, ?onComplete:Void->Void, ?onError:Void->Void):Void
  {
    if (sprite == null || url == null || url.length == 0)
    {
      if (onError != null) onError();
      return;
    }

    var cached:Null<FlxGraphic> = cache.get(url);
    if (cached != null)
    {
      sprite.loadGraphic(cached);
      if (onComplete != null) onComplete();
      return;
    }

    var loader:Loader = new Loader();

    loader.contentLoaderInfo.addEventListener(Event.COMPLETE, (_) ->
    {
      var bmp:Null<Bitmap> = Std.downcast(loader.content, Bitmap);
      var bmpData:Null<BitmapData> = bmp != null ? bmp.bitmapData : null;

      if (bmpData == null)
      {
        trace('[RemoteImageLoader] conteúdo carregado não é um Bitmap: $url');
        if (onError != null) onError();
        return;
      }

      var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bmpData, false, url);
      graphic.persist = true;
      cache.set(url, graphic);

      sprite.loadGraphic(graphic);
      if (onComplete != null) onComplete();
    });

    loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, (e) ->
    {
      trace('[RemoteImageLoader] falha ao carregar $url: ' + e);
      if (onError != null) onError();
    });

    try
    {
      loader.load(new URLRequest(url));
    }
    catch (e:Dynamic)
    {
      trace('[RemoteImageLoader] exceção ao carregar $url: ' + e);
      if (onError != null) onError();
    }
  }

  /** Limpa o cache — chame se isso virar problema de memória numa sessão longa. */
  public static function clearCache():Void
  {
    cache.clear();
  }
}
