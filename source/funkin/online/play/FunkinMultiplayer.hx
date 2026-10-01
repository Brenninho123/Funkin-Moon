package funkin.online.play;

import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.util.FlxTimer;
import funkin.online.FunkinOnline;
import funkin.online.FunkinUser;
import funkin.online.play.MultiplayerData;
import funkin.online.play.MultiplayerData.MultiplayerChatMessage;
import funkin.online.play.MultiplayerData.MultiplayerLeaderboardEntry;
import funkin.online.play.MultiplayerData.MultiplayerMember;
import funkin.online.play.MultiplayerData.MultiplayerResults;
import funkin.online.play.MultiplayerData.MultiplayerRoom;
import funkin.online.play.MultiplayerData.MultiplayerRoomSummary;
import funkin.online.play.MultiplayerData.MultiplayerScore;
import funkin.online.play.MultiplayerData.MultiplayerStats;

typedef FunkinMultiplayerRoomInfo = MultiplayerRoom;
typedef FunkinMultiplayerPlayerScore = MultiplayerScore;

class FunkinMultiplayer
{
  public static var instance(default, null):FunkinMultiplayer = new FunkinMultiplayer();

  public var currentRoom(default, null):Null<MultiplayerRoom> = null;

  public var inMatch(default, null):Bool = false;
  public var connectionLost(default, null):Bool = false;
  public var localFinished(default, null):Bool = false;
  public var lastResults(default, null):Null<MultiplayerResults> = null;
  public var lastCloseReason(default, null):String = '';
  public var rooms(default, null):Array<MultiplayerRoomSummary> = [];
  public var chatLog(default, null):Array<MultiplayerChatMessage> = [];

  public var isHost(get, never):Bool;

  function get_isHost():Bool
  {
    var localId:String = FunkinUser.instance.getLocalUserId();

    return currentRoom != null && localId != '' && currentRoom.hostId == localId;
  }

  public var onRoomCreated:FlxTypedSignal<MultiplayerRoom->Void> = new FlxTypedSignal<MultiplayerRoom->Void>();
  public var onRoomJoined:FlxTypedSignal<MultiplayerRoom->Void> = new FlxTypedSignal<MultiplayerRoom->Void>();
  public var onRoomJoinFailed:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();
  public var onRoomClosed:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
  public var onRoomUpdated:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
  public var onPlayerJoined:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();
  public var onPlayerLeft:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();
  public var onHostChanged:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();
  public var onSongSelected:FlxTypedSignal<MultiplayerRoom->Void> = new FlxTypedSignal<MultiplayerRoom->Void>();
  public var onPlayerReadyChanged:FlxTypedSignal<String->Bool->Void> = new FlxTypedSignal<String->Bool->Void>();
  public var onSongStart:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
  public var onOpponentScoreUpdate:FlxTypedSignal<MultiplayerScore->Void> = new FlxTypedSignal<MultiplayerScore->Void>();
  public var onPlayerFinished:FlxTypedSignal<MultiplayerScore->Void> = new FlxTypedSignal<MultiplayerScore->Void>();
  public var onResults:FlxTypedSignal<MultiplayerResults->Void> = new FlxTypedSignal<MultiplayerResults->Void>();
  public var onChat:FlxTypedSignal<MultiplayerChatMessage->Void> = new FlxTypedSignal<MultiplayerChatMessage->Void>();
  public var onRelay:FlxTypedSignal<String->Dynamic->Void> = new FlxTypedSignal<String->Dynamic->Void>();
  public var onRoomsListed:FlxTypedSignal<Array<MultiplayerRoomSummary>->Void> = new FlxTypedSignal<Array<MultiplayerRoomSummary>->Void>();
  public var onLeaderboard:FlxTypedSignal<String->String->Array<MultiplayerLeaderboardEntry>->Void> = new FlxTypedSignal<String->String->Array<MultiplayerLeaderboardEntry>->Void>();
  public var onConnectionLost:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
  public var onConnectionRestored:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
  public var onPlayerAway:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();
  public var onPlayerBack:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();
  public var onStats:FlxTypedSignal<MultiplayerStats->Void> = new FlxTypedSignal<MultiplayerStats->Void>();
  public var onError:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

