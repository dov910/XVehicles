//=============================================================================
// VehiclesConfig.
//=============================================================================
class VehiclesConfig expands Info Config(XVehicles);

var() config bool bHideState;
var() config bool bPulseAltHeal;
var() config bool bDisableTeamSpawn;
var() config bool bDisableFastWarShell;
var() config bool bAllowTranslocator;
var() config bool bDisableFlagAnnouncer;

defaultproperties
{
	bPulseAltHeal=True
}
