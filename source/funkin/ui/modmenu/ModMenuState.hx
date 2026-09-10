package funkin.ui.modmenu;

#if FEATURE_MOD_MENU
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxMath;
import funkin.Paths;
import funkin.audio.FunkinSound;
import funkin.graphics.FunkinSprite;
import funkin.modding.PolymodHandler;
import funkin.save.Save;
import funkin.util.modmenu.ModMenuUtils;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.MusicBeatState;
import funkin.ui.mods.transition.ModLoadingSubState;
import polymod.Polymod;
#end

class ModMenuState extends MusicBeatState
{
  #if FEATURE_MOD_MENU
  var disabledMods:Array<ModMetadata> = [];
  var enabledMods:Array<ModMetadata> = [];
  var currentColumn:Int = 1;
  var disabledIndex:Int = 0;
  var enabledIndex:Int = 0;
  var focusRow:Int = 0;
  var background:FunkinSprite;
  var backgroundWires:FunkinSprite;
  var topText:FunkinSprite;
  var disabledBox:FunkinSprite;
  var enabledBox:FunkinSprite;
  var disabledLabel:FlxText;
  var enabledLabel:FlxText;
  var disabledGroup:FlxTypedGroup<FlxSprite>;
  var enabledGroup:FlxTypedGroup<FlxSprite>;
  var openFolderBtn:FunkinSprite;
  var openFolderHighlighted:FunkinSprite;
  var doneBtn:FunkinSprite;
  var doneHighlighted:FunkinSprite;
  var transitioning:Bool = false;

  public function new()
  {
    super();
  }

  override public function create():Void
  {
    super.create();

    FunkinSound.playMusic("mod-menu-ambience", {
      startingVolume: 0.0,
      overrideExisting: true,
      restartTrack: true,
      persist: false
    });

    if (FlxG.sound.music != null)
    {
      FlxG.sound.music.fadeIn(1.0, 0.0, 1.0);
    }

    background = new FunkinSprite(0, 0);
    background.loadGraphic(Paths.image("modmenu/bg"));
    background.setGraphicSize(FlxG.width, FlxG.height);
    background.updateHitbox();
    add(background);

    backgroundWires = new FunkinSprite(0, 0);
    backgroundWires.loadGraphic(Paths.image("modmenu/bgwires"));
    backgroundWires.setGraphicSize(FlxG.width, FlxG.height);
    backgroundWires.updateHitbox();
    add(backgroundWires);

    topText = new FunkinSprite();
    topText.loadGraphic(Paths.image("modmenu/top-text"));
    topText.screenCenter(X);
    topText.y = 20;
    add(topText);

    loadModLists();
    createColumns();
    createButtons();
    refreshVisuals();
    refreshFocusVisuals();
  }

  function loadModLists():Void
  {
    disabledMods = [];
    enabledMods = [];

    var allMods:Array<ModMetadata> = PolymodHandler.getAllMods();

    for (mod in allMods)
    {
      if (mod.id == ModMenuUtils.MOD_MENU_ID) continue;

      if (ModMenuUtils.isModEnabled(mod))
      {
        enabledMods.push(mod);
      }
      else
      {
        disabledMods.push(mod);
      }
    }

    disabledIndex = clampIndex(disabledIndex, disabledMods.length - 1);
    enabledIndex = clampIndex(enabledIndex, enabledMods.length);
  }

