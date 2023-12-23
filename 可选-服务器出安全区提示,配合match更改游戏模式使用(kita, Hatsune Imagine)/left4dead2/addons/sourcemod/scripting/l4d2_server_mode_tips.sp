#pragma semicolon 1
#pragma newdecls required
#include<sourcemod>
#include<left4dhooks>
#include<colors>

public Plugin myinfo = 
{
	name 			= "Server Mode Tips",
	author 			= "kita, Hatsune Imagine, 修改:GJKen",
	description 	= "离开安全屋提示当前模式以及刷特数量",
	version 		= "2.2",
	url 			= "N/A"
}

// ConVars
ConVar cv_MyGameMode, cv_MoreInfectedType;

public void OnPluginStart() {
	cv_MyGameMode = CreateConVar("l4d2_my_gamemode", "1", "My Custom GameMode. 1=纯净战役, 2=多特战役 3=增强多特 4=坐牢战役 5=简单药役 6=正常药役 7=坐牢药役 8=单人战役 9=单人药役 10=单人多特 11=普通战役 12=无限火力 13=高级无限 14=HT训练", FCVAR_NONE);
	cv_MoreInfectedType = CreateConVar("l4d2_more_infected_type", "0", "More Infected plugin type. 0=关闭, 1=fdxx多特, 2=夜羽真白多特 3=哈利波特多特");

	RegConsoleCmd("sm_cm", Command_PrintCurrentMode);
	RegConsoleCmd("sm_current_mode", Command_PrintCurrentMode);
}

Action Command_PrintCurrentMode(int client, int args) {
	PrintModeInfo();
	return Plugin_Continue;
}

public Action L4D_OnFirstSurvivorLeftSafeArea() {
	PrintModeInfo();
	return Plugin_Continue;
}

void PrintModeInfo() {
	int mode = GetConVarInt(cv_MyGameMode);
	int moreInfectedType = GetConVarInt(cv_MoreInfectedType);
	int infectedLimit;
	int infectedTime;
	switch (moreInfectedType) {
		case 1: {
			infectedLimit = GetConVarInt(FindConVar("l4d2_si_spawn_control_max_specials"));
			infectedTime = GetConVarInt(FindConVar("l4d2_si_spawn_control_spawn_time"));
		}
		case 2: {
			infectedLimit = GetConVarInt(FindConVar("inf_limit"));
			infectedTime = GetConVarInt(FindConVar("inf_spawn_duration"));
		}
		case 3: {
			infectedLimit = GetConVarInt(FindConVar("l4d_infectedbots_max_specials"));
			infectedTime = GetConVarInt(FindConVar("l4d_infectedbots_spawn_time_max"));
		}
		default: {
			infectedLimit = 0;
			infectedTime = 0;
		}
	}

	switch (mode)
	{
		case 1:
			CPrintToChatAll("{green}当前模式为{blue}<纯净战役>");
		case 2:
			CPrintToChatAll("{green}当前模式为{blue}<多特战役>{green}[%d特%d秒]", infectedLimit, infectedTime);
		case 3:
			CPrintToChatAll("{green}当前模式为{blue}<增强多特>{green}[%d特%d秒]", infectedLimit, infectedTime);
		case 4:
			CPrintToChatAll("{green}当前模式为{blue}<坐牢战役>{green}[%d特%d秒]", infectedLimit, infectedTime);
		case 5:
			CPrintToChatAll("{green}当前模式为{blue}<简单药役>{green}[%d特%d秒]", infectedLimit, infectedTime);
		case 6:
			CPrintToChatAll("{green}当前模式为{blue}<正常药役>{green}[%d特%d秒]", infectedLimit, infectedTime);
		case 7:
			CPrintToChatAll("{green}当前模式为{blue}<坐牢药役>{green}[%d特%d秒]", infectedLimit, infectedTime);
		case 8:
			CPrintToChatAll("{green}当前模式为{blue}<单人战役>");
		case 9:
			CPrintToChatAll("{green}当前模式为{blue}<单人药役>{green}[%d特%d秒]", infectedLimit, infectedTime);
		case 10:
			CPrintToChatAll("{green}当前模式为{blue}<单人多特>{green}[%d特%d秒]", infectedLimit, infectedTime);
		case 11:
			CPrintToChatAll("{green}当前模式为{blue}<普通战役>");
		case 12:
			CPrintToChatAll("{green}当前模式为{blue}<无限火力>{green}[%d特%d秒]", infectedLimit, infectedTime);
		case 13:
			CPrintToChatAll("{green}当前模式为{blue}<高级无限>{green}[%d特%d秒]", infectedLimit, infectedTime);
		case 14:
			CPrintToChatAll("{green}当前模式为{blue}<HT训练>{green}[%d特%d秒]", infectedLimit, infectedTime);
		default:
			CPrintToChatAll("{green}当前模式为{blue}<未知>");
	}
	CPrintToChatAll("{olive}!match{green}选择模式 {olive}!v{green}投票菜单 {olive}!b{green}商店 {olive}!maps{green}换官图{blue}/{green}三方图");
}
