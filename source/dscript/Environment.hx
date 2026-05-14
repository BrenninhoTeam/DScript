package dscript;

class Environment {
	public var parent:Null<Environment>;

	var values:Map<String, Value> = new Map();

	public function new(?parent:Environment) {
		this.parent = parent;
	}

	public function define(name:String, value:Value):Void {
		values.set(name, value);
	}

	public function get(name:Token):Value {
		if (values.exists(name.lexeme))
			return values.get(name.lexeme);
		if (parent != null)
			return parent.get(name);
		throw new DScriptError('Undefined variable "${name.lexeme}"', name.line);
	}

	public function getByName(name:String):Null<Value> {
		if (values.exists(name))
			return values.get(name);
		if (parent != null)
			return parent.getByName(name);
		return null;
	}

	public function getAt(distance:Int, name:String):Value {
		var v = ancestor(distance).values.get(name);
		return v != null ? v : Null;
	}

	public function assign(name:Token, value:Value):Void {
		if (values.exists(name.lexeme)) {
			values.set(name.lexeme, value);
			return;
		}
		if (parent != null) {
			parent.assign(name, value);
			return;
		}
		throw new DScriptError('Undefined variable "${name.lexeme}"', name.line);
	}

	public function assignAt(distance:Int, name:String, value:Value):Void {
		ancestor(distance).values.set(name, value);
	}

	public function assignByName(name:String, value:Value):Bool {
		if (values.exists(name)) {
			values.set(name, value);
			return true;
		}
		if (parent != null)
			return parent.assignByName(name, value);
		return false;
	}

	public function has(name:String):Bool {
		if (values.exists(name)) return true;
		if (parent != null) return parent.has(name);
		return false;
	}

	function ancestor(distance:Int):Environment {
		var env:Environment = this;
		for (_ in 0...distance) {
			if (env.parent == null)
				throw new RuntimeError("Environment ancestor out of range");
			env = env.parent;
		}
		return env;
	}
}
