package funkin.ui.multiplayer;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatSubState;
import funkin.multiplayer.MultiplayerAccountManager;
import funkin.multiplayer.RemoteImageLoader;
#if FEATURE_ONLINE
import funkin.online.DiscordAuth;
import funkin.online.DiscordAuth.DiscordUserProfile;
import funkin.online.FunkinOnline;
import funkin.online.OnlineConfig;
#end

class LoginSubState extends MusicBeatSubState
{
  #if FEATURE_ONLINE
  static inline final CLOSE_DELAY:Float = 2.0;

  var account:Dynamic;
  var onLoggedIn:Null<DiscordUserProfile->Void>;
  var dim:Null<FunkinSprite> = null;
  var cardSprite:Null<FunkinSprite> = null;
  var titleText:Null<FlxText> = null;
  var statusText:Null<FlxText> = null;
  var hintText:Null<FlxText> = null;
  var avatarSprite:Null<FlxSprite> = null;
  var loadedAvatarUrl:String = '';
  var loginReported:Bool = false;
  var closeTimer:Float = 0;

  public function new(account:Dynamic, ?onLoggedIn:DiscordUserProfile->Void)
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

    cardSprite = new FunkinSprite(0, 0);
    cardSprite.frames = Paths.getSparrowAtlas('bgAttentionInternet');
    cardSprite.animation.addByPrefix('idle', 'bgAttentionIdle', 24, true);
    cardSprite.animation.play('idle');
    cardSprite.antialiasing = true;
    cardSprite.screenCenter();
    add(cardSprite);

    titleText = new FlxText(cardSprite.x, cardSprite.y + 24, cardSprite.width, 'DISCORD LOGIN', 20);
    titleText.setFormat(Paths.font('vcr.ttf'), 20, 0xFFFFFFFF, CENTER);
    add(titleText);

    avatarSprite = new FlxSprite(0, cardSprite.y + 60);
    avatarSprite.makeGraphic(64, 64, 0xFF4A4A4A);
    avatarSprite.x = cardSprite.x + (cardSprite.width - avatarSprite.width) / 2;
    avatarSprite.visible = false;
    add(avatarSprite);

    statusText = new FlxText(cardSprite.x + 16, cardSprite.y + cardSprite.height - 110, cardSprite.width - 32, '', 16);
    statusText.setFormat(Paths.font('vcr.ttf'), 16, 0xFFB7C8FF, CENTER);
    add(statusText);

    hintText = new FlxText(cardSprite.x + 16, cardSprite.y + cardSprite.height - 60, cardSprite.width - 32, '', 14);
    hintText.setFormat(Paths.font('vcr.ttf'), 14, 0xFF8FA0CC, CENTER);
    add(hintText);

    DiscordAuth.instance.onChanged.add(updateView);
    FunkinOnline.instance.onConnected.add(updateView);
    FunkinOnline.instance.onDisconnected.add(updateView);

    if (FunkinOnline.instance.state == Disconnected) FunkinOnline.instance.connect(OnlineConfig.host, OnlineConfig.port);

    updateView();
  }

  function describeFailure(reason:String):String
  {
    return switch (reason)
    {
      case 'discord_not_configured': 'This server has Discord login turned off.';
      case 'access_denied': 'The login was cancelled in Discord.';
      case 'expired': 'The login link expired.';
      case 'token_exchange_failed' | 'profile_fetch_failed': 'Discord rejected the login. Try again.';
      case 'logged_in_elsewhere': 'This account logged in from another place.';
      case 'not_connected' | 'disconnected': 'Lost the connection to the server.';
      case 'already_authenticated': 'You are already logged in.';
      default: 'Could not log in ($reason).';
    };
  }

  function updateView():Void
  {
    if (statusText == null || hintText == null || titleText == null) return;

    var auth:DiscordAuth = DiscordAuth.instance;
    var connected:Bool = FunkinOnline.instance.isConnected();

    switch (auth.state)
    {
      case LoggedIn:
        titleText.text = auth.profile.username;
        statusText.text = 'Logged in with Discord.';
        statusText.color = 0xFF7CF6CF;
        hintText.text = 'Closing...';
        showLoggedIn(auth.profile);
      case Requesting:
        titleText.text = 'DISCORD LOGIN';
        statusText.text = 'Contacting the server...';
        statusText.color = 0xFFB7C8FF;
        hintText.text = 'ESC to cancel';
      case WaitingForBrowser:
        titleText.text = 'DISCORD LOGIN';
        statusText.text = 'Finish logging in with Discord in your browser.';
        statusText.color = 0xFFB7C8FF;
        hintText.text = 'ESC to cancel';
      case Failed:
        titleText.text = 'DISCORD LOGIN';
        statusText.text = describeFailure(auth.failureReason);
        statusText.color = 0xFFE74C3C;
        hintText.text = 'ENTER to try again, ESC to close';
      case LoggedOut:
        titleText.text = 'DISCORD LOGIN';

        if (!connected)
        {
          statusText.text = 'Not connected to ${OnlineConfig.describe()}.';
          statusText.color = 0xFFE74C3C;
          hintText.text = 'ENTER to reconnect, ESC to close';
        }
        else if (!auth.discordEnabled)
        {
          statusText.text = 'This server has Discord login turned off.';
          statusText.color = 0xFFE74C3C;
          hintText.text = 'ESC to close';
        }
        else
        {
          statusText.text = 'Log in with Discord to play online.';
          statusText.color = 0xFFB7C8FF;
          hintText.text = 'ENTER to open Discord in your browser, ESC to skip';
        }
    }
  }

  function showLoggedIn(profile:DiscordUserProfile):Void
  {
    if (avatarSprite != null && cardSprite != null && profile.avatarUrl != '' && profile.avatarUrl != loadedAvatarUrl)
    {
      loadedAvatarUrl = profile.avatarUrl;
      avatarSprite.visible = true;

      RemoteImageLoader.loadInto(avatarSprite, profile.avatarUrl, () ->
      {
        if (avatarSprite == null || cardSprite == null) return;

        avatarSprite.setGraphicSize(64, 64);
        avatarSprite.updateHitbox();
        avatarSprite.x = cardSprite.x + (cardSprite.width - avatarSprite.width) / 2;
      });
    }

    if (loginReported) return;

    loginReported = true;
    closeTimer = 0;

    MultiplayerAccountManager.linkDiscordAccount(account, profile);

    if (onLoggedIn != null) onLoggedIn(profile);
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    var auth:DiscordAuth = DiscordAuth.instance;

    if (FlxG.keys.justPressed.ESCAPE)
    {
      if (auth.isBusy()) auth.cancelLogin();

      close();
      return;
    }

    if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
    {
      if (auth.isLoggedIn())
      {
        close();
        return;
      }

      if (!FunkinOnline.instance.isConnected())
      {
        if (FunkinOnline.instance.state == Disconnected) FunkinOnline.instance.connect(OnlineConfig.host, OnlineConfig.port);
      }
      else if (auth.discordEnabled)
      {
        auth.beginLogin();
      }
    }

    if (auth.isLoggedIn())
    {
      closeTimer += elapsed;

      if (closeTimer >= CLOSE_DELAY) close();
    }
  }

  override function destroy():Void
  {
    DiscordAuth.instance.onChanged.remove(updateView);
    FunkinOnline.instance.onConnected.remove(updateView);
    FunkinOnline.instance.onDisconnected.remove(updateView);

    super.destroy();
  }
  #end
}
