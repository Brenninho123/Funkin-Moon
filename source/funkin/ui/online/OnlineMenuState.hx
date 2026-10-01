package funkin.ui.online;

#if FEATURE_ONLINE
import flixel.FlxSprite;
import funkin.graphics.FunkinCamera;
import funkin.input.Cursor;
import funkin.multiplayer.RemoteImageLoader;
import funkin.online.DiscordAuth;
import funkin.online.FunkinOnline;
import funkin.online.FunkinUser;
import funkin.online.OnlineConfig;
import funkin.online.OnlineText;
import funkin.online.OnlineText.DiscordPanel;
import funkin.online.play.FunkinMultiplayer;
import funkin.online.play.MultiplayerData;
import funkin.online.play.MultiplayerData.MultiplayerStats;
import funkin.ui.mainmenu.MainMenuState;
import haxe.ui.backend.flixel.UIState;
import haxe.ui.containers.windows.WindowManager;
import haxe.ui.core.Screen;
import haxe.ui.events.MouseEvent;
import haxe.ui.focus.FocusManager;
import haxe.ui.notifications.NotificationManager;
import haxe.ui.notifications.NotificationType;
import lime.system.Clipboard;

@:build(haxe.ui.ComponentBuilder.build('assets/exclude/ui/online/menu-view.xml'))
class OnlineMenuState extends UIState
{
  static final AVATAR_SIZE:Int = 96;

  var camTop:FunkinCamera;
  var avatarSprite:FlxSprite;
  var loadedAvatarUrl:String = '';
  var panel:DiscordPanel;
  var refreshTimer:Float = 0;
  var lastPlayers:String = '';
  var statsText:String = '';
  var statsFor:String = '';

  override function create():Void
  {
    WindowManager.instance.reset();

    camTop = new FunkinCamera('onlineMenuTop');
    camTop.bgColor.alpha = 0;
    FlxG.cameras.add(camTop, false);

    super.create();

    root.scrollFactor.set();
    root.width = FlxG.width;
    root.height = FlxG.height;

    WindowManager.instance.container = root;
    Screen.instance.addComponent(root);

    FlxG.mouse.visible = true;
    Cursor.show();

    avatarSprite = new FlxSprite();
    avatarSprite.makeGraphic(AVATAR_SIZE, AVATAR_SIZE, 0xFF2C3A52);
    avatarSprite.cameras = [camTop];
    avatarSprite.scrollFactor.set(0, 0);
    avatarSprite.visible = false;
    add(avatarSprite);

    FunkinUser.instance.setActivity('In the online menu');

    DiscordAuth.instance.init();
    FunkinMultiplayer.instance.init();

    FunkinMultiplayer.instance.onStats.add(onStatsReceived);
    FunkinOnline.instance.onNotice.add(onNoticeReceived);
    FunkinOnline.instance.onConnected.add(refreshView);
    FunkinOnline.instance.onDisconnected.add(refreshView);
    FunkinOnline.instance.onError.add(onSocketError);
    FunkinUser.instance.onActiveUsersChanged.add(refreshView);
    DiscordAuth.instance.onChanged.add(refreshView);

    serverHost.text = OnlineConfig.host;
    serverPort.text = Std.string(OnlineConfig.port);

    if (FunkinOnline.instance.state == Disconnected) FunkinOnline.instance.connect(OnlineConfig.host, OnlineConfig.port);

    refreshView();

    haxe.ui.Toolkit.callLater(() ->
    {
      var focused = FocusManager.instance.focus;

      if (focused != null) focused.focus = false;
    });
  }

  function toast(message:String, type:NotificationType = NotificationType.Info):Void
  {
    NotificationManager.instance.addNotification({
      title: switch (type)
      {
        case NotificationType.Success: 'Done';
        case NotificationType.Warning: 'Careful';
        case NotificationType.Error: 'Error';
        default: 'Online';
      },
      body: message,
      type: type,
      expiryMs: Constants.NOTIFICATION_DISMISS_TIME
    });
  }

  function onStatsReceived(stats:MultiplayerStats):Void
  {
    statsText = MultiplayerData.describeStats(stats);

    refreshView();
  }

  function onNoticeReceived(text:String, kind:String):Void
  {
    if (text != '') toast(text, kind == 'announcement' ? NotificationType.Info : NotificationType.Warning);
  }

