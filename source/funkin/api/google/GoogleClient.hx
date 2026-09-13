package funkin.api.google;

#if FEATURE_GOOGLE_LOGIN

typedef GoogleClientInitOptions =
{
  var clientId:String;
  var ?clientSecret:String;
  var ?scopes:Array<String>;
  var ?redirectPort:Int;
}

typedef GoogleClientSession =
{
  var ?refreshToken:String;
  var ?userId:String;
  var ?displayName:String;
  var ?email:String;
  var ?photoUrl:String;
}

#if android

typedef GoogleClientEvent =
{
  var type:String;
  var ?message:String;
  var ?userId:String;
  var ?displayName:String;
  var ?email:String;
  var ?photoUrl:String;
  var ?idToken:String;
  var ?accessToken:String;
}

class GoogleClient
{
  static inline var BRIDGE_CLASS:String = 'com/moonengine/google/GoogleAuthBridge';
  static inline var POLL_INTERVAL:Float = 0.5;

  public static var instance(get, never):GoogleClient;

  static var _instance:Null<GoogleClient> = null;

  static function get_instance():GoogleClient
  {
    if (GoogleClient._instance == null) _instance = new GoogleClient();
    if (GoogleClient._instance == null) throw 'Could not initialize singleton GoogleClient!';
    return GoogleClient._instance;
  }

  public var isInitialized(default, null):Bool = false;
  public var isSignedIn(default, null):Bool = false;
  public var isAuthenticating(default, null):Bool = false;

  public var userId(default, null):Null<String> = null;
  public var displayName(default, null):Null<String> = null;
  public var email(default, null):Null<String> = null;
  public var photoUrl(default, null):Null<String> = null;
  public var idToken(default, null):Null<String> = null;
  public var accessToken(default, null):Null<String> = null;

  public var onSignInSuccess:Null<Void->Void> = null;
  public var onSignInFailure:Null<String->Void> = null;
  public var onSignedOut:Null<Void->Void> = null;
  public var onRevoked:Null<Void->Void> = null;

  var jniConfigure:Null<Dynamic> = null;
  var jniSignIn:Null<Dynamic> = null;
  var jniSignInSilently:Null<Dynamic> = null;
  var jniSignOut:Null<Dynamic> = null;
  var jniRevokeAccess:Null<Dynamic> = null;
  var jniPollEvents:Null<Dynamic> = null;

  var pollTimer:Null<flixel.util.FlxTimer> = null;

  private function new()
  {
    bindNatives();
  }

  function bindNatives():Void
  {
    jniConfigure = lime.system.JNI.createStaticMethod(BRIDGE_CLASS, 'configure', '(Ljava/lang/String;Ljava/lang/String;)V');
    jniSignIn = lime.system.JNI.createStaticMethod(BRIDGE_CLASS, 'signIn', '()V');
    jniSignInSilently = lime.system.JNI.createStaticMethod(BRIDGE_CLASS, 'signInSilently', '()V');
    jniSignOut = lime.system.JNI.createStaticMethod(BRIDGE_CLASS, 'signOut', '()V');
    jniRevokeAccess = lime.system.JNI.createStaticMethod(BRIDGE_CLASS, 'revokeAccess', '()V');
    jniPollEvents = lime.system.JNI.createStaticMethod(BRIDGE_CLASS, 'pollEvents', '()Ljava/lang/String;');
  }

  public function init(options:GoogleClientInitOptions):Void
  {
    if (isInitialized)
    {
      FlxG.log.warn('[Google] init() called but the client is already initialized.');
      return;
    }

    final scopes:Array<String> = options.scopes ?? ['openid', 'email', 'profile'];
    jniConfigure(options.clientId, scopes.join(' '));

    isInitialized = true;
    startPolling();
  }

  public function shutdown():Void
  {
    if (!isInitialized) return;

    isInitialized = false;

    if (pollTimer != null)
    {
      pollTimer.cancel();
      pollTimer = null;
    }
  }

