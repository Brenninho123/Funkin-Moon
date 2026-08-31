package funkin.modding;

import polymod.fs.ZipFileSystem;
import funkin.data.dialogue.ConversationRegistry;
import funkin.data.dialogue.DialogueBoxRegistry;
import funkin.data.dialogue.SpeakerRegistry;
import funkin.data.event.SongEventRegistry;
import funkin.data.story.level.LevelRegistry;
import funkin.data.notestyle.NoteStyleRegistry;
import funkin.play.notes.notekind.NoteKindManager;
import funkin.data.song.SongRegistry;
import funkin.data.freeplay.player.PlayerRegistry;
import funkin.data.freeplay.style.FreeplayStyleRegistry;
import funkin.data.stage.StageRegistry;
import funkin.data.stickers.StickerRegistry;
import funkin.data.freeplay.album.AlbumRegistry;
import funkin.modding.module.ModuleHandler;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.save.Save;
import funkin.util.FileUtil;
import funkin.util.macro.ClassMacro;
import polymod.backends.PolymodAssets.PolymodAssetType;
import polymod.format.ParseRules.TextFileFormat;
import polymod.Polymod;

@:nullSafety
class PolymodHandler
{
  public static var API_VERSION(get, never):String;

  static function get_API_VERSION():String
  {
    return Constants.VERSION;
  }

  public static final API_VERSION_RULE:String = '=0.0.1';

  static final MOD_FOLDER:String =
    #if (REDIRECT_ASSETS_FOLDER && mac)
    '../../../../../../../example_mods'
    #elseif REDIRECT_ASSETS_FOLDER
    '../../../../example_mods'
    #else
    'mods'
    #end;

  static final CORE_FOLDER:Null<String> =
    #if (REDIRECT_ASSETS_FOLDER && mac)
    '../../../../../../../assets'
    #elseif REDIRECT_ASSETS_FOLDER
    '../../../../assets'
    #else
    null
    #end;

  public static var loadedModDirs:Array<String> = [];

  public static var loadedModIds:Array<String> = [];

  static var modFileSystem:Null<ZipFileSystem> = null;

  public static function createModRoot():Void
  {
    FileUtil.createDirIfNotExists(MOD_FOLDER);
  }

  public static function loadAllMods():Void
  {
    #if sys
    createModRoot();
    #end
    loadModsByDir(getAllModDirs());
  }

  public static function loadEnabledMods():Void
  {
    #if sys
    createModRoot();
    #end
    loadModsByDir(Save.instance.enabledModDirs.value);
  }

  public static function loadNoMods():Void
  {
    #if sys
    createModRoot();
    #end
    loadModsByDir([]);
  }

  public static function loadModsByDir(dirs:Array<String>):Void
  {
    buildImports();

    if (modFileSystem == null) modFileSystem = buildFileSystem();

    var loadedModList:Array<ModMetadata> = polymod.Polymod.init({
      modRoot: MOD_FOLDER,
      dirs: dirs,
      framework: OPENFL,
      apiVersionRule: API_VERSION_RULE,
      errorCallback: PolymodErrorHandler.onPolymodError,
      customFilesystem: modFileSystem,
      frameworkParams: buildFrameworkParams(),
      ignoredFiles: buildIgnoreList(),
      parseRules: buildParseRules(),
      skipDependencyErrors: true,
      useScriptedClasses: true,
      loadScriptsAsync: #if html5 true #else false #end,
    });

    loadedModIds = [];
    loadedModDirs = [];

    if (loadedModList != null)
    {
      for (mod in loadedModList)
      {
        loadedModDirs.push(mod.dirName);
        loadedModIds.push(mod.id);
      }
    }
  }

  static function buildFileSystem():polymod.fs.ZipFileSystem
  {
    polymod.Polymod.onError = PolymodErrorHandler.onPolymodError;
    return new ZipFileSystem({
      modRoot: MOD_FOLDER,
      autoScan: true
    });
  }

