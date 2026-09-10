package funkin.ui.mods.transition;

#if FEATURE_MOD_LOADING
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import funkin.Paths;
import funkin.graphics.FunkinSprite;
import funkin.modding.PolymodHandler;
import funkin.audio.FunkinSound;
import funkin.ui.mainmenu.MainMenuState;
#end
import flixel.FlxSubState;

class ModLoadingSubState extends FlxSubState
{
  #if FEATURE_MOD_LOADING
  // ============================================================
  // CONFIGURAÇÃO DA BARRA
  // ============================================================

  /**
   * Cor da parte preenchida da barra.
   *
   * Pode usar:
   * FlxColor.GREEN
   * FlxColor.LIME
   * 0xFF00FF00
   * etc.
   */
  public static var BAR_COLOR:Int = FlxColor.LIME;

  /**
   * Cor do fundo da barra.
   */
  public static var BAR_BACKGROUND_COLOR:Int = 0xFF818181;

  /**
   * Largura da barra.
   */
  public static var BAR_WIDTH:Float = 500;

  /**
   * Altura/espessura da barra.
   */
  public static var BAR_HEIGHT:Float = 22;

  /**
   * Escala geral da barra.
   *
   * 1.0 = tamanho normal
   * 0.5 = metade
   * 2.0 = dobro
   */
  public static var BAR_SCALE:Float = 1.0;

  /**
   * Distância entre o throbber e a barra.
   */
  public static var THROBBER_GAP:Float = 20;

  /**
   * Escala do throbber.
   */
  public static var THROBBER_SCALE:Float = 1.0;

  // ============================================================
  // OBJETOS
  // ============================================================
  public var throbber:FunkinSprite;

  var barBackground:FlxSprite;
  var barFill:FlxSprite;
  var progress:Float = 0;

  /**
   * Estado que será aberto quando o loading terminar.
   */
  var targetState:FlxState;

  var finished:Bool = false;

  // ============================================================
  // CONSTRUTOR
  // ============================================================

  public function new(?targetState:FlxState)
  {
    super();

    this.targetState = targetState;
  }

  // ============================================================
  // CREATE
  // ============================================================

  override public function create():Void
  {
    super.create();

    FlxG.state.persistentUpdate = false;
    FlxG.state.persistentDraw = false;

    createBackground();
    createLoadingBar();
    startLoading();
  }

  // ============================================================
  // FUNDO
  // ============================================================

  function createBackground():Void
  {
    var background:FlxSprite = new FlxSprite();

    background.makeGraphic(FlxG.width, FlxG.height, 0xFF050505);

    add(background);
  }

  // ============================================================
  // BARRA
  // ============================================================

  function createLoadingBar():Void
  {
    var scaledWidth:Float = BAR_WIDTH * BAR_SCALE;
    var scaledHeight:Float = BAR_HEIGHT * BAR_SCALE;

    /**
     * O conjunto inteiro fica centralizado.
     *
     * Primeiro calculamos o espaço ocupado pelo throbber
     * + barra.
     */
    var throbberSize:Float = 64 * THROBBER_SCALE;

    var totalWidth:Float = throbberSize + THROBBER_GAP + scaledWidth;

    var startX:Float = (FlxG.width - totalWidth) / 2;

    var centerY:Float = FlxG.height / 2;

    // ==========================================================
    // THROBBER
    // ==========================================================

    throbber = new FunkinSprite();

    throbber.loadGraphic(Paths.image("modmenu/throbber"));

    throbber.setGraphicSize(Std.int(throbber.width * THROBBER_SCALE), Std.int(throbber.height * THROBBER_SCALE));

    throbber.updateHitbox();

    throbber.x = startX;
    throbber.y = centerY - throbber.height / 2;

    add(throbber);

    // ==========================================================
    // POSIÇÃO DA BARRA
    // ==========================================================

    var barX:Float = startX + throbber.width + THROBBER_GAP;

    var barY:Float = centerY - scaledHeight / 2;

    // ==========================================================
    // FUNDO CINZA
    // ==========================================================

    barBackground = new FlxSprite(barX, barY);

    barBackground.makeGraphic(Std.int(scaledWidth), Std.int(scaledHeight), BAR_BACKGROUND_COLOR);

    add(barBackground);

    // ==========================================================
    // PARTE VERDE
    // ==========================================================

    barFill = new FlxSprite(barX, barY);

    barFill.makeGraphic(Std.int(scaledWidth), Std.int(scaledHeight), BAR_COLOR);

    /**
     * Começa vazia.
     */
    barFill.scale.x = 0;

    /**
     * Faz a barra crescer da esquerda para a direita.
     */
    barFill.origin.set(0, 0);

    add(barFill);
  }

  // ============================================================
  // CARREGAMENTO
  // ============================================================

  function startLoading():Void
  {
    PolymodHandler.forceReloadAssets();

    /**
     * Começa com a barra vazia.
     */
    setProgress(0);

    /**
     * Anima a barra até 100%.
     */
    FlxTween.num(0, 1, 1.5, {
      ease: FlxEase.cubeInOut,

      onUpdate: function(tween:FlxTween)
      {
        setProgress(tween.percent);
      },

      onComplete: function(_)
      {
        finishLoading();
      }
    });
  }

  // ============================================================
  // PROGRESSO
  // ============================================================

  public function setProgress(value:Float):Void
  {
    progress = FlxMath.bound(value, 0, 1);

    if (barFill != null)
    {
      barFill.scale.x = progress;
    }
  }

  // ============================================================
  // FINALIZAÇÃO
  // ============================================================

  function finishLoading():Void
  {
    if (finished)
    {
      return;
    }

    finished = true;

    setProgress(1);

    /**
     * Recarrega os assets dos mods.
     */
    /**
     * Som opcional.
     */
    if (Paths.soundExists("modsLoaded"))
    {
      FunkinSound.playOnce(Paths.sound("modsLoaded"));
    }

    /**
     * Fade da tela.
     */
    FlxTween.tween(this, {
      alpha: 0
    }, 0.35, {
      ease: FlxEase.cubeInOut,

      onComplete: function(_)
      {
        changeState();
      }
    });
  }

  // ============================================================
  // TROCA DE ESTADO
  // ============================================================

  function changeState():Void
  {
    /**
     * Se foi passado um estado pelo construtor,
     * abre esse estado.
     */
    if (targetState != null)
    {
      FlxG.switchState(targetState);
    }
    /**
     * Caso nenhum estado tenha sido passado,
     * abre o Main Menu por padrão.
     */
    else
    {
      FlxG.switchState(new MainMenuState());
    }
  }

  // ============================================================
  // UPDATE
  // ============================================================

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    /**
     * Faz o throbber girar.
     */
    if (throbber != null)
    {
      throbber.angle += elapsed * 180;
    }
  }
  #end
}
