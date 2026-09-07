package funkin.ui.multiplayer;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatSubState;
import funkin.multiplayer.MultiplayerServer;
import funkin.multiplayer.MultiplayerHostSession;
import funkin.audio.FunkinSound;

/**
 * Card que abre por cima da OnlineMenuState quando o jogador clica em HOST.
 * Sobe um MultiplayerServer local e espera o convidado conectar.
 *
 * Botão LIGAR/DESLIGAR (era o antigo PLAY): fica travado (cinza,
 * "DESLIGADO") até o convidado conectar (2/2). Quando liga, a
 * HostMenuSubState fecha e o `onClosed(true)` avisa a OnlineMenuState
 * pra trocar de tela pro Freeplay, onde o host escolhe a música. A
 * seleção de música NÃO acontece mais aqui dentro — ver
 * MultiplayerHostSession pra saber onde ela é retomada.
 *
 * Navegação: setas/WASD alternam entre CONVIDAR e LIGAR/DESLIGAR,
 * ENTER/SPACE confirma, ESC fecha o card (igual o resto do menu).
 */
class HostMenuSubState extends MusicBeatSubState
{
  #if FEATURE_ONLINE
  var account:Dynamic;
  var onClosed:(success:Bool) -> Void;
  var cardBg:Null<FunkinSprite> = null;
  var dim:Null<FunkinSprite> = null;
  var titleText:Null<FlxText> = null;
  var matchupText:Null<FlxText> = null;
  var portText:Null<FlxText> = null;
  var countText:Null<FlxText> = null;
  var serverIdText:Null<FlxText> = null;
  var toggleButton:Null<FlxButton> = null;
  var inviteButton:Null<FlxButton> = null;
  var closeButton:Null<FlxButton> = null;
  var server:Null<MultiplayerServer> = null;
  var serverId:String = '';
  var port:Int = 2082;
  // Só fica true quando o segundo jogador conecta.
  var playerReady:Bool = false;

  /**
   * Endereço que o RELAY vai mandar pro convidado quando ele apertar
   * ACCEPT — é pra ONDE o MultiplayerClient dele vai tentar conectar.
   *
   * '127.0.0.1' só funciona se host e convidado estiverem na MESMA
   * máquina (dois processos do jogo abertos, útil só pra teste). Pra
   * convidar alguém de verdade (outra máquina/rede), troca isso antes
   * de abrir o HostMenuSubState pelo seu IP local (mesma rede/LAN) ou,
   * pra internet, o IP público / domínio DuckDNS da máquina que tá
   * hospedando, com a porta ($port) liberada no roteador.
   */
  public var hostAddress:String = '127.0.0.1';

  // ---- Navegação por teclado ----
  // 0 = CONVIDAR, 1 = LIGAR/DESLIGAR
  var selectedIndex:Int = 0;

  static final OPTION_COUNT:Int = 2;

  public function new(account:Dynamic, onClosed:(success:Bool) -> Void)
  {
    super();
    this.account = account;
    this.onClosed = onClosed;
  }

  override function create():Void
  {
    super.create();

    dim = new FunkinSprite(0, 0);
    dim.makeSolidColor(FlxG.width, FlxG.height, 0x99000000);
    add(dim);

    final cardW:Int = 640;
    final cardH:Int = 460;
    final cardX:Float = (FlxG.width - cardW) / 2;
    final cardY:Float = (FlxG.height - cardH) / 2;

    cardBg = new FunkinSprite(cardX, cardY);
    cardBg.makeSolidColor(cardW, cardH, 0xFF1B2436);
    add(cardBg);

    titleText = new FlxText(cardX, cardY + 20, cardW, 'HOST', 36);
    titleText.setFormat(Paths.font('vcr.ttf'), 36, 0xFFFFFFFF, CENTER);
    add(titleText);

    matchupText = new FlxText(cardX, cardY + 70, cardW, Std.string(account.username) + ' vs. ???', 20);
    matchupText.setFormat(Paths.font('vcr.ttf'), 20, 0xFFB7C8FF, CENTER);
    add(matchupText);

    serverId = generateServerId();

    portText = new FlxText(cardX, cardY + 130, cardW, 'LAN PORTA: ' + Std.string(port), 22);
    portText.setFormat(Paths.font('vcr.ttf'), 22, 0xFFFFFFFF, CENTER);
    add(portText);

    countText = new FlxText(cardX, cardY + 180, cardW, '1/2', 30);
    countText.setFormat(Paths.font('vcr.ttf'), 30, 0xFF7CF6CF, CENTER);
    add(countText);

    serverIdText = new FlxText(cardX, cardY + 240, cardW, 'SERVER: ' + serverId, 20);
    serverIdText.setFormat(Paths.font('vcr.ttf'), 20, 0xFFB7C8FF, CENTER);
    add(serverIdText);

    // Botão LIGAR/DESLIGAR — só é "clicável de verdade" quando
    // playerReady == true (checado no onTogglePressed).
    toggleButton = new FlxButton(cardX + (cardW / 2) - 70, cardY + cardH - 90, 'DESLIGADO', onTogglePressed);
    toggleButton.scale.set(1.6, 1.6);
    toggleButton.updateHitbox();
    add(toggleButton);
    updateToggleVisual();

    // Botão pra convidar alguém pelo nick do Discord. Fica do lado
    // esquerdo do toggle, sempre clicável (não depende do playerReady).
    inviteButton = new FlxButton(cardX + 30, cardY + cardH - 90, 'CONVIDAR', onInvitePressed);
    inviteButton.color = 0xFF5865F2; // roxo/azulado, cor da marca do Discord
    inviteButton.label.color = 0xFFFFFFFF;
    inviteButton.scale.set(1.2, 1.2);
    inviteButton.updateHitbox();
    add(inviteButton);

    closeButton = new FlxButton(cardX + cardW - 40, cardY + 10, 'X', onClosePressed);
    closeButton.color = 0xFF8B8B8B;
    add(closeButton);

    startHosting();
  }

