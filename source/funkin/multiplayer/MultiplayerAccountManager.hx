package funkin.multiplayer;

import haxe.Json;
import sys.io.File;
import sys.FileSystem;
#if FEATURE_ONLINE
import funkin.api.discord.auth.DiscordAuthServer;
import funkin.api.discord.auth.DiscordAuthServer.DiscordProfile;
#end

/**
 * Gerencia contas locais de multiplayer: criação, login e vínculo com Discord.
 *
 * Persistência: um único JSON (accounts.json) na pasta de trabalho do jogo,
 * com a lista de todas as contas já criadas nessa máquina.
 *
 * Métodos públicos usados no resto do projeto (LoginState, LoginSubState,
 * OnlineMenuState):
 *   - getOrCreateAccount(username)
 *   - createAccount(username)
 *   - login(username, password)
 *   - linkDiscordAccount(account, profile)
 *   - isDiscordLinked(account)
 */
#if FEATURE_ONLINE
class MultiplayerAccountManager
{
  static final SAVE_PATH:String = 'accounts.json';
  static var _cache:Null<Array<Dynamic>> = null;

  // ---------------------------------------------------------------------
  // API pública
  // ---------------------------------------------------------------------

  /**
   * Devolve a conta com esse username se já existir; senão cria uma nova
   * (sem senha) e devolve. Usado pro autologin (LoginState.autoLogin,
   * OnlineMenuState.create).
   */
  public static function getOrCreateAccount(username:String):Dynamic
  {
    var accounts:Array<Dynamic> = loadAccounts();
    var found:Dynamic = findByUsername(accounts, username);
    if (found != null) return found;

    return createAccount(username);
  }

  /**
   * Cria uma conta nova com esse username (sem senha, id gerado) e salva.
   * Se já existir uma conta com esse username, ela é sobrescrita por uma
   * nova (mesmo comportamento que criar do zero, já que quem chama isso
   * é a tela de "CRIAR CONTA").
   */
  public static function createAccount(username:String):Dynamic
  {
    var accounts:Array<Dynamic> = loadAccounts();

    // remove conta antiga com o mesmo nome, se tiver, pra não duplicar
    accounts = accounts.filter((acc) -> Std.string(Reflect.field(acc, 'username')) != username);

    var account:Dynamic = {
      id: generateId(),
      username: username,
      password: null,
      discordId: null,
      discordUsername: null,
      discordAvatarUrl: null
    };

    accounts.push(account);
    saveAccounts(accounts);

    return account;
  }

  /**
   * Tenta logar com username + senha. Devolve a conta se bater, ou null
   * se não existir conta com esse username ou a senha não bater.
   *
   * Contas criadas via createAccount() não têm senha (null) — nesse caso
   * qualquer senha vazia '' é aceita como válida, pra não travar o fluxo
   * de autologin/criação rápida que o LoginState usa hoje.
   */
  public static function login(username:String, password:String):Null<Dynamic>
  {
    var accounts:Array<Dynamic> = loadAccounts();
    var account:Dynamic = findByUsername(accounts, username);
    if (account == null) return null;

    var storedPassword:Null<String> = Reflect.field(account, 'password');
    if (storedPassword == null || storedPassword == '')
    {
      // conta sem senha definida: aceita login direto
      return account;
    }

    return (storedPassword == password) ? account : null;
  }

  /**
   * Vincula um perfil do Discord a uma conta local e salva.
   */
  public static function linkDiscordAccount(account:Dynamic, profile:DiscordProfile):Void
  {
    if (account == null || profile == null) return;

    Reflect.setField(account, 'discordId', profile.id);
    Reflect.setField(account, 'discordUsername', profile.username);
    Reflect.setField(account, 'discordAvatarUrl', profile.avatarUrl);

    var accounts:Array<Dynamic> = loadAccounts();
    var existing:Dynamic = findByUsername(accounts, Std.string(Reflect.field(account, 'username')));
    if (existing != null)
    {
      accounts = accounts.filter((acc) -> acc != existing);
    }
    accounts.push(account);
    saveAccounts(accounts);
  }

  /**
   * Diz se essa conta já tem um Discord vinculado.
   */
  public static function isDiscordLinked(account:Dynamic):Bool
  {
    return account != null && Reflect.hasField(account, 'discordId') && Reflect.field(account, 'discordId') != null;
  }

  // ---------------------------------------------------------------------
  // Persistência
  // ---------------------------------------------------------------------

  static function loadAccounts():Array<Dynamic>
  {
    if (_cache != null) return _cache;

    if (!FileSystem.exists(SAVE_PATH))
    {
      _cache = [];
      return _cache;
    }

    try
    {
      var raw:String = File.getContent(SAVE_PATH);
      var parsed:Array<Dynamic> = Json.parse(raw);
      _cache = (parsed != null) ? parsed : [];
    }
    catch (e:Dynamic)
    {
      trace('[MultiplayerAccountManager] falha ao ler $SAVE_PATH, começando do zero: ' + e);
      _cache = [];
    }

    return _cache;
  }

  static function saveAccounts(accounts:Array<Dynamic>):Void
  {
    _cache = accounts;
    try
    {
      File.saveContent(SAVE_PATH, Json.stringify(accounts));
    }
    catch (e:Dynamic)
    {
      trace('[MultiplayerAccountManager] falha ao salvar $SAVE_PATH: ' + e);
    }
  }

  static function findByUsername(accounts:Array<Dynamic>, username:String):Null<Dynamic>
  {
    for (acc in accounts)
    {
      if (Std.string(Reflect.field(acc, 'username')) == username) return acc;
    }
    return null;
  }

  static function generateId():String
  {
    return Std.string(Date.now().getTime()) + '_' + Std.string(Std.int(Math.random() * 100000));
  }
}
#end