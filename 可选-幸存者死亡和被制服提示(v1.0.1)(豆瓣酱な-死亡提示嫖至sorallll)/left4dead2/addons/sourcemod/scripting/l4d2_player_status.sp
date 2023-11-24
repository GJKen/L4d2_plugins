//每行代码结束需填写“;”
#pragma semicolon 1
//强制新语法
#pragma newdecls required
#include <sourcemod>
//#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION	"1.0.1"

static const char g_sZombieClass[][] = 
{
	"舌头",
	"胖子",
	"猎人",
	"口水",
	"猴子",
	"牛牛",
	"女巫",//这个应该无效，但是必须有.
	"坦克"
};

bool   g_bShowPromptVariable;

int    g_iPlayerGrab, g_iPlayerDeath, g_iPlayerDown;
ConVar g_hPlayerGrab, g_hPlayerDeath, g_hPlayerDown;

public Plugin myinfo = 
{
	name 			= "l4d2_player_status",
	author 			= "豆瓣酱な | 死亡提示嫖至:sorallll",
	description 	= "幸存者各种提示.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public void OnPluginStart()
{
	HookEvent("round_end", Event_ShowPromptVariable, EventHookMode_Pre);//回合结束.
	HookEvent("finale_vehicle_leaving", Event_ShowPromptVariable, EventHookMode_Pre);//救援离开
	HookEvent("player_ledge_grab", Event_PlayerLedgeGrab);//幸存者挂边.
	HookEvent("player_incapacitated", Event_Incapacitate);//玩家倒下.
	
	g_hPlayerGrab	= CreateConVar("l4d2_enabled_player_grab", "1", "启用幸存者挂边提示? 0=禁用, 1=启用.", FCVAR_NOTIFY);
	g_hPlayerDeath	= CreateConVar("l4d2_enabled_player_death", "1", "启用幸存者死亡提示和击杀者提示? 0=禁用, 1=启用.", FCVAR_NOTIFY);
	g_hPlayerDown	= CreateConVar("l4d2_enabled_player_down", "1", "启用幸存者被制服提示? 0=禁用, 1=启用.", FCVAR_NOTIFY);
	g_hPlayerGrab.AddChangeHook(IsConVarChanged);
	g_hPlayerDeath.AddChangeHook(IsConVarChanged);
	g_hPlayerDown.AddChangeHook(IsConVarChanged);
	
	AutoExecConfig(true, "l4d2_player_status");//生成指定文件名的CFG.
}

//地图开始.
public void OnMapStart()
{
	IsGetCvars();
	g_bShowPromptVariable = false;
}

public void IsConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsGetCvars();
}

void IsGetCvars()
{
	g_iPlayerGrab = g_hPlayerGrab.IntValue;
	g_iPlayerDeath = g_hPlayerDeath.IntValue;
	g_iPlayerDown = g_hPlayerDown.IntValue;
}

//救援离开.
public void Event_ShowPromptVariable(Event event, const char[] name, bool dontBroadcast)
{
	g_bShowPromptVariable = true;
}

//幸存者挂边.
public void Event_PlayerLedgeGrab(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!g_iPlayerGrab || g_bShowPromptVariable)
		return;
	
	if(IsValidClient(client))
		PrintToChatAll("\x04[提示]\x03%s\x05挂边了.", GetTrueName(client));//聊天窗提示.
}

public void OnClientPutInServer(int client) 
{
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);
}