  var opponentScores:Map<String, MultiplayerScore> = new Map();

  var initialized:Bool = false;

  var scoreUpdateAccumTime:Float = 0.0;
  var resumeTimer:Null<FlxTimer> = null;

  static final SCORE_UPDATE_INTERVAL:Float = 0.2;
  static final RESUME_TIMEOUT:Float = 45.0;
  static final CHAT_HISTORY:Int = 60;

  function new():Void
  {
  }

  public function init():Void
  {
    if (initialized) return;
    initialized = true;

    var online:FunkinOnline = FunkinOnline.instance;

    online.registerHandler('mp_roomCreated', onRoomCreatedMessage);
    online.registerHandler('mp_roomJoined', onRoomJoinedMessage);
    online.registerHandler('mp_roomJoinFailed', onRoomJoinFailedMessage);
    online.registerHandler('mp_roomClosed', onRoomClosedMessage);
    online.registerHandler('mp_roomState', onRoomStateMessage);
    online.registerHandler('mp_roomResumed', onRoomResumedMessage);
    online.registerHandler('mp_playerAway', onPlayerAwayMessage);
    online.registerHandler('mp_playerBack', onPlayerBackMessage);
    online.registerHandler('welcome', onWelcomeMessage);
    online.registerHandler('stats', onStatsMessage);
    online.registerHandler('mp_playerJoined', onPlayerJoinedMessage);
    online.registerHandler('mp_playerLeft', onPlayerLeftMessage);
    online.registerHandler('mp_hostChanged', onHostChangedMessage);
    online.registerHandler('mp_memberUpdated', onMemberUpdatedMessage);
    online.registerHandler('mp_songSelected', onSongSelectedMessage);
    online.registerHandler('mp_playerReady', onPlayerReadyMessage);
    online.registerHandler('mp_startSong', onStartSongMessage);
    online.registerHandler('mp_scoreUpdate', onScoreUpdateMessage);
    online.registerHandler('mp_playerFinished', onPlayerFinishedMessage);
    online.registerHandler('mp_results', onResultsMessage);
    online.registerHandler('mp_relay', onRelayMessage);
    online.registerHandler('mp_chat', onChatMessage);
    online.registerHandler('mp_rooms', onRoomsMessage);
    online.registerHandler('leaderboard', onLeaderboardMessage);
    online.registerHandler('error', onErrorMessage);

    online.onDisconnected.add(onOnlineDisconnected);
  }

  function onOnlineDisconnected():Void
  {
    if (currentRoom != null && FunkinOnline.instance.willReconnect())
    {
      if (!connectionLost)
      {
        connectionLost = true;
        startResumeTimer();
        onConnectionLost.dispatch();
        updated();
      }

      return;
    }

    giveUpResuming();
  }

  function giveUpResuming():Void
  {
    var hadRoom:Bool = currentRoom != null;

    resetLocalState();

    if (hadRoom)
    {
      lastCloseReason = 'disconnected';
      onRoomClosed.dispatch();
    }
  }

  function startResumeTimer():Void
  {
    cancelResumeTimer();

    resumeTimer = FunkinOnline.createTimer().start(RESUME_TIMEOUT, (_) ->
    {
      resumeTimer = null;

      if (connectionLost) giveUpResuming();
    });
  }

  function cancelResumeTimer():Void
  {
    if (resumeTimer != null)
    {
      resumeTimer.cancel();
      resumeTimer = null;
    }
  }

  function onWelcomeMessage(data:Dynamic):Void
  {
    if (!connectionLost) return;

    if (data != null && data.resumed == true) return;

    giveUpResuming();
  }

