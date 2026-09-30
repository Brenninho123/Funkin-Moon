package funkin.ui.debug.modcharteditor;

import funkin.play.modcharts.ModchartDocument;
import funkin.play.modcharts.ModchartDocument.ModchartEvent;

typedef ModchartPreset =
{
  var id:String;
  var label:String;
  var build:(time:Float, beat:Float) -> Array<Null<ModchartEvent>>;
}

class ModchartPresets
{
  public static final ALL:Array<ModchartPreset> = [
    {
      id: 'spin',
      label: 'Spin the strumlines (4 beats)',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, b * 4, 'both', -1, 'angle', 360, 'quadInOut'),
        ModchartDocument.makeEvent(t + b * 4, 0, 'both', -1, 'angle', 0, 'instant')
      ]
    },
    {
      id: 'drunk',
      label: 'Drunk section (8 beats)',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, b, 'both', -1, 'drunk', 40, 'sineOut'),
        ModchartDocument.makeEvent(t + b * 8, b, 'both', -1, 'drunk', 0, 'sineIn')
      ]
    },
    {
      id: 'tipsy',
      label: 'Tipsy section (8 beats)',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, b, 'both', -1, 'tipsy', 30, 'sineOut'),
        ModchartDocument.makeEvent(t + b * 8, b, 'both', -1, 'tipsy', 0, 'sineIn')
      ]
    },
    {
      id: 'wobble',
      label: 'Wobbling arrows (8 beats)',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, b, 'both', -1, 'wobble', 18, 'sineOut'),
        ModchartDocument.makeEvent(t + b * 8, b, 'both', -1, 'wobble', 0, 'sineIn')
      ]
    },
    {
      id: 'sway',
      label: 'Sway the HUD (4 beats)',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, b, 'hud', -1, 'angle', 6, 'sineInOut'),
        ModchartDocument.makeEvent(t + b, b * 2, 'hud', -1, 'angle', -6, 'sineInOut'),
        ModchartDocument.makeEvent(t + b * 3, b, 'hud', -1, 'angle', 0, 'sineInOut')
      ]
    },
    {
      id: 'punch',
      label: 'HUD zoom punch',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, 0, 'hud', -1, 'zoom', 1.15, 'instant'),
        ModchartDocument.makeEvent(t, b, 'hud', -1, 'zoom', 1.0, 'quadOut')
      ]
    },
    {
      id: 'fadeout',
      label: 'Fade out the opponent (2 beats)',
      build: (t, b) -> [ModchartDocument.makeEvent(t, b * 2, 'opponent', -1, 'alpha', 0, 'linear')]
    },
    {
      id: 'fadein',
      label: 'Fade in the opponent (2 beats)',
      build: (t, b) -> [ModchartDocument.makeEvent(t, b * 2, 'opponent', -1, 'alpha', 1, 'linear')]
    },
    {
      id: 'swap',
      label: 'Swap the strumlines (2 beats)',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, b * 2, 'player', -1, 'x', -640, 'backOut'),
        ModchartDocument.makeEvent(t, b * 2, 'opponent', -1, 'x', 640, 'backOut')
      ]
    },
    {
      id: 'reset',
      label: 'Reset everything (1 beat)',
      build: (t, b) -> resetAll(t, b)
    }
  ];

  public static function resetAll(time:Float, beat:Float):Array<Null<ModchartEvent>>
  {
    var events:Array<Null<ModchartEvent>> = [];

    for (target in ['both', 'player', 'opponent'])
    {
      for (modifier in ['x', 'y', 'angle', 'drunk', 'tipsy', 'wobble'])
      {
        events.push(ModchartDocument.makeEvent(time, beat, target, -1, modifier, 0, 'quadOut'));
      }

      events.push(ModchartDocument.makeEvent(time, beat, target, -1, 'alpha', 1, 'quadOut'));
    }

    for (target in ['hud', 'game'])
    {
      for (modifier in ['x', 'y', 'angle'])
      {
        events.push(ModchartDocument.makeEvent(time, beat, target, -1, modifier, 0, 'quadOut'));
      }

      events.push(ModchartDocument.makeEvent(time, beat, target, -1, 'zoom', 1, 'quadOut'));
    }

    return events;
  }

  public static function find(id:String):Null<ModchartPreset>
  {
    for (preset in ALL)
    {
      if (preset.id == id) return preset;
    }

    return null;
  }
}
