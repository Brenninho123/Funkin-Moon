package funkin.ui.multiplayer;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatSubState;
import funkin.multiplayer.MultiplayerAccountManager;
import funkin.multiplayer.RemoteImageLoader;

#if FEATURE_ONLINE
import funkin.api.discord.auth.DiscordAuthServer;
import funkin.api.discord.auth.DiscordAuthServer.DiscordProfile;
#end

/**
 * Card que aparece por cima da OnlineMenuState quando a conta ainda
 * não tem login do Discord vinculado.
 *
 * TEMPORARIAMENTE: o fluxo manual (abrir navegador, OAuth de verdade)
 * tá comentado lá embaixo (ver `startManualDiscordLogin`) — ele exigia
 * um DISCORD_CLIENT_ID de verdade configurado no DiscordAuthServer, que
 * ainda tá com o placeholder 'COLOQUE_SEU_CLIENT_ID_AQUI', então o
 * login de verdade nem tinha como funcionar ainda. Enquanto isso não
 * for configurado, essa tela faz um AUTO-LOGIN local: gera um perfil
 * "fake" a partir da conta local (mesmo username, avatar padrão do
 * Discord) e já vincula, sem precisar abrir navegador nenhum. Assim que
 * o client ID real existir, é só trocar `attemptAutoLogin()` por
 * `startManualDiscordLogin()` no create() lá embaixo.
 *
 * Mostra "Logado como X" + avatar se conseguir, ou "não foi possível
 * logar" se der erro. De qualquer jeito, fecha sozinho depois de 5
 * segundos. ESC ou ENTER fecham na hora, sem esperar o timer.
 */
class LoginSubState extends MusicBeatSubState
{
  #if FEATURE_ONLINE
  var account:Dynamic;
  var onLoggedIn:Null<(profile:DiscordProfile) -> Void>;
  var dim:Null<FunkinSprite> = null;
  var cardSprite:Null<FunkinSprite> = null;
  var titleText:Null<FlxText> = null;
  var statusText:Null<FlxText> = null;
  var avatarSprite:Null<FlxSprite> = null;
  // Fica null enquanto ainda não tentou o login; true = sucesso, false = falhou.
  var loginSucceeded:Null<Bool> = null;
  var closeTimer:Float = 0;

  static inline final AUTO_CLOSE_AFTER:Float = 5.0;

  // ---- Fluxo manual antigo (comentado, ver nota da classe) ----
  // var authServer:Null<DiscordAuthServer> = null;
  // var loginButton:Null<flixel.ui.FlxButton> = null;

  public function new(account:Dynamic, ?onLoggedIn:(profile:DiscordProfile) -> Void)
  {
    super();
    this.account = account;
    this.onLoggedIn = onLoggedIn;
  }

  override function create():Void
  {
    super.create();

    dim = new FunkinSprite(0, 0);
    dim.makeSolidColor(FlxG.width, FlxG.height, 0x99000000);
    add(dim);

    // ---- Card (FunkinSprite, só tem idle) ----
    cardSprite = new FunkinSprite(0, 0);
    cardSprite.frames = Paths.getSparrowAtlas('bgAttentionInternet');
    cardSprite.animation.addByPrefix('idle', 'bgAttentionIdle', 24, true);
    cardSprite.animation.play('idle');
    cardSprite.antialiasing = true;
    cardSprite.screenCenter();
    add(cardSprite);

    titleText = new FlxText(cardSprite.x, cardSprite.y + 24, cardSprite.width, 'ENTRANDO...', 20);
    titleText.setFormat(Paths.font('vcr.ttf'), 20, 0xFFFFFFFF, CENTER);
    add(titleText);

    avatarSprite = new FlxSprite(0, cardSprite.y + 60);
    avatarSprite.makeGraphic(64, 64, 0xFF4A4A4A);
    avatarSprite.x = cardSprite.x + (cardSprite.width - avatarSprite.width) / 2;
    avatarSprite.visible = false;
    add(avatarSprite);

    statusText = new FlxText(cardSprite.x, cardSprite.y + cardSprite.height - 70, cardSprite.width, 'Entrando automaticamente...', 16);
    statusText.setFormat(Paths.font('vcr.ttf'), 16, 0xFFB7C8FF, CENTER);
    add(statusText);

    // ---- Fluxo novo: auto-login local, sem navegador ----
    attemptAutoLogin();

    // ---- Fluxo manual antigo (Discord OAuth de verdade pelo navegador) ----
    // Descomenta isso (e comenta o attemptAutoLogin() acima) assim que
    // o DISCORD_CLIENT_ID real estiver configurado no DiscordAuthServer:
    //
    // loginButton = new flixel.ui.FlxButton(0, 0, 'LOGAR COM DISCORD', startManualDiscordLogin);
    // loginButton.color = 0xFF5865F2;
    // loginButton.label.color = 0xFFFFFFFF;
    // loginButton.scale.set(1.4, 1.4);
    // loginButton.updateHitbox();
    // loginButton.x = cardSprite.x + (cardSprite.width - loginButton.width) / 2;
    // loginButton.y = cardSprite.y + cardSprite.height - 110;
    // add(loginButton);
  }

