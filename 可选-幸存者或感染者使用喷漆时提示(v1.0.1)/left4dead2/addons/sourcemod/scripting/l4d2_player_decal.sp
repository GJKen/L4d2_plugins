#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"1.0.0"

static const char g_sSurvivorNames[][] = 
{
	"Nick",
	"Rochelle",
	"Coach",
	"Ellis",
	"Bill",
	"Zoey",
	"Francis",
	"Louis"
};

static const char g_sSurvivorModels[][] = 
{
	"models/survivors/survivor_gambler.mdl",
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_coach.mdl",
	"models/survivors/survivor_mechanic.mdl",
	"models/survivors/survivor_namvet.mdl",
	"models/survivors/survivor_teenangst.mdl",
	"models/survivors/survivor_biker.mdl",
	"models/survivors/survivor_manager.mdl"
};

static const char g_sZombieName[][] = 
{
	"舌头",
	"胖子",
	"猎人",
	"口水",
	"猴子",
	"牛牛",
	"女巫",
	"坦克"
};

public Plugin myinfo = 
{
	name 			= "l4d2_player_decal",
	author 			= "",
	description 	= "生还者或感染者使用喷漆时提示.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public void OnPluginStart() 
{
	AddTempEntHook("Player Decal", PlayerDecal);
}

public Action PlayerDecal(const char[] te_name, const int[] Players, int numClients, float delay)
{
	int client = TE_ReadNum("m_nPlayer");
	
	if(IsValidClient(client))
	{
		int iTeam = GetClientTeam(client);

		switch (iTeam)
		{
			case 2:
				PrintToChatAll("\x04[提示]\x03%s(%s)\x05使用了喷漆.", GetPlayerName(client), GetPlayerModel(client));
			case 3:
				PrintToChatAll("\x04[提示]\x03%s(%s)\x05使用了喷漆.", GetPlayerName(client), g_sZombieName[GetEntProp(client, Prop_Send, "m_zombieClass") - 1]);
			default:
				PrintToChatAll("\x04[提示]\x03%s\x05使用了喷漆.", GetPlayerName(client));
		}
	}
	return Plugin_Continue;
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock char[] GetPlayerName(int client)
{
	char g_sName[32];
	GetClientName(client, g_sName, sizeof(g_sName));
	return g_sName;
}

stock char[] GetPlayerModel(int client)
{
	char sModel[64];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	for (int i = 0; i < sizeof(g_sSurvivorModels); i++)
	{
		if (strcmp(sModel, g_sSurvivorModels[i], false) == 0)
		{
			strcopy(sModel, sizeof(sModel), g_sSurvivorNames[i]);
			break;
		}
	}
	return sModel;
}