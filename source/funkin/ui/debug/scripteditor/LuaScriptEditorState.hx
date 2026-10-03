package funkin.ui.debug.scripteditor;

#if (FEATURE_LUA_SCRIPTS && FEATURE_HAXEUI)
import flixel.FlxSprite;
import funkin.graphics.FunkinCamera;
import funkin.input.Cursor;
import funkin.lua.FunkinLua;
import funkin.modding.PolymodHandler;
import funkin.ui.debug.scripteditor.bot.BotContext;
import funkin.ui.debug.scripteditor.bot.LuaBotEngine;
import funkin.ui.debug.scripteditor.bot.LuaBotEngine.LuaBotReply;
import funkin.ui.debug.scripteditor.bot.LuaMerge;
import funkin.ui.debug.scripteditor.bot.LuaScan;
import funkin.ui.debug.common.EditorTouch;
import funkin.ui.debug.EditorText;
import funkin.ui.system.FunkinCosmic;
import haxe.ui.backend.flixel.UIState;
import haxe.ui.components.Label;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.containers.dialogs.MessageBox.MessageBoxType;
import haxe.ui.containers.windows.WindowManager;
import haxe.ui.core.Screen;
import haxe.ui.events.UIEvent;
import haxe.ui.focus.FocusManager;
import lime.system.Clipboard;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TextEvent;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.ui.Keyboard;

