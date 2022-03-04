// A helicopter vehicle (Created by .:..: 9.1.2008)
Class ChopperPhys extends Vehicle;

var() float MaxAirSpeed,YawTurnSpeed;
var float CurrentYawSpeed,NextCutTime;
var const float MaxYawRates[2];
var ChopperRotor MyRotor;
var() class<ChopperRotor> ChopperRotorClass;
var() vector RotorOffset,RotorSize;
var int RotorYaw;
var bool bHasRotorDmg;

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();
	if( Level.NetMode!=NM_DedicatedServer && ChopperRotorClass!=None )
		MyRotor = ChopperRotor(AddAttachment(ChopperRotorClass));
	if( Level.NetMode!=NM_Client && ChopperRotorClass!=None && RotorSize!=vect(0,0,0) )
		bHasRotorDmg = True;
}
simulated singular function HitWall( vector HitNormal, Actor Wall )
{
	local vector V;

	MoveSmooth(HitNormal);
	if( bDriving )
	{
		Velocity = SetUpNewMVelocity(Velocity,HitNormal,0.05);
		Return;
	}
	V = SetUpNewMVelocity(Velocity,HitNormal,1);
	if( !bOnGround && HitNormal.Z>0.8 )
	{
		if( VSize(Normal(V)-Normal(Velocity))>0.85 && VSize(Velocity)>450 )
		{
			Velocity = SetUpNewMVelocity(Velocity,HitNormal,0.15);
			Return;
		}
		bOnGround = True;
		ActualFloorNormal = HitNormal;
		Velocity = SetUpNewMVelocity(Velocity,HitNormal,0);
		Return;
	}
	if( VSize(Normal(V)-Normal(Velocity))>0.85 || (bOnGround && !CanYawUpTo(Rotation,TransformForGroundRot(VehicleYaw,HitNormal),1500)) )
	{
		if( bOnGround && CanGetOver(35,0.85) )
			Return;
		bOnGround = False;
		Velocity = SetUpNewMVelocity(Velocity,HitNormal,0.5);
	}
	else
	{
		Velocity = SetUpNewMVelocity(Velocity,HitNormal,0);
		ActualFloorNormal = HitNormal;
		bOnGround = True;
	}
}

// Return normal for acceleration direction.
simulated function vector GetAccelDir( int InTurn, int InRise, int InAccel )
{
	local rotator R;
	local vector X,Y,Z;

	if( PlayerPawn(Driver)==None )
	{
		if( Driver.Target!=None )
			X = Driver.Target.Location;
		else X = MoveDest;
		Return Normal(X-Location);
	}
	if( InTurn==0 && InRise==0 && InAccel==0 )
		Return vect(0,0,0);
	R.Yaw = VehicleYaw;
	GetAxes(R,X,Y,Z);
	Return Normal(X*InAccel+Y*-InTurn+Z*InRise);
}

