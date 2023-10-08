package gameplay;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.system.FlxSound;
import flixel.input.keyboard.FlxKey;
import flixel.group.FlxGroup.FlxTypedGroup;
import lime.utils.Assets;
import gameplay.HealthIcon;
import misc.Highscore;
import ui.FreeplayState;
import ui.ChartingState;
import misc.Song.SwagSong;
import misc.Song.SwagSection;

using StringTools;

#if !debug @:noDebug #end
class PlayState extends MusicBeatState
{
	public static inline var inputRange:Float = 1.25; // 1 = step. 1.5 = 1 + 1/4 step range.

	public static var curSong:String = '';
	public static var SONG:SwagSong;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var curDifficulty:Int = 1;
	public static var totalScore:Int = 0;

	public static var mustHitSection:Bool = false;
	public static var seenCutscene:Bool   = false;
	public var vocals:FlxSound;
	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var highestPossibleScore:Int = 0;

	public var strumLine:FlxObject;
	public var followPos:FlxObject;
	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;

	// health now goes from 0 - 100, instead of 0 - 2
	public var health   :Int = 50;
	public var combo    :Int = 0;
	public var hitCount :Int = 0;
	public var missCount:Int = 0;
	public var fcValue  :Int = 0;

	public var healthBarBG:FlxSprite;
	public var healthBar:HealthBar;
	public var paused:Bool = false;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;

	var songScore:Int = 0;
	var scoreTxt:FlxText;
	static var defaultCamZoom:Float = 1.05;

	private var characterPositions:Array<Int> = [
		// dad
		100, 100,
		//bf
		770,
		450,
		// gf
		400,
		130
	];
	private var playerPos:Int = 1;
	private var allCharacters:Array<Character> = [];

