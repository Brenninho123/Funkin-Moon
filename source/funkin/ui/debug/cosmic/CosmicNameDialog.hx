package funkin.ui.debug.cosmic;

import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.events.KeyboardEvent;
import haxe.ui.events.MouseEvent;

@:build(haxe.ui.macros.ComponentMacros.build('assets/exclude/ui/editors/cosmic-editor/dialogs/name.xml'))
class CosmicNameDialog extends Dialog
{
  var submitCallback:String->Void;

  public function new(title:String, prompt:String, initial:String, submitCallback:String->Void)
  {
    super();

    this.title = title;
    this.submitCallback = submitCallback;

    namePrompt.text = prompt;
    nameField.text = initial;

    nameField.registerEvent(KeyboardEvent.KEY_DOWN, function(event:KeyboardEvent):Void
    {
      if (event.keyCode == 13) submit();
    });

    haxe.ui.Toolkit.callLater(() ->
    {
      nameField.focus = true;
    });
  }

  function submit():Void
  {
    var text:String = nameField.text != null ? nameField.text : '';

    hideDialog(DialogButton.OK);
    submitCallback(text);
  }

  @:bind(dialogCancel, MouseEvent.CLICK)
  function onClickCancel(_):Void
  {
    hideDialog(DialogButton.CANCEL);
  }

  @:bind(dialogOk, MouseEvent.CLICK)
  function onClickOk(_):Void
  {
    submit();
  }
}
