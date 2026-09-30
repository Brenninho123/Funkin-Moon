package funkin.ui.debug.common;

import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.events.MouseEvent;

@:build(haxe.ui.macros.ComponentMacros.build('assets/exclude/ui/editors/common/dialogs/open-song.xml'))
class OpenSongDialog extends Dialog
{
  var onPick:String->Void;

  public function new(onPick:String->Void)
  {
    super();

    this.onPick = onPick;

    openSongList.populate((songId:String) ->
    {
      hideDialog(DialogButton.OK);
      this.onPick(songId);
    });
  }

  @:bind(dialogCancel, MouseEvent.CLICK)
  function onClickCancel(_):Void
  {
    hideDialog(DialogButton.CANCEL);
  }
}
