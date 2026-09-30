package funkin.ui.debug.cosmic;

import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.events.MouseEvent;
import lime.system.Clipboard;

@:build(haxe.ui.macros.ComponentMacros.build('assets/exclude/ui/editors/cosmic-editor/dialogs/info.xml'))
class CosmicInfoDialog extends Dialog
{
  var content:String;

  public function new(title:String, content:String)
  {
    super();

    this.title = title;
    this.content = content;

    infoText.text = content;
  }

  @:bind(infoCopy, MouseEvent.CLICK)
  function onClickCopy(_):Void
  {
    Clipboard.text = content;
  }

  @:bind(dialogClose, MouseEvent.CLICK)
  function onClickClose(_):Void
  {
    hideDialog(DialogButton.CANCEL);
  }
}