// ------------------------------------------------------------------------
// 死亡提示
// ------------------------------------------------------------------------
void OnTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype) 
{
	if (!g_iPlayerDeath)
		return;

	if (victim < 1 || victim > MaxClients || !IsClientInGame(victim) || GetClientTeam(victim) != 2 || GetEntProp(victim, Prop_Data, "m_iHealth") > 0)
		return;

	if (bIsValidClient(attacker)) 
	{
		if (IsClientInGame(attacker)) 
		{
			switch (GetClientTeam(attacker)) 
			{
				case 2: 
				{
					PrintToChatAll("\x04[提示]\x03%s\x05黑死了\x03%s", GetTrueName(attacker), GetTrueName(victim));//聊天窗提示.
				}
				case 3: 
				{
					if (IsFakeClient(attacker))
						PrintToChatAll("\x04[提示]\x03%s\x05杀死了\x03%s", g_sZombieClass[GetEntProp(attacker, Prop_Send, "m_zombieClass") - 1], GetTrueName(victim));//聊天窗提示.
					else
						PrintToChatAll("\x04[提示]\x03%N(%s)\x05杀死了\x03%s", attacker, g_sZombieClass[GetEntProp(attacker, Prop_Send, "m_zombieClass") - 1], GetTrueName(victim));//聊天窗提示.
				}
			}
		}
	}
	else if (IsValidEntity(attacker)) 
	{
		static char classname[32];
		GetEntityClassname(attacker, classname, sizeof classname);

		if (damagetype & DMG_DROWN && GetEntProp(victim, Prop_Data, "m_nWaterLevel") > 1)
			PrintToChatAll("\x04[提示]\x03%s\x05淹死了.", GetTrueName(victim));//聊天窗提示.
		else if (damagetype & DMG_FALL)
			PrintToChatAll("\x04[提示]\x03%s\x05摔死了,亲亲也起不来了.", GetTrueName(victim));//聊天窗提示.
		else if (strcmp(classname, "worldspawn") == 0 && damagetype == 131072)
			PrintToChatAll("\x04[提示]\x03%s\x05流血而死.", GetTrueName(victim));//聊天窗提示.
		else if (strcmp(classname, "infected") == 0)
			PrintToChatAll("\x04[提示]\x03丧尸\x05杀死了\x03%s", GetTrueName(victim));//聊天窗提示.
		else if (StrEqual(classname, "witch", false))
			PrintToChatAll("\x04[提示]\x03女巫\x05杀死了\x03%s", GetTrueName(victim));//聊天窗提示.
		else if (strcmp(classname, "insect_swarm") == 0)
			PrintToChatAll("\x04[提示]\x05踩痰达人\x03%s\x05已死亡.", GetTrueName(victim));//聊天窗提示.
	}
}

bool bIsValidClient(int client) 
{
	return 0 < client <= MaxClients;
}

//玩家倒下.
public void Event_Incapacitate(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_iPlayerDown || g_bShowPromptVariable)
		return;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	int damagetype = GetEventInt(event, "type");
	int entity = GetEventInt(event, "attackerentid");
	
	if (bIsValidClient(attacker)) 
	{
		if (IsClientInGame(attacker) && IsValidClient(victim)) 
		{
			switch (GetClientTeam(attacker)) 
			{
				case 2: 
				{
					PrintToChatAll("\x04[提示]\x03%s\x05制服了\x03%s", GetTrueName(attacker), GetTrueName(victim));//聊天窗提示.
				}
				case 3: 
				{
					if (IsFakeClient(attacker))
						PrintToChatAll("\x04[提示]\x03%s\x05制服了\x03%s", g_sZombieClass[GetEntProp(attacker, Prop_Send, "m_zombieClass") - 1], GetTrueName(victim));//聊天窗提示.
					else
						PrintToChatAll("\x04[提示]\x03%N(%s)\x05制服了\x03%s", attacker, g_sZombieClass[GetEntProp(attacker, Prop_Send, "m_zombieClass") - 1], GetTrueName(victim));//聊天窗提示.
				}
			}
		}
	}
	else if (IsValidEntity(entity)) 
	{
		char classname[32];
		GetEntityClassname(entity, classname, sizeof(classname));

		if (damagetype & DMG_DROWN && GetEntProp(victim, Prop_Data, "m_nWaterLevel") > 1)
			PrintToChatAll("\x04[提示]\x03%s\x05晕倒了.", GetTrueName(victim));//聊天窗提示.
		else if (damagetype & DMG_FALL)
			PrintToChatAll("\x04[提示]\x03%s\x05摔倒了,亲亲也起不来了.", GetTrueName(victim));//聊天窗提示.
		else if (strcmp(classname, "infected") == 0)
			PrintToChatAll("\x04[提示]\x03丧尸\x05制服了\x03%s", GetTrueName(victim));//聊天窗提示.
		else if (StrEqual(classname, "witch", false))
			PrintToChatAll("\x04[提示]\x03女巫\x05制服了\x03%s", GetTrueName(victim));//聊天窗提示.
		else if (strcmp(classname, "insect_swarm") == 0)
			PrintToChatAll("\x04[提示]\x05踩痰达人\x03%s\x05倒下了.", GetTrueName(victim));//聊天窗提示.
	}
}

bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

char[] GetTrueName(int client)
{
	char g_sName[32];
	int Bot = IsClientIdle(client);
	
	if(Bot != 0)
		Format(g_sName, sizeof(g_sName), "★闲置:%N★", Bot);
	else
		GetClientName(client, g_sName, sizeof(g_sName));
	return g_sName;
}

int IsClientIdle(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}
/*
int IsClientIdle(int bot)
{
	if(IsClientInGame(bot) && GetClientTeam(bot) == 2)
	{
		char sNetClass[12];
		GetEntityNetClass(bot, sNetClass, sizeof(sNetClass));

		if(strcmp(sNetClass, "SurvivorBot") == 0)
		{
			int client = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"));			
			if(client > 0 && IsClientInGame(client))
			{
				return client;
			}
		}
	}
	return 0;
}
*/