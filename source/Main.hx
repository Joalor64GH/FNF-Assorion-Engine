package;

import flixel.FlxGame;
import flixel.FlxState;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;

// tells haxe not to generate debugging info in the release build
// ofc if you compile it with debugging enabled it will still work
// but since this isn't very useful for release builds, we're gonna add this flag.

#if !debug
@:noDebug
#end
class Main extends Sprite
{
	public static var fpsC:ui.FPSCounter;
	public static var memC:ui.MemCounter;
	public static var initState:Class<FlxState> = ui.TitleState;

	// inlined. Which means these variables cannot be changed later.
	public static inline var gameWidth:Int  = 1280;
	public static inline var gameHeight:Int = 720;
	public static inline var initFPS:Int = 60;

	public static function changeUsefulInfo(yes:Bool){
		fpsC.visible = yes;
		memC.visible = yes;
	}

	public function new()
	{
		super();

		var zoom = ((Lib.current.stage.stageWidth / gameWidth) + (Lib.current.stage.stageHeight / gameHeight)) / 2;

		Settings.openSettings();

		// # add the game

		#if desktop
		if(Settings.pr.launch_sprites)
			initState = ui.CachingState;
		#end

		fpsC = new ui.FPSCounter(10, 3, 0xFFFFFF);
		memC = new ui.MemCounter(10, 18, 0xFFFFFF);
		addChild(new FlxGame(gameWidth, gameHeight, initState, 
			#if (flixel < "5.0.0") zoom, #end 
			initFPS, initFPS, Settings.pr.skip_logo, Settings.pr.start_fullscreen));

		addChild(fpsC);
		addChild(memC);

		#if (!desktop)
		flixel.FlxG.keys.preventDefaultKeys = [];
		Settings.pr.framerate = 60;
		#end
		// have to give credit for psych engine here.
		// Wouldn't have cared enough to fix this on my own.
		#if linux
		Lib.current.stage.window.setIcon(lime.graphics.Image.fromFile("assets/images/icon.png"));
		#end
		
		Settings.apply();
	}
}