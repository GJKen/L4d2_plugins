#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sdktools>
#define DEBUG_HUNTER_AIM 0
#define DEBUG_HUNTER_RNG 0
#define DEBUG_HUNTER_ANGLE 0

#define POSITIVE 0
#define NEGATIVE 1
#define X 0
#define Y 1
#define Z 2

// Vanilla Cvars
ConVar hCvarHunterCommittedAttackRange;
ConVar hCvarHunterPounceReadyRange;
ConVar hCvarHunterLeapAwayGiveUpRange; 
ConVar hCvarHunterPounceMaxLoftAngle; 
ConVar hCvarLungeInterval; 
ConVar z_pounce_damage_interrupt;
// Gaussian random number generator for pounce angles
ConVar hCvarPounceAngleMean;
ConVar hCvarPounceAngleStd; // standard deviation
// Pounce vertical angle
ConVar hCvarPounceVerticalAngle;
// Distance at which hunter begins pouncing fast
ConVar hCvarFastPounceProximity; 
// Distance at which hunter considers pouncing straight
ConVar hCvarStraightPounceProximity;
// Aim offset(degrees) sensitivity
ConVar hCvarAimOffsetSensitivityHunter;
// Wall detection
ConVar hCvarWallDetectionDistance;

static ConVar g_hCvarEnable; 
static bool g_bCvarEnable;

bool bHasQueuedLunge[MAXPLAYERS];
bool bCanLunge[MAXPLAYERS];

public void Hunter_OnModuleStart() {
	g_hCvarEnable 		= CreateConVar( "AI_HardSI_Hunter_enable",   "1",   "0=Improves the Hunter behaviour off, 1=Improves the Hunter behaviour on.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_EnableCvars);

	// Set aggressive hunter cvars		
	hCvarHunterCommittedAttackRange = FindConVar("hunter_committed_attack_range"); // range at which hunter is committed to attack	
	hCvarHunterPounceReadyRange = FindConVar("hunter_pounce_ready_range"); // range at which hunter prepares pounce	
	hCvarHunterLeapAwayGiveUpRange = FindConVar("hunter_leap_away_give_up_range"); // range at which shooting a non-committed hunter will cause it to leap away	
	hCvarLungeInterval = FindConVar("z_lunge_interval"); // cooldown on lunges
	hCvarHunterPounceMaxLoftAngle = FindConVar("hunter_pounce_max_loft_angle"); // maximum vertical angle hunters can pounce
	z_pounce_damage_interrupt = FindConVar("z_pounce_damage_interrupt");

	if(g_bCvarEnable) _OnModuleStart();
	hCvarHunterCommittedAttackRange.AddChangeHook(OnHunterCvarChange);
	hCvarHunterPounceReadyRange.AddChangeHook(OnHunterCvarChange);
	hCvarHunterLeapAwayGiveUpRange.AddChangeHook(OnHunterCvarChange);
	hCvarHunterPounceMaxLoftAngle.AddChangeHook(OnHunterCvarChange);

	// proximity to nearest survivor when plugin starts to force hunters to lunge ASAP
	hCvarFastPounceProximity = CreateConVar("ai_fast_pounce_proximity", "1000", "At what distance to start pouncing fast");

	// Verticality
	hCvarPounceVerticalAngle = CreateConVar("ai_pounce_vertical_angle", "7", "Vertical angle to which AI hunter pounces will be restricted");

	// Pounce angle
	hCvarPounceAngleMean = CreateConVar( "ai_pounce_angle_mean", "10", "Mean angle produced by Gaussian RNG" );
	hCvarPounceAngleStd = CreateConVar( "ai_pounce_angle_std", "20", "One standard deviation from mean as produced by Gaussian RNG" );
	hCvarStraightPounceProximity = CreateConVar( "ai_straight_pounce_proximity", "200", "Distance to nearest survivor at which hunter will consider pouncing straight");

	// Aim offset sensitivity
	hCvarAimOffsetSensitivityHunter = CreateConVar("ai_aim_offset_sensitivity_hunter",
									"30",
									"If the hunter has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius",
									FCVAR_NONE,
									true, 0.0, true, 179.0 );
	// How far in front of hunter to check for a wall
	hCvarWallDetectionDistance = CreateConVar("ai_wall_detection_distance", "-1", "How far in front of himself infected bot will check for a wall. Use '-1' to disable feature");
}

static void _OnModuleStart()
{
	hCvarHunterCommittedAttackRange.SetInt(10000);
	hCvarHunterPounceReadyRange.SetInt(1000);
	hCvarHunterLeapAwayGiveUpRange.SetInt(0); 
	hCvarHunterPounceMaxLoftAngle.SetInt(0);
	z_pounce_damage_interrupt.SetInt(150);
}

public void Hunter_OnModuleEnd() {
	// Reset aggressive hunter cvars
	ResetConVar(hCvarHunterCommittedAttackRange);
	ResetConVar(hCvarHunterPounceReadyRange);
	ResetConVar(hCvarHunterLeapAwayGiveUpRange);
	ResetConVar(hCvarHunterPounceMaxLoftAngle);
	ResetConVar(z_pounce_damage_interrupt);
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
        Hunter_OnModuleEnd();
    }
}

