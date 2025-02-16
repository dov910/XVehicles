// A car with normal wheels (Created by .:..: 8.1.2008)
Class WheeledCarPhys extends Vehicle;

Enum WheelTypeType
{
	TT_None,
	TT_TurningWheel,
	TT_RevesedTurn
};
struct WheelsTypes
{
	var() vector WheelOffset;
	var() rotator WheelRot;
	var() class<VehicleWheel> WheelClass;
	var() mesh WheelMesh;
	var() WheelTypeType WheelType;
	var() bool bMirroredWheel;
};
var() WheelsTypes Wheels[8];
var() float MaxGroundSpeed,WheelMaxYaw,WheelTurnSpeed;
var VehicleWheel MyWheels[8];
var byte NumWheels,WheelsTurning;
var bool bHasWheelMeshes,bWasStuckOnW,bReversing;
var float WheelYaw,StuckTimer,ReverseTimer;
var int WheelsPitch;
var(WheeledEng) bool bEngDynSndPitch;
var(WheeledEng) byte MinEngPitch, MaxEngPitch;
var() float WheelsTraction;
var() int IronWheelsTerrainDmg;
var vector VelFriction;
var float IronC;
var() bool bUsePerfectWheelAngSpeed;
var() float WheelsRadius;
var() float TractionWheelsPosition;

var VehWaterAttach VWaterT[8];

replication
{
	// Variables the server should send to the client.
	unreliable if( Role==ROLE_Authority && !bNetOwner )
		WheelsTurning;
}

function ZoneChange( ZoneInfo NewZone )
{
	if (NewZone.bWaterZone)
		Velocity *= 0.65;
}

simulated function ClientUpdateState( float Delta )
{
	Super.ClientUpdateState(Delta);
	if( WheelsTurning>0 )
	{
		Turning = int(WheelsTurning)-2;
		WheelsTurning = 0;
	}
}
function ServerPackState( float Delta)
{
	Super.ServerPackState(Delta);
	WheelsTurning = Turning+2;
}
simulated function PostBeginPlay()
{
	local byte i;

	Super.PostBeginPlay();

	if( Level.NetMode!=NM_DedicatedServer )
	{
		For( i=0; i<ArrayCount(Wheels); i++ )
		{
			if( Wheels[i].WheelClass==None )
				Continue;
			MyWheels[NumWheels] = VehicleWheel(AddAttachment(Wheels[i].WheelClass));
			if( MyWheels[NumWheels]==None )
				Continue;
			MyWheels[NumWheels].WheelOffset = Wheels[i].WheelOffset;
			MyWheels[NumWheels].WheelRot = Wheels[i].WheelRot;
			MyWheels[NumWheels].TurnType = Wheels[i].WheelType;
			MyWheels[NumWheels].Mesh = Wheels[i].WheelMesh;
			MyWheels[NumWheels].bMirroredWheel = Wheels[i].bMirroredWheel;

			//Water Trail FX points creation
			if (bHaveGroundWaterFX && bSlopedPhys && MyWheels[NumWheels]!=None)
			{
				VWaterT[NumWheels] = Spawn(Class'VehWaterAttach',Self);
				VWaterT[NumWheels].WaveSize = FMax(MyWheels[NumWheels].CollisionRadius,MyWheels[NumWheels].CollisionHeight)*4;
				VWaterT[NumWheels].SoundRadius = Max(32,Min(FMax(CollisionRadius,CollisionHeight)/2.5,255));
			}

			NumWheels++;
			if( !bHasWheelMeshes )
				bHasWheelMeshes = True;
		}
	}
			
	if (MyWheels[0] != None)
		MyWheels[0].bMasterPart = True;
	else if (DriverWeapon.WeaponClass==None)
		AddAttachment(Class'MasterAttach');
}
// Return normal for acceleration direction.
simulated function vector GetAccelDir( int InTurn, int InRise, int InAccel )
{
	local rotator R;
	
	// X dot X == VSize(X)*VSize(X)
	if (FMax(Region.Zone.ZoneGroundFriction,WheelsTraction) > 4.0 || (Velocity dot Velocity) < 10000 /* 100*100 */)
		R.Yaw = VehicleYaw+(WheelYaw/2);
	else
		R.Yaw = VehicleYaw-(WheelYaw/2);
	Return SetUpNewMVelocity(vector(R)*InAccel,ActualFloorNormal,0);
}

