package funkin.ui.debug.cosmic;

#if (sys && !mobile && FEATURE_HAXEUI)
import flixel.FlxSprite;
import funkin.graphics.FunkinCamera;
import funkin.input.Cursor;
import funkin.modding.ModDoctor;
import funkin.modding.PolymodHandler;
import funkin.ui.debug.common.EditorTouch;
import funkin.ui.debug.cosmic.CosmicRestoreDialog.CosmicBackup;
import funkin.ui.debug.EditorText;
import funkin.ui.system.FunkinCosmic;
import funkin.ui.system.FunkinCosmic.FunkinCosmicWatcher;
import funkin.ui.title.TitleConfig;
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.ui.backend.flixel.UIState;
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.containers.dialogs.MessageBox.MessageBoxType;
import haxe.ui.containers.windows.WindowManager;
import haxe.ui.core.Screen;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import haxe.ui.focus.FocusManager;
import haxe.ui.notifications.NotificationManager;
import haxe.ui.notifications.NotificationType;
import openfl.display.BitmapData;
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

@:build(haxe.ui.ComponentBuilder.build('assets/exclude/ui/editors/cosmic-editor/main-view.xml'))
class CosmicEditorState extends UIState
{
  static final GUTTER_WIDTH:Float = 52;
  static final MIN_FONT_SIZE:Int = 11;
  static final MAX_FONT_SIZE:Int = 26;
  static final MAX_CONSOLE_LINES:Int = 600;
  static final MAX_HIGHLIGHT_LENGTH:Int = 60000;
  static final MAX_TEXT_BYTES:Int = 1024 * 1024;
  static final MAX_CHECKSUM_BYTES:Int = 8 * 1024 * 1024;
  static final MAX_UNDO:Int = 200;
  static final BACKUP_SLOTS_SHOWN:Int = 5;
  static final META_TEMPLATE:String = '{\n  "title": "%TITLE%",\n  "description": "A new mod.",\n  "contributors": [\n    {\n      "name": "Your name"\n    }\n  ],\n  "api_version": "%API%",\n  "mod_version": "1.0.0",\n  "license": "All Rights Reserved"\n}\n';

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
  static final REGEX_ESCAPE:EReg = ~/[.*+?^$|(){}\[\]\\]/g;
  static final MOD_ID_PATTERN:EReg = ~/^[A-Za-z0-9_\-]+$/;

  var roots:Array<CosmicRoot> = [];
  var rootIndex:Int = 0;
  var relDir:String = '';
  var entries:Array<CosmicEntry> = [];
  var selectedName:String = '';

  var editor:TextField;
  var gutter:TextField;
  var console:TextField;

  var camBackdrop:FunkinCamera;
  var camUI:FunkinCamera;
  var editorSnapshot:FlxSprite;
  var gutterSnapshot:FlxSprite;
  var consoleSnapshot:FlxSprite;
  var overlayShown:Bool = false;
  var lastLayout:String = '';
  var lastNativeFocus:Bool = false;
  var lastHaxeFocus:Bool = false;
  var updatingList:Bool = true;
  var touchMode:Bool = false;
  var fontSize:Int = 15;
  var findVisible:Bool = false;
  var findCase:Bool = false;
  var matchFormat:TextFormat = new TextFormat(null, null, 0xFFE066, true);

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
  var dialogOpen:Bool = false;
  var exitDialog:Null<Dialog> = null;

  override function create():Void
  {
    WindowManager.instance.reset();

    camBackdrop = new FunkinCamera('cosmicEditorBackdrop');
    camBackdrop.bgColor = 0xFF14161A;
    camUI = new FunkinCamera('cosmicEditorUI');
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

    baseFormat = new TextFormat(EditorText.resolveFontName(), fontSize, 0xD4D8E0, false, false, false, null, null, TextFormatAlign.LEFT);

    gutter = EditorText.createField(baseFormat, 0, 0, GUTTER_WIDTH, 100, false, true);
    gutter.backgroundColor = 0x16181D;
    gutter.selectable = false;
    gutter.mouseEnabled = false;
    gutter.defaultTextFormat = new TextFormat(baseFormat.font, fontSize, 0x5C6370, false, false, false, null, null, TextFormatAlign.RIGHT);
    editor = EditorText.createField(baseFormat, 0, 0, 400, 100, true, true);
    console = EditorText.createField(baseFormat, 0, 0, 400, 100, false, true);
    console.backgroundColor = 0x101216;

    editor.addEventListener(Event.CHANGE, onEditorChange);
    editor.addEventListener(Event.SCROLL, onEditorScroll);
    editor.addEventListener(KeyboardEvent.KEY_DOWN, onEditorKeyDown);

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

    registerInputEvents();

    Cursor.show();

    mountRoots();
    setReadOnly(true);

    for (item in roots) rootPicker.dataSource.add({text: item.label});

    rootPicker.selectedIndex = 0;

    refreshList();
    updatingList = false;

    logLine('info', 'Cosmic editor ready. Double click opens, Ctrl+S saves, F5 reloads, F7 checks, F8 runs the Mod Doctor, F1 opens the guide, Esc leaves.');
    logLine('info', 'Files stay inside the mounted roots (' + [for (item in roots) item.label].join(', ') + '). Saves keep backups you can bring back from File > Restore a Backup.');

    haxe.ui.Toolkit.callLater(() ->
    {
      var focused = FocusManager.instance.focus;

      if (focused != null) focused.focus = false;
    });
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

    for (item in roots) FunkinCosmic.mount(item.mount, item.path);
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

    statusTimer += elapsed;

    if (statusTimer >= 0.1)
    {
      statusTimer = 0;
      updateStatus();
    }
  }

