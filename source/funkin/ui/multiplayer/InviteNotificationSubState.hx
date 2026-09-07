package funkin.ui.multiplayer;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatSubState;
import funkin.multiplayer.RemoteImageLoader;
import funkin.multiplayer.MultiplayerClient;
import funkin.multiplayer.MultiplayerInviteService;
import funkin.multiplayer.MultiplayerInviteService.InviteInfo;
import funkin.play.PlayState;
import funkin.play.song.Song;
import funkin.data.song.SongRegistry;
import funkin.ui.transition.LoadingState;

/**
 * Card que aparece no PC do CONVIDADO quando alguém manda um convite.
 * Avatar + nick do Discord em cima, ACCEPT (verde, texto branco) e
 * DISCARD (vermelho, texto branco) embaixo.
 *
 * Quem abre esse card é quem estiver escutando
 * `MultiplayerInviteService.instance.onInviteReceived` — hoje isso tá
 * plugado na OnlineMenuState (ver ajuste nesse arquivo).
 *
 * ACCEPT agora conecta de verdade: sobe um MultiplayerClient pro
 * `invite.hostAddress:invite.port` (endereço que o relay mandou junto
 * do convite) e entra no PlayState assim que o host mandar 'match_start'
 * — mesmo fluxo que o connectOnline() manual da OnlineMenuState já
 * fazia, só que disparado automaticamente pelo convite.
 */
class InviteNotificationSubState extends MusicBeatSubState
{
  #if FEATURE_ONLINE
  var invite:InviteInfo;
  var account:Dynamic;
  var dim:Null<FunkinSprite> = null;
  var cardBg:Null<FunkinSprite> = null;
  var avatarSprite:Null<FlxSprite> = null;
  var nickText:Null<FlxText> = null;
  var statusText:Null<FlxText> = null;
  var acceptButton:Null<FlxButton> = null;
  var discardButton:Null<FlxButton> = null;
  var isMultiplayerMode:Bool;
  var client:Null<MultiplayerClient> = null;

  public function new(invite:InviteInfo, ?account:Dynamic)
  {
    super();
    this.invite = invite;
    this.account = account;
  }

  override function create():Void
  {
    super.create();

    final cardW:Int = 360;
    final cardH:Int = 280;
    final cardX:Float = (FlxG.width - cardW) / 2;
    final cardY:Float = (FlxG.height - cardH) / 2;

    dim = new FunkinSprite(0, 0);
    dim.makeSolidColor(FlxG.width, FlxG.height, 0x99000000);
    add(dim);

    cardBg = new FunkinSprite(cardX, cardY);
    cardBg.makeSolidColor(cardW, cardH, 0xFF1B2436);
    add(cardBg);

    avatarSprite = new FlxSprite(cardX + (cardW - 80) / 2, cardY + 24);
    avatarSprite.makeGraphic(80, 80, 0xFF4A4A4A); // placeholder até o avatar real carregar
    add(avatarSprite);
    RemoteImageLoader.loadInto(avatarSprite, invite.avatarUrl, () ->
    {
      avatarSprite.setGraphicSize(80, 80);
      avatarSprite.updateHitbox();
      avatarSprite.x = cardX + (cardW - avatarSprite.width) / 2;
    });

    nickText = new FlxText(cardX, cardY + 112, cardW, invite.username + ' te convidou pra jogar!', 18);
    nickText.setFormat(Paths.font('vcr.ttf'), 18, 0xFFFFFFFF, CENTER);
    add(nickText);

    statusText = new FlxText(cardX, cardY + 142, cardW, '', 14);
    statusText.setFormat(Paths.font('vcr.ttf'), 14, 0xFFB7C8FF, CENTER);
    add(statusText);

    acceptButton = new FlxButton(cardX + 24, cardY + cardH - 70, 'ACCEPT', onAcceptPressed);
    acceptButton.color = 0xFF2ECC71; // verde
    acceptButton.label.color = 0xFFFFFFFF;
    acceptButton.scale.set(1.3, 1.3);
    acceptButton.updateHitbox();
    add(acceptButton);

    discardButton = new FlxButton(cardX + cardW - 24 - acceptButton.width, cardY + cardH - 70, 'DISCARD', onDiscardPressed);
    discardButton.color = 0xFFE74C3C; // vermelho
    discardButton.label.color = 0xFFFFFFFF;
    discardButton.scale.set(1.3, 1.3);
    discardButton.updateHitbox();
    add(discardButton);
  }

  function onAcceptPressed():Void
  {
    MultiplayerInviteService.instance.respondToInvite(invite, true);

    // Trava os botões pra não clicar duas vezes enquanto conecta.
    if (acceptButton != null) acceptButton.exists = false;
    if (discardButton != null) discardButton.exists = false;
    if (statusText != null) statusText.text = 'Conectando...';

    var address:String = (invite.hostAddress != null && invite.hostAddress.length > 0) ? invite.hostAddress : '127.0.0.1';
    var targetPort:Int = (invite.port != null) ? invite.port : 2082;

    var c:MultiplayerClient = new MultiplayerClient(address, targetPort);
    client = c;

    c.onConnect = () ->
    {
      trace('[Invite] conectado no host (' + address + ':' + targetPort + ')');
      if (statusText != null) statusText.text = 'Conectado! Aguardando o host...';

      if (account != null)
      {
        c.send({
          type: 'connect',
          id: Std.string(Reflect.field(account, 'id')),
          username: Std.string(Reflect.field(account, 'username'))
        });
      }
    };

    c.onError = (msg:String) ->
    {
      trace('[Invite] erro ao conectar no host: ' + msg);
      if (statusText != null) statusText.text = 'Falha ao conectar: ' + msg;
    };

    c.onMessage = (msg:Dynamic) ->
    {
      if (msg != null && Reflect.hasField(msg, 'type') && Std.string(Reflect.field(msg, 'type')) == 'match_start')
      {
        onMatchStart(msg);
      }
    };

    try
    {
      c.connect();
    }
    catch (e:Dynamic)
    {
      trace('[Invite] exceção ao conectar no host: ' + e);
      if (statusText != null) statusText.text = 'Falha ao conectar no host.';
    }
  }

  function onMatchStart(msg:Dynamic):Void
  {
    if (!Reflect.hasField(msg, 'songId')) return;

    var songId:String = Std.string(Reflect.field(msg, 'songId'));
    var difficulty:String = Reflect.hasField(msg, 'difficulty') ? Std.string(Reflect.field(msg, 'difficulty')) : 'normal';
    var variation:String = Reflect.hasField(msg, 'variation') ? Std.string(Reflect.field(msg, 'variation')) : 'default';

    var song:Null<Song> = SongRegistry.instance.fetchEntry(songId);
    if (song == null)
    {
      trace('[Invite] música recebida do host não encontrada: ' + songId);
      return;
    }

    #if FEATURE_ONLINE
    PlayState.multiplayerClient = client;
    PlayState.multiplayerMatchActive = true;
    PlayState.multiplayerMatchId = invite.serverId;
    #end

    close();

    LoadingState.loadPlayState({
      targetSong: song,
      targetDifficulty: difficulty,
      targetVariation: variation,
      isMultiplayerMode: true
    });
  }

  function onDiscardPressed():Void
  {
    MultiplayerInviteService.instance.respondToInvite(invite, false);
    close();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (FlxG.keys.justPressed.ESCAPE) onDiscardPressed();
  }
  #end
}