simulated function FellToGround()
{
	if (FallingLenghtZ > 0)
	{
		if ((FallingLenghtZ * VehicleGravityScale) > 1500)
			TakeImpactDamage(FallingLenghtZ*VehicleGravityScale/15,None, "FellToGround_3");
		else if ((FallingLenghtZ * VehicleGravityScale) > 120)
			TakeImpactDamage(0,None, "FellToGround_4");
		FallingLenghtZ = 0;
	}
}

simulated function UpdateDriverInput( float Delta )
{
	local vector Ac,NVeloc;
	local float DesTurn,DeAcc,DeAccRat;
	local rotator R, RA, RB;
	local byte i;
	local rotator OldWheeledRot;

	if (Region.Zone.ZoneGroundFriction + WheelsTraction > 14.0)	//Traction on but outside ice/snow areas
	{
		IronC += Delta;
		// X dot X == VSize(X)*VSize(X)
		if (IronC >= 0.5 && (Velocity dot Velocity) > 0)
		{
			IronC = 0;
			TakeImpactDamage(IronWheelsTerrainDmg*VSize(Velocity)/MaxGroundSpeed, None);
		}
	}

	if (FMax(Region.Zone.ZoneGroundFriction,WheelsTraction) > 4.0 && bOnGround)
	{
		VelFriction = Velocity;
		VirtOldAccel = OldAccelD;
	}	

	if (bSlopedPhys && GVT != None)
		R = TransformForGroundRot(VehicleYaw, GVTNormal);
	else
		R = TransformForGroundRot(VehicleYaw, FloorNormal);
	OldWheeledRot = Rotation;

	if (Rotation != R)
		SetRotation(R);
		
	if (OldWheeledRot.Yaw != Rotation.Yaw)
	{
		Ac.X = TractionWheelsPosition;
		RA.Yaw = Rotation.Yaw;
		RB.Yaw = OldWheeledRot.Yaw;
		MoveSmooth((Ac >> RA) - (Ac >> RB));
	}

	DesTurn = WheelMaxYaw*Turning*-1;
	if (WheelYaw != DesTurn)
	{
		if (WheelYaw < DesTurn)
		{
			WheelYaw += WheelTurnSpeed*Delta;
			if (WheelYaw > DesTurn)
				WheelYaw = DesTurn;
		}
		else
		{
			WheelYaw -= WheelTurnSpeed*Delta;
			if (WheelYaw < DesTurn)
				WheelYaw = DesTurn;
		}
	}
	
	if (Level.NetMode == NM_Client && !IsNetOwner(Owner))
		Return;
	
	if (!bOnGround)
	{
		if (Region.Zone.bWaterZone)
			Velocity += Region.Zone.ZoneGravity*Delta*VehicleGravityScale*0.35;
		else
			Velocity += Region.Zone.ZoneGravity*Delta*VehicleGravityScale;
		FallingLenghtZ += Abs(OldLocation.Z - Location.Z);
		Return;
	}
	
	Velocity += CalcGravityStrength(Region.Zone.ZoneGravity*(VehicleGravityScale/GroundPower), FloorNormal)*
		Delta/(FMax(Region.Zone.ZoneGroundFriction, WheelsTraction)/8.f + 1.f);

	// X dot X == VSize(X)*VSize(X)
	DesTurn = (Velocity dot Velocity);
	if (DesTurn > 0)
	{
		if (FMax(Region.Zone.ZoneGroundFriction, WheelsTraction) > 4.0)
			DesTurn = VSize(Velocity)*WheelYaw*Delta/400*GetMovementDir();
		else
			DesTurn = VSize(Velocity)*WheelYaw*Delta/400*GetMovementDir()*
				FMin(FMax(Region.Zone.ZoneGroundFriction, WheelsTraction), 1.0);
		if (DesTurn != 0)
		{
			VehicleYaw += DesTurn;
			if (!bCameraOnBehindView && Driver!=None)
				Driver.ViewRotation.Yaw += DesTurn;
		}
	}
	
	if (!bOldOnGround && bOnGround) // Landed just now
	{ // clear velocity part which orthogonal to floor
		Velocity -= ActualFloorNormal*(Velocity dot ActualFloorNormal);
	}

	// Update vehicle speed
	if (Accel != 0)
	{
		//Braking, so reduce speed 3x superior to normal deacceleration
		// X dot X == VSize(X)*VSize(X)
		if (OldAccelD == -Accel && (Velocity dot Velocity) > 256 /* 16 * 16 */)
		{
			DeAcc = VSize(Velocity);
			DeAccRat = Delta*WDeAccelRate*3*FMax(Region.Zone.ZoneGroundFriction,WheelsTraction);
			if( DeAccRat>DeAcc )
				DeAccRat = DeAcc;
			if (FMax(Region.Zone.ZoneGroundFriction,WheelsTraction) <= 4.0)
			{	
				if( DeAcc>0 )
				{
					DeAcc-=WDeAccelRate*Delta;
					if( DeAcc<0 )
						DeAcc = 0;
				}
				else DeAcc-=WDeAccelRate*3*Delta/100;

				Ac = GetAccelDir(Turning,Rising,OldAccelD);
				NVeloc = Normal(Velocity);
				if( DeAcc>50 && (Ac Dot NVeloc)<0.4 )
				{
					Velocity-=Ac*FMax(Region.Zone.ZoneGroundFriction,WheelsTraction)*WDeAccelRate*3*Delta*2.f;
					Return;
				}
				Ac = Ac*MaxGroundSpeed*FMax(Region.Zone.ZoneGroundFriction,WheelsTraction)/10;
				Velocity = Normal(Velocity+Ac)*DeAcc;
			}
			else
			{
				if (DeAccRat >= DeAcc)
					Velocity = vect(0,0,0);
				else
				{
					Ac = GetAccelDir(Turning,Rising,OldAccelD);
					Velocity-=Normal(Velocity)*DeAccRat;
					if (Velocity dot Ac > 0)
						Velocity = VSize(Velocity)*Normal(Ac);
					else
						OldAccelD = -OldAccelD;
				}

				SetSignalLights(SL_Stop);
			}
			Return;
		}
		else
		{
			if (FMax(Region.Zone.ZoneGroundFriction,WheelsTraction) > 4.0)
			{
				if (Accel == -1)
					SetSignalLights(SL_Backwards);
				else
					SetSignalLights(SL_None);
			}
			OldAccelD = Accel;
		}
	}

	//If no braking, and no accel, deaccel smoothly
	if (Accel == 0)
	{
		DeAcc = VSize(Velocity);
		DeAccRat = WDeAccelRate*FMax(Region.Zone.ZoneGroundFriction, WheelsTraction)*Delta;
		if (DeAccRat > DeAcc)
			DeAccRat = DeAcc;
		if (FMax(Region.Zone.ZoneGroundFriction, WheelsTraction) <= 4.0)
		{
			if( DeAcc>0 )
			{
				DeAcc-=WDeAccelRate*Delta;
				if( DeAcc<0 )
					DeAcc = 0;
			}
			else DeAcc-=WDeAccelRate*Delta/100;

			Ac = GetAccelDir(Turning,Rising,OldAccelD);
			NVeloc = Normal(Velocity);
			if( DeAcc>50 && (Ac Dot NVeloc)<0.4 )
			{
				Velocity-=Ac*FMax(Region.Zone.ZoneGroundFriction,WheelsTraction)*WDeAccelRate*Delta*2.f;
				Return;
			}
			Ac = Ac*MaxGroundSpeed*FMax(Region.Zone.ZoneGroundFriction,WheelsTraction)/10;
			Velocity = Normal(Velocity+Ac)*DeAcc;
		}
		else
		{
			if (DeAccRat >= DeAcc)
				Velocity = vect(0,0,0);
			else
			{
				Ac = GetAccelDir(Turning,Rising,OldAccelD);
				Velocity -= Normal(Velocity)*DeAccRat;
				if (Velocity dot Ac > 0)
					Velocity = VSize(Velocity)*Normal(Ac);
				// X dot X == VSize(X)*VSize(X)
				else if ((Velocity dot Velocity) > 0)
					OldAccelD = -OldAccelD;
			}
			
			SetSignalLights(SL_None);
		}
		Return;
	}
	DeAcc = VSize(Velocity);
	
	if (DeAcc < MaxGroundSpeed)
	{
		DeAcc+=WAccelRate*Delta;
		if (DeAcc > MaxGroundSpeed)
			DeAcc = MaxGroundSpeed;
	}
	else 
		DeAcc += WAccelRate*Delta/100;

	Ac = GetAccelDir(Turning, Rising, Accel);
	NVeloc = Normal(Velocity);

	if (DeAcc > 50 && (Ac dot NVeloc) < 0.4)
	{
		Velocity += Ac*FMax(Region.Zone.ZoneGroundFriction, WheelsTraction)*WAccelRate*2.f*Delta;
		Return;
	}

	Ac = Ac*MaxGroundSpeed*FMax(Region.Zone.ZoneGroundFriction, WheelsTraction)/10;
	Velocity = Normal(Velocity + Ac)*DeAcc;
}

