package;

import dscript.Interpreter;
import dscript.Environment;
import dscript.Value;
import dscript.Error;
import sys.io.File;
import sys.FileSystem;

class Main {

	static var interpreter:Interpreter;

	static function main():Void {
		interpreter = new Interpreter();
		registerAll(interpreter);

		var args = Sys.args();

		if (args.length == 0) {
			startRepl();
			return;
		}

		var command = args[0];

		switch command {
			case "run":
				if (args.length < 2) {
					Sys.stderr().writeString("[DScript] Usage: dscript run <file.ds>\n");
					Sys.exit(1);
				}
				runFile(args[1]);

			case "repl":
				startRepl();

			case "check":
				if (args.length < 2) {
					Sys.stderr().writeString("[DScript] Usage: dscript check <file.ds>\n");
					Sys.exit(1);
				}
				checkFile(args[1]);

			case "version":
				Sys.println("DScript 0.1.0 (Haxe " + haxe.macro.Compiler.getDefine("haxe") + ")");

			case "help" | "--help" | "-h":
				printHelp();

			default:
				Sys.stderr().writeString('[DScript] Unknown command: $command\n');
				printHelp();
				Sys.exit(1);
		}
	}

	static function runFile(path:String):Void {
		if (!FileSystem.exists(path)) {
			Sys.stderr().writeString('[DScript] File not found: $path\n');
			Sys.exit(1);
		}

		var source = File.getContent(path);

		try {
			interpreter.run(source);
		} catch (e:DScriptError) {
			Sys.stderr().writeString('[DScript] ${e.toString()}\n');
			Sys.exit(1);
		}
	}

	static function checkFile(path:String):Void {
		if (!FileSystem.exists(path)) {
			Sys.stderr().writeString('[DScript] File not found: $path\n');
			Sys.exit(1);
		}

		var source = File.getContent(path);

		try {
			interpreter.check(source);
			Sys.println('[DScript] $path — OK');
		} catch (e:DScriptError) {
			Sys.stderr().writeString('[DScript] ${e.toString()}\n');
			Sys.exit(1);
		}
	}

	static function startRepl():Void {
		Sys.println("DScript 0.1.0  |  type 'exit' to quit");
		Sys.println("--------------------------------------");

		var stdin = Sys.stdin();

		while (true) {
			Sys.print(">> ");

			var line = stdin.readLine();

			if (line == null || line == "exit" || line == "quit") {
				Sys.println("Bye.");
				break;
			}

			if (line.trim() == "") continue;

			try {
				var result = interpreter.eval(line);
				if (!result.isNull()) Sys.println(result.toString());
			} catch (e:DScriptError) {
				Sys.stderr().writeString('[DScript] ${e.toString()}\n');
			}
		}
	}

	static function printHelp():Void {
		Sys.println("DScript 0.1.0");
		Sys.println("");
		Sys.println("USAGE:");
		Sys.println("  dscript <command> [options]");
		Sys.println("");
		Sys.println("COMMANDS:");
		Sys.println("  run <file.ds>    Execute a DScript source file");
		Sys.println("  repl             Start an interactive REPL session");
		Sys.println("  check <file.ds>  Check syntax without executing");
		Sys.println("  version          Print version information");
		Sys.println("  help             Show this help message");
	}

	static function registerAll(i:Interpreter):Void {
		registerIO(i);
		registerMath(i);
		registerString(i);
		registerArray(i);
		registerMap(i);
		registerJson(i);
		registerSys(i);
		registerType(i);
	}

