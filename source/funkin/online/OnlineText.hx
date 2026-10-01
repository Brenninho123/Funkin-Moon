package funkin.online;

typedef DiscordPanel =
{
  var heading:String;
  var status:String;
  var hint:String;
  var action:String;
  var actionLabel:String;
  var kind:String;
  var canCopyLink:Bool;
}

class OnlineText
{
  public static inline var ACTION_NONE:String = 'none';
  public static inline var ACTION_LOGIN:String = 'login';
  public static inline var ACTION_CANCEL:String = 'cancel';
  public static inline var ACTION_LOGOUT:String = 'logout';
  public static inline var ACTION_CONNECT:String = 'connect';

  public static inline var KIND_OK:String = 'ok';
  public static inline var KIND_INFO:String = 'info';
  public static inline var KIND_ERROR:String = 'error';

  public static function authFailure(reason:String):String
  {
    return switch (reason)
    {
      case 'discord_not_configured': 'This server has Discord login turned off.';
      case 'access_denied': 'The login was cancelled in Discord.';
      case 'missing_code': 'Discord did not send a login code.';
      case 'expired': 'The login link expired. Start it again.';
      case 'token_exchange_failed' | 'profile_fetch_failed': 'Discord rejected the login. Try again.';
      case 'logged_in_elsewhere': 'This account logged in from another place.';
      case 'not_connected' | 'disconnected': 'The connection to the server was lost.';
      case 'already_authenticated': 'You are already logged in.';
      case 'bad_url': 'The server sent a login link that cannot be opened.';
      case 'invalid_token': 'Your saved login is no longer valid.';
      default: 'Could not log in (' + reason + ').';
    };
  }

  public static function discordPanel(state:String, connected:Bool, enabled:Bool, username:String, failure:String, hasLink:Bool):DiscordPanel
  {
    if (state == 'LoggedIn')
    {
      return {
        heading: username,
        status: 'Logged in with Discord.',
        hint: 'The leaderboard and the rooms show your Discord name.',
        action: ACTION_LOGOUT,
        actionLabel: 'Log out',
        kind: KIND_OK,
        canCopyLink: false
      };
    }

    if (state == 'Requesting')
    {
      return {
        heading: 'Discord',
        status: 'Contacting the server...',
        hint: 'A page should open in your browser in a moment.',
        action: ACTION_CANCEL,
        actionLabel: 'Cancel',
        kind: KIND_INFO,
        canCopyLink: false
      };
    }

    if (state == 'WaitingForBrowser')
    {
      return {
        heading: 'Discord',
        status: 'Finish logging in with Discord in your browser.',
        hint: hasLink ? 'Did the page not open, or did you close it? Copy the link or open it again.' : 'Waiting for the login to finish.',
        action: ACTION_CANCEL,
        actionLabel: 'Cancel',
        kind: KIND_INFO,
        canCopyLink: hasLink
      };
    }

    if (!connected)
    {
      return {
        heading: 'Discord',
        status: 'Not connected to the server.',
        hint: 'Connect first, then log in.',
        action: ACTION_CONNECT,
        actionLabel: 'Connect',
        kind: KIND_ERROR,
        canCopyLink: false
      };
    }

    if (state == 'Failed')
    {
      var unavailable:Bool = failure == 'discord_not_configured';

      return {
        heading: 'Discord',
        status: authFailure(failure),
        hint: unavailable ? 'The owner of the server has to set up a Discord application, see server/README.md.' : 'You can try again, or keep playing as a guest.',
        action: unavailable ? ACTION_NONE : ACTION_LOGIN,
        actionLabel: 'Try again',
        kind: KIND_ERROR,
        canCopyLink: false
      };
    }

    if (!enabled)
    {
      return {
        heading: 'Discord',
        status: 'This server has Discord login turned off.',
        hint: 'You can still play as a guest. The owner of the server sets login up with a Discord application, see server/README.md.',
        action: ACTION_NONE,
        actionLabel: 'Log in with Discord',
        kind: KIND_INFO,
        canCopyLink: false
      };
    }

    return {
      heading: 'Guest',
      status: 'You are not logged in.',
      hint: 'Log in to play with your Discord name and avatar, and to keep your scores under your account.',
      action: ACTION_LOGIN,
      actionLabel: 'Log in with Discord',
      kind: KIND_INFO,
      canCopyLink: false
    };
  }

  public static function connection(state:String, address:String, players:Int):String
  {
    return switch (state)
    {
      case 'Connected': 'Connected to ' + address + '.   ' + players + ' player' + (players == 1 ? '' : 's') + ' online.';
      case 'Connecting': 'Connecting to ' + address + '...';
      case 'Reconnecting': 'The server is not answering, trying again...';
      default: 'Not connected.';
    };
  }

  public static function playerLine(name:String, authenticated:Bool, isYou:Bool):String
  {
    return (authenticated ? '* ' : '') + name + (isYou ? ' (you)' : '');
  }

  public static function initials(name:String):String
  {
    var clean:String = StringTools.trim(name);

    return clean == '' ? '?' : clean.charAt(0).toUpperCase();
  }
}
