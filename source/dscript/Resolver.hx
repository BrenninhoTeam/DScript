package dscript;

private enum FunctionKind { FkNone; FkFunction; FkMethod; FkInit; }
private enum ClassKind    { CkNone; CkClass; CkSubclass; }

class Resolver {
	var scopes:Array<Map<String, Bool>> = [];
	var currentFunction:FunctionKind   = FkNone;
	var currentClass:ClassKind         = CkNone;
	var loopDepth:Int                  = 0;

	public function new() {}

	public function resolveProgram(stmts:Array<Stmt>):Void {
		resolveStmts(stmts);
	}

	function resolveStmts(stmts:Array<Stmt>):Void {
		for (s in stmts) resolveStmt(s);
	}

	function resolveStmt(stmt:Stmt):Void {
		switch stmt {
			case SBlock(stmts):
				beginScope();
				resolveStmts(stmts);
				endScope();

			case SVarDecl(name, init):
				declare(name);
				if (init != null) resolveExpr(init);
				define(name);

			case SFnDecl(name, params, body):
				declare(name);
				define(name);
				resolveFunction(params, body, FkFunction);

			case SClassDecl(name, superclass, methods):
				var encClass = currentClass;
				currentClass = CkClass;
				declare(name);
				define(name);

				if (superclass != null) {
					currentClass = CkSubclass;
					resolveExpr(superclass);
					beginScope();
					scopes[scopes.length - 1].set("super", true);
				}

				beginScope();
				scopes[scopes.length - 1].set("self", true);

				for (m in methods) {
					var kind = m.name.lexeme == "init" ? FkInit : FkMethod;
					resolveFunction(m.params, m.body, kind);
				}

				endScope();
				if (superclass != null) endScope();
				currentClass = encClass;

			case SIf(cond, then, els):
				resolveExpr(cond);
				resolveStmt(then);
				if (els != null) resolveStmt(els);

			case SWhile(cond, body):
				resolveExpr(cond);
				loopDepth++;
				resolveStmt(body);
				loopDepth--;

			case SFor(varName, iterable, body):
				resolveExpr(iterable);
				beginScope();
				scopes[scopes.length - 1].set(varName.lexeme, true);
				loopDepth++;
				resolveStmts(body);
				loopDepth--;
				endScope();

			case SReturn(keyword, value):
				if (currentFunction == FkNone)
					throw new DScriptError("Cannot use 'return' outside a function", keyword.line);
				if (value != null) {
					if (currentFunction == FkInit)
						throw new DScriptError("Cannot return a value from 'init'", keyword.line);
					resolveExpr(value);
				}

			case SBreak(keyword):
				if (loopDepth == 0)
					throw new DScriptError("Cannot use 'break' outside a loop", keyword.line);

			case SContinue(keyword):
				if (loopDepth == 0)
					throw new DScriptError("Cannot use 'continue' outside a loop", keyword.line);

			case SExpr(expr):
				resolveExpr(expr);

			case STry(body, catchVar, catchBody):
				resolveStmts(body);
				beginScope();
				scopes[scopes.length - 1].set(catchVar.lexeme, true);
				resolveStmts(catchBody);
				endScope();
		}
	}

	function resolveExpr(expr:Expr):Void {
		switch expr {
			case ELiteral(_):

			case EIdent(name):
				if (scopes.length > 0) {
					var top = scopes[scopes.length - 1];
					if (top.exists(name.lexeme) && top.get(name.lexeme) == false)
						throw new DScriptError('Cannot read "${name.lexeme}" in its own initializer', name.line);
				}

			case EAssign(_, value) | ECompoundAssign(_, _, value):
				resolveExpr(value);

			case EAssignField(obj, _, value):
				resolveExpr(obj);
				resolveExpr(value);

			case EAssignIndex(obj, idx, value):
				resolveExpr(obj);
				resolveExpr(idx);
				resolveExpr(value);

			case EBinary(left, _, right) | ELogical(left, _, right):
				resolveExpr(left);
				resolveExpr(right);

			case EUnary(_, right):
				resolveExpr(right);

			case ETernary(cond, then, els):
				resolveExpr(cond);
				resolveExpr(then);
				resolveExpr(els);

			case ECall(callee, _, args):
				resolveExpr(callee);
				for (a in args) resolveExpr(a);

			case EGet(obj, _):
				resolveExpr(obj);

			case ESet(obj, _, value):
				resolveExpr(obj);
				resolveExpr(value);

			case EIndex(obj, idx):
				resolveExpr(obj);
				resolveExpr(idx);

			case EArrayLit(elems):
				for (e in elems) resolveExpr(e);

			case EMapLit(_, values):
				for (v in values) resolveExpr(v);

			case ELambda(params, body):
				resolveFunction(params, body, FkFunction);

			case ESelf(keyword):
				if (currentClass == CkNone)
					throw new DScriptError("Cannot use 'self' outside a class", keyword.line);

			case ESuper(keyword, _):
				if (currentClass == CkNone)
					throw new DScriptError("Cannot use 'super' outside a class", keyword.line);
				if (currentClass != CkSubclass)
					throw new DScriptError("Cannot use 'super' in a class with no superclass", keyword.line);
		}
	}

	function resolveFunction(params:Array<Token>, body:Array<Stmt>, kind:FunctionKind):Void {
		var encFn = currentFunction;
		currentFunction = kind;
		beginScope();
		for (p in params) { declare(p); define(p); }
		resolveStmts(body);
		endScope();
		currentFunction = encFn;
	}

	function beginScope():Void  scopes.push(new Map());
	function endScope():Void    scopes.pop();

	function declare(name:Token):Void {
		if (scopes.length == 0) return;
		scopes[scopes.length - 1].set(name.lexeme, false);
	}

	function define(name:Token):Void {
		if (scopes.length == 0) return;
		scopes[scopes.length - 1].set(name.lexeme, true);
	}
}