	static function registerIO(i:Interpreter):Void {
		i.bind("println", function(args:Array<Value>) {
			Sys.println(args.length > 0 ? args[0].toString() : "");
			return Value.Null;
		});

		i.bind("print", function(args:Array<Value>) {
			Sys.print(args.length > 0 ? args[0].toString() : "");
			return Value.Null;
		});

		i.bind("readLine", function(args:Array<Value>) {
			var line = Sys.stdin().readLine();
			return Value.String(line);
		});

		i.bind("readFile", function(args:Array<Value>) {
			requireArgs("readFile", args, 1);
			var path = expectString("readFile", args[0]);
			if (!FileSystem.exists(path))
				throw new DScriptError('readFile: file not found: $path');
			return Value.String(File.getContent(path));
		});

		i.bind("writeFile", function(args:Array<Value>) {
			requireArgs("writeFile", args, 2);
			var path    = expectString("writeFile", args[0]);
			var content = expectString("writeFile", args[1]);
			File.saveContent(path, content);
			return Value.Null;
		});

		i.bind("appendFile", function(args:Array<Value>) {
			requireArgs("appendFile", args, 2);
			var path    = expectString("appendFile", args[0]);
			var content = expectString("appendFile", args[1]);
			var out = File.append(path, false);
			out.writeString(content);
			out.close();
			return Value.Null;
		});

		i.bind("fileExists", function(args:Array<Value>) {
			requireArgs("fileExists", args, 1);
			var path = expectString("fileExists", args[0]);
			return Value.Bool(FileSystem.exists(path));
		});

		i.bind("deleteFile", function(args:Array<Value>) {
			requireArgs("deleteFile", args, 1);
			var path = expectString("deleteFile", args[0]);
			if (FileSystem.exists(path)) FileSystem.deleteFile(path);
			return Value.Null;
		});
	}

	static function registerMath(i:Interpreter):Void {
		i.bind("abs", function(args:Array<Value>) {
			requireArgs("abs", args, 1);
			return Value.Number(Math.abs(expectNumber("abs", args[0])));
		});

		i.bind("floor", function(args:Array<Value>) {
			requireArgs("floor", args, 1);
			return Value.Number(Math.floor(expectNumber("floor", args[0])));
		});

		i.bind("ceil", function(args:Array<Value>) {
			requireArgs("ceil", args, 1);
			return Value.Number(Math.ceil(expectNumber("ceil", args[0])));
		});

		i.bind("round", function(args:Array<Value>) {
			requireArgs("round", args, 1);
			return Value.Number(Math.round(expectNumber("round", args[0])));
		});

		i.bind("sqrt", function(args:Array<Value>) {
			requireArgs("sqrt", args, 1);
			return Value.Number(Math.sqrt(expectNumber("sqrt", args[0])));
		});

		i.bind("pow", function(args:Array<Value>) {
			requireArgs("pow", args, 2);
			var base = expectNumber("pow", args[0]);
			var exp  = expectNumber("pow", args[1]);
			return Value.Number(Math.pow(base, exp));
		});

		i.bind("sin", function(args:Array<Value>) {
			requireArgs("sin", args, 1);
			return Value.Number(Math.sin(expectNumber("sin", args[0])));
		});

		i.bind("cos", function(args:Array<Value>) {
			requireArgs("cos", args, 1);
			return Value.Number(Math.cos(expectNumber("cos", args[0])));
		});

		i.bind("tan", function(args:Array<Value>) {
			requireArgs("tan", args, 1);
			return Value.Number(Math.tan(expectNumber("tan", args[0])));
		});

		i.bind("log", function(args:Array<Value>) {
			requireArgs("log", args, 1);
			return Value.Number(Math.log(expectNumber("log", args[0])));
		});

		i.bind("min", function(args:Array<Value>) {
			requireArgs("min", args, 2);
			return Value.Number(Math.min(expectNumber("min", args[0]), expectNumber("min", args[1])));
		});

		i.bind("max", function(args:Array<Value>) {
			requireArgs("max", args, 2);
			return Value.Number(Math.max(expectNumber("max", args[0]), expectNumber("max", args[1])));
		});

		i.bind("random", function(args:Array<Value>) {
			return Value.Number(Math.random());
		});

		i.bind("randomInt", function(args:Array<Value>) {
			requireArgs("randomInt", args, 2);
			var min = Std.int(expectNumber("randomInt", args[0]));
			var max = Std.int(expectNumber("randomInt", args[1]));
			return Value.Number(min + Std.int(Math.random() * (max - min + 1)));
		});

		i.bind("PI",  Value.Number(Math.PI));
		i.bind("E",   Value.Number(Math.exp(1)));
		i.bind("INF", Value.Number(Math.POSITIVE_INFINITY));
		i.bind("NAN", Value.Number(Math.NaN));
	}