simulated function UpdateDriverInput( float Delta )
{
	local vector Ac,X,Y,Z,HL,HN,En;
	local rotator R,Rr;
	local float Changed,DeAcc,DeAccRat;
	local Actor A;
	local byte i;

	if( bHasRotorDmg && !bOnGround && NextCutTime<Level.TimeSeconds )
	{
		NextCutTime = Level.TimeSeconds+0.05;
		GetAxes(Rotation,X,Y,Z);
		Ac = Location+(RotorOffset >> Rotation);
		For( i=0; i<8; i++ )
		{
			DeAcc = (float(i)+FRand());
			En = Ac+X*RotorSize.X*Sin(DeAcc)+Y*RotorSize.Y*Cos(DeAcc);
			A = Trace(HL,HN,En,Ac,True);
			if( A!=None )
			{
				if( A.bIsPawn || Carcass(A)!=None )
					A.TakeDamage(50+Rand(60),Driver,HL,vect(0,0,0),'cutted');
				else if( Vehicle(A)!=None )
				{
					A.TakeDamage(50+Rand(60),Driver,HL,HN,'crushed');
					A.Velocity-=HN*500;
					TakeDamage(30+Rand(20),None,HL,HN,'crushed');
					Velocity+=HN*500;
				}
				else
				{
					TakeDamage(50+Rand(60),Driver,HL,HN,'crushed');
					Velocity+=HN*500;
				}
			}
		}
	}
	if( bOnGround )
		R = TransformForGroundRot(VehicleYaw,FloorNormal);
	else
	{
		R = Normalize(Rotation);
		R.Yaw = VehicleYaw;
		R.Roll/=2;
		R.Pitch/=2;
	}
	if( !bDriving && !bOnGround )
	{
		bOnGround = CheckOnGround();
		if( !bOnGround )
		{
			Velocity+=Region.Zone.ZoneGravity*Delta*VehicleGravityScale;
			Return;
		}
	}
	if( Level.NetMode!=NM_DedicatedServer && !bOnGround && bDriving )
	{
		Rr.Yaw = VehicleYaw;
		Ac = (Velocity << Rr)*10f;
		if( Ac.Y>MaxYawRates[0] )
			Ac.Y = MaxYawRates[0];
		else if( Ac.Y<MaxYawRates[1] )
			Ac.Y = MaxYawRates[1];
		if( Ac.X>MaxYawRates[0] )
			Ac.X = MaxYawRates[0];
		else if( Ac.X<MaxYawRates[1] )
			Ac.X = MaxYawRates[1];
		if( Abs(R.Roll)<Abs(Ac.Y) )
			R.Roll = Ac.Y;
		if( Abs(R.Pitch)<Abs(Ac.X) )
			R.Pitch = -Ac.X;
		GetAxes(R,X,Y,Z);
		ActualFloorNormal = Z;
		FloorNormal = Z;
	}
	if( Rotation!=R )
		SetRotation(R);
	if( !bDriving )
	{
		DeAcc = VSize(Velocity);
		DeAccRat = Delta*WAccelRate*Region.Zone.ZoneGroundFriction;
		if( DeAccRat>DeAcc )
			DeAccRat = DeAcc;
		Velocity-=Normal(Velocity)*DeAccRat;
		Return;
	}
	if( Level.NetMode==NM_Client && !IsNetOwner(Owner) )
		Return;
	if( Driver!=None )
	{
		Changed = CalcTurnSpeed(CurrentYawSpeed*Delta,VehicleYaw,Driver.ViewRotation.Yaw);
		Changed-=VehicleYaw;
		if( Changed==0 )
			CurrentYawSpeed = 5;
		else if( CurrentYawSpeed<YawTurnSpeed )
		{
			CurrentYawSpeed+=Delta*0.5*YawTurnSpeed;
			if( CurrentYawSpeed>YawTurnSpeed )
				CurrentYawSpeed = YawTurnSpeed;
		}
		VehicleYaw+=Changed;
	}
	Ac = GetAccelDir(Turning,Rising,Accel)*WAccelRate*Delta;
	if( VSize(Velocity)>MaxAirSpeed && VSize(Normal(Velocity)-Normal(Ac))<0.85 )
		Velocity+=(Ac*0.1);
	else Velocity+=Ac;
	if( Rising==0 && PlayerPawn(Driver)!=None )
		Velocity.Z*=(1.f-Delta);
	if( Turning==0 && Accel==0 )
	{
		Velocity.X*=(1.f-Delta);
		Velocity.Y*=(1.f-Delta);
	}
}
simulated function vector GetMovementSpeeds()
{
	local vector V;

	V = (Velocity << Rotation);
	V.Z = 0;
	Return Normal(V);
}
simulated function AttachmentsTick( float Delta )
{
	if( MyRotor!=None )
	{
		if( bOnGround )
			RotorYaw+=80000*Delta;
		else RotorYaw+=80000*(VSize(Velocity)/500+2.f)*Delta;
		While( RotorYaw>65536 )
			RotorYaw-=65536;
		MyRotor.Move(Location+(RotorOffset >> Rotation)-MyRotor.Location);
		MyRotor.SetRotation(TransformForGroundRot(RotorYaw,FloorNormal));
	}
}

defaultproperties
{
      MaxAirSpeed=1400.000000
      YawTurnSpeed=18000.000000
      CurrentYawSpeed=5.000000
      NextCutTime=0.000000
      MaxYawRates(0)=6000.000000
      MaxYawRates(1)=-6000.000000
      MyRotor=None
      ChopperRotorClass=None
      RotorOffset=(X=0.000000,Y=0.000000,Z=0.000000)
      RotorSize=(X=0.000000,Y=0.000000,Z=0.000000)
      RotorYaw=0
      bHasRotorDmg=False
      WAccelRate=900.000000
      Health=300
      VehicleName="Helicopter"
      TranslatorDescription="This is a chopper vehicle, you can fire different firemodes using [Fire] and [AltFire] buttons. To move higher or lover use [Jump] and [Crouch] buttons and to move around use movement keys. To leave this vehicle press [ThrowWeapon] key."
      VehicleKeyInfoStr="Chopper craft keys:|%MoveForward%,%MoveBackward% to accelerate/deaccelerate|%StrafeLeft%, %StrafeRight% to strafe|%Jump%, %Duck% to move up/down|%Fire% to fire, %AltFire% to alt fire|Number keys to switch seats|%ThrowWeapon% to exit the vehicle"
      Mesh=LodMesh'UnrealShare.WoodenBoxM'
}
