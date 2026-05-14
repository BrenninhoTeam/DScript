package dscript;

import haxe.ds.StringMap;

class DScriptFunction {
	public var name:String;
	public var params:Array<Token>;
	public var body:Array<Stmt>;
	public var closure:Environment;
	public var isInit:Bool;

	public function new(name:String, params:Array<Token>, body:Array<Stmt>, closure:Environment, isInit:Bool = false) {
		this.name    = name;
		this.params  = params;
		this.body    = body;
		this.closure = closure;
		this.isInit  = isInit;
	}

	public function bind(instance:DScriptInstance):DScriptFunction {
		var env = new Environment(closure);
		env.define("self", Value.Instance(instance));
		return new DScriptFunction(name, params, body, env, isInit);
	}

	public function call(interpreter:Interpreter, args:Array<Value>):Value {
		var env = new Environment(closure);
		for (i in 0...params.length)
			env.define(params[i].lexeme, i < args.length ? args[i] : Null);
		try {
			interpreter.executeBlock(body, env);
		} catch (r:ReturnSignal) {
			return isInit ? closure.getAt(0, "self") : r.value;
		}
		return isInit ? closure.getAt(0, "self") : Null;
	}

	public function toString():String return '<fn $name>';
}

class DScriptClass {
	public var name:String;
	public var superclass:Null<DScriptClass>;

	var methods:StringMap<DScriptFunction>;

	public function new(name:String, superclass:Null<DScriptClass>, methods:StringMap<DScriptFunction>) {
		this.name       = name;
		this.superclass = superclass;
		this.methods    = methods;
	}

	public function findMethod(name:String):Null<DScriptFunction> {
		if (methods.exists(name)) return methods.get(name);
		if (superclass != null)   return superclass.findMethod(name);
		return null;
	}

	public function call(interpreter:Interpreter, args:Array<Value>):Value {
		var instance = new DScriptInstance(this);
		var init     = findMethod("init");
		if (init != null) init.bind(instance).call(interpreter, args);
		return Value.Instance(instance);
	}

	public function toString():String return '<class $name>';
}

class DScriptInstance {
	public var cls:DScriptClass;

	var fields:StringMap<Value> = new StringMap();

	public function new(cls:DScriptClass) {
		this.cls = cls;
	}

	public function get(name:Token):Value {
		if (fields.exists(name.lexeme)) return fields.get(name.lexeme);
		var method = cls.findMethod(name.lexeme);
		if (method != null) return Value.Function(method.bind(this));
		throw new RuntimeError('Undefined property "${name.lexeme}"', name.line);
	}

	public function set(name:Token, value:Value):Void {
		fields.set(name.lexeme, value);
	}

	public function setField(name:String, value:Value):Void {
		fields.set(name, value);
	}

	public function toString():String return '<${cls.name} instance>';
}

class Interpreter {
	var globals:Environment;
	var environment:Environment;
	var sandbox:Null<Sandbox>;

	public function new(?sandbox:Sandbox) {
		this.sandbox  = sandbox;
		globals       = new Environment();
		environment   = globals;
	}

	public function bind(name:String, value:Dynamic):Void {
		var v:Value = switch Type.typeof(value) {
			case TFunction: Value.Native(value);
			default:        cast value;
		};
		globals.define(name, v);
	}

	public function run(source:String):Void {
		var stmts = compile(source);
		executeBlock(stmts, globals);
	}

	public function eval(source:String):Value {
		var stmts = compile(source);
		var last:Value = Null;
		for (stmt in stmts) {
			switch stmt {
				case SExpr(expr): last = evaluate(expr);
				default:          executeStmt(stmt);
			}
		}
		return last;
	}

	public function check(source:String):Void {
		compile(source);
	}

	public function callValue(callee:Value, args:Array<Value>):Value {
		if (sandbox != null) sandbox.checkCall();
		return switch callee {
			case Value.Function(fn): fn.call(this, args);
			case Value.Native(fn):   fn(args);
			case Value.Class(cls):   cls.call(this, args);
			default: throw new RuntimeError("Value is not callable: " + callee.typeName());
		};
	}

	public function executeBlock(stmts:Array<Stmt>, env:Environment):Void {
		var prev = environment;
		environment = env;
		try {
			for (s in stmts) executeStmt(s);
			environment = prev;
		} catch (e:Dynamic) {
			environment = prev;
			throw e;
		}
	}

