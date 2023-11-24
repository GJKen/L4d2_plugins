#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
//#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_NAME				"Skip Tank Taunt"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.7"
#define PLUGIN_URL				"https://forums.alliedmods.net/showthread.php?t=336707"

ConVar
	g_cvAnimationPlaybackRate;

float
	g_fAnimationPlaybackRate;

bool
	g_bL4D2,
	g_bLateLoad,
	g_bTankClimb[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	switch (GetEngineVersion()) {
		case Engine_Left4Dead:
			g_bL4D2 = false;

		case Engine_Left4Dead2:
			g_bL4D2 = true;

		default: {
			strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
			return APLRes_SilentFailure;
		}
	}

	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	CreateConVar("skip_tank_taunt_version", PLUGIN_VERSION, "Skip Tank Taunt plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cvAnimationPlaybackRate = CreateConVar("tank_animation_playbackrate", "5.0", "Obstacle animation playback rate", _, true, 0.0);
	g_cvAnimationPlaybackRate.AddChangeHook(CvarChanged);
	AutoExecConfig(true);

	HookEvent("round_end",		Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn",		Event_TankSpawn);
	HookEvent("player_death",	Event_PlayerDeath);
	HookEvent("player_team",	Event_PlayerTeam);

	if (g_bLateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i))
				continue;

			if (GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8) {
				AnimHookEnable(i, OnTankAnimPre);
				if (IsFakeClient(i))
					SDKHook(i, SDKHook_PreThink, OnPreThink);
			}
		}
	}
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_fAnimationPlaybackRate = g_cvAnimationPlaybackRate.FloatValue;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			g_bTankClimb[i] = false;
			AnimHookDisable(i, OnTankAnimPre);
			SDKUnhook(i, SDKHook_PreThink, OnPreThink);
		}
	}
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client)) {
		g_bTankClimb[client] = false;
		AnimHookDisable(client, OnTankAnimPre);
		AnimHookEnable(client, OnTankAnimPre);
		if (IsFakeClient(client)) {
			SDKUnhook(client, SDKHook_PreThink, OnPreThink);
			SDKHook(client, SDKHook_PreThink, OnPreThink);
		}
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client) {
		g_bTankClimb[client] = false;
		AnimHookDisable(client, OnTankAnimPre);
		SDKUnhook(client, SDKHook_PreThink, OnPreThink);
	}
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	if (event.GetInt("oldteam") != 3)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client) {
		g_bTankClimb[client] = false;
		AnimHookDisable(client, OnTankAnimPre);
		SDKUnhook(client, SDKHook_PreThink, OnPreThink);
	}
}

void OnPreThink(int client) {
	switch (GetEntProp(client, Prop_Send, "m_zombieClass") == 8) {
		case true: {
			if (g_bTankClimb[client] && GetEntityMoveType(client) == MOVETYPE_CUSTOM) {
				SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", g_fAnimationPlaybackRate);
			}
			/*switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 16, 17, 18, 19, 20, 21, 22, 23:
					SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", g_fAnimationPlaybackRate);
			}*/
		}

		case false:
			SDKUnhook(client, SDKHook_PreThink, OnPreThink);
	}
}

Action OnTankAnimPre(int client, int &anim) {
	if (g_bL4D2) {
		if (L4D2_ACT_TERROR_HULK_VICTORY <= anim <= L4D2_ACT_TERROR_RAGE_AT_KNOCKDOWN) {
			if (GetEntProp(client, Prop_Send, "m_zombieClass") == 8) {
				anim = 0;
				SetEntPropFloat(client, Prop_Send, "m_flCycle", 1000.0);
				return Plugin_Changed;
			}
		}
		else
			g_bTankClimb[client] = L4D2_ACT_TERROR_CLIMB_24_FROM_STAND <= anim <= L4D2_ACT_TERROR_CLIMB_168_FROM_STAND;
	}
	else {
		if (L4D1_ACT_TERROR_HULK_VICTORY <= anim <= L4D1_ACT_TERROR_RAGE_AT_KNOCKDOWN) {
			if (GetEntProp(client, Prop_Send, "m_zombieClass") == 5) {
				anim = 0;
				SetEntPropFloat(client, Prop_Send, "m_flCycle", 1000.0);
				return Plugin_Changed;
			}
		}
		else
			g_bTankClimb[client] = L4D1_ACT_TERROR_CLIMB_24_FROM_STAND <= anim <= L4D1_ACT_TERROR_CLIMB_168_FROM_STAND;
	}

	return Plugin_Continue;
}
