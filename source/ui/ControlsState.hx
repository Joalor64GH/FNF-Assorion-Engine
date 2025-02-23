package ui;

import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import misc.Alphabet;

/*
    Just a modified -
    Optionstate for controls
*/

#if !debug @:noDebug #end
class ControlsState extends MenuTemplate {
	var controlList:Array<String> = [
        'note_left',
        'note_down',
        'note_up',
        'note_right',
        '',
        'ui_left',
        'ui_down',
        'ui_up',
        'ui_right',
        '',
        'ui_accept',
        'ui_back'
    ];
    var rebinding:Bool = false;
    var dontCancel:Bool = false;

	override function create()
	{
        addBG(FlxColor.fromRGB(0,255,110));
        columns = 3;
		super.create();

		createNewList();
	}

	public function createNewList(){
		clearEverything();

		for(i in 0...controlList.length){
			pushObject(new Alphabet(0, (60 * i) + 30, controlList[i], true));

            var str:String = '';
            var s2r:String = '';

            if(controlList[i] != ''){
                var val:Dynamic = Reflect.field(Settings.pr, controlList[i]);
                str = misc.InputString.getKeyNameFromString(val[0], false, false);
                s2r = misc.InputString.getKeyNameFromString(val[1], false, false);
            }

			pushObject(new Alphabet(0, (60 * i) + 30, str, true));
			pushObject(new Alphabet(0, (60 * i) + 30, s2r, true));
		}

		changeSelection();
	}

    override function update(elasped:Float){
        super.update(elasped);

        if(!rebinding || !FlxG.keys.justPressed.ANY) return;
        if(dontCancel){
            dontCancel = false;
            return;
        }

        var k:Int = FlxG.keys.firstJustPressed();
        var original:Dynamic = Reflect.field(Settings.pr, controlList[curSel]);
            original[curAlt] = k;
        Reflect.setField(Settings.pr, '${controlList[curSel]}', original);

        rebinding = false;
        createNewList();

        trace(k);
    }

	override public function exitFunc(){
		if(NewTransition.skip())
            return;

        MusicBeatState.changeState(new OptionsState());
	}

    // Skip blank space
	override public function changeSelection(to:Int = 0){
		if(curSel + to >= 0 && controlList[curSel + to] == '')
			to *= 2;

		super.changeSelection(to);
	}

	override public function keyHit(ev:KeyboardEvent){
		if(rebinding) 
            return;

        super.keyHit(ev);

		if(!ev.keyCode.hardCheck(Binds.UI_ACCEPT) || controlList[curSel] == '') 
            return;

		for(i in 0...arrGroup.length)
			if(Math.floor(i / columns) != curSel)
				arrGroup[i].targetA = 0;

		dontCancel = true;
		rebinding = true;
		return;
	}
}
