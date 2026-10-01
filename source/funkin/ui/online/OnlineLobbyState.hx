package funkin.ui.online;

#if (FEATURE_ONLINE && FEATURE_HAXEUI)
import funkin.audio.FunkinSound;
import funkin.data.song.SongRegistry;
import funkin.input.Cursor;
import funkin.online.DiscordAuth;
import funkin.online.FunkinOnline;
import funkin.online.FunkinUser;
import funkin.online.OnlineConfig;
import funkin.online.play.FunkinMultiplayer;
import funkin.online.play.MultiplayerData;
import funkin.online.play.MultiplayerData.MultiplayerChatMessage;
import funkin.online.play.MultiplayerData.MultiplayerLeaderboardEntry;
import funkin.online.play.MultiplayerData.MultiplayerMember;
import funkin.online.play.MultiplayerData.MultiplayerResults;
import funkin.online.play.MultiplayerData.MultiplayerRoom;
import funkin.online.play.MultiplayerData.MultiplayerRoomSummary;
import funkin.play.PlayState;
import funkin.play.song.Song;
import funkin.ui.transition.LoadingState;
import haxe.ui.backend.flixel.UIState;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.containers.dialogs.MessageBox.MessageBoxType;
import haxe.ui.containers.windows.WindowManager;
import haxe.ui.core.Screen;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import haxe.ui.focus.FocusManager;
import haxe.ui.notifications.NotificationManager;
import haxe.ui.notifications.NotificationType;
import lime.system.Clipboard;

@:build(haxe.ui.ComponentBuilder.build('assets/exclude/ui/online/lobby-view.xml'))
class OnlineLobbyState extends UIState
{
  static final DIFFICULTIES:Array<String> = ['easy', 'normal', 'hard'];
  static final MAX_CHAT_LINES:Int = 80;

  var autoCreate:Bool;
  var boardWanted:Bool;
  var syncing:Bool = true;
  var songIds:Array<String> = [];
  var summaries:Array<MultiplayerRoomSummary> = [];
  var selectedRoomId:String = '';
  var selectedMemberId:String = '';
  var chatLines:Array<String> = [];
  var statusTimer:Float = 0;
  var starting:Bool = false;
  var multiplayer:FunkinMultiplayer;

  public function new(autoCreate:Bool = false, openLeaderboard:Bool = false)
  {
    super();

    this.autoCreate = autoCreate;
    this.boardWanted = openLeaderboard;
    this.multiplayer = FunkinMultiplayer.instance;
  }