  function resetLocalState():Void
  {
    cancelResumeTimer();

    connectionLost = false;
    currentRoom = null;
    inMatch = false;
    localFinished = false;
    opponentScores = new Map();
    scoreUpdateAccumTime = 0.0;
    chatLog = [];
  }

  function canSend(action:String):Bool
  {
    if (!FunkinOnline.instance.isConnected())
    {
      FlxG.log.warn('[FunkinMultiplayer] Cannot ' + action + ' while offline.');
      onError.dispatch('disconnected');
      return false;
    }

    return true;
  }

  public function createRoom(?name:String, isPublic:Bool = true, maxPlayers:Int = 4):Void
  {
    if (!canSend('create a room')) return;

    var data:Dynamic = {isPublic: isPublic, maxPlayers: maxPlayers};

    if (name != null && StringTools.trim(name) != '') data.name = StringTools.trim(name);

    FunkinOnline.instance.send('mp_createRoom', data);
  }

  public function joinRoom(roomId:String):Void
  {
    if (!canSend('join a room')) return;

    FunkinOnline.instance.send('mp_joinRoom', {roomId: MultiplayerData.normalizeCode(roomId)});
  }

  public function quickMatch():Void
  {
    if (!canSend('find a match')) return;

    FunkinOnline.instance.send('mp_quickMatch');
  }

  public function requestStats(userId:String = ''):Void
  {
    if (!FunkinOnline.instance.isConnected()) return;

    FunkinOnline.instance.send('stats', userId == '' ? {} : {userId: userId});
  }

  public function leaveRoom():Void
  {
    if (currentRoom == null) return;

    if (FunkinOnline.instance.isConnected()) FunkinOnline.instance.send('mp_leaveRoom');

    resetLocalState();
  }

  public function listRooms():Void
  {
    if (!canSend('list the rooms')) return;

    FunkinOnline.instance.send('mp_listRooms');
  }

  public function requestLeaderboard(songId:String, difficulty:String):Void
  {
    if (!FunkinOnline.instance.isConnected()) return;

    FunkinOnline.instance.send('leaderboard', {songId: songId, difficulty: difficulty, limit: 10});
  }

  public function selectSong(songId:String, difficultyId:String, variation:String = 'default'):Void
  {
    if (currentRoom == null || !isHost) return;

    FunkinOnline.instance.send('mp_selectSong', {songId: songId, difficultyId: difficultyId, variation: variation});
  }

  public function setReady(ready:Bool):Void
  {
    if (currentRoom == null) return;

    FunkinOnline.instance.send('mp_setReady', {ready: ready});
  }

  public function setRoomSettings(?name:String, ?isPublic:Bool, ?maxPlayers:Int):Void
  {
    if (currentRoom == null || !isHost) return;

    var data:Dynamic = {};

    if (name != null) data.name = name;
    if (isPublic != null) data.isPublic = isPublic;
    if (maxPlayers != null) data.maxPlayers = maxPlayers;

    FunkinOnline.instance.send('mp_roomSettings', data);
  }

  public function kick(userId:String):Void
  {
    if (currentRoom == null || !isHost) return;

    FunkinOnline.instance.send('mp_kick', {userId: userId});
  }

  public function sendChat(text:String, global:Bool = false):Void
  {
    var clean:String = StringTools.trim(text);

    if (clean == '' || !FunkinOnline.instance.isConnected()) return;

    FunkinOnline.instance.send('mp_chat', {text: clean, scope: global || currentRoom == null ? 'global' : 'room'});
  }

  public function isPlayerReady(userId:String):Bool
  {
    var member:Null<MultiplayerMember> = currentRoom != null ? MultiplayerData.memberById(currentRoom, userId) : null;

    return member != null && member.ready;
  }

  public function areAllPlayersReady():Bool
  {
    return currentRoom != null && currentRoom.members.length > 0 && MultiplayerData.everyoneReady(currentRoom);
  }

  public function startSong():Void
  {
    if (currentRoom == null || !isHost) return;

    FunkinOnline.instance.send('mp_startSong');
  }

