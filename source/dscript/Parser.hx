package dscript;

class Parser {
	var tokens:Array<Token>;
	var current:Int = 0;

	public function new(tokens:Array<Token>) {
		this.tokens = tokens;
	}

	public function parse():Array<Stmt> {
		var stmts:Array<Stmt> = [];
		while (!isAtEnd()) stmts.push(declaration());
		return stmts;
	}

	function declaration():Stmt {
		if (check(TkClass)) return classDecl();
		if (check(TkFn))    return fnDeclStmt();
		if (check(TkVar))   return varDecl();
		return statement();
	}

	function classDecl():Stmt {
		consume(TkClass, "Expected 'class'");
		var name = consume(TkIdent, "Expected class name");

		var superclass:Null<Expr> = null;
		if (match([TkExtends])) {
			var supTok = consume(TkIdent, "Expected superclass name");
			superclass = EIdent(supTok);
		}

		consume(TkLBrace, "Expected '{' before class body");

		var methods:Array<SFnDecl_> = [];
		while (!check(TkRBrace) && !isAtEnd()) {
			consume(TkFn, "Expected 'fn' in class body");
			var mName   = consume(TkIdent, "Expected method name");
			consume(TkLParen, "Expected '(' after method name");
			var params  = paramList();
			consume(TkRParen, "Expected ')' after method parameters");
			consume(TkLBrace, "Expected '{' before method body");
			var body    = block();
			methods.push({ name: mName, params: params, body: body });
		}

		consume(TkRBrace, "Expected '}' after class body");
		return SClassDecl(name, superclass, methods);
	}

	function fnDeclStmt():Stmt {
		consume(TkFn, "Expected 'fn'");
		var name = consume(TkIdent, "Expected function name");
		consume(TkLParen, "Expected '(' after function name");
		var params = paramList();
		consume(TkRParen, "Expected ')' after parameters");
		consume(TkLBrace, "Expected '{' before function body");
		var body = block();
		return SFnDecl(name, params, body);
	}

	function varDecl():Stmt {
		consume(TkVar, "Expected 'var'");
		var name = consume(TkIdent, "Expected variable name");
		var init:Null<Expr> = null;
		if (match([TkEq])) init = expression();
		optSemi();
		return SVarDecl(name, init);
	}

	function statement():Stmt {
		if (match([TkIf]))       return ifStmt();
		if (match([TkWhile]))    return whileStmt();
		if (match([TkFor]))      return forStmt();
		if (match([TkReturn]))   return returnStmt();
		if (match([TkBreak]))    { optSemi(); return SBreak(previous()); }
		if (match([TkContinue])) { optSemi(); return SContinue(previous()); }
		if (match([TkTry]))      return tryStmt();
		if (match([TkLBrace]))   return SBlock(block());
		return exprStmt();
	}

	function ifStmt():Stmt {
		var cond = expression();
		consume(TkLBrace, "Expected '{' after if condition");
		var then = SBlock(block());
		var els:Null<Stmt>  = null;
		if (match([TkElse])) {
			if (match([TkIf])) els = ifStmt()
			else { consume(TkLBrace, "Expected '{' after else"); els = SBlock(block()); }
		}
		return SIf(cond, then, els);
	}

	function whileStmt():Stmt {
		var cond = expression();
		consume(TkLBrace, "Expected '{' before while body");
		var body = SBlock(block());
		return SWhile(cond, body);
	}

	function forStmt():Stmt {
		var varName = consume(TkIdent, "Expected variable name in for");
		consume(TkIn, "Expected 'in' after variable in for");
		var iterable = expression();
		consume(TkLBrace, "Expected '{' before for body");
		var body = block();
		return SFor(varName, iterable, body);
	}

	function returnStmt():Stmt {
		var keyword = previous();
		var value:Null<Expr> = null;
		if (!check(TkRBrace) && !check(TkSemicolon) && !isAtEnd())
			value = expression();
		optSemi();
		return SReturn(keyword, value);
	}

	function tryStmt():Stmt {
		consume(TkLBrace, "Expected '{' after try");
		var body = block();
		consume(TkCatch, "Expected 'catch' after try block");
		consume(TkLParen, "Expected '(' after catch");
		var catchVar = consume(TkIdent, "Expected variable name in catch");
		consume(TkRParen, "Expected ')' after catch variable");
		consume(TkLBrace, "Expected '{' before catch body");
		var catchBody = block();
		return STry(body, catchVar, catchBody);
	}

	function exprStmt():Stmt {
		var expr = expression();
		optSemi();
		return SExpr(expr);
	}

	function block():Array<Stmt> {
		var stmts:Array<Stmt> = [];
		while (!check(TkRBrace) && !isAtEnd()) stmts.push(declaration());
		consume(TkRBrace, "Expected '}' after block");
		return stmts;
	}

	function expression():Expr {
		return assignment();
	}

	function assignment():Expr {
		var expr = ternary();

		if (match([TkEq])) {
			var value = assignment();
			return switch expr {
				case EIdent(name):     EAssign(name, value);
				case EGet(obj, name):  ESet(obj, name, value);
				case EIndex(obj, idx): EAssignIndex(obj, idx, value);
				default: error("Invalid assignment target"); expr;
			};
		}

		if (match([TkPlusEq, TkMinusEq, TkStarEq, TkSlashEq])) {
			var op    = previous();
			var value = assignment();
			return switch expr {
				case EIdent(name): ECompoundAssign(name, op, value);
				default: error("Invalid compound assignment target"); expr;
			};
		}

		return expr;
	}

	function ternary():Expr {
		var expr = or_();
		if (match([TkQuestion])) {
			var then = expression();
			consume(TkColon, "Expected ':' in ternary expression");
			var els  = ternary();
			return ETernary(expr, then, els);
		}
		return expr;
	}