	static function registerString(i:Interpreter):Void {
		i.bind("strLen", function(args:Array<Value>) {
			requireArgs("strLen", args, 1);
			return Value.Number(expectString("strLen", args[0]).length);
		});

		i.bind("strUpper", function(args:Array<Value>) {
			requireArgs("strUpper", args, 1);
			return Value.String(expectString("strUpper", args[0]).toUpperCase());
		});

		i.bind("strLower", function(args:Array<Value>) {
			requireArgs("strLower", args, 1);
			return Value.String(expectString("strLower", args[0]).toLowerCase());
		});

		i.bind("strTrim", function(args:Array<Value>) {
			requireArgs("strTrim", args, 1);
			return Value.String(StringTools.trim(expectString("strTrim", args[0])));
		});

		i.bind("strSplit", function(args:Array<Value>) {
			requireArgs("strSplit", args, 2);
			var str   = expectString("strSplit", args[0]);
			var delim = expectString("strSplit", args[1]);
			var parts = str.split(delim);
			return Value.Array(parts.map(p -> Value.String(p)));
		});

		i.bind("strJoin", function(args:Array<Value>) {
			requireArgs("strJoin", args, 2);
			var arr   = expectArray("strJoin", args[0]);
			var delim = expectString("strJoin", args[1]);
			return Value.String(arr.map(v -> v.toString()).join(delim));
		});

		i.bind("strContains", function(args:Array<Value>) {
			requireArgs("strContains", args, 2);
			var str = expectString("strContains", args[0]);
			var sub = expectString("strContains", args[1]);
			return Value.Bool(str.indexOf(sub) >= 0);
		});

		i.bind("strStartsWith", function(args:Array<Value>) {
			requireArgs("strStartsWith", args, 2);
			var str    = expectString("strStartsWith", args[0]);
			var prefix = expectString("strStartsWith", args[1]);
			return Value.Bool(StringTools.startsWith(str, prefix));
		});

		i.bind("strEndsWith", function(args:Array<Value>) {
			requireArgs("strEndsWith", args, 2);
			var str    = expectString("strEndsWith", args[0]);
			var suffix = expectString("strEndsWith", args[1]);
			return Value.Bool(StringTools.endsWith(str, suffix));
		});

		i.bind("strReplace", function(args:Array<Value>) {
			requireArgs("strReplace", args, 3);
			var str     = expectString("strReplace", args[0]);
			var search  = expectString("strReplace", args[1]);
			var replace = expectString("strReplace", args[2]);
			return Value.String(StringTools.replace(str, search, replace));
		});

		i.bind("strIndexOf", function(args:Array<Value>) {
			requireArgs("strIndexOf", args, 2);
			var str = expectString("strIndexOf", args[0]);
			var sub = expectString("strIndexOf", args[1]);
			return Value.Number(str.indexOf(sub));
		});

		i.bind("strSubstr", function(args:Array<Value>) {
			requireArgs("strSubstr", args, 3);
			var str   = expectString("strSubstr", args[0]);
			var start = Std.int(expectNumber("strSubstr", args[1]));
			var len   = Std.int(expectNumber("strSubstr", args[2]));
			return Value.String(str.substr(start, len));
		});

		i.bind("strCharAt", function(args:Array<Value>) {
			requireArgs("strCharAt", args, 2);
			var str   = expectString("strCharAt", args[0]);
			var index = Std.int(expectNumber("strCharAt", args[1]));
			return Value.String(str.charAt(index));
		});

		i.bind("strCharCode", function(args:Array<Value>) {
			requireArgs("strCharCode", args, 2);
			var str   = expectString("strCharCode", args[0]);
			var index = Std.int(expectNumber("strCharCode", args[1]));
			return Value.Number(str.charCodeAt(index));
		});

		i.bind("strFromCode", function(args:Array<Value>) {
			requireArgs("strFromCode", args, 1);
			var code = Std.int(expectNumber("strFromCode", args[0]));
			return Value.String(String.fromCharCode(code));
		});

		i.bind("strRepeat", function(args:Array<Value>) {
			requireArgs("strRepeat", args, 2);
			var str   = expectString("strRepeat", args[0]);
			var times = Std.int(expectNumber("strRepeat", args[1]));
			var buf   = new StringBuf();
			for (_ in 0...times) buf.add(str);
			return Value.String(buf.toString());
		});
	}

