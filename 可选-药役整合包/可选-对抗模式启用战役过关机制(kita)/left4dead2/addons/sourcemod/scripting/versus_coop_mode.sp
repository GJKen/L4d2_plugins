#pragma semicolon 1
#pragma newdecls required


#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

ConVar hGameMode;

public Plugin myinfo =
{
	name = "VersusMode",
	author = "kita",
	description = "用于药役模式，实现base on versus下用战役的过关机制",
	version = "1.1",
	url = ""
};

public void OnPluginStart()
{
	hGameMode = FindConVar("mp_gamemode");
	HookEvent("map_transition",		Event_MapTransition);
	HookEvent("round_start",  		Event_RoundStart, EventHookMode_Pre);
	HookEvent("finale_win", Event_FinaleWin, EventHookMode_Pre);
	HookEvent("player_team", evt_ChangeTeam, EventHookMode_Post);   //玩家转换队伍检测事件
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	SetConVarString(hGameMode, "coop");    //计分板出来前切换为coop模式，用战役的方式倒地重启，避免出现下回合出现在特感方并且两次后换图
	return Plugin_Continue;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	SetConVarString(hGameMode, "mutation16");    //回合开始再次设置为base on versus
	return Plugin_Continue;
}

void Event_MapTransition(Event event, const char[] name, bool dontBroadcast) {
	CreateTimer(10.0, Timer_SetVersus);    // 用于换图的时候检测，因为积分版检测部分修改了模式为coop，但是加载地图时候会根据模式来加载对应的地图资源，所以在这里延迟切换为mutation16避免下回合出现coop模式
}

public Action Timer_SetVersus(Handle timer)
{
	SetConVarString(hGameMode, "mutation16");
	return Plugin_Handled;
}

public Action Event_FinaleWin(Event event, const char []name, bool dontBroadcast)
{
	CreateTimer(10.0, Timer_SetVersus);
	return Plugin_Continue;
}



public Action Command_ChooseTeam(int client, const char[] command, int args)
{
	return Plugin_Handled;   //阻止使用m切换队伍
}

public void OnClientPutInServer(int client)
{
	if (client && IsClientConnected(client) && !IsFakeClient(client))
	{
		CreateTimer(3.0, Timer_FirstMoveToSpec, client, TIMER_FLAG_NO_MAPCHANGE);   //玩家回合加入游戏之后3秒检测是否属于特感方，是则移至旁观
	}
}

public Action Timer_FirstMoveToSpec(Handle timer, int client)
{
	if (IsValidPlayerInTeam(client, TEAM_INFECTED))
	{
		ChangeClientTeam(client, TEAM_SPECTATOR);
	}
	return Plugin_Continue;
}

public Action evt_ChangeTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int newteam = event.GetInt("team");
	bool disconnect = event.GetBool("disconnect");
	if (IsValidPlayer(client, true, true) && !disconnect && newteam == TEAM_INFECTED)
	{
		if (!IsFakeClient(client))
		{
			CreateTimer(1.0, MoveClientToSpec, client, TIMER_FLAG_NO_MAPCHANGE);   //玩家更换队伍后检测一次是否属于特感方，是则移至旁观
		}
	}
	return Plugin_Continue;
}

public Action MoveClientToSpec(Handle timer, int client)
{
	ChangeClientTeam(client, TEAM_SPECTATOR);
	return Plugin_Continue;
}

bool IsValidPlayerInTeam(int client, int team)
{
	if (IsValidPlayer(client, true, true))
	{
		if (team == GetClientTeam(client))
		{
			return true;
		}
	}
	return false;
}

bool IsValidPlayer(int client, bool allowbot, bool allowdeath)
{
	if (client && client <= MaxClients)
	{
		if (IsClientConnected(client) && IsClientInGame(client))
		{
			if (!allowbot)
			{
				if (IsFakeClient(client))
				{
					return false;
				}
			}
			if (!allowdeath)
			{
				if (!IsPlayerAlive(client))
				{
					return false;
				}
			}
			return true;
		}
		else
		{
			return false;
		}
	}
	else
	{
		return false;
	}
}