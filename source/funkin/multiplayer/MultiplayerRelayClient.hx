package funkin.multiplayer;

#if sys
/**
 * Conexão do jogo com o RelayServer (matchmaking/convites).
 *
 * É uma classe SEPARADA do MultiplayerClient de propósito, apesar de
 * reaproveitar ele por baixo: o MultiplayerClient conecta no server do
 * HOST pra jogar a partida em si (1x1 direto, porta tipo 2082); esse
 * aqui conecta no relay central (porta separada, tipo 8090) só pra
 * buscar gente e mandar/receber convite, e fica ligado o tempo todo que
 * a OnlineMenuState estiver aberta — independente de ter partida
 * rolando ou não.
 *
 * Não fala diretamente com o socket: usa um MultiplayerClient por baixo
 * (mesmo protocolo WebSocket cru), só que apontado pro relay em vez do
 * server do host, e com seu próprio "dialeto" de mensagens JSON
 * (register / search_user / invite / invite_response).
 */
#if FEATURE_ONLINE
class MultiplayerRelayClient
{
  public static var instance(get, never):MultiplayerRelayClient;
  static var _instance:Null<MultiplayerRelayClient> = null;

  static function get_instance():MultiplayerRelayClient
  {
    if (_instance == null) _instance = new MultiplayerRelayClient();
    return _instance;
  }

  /** Chamado quando ALGUÉM te manda um convite. Recebe o JSON cru do relay. */
  public var onInviteReceived:Null<Dynamic->Void>;

  /** Chamado quando o convidado responde (ACCEPT/DISCARD) um convite que VOCÊ mandou. */
  public var onInviteResponse:Null<Dynamic->Void>;

  public var connected(get, never):Bool;

  var client:Null<MultiplayerClient> = null;
  var host:String = '127.0.0.1';
  var port:Int = 8090;
  var registered:Bool = false;
  var pendingSearch:Map<String, Array<Dynamic>->Void> = new Map();
  var pendingInvite:Map<String, PendingInvite> = new Map();

  function new()
  {
  }

  function get_connected():Bool
  {
    return client != null && client.connected;
  }

  public function connect(?targetHost:String, ?targetPort:Int):Void
  {
    if (targetHost != null) host = targetHost;
    if (targetPort != null) port = targetPort;

    if (connected) return;

    var c:MultiplayerClient = new MultiplayerClient(host, port);
    client = c;
    c.onMessage = onSocketMessage;
    c.onError = (err) -> trace('[Relay] erro: $err');
    c.onDisconnect = () ->
    {
      registered = false;
      trace('[Relay] desconectado do relay');
    };

    try
    {
      c.connect();
      trace('[Relay] conectado em $host:$port');
    }
    catch (e:Dynamic)
    {
      trace('[Relay] falha ao conectar no relay ($host:$port): $e');
      client = null;
    }
  }

  public function register(discordId:Null<String>, username:String, avatarUrl:Null<String>):Void
  {
    if (!connected || client == null) return;
    client.send({
      type: 'register',
      discordId: discordId,
      username: username,
      avatarUrl: avatarUrl
    });
  }

  public function searchByNick(query:String, callback:Array<Dynamic>->Void):Void
  {
    if (!connected || client == null)
    {
      callback([]);
      return;
    }

    var requestId:String = generateRequestId();
    pendingSearch.set(requestId, callback);
    client.send({
      type: 'search_user',
      query: query,
      requestId: requestId
    });
  }

  public function sendInvite(targetDiscordId:String, hostServerId:String, hostAddress:String, hostPort:Int, ?onSent:Void->Void, ?onError:String->Void):Void
  {
    if (!connected || client == null)
    {
      if (onError != null) onError('sem conexão com o relay');
      return;
    }

    var requestId:String = generateRequestId();
    pendingInvite.set(requestId, {
      onSent: onSent,
      onError: onError
    });
    client.send({
      type: 'invite',
      targetDiscordId: targetDiscordId,
      hostServerId: hostServerId,
      hostAddress: hostAddress,
      hostPort: hostPort,
      requestId: requestId
    });
  }

  public function respondToInvite(inviteId:String, accept:Bool):Void
  {
    if (!connected || client == null) return;
    client.send({
      type: 'invite_response',
      inviteId: inviteId,
      accept: accept
    });
  }

  function onSocketMessage(data:Dynamic):Void
  {
    var type:String = Std.string(Reflect.field(data, 'type'));

    switch (type)
    {
      case 'registered':
        registered = true;
        trace('[Relay] registrado no relay');

      case 'search_result':
        var requestId:String = Std.string(Reflect.field(data, 'requestId'));
        var cb = pendingSearch.get(requestId);
        if (cb != null)
        {
          pendingSearch.remove(requestId);
          var results:Array<Dynamic> = Reflect.field(data, 'results');
          cb(results != null ? results : []);
        }

      case 'invite_sent':
        var requestId:String = Std.string(Reflect.field(data, 'requestId'));
        var pending:Null<PendingInvite> = pendingInvite.get(requestId);
        if (pending != null)
        {
          pendingInvite.remove(requestId);
          if (pending.onSent != null) pending.onSent();
        }

      case 'invite_error':
        var requestId:String = Std.string(Reflect.field(data, 'requestId'));
        var pending:Null<PendingInvite> = pendingInvite.get(requestId);
        var message:String = Reflect.hasField(data, 'message') ? Std.string(Reflect.field(data, 'message')) : 'erro desconhecido';
        if (pending != null)
        {
          pendingInvite.remove(requestId);
          if (pending.onError != null) pending.onError(message);
        }

      case 'invite_received':
        if (onInviteReceived != null) onInviteReceived(data);

      case 'invite_response':
        if (onInviteResponse != null) onInviteResponse(data);

      default:
        // tipo desconhecido, ignora
    }
  }

  static var _reqCounter:Int = 0;

  static function generateRequestId():String
  {
    _reqCounter++;
    return Std.string(Date.now().getTime()) + '_' + Std.string(_reqCounter);
  }
}

typedef PendingInvite =
{
  var onSent:Null<Void->Void>;
  var onError:Null<String->Void>;
}
#else
class MultiplayerRelayClient
{
  public static var instance(get, never):MultiplayerRelayClient;
  static var _instance:Null<MultiplayerRelayClient> = null;

  static function get_instance():MultiplayerRelayClient
  {
    if (_instance == null) _instance = new MultiplayerRelayClient();
    return _instance;
  }

  public var onInviteReceived:Null<Dynamic->Void>;
  public var onInviteResponse:Null<Dynamic->Void>;
  public var connected(get, never):Bool;

  function new()
  {
  }

  function get_connected():Bool
  {
    return false;
  }

  public function connect(?targetHost:String, ?targetPort:Int):Void
  {
  }

  public function register(discordId:Null<String>, username:String, avatarUrl:Null<String>):Void
  {
  }

  public function searchByNick(query:String, callback:Array<Dynamic>->Void):Void
  {
    callback([]);
  }

  public function sendInvite(targetDiscordId:String, hostServerId:String, hostAddress:String, hostPort:Int, ?onSent:Void->Void, ?onError:String->Void):Void
  {
  }

  public function respondToInvite(inviteId:String, accept:Bool):Void
  {
  }
}
#end
#end
