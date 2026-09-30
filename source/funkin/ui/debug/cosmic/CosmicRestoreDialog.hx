package funkin.ui.debug.cosmic;

import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;

typedef CosmicBackup =
{
  var slot:Int;
  var text:String;
}

@:build(haxe.ui.macros.ComponentMacros.build('assets/exclude/ui/editors/cosmic-editor/dialogs/restore.xml'))
class CosmicRestoreDialog extends Dialog
{
  var pickCallback:Int->Void;

  public function new(label:String, backups:Array<CosmicBackup>, pickCallback:Int->Void)
  {
    super();

    this.pickCallback = pickCallback;

    restorePrompt.text = backups.length == 0 ? label + ' has no backups yet. Saving creates them.' : 'Pick the backup that replaces ' + label + '.';

    for (backup in backups) backupList.dataSource.add({text: backup.text, slot: backup.slot});
  }

  @:bind(backupList, UIEvent.CHANGE)
  function onBackupChange(_):Void
  {
    dialogOk.disabled = backupList.selectedItem == null;
  }

  @:bind(dialogCancel, MouseEvent.CLICK)
  function onClickCancel(_):Void
  {
    hideDialog(DialogButton.CANCEL);
  }

  @:bind(dialogOk, MouseEvent.CLICK)
  function onClickOk(_):Void
  {
    if (backupList.selectedItem == null) return;

    var slot:Int = Std.int(backupList.selectedItem.slot);

    hideDialog(DialogButton.OK);
    pickCallback(slot);
  }
}
