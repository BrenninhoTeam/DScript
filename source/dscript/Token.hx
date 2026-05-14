package dscript;

enum TokenType {
	TkNumber;
	TkString;
	TkTrue;
	TkFalse;
	TkNull;

	TkIdent;

	TkVar;
	TkFn;
	TkReturn;
	TkIf;
	TkElse;
	TkWhile;
	TkFor;
	TkIn;
	TkClass;
	TkExtends;
	TkSelf;
	TkSuper;
	TkBreak;
	TkContinue;
	TkTry;
	TkCatch;
	TkNew;

	TkPlus;
	TkMinus;
	TkStar;
	TkSlash;
	TkPercent;
	TkBang;
	TkBangEq;
	TkEqEq;
	TkLt;
	TkLtEq;
	TkGt;
	TkGtEq;
	TkAnd;
	TkOr;
	TkEq;
	TkPlusEq;
	TkMinusEq;
	TkStarEq;
	TkSlashEq;

	TkLParen;
	TkRParen;
	TkLBrace;
	TkRBrace;
	TkLBracket;
	TkRBracket;
	TkComma;
	TkDot;
	TkSemicolon;
	TkColon;
	TkQuestion;

	TkEof;
}

class Token {
	public var type:TokenType;
	public var lexeme:String;
	public var line:Int;
	public var literal:Dynamic;

	public function new(type:TokenType, lexeme:String, line:Int, ?literal:Dynamic) {
		this.type    = type;
		this.lexeme  = lexeme;
		this.line    = line;
		this.literal = literal;
	}

	public function toString():String {
		return '$type("$lexeme"@$line)';
	}
}
