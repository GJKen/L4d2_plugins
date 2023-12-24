#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>


public Plugin myinfo =
{
	name = "Remove And Give",
	author = "kita",
	description = "回合结束清除身上物品，回合开始发药",
	version = "1.1",
	url = "屎山代码别看了"
}

public void OnPluginStart(){
	HookEvent("map_transition",event_map_transition , EventHookMode_Post);
}

void event_map_transition(Event event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		{
			remove_weapon(client);
		}
	}
}

void remove_weapon(int client)
{
	for(int i =0; i < 5; i++)
	{
		int slot = GetPlayerWeaponSlot(client, i);
		if(slot != -1)
		{		
			RemovePlayerItem(client, slot);
			RemoveEntity(slot);
		}
	}
	GivePlayerItem(client,"weapon_pistol");
}



public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	GiveMedicals();
	return Plugin_Stop;
}

public void GiveMedicals()
{
	int flags = GetCommandFlags("give");	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client)==2) 
		{
			FakeClientCommand(client, "give pain_pills");
		}
	}
	SetCommandFlags("give", flags|FCVAR_CHEAT);
}

