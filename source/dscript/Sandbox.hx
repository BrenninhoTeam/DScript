package dscript;

class Sandbox {
	var allowIO_:Bool     = true;
	var allowNet_:Bool    = true;
	var allowSys_:Bool    = true;
	var memoryLimit:Int   = 0;
	var callLimit:Int     = 0;
	var callCount:Int     = 0;
	var startTime:Float   = 0;
	var timeLimit:Float   = 0;

	public function new() {}

	public function allowIO(enabled:Bool):Sandbox {
		allowIO_ = enabled;
		return this;
	}

	public function allowNet(enabled:Bool):Sandbox {
		allowNet_ = enabled;
		return this;
	}

	public function allowSys(enabled:Bool):Sandbox {
		allowSys_ = enabled;
		return this;
	}

	public function setMemoryLimit(bytes:Int):Sandbox {
		memoryLimit = bytes;
		return this;
	}

	public function setCallLimit(maxCalls:Int):Sandbox {
		callLimit = maxCalls;
		return this;
	}

	public function setTimeLimit(seconds:Float):Sandbox {
		timeLimit  = seconds;
		startTime  = Sys.time();
		return this;
	}

	public function reset():Void {
		callCount = 0;
		startTime = Sys.time();
	}

	public function checkCall():Void {
		callCount++;

		if (callLimit > 0 && callCount > callLimit)
			throw new RuntimeError("Call limit exceeded ($callLimit)");

		if (timeLimit > 0 && (Sys.time() - startTime) > timeLimit)
			throw new RuntimeError("Execution time limit exceeded (${timeLimit}s)");
	}

	public function checkIO(operation:String):Void {
		if (!allowIO_)
			throw new RuntimeError('Sandbox: I/O operation "$operation" is not permitted');
	}

	public function checkNet(operation:String):Void {
		if (!allowNet_)
			throw new RuntimeError('Sandbox: network operation "$operation" is not permitted');
	}

	public function checkSys(operation:String):Void {
		if (!allowSys_)
			throw new RuntimeError('Sandbox: system operation "$operation" is not permitted');
	}

	public function isIOAllowed():Bool  return allowIO_;
	public function isNetAllowed():Bool return allowNet_;
	public function isSysAllowed():Bool return allowSys_;
}