  override function create():Void
  {
    WindowManager.instance.reset();

    super.create();

    root.scrollFactor.set();
    root.width = FlxG.width;
    root.height = FlxG.height;

    WindowManager.instance.container = root;
    Screen.instance.addComponent(root);

    FlxG.mouse.visible = true;
    Cursor.show();

    multiplayer.init();
    registerSignals();

    songIds = SongRegistry.instance.listEntryIds();
    songIds.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));

    populateSongs();

    serverHost.text = OnlineConfig.host;
    serverPort.text = Std.string(OnlineConfig.port);

    syncing = false;

    FunkinUser.instance.setActivity('In an online lobby');

    if (FlxG.sound.music == null || !FlxG.sound.music.playing)
    {
      FunkinSound.playMusic('ui/main-menu/freaky-menu/freaky-menu', {
        startingVolume: 0.0,
        overrideExisting: true,
        restartTrack: false,
        persist: true
      });

      FlxG.sound.music?.fadeIn(2.0, 0.0, 0.7);
    }

    ensureConnected();

    if (multiplayer.currentRoom != null)
    {
      showLobby();
    }
    else
    {
      showBrowser();
      refreshRooms();

      if (autoCreate) createRoomNow();
    }

    if (boardWanted && multiplayer.currentRoom == null)
    {
      browserTabs.pageIndex = 1;
      refreshBoard();
    }

    var pending:Null<MultiplayerResults> = multiplayer.takeResults();

    if (pending != null) announceResults(pending);

    refreshServerStatus();

    haxe.ui.Toolkit.callLater(() ->
    {
      var focused = FocusManager.instance.focus;

      if (focused != null) focused.focus = false;
    });
  }

  function registerSignals():Void
  {
    FunkinOnline.instance.onConnected.add(onConnectedSignal);
    FunkinOnline.instance.onDisconnected.add(onDisconnectedSignal);
    FunkinOnline.instance.onError.add(onSocketError);
    FunkinUser.instance.onActiveUsersChanged.add(refreshServerStatus);
    DiscordAuth.instance.onChanged.add(refreshServerStatus);

    multiplayer.onRoomCreated.add(onRoomEntered);
    multiplayer.onRoomJoined.add(onRoomEntered);
    multiplayer.onRoomJoinFailed.add(onJoinFailed);
    multiplayer.onRoomClosed.add(onRoomClosedSignal);
    multiplayer.onRoomUpdated.add(refreshLobby);
    multiplayer.onPlayerJoined.add(onPlayerJoinedSignal);
    multiplayer.onPlayerLeft.add(onPlayerLeftSignal);
    multiplayer.onHostChanged.add(onHostChangedSignal);
    multiplayer.onSongStart.add(onSongStartSignal);
    multiplayer.onResults.add(announceResults);
    multiplayer.onChat.add(onChatSignal);
    multiplayer.onRoomsListed.add(onRoomsListedSignal);
    multiplayer.onLeaderboard.add(onLeaderboardSignal);
    multiplayer.onError.add(onErrorSignal);
  }

  function unregisterSignals():Void
  {
    FunkinOnline.instance.onConnected.remove(onConnectedSignal);
    FunkinOnline.instance.onDisconnected.remove(onDisconnectedSignal);
    FunkinOnline.instance.onError.remove(onSocketError);
    FunkinUser.instance.onActiveUsersChanged.remove(refreshServerStatus);
    DiscordAuth.instance.onChanged.remove(refreshServerStatus);

    multiplayer.onRoomCreated.remove(onRoomEntered);
    multiplayer.onRoomJoined.remove(onRoomEntered);
    multiplayer.onRoomJoinFailed.remove(onJoinFailed);
    multiplayer.onRoomClosed.remove(onRoomClosedSignal);
    multiplayer.onRoomUpdated.remove(refreshLobby);
    multiplayer.onPlayerJoined.remove(onPlayerJoinedSignal);
    multiplayer.onPlayerLeft.remove(onPlayerLeftSignal);
    multiplayer.onHostChanged.remove(onHostChangedSignal);
    multiplayer.onSongStart.remove(onSongStartSignal);
    multiplayer.onResults.remove(announceResults);
    multiplayer.onChat.remove(onChatSignal);
    multiplayer.onRoomsListed.remove(onRoomsListedSignal);
    multiplayer.onLeaderboard.remove(onLeaderboardSignal);
    multiplayer.onError.remove(onErrorSignal);
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

  function isTyping():Bool
  {
    var focused = FocusManager.instance.focus;

    return focused != null && (Std.isOfType(focused, haxe.ui.components.TextField) || Std.isOfType(focused, haxe.ui.components.NumberStepper));
  }

  // ===============
  // Connection
  // ===============

  function ensureConnected():Void
  {
    if (FunkinOnline.instance.state == Disconnected) FunkinOnline.instance.connect(OnlineConfig.host, OnlineConfig.port);
  }

  function applyServerAddress():Void
  {
    var port:Null<Int> = Std.parseInt(StringTools.trim(serverPort.text));

    if (port == null || !OnlineConfig.set(serverHost.text, port))
    {
      toast('Type a server address and a port between 1 and 65535.', NotificationType.Error);
      return;
    }

    if (multiplayer.currentRoom != null) multiplayer.leaveRoom();

    FunkinOnline.instance.disconnect();
    FunkinOnline.instance.connect(OnlineConfig.host, OnlineConfig.port);

    showBrowser();
    refreshServerStatus();
    toast('Connecting to ' + OnlineConfig.describe() + '...');
  }

  function refreshServerStatus():Void
  {
    var online:FunkinOnline = FunkinOnline.instance;
    var count:Int = FunkinUser.instance.getActiveUserCount();
    var auth:DiscordAuth = DiscordAuth.instance;
    var account:String = auth.isLoggedIn() ? '   Discord: ' + auth.profile.username : '';

    serverStatus.text = switch (online.state)
    {
      case Connected: 'Connected to ' + OnlineConfig.describe() + '   ' + count + ' player' + (count == 1 ? '' : 's') + ' online' + account;
      case Connecting: 'Connecting to ' + OnlineConfig.describe() + '...';
      case Reconnecting: 'The server is not answering, trying again...';
      case Disconnected: 'Not connected';
    };

    serverConnect.text = online.isConnected() ? 'Reconnect' : 'Connect';
  }

  function onConnectedSignal():Void
  {
    refreshServerStatus();

    if (boardWanted) refreshBoard();

    if (multiplayer.currentRoom == null)
    {
      refreshRooms();

      if (autoCreate && !starting)
      {
        autoCreate = false;
        createRoomNow();
      }
    }
  }

  function onDisconnectedSignal():Void
  {
    refreshServerStatus();
  }

  function onSocketError(message:String):Void
  {
    serverStatus.text = 'Error: ' + message;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    statusTimer += elapsed;

    if (statusTimer >= 1.0)
    {
      statusTimer = 0;
      refreshServerStatus();
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

      if (focused == chatInput) sendChatNow();
      else if (focused == joinCode) joinByCode();
      else if (focused == serverHost || focused == serverPort) applyServerAddress();
    }
  }

  function goBack():Void
  {
    if (multiplayer.currentRoom != null)
    {
      multiplayer.leaveRoom();
      showBrowser();
      refreshRooms();
      return;
    }

    FlxG.switchState(() -> new OnlineMenuState());
  }

  // ===============
  // Browser
  // ===============

  function showBrowser():Void
  {
    browserPanel.hidden = false;
    lobbyPanel.hidden = true;
    starting = false;
    selectedRoomId = '';
    joinSelected.disabled = true;

    FunkinUser.instance.setActivity('In an online lobby');
  }

  function refreshRooms():Void
  {
    if (FunkinOnline.instance.isConnected()) multiplayer.listRooms();
  }

  function onRoomsListedSignal(list:Array<MultiplayerRoomSummary>):Void
  {
    if (starting) return;

    summaries = list;

    var previous:Bool = syncing;

    syncing = true;

    roomList.dataSource.clear();

    for (room in summaries)
    {
      var song:String = room.songId != '' ? room.songId + ' (' + room.difficultyId + ')' : 'no song yet';

      roomList.dataSource.add({
        title: room.name,
        subtitle: 'by ' + room.hostName + '   ' + room.players + '/' + room.maxPlayers + '   ' + song,
        tag: room.state == MultiplayerData.STATE_PLAYING ? 'playing' : 'open',
        id: room.roomId
      });
    }

    syncing = previous;

    roomsEmpty.text = summaries.length == 0 ? 'No public rooms yet. Host one, or join a friend with a code.' : '';
  }

  function onRoomEntered(room:MultiplayerRoom):Void
  {
    showLobby();
  }

  function onJoinFailed(reason:String):Void
  {
    browserHint.text = MultiplayerData.describeError(reason);
    toast(MultiplayerData.describeError(reason), NotificationType.Warning);
  }

  function createRoomNow():Void
  {
    if (!FunkinOnline.instance.isConnected())
    {
      browserHint.text = 'Wait for the connection, then create the room.';
      return;
    }

    multiplayer.createRoom(createName.text, createPublic.selected, Std.int(createMax.pos));
  }

  function joinByCode():Void
  {
    var code:String = MultiplayerData.normalizeCode(joinCode.text);

    if (code == '')
    {
      browserHint.text = 'Type the room code first.';
      return;
    }

    browserHint.text = '';
    multiplayer.joinRoom(code);
  }

  // ===============
  // Lobby
  // ===============

  function showLobby():Void
  {
    browserPanel.hidden = true;
    lobbyPanel.hidden = false;
    starting = false;

    chatLines = [];

    for (message in multiplayer.chatLog) chatLines.push(formatChat(message));

    renderChat();
    refreshLobby();

    FunkinUser.instance.setActivity('In a room');
  }

  function songKnown(songId:Null<String>):Bool
  {
    return songId != null && SongRegistry.instance.fetchEntry(songId) != null;
  }

  function populateSongs():Void
  {
    var previous:Bool = syncing;

    syncing = true;

    songPicker.dataSource.clear();
    boardSong.dataSource.clear();

    songPicker.dataSource.add({text: 'Pick a song'});

    for (id in songIds)
    {
      songPicker.dataSource.add({text: id});
      boardSong.dataSource.add({text: id});
    }

    difficultyPicker.dataSource.clear();
    boardDifficulty.dataSource.clear();

    for (difficulty in DIFFICULTIES)
    {
      difficultyPicker.dataSource.add({text: difficulty});
      boardDifficulty.dataSource.add({text: difficulty});
    }

    boardDifficulty.selectedIndex = 1;

    if (songIds.length > 0) boardSong.selectedIndex = 0;

    syncing = previous;
  }

  function fillDifficulties(songId:Null<String>, current:Null<String>):Void
  {
    var options:Array<String> = DIFFICULTIES;

    if (songId != null)
    {
      var song:Null<Song> = SongRegistry.instance.fetchEntry(songId);

      if (song != null)
      {
        var listed:Array<String> = song.listDifficulties(Constants.DEFAULT_VARIATION);

        if (listed.length > 0) options = listed;
      }
    }

    difficultyPicker.dataSource.clear();

    for (difficulty in options) difficultyPicker.dataSource.add({text: difficulty});

    var index:Int = current != null ? options.indexOf(current) : -1;

    difficultyPicker.selectedIndex = index >= 0 ? index : Std.int(Math.max(0, options.indexOf('normal')));
  }

  function memberStatus(room:MultiplayerRoom, member:MultiplayerMember):String
  {
    if (room.state == MultiplayerData.STATE_PLAYING) return member.finished ? 'finished ' + MultiplayerData.formatScore(member.score) : 'playing';

    if (member.id == room.hostId) return 'host';

    return member.ready ? 'ready' : 'waiting';
  }

  function refreshLobby():Void
  {
    var room:Null<MultiplayerRoom> = multiplayer.currentRoom;

    if (starting || room == null || lobbyPanel.hidden) return;

    var previous:Bool = syncing;

    syncing = true;

    var localId:String = FunkinUser.instance.getLocalUserId();
    var host:Bool = multiplayer.isHost;
    var me:Null<MultiplayerMember> = MultiplayerData.memberById(room, localId);

    roomTitle.text = room.name + (room.isPublic ? '' : '  (private)');
    roomCode.text = MultiplayerData.formatCode(room.roomId);

    memberList.dataSource.clear();

    var selectedIndex:Int = -1;

    for (i in 0...room.members.length)
    {
      var member:MultiplayerMember = room.members[i];

      memberList.dataSource.add({
        title: (member.id == room.hostId ? '* ' : '') + member.username + (member.id == localId ? ' (you)' : ''),
        subtitle: memberStatus(room, member),
        id: member.id
      });

      if (member.id == selectedMemberId) selectedIndex = i;
    }

    if (selectedIndex >= 0) memberList.selectedIndex = selectedIndex;
    else
      selectedMemberId = '';

    memberKick.disabled = !host || selectedMemberId == '' || selectedMemberId == localId || room.state != MultiplayerData.STATE_LOBBY;

    var songIndex:Int = room.songId != null ? songIds.indexOf(room.songId) : -1;

    songPicker.selectedIndex = songIndex + 1;
    fillDifficulties(room.songId, room.difficultyId);

    songPicker.disabled = !host || room.state != MultiplayerData.STATE_LOBBY;
    difficultyPicker.disabled = songPicker.disabled;

    if (room.songId == null) songInfo.text = host ? 'Pick a song for the room.' : 'Waiting for the host to pick a song.';
    else if (!songKnown(room.songId)) songInfo.text = 'You do not have the song "' + room.songId + '", so you cannot play this round.';
    else
      songInfo.text = '';

    settingPublic.disabled = !host || room.state != MultiplayerData.STATE_LOBBY;
    settingMax.disabled = settingPublic.disabled;
    settingPublic.selected = room.isPublic;
    settingMax.pos = room.maxPlayers;

    var ready:Bool = me != null && me.ready;

    readyToggle.text = ready ? 'Not ready' : 'Ready';
    readyToggle.disabled = room.state != MultiplayerData.STATE_LOBBY || room.songId == null || !songKnown(room.songId) || host;
    readyToggle.hidden = host;

    startMatch.hidden = !host;
    startMatch.disabled = room.state != MultiplayerData.STATE_LOBBY || room.songId == null || !songKnown(room.songId) || room.members.length < 2
      || !MultiplayerData.everyoneReady(room);

    lobbyStatus.text = describeLobby(room, host);

    syncing = previous;
  }

  function describeLobby(room:MultiplayerRoom, host:Bool):String
  {
    if (room.state == MultiplayerData.STATE_PLAYING) return 'A round is in progress.';
    if (room.songId == null) return host ? 'Pick a song to begin.' : 'The host is choosing a song.';
    if (room.members.length < 2) return 'Waiting for more players. Share the code ' + MultiplayerData.formatCode(room.roomId) + '.';

    var waiting:Array<String> = [for (member in room.members) if (member.id != room.hostId && !member.ready) member.username];

    if (waiting.length > 0) return 'Waiting for ' + waiting.join(', ') + ' to get ready.';

    return host ? 'Everyone is ready. Start when you are.' : 'Waiting for the host to start.';
  }

  function onPlayerJoinedSignal(userId:String):Void
  {
    var room:Null<MultiplayerRoom> = multiplayer.currentRoom;

    appendSystem(MultiplayerData.nameOf(room, userId) + ' joined the room.');
  }

  function onPlayerLeftSignal(userId:String):Void
  {
    appendSystem('A player left the room.');
  }

  function onHostChangedSignal(hostId:String):Void
  {
    appendSystem(MultiplayerData.nameOf(multiplayer.currentRoom, hostId) + ' is the host now.');
  }

  function onRoomClosedSignal():Void
  {
    toast(MultiplayerData.describeError(multiplayer.lastCloseReason), NotificationType.Warning);

    showBrowser();
    refreshRooms();
  }

  function onErrorSignal(reason:String):Void
  {
    toast(MultiplayerData.describeError(reason), NotificationType.Warning);
  }

  // ===============
  // Chat
  // ===============

  function formatChat(message:MultiplayerChatMessage):String
  {
    return (message.scope == 'global' ? '[all] ' : '') + message.username + ': ' + message.text;
  }

  function renderChat():Void
  {
    while (chatLines.length > MAX_CHAT_LINES) chatLines.shift();

    chatLog.text = chatLines.join('\n');

    haxe.ui.Toolkit.callLater(() ->
    {
      chatScroll.vscrollPos = chatScroll.vscrollMax;
    });
  }

  function appendSystem(text:String):Void
  {
    chatLines.push('-- ' + text);
    renderChat();
  }

  function onChatSignal(message:MultiplayerChatMessage):Void
  {
    chatLines.push(formatChat(message));
    renderChat();
  }

  function sendChatNow():Void
  {
    var text:String = chatInput.text != null ? StringTools.trim(chatInput.text) : '';

    if (text == '') return;

    multiplayer.sendChat(text, false);

    chatInput.text = '';
  }

  // ===============
  // Match
  // ===============

  function announceResults(results:MultiplayerResults):Void
  {
    var title:String = 'Results: ' + results.songId + ' (' + results.difficultyId + ')';
    var body:String = MultiplayerData.describeResults(results);

    chatLines.push('== ' + title);

    for (line in body.split('\n')) chatLines.push('   ' + line);

    if (!lobbyPanel.hidden) renderChat();

    Dialogs.messageBox(body == '' ? 'Nobody finished the song.' : body, title, MessageBoxType.TYPE_INFO, true);
  }

  function onSongStartSignal():Void
  {
    if (starting) return;

    starting = true;

    var room:Null<MultiplayerRoom> = multiplayer.currentRoom;

    if (room == null || room.songId == null)
    {
      starting = false;
      return;
    }

    var song:Null<Song> = SongRegistry.instance.fetchEntry(room.songId);

    if (song == null)
    {
      toast('You do not have the song "' + room.songId + '", so you left the round.', NotificationType.Error);
      multiplayer.leaveRoom();
      showBrowser();
      refreshRooms();
      return;
    }

    PlayState.multiplayerMatchActive = true;

    LoadingState.loadPlayState({
      targetSong: song,
      targetDifficulty: room.difficultyId ?? 'normal',
      targetVariation: room.variation ?? Constants.DEFAULT_VARIATION,
      isMultiplayerMode: true
    });
  }

  // ===============
  // Leaderboard
  // ===============

  function refreshBoard():Void
  {
    if (boardSong.selectedItem == null || boardDifficulty.selectedItem == null || !FunkinOnline.instance.isConnected()) return;

    multiplayer.requestLeaderboard(Std.string(boardSong.selectedItem.text), Std.string(boardDifficulty.selectedItem.text));
  }

  function onLeaderboardSignal(songId:String, difficulty:String, entries:Array<MultiplayerLeaderboardEntry>):Void
  {
    if (starting) return;

    boardList.dataSource.clear();

    for (entry in entries)
    {
      boardList.dataSource.add({
        title: entry.rank + '.  ' + entry.username + (entry.authenticated ? '' : '  (guest)'),
        subtitle: MultiplayerData.formatScore(entry.score)
      });
    }

    boardEmpty.text = entries.length == 0 ? 'Nobody has a score for ' + songId + ' (' + difficulty + ') on this server yet.' : '';
  }

  // ===============
  // Events
  // ===============

  @:bind(lobbyBack, MouseEvent.CLICK)
  function onLobbyBackClick(_):Void
  {
    goBack();
  }

  @:bind(serverConnect, MouseEvent.CLICK)
  function onServerConnectClick(_):Void
  {
    applyServerAddress();
  }

  @:bind(roomsRefresh, MouseEvent.CLICK)
  function onRoomsRefreshClick(_):Void
  {
    refreshRooms();
  }

  @:bind(createRoom, MouseEvent.CLICK)
  function onCreateRoomClick(_):Void
  {
    createRoomNow();
  }

  @:bind(joinRoom, MouseEvent.CLICK)
  function onJoinRoomClick(_):Void
  {
    joinByCode();
  }

  @:bind(joinSelected, MouseEvent.CLICK)
  function onJoinSelectedClick(_):Void
  {
    if (selectedRoomId != '') multiplayer.joinRoom(selectedRoomId);
  }

  @:bind(roomList, UIEvent.CHANGE)
  function onRoomListChange(_):Void
  {
    if (syncing || roomList.selectedItem == null) return;

    selectedRoomId = Std.string(roomList.selectedItem.id);
    joinSelected.disabled = false;
  }

  @:bind(memberList, UIEvent.CHANGE)
  function onMemberListChange(_):Void
  {
    if (syncing || memberList.selectedItem == null) return;

    selectedMemberId = Std.string(memberList.selectedItem.id);
    memberKick.disabled = !multiplayer.isHost || selectedMemberId == FunkinUser.instance.getLocalUserId();
  }

  @:bind(memberKick, MouseEvent.CLICK)
  function onMemberKickClick(_):Void
  {
    if (selectedMemberId != '') multiplayer.kick(selectedMemberId);
  }

  @:bind(codeCopy, MouseEvent.CLICK)
  function onCodeCopyClick(_):Void
  {
    if (multiplayer.currentRoom == null) return;

    Clipboard.text = multiplayer.currentRoom.roomId;

    toast('Room code ' + MultiplayerData.formatCode(multiplayer.currentRoom.roomId) + ' copied.', NotificationType.Success);
  }

  @:bind(songPicker, UIEvent.CHANGE)
  function onSongPickerChange(_):Void
  {
    if (syncing || !multiplayer.isHost || songPicker.selectedItem == null || songPicker.selectedIndex == 0) return;

    var songId:String = Std.string(songPicker.selectedItem.text);
    var room:Null<MultiplayerRoom> = multiplayer.currentRoom;

    if (room == null || room.songId == songId) return;

    multiplayer.selectSong(songId, 'normal', Constants.DEFAULT_VARIATION);
  }

  @:bind(difficultyPicker, UIEvent.CHANGE)
  function onDifficultyPickerChange(_):Void
  {
    if (syncing || !multiplayer.isHost || difficultyPicker.selectedItem == null) return;

    var room:Null<MultiplayerRoom> = multiplayer.currentRoom;
    var difficulty:String = Std.string(difficultyPicker.selectedItem.text);

    if (room == null || room.songId == null || room.difficultyId == difficulty) return;

    multiplayer.selectSong(room.songId, difficulty, room.variation ?? Constants.DEFAULT_VARIATION);
  }

  @:bind(settingPublic, UIEvent.CHANGE)
  function onSettingPublicChange(_):Void
  {
    if (syncing || !multiplayer.isHost) return;

    multiplayer.setRoomSettings(null, settingPublic.selected, null);
  }

  @:bind(settingMax, UIEvent.CHANGE)
  function onSettingMaxChange(_):Void
  {
    if (syncing || !multiplayer.isHost) return;

    multiplayer.setRoomSettings(null, null, Std.int(settingMax.pos));
  }

  @:bind(readyToggle, MouseEvent.CLICK)
  function onReadyToggleClick(_):Void
  {
    var room:Null<MultiplayerRoom> = multiplayer.currentRoom;

    if (room == null) return;

    var me:Null<MultiplayerMember> = MultiplayerData.memberById(room, FunkinUser.instance.getLocalUserId());

    multiplayer.setReady(me == null || !me.ready);
  }

  @:bind(startMatch, MouseEvent.CLICK)
  function onStartMatchClick(_):Void
  {
    multiplayer.startSong();
  }

  @:bind(leaveRoom, MouseEvent.CLICK)
  function onLeaveRoomClick(_):Void
  {
    multiplayer.leaveRoom();
    showBrowser();
    refreshRooms();
  }

  @:bind(chatSend, MouseEvent.CLICK)
  function onChatSendClick(_):Void
  {
    sendChatNow();
  }

  @:bind(boardSong, UIEvent.CHANGE)
  function onBoardSongChange(_):Void
  {
    if (!syncing) refreshBoard();
  }

  @:bind(boardDifficulty, UIEvent.CHANGE)
  function onBoardDifficultyChange(_):Void
  {
    if (!syncing) refreshBoard();
  }

  @:bind(boardRefresh, MouseEvent.CLICK)
  function onBoardRefreshClick(_):Void
  {
    refreshBoard();
  }

  override function destroy():Void
  {
    unregisterSignals();

    NotificationManager.instance.clearNotifications();

    super.destroy();
  }
}
#end
