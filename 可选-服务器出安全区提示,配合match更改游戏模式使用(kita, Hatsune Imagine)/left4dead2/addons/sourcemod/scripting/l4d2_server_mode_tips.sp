#pragma semicolon 1
#pragma newdecls required
#include<sourcemod>
#include<left4dhooks>
#include<colors>

public Plugin myinfo = 
{
	name 			= "[L4D2] Server Mode Tips",
	author 			= "kita, Hatsune Imagine, 修改:GJKen",
	description 	= "离开安全屋提示当前模式以及刷特数量,配合服务器名称显示使用,适配了树树子/fdxx刷特插件",
	version 		= "2.2",
	url 			= "https://github.com/GJKen/L4d2_plugins"
}

public void OnPluginStart() {
	RegConsoleCmd("sm_cm", Command_PrintCurrentMode);
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
	int infectedLimit;
	int infectedTime;

	char GameMode [32];
	GetConVarString(FindConVar("sn_base_mode_name"), GameMode, sizeof(GameMode));

	if (LibraryExists("infected_control"))
	{
		infectedLimit = GetConVarInt(FindConVar("inf_limit"));
		infectedTime = GetConVarInt(FindConVar("inf_spawn_duration"));
	}
	else if (LibraryExists("l4d2_si_spawn_control"))
	{
		infectedLimit = GetConVarInt(FindConVar("l4d2_si_spawn_control_max_specials"));
		infectedTime = GetConVarInt(FindConVar("l4d2_si_spawn_control_spawn_time"));
	}
	else if (LibraryExists("director_si_spawn"))
	{
		infectedLimit = GetConVarInt(FindConVar("sss_1P"));
		infectedTime = GetConVarInt(FindConVar("SS_Time"));
	}
	else
	{
		infectedLimit = 0;
		infectedTime = 0;
	}

	if (infectedTime == 0 && infectedTime == 0)
		CPrintToChatAll("{G}当前为{B}%s", GameMode);
	else
		CPrintToChatAll("{G}当前为{B}%s{W}[{O}%d{W}特{O}%d{W}秒]", GameMode, infectedLimit, infectedTime);

	CPrintToChatAll("{O}!match{W}选择模式 {O}!v{W}投票菜单 {O}!b{W}商店 {O}!maps{W}换官图{B}/{W}三方图");
}