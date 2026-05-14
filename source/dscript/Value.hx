package dscript;

import haxe.ds.StringMap;

@:using(dscript.ValueExt)
enum Value {
	Null;
	Bool(b:Bool);
	Number(n:Float);
	String(s:std.String);
	Array(a:std.Array<Value>);
	Map(m:StringMap<Value>);
	Function(fn:DScriptFunction);
	Native(fn:std.Array<Value> -> Value);
	Instance(inst:DScriptInstance);
	Class(cls:DScriptClass);
}

class ValueExt {
	public static function toString(v:Value):std.String {
		return switch v {
			case Null:          "null";
			case Bool(b):       b ? "true" : "false";
			case Number(n):
				if (n == Math.ffloor(n) && !Math.isNaN(n) && !Math.isFinite(n) == false)
					Std.string(Std.int(n));
				else
					Std.string(n);
			case String(s):     s;
			case Array(a):      "[" + a.map(x -> x.toString()).join(", ") + "]";
			case Map(m):
				var pairs = [for (k in m.keys()) '"$k": ${m.get(k).toString()}'];
				"{" + pairs.join(", ") + "}";
			case Function(fn):  fn.toString();
			case Native(_):     "<native fn>";
			case Instance(i):   i.toString();
			case Class(c):      c.toString();
		};
	}

	public static function typeName(v:Value):std.String {
		return switch v {
			case Null:        "null";
			case Bool(_):     "bool";
			case Number(_):   "number";
			case String(_):   "string";
			case Array(_):    "array";
			case Map(_):      "map";
			case Function(_): "function";
			case Native(_):   "function";
			case Instance(_): "instance";
			case Class(_):    "class";
		};
	}

	public static function isNull(v:Value):Bool {
		return switch v { case Null: true; default: false; };
	}

	public static function isTruthy(v:Value):Bool {
		return switch v {
			case Null:     false;
			case Bool(b):  b;
			case Number(n): n != 0 && !Math.isNaN(n);
			case String(s): s.length > 0;
			case Array(a):  a.length > 0;
			default:        true;
		};
	}

	public static function isCallable(v:Value):Bool {
		return switch v {
			case Function(_) | Native(_) | Class(_): true;
			default: false;
		};
	}

	public static function equals(v:Value, other:Value):Bool {
		return switch [v, other] {
			case [Null, Null]:             true;
			case [Bool(a), Bool(b)]:       a == b;
			case [Number(a), Number(b)]:   a == b;
			case [String(a), String(b)]:   a == b;
			case [Array(a), Array(b)]:
				if (a.length != b.length) false
				else {
					var eq = true;
					for (i in 0...a.length) if (!a[i].equals(b[i])) { eq = false; break; }
					eq;
				}
			case [Instance(a), Instance(b)]: a == b;
			case [Class(a), Class(b)]:       a == b;
			default: false;
		};
	}

	public static function toDynamic(v:Value):Dynamic {
		return switch v {
			case Null:        null;
			case Bool(b):     b;
			case Number(n):   n;
			case String(s):   s;
			case Array(a):    a.map(x -> x.toDynamic());
			case Map(m):
				var obj:Dynamic = {};
				for (k in m.keys()) Reflect.setField(obj, k, m.get(k).toDynamic());
				obj;
			default: null;
		};
	}

	public static function fromDynamic(d:Dynamic):Value {
		if (d == null) return Null;
		return switch Type.typeof(d) {
			case TBool:   Bool(d);
			case TInt:    Number(d);
			case TFloat:  Number(d);
			case TClass(String): Value.String(d);
			case TClass(Array):
				var arr:std.Array<Dynamic> = d;
				Value.Array(arr.map(x -> fromDynamic(x)));
			case TObject:
				var m = new StringMap<Value>();
				for (k in Reflect.fields(d)) m.set(k, fromDynamic(Reflect.field(d, k)));
				Value.Map(m);
			default: Null;
		};
	}
}
