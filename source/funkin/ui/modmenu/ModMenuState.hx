package funkin.ui.modmenu;

#if FEATURE_MOD_MENU
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import funkin.graphics.FunkinSprite;
import funkin.modding.PolymodHandler;
import funkin.save.Save;
import funkin.ui.MusicBeatState;
import funkin.ui.mainmenu.MainMenuState;
import polymod.Polymod.ModMetadata;
import funkin.Paths;
#end

class ModMenuState extends MusicBeatState
{
  #if FEATURE_MOD_MENU
  var vcrFont:String;
  // ---- dados dos mods ----
  var disabledMods:Array<ModMetadata> = [];
  var enabledMods:Array<ModMetadata> = [];
  // ---- coluna atual: 0 = disabled, 1 = enabled ----
  var currentColumn:Int = 1;
  var disabledIndex:Int = 0;
  var enabledIndex:Int = 0;
  // ---- foco geral: 0 = lista de mods, 1 = OPEN MOD FOLDER, 2 = DONE ----
  var focusRow:Int = 0;
  var disabledGroup:FlxTypedGroup<FlxSprite>;
  var enabledGroup:FlxTypedGroup<FlxSprite>;
  var openFolderBtn:FlxText;
  var doneBtn:FlxText;

  public function new()
  {
    super();
  }