  public function signIn():Void
  {
    if (!requireInitialized()) return;
    if (isSignedIn || isAuthenticating) return;

    isAuthenticating = true;
    jniSignIn();
  }

  public function signInSilently():Void
  {
    if (!requireInitialized()) return;
    if (isSignedIn || isAuthenticating) return;

    isAuthenticating = true;
    jniSignInSilently();
  }

  public function signOut():Void
  {
    if (!requireInitialized()) return;

    jniSignOut();
    clearSession();

    if (onSignedOut != null) onSignedOut();
  }

  public function revokeAccess():Void
  {
    if (!requireInitialized()) return;

    jniRevokeAccess();
    clearSession();

    if (onRevoked != null) onRevoked();
  }

  public function serializeSession():String
  {
    final session:GoogleClientSession = {
      userId: userId,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl
    };
    return haxe.Json.stringify(session);
  }

  public function restoreSession(raw:String):Bool
  {
    try
    {
      final parsed:GoogleClientSession = haxe.Json.parse(raw);
      userId = parsed.userId;
      displayName = parsed.displayName;
      email = parsed.email;
      photoUrl = parsed.photoUrl;
      return userId != null;
    }
    catch (e:Dynamic)
    {
      return false;
    }
  }

  function requireInitialized():Bool
  {
    if (!isInitialized)
    {
      FlxG.log.warn('[Google] Action requested before init().');
      return false;
    }
    return true;
  }

  function clearSession():Void
  {
    isSignedIn = false;
    isAuthenticating = false;
    userId = null;
    displayName = null;
    email = null;
    photoUrl = null;
    idToken = null;
    accessToken = null;
  }

  function startPolling():Void
  {
    if (pollTimer != null) return;
    pollTimer = new flixel.util.FlxTimer().start(POLL_INTERVAL, pollEvents, 0);
  }

  function pollEvents(_:flixel.util.FlxTimer):Void
  {
    final raw:String = jniPollEvents();
    if (raw == null || raw == '' || raw == '[]') return;

    var events:Array<GoogleClientEvent>;
    try
    {
      events = haxe.Json.parse(raw);
    }
    catch (e:Dynamic)
    {
      FlxG.log.error('[Google] Failed to parse event payload: $e');
      return;
    }

    for (event in events) handleEvent(event);
  }

  function handleEvent(event:GoogleClientEvent):Void
  {
    switch (event.type)
    {
      case 'sign_in_success':
        isAuthenticating = false;
        isSignedIn = true;
        userId = event.userId;
        displayName = event.displayName;
        email = event.email;
        photoUrl = event.photoUrl;
        idToken = event.idToken;
        accessToken = event.accessToken;
        if (onSignInSuccess != null) onSignInSuccess();

      case 'sign_in_failure':
        isAuthenticating = false;
        isSignedIn = false;
        if (onSignInFailure != null) onSignInFailure(event.message ?? 'Unknown error.');

      default:
        FlxG.log.warn('[Google] Received unknown event type "${event.type}".');
    }
  }
}

#elseif sys

typedef GoogleClientTokenResponse =
{
  var access_token:String;
  var ?refresh_token:String;
  var ?id_token:String;
  var expires_in:Float;
}

typedef GoogleClientUserInfo =
{
  var sub:String;
  var ?name:String;
  var ?email:String;
  var ?picture:String;
}

class GoogleClient
{
  static inline var AUTH_ENDPOINT:String = 'https://accounts.google.com/o/oauth2/v2/auth';
  static inline var TOKEN_ENDPOINT:String = 'https://oauth2.googleapis.com/token';
  static inline var REVOKE_ENDPOINT:String = 'https://oauth2.googleapis.com/revoke';
  static inline var USERINFO_ENDPOINT:String = 'https://www.googleapis.com/oauth2/v3/userinfo';
  static inline var TOKEN_EXPIRY_SAFETY_MARGIN:Float = 60.0;

