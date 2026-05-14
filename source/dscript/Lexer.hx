package dscript;

class Lexer {
	var source:String;
	var tokens:Array<Token> = [];
	var start:Int   = 0;
	var current:Int = 0;
	var line:Int    = 1;

	static final keywords:Map<String, TokenType> = [
		"var"      => TkVar,
		"fn"       => TkFn,
		"return"   => TkReturn,
		"if"       => TkIf,
		"else"     => TkElse,
		"while"    => TkWhile,
		"for"      => TkFor,
		"in"       => TkIn,
		"class"    => TkClass,
		"extends"  => TkExtends,
		"self"     => TkSelf,
		"super"    => TkSuper,
		"break"    => TkBreak,
		"continue" => TkContinue,
		"try"      => TkTry,
		"catch"    => TkCatch,
		"new"      => TkNew,
		"true"     => TkTrue,
		"false"    => TkFalse,
		"null"     => TkNull,
	];

	public function new(source:String) {
		this.source = source;
	}

	public function scan():Array<Token> {
		while (!isAtEnd()) {
			start = current;
			scanToken();
		}
		tokens.push(new Token(TkEof, "", line));
		return tokens;
	}

	function scanToken():Void {
		var c = advance();
		switch c {
			case "(":  addToken(TkLParen);
			case ")":  addToken(TkRParen);
			case "{":  addToken(TkLBrace);
			case "}":  addToken(TkRBrace);
			case "[":  addToken(TkLBracket);
			case "]":  addToken(TkRBracket);
			case ",":  addToken(TkComma);
			case ".":  addToken(TkDot);
			case ";":  addToken(TkSemicolon);
			case ":":  addToken(TkColon);
			case "?":  addToken(TkQuestion);
			case "+":  addToken(matchChar("=") ? TkPlusEq  : TkPlus);
			case "-":  addToken(matchChar("=") ? TkMinusEq : TkMinus);
			case "*":  addToken(matchChar("=") ? TkStarEq  : TkStar);
			case "%":  addToken(TkPercent);
			case "!":  addToken(matchChar("=") ? TkBangEq  : TkBang);
			case "=":  addToken(matchChar("=") ? TkEqEq    : TkEq);
			case "<":  addToken(matchChar("=") ? TkLtEq    : TkLt);
			case ">":  addToken(matchChar("=") ? TkGtEq    : TkGt);
			case "&":
				if (matchChar("&")) addToken(TkAnd)
				else error('Unexpected character "&"');
			case "|":
				if (matchChar("|")) addToken(TkOr)
				else error('Unexpected character "|"');
			case "/":
				if      (matchChar("/")) lineComment()
				else if (matchChar("*")) blockComment()
				else addToken(matchChar("=") ? TkSlashEq : TkSlash);
			case " " | "\r" | "\t": // whitespace
			case "\n": line++;
			case '"' | "'": scanString(c);
			default:
				if   (isDigit(c)) scanNumber();
				else if (isAlpha(c)) scanIdentifier();
				else error('Unexpected character "$c"');
		}
	}

	function lineComment():Void {
		while (peek() != "\n" && !isAtEnd()) advance();
	}

	function blockComment():Void {
		var depth = 1;
		while (!isAtEnd() && depth > 0) {
			if      (peek() == "/" && peekNext() == "*") { advance(); advance(); depth++; }
			else if (peek() == "*" && peekNext() == "/") { advance(); advance(); depth--; }
			else {
				if (peek() == "\n") line++;
				advance();
			}
		}
		if (depth > 0) error("Unterminated block comment");
	}

	function scanString(quote:String):Void {
		var buf = new StringBuf();
		while (!isAtEnd() && peek() != quote) {
			if (peek() == "\n") line++;
			if (peek() == "\\") {
				advance();
				switch advance() {
					case "n":  buf.addChar("\n".code);
					case "t":  buf.addChar("\t".code);
					case "r":  buf.addChar("\r".code);
					case "0":  buf.addChar(0);
					case "\\":  buf.addChar("\\".code);
					case "\"": buf.addChar('"'.code);
					case "'":  buf.addChar("'".code);
					case var e: error('Unknown escape sequence "\\$e"');
				}
			} else {
				buf.add(advance());
			}
		}
		if (isAtEnd()) error("Unterminated string literal");
		advance();
		addTokenLiteral(TkString, buf.toString());
	}

	function scanNumber():Void {
		while (isDigit(peek())) advance();
		if (peek() == "." && isDigit(peekNext())) {
			advance();
			while (isDigit(peek())) advance();
		}
		var raw = source.substring(start, current);
		addTokenLiteral(TkNumber, Std.parseFloat(raw));
	}

	function scanIdentifier():Void {
		while (isAlphaNumeric(peek())) advance();
		var text = source.substring(start, current);
		var type = keywords.exists(text) ? keywords.get(text) : TkIdent;
		addToken(type);
	}

	function advance():String {
		return source.charAt(current++);
	}

	function matchChar(expected:String):Bool {
		if (isAtEnd() || source.charAt(current) != expected) return false;
		current++;
		return true;
	}

	function peek():String {
		return isAtEnd() ? "\x00" : source.charAt(current);
	}

	function peekNext():String {
		return (current + 1 >= source.length) ? "\x00" : source.charAt(current + 1);
	}

	function addToken(type:TokenType):Void {
		tokens.push(new Token(type, source.substring(start, current), line));
	}

	function addTokenLiteral(type:TokenType, literal:Dynamic):Void {
		tokens.push(new Token(type, source.substring(start, current), line, literal));
	}

	function error(msg:String):Void {
		throw new ParseError(msg, line);
	}

	inline function isAtEnd():Bool    return current >= source.length;
	inline function isDigit(c:String):Bool return c >= "0" && c <= "9";
	inline function isAlpha(c:String):Bool
		return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "_";
	inline function isAlphaNumeric(c:String):Bool return isAlpha(c) || isDigit(c);
}
