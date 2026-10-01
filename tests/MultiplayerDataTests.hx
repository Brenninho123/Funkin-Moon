import funkin.online.play.MultiplayerData;
import haxe.Json;

class MultiplayerDataTests
{
  static var checks:Int = 0;
  static var failures:Int = 0;

  static function check(name:String, condition:Bool, ?detail:String):Void
  {
    checks++;

    if (condition) return;

    failures++;
    Sys.println('FAIL: ' + name + (detail != null ? '  (' + detail + ')' : ''));
  }

  static function main():Void
  {
    var roomJson:String = '{"roomId":"AB3DE","name":"Test","hostId":"p1","isPublic":true,"maxPlayers":4,"state":"lobby","songId":null,"difficultyId":null,"variation":null,"players":["p1","p2"],"members":[{"id":"p1","username":"Host","avatarUrl":"","ready":false,"finished":false,"score":0,"combo":0,"accuracy":0,"isHost":true},{"id":"p2","username":"Guest","ready":true}],"round":0}';

    Sys.println('rooms');

    var room = MultiplayerData.parseRoom(Json.parse(roomJson));
    check('a room is parsed', room != null && room.roomId == 'AB3DE' && room.hostId == 'p1' && room.maxPlayers == 4);
    check('members are parsed', room.members.length == 2 && room.members[0].isHost && room.members[1].ready && room.members[1].username == 'Guest');
    check('players are listed by id', room.players.join(',') == 'p1,p2');
    check('a missing song stays null', room.songId == null && room.difficultyId == null);
    check('a room without ids is rejected', MultiplayerData.parseRoom(Json.parse('{"name":"x"}')) == null && MultiplayerData.parseRoom(null) == null);

    var bare = MultiplayerData.parseRoom(Json.parse('{"roomId":"AAAAA","hostId":"p9"}'));
    check('an old style room still works', bare != null && bare.players.join(',') == 'p9' && bare.state == 'lobby' && bare.members.length == 0);
    var fromMembers = MultiplayerData.parseRoom(Json.parse('{"roomId":"AAAAA","hostId":"p9","members":[{"id":"p9","username":"x"},{"id":"p8","username":"y"}]}'));
    check('players fall back to the members', fromMembers.players.join(',') == 'p9,p8');
    check('a member without an id is skipped', MultiplayerData.parseMember(Json.parse('{"username":"x"}')) == null);

    check('members are found by id', MultiplayerData.memberById(room, 'p2').username == 'Guest' && MultiplayerData.memberById(room, 'zz') == null);
    check('names fall back to the id', MultiplayerData.nameOf(room, 'p1') == 'Host' && MultiplayerData.nameOf(room, 'zz') == 'zz' && MultiplayerData.nameOf(null, 'q') == 'q');
    check('the host does not need to be ready', MultiplayerData.everyoneReady(room));
    room.members[1].ready = false;
    check('a waiting player blocks the start', !MultiplayerData.everyoneReady(room));

    var summaries = MultiplayerData.parseRooms(Json.parse('{"rooms":[{"roomId":"AAAAA","name":"One","hostName":"Ann","players":2,"maxPlayers":4,"state":"playing","songId":"bopeebo","difficultyId":"hard"},{"name":"broken"},null]}'));
    check('room summaries are parsed', summaries.length == 1 && summaries[0].hostName == 'Ann' && summaries[0].players == 2 && summaries[0].state == 'playing' && summaries[0].songId == 'bopeebo');
    check('a missing list is empty', MultiplayerData.parseRooms(null).length == 0 && MultiplayerData.parseRooms(Json.parse('{}')).length == 0);

    Sys.println('scores and results');

    var score = MultiplayerData.parseScore(Json.parse('{"userId":"p2","username":"Guest","score":1200,"combo":5,"health":1.2,"accuracy":98.5}'));
    check('a score is parsed', score != null && score.score == 1200 && score.combo == 5 && score.health == 1.2 && score.accuracy == 98.5);
    check('a score without an id is rejected', MultiplayerData.parseScore(Json.parse('{"score":1}')) == null);
    check('missing numbers become zero', MultiplayerData.parseScore(Json.parse('{"userId":"x"}')).score == 0);

    var results = MultiplayerData.parseResults(Json.parse('{"songId":"bopeebo","difficultyId":"hard","variation":"default","round":2,"rankings":[{"userId":"p2","username":"Guest","score":8000,"accuracy":97.5,"rank":1,"finished":true},{"userId":"p1","username":"Host","score":5000,"accuracy":91.22,"rank":2,"finished":false},{"nothing":1}]}'));
    check('results are parsed', results != null && results.round == 2 && results.rankings.length == 2 && results.rankings[0].rank == 1 && !results.rankings[1].finished);
    check('results are described for the screen', MultiplayerData.describeResults(results) == '1. Guest  8,000  97.5%\n2. Host  5,000  91.2%  (did not finish)', MultiplayerData.describeResults(results));
    check('results without a list are empty', MultiplayerData.parseResults(Json.parse('{"songId":"x"}')).rankings.length == 0 && MultiplayerData.parseResults(null) == null);

    var board = MultiplayerData.sortScoreboard([
      {userId: 'a', username: 'A', score: 10, combo: 0, health: 0, accuracy: 0},
      {userId: 'b', username: 'B', score: 30, combo: 0, health: 0, accuracy: 0},
      {userId: 'c', username: 'C', score: 20, combo: 0, health: 0, accuracy: 0}
    ]);
    check('the scoreboard is ordered by score', board.map((s) -> s.userId).join('') == 'bca');

    check('scores get thousands separators', MultiplayerData.formatScore(0) == '0' && MultiplayerData.formatScore(999) == '999' && MultiplayerData.formatScore(1000) == '1,000' && MultiplayerData.formatScore(1234567) == '1,234,567' && MultiplayerData.formatScore(-4500) == '-4,500');

    Sys.println('chat, codes and errors');

    var chat = MultiplayerData.parseChat(Json.parse('{"userId":"p1","username":"Host","text":"hi","time":5,"scope":"global"}'));
    check('chat is parsed', chat != null && chat.text == 'hi' && chat.scope == 'global' && chat.username == 'Host');
    check('chat without text is rejected', MultiplayerData.parseChat(Json.parse('{"userId":"p1"}')) == null);
    check('chat defaults to the room scope', MultiplayerData.parseChat(Json.parse('{"text":"x"}')).scope == 'room');

    check('codes are normalized', MultiplayerData.normalizeCode(' ab-3 de ') == 'AB3DE' && MultiplayerData.normalizeCode('') == '');
    check('codes are shown in two groups', MultiplayerData.formatCode('ab3de') == 'AB3 DE' && MultiplayerData.formatCode('ab') == 'AB');

    var entries = MultiplayerData.parseLeaderboard(Json.parse('{"entries":[{"rank":1,"username":"A","score":900,"authenticated":true},{"username":"B","score":800}]}'));
    check('leaderboard entries are parsed', entries.length == 2 && entries[0].authenticated && entries[1].rank == 2 && entries[1].score == 800);

    var everyReason:Bool = true;

    for (reason in ['not_found', 'full', 'in_progress', 'already_in_room', 'not_in_room', 'not_host', 'no_song', 'not_enough_players', 'not_all_ready', 'invalid_song', 'room_limit', 'chat_cooldown', 'unknown_member', 'rate_limited', 'server_full', 'kicked', 'disconnected', 'not_joined', 'banned', 'cheating', 'closed_by_admin', 'timeout', 'score_rejected', 'logged_in_elsewhere'])
    {
      if (MultiplayerData.describeError(reason).indexOf('The server said') == 0) everyReason = false;
    }

    check('every known server error has a sentence', everyReason);
    check('unknown errors keep their reason', MultiplayerData.describeError('weird') == 'The server said: weird');

    Sys.println('stats and resuming');

    var stats = MultiplayerData.parseStats(Json.parse('{"id":"d1","username":"Nelly","found":true,"roundsPlayed":12,"roundsWon":5,"songsFinished":30,"totalScore":900000,"bestScore":123456}'));
    check('stats are parsed', stats != null && stats.found && stats.roundsPlayed == 12 && stats.roundsWon == 5 && stats.songsFinished == 30 && stats.bestScore == 123456 && stats.username == 'Nelly');
    check('stats without data are rejected', MultiplayerData.parseStats(null) == null);
    check('missing stats fields default to zero', MultiplayerData.parseStats(Json.parse('{"id":"x"}')).roundsPlayed == 0);
    check('stats are described', MultiplayerData.describeStats(stats) == '30 songs finished\n12 online rounds, 5 won\nBest score 123,456', MultiplayerData.describeStats(stats));
    check('singular nouns are used', MultiplayerData.plural(1, 'song') == '1 song' && MultiplayerData.plural(0, 'song') == '0 songs' && MultiplayerData.plural(2, 'song') == '2 songs');
    check('a player without history gets a friendly line', MultiplayerData.describeStats(MultiplayerData.parseStats(Json.parse('{"id":"x","found":false}'))) == 'No songs finished on this server yet.');

    var away = MultiplayerData.parseMember(Json.parse('{"id":"p2","username":"Guest","away":true}'));
    check('the away flag is parsed', away != null && away.away && !MultiplayerData.parseMember(Json.parse('{"id":"p3"}')).away);

    var resume = MultiplayerData.parseResume(Json.parse('{"roomId":"AB3DE","hostId":"p1","members":[{"id":"p1"}],"state":"lobby","results":{"songId":"bopeebo","difficultyId":"hard","round":2,"rankings":[{"userId":"p1","username":"Host","score":10,"rank":1,"finished":true}]}}'));
    check('a resumed room carries the missed results', resume != null && resume.room.roomId == 'AB3DE' && resume.results != null && resume.results.rankings.length == 1 && resume.results.round == 2);
    check('a resumed room without results is fine', MultiplayerData.parseResume(Json.parse('{"roomId":"AB3DE","hostId":"p1","members":[]}')).results == null);
    check('a resume without a room is rejected', MultiplayerData.parseResume(Json.parse('{"state":"lobby"}')) == null);

    var awayRoom = MultiplayerData.parseRoom(Json.parse('{"roomId":"AB3DE","hostId":"p1","members":[{"id":"p1"},{"id":"p2","ready":true,"away":true}]}'));
    check('an away player keeps the round from starting', !MultiplayerData.everyoneReady(awayRoom));

    Sys.println(failures == 0 ? '\nall ' + checks + ' checks passed' : '\n' + failures + ' of ' + checks + ' checks failed');
    Sys.exit(failures == 0 ? 0 : 1);
  }
}
