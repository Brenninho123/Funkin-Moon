import funkin.online.OnlineText;

class OnlineTextTests
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
    Sys.println('failures');

    var reasons:Array<String> = [
      'discord_not_configured', 'access_denied', 'missing_code', 'expired', 'token_exchange_failed', 'profile_fetch_failed', 'logged_in_elsewhere',
      'not_connected', 'disconnected', 'already_authenticated', 'bad_url', 'invalid_token'
    ];
    var known:Bool = true;

    for (reason in reasons)
    {
      if (OnlineText.authFailure(reason).indexOf('Could not log in') == 0) known = false;
    }

    check('every known login failure has a sentence', known);
    check('an unknown failure keeps its reason', OnlineText.authFailure('weird') == 'Could not log in (weird).');

    Sys.println('discord panel');

    var guest = OnlineText.discordPanel('LoggedOut', true, true, '', '', false);
    check('a guest can log in', guest.action == OnlineText.ACTION_LOGIN && guest.heading == 'Guest' && guest.actionLabel == 'Log in with Discord' && guest.kind == OnlineText.KIND_INFO);

    var off = OnlineText.discordPanel('LoggedOut', true, false, '', '', false);
    check('login is not offered when the server has it off', off.action == OnlineText.ACTION_NONE && off.status.indexOf('turned off') > 0 && off.hint.indexOf('server/README.md') > 0);

    var offline = OnlineText.discordPanel('LoggedOut', false, true, '', '', false);
    check('without a connection the button connects', offline.action == OnlineText.ACTION_CONNECT && offline.kind == OnlineText.KIND_ERROR);

    var requesting = OnlineText.discordPanel('Requesting', true, true, '', '', false);
    check('while asking the server login can be cancelled', requesting.action == OnlineText.ACTION_CANCEL && !requesting.canCopyLink);

    var waiting = OnlineText.discordPanel('WaitingForBrowser', true, true, '', '', true);
    check('while waiting for the browser the link can be copied', waiting.action == OnlineText.ACTION_CANCEL && waiting.canCopyLink && waiting.hint.indexOf('Copy the link') >= 0);
    check('without a link nothing can be copied', !OnlineText.discordPanel('WaitingForBrowser', true, true, '', '', false).canCopyLink);

    var done = OnlineText.discordPanel('LoggedIn', true, true, 'Nelly', '', false);
    check('a logged in player sees the name and can log out', done.heading == 'Nelly' && done.action == OnlineText.ACTION_LOGOUT && done.kind == OnlineText.KIND_OK);
    check('a logged in player stays logged in while the connection drops', OnlineText.discordPanel('LoggedIn', false, true, 'Nelly', '', false).action == OnlineText.ACTION_LOGOUT);

    var failed = OnlineText.discordPanel('Failed', true, true, '', 'access_denied', false);
    check('a failed login can be tried again', failed.action == OnlineText.ACTION_LOGIN && failed.actionLabel == 'Try again' && failed.status == 'The login was cancelled in Discord.' && failed.kind == OnlineText.KIND_ERROR);
    check('a server without discord cannot be retried', OnlineText.discordPanel('Failed', true, false, '', 'discord_not_configured', false).action == OnlineText.ACTION_NONE);

    Sys.println('lines');

    check('the connection line', OnlineText.connection('Connected', '127.0.0.1:7777', 3) == 'Connected to 127.0.0.1:7777.   3 players online.' && OnlineText.connection('Connected', 'x', 1).indexOf('1 player online') > 0);
    check('connecting and offline lines', OnlineText.connection('Connecting', 'host:1', 0) == 'Connecting to host:1...' && OnlineText.connection('Disconnected', 'x', 0) == 'Not connected.' && OnlineText.connection('Reconnecting', 'x', 0).indexOf('trying again') > 0);
    check('player lines mark accounts and you', OnlineText.playerLine('Ann', true, true) == '* Ann (you)' && OnlineText.playerLine('Bob', false, false) == 'Bob');
    check('initials', OnlineText.initials(' nelly') == 'N' && OnlineText.initials('') == '?');

    Sys.println(failures == 0 ? '\nall ' + checks + ' checks passed' : '\n' + failures + ' of ' + checks + ' checks failed');
    Sys.exit(failures == 0 ? 0 : 1);
  }
}
