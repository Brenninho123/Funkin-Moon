package funkin.ui.debug.scripteditor;

#if FEATURE_LUA_SCRIPTS
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.input.Cursor;
import funkin.lua.FunkinLua;
import funkin.modding.PolymodHandler;
import funkin.ui.MusicBeatState;
import funkin.ui.debug.EditorButton;
import funkin.ui.debug.common.EditorTouch;
import funkin.ui.debug.EditorText;
import funkin.ui.system.FunkinCosmic;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TextEvent;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.ui.Keyboard;

class LuaScriptEditorState extends MusicBeatState
{
  static final LIST_X:Float = 8;
  static final LIST_WIDTH:Int = 260;
  static final EDITOR_X:Float = 276;
  static final GUTTER_WIDTH:Float = 52;
  static final MAX_COMPLETIONS:Int = 8;
  static final MIN_FONT_SIZE:Int = 11;
  static final MAX_FONT_SIZE:Int = 26;
  static final CONSOLE_Y:Float = 490;
  static final CONSOLE_HEIGHT:Float = 222;
  static final MAX_CONSOLE_LINES:Int = 600;
  static final MAX_HIGHLIGHT_LENGTH:Int = 60000;
  static final MAX_UNDO:Int = 200;
  static final TEMPLATE:String = 'function onCreate()\n  debugPrint("script started")\nend\n\nfunction onUpdate(elapsed)\nend\n';