static void GetCvars()
{
    g_bCvarEnable = g_hCvarEnable.BoolValue;
}

// Game tries to reset these cvars
public void OnHunterCvarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	if(g_bCvarEnable) _OnModuleStart();
}

public Action Hunter_OnSpawn(int botHunter) {
	if(!g_bCvarEnable) return Plugin_Continue;

	bHasQueuedLunge[botHunter] = false;
	bCanLunge[botHunter] = true;
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

																		FAST POUNCING

***********************************************************************************************************************************************************************************/

public Action Hunter_OnPlayerRunCmd(int hunter, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon ) {	
	if(!g_bCvarEnable) return Plugin_Continue;

	buttons &= ~IN_ATTACK2; // block scratches
	int flags = GetEntityFlags(hunter);
	//Proceed if the hunter is in a position to pounce
	if( (flags & FL_DUCKING) && (flags & FL_ONGROUND) ) {		
		float hunterPos[3];
		GetClientAbsOrigin(hunter, hunterPos);		
		int iSurvivorsProximity = GetSurvivorProximity(hunterPos);
		if (iSurvivorsProximity == -1) return Plugin_Continue;
		
		bool bHasLOS = view_as<bool>(GetEntProp(hunter, Prop_Send, "m_hasVisibleThreats")); // Line of sight to survivors		
		// Start fast pouncing if close enough to survivors
		if( bHasLOS ) {
			if( iSurvivorsProximity < hCvarFastPounceProximity.IntValue ) {
				buttons &= ~IN_ATTACK; // release attack button; precautionary					
				// Queue a pounce/lunge
				if (!bHasQueuedLunge[hunter]) { // check lunge interval timer has not already been initiated
					bCanLunge[hunter] = false;
					bHasQueuedLunge[hunter] = true; // block duplicate lunge interval timers
					CreateTimer(hCvarLungeInterval.FloatValue, Timer_LungeInterval, hunter, TIMER_FLAG_NO_MAPCHANGE);
				} else if (bCanLunge[hunter]) { // end of lunge interval; lunge!
					buttons |= IN_ATTACK;
					bHasQueuedLunge[hunter] = false; // unblock lunge interval timer
				} // else lunge queue is being processed
			}
		} 	
	} 	
	return Plugin_Changed;
}

/***********************************************************************************************************************************************************************************

																	POUNCING AT AN ANGLE TO SURVIVORS

***********************************************************************************************************************************************************************************/

public Action Hunter_OnPounce(int botHunter) {	
	if(!g_bCvarEnable) return Plugin_Continue;
	
	int entLunge = GetEntPropEnt(botHunter, Prop_Send, "m_customAbility"); // get the hunter's lunge entity				
	float lungeVector[3]; 
	GetEntPropVector(entLunge, Prop_Send, "m_queuedLunge", lungeVector); // get the vector from the lunge entity
	
	// Avoid pouncing straight forward if there is a wall close in front
	float hunterPos[3];
	float hunterAngle[3];
	GetClientAbsOrigin(botHunter, hunterPos);
	GetClientEyeAngles(botHunter, hunterAngle); 
	// Fire traceray in front of hunter 
	TR_TraceRayFilter( hunterPos, hunterAngle, MASK_PLAYERSOLID, RayType_Infinite, TracerayFilter, botHunter );
	float impactPos[3];
	TR_GetEndPosition( impactPos );
	// Check first object hit
	if( GetVectorDistance(hunterPos, impactPos) < hCvarWallDetectionDistance.IntValue ) { // wall detected in front
		if( GetRandomInt(0, 1) ) { // 50% chance left or right
			AngleLunge( entLunge, 45.0 );
		} else {
			AngleLunge( entLunge, 315.0 );
		}
		
			#if DEBUG_HUNTER_AIM
				PrintToChatAll("Pouncing sideways to avoid wall");
			#endif
		
	} else {
		// Angle pounce if survivor is watching the hunter approach
		GetClientAbsOrigin(botHunter, hunterPos);		
		if( IsTargetWatchingAttacker(botHunter, hCvarAimOffsetSensitivityHunter.IntValue) && GetSurvivorProximity(hunterPos) > hCvarStraightPounceProximity.IntValue ) {			
			float pounceAngle = GaussianRNG( hCvarPounceAngleMean.FloatValue, hCvarPounceAngleStd.FloatValue );
			AngleLunge( entLunge, pounceAngle );
			LimitLungeVerticality( entLunge );
			
				#if DEBUG_HUNTER_AIM
					int target = GetClientAimTarget(botHunter);
					if( IsSurvivor(target) ) {
						char targetName[32];
						GetClientName(target, targetName, sizeof(targetName));
						PrintToChatAll("The aim of hunter's target(%s) is %f degrees off", targetName, GetPlayerAimOffset(target, botHunter));
						PrintToChatAll("Angling pounce to throw off survivor");
					} 
					
				#endif
	
			return Plugin_Changed;					
		}	
	}
	return Plugin_Continue;
}

public bool TracerayFilter( int impactEntity, int contentMask, any rayOriginEntity ) {
	return impactEntity != rayOriginEntity;
}
// Credits to High Cookie and Standalone for working out the math behind hunter lunges
void AngleLunge( int lungeEntity, float turnAngle ) {	
	// Get the original lunge's vector
	float lungeVector[3];
	GetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", lungeVector);
	float x = lungeVector[X];
	float y = lungeVector[Y];
	float z = lungeVector[Z];
    
    // Create a int vector of the desired angle from the original
	turnAngle = DegToRad(turnAngle); // convert angle to radian form
	float forcedLunge[3];
	forcedLunge[X] = x * Cosine(turnAngle) - y * Sine(turnAngle); 
	forcedLunge[Y] = x * Sine(turnAngle)   + y * Cosine(turnAngle);
	forcedLunge[Z] = z;
	
	SetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", forcedLunge);	
}

// Stop pounces being too high
void LimitLungeVerticality( int lungeEntity ) {
	// Get vertical angle restriction
	float vertAngle = hCvarPounceVerticalAngle.FloatValue;
	// Get the original lunge's vector
	float lungeVector[3];
	GetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", lungeVector);
	float x = lungeVector[X];
	float y = lungeVector[Y];
	float z = lungeVector[Z];
	
	vertAngle = DegToRad(vertAngle);	
	float flatLunge[3];
	// First rotation
	flatLunge[Y] = y * Cosine(vertAngle) - z * Sine(vertAngle);
	flatLunge[Z] = y * Sine(vertAngle) + z * Cosine(vertAngle);
	// Second rotation
	flatLunge[X] = x * Cosine(vertAngle) + z * Sine(vertAngle);
	flatLunge[Z] = x * -Sine(vertAngle) + z * Cosine(vertAngle);
	
	SetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", flatLunge);
}

/** 
 * Thanks to Newteee:
 * Random number generator fit to a bellcurve. Function to generate Gaussian Random Number fit to a bellcurve with a specified mean and std
 * Uses Polar Form of the Box-Muller transformation
*/
float GaussianRNG( float mean, float std ) {	 	
	// Randomising positive/negative
	float chanceToken = GetRandomFloat( 0.0, 1.0 );
	int signBit;	
	if( chanceToken >= 0.5 ) {
		signBit = POSITIVE;
	} else {
		signBit = NEGATIVE;
	}	   
	
	float x1;
	float x2;
	float w;
	// Box-Muller algorithm
	do {
	    // Generate random number
	    float random1 = GetRandomFloat( 0.0, 1.0 );	// Random number between 0 and 1
	    float random2 = GetRandomFloat( 0.0, 1.0 );	// Random number between 0 and 1
	 
	    x1 = 2.0 * random1 - 1.0;
	    x2 = 2.0 * random2 - 1.0;
	    w = x1 * x1 + x2 * x2;
	 
	} while( w >= 1.0 );	 
	static float e = 2.71828;
	w = SquareRoot( -2.0 * ( Logarithm(w, e)/ w )); 

	// Random normal variable
	float y1 = x1 * w;
	float y2 = x2 * w;
	 
	// Random gaussian variable with std and mean
	float z1 = y1 * std + mean;
	float z2 = y2 * std - mean;
	
	#if DEBUG_HUNTER_RNG	
		if( signBit == NEGATIVE )PrintToChatAll("Angle: %f", z1);
		else PrintToChatAll("Angle: %f", z2);
	#endif
	
	// Output z1 or z2 depending on sign
	if( signBit == NEGATIVE )return z1;
	else return z2;
}

// After the given interval, hunter is allowed to pounce/lunge
public Action Timer_LungeInterval(Handle timer, any client) {
	bCanLunge[client] = true;

	return Plugin_Continue;
}