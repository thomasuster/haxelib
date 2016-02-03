import Sys.*;
import haxe.*;
import sys.FileSystem.*;
import sys.io.File.*;

class RunCi {
	static function successMsg(msg:String):Void {
		Sys.println('\x1b[32m' + msg + '\x1b[0m');
	}
	static function failMsg(msg:String):Void {
		Sys.println('\x1b[31m' + msg + '\x1b[0m');
	}
	static function infoMsg(msg:String):Void {
		Sys.println('\x1b[36m' + msg + '\x1b[0m');
	}

	/**
		Run a command using `Sys.command()`.
		If the command exits with non-zero code, exit the whole script with the same code.

		If `useRetry` is `true`, the command will be re-run if it exits with non-zero code (3 trials).
		It is useful for running network-dependent commands.
	*/
	static function runCommand(cmd:String, ?args:Array<String>, useRetry:Bool = false):Void {
		var trials = useRetry ? 3 : 1;
		var exitCode:Int = 1;
		var cmdStr = cmd + (args != null ? ' $args' : '');

		while (trials-->0) {
			Sys.println("Command: " + cmdStr);

			var t = Timer.stamp();
			exitCode = Sys.command(cmd, args);
			var dt = Math.round(Timer.stamp() - t);

			if (exitCode == 0)
				successMsg('Command exited with $exitCode in ${dt}s: $cmdStr');
			else
				failMsg('Command exited with $exitCode in ${dt}s: $cmdStr');

			if (exitCode == 0) {
				return;
			} else if (trials > 0) {
				Sys.println('Command will be re-run...');
			}
		}

		Sys.exit(exitCode);
	}

	static function compileServer():Void {
		runCommand("haxelib", ["install", "newsite.hxml", "--always"]);
		runCommand("haxelib", ["install", "newsite_each.hxml", "--always"]);
		runCommand("haxelib", ["install", "newsite_test.hxml", "--always"]);
		runCommand("haxelib", ["list"]);
		runCommand("haxe", ["newsite.hxml"]);
	}

	static function compileLegacyServer():Void {
		runCommand("haxelib", ["install", "hx2compat"]);
		runCommand("haxe", ["legacysite.hxml"]);
	}

	static function compileClient():Void {
		runCommand("haxe", ["haxelib.hxml"]);
	}

	static function compileLegacyClient():Void {
		runCommand("haxe", ["legacyhaxelib.hxml"]);
	}

	static function testClient():Void {
		runCommand("haxe", ["test.hxml"]);
		runCommand("neko", ["bin/test.n"]);
	}

	static function testServer():Void {
		runCommand("haxe", ["newsite_test.hxml"]);
	}

	static function integrationTests():Void {
		runCommand("haxe", ["integration_tests.hxml"]);
		runCommand("haxe", ["integration_tests.hxml", "-D", "system_haxelib"]);
	}

	static function main():Void {
		compileLegacyClient();
		compileLegacyServer();
		compileClient();
		testClient();

		// the server can only be compiled with haxe 3.2.x for now...
		#if ((haxe_ver >= 3.2) && (haxe_ver < 3.3))
		compileServer();

		switch (Sys.systemName()) {
			case "Windows":
				// skip for now
				// The Neko 2.0 Windows binary archive is missing "msvcr71.dll", which is a dependency of "sqlite.ndll".
				// https://github.com/HaxeFoundation/haxe/issues/2008#issuecomment-176849497
			case _:
				testServer();
				integrationTests();
		}
		#end
	}
}