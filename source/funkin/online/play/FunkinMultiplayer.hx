package funkin.online.play;

import flixel.util.FlxSignal.FlxTypedSignal;
import funkin.online.FunkinOnline;
import funkin.online.FunkinUser;

typedef FunkinMultiplayerRoomInfo =
{
  var roomId:String;
  var hostId:String;
  var songId:Null<String>;
  var difficultyId:Null<String>;
  var variation:Null<String>;
  var players:Array<String>;
}

typedef FunkinMultiplayerPlayerScore =
{
  var userId:String;
  var score:Int;
  var combo:Int;
  var health:Float;
  var accuracy:Float;
}

class FunkinMultiplayer
{
  public static var instance(default, null):FunkinMultiplayer = new FunkinMultiplayer();

  public var currentRoom(default, null):Null<FunkinMultiplayerRoomInfo> = null;

  public var isHost(get, never):Bool;

  function get_isHost():Bool
  {
    var localId:Null<String> = FunkinUser.instance.localUser?.id;
    return currentRoom != null && localId != null && currentRoom.hostId == localId;
  }

  public var onRoomCreated:FlxTypedSignal<FunkinMultiplayerRoomInfo->Void> = new FlxTypedSignal<FunkinMultiplayerRoomInfo->Void>();
  public var onRoomJoined:FlxTypedSignal<FunkinMultiplayerRoomInfo->Void> = new FlxTypedSignal<FunkinMultiplayerRoomInfo->Void>();
  public var onRoomJoinFailed:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();
  public var onRoomClosed:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
  public var onPlayerJoined:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();
  public var onPlayerLeft:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();
  public var onSongSelected:FlxTypedSignal<FunkinMultiplayerRoomInfo->Void> = new FlxTypedSignal<FunkinMultiplayerRoomInfo->Void>();
  public var onPlayerReadyChanged:FlxTypedSignal<String->Bool->Void> = new FlxTypedSignal<String->Bool->Void>();
  public var onSongStart:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();
  public var onOpponentScoreUpdate:FlxTypedSignal<FunkinMultiplayerPlayerScore->Void> = new FlxTypedSignal<FunkinMultiplayerPlayerScore->Void>();
  public var onPlayerFinished:FlxTypedSignal<FunkinMultiplayerPlayerScore->Void> = new FlxTypedSignal<FunkinMultiplayerPlayerScore->Void>();

  var readyPlayers:Map<String, Bool> = new Map();
  var opponentScores:Map<String, FunkinMultiplayerPlayerScore> = new Map();

  var initialized:Bool = false;

  var scoreUpdateAccumTime:Float = 0.0;

  static final SCORE_UPDATE_INTERVAL:Float = 0.2;

  function new():Void
  {
  }

  public function init():Void
  {
    if (initialized) return;
    initialized = true;

    FunkinOnline.instance.registerHandler('mp_roomCreated', onRoomCreatedMessage);
    FunkinOnline.instance.registerHandler('mp_roomJoined', onRoomJoinedMessage);
    FunkinOnline.instance.registerHandler('mp_roomJoinFailed', onRoomJoinFailedMessage);
    FunkinOnline.instance.registerHandler('mp_roomClosed', onRoomClosedMessage);
    FunkinOnline.instance.registerHandler('mp_playerJoined', onPlayerJoinedMessage);
    FunkinOnline.instance.registerHandler('mp_playerLeft', onPlayerLeftMessage);
    FunkinOnline.instance.registerHandler('mp_songSelected', onSongSelectedMessage);
    FunkinOnline.instance.registerHandler('mp_playerReady', onPlayerReadyMessage);
    FunkinOnline.instance.registerHandler('mp_startSong', onStartSongMessage);
    FunkinOnline.instance.registerHandler('mp_scoreUpdate', onScoreUpdateMessage);
    FunkinOnline.instance.registerHandler('mp_playerFinished', onPlayerFinishedMessage);

    FunkinOnline.instance.onDisconnected.add(onOnlineDisconnected);
  }

  function onOnlineDisconnected():Void
  {
    resetLocalState();
    onRoomClosed.dispatch();
  }

  function resetLocalState():Void
  {
    currentRoom = null;
    readyPlayers = new Map();
    opponentScores = new Map();
    scoreUpdateAccumTime = 0.0;
  }

