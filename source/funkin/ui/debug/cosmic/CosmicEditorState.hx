package funkin.ui.debug.cosmic;

#if (sys && !mobile)
import flixel.FlxSprite;
import flixel.text.FlxText;
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import funkin.input.Cursor;
import funkin.modding.PolymodHandler;
import funkin.ui.MusicBeatState;
import funkin.ui.debug.EditorButton;
import funkin.ui.debug.EditorText;
import funkin.ui.system.FunkinCosmic;
import funkin.ui.system.FunkinCosmic.FunkinCosmicWatcher;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.ui.Keyboard;
#if FEATURE_LUA_SCRIPTS
import funkin.lua.FunkinLua;
#end

typedef CosmicRoot =
{
  var mount:String;
  var label:String;
  var path:String;
}

typedef CosmicEntry =
{
  var name:String;
  var isDir:Bool;
  var size:Int;
}

class CosmicEditorState extends MusicBeatState
{
  static final LIST_X:Float = 8;
  static final LIST_Y:Float = 80;
  static final LIST_WIDTH:Int = 290;
  static final LIST_ROW_HEIGHT:Int = 20;
  static final LIST_ROWS:Int = 20;
  static final EDITOR_X:Float = 306;
  static final EDITOR_Y:Float = 80;
  static final GUTTER_WIDTH:Float = 52;
  static final EDITOR_WIDTH:Float = 966;
  static final EDITOR_HEIGHT:Float = 400;
  static final CONSOLE_Y:Float = 490;
  static final CONSOLE_HEIGHT:Float = 222;
  static final MAX_CONSOLE_LINES:Int = 600;
  static final MAX_HIGHLIGHT_LENGTH:Int = 60000;
  static final MAX_TEXT_BYTES:Int = 1024 * 1024;
  static final MAX_CHECKSUM_BYTES:Int = 8 * 1024 * 1024;
  static final MAX_UNDO:Int = 200;
  static final CONFIRM_SECONDS:Float = 4.0;
  static final DOUBLE_CLICK_SECONDS:Float = 0.4;
  static final BACKUP_SLOTS_SHOWN:Int = 5;

