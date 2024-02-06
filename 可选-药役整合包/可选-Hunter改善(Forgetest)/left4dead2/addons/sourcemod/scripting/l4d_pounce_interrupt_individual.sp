#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Pounce Interrupt Individual",
	author = "Forgetest",
	description = "Skeet at your own risk of a full threshold regardless of assistance.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

int g_iOffs_m_pounceInterruptAmount = -1;
int g_iPounceDamageInterrupt;

int g_iInterruptDamage[MAXPLAYERS+1][MAXPLAYERS+1];

public void OnPluginStart()
{
	g_iOffs_m_pounceInterruptAmount = FindSendPropInfo("CTerrorPlayer", "m_isAttemptingToPounce") + 4;
	
	ConVar cv = FindConVar("z_pounce_damage_interrupt");
	CvarChg_PounceDamageInterrupt(cv, "", "");
	cv.AddChangeHook(CvarChg_PounceDamageInterrupt);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("ability_use", Event_AbilityUse);
	HookEvent("player_bot_replace", Event_PlayerBotReplace);
	HookEvent("bot_player_replace", Event_BotPlayerReplace);
}

void CvarChg_PounceDamageInterrupt(ConVar cv, const char[] oldValue, const char[] newValue)
{
	g_iPounceDamageInterrupt = cv.IntValue;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;
	
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 3)
		return;
	
	SDKHook(client, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, SDK_OnTakeDamageAlive_Post);
}

void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
	static char sAbility[15];
	event.GetString("ability", sAbility, sizeof(sAbility));
	
	if (sAbility[0] == '\0' || sAbility[8] != 'l')
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;
	
	for (int i = 1; i <= MaxClients; ++i)
		g_iInterruptDamage[client][i] = 0;
}

void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	HandlePlayerReplace(GetClientOfUserId(event.GetInt("bot")), GetClientOfUserId(event.GetInt("player")));
}

void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	HandlePlayerReplace(GetClientOfUserId(event.GetInt("player")), GetClientOfUserId(event.GetInt("bot")));
}

void HandlePlayerReplace(int replacer, int replacee)
{
	if (!replacee || !IsClientInGame(replacee))
		return;
	
	if (!replacer || !IsClientInGame(replacer))
		return;
	
	if (GetEntProp(replacer, Prop_Send, "m_zombieClass") != 3)
		return;
	
	SDKUnhook(replacee, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
	SDKUnhook(replacee, SDKHook_OnTakeDamageAlivePost, SDK_OnTakeDamageAlive_Post);
}

public void L4D_OnEnterGhostState(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamageAlivePost, SDK_OnTakeDamageAlive_Post);
}

Action SDK_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damage <= 0.0)
		return Plugin_Continue;
	
	if (!GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce"))
		return Plugin_Continue;
	
	if (attacker <= 0 || attacker > MaxClients)
		return Plugin_Continue;
	
	if (GetClientTeam(attacker) != 2)
		return Plugin_Continue;
	
	int remainInterrupt = g_iPounceDamageInterrupt - g_iInterruptDamage[victim][attacker];
	SetRemainingPounceInterrupt(victim, remainInterrupt);
	
	return Plugin_Continue;
}

void SDK_OnTakeDamageAlive_Post(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (damage <= 0.0)
		return;
	
	if (!GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce"))
		return;
	
	if (attacker <= 0 || attacker > MaxClients)
		return;
	
	if (GetClientTeam(attacker) != 2)
		return;
	
	if (!IsPlayerAlive(victim))
		return;
	
	g_iInterruptDamage[victim][attacker] += RoundToFloor(damage);
}

void SetRemainingPounceInterrupt(int client, int value)
{
	SetEntData(client, g_iOffs_m_pounceInterruptAmount, value);
}