	function compile(source:String):Array<Stmt> {
		var tokens = new Lexer(source).scan();
		var stmts  = new Parser(tokens).parse();
		new Resolver().resolveProgram(stmts);
		return stmts;
	}

	function executeStmt(stmt:Stmt):Void {
		switch stmt {
			case SExpr(expr):
				evaluate(expr);

			case SVarDecl(name, init):
				var value = init != null ? evaluate(init) : Null;
				environment.define(name.lexeme, value);

			case SFnDecl(name, params, body):
				var fn = new DScriptFunction(name.lexeme, params, body, environment);
				environment.define(name.lexeme, Value.Function(fn));

			case SClassDecl(name, superExpr, methods):
				environment.define(name.lexeme, Null);

				var superclass:Null<DScriptClass> = null;
				if (superExpr != null) {
					var sv = evaluate(superExpr);
					switch sv {
						case Value.Class(c): superclass = c;
						default: throw new RuntimeError("Superclass must be a class");
					}
					environment = new Environment(environment);
					environment.define("super", sv);
				}

				var methodMap = new StringMap<DScriptFunction>();
				for (m in methods) {
					var fn = new DScriptFunction(m.name.lexeme, m.params, m.body, environment, m.name.lexeme == "init");
					methodMap.set(m.name.lexeme, fn);
				}

				var cls = new DScriptClass(name.lexeme, superclass, methodMap);
				if (superclass != null) environment = environment.parent;
				environment.assign(name, Value.Class(cls));

			case SIf(cond, then, els):
				if (evaluate(cond).isTruthy()) executeStmt(then)
				else if (els != null)          executeStmt(els);

			case SWhile(cond, body):
				while (evaluate(cond).isTruthy()) {
					try {
						executeStmt(body);
					} catch (b:BreakSignal) {
						break;
					} catch (c:ContinueSignal) {
						continue;
					}
				}

			case SFor(varName, iterable, body):
				var iter  = evaluate(iterable);
				var items = switch iter {
					case Value.Array(a):  a;
					case Value.String(s): [for (i in 0...s.length) Value.String(s.charAt(i))];
					default: throw new RuntimeError("'for' target must be iterable (array or string)");
				};
				for (item in items) {
					var loopEnv = new Environment(environment);
					loopEnv.define(varName.lexeme, item);
					try {
						executeBlock(body, loopEnv);
					} catch (b:BreakSignal) {
						break;
					} catch (c:ContinueSignal) {
						continue;
					}
				}

			case SReturn(_, value):
				var v = value != null ? evaluate(value) : Null;
				throw new ReturnSignal(v);

			case SBreak(_):
				throw new BreakSignal();

			case SContinue(_):
				throw new ContinueSignal();

			case SBlock(stmts):
				executeBlock(stmts, new Environment(environment));

			case STry(body, catchVar, catchBody):
				try {
					executeBlock(body, new Environment(environment));
				} catch (e:BreakSignal) {
					throw e;
				} catch (e:ContinueSignal) {
					throw e;
				} catch (e:ReturnSignal) {
					throw e;
				} catch (e:DScriptError) {
					var catchEnv = new Environment(environment);
					catchEnv.define(catchVar.lexeme, Value.Instance(wrapError(e)));
					executeBlock(catchBody, catchEnv);
				} catch (e:haxe.Exception) {
					var catchEnv = new Environment(environment);
					catchEnv.define(catchVar.lexeme, Value.Instance(wrapMessage(e.message)));
					executeBlock(catchBody, catchEnv);
				}
		}
	}

