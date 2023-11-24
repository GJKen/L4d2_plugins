// Thanks to L4D2Util for many stock functions and enumerations

#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>

#if defined HARDCOOP_UTIL_included
#endinput
#endif

#define HARDCOOP_UTIL_included

#define DEBUG_FLOW 0

#define TEAM_CLASS(%1) (%1 == ZC_SMOKER ? "smoker" : (%1 == ZC_BOOMER ? "boomer" : (%1 == ZC_HUNTER ? "hunter" :(%1 == ZC_SPITTER ? "spitter" : (%1 == ZC_JOCKEY ? "jockey" : (%1 == ZC_CHARGER ? "charger" : (%1 == ZC_WITCH ? "witch" : (%1 == ZC_TANK ? "tank" : "None"))))))))
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

#define L4D2Team_Spectator 1
#define L4D2Team_Survivor 2
#define L4D2Team_Infected 3

#define L4D2Infected_Smoker 1
#define L4D2Infected_Boomer 2
#define L4D2Infected_Hunter 3
#define L4D2Infected_Spitter 4
#define L4D2Infected_Jockey 5
#define L4D2Infected_Charger 6
#define L4D2Infected_Witch 7
#define L4D2Infected_Tank 8

// alternative enumeration
// Special infected classes
#define ZC_NONE 0
#define ZC_SMOKER 1
#define ZC_BOOMER 2
#define ZC_HUNTER 3
#define ZC_SPITTER 4
#define ZC_JOCKEY 5
#define ZC_CHARGER 6
#define ZC_WITCH 7
#define ZC_TANK 8
#define ZC_NOTINFECTED 9

// 0=Anywhere, 1=Behind, 2=IT, 3=Specials in front, 4=Specials anywhere, 5=Far Away, 6=Above
#define ANYWHERE 0
#define BEHIND 1
#define IT 2
#define SPECIALS_IN_FRONT 3
#define SPECIALS_ANYWHERE 4
#define FAR_AWAY 5
#define ABOVE 6

/***********************************************************************************************************************************************************************************

                                                                  		SURVIVORS
                                                                    
***********************************************************************************************************************************************************************************/

/**
 * Returns true if the player is currently on the survivor team. 
 *
 * @param client: client ID
 * @return bool
 */
stock bool IsSurvivor(int client) {
	if( IsValidClient(client) && GetClientTeam(client) == L4D2Team_Survivor ) {
		return true;
	} else {
		return false;
	}
}

stock bool IsPinned(int client) {
	bool bIsPinned = false;
	if (IsSurvivor(client)) {
		// check if held by:
		if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ) bIsPinned = true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) bIsPinned = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) bIsPinned = true; // charger carry
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) bIsPinned = true; // charger pound
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ) bIsPinned = true; // jockey
	}		
	return bIsPinned;
}

/**
 * @return: The highest %map completion held by a survivor at the current point in time
 */
stock int GetMaxSurvivorCompletion() {
	float flow = 0.0;
	float tmp_flow;
	float origin[3];
	for ( int client = 1; client <= MaxClients; client++ ) {
		if ( IsSurvivor(client) && IsPlayerAlive(client) ) {
			GetClientAbsOrigin(client, origin);
			tmp_flow = GetFlow(origin);
			flow = MAX(flow, tmp_flow);
		}
	}
	
	int current = RoundToNearest(flow * 100 / L4D2Direct_GetMapMaxFlowDistance());
		
		#if DEBUG_FLOW
			Client_PrintToChatAll( true, "Current: {G}%d%%", current );
		#endif
		
	return current;
}

/**
 * @return: the farthest flow distance currently held by a survivor
 */
stock float GetFarthestSurvivorFlow() {
	float farthest_flow = 0.0;
	float origin[3];
	for (int client = 1; client <= MaxClients; client++) {
        if ( IsSurvivor(client) && IsPlayerAlive(client) ) {
            GetClientAbsOrigin(client, origin);
            float flow = GetFlow(origin);
            if ( flow > farthest_flow ) {
            	farthest_flow = flow;
            }
        }
    }
	return farthest_flow;
}

/**
 * Returns the average flow distance covered by each survivor
 */
