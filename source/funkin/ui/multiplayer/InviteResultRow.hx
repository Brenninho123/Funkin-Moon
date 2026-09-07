package funkin.ui.multiplayer;

import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.FlxSprite;
import funkin.graphics.FunkinSprite;
import funkin.multiplayer.MultiplayerInviteService.InviteInfo;
import funkin.multiplayer.RemoteImageLoader;

/**
 * Uma linha dentro do InviteSearchSubState: avatar do Discord + nick +
 * botão "CONVIDAR". Vira "ENVIADO" (travado) depois de clicado, pra não
 * mandar o mesmo convite duas vezes.
 *
 * `setSelected()` é o destaque visual usado pela navegação por teclado
 * do InviteSearchSubState (setas cima/baixo entre os resultados).
 */
class InviteResultRow extends FlxSpriteGroup
{
  #if FEATURE_ONLINE
  public var info(default, null):InviteInfo;

  var rowBg:FunkinSprite;
  var avatarSprite:FlxSprite;
  var nickText:FlxText;
  var inviteButton:FlxButton;
  var onInvitePressed:InviteInfo->Void;
  var invited:Bool = false;
  var selected:Bool = false;

  static inline final BG_NORMAL:Int = 0xFF232E45;
  static inline final BG_SELECTED:Int = 0xFF32436B;

  public function new(x:Float, y:Float, width:Float, info:InviteInfo, onInvitePressed:InviteInfo->Void)
  {
    super(x, y);
    this.info = info;
    this.onInvitePressed = onInvitePressed;

    rowBg = new FunkinSprite(0, 0);
    rowBg.makeSolidColor(Std.int(width), 56, BG_NORMAL);
    add(rowBg);

    avatarSprite = new FlxSprite(6, 4);
    avatarSprite.makeGraphic(48, 48, 0xFF4A4A4A); // placeholder até o avatar real carregar
    add(avatarSprite);
    RemoteImageLoader.loadInto(avatarSprite, info.avatarUrl, () ->
    {
      avatarSprite.setGraphicSize(48, 48);
      avatarSprite.updateHitbox();
    });

    nickText = new FlxText(62, 0, width - 62 - 100, info.username, 18);
    nickText.setFormat(Paths.font('vcr.ttf'), 18, 0xFFFFFFFF, LEFT);
    nickText.y = (56 - nickText.height) / 2;
    add(nickText);

    inviteButton = new FlxButton(width - 96, 10, 'CONVIDAR', pressInvite);
    inviteButton.color = 0xFF3B82F6;
    inviteButton.scale.set(0.85, 0.85);
    inviteButton.updateHitbox();
    add(inviteButton);
  }

  /** Destaque visual quando essa linha tá selecionada pelo teclado. */
  public function setSelected(value:Bool):Void
  {
    if (selected == value) return;
    selected = value;

    if (rowBg != null) rowBg.makeSolidColor(Std.int(rowBg.width), Std.int(rowBg.height), selected ? BG_SELECTED : BG_NORMAL);
    scale.set(selected ? 1.02 : 1.0, selected ? 1.02 : 1.0);
  }

  /** Confirma o convite dessa linha (chamado pelo clique OU pelo ENTER do teclado). */
  public function confirm():Void
  {
    pressInvite();
  }

  function pressInvite():Void
  {
    if (invited) return;
    invited = true;

    if (inviteButton != null)
    {
      inviteButton.label.text = 'ENVIADO';
      inviteButton.color = 0xFF4A4A4A;
    }

    if (onInvitePressed != null) onInvitePressed(info);
  }
  #end
}
