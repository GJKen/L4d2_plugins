/*  
*    Fixes for gamebreaking bugs and stupid gameplay aspects
*    Copyright (C) 2022  LuxLuma
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU General Public License as published by
*    the Free Software Foundation, either version 3 of the License, or
*    (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU General Public License for more details.
*
*    You should have received a copy of the GNU General Public License
*    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <sourcescramble>

#pragma newdecls required

#define GAMEDATA "charger_collision_patch"
#define CHARGE_MARKSURVIVOR_KEY "CCharge::HandleCustomCollision()::MarkSurvivor"
#define CHARGE_ISINCAPPED_KEY "CCharge::HandleCustomCollision()::IsIncap"
#define PLUGIN_VERSION	"2.0"


#define IMPACT_SND_INTERVAL 0.1

enum struct ChargerCharge
{
	int m_Index;
	float m_NextImpactSND;
	bool m_MarkHit[MAXPLAYERS+1];
	
	void Reset()
	{
		this.m_NextImpactSND = 0.0;
		for(int i; i <= MAXPLAYERS; ++i)
		{
			this.m_MarkHit[i] = false;
		}
	}
}

ChargerCharge g_ChargerCharge[MAXPLAYERS+1];

MemoryPatch Charge_MarkSurvivor;
Handle g_hSetAbsVelocity;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "[L4D2]Charger_Collision_Patch",
	author = "Lux",
	description = "Fixes charger only allow to his 1 survivor index & allows colliding same target more than once",
	version = PLUGIN_VERSION,
	url = "forums.alliedmods.net/showthread.php?p=2647017"
};


public void OnPluginStart()
{
	CreateConVar("charger_collision_patch_version", PLUGIN_VERSION, "", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	for(int i; i <= MAXPLAYERS; ++i)
	{
		g_ChargerCharge[i].m_Index = i;
	}
	
	Handle hGamedata = LoadGameConfigFile(GAMEDATA);
	if(hGamedata == null) 
	{
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
	}
	
	Charge_MarkSurvivor = MemoryPatch.CreateFromConf(hGamedata, CHARGE_MARKSURVIVOR_KEY);
	if(!Charge_MarkSurvivor.Validate())
	{
		SetFailState("Failed to validate patch \"%s\"", CHARGE_MARKSURVIVOR_KEY);
	}
	
	Handle hDetour;
	hDetour = DHookCreateFromConf(hGamedata, "Lux::ThrowImpactedSurvivor");
	if(!hDetour)
	{
		SetFailState("Failed to find 'Lux::ThrowImpactedSurvivor' signature");
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	if(!PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CBaseEntity::SetAbsVelocity"))
	{
		SetFailState("Error finding the 'CBaseEntity::SetAbsVelocity' signature.");
	}
	
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	g_hSetAbsVelocity = EndPrepSDKCall();
	if(g_hSetAbsVelocity == null)
	{
		SetFailState("Unable to prep SDKCall 'CBaseEntity::SetAbsVelocity'");
	}
	
	if(!DHookEnableDetour(hDetour, false, ThrowImpactedSurvivor))
	{
		SetFailState("Failed to detour 'Lux::ThrowImpactedSurvivor'");
	}
	
	if(Charge_MarkSurvivor.Enable())
	{
		PrintToServer("[%s] Enabled \"%s\" patch", GAMEDATA, CHARGE_MARKSURVIVOR_KEY);
	}
	
	delete hGamedata;
	
	HookEvent("round_start", RoundStart);
	HookEvent("charger_charge_start", ClearMarkedSurvivors, EventHookMode_Pre);
	HookEvent("charger_charge_end", ClearMarkedSurvivors, EventHookMode_Pre);
	AddNormalSoundHook(ImpactSNDHook);
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

public MRESReturn ThrowImpactedSurvivor(Handle hReturn, Handle hParams)
{
	int iCharger = DHookGetParam(hParams, 1);
	int iVictim = DHookGetParam(hParams, 2);
	bool ShouldDamage = DHookGetParam(hParams, 4);
	
	//sanity check everything avoids conflicts
	if(!ShouldDamage)
		return MRES_Ignored;
	
	if(iCharger < 1 || iCharger > MaxClients || 
		GetClientTeam(iCharger) != 3 || !IsPlayerAlive(iCharger))
	{
		return MRES_Ignored;
	}
	
	int iAbility = GetEntPropEnt(iCharger, Prop_Send, "m_customAbility");
	if(iAbility == -1 || !HasEntProp(iAbility, Prop_Send, "m_isCharging"))
	{
		return MRES_Ignored;
	}
	
	if(!GetEntProp(iAbility, Prop_Send, "m_isCharging", 1))
		return MRES_Ignored;
	
	int iCarryVictim = GetEntPropEnt(iCharger, Prop_Send, "m_carryVictim");
	if(iCarryVictim == -1)
	{
		DHookSetReturn(hReturn, 1);
		return MRES_Supercede;
	}
	
	if(iCarryVictim == iVictim)
	{
		//PrintToChatAll("illegal damage on %N from %N", iVictim, iCharger);
		g_ChargerCharge[iCharger].m_NextImpactSND = GetGameTime() + IMPACT_SND_INTERVAL;
		DHookSetReturn(hReturn, 1);
		return MRES_Supercede;
	}
	
	//Set velocity to 0 so impulse velocity does not account for current velocity
	static float vecNoVel[3] = {0.0, 0.0, 0.0};
	SDKCall(g_hSetAbsVelocity, iVictim, vecNoVel);
	
	g_ChargerCharge[iCharger].m_NextImpactSND = GetGameTime() + IMPACT_SND_INTERVAL;
	if(g_ChargerCharge[iCharger].m_MarkHit[iVictim])
	{
		DHookSetParam(hParams, 4, false);
		DHookSetReturn(hReturn, 1);
		return MRES_ChangedHandled;
	}
	g_ChargerCharge[iCharger].m_MarkHit[iVictim] = true;
	return MRES_Ignored;
}

public Action ImpactSNDHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &iCharger, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if(iCharger < 1 || iCharger > MaxClients || 
		GetClientTeam(iCharger) != 3 || !IsPlayerAlive(iCharger))
	{
		return Plugin_Continue;
	}
	
	int iAbility = GetEntPropEnt(iCharger, Prop_Send, "m_customAbility");
	if(iAbility == -1 || !HasEntProp(iAbility, Prop_Send, "m_isCharging"))
	{
		return Plugin_Continue;
	}
	
	if(!GetEntProp(iAbility, Prop_Send, "m_isCharging", 1))
		return Plugin_Continue;
	
	if(g_ChargerCharge[iCharger].m_NextImpactSND > GetGameTime())
	{
		if(StrContains(sample, "player/charger/hit/charger_smash_0", false) != -1)
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_SpawnPost, OnSpawnPost);
}

public void OnSpawnPost(int client)
{
	g_ChargerCharge[client].Reset();
	for(int i; i <= MAXPLAYERS; ++i)
	{
		g_ChargerCharge[i].m_MarkHit[client] = false;
	}
}

public void RoundStart(Event event, const char[] eventName, bool dontBroadcast)
{
	for(int i; i <= MAXPLAYERS; ++i)
	{
		g_ChargerCharge[i].Reset();
	}
}

public void ClearMarkedSurvivors(Event event, const char[] eventName, bool dontBroadcast)
{
	int iCharger = GetClientOfUserId(event.GetInt("userid"));
	if(iCharger < 1)
		return;
	
	for(int i; i <= MAXPLAYERS; ++i)
	{
		g_ChargerCharge[iCharger].m_MarkHit[i] = false;
	}
}