Class TreadsTrailer extends Effects;

var vector PrePivotRel;

function Tick(float Delta)
{
	if (Vehicle(Owner) != None)
	{
		if (Vehicle(Owner).GVT != None)
			PrePivot = (PrePivotRel >> Owner.Rotation) + Vehicle(Owner).GVT.PrePivot;
		else
			PrePivot = (PrePivotRel >> Owner.Rotation);
	}
	else if (Owner == None)
		Destroy();
}

defaultproperties
{
	bNetTemporary=False
	bTrailerSameRotation=True
	bTrailerPrePivot=True
	Physics=PHYS_Trailer
	RemoteRole=ROLE_None
	DrawType=DT_Mesh
}