	static function registerArray(i:Interpreter):Void {
		i.bind("len", function(args:Array<Value>) {
			requireArgs("len", args, 1);
			return Value.Number(expectArray("len", args[0]).length);
		});

		i.bind("push", function(args:Array<Value>) {
			requireArgs("push", args, 2);
			expectArray("push", args[0]).push(args[1]);
			return Value.Null;
		});

		i.bind("pop", function(args:Array<Value>) {
			requireArgs("pop", args, 1);
			var arr = expectArray("pop", args[0]);
			return arr.length > 0 ? arr.pop() : Value.Null;
		});

		i.bind("shift", function(args:Array<Value>) {
			requireArgs("shift", args, 1);
			var arr = expectArray("shift", args[0]);
			return arr.length > 0 ? arr.shift() : Value.Null;
		});

		i.bind("unshift", function(args:Array<Value>) {
			requireArgs("unshift", args, 2);
			expectArray("unshift", args[0]).unshift(args[1]);
			return Value.Null;
		});

		i.bind("arrGet", function(args:Array<Value>) {
			requireArgs("arrGet", args, 2);
			var arr   = expectArray("arrGet", args[0]);
			var index = Std.int(expectNumber("arrGet", args[1]));
			if (index < 0 || index >= arr.length)
				throw new DScriptError('arrGet: index $index out of bounds (length ${arr.length})');
			return arr[index];
		});

		i.bind("arrSet", function(args:Array<Value>) {
			requireArgs("arrSet", args, 3);
			var arr   = expectArray("arrSet", args[0]);
			var index = Std.int(expectNumber("arrSet", args[1]));
			if (index < 0 || index >= arr.length)
				throw new DScriptError('arrSet: index $index out of bounds (length ${arr.length})');
			arr[index] = args[2];
			return Value.Null;
		});

		i.bind("arrSlice", function(args:Array<Value>) {
			requireArgs("arrSlice", args, 3);
			var arr   = expectArray("arrSlice", args[0]);
			var start = Std.int(expectNumber("arrSlice", args[1]));
			var end_  = Std.int(expectNumber("arrSlice", args[2]));
			return Value.Array(arr.slice(start, end_));
		});

		i.bind("arrConcat", function(args:Array<Value>) {
			requireArgs("arrConcat", args, 2);
			var a = expectArray("arrConcat", args[0]);
			var b = expectArray("arrConcat", args[1]);
			return Value.Array(a.concat(b));
		});

		i.bind("arrReverse", function(args:Array<Value>) {
			requireArgs("arrReverse", args, 1);
			var arr  = expectArray("arrReverse", args[0]).copy();
			arr.reverse();
			return Value.Array(arr);
		});

		i.bind("arrContains", function(args:Array<Value>) {
			requireArgs("arrContains", args, 2);
			var arr = expectArray("arrContains", args[0]);
			return Value.Bool(arr.exists(v -> v.equals(args[1])));
		});

		i.bind("arrIndexOf", function(args:Array<Value>) {
			requireArgs("arrIndexOf", args, 2);
			var arr = expectArray("arrIndexOf", args[0]);
			return Value.Number(arr.findIndex(v -> v.equals(args[1])));
		});

		i.bind("arrMap", function(args:Array<Value>) {
			requireArgs("arrMap", args, 2);
			var arr = expectArray("arrMap", args[0]);
			var fn  = expectCallable("arrMap", args[1]);
			return Value.Array(arr.map(v -> interpreter.callValue(fn, [v])));
		});

		i.bind("arrFilter", function(args:Array<Value>) {
			requireArgs("arrFilter", args, 2);
			var arr = expectArray("arrFilter", args[0]);
			var fn  = expectCallable("arrFilter", args[1]);
			return Value.Array(arr.filter(v -> interpreter.callValue(fn, [v]).isTruthy()));
		});

		i.bind("arrReduce", function(args:Array<Value>) {
			requireArgs("arrReduce", args, 3);
			var arr  = expectArray("arrReduce", args[0]);
			var fn   = expectCallable("arrReduce", args[1]);
			var acc  = args[2];
			for (v in arr) acc = interpreter.callValue(fn, [acc, v]);
			return acc;
		});

		i.bind("arrSort", function(args:Array<Value>) {
			requireArgs("arrSort", args, 1);
			var arr = expectArray("arrSort", args[0]).copy();
			if (args.length >= 2) {
				var fn = expectCallable("arrSort", args[1]);
				arr.sort((a, b) -> {
					var r = interpreter.callValue(fn, [a, b]);
					return Std.int(expectNumber("arrSort comparator", r));
				});
			} else {
				arr.sort((a, b) -> Reflect.compare(a.toString(), b.toString()));
			}
			return Value.Array(arr);
		});

		i.bind("arrFlat", function(args:Array<Value>) {
			requireArgs("arrFlat", args, 1);
			var arr    = expectArray("arrFlat", args[0]);
			var result = new Array<Value>();
			for (v in arr) {
				switch v {
					case Value.Array(inner): for (item in inner) result.push(item);
					default: result.push(v);
				}
			}
			return Value.Array(result);
		});

		i.bind("range", function(args:Array<Value>) {
			requireArgs("range", args, 2);
			var from = Std.int(expectNumber("range", args[0]));
			var to   = Std.int(expectNumber("range", args[1]));
			var step = args.length >= 3 ? Std.int(expectNumber("range", args[2])) : 1;
			var result = new Array<Value>();
			var n = from;
			while (n < to) {
				result.push(Value.Number(n));
				n += step;
			}
			return Value.Array(result);
		});
	}

