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
      id: 'beatbounce',
      label: 'Beat bounce (8 beats)',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, 0, 'both', -1, 'beat', 60, 'instant'),
        ModchartDocument.makeEvent(t + b * 8, 0, 'both', -1, 'beat', 0, 'instant')
      ]
    },
    {
      id: 'flip',
      label: 'Flip the lanes (2 beats)',
      build: (t, b) -> [ModchartDocument.makeEvent(t, b * 2, 'both', -1, 'flip', 1, 'backOut')]
    },
    {
      id: 'invert',
      label: 'Invert the lane pairs (2 beats)',
      build: (t, b) -> [ModchartDocument.makeEvent(t, b * 2, 'both', -1, 'invert', 1, 'backOut')]
    },
    {
      id: 'bumpy',
      label: 'Bumpy notes (8 beats)',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, b, 'both', -1, 'bumpy', 60, 'sineOut'),
        ModchartDocument.makeEvent(t + b * 8, b, 'both', -1, 'bumpy', 0, 'sineIn')
      ]
    },
    {
      id: 'bigarrows',
      label: 'Big arrows (4 beats)',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, b, 'both', -1, 'scale', 1.4, 'backOut'),
        ModchartDocument.makeEvent(t + b * 4, b, 'both', -1, 'scale', 1, 'quadInOut')
      ]
    },
    {
      id: 'spinnotes',
      label: 'Keep spinning (4 beats)',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, 0, 'both', -1, 'spin', 180, 'instant'),
        ModchartDocument.makeEvent(t + b * 4, 0, 'both', -1, 'spin', 0, 'instant')
      ]
    },
    {
      id: 'hidenotes',
      label: 'Hide the notes, keep the receptors (4 beats)',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, b, 'both', -1, 'noteAlpha', 0, 'linear'),
        ModchartDocument.makeEvent(t + b * 4, b, 'both', -1, 'noteAlpha', 1, 'linear')
      ]
    },
    {
      id: 'shake',
      label: 'Shake the game camera (2 beats)',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, 0, 'game', -1, 'shake', 12, 'instant'),
        ModchartDocument.makeEvent(t, b * 2, 'game', -1, 'shake', 0, 'quadOut')
      ]
    },
    {
      id: 'pulse',
      label: 'Pulse the cameras on the beat (8 beats)',
      build: (t, b) -> [
        ModchartDocument.makeEvent(t, 0, 'hud', -1, 'pulse', 0.06, 'instant'),
        ModchartDocument.makeEvent(t, 0, 'game', -1, 'pulse', 0.03, 'instant'),
        ModchartDocument.makeEvent(t + b * 8, 0, 'hud', -1, 'pulse', 0, 'instant'),
        ModchartDocument.makeEvent(t + b * 8, 0, 'game', -1, 'pulse', 0, 'instant')
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
      for (modifier in ['x', 'y', 'angle', 'drunk', 'tipsy', 'wobble', 'spin', 'flip', 'invert', 'beat', 'bumpy'])
      {
        events.push(ModchartDocument.makeEvent(time, beat, target, -1, modifier, 0, 'quadOut'));
      }

      events.push(ModchartDocument.makeEvent(time, beat, target, -1, 'alpha', 1, 'quadOut'));
      events.push(ModchartDocument.makeEvent(time, beat, target, -1, 'noteAlpha', 1, 'quadOut'));
      events.push(ModchartDocument.makeEvent(time, beat, target, -1, 'scale', 1, 'quadOut'));
    }

    for (target in ['hud', 'game'])
    {
      for (modifier in ['x', 'y', 'angle', 'shake', 'pulse'])
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