  public static var instance(get, never):GoogleClient;

  static var _instance:Null<GoogleClient> = null;

  static function get_instance():GoogleClient
  {
    if (GoogleClient._instance == null) _instance = new GoogleClient();
    if (GoogleClient._instance == null) throw 'Could not initialize singleton GoogleClient!';
    return GoogleClient._instance;
  }

  public var isInitialized(default, null):Bool = false;
  public var isSignedIn(default, null):Bool = false;
  public var isAuthenticating(default, null):Bool = false;

  public var userId(default, null):Null<String> = null;
  public var displayName(default, null):Null<String> = null;
  public var email(default, null):Null<String> = null;
  public var photoUrl(default, null):Null<String> = null;
  public var idToken(default, null):Null<String> = null;
  public var accessToken(default, null):Null<String> = null;

  public var onSignInSuccess:Null<Void->Void> = null;
  public var onSignInFailure:Null<String->Void> = null;
  public var onSignedOut:Null<Void->Void> = null;
  public var onRevoked:Null<Void->Void> = null;
  public var onTokenRefreshed:Null<Void->Void> = null;

  var clientId:String = '';
  var clientSecret:Null<String> = null;
  var scopes:Array<String> = ['openid', 'email', 'profile'];
  var redirectPort:Int = 51235;

  var refreshToken:Null<String> = null;
  var pkceVerifier:String = '';
  var tokenExpiresAt:Float = 0;

  private function new() {}

  public function init(options:GoogleClientInitOptions):Void
  {
    if (isInitialized)
    {
      FlxG.log.warn('[Google] init() called but the client is already initialized.');
      return;
    }

    clientId = options.clientId;
    clientSecret = options.clientSecret;
    scopes = options.scopes ?? ['openid', 'email', 'profile'];
    redirectPort = options.redirectPort ?? 51235;

    isInitialized = true;
  }

  public function shutdown():Void
  {
    isInitialized = false;
  }

  public function signIn():Void
  {
    if (!requireInitialized()) return;
    if (isSignedIn || isAuthenticating) return;

    isAuthenticating = true;

    final state:String = randomString(24);
    pkceVerifier = randomString(64);
    final challenge:String = base64UrlEncode(haxe.crypto.Sha256.make(haxe.io.Bytes.ofString(pkceVerifier)));
    final redirectUri:String = 'http://127.0.0.1:$redirectPort/callback';
    final url:String = buildAuthUrl(state, challenge, redirectUri);

    sys.thread.Thread.create(() -> runLoopbackServer(redirectPort, state, redirectUri));

    lime.system.System.openURL(url);
  }

  public function signInSilently():Void
  {
    if (!requireInitialized()) return;
    if (isSignedIn) return;

    if (refreshToken == null)
    {
      if (onSignInFailure != null) onSignInFailure('No cached credentials.');
      return;
    }

    isAuthenticating = true;
    refreshAccessToken();
  }

  public function signOut():Void
  {
    clearSession();
    if (onSignedOut != null) onSignedOut();
  }

  public function revokeAccess():Void
  {
    final tokenToRevoke:Null<String> = refreshToken ?? accessToken;

    if (tokenToRevoke != null)
    {
      final http = new haxe.Http(REVOKE_ENDPOINT);
      http.setParameter('token', tokenToRevoke);
      http.onData = function(_) {};
      http.onError = function(message) FlxG.log.warn('[Google] Revoke request failed: $message');
      http.request(true);
    }

    clearSession();

    if (onRevoked != null) onRevoked();
  }

  public function getFreshAccessToken(callback:Null<String>->Void):Void
  {
    if (accessToken == null || haxe.Timer.stamp() >= (tokenExpiresAt - TOKEN_EXPIRY_SAFETY_MARGIN))
    {
      if (refreshToken == null)
      {
        callback(null);
        return;
      }

      refreshAccessToken();
    }

    callback(accessToken);
  }

