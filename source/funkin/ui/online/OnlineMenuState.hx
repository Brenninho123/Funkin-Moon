package funkin.ui.online;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.math.FlxPoint;
import funkin.audio.FunkinSound;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatState;
import funkin.ui.mainmenu.MainMenuState;
import funkin.online.FunkinOnline;
import funkin.online.play.FunkinMultiplayer;
import funkin.ui.multiplayer.LoginSubState;
import funkin.ui.multiplayer.HostMenuSubState;
import funkin.ui.multiplayer.InviteNotificationSubState;
import funkin.multiplayer.MultiplayerAccountManager;
import funkin.multiplayer.MultiplayerInviteService;
import funkin.multiplayer.MultiplayerInviteService.InviteInfo;
import funkin.play.PlayState;
import funkin.play.song.Song;
import funkin.data.song.SongRegistry;
import funkin.ui.transition.LoadingState;

class OnlineMenuState extends MusicBeatState
{
  #if FEATURE_ONLINE
  var bg:Null<FunkinSprite> = null;
  var title:Null<FlxText> = null;
  var watermarkText:Null<FlxText> = null;
  var subtitle:Null<FlxText> = null;
  var statusText:Null<FlxText> = null;
  var hostButton:Null<FunkinSprite> = null;
  var hostLocked:Bool = false;
  var isMultiplayerMode:Bool;
  var connectButton:Null<FlxButton> = null;
  var backButton:Null<FlxButton> = null;
  var currentAccount:Dynamic = null;
  var selectedIndex:Int = 0;

  static final OPTION_COUNT:Int = 3;

  override function create():Void
  {
    super.create();

    FlxG.mouse.visible = true;

    bg = new FunkinSprite(0, 0);
    bg.makeSolidColor(FlxG.width, FlxG.height, 0xFF101722);
    add(bg);

    title = new FlxText(0, 40, FlxG.width, 'ONLINE MENU', 42);
    if (title != null)
    {
      title.setFormat(Paths.font('vcr.ttf'), 42, 0xFFFFFFFF, CENTER);
      add(title);
    }

    subtitle = new FlxText(0, 100, FlxG.width, 'Aguardando jogadores...', 18);
    if (subtitle != null)
    {
      subtitle.setFormat(Paths.font('vcr.ttf'), 18, 0xFFB7C8FF, CENTER);
      add(subtitle);
    }

    watermarkText = new FlxText(0, 250, FlxG.width, 'online feature in wip.', 18);
    if (watermarkText != null)
    {
      watermarkText.setFormat(Paths.font('vcr.ttf'), 18, 0xFFB7C8FF, CENTER);
      add(watermarkText);
    }

    statusText = new FlxText(0, 150, FlxG.width, '1/2 connected', 22);
    if (statusText != null)
    {
      statusText.setFormat(Paths.font('vcr.ttf'), 22, 0xFF7CF6CF, CENTER);
      add(statusText);
    }

    // ---- HOST como FunkinSprite animado ----
    hostButton = new FunkinSprite(220, 280);
    hostButton.frames = Paths.getSparrowAtlas('mainmenu/host');
    hostButton.animation.addByPrefix('idle', 'host idle', 24, true);
    hostButton.animation.addByPrefix('confirm', 'host selected', 24, false);
    hostButton.animation.play('idle');
    hostButton.antialiasing = true;
    add(hostButton);

    connectButton = new FlxButton(460, 280, 'CONNECT', connectOnline);
    if (connectButton != null)
    {
      connectButton.color = 0xFF27C7A4;
      connectButton.scale.set(2.0, 2.0);
      connectButton.updateHitbox();
      connectButton.onOver.callback = () ->
      {
        connectButton.color = 0xFF3FE9D6;
        connectButton.scale.set(2.1, 2.1);
      };
      connectButton.onOut.callback = () ->
      {
        connectButton.color = 0xFF27C7A4;
        connectButton.scale.set(2.0, 2.0);
      };
      add(connectButton);
    }

    backButton = new FlxButton(340, 400, 'BACK', () ->
    {
      trace('[MP] Back button clicked');
      FlxG.switchState(() -> new MainMenuState());
    });
    if (backButton != null)
    {
      backButton.color = 0xFF8B8B8B;
      backButton.scale.set(1.8, 1.8);
      backButton.updateHitbox();
      backButton.onOver.callback = () ->
      {
        backButton.color = 0xFFC0C0C0;
        backButton.scale.set(1.9, 1.9);
      };
      backButton.onOut.callback = () ->
      {
        backButton.color = 0xFF8B8B8B;
        backButton.scale.set(1.8, 1.8);
      };
      add(backButton);
    }

    currentAccount = MultiplayerAccountManager.getOrCreateAccount('Player');
    if (statusText != null)
    {
      statusText.text = 'Conta ativa: ' + Std.string(currentAccount.username) + ' | ID: ' + Std.string(currentAccount.id) + ' | 1/2 connected';
    }

    registerOnlineHandlers();

    FunkinSound.playMusic('chartEditorloop', {
      overrideExisting: true,
      loop: true
    });

    if (!MultiplayerAccountManager.isDiscordLinked(currentAccount))
    {
      openSubState(new LoginSubState(currentAccount, (profile) ->
      {
        if (statusText != null)
        {
          statusText.text = 'Conta ativa: ' + Std.string(currentAccount.username) + ' | ID: ' + Std.string(currentAccount.id) + ' | 1/2 connected';
        }

        MultiplayerInviteService.instance.updateIdentity(currentAccount);
      }));
    }
  }

