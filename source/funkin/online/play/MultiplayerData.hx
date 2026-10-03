package funkin.online.play;

typedef MultiplayerMember =
{
  var id:String;
  var username:String;
  var avatarUrl:String;
  var ready:Bool;
  var finished:Bool;
  var score:Int;
  var combo:Int;
  var accuracy:Float;
  var isHost:Bool;
  var away:Bool;
  var rating:Int;
}

typedef MultiplayerRoom =
{
  var roomId:String;
  var name:String;
  var hostId:String;
  var isPublic:Bool;
  var maxPlayers:Int;
  var state:String;
  var songId:Null<String>;
  var difficultyId:Null<String>;
  var variation:Null<String>;
  var players:Array<String>;
  var members:Array<MultiplayerMember>;
  var round:Int;
  var seed:Int;
  var locked:Bool;
  var spectators:Int;
}

typedef MultiplayerRoomSummary =
{
  var roomId:String;
  var name:String;
  var hostName:String;
  var players:Int;
  var maxPlayers:Int;
  var state:String;
  var songId:String;
  var difficultyId:String;
  var locked:Bool;
  var spectators:Int;
  var rating:Int;
}

typedef MultiplayerScore =
{
  var userId:String;
  var username:String;
  var score:Int;
  var combo:Int;
  var health:Float;
  var accuracy:Float;
}

typedef MultiplayerRanking =
{
  > MultiplayerScore,
  var rank:Int;
  var finished:Bool;
  var rating:Int;
  var ratingChange:Int;
}

typedef MultiplayerResults =
{
  var songId:String;
  var difficultyId:String;
  var variation:String;
  var round:Int;
  var rated:Bool;
  var rankings:Array<MultiplayerRanking>;
}

typedef MultiplayerChatMessage =
{
  var userId:String;
  var username:String;
  var text:String;
  var time:Float;
  var scope:String;
}

typedef MultiplayerStats =
{
  var id:String;
  var username:String;
  var found:Bool;
  var roundsPlayed:Int;
  var roundsWon:Int;
  var songsFinished:Int;
  var totalScore:Int;
  var bestScore:Int;
  var rating:Int;
  var ratedRounds:Int;
  var peakRating:Int;
}

typedef MultiplayerRatingEntry =
{
  var rank:Int;
  var username:String;
  var rating:Int;
  var ratedRounds:Int;
  var authenticated:Bool;
}

typedef MultiplayerResume =
{
  var room:MultiplayerRoom;
  var results:Null<MultiplayerResults>;
}

typedef MultiplayerLeaderboardEntry =
{
  var rank:Int;
  var username:String;
  var score:Int;
  var authenticated:Bool;
}

class MultiplayerData
{
  public static inline var STATE_LOBBY:String = 'lobby';
  public static inline var STATE_PLAYING:String = 'playing';
  public static inline var DEFAULT_RATING:Int = 1000;

  static function text(value:Dynamic, fallback:String = ''):String
  {
    return value == null ? fallback : Std.string(value);
  }

  static function number(value:Dynamic, fallback:Float = 0):Float
  {
    return Std.isOfType(value, Float) ? (value : Float) : fallback;
  }

  static function integer(value:Dynamic, fallback:Int = 0):Int
  {
    return Std.isOfType(value, Float) ? Std.int((value : Float)) : fallback;
  }

  static function flag(value:Dynamic, fallback:Bool = false):Bool
  {
    return value == null ? fallback : value == true;
  }

  static function list(value:Dynamic):Array<Dynamic>
  {
    return Std.isOfType(value, Array) ? (value : Array<Dynamic>) : [];
  }

  public static function parseMember(data:Dynamic):Null<MultiplayerMember>
  {
    if (data == null || data.id == null) return null;

    return {
      id: text(data.id),
      username: text(data.username, 'Player'),
      avatarUrl: text(data.avatarUrl),
      ready: flag(data.ready),
      finished: flag(data.finished),
      score: integer(data.score),
      combo: integer(data.combo),
      accuracy: number(data.accuracy),
      isHost: flag(data.isHost),
      away: flag(data.away),
      rating: integer(data.rating, DEFAULT_RATING)
    };
  }

  public static function parseStats(data:Dynamic):Null<MultiplayerStats>
  {
    if (data == null) return null;

    return {
      id: text(data.id),
      username: text(data.username, 'Player'),
      found: flag(data.found),
      roundsPlayed: integer(data.roundsPlayed),
      roundsWon: integer(data.roundsWon),
      songsFinished: integer(data.songsFinished),
      totalScore: integer(data.totalScore),
      bestScore: integer(data.bestScore),
      rating: integer(data.rating, DEFAULT_RATING),
      ratedRounds: integer(data.ratedRounds),
      peakRating: integer(data.peakRating, DEFAULT_RATING)
    };
  }

  public static function parseResume(data:Dynamic):Null<MultiplayerResume>
  {
    var room:Null<MultiplayerRoom> = parseRoom(data);

    if (room == null) return null;

    return {
      room: room,
      results: data.results == null ? null : parseResults(data.results)
    };
  }

