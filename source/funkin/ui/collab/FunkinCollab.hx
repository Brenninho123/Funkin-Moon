package funkin.ui.collab;

import haxe.Json;

#if sys
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef CollabMember =
{
  var name:String;
  var roles:Array<String>;
  @:optional var link:String;
}

typedef CollabProject =
{
  var title:String;
  var tagline:String;
  var includeTitle:Bool;
  var showLinks:Bool;
  var memberOrder:String;
  var roleOrder:Array<String>;
  var members:Array<CollabMember>;
}

typedef CollabCreditsLine =
{
  var line:String;
}

typedef CollabCreditsEntry =
{
  var header:String;
  var body:Array<CollabCreditsLine>;
}

typedef CollabCreditsFile =
{
  var entries:Array<CollabCreditsEntry>;
}

enum abstract CollabMemberOrder(String) from String to String
{
  var INSERTION = 'insertion';
  var ALPHABETICAL = 'alphabetical';
}

class FunkinCollab
{
  public static inline final CREDITS_FILE_NAME:String = 'credits.json';

  public static inline final PROJECT_FILE_NAME:String = 'collab.json';

  public static inline final POLYMOD_META_FILE_NAME:String = '_polymod_meta.json';

  public static inline final DEFAULT_AUTHOR_ROLE:String = 'Mod Author';

  public static inline final DEFAULT_CONTRIBUTOR_ROLE:String = 'Contributor';

  static final ROLE_SEPARATORS:EReg = ~/\s*(?:,|\/|&|;|\+)\s*/;

  static final WHITESPACE:EReg = ~/\s+/g;

  public var title:String;

  public var tagline:String;

  public var includeTitle:Bool;

  public var showLinks:Bool;

  public var memberOrder:CollabMemberOrder;

  public var roleOrder:Array<String>;

  public var members(default, null):Array<CollabMember>;

  public function new(title:String = 'Collab', tagline:String = '')
  {
    this.title = title;
    this.tagline = tagline;
    this.includeTitle = true;
    this.showLinks = false;
    this.memberOrder = CollabMemberOrder.INSERTION;
    this.roleOrder = [];
    this.members = [];
  }

  public function addMember(name:String, roles:Array<String>, link:String = ''):FunkinCollab
  {
    var cleanName:String = normalizeText(name);

    if (cleanName.length == 0) return this;

    var cleanRoles:Array<String> = normalizeRoles(roles);
    var cleanLink:String = link.trim();
    var existing:Null<CollabMember> = findMember(cleanName);

    if (existing != null)
    {
      for (role in cleanRoles)
      {
        if (indexOfIgnoreCase(existing.roles, role) == -1) existing.roles.push(role);
      }

      if (existing.link == null && cleanLink.length > 0) existing.link = cleanLink;

      return this;
    }

    var member:CollabMember = {name: cleanName, roles: cleanRoles};

    if (cleanLink.length > 0) member.link = cleanLink;

    members.push(member);

    return this;
  }

  public function addMemberFromText(name:String, roleText:String, link:String = ''):FunkinCollab
  {
    return addMember(name, splitRoles(roleText), link);
  }

  public function removeMember(name:String):Bool
  {
    var member:Null<CollabMember> = findMember(normalizeText(name));

    return member != null && members.remove(member);
  }

  public function findMember(name:String):Null<CollabMember>
  {
    var key:String = name.toLowerCase();

    for (member in members)
    {
      if (member.name.toLowerCase() == key) return member;
    }

    return null;
  }

  public function setRoleOrder(order:Array<String>):FunkinCollab
  {
    roleOrder = normalizeRoles(order);

    return this;
  }

  public function collectRoles():Array<String>
  {
    var roles:Array<String> = [];

    for (member in members)
    {
      for (role in member.roles)
      {
        if (indexOfIgnoreCase(roles, role) == -1) roles.push(role);
      }
    }

    var ordered:Array<String> = [];

    for (preferred in roleOrder)
    {
      var index:Int = indexOfIgnoreCase(roles, preferred);

      if (index != -1)
      {
        ordered.push(roles[index]);
        roles.splice(index, 1);
      }
    }

    return ordered.concat(roles);
  }

  public function validate():Array<String>
  {
    var problems:Array<String> = [];

    if (includeTitle && title.trim().length == 0) problems.push('The collab title is empty.');

    if (members.length == 0) problems.push('The collab has no members.');

    for (member in members)
    {
      if (member.roles.length == 0) problems.push('${member.name} has no roles.');
    }

    return problems;
  }

  public function toCreditsFile():CollabCreditsFile
  {
    var entries:Array<CollabCreditsEntry> = [];

    if (includeTitle && title.trim().length > 0)
    {
      var titleBody:Array<CollabCreditsLine> = [];

      if (tagline.trim().length > 0) titleBody.push({line: tagline.trim()});

      entries.push({header: title.trim(), body: titleBody});
    }

    for (role in collectRoles())
    {
      var body:Array<CollabCreditsLine> = [for (member in membersForRole(role)) {line: formatLine(member)}];

      entries.push({header: role, body: body});
    }

    return {entries: entries};
  }

  public function toCreditsJson(pretty:Bool = true):String
  {
    return Json.stringify(toCreditsFile(), null, pretty ? '  ' : null);
  }

  public function toProject():CollabProject
  {
    return {
      title: title,
      tagline: tagline,
      includeTitle: includeTitle,
      showLinks: showLinks,
      memberOrder: memberOrder,
      roleOrder: roleOrder.copy(),
      members: [for (member in members) cloneMember(member)]
    };
  }