  static final SNIPPETS:Array<{trigger:String, body:String}> = [
    {trigger: 'onCreate', body: 'function onCreate()\n  |\nend\n'},
    {trigger: 'onUpdate', body: 'function onUpdate(elapsed)\n  |\nend\n'},
    {trigger: 'onStepHit', body: 'function onStepHit(step)\n  |\nend\n'},
    {trigger: 'onBeatHit', body: 'function onBeatHit(beat)\n  |\nend\n'},
    {trigger: 'onSongStart', body: 'function onSongStart()\n  |\nend\n'},
    {trigger: 'onNoteHit', body: 'function onNoteHit(judgement, combo)\n  |\nend\n'},
    {trigger: 'onNoteMiss', body: 'function onNoteMiss(healthChange)\n  |\nend\n'},
    {trigger: 'onSongEvent', body: 'function onSongEvent(kind, value)\n  |\nend\n'},
    {trigger: 'function', body: 'function name(|)\n  \nend\n'},
    {trigger: 'for', body: 'for i = 1, 10 do\n  |\nend\n'},
    {trigger: 'foreach', body: 'for key, value in pairs(|) do\n  \nend\n'},
    {trigger: 'if', body: 'if | then\n  \nend\n'},
    {trigger: 'ifelse', body: 'if | then\n  \nelse\n  \nend\n'},
    {trigger: 'while', body: 'while | do\n  \nend\n'}
  ];
  static final LUA_KEYWORDS:Array<String> = [
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then',
    'true', 'until', 'while'
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
  var pathField:TextField;
  var console:TextField;

  var touchMode:Bool = false;
  var fontSize:Int = 15;
  var editorTop:Float = 80;
  var listTop:Float = 80;
  var listRowHeight:Int = 20;
  var listRows:Int = 20;
  var editorWidth:Float = 996;
  var editorHeight:Float = 368;
  var findBarY:Float = 454;
  var barHeight:Int = 26;
  var listDragY:Float = 0.0;
  var listDragging:Bool = false;
  var statusText:FlxText;
  var findField:TextField;
  var replaceField:TextField;
  var gotoField:TextField;
  var completionField:TextField;
  var findInfo:FlxText;
  var findLabels:Array<FlxText> = [];
  var findButtons:Array<EditorButton> = [];
  var caseButton:EditorButton;
  var findVisible:Bool = false;
  var findCase:Bool = false;
  var completionItems:Array<String> = [];
  var completionIndex:Int = 0;
  var completionCaret:Int = -1;
  var errorLine:Int = -1;
  var matchFormat:TextFormat = new TextFormat(null, null, 0xFFE066, true);
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

    touchMode = EditorTouch.enabled;

    var shift:Float = touchMode ? 18.0 : 0.0;

    barHeight = touchMode ? 34 : 26;
    editorTop = 80 + shift;
    listTop = 80 + shift;
    listRowHeight = touchMode ? 30 : 20;
    listRows = touchMode ? 13 : 20;
    editorHeight = 368 - shift;
    editorWidth = FlxG.width - EDITOR_X - 8;
    findBarY = editorTop + editorHeight + 6;
    fontSize = touchMode ? 18 : 15;

    add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF14161A));

    var title:FlxText = new FlxText(16, 10, 0, 'LUA SCRIPT EDITOR', 22);
    title.color = 0xFF8FB8E8;
    add(title);

    statusText = new FlxText(FlxG.width - 270, 14, 262, '', 14);
    statusText.alignment = RIGHT;
    statusText.color = 0xFFAAB2BF;
    add(statusText);

    baseFormat = new TextFormat(resolveFontName(), fontSize, 0xD4D8E0, false, false, false, null, null, TextFormatAlign.LEFT);

    pathField = createField(300, 10, 620, 26, true, false);
    gutter = createField(EDITOR_X, editorTop, GUTTER_WIDTH, editorHeight, false, true);
    gutter.backgroundColor = 0x16181D;
    gutter.selectable = false;
    gutter.mouseEnabled = false;
    gutter.defaultTextFormat = new TextFormat(baseFormat.font, fontSize, 0x5C6370, false, false, false, null, null, TextFormatAlign.RIGHT);
    editor = createField(EDITOR_X + GUTTER_WIDTH, editorTop, editorWidth - GUTTER_WIDTH, editorHeight, true, true);
    console = createField(8, CONSOLE_Y, FlxG.width - 16, CONSOLE_HEIGHT, false, true);
    console.backgroundColor = 0x101216;

    editor.addEventListener(Event.CHANGE, onEditorChange);
    editor.addEventListener(Event.SCROLL, onEditorScroll);
    editor.addEventListener(KeyboardEvent.KEY_DOWN, onEditorKeyDown);
    editor.addEventListener(TextEvent.TEXT_INPUT, onEditorTextInput);

    createFindBar();
    createCompletion();

    createButtons();

    for (i in 0...listRows)
    {
      var row:EditorButton = new EditorButton(LIST_X, listTop + (i * listRowHeight), LIST_WIDTH, listRowHeight - 1, '', true, 0xFF1B1E24);
      row.triggerOnRelease = touchMode;
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

    logLine('info', 'Lua script editor ready. Ctrl+S save, F5 run, F6 stop, F7 check, Ctrl+F find, Ctrl+H replace, Ctrl+G go to line, Ctrl+Space complete, Ctrl+/ comment, Ctrl+D duplicate, Alt+Up/Down move line, Ctrl+Z undo, Esc exit.');
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
      {label: 'UNDO', action: undo},
      {label: 'REDO', action: redo},
      {label: 'FIND', action: () -> openFind(false)},
      {label: 'GOTO', action: focusGoto},
      {label: 'CMT', action: toggleComment},
      {label: 'EXIT', action: requestExit}
    ];

    for (i in 0...buttons.length)
    {
      var button:EditorButton = new EditorButton(8 + (i * 90), 44, 86, barHeight, buttons[i].label);
      button.onClick = buttons[i].action;
      add(button);
    }

    var smaller:EditorButton = new EditorButton(930, 10, 32, barHeight, 'A-');
    smaller.onClick = () -> changeFontSize(-1);
    add(smaller);

    var larger:EditorButton = new EditorButton(966, 10, 32, barHeight, 'A+');
    larger.onClick = () -> changeFontSize(1);
    add(larger);
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

  function handleShortcuts():Void
  {
    var keys = FlxG.keys;
    var ctrl:Bool = keys.pressed.CONTROL;
    var shift:Bool = keys.pressed.SHIFT;
    var alt:Bool = keys.pressed.ALT;

    if (ctrl && keys.justPressed.S) save();
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
    else if (keys.justPressed.F5) run();
    else if (keys.justPressed.F6) stop();
    else if (keys.justPressed.F7) check();
    else if (keys.justPressed.ESCAPE)
    {
      if (completionItems.length > 0) hideCompletion();
      else if (findVisible)
        closeFind();
      else
        requestExit();
    }
  }

  function handleListWheel():Void
  {
    if (touchMode) handleListDrag();

    if (FlxG.mouse.wheel == 0) return;

    if (FlxG.mouse.x < LIST_X || FlxG.mouse.x > LIST_X + LIST_WIDTH || FlxG.mouse.y < listTop || FlxG.mouse.y > listTop + (listRows * listRowHeight)) return;

    listOffset = Std.int(Math.max(0, Math.min(scripts.length - listRows, listOffset - FlxG.mouse.wheel)));

    refreshList();
  }

  function handleListDrag():Void
  {
    var inside:Bool = FlxG.mouse.x >= LIST_X && FlxG.mouse.x <= LIST_X + LIST_WIDTH && FlxG.mouse.y >= listTop && FlxG.mouse.y <= listTop + (listRows * listRowHeight);

    if (FlxG.mouse.justPressed && inside)
    {
      listDragging = true;
      listDragY = FlxG.mouse.y;
    }

    if (!FlxG.mouse.pressed)
    {
      listDragging = false;
      return;
    }

    if (!listDragging) return;

    var moved:Float = FlxG.mouse.y - listDragY;
    var rowsMoved:Int = Std.int(moved / listRowHeight);

    if (rowsMoved == 0) return;

    listDragY += rowsMoved * listRowHeight;
    listOffset = Std.int(Math.max(0, Math.min(scripts.length - listRows, listOffset - rowsMoved)));

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
    for (i in 0...listRows)
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

      gotoLine(line);
      markErrorLine(line);
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

  function createFindBar():Void
  {
    findField = createField(EDITOR_X, findBarY, 230, barHeight, true, false);
    replaceField = createField(EDITOR_X + 236, findBarY, 200, barHeight, true, false);
    gotoField = createField(EDITOR_X + 880, findBarY, 60, barHeight, true, false);

    findField.addEventListener(Event.CHANGE, onFindChange);
    findField.addEventListener(KeyboardEvent.KEY_DOWN, onFindKeyDown);
    replaceField.addEventListener(KeyboardEvent.KEY_DOWN, onReplaceKeyDown);
    gotoField.addEventListener(KeyboardEvent.KEY_DOWN, onGotoKeyDown);

    var actions:Array<{label:String, x:Float, width:Int, action:Void->Void}> = [
      {label: 'PREV', x: EDITOR_X + 442, width: 52, action: () -> findNext(-1)},
      {label: 'NEXT', x: EDITOR_X + 498, width: 52, action: () -> findNext(1)},
      {label: 'REPL', x: EDITOR_X + 554, width: 52, action: replaceCurrent},
      {label: 'ALL', x: EDITOR_X + 610, width: 44, action: replaceAll},
      {label: 'Aa', x: EDITOR_X + 658, width: 36, action: toggleCase},
      {label: 'X', x: EDITOR_X + 698, width: 30, action: closeFind}
    ];

    for (entry in actions)
    {
      var button:EditorButton = new EditorButton(entry.x, findBarY, entry.width, barHeight, entry.label);
      button.onClick = entry.action;
      button.visible = false;
      findButtons.push(button);
      add(button);

      if (entry.label == 'Aa') caseButton = button;
    }

    findInfo = new FlxText(EDITOR_X + 736, findBarY + 5, 140, '', 14);
    findInfo.color = 0xFFAAB2BF;
    findInfo.visible = false;
    add(findInfo);

    var gotoLabel:FlxText = new FlxText(EDITOR_X + 836, findBarY + 5, 44, 'Line', 14);
    gotoLabel.color = 0xFFAAB2BF;
    gotoLabel.visible = false;
    findLabels.push(gotoLabel);
    add(gotoLabel);

    setFindVisible(false);
  }

  function setFindVisible(visible:Bool):Void
  {
    findVisible = visible;

    findField.visible = visible;
    replaceField.visible = visible;
    gotoField.visible = visible;
    findInfo.visible = visible;

    for (button in findButtons) button.visible = visible;
    for (label in findLabels) label.visible = visible;
  }

  function openFind(withReplace:Bool):Void
  {
    setFindVisible(true);

    var selection:String = editor.text.substring(editor.selectionBeginIndex, editor.selectionEndIndex);

    if (selection != '' && selection.indexOf('\n') == -1) findField.text = selection;

    FlxG.stage.focus = withReplace ? replaceField : findField;

    findField.setSelection(0, findField.text.length);

    updateFindInfo();
  }

  function closeFind():Void
  {
    setFindVisible(false);

    FlxG.stage.focus = editor;
  }

  function focusGoto():Void
  {
    setFindVisible(true);

    gotoField.text = '';

    FlxG.stage.focus = gotoField;
  }

  function toggleCase():Void
  {
    findCase = !findCase;
    caseButton.selected = findCase;

    updateFindInfo();
  }

  function onFindChange(_:Event):Void
  {
    findNext(1, true);
  }

  function onFindKeyDown(event:KeyboardEvent):Void
  {
    if (event.keyCode == Keyboard.ENTER) findNext(event.shiftKey ? -1 : 1);
  }

  function onReplaceKeyDown(event:KeyboardEvent):Void
  {
    if (event.keyCode == Keyboard.ENTER) replaceCurrent();
  }

  function onGotoKeyDown(event:KeyboardEvent):Void
  {
    if (event.keyCode != Keyboard.ENTER) return;

    var line:Null<Int> = Std.parseInt(StringTools.trim(gotoField.text));

    if (line == null)
    {
      logLine('warn', 'Type a line number.');
      return;
    }

    gotoLine(line);

    FlxG.stage.focus = editor;
  }

  function haystackFor(text:String):String
  {
    return findCase ? text : text.toLowerCase();
  }

  function findMatches():Array<Int>
  {
    var needle:String = haystackFor(findField.text);
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
      findInfo.text = findField.text == '' ? '' : 'no matches';
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

    selectRange(target, target + findField.text.length);
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

    if (findField.text == '')
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
    var needle:String = findField.text;

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
    var replacement:String = replaceField.text;

    applyEdit(text.substring(0, start) + replacement + text.substring(editor.selectionEndIndex), start + replacement.length, start + replacement.length);
    findNext(1);
  }

  function replaceAll():Void
  {
    var needle:String = findField.text;

    if (needle == '') return;

    var matches:Array<Int> = findMatches();

    if (matches.length == 0)
    {
      findInfo.text = 'no matches';
      return;
    }

    var pattern:EReg = new EReg(REGEX_ESCAPE.replace(needle, '\\$0'), findCase ? 'g' : 'gi');
    var replacement:String = replaceField.text;
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

  function lineRange():{first:Int, last:Int}
  {
    var begin:Int = editor.selectionBeginIndex;
    var end:Int = editor.selectionEndIndex;
    var first:Int = Std.int(Math.max(0, editor.getLineIndexOfChar(begin)));
    var lastChar:Int = end > begin ? end - 1 : end;
    var last:Int = Std.int(Math.max(first, editor.getLineIndexOfChar(Std.int(Math.max(begin, lastChar)))));

    return {first: first, last: Std.int(Math.min(last, editor.numLines - 1))};
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

    completionField = createField(EDITOR_X + GUTTER_WIDTH + 12, editorTop + editorHeight - 120, 320, 110, false, true);
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
    completionField.y = editorTop + editorHeight - completionField.height - 6;
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

    for (field in [editor, gutter, pathField, console, findField, replaceField, gotoField, completionField])
    {
      if (field != null && field.parent != null) field.parent.removeChild(field);
    }

    if (FlxG.stage != null) FlxG.stage.focus = null;

    Cursor.hide();

    super.destroy();
  }
}
#end
