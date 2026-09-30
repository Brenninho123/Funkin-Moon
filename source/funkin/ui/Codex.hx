package funkin.ui;

import funkin.ui.Page.PageName;
import flixel.group.FlxGroup;
import funkin.modding.events.ScriptEvent.CodexScriptEvent;
import funkin.modding.module.ModuleHandler;

interface CodexControl
{
  public function getCurrentPageName():String;
  public function getPageNames():Array<String>;
  public function hasPage(name:String):Bool;
  public function requestPage(name:String):Bool;
}

/**
 * The Codex class is what holds our `Page` objects together. Apologies for the potentially obtuse quirky name.
 * Codex stands for "Collection Of Pages ex"... imagine P is rotated 180 degress now its a d :)
 * I just wanted something not called "PageManager" grr...
 */
class Codex<T:PageName> extends FlxGroup implements CodexControl
{
  public static var current(default, null):Null<CodexControl> = null;

  var pages:Map<T, Page<T>>;

  public var currentName:T;
  public var currentPage(get, never):Page<T>;

  inline function get_currentPage():Page<T> return pages[currentName];

  public function new(initPage:T)
  {
    super();
    pages = new Map<T, Page<T>>();
    currentName = initPage;
    current = this;
  }

  public function addPage<P:Page<T>>(name:T, page:P):P
  {
    page.onSwitch.add(switchPage);
    page.codex = this;
    pages[name] = page;
    add(page);
    page.exists = currentName == name;
    return page;
  }

  public function setPage(name:T):Void
  {
    if (!pages.exists(name)) return;

    var previousName:T = currentName;

    if (pages.exists(previousName))
    {
      currentPage.exists = false;
      currentPage.visible = false;
    }

    currentName = name;

    currentPage.exists = true;
    currentPage.visible = true;

    if (previousName != name)
    {
      ModuleHandler.callEvent(new CodexScriptEvent(previousName, name));
    }
  }

  public function switchPage(name:T):Void
  {
    setPage(name);
  }

  public function getCurrentPageName():String
  {
    return currentName;
  }

  public function getPageNames():Array<String>
  {
    return [for (name in pages.keys()) name];
  }

  public function hasPage(name:String):Bool
  {
    return pages.exists(cast name);
  }

  public function requestPage(name:String):Bool
  {
    var target:T = cast name;

    if (!pages.exists(target)) return false;

    if (pages.exists(currentName) && !currentPage.enabled) return false;

    switchPage(target);

    return true;
  }

  override public function destroy():Void
  {
    if (current == this) current = null;

    super.destroy();
  }
}
