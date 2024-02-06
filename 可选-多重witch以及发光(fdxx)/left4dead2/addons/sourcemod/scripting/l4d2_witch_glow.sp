#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VERSION "0.3"

ConVar
	g_cvGlowMinRange,
	g_cvGlowMaxRange;

int
	g_iGlowMinRange,
	g_iGlowMaxRange;

public Plugin myinfo =
{
	name = "L4D2 Witch glow",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_witch_glow_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_cvGlowMinRange = CreateConVar("l4d2_witch_glow_min_range", "300");
	g_cvGlowMaxRange = CreateConVar("l4d2_witch_glow_max_range", "2000");

	OnConVarChanged(null, "", "");

	g_cvGlowMinRange.AddChangeHook(OnConVarChanged);
	g_cvGlowMaxRange.AddChangeHook(OnConVarChanged);

	HookEvent("witch_spawn", Event_WitchSpawn);
	HookEvent("witch_harasser_set", Event_WitchHarasserSet);
	HookEvent("witch_killed", Event_Witchkilled, EventHookMode_Pre);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iGlowMinRange = g_cvGlowMinRange.IntValue;
	g_iGlowMaxRange = g_cvGlowMaxRange.IntValue;
}

void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (IsValidEntityEx(witch))
		SetGlow(witch);
}

void Event_WitchHarasserSet(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (IsValidEntityEx(witch))
		RestGlow(witch);
}

void Event_Witchkilled(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (IsValidEntityEx(witch))
		RestGlow(witch);
}

bool IsValidEntityEx(int entity)
{
	return entity > MaxClients && IsValidEntity(entity);
}

void SetGlow(int witch)
{
	SetEntProp(witch, Prop_Send, "m_iGlowType", 3);
	SetEntProp(witch, Prop_Send, "m_glowColorOverride", 16777215);
	SetEntProp(witch, Prop_Send, "m_nGlowRangeMin", g_iGlowMinRange);
	SetEntProp(witch, Prop_Send, "m_nGlowRange", g_iGlowMaxRange);
}

void RestGlow(int witch)
{
	SetEntProp(witch, Prop_Send, "m_iGlowType", 0);
	SetEntProp(witch, Prop_Send, "m_glowColorOverride", 0);
	SetEntProp(witch, Prop_Send, "m_nGlowRangeMin", 0);
	SetEntProp(witch, Prop_Send, "m_nGlowRange", 0);
}