simulated function int GetIcedMovementDir()
{
	if( (Normal(VelFriction) dot vector(Rotation))>0 )
		Return 1;
	else Return -1;
}

function int ShouldAccelFor( vector AcTarget )
{
	local bool bStuck;
	local vector X,Y,Z;
	local float Res;
	local int ret;
	
	if (AboutToCrash(ret))
		return ret;
		
	ret = 1;
	if ((AcTarget - Location) dot vector(Rotation) < 0)
		ret = -1;

	if( bReversing )
	{
		if( ReverseTimer<Level.TimeSeconds )
		{
			bReversing = False;
			StuckTimer = Level.TimeSeconds+3;
			Return ret;
		}
		Return -ret;
	}
	// X dot X == VSize(X)*VSize(X)
	bStuck = (Velocity dot Velocity) < MaxGroundSpeed*MaxGroundSpeed/25 /* 5*5 */;
	if (!bStuck)
	{
		GetAxes(Rotation,X,Y,Z);
		Res = Normal(AcTarget-Location) dot X;
//		Log("ShouldAccelFor" @ res);
		bStuck = Abs(Res) < 0.7; // direction not in forward/backward way
	}
	if( bWasStuckOnW!=bStuck )
	{
		bWasStuckOnW = bStuck;
		if( bStuck )
			StuckTimer = Level.TimeSeconds+2;
	}
	if( bStuck && StuckTimer<Level.TimeSeconds )
	{
		bReversing = True;
		ReverseTimer = Level.TimeSeconds+2;
		Return -ret;
	}
	Return ret;
}
function int ShouldTurnFor( vector AcTarget, optional float YawAdjust, optional float DeadZone )
{
	local int ret;
	
	local vector X,Y,Z;
	local rotator R;
	local float Res, res2;
		
	YawAdjust = WheelYaw*FMin(1, Vsize(Velocity)/400);
	if ((AcTarget - Location) dot vector(Rotation) < 0)
		YawAdjust = -YawAdjust;

	ret = Super.ShouldTurnFor(AcTarget, YawAdjust, DeadZone);
/*	
	GetAxes(Rotation,X,Y,Z);
	Res = Normal(AcTarget-Location) dot Y;	
	
	R = Rotation;
	R.Yaw += YawAdjust;

	GetAxes(R,X,Y,Z);
	Res2 = Normal(AcTarget-Location) dot Y;
	
	log("ShouldTurnFor" @ "VehicleYaw" @ VehicleYaw @ "WheelYaw" @ WheelYaw @ "YawAdjust" @ YawAdjust @ "ret" @ ret @ "res" @ res @ "res2" @ res2);
*/	
	if( bReversing )
		Return -ret;
	else
		Return ret;
}

