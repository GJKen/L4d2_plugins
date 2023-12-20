#pragma semicolon 1
#pragma newdecls required
#define TEAM_SURVIVOR 2
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin myinfo = 
{
	name 		= "Kill Witch Regain Hp",
	author 		= "kita",
	description 	= "杀妹回血",
	version 		= "1.1",
	url 		= "no"
}

public void OnPluginStart()
{
	HookEvent("witch_killed", evt_WitchKilled, EventHookMode_Post);

}

public void evt_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidSurvivor(client) && IsPlayerAlive(client) && !IsIncapped(client))
	{
		int iMaxHp = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		int iTargetHealth = GetSurvivorPermHealth(client) + 15;
		if (iTargetHealth > iMaxHp)
		{
			iTargetHealth = iMaxHp;
		}
		SetSurvivorPermHealth(client, iTargetHealth);
	}
}

bool IsValidSurvivor(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) ==TEAM_SURVIVOR)
	{
		return true;
	}
	else
	{
		return false;
	}
}


bool IsIncapped(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}


int GetSurvivorPermHealth(int client)
{
	return GetEntProp(client, Prop_Data, "m_iHealth");
}

void SetSurvivorPermHealth(int client, int health)
{
	SetEntProp(client, Prop_Data, "m_iHealth", health);
}
