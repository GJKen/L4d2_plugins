#pragma semicolon 1
#pragma newdecls required
#include<sourcemod>
#include<left4dhooks>
#include<colors>

public Plugin myinfo = 
{
	name 			= "[L4D2] Server Mode Tips",
	author 			= "kita, Hatsune Imagine, 修改:GJKen",
	description 	= "离开安全屋提示当前模式以及刷特数量,配合服务器名称显示使用,适配了fdxx/树树子/哈利波特刷特插件",
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
	else if (LibraryExists("l4dinfectedbots"))
	{
		infectedLimit = GetConVarInt(FindConVar("l4d_infectedbots_max_specials"));
		infectedTime = GetConVarInt(FindConVar("l4d_infectedbots_spawn_time_max"));
	}
	else
	{
		infectedLimit = 0;
		infectedTime = 0;
	}

	if (infectedTime == 0 && infectedTime == 0)
		CPrintToChatAll("{green}当前为{blue}%s{default}", GameMode);
	else
		CPrintToChatAll("{green}当前为{blue}%s{default}[{olive}%d{default}特{olive}%d{default}秒]", GameMode, infectedLimit, infectedTime);

	CPrintToChatAll("{olive}!match{green}选择模式 {olive}!v{green}投票菜单 {olive}!b{green}商店 {olive}!maps{green}换官图{blue}/{green}三方图");
}