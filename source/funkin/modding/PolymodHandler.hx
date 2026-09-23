package funkin.modding;

import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.data.dialogue.ConversationRegistry;
import funkin.data.dialogue.DialogueBoxRegistry;
import funkin.data.dialogue.SpeakerRegistry;
import funkin.data.event.SongEventRegistry;
import funkin.data.freeplay.album.AlbumRegistry;
import funkin.data.freeplay.player.PlayerRegistry;
import funkin.data.freeplay.style.FreeplayStyleRegistry;
import funkin.data.notestyle.NoteStyleRegistry;
import funkin.data.song.SongRegistry;
import funkin.data.stage.StageRegistry;
import funkin.data.stickers.StickerRegistry;
import funkin.data.story.level.LevelRegistry;
import funkin.modding.module.ModuleHandler;
import funkin.play.notes.notekind.NoteKindManager;
import funkin.save.Save;
import funkin.util.FileUtil;
import funkin.util.SortUtil;
import funkin.util.macro.ClassMacro;
import polymod.Polymod;
import polymod.PolymodAssets.PolymodAssetType;
import polymod.format.ParseRules.TextFileFormat;
import polymod.fs.ZipFileSystem;

@:nullSafety
class PolymodHandler
{
  public static var API_VERSION(get, never):String;

  static function get_API_VERSION():String
  {
    return Constants.VERSION;
  }

  public static final API_VERSION_RULE:String = '*';

  public static var MOD_FOLDER(get, never):String;

  static function get_MOD_FOLDER():String
  {
    #if (REDIRECT_ASSETS_FOLDER && mac)
    return '../../../../../../../example_mods';
    #elseif REDIRECT_ASSETS_FOLDER
    return '../../../../example_mods';
    #elseif mobile
    return lime.system.System.applicationStorageDirectory + '/mods';
    #else
    return 'mods';
    #end
  }

