package funkin.ui.scripting;

enum MoonTokenType
{
  LeftParen;
  RightParen;
  LeftBrace;
  RightBrace;
  LeftBracket;
  RightBracket;
  Comma;
  Dot;
  Semicolon;
  Colon;
  Plus;
  Minus;
  Star;
  Slash;
  Percent;
  PlusEqual;
  MinusEqual;
  StarEqual;
  SlashEqual;
  PlusPlus;
  MinusMinus;
  Bang;
  BangEqual;
  Equal;
  EqualEqual;
  Greater;
  GreaterEqual;
  Less;
  LessEqual;
  AndAnd;
  OrOr;
  Identifier;
  StringLit;
  NumberLit;
  Var;
  Let;
  Function;
  Class;
  Extends;
  If;
  Else;
  While;
  For;
  Return;
  Break;
  Continue;
  True;
  False;
  Null;
  This;
  New;
  Public;
  Private;
  Static;
  Import;
  Eof;
}

class MoonToken
{
  public var type:MoonTokenType;
  public var lexeme:String;
  public var literal:Dynamic;
  public var line:Int;

  public function new(type:MoonTokenType, lexeme:String, literal:Dynamic, line:Int)
  {
    this.type = type;
    this.lexeme = lexeme;
    this.literal = literal;
    this.line = line;
  }
}

class MoonLexer
{
  static var keywords:Map<String, MoonTokenType> = [
    'var' => Var, 'let' => Let, 'function' => Function, 'class' => Class,
    'extends' => Extends, 'if' => If, 'else' => Else, 'while' => While,
    'for' => For, 'return' => Return, 'break' => Break, 'continue' => Continue,
    'true' => True, 'false' => False, 'null' => Null, 'this' => This,
    'new' => New, 'public' => Public, 'private' => Private, 'static' => Static,
    'import' => Import
  ];

  var source:String;
  var tokens:Array<MoonToken> = [];
  var start:Int = 0;
  var current:Int = 0;
  var line:Int = 1;

  public function new(source:String)
  {
    this.source = source;
  }

  public function scanTokens():Array<MoonToken>
  {
    while (!isAtEnd())
    {
      start = current;
      scanToken();
    }
    tokens.push(new MoonToken(Eof, '', null, line));
    return tokens;
  }

  function isAtEnd():Bool
  {
    return current >= source.length;
  }

  function advance():String
  {
    var c = source.charAt(current);
    current++;
    return c;
  }

  function peek():String
  {
    return isAtEnd() ? '\0' : source.charAt(current);
  }

  function peekNext():String
  {
    return current + 1 >= source.length ? '\0' : source.charAt(current + 1);
  }

  function match(expected:String):Bool
  {
    if (isAtEnd() || source.charAt(current) != expected) return false;
    current++;
    return true;
  }

  function addToken(type:MoonTokenType, ?literal:Dynamic):Void
  {
    var text = source.substring(start, current);
    tokens.push(new MoonToken(type, text, literal, line));
  }

  function scanToken():Void
  {
    var c = advance();
    switch (c)
    {
      case '(': addToken(LeftParen);
      case ')': addToken(RightParen);
      case '{': addToken(LeftBrace);
      case '}': addToken(RightBrace);
      case '[': addToken(LeftBracket);
      case ']': addToken(RightBracket);
      case ',': addToken(Comma);
      case '.': addToken(Dot);
      case ';': addToken(Semicolon);
      case ':': addToken(Colon);
      case '+':
        if (match('+')) addToken(PlusPlus)
        else if (match('=')) addToken(PlusEqual)
        else addToken(Plus);
      case '-':
        if (match('-')) addToken(MinusMinus)
        else if (match('=')) addToken(MinusEqual)
        else addToken(Minus);
      case '*':
        if (match('=')) addToken(StarEqual) else addToken(Star);
      case '%':
        addToken(Percent);
      case '/':
        if (match('/'))
        {
          while (peek() != '\n' && !isAtEnd()) advance();
        }
        else if (match('*'))
        {
          while (!(peek() == '*' && peekNext() == '/') && !isAtEnd())
          {
            if (peek() == '\n') line++;
            advance();
          }
          if (!isAtEnd())
          {
            advance();
            advance();
          }
        }
        else if (match('=')) addToken(SlashEqual)
        else addToken(Slash);
      case '!':
        addToken(match('=') ? BangEqual : Bang);
      case '=':
        addToken(match('=') ? EqualEqual : Equal);
      case '<':
        addToken(match('=') ? LessEqual : Less);
      case '>':
        addToken(match('=') ? GreaterEqual : Greater);
      case '&':
        if (match('&')) addToken(AndAnd);
      case '|':
        if (match('|')) addToken(OrOr);
      case ' ', '\r', '\t':
      case '\n':
        line++;
      case '"':
        scanString();
      default:
        if (isDigit(c)) scanNumber()
        else if (isAlpha(c)) scanIdentifier()
        else throw new MoonRuntimeError('[line $line] Unexpected character "$c".');
    }
  }

