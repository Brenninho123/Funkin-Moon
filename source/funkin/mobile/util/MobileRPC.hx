package funkin.mobile.util;

/**
 * Mobile-friendly Rich Presence facade.
 *
 * Discord's desktop RPC transport is not available on Android or iOS. This
 * class keeps the same presence data on mobile and provides a single place for
 * a native Discord bridge to be connected later.
 */
@:unreflective
@:nullSafety
class MobileRPC
{
	/** The latest presence sent to the mobile bridge. */
	public static var presence(get, never):Null<MobileRPCPresence>;

	static var _presence:Null<MobileRPCPresence> = null;
	static var initialized:Bool = false;

	static function get_presence():Null<MobileRPCPresence>
	{
		return _presence;
	}

	/** Initializes the mobile presence bridge. */
	public static function init():Void
	{
		if (initialized) return;

		initialized = true;
		trace('[MobileRPC] Initialized.');
	}

	/**
	 * Publishes a mobile presence.
	 *
	 * The presence is retained even when no native bridge is installed, so
	 * callers can use this API on every target without conditional code.
	 */
	public static function setPresence(value:MobileRPCPresence):Void
	{
		if (!initialized) init();

		_presence = {
			state: value.state,
			details: value.details,
			largeImageKey: value.largeImageKey,
			smallImageKey: value.smallImageKey
		};

		#if (android || ios)
		sendToNative(_presence);
		#end
	}

	/** Clears the current mobile presence. */
	public static function clearPresence():Void
	{
		_presence = null;

		#if (android || ios)
		sendToNative(null);
		#end
	}

	/** Shuts down the mobile presence bridge and clears its cached data. */
	public static function shutdown():Void
	{
		if (!initialized) return;

		clearPresence();
		initialized = false;
		trace('[MobileRPC] Shut down.');
	}

	#if (android || ios)
	static function sendToNative(value:Null<MobileRPCPresence>):Void
	{
		// Native Discord activity support can call this method without changing
		// gameplay code when the platform bridge becomes available.
		trace('[MobileRPC] Native bridge update: ${value == null ? "cleared" : value.state}');
	}
	#end
}

typedef MobileRPCPresence =
{
	/** The first line shown below the game title. */
	var state:String;

	/** The second line shown below the game title. */
	var details:Null<String>;

	/** The large presence image key or URL. */
	var ?largeImageKey:String;

	/** The small presence image key or URL. */
	var ?smallImageKey:String;
}

