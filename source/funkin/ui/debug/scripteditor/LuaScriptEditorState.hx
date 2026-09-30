package funkin.ui.debug.scripteditor;

#if (FEATURE_LUA_SCRIPTS && !mobile)
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.input.Cursor;
import funkin.lua.FunkinLua;
import funkin.modding.PolymodHandler;
import funkin.ui.MusicBeatState;
import funkin.ui.debug.EditorButton;
import funkin.ui.debug.EditorText;
import funkin.ui.system.FunkinCosmic;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.ui.Keyboard;

class LuaScriptEditorState extends MusicBeatState
{
  static final LIST_X:Float = 8;
  static final LIST_Y:Float = 80;
  static final LIST_WIDTH:Int = 260;
  static final LIST_ROW_HEIGHT:Int = 20;
  static final LIST_ROWS:Int = 20;
  static final EDITOR_X:Float = 276;
  static final EDITOR_Y:Float = 80;
  static final GUTTER_WIDTH:Float = 52;
  static final EDITOR_WIDTH:Float = 996;
  static final EDITOR_HEIGHT:Float = 400;
  static final CONSOLE_Y:Float = 490;
  static final CONSOLE_HEIGHT:Float = 222;
  static final MAX_CONSOLE_LINES:Int = 600;
  static final MAX_HIGHLIGHT_LENGTH:Int = 60000;
  static final MAX_UNDO:Int = 200;
  static final TEMPLATE:String = 'function onCreate()\n  debugPrint("script started")\nend\n\nfunction onUpdate(elapsed)\nend\n';