  function scanString():Void
  {
    var buffer = new StringBuf();
    while (peek() != '"' && !isAtEnd())
    {
      if (peek() == '\n') line++;
      if (peek() == '\\')
      {
        advance();
        var esc = advance();
        buffer.add(switch (esc)
        {
          case 'n': '\n';
          case 't': '\t';
          case '"': '"';
          case '\\': '\\';
          default: esc;
        });
      }
      else
      {
        buffer.add(advance());
      }
    }
    if (isAtEnd()) throw new MoonRuntimeError('[line $line] Unterminated string.');
    advance();
    addToken(StringLit, buffer.toString());
  }

  function scanNumber():Void
  {
    while (isDigit(peek())) advance();
    if (peek() == '.' && isDigit(peekNext()))
    {
      advance();
      while (isDigit(peek())) advance();
    }
    addToken(NumberLit, Std.parseFloat(source.substring(start, current)));
  }

  function scanIdentifier():Void
  {
    while (isAlphaNumeric(peek())) advance();
    var text = source.substring(start, current);
    var type = keywords.exists(text) ? keywords.get(text) : Identifier;
    addToken(type);
  }

  function isDigit(c:String):Bool
  {
    return c >= '0' && c <= '9';
  }

  function isAlpha(c:String):Bool
  {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
  }

  function isAlphaNumeric(c:String):Bool
  {
    return isAlpha(c) || isDigit(c);
  }
}

typedef MoonParam =
{
  var name:String;
  var ?type:String;
  var ?defaultValue:MoonExpr;
}

enum MoonExpr
{
  Literal(value:Dynamic);
  Grouping(expr:MoonExpr);
  Variable(name:String);
  This;
  Assign(name:String, value:MoonExpr);
  Unary(op:MoonTokenType, right:MoonExpr);
  Logical(left:MoonExpr, op:MoonTokenType, right:MoonExpr);
  Binary(left:MoonExpr, op:MoonTokenType, right:MoonExpr);
  ArrayLiteral(items:Array<MoonExpr>);
  Index(obj:MoonExpr, index:MoonExpr);
  IndexSet(obj:MoonExpr, index:MoonExpr, value:MoonExpr);
  Get(obj:MoonExpr, name:String);
  Set(obj:MoonExpr, name:String, value:MoonExpr);
  New(className:String, args:Array<MoonExpr>);
  Call(callee:MoonExpr, args:Array<MoonExpr>);
}

enum MoonStmt
{
  ExprStmt(expr:MoonExpr);
  VarStmt(name:String, type:Null<String>, init:Null<MoonExpr>);
  FunctionStmt(name:String, params:Array<MoonParam>, body:Array<MoonStmt>);
  ClassStmt(name:String, superclass:Null<String>, methods:Array<MoonStmt>, fields:Array<MoonStmt>);
  IfStmt(cond:MoonExpr, thenBranch:MoonStmt, elseBranch:Null<MoonStmt>);
  WhileStmt(cond:MoonExpr, body:MoonStmt);
  ForStmt(init:Null<MoonStmt>, cond:Null<MoonExpr>, increment:Null<MoonExpr>, body:MoonStmt);
  ReturnStmt(value:Null<MoonExpr>);
  BreakStmt;
  ContinueStmt;
  BlockStmt(statements:Array<MoonStmt>);
}

class MoonRuntimeError extends haxe.Exception {}

class MoonReturnSignal extends haxe.Exception
{
  public var value:Dynamic;

  public function new(value:Dynamic)
  {
    super('return');
    this.value = value;
  }
}

class MoonBreakSignal extends haxe.Exception
{
  public function new()
  {
    super('break');
  }
}

class MoonContinueSignal extends haxe.Exception
{
  public function new()
  {
    super('continue');
  }
}

class MoonEnvironment
{
  var values:Map<String, Dynamic> = new Map();
  var enclosing:MoonEnvironment;

  public function new(?enclosing:MoonEnvironment)
  {
    this.enclosing = enclosing;
  }

  public function define(name:String, value:Dynamic):Void
  {
    values.set(name, value);
  }

  public function get(name:String):Dynamic
  {
    if (values.exists(name)) return values.get(name);
    if (enclosing != null) return enclosing.get(name);
    throw new MoonRuntimeError('Undefined variable "$name".');
  }

