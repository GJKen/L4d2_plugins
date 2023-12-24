#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "0.2"

ConVar
	g_cvInterval,
	g_cvMaxHeal,
	g_cvIncrement;

float
	g_fInterval,
	g_fMaxHeal,
	g_fRemaining[MAXPLAYERS],
	g_fIncrement;

Handle
	g_hTimer[MAXPLAYERS];

public Plugin myinfo = 
{
	name = "L4D2 Hot pills",
	author = "ProdigySim, CircleSquared, fdxx",
	description = "Pills heal over time",
	version = VERSION,
	url = "https://bitbucket.org/ProdigySim/misc-sourcemod-plugins"
}

public void OnPluginStart()
{
	CreateConVar("l4d2_hot_pills_version", VERSION, "Version", FCVAR_NONE | FCVAR_DONTRECORD);

	g_cvInterval = CreateConVar("l4d2_hot_pills_interval", "0.1", "Interval", FCVAR_NONE);
	g_cvIncrement = CreateConVar("l4d2_hot_pills_increment", "2.0", "Increment", FCVAR_NONE);
	g_cvMaxHeal = CreateConVar("l4d2_hot_pills_max_heal", "50.0", "Max heal", FCVAR_NONE);

	g_cvInterval.AddChangeHook(OnConVarChanged);
	g_cvIncrement.AddChangeHook(OnConVarChanged);
	g_cvMaxHeal.AddChangeHook(OnConVarChanged);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("pills_used", Event_PillsUsed);
	HookEvent("player_bot_replace", Event_BotReplacedPlayer);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fInterval = g_cvInterval.FloatValue;
	g_fIncrement = g_cvIncrement.FloatValue;
	g_fMaxHeal = g_cvMaxHeal.FloatValue;
}

public void OnConfigsExecuted()
{
	GetCvars();
	FindConVar("pain_pills_health_value").IntValue = 0;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

public void OnMapEnd()
{
	Reset();
}

void Reset()
{
	static int i;
	for (i = 0; i <= MaxClients; i++)
	{
		delete g_hTimer[i];
	}
}

void Event_BotReplacedPlayer(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hTimer[GetClientOfUserId(event.GetInt("player"))];
}

public void OnClientDisconnect(int client)
{
	delete g_hTimer[client];
}

void Event_PillsUsed(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	g_fRemaining[client] = g_fMaxHeal;
	delete g_hTimer[client];
	g_hTimer[client] = CreateTimer(g_fInterval, HealHealthBuffer_Timer, userid, TIMER_REPEAT);
}

Action HealHealthBuffer_Timer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (IsValidSur(client) && IsPlayerAlive(client))
	{
		if (g_fIncrement >= g_fRemaining[client])
		{
			Heal(client, g_fRemaining[client]);
			g_hTimer[client] = null;
			return Plugin_Stop;
		}

		Heal(client, g_fIncrement);
		g_fRemaining[client] -= g_fIncrement;
		return Plugin_Continue;
	}

	g_hTimer[client] = null;
	return Plugin_Stop;
}

void Heal(int client, float fValue)
{
	float fHealthBuffer = fValue + GetEntPropFloat(client, Prop_Send, "m_healthBuffer");

	float fOverflow = fHealthBuffer + GetClientHealth(client) - GetEntProp(client, Prop_Send, "m_iMaxHealth");
	if (fOverflow > 0.0)
		fHealthBuffer -= fOverflow;

	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fHealthBuffer);
}

bool IsValidSur(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			return true;
		}
	}
	return false;
}