	function evaluate(expr:Expr):Value {
		return switch expr {
			case ELiteral(v): v;

			case EIdent(name):
				var v = environment.getByName(name.lexeme);
				if (v != null) v
				else throw new RuntimeError('Undefined variable "${name.lexeme}"', name.line);

			case EAssign(name, valExpr):
				var v = evaluate(valExpr);
				if (!environment.assignByName(name.lexeme, v))
					throw new RuntimeError('Undefined variable "${name.lexeme}"', name.line);
				v;

			case ECompoundAssign(name, op, valExpr):
				var current = switch environment.getByName(name.lexeme) {
					case null: throw new RuntimeError('Undefined variable "${name.lexeme}"', name.line);
					case v: v;
				};
				var right  = evaluate(valExpr);
				var result = applyArith(op, current, right);
				environment.assignByName(name.lexeme, result);
				result;

			case EBinary(left, op, right):
				applyBinary(op, evaluate(left), evaluate(right));

			case EUnary(op, right):
				applyUnary(op, evaluate(right));

			case ELogical(left, op, right):
				var lv = evaluate(left);
				switch op.type {
					case TkOr:  lv.isTruthy() ? lv : evaluate(right);
					case TkAnd: !lv.isTruthy() ? lv : evaluate(right);
					default: lv;
				}

			case ETernary(cond, then, els):
				evaluate(cond).isTruthy() ? evaluate(then) : evaluate(els);

			case ECall(calleeExpr, paren, argExprs):
				var callee = evaluate(calleeExpr);
				var args   = argExprs.map(a -> evaluate(a));
				try {
					callValue(callee, args);
				} catch (e:DScriptError) {
					throw e;
				} catch (e:ReturnSignal | e:BreakSignal | e:ContinueSignal) {
					throw e;
				} catch (e:haxe.Exception) {
					throw new RuntimeError(e.message, paren.line);
				}

			case EGet(objExpr, name):
				var obj = evaluate(objExpr);
				switch obj {
					case Value.Instance(i):
						i.get(name);
					case Value.Map(m):
						m.exists(name.lexeme) ? m.get(name.lexeme) : Null;
					case Value.String(s):
						getStringProp(s, name);
					case Value.Array(a):
						getArrayProp(a, name);
					default:
						throw new RuntimeError('Cannot access property "${name.lexeme}" on ${obj.typeName()}', name.line);
				}

			case ESet(objExpr, name, valExpr):
				var obj = evaluate(objExpr);
				var v   = evaluate(valExpr);
				switch obj {
					case Value.Instance(i): i.set(name, v);
					case Value.Map(m):      m.set(name.lexeme, v);
					default: throw new RuntimeError('Cannot set property "${name.lexeme}" on ${obj.typeName()}', name.line);
				}
				v;

			case EAssignField(objExpr, name, valExpr):
				var obj = evaluate(objExpr);
				var v   = evaluate(valExpr);
				switch obj {
					case Value.Instance(i): i.set(name, v);
					default: throw new RuntimeError('Cannot set field "${name.lexeme}" on ${obj.typeName()}', name.line);
				}
				v;

			case EIndex(objExpr, idxExpr):
				var obj = evaluate(objExpr);
				var idx = evaluate(idxExpr);
				switch [obj, idx] {
					case [Value.Array(a), Value.Number(n)]:
						var i = Std.int(n);
						if (i < 0 || i >= a.length)
							throw new RuntimeError('Array index $i out of bounds (length ${a.length})');
						a[i];
					case [Value.Map(m), Value.String(k)]:
						m.exists(k) ? m.get(k) : Null;
					case [Value.String(s), Value.Number(n)]:
						Value.String(s.charAt(Std.int(n)));
					default:
						throw new RuntimeError('Cannot index ${obj.typeName()} with ${idx.typeName()}');
				}

			case EAssignIndex(objExpr, idxExpr, valExpr):
				var obj = evaluate(objExpr);
				var idx = evaluate(idxExpr);
				var v   = evaluate(valExpr);
				switch [obj, idx] {
					case [Value.Array(a), Value.Number(n)]:
						var i = Std.int(n);
						if (i < 0 || i >= a.length)
							throw new RuntimeError('Array index $i out of bounds');
						a[i] = v;
					case [Value.Map(m), Value.String(k)]:
						m.set(k, v);
					default:
						throw new RuntimeError('Cannot assign index on ${obj.typeName()}');
				}
				v;

			case EArrayLit(elems):
				Value.Array(elems.map(e -> evaluate(e)));

			case EMapLit(keys, vals):
				var m = new StringMap<Value>();
				for (i in 0...keys.length) m.set(keys[i], evaluate(vals[i]));
				Value.Map(m);

			case ELambda(params, body):
				Value.Function(new DScriptFunction("<lambda>", params, body, environment));

			case ESelf(keyword):
				var v = environment.getByName("self");
				if (v == null)
					throw new RuntimeError("'self' is not defined in this context", keyword.line);
				v;

			case ESuper(keyword, method):
				var superVal = environment.getByName("super");
				var selfVal  = environment.getByName("self");
				switch [superVal, selfVal] {
					case [Value.Class(cls), Value.Instance(inst)]:
						var fn = cls.findMethod(method.lexeme);
						if (fn == null)
							throw new RuntimeError('Undefined super method "${method.lexeme}"', method.line);
						Value.Function(fn.bind(inst));
					default:
						throw new RuntimeError("Invalid 'super' reference", keyword.line);
				}
		}
	}

