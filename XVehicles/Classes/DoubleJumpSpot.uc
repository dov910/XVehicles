//=============================================================================
// DoubleJumpSpot.
//=============================================================================
class DoubleJumpSpot expands Teleporter;

var int Allowed;

event int SpecialCost(Pawn Seeker)
{
	if (Url == "")
		return ExtraCost;

	if (Seeker != None && DriverWeapon(Seeker.Weapon) != None)
		return 100000;
	
	if (default.Allowed == 0 || Allowed != 0)
		check();
		
	return ExtraCost;
}

function check() {
	local Mutator M;
	local Inventory Inv;
	local string str;
	
	if (default.Allowed == 0) { // try detect it
		default.Allowed = -1; // not found		

		foreach AllActors(class'Mutator', M) {
			str = Caps(string(M.Class.Name));
			if (InStr(str, "DOUBLEJUMP") != -1)
				break;
			if (InStr(str, "UTPURE") != -1 && M.GetPropertyText("bDoubleJump") ~= "True")
				break;
		}
		if (M != None)
			default.Allowed = 1;
		else {
			foreach AllActors(class'Inventory', Inv) {
				str = Caps(string(Inv.Class.Name));
				if (InStr(str, "DOUBLEJUMP") != -1 || InStr(str, "DJ_INVENTORY") != -1)
					break;
			}
			if (Inv != None)
				default.Allowed = 2;
			else {
				str = Caps(Level.ConsoleCommand("OBJ CLASSES"));
				if (InStr(str, "DJ_INVENTORY") != -1 || 
					InStr(str, "DOUBLEJUMPBOOTS") != -1 || 
					InStr(str, "DOUBLEJUMPITEM") != -1)
					default.Allowed = 3;
			}
		}
		Log("Try detect DoubleJump:" @ default.Allowed, Class.Name);
	}
	fix();
}

function bool fix()
{
	local DoubleJumpSpot NP;
	local int i, j, flags, dist;
	local Actor Start, End;
	
	foreach AllActors(class'DoubleJumpSpot', NP) {
		NP.Allowed = 0;
		if (default.Allowed < 0)
		{
			NP.SetCollision(false, false, false);
			NP.Disable('Touch');
			for (i = 0; i < ArrayCount(NP.upstreamPaths); i++)
				if (NP.upstreamPaths[i] == -1)
					break;
				else {
					NP.describeSpec(NP.upstreamPaths[i], Start, End, flags, dist);
					if (flags == 32 && DoubleJumpSpot(Start) != None && DoubleJumpSpot(End) != None)
					{
						for (j = i-- + 1; j < ArrayCount(NP.upstreamPaths); j++)
							NP.upstreamPaths[j - 1] = NP.upstreamPaths[j];
						NP.upstreamPaths[j - 1] = -1;
					}
				}
			for (i = 0; i < ArrayCount(NP.Paths); i++)
				if (NP.Paths[i] == -1)
					break;
				else {
					NP.describeSpec(NP.Paths[i], Start, End, flags, dist);
					if (flags == 32 && DoubleJumpSpot(Start) != None && DoubleJumpSpot(End) != None)
					{
						for (j = i-- + 1; j < ArrayCount(NP.Paths); j++)
							NP.Paths[j - 1] = NP.Paths[j];
						NP.Paths[j - 1] = -1;
					}
				}
			for (i = 0; i < ArrayCount(NP.PrunedPaths); i++)
				if (NP.PrunedPaths[i] == -1)
					break;
				else {
					NP.describeSpec(NP.PrunedPaths[i], Start, End, flags, dist);
					if (flags == 32 && DoubleJumpSpot(Start) != None && DoubleJumpSpot(End) != None)
					{
						for (j = i-- + 1; j < ArrayCount(NP.PrunedPaths); j++)
							NP.PrunedPaths[j - 1] = NP.PrunedPaths[j];
						NP.PrunedPaths[j - 1] = -1;
					}
				}
			}
	}
}

simulated function bool Accept( actor Incoming, Actor Source )
{
	return false;
}

simulated function Touch( actor Other )
{
	local DoubleJumpSpot Dest;
	local Bot B;
	local int i;

	B = Bot(Other);
	if (B == None || B.MoveTarget != self || URL == "")
		return;
		
	PendingTouch = Other.PendingTouch;
	Other.PendingTouch = self;
}

simulated function PostTouch( Actor Other )
{
	local DoubleJumpSpot Dest;
	local Bot B;
	local int i;	
	
	B = Bot(Other);
	if (B == None || B.MoveTarget != self || URL == "")
		return;
		
	foreach AllActors(class'DoubleJumpSpot', Dest)
		if (string(Dest.tag) ~= URL && Dest != Self)
			break;
		
	if (Dest == None)
		return;
		
	for (i = ArrayCount(B.RouteCache) - 1; i >= 0; i--)
		if (B.RouteCache[i] == Dest)
			break;

	if (i < 0 || (i > 0 && B.RouteCache[i - 1] != self) || 
		(i < ArrayCount(B.RouteCache) - 1 && B.RouteCache[i + 1] == self))
		return;
		
	B.bJumpOffPawn = true;
	B.SetFall();
	B.SetPhysics(PHYS_Falling);
		
	B.Focus = Dest.Location;
	B.MoveTarget = Dest;
	B.MoveTimer = VSize(Dest.Location - B.Location)/B.GroundSpeed;
	B.Destination = Dest.Location;
	
    B.Velocity = Dest.Location - B.Location;
    B.Velocity.Z = 0;
    B.Velocity = Normal(B.Velocity);
    B.Acceleration = B.Velocity*B.AccelRate; 
    B.Velocity *= B.GroundSpeed;
    B.Velocity.Z = 210*2.7;
    B.bBigJump = true;
    
	//B.DesiredRotation = rotator(Dest.Location - Location);
	B.PlaySound(B.JumpSound, SLOT_Talk, 1.0, true, 800, 1.0);
	B.MakeNoise(1.0);

	if ( (B.Weapon != None) && B.Weapon.bSplashDamage
		&& ((B.bFire != 0) || (B.bAltFire != 0)) && (B.Enemy != None)
		&& !B.FastTrace(B.Enemy.Location, Location)
		&& B.FastTrace(B.Enemy.Location, B.Location) )
	{
		B.bFire = 0;
		B.bAltFire = 0;
	}
}

function Actor SpecialHandling(Pawn Other)
{
	return self;
}

defaultproperties
{
	bSpecialCost=True
	RemoteRole=ROLE_None
}