  public static function describeStats(stats:MultiplayerStats):String
  {
    if (!stats.found || (stats.roundsPlayed == 0 && stats.songsFinished == 0)) return 'No songs finished on this server yet.';

    var lines:Array<String> = [
      plural(stats.songsFinished, 'song') + ' finished',
      plural(stats.roundsPlayed, 'online round') + ', ' + stats.roundsWon + ' won'
    ];

    if (stats.bestScore > 0) lines.push('Best score ' + formatScore(stats.bestScore));

    if (stats.ratedRounds > 0) lines.push('Rating ' + stats.rating + ' (best ' + stats.peakRating + ')');
    else
      lines.push('Rating ' + stats.rating + ' (play a rated round to earn one)');

    return lines.join('\n');
  }

  public static function plural(count:Int, noun:String):String
  {
    return count + ' ' + noun + (count == 1 ? '' : 's');
  }

  public static function parseRoom(data:Dynamic):Null<MultiplayerRoom>
  {
    if (data == null || data.roomId == null || data.hostId == null) return null;

    var members:Array<MultiplayerMember> = [];

    for (raw in list(data.members))
    {
      var member:Null<MultiplayerMember> = parseMember(raw);

      if (member != null) members.push(member);
    }

    var players:Array<String> = [for (raw in list(data.players)) Std.string(raw)];

    if (players.length == 0) players = [for (member in members) member.id];
    if (players.length == 0) players = [text(data.hostId)];

    return {
      roomId: text(data.roomId),
      name: text(data.name, 'Room'),
      hostId: text(data.hostId),
      isPublic: flag(data.isPublic, true),
      maxPlayers: integer(data.maxPlayers, 4),
      state: text(data.state, STATE_LOBBY),
      songId: data.songId == null ? null : text(data.songId),
      difficultyId: data.difficultyId == null ? null : text(data.difficultyId),
      variation: data.variation == null ? null : text(data.variation),
      players: players,
      members: members,
      round: integer(data.round),
      seed: integer(data.seed),
      locked: flag(data.locked),
      spectators: integer(data.spectators)
    };
  }

  public static function parseRooms(data:Dynamic):Array<MultiplayerRoomSummary>
  {
    var rooms:Array<MultiplayerRoomSummary> = [];

    if (data == null) return rooms;

    for (raw in list(data.rooms))
    {
      if (raw == null || raw.roomId == null) continue;

      rooms.push({
        roomId: text(raw.roomId),
        name: text(raw.name, 'Room'),
        hostName: text(raw.hostName),
        players: integer(raw.players),
        maxPlayers: integer(raw.maxPlayers, 4),
        state: text(raw.state, STATE_LOBBY),
        songId: text(raw.songId),
        difficultyId: text(raw.difficultyId),
        locked: flag(raw.locked),
        spectators: integer(raw.spectators),
        rating: integer(raw.rating, DEFAULT_RATING)
      });
    }

    return rooms;
  }

  public static function parseScore(data:Dynamic):Null<MultiplayerScore>
  {
    if (data == null || data.userId == null) return null;

    return {
      userId: text(data.userId),
      username: text(data.username, 'Player'),
      score: integer(data.score),
      combo: integer(data.combo),
      health: number(data.health),
      accuracy: number(data.accuracy)
    };
  }

  public static function parseResults(data:Dynamic):Null<MultiplayerResults>
  {
    if (data == null) return null;

    var rankings:Array<MultiplayerRanking> = [];
    var position:Int = 0;

    for (raw in list(data.rankings))
    {
      var score:Null<MultiplayerScore> = parseScore(raw);

      if (score == null) continue;

      position++;

      rankings.push({
        userId: score.userId,
        username: score.username,
        score: score.score,
        combo: score.combo,
        health: score.health,
        accuracy: score.accuracy,
        rank: integer(raw.rank, position),
        finished: flag(raw.finished, true),
        rating: integer(raw.rating, DEFAULT_RATING),
        ratingChange: integer(raw.ratingChange)
      });
    }

    return {
      songId: text(data.songId),
      difficultyId: text(data.difficultyId),
      variation: text(data.variation, 'default'),
      round: integer(data.round),
      rated: flag(data.rated),
      rankings: rankings
    };
  }

  public static function parseChat(data:Dynamic):Null<MultiplayerChatMessage>
  {
    if (data == null || data.text == null) return null;

    return {
      userId: text(data.userId),
      username: text(data.username, 'Player'),
      text: text(data.text),
      time: number(data.time),
      scope: text(data.scope, 'room')
    };
  }

  public static function parseLeaderboard(data:Dynamic):Array<MultiplayerLeaderboardEntry>
  {
    var entries:Array<MultiplayerLeaderboardEntry> = [];

    if (data == null) return entries;

    for (raw in list(data.entries))
    {
      if (raw == null) continue;

      entries.push({
        rank: integer(raw.rank, entries.length + 1),
        username: text(raw.username, 'Player'),
        score: integer(raw.score),
        authenticated: flag(raw.authenticated)
      });
    }

    return entries;
  }