function vector GetVirtualSpeedOnIce(float Delta)
{
local float DeAcc,DeAccRat;
local vector Ac;
local byte i;

	/*if( !bOnGround )
	{
		VelFriction+=Region.Zone.ZoneGravity*Delta*VehicleGravityScale;
		Return VelFriction;
	}*/

	if( bOnGround )
		VelFriction+=CalcGravityStrength(Region.Zone.ZoneGravity,FloorNormal)*Delta/(8.0/8.f+1.f);

	if (Accel != 0)
	{
		// X dot X == VSize(X)*VSize(X)
		if (VirtOldAccel == -Accel && (VelFriction dot VelFriction) > 256 /* 16*16 */)
		{
			DeAcc = VSize(VelFriction);
			DeAccRat = Delta*WDeAccelRate*24.0;
			if( DeAccRat>DeAcc )
				DeAccRat = DeAcc;
			VelFriction-=Normal(VelFriction)*DeAccRat;

			SetSignalLights(SL_Stop);

			Return VelFriction;
		}
		else
		{
			if (Accel == -1)
				SetSignalLights(SL_Backwards);
			else
				SetSignalLights(SL_None);
			VirtOldAccel = Accel;
		}
	}
	else
	{
		DeAcc = VSize(VelFriction);
		DeAccRat = Delta*WDeAccelRate*8.0;
		if( DeAccRat>DeAcc )
			DeAccRat = DeAcc;
		VelFriction-=Normal(VelFriction)*DeAccRat;

		SetSignalLights(SL_None);

		Return VelFriction;
	}

	DeAcc = VSize(VelFriction);
	
	if( DeAcc<MaxGroundSpeed )
	{
		DeAcc+=WAccelRate*Delta;
		if( DeAcc>MaxGroundSpeed )
			DeAcc = MaxGroundSpeed;
	}
	else DeAcc+=WAccelRate*Delta/100;

	Ac = vector(Rotation)*Accel*MaxGroundSpeed*8/10;
	VelFriction = Normal(VelFriction+Ac)*DeAcc;

	Return VelFriction;
}

