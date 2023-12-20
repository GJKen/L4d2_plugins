#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#include <colors>


public Plugin myinfo = 
{
	name 			= "Server Text",
	author 			= "kita, Hatsune Imagine",
	description 	= "离开安全屋提示当前模式以及刷特数量",
	version 		= "2.2",
	url 			= "N/A"
}


// ConVars
ConVar cv_MyGameMode, cv_MoreInfectedType;

public void OnPluginStart() {
	cv_MyGameMode = CreateConVar("l4d2_my_gamemode", "1", "My Custom GameMode. 1=纯净战役, 2=多特战役 3=多特战役+特感增强 4=坐牢战役 5=简单药役 6=正常药役 7=坐牢药役 8=正常单人 9=坐牢单人 10=普通战役", FCVAR_NONE);
	cv_MoreInfectedType = CreateConVar("l4d2_more_infected_type", "0", "More Infected plugin type. 0=关闭, 1=fdxx多特, 2=夜羽真白多特");

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
		default: {
			infectedLimit = 0;
			infectedTime = 0;
		}
	}

	switch (mode)
	{
		case 1:
			CPrintToChatAll("{G}当前模式为：{B} <纯净模式>  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单");
		case 2:
			CPrintToChatAll("{G}当前模式为：{B} <多特模式>  {O}[%d特%d秒]  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单", infectedLimit, infectedTime);
		case 3:
			CPrintToChatAll("{G}当前模式为：{B} <增强多特>  {O}[%d特%d秒]  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单", infectedLimit, infectedTime);
		case 4:
			CPrintToChatAll("{G}当前模式为：{B} <坐牢多特>  {O}[%d特%d秒]  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单", infectedLimit, infectedTime);
		case 5:
			CPrintToChatAll("{G}当前模式为：{B} <简单药役>  {O}[%d特%d秒]  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单", infectedLimit, infectedTime);
		case 6:
			CPrintToChatAll("{G}当前模式为：{B} <正常药役>  {O}[%d特%d秒]  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单", infectedLimit, infectedTime);
		case 7:
			CPrintToChatAll("{G}当前模式为：{B} <坐牢药役>  {O}[%d特%d秒]  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单", infectedLimit, infectedTime);
		case 8:
			CPrintToChatAll("{G}当前模式为：{B} <单人模式>  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单");
		case 9:
			CPrintToChatAll("{G}当前模式为：{B} <单人药役>  {O}[%d特%d秒]  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单", infectedLimit, infectedTime);
		case 10:
			CPrintToChatAll("{G}当前模式为：{B} <单人多特>  {O}[%d特%d秒]  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单", infectedLimit, infectedTime);
		case 11:
			CPrintToChatAll("{G}当前模式为：{B} <普通模式>  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单");
		case 12:
			CPrintToChatAll("{G}当前模式为：{B} <无限火力>  {O}[%d特%d秒]  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单", infectedLimit, infectedTime);
		case 13:
			CPrintToChatAll("{G}当前模式为：{B} <高级无限>  {O}[%d特%d秒]  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单", infectedLimit, infectedTime);
		case 14:
			CPrintToChatAll("{G}当前模式为：{B} <HT训练>  {O}[%d特%d秒]  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单", infectedLimit, infectedTime);
		default:
			CPrintToChatAll("{G}当前模式为：{B} <未知模式>  {W}输入{O}!match{W}选择模式  {O}!v{W}打开投票菜单");
	}
}
