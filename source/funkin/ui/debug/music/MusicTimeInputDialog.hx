package funkin.ui.debug.music;

import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.events.KeyboardEvent;
import haxe.ui.events.MouseEvent;

@:build(haxe.ui.macros.ComponentMacros.build('assets/exclude/ui/editors/music-editor/dialogs/time-input.xml'))
class MusicTimeInputDialog extends Dialog
{
  var submitCallback:String->Void;

  public function new(title:String, prompt:String, submitCallback:String->Void)
  {
    super();

    this.title = title;
    this.submitCallback = submitCallback;

    timeInputPrompt.text = prompt;

    timeInputField.registerEvent(KeyboardEvent.KEY_DOWN, function(event:KeyboardEvent):Void
    {
      if (event.keyCode == 13) submit();
    });

    haxe.ui.Toolkit.callLater(() ->
    {
      timeInputField.focus = true;
    });
  }

  function submit():Void
  {
    var text:String = timeInputField.text != null ? timeInputField.text : '';

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
