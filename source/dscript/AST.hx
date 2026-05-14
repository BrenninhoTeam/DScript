package dscript;

enum Expr {
	ELiteral(v:Value);
	EIdent(name:Token);
	EBinary(left:Expr, op:Token, right:Expr);
	EUnary(op:Token, right:Expr);
	ELogical(left:Expr, op:Token, right:Expr);
	ETernary(cond:Expr, then:Expr, els:Expr);
	EAssign(name:Token, value:Expr);
	ECompoundAssign(name:Token, op:Token, value:Expr);
	EAssignField(object:Expr, name:Token, value:Expr);
	EAssignIndex(object:Expr, index:Expr, value:Expr);
	ECall(callee:Expr, paren:Token, args:Array<Expr>);
	EGet(object:Expr, name:Token);
	ESet(object:Expr, name:Token, value:Expr);
	EIndex(object:Expr, index:Expr);
	EArrayLit(elements:Array<Expr>);
	EMapLit(keys:Array<String>, values:Array<Expr>);
	ELambda(params:Array<Token>, body:Array<Stmt>);
	ESelf(keyword:Token);
	ESuper(keyword:Token, method:Token);
}

enum Stmt {
	SExpr(expr:Expr);
	SVarDecl(name:Token, init:Null<Expr>);
	SFnDecl(name:Token, params:Array<Token>, body:Array<Stmt>);
	SClassDecl(name:Token, superclass:Null<Expr>, methods:Array<SFnDecl_>);
	SIf(cond:Expr, then:Stmt, els:Null<Stmt>);
	SWhile(cond:Expr, body:Stmt);
	SFor(varName:Token, iterable:Expr, body:Array<Stmt>);
	SReturn(keyword:Token, value:Null<Expr>);
	SBreak(keyword:Token);
	SContinue(keyword:Token);
	SBlock(stmts:Array<Stmt>);
	STry(body:Array<Stmt>, catchVar:Token, catchBody:Array<Stmt>);
}

typedef SFnDecl_ = {
	name:Token,
	params:Array<Token>,
	body:Array<Stmt>
}