  public static final CORE_FOLDER:Null<String> =
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
    loadModsById(getAllModIds());
  }

  public static function loadEnabledMods():Void
  {
    #if sys
    createModRoot();
    #end
    loadModsById(Save.instance.enabledModIds.value);
  }

  public static function loadNoMods():Void
  {
    #if sys
    createModRoot();
    #end
    loadModsById([]);
  }

  public static function loadModsById(modIds:Array<String>):Void
  {
    buildImports();

    funkin.modding.ScriptGuard.clear();

    try
    {
      if (modFileSystem == null) modFileSystem = buildFileSystem();
    }
    catch (e:Dynamic)
    {
    }

    var allModIds:Array<String> = getAllModIds();
    var toRemove:Array<String> = [];
    for (modId in modIds)
    {
      if (!allModIds.contains(modId))
      {
        toRemove.push(modId);
      }
    }

    for (modId in toRemove) modIds.remove(modId);

    var loadedModList:Array<ModMetadata> = polymod.Polymod.init({
      modRoot: MOD_FOLDER,
      modIds: modIds,
      framework: OPENFL,
      apiVersionRule: API_VERSION_RULE,
      errorCallback: PolymodErrorHandler.onPolymodError,

      customFilesystem: modFileSystem,

      frameworkParams: buildFrameworkParams(),

      ignoredFiles: buildIgnoreList(),

      parseRules: buildParseRules(),

      skipDependencyErrors: true,

      useScriptedClasses: false,
      loadScriptsAsync: false
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

  public static function loadScripts(async:Bool = true):lime.app.Future<
    {success:Int, total:Int}>
  {
    #if FEATURE_CPPIA
    polymod.hscript._internal.PolymodCppiaClassReference.expectedVersion = lime.app.Application.current.meta.get('version');
    #end

    if (async)
    {
      return Polymod.registerAllScriptClassesAsync().then((result) ->
      {
        var total = 0;
        var success = 0;

        for (future in result)
        {
          total += 1;
          if (future.isComplete) success += 1;
        }

        return lime.app.Future.withValue({
          success: success,
          total: total
        });
      });
    }
    else
    {
      var result = Polymod.registerAllScriptClasses();

      var total = result.size();
      var success = result.values().filter((v) -> (v == true)).length;
      return lime.app.Future.withValue({
        success: success,
        total: total
      });
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
    buildConvenienceAliases();
    buildCompatAliases();
    buildBlacklist();
  }

  static function buildConvenienceAliases():Void
  {
    final DEFAULT_IMPORTS:Array<Class<Dynamic>> = [
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
  }

  static function buildCompatAliases():Void
  {
    Polymod.addImportAlias('funkin.data.dialogue.conversation.ConversationRegistry', funkin.data.dialogue.ConversationRegistry);
    Polymod.addImportAlias('funkin.data.dialogue.dialoguebox.DialogueBoxRegistry', funkin.data.dialogue.DialogueBoxRegistry);
    Polymod.addImportAlias('funkin.data.dialogue.speaker.SpeakerRegistry', funkin.data.dialogue.SpeakerRegistry);
    Polymod.addImportAlias('funkin.play.character.CharacterDataParser', funkin.data.character.CharacterData.CharacterDataParser);
    Polymod.addImportAlias('funkin.play.character.CharacterData.CharacterDataParser', funkin.data.character.CharacterData.CharacterDataParser);

    Polymod.addImportAlias('funkin.modding.base.ScriptedFunkinSprite', funkin.graphics.FunkinSprite);
    Polymod.addImportAlias('funkin.modding.base.ScriptedMusicBeatState', funkin.ui.MusicBeatState);
    Polymod.addImportAlias('funkin.modding.base.ScriptedMusicBeatSubState', funkin.ui.MusicBeatSubState);

    Polymod.addImportAlias('funkin.play.character.CharacterDataParser', funkin.data.character.CharacterData.CharacterDataParser);

    Polymod.addImportAlias('funkin.graphics.adobeanimate.FlxAtlasSprite', funkin.graphics.FunkinSprite);
    Polymod.addImportAlias('funkin.modding.base.ScriptedFlxAtlasSprite', funkin.graphics.FunkinSprite);

    Polymod.addImportAlias('funkin.play.cutscene.VideoCutscene', funkin.modding.compat.VideoCutscene);
    Polymod.addImportAlias('funkin.FunkinMemory', funkin.memory.FunkinMemory);

    Polymod.addImportAlias('funkin.modding.base.ScriptedFlxBasic', flixel.FlxBasic);
    Polymod.addImportAlias('funkin.modding.base.ScriptedFlxObject', flixel.FlxObject);
    Polymod.addImportAlias('funkin.modding.base.ScriptedFlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
    Polymod.addImportAlias('funkin.modding.base.ScriptedFlxSprite', flixel.FlxSprite);
    Polymod.addImportAlias('funkin.modding.base.ScriptedFlxState', flixel.FlxState);
    Polymod.addImportAlias('funkin.modding.base.ScriptedFlxSubState', flixel.FlxSubState);
    Polymod.addImportAlias('funkin.modding.base.ScriptedFlxStrip', flixel.FlxStrip);
    Polymod.addImportAlias('funkin.modding.base.ScriptedFlxTransitionableState', flixel.addons.transition.FlxTransitionableState);
    Polymod.addImportAlias('funkin.modding.base.ScriptedFlxSpriteGroup', flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup);
    Polymod.addImportAlias('funkin.modding.base.ScriptedFlxTypedGroup', flixel.group.FlxGroup.FlxTypedGroup);
    Polymod.addImportAlias('funkin.graphics.ScriptedFunkinSprite', funkin.graphics.FunkinSprite);
    Polymod.addImportAlias('funkin.group.ScriptedFunkinGroup', funkin.group.FunkinGroup);
    Polymod.addImportAlias('funkin.graphics.video.ScriptedFunkinVideoSprite', funkin.graphics.video.FunkinVideoSprite);
    Polymod.addImportAlias('funkin.play.character.ScriptedBaseCharacter', funkin.play.character.BaseCharacter);
    Polymod.addImportAlias('funkin.play.character.ScriptedSparrowCharacter', funkin.play.character.SparrowCharacter);
    Polymod.addImportAlias('funkin.play.character.ScriptedMultiSparrowCharacter', funkin.play.character.MultiSparrowCharacter);
    Polymod.addImportAlias('funkin.play.character.ScriptedMultiAnimateAtlasCharacter', funkin.play.character.MultiAnimateAtlasCharacter);
    Polymod.addImportAlias('funkin.play.character.ScriptedPackerCharacter', funkin.play.character.PackerCharacter);
    Polymod.addImportAlias('funkin.play.character.ScriptedAnimateAtlasCharacter', funkin.play.character.AnimateAtlasCharacter);
    Polymod.addImportAlias('funkin.play.cutscene.dialogue.ScriptedConversation', funkin.play.cutscene.dialogue.Conversation);
    Polymod.addImportAlias('funkin.play.cutscene.dialogue.ScriptedDialogueBox', funkin.play.cutscene.dialogue.DialogueBox);
    Polymod.addImportAlias('funkin.play.cutscene.dialogue.ScriptedSpeaker', funkin.play.cutscene.dialogue.Speaker);
    Polymod.addImportAlias('funkin.play.event.ScriptedSongEvent', funkin.play.event.SongEvent);
    Polymod.addImportAlias('funkin.play.notes.ScriptedStrumline', funkin.play.notes.Strumline);
    Polymod.addImportAlias('funkin.play.notes.notekind.ScriptedNoteKind', funkin.play.notes.notekind.NoteKind);
    Polymod.addImportAlias('funkin.play.notes.notestyle.ScriptedNoteStyle', funkin.play.notes.notestyle.NoteStyle);
    Polymod.addImportAlias('funkin.play.song.ScriptedSong', funkin.play.song.Song);
    Polymod.addImportAlias('funkin.play.stage.ScriptedBopper', funkin.play.stage.Bopper);
    Polymod.addImportAlias('funkin.play.stage.ScriptedStage', funkin.play.stage.Stage);
    Polymod.addImportAlias('funkin.play.stage.ScriptedStageProp', funkin.play.stage.StageProp);
    Polymod.addImportAlias('funkin.ui.ScriptedMusicBeatState', funkin.ui.MusicBeatState);
    Polymod.addImportAlias('funkin.ui.ScriptedMusicBeatSubState', funkin.ui.MusicBeatSubState);
    Polymod.addImportAlias('funkin.ui.freeplay.ScriptedAlbum', funkin.ui.freeplay.Album);
    Polymod.addImportAlias('funkin.ui.freeplay.ScriptedFreeplayStyle', funkin.ui.freeplay.FreeplayStyle);
    Polymod.addImportAlias('funkin.ui.freeplay.backcards.ScriptedBackingCard', funkin.ui.freeplay.backcards.BackingCard);
    Polymod.addImportAlias('funkin.ui.freeplay.charselect.ScriptedPlayableCharacter', funkin.ui.freeplay.charselect.PlayableCharacter);
    Polymod.addImportAlias('funkin.ui.freeplay.dj.ScriptedAnimateAtlasFreeplayDJ', funkin.ui.freeplay.dj.AnimateAtlasFreeplayDJ);
    Polymod.addImportAlias('funkin.ui.freeplay.dj.ScriptedBaseFreeplayDJ', funkin.ui.freeplay.dj.BaseFreeplayDJ);
    Polymod.addImportAlias('funkin.ui.freeplay.dj.ScriptedSparrowFreeplayDJ', funkin.ui.freeplay.dj.SparrowFreeplayDJ);
    Polymod.addImportAlias('funkin.ui.freeplay.dj.ScriptedMultiSparrowFreeplayDJ', funkin.ui.freeplay.dj.MultiSparrowFreeplayDJ);
    Polymod.addImportAlias('funkin.ui.freeplay.dj.ScriptedPackerFreeplayDJ', funkin.ui.freeplay.dj.PackerFreeplayDJ);
    Polymod.addImportAlias('funkin.ui.story.ScriptedLevel', funkin.ui.story.Level);
    Polymod.addImportAlias('funkin.ui.transition.stickers.ScriptedStickerPack', funkin.ui.transition.stickers.StickerPack);

    Polymod.addImportAlias('funkin.graphics.framebuffer.FixedBitmapData', openfl.display.BitmapData);
  }

  static function buildBlacklist():Void
  {
    Polymod.addImportAlias('lime.utils.Assets', funkin.Assets);
    Polymod.addImportAlias('openfl.utils.Assets', funkin.Assets);
    Polymod.addImportAlias('openfl.Assets', funkin.Assets);

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

    Polymod.blacklistInstanceFields(lime.utils.AssetLibrary, ['classTypes']);

    Polymod.blacklistStaticFields(haxe.Unserializer, ['run']);
    Polymod.blacklistInstanceFields(haxe.Unserializer, ['unserialize']);

    Polymod.blacklistInstanceFields(funkin.save.Save, [
      'data',
      'clearData',
      'setLevelScore',
      'setSongScore',
      'applySongRank'
    ]);

    Polymod.blacklistStaticFields(funkin.Assets, ['getLibrary']);

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

    Polymod.blacklistDynamicFieldNames([
      'resolveFlixelClasses',
      'classTypes',
      'unserialize',
      'getLibrary',
      'readObject',
      'clearData',
      'setLevelScore',
      'setSongScore',
      'applySongRank',
      '_interp'
    ]);
  }

  static function buildIgnoreList():Array<String>
  {
    var result = Polymod.getDefaultIgnoreList();

    result.push('.vscode');
    result.push('.idea');
    result.push('.git');
    result.push('.gitignore');
    result.push('.gitattributes');
    result.push('.jj');
    result.push('.DS_Store');
    result.push('README.md');
    result.push('cppia-src');
    result.push('build.sh');
    result.push('build.ps1');

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
      assetLibraryPaths: ['default' => ''],
      coreAssetRedirect: CORE_FOLDER,
    }
  }

  public static function getAllMods(force:Bool = false):Array<ModMetadata>
  {
    return scanMods(false, force);
  }

  public static function getAllModsIncludingIncompatible(force:Bool = false):Array<ModMetadata>
  {
    return scanMods(true, force);
  }

  static function scanMods(includeIncompatible:Bool, force:Bool):Array<ModMetadata>
  {
    var modMetadata:Array<ModMetadata> = [];
    try
    {
      if (modFileSystem == null || force) modFileSystem = buildFileSystem();

      var scanParams:Dynamic = {
        modRoot: MOD_FOLDER,
        fileSystem: modFileSystem,
        errorCallback: PolymodErrorHandler.onPolymodError
      };
      if (!includeIncompatible) scanParams.apiVersionRule = API_VERSION_RULE;
      modMetadata = Polymod.scan(scanParams);
    }
    catch (e:Dynamic)
    {
      return [];
    }
    return modMetadata;
  }

  public static function isModCompatible(mod:ModMetadata):Bool
  {
    if (mod == null) return true;
    return mod.isCompatible(API_VERSION_RULE);
  }

  public static function getAllModIds():Array<String>
  {
    var modIds:Array<String> = [for (i in getAllMods()) i.id];
    return modIds;
  }

  public static function getAllModDirs():Array<String>
  {
    var modDirs:Array<String> = [for (i in getAllMods()) i.dirName];
    return modDirs;
  }

  public static function enableMod(modId:String):Void
  {
    var enabledModIds:Array<String> = Save.instance.enabledModIds.value;
    if (!enabledModIds.contains(modId))
    {
      enabledModIds.push(modId);
      Save.instance.enabledModIds.value = enabledModIds;
      Save.system.flush();
    }
  }

  public static function disableMod(modId:String):Void
  {
    var enabledModIds:Array<String> = Save.instance.enabledModIds.value;
    if (enabledModIds.contains(modId))
    {
      enabledModIds.remove(modId);
      Save.instance.enabledModIds.value = enabledModIds;
      Save.system.flush();
    }
  }

  public static function disableAllMods():Void
  {
    Save.instance.enabledModIds.value = [];
    Save.system.flush();
  }

  public static function getEnabledMods():Array<ModMetadata>
  {
    var enabledModIds:Array<String> = Save.instance.enabledModIds.value;
    var modMetadata:Array<ModMetadata> = getAllMods();
    var enabledMods:Array<ModMetadata> = modMetadata.filter((item) ->
    {
      return enabledModIds.contains(item.id);
    });

    enabledMods.sort((a, b) ->
    {
      return enabledModIds.indexOf(a.id) - enabledModIds.indexOf(b.id);
    });

    return enabledMods;
  }

  public static function getDisabledMods():Array<ModMetadata>
  {
    var modMetadata:Array<ModMetadata> = getAllMods();
    var enabledModIds:Array<String> = Save.instance.enabledModIds.value;
    var disabledMods:Array<ModMetadata> = modMetadata.filter((item) ->
    {
      return !enabledModIds.contains(item.id);
    });

    disabledMods.sort((a, b) ->
    {
      return SortUtil.alphabetically(a.title, b.title);
    });

    return disabledMods;
  }

  public static function getDisabledModsIncludingIncompatible(force:Bool = false):Array<ModMetadata>
  {
    var modMetadata:Array<ModMetadata> = getAllModsIncludingIncompatible(force);
    var enabledModIds:Array<String> = Save.instance.enabledModIds.value;
    var disabledMods:Array<ModMetadata> = modMetadata.filter((item) ->
    {
      return !enabledModIds.contains(item.id);
    });

    disabledMods.sort((a, b) ->
    {
      var aCompatible:Bool = isModCompatible(a);
      var bCompatible:Bool = isModCompatible(b);
      if (aCompatible != bCompatible) return aCompatible ? 1 : -1;
      return SortUtil.alphabetically(a.title, b.title);
    });

    return disabledMods;
  }

  public static function forceReloadAssets():Void
  {
    ModuleHandler.clearModuleCache();
    Polymod.clearScripts();

    funkin.modding.PolymodHandler.loadEnabledMods();

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