  static function buildImports():Void
  {
    static final DEFAULT_IMPORTS:Array<Class<Dynamic>> = [
      funkin.Assets,
      funkin.Paths,
      funkin.Preferences,
      funkin.util.Constants,
      flixel.FlxG
    ];

    for (cls in DEFAULT_IMPORTS)
    {
      Polymod.addDefaultImport(cls);
    }

    Polymod.addImportAlias('lime.utils.Assets', funkin.Assets);
    Polymod.addImportAlias('openfl.utils.Assets', funkin.Assets);

    Polymod.addImportAlias('funkin.modding.base.ScriptedFunkinSprite', funkin.graphics.ScriptedFunkinSprite);
    Polymod.addImportAlias('funkin.modding.base.ScriptedMusicBeatState', funkin.ui.ScriptedMusicBeatState);
    Polymod.addImportAlias('funkin.modding.base.ScriptedMusicBeatSubState', funkin.ui.ScriptedMusicBeatSubState);

    Polymod.addImportAlias('funkin.data.dialogue.conversation.ConversationRegistry', funkin.data.dialogue.ConversationRegistry);
    Polymod.addImportAlias('funkin.data.dialogue.dialoguebox.DialogueBoxRegistry', funkin.data.dialogue.DialogueBoxRegistry);
    Polymod.addImportAlias('funkin.data.dialogue.speaker.SpeakerRegistry', funkin.data.dialogue.SpeakerRegistry);
    Polymod.addImportAlias('funkin.play.character.CharacterDataParser', funkin.data.character.CharacterData.CharacterDataParser);
    Polymod.addImportAlias('funkin.play.character.CharacterData.CharacterDataParser', funkin.data.character.CharacterData.CharacterDataParser);

    Polymod.addImportAlias('funkin.graphics.adobeanimate.FlxAtlasSprite', funkin.graphics.FunkinSprite);
    Polymod.addImportAlias('funkin.modding.base.ScriptedFlxAtlasSprite', funkin.graphics.ScriptedFunkinSprite);

    Polymod.addImportAlias('funkin.util.FileUtil', funkin.util.FileUtilSandboxed);

    #if FEATURE_NEWGROUNDS
    Polymod.addImportAlias('funkin.api.newgrounds.Leaderboards', funkin.api.newgrounds.Leaderboards.LeaderboardsSandboxed);
    Polymod.addImportAlias('funkin.api.newgrounds.Medals', funkin.api.newgrounds.Medals.MedalsSandboxed);
    Polymod.addImportAlias('funkin.api.newgrounds.NewgroundsClient', funkin.api.newgrounds.NewgroundsClient.NewgroundsClientSandboxed);
    #end

    Polymod.addImportAlias('funkin.api.discord.DiscordClient', funkin.api.discord.DiscordClient.DiscordClientSandboxed);

    Polymod.blacklistImport('Sys');

    Polymod.addImportAlias('Reflect', funkin.util.ReflectUtil);

    Polymod.addImportAlias('Type', funkin.util.ReflectUtil);

    Polymod.blacklistImport('cpp.Lib');

    Polymod.blacklistImport('haxe.Http');

    Polymod.blacklistImport('haxe.Unserializer');

    Polymod.blacklistImport('lime.utils.AssetLibrary');

    for (cls in ClassMacro.listClassesInPackage('funkin.mobile.util'))
    {
      if (cls == null) continue;
      var className:String = Type.getClassName(cls);
      Polymod.blacklistImport(className);
    }

    for (cls in ClassMacro.listClassesInPackage('extension'))
    {
      if (cls == null) continue;
      var className:String = Type.getClassName(cls);
      Polymod.blacklistImport(className);
    }

    Polymod.blacklistImport('lime.system.CFFI');

    Polymod.blacklistImport('lime.system.JNI');

    Polymod.blacklistImport('lime.system.System');

    Polymod.blacklistImport('lime.utils.Assets');
    Polymod.blacklistImport('openfl.utils.Assets');
    Polymod.blacklistImport('openfl.Lib');
    Polymod.blacklistImport('openfl.system.ApplicationDomain');
    Polymod.blacklistImport('openfl.net.SharedObject');

    Polymod.blacklistImport('openfl.desktop.NativeProcess');

    Polymod.blacklistStaticFields(flixel.util.FlxSave, ['resolveFlixelClasses']);
    Polymod.blacklistStaticFields(flixel.FlxG, ['save']);

    Polymod.blacklistStaticFields(haxe.Unserializer, ['run']);
    Polymod.blacklistInstanceFields(haxe.Unserializer, ['unserialize']);

    Polymod.blacklistInstanceFields(funkin.save.Save, [
      'data',
      'clearData',
      'setLevelScore',
      'setSongScore',
      'applySongRank'
    ]);

    #if !html5 Polymod.blacklistInstanceFields(openfl.filesystem.FileStream, ['readObject']); #end
    Polymod.blacklistInstanceFields(openfl.net.Socket, ['readObject']);
    Polymod.blacklistInstanceFields(openfl.utils.ByteArray.ByteArrayData, ['readObject']);

    for (cls in ClassMacro.listClassesInPackage('funkin.api'))
    {
      if (cls == null) continue;
      var className:String = Type.getClassName(cls);
      if (polymod.hscript._internal.PolymodScriptClass.importOverrides.exists(className)) continue;
      Polymod.blacklistImport(className);
    }

    for (cls in ClassMacro.listClassesInPackage('polymod'))
    {
      if (cls == null) continue;
      var className:String = Type.getClassName(cls);
      Polymod.blacklistImport(className);
    }

    for (cls in ClassMacro.listClassesInPackage('hscript'))
    {
      if (cls == null) continue;
      var className:String = Type.getClassName(cls);
      Polymod.blacklistImport(className);
    }

    for (cls in ClassMacro.listClassesInPackage('io.newgrounds'))
    {
      if (cls == null) continue;
      var className:String = Type.getClassName(cls);
      Polymod.blacklistImport(className);
    }

    for (cls in ClassMacro.listClassesInPackage('sys'))
    {
      if (cls == null) continue;
      var className:String = Type.getClassName(cls);
      Polymod.blacklistImport(className);
    }

    for (cls in ClassMacro.listClassesInPackage('funkin.util.macro'))
    {
      if (cls == null) continue;
      var className:String = Type.getClassName(cls);
      Polymod.blacklistImport(className);
    }

    Polymod.blacklistImport('funkin.external.android.CallbackUtil');
    Polymod.blacklistImport('funkin.external.android.DataFolderUtil');
    Polymod.blacklistImport('funkin.external.android.JNIUtil');

    Polymod.blacklistInstanceFields(polymod.hscript._internal.PolymodScriptClass.PolymodScriptClass, ['_interp']);
  }