  public function toProjectJson(pretty:Bool = true):String
  {
    return Json.stringify(toProject(), null, pretty ? '  ' : null);
  }

  public static function fromProject(data:Dynamic):FunkinCollab
  {
    var collab:FunkinCollab = new FunkinCollab(read(data, 'title', 'Collab'), read(data, 'tagline', ''));

    collab.includeTitle = read(data, 'includeTitle', true);
    collab.showLinks = read(data, 'showLinks', false);
    collab.memberOrder = read(data, 'memberOrder', 'insertion') == CollabMemberOrder.ALPHABETICAL ? CollabMemberOrder.ALPHABETICAL : CollabMemberOrder.INSERTION;
    collab.setRoleOrder(read(data, 'roleOrder', []));

    var rawMembers:Array<Dynamic> = read(data, 'members', []);

    for (raw in rawMembers)
    {
      var roles:Array<String> = read(raw, 'roles', []);

      collab.addMember(read(raw, 'name', ''), roles, read(raw, 'link', ''));
    }

    return collab;
  }

  public static function fromProjectJson(json:String):FunkinCollab
  {
    return fromProject(Json.parse(json));
  }

  public static function fromPolymodMeta(json:String):FunkinCollab
  {
    var data:Dynamic = Json.parse(json);
    var collab:FunkinCollab = new FunkinCollab(read(data, 'title', 'Collab'));

    var author:String = normalizeText(read(data, 'author', ''));

    if (author.length > 0) collab.addMember(author, [DEFAULT_AUTHOR_ROLE], read(data, 'homepage', ''));

    var contributors:Array<Dynamic> = read(data, 'contributors', []);

    for (contributor in contributors)
    {
      var roles:Array<String> = splitRoles(read(contributor, 'role', ''));

      if (roles.length == 0) roles.push(DEFAULT_CONTRIBUTOR_ROLE);

      collab.addMember(read(contributor, 'name', ''), roles, read(contributor, 'url', ''));
    }

    return collab;
  }

  #if sys
  public static function defaultOutputDirectory(modId:String):String
  {
    return Path.join(['mods', modId, 'data']);
  }

  public static function loadProject(path:String):FunkinCollab
  {
    return fromProjectJson(File.getContent(path));
  }

  public static function loadPolymodMeta(modDirectory:String):FunkinCollab
  {
    var path:String = Path.join([modDirectory, POLYMOD_META_FILE_NAME]);

    if (!FileSystem.exists(path)) throw 'Mod metadata not found: $path';

    return fromPolymodMeta(File.getContent(path));
  }

  public function exportTo(directory:String, writeProject:Bool = true):Array<String>
  {
    var problems:Array<String> = validate();

    if (problems.length > 0) throw problems.join('\n');

    ensureDirectory(directory);

    var written:Array<String> = [];

    var creditsPath:String = Path.join([directory, CREDITS_FILE_NAME]);
    File.saveContent(creditsPath, toCreditsJson());
    written.push(creditsPath);

    if (writeProject)
    {
      var projectPath:String = Path.join([directory, PROJECT_FILE_NAME]);
      File.saveContent(projectPath, toProjectJson());
      written.push(projectPath);
    }

    return written;
  }

  static function ensureDirectory(path:String):Void
  {
    var normalized:String = Path.normalize(path);

    if (normalized == '' || FileSystem.exists(normalized)) return;

    var parent:String = Path.directory(normalized);

    if (parent != '' && parent != normalized) ensureDirectory(parent);

    FileSystem.createDirectory(normalized);
  }
  #end

  function membersForRole(role:String):Array<CollabMember>
  {
    var result:Array<CollabMember> = members.filter(function(member:CollabMember):Bool return indexOfIgnoreCase(member.roles, role) != -1);

    if (memberOrder == CollabMemberOrder.ALPHABETICAL)
    {
      result.sort(function(a:CollabMember, b:CollabMember):Int return Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase()));
    }

    return result;
  }

  function formatLine(member:CollabMember):String
  {
    return showLinks && member.link != null ? '${member.name} - ${member.link}' : member.name;
  }

  static function cloneMember(member:CollabMember):CollabMember
  {
    var copy:CollabMember = {name: member.name, roles: member.roles.copy()};

    if (member.link != null) copy.link = member.link;

    return copy;
  }

  static function splitRoles(text:String):Array<String>
  {
    return normalizeRoles(ROLE_SEPARATORS.split(text));
  }

  static function normalizeText(text:String):String
  {
    return WHITESPACE.replace(text.trim(), ' ');
  }

  static function normalizeRoles(roles:Array<String>):Array<String>
  {
    var result:Array<String> = [];

    for (role in roles)
    {
      var clean:String = normalizeText(role);

      if (clean.length > 0 && indexOfIgnoreCase(result, clean) == -1) result.push(clean);
    }

    return result;
  }

  static function indexOfIgnoreCase(list:Array<String>, value:String):Int
  {
    var key:String = value.toLowerCase();

    for (i in 0...list.length)
    {
      if (list[i].toLowerCase() == key) return i;
    }

    return -1;
  }

  static function read<T>(data:Dynamic, name:String, fallback:T):T
  {
    if (data == null || !Reflect.hasField(data, name)) return fallback;

    var value:Null<Dynamic> = Reflect.field(data, name);

    return value == null ? fallback : cast value;
  }
}
