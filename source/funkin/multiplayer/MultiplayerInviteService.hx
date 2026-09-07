package funkin.multiplayer;

/**
 * Client de busca/convite por nick do Discord.
 *
 * Fala de verdade com o RelayServer (funkin.multiplayer.relay.RelayServer)
 * através do MultiplayerRelayClient. A interface pública é praticamente
 * a mesma de quando isso era stub — só duas mudanças:
 *   - connect() agora aceita a conta opcionalmente, pra já se registrar
 *     no relay com a identidade certa.
 *   - sendInvite() agora recebe `hostAddress` (o endereço que o
 *     CONVIDADO vai usar pra se conectar), porque sem ele o relay não
 *     tem como saber pra onde mandar o convidado.
 *
 * Endereço do relay: por padrão 127.0.0.1:8090 (testes locais, mesma
 * máquina, que é o que você tá fazendo agora). Quando tiver uma máquina
 * sempre ligada (a Xeon com DuckDNS), troca só o connect() lá na
 * OnlineMenuState pra apontar pro domínio.
 */
class MultiplayerInviteService
{
  #if FEATURE_ONLINE
  public static var instance(get, never):MultiplayerInviteService;
  static var _instance:Null<MultiplayerInviteService> = null;

  static function get_instance():MultiplayerInviteService
  {
    if (_instance == null) _instance = new MultiplayerInviteService();
    return _instance;
  }

  public static inline final DEFAULT_RELAY_HOST:String = '127.0.0.1';
  public static inline final DEFAULT_RELAY_PORT:Int = 8090;

  /** Chamado quando ALGUÉM te manda um convite (você é o convidado). */
  public var onInviteReceived:Null<InviteInfo->Void>;

  var relay:MultiplayerRelayClient;

  function new()
  {
    relay = MultiplayerRelayClient.instance;
    relay.onInviteReceived = handleRelayInvite;
  }

  /**
   * Conecta no relay e, se `account` for passado, já se registra com a
   * identidade da conta (username/avatar do Discord se já tiver
   * vinculado, senão username local mesmo). Chame de novo com o mesmo
   * account depois que o Discord for vinculado, pra atualizar o
   * nick/avatar publicados — não tem problema chamar connect() várias
   * vezes, ele só reusa a conexão se já tiver uma aberta.
   */
  public function connect(?account:Dynamic, ?relayHost:String, ?relayPort:Int):Void
  {
    relay.connect(relayHost != null ? relayHost : DEFAULT_RELAY_HOST, relayPort != null ? relayPort : DEFAULT_RELAY_PORT);

    if (account != null)
    {
      updateIdentity(account);
    }
  }

  /**
   * Manda (de novo, se precisar) a identidade atual pro relay. Chame
   * isso sempre que os dados da conta mudarem — em particular, logo
   * depois de MultiplayerAccountManager.linkDiscordAccount().
   */
  public function updateIdentity(account:Dynamic):Void
  {
    if (account == null) return;

    var discordId:Null<String> = Reflect.hasField(account, 'discordId') ? Reflect.field(account, 'discordId') : null;
    var discordUsername:Null<String> = Reflect.hasField(account, 'discordUsername') ? Reflect.field(account, 'discordUsername') : null;
    var discordAvatarUrl:Null<String> = Reflect.hasField(account, 'discordAvatarUrl') ? Reflect.field(account, 'discordAvatarUrl') : null;

    // Sem Discord vinculado ainda: usa o id/username local mesmo, só pra
    // já ficar "visível" no relay. Quando o Discord for vinculado, chama
    // updateIdentity() de novo (ver OnlineMenuState) que troca pro
    // discordId/discordUsername real.
    var effectiveId:String = (discordId != null) ? discordId : Std.string(Reflect.field(account, 'id'));
    var effectiveUsername:String = (discordUsername != null) ? discordUsername : Std.string(Reflect.field(account, 'username'));

    relay.register(effectiveId, effectiveUsername, discordAvatarUrl);
  }