  public function serializeSession():String
  {
    final session:GoogleClientSession = {
      refreshToken: refreshToken,
      userId: userId,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl
    };
    return haxe.Json.stringify(session);
  }

  public function restoreSession(raw:String):Bool
  {
    try
    {
      final parsed:GoogleClientSession = haxe.Json.parse(raw);
      refreshToken = parsed.refreshToken;
      userId = parsed.userId;
      displayName = parsed.displayName;
      email = parsed.email;
      photoUrl = parsed.photoUrl;
      return refreshToken != null;
    }
    catch (e:Dynamic)
    {
      return false;
    }
  }

  function requireInitialized():Bool
  {
    if (!isInitialized)
    {
      FlxG.log.warn('[Google] Action requested before init().');
      return false;
    }
    return true;
  }

  function clearSession():Void
  {
    isSignedIn = false;
    isAuthenticating = false;
    userId = null;
    displayName = null;
    email = null;
    photoUrl = null;
    idToken = null;
    accessToken = null;
    refreshToken = null;
    tokenExpiresAt = 0;
  }

  function buildAuthUrl(state:String, codeChallenge:String, redirectUri:String):String
  {
    final params:Array<String> = [
      'client_id=' + StringTools.urlEncode(clientId),
      'redirect_uri=' + StringTools.urlEncode(redirectUri),
      'response_type=code',
      'scope=' + StringTools.urlEncode(scopes.join(' ')),
      'access_type=offline',
      'prompt=select_account',
      'state=' + StringTools.urlEncode(state),
      'code_challenge=' + StringTools.urlEncode(codeChallenge),
      'code_challenge_method=S256'
    ];
    return AUTH_ENDPOINT + '?' + params.join('&');
  }

  function runLoopbackServer(port:Int, expectedState:String, redirectUri:String):Void
  {
    var socket:Null<sys.net.Socket> = null;

    try
    {
      socket = new sys.net.Socket();
      socket.bind(new sys.net.Host('127.0.0.1'), port);
      socket.listen(1);

      final client:sys.net.Socket = socket.accept();
      final requestLine:String = client.input.readLine();
      final requestParts:Array<String> = requestLine.split(' ');
      final path:String = requestParts.length > 1 ? requestParts[1] : '';
      final query:Map<String, String> = parseQueryString(path);

      final responseBody:String = '<html><body>You can close this window and return to the game.</body></html>';
      final response:String = 'HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: '
        + Std.string(responseBody.length)
        + '\r\nConnection: close\r\n\r\n'
        + responseBody;

      client.output.writeString(response);
      client.close();
      socket.close();

      handleRedirect(query, expectedState, redirectUri);
    }
    catch (e:Dynamic)
    {
      if (socket != null) socket.close();
      isAuthenticating = false;
      if (onSignInFailure != null) onSignInFailure('Local server error: $e');
    }
  }

  function parseQueryString(path:String):Map<String, String>
  {
    final result:Map<String, String> = new Map();
    final questionIndex:Int = path.indexOf('?');
    if (questionIndex == -1) return result;

    final rawQuery:String = path.substring(questionIndex + 1);
    for (pair in rawQuery.split('&'))
    {
      final eqIndex:Int = pair.indexOf('=');
      if (eqIndex == -1) continue;

      final key:String = StringTools.urlDecode(pair.substring(0, eqIndex));
      final value:String = StringTools.urlDecode(pair.substring(eqIndex + 1));
      result.set(key, value);
    }
    return result;
  }