	static function registerMap(i:Interpreter):Void {
		i.bind("mapGet", function(args:Array<Value>) {
			requireArgs("mapGet", args, 2);
			var map = expectMap("mapGet", args[0]);
			var key = expectString("mapGet", args[1]);
			return map.exists(key) ? map.get(key) : Value.Null;
		});

		i.bind("mapSet", function(args:Array<Value>) {
			requireArgs("mapSet", args, 3);
			var map = expectMap("mapSet", args[0]);
			var key = expectString("mapSet", args[1]);
			map.set(key, args[2]);
			return Value.Null;
		});

		i.bind("mapHas", function(args:Array<Value>) {
			requireArgs("mapHas", args, 2);
			var map = expectMap("mapHas", args[0]);
			var key = expectString("mapHas", args[1]);
			return Value.Bool(map.exists(key));
		});

		i.bind("mapRemove", function(args:Array<Value>) {
			requireArgs("mapRemove", args, 2);
			var map = expectMap("mapRemove", args[0]);
			var key = expectString("mapRemove", args[1]);
			map.remove(key);
			return Value.Null;
		});

		i.bind("mapKeys", function(args:Array<Value>) {
			requireArgs("mapKeys", args, 1);
			var map = expectMap("mapKeys", args[0]);
			return Value.Array([for (k in map.keys()) Value.String(k)]);
		});

		i.bind("mapValues", function(args:Array<Value>) {
			requireArgs("mapValues", args, 1);
			var map = expectMap("mapValues", args[0]);
			return Value.Array([for (v in map) v]);
		});

		i.bind("mapSize", function(args:Array<Value>) {
			requireArgs("mapSize", args, 1);
			var map = expectMap("mapSize", args[0]);
			var count = 0;
			for (_ in map) count++;
			return Value.Number(count);
		});
	}

	static function registerJson(i:Interpreter):Void {
		i.bind("jsonParse", function(args:Array<Value>) {
			requireArgs("jsonParse", args, 1);
			var raw = expectString("jsonParse", args[0]);
			try {
				var parsed = haxe.Json.parse(raw);
				return Value.fromDynamic(parsed);
			} catch (e:Dynamic) {
				throw new DScriptError("jsonParse: invalid JSON — " + Std.string(e));
			}
		});

		i.bind("jsonStringify", function(args:Array<Value>) {
			requireArgs("jsonStringify", args, 1);
			return Value.String(haxe.Json.stringify(args[0].toDynamic()));
		});
	}