stock float GetAverageSurvivorFlow() {
    int survivor_count = 0;
    float total_flow = 0.0;
    float origin[3];
    for (int client = 1; client <= MaxClients; client++) {
        if ( IsSurvivor(client) && IsPlayerAlive(client) ) {
            survivor_count++;
            GetClientAbsOrigin(client, origin);
            if ( GetFlow(origin) != -1.0 ) {
            	total_flow++;
            }
        }
    }
    return (total_flow / float(survivor_count));
}

/**
 * Returns the flow distance from given point to closest alive survivor. 
 * Returns -1.0 if either the given point or the survivors as a whole are not upon a valid nav mesh
 */
stock float GetFlowDistToSurvivors(const float pos[3]) {
	float spawnpoint_flow;
	float lowest_flow_dist = -1.0;
	
	spawnpoint_flow = GetFlow(pos);
	if ( spawnpoint_flow < 0) {
		return -1.0;
	}
	
	for ( int j = 0; j < MaxClients; j++ ) {
		if ( IsSurvivor(j) && IsPlayerAlive(j) ) {
			float origin[3];
			float flow_dist;
			
			GetClientAbsOrigin(j, origin);
			flow_dist = GetFlow(origin);
			
			// have we found a int valid(i.e. != -1) lowest flow_dist
			if ( flow_dist > 0.0 && FloatCompare(FloatAbs(flow_dist - spawnpoint_flow), lowest_flow_dist) == -1 ) {
				lowest_flow_dist = flow_dist;
			}
		}
	}
	
	return lowest_flow_dist;
}

/**
 * Returns the flow distance of a given point
 */
 stock float GetFlow(const float o[3]) {
 	float origin[3]; //non constant var
 	origin[0] = o[0];
 	origin[1] = o[1];
 	origin[2] = o[2];
 	Address pNavArea;
 	pNavArea = L4D2Direct_GetTerrorNavArea(origin);
 	if ( pNavArea != Address_Null ) {
 		return L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
 	} else {
 		return -1.0;
 	}
 }
 
/**
 * Returns true if the player is incapacitated. 
 *
 * @param client client ID
 * @return bool
 */
stock bool IsIncapacitated(int client) {
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

/**
 * Finds the closest survivor excluding a given survivor 
 * @param referenceClient: compares survivor distances to this client
 * @param excludeSurvivor: ignores this survivor
 * @return: the entity index of the closest survivor
**/
stock int GetClosestSurvivor( float referencePos[3], int excludeSurvivor = -1 ) {
	float survivorPos[3];
	int closestSurvivor = GetRandomSurvivor(1, -1);	
	if (closestSurvivor <= 0) return -1;
	GetClientAbsOrigin( closestSurvivor, survivorPos );
	int iClosestAbsDisplacement = RoundToNearest( GetVectorDistance(referencePos, survivorPos) );
	for (int client = 1; client < MaxClients; client++) {
		if( IsSurvivor(client) && IsPlayerAlive(client) && client != excludeSurvivor ) {
			GetClientAbsOrigin( client, survivorPos );
			int iAbsDisplacement = RoundToNearest( GetVectorDistance(referencePos, survivorPos) );			
			if( iClosestAbsDisplacement < 0 ) { // Start with the absolute displacement to the first survivor found:
				iClosestAbsDisplacement = iAbsDisplacement;
				closestSurvivor = client;
			} else if( iAbsDisplacement < iClosestAbsDisplacement ) { // closest survivor so far
				iClosestAbsDisplacement = iAbsDisplacement;
				closestSurvivor = client;
			}			
		}
	}
	return closestSurvivor;
}

/**
 * Returns the distance of the closest survivor or a specified survivor
 * @param referenceClient: the client from which to measure distance to survivor
 * @param specificSurvivor: the index of the survivor to be measured, -1 to search for distance to closest survivor
 * @return: the distance
 */
stock int GetSurvivorProximity( const float rp[3], int specificSurvivor = -1 ) {
	
	int targetSurvivor;
	float targetSurvivorPos[3];
	float referencePos[3]; // non constant var
	referencePos[0] = rp[0];
	referencePos[1] = rp[1];
	referencePos[2] = rp[2];
	

	if( specificSurvivor > 0 && IsSurvivor(specificSurvivor) ) { // specified survivor
		targetSurvivor = specificSurvivor;		
	} else { // closest survivor		
		targetSurvivor = GetClosestSurvivor( referencePos );
	}
	
	if (targetSurvivor <= 0) return -1;

	GetEntPropVector( targetSurvivor, Prop_Send, "m_vecOrigin", targetSurvivorPos );
	return RoundToNearest( GetVectorDistance(referencePos, targetSurvivorPos) );
}

/***********************************************************************************************************************************************************************************

                                                                   	SPECIAL INFECTED 
                                                                    
***********************************************************************************************************************************************************************************/

/**
 * @return: the special infected class of the client
 */
stock int GetInfectedClass(int client) {
    return GetEntProp(client, Prop_Send, "m_zombieClass");
}

stock bool IsInfected(int client) {
    if (!IsClientInGame(client) || GetClientTeam(client) != L4D2Team_Infected) {
        return false;
    }
    return true;
}

/**
 * @return: true if client is a special infected bot
 */
stock bool IsBotInfected(int client) {
    // Check the input is valid
    if (!IsValidClient(client))return false;
    
    // Check if player is a bot on the infected team
    if (IsInfected(client) && IsFakeClient(client)) {
        return true;
    }
    return false; // otherwise
}

stock bool IsBotHunter(int client) {
	return (IsBotInfected(client) && GetInfectedClass(client) == L4D2Infected_Hunter);
}

stock bool IsBotCharger(int client) {
	return (IsBotInfected(client) && GetInfectedClass(client) == L4D2Infected_Charger);
}

stock bool IsBotJockey(int client) {
	return (IsBotInfected(client) && GetInfectedClass(client) == L4D2Infected_Jockey);
}

// @return: the number of a particular special infected class alive in the game
stock int CountSpecialInfectedClass(int targetClass) {
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if ( IsBotInfected(i) && IsPlayerAlive(i) && !IsClientInKickQueue(i) ) {
            int playerClass = GetEntProp(i, Prop_Send, "m_zombieClass");
            if (playerClass == targetClass) {
                count++;
            }
        }
    }
    return count;
}