	private static var songTime:Float;
	public static var sDir:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];

	public function new(?songs:Array<String>, difficulty:Int = 1, week:Int = 0){
		super();
		if(songs == null) return;
		
		storyPlaylist = songs;
		curDifficulty = difficulty;
		storyWeek = week;
		totalScore = 0;

		SONG = misc.Song.loadFromJson(storyPlaylist[0], curDifficulty);
	}

	// # Create (obvious) where game starts.
	override public function create()
	{
		camGame = new FlxCamera();
		camHUD  = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD);
		FlxCamera.defaultCameras = [camGame];

		Conductor.changeBPM(SONG.bpm);

		handleStage();

		for(i in 0...SONG.characters.length)
			allCharacters.push(new Character(characterPositions[i * 2], characterPositions[(i * 2) + 1], SONG.characters[i], i == 1));

		playerPos = SONG.activePlayer;

		// this adds the characters in reverse.
		for(i in 0...SONG.characters.length)
			add(allCharacters[(SONG.characters.length - 1) - i]);

		///////////////////////////////////

		curSong = SONG.song.toLowerCase();
		strumLine = new FlxObject(0, Settings.pr.downscroll ? FlxG.height - 150 : 50, 1, 1);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		playerStrums   = new FlxTypedGroup<StrumNote>();
		notes          = new FlxTypedGroup<Note>();
		add(strumLineNotes);
		add(notes);

		vocals = new FlxSound();
		if (SONG.needsVoices)
			vocals.loadEmbedded(Paths.playableSong(curSong, true));

		FlxG.sound.list.add(vocals);
		FlxG.sound.playMusic(Paths.playableSong(curSong), 1, false);
		FlxG.sound.music.onComplete = endSong;
		FlxG.sound.music.stop();
		correctMusic = false;

		generateSong();
		for(i in 0...2)
			generateStaticArrows(i, i == playerPos);

		followPos = new FlxObject(0, 0, 1, 1);
		followPos.setPosition(FlxG.width / 2, FlxG.height / 2);

		FlxG.camera.follow(followPos, LOCKON, 0.04);
		FlxG.camera.zoom = defaultCamZoom;

		// popup score stuff
		// I agree this is a mess.
		ratingSpr = new FlxSprite(0,0).loadGraphic(Paths.lImage('gameplay/sick'));
		ratingSpr.graphic.persist = true;
		ratingSpr.updateHitbox();
		ratingSpr.centerOrigin();
		ratingSpr.screenCenter();
		ratingSpr.scale.set(0.7, 0.7);
		ratingSpr.alpha = 0;
		ratingSpr.antialiasing = Settings.pr.antialiasing;
		add(ratingSpr);

		for(i in 0...3){
			comboSprs[i] = new FlxSprite(0,0);
			var sRef = comboSprs[i];
			sRef.frames = Paths.lSparrow('gameplay/comboNumbers');
			for(i in 0...10) 
				sRef.animation.addByPrefix('$i', '${i}num', 1, false);
			sRef.animation.play('0');
			sRef.updateHitbox();
			sRef.centerOrigin();
			sRef.screenCenter();
			sRef.y += 120;
			sRef.x += (i - 1) * 60;
			sRef.scale.set(0.6, 0.6);
			sRef.antialiasing = Settings.pr.antialiasing;
			sRef.alpha = 0;
			add(sRef);
		}
		///////////////////////////////////////////////
		var baseY:Int = Settings.pr.downscroll ? 80 : 650;

		healthBarBG = new FlxSprite(0, baseY).loadGraphic(Paths.lImage('gameplay/healthBar'));
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		healthBarBG.antialiasing = Settings.pr.antialiasing;

		var healthColours:Array<Int> = [0xFFFF0000, 0xFF66FF33];
		healthBar = new HealthBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8));
		healthBar.scrollFactor.set();
		healthBar.createFilledBar(healthColours[0], healthColours[1]);

		// score
		scoreTxt = new FlxText(0, baseY + 40, 0, "", 20);
		scoreTxt.setFormat("assets/fonts/vcr.ttf", 16, 0xFFFFFFFF, CENTER, OUTLINE, 0xFF000000);
		scoreTxt.scrollFactor.set();
		scoreTxt.screenCenter(X);

		iconP1 = new HealthIcon(SONG.characters[1], true);
		iconP2 = new HealthIcon(SONG.characters[0], false);
		iconP1.y = baseY - (iconP1.height / 2);
		iconP2.y = baseY - (iconP2.height / 2);

		// hud stuff
		strumLineNotes.cameras = [camHUD];
		notes.cameras          = [camHUD];
		if(Settings.pr.show_hud){
			add(healthBarBG);
			add(healthBar);
			add(scoreTxt);
			add(iconP1);
			add(iconP2);

			healthBar.cameras      = [camHUD];
			healthBarBG.cameras    = [camHUD];
			iconP1.cameras         = [camHUD];
			iconP2.cameras         = [camHUD];
			scoreTxt.cameras       = [camHUD];
		}

		songTime = -16 - (Settings.pr.audio_offset * Conductor.songDiv);
		updateHealth(0);

		super.create();

		// cutscene stuff :vomit:
		var dPath:String = 'assets/songs-data/${PlayState.curSong}/dialogue.txt';
		if(storyWeek >= 0 && !seenCutscene && Assets.exists(dPath)){
			postEvent(0.8, ()->{
				pauseGame(new DialogueSubstate(camHUD, startCountdown, dPath, this));
			});
			return;
		}
		seenCutscene = true;
		postEvent(SONG.beginTime + 0.1, () -> {startCountdown(); });
	}

	// # stage code.
	// put things like gf and bf positions here.

	public inline function handleStage(){
		switch(SONG.stage){
			case 'stage', '':
				if(SONG.song == 'tutorial')
					characterPositions = [
						70,
						130,
						780,
						450
					];

				defaultCamZoom = 0.9;
				var bg:FlxSprite = new FlxSprite(-600, -200).loadGraphic(Paths.lImage('stages/stageback'));
					bg.antialiasing = Settings.pr.antialiasing;
					bg.setGraphicSize(Std.int(bg.width * 2));
					bg.updateHitbox();
					bg.scrollFactor.set(0.9, 0.9);
					bg.active = false;
				add(bg);

				var stageFront:FlxSprite = new FlxSprite(-650, 600).loadGraphic(Paths.lImage('stages/stagefront'));
					stageFront.setGraphicSize(Std.int(stageFront.width * 2.2));
					stageFront.updateHitbox();
					stageFront.antialiasing = Settings.pr.antialiasing;
					stageFront.scrollFactor.set(0.9, 0.9);
					stageFront.active = false;
				add(stageFront);

				var stageCurtains:FlxSprite = new FlxSprite(-500, -300).loadGraphic(Paths.lImage('stages/stagecurtains'));
					stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 1.8));
					stageCurtains.updateHitbox();
					stageCurtains.antialiasing = Settings.pr.antialiasing;
					stageCurtains.scrollFactor.set(1.3, 1.3);
					stageCurtains.active = false;

				add(stageCurtains);
		}
	}

	// # note spawning
	private inline function generateSong():Void
	{
		for(section in SONG.notes)
		for(fNote in section.sectionNotes){
			var time:Float = fNote[0];
			var noteData :Int = Std.int(fNote[1]);
			var susLength:Int = Std.int(fNote[2]);
			var player   :Int = Std.int(fNote[3]);
			var ntype    :Int = Std.int(fNote[4]);

			var newNote = new Note(time, noteData % 4, ntype, false, false);
			newNote.scrollFactor.set();
			newNote.player = player;
			unspawnNotes.push(newNote);
			highestPossibleScore += player == playerPos ? 350 : 0;

			if(susLength > 1)
				for(i in 0...susLength+1){
					var susNote = new Note(time + i + 0.5, noteData, ntype, true, i == susLength);
					susNote.scrollFactor.set();
					susNote.player = player;
					unspawnNotes.push(susNote);
				}
		}
		unspawnNotes.sort((A,B) -> Std.int(A.strumTime - B.strumTime));
	}

	private function generateStaticArrows(player:Int, playable:Bool):Void
		for (i in 0...4)
		{
			var babyArrow:StrumNote = new StrumNote(0, strumLine.y, i, player);
			babyArrow.alpha = 0;

			strumLineNotes.add(babyArrow);
			if(playable)
				playerStrums.add(babyArrow);
		}

	var countTickFunc:Void->Void;
	function startCountdown():Void
	{
		for(i in 0...strumLineNotes.length)
			FlxTween.tween(strumLineNotes.members[i], {alpha: 1}, 0.5, {startDelay: (i + 1) * 0.2});

		var introSprites:Array<FlxSprite> = [];
		var introSounds:Array<FlxSound>   = [];
		var introAssets :Array<String>    = [
			'ready', 'set', 'go', '',
			'intro3', 'intro2', 'intro1', 'introGo'
		]; 
		for(i in 0...4){
			var snd:FlxSound = new FlxSound().loadEmbedded(Paths.lSound('gameplay/' + introAssets[i + 4]));
				snd.volume = 0.6;
			introSounds[i] = snd;

			if(i > 3) continue;

			var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.lImage('gameplay/${ introAssets[i] }'));
				spr.scrollFactor.set();
				spr.screenCenter();
				spr.antialiasing = Settings.pr.antialiasing;
				spr.alpha = 0;
			add(spr);

			introSprites[i+1] = spr;
		}

		var swagCounter:Int = 0;
		countTickFunc = function(){
			if(swagCounter >= 4){
				FlxG.sound.music.play();
				FlxG.sound.music.volume = 1;
				vocals.play();

				syncEverything(0);
				return;
			}
			for(pc in allCharacters)
				pc.dance();

			songTime = (swagCounter - 4) * 4;
			songTime -= Settings.pr.audio_offset * Conductor.songDiv;

			introSounds[swagCounter].play();
			if(introSprites[swagCounter] != null)
				introSpriteTween(introSprites[swagCounter], 3, Conductor.stepCrochet, true);

			swagCounter++;
		}
		for(i in 0...5)
			postEvent(((Conductor.crochet * (i + 1)) - Settings.pr.audio_offset) * 0.001, countTickFunc);
	}

	override function closeSubState()
	{
		if(!seenCutscene) return;
		super.closeSubState();
		if(!paused) return;

		paused = false;

		FlxG.sound.music.play();
		vocals.play();
		syncEverything(-1);
	}

	// # THE GRAND UPDATE FUNCTION!!!

	var noteCount:Int = 0;
	override public function update(elapsed:Float)
	{
		if(paused) return;

		var scaleVal = CoolUtil.boundTo(iconP1.scale.x - (elapsed * 2), 1, 1.2);
		iconP1.scale.set(scaleVal, scaleVal);
		iconP2.scale.set(scaleVal, scaleVal);

		if(seenCutscene)
			songTime += (elapsed * 1000) * Conductor.songDiv;

		// note spawning
		var uNote = unspawnNotes[noteCount];
		if (uNote != null && uNote.strumTime - songTime < 64)
		{
			notes.add(uNote);
			noteCount++;
		}
		notes.forEachAlive(handleNotes);

		super.update(elapsed);
	}

	override function stepHit(){
		super.stepHit();

		if(!FlxG.sound.music.playing) return;
		songTime = ((Conductor.songPosition * Conductor.songDiv) + songTime) * 0.5;
	}
	override function beatHit()
	{
		super.beatHit();
		
		FlxG.camera.followLerp = (1 - Math.pow(0.5, FlxG.elapsed * 6)) * (60 / Settings.pr.framerate);

		if(curBeat % 4 == 0 && FlxG.sound.music.playing){
			mustHitSection = false;
			var sec:SwagSection = SONG.notes[Math.floor(curBeat / 4)];
			if (Std.string(sec != null ? sec.mustHitSection : null) != 'null')
				mustHitSection = sec.mustHitSection;

			var char = allCharacters[mustHitSection ? 1 : 0];
			followPos.x = char.getMidpoint().x + char.camOffset[0];
			followPos.y = char.getMidpoint().y + char.camOffset[1];
		}

		iconP1.scale.set(1.2,1.2);
		iconP2.scale.set(1.2,1.2);

		for(pc in allCharacters)
			pc.dance();
	}

	// # Update stats
	// THIS IS WHAT UPDATES YOUR SCORE AND HEALTH AND STUFF!

	private static inline var iconSpacing:Int = 52;
	public function updateHealth(change:Int){
		var fcText:String = ['?', 'SFC', 'GFC', 'FC', '(Bad) FC', 'SDCB', 'Clear'][fcValue];
		var accuracyCount:Float = fcValue != 0 ? Math.floor(songScore / ((hitCount + missCount) * 3.5)) : 0;

		scoreTxt.text = 'Notes Hit: $hitCount | Notes Missed: $missCount | Accuracy: $accuracyCount% - $fcText | Score: $songScore - ${Math.floor(songScore / highestPossibleScore * 100)}%';
		scoreTxt.screenCenter(X);

		health = CoolUtil.boundTo(health + change, 0, 100, true);
		healthBar.percent = health;

		var calc = (0 - ((health - 50) * 0.01)) * healthBar.width;
		iconP1.screenCenter(X); 
		iconP2.screenCenter(X); 
		iconP1.x += calc + iconSpacing;
		iconP2.x += calc - iconSpacing;

		var animStr = health < 20 ? 'losing' : 'neutral';
		iconP1.animation.play(animStr);
			animStr = health > 80 ? 'losing' : 'neutral';
		iconP2.animation.play(animStr);

		if(health > 0) return; 

		remove(allCharacters[playerPos]);
		pauseGame(new GameOverSubstate(allCharacters[playerPos], camHUD, this));
	}

	// # On note hit.

	function goodNoteHit(note:Note):Void
	{
		destroyNote(note, 0);

		if(!note.curType.mustHit){
			noteMiss(note.noteData);
			return;
		}

		playerStrums.members[note.noteData].playAnim(2);
		allCharacters[playerPos].playAnim('sing' + sDir[note.noteData]);
		vocals.volume = 1;

		if(!note.isSustainNote){
			hitCount++;
			popUpScore(note.strumTime);
		}
		updateHealth(5);
	}

	function noteMiss(direction:Int = 1):Void
	{
		if (combo > 20)
			for(i in 0...allCharacters.length)
				allCharacters[i].playAnim('sad');

		combo = 0;
		songScore -= 50;
		missCount++;
		
		vocals.volume = 0.5;
		FlxG.sound.play(Paths.lSound('gameplay/missnote' + (Math.round(Math.random() * 2) + 1)), 0.2);

		allCharacters[playerPos].playAnim('sing' + sDir[direction] + 'miss');
		fcValue = missCount >= 10 ? 6 : 5;

		updateHealth(Math.round(-Settings.pr.miss_health * 0.5));
	}

	inline function destroyNote(note:Note, act:Int){
		note.typeAction(act);
		notes.remove(note, true);
		note.destroy();

		if(hittableNotes[note.noteData] == null 
		|| hittableNotes[note.noteData] != note)
			return;
		
		hittableNotes[note.noteData] = null;
	}

	// # input code.
	// please add any keys or stuff you want to add here.

	public var hittableNotes:Array<Note> = [null, null, null, null];
	public var keysPressed:Array<Bool>   = [false, false, false, false];
	override function keyHit(ev:KeyboardEvent){
		super.keyHit(ev);

		if(paused) return;

		var k = key.deepCheck([NewControls.UI_ACCEPT, NewControls.UI_BACK, [FlxKey.SEVEN], [FlxKey.F12] ]);
		switch(k){
			case 0, 1:
				if(FlxG.sound.music.playing)
					pauseGame(new PauseSubState(camHUD, this));
				return;
			case 2:
				FlxG.switchState(new ChartingState());
				return;
			case 3:
				misc.Screenshot.takeScreenshot();
				return;
		}

		// actual input system
		var nkey = key.deepCheck([NewControls.NOTE_LEFT, NewControls.NOTE_DOWN, NewControls.NOTE_UP, NewControls.NOTE_RIGHT]);
		if(nkey == -1 || keysPressed[nkey] || Settings.pr.botplay) return;

		keysPressed[nkey] = true;

		var sRef = playerStrums.members[nkey];
		var nRef = hittableNotes[nkey];
		if(nRef != null){
			goodNoteHit(nRef);
			sRef.pressTime = Conductor.stepCrochet * 0.00075;
			
			return;
		}
		if(sRef.pressTime != 0) return;

		sRef.playAnim(1);
		if(!Settings.pr.ghost_tapping)
			noteMiss(nkey);
	}
	override public function keyRel(ev:KeyboardEvent){
		super.keyRel(ev);

		var nkey = key.deepCheck([NewControls.NOTE_LEFT, NewControls.NOTE_DOWN, NewControls.NOTE_UP, NewControls.NOTE_RIGHT]);
		if (nkey == -1) return;

		keysPressed[nkey] = false;
		playerStrums.members[nkey].playAnim();
	}

	// # handle notes. Note scrolling etc

	private inline function handleNotes(daNote:Note){
		var dir = Settings.pr.downscroll ? 45 : -45;
		var nDiff:Float = songTime - daNote.strumTime;
		daNote.y = dir * nDiff * SONG.speed;
		daNote.y += strumLine.y;

		// 1.5 because we need room for the player to miss.
		daNote.visible = daNote.active = (daNote.height > -daNote.height * SONG.speed * 1.5) && (daNote.y < FlxG.height + (daNote.height * SONG.speed * 1.5));
		if(!daNote.active) return;
		
		var strumRef = strumLineNotes.members[daNote.noteData + (4 * daNote.player)];
		if((daNote.player != playerPos || Settings.pr.botplay) && daNote.curType.mustHit && songTime >= daNote.strumTime){
			allCharacters[daNote.player].playAnim('sing' + sDir[daNote.noteData]);
			vocals.volume = 1;

			notes.remove(daNote, true);
			daNote.destroy();
			
			if(!Settings.pr.light_bot_strums) return;

			strumRef.playAnim(2);
			strumRef.pressTime = Conductor.stepCrochet * 0.001;

			return;
		}

		daNote.x     = strumRef.x + daNote.offsetX;
		daNote.angle = strumRef.angle;
		daNote.y    += daNote.offsetY;

		if(daNote.player != playerPos || Settings.pr.botplay) return;

		if(nDiff > inputRange){
			if(daNote.curType.mustHit)
				noteMiss(daNote.noteData);
			
			destroyNote(daNote, 1);
			return;
		}

		if (!daNote.isSustainNote && hittableNotes[daNote.noteData] == null && Math.abs(nDiff) <= inputRange * daNote.curType.rangeMul){
			hittableNotes[daNote.noteData] = daNote;
			return;
		}

		// sustain note input.
		if(daNote.isSustainNote && Math.abs(nDiff) < 0.8 && keysPressed[daNote.noteData]){
			goodNoteHit(daNote);
			return;
		}
	}

	// you can add your own scores too.
	public static var possibleScores:Array<RatingThing> = [
		{
			score: 350,
			threshold: 0,
			name: 'sick',
			value: 1
		},
		{
			score: 200,
			threshold: 0.45,
			name: 'good',
			value: 2
		},
		{
			score: 100,
			threshold: 0.65,
			name: 'bad',
			value: 3
		},
		{
			score: 25,
			threshold: 1,
			name: 'superbad',
			value: 4
		}
	];

	private var ratingSpr:FlxSprite;
	private var prevString:String = 'sick';
	private var comboSprs:Array<FlxSprite> = [];
	private var scoreTweens:Array<FlxTween> = [];
	private inline function popUpScore(strumtime:Float):Void
	{
		var noteDiff:Float = Math.abs(strumtime - (songTime - (Settings.pr.input_offset * Conductor.songDiv)));
		combo++;

		var pscore:RatingThing = null;
		for(i in 0...possibleScores.length)
			if(noteDiff >= possibleScores[i].threshold){
				pscore   = possibleScores[i];
			} else break;

		songScore += pscore.score;

		if(pscore.value > fcValue) 
			fcValue = pscore.value;
		if(pscore.score < 50 || combo > 999)
			combo = 0;
		if(scoreTweens[0] != null)
			for(i in 0...4) scoreTweens[i].cancel();

		if(prevString != pscore.name){
			ratingSpr.loadGraphic(Paths.lImage('gameplay/' + pscore.name));
			ratingSpr.graphic.persist = true;
			prevString = pscore.name;
		}
		ratingSpr.centerOrigin();
		ratingSpr.screenCenter();

		var comsplit:Array<String> = Std.string(combo).split('');

		for(i in 0...3){
			var char = '0';
			if(3 - comsplit.length <= i) char = comsplit[i + (comsplit.length - 3)];

			var sRef = comboSprs[i];
			sRef.animation.play(char);
			sRef.screenCenter(Y);
			sRef.y += 120;
			scoreTweens[i+1] = introSpriteTween(sRef, 3, Conductor.stepCrochet * 0.5, false);
		}
		scoreTweens[0] = introSpriteTween(ratingSpr, 3, Conductor.stepCrochet * 0.5, false);
	}

	function endSong():Void
	{
		FlxG.sound.music.volume = 0;
		vocals.volume = 0;
		paused = true;

		Highscore.saveScore(SONG.song, songScore, curDifficulty);

		if (storyWeek >= 0){
			totalScore += songScore;
			storyPlaylist.splice(0,1);

			if (storyPlaylist.length <= 0){
				Highscore.saveScore('week-$storyWeek', totalScore, curDifficulty);
				PauseSubState.exitToProperMenu();
				return;
			}

			seenCutscene = false;
			SONG = misc.Song.loadFromJson(storyPlaylist[0], curDifficulty);
			FlxG.sound.music.stop();
			FlxG.resetState();

			return;
		}
		PauseSubState.exitToProperMenu();
	}

	// Smaller helper functions
	function syncEverything(forceTime:Float){
		var roundedTime:Float = (forceTime == -1 ? Conductor.songPosition + Settings.pr.audio_offset : forceTime);

		FlxG.sound.music.time  = roundedTime;
		vocals.time            = roundedTime;
		Conductor.songPosition = roundedTime - Settings.pr.audio_offset;
		songTime = Conductor.songPosition * Conductor.songDiv;
	}
	function pauseGame(state:MusicBeatSubstate){
		paused = true;
		FlxG.sound.music.pause();
		vocals.pause();

		openSubState(state);
	}
	private inline function introSpriteTween(spr:FlxSprite, steps:Int, delay:Float = 0, destroy:Bool):FlxTween
	{
		spr.alpha = 1;
		return FlxTween.tween(spr, {y: spr.y + 10, alpha: 0}, (steps * Conductor.stepCrochet) / 1000, { ease: FlxEase.cubeInOut, startDelay: delay * 0.001,
			onComplete: function(twn:FlxTween)
			{
				if(destroy)
					spr.destroy();
			}
		});
	}
	override function onFocusLost(){
		super.onFocusLost();
		if(paused || !FlxG.sound.music.playing) return;
		
		pauseGame(new PauseSubState(camHUD, this));
	}
}
typedef RatingThing = {
	var score:Int;
	var threshold:Float;
	var name:String;
	var value:Int;
}