  /**
   * Busca usuários do Discord por nick (prefixo/substring). Assíncrono
   * de propósito (callback, não return) — bate no relay de verdade.
   */
  public function searchByNick(query:String, callback:Array<InviteInfo>->Void):Void
  {
    if (query == null || query.length == 0)
    {
      callback([]);
      return;
    }

    relay.searchByNick(query, (rawResults) ->
    {
      var parsed:Array<InviteInfo> = [];
      for (r in rawResults)
      {
        if (r == null) continue;
        parsed.push({
          discordId: Std.string(Reflect.field(r, 'discordId')),
          username: Std.string(Reflect.field(r, 'username')),
          avatarUrl: Reflect.hasField(r, 'avatarUrl') && Reflect.field(r, 'avatarUrl') != null ? Std.string(Reflect.field(r, 'avatarUrl')) : ''});
      }
      callback(parsed);
    });
  }

  /**
   * Manda um convite pro usuário `target`.
   *
   * `hostAddress` é o IP/domínio que o CONVIDADO vai usar pra conectar
   * no server que o host subiu — em teste local é '127.0.0.1'; pra
   * internet de verdade, o IP público (com a porta liberada no
   * roteador) ou o domínio DuckDNS da máquina hospedando.
   */
  public function sendInvite(target:InviteInfo, hostServerId:String, hostAddress:String, hostPort:Int, ?onSent:Void->Void, ?onError:String->Void):Void
  {
    if (target == null)
    {
      if (onError != null) onError('destino inválido');
      return;
    }

    relay.sendInvite(target.discordId, hostServerId, hostAddress, hostPort, onSent, onError);
  }

  /** Chame do lado do convidado quando ele apertar ACCEPT/DISCARD. */
  public function respondToInvite(invite:InviteInfo, accept:Bool):Void
  {
    if (invite == null || invite.inviteId == null) return;
    relay.respondToInvite(invite.inviteId, accept);
  }

  function handleRelayInvite(data:Dynamic):Void
  {
    if (onInviteReceived == null) return;

    var invite:InviteInfo = {
      discordId: Std.string(Reflect.field(data, 'fromDiscordId')),
      username: Std.string(Reflect.field(data, 'fromUsername')),
      avatarUrl
      : Reflect.hasField(data, 'fromAvatarUrl')
      && Reflect.field(data, 'fromAvatarUrl') != null ? Std.string(Reflect.field(data, 'fromAvatarUrl')) : '',
      inviteId: Std.string(Reflect.field(data, 'inviteId')),
      serverId: Reflect.hasField(data, 'hostServerId') ? Std.string(Reflect.field(data, 'hostServerId')) : null,
      hostAddress: Reflect.hasField(data, 'hostAddress') ? Std.string(Reflect.field(data, 'hostAddress')) : null,
      port: Reflect.hasField(data, 'hostPort') ? Std.int(Reflect.field(data, 'hostPort')) : null
    };

    // O convite chega numa thread de rede (leitura do socket) — o resto
    // do jogo (Flixel/sprites) só pode ser mexido na main thread.
    haxe.MainLoop.runInMainThread(() -> onInviteReceived(invite));
  }

  /**
   * Só pra testar a UI sem precisar do relay rodando: dispara
   * onInviteReceived manualmente, simulando que alguém te convidou.
   */
  public function debugSimulateIncomingInvite(fromUsername:String, fromAvatarUrl:String, serverId:String, hostAddress:String, port:Int):Void
  {
    if (onInviteReceived == null) return;
    onInviteReceived({
      discordId: 'debug_' + fromUsername,
      username: fromUsername,
      avatarUrl: fromAvatarUrl,
      inviteId: 'debug_invite',
      serverId: serverId,
      hostAddress: hostAddress,
      port: port
    });
  }
  #end
}

typedef InviteInfo =
{
  var discordId:String;
  var username:String;
  var avatarUrl:String;
  var ?inviteId:String;
  var ?serverId:String;
  var ?hostAddress:String;
  var ?port:Int;
}
