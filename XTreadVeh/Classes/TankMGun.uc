class TankMGun expands xTreadVehAttach;

//Mesh import
#exec MESH IMPORT MESH=TankMGun ANIVFILE=MODELS\TankMGun_a.3d DATAFILE=MODELS\TankMGun_d.3d X=0 Y=0 Z=0 UNMIRROR=1
#exec MESH LODPARAMS MESH=TankMGun STRENGTH=0.85
#exec MESH ORIGIN MESH=TankMGun X=0 Y=0 Z=0

//Mesh anim
#exec MESH SEQUENCE MESH=TankMGun SEQ=All STARTFRAME=0 NUMFRAMES=1
#exec MESH SEQUENCE MESH=TankMGun SEQ=Still STARTFRAME=0 NUMFRAMES=1

//Mesh scale
#exec MESHMAP NEW MESHMAP=TankMGun MESH=TankMGun
#exec MESHMAP SCALE MESHMAP=TankMGun X=0.125 Y=0.125 Z=0.25

//Skinning
#exec TEXTURE IMPORT NAME=TankMGSk_II FILE=SKINS\TankMGSk_II.bmp GROUP=Skins LODSET=2
#exec MESHMAP SETTEXTURE MESHMAP=TankMGun NUM=1 TEXTURE=TankMGSk_II

defaultproperties
{
	Mesh=LodMesh'XTreadVeh.TankMGun'
}