  function handleRedirect(query:Map<String, String>, expectedState:String, redirectUri:String):Void
  {
    final error:Null<String> = query.get('error');
    if (error != null)
    {
      isAuthenticating = false;
      if (onSignInFailure != null) onSignInFailure('Google returned an error: $error');
      return;
    }

    final state:Null<String> = query.get('state');
    if (state != expectedState)
    {
      isAuthenticating = false;
      if (onSignInFailure != null) onSignInFailure('State mismatch, possible CSRF attempt.');
      return;
    }

    final code:Null<String> = query.get('code');
    if (code == null)
    {
      isAuthenticating = false;
      if (onSignInFailure != null) onSignInFailure('No authorization code in redirect.');
      return;
    }

    exchangeCodeForTokens(code, redirectUri);
  }

  function exchangeCodeForTokens(code:String, redirectUri:String):Void
  {
    final http = new haxe.Http(TOKEN_ENDPOINT);
    http.setParameter('code', code);
    http.setParameter('client_id', clientId);
    if (clientSecret != null) http.setParameter('client_secret', clientSecret);
    http.setParameter('redirect_uri', redirectUri);
    http.setParameter('grant_type', 'authorization_code');
    http.setParameter('code_verifier', pkceVerifier);

    var resultRaw:Null<String> = null;
    var errorMessage:Null<String> = null;
    http.onData = function(data) resultRaw = data;
    http.onError = function(message) errorMessage = message;
    http.request(true);

    if (errorMessage != null || resultRaw == null)
    {
      isAuthenticating = false;
      if (onSignInFailure != null) onSignInFailure('Token exchange failed: ${errorMessage ?? "empty response"}');
      return;
    }

    try
    {
      final parsed:GoogleClientTokenResponse = haxe.Json.parse(resultRaw);
      accessToken = parsed.access_token;
      if (parsed.refresh_token != null) refreshToken = parsed.refresh_token;
      idToken = parsed.id_token;
      tokenExpiresAt = haxe.Timer.stamp() + parsed.expires_in;
    }
    catch (e:Dynamic)
    {
      isAuthenticating = false;
      if (onSignInFailure != null) onSignInFailure('Could not parse token response: $e');
      return;
    }

    fetchUserInfo();
  }

  function refreshAccessToken():Void
  {
    if (refreshToken == null)
    {
      isAuthenticating = false;
      if (onSignInFailure != null) onSignInFailure('No refresh token available.');
      return;
    }

    final http = new haxe.Http(TOKEN_ENDPOINT);
    http.setParameter('client_id', clientId);
    if (clientSecret != null) http.setParameter('client_secret', clientSecret);
    http.setParameter('refresh_token', refreshToken);
    http.setParameter('grant_type', 'refresh_token');

    var resultRaw:Null<String> = null;
    var errorMessage:Null<String> = null;
    http.onData = function(data) resultRaw = data;
    http.onError = function(message) errorMessage = message;
    http.request(true);

    if (errorMessage != null || resultRaw == null)
    {
      isAuthenticating = false;
      if (onSignInFailure != null) onSignInFailure('Token refresh failed: ${errorMessage ?? "empty response"}');
      return;
    }

    try
    {
      final parsed:GoogleClientTokenResponse = haxe.Json.parse(resultRaw);
      accessToken = parsed.access_token;
      if (parsed.id_token != null) idToken = parsed.id_token;
      tokenExpiresAt = haxe.Timer.stamp() + parsed.expires_in;
    }
    catch (e:Dynamic)
    {
      isAuthenticating = false;
      if (onSignInFailure != null) onSignInFailure('Could not parse refresh response: $e');
      return;
    }

    fetchUserInfo();

    if (onTokenRefreshed != null) onTokenRefreshed();
  }