  public function sendScoreUpdate(elapsed:Float, score:Int, combo:Int, health:Float, accuracy:Float, force:Bool = false):Void
  {
    if (currentRoom == null || !inMatch || localFinished || connectionLost) return;

    scoreUpdateAccumTime += elapsed;

    if (!force && scoreUpdateAccumTime < SCORE_UPDATE_INTERVAL) return;

    scoreUpdateAccumTime = 0.0;

    FunkinOnline.instance.send('mp_scoreUpdate', {score: score, combo: combo, health: health, accuracy: accuracy});
  }

  public function sendRelay(payload:Dynamic):Void
  {
    if (currentRoom == null || !inMatch || localFinished || connectionLost) return;

    FunkinOnline.instance.send('mp_relay', {payload: payload});
  }

  public function sendFinished(score:Int, combo:Int, health:Float, accuracy:Float):Void
  {
    if (currentRoom == null || !inMatch || localFinished) return;

    localFinished = true;

    var me:Null<MultiplayerMember> = MultiplayerData.memberById(currentRoom, FunkinUser.instance.getLocalUserId());

    if (me != null)
    {
      me.finished = true;
      me.score = score;
      me.combo = combo;
      me.accuracy = accuracy;
    }

    FunkinOnline.instance.send('mp_playerFinished', {score: score, combo: combo, health: health, accuracy: accuracy});
  }

  public function takeResults():Null<MultiplayerResults>
  {
    var results:Null<MultiplayerResults> = lastResults;

    lastResults = null;

    return results;
  }

  public function getOpponentScore(userId:String):Null<MultiplayerScore>
  {
    return opponentScores.get(userId);
  }

  public function getAllOpponentScores():Array<MultiplayerScore>
  {
    return [for (score in opponentScores) score];
  }

  function updated():Void
  {
    onRoomUpdated.dispatch();
  }

  function onRoomCreatedMessage(data:Dynamic):Void
  {
    var room:Null<MultiplayerRoom> = MultiplayerData.parseRoom(data);

    if (room == null) return;

    currentRoom = room;
    inMatch = false;
    localFinished = false;
    lastResults = null;
    chatLog = [];
    opponentScores = new Map();

    onRoomCreated.dispatch(room);
    updated();
  }

  function onRoomJoinedMessage(data:Dynamic):Void
  {
    var room:Null<MultiplayerRoom> = MultiplayerData.parseRoom(data);

    if (room == null) return;

    currentRoom = room;
    inMatch = false;
    localFinished = false;
    lastResults = null;
    chatLog = [];
    opponentScores = new Map();

    onRoomJoined.dispatch(room);
    updated();
  }

  function onRoomJoinFailedMessage(data:Dynamic):Void
  {
    var reason:String = (data != null && data.reason != null) ? Std.string(data.reason) : 'unknown';

    onRoomJoinFailed.dispatch(reason);
  }

  function onRoomClosedMessage(data:Dynamic):Void
  {
    lastCloseReason = (data != null && data.reason != null) ? Std.string(data.reason) : 'closed';

    resetLocalState();
    onRoomClosed.dispatch();
  }

  function onRoomStateMessage(data:Dynamic):Void
  {
    var room:Null<MultiplayerRoom> = MultiplayerData.parseRoom(data);

    if (room == null || currentRoom == null || room.roomId != currentRoom.roomId) return;

    currentRoom = room;

    if (room.state == MultiplayerData.STATE_LOBBY)
    {
      inMatch = false;
      localFinished = false;
    }

    updated();
  }

  function onRoomResumedMessage(data:Dynamic):Void
  {
    var resume:Null<MultiplayerData.MultiplayerResume> = MultiplayerData.parseResume(data);

    if (resume == null) return;

    cancelResumeTimer();

    var wasLost:Bool = connectionLost;

    connectionLost = false;
    currentRoom = resume.room;

    if (resume.room.state == MultiplayerData.STATE_LOBBY)
    {
      inMatch = false;
      localFinished = false;
    }

    if (resume.results != null)
    {
      lastResults = resume.results;
      onResults.dispatch(resume.results);
    }

    if (wasLost) onConnectionRestored.dispatch();

    updated();
  }