  function refreshStats():Void
  {
    var online:FunkinOnline = FunkinOnline.instance;
    var localId:String = FunkinUser.instance.getLocalUserId();

    if (!online.isConnected())
    {
      statsFor = '';
      statsText = '';
      profileStats.text = 'Connect to a server to see your record.';
      return;
    }

    if (statsFor != localId)
    {
      statsFor = localId;
      statsText = '';
      FunkinMultiplayer.instance.requestStats();
    }

    profileStats.text = statsText != '' ? statsText : 'Loading...';
  }

  function onSocketError(message:String):Void
  {
    serverStatus.text = 'Error: ' + message;
    tint(serverStatus, 0xFFFF6B6B);
  }

  function colorFor(kind:String):Int
  {
    return switch (kind)
    {
      case OnlineText.KIND_OK: 0xFF7CF6CF;
      case OnlineText.KIND_ERROR: 0xFFFF6B6B;
      default: 0xFFB7C8FF;
    };
  }

  function tint(label:haxe.ui.components.Label, color:Int):Void
  {
    label.customStyle.color = color;
    label.invalidateComponentStyle();
  }

  function refreshView():Void
  {
    if (root == null) return;

    var online:FunkinOnline = FunkinOnline.instance;
    var auth:DiscordAuth = DiscordAuth.instance;
    var user = FunkinUser.instance;
    var loggedIn:Bool = auth.isLoggedIn();
    var username:String = loggedIn ? auth.profile.username : (user.localUser?.username ?? 'Guest');
    var users = user.getActiveUsers();

    users.sort((a, b) -> a.username.toLowerCase() < b.username.toLowerCase() ? -1 : (a.username.toLowerCase() > b.username.toLowerCase() ? 1 : 0));

    var serverNameText:String = auth.serverName;

    headline.text = serverNameText != '' ? 'Playing on ' + serverNameText : 'Play with friends on a Moon Engine server.';

    profileName.text = username;
    profileKind.text = loggedIn ? 'Discord account' : 'Guest';

    panel = OnlineText.discordPanel(Std.string(auth.state), online.isConnected(), auth.discordEnabled, username, auth.failureReason, auth.loginUrl != '');

    discordStatus.text = panel.status;
    tint(discordStatus, colorFor(panel.kind));
    discordHint.text = panel.hint;
    discordAction.text = panel.actionLabel;
    discordAction.hidden = panel.action == OnlineText.ACTION_NONE;
    discordCopy.hidden = !panel.canCopyLink;
    discordReopen.hidden = !panel.canCopyLink;

    serverName.text = serverNameText != '' ? serverNameText : 'Moon Engine server';
    serverMotd.text = online.isConnected() ? auth.serverMotd : '';
    serverStatus.text = OnlineText.connection(Std.string(online.state), OnlineConfig.describe(), users.length);
    tint(serverStatus, online.isConnected() ? 0xFF7CF6CF : 0xFFFF9F6B);
    serverConnect.text = online.isConnected() ? 'Reconnect' : 'Connect';

    refreshStats();

    actionHint.text = online.isConnected() ? '' : 'Connect to a server to play online. Start one with server/build/moon-server.exe.';

    var signature:String = [for (entry in users) entry.id + entry.username + entry.activity + (entry.authenticated == true ? '1' : '0')].join('|');

    if (signature != lastPlayers)
    {
      lastPlayers = signature;

      playerList.dataSource.clear();

      for (entry in users)
      {
        playerList.dataSource.add({
          title: OnlineText.playerLine(entry.username, entry.authenticated == true, entry.id == user.getLocalUserId()),
          subtitle: entry.activity
        });
      }
    }

    playersTitle.text = 'PLAYERS ONLINE (' + users.length + ')';

    showAvatar(loggedIn ? auth.profile.avatarUrl : '');
  }

  function showAvatar(url:String):Void
  {
    if (url == loadedAvatarUrl) return;

    loadedAvatarUrl = url;

    if (url == '')
    {
      avatarSprite.makeGraphic(AVATAR_SIZE, AVATAR_SIZE, 0xFF2C3A52);
      return;
    }

    RemoteImageLoader.loadInto(avatarSprite, url, () ->
    {
      if (avatarSprite == null) return;

      avatarSprite.setGraphicSize(AVATAR_SIZE, AVATAR_SIZE);
      avatarSprite.updateHitbox();
    });
  }

  function overlayOpen():Bool
  {
    for (component in Screen.instance.rootComponents)
    {
      if (component == root) continue;

      var name:String = Type.getClassName(Type.getClass(component));

      if (name.indexOf('Notification') >= 0 || name.indexOf('ToolTip') >= 0) continue;

      return true;
    }

    return false;
  }

