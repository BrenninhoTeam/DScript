package dscript;

class DScriptError extends haxe.Exception {
	public var line:Int;
	public var column:Int;

	public function new(message:String, line:Int = 0, column:Int = 0) {
		super(message);
		this.line = line;
		this.column = column;
	}

	override public function toString():String {
		return line > 0 ? '[line $line] $message' : message;
	}
}

class ParseError extends DScriptError {
	public function new(message:String, line:Int = 0, column:Int = 0) {
		super(message, line, column);
	}
}

class RuntimeError extends DScriptError {
	public function new(message:String, line:Int = 0) {
		super(message, line);
	}
}

class ReturnSignal extends haxe.Exception {
	public var value:Value;

	public function new(value:Value) {
		super("__return__");
		this.value = value;
	}
}

class BreakSignal extends haxe.Exception {
	public function new() {
		super("__break__");
	}
}

class ContinueSignal extends haxe.Exception {
	public function new() {
		super("__continue__");
	}
}