  function onPlayerAwayMessage(data:Dynamic):Void
  {
    if (currentRoom == null || data == null || data.userId == null) return;

    var userId:String = Std.string(data.userId);
    var member:Null<MultiplayerMember> = MultiplayerData.memberById(currentRoom, userId);

    if (member != null) member.away = true;

    if (data.hostId != null) applyHost(Std.string(data.hostId));

    onPlayerAway.dispatch(userId);
    updated();
  }

  function onPlayerBackMessage(data:Dynamic):Void
  {
    if (currentRoom == null || data == null || data.userId == null) return;

    var userId:String = Std.string(data.userId);
    var member:Null<MultiplayerMember> = MultiplayerData.memberById(currentRoom, userId);

    if (member != null) member.away = false;

    if (data.hostId != null) applyHost(Std.string(data.hostId));

    onPlayerBack.dispatch(userId);
    updated();
  }

  function onStatsMessage(data:Dynamic):Void
  {
    var stats:Null<MultiplayerStats> = MultiplayerData.parseStats(data);

    if (stats != null) onStats.dispatch(stats);
  }

  function onPlayerJoinedMessage(data:Dynamic):Void
  {
    if (currentRoom == null || data == null) return;

    var member:Null<MultiplayerMember> = MultiplayerData.parseMember(data.member);
    var userId:String = data.userId != null ? Std.string(data.userId) : (member != null ? member.id : '');

    if (userId == '') return;

    if (currentRoom.players.indexOf(userId) == -1) currentRoom.players.push(userId);

    if (member != null && MultiplayerData.memberById(currentRoom, userId) == null) currentRoom.members.push(member);

    onPlayerJoined.dispatch(userId);
    updated();
  }

  function onPlayerLeftMessage(data:Dynamic):Void
  {
    if (currentRoom == null || data == null || data.userId == null) return;

    var userId:String = Std.string(data.userId);

    currentRoom.players.remove(userId);
    currentRoom.members = [for (member in currentRoom.members) if (member.id != userId) member];
    opponentScores.remove(userId);

    if (data.hostId != null) applyHost(Std.string(data.hostId));

    onPlayerLeft.dispatch(userId);
    updated();
  }

  function applyHost(hostId:String):Void
  {
    if (currentRoom == null) return;

    currentRoom.hostId = hostId;

    for (member in currentRoom.members) member.isHost = member.id == hostId;
  }

  function onHostChangedMessage(data:Dynamic):Void
  {
    if (currentRoom == null || data == null || data.hostId == null) return;

    applyHost(Std.string(data.hostId));

    onHostChanged.dispatch(currentRoom.hostId);
    updated();
  }

  function onMemberUpdatedMessage(data:Dynamic):Void
  {
    if (currentRoom == null || data == null) return;

    var member:Null<MultiplayerMember> = MultiplayerData.parseMember(data.member);

    if (member == null) return;

    var oldId:String = data.oldId != null ? Std.string(data.oldId) : member.id;
    var index:Int = currentRoom.players.indexOf(oldId);

    if (index >= 0) currentRoom.players[index] = member.id;

    for (i in 0...currentRoom.members.length)
    {
      if (currentRoom.members[i].id == oldId) currentRoom.members[i] = member;
    }

    if (data.hostId != null) applyHost(Std.string(data.hostId));

    updated();
  }

  function onSongSelectedMessage(data:Dynamic):Void
  {
    if (currentRoom == null || data == null) return;

    currentRoom.songId = data.songId != null ? Std.string(data.songId) : null;
    currentRoom.difficultyId = data.difficultyId != null ? Std.string(data.difficultyId) : null;
    currentRoom.variation = data.variation != null ? Std.string(data.variation) : null;

    for (member in currentRoom.members) member.ready = false;

    onSongSelected.dispatch(currentRoom);
    updated();
  }