	function applyBinary(op:Token, left:Value, right:Value):Value {
		return switch op.type {
			case TkPlus:
				switch [left, right] {
					case [Value.Number(a), Value.Number(b)]: Value.Number(a + b);
					case [Value.String(a), Value.String(b)]: Value.String(a + b);
					case [Value.String(a), _]:               Value.String(a + right.toString());
					case [_, Value.String(b)]:               Value.String(left.toString() + b);
					default: throw new RuntimeError("Operands must be numbers or strings for '+'", op.line);
				}
			case TkMinus:   numOp(op, left, right, (a, b) -> a - b);
			case TkStar:    numOp(op, left, right, (a, b) -> a * b);
			case TkPercent: numOp(op, left, right, (a, b) -> a % b);
			case TkSlash:
				switch [left, right] {
					case [Value.Number(a), Value.Number(b)]:
						if (b == 0) throw new RuntimeError("Division by zero", op.line);
						Value.Number(a / b);
					default: throw new RuntimeError("Operands must be numbers for '/'", op.line);
				}
			case TkEqEq:  Value.Bool(left.equals(right));
			case TkBangEq: Value.Bool(!left.equals(right));
			case TkLt:    numCmp(op, left, right, (a, b) -> a < b);
			case TkLtEq:  numCmp(op, left, right, (a, b) -> a <= b);
			case TkGt:    numCmp(op, left, right, (a, b) -> a > b);
			case TkGtEq:  numCmp(op, left, right, (a, b) -> a >= b);
			default: throw new RuntimeError('Unknown binary operator "${op.lexeme}"', op.line);
		};
	}

	function applyUnary(op:Token, right:Value):Value {
		return switch op.type {
			case TkMinus:
				switch right {
					case Value.Number(n): Value.Number(-n);
					default: throw new RuntimeError("Operand must be a number for unary '-'", op.line);
				}
			case TkBang: Value.Bool(!right.isTruthy());
			default: throw new RuntimeError('Unknown unary operator "${op.lexeme}"', op.line);
		};
	}

	function applyArith(op:Token, current:Value, right:Value):Value {
		var synth = switch op.type {
			case TkPlusEq:  new Token(TkPlus,  "+", op.line);
			case TkMinusEq: new Token(TkMinus, "-", op.line);
			case TkStarEq:  new Token(TkStar,  "*", op.line);
			case TkSlashEq: new Token(TkSlash, "/", op.line);
			default: throw new RuntimeError('Unknown compound operator "${op.lexeme}"', op.line);
		};
		return applyBinary(synth, current, right);
	}

	function getStringProp(s:String, name:Token):Value {
		return switch name.lexeme {
			case "length":     Value.Number(s.length);
			case "upper":      Value.Native(_ -> Value.String(s.toUpperCase()));
			case "lower":      Value.Native(_ -> Value.String(s.toLowerCase()));
			case "trim":       Value.Native(_ -> Value.String(StringTools.trim(s)));
			case "split":      Value.Native(args -> {
				var delim = switch args[0] { case Value.String(d): d; default: ""; };
				Value.Array(s.split(delim).map(p -> Value.String(p)));
			});
			case "contains":   Value.Native(args -> {
				var sub = switch args[0] { case Value.String(d): d; default: args[0].toString(); };
				Value.Bool(s.indexOf(sub) >= 0);
			});
			case "startsWith": Value.Native(args -> {
				var p = switch args[0] { case Value.String(d): d; default: args[0].toString(); };
				Value.Bool(StringTools.startsWith(s, p));
			});
			case "endsWith":   Value.Native(args -> {
				var p = switch args[0] { case Value.String(d): d; default: args[0].toString(); };
				Value.Bool(StringTools.endsWith(s, p));
			});
			case "replace":    Value.Native(args -> {
				var from = switch args[0] { case Value.String(d): d; default: args[0].toString(); };
				var to   = switch args[1] { case Value.String(d): d; default: args[1].toString(); };
				Value.String(StringTools.replace(s, from, to));
			});
			case "indexOf":    Value.Native(args -> {
				var sub = switch args[0] { case Value.String(d): d; default: args[0].toString(); };
				Value.Number(s.indexOf(sub));
			});
			case "charAt":     Value.Native(args -> {
				var i = switch args[0] { case Value.Number(n): Std.int(n); default: 0; };
				Value.String(s.charAt(i));
			});
			case "substr":     Value.Native(args -> {
				var start = switch args[0] { case Value.Number(n): Std.int(n); default: 0; };
				var len   = switch args[1] { case Value.Number(n): Std.int(n); default: s.length; };
				Value.String(s.substr(start, len));
			});
			default: throw new RuntimeError('String has no property "${name.lexeme}"', name.line);
		};
	}