  function createColumns():Void
  {
    var margin:Float = 55;
    var columnWidth:Float = 400;
    var leftX:Float = margin;
    var rightX:Float = FlxG.width - margin - columnWidth;
    var columnY:Float = 135;

    disabledBox = new FunkinSprite(leftX, columnY);
    disabledBox.loadGraphic(Paths.image("modmenu/box"));
    disabledBox.setGraphicSize(Std.int(columnWidth), Std.int(FlxG.height - columnY - 115));
    disabledBox.updateHitbox();
    add(disabledBox);

    enabledBox = new FunkinSprite(rightX, columnY);
    enabledBox.loadGraphic(Paths.image("modmenu/box"));
    enabledBox.setGraphicSize(Std.int(columnWidth), Std.int(FlxG.height - columnY - 115));
    enabledBox.updateHitbox();
    add(enabledBox);

    disabledLabel = new FlxText(leftX, columnY + 8, columnWidth, "DISABLED", 28);
    disabledLabel.setFormat(Paths.font("FunkinLingLong.otf"), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(disabledLabel);

    enabledLabel = new FlxText(rightX, columnY + 8, columnWidth, "ENABLED", 28);
    enabledLabel.setFormat(Paths.font("FunkinLingLong.otf"), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(enabledLabel);

    disabledGroup = new FlxTypedGroup<FlxSprite>();
    enabledGroup = new FlxTypedGroup<FlxSprite>();

    add(disabledGroup);
    add(enabledGroup);
  }

  function createButtons():Void
  {
    openFolderBtn = new FunkinSprite();
    openFolderBtn.loadGraphic(Paths.image("modmenu/open-folder"));
    openFolderBtn.x = 55;
    openFolderBtn.y = FlxG.height - openFolderBtn.height - 30;
    add(openFolderBtn);

    doneBtn = new FunkinSprite();
    doneBtn.loadGraphic(Paths.image("modmenu/done"));
    doneBtn.x = FlxG.width - doneBtn.width - 55;
    doneBtn.y = FlxG.height - doneBtn.height - 30;
    add(doneBtn);

    openFolderHighlighted = new FunkinSprite(openFolderBtn.x, openFolderBtn.y);
    openFolderHighlighted.loadGraphic(Paths.image("modmenu/open-folder-highlighted"));
    openFolderHighlighted.visible = false;
    add(openFolderHighlighted);

    doneHighlighted = new FunkinSprite(doneBtn.x, doneBtn.y);
    doneHighlighted.loadGraphic(Paths.image("modmenu/done-highlighted"));
    doneHighlighted.visible = false;
    add(doneHighlighted);
  }

  function refreshVisuals():Void
  {
    disabledGroup.clear();
    enabledGroup.clear();

    var leftX:Float = disabledBox.x;
    var rightX:Float = enabledBox.x;
    var y:Float = disabledBox.y + 55;

    buildColumnEntries(disabledGroup, disabledMods, leftX, y, currentColumn == 0 ? disabledIndex : -1, false);

    buildColumnEntries(enabledGroup, enabledMods, rightX, y, currentColumn == 1 ? enabledIndex : -1, true);
  }

  function buildColumnEntries(group:FlxTypedGroup<FlxSprite>, mods:Array<ModMetadata>, x:Float, y:Float, selectedIndex:Int, isEnabledColumn:Bool):Void
  {
    var rowWidth:Float = 380;
    var rowHeight:Float = 90;
    var startY:Float = y;
    var index:Int = 0;

    if (isEnabledColumn)
    {
      addModRow(group, x + 10, startY, rowWidth, rowHeight, null, selectedIndex == 0);

      index = 1;
      startY += rowHeight + 10;
    }

    for (mod in mods)
    {
      addModRow(group, x + 10, startY, rowWidth, rowHeight, mod, selectedIndex == index);

      startY += rowHeight + 10;
      index++;
    }
  }

  function addModRow(group:FlxTypedGroup<FlxSprite>, x:Float, y:Float, w:Float, h:Float, mod:Null<ModMetadata>, selected:Bool):Void
  {
    var rowBg:FunkinSprite = new FunkinSprite(x, y);
    rowBg.loadGraphic(Paths.image("modmenu/box"));
    rowBg.setGraphicSize(Std.int(w), Std.int(h));
    rowBg.updateHitbox();
    rowBg.alpha = selected ? 1.0 : 0.75;
    group.add(rowBg);

    var icon:FunkinSprite = new FunkinSprite(x + 10, y + 10);

    var iconSize:Int = Std.int(h - 20);

    if (mod == null)
    {
      icon.loadGraphic(Paths.image("modmenu/base-icon"));
    }
    else
    {
      icon.loadGraphic(ModMenuUtils.getModIcon(mod));
    }

    icon.setGraphicSize(iconSize, iconSize);
    icon.updateHitbox();
    group.add(icon);

    var modTitle:String = mod != null ? mod.title : "BASE GAME";

    var titleText:FlxText = new FlxText(x + iconSize + 25, y + 12, w - iconSize - 35, modTitle, 22);

    titleText.setFormat(Paths.font("FunkinLingLong.otf"), 22, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

    group.add(titleText);

    var description:String;

    if (mod == null)
    {
      description = "Default game content";
    }
    else
    {
      var value:Dynamic = Reflect.field(mod, "description");
      description = value != null ? Std.string(value) : "";
    }

    var descText:FlxText = new FlxText(x + iconSize + 25, y + 42, w - iconSize - 35, description, 15);

    descText.setFormat(Paths.font("FunkinLingLong.otf"), 15, 0xFFCCCCCC, LEFT);

    group.add(descText);
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (transitioning) return;

    if (focusRow == 0)
    {
      updateListNavigation();
    }

    if (FlxG.keys.justPressed.TAB)
    {
      focusRow++;

      if (focusRow > 2)
      {
        focusRow = 0;
      }

      refreshFocusVisuals();
    }

    if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
    {
      confirmFocus();
    }

    if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE)
    {
      leaveMenu();
    }
  }

  function updateListNavigation():Void
  {
    if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A || FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D)
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

  function confirmFocus():Void
  {
    switch (focusRow)
    {
      case 0:
        toggleSelectedMod();

      case 1:
        openModFolder();

      case 2:
        leaveMenu();
    }
  }

  function toggleSelectedMod():Void
  {
    if (currentColumn == 0)
    {
      if (disabledMods.length == 0) return;

      if (disabledIndex < 0 || disabledIndex >= disabledMods.length)
      {
        return;
      }

      var mod:ModMetadata = disabledMods[disabledIndex];

      ModMenuUtils.toggleMod(mod);
      loadModLists();

      enabledIndex = enabledMods.indexOf(mod);

      if (enabledIndex < 0)
      {
        enabledIndex = 0;
      }
      else
      {
        enabledIndex++;
      }

      disabledIndex = clampIndex(disabledIndex, disabledMods.length - 1);
    }
    else
    {
      if (enabledIndex == 0) return;

      var modIndex:Int = enabledIndex - 1;

      if (modIndex < 0 || modIndex >= enabledMods.length)
      {
        return;
      }

      var mod:ModMetadata = enabledMods[modIndex];

      ModMenuUtils.toggleMod(mod);
      loadModLists();

      disabledIndex = disabledMods.indexOf(mod);

      if (disabledIndex < 0)
      {
        disabledIndex = 0;
      }

      enabledIndex = clampIndex(enabledIndex, enabledMods.length);
    }

    refreshVisuals();
  }

  function openModFolder():Void
  {
    #if sys
    #if windows
    Sys.command("explorer", [PolymodHandler.getModFolder()]);
    #elseif linux
    Sys.command("xdg-open", [PolymodHandler.getModFolder()]);
    #elseif mac
    Sys.command("open", [PolymodHandler.getModFolder()]);
    #end
    #end
  }

  function refreshFocusVisuals():Void
  {
    openFolderBtn.visible = focusRow != 1;
    openFolderHighlighted.visible = focusRow == 1;

    doneBtn.visible = focusRow != 2;
    doneHighlighted.visible = focusRow == 2;
  }

  function leaveMenu():Void
  {
    if (transitioning) return;

    transitioning = true;

    if (FlxG.sound.music != null)
    {
      FlxG.sound.music.fadeOut(0.5, 0.0);
    }

    new FlxTimer().start(2.5, function(timer:FlxTimer)
    {
      openSubState(new ModLoadingSubState(new MainMenuState()));
    });
  }

  function clampIndex(value:Int, max:Int):Int
  {
    if (max < 0) return 0;
    if (value < 0) return 0;
    if (value > max) return max;

    return value;
  }
  #end
}
