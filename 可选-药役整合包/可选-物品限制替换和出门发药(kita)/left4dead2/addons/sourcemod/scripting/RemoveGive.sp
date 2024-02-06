#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin myinfo =
{
	name = "Remove And Give",
	author = "kita",
	description = "回合结束重置状态、出门给药",
	version = "1.3",
	url = "没有，问就是复制粘贴修改一下来的"
}

public void OnPluginStart(){
	HookEvent("map_transition",Event_MapTransition , EventHookMode_Post);
	HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
}


void Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
	//回合结束换图时清除玩家物品
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		{
			RemoveWeapon(client);
		}
	}
}

void Event_PlayerLeftSafeArea(Event event, const char[] name, bool dontBroadcast)
{
	//玩家离开安全区域给药回血
	RestoreHealth();
	GivePill();
}

void RemoveWeapon(int client)
{
	//清除物品
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


void RestoreHealth()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client))
		{
			//死亡玩家复活
			if(!IsPlayerAlive(client))
			{
				L4D_RespawnPlayer(client);
				TeleportClient(client);
			}
			//回血
			GiveCommand(client, "health");
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
			SetEntityHealth(client, GetEntProp(client, Prop_Data, "m_iMaxHealth"));
			SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
			SetEntProp(client, Prop_Send, "m_isGoingToDie", 0);
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
			StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");
		}
	}
}


void GivePill()
{
	//给药
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


void TeleportClient(int client)
{
	//传送
	for (int i = 1; i <= MaxClients; i++)
	{
		float Origin[3];
		if (IsValidSurvivor(i) && i != client)
		{
			ForceCrouch(client);
			GetClientAbsOrigin(i, Origin);
			TeleportEntity(client, Origin, NULL_VECTOR, NULL_VECTOR);
			break;
		}
	}
}

void ForceCrouch(int client)
{
	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
}

bool IsValidSurvivor(int client)
{
	//验证
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2)
		return true;
	else
		return false;
}

//cheat
void GiveCommand(int client, char[] args = "")
{
	int flags = GetCommandFlags("give");	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", args);
	SetCommandFlags("give", flags|FCVAR_CHEAT);
}