  static final NUMBER_PATTERN:EReg = ~/\b(0[xX][0-9a-fA-F]+|[0-9]+\.?[0-9]*)\b/g;
  static final LUA_KEYWORDS:EReg = ~/\b(and|break|do|else|elseif|end|false|for|function|goto|if|in|local|nil|not|or|repeat|return|then|true|until|while)\b/g;
  static final HAXE_KEYWORDS:EReg = ~/\b(abstract|break|case|cast|catch|class|continue|default|do|else|enum|extends|false|final|for|function|if|implements|import|in|inline|interface|new|null|override|package|private|public|return|static|switch|this|throw|true|try|typedef|untyped|using|var|while)\b/g;
  static final JSON_KEYWORDS:EReg = ~/\b(true|false|null)\b/g;
  static final STRING_PATTERN:EReg = ~/"(\\.|[^"\\\n])*"|'(\\.|[^'\\\n])*'/g;
  static final LUA_COMMENT:EReg = ~/--[^\n]*/g;
  static final SLASH_COMMENT:EReg = ~/\/\/[^\n]*|\/\*[\s\S]*?\*\//g;
  static final XML_TAG:EReg = ~/<\/?[A-Za-z_?!][^>]*>/g;
  static final XML_COMMENT:EReg = ~/<!--[\s\S]*?-->/g;
  static final POSITION_PATTERN:EReg = ~/position ([0-9]+)/;
  static final LINE_PATTERN:EReg = ~/^[^:]*:([0-9]+):/;

  var roots:Array<CosmicRoot> = [];
  var rootIndex:Int = 0;
  var relDir:String = '';
  var entries:Array<CosmicEntry> = [];
  var listOffset:Int = 0;
  var selectedName:String = '';
  var lastClickTime:Float = 0;
  var rows:Array<EditorButton> = [];

  var editor:TextField;
  var gutter:TextField;
  var pathField:TextField;
  var nameField:TextField;
  var console:TextField;
  var statusText:FlxText;

  var baseFormat:TextFormat;
  var numberFormat:TextFormat = new TextFormat(null, null, 0xD19A66);
  var keywordFormat:TextFormat = new TextFormat(null, null, 0xC678DD);
  var stringFormat:TextFormat = new TextFormat(null, null, 0x98C379);
  var commentFormat:TextFormat = new TextFormat(null, null, 0x6B7280);
  var tagFormat:TextFormat = new TextFormat(null, null, 0x61AFEF);

  var currentFile:Null<String> = null;
  var currentLabel:String = '';
  var language:String = 'plain';
  var readOnly:Bool = true;
  var usesCrlf:Bool = false;
  var dirty:Bool = false;
  var watcher:Null<FunkinCosmicWatcher> = null;
  var selfMtime:Float = -1;

  var previousText:String = '';
  var undoStack:Array<String> = [];
  var redoStack:Array<String> = [];
  var changeClock:Float = 10;
  var highlightTimer:Float = 0;
  var statusTimer:Float = 0;
  var gutterLines:Int = -1;
  var consoleLines:Int = 0;
  var lastStatus:String = '';
  var armedAction:String = '';
  var armedUntil:Float = 0;

  override function create():Void
  {
    super.create();

    add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF14161A));

    var title:FlxText = new FlxText(16, 10, 0, 'COSMIC EDITOR', 22);
    title.color = 0xFF9B8CFF;
    add(title);

    var nameLabel:FlxText = new FlxText(786, 14, 0, 'name:', 14);
    nameLabel.color = 0xFFAAB2BF;
    add(nameLabel);

    statusText = new FlxText(1050, 14, 222, '', 14);
    statusText.alignment = RIGHT;
    statusText.color = 0xFFAAB2BF;
    add(statusText);

    baseFormat = new TextFormat(EditorText.resolveFontName(), 15, 0xD4D8E0, false, false, false, null, null, TextFormatAlign.LEFT);

    pathField = EditorText.createField(baseFormat, 210, 10, 560, 26, true, false);
    nameField = EditorText.createField(baseFormat, 840, 10, 200, 26, true, false);
    gutter = EditorText.createField(baseFormat, EDITOR_X, EDITOR_Y, GUTTER_WIDTH, EDITOR_HEIGHT, false, true);
    gutter.backgroundColor = 0x16181D;
    gutter.selectable = false;
    gutter.mouseEnabled = false;
    gutter.defaultTextFormat = new TextFormat(baseFormat.font, 15, 0x5C6370, false, false, false, null, null, TextFormatAlign.RIGHT);
    editor = EditorText.createField(baseFormat, EDITOR_X + GUTTER_WIDTH, EDITOR_Y, EDITOR_WIDTH - GUTTER_WIDTH, EDITOR_HEIGHT, true, true);
    console = EditorText.createField(baseFormat, 8, CONSOLE_Y, 1264, CONSOLE_HEIGHT, false, true);
    console.backgroundColor = 0x101216;

    editor.addEventListener(Event.CHANGE, onEditorChange);
    editor.addEventListener(Event.SCROLL, onEditorScroll);
    editor.addEventListener(KeyboardEvent.KEY_DOWN, onEditorKeyDown);
    pathField.addEventListener(KeyboardEvent.KEY_DOWN, onPathKeyDown);

    createButtons();

    for (i in 0...LIST_ROWS)
    {
      var row:EditorButton = new EditorButton(LIST_X, LIST_Y + (i * LIST_ROW_HEIGHT), LIST_WIDTH, LIST_ROW_HEIGHT - 1, '', true, 0xFF1B1E24);
      row.visible = false;
      rows.push(row);
      add(row);
    }

    Cursor.show();

    mountRoots();
    setReadOnly(true);
    refreshList();

    logLine('info', 'Cosmic editor ready. Double click to open, Ctrl+S save, F5 reload, F7 check, Ctrl+Z undo, Esc exit.');
    logLine('info', 'Files stay inside the mounted roots (' + [for (root in roots) root.label].join(', ') + '). Saves keep backups you can bring back with RESTORE.');
  }

  function mountRoots():Void
  {
    var cwd:String = Path.removeTrailingSlashes(Path.normalize(Sys.getCwd()));
    var storage:String = Path.removeTrailingSlashes(Path.normalize(lime.system.System.applicationStorageDirectory));
    var modFolder:String = PolymodHandler.getModFolder();
    var modPath:String = Path.isAbsolute(modFolder) ? Path.removeTrailingSlashes(Path.normalize(modFolder)) : cwd + '/' + modFolder;

    roots = [
      {mount: 'cosmic-game', label: 'GAME', path: cwd},
      {mount: 'cosmic-assets', label: 'ASSETS', path: cwd + '/assets'},
      {mount: 'cosmic-mods', label: 'MODS', path: modPath},
      {mount: 'cosmic-data', label: 'DATA', path: storage}
    ];

    for (root in roots) FunkinCosmic.mount(root.mount, root.path);
  }

  function createButtons():Void
  {
    var buttons:Array<{label:String, action:Void->Void}> = [
      {label: 'UP', action: goUp},
      {label: 'ROOT', action: nextRoot},
      {label: 'SAVE', action: save},
      {label: 'RELOAD', action: reload},
      {label: 'NEW FILE', action: createFile},
      {label: 'NEW DIR', action: createDirectory},
      {label: 'RENAME', action: renameSelected},
      {label: 'COPY', action: copySelected},
      {label: 'DELETE', action: deleteSelected},
      {label: 'RESTORE', action: restoreBackup},
      {label: 'INFO', action: showInfo},
      {label: 'EXIT', action: requestExit}
    ];

    for (i in 0...buttons.length)
    {
      var button:EditorButton = new EditorButton(8 + (i * 103), 44, 97, 26, buttons[i].label);
      button.onClick = buttons[i].action;
      add(button);
    }
  }

  function currentRoot():CosmicRoot
  {
    return roots[rootIndex];
  }

  function dirPath():Null<String>
  {
    return FunkinCosmic.resolve(currentRoot().mount, relDir);
  }

  function childRel(name:String):String
  {
    return relDir == '' ? name : relDir + '/' + name;
  }

  function childPath(name:String):Null<String>
  {
    return FunkinCosmic.resolve(currentRoot().mount, childRel(name));
  }

  function displayName(name:String):String
  {
    return currentRoot().label + ':/' + childRel(name);
  }

  static function isValidName(name:String):Bool
  {
    if (name == '' || name == '.' || name == '..' || name.length > 120) return false;

    for (bad in ['/', '\\', ':', '*', '?', '"', '<', '>', '|'])
    {
      if (name.indexOf(bad) != -1) return false;
    }

    return true;
  }

  function confirm(action:String, message:String):Bool
  {
    var now:Float = haxe.Timer.stamp();

    if (armedAction == action && now < armedUntil)
    {
      armedAction = '';
      return true;
    }

    armedAction = action;
    armedUntil = now + CONFIRM_SECONDS;

    logLine('warn', message);

    return false;
  }

  function guardDiscard():Bool
  {
    return !dirty || confirm('discard', 'Unsaved changes. Repeat the action within ' + Std.int(CONFIRM_SECONDS) + ' seconds to discard them.');
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
  }

  function handleShortcuts():Void
  {
    var ctrl:Bool = FlxG.keys.pressed.CONTROL;

    if (ctrl && FlxG.keys.justPressed.S) save();
    else if (ctrl && FlxG.keys.justPressed.Z) undo();
    else if (ctrl && FlxG.keys.justPressed.Y) redo();
    else if (FlxG.keys.justPressed.F5) reload();
    else if (FlxG.keys.justPressed.F7) check();
    else if (FlxG.keys.justPressed.ESCAPE) requestExit();
  }

  function handleListWheel():Void
  {
    if (FlxG.mouse.wheel == 0) return;

    if (FlxG.mouse.x < LIST_X || FlxG.mouse.x > LIST_X + LIST_WIDTH || FlxG.mouse.y < LIST_Y || FlxG.mouse.y > LIST_Y + (LIST_ROWS * LIST_ROW_HEIGHT)) return;

    listOffset = Std.int(Math.max(0, Math.min(entries.length - LIST_ROWS, listOffset - FlxG.mouse.wheel)));

    refreshRows();
  }

  function refreshList():Void
  {
    entries = [];

    var directory:Null<String> = dirPath();

    if (directory == null || !FunkinCosmic.isDirectory(directory))
    {
      logLine('error', 'Cannot open ' + currentRoot().label + ':/' + relDir);
      relDir = '';
      directory = dirPath();
    }

    if (directory != null)
    {
      try
      {
        for (name in sys.FileSystem.readDirectory(directory))
        {
          var full:String = directory + '/' + name;
          var isDir:Bool = sys.FileSystem.isDirectory(full);

          entries.push({name: name, isDir: isDir, size: isDir ? 0 : FunkinCosmic.getFileSize(full)});
        }
      }
      catch (e:Dynamic)
      {
        logLine('error', 'Could not read the folder: $e');
      }
    }

    entries.sort((a, b) ->
    {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;

      var left:String = a.name.toLowerCase();
      var right:String = b.name.toLowerCase();

      return left < right ? -1 : (left > right ? 1 : 0);
    });

    listOffset = 0;
    pathField.text = currentRoot().label + ':/' + relDir;

    refreshRows();
  }

  function refreshRows():Void
  {
    for (i in 0...LIST_ROWS)
    {
      var row:EditorButton = rows[i];
      var index:Int = listOffset + i;

      if (index >= entries.length)
      {
        row.visible = false;
        row.onClick = null;
        continue;
      }

      var entry:CosmicEntry = entries[index];
      var label:String = (entry.isDir ? '[D] ' : '    ') + entry.name;

      row.visible = true;
      row.setLabel(label.length > 36 ? label.substr(0, 34) + '..' : label);
      row.selected = entry.name == selectedName;
      row.onClick = () -> clickEntry(entry);
    }
  }

  function clickEntry(entry:CosmicEntry):Void
  {
    var now:Float = haxe.Timer.stamp();
    var doubleClick:Bool = selectedName == entry.name && now - lastClickTime < DOUBLE_CLICK_SECONDS;

    lastClickTime = now;
    selectedName = entry.name;

    refreshRows();

    if (doubleClick) openEntry(entry);
  }

  function openEntry(entry:CosmicEntry):Void
  {
    if (entry.isDir)
    {
      enterDirectory(childRel(entry.name));
      return;
    }

    var path:Null<String> = childPath(entry.name);

    if (path != null && guardDiscard()) openFile(path, displayName(entry.name));
  }

  function enterDirectory(rel:String):Void
  {
    var path:Null<String> = FunkinCosmic.resolve(currentRoot().mount, rel);

    if (path == null || !FunkinCosmic.isDirectory(path))
    {
      logLine('error', 'Not a folder: ' + currentRoot().label + ':/' + rel);
      return;
    }

    relDir = rel;
    selectedName = '';

    refreshList();
  }

  function goUp():Void
  {
    if (relDir == '')
    {
      logLine('info', 'Already at the top of ' + currentRoot().label);
      return;
    }

    relDir = Path.directory(relDir);
    selectedName = '';

    refreshList();
  }

  function nextRoot():Void
  {
    rootIndex = (rootIndex + 1) % roots.length;
    relDir = '';
    selectedName = '';

    refreshList();

    logLine('info', 'Root ' + currentRoot().label + ' = ' + currentRoot().path);
  }

  function onPathKeyDown(event:KeyboardEvent):Void
  {
    if (event.keyCode != Keyboard.ENTER) return;

    var text:String = StringTools.trim(pathField.text);
    var colon:Int = text.indexOf(':');

    if (colon < 0)
    {
      logLine('error', 'Use ROOT:/folder, for example MODS:/mymod');
      return;
    }

    var label:String = StringTools.trim(text.substr(0, colon)).toUpperCase();
    var rel:String = Path.removeTrailingSlashes(Path.normalize(StringTools.trim(text.substr(colon + 1))));

    while (rel.charAt(0) == '/') rel = rel.substr(1);

    for (i in 0...roots.length)
    {
      if (roots[i].label != label) continue;

      var previousRoot:Int = rootIndex;
      var previousDir:String = relDir;

      rootIndex = i;

      var path:Null<String> = FunkinCosmic.resolve(roots[i].mount, rel);

      if (path == null || !FunkinCosmic.isDirectory(path))
      {
        rootIndex = previousRoot;
        relDir = previousDir;
        logLine('error', 'Not a folder: ' + text);
        pathField.text = currentRoot().label + ':/' + relDir;
        return;
      }

      relDir = rel;
      selectedName = '';

      refreshList();
      return;
    }

    logLine('error', 'Unknown root ' + label + '. Roots: ' + [for (root in roots) root.label].join(', '));
  }

  function setReadOnly(value:Bool):Void
  {
    readOnly = value;
    editor.type = value ? TextFieldType.DYNAMIC : TextFieldType.INPUT;
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
    gutterLines = -1;
    dirty = false;

    refreshGutter();
    applyHighlight();
  }

  static function languageFor(path:String):String
  {
    return switch (Path.extension(path).toLowerCase())
    {
      case 'lua': 'lua';
      case 'hx' | 'hxc' | 'hxs' | 'hscript': 'haxe';
      case 'json' | 'jsonc': 'json';
      case 'xml' | 'html' | 'svg' | 'plist': 'xml';
      default: 'plain';
    };
  }

  function openFile(path:String, label:String):Void
  {
    var size:Int = FunkinCosmic.getFileSize(path);

    if (size < 0)
    {
      logLine('error', 'Cannot read ' + label);
      return;
    }

    closeFile();

    currentFile = path;
    currentLabel = label;
    language = languageFor(path);

    if (size > MAX_TEXT_BYTES)
    {
      setEditorText('');
      logLine('warn', label + ' is ' + size + ' bytes, larger than the 1 MB limit for editing. Use INFO for details.');
      return;
    }

    var bytes:Null<Bytes> = FunkinCosmic.readBytes(path);

    if (bytes == null)
    {
      currentFile = null;
      logLine('error', 'Could not read ' + label);
      return;
    }

    for (i in 0...Std.int(Math.min(bytes.length, 8000)))
    {
      if (bytes.get(i) == 0)
      {
        setEditorText('');
        logLine('warn', label + ' is a binary file (' + size + ' bytes) and cannot be edited as text. Use INFO for details.');
        return;
      }
    }

    var text:String = bytes.toString();

    usesCrlf = text.indexOf('\r\n') != -1;
    text = StringTools.replace(StringTools.replace(text, '\r\n', '\n'), '\r', '\n');

    setReadOnly(false);
    setEditorText(text);

    selfMtime = FunkinCosmic.getModifiedTime(path);
    watcher = FunkinCosmic.watch(path, onFileChangedOnDisk, 1000);

    logLine('info', 'Opened ' + label + ' (' + size + ' bytes, ' + (usesCrlf ? 'CRLF' : 'LF') + ')');
  }

  function closeFile():Void
  {
    if (watcher != null)
    {
      FunkinCosmic.unwatch(watcher);
      watcher = null;
    }

    currentFile = null;
    currentLabel = '';
    language = 'plain';

    setReadOnly(true);
    setEditorText('');
  }

  function onFileChangedOnDisk(path:String):Void
  {
    if (path != currentFile) return;

    var modified:Float = FunkinCosmic.getModifiedTime(path);

    if (modified == selfMtime) return;

    selfMtime = modified;

    logLine('warn', currentLabel + ' changed on disk. Press F5 or RELOAD to load the new version.');
  }

  function reload():Void
  {
    if (currentFile == null)
    {
      refreshList();
      return;
    }

    if (!guardDiscard()) return;

    openFile(currentFile, currentLabel);
  }

  function save():Void
  {
    if (currentFile == null || readOnly)
    {
      logLine('error', 'Nothing to save. Open a text file first.');
      return;
    }

    var text:String = editor.text;

    if (usesCrlf) text = text.split('\n').join('\r\n');

    var problem:Null<String> = validate(editor.text);

    if (!FunkinCosmic.writeTextAtomic(currentFile, text, true))
    {
      logLine('error', 'Could not write ' + currentLabel);
      return;
    }

    dirty = false;
    selfMtime = FunkinCosmic.getModifiedTime(currentFile);

    logLine('ok', 'Saved ' + currentLabel + ' (previous version kept as .bak1)');

    if (problem != null) logLine('warn', 'Saved with a syntax problem: ' + problem);
  }

  function validate(text:String):Null<String>
  {
    switch (language)
    {
      case 'json':
        try
        {
          Json.parse(text);
        }
        catch (e:Dynamic)
        {
          jumpToPosition(Std.string(e));
          return Std.string(e);
        }
      case 'xml':
        try
        {
          Xml.parse(text);
        }
        catch (e:Dynamic)
        {
          return Std.string(e);
        }
      #if FEATURE_LUA_SCRIPTS
      case 'lua':
        var message:Null<String> = FunkinLua.checkSyntax(text);

        if (message != null)
        {
          jumpToLine(message);
          return message;
        }
      #end
      default:
    }

    return null;
  }

  function jumpToPosition(message:String):Void
  {
    if (!POSITION_PATTERN.match(message)) return;

    var position:Int = Std.int(Math.min(Std.parseInt(POSITION_PATTERN.matched(1)) ?? 0, editor.text.length));
    var line:Int = Std.int(Math.max(0, editor.getLineIndexOfChar(position)));

    selectLine(line);
  }

  function jumpToLine(message:String):Void
  {
    if (!LINE_PATTERN.match(message)) return;

    selectLine((Std.parseInt(LINE_PATTERN.matched(1)) ?? 1) - 1);
  }

  function selectLine(line:Int):Void
  {
    var index:Int = Std.int(Math.max(0, Math.min(editor.numLines - 1, line)));

    editor.scrollV = Std.int(Math.max(1, index - 2));
    editor.setSelection(editor.getLineOffset(index), editor.getLineOffset(index) + editor.getLineLength(index));
  }

  function check():Void
  {
    if (currentFile == null || readOnly)
    {
      logLine('error', 'Open a text file first.');
      return;
    }

    if (language == 'plain' || language == 'haxe')
    {
      logLine('info', 'There is no syntax checker for ' + (language == 'haxe' ? 'Haxe' : 'this file type') + '.');
      return;
    }

    var problem:Null<String> = validate(editor.text);

    if (problem == null) logLine('ok', 'Syntax OK');
    else logLine('error', problem);
  }

  function selectedPath():Null<String>
  {
    return selectedName == '' ? null : childPath(selectedName);
  }

  function selectedEntry():Null<CosmicEntry>
  {
    for (entry in entries)
    {
      if (entry.name == selectedName) return entry;
    }

    return null;
  }

  function createFile():Void
  {
    var name:String = StringTools.trim(nameField.text);

    if (!isValidName(name))
    {
      logLine('error', 'Type a valid file name in the name field first.');
      return;
    }

    var path:Null<String> = childPath(name);

    if (path == null || FunkinCosmic.exists(path))
    {
      logLine('error', displayName(name) + ' already exists or is outside the root.');
      return;
    }

    if (!guardDiscard()) return;

    if (!FunkinCosmic.writeTextAtomic(path, '', false))
    {
      logLine('error', 'Could not create ' + displayName(name));
      return;
    }

    selectedName = name;

    refreshList();
    openFile(path, displayName(name));
  }

  function createDirectory():Void
  {
    var name:String = StringTools.trim(nameField.text);

    if (!isValidName(name))
    {
      logLine('error', 'Type a valid folder name in the name field first.');
      return;
    }

    var path:Null<String> = childPath(name);

    if (path == null || FunkinCosmic.exists(path))
    {
      logLine('error', displayName(name) + ' already exists or is outside the root.');
      return;
    }

    if (!FunkinCosmic.createDirectory(path))
    {
      logLine('error', 'Could not create ' + displayName(name));
      return;
    }

    selectedName = name;

    refreshList();
    logLine('ok', 'Created ' + displayName(name));
  }

  function renameSelected():Void
  {
    var source:Null<String> = selectedPath();
    var name:String = StringTools.trim(nameField.text);

    if (source == null || !isValidName(name))
    {
      logLine('error', 'Select an entry and type the new name in the name field.');
      return;
    }

    var target:Null<String> = childPath(name);

    if (target == null || FunkinCosmic.exists(target))
    {
      logLine('error', displayName(name) + ' already exists or is outside the root.');
      return;
    }

    var wasOpen:Bool = source == currentFile;

    if (wasOpen && !guardDiscard()) return;

    if (!FunkinCosmic.moveFile(source, target, false))
    {
      logLine('error', 'Could not rename ' + displayName(selectedName));
      return;
    }

    logLine('ok', 'Renamed ' + displayName(selectedName) + ' to ' + name);

    if (wasOpen) closeFile();

    selectedName = name;

    refreshList();
  }

  function copySelected():Void
  {
    var source:Null<String> = selectedPath();
    var entry:Null<CosmicEntry> = selectedEntry();
    var name:String = StringTools.trim(nameField.text);

    if (source == null || entry == null || !isValidName(name))
    {
      logLine('error', 'Select a file and type the name of the copy in the name field.');
      return;
    }

    if (entry.isDir)
    {
      logLine('error', 'Copying folders is not supported.');
      return;
    }

    var target:Null<String> = childPath(name);

    if (target == null || FunkinCosmic.exists(target))
    {
      logLine('error', displayName(name) + ' already exists or is outside the root.');
      return;
    }

    if (!FunkinCosmic.copyFile(source, target, false))
    {
      logLine('error', 'Could not copy to ' + displayName(name));
      return;
    }

    logLine('ok', 'Copied ' + displayName(selectedName) + ' to ' + name);

    selectedName = name;

    refreshList();
  }

  function deleteSelected():Void
  {
    var path:Null<String> = selectedPath();
    var entry:Null<CosmicEntry> = selectedEntry();

    if (path == null || entry == null)
    {
      logLine('error', 'Select a file or folder to delete.');
      return;
    }

    var label:String = displayName(entry.name);

    if (relDir == '' && (currentRoot().label == 'GAME' || currentRoot().label == 'DATA'))
    {
      logLine('error', 'Top level entries of ' + currentRoot().label + ' are protected. Open the folder and delete items inside it.');
      return;
    }

    if (!confirm('delete:' + path, 'Click DELETE again within ' + Std.int(CONFIRM_SECONDS) + ' seconds to delete ' + label + (entry.isDir ? ' and everything inside it.' : '.'))) return;

    var deleted:Bool = entry.isDir ? FunkinCosmic.deleteDirectory(path, true) : FunkinCosmic.deleteFile(path);

    if (!deleted)
    {
      logLine('error', 'Could not delete ' + label);
      return;
    }

    if (path == currentFile) closeFile();

    logLine('ok', 'Deleted ' + label);

    selectedName = '';

    refreshList();
  }

  function restoreBackup():Void
  {
    if (currentFile == null || readOnly)
    {
      logLine('error', 'Open a text file first.');
      return;
    }

    var slot:Int = Std.int(Math.max(1, Std.parseInt(StringTools.trim(nameField.text)) ?? 1));

    if (!FunkinCosmic.exists(currentFile + '.bak' + slot))
    {
      logLine('error', currentLabel + ' has no backup in slot ' + slot + '. Type a slot number in the name field (INFO lists them).');
      return;
    }

    if (!confirm('restore', 'This replaces ' + currentLabel + ' with backup slot ' + slot + '. Click RESTORE again within ' + Std.int(CONFIRM_SECONDS) + ' seconds.')) return;

    if (!FunkinCosmic.restoreBackup(currentFile, slot))
    {
      logLine('error', 'Could not restore slot ' + slot);
      return;
    }

    var path:String = currentFile;
    var label:String = currentLabel;

    openFile(path, label);

    logLine('ok', 'Restored backup slot ' + slot);
  }

  function showInfo():Void
  {
    var path:Null<String> = selectedPath() ?? currentFile;

    if (path == null)
    {
      logLine('error', 'Select a file or folder first.');
      return;
    }

    logLine('info', 'Path: ' + path);

    if (FunkinCosmic.isDirectory(path))
    {
      var count:Int = 0;

      try
      {
        count = sys.FileSystem.readDirectory(path).length;
      }
      catch (e:Dynamic) {}

      logLine('info', 'Folder with ' + count + ' entries');
      return;
    }

    var size:Int = FunkinCosmic.getFileSize(path);

    logLine('info', 'Size: ' + size + ' bytes');
    logLine('info', 'Modified: ' + Date.fromTime(FunkinCosmic.getModifiedTime(path)).toString());

    if (size >= 0 && size <= MAX_CHECKSUM_BYTES) logLine('info', 'MD5: ' + (FunkinCosmic.checksum(path) ?? 'unavailable'));

    var backups:Array<String> = [];

    for (slot in 1...BACKUP_SLOTS_SHOWN + 1)
    {
      var backup:String = path + '.bak' + slot;

      if (FunkinCosmic.exists(backup)) backups.push('slot ' + slot + ' (' + FunkinCosmic.getFileSize(backup) + ' bytes, ' + Date.fromTime(FunkinCosmic.getModifiedTime(backup)).toString() + ')');
    }

    logLine('info', backups.length == 0 ? 'Backups: none' : 'Backups: ' + backups.join('; '));
  }

  function onEditorChange(_:Event):Void
  {
    if (readOnly) return;

    dirty = true;
    armedAction = '';

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
    if (readOnly || event.keyCode != Keyboard.TAB) return;

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
    if (readOnly || undoStack.length == 0) return;

    redoStack.push(editor.text);

    replaceText(undoStack.pop());
  }

  function redo():Void
  {
    if (readOnly || redoStack.length == 0) return;

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

    switch (language)
    {
      case 'lua':
        EditorText.highlightMatches(editor, NUMBER_PATTERN, numberFormat);
        EditorText.highlightMatches(editor, LUA_KEYWORDS, keywordFormat);
        EditorText.highlightMatches(editor, STRING_PATTERN, stringFormat);
        EditorText.highlightMatches(editor, LUA_COMMENT, commentFormat);
      case 'haxe':
        EditorText.highlightMatches(editor, NUMBER_PATTERN, numberFormat);
        EditorText.highlightMatches(editor, HAXE_KEYWORDS, keywordFormat);
        EditorText.highlightMatches(editor, STRING_PATTERN, stringFormat);
        EditorText.highlightMatches(editor, SLASH_COMMENT, commentFormat);
      case 'json':
        EditorText.highlightMatches(editor, NUMBER_PATTERN, numberFormat);
        EditorText.highlightMatches(editor, JSON_KEYWORDS, keywordFormat);
        EditorText.highlightMatches(editor, STRING_PATTERN, stringFormat);
      case 'xml':
        EditorText.highlightMatches(editor, XML_TAG, tagFormat);
        EditorText.highlightMatches(editor, STRING_PATTERN, stringFormat);
        EditorText.highlightMatches(editor, XML_COMMENT, commentFormat);
      default:
    }
  }

  function updateStatus():Void
  {
    var caret:Int = editor.caretIndex;
    var line:Int = Std.int(Math.max(0, editor.getLineIndexOfChar(caret)));
    var column:Int = caret - editor.getLineOffset(line) + 1;
    var status:String = currentFile == null ? 'no file' : 'Ln ${line + 1}, Col $column' + (dirty ? '  MODIFIED' : '') + (readOnly ? '  READ-ONLY' : '');

    if (status == lastStatus) return;

    lastStatus = status;
    statusText.text = status;
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

  function clearConsole():Void
  {
    console.text = '';
    consoleLines = 0;
  }

  function requestExit():Void
  {
    if (!guardDiscard()) return;

    FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
  }

  override function destroy():Void
  {
    if (watcher != null)
    {
      FunkinCosmic.unwatch(watcher);
      watcher = null;
    }

    for (root in roots) FunkinCosmic.unmount(root.mount);

    for (field in [editor, gutter, pathField, nameField, console])
    {
      if (field != null && field.parent != null) field.parent.removeChild(field);
    }

    if (FlxG.stage != null) FlxG.stage.focus = null;

    Cursor.hide();

    super.destroy();
  }
}
#end