  public function assign(name:String, value:Dynamic):Void
  {
    if (values.exists(name))
    {
      values.set(name, value);
      return;
    }
    if (enclosing != null)
    {
      enclosing.assign(name, value);
      return;
    }
    throw new MoonRuntimeError('Undefined variable "$name".');
  }
}

class MoonFunction
{
  var declaration:MoonStmt;
  var closure:MoonEnvironment;
  var boundInstance:MoonInstance;

  public function new(declaration:MoonStmt, closure:MoonEnvironment, ?boundInstance:MoonInstance)
  {
    this.declaration = declaration;
    this.closure = closure;
    this.boundInstance = boundInstance;
  }

  public function bind(instance:MoonInstance):MoonFunction
  {
    return new MoonFunction(declaration, closure, instance);
  }

  public function arity():Int
  {
    return switch (declaration)
    {
      case FunctionStmt(_, params, _): params.length;
      default: 0;
    }
  }

  public function call(interpreter:MoonInterpreter, args:Array<Dynamic>):Dynamic
  {
    return switch (declaration)
    {
      case FunctionStmt(_, params, body):
        var env = new MoonEnvironment(closure);
        if (boundInstance != null) env.define('this', boundInstance);
        for (i in 0...params.length)
        {
          var value:Dynamic = i < args.length ? args[i] :
            (params[i].defaultValue != null ? interpreter.evaluate(params[i].defaultValue) : null);
          env.define(params[i].name, value);
        }
        try
        {
          interpreter.executeBlock(body, env);
          null;
        }
        catch (r:MoonReturnSignal)
        {
          r.value;
        }
      default: null;
    }
  }
}

class MoonNativeFunction
{
  public var name:String;
  var fn:Array<Dynamic>->Dynamic;

  public function new(name:String, fn:Array<Dynamic>->Dynamic)
  {
    this.name = name;
    this.fn = fn;
  }

  public function call(args:Array<Dynamic>):Dynamic
  {
    return fn(args);
  }
}

class MoonClass
{
  public var name:String;
  public var superclass:MoonClass;

  var methods:Map<String, MoonFunction>;
  var staticFields:Map<String, Dynamic> = new Map();

  public function new(name:String, superclass:MoonClass, methods:Map<String, MoonFunction>)
  {
    this.name = name;
    this.superclass = superclass;
    this.methods = methods;
  }

  public function findMethod(name:String):MoonFunction
  {
    if (methods.exists(name)) return methods.get(name);
    if (superclass != null) return superclass.findMethod(name);
    return null;
  }

  public function arity():Int
  {
    var initializer = findMethod('new');
    return initializer == null ? 0 : initializer.arity();
  }

  public function instantiate(interpreter:MoonInterpreter, args:Array<Dynamic>):MoonInstance
  {
    var instance = new MoonInstance(this);
    var initializer = findMethod('new');
    if (initializer != null) initializer.bind(instance).call(interpreter, args);
    return instance;
  }

  public function getStatic(name:String):Dynamic
  {
    if (staticFields.exists(name)) return staticFields.get(name);
    var method = findMethod(name);
    if (method != null) return method;
    if (superclass != null) return superclass.getStatic(name);
    throw new MoonRuntimeError('"$name" is not defined on class "$name".');
  }

  public function setStatic(name:String, value:Dynamic):Void
  {
    staticFields.set(name, value);
  }
}

class MoonInstance
{
  public var klass:MoonClass;

  var fields:Map<String, Dynamic> = new Map();

  public function new(klass:MoonClass)
  {
    this.klass = klass;
  }

  public function get(name:String):Dynamic
  {
    if (fields.exists(name)) return fields.get(name);
    var method = klass.findMethod(name);
    if (method != null) return method.bind(this);
    throw new MoonRuntimeError('Undefined property "$name" on "${klass.name}".');
  }

  public function set(name:String, value:Dynamic):Void
  {
    fields.set(name, value);
  }

  public function toString():String
  {
    return '${klass.name} instance';
  }
}

class MoonParser
{
  var tokens:Array<MoonToken>;
  var current:Int = 0;

  public function new(tokens:Array<MoonToken>)
  {
    this.tokens = tokens;
  }

  public function parseProgram():Array<MoonStmt>
  {
    var statements = [];
    while (!isAtEnd()) statements.push(declaration());
    return statements;
  }

  function declaration():MoonStmt
  {
    if (match([Import]))
    {
      skipImport();
      return declaration();
    }
    if (match([Class])) return classDeclaration();
    if (match([Function])) return functionBody();
    if (match([Var]) || match([Let])) return varDeclaration();
    return statement();
  }

