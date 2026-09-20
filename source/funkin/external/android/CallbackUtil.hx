package funkin.external.android;

#if android
import lime.system.JNI;
import flixel.util.FlxSignal;
import haxe.ds.Map;

typedef CallbackBinding =
{
  var arity:Int;
  var invoke:Array<Dynamic>->Void;
}

class CallbackUtil #if (lime >= '8.0.0') implements JNISafety #end
{
  static inline final JAVA_CLASS:String = 'funkin/extensions/CallbackUtil';

  public static var DATA_FOLDER_CLOSED(get, never):Int;

  public static var onActivityResult:FlxTypedSignal<Int->Int->Void> = new FlxTypedSignal<Int->Int->Void>();

  public static var onFNFCOpen:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

  public static var onUnknownCallback:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

  static final bindings:Map<String, CallbackBinding> = createDefaultBindings();

  static var instance:Null<CallbackUtil> = null;

  static var dataFolderClosed:Int = 0;

  static var dataFolderClosedResolved:Bool = false;

  public static function init():Void
  {
    if (instance != null) return;

    final initCallBackJNI:Null<Dynamic> = JNIUtil.createStaticMethod(JAVA_CLASS, 'initCallBack', '(Lorg/haxe/lime/HaxeObject;)V');

    if (initCallBackJNI == null) return;

    instance = new CallbackUtil();
    initCallBackJNI(instance);
  }

  public static function registerCallback(name:String, arity:Int, invoke:Array<Dynamic>->Void):Void
  {
    bindings.set(name, {arity: arity, invoke: invoke});
  }

  public static function unregisterCallback(name:String):Bool
  {
    return bindings.remove(name);
  }

  @:noCompletion
  static function get_DATA_FOLDER_CLOSED():Int
  {
    if (dataFolderClosedResolved) return dataFolderClosed;

    final field:Null<Dynamic> = JNIUtil.createStaticField(JAVA_CLASS, 'DATA_FOLDER_CLOSED', 'I');

    if (field == null) return 0;

    dataFolderClosed = field.get();
    dataFolderClosedResolved = true;

    return dataFolderClosed;
  }

  @:noCompletion
  static function createDefaultBindings():Map<String, CallbackBinding>
  {
    final map:Map<String, CallbackBinding> = new Map<String, CallbackBinding>();

    map.set('onActivityResult', {arity: 2, invoke: (args) -> onActivityResult.dispatch(args[0], args[1])});
    map.set('onFNFCOpen', {arity: 1, invoke: (args) -> onFNFCOpen.dispatch(args[0])});

    return map;
  }

  @:noCompletion
  private function new() {}

  @:noCompletion
  @:keep
  #if (lime >= '8.0.0')
  @:runOnMainThread
  #end
  private function dispatchCallback(callbackName:String, arguments:Array<Dynamic>):Void
  {
    final binding:Null<CallbackBinding> = bindings.get(callbackName);

    if (binding == null || arguments == null || arguments.length < binding.arity)
    {
      onUnknownCallback.dispatch(callbackName);
      return;
    }

    binding.invoke(arguments);
  }
}
#end
