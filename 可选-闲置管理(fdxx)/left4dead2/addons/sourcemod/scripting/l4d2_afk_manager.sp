#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VERSION "0.5"

#define TEAM_SPEC	1
#define TEAM_SUR	2
#define TEAM_INF	3

// https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/shareddefs.h#L378
enum
{
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_ROAMING,	// free roaming
	NUM_OBSERVER_MODES,
};

ConVar
	g_cvSpecTime,
	g_cvKickTime,
	g_cvExcludeTank,
	g_cvExcludeAdmin,
	g_cvExcludeDead,
	g_cvPlayersLimit;

float
	g_fSpecTime,
	g_fKickTime,
	g_fLastActionTime[MAXPLAYERS+1];

bool
	g_bExcludeTank,
	g_bExcludeAdmin,
	g_bExcludeDead,
	g_bForceSpec[MAXPLAYERS+1];

int
	g_iPlayersLimit,
	m_iObserverMode_offset,
	m_hObserverTarget_offset,
	m_isIncapacitated_offset;

public Plugin myinfo =
{
	name = "L4D2 AFK Manager",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_afk_manager_version", VERSION, "version", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_cvSpecTime = CreateConVar("l4d2_afk_manager_spec_time", "120.0", "After how many seconds idle players will be forced to change to spectator team. 0.0=Disabled", FCVAR_NONE);
	g_cvKickTime = CreateConVar("l4d2_afk_manager_kick_time", "0.0", "After how many seconds idle spectator players(forced change to spectator) will be kicked from the server. 0.0=Disabled", FCVAR_NONE);
	g_cvExcludeTank = CreateConVar("l4d2_afk_manager_exclude_tank",	"1", "Forced to change to spectate exclude Tank", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvExcludeAdmin = CreateConVar("l4d2_afk_manager_exclude_admin", "1", "Forced to change to spectate exclude Admin", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvExcludeDead = CreateConVar("l4d2_afk_manager_exclude_dead", "1", "Forced to change to spectate exclude dead", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvPlayersLimit = CreateConVar("l4d2_afk_manager_kick_players_limit", "8", "How many players will the server reach before kicking the player out of the server.", FCVAR_NONE, true, 0.0, true, 32.0);

	OnConVarChanged(null, "", "");

	g_cvSpecTime.AddChangeHook(OnConVarChanged);
	g_cvKickTime.AddChangeHook(OnConVarChanged);
	g_cvExcludeTank.AddChangeHook(OnConVarChanged);
	g_cvExcludeAdmin.AddChangeHook(OnConVarChanged);
	g_cvExcludeDead.AddChangeHook(OnConVarChanged);
	g_cvPlayersLimit.AddChangeHook(OnConVarChanged);

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeamChanged);
	HookEvent("player_say",	Event_PlayerSay);

	m_iObserverMode_offset = FindSendPropInfo("CTerrorPlayer", "m_iObserverMode");
	m_hObserverTarget_offset = FindSendPropInfo("CTerrorPlayer", "m_hObserverTarget");
	m_isIncapacitated_offset = FindSendPropInfo("CTerrorPlayer", "m_isIncapacitated");

	//AutoExecConfig(true, "l4d2_afk_manager");
	CreateTimer(1.0, Check_Timer, _, TIMER_REPEAT);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fSpecTime = g_cvSpecTime.FloatValue;
	g_fKickTime = g_cvKickTime.FloatValue;
	g_bExcludeTank = g_cvExcludeTank.BoolValue;
	g_bExcludeAdmin = g_cvExcludeAdmin.BoolValue;
	g_bExcludeDead = g_cvExcludeDead.BoolValue;
	g_iPlayersLimit = g_cvPlayersLimit.IntValue;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (IsFakeClient(client))
		return;
	
	if (buttons)
	{
		g_fLastActionTime[client] = GetEngineTime();
		g_bForceSpec[client] = false;
		return;
	}

	if ((mouse[0] || mouse[1]) && !IsMouseExclude(client))
	{
		g_fLastActionTime[client] = GetEngineTime();
		g_bForceSpec[client] = false;
	}
}

//https://forums.alliedmods.net/showthread.php?p=2569852
bool IsMouseExclude(int client)
{
	if (GetEntData(client, m_iObserverMode_offset, 4) == OBS_MODE_IN_EYE)
	{
		static int target;
		target = GetEntDataEnt2(client, m_hObserverTarget_offset);
		if (target > 0 && target <= MaxClients && IsClientInGame(target) && IsPlayerAlive(target))
			return GetEntData(target, m_isIncapacitated_offset, 1) > 0;
	}
	return false;
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bForceSpec[client] = false;
}

Action Check_Timer(Handle timer)
{
	int team;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		if (g_bExcludeAdmin && CheckCommandAccess(i, "sm_admin", ADMFLAG_ROOT))
			continue;

		team = GetClientTeam(i);
		switch (team)
		{
			case TEAM_INF, TEAM_SUR:
			{
				if (g_fSpecTime <= 0.0)
					continue;

				if (g_bExcludeDead && !IsPlayerAlive(i))
					continue;

				if (g_bExcludeTank && team == TEAM_INF && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
					continue;

				if (GetClientAFKTime(i) >= g_fSpecTime)
				{
					g_bForceSpec[i] = true;
					g_fLastActionTime[i] = GetEngineTime();
					ChangeClientTeam(i, TEAM_SPEC);
				}
			}

			case TEAM_SPEC:
			{
				if (g_fKickTime <= 0.0 || !g_bForceSpec[i])
					continue;

				if (GetClientAFKTime(i) >= g_fKickTime && GetPlayerCount() >= g_iPlayersLimit)
				{
					if (!IsClientInKickQueue(i))
						KickClient(i, "You were kicked for being AFK too long");
				}
			}
		}
	}
	return Plugin_Continue;
}

void Event_PlayerTeamChanged(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	bool bDisconnect = event.GetBool("disconnect");
	int newTeam = event.GetInt("team");

	if (!bDisconnect && !IsFakeClient(client))
	{
		if (newTeam == TEAM_INF || newTeam == TEAM_SUR)
		{
			g_bForceSpec[client] = false;
			g_fLastActionTime[client] = GetEngineTime();
			return;
		}

		if (newTeam == TEAM_SPEC && !g_bForceSpec[client])
			g_fLastActionTime[client] = GetEngineTime();
	}
}

void Event_PlayerSay(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bForceSpec[client] = false;
	g_fLastActionTime[client] = GetEngineTime();
}

public void OnClientSpeakingEnd(int client)
{
	g_bForceSpec[client] = false;
	g_fLastActionTime[client] = GetEngineTime();
}

float GetClientAFKTime(int client)
{
	return (GetEngineTime() - g_fLastActionTime[client]);
}

int GetPlayerCount()
{
	int iCount;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
			iCount++;
	}
	return iCount;
}