  function skipImport():Void
  {
    while (!check(Semicolon) && !isAtEnd()) advance();
    match([Semicolon]);
  }

  function classDeclaration():MoonStmt
  {
    var name = consume(Identifier, 'Expect class name.').lexeme;
    var superclass:String = null;
    if (match([Extends])) superclass = consume(Identifier, 'Expect superclass name.').lexeme;
    consume(LeftBrace, 'Expect "{" before class body.');

    var methods:Array<MoonStmt> = [];
    var fields:Array<MoonStmt> = [];

    while (!check(RightBrace) && !isAtEnd())
    {
      while (match([Public]) || match([Private]) || match([Static])) {}

      if (match([Function]))
      {
        methods.push(functionBody());
      }
      else
      {
        match([Var]);
        match([Let]);
        var field = varDeclarationBody();
        match([Semicolon]);
        fields.push(field);
      }
    }

    consume(RightBrace, 'Expect "}" after class body.');
    return ClassStmt(name, superclass, methods, fields);
  }

  function functionBody():MoonStmt
  {
    var name = consume(Identifier, 'Expect function name.').lexeme;
    consume(LeftParen, 'Expect "(" after function name.');

    var params:Array<MoonParam> = [];
    if (!check(RightParen))
    {
      do
      {
        var paramName = consume(Identifier, 'Expect parameter name.').lexeme;
        var paramType:String = null;
        if (match([Colon])) paramType = consume(Identifier, 'Expect type name.').lexeme;
        var paramDefault:MoonExpr = null;
        if (match([Equal])) paramDefault = expression();
        params.push({name: paramName, type: paramType, defaultValue: paramDefault});
      }
      while (match([Comma]));
    }
    consume(RightParen, 'Expect ")" after parameters.');

    if (match([Colon])) consume(Identifier, 'Expect return type.');

    consume(LeftBrace, 'Expect "{" before function body.');
    var body = block();
    return FunctionStmt(name, params, body);
  }

  function varDeclaration():MoonStmt
  {
    var stmt = varDeclarationBody();
    consume(Semicolon, 'Expect ";" after variable declaration.');
    return stmt;
  }

  function varDeclarationBody():MoonStmt
  {
    var name = consume(Identifier, 'Expect variable name.').lexeme;
    var type:String = null;
    if (match([Colon])) type = consume(Identifier, 'Expect type name.').lexeme;
    var init:MoonExpr = null;
    if (match([Equal])) init = expression();
    return VarStmt(name, type, init);
  }

  function statement():MoonStmt
  {
    if (match([If])) return ifStatement();
    if (match([While])) return whileStatement();
    if (match([For])) return forStatement();
    if (match([Return])) return returnStatement();
    if (match([Break]))
    {
      consume(Semicolon, 'Expect ";" after break.');
      return BreakStmt;
    }
    if (match([Continue]))
    {
      consume(Semicolon, 'Expect ";" after continue.');
      return ContinueStmt;
    }
    if (match([LeftBrace])) return BlockStmt(block());
    return expressionStatement();
  }

  function ifStatement():MoonStmt
  {
    consume(LeftParen, 'Expect "(" after if.');
    var cond = expression();
    consume(RightParen, 'Expect ")" after condition.');
    var thenBranch = statement();
    var elseBranch:MoonStmt = null;
    if (match([Else])) elseBranch = statement();
    return IfStmt(cond, thenBranch, elseBranch);
  }

  function whileStatement():MoonStmt
  {
    consume(LeftParen, 'Expect "(" after while.');
    var cond = expression();
    consume(RightParen, 'Expect ")" after condition.');
    var body = statement();
    return WhileStmt(cond, body);
  }

  function forStatement():MoonStmt
  {
    consume(LeftParen, 'Expect "(" after for.');

    var init:MoonStmt = null;
    if (match([Semicolon])) {}
    else if (match([Var]) || match([Let])) init = varDeclaration();
    else init = expressionStatement();

    var cond:MoonExpr = check(Semicolon) ? null : expression();
    consume(Semicolon, 'Expect ";" after loop condition.');

    var increment:MoonExpr = check(RightParen) ? null : expression();
    consume(RightParen, 'Expect ")" after for clauses.');

    var body = statement();
    return ForStmt(init, cond, increment, body);
  }

  function returnStatement():MoonStmt
  {
    var value:MoonExpr = check(Semicolon) ? null : expression();
    consume(Semicolon, 'Expect ";" after return value.');
    return ReturnStmt(value);
  }

  function block():Array<MoonStmt>
  {
    var statements = [];
    while (!check(RightBrace) && !isAtEnd()) statements.push(declaration());
    consume(RightBrace, 'Expect "}" after block.');
    return statements;
  }