  public static function describeError(reason:String):String
  {
    return switch (reason)
    {
      case 'not_found': 'That room does not exist. Check the code.';
      case 'full': 'That room is full.';
      case 'in_progress': 'That room is in the middle of a song.';
      case 'already_in_room': 'You are already in a room.';
      case 'not_in_room': 'You are not in a room.';
      case 'not_host': 'Only the host can do that.';
      case 'no_song': 'Pick a song first.';
      case 'not_enough_players': 'More players are needed to start.';
      case 'not_all_ready': 'Everyone has to be ready.';
      case 'invalid_song': 'That song cannot be used.';
      case 'room_limit': 'The server has too many rooms right now.';
      case 'chat_cooldown': 'Wait a moment before you chat again.';
      case 'unknown_member': 'That player is not in the room.';
      case 'rate_limited': 'You are sending too much. Slow down.';
      case 'server_full': 'The server is full.';
      case 'kicked': 'You were removed from the room.';
      case 'wrong_password': 'That room needs a password, and it was not the right one.';
      case 'spectators_full': 'That room has no more places for spectators.';
      case 'muted': 'You are muted and cannot chat for now.';
      case 'report_cooldown': 'Wait a little before you report again.';
      case 'banned': 'You are banned from this server.';
      case 'cheating': 'You were removed from the room because your scores were not valid.';
      case 'closed_by_admin': 'The room was closed by the server.';
      case 'timeout': 'The player did not come back in time.';
      case 'score_rejected': 'That score was rejected by the server.';
      case 'logged_in_elsewhere': 'You logged in from another place.';
      case 'disconnected': 'The connection to the server was lost.';
      case 'not_joined': 'The server has not accepted you yet.';
      default: 'The server said: ' + reason;
    };
  }

  public static function formatCode(roomId:String):String
  {
    var clean:String = StringTools.trim(roomId).toUpperCase();

    return clean.length > 3 ? clean.substr(0, 3) + ' ' + clean.substr(3) : clean;
  }

  public static function normalizeCode(input:String):String
  {
    var result:StringBuf = new StringBuf();

    for (i in 0...input.length)
    {
      var character:String = input.charAt(i).toUpperCase();

      if (character == ' ' || character == '-') continue;

      result.add(character);
    }

    return result.toString();
  }

  public static function memberById(room:MultiplayerRoom, id:String):Null<MultiplayerMember>
  {
    for (member in room.members)
    {
      if (member.id == id) return member;
    }

    return null;
  }

  public static function nameOf(room:Null<MultiplayerRoom>, id:String):String
  {
    if (room == null) return id;

    var member:Null<MultiplayerMember> = memberById(room, id);

    return member != null ? member.username : id;
  }

  public static function everyoneReady(room:MultiplayerRoom):Bool
  {
    for (member in room.members)
    {
      if (member.away) return false;

      if (member.id != room.hostId && !member.ready) return false;
    }

    return true;
  }

  public static function formatScore(score:Int):String
  {
    var digits:String = Std.string(Std.int(Math.abs(score)));
    var result:String = '';

    while (digits.length > 3)
    {
      result = ',' + digits.substr(digits.length - 3) + result;
      digits = digits.substr(0, digits.length - 3);
    }

    return (score < 0 ? '-' : '') + digits + result;
  }

  public static function formatRatingChange(change:Int):String
  {
    return (change > 0 ? '+' : '') + change;
  }

  public static function parseRatings(data:Dynamic):Array<MultiplayerRatingEntry>
  {
    var entries:Array<MultiplayerRatingEntry> = [];

    if (data == null) return entries;

    for (raw in list(data.entries))
    {
      if (raw == null) continue;

      entries.push({
        rank: integer(raw.rank, entries.length + 1),
        username: text(raw.username, 'Player'),
        rating: integer(raw.rating, DEFAULT_RATING),
        ratedRounds: integer(raw.ratedRounds),
        authenticated: flag(raw.authenticated)
      });
    }

    return entries;
  }

  public static function describeLive(scores:Array<MultiplayerScore>):String
  {
    if (scores.length == 0) return 'Waiting for the first scores...';

    return [for (score in sortScoreboard(scores)) score.username + ' ' + formatScore(score.score)].join('   ');
  }

  public static function describeResults(results:MultiplayerResults):String
  {
    var lines:Array<String> = [];

    for (entry in results.rankings)
    {
      lines.push(entry.rank
        + '. '
        + entry.username
        + '  '
        + formatScore(entry.score)
        + '  '
        + (Std.int(entry.accuracy * 10) / 10)
        + '%'
        + (entry.finished ? '' : '  (did not finish)')
        + (results.rated ? '  ' + formatRatingChange(entry.ratingChange) + ' (' + entry.rating + ')' : ''));
    }

    return lines.join('\n');
  }

  public static function sortScoreboard(scores:Array<MultiplayerScore>):Array<MultiplayerScore>
  {
    var sorted:Array<MultiplayerScore> = scores.copy();

    sorted.sort((a, b) -> b.score - a.score);

    return sorted;
  }
}