  /**
   * Liga os sinais do FunkinMultiplayer (camada de sala/partida) aos
   * elementos visuais dessa tela. Substitui os antigos callbacks
   * onConnect/onMessage/onDisconnect do MultiplayerClient binário.
   */
  function registerOnlineHandlers():Void
  {
    FunkinMultiplayer.instance.init();

    FunkinOnline.instance.onConnected.add(onOnlineConnected);
    FunkinOnline.instance.onDisconnected.add(onOnlineDisconnected);
    FunkinOnline.instance.onError.add(onOnlineError);

    FunkinMultiplayer.instance.onRoomJoined.add(onRoomReady);
    FunkinMultiplayer.instance.onRoomCreated.add(onRoomReady);
    FunkinMultiplayer.instance.onSongStart.add(onSongStart);
  }

  function unregisterOnlineHandlers():Void
  {
    FunkinOnline.instance.onConnected.remove(onOnlineConnected);
    FunkinOnline.instance.onDisconnected.remove(onOnlineDisconnected);
    FunkinOnline.instance.onError.remove(onOnlineError);

    FunkinMultiplayer.instance.onRoomJoined.remove(onRoomReady);
    FunkinMultiplayer.instance.onRoomCreated.remove(onRoomReady);
    FunkinMultiplayer.instance.onSongStart.remove(onSongStart);
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (!hostLocked)
    {
      // ---- Navegação: setas/WASD movem a seleção ----
      final pressedNext:Bool = FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S || FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D;
      final pressedPrev:Bool = FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W || FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A;

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

      // ---- Confirmar com ENTER/SPACE ----
      if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
      {
        confirmSelection();
      }

      // ---- ESC volta pro menu principal ----
      if (FlxG.keys.justPressed.ESCAPE)
      {
        trace('[MP] ESC pressionado - voltando pro MainMenuState');
        FlxG.switchState(() -> new MainMenuState());
      }
    }

    updateSelectionVisuals();

    final mouseWorld:FlxPoint = FlxG.mouse.getWorldPosition();

    if (hostButton != null && !hostLocked)
    {
      final overHost:Bool = hostButton.overlapsPoint(mouseWorld, false);
      if (overHost && FlxG.mouse.justPressed)
      {
        selectedIndex = 0;
        confirmSelection();
      }
    }
  }

  function updateSelectionVisuals():Void
  {
    if (hostButton != null && !hostLocked)
    {
      final scale:Float = (selectedIndex == 0) ? 1.05 : 1.0;
      if (hostButton.scale.x != scale)
      {
        hostButton.scale.set(scale, scale);
        hostButton.updateHitbox();
      }
    }

    if (connectButton != null)
    {
      final selected:Bool = selectedIndex == 1;
      connectButton.color = selected ? 0xFF3FE9D6 : 0xFF27C7A4;
      connectButton.scale.set(selected ? 2.1 : 2.0, selected ? 2.1 : 2.0);
    }

    if (backButton != null)
    {
      final selected:Bool = selectedIndex == 2;
      backButton.color = selected ? 0xFFC0C0C0 : 0xFF8B8B8B;
      backButton.scale.set(selected ? 1.9 : 1.8, selected ? 1.9 : 1.8);
    }
  }