simulated function AttachmentsTick( float Delta )
{
	local byte i,bSet[3];
	local rotator R,SR[3];
	local Quat WQ,VehQ;
	local byte PitchDif;
	local float EngP;

	//Water zone variables
	local byte rec;
	local byte FootSndVol, FootSndPitch;
	local sound FootAmbSnd;
	local float FootZoneSpeed;

	Super.AttachmentsTick(Delta);

	if (bEngDynSndPitch)
	{
		PitchDif = MaxEngPitch - MinEngPitch;
		if (FMax(Region.Zone.ZoneGroundFriction,WheelsTraction) > 4.0)
			EngP = MinEngPitch + Min(PitchDif,(VSize(Velocity)*PitchDif/MaxGroundSpeed));
		else
			EngP = MinEngPitch + Min(PitchDif,(VSize(VelFriction)*PitchDif/MaxGroundSpeed));
		SoundPitch = Byte(EngP);
	}

	// Update wheels turning
	if( bHasWheelMeshes )
	{
		VehQ = RtoQ(Rotation);

		if (bUsePerfectWheelAngSpeed && WheelsRadius > 0)
		{
			if (FMax(Region.Zone.ZoneGroundFriction,WheelsTraction) > 4.0)
				WheelsPitch-=GetMovementDir()*GetAngularSpeed(VSize(Velocity),Delta,WheelsRadius);
			else
				WheelsPitch-=GetIcedMovementDir()*GetAngularSpeed(VSize(GetVirtualSpeedOnIce(Delta)),Delta,WheelsRadius);
		}
		else
		{
			if (FMax(Region.Zone.ZoneGroundFriction,WheelsTraction) > 4.0 && bOnGround)
				WheelsPitch-=GetMovementDir()*VSize(Velocity)*200.f*Delta;
			else
				WheelsPitch-=GetIcedMovementDir()*VSize(GetVirtualSpeedOnIce(Delta))*200.f*Delta;
		}

		While( WheelsPitch>UU_360_DEGREES )
			WheelsPitch-=UU_360_DEGREES;
		While( WheelsPitch>UU_360_NEGDEGREES )
			WheelsPitch-=UU_360_NEGDEGREES;
		For( i=0; i<NumWheels; i++ )
		{
			if (bSlopedPhys && GVT!=None)
				MyWheels[i].SetLocation(GVT.PrePivot + Location +(MyWheels[i].WheelOffset >> Rotation)*DrawScale);
			else
				MyWheels[i].SetLocation(Location+(MyWheels[i].WheelOffset >> Rotation)*DrawScale);

			if( bSet[MyWheels[i].TurnType]==0 )
			{
				bSet[MyWheels[i].TurnType] = 1;
				R = MyWheels[i].WheelRot;
				if( MyWheels[i].TurnType==1 )
					R.Yaw+=WheelYaw;
				else if( MyWheels[i].TurnType==2 )
					R.Yaw-=WheelYaw;
				R.Pitch = WheelsPitch;
				WQ = RtoQ(R);
				WQ = WQ Qmulti VehQ;
				SR[MyWheels[i].TurnType] = QtoR(WQ);
			}
			MyWheels[i].SetRotation(SR[MyWheels[i].TurnType]);


			//********************************************************************************
			//Water Trail FX points update
			//********************************************************************************
			if (bHaveGroundWaterFX && bSlopedPhys && VWaterT[i] != None && (Location != OldLocation ||
				(FootVehZone[i] != None && VSize(FootVehZone[i].ZoneVelocity) > 150 )))
			{
				VWaterT[i].SetLocation(MyWheels[i].Location);
				VWaterT[i].Move(MyWheels[i].CollisionHeight*vect(0,0,-1));

				if (VWaterT[i].Region.Zone.bWaterZone && !Region.Zone.bWaterZone)
				{
					FootVehZone[i] = VWaterT[i].Region.Zone;
					rec = 0;
					
					if (VSize(FootVehZone[i].ZoneVelocity) > 150)
						FootZoneSpeed = VSize(FootVehZone[i].ZoneVelocity);
					else
						FootZoneSpeed = 0;

					FootSndVol = Min(Max(8,VWaterT[i].WaveSize*3),255) * ((VSize(Location - OldLocation)/Delta + FootZoneSpeed)/ RefMaxWaterSpeed);
					FootSndPitch = 32 + ((VSize(Location - OldLocation)/Delta + FootZoneSpeed)/ RefMaxWaterSpeed) * 96;
					FootAmbSnd = VWaterT[i].Region.Zone.AmbientSound;

					if (VWaterT[i].SoundPitch != FootSndPitch)
						VWaterT[i].SoundPitch = FootSndPitch;
					if (VWaterT[i].AmbientSound != FootAmbSnd)
						VWaterT[i].AmbientSound = FootAmbSnd;
					if (VWaterT[i].SoundVolume != FootSndVol)
						VWaterT[i].SoundVolume = FootSndVol;
						

					while (VWaterT[i].Region.Zone.bWaterZone && !Region.Zone.bWaterZone && rec < 20)
					{
						VWaterT[i].OldWaterZone = VWaterT[i].Region.Zone;
						VWaterT[i].Move(vect(0,0,8));
						rec++;
					}

					if ((Velocity dot vector(Rotation)) > 0)
						VWaterT[i].WaveLenght += VSize(Location - OldLocation);
					else
						VWaterT[i].WaveLenght -= VSize(Location - OldLocation);

				}
				else
				{
					if (VWaterT[i].OldWaterZone != None)
						VWaterT[i].OldWaterZone = None;
					if (VWaterT[i].AmbientSound != None)
						VWaterT[i].AmbientSound = None;

					FootVehZone[i] = None;
				}
			}
			else if (FootVehZone[i] != None && Location == OldLocation && VWaterT[i] != None && VWaterT[i].AmbientSound != None)
				VWaterT[i].AmbientSound = None;
				
			//********************************************************************************
		}

		//********************************************************************************
		//Foot zone handling
		//********************************************************************************
		if (bHaveGroundWaterFX)
		{
			SecCount += Delta;
			if (SecCount >= 0.35)
			{
				i = 0;
				while (i < 8)
				{
					if (FootVehZone[i] != None)
					{
						AnalyzeZone(FootVehZone[i]);
						i = 10;
					}
					
					i++;
				}
				SecCount = 0;
			}
		}
		//********************************************************************************
	}
}