  static function buildIgnoreList():Array<String>
  {
    var result = Polymod.getDefaultIgnoreList();

    result.push('.vscode');
    result.push('.idea');
    result.push('.git');
    result.push('.gitignore');
    result.push('.gitattributes');
    result.push('README.md');

    return result;
  }

  static function buildParseRules():polymod.format.ParseRules
  {
    var output:polymod.format.ParseRules = polymod.format.ParseRules.getDefault();
    output.addType('txt', TextFileFormat.LINES);
    return output;
  }

  static inline function buildFrameworkParams():polymod.Polymod.FrameworkParams
  {
    return {
      assetLibraryPaths: [
        'default' => 'preload',
        'shared' => 'shared',
        'songs' => 'songs',
        'videos' => 'videos',
        'tutorial' => 'tutorial',
        'week1' => 'week1',
        'week2' => 'week2',
        'week3' => 'week3',
        'week4' => 'week4',
        'week5' => 'week5',
        'week6' => 'week6',
        'week7' => 'week7',
        'weekend1' => 'weekend1',
        'sserafim' => 'sserafim'
      ],
      coreAssetRedirect: CORE_FOLDER,
    }
  }

  public static function getAllMods():Array<ModMetadata>
  {
    if (modFileSystem == null) modFileSystem = buildFileSystem();

    var modMetadata:Array<ModMetadata> = Polymod.scan({
      modRoot: MOD_FOLDER,
      apiVersionRule: API_VERSION_RULE,
      fileSystem: modFileSystem,
      errorCallback: PolymodErrorHandler.onPolymodError
    });

    return modMetadata;
  }

  public static function getAllModIds():Array<String>
  {
    var modIds:Array<String> = [for (i in getAllMods()) i.id];
    return modIds;
  }

  public static function getAllModDirs():Array<String>
  {
    var modDirs:Array<String> = [
      for (i in getAllMods()) i.dirName
    ];
    return modDirs;
  }

  public static function getEnabledMods():Array<ModMetadata>
  {
    var modDirs:Array<String> = Save.instance.enabledModDirs.value;
    var modMetadata:Array<ModMetadata> = getAllMods();
    var enabledMods:Array<ModMetadata> = [];
    for (item in modMetadata)
    {
      if (modDirs.indexOf(item.dirName) != -1)
      {
        enabledMods.push(item);
      }
    }
    return enabledMods;
  }

  public static function forceReloadAssets():Void
  {
    ModuleHandler.clearModuleCache();
    Polymod.clearScripts();

    funkin.modding.PolymodHandler.loadAllMods();

    SongEventRegistry.loadEventCache();

    SongRegistry.instance.loadEntries();
    LevelRegistry.instance.loadEntries();
    NoteStyleRegistry.instance.loadEntries();
    PlayerRegistry.instance.loadEntries();
    ConversationRegistry.instance.loadEntries();
    DialogueBoxRegistry.instance.loadEntries();
    SpeakerRegistry.instance.loadEntries();
    AlbumRegistry.instance.loadEntries();
    StageRegistry.instance.loadEntries();
    StickerRegistry.instance.loadEntries();
    FreeplayStyleRegistry.instance.loadEntries();

    CharacterDataParser.loadCharacterCache();
    NoteKindManager.initialize();
    ModuleHandler.loadModuleCache();
    ModuleHandler.callOnCreate();
  }
}