  public function createRoom():Void
  {
    if (!FunkinOnline.instance.isConnected())
    {
      FlxG.log.warn('[FunkinMultiplayer] Cannot create a room while offline.');
      return;
    }

    var localId:Null<String> = FunkinUser.instance.localUser?.id;
    if (localId == null)
    {
      FlxG.log.warn('[FunkinMultiplayer] Cannot create a room before FunkinUser is initialized.');
      return;
    }

    FunkinOnline.instance.send('mp_createRoom', {hostId: localId});
  }

  public function joinRoom(roomId:String):Void
  {
    if (!FunkinOnline.instance.isConnected())
    {
      FlxG.log.warn('[FunkinMultiplayer] Cannot join a room while offline.');
      return;
    }

    var localId:Null<String> = FunkinUser.instance.localUser?.id;
    if (localId == null)
    {
      FlxG.log.warn('[FunkinMultiplayer] Cannot join a room before FunkinUser is initialized.');
      return;
    }

    FunkinOnline.instance.send('mp_joinRoom', {roomId: roomId, userId: localId});
  }

  public function leaveRoom():Void
  {
    if (currentRoom == null) return;

    FunkinOnline.instance.send('mp_leaveRoom', {roomId: currentRoom.roomId});

    resetLocalState();
  }

  public function selectSong(songId:String, difficultyId:String, variation:String = 'default'):Void
  {
    if (currentRoom == null) return;

    if (!isHost)
    {
      FlxG.log.warn('[FunkinMultiplayer] Only the host can select the song.');
      return;
    }

    FunkinOnline.instance.send('mp_selectSong', {
      roomId: currentRoom.roomId,
      songId: songId,
      difficultyId: difficultyId,
      variation: variation
    });
  }

  public function setReady(ready:Bool):Void
  {
    if (currentRoom == null) return;

    var localId:Null<String> = FunkinUser.instance.localUser?.id;
    if (localId == null) return;

    readyPlayers.set(localId, ready);

    FunkinOnline.instance.send('mp_setReady', {roomId: currentRoom.roomId, userId: localId, ready: ready});
  }

  public function isPlayerReady(userId:String):Bool
  {
    return readyPlayers.get(userId) ?? false;
  }

  public function areAllPlayersReady():Bool
  {
    if (currentRoom == null || currentRoom.players.length == 0) return false;

    for (playerId in currentRoom.players)
    {
      if (!isPlayerReady(playerId)) return false;
    }

    return true;
  }

  public function startSong():Void
  {
    if (currentRoom == null) return;

    if (!isHost)
    {
      FlxG.log.warn('[FunkinMultiplayer] Only the host can start the song.');
      return;
    }

    FunkinOnline.instance.send('mp_startSong', {roomId: currentRoom.roomId});
  }

  public function sendScoreUpdate(elapsed:Float, score:Int, combo:Int, health:Float, accuracy:Float, force:Bool = false):Void
  {
    if (currentRoom == null) return;

    scoreUpdateAccumTime += elapsed;

    if (!force && scoreUpdateAccumTime < SCORE_UPDATE_INTERVAL) return;

    scoreUpdateAccumTime = 0.0;

    var localId:Null<String> = FunkinUser.instance.localUser?.id;
    if (localId == null) return;

    FunkinOnline.instance.send('mp_scoreUpdate', {
      roomId: currentRoom.roomId,
      userId: localId,
      score: score,
      combo: combo,
      health: health,
      accuracy: accuracy
    });
  }

  public function sendFinished(score:Int, combo:Int, health:Float, accuracy:Float):Void
  {
    if (currentRoom == null) return;

    var localId:Null<String> = FunkinUser.instance.localUser?.id;
    if (localId == null) return;

    FunkinOnline.instance.send('mp_playerFinished', {
      roomId: currentRoom.roomId,
      userId: localId,
      score: score,
      combo: combo,
      health: health,
      accuracy: accuracy
    });
  }

  public function getOpponentScore(userId:String):Null<FunkinMultiplayerPlayerScore>
  {
    return opponentScores.get(userId);
  }

  public function getAllOpponentScores():Array<FunkinMultiplayerPlayerScore>
  {
    var result:Array<FunkinMultiplayerPlayerScore> = [];
    for (score in opponentScores) result.push(score);
    return result;
  }