  static final KEYWORD_PATTERN:EReg = ~/\b(and|break|do|else|elseif|end|false|for|function|goto|if|in|local|nil|not|or|repeat|return|then|true|until|while)\b/g;
  static final NUMBER_PATTERN:EReg = ~/\b(0[xX][0-9a-fA-F]+|[0-9]+\.?[0-9]*)\b/g;
  static final STRING_PATTERN:EReg = ~/"(\\.|[^"\\\n])*"|'(\\.|[^'\\\n])*'/g;
  static final COMMENT_PATTERN:EReg = ~/--[^\n]*/g;
  static final ERROR_LINE_PATTERN:EReg = ~/^[^:]*:([0-9]+):/;

  var editor:TextField;
  var gutter:TextField;
  var pathField:TextField;
  var console:TextField;

  var statusText:FlxText;
  var rows:Array<EditorButton> = [];

  var baseFormat:TextFormat;
  var numberFormat:TextFormat = new TextFormat(null, null, 0xD19A66);
  var keywordFormat:TextFormat = new TextFormat(null, null, 0xC678DD);
  var apiFormat:TextFormat = new TextFormat(null, null, 0x61AFEF);
  var stringFormat:TextFormat = new TextFormat(null, null, 0x98C379);
  var commentFormat:TextFormat = new TextFormat(null, null, 0x6B7280);
  var apiPattern:Null<EReg> = null;

  var scripts:Array<String> = [];
  var listOffset:Int = 0;
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

  override function create():Void
  {
    super.create();

    add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF14161A));

    var title:FlxText = new FlxText(16, 10, 0, 'LUA SCRIPT EDITOR', 22);
    title.color = 0xFF8FB8E8;
    add(title);

    statusText = new FlxText(1010, 14, 262, '', 14);
    statusText.alignment = RIGHT;
    statusText.color = 0xFFAAB2BF;
    add(statusText);

    baseFormat = new TextFormat(resolveFontName(), 15, 0xD4D8E0, false, false, false, null, null, TextFormatAlign.LEFT);

    pathField = createField(300, 10, 700, 26, true, false);
    gutter = createField(EDITOR_X, EDITOR_Y, GUTTER_WIDTH, EDITOR_HEIGHT, false, true);
    gutter.backgroundColor = 0x16181D;
    gutter.selectable = false;
    gutter.mouseEnabled = false;
    gutter.defaultTextFormat = new TextFormat(baseFormat.font, 15, 0x5C6370, false, false, false, null, null, TextFormatAlign.RIGHT);
    editor = createField(EDITOR_X + GUTTER_WIDTH, EDITOR_Y, EDITOR_WIDTH - GUTTER_WIDTH, EDITOR_HEIGHT, true, true);
    console = createField(8, CONSOLE_Y, 1264, CONSOLE_HEIGHT, false, true);
    console.backgroundColor = 0x101216;

    editor.addEventListener(Event.CHANGE, onEditorChange);
    editor.addEventListener(Event.SCROLL, onEditorScroll);
    editor.addEventListener(KeyboardEvent.KEY_DOWN, onEditorKeyDown);

    createButtons();

    for (i in 0...LIST_ROWS)
    {
      var row:EditorButton = new EditorButton(LIST_X, LIST_Y + (i * LIST_ROW_HEIGHT), LIST_WIDTH, LIST_ROW_HEIGHT - 1, '', true, 0xFF1B1E24);
      row.visible = false;
      rows.push(row);
      add(row);
    }

    var apiNames:Array<String> = FunkinLua.getApiNames();

    apiPattern = new EReg('\\b(' + apiNames.join('|') + ')\\b', 'g');

    FunkinLua.logSink = onLuaLog;

    Cursor.show();

    refreshScripts();
    newScript();

    logLine('info', 'Lua script editor ready. Ctrl+S save, F5 run, F6 stop, F7 check syntax, Ctrl+Z undo, Esc exit.');
  }

  function resolveFontName():String
  {
    return EditorText.resolveFontName();
  }

  function createField(x:Float, y:Float, width:Float, height:Float, input:Bool, multiline:Bool):TextField
  {
    return EditorText.createField(baseFormat, x, y, width, height, input, multiline);
  }

  function createButtons():Void
  {
    var buttons:Array<{label:String, action:Void->Void}> = [
      {label: 'SAVE', action: save},
      {label: 'CHECK', action: check},
      {label: 'RUN', action: run},
      {label: 'STOP', action: stop},
      {label: 'NEW', action: newScript},
      {label: 'RELOAD', action: refreshScripts},
      {label: 'API', action: printApi},
      {label: 'CLEAR', action: clearConsole},
      {label: 'EXIT', action: requestExit}
    ];

    for (i in 0...buttons.length)
    {
      var button:EditorButton = new EditorButton(8 + (i * 96), 44, 90, 26, buttons[i].label);
      button.onClick = buttons[i].action;
      add(button);
    }
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    changeClock += elapsed;

    handleShortcuts();
    handleListWheel();

    if (highlightTimer > 0)
    {
      highlightTimer -= elapsed;

      if (highlightTimer <= 0) applyHighlight();
    }

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

  function handleShortcuts():Void
  {
    var ctrl:Bool = FlxG.keys.pressed.CONTROL;

    if (ctrl && FlxG.keys.justPressed.S) save();
    else if (ctrl && FlxG.keys.justPressed.Z) undo();
    else if (ctrl && FlxG.keys.justPressed.Y) redo();
    else if (FlxG.keys.justPressed.F5) run();
    else if (FlxG.keys.justPressed.F6) stop();
    else if (FlxG.keys.justPressed.F7) check();
    else if (FlxG.keys.justPressed.ESCAPE) requestExit();
  }

  function handleListWheel():Void
  {
    if (FlxG.mouse.wheel == 0) return;

    if (FlxG.mouse.x < LIST_X || FlxG.mouse.x > LIST_X + LIST_WIDTH || FlxG.mouse.y < LIST_Y || FlxG.mouse.y > LIST_Y + (LIST_ROWS * LIST_ROW_HEIGHT)) return;

    listOffset = Std.int(Math.max(0, Math.min(scripts.length - LIST_ROWS, listOffset - FlxG.mouse.wheel)));

    refreshList();
  }

  function refreshScripts():Void
  {
    scripts = [];

    #if sys
    scanLua('assets/songs', scripts, 0);
    scanLua(PolymodHandler.getModFolder(), scripts, 0);
    #end

    scripts.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));

    listOffset = 0;

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
    for (i in 0...LIST_ROWS)
    {
      var row:EditorButton = rows[i];
      var index:Int = listOffset + i;

      if (index >= scripts.length)
      {
        row.visible = false;
        row.onClick = null;
        continue;
      }

      var path:String = scripts[index];
      var shown:String = path.length > 34 ? '..' + path.substr(path.length - 32) : path;

      row.visible = true;
      row.setLabel(shown);
      row.selected = path == currentPath;
      row.onClick = () -> openScript(path);
    }
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
    pathField.text = path;

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
    pathField.text = path;

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

    refreshGutter();

    highlightTimer = 0.3;
  }

  function onEditorScroll(_:Event):Void
  {
    gutter.scrollV = editor.scrollV;
  }

  function onEditorKeyDown(event:KeyboardEvent):Void
  {
    if (event.keyCode != Keyboard.TAB) return;

    editor.replaceSelectedText('  ');

    event.preventDefault();

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
    var status:String = 'Ln ${line + 1}, Col $column' + (dirty ? '  MODIFIED' : '') + (runner != null ? '  RUNNING' : '');

    if (status == lastStatus) return;

    lastStatus = status;
    statusText.text = status;
  }

  function save():Void
  {
    var path:String = StringTools.trim(pathField.text).split('\\').join('/');

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
    else refreshList();
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

    if (ERROR_LINE_PATTERN.match(message))
    {
      var line:Int = Std.parseInt(ERROR_LINE_PATTERN.matched(1)) ?? 1;
      var index:Int = Std.int(Math.max(0, Math.min(editor.numLines - 1, line - 1)));

      editor.scrollV = Std.int(Math.max(1, line - 3));
      editor.setSelection(editor.getLineOffset(index), editor.getLineOffset(index) + editor.getLineLength(index));
    }

    return false;
  }

  function run():Void
  {
    stop();

    if (!check()) return;

    var name:String = StringTools.trim(pathField.text);

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
    logLine(level, message);
  }

  function logLine(level:String, message:String):Void
  {
    if (console == null) return;

    if (consoleLines >= MAX_CONSOLE_LINES) clearConsole();

    var color:Int = switch (level)
    {
      case 'error': 0xFF6B6B;
      case 'warn': 0xFFD166;
      case 'ok': 0x7CFC9A;
      default: 0xC8D0DA;
    };

    var start:Int = console.text.length;

    console.appendText(message + '\n');
    console.setTextFormat(new TextFormat(null, null, color), start, console.text.length);

    consoleLines++;

    console.scrollV = console.maxScrollV;
  }

  function requestExit():Void
  {
    if (dirty && !exitArmed)
    {
      exitArmed = true;
      logLine('warn', 'Unsaved changes. Press ESC or EXIT again to discard them.');
      return;
    }

    stop();

    FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
  }

  override function destroy():Void
  {
    FunkinLua.logSink = null;

    if (runner != null)
    {
      runner.destroy();
      runner = null;
    }

    for (field in [editor, gutter, pathField, console])
    {
      if (field != null && field.parent != null) field.parent.removeChild(field);
    }

    if (FlxG.stage != null) FlxG.stage.focus = null;

    Cursor.hide();

    super.destroy();
  }
}
#end