  function expressionStatement():MoonStmt
  {
    var expr = expression();
    consume(Semicolon, 'Expect ";" after expression.');
    return ExprStmt(expr);
  }

  function expression():MoonExpr
  {
    return assignment();
  }

  function assignment():MoonExpr
  {
    var expr = orExpr();

    if (match([Equal, PlusEqual, MinusEqual, StarEqual, SlashEqual]))
    {
      var opType = previous().type;
      var value = assignment();

      var desugared:MoonExpr = switch (opType)
      {
        case Equal: value;
        case PlusEqual: Binary(expr, Plus, value);
        case MinusEqual: Binary(expr, Minus, value);
        case StarEqual: Binary(expr, Star, value);
        case SlashEqual: Binary(expr, Slash, value);
        default: value;
      }

      return switch (expr)
      {
        case Variable(name): Assign(name, desugared);
        case Get(obj, name): Set(obj, name, desugared);
        case Index(obj, idx): IndexSet(obj, idx, desugared);
        default: throw error(previous(), 'Invalid assignment target.');
      }
    }

    return expr;
  }

  function orExpr():MoonExpr
  {
    var expr = andExpr();
    while (match([OrOr]))
    {
      var right = andExpr();
      expr = Logical(expr, OrOr, right);
    }
    return expr;
  }

  function andExpr():MoonExpr
  {
    var expr = equality();
    while (match([AndAnd]))
    {
      var right = equality();
      expr = Logical(expr, AndAnd, right);
    }
    return expr;
  }

  function equality():MoonExpr
  {
    var expr = comparison();
    while (match([BangEqual, EqualEqual]))
    {
      var op = previous().type;
      var right = comparison();
      expr = Binary(expr, op, right);
    }
    return expr;
  }

  function comparison():MoonExpr
  {
    var expr = term();
    while (match([Greater, GreaterEqual, Less, LessEqual]))
    {
      var op = previous().type;
      var right = term();
      expr = Binary(expr, op, right);
    }
    return expr;
  }

  function term():MoonExpr
  {
    var expr = factor();
    while (match([Plus, Minus]))
    {
      var op = previous().type;
      var right = factor();
      expr = Binary(expr, op, right);
    }
    return expr;
  }

  function factor():MoonExpr
  {
    var expr = unary();
    while (match([Star, Slash, Percent]))
    {
      var op = previous().type;
      var right = unary();
      expr = Binary(expr, op, right);
    }
    return expr;
  }

  function unary():MoonExpr
  {
    if (match([Bang, Minus]))
    {
      var op = previous().type;
      var right = unary();
      return Unary(op, right);
    }
    return postfix();
  }

  function postfix():MoonExpr
  {
    var expr = callExpr();

    if (match([PlusPlus, MinusMinus]))
    {
      var op = previous().type;
      var delta = op == PlusPlus ? Plus : Minus;
      var desugared = Binary(expr, delta, Literal(1.0));

      return switch (expr)
      {
        case Variable(name): Assign(name, desugared);
        case Get(obj, name): Set(obj, name, desugared);
        default: expr;
      }
    }

    return expr;
  }

  function callExpr():MoonExpr
  {
    var expr = primary();

    while (true)
    {
      if (match([LeftParen]))
      {
        expr = Call(expr, arguments());
      }
      else if (match([Dot]))
      {
        var name = consume(Identifier, 'Expect property name after ".".').lexeme;
        expr = Get(expr, name);
      }
      else if (match([LeftBracket]))
      {
        var idx = expression();
        consume(RightBracket, 'Expect "]" after index.');
        expr = Index(expr, idx);
      }
      else break;
    }

    return expr;
  }

  function arguments():Array<MoonExpr>
  {
    var args:Array<MoonExpr> = [];
    if (!check(RightParen))
    {
      do
      {
        args.push(expression());
      }
      while (match([Comma]));
    }
    consume(RightParen, 'Expect ")" after arguments.');
    return args;
  }

  function primary():MoonExpr
  {
    if (match([False])) return Literal(false);
    if (match([True])) return Literal(true);
    if (match([Null])) return Literal(null);
    if (match([This])) return This;
    if (match([NumberLit])) return Literal(previous().literal);
    if (match([StringLit])) return Literal(previous().literal);
    if (match([Identifier])) return Variable(previous().lexeme);

    if (match([New]))
    {
      var name = consume(Identifier, 'Expect class name after "new".').lexeme;
      consume(LeftParen, 'Expect "(" after class name.');
      return New(name, arguments());
    }

    if (match([LeftBracket]))
    {
      var items:Array<MoonExpr> = [];
      if (!check(RightBracket))
      {
        do
        {
          items.push(expression());
        }
        while (match([Comma]));
      }
      consume(RightBracket, 'Expect "]" after array literal.');
      return ArrayLiteral(items);
    }

    if (match([LeftParen]))
    {
      var expr = expression();
      consume(RightParen, 'Expect ")" after expression.');
      return Grouping(expr);
    }

    throw error(peek(), 'Expect expression.');
  }

