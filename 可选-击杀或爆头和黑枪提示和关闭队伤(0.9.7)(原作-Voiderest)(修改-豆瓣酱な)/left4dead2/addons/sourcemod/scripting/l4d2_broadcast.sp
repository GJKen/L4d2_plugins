#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>

#define DOUBANFIRE		2056
#define DOUBANONFIRE	268435464
#define DOUBOOM			134217792
#define DOUEXPLOSION	16777280
#define DOUBLOWOUT		33554432
#define DOUDETONATE		1107296256

bool l4d2_broadcast_ff, l4d2_OnTakeDamage, broadcast_Switch_true;

ConVar broadcast, broadcast_don_Switch, broadcast_don, broadcast_don_Black_Gun;
int Hbroadcast, Hbroadcast_don_Switch, Hbroadcast_don, Hbroadcast_don_Black_Gun;

int	kill_counts[MAXPLAYERS+1][3], 
	fire_counts[MAXPLAYERS+1][MAXPLAYERS+1];

Handle kill_timers[MAXPLAYERS+1][3];

char g_sHitName[][] = 
{
	"",
	"的\x05头部",
	"的\x05胸部",
	"的\x05腹部",
	"的\x05左手",
	"的\x05右手",
	"的\x05左脚",
	"的\x05右脚"
};

#define VERSION "0.9.7"

public Plugin myinfo = 
{
	name = "L4D Broadcast",
	author = "Voiderest | 豆瓣酱な",
	description = "Displays extra info for kills and friendly fire.",
	version = VERSION,
	url = "N/A"
}

public void OnPluginStart() 
{
	RegConsoleCmd("sm_black", l4d2_broadcast_don, "管理员开启或关闭幸存者黑枪提示.");
	
	broadcast		= CreateConVar("l4d2_broadcast_Kill", "1", "启用击杀或爆头提示? 0=禁用, 1=启用, 2=只在爆头时提示.", FCVAR_NOTIFY);
	broadcast_don	= CreateConVar("l4d2_broadcast_don", "1", "启用幸存者黑枪提示和友伤开关功能? 0=禁用(禁用后指令开关也不可用), 1=启用.", FCVAR_NOTIFY);
	broadcast_don_Switch	= CreateConVar("l4d2_broadcast_don_Switch", "0", "默认关闭或开启黑枪提示和友伤? (或输入指令 !black 开启或关闭) 0=关闭黑枪提示和友伤, 1=开启黑枪提示和友伤.", FCVAR_NOTIFY);
	broadcast_don_Black_Gun	= CreateConVar("l4d2_broadcast_don_black_gun", "1", "开启友伤时关闭黑枪提示? 0=关闭黑枪提示, 1=开启黑枪提示.", FCVAR_NOTIFY);
	
	broadcast.AddChangeHook(SConVardonChanged);
	broadcast_don.AddChangeHook(SConVardonChanged);
	broadcast_don_Switch.AddChangeHook(SConVardonChanged);
	broadcast_don_Black_Gun.AddChangeHook(SConVardonChanged);
	
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	AutoExecConfig(true,"l4d2_broadcast");
}

//地图开始
public void OnMapStart()
{	
	l4d2broadcast();
}

public void SConVardonChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	l4d2broadcast();
}

void l4d2broadcast()
{
	Hbroadcast	= broadcast.IntValue;
	Hbroadcast_don	= broadcast_don.IntValue;
	Hbroadcast_don_Switch	= broadcast_don_Switch.IntValue;
	Hbroadcast_don_Black_Gun	= broadcast_don_Black_Gun.IntValue;
}

public void OnConfigsExecuted()
{
	if(!broadcast_Switch_true)
	{
		switch(Hbroadcast_don_Switch)
		{
			case 0:
			{
				l4d2_broadcast_ff = false;
				l4d2_OnTakeDamage = true;
			}
			case 1:
			{
				l4d2_broadcast_ff = true;
				l4d2_OnTakeDamage = false;
			}
		}
	}
}

