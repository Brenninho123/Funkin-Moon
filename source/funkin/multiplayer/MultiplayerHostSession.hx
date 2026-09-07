package funkin.multiplayer;

#if FEATURE_ONLINE
import funkin.multiplayer.MultiplayerServer;
import funkin.play.PlayState;
import funkin.play.song.Song;
import funkin.ui.transition.LoadingState;
#end

/**
 * Ponte HostMenu -> Freeplay pro fluxo de multiplayer.
 *
 * Fluxo: host abre o HostMenu, espera o convidado conectar, aperta LIGAR
 * (só libera com o convidado dentro) -> fecha o HostMenu, seta
 * `MultiplayerHostSession.active = true` e o OnlineMenuState manda pro
 * Freeplay. Host escolhe a música lá normal.
 *
 * falta plugar, importar, seila. tem que importar no Freeplay, mas enfim quando a musica for confirmada (com
 * active == true), chama MultiplayerHostSession.startMatch(song, diff,
 * variation) em vez de ir direto pro loadingState.
 */
class MultiplayerHostSession
{
  #if FEATURE_ONLINE
  public static var active:Bool = false;
  public static var serverId:String = '';

  public static function startMatch(song:Song, difficulty:String, variation:String):Void
  {
    if (!active) return;

    if (MultiplayerServer.instance != null)
    {
      MultiplayerServer.instance.broadcast({
        type: 'match_start',
        songId: song.id,
        difficulty: difficulty,
        variation: variation
      });
    }
    else
    {
      trace('[MultiplayerHostSession] ATENÇÃO: startMatch chamado sem MultiplayerServer.instance ativo.');
    }

    PlayState.multiplayerClient = null;
    PlayState.multiplayerMatchActive = true;
    PlayState.multiplayerMatchId = serverId;

    active = false;

    LoadingState.loadPlayState({
      targetSong: song,
      targetDifficulty: difficulty,
      targetVariation: variation,
      isMultiplayerMode: true
    });
  }

  public static function cancel():Void
  {
    active = false;
    serverId = '';
  }
  #end
}