  function generateServerId():String
  {
    final chars:String = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    var id:String = '';
    for (i in 0...6) id += chars.charAt(Std.int(Math.random() * chars.length));
    return id;
  }

  function startHosting():Void
  {
    try
    {
      server = new MultiplayerServer(port);

      server.onClientConnect = () ->
      {
        trace('[Host] client conectou');
        playerReady = true;
        if (countText != null) countText.text = '2/2';
        updateToggleVisual();
      };

      server.onClientDisconnect = () ->
      {
        trace('[Host] client desconectou');
        playerReady = false;
        if (countText != null) countText.text = '1/2';
        if (matchupText != null) matchupText.text = Std.string(account.username) + ' vs. ???';
        updateToggleVisual();
      };

      server.onClientMessage = (data:Dynamic) ->
      {
        if (data != null && Reflect.hasField(data, 'type') && Std.string(Reflect.field(data, 'type')) == 'connect')
        {
          var opponentName:String = Reflect.hasField(data, 'username') ? Std.string(Reflect.field(data, 'username')) : '???';
          if (matchupText != null) matchupText.text = Std.string(account.username) + ' vs. ' + opponentName;
        }
      };

      server.start();
      // Se chegou até aqui sem exception, o server subiu certinho na porta.
      trace('[Host] server rodando na porta ' + port);
    }
    catch (e:Dynamic)
    {
      trace('[Host] falha ao iniciar servidor: ' + e);
      if (portText != null) portText.text = 'Falha ao abrir a porta ' + Std.string(port);
      server = null;
    }
  }

  function onInvitePressed():Void
  {
    trace('[Host] CONVIDAR clicado, abrindo busca por nick do Discord (endereço enviado: $hostAddress:$port)');
    // Mesma package (funkin.ui.multiplayer), não precisa de import extra.
    openSubState(new InviteSearchSubState(serverId, hostAddress, port));
  }

  function updateToggleVisual():Void
  {
    if (toggleButton == null) return;
    if (playerReady)
    {
      toggleButton.label.text = 'LIGAR';
      toggleButton.color = 0xFF2ECC71; // verde, pronto pra ligar
    }
    else
    {
      toggleButton.label.text = 'DESLIGADO';
      toggleButton.color = 0xFF4A4A4A; // cinza, travado
    }
  }

  function onTogglePressed():Void
  {
    // Trava real: só passa daqui se os dois jogadores estiverem conectados.
    if (!playerReady)
    {
      trace('[Host] toggle ignorado, esperando o segundo jogador ainda');
      return;
    }

    trace('[Host] LIGADO — indo pro Freeplay escolher a música');

    MultiplayerHostSession.active = true;
    MultiplayerHostSession.serverId = serverId;

    // NOTA: não chama server.stop() aqui — o servidor precisa continuar
    // rodando pra avisar o convidado quando a música for escolhida no
    // Freeplay (ver MultiplayerHostSession.startMatch).
    if (onClosed != null) onClosed(true);
    close();
  }

  function onClosePressed():Void
  {
    if (server != null)
    {
      server.stop();
    }
    MultiplayerHostSession.cancel();
    if (onClosed != null) onClosed(false);
    close();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    // ---- Navegação por teclado: setas/WASD alternam CONVIDAR <-> LIGAR ----
    final pressedNext:Bool = FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D || FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S;
    final pressedPrev:Bool = FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A || FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W;

    if (pressedNext)
    {
      selectedIndex = (selectedIndex + 1) % OPTION_COUNT;
      FunkinSound.playOnce(Paths.sound('scrollMenu'));
    }
    else if (pressedPrev)
    {
      selectedIndex = (selectedIndex - 1 + OPTION_COUNT) % OPTION_COUNT;
      FunkinSound.playOnce(Paths.sound('scrollMenu'));
    }

    if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
    {
      switch (selectedIndex)
      {
        case 0:
          onInvitePressed();
        case 1:
          onTogglePressed();
      }
    }

    if (FlxG.keys.justPressed.ESCAPE)
    {
      onClosePressed();
    }

    updateSelectionVisuals();
  }

  function updateSelectionVisuals():Void
  {
    if (inviteButton != null)
    {
      final selected:Bool = selectedIndex == 0;
      inviteButton.scale.set(selected ? 1.3 : 1.2, selected ? 1.3 : 1.2);
      inviteButton.updateHitbox();
    }

    if (toggleButton != null)
    {
      final selected:Bool = selectedIndex == 1;
      toggleButton.scale.set(selected ? 1.7 : 1.6, selected ? 1.7 : 1.6);
      toggleButton.updateHitbox();
    }
  }

  override function destroy():Void
  {
    // Só derruba o servidor se a partida NÃO tiver sido iniciada — se
    // MultiplayerHostSession.active for true, o servidor precisa
    // continuar rodando até o match_start ser mandado do Freeplay.
    if (server != null && !MultiplayerHostSession.active)
    {
      server.stop();
    }
    super.destroy();
  }
  #end
}
