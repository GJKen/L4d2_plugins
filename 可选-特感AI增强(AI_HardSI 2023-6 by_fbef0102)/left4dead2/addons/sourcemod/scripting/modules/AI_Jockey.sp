#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
enum Angle_Vector {
	Pitch = 0,
	Yaw,
	Roll
};

ConVar hCvarJockeyLeapRange; // vanilla cvar
ConVar hCvarHopActivationProximity; // custom cvar
ConVar z_jockey_leap_again_timer;

// Leaps
bool bCanLeap[MAXPLAYERS];
bool bDoNormalJump[MAXPLAYERS]; // used to alternate pounces and normal jumps
 // shoved jockeys will stop hopping

// Bibliography: "hunter pounce push" by "Pan XiaoHai & Marcus101RR & AtomicStryker"

public void Jockey_OnModuleStart() {
	// CONSOLE VARIABLES
	// jockeys will move to attack survivors within this range
	z_jockey_leap_again_timer = FindConVar("z_jockey_leap_again_timer");
	hCvarJockeyLeapRange = FindConVar("z_jockey_leap_range");
	hCvarJockeyLeapRange.SetInt(1000); 
	hCvarJockeyLeapRange.AddChangeHook(OnJockeyCvarChange);
	
	// proximity when plugin will start forcing jockeys to hop
	hCvarHopActivationProximity = CreateConVar("ai_hop_activation_proximity", "500", "How close a jockey will approach before it starts hopping");
}

public void Jockey_OnModuleEnd() {
	hCvarJockeyLeapRange.RestoreDefault();
}

// Game tries to reset these cvars
public void OnJockeyCvarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	hCvarJockeyLeapRange.SetInt(1000);
}

/***********************************************************************************************************************************************************************************

																	HOPS: ALTERNATING LEAP AND JUMP

***********************************************************************************************************************************************************************************/

public Action Jockey_OnPlayerRunCmd(int jockey, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, bool hasBeenShoved) {
	float jockeyPos[3];
	GetClientAbsOrigin(jockey, jockeyPos);
	int iSurvivorsProximity = GetSurvivorProximity(jockeyPos);
	if (iSurvivorsProximity == -1) return Plugin_Continue;
	
	bool bHasLOS = view_as<bool>(GetEntProp(jockey, Prop_Send, "m_hasVisibleThreats")); // line of sight to any survivor
	
	// Start hopping if within range	
	if ( bHasLOS && (iSurvivorsProximity < GetConVarInt(hCvarHopActivationProximity)) ) {
		
		// Force them to hop 
		int flags = GetEntityFlags(jockey);
		
		// Alternate normal jump and pounces if jockey has not been shoved
		if ( (flags & FL_ONGROUND) && !hasBeenShoved ) { // jump/leap off cd when on ground (unless being shoved)
			if (bDoNormalJump[jockey]) {
				buttons |= IN_JUMP; // normal jump
				bDoNormalJump[jockey] = false;
			} else {
				if( bCanLeap[jockey] ) {
					buttons |= IN_ATTACK; // pounce leap
					bCanLeap[jockey] = false; // leap should be on cooldown
					float leapCooldown = z_jockey_leap_again_timer.FloatValue;
					CreateTimer(leapCooldown, Timer_LeapCooldown, jockey, TIMER_FLAG_NO_MAPCHANGE);
					bDoNormalJump[jockey] = true;
				} 			
			}
			
		} else { // midair, release buttons
			buttons &= ~IN_JUMP;
			buttons &= ~IN_ATTACK;
		}		
		return Plugin_Changed;
	} 

	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																	DEACTIVATING HOP DURING SHOVES

***********************************************************************************************************************************************************************************/

// Enable hopping on spawned jockeys
public Action Jockey_OnSpawn(int botJockey) {
	bCanLeap[botJockey] = true;
	return Plugin_Handled;
}

// Disable hopping when shoved
public void Jockey_OnShoved(int botJockey) {
	bCanLeap[botJockey] = false;
	CreateTimer( z_jockey_leap_again_timer.FloatValue, Timer_LeapCooldown, botJockey, TIMER_FLAG_NO_MAPCHANGE) ;
}

public Action Timer_LeapCooldown(Handle timer, any jockey) {
	bCanLeap[jockey] = true;

	return Plugin_Continue;
}