simulated function Destroyed()
{
local byte i;

	For (i = 0; i < 8; i++)
	{
		if (VWaterT[i] != None)
			VWaterT[i].Destroy();
	}

	Super.Destroyed();
}
/*function TakeDamage( int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType)
{
	if ((normal(momentum) Dot vector(Rotation)) > 0.5)
		Accel = 1;
	else if ((normal(momentum) Dot -vector(Rotation)) > 0.5)
		Accel = -1;

	Super.TakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType);
}*/

defaultproperties
{
	Wheels(0)=(WheelOffset=(X=25.320000,Y=28.540001,Z=-23.000000),WheelClass=Class'XVehicles.VehicleWheel',WheelMesh=LodMesh'UnrealShare.WoodenBoxM',WheelType=TT_TurningWheel)
	Wheels(1)=(WheelOffset=(X=25.320000,Y=-28.540001,Z=-23.000000),WheelClass=Class'XVehicles.VehicleWheel',WheelMesh=LodMesh'UnrealShare.WoodenBoxM',WheelType=TT_TurningWheel)
	Wheels(2)=(WheelOffset=(X=-25.320000,Y=28.540001,Z=-23.000000),WheelClass=Class'XVehicles.VehicleWheel',WheelMesh=LodMesh'UnrealShare.WoodenBoxM')
	Wheels(3)=(WheelOffset=(X=-25.320000,Y=-28.540001,Z=-23.000000),WheelClass=Class'XVehicles.VehicleWheel',WheelMesh=LodMesh'UnrealShare.WoodenBoxM')
	MaxGroundSpeed=3000.000000
	WheelMaxYaw=8000.000000
	WheelTurnSpeed=12000.000000
	WheelsTraction=0.100000
	IronWheelsTerrainDmg=25
	bUsePerfectWheelAngSpeed=True
	WAccelRate=500.000000
	Health=500
	bFPViewUseRelRot=True
	bFPRepYawUpdatesView=True
	VehicleName="Wheeled Car"
	TranslatorDescription="This is a wheeled vehicle, press [Fire] or [AltFire] to fire the different firemodes. Use your Strafe keys to turn this vehicle and Move Forward/Backward keys to accelerate/deaccelerate. To leave this vehicle, press your [ThrowWeapon] key."
	bMaster=True
	VehicleKeyInfoStr="Wheeled car keys:|%MoveForward%,%MoveBackward% to accelerate/deaccelerate|%StrafeLeft%, %StrafeRight% to turn|%Fire% to fire, %AltFire% to alt fire|Number keys to switch seats|%PrevWeapon%, %NextWeapon%, %SwitchToBestWeapon% to change camera|%ThrowWeapon% to exit the vehicle"
	bDestroyUpsideDown=True
	WDeAccelRate=50.000000
	Mesh=LodMesh'UnrealShare.WoodenBoxM'
}
