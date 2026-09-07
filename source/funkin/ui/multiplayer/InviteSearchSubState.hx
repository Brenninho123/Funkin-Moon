package funkin.ui.multiplayer;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.group.FlxGroup.FlxTypedGroup;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatSubState;
import funkin.multiplayer.MultiplayerInviteService;
import funkin.multiplayer.MultiplayerInviteService.InviteInfo;

/**
 * Card de busca por nick do Discord. Abre por cima do HostMenuSubState
 * quando o host clica em CONVIDAR. Digita o nick, aperta ENTER (ou
 * BUSCAR), e cada resultado vira uma InviteResultRow com botão CONVIDAR.
 *
 * Entrada de texto 100% por teclado (onKeyDown), SEM depender de
 * onTextInput/IME — isso é de propósito: onTextInput não tava
 * disparando de forma confiável nesse setup, então a digitação inteira
 * (letras, números, espaço, ponto, hífen/underscore) é mapeada direto
 * de lime.ui.KeyCode. Discord só usa nick em minúsculo, então toda
 * letra já entra em minúsculo, não precisa de SHIFT pra maiúscula.
 *
 * Navegação por teclado:
 *   - Digitar qualquer caractere sempre volta o foco pro campo de busca.
 *   - SETA BAIXO/CIMA: quando tem resultados na tela, navega entre eles
 *     (a primeira vez que aperta BAIXO sai do campo de busca e entra na
 *     lista; CIMA no primeiro item volta pro campo de busca).
 *   - ENTER: se tiver um resultado selecionado, manda convite pra ele;
 *     senão, dispara a busca (igual apertar BUSCAR).
 *   - BACKSPACE: apaga o último caractere digitado.
 *   - ESC: fecha o card.
 */
class InviteSearchSubState extends MusicBeatSubState
{
  #if FEATURE_ONLINE
  var hostServerId:String;
  var hostAddress:String;
  var hostPort:Int;
  var dim:Null<FunkinSprite> = null;
  var cardBg:Null<FunkinSprite> = null;
  var titleText:Null<FlxText> = null;
  var searchInputBg:Null<FunkinSprite> = null;
  var searchInputText:Null<FlxText> = null;
  var searchButton:Null<FlxButton> = null;
  var closeButton:Null<FlxButton> = null;
  var emptyText:Null<FlxText> = null;
  var resultsGroup:FlxTypedGroup<InviteResultRow> = new FlxTypedGroup();
  final cardW:Int = 520;
  final cardH:Int = 420;
  var typedQuery:String = '';
  // -1 = foco no campo de busca; 0+ = índice do resultado selecionado.
  var selectedResultIndex:Int = -1;

  public function new(hostServerId:String, hostAddress:String, hostPort:Int)
  {
    super();
    this.hostServerId = hostServerId;
    this.hostAddress = hostAddress;
    this.hostPort = hostPort;
  }

  override function create():Void
  {
    super.create();

    final cardX:Float = (FlxG.width - cardW) / 2;
    final cardY:Float = (FlxG.height - cardH) / 2;

    dim = new FunkinSprite(0, 0);
    dim.makeSolidColor(FlxG.width, FlxG.height, 0x99000000);
    add(dim);

    cardBg = new FunkinSprite(cardX, cardY);
    cardBg.makeSolidColor(cardW, cardH, 0xFF1B2436);
    add(cardBg);

    titleText = new FlxText(cardX, cardY + 16, cardW, 'CONVIDAR PELO DISCORD', 24);
    titleText.setFormat(Paths.font('vcr.ttf'), 24, 0xFFFFFFFF, CENTER);
    add(titleText);

    searchInputBg = new FunkinSprite(cardX + 20, cardY + 58);
    searchInputBg.makeSolidColor(cardW - 140, 40, 0xFF0F1622);
    add(searchInputBg);

    searchInputText = new FlxText(cardX + 28, cardY + 68, cardW - 156, 'Digite o nick do Discord...', 18);
    searchInputText.setFormat(Paths.font('vcr.ttf'), 18, 0xFF8B93A8, LEFT);
    add(searchInputText);

    // Captura teclado enquanto esse card tá aberto.
    FlxG.stage.window.onKeyDown.add(onKeyDown);

    searchButton = new FlxButton(cardX + cardW - 108, cardY + 56, 'BUSCAR', onSearchPressed);
    searchButton.color = 0xFF3B82F6;
    add(searchButton);

    emptyText = new FlxText(cardX, cardY + 120, cardW, 'Digite um nick e aperte ENTER.', 16);
    emptyText.setFormat(Paths.font('vcr.ttf'), 16, 0xFF8B93A8, CENTER);
    add(emptyText);

    add(resultsGroup);

    closeButton = new FlxButton(cardX + cardW - 40, cardY + 10, 'X', onClosePressed);
    closeButton.color = 0xFF8B8B8B;
    add(closeButton);

    MultiplayerInviteService.instance.connect();
  }

  // ---------------------------------------------------------------
  // Teclado
  // ---------------------------------------------------------------

