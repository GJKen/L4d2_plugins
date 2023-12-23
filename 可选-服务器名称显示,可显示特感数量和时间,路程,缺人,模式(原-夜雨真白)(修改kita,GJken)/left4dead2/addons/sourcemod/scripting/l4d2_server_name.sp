#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include "treeutil\treeutil.sp"

#define SERVER_NAME_PATH "configs/hostname/hostname.txt"
#define CVAR_FLAG FCVAR_NOTIFY

public Plugin myinfo = 
{
	name 			= "L4d2 Server Name",
	author 			= "原-夜雨真白, 修改kita,GJken",
	description 	= "服务器名称配置",
	version 		= "1.0.1.1",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

static char serverNamePath[PLATFORM_MAX_PATH];
static KeyValues key;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "本插件仅支持 Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	BuildPath(Path_SM, serverNamePath, sizeof(serverNamePath), SERVER_NAME_PATH);
	if (!FileExists(serverNamePath))
	{
		FormatEx(serverNamePath, sizeof(serverNamePath), "无法找到服名文件位于:%s", SERVER_NAME_PATH);
		strcopy(error, err_max, serverNamePath);
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

ConVar
	g_hAllowDisplayInfectedInfo,
	g_hAllowDisplayCurrent,
	g_hAllowDisplayMode,
	g_hAllowDisplayNeedPeople,
	g_hRefreshTime,
	g_hBaseModeName,
	g_hBaseServerName;
// 其他 Cvar
ConVar
	g_hHostName;

Handle
	g_hRefreshTimer = null;

public void OnPluginStart()
{
	key = CreateKeyValues("ServerName");
	if (!FileToKeyValues(key, serverNamePath)) { SetFailState("无法找到服名文件位于:%s", SERVER_NAME_PATH); }
	// CreateConVars
	g_hAllowDisplayInfectedInfo = CreateConVar("sn_display_infected_info", "0", "是否在服名中显示特感信息 1=开,0=关", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowDisplayCurrent = CreateConVar("sn_display_current_info", "0", "是否在服名中显示当前路程信息 1=开,0=关", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowDisplayMode = CreateConVar("sn_display_mode_info", "0", "是否在当前服名中显示是什么模式 1=开,0=关", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowDisplayNeedPeople = CreateConVar("sn_display_need_people", "0", "是否在当前服名中显示是否缺人 1=开,0=关", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hRefreshTime = CreateConVar("sn_refresh_time", "10", "服名的刷新时间,单位:秒", CVAR_FLAG, true, 0.1);
	g_hBaseServerName = CreateConVar("sn_base_server_name", "", "基本服名,配置则使用当前服名,未配置则使用文件中的服名", CVAR_FLAG, true, 0.0);
	g_hBaseModeName = CreateConVar("sn_base_mode_name", "", "基本模式名称,未配置则不显示", CVAR_FLAG, true, 0.0);
	// 获取其他 Cvar
	g_hHostName = FindConVar("hostname");
	g_hRefreshTime.AddChangeHook(refreshTimeCvarChanged);
	// AdminCommand
	RegAdminCmd("sm_hostname", refreshHostNameHandler, ADMFLAG_BAN, "立即刷新服名");
	// CreateTimer
	g_hRefreshTimer = CreateTimer(g_hRefreshTime.FloatValue, timerRefreshHostNameHandler, _, TIMER_REPEAT);
}
public void OnPluginEnd()
{
	delete key;
	delete g_hRefreshTimer;
}

public void refreshTimeCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	delete g_hRefreshTimer;
	g_hRefreshTimer = CreateTimer(g_hRefreshTime.FloatValue, timerRefreshHostNameHandler, _, TIMER_REPEAT);
}

public void OnConfigsExecuted()
{
	setServerName();
}

public void OnClientConnected()
{
	setServerName();
}

public void OnClientDisconnect()
{
	setServerName();
}

public Action refreshHostNameHandler(int client, int args)
{
	setServerName();
	return Plugin_Handled;
}

public Action timerRefreshHostNameHandler(Handle timer)
{
	if (FindConVar("sn_display_infected_info") == null)
	{
		g_hRefreshTimer = null;
		return Plugin_Stop;
	}
	setServerName();
	return Plugin_Continue;
}

void setServerName()
{
	//判断不同刷特插件的刷特cvar
	int moreInfectedType = GetConVarInt(FindConVar("l4d2_more_infected_type"));
	int g_hInfectedTime, g_hInfectedLimit;
	// int g_h;
	switch (moreInfectedType)
	{
		case 1:
		{
			g_hInfectedLimit = GetConVarInt(FindConVar("l4d2_si_spawn_control_max_specials"));
			g_hInfectedTime = GetConVarInt(FindConVar("l4d2_si_spawn_control_spawn_time"));
		}
		case 2:
		{
			g_hInfectedLimit = GetConVarInt(FindConVar("inf_limit"));
			g_hInfectedTime = GetConVarInt(FindConVar("inf_spawn_duration"));
		}
		case 3:
		{
			g_hInfectedLimit = GetConVarInt(FindConVar("l4d_infectedbots_max_specials"));
			g_hInfectedTime = GetConVarInt(FindConVar("l4d_infectedbots_spawn_time_max"));
		}
		default:
		{
			g_hInfectedTime = 0;
			g_hInfectedLimit = 0;
		}
	}

	char
		cvarString[128],
		port[16],
		finalServerName[128];
	// 获取基本服名
	g_hBaseServerName.GetString(cvarString, sizeof(cvarString));
	FindConVar("hostport").GetString(port, sizeof(port));
	// 配置基本服名
	if (strlen(cvarString) < 1) {
		// 基本服名不存在, 找 hostport 中的端口配置, 如未配置则使用 Left 4 Dead 2
		key.Rewind();
		// 找到在文件中配置的端口
		if (key.JumpToKey(port, false)) { key.GetString("baseName", finalServerName, sizeof(finalServerName), "Left 4 Dead 2"); }
		else { FormatEx(finalServerName, sizeof(finalServerName), "Left 4 Dead 2"); }
	} else {
		FormatEx(finalServerName, sizeof(finalServerName), "%s", cvarString);
	}
	// 配置特感信息(kita)
	if (g_hAllowDisplayInfectedInfo.BoolValue)
	{
		char infectedInfo[32];
		FormatEx(infectedInfo, sizeof(infectedInfo), "[%d特%d秒]", g_hInfectedLimit, g_hInfectedTime);
		StrCat(finalServerName, sizeof(finalServerName), infectedInfo);
	}
	// 配置路程
	if (g_hAllowDisplayCurrent.BoolValue)
	{
		char currentInfo[32] = {'\0'};
		FormatEx(currentInfo, sizeof(currentInfo), "[当前%d%%]", RoundToNearest(getSurvivorFlow() * 100.0));
		StrCat(finalServerName, sizeof(finalServerName), currentInfo);
	}
	// 配置模式(kita)
	if (g_hAllowDisplayMode.BoolValue)
	{
		char num[64], modeName[64];
		GetConVarString(g_hBaseModeName, num, sizeof(num));

		if(StrContains(num, "a", false) != -1)
		{
		Format(modeName,sizeof(modeName),"纯净战役");
		}
		else if(StrContains(num, "b", false) != -1)
		{
		Format(modeName,sizeof(modeName),"多特战役");
		}
		else if(StrContains(num, "c", false) != -1)
		{
		Format(modeName,sizeof(modeName),"增强多特");
		}
		else if(StrContains(num, "d", false) != -1)
		{
		Format(modeName,sizeof(modeName),"坐牢战役");
		}
		else if(StrContains(num, "e", false) != -1)
		{
		Format(modeName,sizeof(modeName),"简单药役");
		}
		else if(StrContains(num, "f", false) != -1)
		{
		Format(modeName,sizeof(modeName),"正常药役");
		}
		else if(StrContains(num, "g", false) != -1)
		{
		Format(modeName,sizeof(modeName),"坐牢药役");
		}
		else if(StrContains(num, "h", false) != -1)
		{
		Format(modeName,sizeof(modeName),"单人战役");
		}
		else if(StrContains(num, "i", false) != -1)
		{
		Format(modeName,sizeof(modeName),"单人药役");
		}
		else if(StrContains(num, "j", false) != -1)
		{
		Format(modeName,sizeof(modeName),"单人多特");
		}
		else if(StrContains(num, "k", false) != -1)
		{
		Format(modeName,sizeof(modeName),"普通战役");
		}
		else if(StrContains(num, "l", false) != -1)
		{
		Format(modeName,sizeof(modeName),"无限火力");
		}
		else if(StrContains(num, "m", false) != -1)
		{
		Format(modeName,sizeof(modeName),"高级无限");
		}
		else if(StrContains(num, "n", false) != -1)
		{
		Format(modeName,sizeof(modeName),"HT训练");
		}
		else {modeName = num;}

		StrCat(finalServerName, sizeof(finalServerName), "[");
		StrCat(finalServerName, sizeof(finalServerName), modeName);
		StrCat(finalServerName, sizeof(finalServerName), "]");
	}
	// 配置是否缺人
	if (g_hAllowDisplayNeedPeople.BoolValue)
	{
		if (isServerEmpty()) { StrCat(finalServerName, sizeof(finalServerName), "[无人]"); }
		else { if (isNeedPeople()) { StrCat(finalServerName, sizeof(finalServerName), "[缺人]"); } }
	}
	g_hHostName.SetString(finalServerName, false, false);
}

bool isServerEmpty()
{
	for (int i = 1; i <= MaxClients; i++) { if (IsClientConnected(i) && !IsFakeClient(i)) { return false; } }
	return true;
}

bool isNeedPeople()
{
	for (int i = 1; i <= MaxClients; i++) { if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR) { return true; } }
	return false;
}

float getSurvivorFlow()
{
	static float maxDistance;
	static int targetSurvivor;
	targetSurvivor = L4D_GetHighestFlowSurvivor();
	if (!IsValidSurvivor(targetSurvivor)) { L4D2_GetFurthestSurvivorFlow(); }
	else { maxDistance = L4D2Direct_GetFlowDistance(targetSurvivor); }
	return maxDistance / L4D2Direct_GetMapMaxFlowDistance();
}