  function isTyping():Bool
  {
    var focused = FocusManager.instance.focus;

    return focused != null && Std.isOfType(focused, haxe.ui.components.TextField);
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (avatarSlot.width > 0)
    {
      avatarSprite.setPosition(avatarSlot.screenLeft + 1, avatarSlot.screenTop + 1);
      avatarSprite.visible = !overlayOpen();
    }

    refreshTimer += elapsed;

    if (refreshTimer >= 1.0)
    {
      refreshTimer = 0;
      refreshView();
    }

    if (FlxG.keys.justPressed.ESCAPE)
    {
      if (isTyping()) FocusManager.instance.focus.focus = false;
      else
        goBack();
    }

    if (FlxG.keys.justPressed.ENTER && FocusManager.instance.focus != null)
    {
      var focused = FocusManager.instance.focus;

      if (focused == serverHost || focused == serverPort) applyServerAddress();
    }
  }

  function goBack():Void
  {
    FlxG.switchState(() -> new MainMenuState());
  }

  function applyServerAddress():Void
  {
    var port:Null<Int> = Std.parseInt(StringTools.trim(serverPort.text));

    if (port == null || !OnlineConfig.set(serverHost.text, port))
    {
      toast('Type a server address and a port between 1 and 65535.', NotificationType.Error);
      return;
    }

    FunkinOnline.instance.disconnect();
    FunkinOnline.instance.connect(OnlineConfig.host, OnlineConfig.port);

    refreshView();
    toast('Connecting to ' + OnlineConfig.describe() + '...');
  }

  function connectNow():Void
  {
    if (FunkinOnline.instance.state == Disconnected) FunkinOnline.instance.connect(OnlineConfig.host, OnlineConfig.port);

    refreshView();
  }

  @:bind(menuBack, MouseEvent.CLICK)
  function onMenuBackClick(_):Void
  {
    goBack();
  }

  @:bind(serverConnect, MouseEvent.CLICK)
  function onServerConnectClick(_):Void
  {
    applyServerAddress();
  }

  @:bind(discordAction, MouseEvent.CLICK)
  function onDiscordActionClick(_):Void
  {
    var auth:DiscordAuth = DiscordAuth.instance;

    switch (panel.action)
    {
      case OnlineText.ACTION_LOGIN:
        auth.beginLogin();
      case OnlineText.ACTION_CANCEL:
        auth.cancelLogin();
      case OnlineText.ACTION_LOGOUT:
        auth.logout();
        toast('You logged out of Discord.', NotificationType.Success);
      case OnlineText.ACTION_CONNECT:
        connectNow();
      default:
    }
  }

  @:bind(discordCopy, MouseEvent.CLICK)
  function onDiscordCopyClick(_):Void
  {
    if (DiscordAuth.instance.loginUrl == '') return;

    Clipboard.text = DiscordAuth.instance.loginUrl;

    toast('The login link is on the clipboard. Paste it in your browser.', NotificationType.Success);
  }

  @:bind(discordReopen, MouseEvent.CLICK)
  function onDiscordReopenClick(_):Void
  {
    DiscordAuth.instance.reopenLoginPage();
  }

  @:bind(actionQuick, MouseEvent.CLICK)
  function onActionQuickClick(_):Void
  {
    FlxG.switchState(() -> new OnlineLobbyState(false, false, true));
  }

  @:bind(actionHost, MouseEvent.CLICK)
  function onActionHostClick(_):Void
  {
    FlxG.switchState(() -> new OnlineLobbyState(true));
  }

  @:bind(actionBrowse, MouseEvent.CLICK)
  function onActionBrowseClick(_):Void
  {
    FlxG.switchState(() -> new OnlineLobbyState(false));
  }

  @:bind(actionBoard, MouseEvent.CLICK)
  function onActionBoardClick(_):Void
  {
    FlxG.switchState(() -> new OnlineLobbyState(false, true));
  }

  override function destroy():Void
  {
    FunkinMultiplayer.instance.onStats.remove(onStatsReceived);
    FunkinOnline.instance.onNotice.remove(onNoticeReceived);
    FunkinOnline.instance.onConnected.remove(refreshView);
    FunkinOnline.instance.onDisconnected.remove(refreshView);
    FunkinOnline.instance.onError.remove(onSocketError);
    FunkinUser.instance.onActiveUsersChanged.remove(refreshView);
    DiscordAuth.instance.onChanged.remove(refreshView);

    NotificationManager.instance.clearNotifications();

    if (camTop != null) FlxG.cameras.remove(camTop);

    super.destroy();
  }
}
#end