  function match(types:Array<MoonTokenType>):Bool
  {
    for (t in types)
    {
      if (check(t))
      {
        advance();
        return true;
      }
    }
    return false;
  }

  function check(type:MoonTokenType):Bool
  {
    if (isAtEnd()) return false;
    return peek().type == type;
  }

  function advance():MoonToken
  {
    if (!isAtEnd()) current++;
    return previous();
  }

  function isAtEnd():Bool
  {
    return peek().type == Eof;
  }

  function peek():MoonToken
  {
    return tokens[current];
  }

  function previous():MoonToken
  {
    return tokens[current - 1];
  }

  function consume(type:MoonTokenType, message:String):MoonToken
  {
    if (check(type)) return advance();
    throw error(peek(), message);
  }

  function error(token:MoonToken, message:String):MoonRuntimeError
  {
    return new MoonRuntimeError('[line ${token.line}] Error at "${token.lexeme}": $message');
  }
}

class MoonInterpreter
{
  var globals:MoonEnvironment;
  var environment:MoonEnvironment;

  public function new(globals:MoonEnvironment)
  {
    this.globals = globals;
    this.environment = globals;
  }

  public function interpret(statements:Array<MoonStmt>):Void
  {
    for (statement in statements) execute(statement);
  }

  public function execute(stmt:MoonStmt):Void
  {
    switch (stmt)
    {
      case ExprStmt(expr):
        evaluate(expr);

      case VarStmt(name, _, init):
        environment.define(name, init != null ? evaluate(init) : null);

      case FunctionStmt(name, _, _):
        environment.define(name, new MoonFunction(stmt, environment));

      case ClassStmt(name, superclassName, methodStmts, fieldStmts):
        var superclass:MoonClass = null;
        if (superclassName != null)
        {
          var raw = environment.get(superclassName);
          if (!Std.isOfType(raw, MoonClass)) throw new MoonRuntimeError('"$superclassName" is not a class.');
          superclass = cast raw;
        }

        var classEnv = environment;
        if (superclass != null)
        {
          classEnv = new MoonEnvironment(environment);
          classEnv.define('super', superclass);
        }

        var methods = new Map<String, MoonFunction>();
        for (m in methodStmts)
        {
          switch (m)
          {
            case FunctionStmt(mname, _, _): methods.set(mname, new MoonFunction(m, classEnv));
            default:
          }
        }

        var klass = new MoonClass(name, superclass, methods);

        for (f in fieldStmts)
        {
          switch (f)
          {
            case VarStmt(fname, _, finit): klass.setStatic(fname, finit != null ? evaluate(finit) : null);
            default:
          }
        }

        environment.define(name, klass);

      case IfStmt(cond, thenBranch, elseBranch):
        if (isTruthy(evaluate(cond))) execute(thenBranch)
        else if (elseBranch != null) execute(elseBranch);

      case WhileStmt(cond, body):
        while (isTruthy(evaluate(cond)))
        {
          try
          {
            execute(body);
          }
          catch (b:MoonBreakSignal)
          {
            break;
          }
          catch (c:MoonContinueSignal)
          {
            continue;
          }
        }

      case ForStmt(init, cond, increment, body):
        var previousEnv = environment;
        environment = new MoonEnvironment(previousEnv);
        try
        {
          if (init != null) execute(init);
          while (cond == null || isTruthy(evaluate(cond)))
          {
            try
            {
              execute(body);
            }
            catch (b:MoonBreakSignal)
            {
              break;
            }
            catch (c:MoonContinueSignal) {}
            if (increment != null) evaluate(increment);
          }
        }
        finally
        {
          environment = previousEnv;
        }

      case ReturnStmt(value):
        throw new MoonReturnSignal(value != null ? evaluate(value) : null);

      case BreakStmt:
        throw new MoonBreakSignal();

      case ContinueStmt:
        throw new MoonContinueSignal();

      case BlockStmt(statements):
        executeBlock(statements, new MoonEnvironment(environment));
    }
  }

  public function executeBlock(statements:Array<MoonStmt>, env:MoonEnvironment):Void
  {
    var previousEnv = environment;
    environment = env;
    try
    {
      for (s in statements) execute(s);
    }
    finally
    {
      environment = previousEnv;
    }
  }