  public override function create():Void
  {
    super.create();

    vcrFont = Paths.font('vcr.ttf');

    // Fundo sólido, placeholder.
    var bg = new FlxSprite(0, 0);
    bg.makeGraphic(Std.int(FlxG.width), Std.int(FlxG.height), 0xFF2A2438);
    add(bg);

    var title = new FlxText(0, 20, FlxG.width, 'CHOOSE YOUR MODS', 40);
    title.setFormat(vcrFont, 40, FlxColor.WHITE, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(title);

    var subtitle = new FlxText(0, 70, FlxG.width, 'Drag packs onto this window to add new stuff', 18);
    subtitle.setFormat(vcrFont, 18, 0xFFCCCCCC, "center");
    add(subtitle);

    loadModLists();

    setupColumn(60, 130, 'DISABLED', true);
    setupColumn(FlxG.width - 60 - 400, 130, 'ENABLED', false);

    openFolderBtn = new FlxText(60, FlxG.height - 60, 260, 'OPEN MOD FOLDER', 26);
    openFolderBtn.setFormat(vcrFont, 26, FlxColor.WHITE, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(openFolderBtn);

    doneBtn = new FlxText(FlxG.width - 60 - 200, FlxG.height - 60, 200, 'DONE', 26);
    doneBtn.setFormat(vcrFont, 26, FlxColor.WHITE, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(doneBtn);

    refreshVisuals();
    refreshFocusVisuals();
  }

  function loadModLists():Void
  {
    var allMods:Array<ModMetadata> = PolymodHandler.getAllMods();

    disabledMods = [];
    enabledMods = [];

    // Mods que estão realmente habilitados no Save.
    var enabledDirs:Array<String> = Save.instance.enabledModDirs.value;

    for (mod in allMods)
    {
      if (enabledDirs.indexOf(mod.dirName) != -1)
      {
        enabledMods.push(mod);
      }
      else
      {
        disabledMods.push(mod);
      }
    }
  }

  function setupColumn(x:Float, y:Float, label:String, isDisabledColumn:Bool):Void
  {
    var box = new FlxSprite(x, y);
    box.makeGraphic(400, Std.int(FlxG.height - y - 100), 0xFF141018);
    add(box);

    var header = new FlxText(x, y - 35, 400, label, 28);
    header.setFormat(vcrFont, 28, FlxColor.WHITE, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(header);

    if (isDisabledColumn)
    {
      disabledGroup = new FlxTypedGroup<FlxSprite>();
      add(disabledGroup);
    }
    else
    {
      enabledGroup = new FlxTypedGroup<FlxSprite>();
      add(enabledGroup);
    }
  }

  function refreshVisuals():Void
  {
    disabledGroup.clear();
    enabledGroup.clear();

    buildColumnEntries(disabledGroup, disabledMods, 60, 130, currentColumn == 0 ? disabledIndex : -1, false);

    buildColumnEntries(enabledGroup, enabledMods, FlxG.width - 60 - 400, 130, currentColumn == 1 ? enabledIndex : -1, true);
  }

  function buildColumnEntries(group:FlxTypedGroup<FlxSprite>, mods:Array<ModMetadata>, x:Float, y:Float, selectedIndex:Int, isEnabledColumn:Bool):Void
  {
    var rowHeight = 90;
    var startY = y + 10;
    var index = 0;

    // BASE GAME fica no topo da coluna ENABLED.
    if (isEnabledColumn)
    {
      addModRow(group, x + 10, startY, 380, rowHeight, null, selectedIndex == 0);

      index = 1;
      startY += rowHeight + 10;
    }

    for (mod in mods)
    {
      addModRow(group, x + 10, startY, 380, rowHeight, mod, selectedIndex == index);

      startY += rowHeight + 10;
      index++;
    }
  }

  function addModRow(group:FlxTypedGroup<FlxSprite>, x:Float, y:Float, w:Float, h:Float, mod:Null<ModMetadata>, selected:Bool):Void
  {
    var rowBg = new FlxSprite(x, y);

    rowBg.makeGraphic(Std.int(w), Std.int(h), selected ? 0xFF6A6A6A : 0xFF000000);

    group.add(rowBg);

    // Ícone do mod.
    var icon = new FunkinSprite(x + 8, y + 8);
    var iconSize = Std.int(h - 16);

    #if sys
    if (mod != null)
    {
      var iconPath:String = 'mods/${mod.dirName}/_polymod_icon.png';

      if (sys.FileSystem.exists(iconPath))
      {
        icon.loadGraphic(iconPath);
        icon.setGraphicSize(iconSize, iconSize);
        icon.updateHitbox();
      }
      else
      {
        icon.makeGraphic(iconSize, iconSize, 0xFFFFE55C);
      }
    }
    else
    {
      // BASE GAME ainda não possui caminho de imagem definido.
      icon.makeGraphic(iconSize, iconSize, 0xFFFFE55C);
    }
    #else
    icon.makeGraphic(iconSize, iconSize, 0xFFFFE55C);
    #end

    group.add(icon);

    var modTitle = mod != null ? mod.title : 'BASE GAME';
    var modDesc = mod != null ? (Reflect.field(mod, 'description') ?? '') : 'Default game content';

    var titleText = new FlxText(x + iconSize + 20, y + 10, w - iconSize - 30, modTitle, 22);

    titleText.setFormat(vcrFont, 22, FlxColor.WHITE, "left");
    group.add(titleText);

    var descText = new FlxText(x + iconSize + 20, y + 38, w - iconSize - 30, modDesc, 16);

    descText.setFormat(vcrFont, 16, 0xFFAAAAAA, "left");
    group.add(descText);
  }

  public override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (focusRow == 0)
    {
      updateListNavigation();
    }

    // TAB alterna entre lista de mods / OPEN MOD FOLDER / DONE
    if (FlxG.keys.justPressed.TAB)
    {
      focusRow = (focusRow + 1) % 3;
      refreshFocusVisuals();
    }

    if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
    {
      confirmFocus();
    }

    if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE)
    {
      FlxG.switchState(() -> new MainMenuState());
    }
  }

  function updateListNavigation():Void
  {
    var leftRight = FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A || FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D;

    if (leftRight)
    {
      currentColumn = currentColumn == 0 ? 1 : 0;
      refreshVisuals();
    }

    if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
    {
      if (currentColumn == 0)
      {
        disabledIndex = clampIndex(disabledIndex + 1, disabledMods.length - 1);
      }
      else
      {
        // ENABLED tem BASE GAME no índice 0.
        enabledIndex = clampIndex(enabledIndex + 1, enabledMods.length);
      }

      refreshVisuals();
    }

    if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
    {
      if (currentColumn == 0)
      {
        disabledIndex = clampIndex(disabledIndex - 1, disabledMods.length - 1);
      }
      else
      {
        enabledIndex = clampIndex(enabledIndex - 1, enabledMods.length);
      }

      refreshVisuals();
    }
  }

  function clampIndex(value:Int, max:Int):Int
  {
    if (max < 0) return 0;

    if (value < 0) return 0;

    if (value > max) return max;

    return value;
  }

  function confirmFocus():Void
  {
    switch (focusRow)
    {
      case 0:
        toggleSelectedMod();

      case 1:
        openModFolder();

      case 2:
        FlxG.switchState(() -> new MainMenuState());
    }
  }

  function toggleSelectedMod():Void
  {
    var enabledDirs:Array<String> = Save.instance.enabledModDirs.value;

    if (currentColumn == 0)
    {
      // DISABLED -> ENABLED
      if (disabledMods.length == 0) return;

      if (disabledIndex < 0 || disabledIndex >= disabledMods.length) return;

      var mod = disabledMods[disabledIndex];

      if (enabledDirs.indexOf(mod.dirName) == -1)
      {
        enabledDirs.push(mod.dirName);
      }

      Save.instance.enabledModDirs.value = enabledDirs;

      loadModLists();

      disabledIndex = clampIndex(disabledIndex, disabledMods.length - 1);

      enabledIndex = clampIndex(enabledIndex, enabledMods.length);
    }
    else
    {
      // BASE GAME não pode ser desativado.
      if (enabledIndex == 0) return;

      if (enabledMods.length == 0) return;

      var mod = enabledMods[enabledIndex - 1];

      enabledDirs.remove(mod.dirName);

      Save.instance.enabledModDirs.value = enabledDirs;

      loadModLists();

      disabledIndex = clampIndex(disabledIndex, disabledMods.length - 1);

      enabledIndex = clampIndex(enabledIndex, enabledMods.length);
    }

    refreshVisuals();
  }

  function openModFolder():Void
  {
    // essa porra aqui não funciona no Linux, mas no Windows abre a pasta de mods, urgente arrumar isso depois

    #if sys
    Sys.command('explorer', ['mods']);
    #end
  }

  function refreshFocusVisuals():Void
  {
    openFolderBtn.color = focusRow == 1 ? FlxColor.YELLOW : FlxColor.WHITE;

    doneBtn.color = focusRow == 2 ? FlxColor.YELLOW : FlxColor.WHITE;
  }
  #end
}
