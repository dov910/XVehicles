//=============================================================================
// FixGun.
//=============================================================================
class FixGun expands PulseGun;

var Actor Actor;
var float CheckTimer;

simulated event RenderOverlays( canvas Canvas )
{
	MultiSkins[1] = Texture'Ammoled';
	Texture'Ammoled'.NotifyActor = Self;
	Super.RenderOverlays(Canvas);
	Texture'Ammoled'.NotifyActor = None;
	MultiSkins[1] = Default.MultiSkins[1];
}

function float RateSelf( out int bUseAltMode )
{
	local int Ignored;
	local Bot Bot;
	
	Bot = Bot(Owner);	
	
	bUseAltMode = 0; // never use for Bot.
	if (Bot != None && Bot.Enemy == Bot && Bot.Target != None && Bot.Target.IsA('Vehicle') && Bot.PlayerReplicationInfo != None &&
		Bot.PlayerReplicationInfo.GetPropertyText("Team") == Bot.Target.GetPropertyText("CurrentTeam") && Bot.bComboPaused)
	{
		bUseAltMode = 1; // do special heal
		return 10;
	}
	return Super.RateSelf(Ignored);
}	

function Tick(float delta)
{
	Super.Tick(delta);
	
	if (CheckTimer <= Level.TimeSeconds)
	{
		CheckTimer = Level.TimeSeconds + 0.5;
		MyTimer();		
	}
}

function MyTimer()
{
	Local Pawn P;
	Local Inventory Inv;
	local FixGun FG;
	local Bot Bot;

	Bot = Bot(Owner);
	if (Bot == None || Bot.Weapon != self || Bot.PlayerReplicationInfo == None ||
		(Bot.Enemy != None && Bot.Enemy != Bot) ||
		CTFFlag(Bot.Target) != None || Bot.PlayerReplicationInfo.HasFlag != None ||
		(Bot.GetStateName() == 'RangedAttack' && Bot.bComboPaused))
		return;

	for (P = Level.PawnList; P != None; P = P.nextPawn)
		if (P.Weapon != None && P.Weapon.isA('DriverWeapon') && 
			P.PlayerReplicationInfo != None && P.PlayerReplicationInfo.Team == Bot.PlayerReplicationInfo.Team)
		{
			Actor = None;
			SetPropertyText("Actor", P.Weapon.GetPropertyText("VehicleOwner"));
			if (Actor == None || int(Actor.GetPropertyText("Health")) >= int(Actor.GetPropertyText("FirstHealth")) ||
				VSize(Actor.Location - Bot.Location) - Actor.CollisionRadius > 710 || !Bot.LineOfSightTo(Actor))
				continue;
			Bot.Enemy = Bot; // weird hack
			Bot.Target = Actor;
			Bot.bComboPaused = true;
			Bot.SpecialPause = 1.0; // calculate exact time for heal
			if (Bot.GetStateName() != 'RangedAttack')
			{
				Bot.NextState = Bot.GetStateName();
				Bot.NextLabel = 'Begin';
			}
			Bot.GotoState('RangedAttack');
			break;
		}
	if (P == None && Bot.Enemy == Bot)
		Bot.Enemy = None; // reset hack
}

defaultproperties
{
      Actor=None
      CheckTimer=0.000000
      WeaponDescription="Classification: Fix RiflenPrimary Fire: Medium sized, fast moving plasma balls are fired at a fast rate of fire.nSecondary Fire: A bolt of blue lightning is expelled for 100 meters, which will fix vehicles.nTechniques: Firing and keeping the secondary fire's beam on a vehicle will fix them in seconds."
      AmmoName=Class'FixGun.FixAmmo'
      PickupAmmoCount=200
      ProjectileClass=Class'FixGun.FixSphere'
      AltProjectileClass=Class'FixGun.StarterFixBolt'
      AIRating=1.000000
      MessageNoAmmo=" has no ammo."
      NameColor=(R=0,G=0,B=255)
      PickupMessage="You got a Fixing Gun"
      ItemName="Fixing Gun"
      StatusIcon=Texture'FixGun.Icons.UseFix'
      MuzzleFlashScale=1.000000
      MuzzleFlashTexture=Texture'UnrealShare.DispExpl.dseb_A01'
      Icon=Texture'FixGun.Icons.UseFix'
      bGameRelevant=True
      MultiSkins(0)=Texture'Botpack.Ammocount.AmmoCountBar'
      MultiSkins(1)=Texture'FixGun.Skins.JFixPickup_01'
      MultiSkins(2)=Texture'FixGun.Skins.JFixGun_02'
      MultiSkins(3)=Texture'FixGun.Skins.JFixGun_03'
      MultiSkins(7)=ScriptedTexture'Botpack.Ammocount.AmmoLed'
      CollisionHeight=16.000000
}