  public function evaluate(expr:MoonExpr):Dynamic
  {
    return switch (expr)
    {
      case Literal(value): value;
      case Grouping(e): evaluate(e);
      case Variable(name): environment.get(name);
      case This: environment.get('this');

      case Assign(name, value):
        var v = evaluate(value);
        environment.assign(name, v);
        v;

      case Unary(op, right):
        var r = evaluate(right);
        switch (op)
        {
          case Bang: !isTruthy(r);
          case Minus: -toNum(r);
          default: null;
        }

      case Logical(left, op, right):
        var l = evaluate(left);
        switch (op)
        {
          case OrOr: isTruthy(l) ? l : evaluate(right);
          case AndAnd: !isTruthy(l) ? l : evaluate(right);
          default: null;
        }

      case Binary(left, op, right):
        evalBinary(op, evaluate(left), evaluate(right));

      case ArrayLiteral(items):
        [for (i in items) evaluate(i)];

      case Index(objExpr, indexExpr):
        var obj = evaluate(objExpr);
        var idx = evaluate(indexExpr);
        Std.isOfType(obj, Array) ? (obj : Array<Dynamic>)[Std.int(toNum(idx))] : Reflect.field(obj, Std.string(idx));

      case IndexSet(objExpr, indexExpr, valueExpr):
        var obj = evaluate(objExpr);
        var idx = evaluate(indexExpr);
        var value = evaluate(valueExpr);
        if (Std.isOfType(obj, Array)) (obj : Array<Dynamic>)[Std.int(toNum(idx))] = value
        else Reflect.setField(obj, Std.string(idx), value);
        value;

      case Get(objExpr, name):
        getProperty(evaluate(objExpr), name);

      case Set(objExpr, name, valueExpr):
        var obj = evaluate(objExpr);
        var value = evaluate(valueExpr);
        setProperty(obj, name, value);
        value;

      case New(className, argExprs):
        var raw = environment.get(className);
        if (!Std.isOfType(raw, MoonClass)) throw new MoonRuntimeError('"$className" is not a class.');
        (cast raw : MoonClass).instantiate(this, [for (a in argExprs) evaluate(a)]);

      case Call(calleeExpr, argExprs):
        var args = [for (a in argExprs) evaluate(a)];
        switch (calleeExpr)
        {
          case Get(objExpr, name):
            callMethod(evaluate(objExpr), name, args);
          default:
            callValue(evaluate(calleeExpr), args);
        }
    }
  }

  function getProperty(obj:Dynamic, name:String):Dynamic
  {
    if (Std.isOfType(obj, MoonInstance)) return (cast obj : MoonInstance).get(name);
    if (Std.isOfType(obj, MoonClass)) return (cast obj : MoonClass).getStatic(name);
    return Reflect.getProperty(obj, name);
  }

  function setProperty(obj:Dynamic, name:String, value:Dynamic):Void
  {
    if (Std.isOfType(obj, MoonInstance))
    {
      (cast obj : MoonInstance).set(name, value);
      return;
    }
    if (Std.isOfType(obj, MoonClass))
    {
      (cast obj : MoonClass).setStatic(name, value);
      return;
    }
    Reflect.setProperty(obj, name, value);
  }

  function callMethod(obj:Dynamic, name:String, args:Array<Dynamic>):Dynamic
  {
    if (Std.isOfType(obj, MoonInstance)) return callValue((cast obj : MoonInstance).get(name), args);
    if (Std.isOfType(obj, MoonClass)) return callValue((cast obj : MoonClass).getStatic(name), args);
    return Reflect.callMethod(obj, Reflect.field(obj, name), args);
  }

  public function callValue(callee:Dynamic, args:Array<Dynamic>):Dynamic
  {
    if (Std.isOfType(callee, MoonFunction)) return (cast callee : MoonFunction).call(this, args);
    if (Std.isOfType(callee, MoonNativeFunction)) return (cast callee : MoonNativeFunction).call(args);
    if (Std.isOfType(callee, MoonClass)) return (cast callee : MoonClass).instantiate(this, args);
    if (Reflect.isFunction(callee)) return Reflect.callMethod(null, callee, args);
    throw new MoonRuntimeError('Value is not callable.');
  }

  function evalBinary(op:MoonTokenType, l:Dynamic, r:Dynamic):Dynamic
  {
    return switch (op)
    {
      case Plus:
        (Std.isOfType(l, String) || Std.isOfType(r, String)) ? (Std.string(l) + Std.string(r)) : (toNum(l) + toNum(r));
      case Minus: toNum(l) - toNum(r);
      case Star: toNum(l) * toNum(r);
      case Slash: toNum(l) / toNum(r);
      case Percent: toNum(l) % toNum(r);
      case Greater: toNum(l) > toNum(r);
      case GreaterEqual: toNum(l) >= toNum(r);
      case Less: toNum(l) < toNum(r);
      case LessEqual: toNum(l) <= toNum(r);
      case EqualEqual: valuesEqual(l, r);
      case BangEqual: !valuesEqual(l, r);
      default: throw new MoonRuntimeError('Unsupported binary operator.');
    }
  }

