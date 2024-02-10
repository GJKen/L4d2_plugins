#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#define SERVER_NAME_PATH "configs/hostname.txt"
#define CVAR_FLAG FCVAR_NOTIFY
#define MODE 13

static char serverNamePath[PLATFORM_MAX_PATH];
static KeyValues key;

ConVar
	g_hAllowDisplayInfectedInfo,
	g_hAllowDisplayMode,
	g_hRefreshTime,
	g_hBaseModeName,
	g_hBaseServerName,
	g_hBaseModeCode,
	g_hHostName;

Handle
	g_hRefreshTimer = null;

public Plugin myinfo = 
{
	name 			= "[L4D2] Server Name",
	author 			= "GlowingTree880, kita, 修改:GJKen",
	description 	= "服务器名称显示",
	version 		= "1.0.1.2",
	url 			= "https://github.com/gjken/L4d2_plugins"
}

public void OnPluginStart()
{
	key = CreateKeyValues("ServerName");
	if (!FileToKeyValues(key, serverNamePath)) { SetFailState("无法找到服名文件位于：%s", SERVER_NAME_PATH); }
	g_hAllowDisplayInfectedInfo = CreateConVar("sn_display_infected_info", "0", "是否在服名中显示特感信息,0=关", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowDisplayMode = CreateConVar("sn_display_mode_info", "0", "是否在当前服名中显示什么模式,0=关", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hRefreshTime = CreateConVar("sn_refresh_time", "10", "服名刷新时间-秒", CVAR_FLAG, true, 0.1);
	g_hBaseServerName = CreateConVar("sn_base_server_name", "", "基本服名,配置则使用当前服名,未配置则使用文件中的服名", CVAR_FLAG, true, 0.0);
	g_hBaseModeName = CreateConVar("sn_base_mode_name", "", "基本模式名称,空则不显示", CVAR_FLAG, true, 0.0);
	g_hBaseModeCode = CreateConVar("sn_base_mode_code", "", "基本模式名称代码", CVAR_FLAG, true, 0.0);

	g_hHostName = FindConVar("hostname");
	g_hRefreshTime.AddChangeHook(refreshTimeCvarChanged);
	RegAdminCmd("sm_hostname", refreshHostNameHandler, ADMFLAG_BAN);
	g_hRefreshTimer = CreateTimer(g_hRefreshTime.FloatValue, timerRefreshHostNameHandler, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
	delete key;
	delete g_hRefreshTimer;
}

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
		FormatEx(serverNamePath, sizeof(serverNamePath), "无法找到服名文件位于：%s", SERVER_NAME_PATH);
		strcopy(error, err_max, serverNamePath);
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}


public void OnMapStart()
{
	setServerName();
}

public void refreshTimeCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	delete g_hRefreshTimer;
	g_hRefreshTimer = CreateTimer(g_hRefreshTime.FloatValue, timerRefreshHostNameHandler, _, TIMER_REPEAT);
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
	setServerName();
	return Plugin_Continue;
}

void setServerName()
{
	char cvarString[128], port[16], finalServerName[128];
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

	char c_mode[32];
	char ModeCode[MODE][32] = {"a","b","c","d","e","f","g","h","i","j","k","l","n"};
	char ModeName[MODE][128] = {"[纯净战役]","[绝境战役18特]","[多特战役]","[写专多特]","[无限火力]","[困难无限]","[药役A]","[药役B]","[药役C]","[药役D]","[单人药役]","[HT训练]","[HT x Witch]"};
	// char ModeName[MODE][128] = {"[a纯净模式]","[b绝境战役18特]","[c多特战役]","[d写专多特]","[e无限火力]","[f困难无限]","[g药役A]","[h药役B]","[i药役C]","[j药役D]","[k单人药役]","[lHT训练]","[nHTx Witch]"};
	GetConVarString(g_hBaseModeCode, c_mode, sizeof(c_mode));
	for (int i = 0; i < MODE; i++)
	if(StrEqual(c_mode, ModeCode[i])) {
		g_hBaseModeName.SetString(ModeName[i], false, false);  //将ModeCode对应中文写入sn_base_mode_name里面
	}


	// 配置模式
	if (g_hAllowDisplayMode.BoolValue)
	{
		char modeName[32] = {'\0'};
		g_hBaseModeName.GetString(modeName, sizeof(modeName));
		StrCat(finalServerName, sizeof(finalServerName), modeName);
	}

	// 配置特感信息
	if (g_hAllowDisplayInfectedInfo.BoolValue)
	{
		int cv_hInfectedTime;
		int cv_hInfectedLimit;
		if (LibraryExists("infected_control")) //这个如果不在原插件代码写入注册依赖库这里是return false
		{
			cv_hInfectedLimit = GetConVarInt(FindConVar("inf_limit"));
			cv_hInfectedTime = GetConVarInt(FindConVar("inf_spawn_duration"));
		}
		else if (LibraryExists("l4d2_si_spawn_control"))
		{
			cv_hInfectedLimit = GetConVarInt(FindConVar("l4d2_si_spawn_control_max_specials"));
			cv_hInfectedTime = GetConVarInt(FindConVar("l4d2_si_spawn_control_spawn_time"));
		}
		else if (LibraryExists("l4dinfectedbots"))
		{
			PrintToServer("哈利波特");
			cv_hInfectedLimit = GetConVarInt(FindConVar("l4d_infectedbots_max_specials"));
			cv_hInfectedTime = GetConVarInt(FindConVar("l4d_infectedbots_spawn_time_max"));
		}
		else
		{
			//else判断0不可删,出现找不到cvar的情况会报错
			cv_hInfectedTime = 0;
			cv_hInfectedLimit = 0;
		}

		char infectedInfo[32];
		FormatEx(infectedInfo, sizeof(infectedInfo), "[%d特%d秒]", cv_hInfectedLimit, cv_hInfectedTime);
		StrCat(finalServerName, sizeof(finalServerName), infectedInfo);
	}
	
	g_hHostName.SetString(finalServerName, false, false);
}