public Action l4d2_broadcast_don(int client, int args)
{
	if(bCheckClientAccess(client))
	{
		switch(Hbroadcast_don)
		{
			case 0:
			{
				PrintToChat(client, "\x04[提示]\x05幸存者黑枪提示和队友伤害已禁用,请在CFG中设为1启用.");
			}
			case 1:
			{
				if (l4d2_broadcast_ff)
				{
					l4d2_OnTakeDamage = true;
					l4d2_broadcast_ff = false;
					broadcast_Switch_true = true;
					
					if (!Hbroadcast_don_Black_Gun)
						PrintToChatAll("\x04[提示]\x03已关闭\x05幸存者队友伤害.");
					else
						PrintToChatAll("\x04[提示]\x03已关闭\x05幸存者队友伤害和黑枪提示.");
				}
				else
				{
					l4d2_broadcast_ff = true;
					l4d2_OnTakeDamage = false;
					broadcast_Switch_true = true;
					
					if (!Hbroadcast_don_Black_Gun)
						PrintToChatAll("\x04[提示]\x03已开启\x05幸存者队友伤害.");
					else
						PrintToChatAll("\x04[提示]\x03已开启\x05幸存者队友伤害和黑枪提示.");
				}
			}
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype)
{ 
	if (Hbroadcast_don != 0 && l4d2_OnTakeDamage)
	{
		if(IsValidClient(client) && GetClientTeam(client) == 2)
		{
			if(IsValidClient(attacker) && GetClientTeam(attacker) == 2)
				return Plugin_Handled;
			else
				if(IsDamageTypes(damagetype))
					return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

bool IsDamageTypes(int damagetype)
{
	return damagetype == DMG_BURN  || damagetype == DOUBANFIRE || damagetype == DOUBANONFIRE //火焰伤害.
	|| damagetype == DOUBOOM //土制炸弹,煤气罐,氧气罐爆炸伤害.
	|| damagetype == DOUEXPLOSION  || damagetype == DOUBLOWOUT || damagetype == DOUDETONATE;//榴弹发射器伤害.
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsValidClient(client) && GetClientTeam(client) == 2)
		for (int i = 1; i <= MaxClients; i++)
			fire_counts[client][i] = true;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	bool headshot = GetEventBool(event, "headshot");
	
	if (attacker && GetClientTeam(attacker) != 1 && client != attacker)
		Printkillinfo(attacker, headshot);
}

void Printkillinfo(int attacker, bool headshot)
{
	int murder;
	
	if ((Hbroadcast <= 2) && headshot)
	{
		murder = kill_counts[attacker][0];
		
		if(murder > 1)
		{
			PrintCenterText(attacker, "爆头! +%d", murder);
			KillTimer(kill_timers[attacker][0]);
		}
		else
		{
			PrintCenterText(attacker, "爆头!");
		}
		
		kill_timers[attacker][0] = CreateTimer(5.0, KillCountTimer, (attacker * 10));
		kill_counts[attacker][0] = murder + 1;
	}
	else if (Hbroadcast == 1)
	{
		murder = kill_counts[attacker][1];
		
		if(murder >= 1)
		{
			PrintCenterText(attacker, "击杀! +%d", murder);
			KillTimer(kill_timers[attacker][1]);
		}
		else
		{
			PrintCenterText(attacker, "击杀!");
		}
		
		kill_timers[attacker][1] = CreateTimer(5.0, KillCountTimer, ((attacker * 10) + 1));
		kill_counts[attacker][1] = murder + 1;
	}
}

public Action KillCountTimer(Handle timer, any info) 
{
	int id = info - (info%10);
	info = info-  id;
	id = id / 10;
	
	kill_counts[id][info] = 0;
	return Plugin_Continue;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (Hbroadcast_don != 0 && Hbroadcast_don_Black_Gun != 0 && l4d2_broadcast_ff)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		int attacker = GetClientOfUserId(event.GetInt("attacker"));

		if(IsValidClient(client) && GetClientTeam(client) == 2 && IsValidClient(attacker) && GetClientTeam(attacker) == 2)
		{
			if (client == attacker)
				PrintToChat(attacker, "\x04[提示]\x05请勿自残\x04!");
			else
			{
				if (fire_counts[attacker][client])
				{
					int iBot = IsClientIdle(client);
					int iHitGroup = GetEventInt(event, "hitgroup");
					PrintToChat(attacker, "\x04[提示]\x05你攻击了\x03%s\x04%s\x04.", GetTrueName(client), g_sHitName[iHitGroup]);
					PrintToChat(iBot != 0 ? iBot : client, "\x04[提示]\x03%s\x05攻击了你\x04%s\x04.", GetTrueName(attacker), g_sHitName[iHitGroup]);
				}
			}
			for (int i = 1; i <= MaxClients; i++)
				fire_counts[attacker][client] = false;
		}
	}
}

bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

char[] GetTrueName(int client)
{
	char g_sName[32];
	int Bot = IsClientIdle(client);
	
	if(Bot != 0)
		Format(g_sName, sizeof(g_sName), "闲置:%N", Bot);
	else
		GetClientName(client, g_sName, sizeof(g_sName));
	return g_sName;
}

int IsClientIdle(int client) 
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}