  function isTruthy(v:Dynamic):Bool
  {
    if (v == null) return false;
    if (Std.isOfType(v, Bool)) return v;
    return true;
  }

  function toNum(v:Dynamic):Float
  {
    if (v == null) return 0.0;
    if (Std.isOfType(v, String)) return Std.parseFloat(v);
    if (Std.isOfType(v, Bool)) return (v : Bool) ? 1.0 : 0.0;
    return v;
  }

  function valuesEqual(a:Dynamic, b:Dynamic):Bool
  {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a == b;
  }
}

class MoonScript
{
  var globals:MoonEnvironment;
  var interpreter:MoonInterpreter;

  public var onPrint:String->Void;
  public var onError:String->Void;

  public function new(?source:String)
  {
    globals = new MoonEnvironment();
    interpreter = new MoonInterpreter(globals);
    registerBuiltins();
    if (source != null) execute(source);
  }

  public function execute(source:String):Void
  {
    try
    {
      var tokens = new MoonLexer(source).scanTokens();
      var statements = new MoonParser(tokens).parseProgram();
      interpreter.interpret(statements);
    }
    catch (e:MoonRuntimeError)
    {
      if (onError != null) onError(e.message) else throw e;
    }
  }

  function registerBuiltins():Void
  {
    registerNative('print', function(args:Array<Dynamic>):Dynamic
    {
      if (onPrint != null) onPrint([for (a in args) Std.string(a)].join(' '));
      return null;
    });

    registerNative('length', function(args:Array<Dynamic>):Dynamic
    {
      var value = args[0];
      if (Std.isOfType(value, String)) return (value : String).length;
      if (Std.isOfType(value, Array)) return (value : Array<Dynamic>).length;
      return 0;
    });

    registerNative('typeOf', function(args:Array<Dynamic>):Dynamic
    {
      var v = args[0];
      if (v == null) return 'null';
      if (Std.isOfType(v, Bool)) return 'bool';
      if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) return 'number';
      if (Std.isOfType(v, String)) return 'string';
      if (Std.isOfType(v, Array)) return 'array';
      if (Std.isOfType(v, MoonInstance)) return (cast v : MoonInstance).klass.name;
      if (Std.isOfType(v, MoonClass)) return 'class';
      if (Std.isOfType(v, MoonFunction) || Std.isOfType(v, MoonNativeFunction)) return 'function';
      return 'object';
    });

    registerNative('string', function(args:Array<Dynamic>):Dynamic return Std.string(args[0]));
    registerNative('int', function(args:Array<Dynamic>):Dynamic return Std.int(toNumber(args[0])));
    registerNative('float', function(args:Array<Dynamic>):Dynamic return toNumber(args[0]));

    registerNative('abs', function(args:Array<Dynamic>):Dynamic return Math.abs(toNumber(args[0])));
    registerNative('floor', function(args:Array<Dynamic>):Dynamic return Math.floor(toNumber(args[0])));
    registerNative('ceil', function(args:Array<Dynamic>):Dynamic return Math.ceil(toNumber(args[0])));
    registerNative('round', function(args:Array<Dynamic>):Dynamic return Math.round(toNumber(args[0])));
    registerNative('random', function(args:Array<Dynamic>):Dynamic return Math.random());
    registerNative('randomInt', function(args:Array<Dynamic>):Dynamic
    {
      var min = Std.int(toNumber(args[0]));
      var max = Std.int(toNumber(args[1]));
      return min + Std.random(max - min + 1);
    });
  }

  function toNumber(v:Dynamic):Float
  {
    if (v == null) return 0.0;
    if (Std.isOfType(v, String)) return Std.parseFloat(v);
    return v;
  }

  public function registerNative(name:String, fn:Array<Dynamic>->Dynamic):Void
  {
    globals.define(name, new MoonNativeFunction(name, fn));
  }

  public function setGlobal(name:String, value:Dynamic):Void
  {
    globals.define(name, value);
  }

  public function getGlobal(name:String):Dynamic
  {
    return globals.get(name);
  }

  public function call(name:String, ?args:Array<Dynamic>):Dynamic
  {
    var callee = globals.get(name);
    return interpreter.callValue(callee, args == null ? [] : args);
  }
}