	static function registerSys(i:Interpreter):Void {
		i.bind("time", function(args:Array<Value>) {
			return Value.Number(Sys.time());
		});

		i.bind("exit", function(args:Array<Value>) {
			var code = args.length > 0 ? Std.int(expectNumber("exit", args[0])) : 0;
			Sys.exit(code);
			return Value.Null;
		});

		i.bind("env", function(args:Array<Value>) {
			requireArgs("env", args, 1);
			var key = expectString("env", args[0]);
			var val = Sys.getEnv(key);
			return val != null ? Value.String(val) : Value.Null;
		});

		i.bind("args", function(args:Array<Value>) {
			return Value.Array(Sys.args().map(a -> Value.String(a)));
		});

		i.bind("sleep", function(args:Array<Value>) {
			requireArgs("sleep", args, 1);
			var ms = expectNumber("sleep", args[0]);
			Sys.sleep(ms / 1000.0);
			return Value.Null;
		});

		i.bind("cwd", function(args:Array<Value>) {
			return Value.String(Sys.getCwd());
		});
	}

	static function registerType(i:Interpreter):Void {
		i.bind("typeOf", function(args:Array<Value>) {
			requireArgs("typeOf", args, 1);
			return Value.String(args[0].typeName());
		});

		i.bind("isNull", function(args:Array<Value>) {
			requireArgs("isNull", args, 1);
			return Value.Bool(args[0].isNull());
		});

		i.bind("isString", function(args:Array<Value>) {
			requireArgs("isString", args, 1);
			return switch args[0] { case Value.String(_): Value.Bool(true); default: Value.Bool(false); };
		});

		i.bind("isNumber", function(args:Array<Value>) {
			requireArgs("isNumber", args, 1);
			return switch args[0] { case Value.Number(_): Value.Bool(true); default: Value.Bool(false); };
		});

		i.bind("isBool", function(args:Array<Value>) {
			requireArgs("isBool", args, 1);
			return switch args[0] { case Value.Bool(_): Value.Bool(true); default: Value.Bool(false); };
		});

		i.bind("isArray", function(args:Array<Value>) {
			requireArgs("isArray", args, 1);
			return switch args[0] { case Value.Array(_): Value.Bool(true); default: Value.Bool(false); };
		});

		i.bind("isCallable", function(args:Array<Value>) {
			requireArgs("isCallable", args, 1);
			return Value.Bool(args[0].isCallable());
		});

		i.bind("toNumber", function(args:Array<Value>) {
			requireArgs("toNumber", args, 1);
			return switch args[0] {
				case Value.Number(n): Value.Number(n);
				case Value.String(s):
					var n = Std.parseFloat(s);
					if (Math.isNaN(n)) throw new DScriptError('toNumber: cannot convert "$s" to number');
					Value.Number(n);
				case Value.Bool(b): Value.Number(b ? 1 : 0);
				default: throw new DScriptError("toNumber: unsupported type " + args[0].typeName());
			};
		});

		i.bind("toString", function(args:Array<Value>) {
			requireArgs("toString", args, 1);
			return Value.String(args[0].toString());
		});

		i.bind("toBool", function(args:Array<Value>) {
			requireArgs("toBool", args, 1);
			return Value.Bool(args[0].isTruthy());
		});
	}

	static inline function requireArgs(fn:String, args:Array<Value>, min:Int):Void {
		if (args.length < min)
			throw new DScriptError('$fn: expected $min argument(s), got ${args.length}');
	}

	static inline function expectNumber(fn:String, v:Value):Float {
		return switch v {
			case Value.Number(n): n;
			default: throw new DScriptError('$fn: expected number, got ${v.typeName()}');
		};
	}

	static inline function expectString(fn:String, v:Value):String {
		return switch v {
			case Value.String(s): s;
			default: throw new DScriptError('$fn: expected string, got ${v.typeName()}');
		};
	}

	static inline function expectArray(fn:String, v:Value):Array<Value> {
		return switch v {
			case Value.Array(a): a;
			default: throw new DScriptError('$fn: expected array, got ${v.typeName()}');
		};
	}

	static inline function expectMap(fn:String, v:Value):Map<String, Value> {
		return switch v {
			case Value.Map(m): m;
			default: throw new DScriptError('$fn: expected map, got ${v.typeName()}');
		};
	}

	static inline function expectCallable(fn:String, v:Value):Value {
		if (!v.isCallable())
			throw new DScriptError('$fn: expected callable, got ${v.typeName()}');
		return v;
	}
}
