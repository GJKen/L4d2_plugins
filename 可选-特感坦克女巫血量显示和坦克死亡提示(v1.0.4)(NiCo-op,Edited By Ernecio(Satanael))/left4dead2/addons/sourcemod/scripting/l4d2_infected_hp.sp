#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
//原作者版本号v1.0.3
#define PLUGIN_VERSION 				"1.0.4"
#define INFECTED_NAMES 				6
#define WITCH_LEN 					32
#define CVAR_FLAGS 					FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION 	FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

public Plugin myinfo =
{
	name 		= "[L4D1 AND L4D2] Infected HP(血量显示)",
	author 		= "NiCo-op, Edited By Ernecio (Satanael)",
	description = "L4D Infected HP",
	version 	= PLUGIN_VERSION,
	url 		= "http://nico-op.forjp.net/"
};

ConVar hPluginEnable;
ConVar hPluginTank;
ConVar hBarLEN;
ConVar hCharHealth;
ConVar hCharDamage;
ConVar hShowType;
ConVar hShowNum;
ConVar hTank;
ConVar hWitch;
ConVar hInfected[INFECTED_NAMES];

bool TankkillFinaleVehicleLeaving;

int witchCUR = 0;
int witchMAX[WITCH_LEN];
int witchHP[WITCH_LEN];
int witchID[WITCH_LEN];
int prevMAX[MAXPLAYERS+1];
int prevHP[MAXPLAYERS+1];
int nCharLength;
int nShowType;
int nShowNum;
int nShowTank;
int nShowWitch;
int nShowFlag[INFECTED_NAMES];

char sCharHealth[8] = "#";
char sCharDamage[8] = "=";

char sClassName[][] = 
{
	"boome",
	"hunter",
	"smoker",
	"jockey",
	"spitter",
	"charger"
};

public void OnPluginStart()
{
	CreateConVar("l4d2_infectedhp_version", PLUGIN_VERSION, "特感血条插件的版本.", CVAR_FLAGS_PLUGIN_VERSION );
	hPluginEnable 	= CreateConVar("l4d2_infectedhp", 				"1", 		"启用插件? 0=禁用, 1=启用.", CVAR_FLAGS);
	hPluginTank		= CreateConVar("l4d2_infectedhp_a",				"1",		"启用坦克卡死提示? 0=禁用, 1=聊天窗, 2=屏幕中下+聊天窗, 3=屏幕中下.", CVAR_FLAGS);
	hBarLEN 		= CreateConVar("l4d2_infectedhp_bar", 			"70", 		"生命条长度(默认100). 最小:10 / 最大:200", CVAR_FLAGS);
	hCharHealth 	= CreateConVar("l4d2_infectedhp_health", 		"|", 		"设置血量符号.", CVAR_FLAGS );
	hCharDamage 	= CreateConVar("l4d2_infectedhp_damage", 		" ", 		"设置去血符号.", CVAR_FLAGS );
	hShowType 		= CreateConVar("l4d2_infectedhp_type", 			"0", 		"设置血条的显示位置和类型. 0=屏幕中心 1=屏幕中下.", CVAR_FLAGS);
	hShowNum 		= CreateConVar("l4d2_infectedhp_num", 			"1", 		"启用血量数字显示? 0=禁用, 1=启用.", CVAR_FLAGS);
	hTank 			= CreateConVar("l4d2_infectedhp_tank", 			"1", 		"启用坦克血条显示? 0=禁用, 1=启用.", CVAR_FLAGS);
	hWitch 			= CreateConVar("l4d2_infectedhp_witch", 		"1", 		"启用女巫血条显示? 0=禁用, 1=启用.", CVAR_FLAGS);
	hInfected[0] 	= CreateConVar("l4d2_infectedhp_zmykey_boomer", "1", 		"启用 boomer 血条显示? 0=禁用, 1=启用.", CVAR_FLAGS);
	
	char bar[64];
	char buffers[64];
	for(int i = 1; i < INFECTED_NAMES; i ++)
	{
		Format(buffers, sizeof(buffers), "l4d2_infectedhp_zmykey_%s", sClassName[i]);
		Format(bar, sizeof(bar), "启用特感 %s 生命血条显示? 0=禁用, 1=启用.", sClassName[i]);
		hInfected[i] = CreateConVar(buffers,"1", bar, CVAR_FLAGS);
	}

	HookEvent("round_start", 	OnRoundStart, 	 EventHookMode_Post);
	HookEvent("player_hurt", 	OnPlayerHurt);
	HookEvent("witch_spawn", 	OnWitchSpawn);
	HookEvent("witch_killed", 	OnWitchKilled);
	HookEvent("infected_hurt", 	OnWitchHurt);
	HookEvent("player_spawn", 	OnInfectedSpawn, EventHookMode_Post);
	HookEvent("player_death", 	OnInfectedDeath, EventHookMode_Pre);
	
	HookEvent("round_start",	Event_RoundStart);//回合开始.
	HookEvent("round_end",		Event_RoundEnd);//回合结束.
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving, EventHookMode_Pre);//救援离开.
//	HookEvent("tank_spawn", 	OnInfectedSpawn);
//	HookEvent("tank_killed", 	OnInfectedDeath, EventHookMode_Pre);

	AutoExecConfig(true, "l4d2_infected_hp");
}