  function onKeyDown(key:lime.ui.KeyCode, modifier:lime.ui.KeyModifier):Void
  {
    if (key == lime.ui.KeyCode.ESCAPE)
    {
      onClosePressed();
      return;
    }

    if (key == lime.ui.KeyCode.DOWN)
    {
      moveSelection(1);
      return;
    }

    if (key == lime.ui.KeyCode.UP)
    {
      moveSelection(-1);
      return;
    }

    if (key == lime.ui.KeyCode.RETURN || key == lime.ui.KeyCode.NUMPAD_ENTER)
    {
      if (selectedResultIndex >= 0)
      {
        confirmSelectedResult();
      }
      else
      {
        onSearchPressed();
      }
      return;
    }

    if (key == lime.ui.KeyCode.BACKSPACE)
    {
      if (typedQuery.length > 0)
      {
        typedQuery = typedQuery.substring(0, typedQuery.length - 1);
        refreshInputLabel();
      }
      return;
    }

    var char:Null<String> = keyCodeToChar(key, modifier.shiftKey);
    if (char != null)
    {
      // Digitar sempre volta o foco pro campo de busca, saindo da
      // navegação entre resultados se estiver nela.
      if (selectedResultIndex >= 0) setSelectedResult(-1);
      typedQuery += char;
      refreshInputLabel();
    }
  }

  /**
   * Traduz uma tecla física pra caractere digitável. Cobre letras (só
   * minúsculo — nick do Discord não usa maiúscula), números, espaço,
   * ponto e hífen/underscore. Setas/ENTER/ESC/BACKSPACE são tratadas
   * antes de chegar aqui.
   */
  function keyCodeToChar(key:lime.ui.KeyCode, shift:Bool):Null<String>
  {
    var code:Int = key;

    if (code >= lime.ui.KeyCode.A && code <= lime.ui.KeyCode.Z)
    {
      return String.fromCharCode('a'.code + (code - lime.ui.KeyCode.A));
    }

    if (code >= lime.ui.KeyCode.NUMBER_0 && code <= lime.ui.KeyCode.NUMBER_9)
    {
      return String.fromCharCode('0'.code + (code - lime.ui.KeyCode.NUMBER_0));
    }

    if (key == lime.ui.KeyCode.SPACE) return ' ';
    if (key == lime.ui.KeyCode.PERIOD) return '.';
    if (key == lime.ui.KeyCode.MINUS) return shift ? '_' : '-';

    return null;
  }

  function moveSelection(dir:Int):Void
  {
    if (resultsGroup.length == 0) return;

    var newIndex:Int = selectedResultIndex + dir;
    if (newIndex < -1) newIndex = -1;
    if (newIndex >= resultsGroup.length) newIndex = resultsGroup.length - 1;
    setSelectedResult(newIndex);
  }

  function setSelectedResult(index:Int):Void
  {
    var members:Array<InviteResultRow> = resultsGroup.members;

    if (selectedResultIndex >= 0 && selectedResultIndex < members.length && members[selectedResultIndex] != null)
    {
      members[selectedResultIndex].setSelected(false);
    }

    selectedResultIndex = index;

    if (selectedResultIndex >= 0 && selectedResultIndex < members.length && members[selectedResultIndex] != null)
    {
      members[selectedResultIndex].setSelected(true);
    }
  }

  function confirmSelectedResult():Void
  {
    var members:Array<InviteResultRow> = resultsGroup.members;
    if (selectedResultIndex < 0 || selectedResultIndex >= members.length) return;
    if (members[selectedResultIndex] != null) members[selectedResultIndex].confirm();
  }

  // ---------------------------------------------------------------
  // Busca / resultados
  // ---------------------------------------------------------------

  function refreshInputLabel():Void
  {
    if (searchInputText == null) return;
    if (typedQuery.length == 0)
    {
      searchInputText.text = 'Digite o nick do Discord...';
      searchInputText.color = 0xFF8B93A8;
    }
    else
    {
      searchInputText.text = typedQuery;
      searchInputText.color = 0xFFFFFFFF;
    }
  }

  function onSearchPressed():Void
  {
    if (typedQuery.length == 0) return;

    if (emptyText != null) emptyText.text = 'Buscando...';
    clearResults();

    MultiplayerInviteService.instance.searchByNick(typedQuery, onSearchResults);
  }

  function onSearchResults(results:Array<InviteInfo>):Void
  {
    clearResults();

    if (results == null || results.length == 0)
    {
      if (emptyText != null)
      {
        emptyText.text = 'Ninguém encontrado com esse nick.';
      }
      return;
    }

    if (emptyText != null) emptyText.text = '';

    final cardX:Float = (FlxG.width - cardW) / 2;
    final cardY:Float = (FlxG.height - cardH) / 2;
    var rowY:Float = cardY + 120;

    for (result in results)
    {
      var row:InviteResultRow = new InviteResultRow(cardX + 20, rowY, cardW - 40, result, onInvitePressed);
      resultsGroup.add(row);
      rowY += 62;
    }
  }

  function onInvitePressed(target:InviteInfo):Void
  {
    MultiplayerInviteService.instance.sendInvite(target, hostServerId, hostAddress, hostPort, () ->
    {
      trace('[Invite] convite enviado pra ' + target.username);
    }, (err) ->
      {
        trace('[Invite] falha ao convidar: ' + err);
      });
  }

  function clearResults():Void
  {
    selectedResultIndex = -1;
    resultsGroup.forEachAlive((row) -> row.destroy());
    resultsGroup.clear();
  }

  function onClosePressed():Void
  {
    close();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
  }

  override function destroy():Void
  {
    FlxG.stage.window.onKeyDown.remove(onKeyDown);
    super.destroy();
  }
  #end
}