	function getArrayProp(a:Array<Value>, name:Token):Value {
		return switch name.lexeme {
			case "length":  Value.Number(a.length);
			case "push":    Value.Native(args -> { a.push(args[0]); Null; });
			case "pop":     Value.Native(_ -> a.length > 0 ? a.pop() : Null);
			case "shift":   Value.Native(_ -> a.length > 0 ? a.shift() : Null);
			case "unshift": Value.Native(args -> { a.unshift(args[0]); Null; });
			case "reverse": Value.Native(_ -> { var c = a.copy(); c.reverse(); Value.Array(c); });
			case "join":    Value.Native(args -> {
				var sep = switch args[0] { case Value.String(s): s; default: ","; };
				Value.String(a.map(v -> v.toString()).join(sep));
			});
			case "slice":   Value.Native(args -> {
				var s = switch args[0] { case Value.Number(n): Std.int(n); default: 0; };
				var e = switch args[1] { case Value.Number(n): Std.int(n); default: a.length; };
				Value.Array(a.slice(s, e));
			});
			case "indexOf": Value.Native(args -> Value.Number(a.findIndex(v -> v.equals(args[0]))));
			case "contains": Value.Native(args -> Value.Bool(a.exists(v -> v.equals(args[0]))));
			case "map":     Value.Native(args -> Value.Array(a.map(v -> callValue(args[0], [v]))));
			case "filter":  Value.Native(args -> Value.Array(a.filter(v -> callValue(args[0], [v]).isTruthy())));
			case "reduce":  Value.Native(args -> {
				var acc = args[1];
				for (v in a) acc = callValue(args[0], [acc, v]);
				acc;
			});
			case "forEach": Value.Native(args -> {
				for (v in a) callValue(args[0], [v]);
				Null;
			});
			case "sort":    Value.Native(args -> {
				var c = a.copy();
				if (args.length > 0 && args[0].isCallable()) {
					c.sort((x, y) -> switch callValue(args[0], [x, y]) {
						case Value.Number(n): Std.int(n);
						default: 0;
					});
				} else {
					c.sort((x, y) -> Reflect.compare(x.toString(), y.toString()));
				}
				Value.Array(c);
			});
			default: throw new RuntimeError('Array has no property "${name.lexeme}"', name.line);
		};
	}

	function wrapError(e:DScriptError):DScriptInstance {
		var cls  = new DScriptClass("Error", null, new StringMap());
		var inst = new DScriptInstance(cls);
		inst.setField("message", Value.String(e.message));
		inst.setField("line",    Value.Number(e.line));
		return inst;
	}

	function wrapMessage(msg:String):DScriptInstance {
		var cls  = new DScriptClass("Error", null, new StringMap());
		var inst = new DScriptInstance(cls);
		inst.setField("message", Value.String(msg));
		inst.setField("line",    Value.Number(0));
		return inst;
	}

	inline function numOp(op:Token, l:Value, r:Value, fn:Float -> Float -> Float):Value {
		return switch [l, r] {
			case [Value.Number(a), Value.Number(b)]: Value.Number(fn(a, b));
			default: throw new RuntimeError('Operands must be numbers for "${op.lexeme}"', op.line);
		};
	}

	inline function numCmp(op:Token, l:Value, r:Value, fn:Float -> Float -> Bool):Value {
		return switch [l, r] {
			case [Value.Number(a), Value.Number(b)]: Value.Bool(fn(a, b));
			default: throw new RuntimeError('Operands must be numbers for "${op.lexeme}"', op.line);
		};
	}
}