@:build(haxe.ui.ComponentBuilder.build('assets/exclude/ui/editors/script-editor/main-view.xml'))
class LuaScriptEditorState extends UIState
{
  static final GUTTER_WIDTH:Float = 52;
  static final MAX_COMPLETIONS:Int = 8;
  static final MIN_FONT_SIZE:Int = 11;
  static final MAX_FONT_SIZE:Int = 26;
  static final MAX_CONSOLE_LINES:Int = 600;
  static final MAX_HIGHLIGHT_LENGTH:Int = 60000;
  static final MAX_UNDO:Int = 200;
  static final TEMPLATE:String = 'function onCreate()\n  debugPrint("script started")\nend\n\nfunction onUpdate(elapsed)\nend\n';
  static final SNIPPETS:Array<
    {trigger:String, body:String}> = [
    {
      trigger: 'onCreate',
      body: 'function onCreate()\n  |\nend\n'
    },
    {
      trigger: 'onUpdate',
      body: 'function onUpdate(elapsed)\n  |\nend\n'
    },
    {
      trigger: 'onStepHit',
      body: 'function onStepHit(step)\n  |\nend\n'
    },
    {
      trigger: 'onBeatHit',
      body: 'function onBeatHit(beat)\n  |\nend\n'
    },
    {
      trigger: 'onSongStart',
      body: 'function onSongStart()\n  |\nend\n'
    },
    {
      trigger: 'onNoteHit',
      body: 'function onNoteHit(judgement, combo)\n  |\nend\n'
    },
    {
      trigger: 'onNoteMiss',
      body: 'function onNoteMiss(healthChange)\n  |\nend\n'
    },
    {
      trigger: 'onSongEvent',
      body: 'function onSongEvent(kind, value)\n  |\nend\n'
    },
    {
      trigger: 'function',
      body: 'function name(|)\n  \nend\n'
    },
    {
      trigger: 'for',
      body: 'for i = 1, 10 do\n  |\nend\n'
    },
    {
      trigger: 'foreach',
      body: 'for key, value in pairs(|) do\n  \nend\n'
    },
    {
      trigger: 'if',
      body: 'if | then\n  \nend\n'
    },
    {
      trigger: 'ifelse',
      body: 'if | then\n  \nelse\n  \nend\n'
    },
    {
      trigger: 'while',
      body: 'while | do\n  \nend\n'
    }
  ];
  static final LUA_KEYWORDS:Array<String> = [
    'and',
    'break',
    'do',
    'else',
    'elseif',
    'end',
    'false',
    'for',
    'function',
    'goto',
    'if',
    'in',
    'local',
    'nil',
    'not',
    'or',
    'repeat',
    'return',
    'then',
    'true',
    'until',
    'while'
  ];
  static final OPENING_PATTERN:EReg = ~/(\bthen|\bdo|\belse|\brepeat|\bfunction\b.*\)|\{)$/;
  static final WORD_PATTERN:EReg = ~/[A-Za-z_][A-Za-z0-9_]*$/;
  static final REGEX_ESCAPE:EReg = ~/[.*+?^$|(){}\[\]\\]/g;
  static final KEYWORD_PATTERN:EReg = ~/\b(and|break|do|else|elseif|end|false|for|function|goto|if|in|local|nil|not|or|repeat|return|then|true|until|while)\b/g;
  static final NUMBER_PATTERN:EReg = ~/\b(0[xX][0-9a-fA-F]+|[0-9]+\.?[0-9]*)\b/g;
  static final STRING_PATTERN:EReg = ~/"(\\.|[^"\\\n])*"|'(\\.|[^'\\\n])*'/g;
  static final COMMENT_PATTERN:EReg = ~/--[^\n]*/g;
  static final ERROR_LINE_PATTERN:EReg = ~/^[^:]*:([0-9]+):/;

  var editor:TextField;
  var gutter:TextField;
  var console:TextField;
  var completionField:TextField;
  var camBackdrop:FunkinCamera;
  var camUI:FunkinCamera;
  var editorSnapshot:FlxSprite;
  var gutterSnapshot:FlxSprite;
  var consoleSnapshot:FlxSprite;
  var overlayShown:Bool = false;
  var lastLayout:String = '';
  var lastNativeFocus:Bool = false;
  var lastHaxeFocus:Bool = false;
  var updatingList:Bool = false;
  var touchMode:Bool = false;
  var fontSize:Int = 15;
  var findVisible:Bool = false;
  var findCase:Bool = false;
  var completionItems:Array<String> = [];
  var completionIndex:Int = 0;
  var completionCaret:Int = -1;
  var errorLine:Int = -1;
  var lastError:Null<String> = null;
  var matchFormat:TextFormat = new TextFormat(null, null, 0xFFE066, true);
  var bot:LuaBotEngine;
  var apiNames:Array<String> = [];
  var pendingCode:Null<String> = null;
  var botPortuguese:Bool = false;
  var baseFormat:TextFormat;
  var numberFormat:TextFormat = new TextFormat(null, null, 0xD19A66);
  var keywordFormat:TextFormat = new TextFormat(null, null, 0xC678DD);
  var apiFormat:TextFormat = new TextFormat(null, null, 0x61AFEF);
  var stringFormat:TextFormat = new TextFormat(null, null, 0x98C379);
  var commentFormat:TextFormat = new TextFormat(null, null, 0x6B7280);
  var apiPattern:Null<EReg> = null;
  var scripts:Array<String> = [];
  var currentPath:String = '';
  var dirty:Bool = false;
  var exitArmed:Bool = false;
  var runner:Null<FunkinLua> = null;
  var previousText:String = '';
  var undoStack:Array<String> = [];
  var redoStack:Array<String> = [];
  var changeClock:Float = 10;
  var highlightTimer:Float = 0;
  var statusTimer:Float = 0;
  var gutterLines:Int = -1;
  var consoleLines:Int = 0;
  var lastStatus:String = '';
  var dialogOpen:Bool = false;
  var exitDialog:Null<haxe.ui.containers.dialogs.Dialog> = null;

  override function create():Void
  {
    #if (FEATURE_SCREENSHOTS && sys)
    funkin.util.plugins.VideoRecorderPlugin.suspended = true;
    #end

    WindowManager.instance.reset();

    camBackdrop = new FunkinCamera('scriptEditorBackdrop');
    camBackdrop.bgColor = 0xFF14161A;
    camUI = new FunkinCamera('scriptEditorUI');
    camUI.bgColor.alpha = 0;

    FlxG.cameras.reset(camBackdrop);
    FlxG.cameras.add(camUI, false);
    FlxG.cameras.setDefaultDrawTarget(camBackdrop, true);

    persistentUpdate = false;

    super.create();

    root.scrollFactor.set();
    root.cameras = [camUI];
    root.width = FlxG.width;
    root.height = FlxG.height;

    menubar.height = 35;

    WindowManager.instance.container = root;
    Screen.instance.addComponent(root);

    touchMode = EditorTouch.enabled;
    fontSize = touchMode ? 18 : 15;

    baseFormat = new TextFormat(resolveFontName(), fontSize, 0xD4D8E0, false, false, false, null, null, TextFormatAlign.LEFT);

    gutter = createField(0, 0, GUTTER_WIDTH, 100, false, true);
    gutter.backgroundColor = 0x16181D;
    gutter.selectable = false;
    gutter.mouseEnabled = false;
    gutter.defaultTextFormat = new TextFormat(baseFormat.font, fontSize, 0x5C6370, false, false, false, null, null, TextFormatAlign.RIGHT);
    editor = createField(0, 0, 400, 100, true, true);
    console = createField(0, 0, 400, 100, false, true);
    console.backgroundColor = 0x101216;

    editor.addEventListener(Event.CHANGE, onEditorChange);
    editor.addEventListener(Event.SCROLL, onEditorScroll);
    editor.addEventListener(KeyboardEvent.KEY_DOWN, onEditorKeyDown);
    editor.addEventListener(TextEvent.TEXT_INPUT, onEditorTextInput);

    createCompletion();

    // gutter, editor e console ficam na camada de baixo; o completion por último para ficar acima do editor
    for (field in [gutter, editor, console, completionField]) moveToBackdropLayer(field);

    editorSnapshot = new FlxSprite();
    gutterSnapshot = new FlxSprite();
    consoleSnapshot = new FlxSprite();

    for (snapshot in [gutterSnapshot, editorSnapshot, consoleSnapshot])
    {
      snapshot.scrollFactor.set(0, 0);
      snapshot.cameras = [camBackdrop];
      snapshot.visible = false;
      add(snapshot);
    }

    apiNames = FunkinLua.getApiNames();
    apiPattern = new EReg('\\b(' + apiNames.join('|') + ')\\b', 'g');

    FunkinLua.logSink = onLuaLog;

    bot = new LuaBotEngine(apiNames);

    registerInputEvents();
    populateRecipes();
    botSay('bot', LuaBotEngine.helpText(false));

    Cursor.show();

    refreshScripts();
    newScript();

    logLine(
      'info',
      'Lua script editor ready. Ctrl+S save, F5 run, F6 stop, F7 check, Ctrl+F find, Ctrl+H replace, Ctrl+G go to line, Ctrl+Space complete, Ctrl+/ comment, F4 bot, F1 guide, Esc exit.'
    );

    haxe.ui.Toolkit.callLater(() ->
    {
      var focused = FocusManager.instance.focus;

      if (focused != null) focused.focus = false;
    });
  }

  function resolveFontName():String
  {
    return EditorText.resolveFontName();
  }

  function createField(x:Float, y:Float, width:Float, height:Float, input:Bool, multiline:Bool):TextField
  {
    return EditorText.createField(baseFormat, x, y, width, height, input, multiline);
  }

  override function update(elapsed:Float):Void
  {
    updateLayout();

    super.update(elapsed);

    changeClock += elapsed;

    updateOverlay();
    arbitrateFocus();
    handleShortcuts();

    if (highlightTimer > 0)
    {
      highlightTimer -= elapsed;

      if (highlightTimer <= 0) applyHighlight();
    }

    if (completionItems.length > 0 && editor.caretIndex != completionCaret) hideCompletion();

    statusTimer += elapsed;

    if (statusTimer >= 0.1)
    {
      statusTimer = 0;
      updateStatus();
    }

    if (runner != null)
    {
      if (runner.closed)
      {
        runner = null;
        logLine('warn', 'Script stopped.');
      }
      else
      {
        runner.call('onUpdate', [elapsed]);
      }
    }
  }

  function placeField(field:TextField, x:Float, y:Float, width:Float, height:Float):Void
  {
    var parent = field.parent;
    var sx:Float = 1;
    var sy:Float = 1;

    if (parent != null)
    {
      var local = parent.globalToLocal(new openfl.geom.Point(x, y));
      x = local.x;
      y = local.y;
      sx = parent.scaleX == 0 ? 1 : parent.scaleX;
      sy = parent.scaleY == 0 ? 1 : parent.scaleY;
    }

    field.x = x;
    field.y = y;
    field.width = Math.max(40, width / sx);
    field.height = Math.max(24, height / sy);
  }

  function updateLayout():Void
  {
    if (editorArea.width <= 0 || consoleArea.width <= 0) return;

    var key:String = [
      editorArea.screenLeft,
      editorArea.screenTop,
      editorArea.width,
      editorArea.height,
      consoleArea.screenLeft,
      consoleArea.screenTop,
      consoleArea.width,
      consoleArea.height
    ].join(',');

    if (key == lastLayout) return;

    lastLayout = key;

    placeField(gutter, editorArea.screenLeft, editorArea.screenTop, GUTTER_WIDTH, editorArea.height);
    placeField(editor, editorArea.screenLeft + GUTTER_WIDTH, editorArea.screenTop, editorArea.width - GUTTER_WIDTH, editorArea.height);
    placeField(console, consoleArea.screenLeft, consoleArea.screenTop, consoleArea.width, consoleArea.height);

    if (overlayShown) captureSnapshots();
  }

  function overlayOpen():Bool
  {
    for (component in Screen.instance.rootComponents)
    {
      if (component == root) continue;

      var name:String = Type.getClassName(Type.getClass(component));

      if (name.indexOf('Notification') >= 0 || name.indexOf('ToolTip') >= 0) continue;

      return true;
    }

    return false;
  }

  function captureSnapshot(field:TextField, sprite:FlxSprite):Void
  {
    var width:Int = Std.int(field.width);
    var height:Int = Std.int(field.height);

    if (width <= 0 || height <= 0) return;

    var bitmap:BitmapData = new BitmapData(width, height, false, 0x1B1E24);

    bitmap.draw(field);

    sprite.pixels = bitmap;
    sprite.x = field.x;
    sprite.y = field.y;
  }

  function captureSnapshots():Void
  {
    captureSnapshot(gutter, gutterSnapshot);
    captureSnapshot(editor, editorSnapshot);
    captureSnapshot(console, consoleSnapshot);
  }

  function updateOverlay():Void
  {
    return; // não é mais necessário: os campos já ficam abaixo da camUI

    var open:Bool = overlayOpen();

    if (open == overlayShown) return;

    overlayShown = open;

    if (open) captureSnapshots();

    for (field in [gutter, editor, console]) field.visible = !open;

    for (snapshot in [gutterSnapshot, editorSnapshot, consoleSnapshot]) snapshot.visible = open;

    if (open) completionField.visible = false;
    else if (completionItems.length > 0) completionField.visible = true;
  }

  function arbitrateFocus():Void
  {
    var haxeFocus:Bool = FocusManager.instance.focus != null;
    var nativeFocus:Bool = FlxG.stage.focus == editor;

    if (nativeFocus && !lastNativeFocus && haxeFocus)
    {
      FocusManager.instance.focus.focus = false;
      haxeFocus = false;
    }
    else if (haxeFocus && !lastHaxeFocus && nativeFocus)
    {
      FlxG.stage.focus = null;
      nativeFocus = false;
    }

    lastNativeFocus = nativeFocus;
    lastHaxeFocus = haxeFocus;
  }

  function isTypingInUI():Bool
  {
    var focused = FocusManager.instance.focus;

    return
      focused != null
      && (
        Std.isOfType(focused, haxe.ui.components.TextField)
        || Std.isOfType(focused, haxe.ui.components.NumberStepper)
        || Std.isOfType(focused, haxe.ui.components.DropDown)
      );
  }

  function handleShortcuts():Void
  {
    if (dialogOpen) return;

    var keys = FlxG.keys;
    var ctrl:Bool = keys.pressed.CONTROL;
    var shift:Bool = keys.pressed.SHIFT;
    var alt:Bool = keys.pressed.ALT;
    var typing:Bool = isTypingInUI();

    if (keys.justPressed.F1)
    {
      openGuide();
      return;
    }

    if (keys.justPressed.F4) setBotPanel(botPanel.hidden);

    if (ctrl && keys.justPressed.S) save();
    else if (keys.justPressed.F5) run();
    else if (keys.justPressed.F6) stop();
    else if (keys.justPressed.F7) check();
    else if (keys.justPressed.ESCAPE)
    {
      if (completionItems.length > 0) hideCompletion();
      else if (findVisible) closeFind();
      else if (typing) FocusManager.instance.focus.focus = false;
      else
        requestExit();
    }
    else if (typing)
    {
      return;
    }
    else if (ctrl && keys.justPressed.Z) undo();
    else if (ctrl && keys.justPressed.Y) redo();
    else if (ctrl && keys.justPressed.F) openFind(false);
    else if (ctrl && keys.justPressed.H) openFind(true);
    else if (ctrl && keys.justPressed.G) focusGoto();
    else if (ctrl && keys.justPressed.D) duplicateLines();
    else if (ctrl && shift && keys.justPressed.K) deleteLines();
    else if (ctrl && keys.justPressed.SLASH) toggleComment();
    else if (ctrl && keys.justPressed.SPACE) updateCompletion(true);
    else if (ctrl && keys.justPressed.PLUS) changeFontSize(1);
    else if (ctrl && keys.justPressed.MINUS) changeFontSize(-1);
    else if (ctrl && completionItems.length > 0 && keys.justPressed.N) moveCompletion(1);
    else if (ctrl && completionItems.length > 0 && keys.justPressed.P) moveCompletion(-1);
    else if (alt && keys.justPressed.UP) moveLines(-1);
    else if (alt && keys.justPressed.DOWN) moveLines(1);
    else if (keys.justPressed.F3) findNext(shift ? -1 : 1);
  }

  function refreshScripts():Void
  {
    scripts = [];

    #if sys
    scanLua('assets/songs', scripts, 0);
    scanLua(PolymodHandler.getModFolder(), scripts, 0);
    #end

    scripts.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));

    refreshList();
  }

  #if sys
  function scanLua(directory:String, found:Array<String>, depth:Int):Void
  {
    if (depth > 8 || found.length >= 1000) return;
    if (!sys.FileSystem.exists(directory) || !sys.FileSystem.isDirectory(directory)) return;

    for (entry in sys.FileSystem.readDirectory(directory))
    {
      var path:String = '$directory/$entry';

      if (sys.FileSystem.isDirectory(path)) scanLua(path, found, depth + 1);
      else if (StringTools.endsWith(entry.toLowerCase(), '.lua')) found.push(path);
    }
  }
  #end

  function refreshList():Void
  {
    if (scriptList == null) return;

    var filter:String = scriptFilter.text != null ? scriptFilter.text.toLowerCase() : '';

    updatingList = true;

    scriptList.dataSource.clear();

    var selectedIndex:Int = -1;
    var count:Int = 0;

    for (path in scripts)
    {
      if (filter != '' && path.toLowerCase().indexOf(filter) < 0) continue;

      var shown:String = path.length > 36 ? '..' + path.substr(path.length - 34) : path;

      scriptList.dataSource.add({
        text: shown,
        path: path
      });

      if (path == currentPath) selectedIndex = count;

      count++;
    }

    if (selectedIndex >= 0) scriptList.selectedIndex = selectedIndex;

    updatingList = false;
  }

  function openScript(path:String):Void
  {
    var content:Null<String> = FunkinCosmic.readText(path, false);

    if (content == null)
    {
      logLine('error', 'Could not read $path');
      return;
    }

    currentPath = path;
    pathInput.text = path;

    setEditorText(StringTools.replace(StringTools.replace(content, '\r\n', '\n'), '\r', '\n'));

    dirty = false;

    refreshList();
    logLine('info', 'Opened $path');
  }

  function newScript():Void
  {
    var modDirs:Array<String> = PolymodHandler.loadedModDirs;
    var path:String = modDirs.length > 0 ? '${PolymodHandler.getModFolder()}/${modDirs[0]}/scripts/new_script.lua' : 'new_script.lua';

    currentPath = '';
    pathInput.text = path;

    setEditorText(TEMPLATE);

    dirty = false;

    refreshList();
  }

  function setEditorText(text:String):Void
  {
    editor.text = text;
    editor.scrollV = 1;
    editor.setSelection(0, 0);

    undoStack = [];
    redoStack = [];
    previousText = text;
    changeClock = 10;
    exitArmed = false;
    gutterLines = -1;

    refreshGutter();
    applyHighlight();
  }

  function onEditorChange(_:Event):Void
  {
    dirty = true;
    exitArmed = false;

    if (changeClock > 0.6)
    {
      undoStack.push(previousText);

      if (undoStack.length > MAX_UNDO) undoStack.shift();
    }

    changeClock = 0;
    redoStack = [];
    previousText = editor.text;

    if (errorLine >= 0)
    {
      errorLine = -1;
      gutterLines = -1;
    }

    refreshGutter();

    highlightTimer = 0.3;

    updateCompletion(false);
  }

  function onEditorScroll(_:Event):Void
  {
    gutter.scrollV = editor.scrollV;
  }

  function onEditorKeyDown(event:KeyboardEvent):Void
  {
    if (event.keyCode != Keyboard.TAB) return;

    if (completionItems.length > 0)
    {
      acceptCompletion();
      return;
    }

    editor.replaceSelectedText('  ');

    event.preventDefault();

    onEditorChange(null);
  }

  function onEditorTextInput(event:TextEvent):Void
  {
    if (event.text != '\n') return;

    event.preventDefault();

    var text:String = editor.text;
    var caret:Int = editor.selectionBeginIndex;
    var lineStart:Int = text.lastIndexOf('\n', caret - 1) + 1;
    var linePrefix:String = text.substring(lineStart, caret);
    var indent:String = '';

    for (i in 0...linePrefix.length)
    {
      var character:String = linePrefix.charAt(i);

      if (character == ' ' || character == '\t') indent += character;
      else
        break;
    }

    var trimmed:String = StringTools.rtrim(linePrefix);

    if (OPENING_PATTERN.match(trimmed)) indent += '  ';

    editor.replaceSelectedText('\n' + indent);

    onEditorChange(null);
  }

  function replaceText(text:String):Void
  {
    var caret:Int = Std.int(Math.min(editor.caretIndex, text.length));

    editor.text = text;
    editor.setSelection(caret, caret);

    previousText = text;
    changeClock = 10;
    dirty = true;

    refreshGutter();
    applyHighlight();
  }

  function undo():Void
  {
    if (undoStack.length == 0) return;

    redoStack.push(editor.text);

    replaceText(undoStack.pop());
  }

  function redo():Void
  {
    if (redoStack.length == 0) return;

    undoStack.push(editor.text);

    replaceText(redoStack.pop());
  }

  function refreshGutter():Void
  {
    var count:Int = Std.int(Math.max(1, editor.numLines));

    if (count == gutterLines) return;

    gutterLines = count;
    gutter.text = [for (i in 1...count + 1) Std.string(i)].join('\n');

    if (errorLine > 0 && errorLine <= count)
    {
      var errorStart:Int = gutter.getLineOffset(errorLine - 1);

      gutter.setTextFormat(new TextFormat(null, null, 0xFF6B6B, true), errorStart, errorStart + gutter.getLineLength(errorLine - 1));
    }
    gutter.scrollV = editor.scrollV;
  }

  function applyHighlight():Void
  {
    highlightTimer = 0;

    var text:String = editor.text;

    editor.setTextFormat(baseFormat, 0, text.length);

    if (text.length > MAX_HIGHLIGHT_LENGTH) return;

    highlightMatches(NUMBER_PATTERN, numberFormat);
    highlightMatches(KEYWORD_PATTERN, keywordFormat);

    if (apiPattern != null) highlightMatches(apiPattern, apiFormat);

    highlightMatches(STRING_PATTERN, stringFormat);
    highlightMatches(COMMENT_PATTERN, commentFormat);
  }

  function highlightMatches(pattern:EReg, format:TextFormat):Void
  {
    EditorText.highlightMatches(editor, pattern, format);
  }

  function updateStatus():Void
  {
    var caret:Int = editor.caretIndex;
    var line:Int = Std.int(Math.max(0, editor.getLineIndexOfChar(caret)));
    var column:Int = caret - editor.getLineOffset(line) + 1;
    var status:String =
      'Ln '
      + (line + 1)
      + ', Col '
      + column
      + '   '
      + editor.numLines
      + ' lines'
      + (dirty ? '   MODIFIED' : '')
      + (runner != null ? '   RUNNING' : '');

    if (status == lastStatus) return;

    lastStatus = status;
    statusLabel.text = status;
  }

  function save():Void
  {
    var path:String = StringTools.trim(pathInput.text).split('\\').join('/');

    if (path == '' || !StringTools.endsWith(path.toLowerCase(), '.lua'))
    {
      logLine('error', 'Enter a script path ending in .lua');
      return;
    }

    if (!FunkinCosmic.writeTextAtomic(path, editor.text, false))
    {
      logLine('error', 'Could not write $path');
      return;
    }

    currentPath = path;
    dirty = false;

    logLine('ok', 'Saved $path (scripts that are already loaded keep running the old version until they are reloaded)');

    if (scripts.indexOf(path) == -1) refreshScripts();
    else
      refreshList();
  }

  function check():Bool
  {
    var message:Null<String> = FunkinLua.checkSyntax(editor.text);

    if (message == null)
    {
      logLine('ok', 'Syntax OK');
      return true;
    }

    logLine('error', message);
    lastError = message;

    if (ERROR_LINE_PATTERN.match(message))
    {
      var line:Int = Std.parseInt(ERROR_LINE_PATTERN.matched(1)) ?? 1;

      gotoLine(line);
      markErrorLine(line);
    }

    return false;
  }

  function run():Void
  {
    stop();

    if (!check()) return;

    var name:String = StringTools.trim(pathInput.text);

    logLine('info', 'Running ${name == '' ? 'script' : name} (onCreate and onUpdate are called; PlayState callbacks are not available here)');

    runner = new FunkinLua(name == '' ? 'editor.lua' : name, editor.text, false);

    if (runner.closed)
    {
      runner = null;
      return;
    }

    runner.call('onCreate', []);
  }

  function stop():Void
  {
    if (runner == null) return;

    runner.destroy();
    runner = null;

    logLine('info', 'Script stopped.');
  }

  function printApi():Void
  {
    var names:Array<String> = FunkinLua.getApiNames();

    logLine('info', '${names.length} functions:');

    var index:Int = 0;

    while (index < names.length)
    {
      logLine('info', '  ' + names.slice(index, index + 6).join(', '));
      index += 6;
    }
  }

  function clearConsole():Void
  {
    console.text = '';
    consoleLines = 0;
  }

  function onLuaLog(script:String, level:String, message:String):Void
  {
    if (level == 'error') lastError = message;

    logLine(level, message);
  }

  function logLine(level:String, message:String):Void
  {
    if (console == null) return;

    if (consoleLines >= MAX_CONSOLE_LINES) clearConsole();

    var color:Int = switch (level)
    {
      case 'error':
        0xFF6B6B;
      case 'warn':
        0xFFD166;
      case 'ok':
        0x7CFC9A;
      default:
        0xC8D0DA;
    };

    var start:Int = console.text.length;

    console.appendText(message + '\n');
    console.setTextFormat(new TextFormat(null, null, color), start, console.text.length);

    consoleLines++;

    console.scrollV = console.maxScrollV;
  }

  function moveToBackdropLayer(field:TextField):Void
  {
    camBackdrop.flashSprite.addChild(field);
    lastLayout = '';
  }

  function openFind(withReplace:Bool):Void
  {
    findVisible = true;
    findBar.hidden = false;

    var selection:String = editor.text.substring(editor.selectionBeginIndex, editor.selectionEndIndex);

    if (selection != '' && selection.indexOf('\n') == -1) findInput.text = selection;

    (withReplace ? replaceInput : findInput).focus = true;

    updateFindInfo();
  }

  function closeFind():Void
  {
    findVisible = false;
    findBar.hidden = true;

    var focused = FocusManager.instance.focus;

    if (focused != null) focused.focus = false;

    FlxG.stage.focus = editor;
  }

  function focusGoto():Void
  {
    findVisible = true;
    findBar.hidden = false;

    gotoInput.text = '';
    gotoInput.focus = true;
  }

  function submitGoto():Void
  {
    var line:Null<Int> = Std.parseInt(StringTools.trim(gotoInput.text));

    if (line == null)
    {
      logLine('warn', 'Type a line number.');
      return;
    }

    gotoLine(line);

    FlxG.stage.focus = editor;
  }

  function registerInputEvents():Void
  {
    findInput.registerEvent(haxe.ui.events.KeyboardEvent.KEY_DOWN, function(event:haxe.ui.events.KeyboardEvent):Void
    {
      if (event.keyCode == 13) findNext(event.shiftKey ? -1 : 1);
    });

    replaceInput.registerEvent(haxe.ui.events.KeyboardEvent.KEY_DOWN, function(event:haxe.ui.events.KeyboardEvent):Void
    {
      if (event.keyCode == 13) replaceCurrent();
    });

    gotoInput.registerEvent(haxe.ui.events.KeyboardEvent.KEY_DOWN, function(event:haxe.ui.events.KeyboardEvent):Void
    {
      if (event.keyCode == 13) submitGoto();
    });

    botInput.registerEvent(haxe.ui.events.KeyboardEvent.KEY_DOWN, function(event:haxe.ui.events.KeyboardEvent):Void
    {
      if (event.keyCode == 13) sendBot();
    });
  }

  function haystackFor(text:String):String
  {
    return findCase ? text : text.toLowerCase();
  }

  function findMatches():Array<Int>
  {
    var needle:String = haystackFor(findInput.text);
    var matches:Array<Int> = [];

    if (needle == '') return matches;

    var haystack:String = haystackFor(editor.text);
    var position:Int = haystack.indexOf(needle);

    while (position >= 0 && matches.length < 5000)
    {
      matches.push(position);
      position = haystack.indexOf(needle, position + Std.int(Math.max(1, needle.length)));
    }

    return matches;
  }

  function findNext(direction:Int, fromStart:Bool = false):Void
  {
    var matches:Array<Int> = findMatches();

    if (matches.length == 0)
    {
      findInfo.text = findInput.text == '' ? '' : 'no matches';
      return;
    }

    var anchor:Int = fromStart ? editor.selectionBeginIndex : (direction > 0 ? editor.selectionEndIndex : editor.selectionBeginIndex);
    var target:Int = -1;

    if (direction > 0)
    {
      for (position in matches)
      {
        if (position >= anchor)
        {
          target = position;
          break;
        }
      }

      if (target < 0) target = matches[0];
    }
    else
    {
      var index:Int = matches.length - 1;

      while (index >= 0)
      {
        if (matches[index] < anchor)
        {
          target = matches[index];
          break;
        }

        index--;
      }

      if (target < 0) target = matches[matches.length - 1];
    }

    selectRange(target, target + findInput.text.length);
    updateFindInfo();
  }

  function selectRange(start:Int, end:Int):Void
  {
    var line:Int = editor.getLineIndexOfChar(start);

    if (line >= 0 && (line + 1 < editor.scrollV || line + 1 > editor.bottomScrollV)) editor.scrollV = Std.int(Math.max(1, line - 4));

    applyHighlight();
    editor.setTextFormat(matchFormat, start, end);
    editor.setSelection(start, end);
  }

  function updateFindInfo():Void
  {
    if (findInfo == null) return;

    var matches:Array<Int> = findMatches();

    if (findInput.text == '')
    {
      findInfo.text = '';
      return;
    }

    if (matches.length == 0)
    {
      findInfo.text = 'no matches';
      return;
    }

    var current:Int = matches.indexOf(editor.selectionBeginIndex);

    findInfo.text = (current >= 0 ? Std.string(current + 1) : '-') + ' of ' + matches.length;
  }

  function selectionMatchesFind():Bool
  {
    var needle:String = findInput.text;

    if (needle == '' || editor.selectionEndIndex - editor.selectionBeginIndex != needle.length) return false;

    return haystackFor(editor.text.substring(editor.selectionBeginIndex, editor.selectionEndIndex)) == haystackFor(needle);
  }

  function replaceCurrent():Void
  {
    if (!selectionMatchesFind())
    {
      findNext(1);
      return;
    }

    var start:Int = editor.selectionBeginIndex;
    var text:String = editor.text;
    var replacement:String = replaceInput.text;

    applyEdit(text.substring(0, start) + replacement + text.substring(editor.selectionEndIndex), start + replacement.length, start + replacement.length);
    findNext(1);
  }

  function replaceAll():Void
  {
    var needle:String = findInput.text;

    if (needle == '') return;

    var matches:Array<Int> = findMatches();

    if (matches.length == 0)
    {
      findInfo.text = 'no matches';
      return;
    }

    var pattern:EReg = new EReg(REGEX_ESCAPE.replace(needle, '\\$0'), findCase ? 'g' : 'gi');
    var replacement:String = replaceInput.text;
    var result:String = pattern.map(editor.text, (_) -> replacement);

    applyEdit(result, 0, 0);
    logLine('ok', 'Replaced ' + matches.length + ' matches.');
    updateFindInfo();
  }

  function gotoLine(line:Int):Void
  {
    var index:Int = Std.int(Math.max(0, Math.min(editor.numLines - 1, line - 1)));
    var start:Int = editor.getLineOffset(index);

    editor.scrollV = Std.int(Math.max(1, index - 3));
    editor.setSelection(start, start + Std.int(Math.max(0, editor.getLineLength(index) - 1)));

    gutter.scrollV = editor.scrollV;
  }

  function markErrorLine(line:Int):Void
  {
    errorLine = line;

    gutterLines = -1;
    refreshGutter();
  }

  function applyEdit(text:String, selectionStart:Int, selectionEnd:Int):Void
  {
    undoStack.push(editor.text);

    if (undoStack.length > MAX_UNDO) undoStack.shift();

    redoStack = [];

    var scroll:Int = editor.scrollV;

    editor.text = text;
    editor.scrollV = scroll;
    editor.setSelection(selectionStart, selectionEnd);

    previousText = text;
    changeClock = 10;
    dirty = true;
    exitArmed = false;
    errorLine = -1;
    gutterLines = -1;

    refreshGutter();
    applyHighlight();
  }

  function lineRange():
    {first:Int, last:Int}
  {
    var begin:Int = editor.selectionBeginIndex;
    var end:Int = editor.selectionEndIndex;
    var first:Int = Std.int(Math.max(0, editor.getLineIndexOfChar(begin)));
    var lastChar:Int = end > begin ? end - 1 : end;
    var last:Int = Std.int(Math.max(first, editor.getLineIndexOfChar(Std.int(Math.max(begin, lastChar)))));

    return {
      first: first,
      last: Std.int(Math.min(last, editor.numLines - 1))
    };
  }

  function lineOffset(lines:Array<String>, index:Int):Int
  {
    var offset:Int = 0;

    for (i in 0...index) offset += lines[i].length + 1;

    return offset;
  }

  function selectLines(lines:Array<String>, first:Int, last:Int):Void
  {
    var start:Int = lineOffset(lines, first);
    var end:Int = lineOffset(lines, last) + lines[last].length;

    applyEdit(lines.join('\n'), start, end);
  }

  function toggleComment():Void
  {
    var range = lineRange();
    var lines:Array<String> = editor.text.split('\n');
    var allCommented:Bool = true;
    var any:Bool = false;

    for (i in range.first...range.last + 1)
    {
      var trimmed:String = StringTools.ltrim(lines[i]);

      if (trimmed == '') continue;

      any = true;

      if (!StringTools.startsWith(trimmed, '--')) allCommented = false;
    }

    if (!any) return;

    for (i in range.first...range.last + 1)
    {
      var line:String = lines[i];
      var trimmed:String = StringTools.ltrim(line);

      if (trimmed == '') continue;

      var indent:String = line.substr(0, line.length - trimmed.length);

      if (allCommented)
      {
        var rest:String = trimmed.substr(2);

        if (StringTools.startsWith(rest, ' ')) rest = rest.substr(1);

        lines[i] = indent + rest;
      }
      else
      {
        lines[i] = indent + '-- ' + trimmed;
      }
    }

    selectLines(lines, range.first, range.last);
  }

  function duplicateLines():Void
  {
    var range = lineRange();
    var lines:Array<String> = editor.text.split('\n');
    var block:Array<String> = lines.slice(range.first, range.last + 1);
    var inserted:Array<String> = lines.slice(0, range.last + 1).concat(block).concat(lines.slice(range.last + 1));
    var count:Int = block.length;

    selectLines(inserted, range.first + count, range.last + count);
  }

  function deleteLines():Void
  {
    var range = lineRange();
    var lines:Array<String> = editor.text.split('\n');

    lines.splice(range.first, range.last - range.first + 1);

    if (lines.length == 0) lines.push('');

    var target:Int = Std.int(Math.min(range.first, lines.length - 1));
    var start:Int = lineOffset(lines, target);

    applyEdit(lines.join('\n'), start, start);
  }

  function moveLines(direction:Int):Void
  {
    var range = lineRange();
    var lines:Array<String> = editor.text.split('\n');

    if (direction < 0 && range.first == 0) return;
    if (direction > 0 && range.last >= lines.length - 1) return;

    var block:Array<String> = lines.splice(range.first, range.last - range.first + 1);
    var target:Int = range.first + direction;

    for (i in 0...block.length) lines.insert(target + i, block[i]);

    selectLines(lines, target, target + block.length - 1);
  }

  function changeFontSize(delta:Int):Void
  {
    var next:Int = Std.int(Math.max(MIN_FONT_SIZE, Math.min(MAX_FONT_SIZE, fontSize + delta)));

    if (next == fontSize) return;

    fontSize = next;
    baseFormat.size = next;

    editor.defaultTextFormat = baseFormat;

    var gutterFormat:TextFormat = new TextFormat(baseFormat.font, next, 0x5C6370, false, false, false, null, null, TextFormatAlign.RIGHT);

    gutter.defaultTextFormat = gutterFormat;
    console.defaultTextFormat = new TextFormat(baseFormat.font, next, 0xC8D0DA);

    gutterLines = -1;
    refreshGutter();
    applyHighlight();
  }

  function createCompletion():Void
  {
    var format:TextFormat = new TextFormat(baseFormat.font, 14, 0xD4D8E0);

    completionField = createField(0, 0, 320, 110, false, true);
    completionField.defaultTextFormat = format;
    completionField.backgroundColor = 0x242933;
    completionField.borderColor = 0x61AFEF;
    completionField.visible = false;
    completionField.selectable = false;
    completionField.addEventListener(MouseEvent.MOUSE_DOWN, onCompletionClick);
  }

  function updateCompletion(force:Bool):Void
  {
    if (completionField == null) return;

    var caret:Int = editor.caretIndex;
    var before:String = editor.text.substring(Std.int(Math.max(0, caret - 64)), caret);
    var word:String = WORD_PATTERN.match(before) ? WORD_PATTERN.matched(0) : '';

    if (word.length < (force ? 1 : 3))
    {
      hideCompletion();
      return;
    }

    var lowered:String = word.toLowerCase();
    var found:Array<String> = [];

    for (entry in SNIPPETS)
    {
      if (entry.trigger.toLowerCase().indexOf(lowered) == 0 && entry.trigger != word) found.push(entry.trigger);
    }

    for (name in FunkinLua.getApiNames())
    {
      if (name.toLowerCase().indexOf(lowered) == 0 && name != word && found.indexOf(name) == -1) found.push(name);
    }

    for (keyword in LUA_KEYWORDS)
    {
      if (keyword.indexOf(lowered) == 0 && keyword != word) found.push(keyword);
    }

    if (found.length == 0)
    {
      hideCompletion();
      return;
    }

    completionItems = found.slice(0, MAX_COMPLETIONS);
    completionIndex = 0;
    completionCaret = caret;

    renderCompletion();
  }

  function renderCompletion():Void
  {
    var lines:Array<String> = [];

    for (i in 0...completionItems.length)
    {
      var isSnippet:Bool = false;

      for (entry in SNIPPETS)
      {
        if (entry.trigger == completionItems[i]) isSnippet = true;
      }

      lines.push((i == completionIndex ? '> ' : '  ') + completionItems[i] + (isSnippet ? '  (snippet)' : ''));
    }

    completionField.text = lines.join('\n');
    completionField.setTextFormat(new TextFormat(null, null, 0xD4D8E0), 0, completionField.text.length);

    var start:Int = completionField.getLineOffset(completionIndex);

    completionField.setTextFormat(new TextFormat(null, null, 0x7CFC9A), start, start + completionField.getLineLength(completionIndex));

    completionField.height = completionItems.length * 19 + 8;
    completionField.x = editor.x + 12;
    completionField.y = editor.y + editor.height - completionField.height - 6;
    completionField.visible = true;
  }

  function hideCompletion():Void
  {
    completionItems = [];

    if (completionField != null) completionField.visible = false;
  }

  function moveCompletion(direction:Int):Void
  {
    if (completionItems.length == 0) return;

    completionIndex = (completionIndex + direction + completionItems.length) % completionItems.length;

    renderCompletion();
  }

  function onCompletionClick(event:MouseEvent):Void
  {
    var line:Int = Std.int(Math.max(0, completionField.getLineIndexAtPoint(event.localX, event.localY)));

    if (line >= 0 && line < completionItems.length)
    {
      completionIndex = line;
      acceptCompletion();
    }
  }

  function acceptCompletion():Void
  {
    if (completionItems.length == 0) return;

    var item:String = completionItems[completionIndex];
    var caret:Int = editor.caretIndex;
    var text:String = editor.text;
    var before:String = text.substring(Std.int(Math.max(0, caret - 64)), caret);
    var word:String = WORD_PATTERN.match(before) ? WORD_PATTERN.matched(0) : '';
    var start:Int = caret - word.length;
    var insertion:String = item;
    var marker:Int = -1;

    for (entry in SNIPPETS)
    {
      if (entry.trigger == item)
      {
        var lineStart:Int = text.lastIndexOf('\n', start - 1) + 1;
        var indent:String = '';

        for (i in lineStart...start)
        {
          var character:String = text.charAt(i);

          if (character == ' ' || character == '\t') indent += character;
          else
            break;
        }

        insertion = StringTools.replace(entry.body, '\n', '\n' + indent);
        marker = insertion.indexOf('|');

        if (marker >= 0) insertion = insertion.substr(0, marker) + insertion.substr(marker + 1);

        break;
      }
    }

    var caretAfter:Int = start + (marker >= 0 ? marker : insertion.length);

    hideCompletion();

    applyEdit(text.substring(0, start) + insertion + text.substring(caret), caretAfter, caretAfter);
  }

  function requestExit():Void
  {
    if (dirty)
    {
      if (exitDialog == null)
      {
        exitDialog = Dialogs.messageBox(
          'You are about to leave the editor without saving.\n\nAre you sure?',
          'Leave Editor',
          MessageBoxType.TYPE_YESNO,
          true,
          function(button:DialogButton):Void
          {
            exitDialog = null;

            if (button == DialogButton.YES) leave();
          }
        );
      }

      return;
    }

    leave();
  }

  function leave():Void
  {
    stop();

    FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
  }

  function confirmDiscard(action:Void->Void, ?cancel:Void->Void):Void
  {
    if (!dirty)
    {
      action();
      return;
    }

    Dialogs.messageBox('This script has unsaved changes. Discard them?', 'Unsaved Changes', MessageBoxType.TYPE_YESNO, true, function(button:DialogButton):Void
    {
      if (button == DialogButton.YES) action();
      else if (cancel != null) cancel();
    });
  }

  function openGuide():Void
  {
    var guide:ScriptUserGuideDialog = new ScriptUserGuideDialog();

    dialogOpen = true;
    guide.onDialogClosed = function(_):Void
    {
      dialogOpen = false;
    };
    guide.showDialog(true);
  }

  function setBotPanel(visible:Bool):Void
  {
    botPanel.hidden = !visible;
    menubarItemBotPanel.selected = visible;
  }

  function populateRecipes():Void
  {
    botRecipes.dataSource.clear();

    for (recipe in funkin.ui.debug.scripteditor.bot.LuaBotRecipes.ALL) botRecipes.dataSource.add({
      id: recipe.id,
      text: recipe.title
    });
  }

  function botSay(who:String, text:String, code:Bool = false):Void
  {
    var label:Label = new Label();

    label.percentWidth = 100;
    label.text = (who == 'you' ? 'You: ' : (who == 'bot' ? 'Bot: ' : '')) + text;
    label.customStyle.color = who == 'you' ? 0xE5C07B : (code ? 0x98C379 : 0xD4D8E0);

    botLog.addComponent(label);

    haxe.ui.Toolkit.callLater(() ->
    {
      botScroll.vscrollPos = botScroll.vscrollMax;
    });
  }

  function setPendingCode(code:Null<String>):Void
  {
    pendingCode = code;

    botInsert.disabled = code == null;
    botReplace.disabled = code == null;
    botCopy.disabled = code == null;
  }

  function sendBot():Void
  {
    var text:String = botInput.text != null ? StringTools.trim(botInput.text) : '';

    if (text == '') return;

    botInput.text = '';
    botPortuguese = new BotContext(text).portuguese;

    botSay('you', text);

    var reply:LuaBotReply = bot.respond(text, editor.text);

    botSay('bot', reply.message);

    if (reply.code != null)
    {
      botSay('code', reply.code, true);
      setPendingCode(reply.code);

      var error:Null<String> = FunkinLua.checkSyntax(reply.code);

      if (error != null) botSay('bot', 'The generated code did not pass the syntax check: ' + error);
    }

    if (reply.kind == 'review') showFindings(reply);
  }

  function showFindings(reply:LuaBotReply):Void
  {
    for (finding in reply.findings) logLine(finding.level == 'error' ? 'error' : 'warn', 'Line ' + (finding.line + 1) + ': ' + finding.message);

    if (reply.findings.length > 0) markErrorLine(reply.findings[0].line + 1);
  }

  function insertGenerated():Void
  {
    if (pendingCode == null) return;

    if (LuaScan.scan(editor.text).issues.length > 0)
    {
      botSay(
        'bot',
        botPortuguese ? 'Seu script tem blocos sem end. Corrija primeiro, ou use Substituir.' : 'Your script has blocks without an end. Fix them first, or use Replace.'
      );
      return;
    }

    var merged:String = LuaMerge.merge(editor.text, pendingCode);

    applyEdit(merged, 0, 0);

    var error:Null<String> = FunkinLua.checkSyntax(editor.text);

    logLine(error == null ? 'ok' : 'error', error == null ? 'Inserted the generated code. Syntax OK.' : error);
  }

  function replaceWithGenerated():Void
  {
    if (pendingCode == null) return;

    applyEdit(pendingCode, 0, 0);
    logLine('ok', 'Replaced the script with the generated code. Undo brings the old one back.');
  }

  function copyGenerated():Void
  {
    if (pendingCode == null) return;

    Clipboard.text = pendingCode;
    logLine('ok', 'Copied the generated code.');
  }

  function explainLastError():Void
  {
    var message:Null<String> = lastError;

    if (message == null) message = FunkinLua.checkSyntax(editor.text);

    if (message == null)
    {
      botSay(
        'bot',
        botPortuguese ? 'Nao ha erros para explicar. O script passa na checagem de sintaxe.' : 'There is no error to explain. The script passes the syntax check.'
      );
      return;
    }

    botSay('bot', message);
    botSay('bot', LuaBotEngine.explainError(message, apiNames, botPortuguese));
  }

  @:bind(scriptReload, haxe.ui.events.MouseEvent.CLICK)
  function onScriptReloadClick(_):Void
  {
    refreshScripts();
  }

  @:bind(scriptNew, haxe.ui.events.MouseEvent.CLICK)
  function onScriptNewClick(_):Void
  {
    confirmDiscard(newScript);
  }

  @:bind(toolSave, haxe.ui.events.MouseEvent.CLICK)
  function onToolSaveClick(_):Void
  {
    save();
  }

  @:bind(toolCheck, haxe.ui.events.MouseEvent.CLICK)
  function onToolCheckClick(_):Void
  {
    check();
  }

  @:bind(toolRun, haxe.ui.events.MouseEvent.CLICK)
  function onToolRunClick(_):Void
  {
    run();
  }

  @:bind(toolStop, haxe.ui.events.MouseEvent.CLICK)
  function onToolStopClick(_):Void
  {
    stop();
  }

  @:bind(toolUndo, haxe.ui.events.MouseEvent.CLICK)
  function onToolUndoClick(_):Void
  {
    undo();
  }

  @:bind(toolRedo, haxe.ui.events.MouseEvent.CLICK)
  function onToolRedoClick(_):Void
  {
    redo();
  }

  @:bind(findPreviousButton, haxe.ui.events.MouseEvent.CLICK)
  function onFindPreviousClick(_):Void
  {
    findNext(-1);
  }

  @:bind(findNextButton, haxe.ui.events.MouseEvent.CLICK)
  function onFindNextClick(_):Void
  {
    findNext(1);
  }

  @:bind(findReplaceButton, haxe.ui.events.MouseEvent.CLICK)
  function onFindReplaceClick(_):Void
  {
    replaceCurrent();
  }

  @:bind(findReplaceAllButton, haxe.ui.events.MouseEvent.CLICK)
  function onFindReplaceAllClick(_):Void
  {
    replaceAll();
  }

  @:bind(findCloseButton, haxe.ui.events.MouseEvent.CLICK)
  function onFindCloseClick(_):Void
  {
    closeFind();
  }

  @:bind(botInsert, haxe.ui.events.MouseEvent.CLICK)
  function onBotInsertClick(_):Void
  {
    insertGenerated();
  }

  @:bind(botReplace, haxe.ui.events.MouseEvent.CLICK)
  function onBotReplaceClick(_):Void
  {
    replaceWithGenerated();
  }

  @:bind(botCopy, haxe.ui.events.MouseEvent.CLICK)
  function onBotCopyClick(_):Void
  {
    copyGenerated();
  }

  @:bind(botReview, haxe.ui.events.MouseEvent.CLICK)
  function onBotReviewClick(_):Void
  {
    botInput.text = 'review';
    sendBot();
  }

  @:bind(botExplain, haxe.ui.events.MouseEvent.CLICK)
  function onBotExplainClick(_):Void
  {
    explainLastError();
  }

  @:bind(botSend, haxe.ui.events.MouseEvent.CLICK)
  function onBotSendClick(_):Void
  {
    sendBot();
  }

  @:bind(botClear, haxe.ui.events.MouseEvent.CLICK)
  function onBotClearClick(_):Void
  {
    clearBot();
  }

  @:bind(menubarItemNew, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemNewClick(_):Void
  {
    confirmDiscard(newScript);
  }

  @:bind(menubarItemReload, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemReloadClick(_):Void
  {
    refreshScripts();
  }

  @:bind(menubarItemSave, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemSaveClick(_):Void
  {
    save();
  }

  @:bind(menubarItemExit, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemExitClick(_):Void
  {
    requestExit();
  }

  @:bind(menubarItemUndo, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemUndoClick(_):Void
  {
    undo();
  }

  @:bind(menubarItemRedo, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemRedoClick(_):Void
  {
    redo();
  }

  @:bind(menubarItemComment, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemCommentClick(_):Void
  {
    toggleComment();
  }

  @:bind(menubarItemDuplicate, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemDuplicateClick(_):Void
  {
    duplicateLines();
  }

  @:bind(menubarItemDeleteLine, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemDeleteLineClick(_):Void
  {
    deleteLines();
  }

  @:bind(menubarItemMoveUp, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemMoveUpClick(_):Void
  {
    moveLines(-1);
  }

  @:bind(menubarItemMoveDown, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemMoveDownClick(_):Void
  {
    moveLines(1);
  }

  @:bind(menubarItemComplete, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemCompleteClick(_):Void
  {
    updateCompletion(true);
  }

  @:bind(menubarItemFind, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemFindClick(_):Void
  {
    openFind(false);
  }

  @:bind(menubarItemReplace, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemReplaceClick(_):Void
  {
    openFind(true);
  }

  @:bind(menubarItemFindNext, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemFindNextClick(_):Void
  {
    findNext(1);
  }

  @:bind(menubarItemGoto, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemGotoClick(_):Void
  {
    focusGoto();
  }

  @:bind(menubarItemFontLarger, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemFontLargerClick(_):Void
  {
    changeFontSize(1);
  }

  @:bind(menubarItemFontSmaller, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemFontSmallerClick(_):Void
  {
    changeFontSize(-1);
  }

  @:bind(menubarItemClearConsole, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemClearConsoleClick(_):Void
  {
    clearConsole();
  }

  @:bind(menubarItemCheck, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemCheckClick(_):Void
  {
    check();
  }

  @:bind(menubarItemRun, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemRunClick(_):Void
  {
    run();
  }

  @:bind(menubarItemStop, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemStopClick(_):Void
  {
    stop();
  }

  @:bind(menubarItemApi, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemApiClick(_):Void
  {
    printApi();
  }

  @:bind(menubarItemBotReview, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemBotReviewClick(_):Void
  {
    setBotPanel(true);
    botInput.text = 'review';
    sendBot();
  }

  @:bind(menubarItemBotExplain, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemBotExplainClick(_):Void
  {
    setBotPanel(true);
    explainLastError();
  }

  @:bind(menubarItemBotClear, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemBotClearClick(_):Void
  {
    clearBot();
  }

  @:bind(menubarItemGuide, haxe.ui.events.MouseEvent.CLICK)
  function onMenubarItemGuideClick(_):Void
  {
    openGuide();
  }

  @:bind(scriptFilter, UIEvent.CHANGE)
  function onScriptFilterChange(_):Void
  {
    refreshList();
  }

  @:bind(findInput, UIEvent.CHANGE)
  function onFindInputChange(_):Void
  {
    if (findInput.text != null && findInput.text != '') findNext(1, true);
    else
      updateFindInfo();
  }

  @:bind(findCaseBox, UIEvent.CHANGE)
  function onFindCaseChange(_):Void
  {
    findCase = findCaseBox.selected;
    updateFindInfo();
  }

  @:bind(menubarItemBotPanel, UIEvent.CHANGE)
  function onBotPanelChange(_):Void
  {
    if (botPanel.hidden == menubarItemBotPanel.selected) setBotPanel(menubarItemBotPanel.selected);
  }

  @:bind(botRecipes, UIEvent.CHANGE)
  function onBotRecipeChange(_):Void
  {
    if (botRecipes.selectedItem == null) return;

    var recipe = funkin.ui.debug.scripteditor.bot.LuaBotRecipes.find(Std.string(botRecipes.selectedItem.id));

    if (recipe != null) botInput.text = recipe.example;
  }

  @:bind(scriptList, UIEvent.CHANGE)
  function onScriptListChange(_):Void
  {
    if (updatingList || scriptList.selectedItem == null) return;

    var path:String = Std.string(scriptList.selectedItem.path);

    if (path == currentPath) return;

    confirmDiscard(() -> openScript(path), refreshList);
  }

  function clearBot():Void
  {
    botLog.removeAllComponents();
    bot.reset();
    setPendingCode(null);
    botSay('bot', LuaBotEngine.helpText(botPortuguese));
  }

  override function destroy():Void
  {
    #if (FEATURE_SCREENSHOTS && sys)
    funkin.util.plugins.VideoRecorderPlugin.suspended = false;
    #end

    FunkinLua.logSink = null;

    if (runner != null)
    {
      runner.destroy();
      runner = null;
    }

    for (field in [editor, gutter, console, completionField])
    {
      if (field != null && field.parent != null) field.parent.removeChild(field);
    }

    if (FlxG.stage != null) FlxG.stage.focus = null;

    haxe.ui.notifications.NotificationManager.instance.clearNotifications();

    Cursor.hide();

    super.destroy();
  }
}
#end
