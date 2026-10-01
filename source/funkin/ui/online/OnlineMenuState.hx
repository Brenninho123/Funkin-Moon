package funkin.ui.online;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.math.FlxPoint;
import funkin.audio.FunkinSound;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatState;
import funkin.ui.mainmenu.MainMenuState;
import funkin.online.DiscordAuth;
import funkin.online.DiscordAuth.DiscordUserProfile;
import funkin.online.FunkinOnline;
import funkin.online.FunkinUser;
import funkin.online.OnlineConfig;
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
  var exitButton:Null<FlxButton> = null;
  var currentAccount:Dynamic = null;
  var selectedIndex:Int = 0;
  var playerListText:Null<FlxText> = null;
  var loginPrompted:Bool = false;
  var refreshTimer:Float = 0;

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

    subtitle = new FlxText(0, 100, FlxG.width, 'Connecting...', 18);
    if (subtitle != null)
    {
      subtitle.setFormat(Paths.font('vcr.ttf'), 18, 0xFFB7C8FF, CENTER);
      add(subtitle);
    }

    watermarkText = new FlxText(0, 230, FlxG.width, '', 18);
    if (watermarkText != null)
    {
      watermarkText.setFormat(Paths.font('vcr.ttf'), 18, 0xFFB7C8FF, CENTER);
      add(watermarkText);
    }

    statusText = new FlxText(0, 150, FlxG.width, 'Offline', 22);
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

    connectButton = new FlxButton(460, 280, 'ROOMS', connectOnline);
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

    exitButton = new FlxButton(340, 400, 'BACK', () ->
    {
      trace('[MP] Back button clicked');
      FlxG.switchState(() -> new MainMenuState());
    });
    if (exitButton != null)
    {
      exitButton.color = 0xFF8B8B8B;
      exitButton.scale.set(1.8, 1.8);
      exitButton.updateHitbox();
      exitButton.onOver.callback = () ->
      {
        exitButton.color = 0xFFC0C0C0;
        exitButton.scale.set(1.9, 1.9);
      };
      exitButton.onOut.callback = () ->
      {
        exitButton.color = 0xFF8B8B8B;
        exitButton.scale.set(1.8, 1.8);
      };
      add(exitButton);
    }

    playerListText = new FlxText(FlxG.width - 360, 150, 340, '', 16);
    playerListText.setFormat(Paths.font('vcr.ttf'), 16, 0xFFD6E0FF, LEFT);
    add(playerListText);

    currentAccount = MultiplayerAccountManager.getOrCreateAccount(DiscordAuth.instance.getCachedUsername() ?? 'Player');

    registerOnlineHandlers();
    refreshStatus();

    FunkinSound.playMusic('chartEditorLoop', {
      overrideExisting: true,
      loop: true
    });

    if (FunkinOnline.instance.state == Disconnected) FunkinOnline.instance.connect(OnlineConfig.host, OnlineConfig.port);

    promptLoginIfNeeded();
  }

  function promptLoginIfNeeded():Void
  {
    var auth:DiscordAuth = DiscordAuth.instance;

    if (loginPrompted || auth.isLoggedIn() || !auth.discordEnabled || !FunkinOnline.instance.isConnected()) return;

    loginPrompted = true;

    openLogin();
  }

  function openLogin():Void
  {
    if (subState != null || currentAccount == null) return;

    openSubState(new LoginSubState(currentAccount, onDiscordLoggedIn));
  }

  function onDiscordLoggedIn(profile:DiscordUserProfile):Void
  {
    MultiplayerInviteService.instance.updateIdentity(currentAccount);

    refreshStatus();
  }

  function refreshStatus():Void
  {
    var online:FunkinOnline = FunkinOnline.instance;
    var auth:DiscordAuth = DiscordAuth.instance;
    var users:Array<funkin.online.FunkinUser.FunkinUserInfo> = FunkinUser.instance.getActiveUsers();

    users.sort((a, b) -> a.username.toLowerCase() < b.username.toLowerCase() ? -1 : (a.username.toLowerCase() > b.username.toLowerCase() ? 1 : 0));

    if (subtitle != null)
    {
      subtitle.text = switch (online.state)
      {
        case Connected: 'Connected to ' + OnlineConfig.describe();
        case Connecting: 'Connecting to ' + OnlineConfig.describe() + '...';
        case Reconnecting: 'Server unreachable, retrying...';
        case Disconnected: 'Not connected';
      };
    }

    if (statusText != null)
    {
      statusText.text = online.isConnected() ? '${users.length} player${users.length == 1 ? '' : 's'} online' : 'Offline';
      statusText.color = online.isConnected() ? 0xFF7CF6CF : 0xFFFF7C7C;
    }

    if (watermarkText != null)
    {
      watermarkText.text = auth.isLoggedIn() ? 'Discord: ' + auth.profile.username : (auth.discordEnabled ? 'Discord: not logged in (press L)' : 'Discord login is unavailable on this server');
    }

    if (playerListText != null)
    {
      var localId:String = FunkinUser.instance.getLocalUserId();
      var lines:Array<String> = [];

      for (user in users)
      {
        if (lines.length >= 10) break;

        lines.push((user.authenticated == true ? '* ' : '  ') + user.username + (user.id == localId ? ' (you)' : '') + '  ' + user.activity);
      }

      if (users.length > 10) lines.push('  +' + (users.length - 10) + ' more');

      playerListText.text = lines.join('\n');
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
    FunkinUser.instance.onActiveUsersChanged.add(refreshStatus);
    DiscordAuth.instance.onChanged.add(refreshStatus);

    FunkinMultiplayer.instance.onRoomJoined.add(onRoomReady);
    FunkinMultiplayer.instance.onRoomCreated.add(onRoomReady);
  }

  function unregisterOnlineHandlers():Void
  {
    FunkinOnline.instance.onConnected.remove(onOnlineConnected);
    FunkinOnline.instance.onDisconnected.remove(onOnlineDisconnected);
    FunkinOnline.instance.onError.remove(onOnlineError);
    FunkinUser.instance.onActiveUsersChanged.remove(refreshStatus);
    DiscordAuth.instance.onChanged.remove(refreshStatus);

    FunkinMultiplayer.instance.onRoomJoined.remove(onRoomReady);
    FunkinMultiplayer.instance.onRoomCreated.remove(onRoomReady);
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

    if (FlxG.keys.justPressed.L && !DiscordAuth.instance.isLoggedIn()) openLogin();

    refreshTimer += elapsed;

    if (refreshTimer >= 0.5)
    {
      refreshTimer = 0;
      refreshStatus();
      promptLoginIfNeeded();
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

    if (exitButton != null)
    {
      final selected:Bool = selectedIndex == 2;
      exitButton.color = selected ? 0xFFC0C0C0 : 0xFF8B8B8B;
      exitButton.scale.set(selected ? 1.9 : 1.8, selected ? 1.9 : 1.8);
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
    #if FEATURE_HAXEUI
    FlxG.switchState(() -> new OnlineLobbyState(false));
    #else
    if (FunkinOnline.instance.state == Disconnected)
    {
      FunkinOnline.instance.connect(OnlineConfig.host, OnlineConfig.port);
    }

    refreshStatus();
    #end
  }

  function onOnlineConnected():Void
  {
    refreshStatus();
    promptLoginIfNeeded();
  }

  function onOnlineDisconnected():Void
  {
    refreshStatus();
  }

  function onOnlineError(msg:String):Void
  {
    if (statusText != null) statusText.text = 'Error: ' + msg;
  }

  function onRoomReady(room:Dynamic):Void
  {
    if (statusText != null) statusText.text = 'Room ready. Waiting for an opponent...';
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
    #if FEATURE_HAXEUI
    FlxG.switchState(() -> new OnlineLobbyState(true));
    #else
    hostLocked = false;
    if (hostButton != null) hostButton.animation.play('idle', true);
    #end
  }

  override function destroy():Void
  {
    unregisterOnlineHandlers();

    if (MultiplayerInviteService.instance.onInviteReceived == onInviteReceived)
    {
      MultiplayerInviteService.instance.onInviteReceived = null;
    }
    super.destroy();
  }
  #end
}