  function parseRoomInfo(data:Dynamic):Null<FunkinMultiplayerRoomInfo>
  {
    if (data == null) return null;

    var roomId:Null<String> = data.roomId;
    var hostId:Null<String> = data.hostId;
    if (roomId == null || hostId == null) return null;

    var players:Array<String> = [];

    if (data.players != null)
    {
      var rawPlayers:Array<Dynamic> = data.players;
      for (rawPlayer in rawPlayers)
        players.push(Std.string(rawPlayer));
    }
    else
    {
      players.push(hostId);
    }

    return {
      roomId: roomId,
      hostId: hostId,
      songId: data.songId,
      difficultyId: data.difficultyId,
      variation: data.variation,
      players: players
    };
  }

  function onRoomCreatedMessage(data:Dynamic):Void
  {
    var room:Null<FunkinMultiplayerRoomInfo> = parseRoomInfo(data);
    if (room == null) return;

    currentRoom = room;
    readyPlayers = new Map();
    opponentScores = new Map();

    onRoomCreated.dispatch(room);
  }

  function onRoomJoinedMessage(data:Dynamic):Void
  {
    var room:Null<FunkinMultiplayerRoomInfo> = parseRoomInfo(data);
    if (room == null) return;

    currentRoom = room;
    readyPlayers = new Map();
    opponentScores = new Map();

    onRoomJoined.dispatch(room);
  }

  function onRoomJoinFailedMessage(data:Dynamic):Void
  {
    var reason:String = (data != null && data.reason != null) ? data.reason : 'Unknown error';
    onRoomJoinFailed.dispatch(reason);
  }

  function onRoomClosedMessage(data:Dynamic):Void
  {
    resetLocalState();
    onRoomClosed.dispatch();
  }

  function onPlayerJoinedMessage(data:Dynamic):Void
  {
    if (currentRoom == null || data == null) return;

    var userId:Null<String> = data.userId;
    if (userId == null) return;

    if (currentRoom.players.indexOf(userId) == -1) currentRoom.players.push(userId);

    onPlayerJoined.dispatch(userId);
  }

  function onPlayerLeftMessage(data:Dynamic):Void
  {
    if (currentRoom == null || data == null) return;

    var userId:Null<String> = data.userId;
    if (userId == null) return;

    currentRoom.players.remove(userId);
    readyPlayers.remove(userId);
    opponentScores.remove(userId);

    onPlayerLeft.dispatch(userId);
  }

  function onSongSelectedMessage(data:Dynamic):Void
  {
    if (currentRoom == null || data == null) return;

    currentRoom.songId = data.songId;
    currentRoom.difficultyId = data.difficultyId;
    currentRoom.variation = data.variation;

    readyPlayers = new Map();

    onSongSelected.dispatch(currentRoom);
  }

  function onPlayerReadyMessage(data:Dynamic):Void
  {
    if (data == null) return;

    var userId:Null<String> = data.userId;
    if (userId == null) return;

    var ready:Bool = data.ready ?? false;

    readyPlayers.set(userId, ready);

    onPlayerReadyChanged.dispatch(userId, ready);
  }

  function onStartSongMessage(data:Dynamic):Void
  {
    opponentScores = new Map();
    scoreUpdateAccumTime = 0.0;

    onSongStart.dispatch();
  }

  function onScoreUpdateMessage(data:Dynamic):Void
  {
    var scoreInfo:Null<FunkinMultiplayerPlayerScore> = parsePlayerScore(data);
    if (scoreInfo == null) return;

    opponentScores.set(scoreInfo.userId, scoreInfo);

    onOpponentScoreUpdate.dispatch(scoreInfo);
  }

  function onPlayerFinishedMessage(data:Dynamic):Void
  {
    var scoreInfo:Null<FunkinMultiplayerPlayerScore> = parsePlayerScore(data);
    if (scoreInfo == null) return;

    opponentScores.set(scoreInfo.userId, scoreInfo);

    onPlayerFinished.dispatch(scoreInfo);
  }

  function parsePlayerScore(data:Dynamic):Null<FunkinMultiplayerPlayerScore>
  {
    if (data == null) return null;

    var userId:Null<String> = data.userId;
    if (userId == null) return null;

    return {
      userId: userId,
      score: data.score ?? 0,
      combo: data.combo ?? 0,
      health: data.health ?? 0.0,
      accuracy: data.accuracy ?? 0.0
    };
  }
}
