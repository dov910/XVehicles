class JSDXWheel expands VehicleWheel;

//Mesh import
#exec MESH IMPORT MESH=JSDXWheel ANIVFILE=MODELS\JSDXWheel_a.3d DATAFILE=MODELS\JSDXWheel_d.3d X=0 Y=0 Z=0
#exec MESH LODPARAMS MESH=JSDXWheel STRENGTH=0.85
#exec MESH ORIGIN MESH=JSDXWheel X=0 Y=0 Z=0

#exec MESH IMPORT MESH=JSDXWheelMir ANIVFILE=MODELS\JSDXWheel_a.3d DATAFILE=MODELS\JSDXWheel_d.3d X=0 Y=0 Z=0 UNMIRROR=1
#exec MESH LODPARAMS MESH=JSDXWheelMir STRENGTH=0.85
#exec MESH ORIGIN MESH=JSDXWheelMir X=0 Y=0 Z=0 YAW=128

//Mesh anim
#exec MESH SEQUENCE MESH=JSDXWheel SEQ=All STARTFRAME=0 NUMFRAMES=1
#exec MESH SEQUENCE MESH=JSDXWheel SEQ=Still STARTFRAME=0 NUMFRAMES=1

#exec MESH SEQUENCE MESH=JSDXWheelMir SEQ=All STARTFRAME=0 NUMFRAMES=1
#exec MESH SEQUENCE MESH=JSDXWheelMir SEQ=Still STARTFRAME=0 NUMFRAMES=1

//Mesh scale
#exec MESHMAP NEW MESHMAP=JSDXWheel MESH=JSDXWheel
#exec MESHMAP SCALE MESHMAP=JSDXWheel X=0.25 Y=0.25 Z=0.5

#exec MESHMAP NEW MESHMAP=JSDXWheelMir MESH=JSDXWheelMir
#exec MESHMAP SCALE MESHMAP=JSDXWheelMir X=0.25 Y=0.25 Z=0.5

//Skinning
#exec TEXTURE IMPORT NAME=WheelHIIISk01 FILE=SKINS\WheelHIIISk01.bmp GROUP=Skins LODSET=2
#exec MESHMAP SETTEXTURE MESHMAP=JSDXWheel NUM=1 TEXTURE=WheelHIIISk01
#exec MESHMAP SETTEXTURE MESHMAP=JSDXWheelMir NUM=1 TEXTURE=WheelHIIISk01

#exec TEXTURE IMPORT NAME=WheelHIIISk02 FILE=SKINS\WheelHIIISk02.bmp GROUP=Skins LODSET=2
#exec MESHMAP SETTEXTURE MESHMAP=JSDXWheel NUM=2 TEXTURE=WheelHIIISk02
#exec MESHMAP SETTEXTURE MESHMAP=JSDXWheelMir NUM=2 TEXTURE=WheelHIIISk02

defaultproperties
{
	Mesh=LodMesh'XWheelVeh.JSDXWheel'
	DrawScale=1.000000
}