  /**
   * Auto-login local: sem bater em nenhum servidor, sem abrir
   * navegador. Gera um "perfil" a partir da própria conta local
   * (username igual, avatar padrão do Discord) e já vincula. Serve pra
   * destravar o fluxo de teste enquanto o OAuth de verdade não tá
   * configurado — troca pra startManualDiscordLogin() quando tiver.
   */
  function attemptAutoLogin():Void
  {
    try
    {
      if (account == null) throw 'conta local inválida (null)';

      var username:String = Std.string(Reflect.field(account, 'username'));
      if (username == null || username.length == 0) throw 'conta sem username';

      var fakeId:String = 'local_' + Std.string(Reflect.field(account, 'id'));
      var fakeAvatarUrl:String = 'https://cdn.discordapp.com/embed/avatars/' + Std.string(Std.int(Math.random() * 5)) + '.png';

      var profile:DiscordProfile = {
        id: fakeId,
        username: username,
        discriminator: '0',
        avatarUrl: fakeAvatarUrl
      };

      MultiplayerAccountManager.linkDiscordAccount(account, profile);
      onAutoLoginResult(true, profile);
    }
    catch (e:Dynamic)
    {
      trace('[Login] auto-login falhou: ' + e);
      onAutoLoginResult(false, null);
    }
  }

  function onAutoLoginResult(success:Bool, ?profile:DiscordProfile):Void
  {
    loginSucceeded = success;
    closeTimer = 0;

    if (success && profile != null)
    {
      if (titleText != null) titleText.text = profile.username;
      if (statusText != null)
      {
        statusText.text = 'Logado! Fechando em alguns segundos...';
        statusText.color = 0xFFB7C8FF;
      }

      if (avatarSprite != null)
      {
        avatarSprite.visible = true;
        RemoteImageLoader.loadInto(avatarSprite, profile.avatarUrl, () ->
        {
          if (avatarSprite == null || cardSprite == null) return;
          avatarSprite.setGraphicSize(64, 64);
          avatarSprite.updateHitbox();
          avatarSprite.x = cardSprite.x + (cardSprite.width - avatarSprite.width) / 2;
        });
      }

      if (onLoggedIn != null) onLoggedIn(profile);
    }
    else
    {
      if (titleText != null) titleText.text = 'não foi possível logar';
      if (statusText != null)
      {
        statusText.text = 'Tenta de novo mais tarde. Fechando...';
        statusText.color = 0xFFE74C3C;
      }
    }
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    // ---- Teclado: ESC ou ENTER fecham na hora ----
    if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
    {
      close();
      return;
    }

    // ---- Fecha sozinho depois de 5s, contando só a partir do
    // resultado (sucesso ou falha) já estar na tela ----
    if (loginSucceeded != null)
    {
      closeTimer += elapsed;
      if (closeTimer >= AUTO_CLOSE_AFTER)
      {
        close();
      }
    }
  }

  // ---------------------------------------------------------------
  // Fluxo manual antigo (Discord OAuth de verdade). Comentado por
  // enquanto — ver nota no topo da classe. Preservado aqui pra quando
  // o DISCORD_CLIENT_ID real for configurado.
  // ---------------------------------------------------------------

  /*
    function startManualDiscordLogin():Void
    {
      if (statusText != null) statusText.text = 'Abrindo navegador pra login...';

      authServer = new DiscordAuthServer(8083);
      authServer.onLogin = onDiscordLogin;

      try
      {
        authServer.start();
        authServer.openLoginPage();
      }
      catch (e:Dynamic)
      {
        trace('[Login] falha ao abrir servidor de auth: ' + e);
        if (statusText != null) statusText.text = 'Falha ao abrir o navegador. Tenta de novo.';
      }
    }

    function onDiscordLogin(profile:DiscordProfile):Void
    {
      trace('[Login] logado como ' + profile.username);

      // Volta pra main thread antes de mexer em sprites/flixel.
      haxe.MainLoop.runInMainThread(() ->
      {
        MultiplayerAccountManager.linkDiscordAccount(account, profile);

        if (authServer != null)
        {
          authServer.stop();
          authServer = null;
        }

        onAutoLoginResult(true, profile);
      });
    }
   */
  override function destroy():Void
  {
    // if (authServer != null)
    // {
    //   authServer.stop();
    //   authServer = null;
    // }
    super.destroy();
  }
  #end
}