  function fetchUserInfo():Void
  {
    final http = new haxe.Http(USERINFO_ENDPOINT);
    http.addHeader('Authorization', 'Bearer $accessToken');

    var resultRaw:Null<String> = null;
    var errorMessage:Null<String> = null;
    http.onData = function(data) resultRaw = data;
    http.onError = function(message) errorMessage = message;
    http.request(false);

    if (errorMessage != null || resultRaw == null)
    {
      isAuthenticating = false;
      if (onSignInFailure != null) onSignInFailure('Could not fetch user info: ${errorMessage ?? "empty response"}');
      return;
    }

    try
    {
      final info:GoogleClientUserInfo = haxe.Json.parse(resultRaw);
      userId = info.sub;
      displayName = info.name;
      email = info.email;
      photoUrl = info.picture;
    }
    catch (e:Dynamic)
    {
      isAuthenticating = false;
      if (onSignInFailure != null) onSignInFailure('Could not parse user info: $e');
      return;
    }

    isAuthenticating = false;
    isSignedIn = true;

    if (onSignInSuccess != null) onSignInSuccess();
  }

  function randomString(length:Int):String
  {
    final chars:String = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final buffer:StringBuf = new StringBuf();
    for (i in 0...length) buffer.addChar(chars.charCodeAt(Std.random(chars.length)));
    return buffer.toString();
  }

  function base64UrlEncode(bytes:haxe.io.Bytes):String
  {
    final standard:String = haxe.crypto.Base64.encode(bytes);
    return standard.split('+').join('-').split('/').join('_').split('=').join('');
  }
}

#else

class GoogleClient
{
  public static var instance(get, never):GoogleClient;

  static var _instance:Null<GoogleClient> = null;

  static function get_instance():GoogleClient
  {
    if (_instance == null) _instance = new GoogleClient();
    return _instance;
  }

  public var isInitialized(default, null):Bool = false;
  public var isSignedIn(default, null):Bool = false;
  public var isAuthenticating(default, null):Bool = false;

  public var userId(default, null):Null<String> = null;
  public var displayName(default, null):Null<String> = null;
  public var email(default, null):Null<String> = null;
  public var photoUrl(default, null):Null<String> = null;
  public var idToken(default, null):Null<String> = null;
  public var accessToken(default, null):Null<String> = null;

  public var onSignInSuccess:Null<Void->Void> = null;
  public var onSignInFailure:Null<String->Void> = null;
  public var onSignedOut:Null<Void->Void> = null;
  public var onRevoked:Null<Void->Void> = null;

  private function new() {}

  public function init(options:GoogleClientInitOptions):Void
  {
    isInitialized = true;
    FlxG.log.add('[Google] Sign-In is not available on this platform. Running in no-op mode.');
  }

  public function shutdown():Void
  {
    isInitialized = false;
  }

  public function signIn():Void
  {
    if (onSignInFailure != null) onSignInFailure('Google Sign-In is not supported on this platform.');
  }

  public function signInSilently():Void
  {
    if (onSignInFailure != null) onSignInFailure('Google Sign-In is not supported on this platform.');
  }

  public function signOut():Void
  {
    if (onSignedOut != null) onSignedOut();
  }

  public function revokeAccess():Void
  {
    if (onRevoked != null) onRevoked();
  }

  public function serializeSession():String
  {
    return haxe.Json.stringify({});
  }

  public function restoreSession(raw:String):Bool
  {
    return false;
  }
}

#end

class GoogleClientSandboxed
{
  public static function init(options:GoogleClientInitOptions):Void
  {
    GoogleClient.instance.init(options);
  }

  public static function signIn():Void
  {
    GoogleClient.instance.signIn();
  }

  public static function signInSilently():Void
  {
    GoogleClient.instance.signInSilently();
  }

  public static function signOut():Void
  {
    GoogleClient.instance.signOut();
  }

  public static function revokeAccess():Void
  {
    GoogleClient.instance.revokeAccess();
  }

  public static function shutdown():Void
  {
    GoogleClient.instance.shutdown();
  }
}

#else

class GoogleClientSandboxed
{
  public static function init(options:Dynamic):Void {}

  public static function signIn():Void {}

  public static function signInSilently():Void {}

  public static function signOut():Void {}

  public static function revokeAccess():Void {}

  public static function shutdown():Void {}
}
#end
