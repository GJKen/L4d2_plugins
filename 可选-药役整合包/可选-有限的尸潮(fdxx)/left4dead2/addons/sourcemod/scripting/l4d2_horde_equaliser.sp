#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.2"

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>
#include <multicolors>  

#define MIN_TIME 0.0
#define MAX_TIME 10.0
#define HORDE_END_SOUND "level/bell_normal.wav"

ConVar
	g_cvNotifyNum,
	g_cvPauseWhenTankAlive;

int g_iNotifyNum,
	g_iCommInfCount, 
	g_iHordeLimit;

bool 
	g_bPauseWhenTankAlive,
	g_bNotifyStart,
	g_bNotifyRemain,
	g_bNotifyEnd;

public Plugin myinfo = 
{
	name = "L4D2 Horde Equaliser",
	author = "Visor, sir, A1m, fdxx",
	description = "Make certain event hordes finite",
	version = VERSION,
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	CreateConVar("l4d2_horde_equaliser_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvNotifyNum = CreateConVar("l4d2_horde_equaliser_notify_num", "30", "剩余多少尸潮时公告");
	g_cvPauseWhenTankAlive  = CreateConVar("l4d2_horde_equaliser_pause_when_tank_alive", "1", "Tank活着时暂停事件尸潮", FCVAR_NONE, true, 0.0, true, 1.0);

	OnConVarChange(null, "", "");

	g_cvNotifyNum.AddChangeHook(OnConVarChange);
	g_cvPauseWhenTankAlive.AddChangeHook(OnConVarChange);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iNotifyNum = g_cvNotifyNum.IntValue;
	g_bPauseWhenTankAlive = g_cvPauseWhenTankAlive.BoolValue;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
	CreateTimer(1.0, GetHordeLimit_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action GetHordeLimit_Timer(Handle timer)
{
	char sBuffer[256];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "data/mapinfo.txt");

	KeyValues kv = new KeyValues("");
	if (!kv.ImportFromFile(sBuffer))
		SetFailState("Failed to load %s", sBuffer);

	GetCurrentMap(sBuffer, sizeof(sBuffer));
	if (kv.JumpToKey(sBuffer))
		g_iHordeLimit = kv.GetNum("horde_limit", 0);
	else
		g_iHordeLimit = 0;

	delete kv;
	return Plugin_Continue;
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
	g_iHordeLimit = 0;
	g_iCommInfCount = 0;
	g_bNotifyRemain = false;
	g_bNotifyStart = false;
	g_bNotifyEnd = false;
}

public void OnMapStart()
{
	PrecacheSound(HORDE_END_SOUND, true);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (g_iHordeLimit <= 0 || classname[0] != 'i' || strcmp(classname, "infected", false))
		return;

	if (IsEventHordeActive())
	{
		if (g_bPauseWhenTankAlive && IsTankAlive())
			return;

		if (g_iCommInfCount >= g_iHordeLimit)
			return;

		g_iCommInfCount++;

		if (!g_bNotifyRemain && (g_iHordeLimit - g_iCommInfCount <= g_iNotifyNum))
		{
			g_bNotifyRemain = true;
			CPrintToChatAll("{blue}[Horde] {yellow}%i {olive}common infected {default}remaining...", g_iNotifyNum);
		}
	}
}

public Action L4D_OnSpawnMob(int &amount)
{
	if (g_iHordeLimit <= 0 || !IsEventHordeActive())
		return Plugin_Continue;

	if (g_bPauseWhenTankAlive && IsTankAlive())
	{
		L4D2Direct_SetPendingMobCount(0);
		return Plugin_Handled;
	}

	if (!g_bNotifyStart)
	{
		g_bNotifyStart = true;
		CPrintToChatAll("{blue}[Horde] {default}A {olive}horde event {default}has started!");
		CPrintToChatAll("{blue}[Horde] {yellow}%i {olive}common infected {default}remaining...", g_iHordeLimit);
	}

	if (g_iCommInfCount >= g_iHordeLimit)
	{
		if (!g_bNotifyEnd)
		{
			g_bNotifyEnd = true;
			EmitSoundToAll(HORDE_END_SOUND);
		}

		L4D2Direct_SetPendingMobCount(0);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

bool IsEventHordeActive()
{
	float min = L4D2_GetScriptValueFloat("MobSpawnMinTime", MIN_TIME-1);
	float max = L4D2_GetScriptValueFloat("MobSpawnMaxTime", MAX_TIME+1);
	
	return min >= MIN_TIME && max <= MAX_TIME;
}

bool IsTankAlive()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && GetEntProp(i, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(i))
		{
			return true;
		}
	}
	return false;
}