	function or_():Expr {
		var expr = and_();
		while (match([TkOr])) {
			var op    = previous();
			var right = and_();
			expr = ELogical(expr, op, right);
		}
		return expr;
	}

	function and_():Expr {
		var expr = equality();
		while (match([TkAnd])) {
			var op    = previous();
			var right = equality();
			expr = ELogical(expr, op, right);
		}
		return expr;
	}

	function equality():Expr {
		var expr = comparison();
		while (match([TkBangEq, TkEqEq])) {
			var op    = previous();
			var right = comparison();
			expr = EBinary(expr, op, right);
		}
		return expr;
	}

	function comparison():Expr {
		var expr = addition();
		while (match([TkLt, TkLtEq, TkGt, TkGtEq])) {
			var op    = previous();
			var right = addition();
			expr = EBinary(expr, op, right);
		}
		return expr;
	}

	function addition():Expr {
		var expr = multiplication();
		while (match([TkPlus, TkMinus])) {
			var op    = previous();
			var right = multiplication();
			expr = EBinary(expr, op, right);
		}
		return expr;
	}

	function multiplication():Expr {
		var expr = unary();
		while (match([TkStar, TkSlash, TkPercent])) {
			var op    = previous();
			var right = unary();
			expr = EBinary(expr, op, right);
		}
		return expr;
	}

	function unary():Expr {
		if (match([TkBang, TkMinus])) {
			var op    = previous();
			var right = unary();
			return EUnary(op, right);
		}
		return callExpr();
	}

	function callExpr():Expr {
		var expr = primary();
		while (true) {
			if (match([TkLParen])) {
				var paren = previous();
				var args  = argList();
				consume(TkRParen, "Expected ')' after arguments");
				expr = ECall(expr, paren, args);
			} else if (match([TkDot])) {
				var name = consume(TkIdent, "Expected property name after '.'");
				expr = EGet(expr, name);
			} else if (match([TkLBracket])) {
				var index = expression();
				consume(TkRBracket, "Expected ']' after index");
				expr = EIndex(expr, index);
			} else break;
		}
		return expr;
	}

	function primary():Expr {
		if (match([TkNull]))   return ELiteral(Null);
		if (match([TkTrue]))   return ELiteral(Bool(true));
		if (match([TkFalse]))  return ELiteral(Bool(false));
		if (match([TkNumber])) return ELiteral(Number(previous().literal));
		if (match([TkString])) return ELiteral(Value.String(previous().literal));
		if (match([TkSelf]))   return ESelf(previous());

		if (match([TkSuper])) {
			var keyword = previous();
			consume(TkDot, "Expected '.' after 'super'");
			var method = consume(TkIdent, "Expected method name after 'super.'");
			return ESuper(keyword, method);
		}

		if (match([TkIdent])) return EIdent(previous());

		if (match([TkLParen])) {
			var expr = expression();
			consume(TkRParen, "Expected ')' after expression");
			return expr;
		}

		if (match([TkLBracket])) {
			var elems:Array<Expr> = [];
			if (!check(TkRBracket)) {
				elems.push(expression());
				while (match([TkComma]) && !check(TkRBracket))
					elems.push(expression());
			}
			consume(TkRBracket, "Expected ']' after array elements");
			return EArrayLit(elems);
		}

		if (match([TkLBrace])) {
			var keys:Array<String>  = [];
			var vals:Array<Expr>    = [];
			if (!check(TkRBrace)) {
				parseMapEntry(keys, vals);
				while (match([TkComma]) && !check(TkRBrace))
					parseMapEntry(keys, vals);
			}
			consume(TkRBrace, "Expected '}' after map entries");
			return EMapLit(keys, vals);
		}

		if (match([TkFn])) {
			consume(TkLParen, "Expected '(' in lambda");
			var params = paramList();
			consume(TkRParen, "Expected ')' in lambda");
			consume(TkLBrace, "Expected '{' before lambda body");
			var body = block();
			return ELambda(params, body);
		}

		throw new ParseError('Unexpected token "${peek().lexeme}"', peek().line);
	}

	function parseMapEntry(keys:Array<String>, vals:Array<Expr>):Void {
		var key:String;
		if      (match([TkString])) key = previous().literal;
		else if (match([TkIdent]))  key = previous().lexeme;
		else throw new ParseError("Expected string or identifier as map key", peek().line);
		consume(TkColon, "Expected ':' after map key");
		keys.push(key);
		vals.push(expression());
	}

	function paramList():Array<Token> {
		var params:Array<Token> = [];
		if (!check(TkRParen)) {
			params.push(consume(TkIdent, "Expected parameter name"));
			while (match([TkComma]))
				params.push(consume(TkIdent, "Expected parameter name"));
		}
		return params;
	}

	function argList():Array<Expr> {
		var args:Array<Expr> = [];
		if (!check(TkRParen)) {
			args.push(expression());
			while (match([TkComma]))
				args.push(expression());
		}
		return args;
	}

	function match(types:Array<TokenType>):Bool {
		for (t in types) if (check(t)) { advance(); return true; }
		return false;
	}

	function check(type:TokenType):Bool {
		return !isAtEnd() && peek().type == type;
	}

	function advance():Token {
		if (!isAtEnd()) current++;
		return previous();
	}

	function consume(type:TokenType, message:String):Token {
		if (check(type)) return advance();
		throw new ParseError('$message (got "${peek().lexeme}")', peek().line);
	}

	function optSemi():Void {
		match([TkSemicolon]);
	}

	function error(message:String):Void {
		throw new ParseError(message, peek().line);
	}

	inline function isAtEnd():Bool  return peek().type == TkEof;
	inline function peek():Token    return tokens[current];
	inline function previous():Token return tokens[current - 1];
}