  function confirmSelection():Void
  {
    switch (selectedIndex)
    {
      case 0:
        if (hostButton != null && !hostLocked)
        {
          hostLocked = true;
          hostButton.animation.play('confirm', true);
          hostButton.animation.finishCallback = (_) -> startHost();
        }
      case 1:
        connectOnline();
      case 2:
        trace('[MP] Back selecionado');
        FlxG.switchState(() -> new MainMenuState());
    }
  }

  /**
   * Conecta no relay via FunkinOnline (texto JSON + '\n'), no lugar do
   * antigo MultiplayerClient binário. O resultado da conexão chega
   * pelos sinais registrados em registerOnlineHandlers(), não mais
   * por callbacks onConnect/onMessage passados na hora.
   */
  function connectOnline():Void
  {
    trace('[MP] Connect button clicked');

    if (statusText != null) statusText.text = 'Conectando...';

    FunkinOnline.instance.connect('127.0.0.1', 2082);
  }

  function onOnlineConnected():Void
  {
    trace('[MP] connected to server');
    if (statusText != null) statusText.text = 'Conectado. Aguardando partida...';

    if (currentAccount != null)
    {
      FunkinOnline.instance.send('connect', {
        id: Std.string(currentAccount.id),
        username: Std.string(currentAccount.username),
        password: Std.string(currentAccount.password)
      });
    }
  }

  function onOnlineDisconnected():Void
  {
    trace('[MP] disconnected');
    if (statusText != null) statusText.text = 'Desconectado.';
  }

  function onOnlineError(msg:String):Void
  {
    trace('[MP] error: $msg');
    if (statusText != null) statusText.text = 'Erro: ' + msg;
  }

  function onRoomReady(room:Dynamic):Void
  {
    if (statusText != null) statusText.text = 'Sala pronta. Aguardando oponente... 1/2 connected';
  }

  // Chamado quando FunkinMultiplayer recebe 'mp_startSong' do host.
  // NOTA: essa mensagem não carrega mais songId/difficulty/variation
  // diretamente no payload que o FunkinMultiplayer expõe pro
  // onSongStart (ele só dispara Void->Void). Se o relay novo ainda não
  // manda esses dados nesse evento, isso vai quebrar até a gente
  // reescrever o RelayServer/MultiplayerServer (próximo passo da fila).

  function onSongStart():Void
  {
    if (FunkinMultiplayer.instance.currentRoom == null) return;

    var room = FunkinMultiplayer.instance.currentRoom;
    var songId:String = room.songId;
    if (songId == null) return;

    var song:Null<Song> = SongRegistry.instance.fetchEntry(songId);
    if (song == null)
    {
      trace('[MP] música recebida do host não encontrada: ' + songId);
      return;
    }

    // PlayState.multiplayerClient esperava o MultiplayerClient antigo.
    // Isso vai quebrar a compilação até PlayState.hx ser atualizado pra
    // apontar pro FunkinOnline/FunkinMultiplayer — não mexi nele agora
    // porque não foi o que você pediu nessa rodada.
    #if FEATURE_ONLINE
    PlayState.multiplayerMatchActive = true;
    #end

    LoadingState.loadPlayState({
      targetSong: song,
      targetDifficulty: room.difficultyId ?? 'normal',
      targetVariation: room.variation ?? 'default',
      isMultiplayerMode: true
    });
  }

  function onInviteReceived(invite:InviteInfo):Void
  {
    trace('[MP] convite recebido de ' + invite.username);
    openSubState(new InviteNotificationSubState(invite, currentAccount));
  }

  function startHost():Void
  {
    trace('[MP] HOST clicked - abrindo HostMenuSubState');
    if (statusText != null) statusText.text = 'Abrindo host...';

    openSubState(new HostMenuSubState(currentAccount, (success:Bool) ->
    {
      hostLocked = false;
      if (hostButton != null) hostButton.animation.play('idle', true);

      if (success)
      {
        if (statusText != null) statusText.text = 'Indo pro Freeplay escolher a música...';
        FlxG.switchState(() -> new funkin.ui.freeplay.FreeplayState());
      }
      else if (statusText != null)
      {
        statusText.text = 'Host fechado. 1/2 connected';
      }
    }));
  }

  override function destroy():Void
  {
    unregisterOnlineHandlers();
    FunkinOnline.instance.disconnect();

    if (MultiplayerInviteService.instance.onInviteReceived == onInviteReceived)
    {
      MultiplayerInviteService.instance.onInviteReceived = null;
    }
    super.destroy();
  }
  #end
}
