#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define VERSION "0.4"

ConVar g_cvMaxWitchLimit, g_cvWitchSpawnTime, g_cvKillWitchDistance;
int g_iMaxWitchLimit;
float g_fWitchSpawnTime, g_fKillWitchDist;
bool g_bLeftSafeArea;
Handle g_hSpawnWitchTimer;

public Plugin myinfo =
{
	name = "L4D2 Multi Witches",
	author = "Shele, Dragokas, fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_multi_witches_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_cvMaxWitchLimit = CreateConVar("l4d2_multi_witches_limit", "40", "Limit the number of alive witches.");
	g_cvWitchSpawnTime = CreateConVar("l4d2_multi_witches_spawn_time", "30.0", "Witch spawn time.");
	g_cvKillWitchDistance = CreateConVar("l4d2_multi_witches_kill_distance", "1800.0", "Witches that exceed this distance will be auto killed.");
	
	OnConVarChanged(null, "", "");

	g_cvMaxWitchLimit.AddChangeHook(OnConVarChanged);
	g_cvWitchSpawnTime.AddChangeHook(OnConVarChanged);
	g_cvKillWitchDistance.AddChangeHook(OnConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
}

void OnConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	g_iMaxWitchLimit = g_cvMaxWitchLimit.IntValue;
	g_fWitchSpawnTime = g_cvWitchSpawnTime.FloatValue;
	g_fKillWitchDist = g_cvKillWitchDistance.FloatValue;

	if (convar == null)
		return;

	delete g_hSpawnWitchTimer;
	if (g_fWitchSpawnTime > 0.0)
		g_hSpawnWitchTimer = CreateTimer(g_fWitchSpawnTime, SpawnWitch_Timer, _, TIMER_REPEAT);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

public void OnMapStart()
{
	if (!IsModelPrecached("models/infected/witch.mdl"))
		PrecacheModel("models/infected/witch.mdl", true);
}

public void OnMapEnd()
{
	Reset();
}

void Reset()
{
	g_bLeftSafeArea = false;
	delete g_hSpawnWitchTimer;
}

void Event_PlayerLeftSafeArea(Event event, const char[] name, bool dontBroadcast)
{
	if (g_fWitchSpawnTime > 0.0)
	{
		g_bLeftSafeArea = true;
		delete g_hSpawnWitchTimer;
		g_hSpawnWitchTimer = CreateTimer(g_fWitchSpawnTime, SpawnWitch_Timer, _, TIMER_REPEAT);
	}
}

Action SpawnWitch_Timer(Handle timer)
{
	if (!g_bLeftSafeArea)
	{
		g_hSpawnWitchTimer = null;
		return Plugin_Stop;
	}

	if (GetWitchCount() >= g_iMaxWitchLimit)
		return Plugin_Continue;

	float fSpawnPos[3], fSpawnAng[3];
	int iRandomSur, witch;

	iRandomSur = GetRandomSur();
	if (iRandomSur > 0 && L4D_GetRandomPZSpawnPosition(iRandomSur, 8, 30, fSpawnPos))
	{
		witch = CreateEntityByName("witch");
		if (witch <= MaxClients)
		{
			LogError("Failed to create witch");
			return Plugin_Continue;
		}

		SetAbsOrigin(witch, fSpawnPos);
		fSpawnAng[1] = GetRandomFloatEx(-179.0, 179.0);
		SetAbsAngles(witch, fSpawnAng);
		DispatchSpawn(witch);
	}

	return Plugin_Continue;
}


// Kill witches out of range, and return total count of witches on the map
int GetWitchCount()
{
	int iCount, i;
	bool bInRange;
	float fWitchPos[3], fSurPos[3];
	int witch = MaxClients+1;

	while ((witch = FindEntityByClassname(witch, "witch")) != -1)
	{
		iCount++;

		if (g_fKillWitchDist <= 0.0)
			continue;

		bInRange = false;
		GetEntPropVector(witch, Prop_Send, "m_vecOrigin", fWitchPos);

		for (i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
			{
				GetClientAbsOrigin(i, fSurPos);
				if (GetVectorDistance(fWitchPos, fSurPos) < g_fKillWitchDist)
				{
					bInRange = true;
					break;
				}
			}
		}

		if (!bInRange)
		{
			RemoveEntity(witch);
			iCount--;
		}
	}

	return iCount;
}

int GetRandomSur()
{
	int client;
	ArrayList array = new ArrayList();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			array.Push(i);
		}
	}

	if (array.Length > 0)
	{
		client = array.Get(GetRandomIntEx(0, array.Length - 1));
	}

	delete array;
	return client;
}

int GetRandomIntEx(int min, int max)
{
	return GetURandomInt() % (max - min + 1) + min;
}

float GetRandomFloatEx(float min, float max)
{
	return GetURandomFloat() * (max - min) + min;
}

