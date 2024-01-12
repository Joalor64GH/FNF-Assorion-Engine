package misc;

import lime.utils.Assets;
import flixel.FlxG;
import flixel.FlxCamera;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.geom.Matrix;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.util.FlxColor;

using StringTools;

#if !debug @:noDebug #end
class CoolUtil
{
	// Change if adding a custom difficulty.
	public static inline var diffNumb:Int = 3;
	public static var diffArr:Array<String> = [
		// file names
		'-easy',
		'',
		'-hard',
		// formatted names.
		'Easy',
		'Normal',
		'Hard'
	];

	public static function diffString(diff:Int, mode:Int):String
		return diffArr[diff + (diffNumb * mode)];

	// Not clean, but it's faster.
	public static function boundTo(val:Float, min:Float, max:Float):Float
	{
		if(val < min) return min;
		if(val > max) return max;

		return val;
	}
	public static inline function intBoundTo(val:Float, min:Float, max:Float):Int
		return Math.round(boundTo(val, min, max));

	public inline static function cfArray(array:Array<Int>):Int
        return FlxColor.fromRGB(array[0], array[1], array[2]);

	// # Copy camera to bitmap data keeping rotation and zoom.
	// TODO: Increase accuracy. Some things are still not 1 to 1.

	public static function copyCameraToData(bitmapDat:BitmapData, camera:FlxCamera){
		var matr:Matrix = new Matrix(camera.zoom, 0, 0, camera.zoom, 0, 0);
			matr.translate(-(camera.width * 0.5), -(camera.height * 0.5));
			matr.rotate   (( camera.angle * Math.PI) / 180);
			matr.translate(  camera.width * 0.5, camera.height * 0.5);
			matr.translate(((camera.width * camera.zoom) - camera.width) * -0.5, ((camera.height * camera.zoom) - camera.height) * -0.5);

		bitmapDat.draw(camera.canvas, matr, null, null, null, true);
	}

	// Might remove this since it's used once.
	public inline static function browserLoad(site:String){
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		FlxG.openURL(site);
		#end
	}
}
