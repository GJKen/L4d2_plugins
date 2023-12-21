#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#define DEBUG_CHARGER_TARGET 0

// custom convar
ConVar hCvarChargeProximity;
ConVar hCvarAimOffsetSensitivityCharger;
ConVar hCvarHealthThresholdCharger;
int bShouldCharge[MAXPLAYERS]; // manual tracking of charge cooldown

static ConVar g_hCvarEnable; 
static bool g_bCvarEnable;

public void Charger_OnModuleStart() {
	g_hCvarEnable 		= CreateConVar( "AI_HardSI_Charger_enable",   "1",   "0=Improves the Charger behaviour off, 1=Improves the Charger behaviour on.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_EnableCvars);

	// Charge proximity
	hCvarChargeProximity = CreateConVar("ai_charge_proximity", "300", "How close a charger will approach before charging");	
	// Aim offset sensitivity
	hCvarAimOffsetSensitivityCharger = CreateConVar("ai_aim_offset_sensitivity_charger",
									"20",
									"If the charger has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius",
									FCVAR_NONE,
									true, 0.0, true, 179.0);
	// Health threshold
	hCvarHealthThresholdCharger = CreateConVar("ai_health_threshold_charger", "300", "Charger will charge if its health drops to this level");	
}

static void _OnModuleStart()
{
}

public void Charger_OnModuleEnd() 
{
}

static void ConVarChanged_EnableCvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
    GetCvars();
    if(g_bCvarEnable)
    {
        _OnModuleStart();
    }
    else
    {
        Charger_OnModuleEnd();
    }
}

static void GetCvars()
{
    g_bCvarEnable = g_hCvarEnable.BoolValue;
}

/***********************************************************************************************************************************************************************************

																KEEP CHARGE ON COOLDOWN UNTIL WITHIN PROXIMITY

***********************************************************************************************************************************************************************************/

// Initialise spawned chargers
public Action Charger_OnSpawn(int botCharger) {
	if(!g_bCvarEnable) return Plugin_Continue;

	bShouldCharge[botCharger] = false;
	return Plugin_Handled;
}

public Action Charger_OnPlayerRunCmd(int charger, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon ) {
	if(!g_bCvarEnable) return Plugin_Continue;
	
	// prevent charge until survivors are within the defined proximity
	float chargerPos[3];
	GetClientAbsOrigin(charger, chargerPos);
	int target = GetClientAimTarget(charger);	
	int iSurvivorProximity = GetSurvivorProximity(chargerPos, target); // invalid(=-1) target will cause GetSurvivorProximity() to return distance to closest survivor
	if (iSurvivorProximity == -1) return Plugin_Continue;	
	
	int chargerHealth = GetEntProp(charger, Prop_Send, "m_iHealth");
	if( chargerHealth > hCvarHealthThresholdCharger.IntValue && iSurvivorProximity > hCvarChargeProximity.IntValue ) {	
		if( !bShouldCharge[charger] ) { 				
			BlockCharge(charger);
			return Plugin_Changed;
		} 			
	} else {
		bShouldCharge[charger] = true;
	}
	return Plugin_Continue;	
}

void BlockCharge(int charger) {
	int chargeEntity = GetEntPropEnt(charger, Prop_Send, "m_customAbility");
	if (chargeEntity > 0) {  // charger entity persists for a short while after death; check ability entity is valid
		SetEntPropFloat(chargeEntity, Prop_Send, "m_timestamp", GetGameTime() + 0.1); // keep extending end of cooldown period
	} 			
}

void Charger_OnCharge(int charger) {
	// Assign charger a int survivor target if they are not specifically targetting anybody with their charge or their target is watching
	int aimTarget = GetClientAimTarget(charger);
	if( !IsSurvivor(aimTarget) || IsTargetWatchingAttacker(charger, hCvarAimOffsetSensitivityCharger.IntValue) ) {	
		float chargerPos[3];
		GetClientAbsOrigin(charger, chargerPos);
		int newTarget = GetClosestSurvivor(chargerPos, aimTarget);	// try and find another closeby survivor
		int distance = GetSurvivorProximity(chargerPos, newTarget);
		if( newTarget != -1 && distance != -1 && distance <= hCvarChargeProximity.IntValue ) {
			aimTarget = newTarget; // might be the same survivor if there were no other survivors within configured charge proximity
			
			#if DEBUG_CHARGER_TARGET	
				char targetName[32];
				GetClientName(newTarget, targetName, sizeof(targetName));
				PrintToChatAll("Charger forced to charge survivor %s", targetName);
			#endif
			ChargePrediction(charger, aimTarget);
		}
	}
}

void ChargePrediction(int charger, int survivor) {
	if( !IsBotCharger(charger) || !IsSurvivor(survivor) ) {
		return;
	}
	float survivorPos[3];
	float chargerPos[3];
	float attackDirection[3];
	float attackAngle[3];
	// Add some fancy schmancy trignometric prediction here; as a placeholder charger will face survivor directly
	GetClientAbsOrigin(charger, chargerPos);
	GetClientAbsOrigin(survivor, survivorPos);
	MakeVectorFromPoints( chargerPos, survivorPos, attackDirection );
	GetVectorAngles(attackDirection, attackAngle);	
	TeleportEntity(charger, NULL_VECTOR, attackAngle, NULL_VECTOR); 
}