void GetConfig()
{
	char bufA[8];
	char bufB[8];
	hCharHealth.GetString( bufA, sizeof( bufA ) );
	hCharDamage.GetString( bufB, sizeof( bufB ) );
	nCharLength = strlen(bufA);
	if(!nCharLength || nCharLength != strlen(bufB))
	{
		nCharLength = 1;
		sCharHealth[0] = '#';
		sCharHealth[1] = '\0';
		sCharDamage[0] = '=';
		sCharDamage[1] = '\0';
	}
	else
	{
		strcopy(sCharHealth, sizeof(sCharHealth), bufA);
		strcopy(sCharDamage, sizeof(sCharDamage), bufB);
	}

	nShowType = hShowType.BoolValue;
	nShowNum = hShowNum.BoolValue;
	nShowTank = hTank.BoolValue;
	nShowWitch = hWitch.BoolValue;
	for(int i = 0; i < INFECTED_NAMES; i ++)
	{
		nShowFlag[i] = GetConVarBool(hInfected[i]);
	}
}

void ShowHealthGauge(int client, int maxBAR, int maxHP, int nowHP, char[] clName)
{
	int percent = RoundToCeil((float(nowHP) / float(maxHP)) * float(maxBAR));
	int i; 
	int length = maxBAR * nCharLength + 2;
	static char showBAR[256];
	
	showBAR[0] = '\0';
	for(i = 0; i < percent && i < maxBAR; i ++) StrCat(showBAR, length, sCharHealth);
	for(; i < maxBAR; i ++) 					StrCat(showBAR, length, sCharDamage);

	if(nShowType)
	{
		if(!nShowNum) 	PrintHintText(client, "HP: |-%s-|  %s", showBAR, clName);
		else 			PrintHintText(client, "HP: |-%s-|  [%d / %d]  %s", showBAR, nowHP, maxHP, clName);
	}
	else
	{
		if(!nShowNum) 	PrintCenterText(client, "HP: |-%s-|  %s", showBAR, clName);
		else 			PrintCenterText(client, "HP: |-%s-|  [%d / %d]  %s", showBAR, nowHP, maxHP, clName);
	}
}

public void OnRoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	nShowTank = 0;
	nShowWitch = 0;
	witchCUR = 0;
	for(int i = 0; i < WITCH_LEN; i ++)
	{
		witchMAX[i] = -1;
		witchHP[i] = -1;
		witchID[i] = -1;

	}
	for(int i = 0; i < MAXPLAYERS + 1; i ++)
	{
		prevMAX[i] = -1;
		prevHP[i] = -1;
	}
}

public Action TimerSpawn(Handle timer, any client)
{
	if(IsValidEntity(client))
	{
		int val = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		prevMAX[client] = ( val <= 0 ) ? val : 1;
		prevHP[client] = 999999;
	}
	return Plugin_Stop;
}

public void OnInfectedSpawn(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	GetConfig();

	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	
	if( client > 0 && IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == 3 )
	{
		TimerSpawn(INVALID_HANDLE, client);
		CreateTimer(0.5, TimerSpawn, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

//地图结束.
public void OnMapEnd()
{
	TankkillFinaleVehicleLeaving = false;
}

//回合结束.
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	TankkillFinaleVehicleLeaving = false;
}

//回合开始.
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	TankkillFinaleVehicleLeaving = false;
}

//救援离开时.
public void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
	TankkillFinaleVehicleLeaving = true;
}