// @return: the total special infected bots alive in the game
stock int CountSpecialInfectedBots() {
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsBotInfected(i) && IsPlayerAlive(i)) {
            count++;
        }
    }
    return count;
}

/***********************************************************************************************************************************************************************************

                                                                       		TANK
                                                                    
***********************************************************************************************************************************************************************************/

/**
 *@return: true if client is a tank
 */
stock bool IsTank(int client) {
    return IsClientInGame(client)
        && GetClientTeam(client) == L4D2Team_Infected
        && GetInfectedClass(client) == L4D2Infected_Tank;
}

/**
 * Searches for a player who is in control of a tank.
 *
 * @param iTankClient client index to begin searching from
 * @return client ID or -1 if not found
 */
stock int FindTankClient(int iTankClient) {
    for (int i = iTankClient < 0 ? 1 : iTankClient+1; i < MaxClients+1; i++) {
        if (IsTank(i)) {
            return i;
        }
    }
    
    return -1;
}

/**
 * Is there a tank currently in play?
 *
 * @return bool
 */
stock bool IsTankInPlay() {
	if(FindTankClient(-1) != -1)
	{
		return true;
	}
	return false;
}

stock bool IsBotTank(int client) {
	// Check the input is valid
	if (!IsValidClient(client)) return false;
	// Check if player is on the infected team, a hunter, and a bot
	if (GetClientTeam(client) == L4D2Team_Infected) {
		int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombieClass == L4D2Infected_Tank) {
			if(IsFakeClient(client)) {
				return true;
			}
		}
	}
	return false; // otherwise
}

/***********************************************************************************************************************************************************************************

                                                                   			MISC
                                                                    
***********************************************************************************************************************************************************************************/


stock void CheatServerCommand(char[] command)
{
    int flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    ServerCommand("%s", command);
    ServerExecute();
    SetCommandFlags(command, flags);
}

/**
 * Returns true if the client ID is valid
 *
 * @param client: client ID
 * @return bool
 */
stock bool IsValidClient(int client) {
    if( client > 0 && client <= MaxClients && IsClientInGame(client) ) {
    	return true;
    } else {
    	return false;
    }    
}

stock bool IsGenericAdmin(int client) {
	return CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false); 
}

// Kick dummy bot 
public Action Timer_KickBot(Handle timer, any client) {
	if (IsClientInGame(client) && (!IsClientInKickQueue(client))) {
		if (IsFakeClient(client))KickClient(client);
	}

	return Plugin_Continue;
}