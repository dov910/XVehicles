//=============================================================================
// VehiclesConfig.
//=============================================================================
class VehiclesConfig expands Info Config(XVehicles);

var() config bool bHideState;
var() config bool bPulseAltHeal;
var() config bool bDisableTeamSpawn;

defaultproperties
{
      bHideState=False
      bPulseAltHeal=False
      bDisableTeamSpawn=False
}