  function placeField(field:TextField, x:Float, y:Float, width:Float, height:Float):Void
  {
    field.x = x;
    field.y = y;
    field.width = Math.max(40, width);
    field.height = Math.max(24, height);
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
    var open:Bool = overlayOpen();

    if (open == overlayShown) return;

    overlayShown = open;

    if (open) captureSnapshots();

    for (field in [gutter, editor, console]) field.visible = !open;

    for (snapshot in [gutterSnapshot, editorSnapshot, consoleSnapshot]) snapshot.visible = open;
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

    return focused != null
      && (Std.isOfType(focused, haxe.ui.components.TextField) || Std.isOfType(focused, haxe.ui.components.NumberStepper)
        || Std.isOfType(focused, haxe.ui.components.DropDown));
  }

  function handleShortcuts():Void
  {
    if (dialogOpen) return;

    var keys = FlxG.keys;
    var ctrl:Bool = keys.pressed.CONTROL;
    var shift:Bool = keys.pressed.SHIFT;
    var typing:Bool = isTypingInUI();
    var inEditor:Bool = FlxG.stage.focus == editor;

    if (keys.justPressed.F1)
    {
      openGuide();
      return;
    }

    if (ctrl && keys.justPressed.S) save();
    else if (keys.justPressed.F5) reload();
    else if (keys.justPressed.F7) check();
    else if (keys.justPressed.F8) openModDoctor();
    else if (keys.justPressed.ESCAPE)
    {
      if (findVisible) closeFind();
      else if (typing)
        FocusManager.instance.focus.focus = false;
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
    else if (ctrl && keys.justPressed.PLUS) changeFontSize(1);
    else if (ctrl && keys.justPressed.MINUS) changeFontSize(-1);
    else if (keys.justPressed.F4) findNext(shift ? -1 : 1);
    else if (keys.justPressed.F3) showInfo();
    else if (keys.justPressed.F2 && !inEditor) renameSelected();
    else if (keys.justPressed.DELETE && !inEditor) deleteSelected();
    else if (keys.justPressed.ENTER && !inEditor && fileList.focus) openSelected();
  }

  function currentRoot():CosmicRoot
  {
    return roots[rootIndex];
  }

  function rootPrefix():String
  {
    return currentRoot().label + ':/';
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
    return rootPrefix() + childRel(name);
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

  function toast(message:String, type:NotificationType = NotificationType.Info):Void
  {
    NotificationManager.instance.addNotification({
      title: switch (type)
      {
        case NotificationType.Success: 'Done';
        case NotificationType.Warning: 'Careful';
        case NotificationType.Error: 'Error';
        default: 'Cosmic Editor';
      },
      body: message,
      type: type,
      expiryMs: Constants.NOTIFICATION_DISMISS_TIME
    });
  }

  function fail(message:String):Void
  {
    logLine('error', message);
    toast(message, NotificationType.Error);
  }

  function formatSize(size:Int):String
  {
    if (size < 1024) return size + ' B';
    if (size < 1024 * 1024) return Std.int(size / 102.4) / 10 + ' KB';

    return Std.int(size / 104857.6) / 10 + ' MB';
  }

  function refreshList():Void
  {
    entries = [];

    var directory:Null<String> = dirPath();

    if (directory == null || !FunkinCosmic.isDirectory(directory))
    {
      logLine('error', 'Cannot open ' + rootPrefix() + relDir);
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

    pathInput.text = rootPrefix() + relDir;

    renderList();
  }

  function renderList():Void
  {
    var filter:String = listFilter.text != null ? listFilter.text.toLowerCase() : '';
    var previous:Bool = updatingList;

    updatingList = true;

    fileList.dataSource.clear();

    var selectedIndex:Int = -1;
    var count:Int = 0;

    for (entry in entries)
    {
      if (filter != '' && entry.name.toLowerCase().indexOf(filter) < 0) continue;

      var label:String = entry.isDir ? '[D]  ' + entry.name : '       ' + entry.name + '   ' + formatSize(entry.size);

      fileList.dataSource.add({text: label, name: entry.name, isDir: entry.isDir});

      if (entry.name == selectedName) selectedIndex = count;

      count++;
    }

    if (selectedIndex >= 0) fileList.selectedIndex = selectedIndex;

    updatingList = previous;
  }

  function selectedEntry():Null<CosmicEntry>
  {
    for (entry in entries)
    {
      if (entry.name == selectedName) return entry;
    }

    return null;
  }

  function selectedPath():Null<String>
  {
    return selectedName == '' ? null : childPath(selectedName);
  }

  function openSelected():Void
  {
    var entry:Null<CosmicEntry> = selectedEntry();

    if (entry == null)
    {
      logLine('warn', 'Select a file or folder first.');
      return;
    }

    if (entry.isDir)
    {
      enterDirectory(childRel(entry.name));
      return;
    }

    var path:Null<String> = childPath(entry.name);

    if (path != null) confirmDiscard(() -> openFile(path, displayName(entry.name)));
  }

  function enterDirectory(rel:String):Void
  {
    var path:Null<String> = FunkinCosmic.resolve(currentRoot().mount, rel);

    if (path == null || !FunkinCosmic.isDirectory(path))
    {
      logLine('error', 'Not a folder: ' + rootPrefix() + rel);
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

  function switchRoot(index:Int):Void
  {
    if (index < 0 || index >= roots.length || index == rootIndex) return;

    rootIndex = index;
    relDir = '';
    selectedName = '';

    refreshList();

    logLine('info', 'Root ' + currentRoot().label + ' = ' + currentRoot().path);
  }

  function submitPath():Void
  {
    var text:String = StringTools.trim(pathInput.text);
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

      var path:Null<String> = FunkinCosmic.resolve(roots[i].mount, rel);

      if (path == null || !FunkinCosmic.isDirectory(path))
      {
        logLine('error', 'Not a folder: ' + text);
        pathInput.text = rootPrefix() + relDir;
        return;
      }

      rootIndex = i;
      relDir = rel;
      selectedName = '';

      updatingList = true;
      rootPicker.selectedIndex = i;
      updatingList = false;

      refreshList();
      return;
    }

    logLine('error', 'Unknown root ' + label + '. Roots: ' + [for (item in roots) item.label].join(', '));
  }

  function registerInputEvents():Void
  {
    pathInput.registerEvent(haxe.ui.events.KeyboardEvent.KEY_DOWN, function(event:haxe.ui.events.KeyboardEvent):Void
    {
      if (event.keyCode == 13) submitPath();
    });

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

    fileList.registerEvent(haxe.ui.events.MouseEvent.DBL_CLICK, function(_):Void
    {
      openSelected();
    });
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
    updateFileLabel();
  }

  function updateFileLabel():Void
  {
    fileLabel.text = currentFile == null ? 'No file open' : currentLabel + (dirty ? '  *' : '') + (readOnly ? '  (read only)' : '');
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
      fail('Cannot read ' + label);
      return;
    }

    closeFile();

    currentFile = path;
    currentLabel = label;
    language = languageFor(path);

    if (size > MAX_TEXT_BYTES)
    {
      setEditorText('');
      logLine('warn', label + ' is ' + size + ' bytes, larger than the 1 MB limit for editing. Use File Info for details.');
      return;
    }

    var bytes:Null<Bytes> = FunkinCosmic.readBytes(path);

    if (bytes == null)
    {
      currentFile = null;
      fail('Could not read ' + label);
      return;
    }

    for (i in 0...Std.int(Math.min(bytes.length, 8000)))
    {
      if (bytes.get(i) == 0)
      {
        setEditorText('');
        logLine('warn', label + ' is a binary file (' + size + ' bytes) and cannot be edited as text. Use File Info for details.');
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

    logLine('warn', currentLabel + ' changed on disk. Press F5 or Reload to load the new version.');
  }

  function reload():Void
  {
    if (currentFile == null)
    {
      refreshList();
      return;
    }

    var path:String = currentFile;
    var label:String = currentLabel;

    confirmDiscard(() -> openFile(path, label));
  }

  function save():Void
  {
    if (currentFile == null || readOnly)
    {
      fail('Nothing to save. Open a text file first.');
      return;
    }

    var text:String = editor.text;

    if (usesCrlf) text = text.split('\n').join('\r\n');

    var problems:Array<String> = validate(editor.text);

    if (!FunkinCosmic.writeTextAtomic(currentFile, text, true))
    {
      fail('Could not write ' + currentLabel);
      return;
    }

    dirty = false;
    selfMtime = FunkinCosmic.getModifiedTime(currentFile);

    updateFileLabel();
    logLine('ok', 'Saved ' + currentLabel + ' (previous version kept as .bak1)');
    toast('Saved ' + currentLabel, NotificationType.Success);

    for (problem in problems) logLine(StringTools.startsWith(problem, 'ERROR') ? 'error' : 'warn', problem);

    if (problems.length > 0) toast('Saved with ' + problems.length + ' problem' + (problems.length == 1 ? '' : 's') + '. See the console.', NotificationType.Warning);
  }

  function fileName():String
  {
    return currentFile == null ? '' : Path.withoutDirectory(currentFile).toLowerCase();
  }

  function validate(text:String):Array<String>
  {
    var problems:Array<String> = [];

    switch (language)
    {
      case 'json':
        var parsed:Bool = true;

        try
        {
          Json.parse(text);
        }
        catch (e:Dynamic)
        {
          parsed = false;
          jumpToPosition(Std.string(e));
          problems.push('ERROR ' + Std.string(e));
        }

        if (parsed && fileName() == '_polymod_meta.json')
        {
          for (item in ModDoctor.validateMeta(text)) problems.push(item.level.toUpperCase() + ' ' + item.message);
        }
        else if (parsed && fileName() == 'title-screen.json')
        {
          for (line in TitleConfig.parse(text).describeIssues()) problems.push(line);
        }
      case 'xml':
        try
        {
          Xml.parse(text);
        }
        catch (e:Dynamic)
        {
          problems.push('ERROR ' + Std.string(e));
        }
      #if FEATURE_LUA_SCRIPTS
      case 'lua':
        var message:Null<String> = FunkinLua.checkSyntax(text);

        if (message != null)
        {
          jumpToLine(message);
          problems.push('ERROR ' + message);
        }
      #end
      default:
    }

    return problems;
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
      fail('Open a text file first.');
      return;
    }

    if (language == 'plain' || language == 'haxe')
    {
      logLine('info', 'There is no syntax checker for ' + (language == 'haxe' ? 'Haxe' : 'this file type') + '.');
      return;
    }

    var problems:Array<String> = validate(editor.text);

    if (problems.length == 0)
    {
      logLine('ok', 'Syntax OK');
      toast('Syntax OK', NotificationType.Success);
      return;
    }

    for (problem in problems) logLine(StringTools.startsWith(problem, 'ERROR') ? 'error' : 'warn', problem);

    toast(problems[0], NotificationType.Error);
  }

  function askName(title:String, prompt:String, initial:String, done:String->Void):Void
  {
    var dialog:CosmicNameDialog = new CosmicNameDialog(title, prompt, initial, function(text:String):Void
    {
      dialogOpen = false;
      done(StringTools.trim(text));
    });

    dialogOpen = true;
    dialog.onDialogClosed = function(_):Void
    {
      dialogOpen = false;
    };
    dialog.showDialog(true);
  }

  function targetFree(name:String):Null<String>
  {
    if (!isValidName(name))
    {
      fail('"' + name + '" is not a valid name.');
      return null;
    }

    var path:Null<String> = childPath(name);

    if (path == null || FunkinCosmic.exists(path))
    {
      fail(displayName(name) + ' already exists or is outside the root.');
      return null;
    }

    return path;
  }

  function createFile():Void
  {
    askName('New File', 'Name of the new file in ' + rootPrefix() + relDir, '', function(name:String):Void
    {
      var path:Null<String> = targetFree(name);

      if (path == null) return;

      confirmDiscard(() ->
      {
        if (!FunkinCosmic.writeTextAtomic(path, '', false))
        {
          fail('Could not create ' + displayName(name));
          return;
        }

        selectedName = name;

        refreshList();
        openFile(path, displayName(name));
      });
    });
  }

  function createDirectory():Void
  {
    askName('New Folder', 'Name of the new folder in ' + rootPrefix() + relDir, '', function(name:String):Void
    {
      var path:Null<String> = targetFree(name);

      if (path == null) return;

      if (!FunkinCosmic.createDirectory(path))
      {
        fail('Could not create ' + displayName(name));
        return;
      }

      selectedName = name;

      refreshList();
      logLine('ok', 'Created ' + displayName(name));
    });
  }

  function renameSelected():Void
  {
    var source:Null<String> = selectedPath();

    if (source == null)
    {
      fail('Select an entry to rename.');
      return;
    }

    var oldName:String = selectedName;

    askName('Rename', 'New name for ' + displayName(oldName), oldName, function(name:String):Void
    {
      if (name == oldName) return;

      var target:Null<String> = targetFree(name);

      if (target == null) return;

      var wasOpen:Bool = source == currentFile;

      var apply:Void->Void = function():Void
      {
        if (!FunkinCosmic.moveFile(source, target, false))
        {
          fail('Could not rename ' + displayName(oldName));
          return;
        }

        logLine('ok', 'Renamed ' + displayName(oldName) + ' to ' + name);

        if (wasOpen) closeFile();

        selectedName = name;

        refreshList();
      };

      if (wasOpen) confirmDiscard(apply);
      else
        apply();
    });
  }

  function copySelected():Void
  {
    var source:Null<String> = selectedPath();
    var entry:Null<CosmicEntry> = selectedEntry();

    if (source == null || entry == null)
    {
      fail('Select a file to duplicate.');
      return;
    }

    if (entry.isDir)
    {
      fail('Copying folders is not supported.');
      return;
    }

    var oldName:String = entry.name;
    var extension:String = Path.extension(oldName);
    var suggestion:String = extension == '' ? oldName + '-copy' : Path.withoutExtension(oldName) + '-copy.' + extension;

    askName('Duplicate', 'Name of the copy of ' + displayName(oldName), suggestion, function(name:String):Void
    {
      var target:Null<String> = targetFree(name);

      if (target == null) return;

      if (!FunkinCosmic.copyFile(source, target, false))
      {
        fail('Could not copy to ' + displayName(name));
        return;
      }

      logLine('ok', 'Copied ' + displayName(oldName) + ' to ' + name);

      selectedName = name;

      refreshList();
    });
  }

  function deleteSelected():Void
  {
    var path:Null<String> = selectedPath();
    var entry:Null<CosmicEntry> = selectedEntry();

    if (path == null || entry == null)
    {
      fail('Select a file or folder to delete.');
      return;
    }

    if (relDir == '' && (currentRoot().label == 'GAME' || currentRoot().label == 'DATA'))
    {
      fail('Top level entries of ' + currentRoot().label + ' are protected. Open the folder and delete items inside it.');
      return;
    }

    var label:String = displayName(entry.name);
    var isDir:Bool = entry.isDir;

    dialogOpen = true;

    Dialogs.messageBox('Delete ' + label + (isDir ? ' and everything inside it?' : '?') + '\n\nThis cannot be undone.', 'Delete', MessageBoxType.TYPE_YESNO, true,
      function(button:DialogButton):Void
      {
        dialogOpen = false;

        if (button != DialogButton.YES) return;

        var deleted:Bool = isDir ? FunkinCosmic.deleteDirectory(path, true) : FunkinCosmic.deleteFile(path);

        if (!deleted)
        {
          fail('Could not delete ' + label);
          return;
        }

        if (path == currentFile) closeFile();

        logLine('ok', 'Deleted ' + label);

        selectedName = '';

        refreshList();
      });
  }

  function backupsOf(path:String):Array<CosmicBackup>
  {
    var backups:Array<CosmicBackup> = [];

    for (slot in 1...BACKUP_SLOTS_SHOWN + 1)
    {
      var backup:String = path + '.bak' + slot;

      if (!FunkinCosmic.exists(backup)) continue;

      backups.push({
        slot: slot,
        text: 'Slot ' + slot + '   ' + formatSize(FunkinCosmic.getFileSize(backup)) + '   ' + Date.fromTime(FunkinCosmic.getModifiedTime(backup)).toString()
      });
    }

    return backups;
  }

  function restoreBackup():Void
  {
    if (currentFile == null || readOnly)
    {
      fail('Open a text file first.');
      return;
    }

    var path:String = currentFile;
    var label:String = currentLabel;

    var dialog:CosmicRestoreDialog = new CosmicRestoreDialog(label, backupsOf(path), function(slot:Int):Void
    {
      dialogOpen = false;

      if (!FunkinCosmic.restoreBackup(path, slot))
      {
        fail('Could not restore slot ' + slot);
        return;
      }

      openFile(path, label);
      logLine('ok', 'Restored backup slot ' + slot);
    });

    dialogOpen = true;
    dialog.onDialogClosed = function(_):Void
    {
      dialogOpen = false;
    };
    dialog.showDialog(true);
  }

  function describe(path:String):String
  {
    var lines:Array<String> = ['Path: ' + path];

    if (FunkinCosmic.isDirectory(path))
    {
      var count:Int = 0;

      try
      {
        count = sys.FileSystem.readDirectory(path).length;
      }
      catch (e:Dynamic) {}

      lines.push('Folder with ' + count + ' entries');
      return lines.join('\n');
    }

    var size:Int = FunkinCosmic.getFileSize(path);

    lines.push('Size: ' + size + ' bytes');
    lines.push('Modified: ' + Date.fromTime(FunkinCosmic.getModifiedTime(path)).toString());

    if (size >= 0 && size <= MAX_CHECKSUM_BYTES) lines.push('MD5: ' + (FunkinCosmic.checksum(path) ?? 'unavailable'));

    var backups:Array<CosmicBackup> = backupsOf(path);

    lines.push(backups.length == 0 ? 'Backups: none' : 'Backups:');

    for (backup in backups) lines.push('  ' + backup.text);

    return lines.join('\n');
  }

  function showInfo():Void
  {
    var path:Null<String> = selectedPath() ?? currentFile;

    if (path == null)
    {
      fail('Select a file or folder first.');
      return;
    }

    showReport('File Info', describe(path));
  }

  function showReport(title:String, content:String):Void
  {
    var dialog:CosmicInfoDialog = new CosmicInfoDialog(title, content);

    dialogOpen = true;
    dialog.onDialogClosed = function(_):Void
    {
      dialogOpen = false;
    };
    dialog.showDialog(true);
  }

  function openGuide():Void
  {
    var guide:CosmicGuideDialog = new CosmicGuideDialog();

    dialogOpen = true;
    guide.onDialogClosed = function(_):Void
    {
      dialogOpen = false;
    };
    guide.showDialog(true);
  }

  function openModDoctor():Void
  {
    var dialog:CosmicModsDialog = new CosmicModsDialog();

    dialogOpen = true;
    dialog.onDialogClosed = function(_):Void
    {
      dialogOpen = false;
    };
    dialog.showDialog(true);
  }

  function modsRootIndex():Int
  {
    for (i in 0...roots.length)
    {
      if (roots[i].label == 'MODS') return i;
    }

    return 0;
  }

  function createMod():Void
  {
    askName('Create a New Mod', 'Type the mod folder name (letters, numbers, - and _).', '', function(name:String):Void
    {
      if (!MOD_ID_PATTERN.match(name))
      {
        fail('Use only letters, numbers, - and _ in a mod name.');
        return;
      }

      var modsIndex:Int = modsRootIndex();
      var folder:Null<String> = FunkinCosmic.resolve(roots[modsIndex].mount, name);

      if (folder == null || FunkinCosmic.exists(folder))
      {
        fail('MODS:/' + name + ' already exists.');
        return;
      }

      FunkinCosmic.createDirectory(PolymodHandler.getModFolder());

      var api:String = PolymodHandler.API_VERSION;

      if (api.charAt(0) == 'v' || api.charAt(0) == 'V') api = api.substr(1);

      var meta:String = StringTools.replace(StringTools.replace(META_TEMPLATE, '%TITLE%', name), '%API%', api);

      if (!FunkinCosmic.createDirectory(folder) || !FunkinCosmic.writeTextAtomic(folder + '/_polymod_meta.json', meta, false))
      {
        fail('Could not create MODS:/' + name);
        return;
      }

      rootIndex = modsIndex;
      relDir = name;
      selectedName = '_polymod_meta.json';

      updatingList = true;
      rootPicker.selectedIndex = modsIndex;
      updatingList = false;

      refreshList();
      logLine('ok', 'Created MODS:/' + name + '. Enable it in the Mod Menu after you add some content.');
      confirmDiscard(() -> openFile(folder + '/_polymod_meta.json', 'MODS:/' + name + '/_polymod_meta.json'));
    });
  }

  function addTitleConfig():Void
  {
    if (currentRoot().label != 'MODS' || relDir == '')
    {
      fail('Open a mod folder inside MODS first, then use this again.');
      return;
    }

    var modDir:String = relDir.split('/')[0];
    var rel:String = modDir + '/ui/title';
    var folder:Null<String> = FunkinCosmic.resolve(currentRoot().mount, rel);
    var target:Null<String> = FunkinCosmic.resolve(currentRoot().mount, rel + '/title-screen.json');

    if (folder == null || target == null)
    {
      fail('That folder is outside the root.');
      return;
    }

    if (FunkinCosmic.exists(target))
    {
      fail('MODS:/' + rel + '/title-screen.json already exists.');
      return;
    }

    if (!FunkinCosmic.createDirectory(folder) || !FunkinCosmic.writeTextAtomic(target, TitleConfig.DEFAULTS + '\n', false))
    {
      fail('Could not create the title screen config.');
      return;
    }

    relDir = rel;
    selectedName = 'title-screen.json';

    refreshList();
    logLine('ok', 'Created MODS:/' + rel + '/title-screen.json with every setting at its default. Delete the settings you do not change.');
    confirmDiscard(() -> openFile(target, 'MODS:/' + rel + '/title-screen.json'));
  }

  function onEditorChange(_:Event):Void
  {
    if (readOnly) return;

    if (!dirty)
    {
      dirty = true;
      updateFileLabel();
    }

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

    updateFileLabel();
    refreshGutter();
    applyHighlight();
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
    gutterLines = -1;

    updateFileLabel();
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

  function changeFontSize(delta:Int):Void
  {
    var next:Int = Std.int(Math.max(MIN_FONT_SIZE, Math.min(MAX_FONT_SIZE, fontSize + delta)));

    if (next == fontSize) return;

    fontSize = next;
    baseFormat.size = next;

    editor.defaultTextFormat = baseFormat;
    gutter.defaultTextFormat = new TextFormat(baseFormat.font, next, 0x5C6370, false, false, false, null, null, TextFormatAlign.RIGHT);
    console.defaultTextFormat = new TextFormat(baseFormat.font, next, 0xC8D0DA);

    gutterLines = -1;
    refreshGutter();
    applyHighlight();
  }

  function updateStatus():Void
  {
    var caret:Int = editor.caretIndex;
    var line:Int = Std.int(Math.max(0, editor.getLineIndexOfChar(caret)));
    var column:Int = caret - editor.getLineOffset(line) + 1;
    var status:String = currentFile == null ? rootPrefix() + relDir + '   ' + entries.length + ' entries' : 'Ln ${line + 1}, Col $column   ${editor.numLines} lines   $language'
      + (dirty ? '   MODIFIED' : '') + (readOnly ? '   READ-ONLY' : '');

    if (status == lastStatus) return;

    lastStatus = status;
    statusLabel.text = status;
  }

  function openFind(withReplace:Bool):Void
  {
    if (readOnly && currentFile == null) return;

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

  function gotoLine(line:Int):Void
  {
    var index:Int = Std.int(Math.max(0, Math.min(editor.numLines - 1, line - 1)));
    var start:Int = editor.getLineOffset(index);

    editor.scrollV = Std.int(Math.max(1, index - 3));
    editor.setSelection(start, start + Std.int(Math.max(0, editor.getLineLength(index) - 1)));

    gutter.scrollV = editor.scrollV;
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

    if (findInput.text == '')
    {
      findInfo.text = '';
      return;
    }

    var matches:Array<Int> = findMatches();

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
    if (readOnly) return;

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

    if (readOnly || needle == '') return;

    var matches:Array<Int> = findMatches();

    if (matches.length == 0)
    {
      findInfo.text = 'no matches';
      return;
    }

    var pattern:EReg = new EReg(REGEX_ESCAPE.replace(needle, '\\$0'), findCase ? 'g' : 'gi');
    var replacement:String = replaceInput.text;

    applyEdit(pattern.map(editor.text, (_) -> replacement), 0, 0);
    logLine('ok', 'Replaced ' + matches.length + ' matches.');
    updateFindInfo();
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

  function confirmDiscard(action:Void->Void, ?cancel:Void->Void):Void
  {
    if (!dirty)
    {
      action();
      return;
    }

    dialogOpen = true;

    Dialogs.messageBox('This file has unsaved changes. Discard them?', 'Unsaved Changes', MessageBoxType.TYPE_YESNO, true, function(button:DialogButton):Void
    {
      dialogOpen = false;

      if (button == DialogButton.YES) action();
      else if (cancel != null)
        cancel();
    });
  }

  function requestExit():Void
  {
    if (exitDialog != null) return;

    if (!dirty)
    {
      leave();
      return;
    }

    dialogOpen = true;

    exitDialog = Dialogs.messageBox('You are about to leave the editor without saving.\n\nAre you sure?', 'Leave Editor', MessageBoxType.TYPE_YESNO, true,
      function(button:DialogButton):Void
      {
        exitDialog = null;
        dialogOpen = false;

        if (button == DialogButton.YES) leave();
      });
  }

  function leave():Void
  {
    FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
  }

  @:bind(listUp, MouseEvent.CLICK)
  function onListUpClick(_):Void
  {
    goUp();
  }

  @:bind(listOpen, MouseEvent.CLICK)
  function onListOpenClick(_):Void
  {
    openSelected();
  }

  @:bind(listNewFile, MouseEvent.CLICK)
  function onListNewFileClick(_):Void
  {
    createFile();
  }

  @:bind(listNewFolder, MouseEvent.CLICK)
  function onListNewFolderClick(_):Void
  {
    createDirectory();
  }

  @:bind(toolSave, MouseEvent.CLICK)
  function onToolSaveClick(_):Void
  {
    save();
  }

  @:bind(toolReload, MouseEvent.CLICK)
  function onToolReloadClick(_):Void
  {
    reload();
  }

  @:bind(toolCheck, MouseEvent.CLICK)
  function onToolCheckClick(_):Void
  {
    check();
  }

  @:bind(toolUndo, MouseEvent.CLICK)
  function onToolUndoClick(_):Void
  {
    undo();
  }

  @:bind(toolRedo, MouseEvent.CLICK)
  function onToolRedoClick(_):Void
  {
    redo();
  }

  @:bind(toolInfo, MouseEvent.CLICK)
  function onToolInfoClick(_):Void
  {
    showInfo();
  }

  @:bind(findPreviousButton, MouseEvent.CLICK)
  function onFindPreviousButtonClick(_):Void
  {
    findNext(-1);
  }

  @:bind(findNextButton, MouseEvent.CLICK)
  function onFindNextButtonClick(_):Void
  {
    findNext(1);
  }

  @:bind(findReplaceButton, MouseEvent.CLICK)
  function onFindReplaceButtonClick(_):Void
  {
    replaceCurrent();
  }

  @:bind(findReplaceAllButton, MouseEvent.CLICK)
  function onFindReplaceAllButtonClick(_):Void
  {
    replaceAll();
  }

  @:bind(findCloseButton, MouseEvent.CLICK)
  function onFindCloseButtonClick(_):Void
  {
    closeFind();
  }

  @:bind(menubarItemNewFile, MouseEvent.CLICK)
  function onMenubarItemNewFileClick(_):Void
  {
    createFile();
  }

  @:bind(menubarItemNewFolder, MouseEvent.CLICK)
  function onMenubarItemNewFolderClick(_):Void
  {
    createDirectory();
  }

  @:bind(menubarItemOpen, MouseEvent.CLICK)
  function onMenubarItemOpenClick(_):Void
  {
    openSelected();
  }

  @:bind(menubarItemSave, MouseEvent.CLICK)
  function onMenubarItemSaveClick(_):Void
  {
    save();
  }

  @:bind(menubarItemReload, MouseEvent.CLICK)
  function onMenubarItemReloadClick(_):Void
  {
    reload();
  }

  @:bind(menubarItemRename, MouseEvent.CLICK)
  function onMenubarItemRenameClick(_):Void
  {
    renameSelected();
  }

  @:bind(menubarItemCopy, MouseEvent.CLICK)
  function onMenubarItemCopyClick(_):Void
  {
    copySelected();
  }

  @:bind(menubarItemDelete, MouseEvent.CLICK)
  function onMenubarItemDeleteClick(_):Void
  {
    deleteSelected();
  }

  @:bind(menubarItemRestore, MouseEvent.CLICK)
  function onMenubarItemRestoreClick(_):Void
  {
    restoreBackup();
  }

  @:bind(menubarItemInfo, MouseEvent.CLICK)
  function onMenubarItemInfoClick(_):Void
  {
    showInfo();
  }

  @:bind(menubarItemExit, MouseEvent.CLICK)
  function onMenubarItemExitClick(_):Void
  {
    requestExit();
  }

  @:bind(menubarItemUndo, MouseEvent.CLICK)
  function onMenubarItemUndoClick(_):Void
  {
    undo();
  }

  @:bind(menubarItemRedo, MouseEvent.CLICK)
  function onMenubarItemRedoClick(_):Void
  {
    redo();
  }

  @:bind(menubarItemFind, MouseEvent.CLICK)
  function onMenubarItemFindClick(_):Void
  {
    openFind(false);
  }

  @:bind(menubarItemReplace, MouseEvent.CLICK)
  function onMenubarItemReplaceClick(_):Void
  {
    openFind(true);
  }

  @:bind(menubarItemFindNext, MouseEvent.CLICK)
  function onMenubarItemFindNextClick(_):Void
  {
    findNext(1);
  }

  @:bind(menubarItemGoto, MouseEvent.CLICK)
  function onMenubarItemGotoClick(_):Void
  {
    focusGoto();
  }

  @:bind(menubarItemFontLarger, MouseEvent.CLICK)
  function onMenubarItemFontLargerClick(_):Void
  {
    changeFontSize(1);
  }

  @:bind(menubarItemFontSmaller, MouseEvent.CLICK)
  function onMenubarItemFontSmallerClick(_):Void
  {
    changeFontSize(-1);
  }

  @:bind(menubarItemRefresh, MouseEvent.CLICK)
  function onMenubarItemRefreshClick(_):Void
  {
    refreshList();
  }

  @:bind(menubarItemClearConsole, MouseEvent.CLICK)
  function onMenubarItemClearConsoleClick(_):Void
  {
    clearConsole();
  }

  @:bind(menubarItemCheck, MouseEvent.CLICK)
  function onMenubarItemCheckClick(_):Void
  {
    check();
  }

  @:bind(menubarItemNewMod, MouseEvent.CLICK)
  function onMenubarItemNewModClick(_):Void
  {
    createMod();
  }

  @:bind(menubarItemTitleConfig, MouseEvent.CLICK)
  function onMenubarItemTitleConfigClick(_):Void
  {
    addTitleConfig();
  }

  @:bind(menubarItemModDoctor, MouseEvent.CLICK)
  function onMenubarItemModDoctorClick(_):Void
  {
    openModDoctor();
  }

  @:bind(menubarItemGuide, MouseEvent.CLICK)
  function onMenubarItemGuideClick(_):Void
  {
    openGuide();
  }

  @:bind(rootPicker, UIEvent.CHANGE)
  function onRootPickerChange(_):Void
  {
    if (updatingList) return;

    switchRoot(rootPicker.selectedIndex);
  }

  @:bind(listFilter, UIEvent.CHANGE)
  function onListFilterChange(_):Void
  {
    renderList();
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

  @:bind(fileList, UIEvent.CHANGE)
  function onFileListChange(_):Void
  {
    if (updatingList || fileList.selectedItem == null) return;

    selectedName = Std.string(fileList.selectedItem.name);
  }

  override function destroy():Void
  {
    if (watcher != null)
    {
      FunkinCosmic.unwatch(watcher);
      watcher = null;
    }

    for (item in roots) FunkinCosmic.unmount(item.mount);

    for (field in [editor, gutter, console])
    {
      if (field != null && field.parent != null) field.parent.removeChild(field);
    }

    if (FlxG.stage != null) FlxG.stage.focus = null;

    NotificationManager.instance.clearNotifications();

    Cursor.hide();

    super.destroy();
  }
}
#end
