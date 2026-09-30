package funkin.ui.debug.cosmic;

import funkin.modding.ModDoctor;
import funkin.modding.ModDoctor.ModReport;
import funkin.modding.PolymodHandler;
import funkin.save.Save;
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.events.MouseEvent;

@:build(haxe.ui.macros.ComponentMacros.build('assets/exclude/ui/editors/cosmic-editor/dialogs/mods.xml'))
class CosmicModsDialog extends Dialog
{
  public function new()
  {
    super();

    refresh();
  }

  function refresh():Void
  {
    var enabled:Array<String> = Save.instance.enabledModIds.value.copy();
    var report:ModReport = PolymodHandler.inspectMods(enabled, true);

    modsSummary.text = enabled.length == 0 ? 'No mods are enabled. Enable mods in the Mod Menu first.' : ModDoctor.summarize(report);

    problemList.dataSource.clear();
    orderList.dataSource.clear();
    overrideList.dataSource.clear();

    for (item in report.findings)
    {
      problemList.dataSource.add({text: item.level.toUpperCase() + '  ' + item.message});
    }

    if (report.findings.length == 0 && enabled.length > 0) problemList.dataSource.add({text: 'No problems found.'});

    for (i in 0...report.order.length) orderList.dataSource.add({text: (i + 1) + '.  ' + report.order[i]});

    for (conflict in report.conflicts)
    {
      overrideList.dataSource.add({text: conflict.path + '   ' + conflict.winner + ' replaces ' + conflict.others.join(', ')});
    }

    if (report.conflicts.length == 0 && enabled.length > 0) overrideList.dataSource.add({text: 'No file is replaced by more than one mod.'});
  }

  @:bind(modsRefresh, MouseEvent.CLICK)
  function onClickRefresh(_):Void
  {
    refresh();
  }

  @:bind(dialogClose, MouseEvent.CLICK)
  function onClickClose(_):Void
  {
    hideDialog(DialogButton.CANCEL);
  }
}