  function onPlayerReadyMessage(data:Dynamic):Void
  {
    if (currentRoom == null || data == null || data.userId == null) return;

    var userId:String = Std.string(data.userId);
    var ready:Bool = data.ready == true;
    var member:Null<MultiplayerMember> = MultiplayerData.memberById(currentRoom, userId);

    if (member != null) member.ready = ready;

    onPlayerReadyChanged.dispatch(userId, ready);
    updated();
  }

  function onStartSongMessage(data:Dynamic):Void
  {
    if (currentRoom == null) return;

    if (data != null)
    {
      if (data.songId != null) currentRoom.songId = Std.string(data.songId);
      if (data.difficultyId != null) currentRoom.difficultyId = Std.string(data.difficultyId);
      if (data.variation != null) currentRoom.variation = Std.string(data.variation);
      if (data.seed != null) currentRoom.seed = Std.int(data.seed);
      if (data.round != null) currentRoom.round = Std.int(data.round);
    }

    currentRoom.state = MultiplayerData.STATE_PLAYING;

    for (member in currentRoom.members)
    {
      member.finished = false;
      member.score = 0;
      member.combo = 0;
    }

    inMatch = true;
    localFinished = false;
    lastResults = null;
    opponentScores = new Map();
    scoreUpdateAccumTime = 0.0;

    onSongStart.dispatch();
    updated();
  }

  function onScoreUpdateMessage(data:Dynamic):Void
  {
    var scoreInfo:Null<MultiplayerScore> = MultiplayerData.parseScore(data);

    if (scoreInfo == null) return;

    opponentScores.set(scoreInfo.userId, scoreInfo);

    onOpponentScoreUpdate.dispatch(scoreInfo);
  }

  function onPlayerFinishedMessage(data:Dynamic):Void
  {
    var scoreInfo:Null<MultiplayerScore> = MultiplayerData.parseScore(data);

    if (scoreInfo == null) return;

    opponentScores.set(scoreInfo.userId, scoreInfo);

    if (currentRoom != null)
    {
      var member:Null<MultiplayerMember> = MultiplayerData.memberById(currentRoom, scoreInfo.userId);

      if (member != null)
      {
        member.finished = true;
        member.score = scoreInfo.score;
      }
    }

    onPlayerFinished.dispatch(scoreInfo);
  }

  function onResultsMessage(data:Dynamic):Void
  {
    var results:Null<MultiplayerResults> = MultiplayerData.parseResults(data);

    if (results == null) return;

    lastResults = results;
    inMatch = false;
    localFinished = false;

    if (currentRoom != null) currentRoom.state = MultiplayerData.STATE_LOBBY;

    onResults.dispatch(results);
    updated();
  }

  function onRelayMessage(data:Dynamic):Void
  {
    if (data == null || data.userId == null || data.payload == null) return;

    onRelay.dispatch(Std.string(data.userId), data.payload);
  }

  function onChatMessage(data:Dynamic):Void
  {
    var message:Null<MultiplayerChatMessage> = MultiplayerData.parseChat(data);

    if (message == null) return;

    chatLog.push(message);

    while (chatLog.length > CHAT_HISTORY) chatLog.shift();

    onChat.dispatch(message);
  }

  function onRoomsMessage(data:Dynamic):Void
  {
    rooms = MultiplayerData.parseRooms(data);

    onRoomsListed.dispatch(rooms);
  }

  function onLeaderboardMessage(data:Dynamic):Void
  {
    if (data == null) return;

    onLeaderboard.dispatch(data.songId != null ? Std.string(data.songId) : '', data.difficulty != null ? Std.string(data.difficulty) : '',
      MultiplayerData.parseLeaderboard(data));
  }

  function onErrorMessage(data:Dynamic):Void
  {
    var reason:String = (data != null && data.reason != null) ? Std.string(data.reason) : 'unknown';

    if (reason == 'logged_in_elsewhere') return;

    onError.dispatch(reason);
  }
}