public void OnInfectedDeath(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if ( !hPluginEnable.BoolValue ) return;

	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	
	if( client > 0 && IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == 3 )
	{
		char clName1[128];
		FormatEx(clName1, sizeof(clName1), "%N", client);
		SplitString(clName1, "Tank", clName1, sizeof(clName1));

		prevMAX[client] = -1;
		prevHP[client] = -1;
		
		int HLZClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (HLZClass == 8 && nShowTank)
		{
			int max = MaxClients;
			
			if (TankkillFinaleVehicleLeaving)
				return;
			
			if(attacker == client)
			{
				if(GetConVarInt(hPluginTank) != 0)
				{
					for(int i=1; i<=max; i++)
					{
						if(IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != 3)
						{
							if(GetConVarInt(hPluginTank) == 1 || GetConVarInt(hPluginTank) == 2)
							{
								PrintToChat(i, "Tank%s\x05被卡到气死了捏❤", clName1);//聊天窗提示.
							}
							if(GetConVarInt(hPluginTank) == 2 || GetConVarInt(hPluginTank) == 3)
							{
								PrintHintText(i, "Tank%s被卡到气死了捏❤", clName1);//屏幕中下提示.
							}
						}
					}
				}
			}
			else
			{
				for(int i=1; i<=max; i++)
				{
					if(IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != 3)
					{
						PrintHintText(i, "❤杂鱼Tank%s嗝屁了捏❤", clName1);
					}
				}
			}
		}
	}
}

public void OnPlayerHurt( Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if(!GetConVarBool(hPluginEnable)) return;
	
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	if(!attacker || !IsClientConnected(attacker) || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2) return;
	
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(!client || !IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 3) return;

	char class[128];
	GetClientModel(client, class, sizeof(class));
	int match = 0;
	for(int i = 0; i < INFECTED_NAMES; i ++){
		if(nShowFlag[i] && StrContains(class, sClassName[i], false) != -1){
			match = 1;
			break;
		}
	}
	
	if(!match && (!nShowTank || (nShowTank && StrContains(class, "tank", false) == -1 && StrContains(class, "hulk", false) == -1))) return;

	int maxBAR = hBarLEN.IntValue;
	int nowHP = GetEntProp(client, Prop_Data, "m_iHealth");
	int maxHP = GetEntProp(client, Prop_Data, "m_iMaxHealth");

	if(nowHP <= 0 || prevMAX[client] < 0) 	nowHP = 0;
	
	if(nowHP && nowHP > prevHP[client]) 	nowHP = prevHP[client];
	else 									prevHP[client] = nowHP;
	
	if(maxHP < prevMAX[client]) 			maxHP = prevMAX[client];
	
	if(maxHP < nowHP){
		maxHP = nowHP;
		prevMAX[client] = nowHP;
	}
	
	if(maxHP < 1) maxHP = 1;

	char clName[MAX_NAME_LENGTH];
	GetClientName(client, clName, sizeof(clName));
	ShowHealthGauge(attacker, maxBAR, maxHP, nowHP, clName);
}

public void OnWitchSpawn( Event hEvent, const char[] sName, bool bDontBroadcast )
{
	GetConfig();

	int entity = hEvent.GetInt( "witchid" );
	witchID[witchCUR] = entity;
	RequestFrame(IsGetWitchID, entity);//为了避免可能出现的问题,这里延迟一帧获取血量.
}

void IsGetWitchID(int entity)
{
	int health = GetEntProp(entity, Prop_Data, "m_iMaxHealth");
	witchMAX[witchCUR] = health;
	witchHP[witchCUR] = health;
	witchCUR = (witchCUR + 1) % WITCH_LEN;
}

public void OnWitchKilled( Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int entity = hEvent.GetInt( "witchid" );
	
	for(int i = 0; i < WITCH_LEN; i ++)
	{
		if(witchID[i] == entity)
		{
			witchMAX[i] = -1;
			witchHP[i] = -1;
			witchID[i] = -1;
			break;
		}
	}
}

public void OnWitchHurt( Event hEvent, const char[] sName, bool bDontBroadcast )
{
	if ( !nShowWitch || !GetConVarBool( hPluginEnable ) ) return;
	
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	if(!attacker || !IsClientConnected(attacker) || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2) return;

	int entity = hEvent.GetInt( "entityid" );
	for(int i = 0; i < WITCH_LEN; i ++)
	{
		if(witchID[i] == entity)
		{
			int damage = GetEventInt(hEvent, "amount");
			int maxBAR = GetConVarInt(hBarLEN);
			int nowHP = witchHP[i] - damage;
			int maxHP = witchMAX[i];

			if(nowHP <= 0 || witchMAX[i] < 0) nowHP = 0;
			
			if(nowHP && nowHP > witchHP[i])	nowHP = witchHP[i];
			else							witchHP[i] = nowHP;
			
			if( maxHP < 1 )	maxHP = 1;
			
			char clName[64];
			if(i == 0) 	strcopy(clName, sizeof(clName), "Witch");
			else 		Format(clName, sizeof(clName), "(%d)Witch", i);
			
			ShowHealthGauge(attacker, maxBAR, maxHP, nowHP, clName);
		}
	}
}
