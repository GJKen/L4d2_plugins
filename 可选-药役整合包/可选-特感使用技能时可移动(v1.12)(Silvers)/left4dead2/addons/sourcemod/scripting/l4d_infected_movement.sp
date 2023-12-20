/*
*	Special Infected Ability Movement
*	Copyright (C) 2022 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.12"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Special Infected Ability Movement
*	Author	:	SilverShot
*	Descrp	:	Continue normal movement speed while spitting/smoking/tank throwing rock
*	Link	:	https://forums.alliedmods.net/showthread.php?t=307330
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.12 (10-Feb-2023)
	- Fixed affecting Survivors under certain circumstances. Thanks to "Voevoda" for reporting.

1.11 (03-Dec-2022)
	- Added cvars "l4d_infected_movement_delay_smoker", "l4d_infected_movement_delay_spitter" and "l4d_infected_movement_delay_tank" to delay unlocking movement. Requested by "Mika Misori".

1.10 (22-Nov-2022)
	- Fixed the "l4d_infected_movement_bots" and "l4d_infected_movement_type" cvars being flipped. Thanks to "Fraggor" for reporting.

1.9 (02-Feb-2022)
	- Added cvar "l4d_infected_movement_bots" to control which bots this plugin enables for. Requested by "Alexmy".

1.8 (30-Sep-2020)
	- Fixed compile errors on SM 1.11.

1.7 (18-Sep-2020)
	- Fixed Smoker speed not resetting if the Tongue misses. Thanks to "fbef0102" for reporting.

1.6 (05-Sep-2020)
	- Added resetting speed on player death and Smoker tongue release. Thanks to "fbef0102" for reporting.

1.5 (01-Sep-2020)
	- Added cvars "l4d_infected_movement_speed_smoker", "l4d_infected_movement_speed_tank", and
		"l4d_infected_movement_speed_spitter" to control speed while using their ability.

1.4 (10-May-2020)
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.

1.3 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.2 (23-Oct-2019)
	- Added cvar "l4d_infected_movement_smoker" to control Smoker movement while someones hanging the tongue.

1.1 (23-Aug-2018)
	- Fixed the Smoker not working correctly. Thanks to "phoenix0001" for reporting.

1.0 (05-May-2018)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarBots, g_hCvarDelaySmoker, g_hCvarDelaySpitter, g_hCvarDelayTank, g_hCvarSmoker, g_hCvarType, g_hSpeedSmoke, g_hSpeedSpit, g_hSpeedTank, g_hSpeedSmokeDef, g_hSpeedSpitDef, g_hSpeedTankDef;
int g_iCvarAllow, g_iCvarBots, g_iCvarSmoker, g_iCvarType, g_iClassTank;
bool g_bCvarAllow, g_bMapStarted, g_bLeft4Dead2;
float g_fCvarDelaySmoker, g_fCvarDelaySpitter, g_fCvarDelayTank, g_fSpeedSmoke, g_fSpeedSmokeDef, g_fSpeedSpit, g_fSpeedSpitDef, g_fSpeedTank, g_fSpeedTankDef;
float g_fTime[MAXPLAYERS+1];

enum
{
	ENUM_SMOKE = 1,
	ENUM_SPITS = 2,
	ENUM_TANKS = 4
}



// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Special Infected Ability Movement",
	author = "SilverShot",
	description = "Continue normal movement speed while spitting/smoking/tank throwing rocks.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=307330"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	RegPluginLibrary("l4d_infected_movement");

	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hCvarAllow =			CreateConVar(	"l4d_infected_movement_allow",			"3",			"0=Plugin off, 1=Allow players only, 2=Allow bots only, 3=Both.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_infected_movement_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_infected_movement_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_infected_movement_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarBots =			CreateConVar(	"l4d_infected_movement_bots",			"7",			"These Special Infected bots can use: 1=Smoker, 2=Spitter, 4=Tank, 7=All. Add numbers together.", CVAR_FLAGS );
	g_hCvarDelaySmoker =	CreateConVar(	"l4d_infected_movement_delay_smoker",	"0.0",			"0.0=Instantly. How many seconds after using their ability can the Smoker move.", CVAR_FLAGS );
	g_hCvarDelaySpitter =	CreateConVar(	"l4d_infected_movement_delay_spitter",	"0.0",			"0.0=Instantly. How many seconds after using their ability can the Spitter move.", CVAR_FLAGS );
	g_hCvarDelayTank =		CreateConVar(	"l4d_infected_movement_delay_tank",		"0.0",			"0.0=Instantly. How many seconds after using their ability can the Tank move.", CVAR_FLAGS );
	g_hCvarSmoker =			CreateConVar(	"l4d_infected_movement_smoker",			"2",			"0=Only on shooting. 1=Smokers can move while pulling someone. 2=Smokers can also move when someone is hanging from the tongue.", CVAR_FLAGS );
	g_hSpeedSmoke =			CreateConVar(	"l4d_infected_movement_speed_smoker",	"250",			"How fast can Smokers move while using their ability.", CVAR_FLAGS );
	g_hSpeedTank =			CreateConVar(	"l4d_infected_movement_speed_tank",		"250",			"How fast can Tanks move while using their ability.", CVAR_FLAGS );
	if( g_bLeft4Dead2 )
		g_hSpeedSpit =		CreateConVar(	"l4d_infected_movement_speed_spitter",	"250",			"How fast can Spitters move while using their ability.", CVAR_FLAGS );
	g_hCvarType =			CreateConVar(	"l4d_infected_movement_type",			"7",			"These Special Infected players can use: 1=Smoker, 2=Spitter, 4=Tank, 7=All. Add numbers together.", CVAR_FLAGS );
	CreateConVar(							"l4d_infected_movement_version",		PLUGIN_VERSION, "Ability Movement plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_infected_movement");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarBots.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDelaySmoker.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDelaySpitter.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDelayTank.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarType.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSmoker.AddChangeHook(ConVarChanged_Cvars);
	g_hSpeedSmoke.AddChangeHook(ConVarChanged_Cvars);
	g_hSpeedTank.AddChangeHook(ConVarChanged_Cvars);
	if( g_bLeft4Dead2 )
		g_hSpeedSpit.AddChangeHook(ConVarChanged_Cvars);

	g_hSpeedTankDef = FindConVar("z_tank_speed");
	g_hSpeedTankDef.AddChangeHook(ConVarChanged_Cvars);
	g_hSpeedSmokeDef = FindConVar("tongue_victim_max_speed");
	g_hSpeedSmokeDef.AddChangeHook(ConVarChanged_Cvars);

	if( g_bLeft4Dead2 )
	{
		g_hSpeedSpitDef = FindConVar("z_spitter_speed");
		g_hSpeedSpitDef.AddChangeHook(ConVarChanged_Cvars);
	}

	g_iClassTank = g_bLeft4Dead2 ? 8 : 5;
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	if( g_bLeft4Dead2 )
	{
		g_fSpeedSpit = g_hSpeedSpit.FloatValue;
		g_fSpeedSpitDef = g_hSpeedSpitDef.FloatValue;
	}
	g_fSpeedSmoke = g_hSpeedSmoke.FloatValue;
	g_fSpeedSmokeDef = g_hSpeedSmokeDef.FloatValue;
	g_fSpeedTank = g_hSpeedTank.FloatValue;
	g_fSpeedTankDef = g_hSpeedTankDef.FloatValue;
	g_iCvarSmoker = g_hCvarSmoker.IntValue;
	g_iCvarType = g_hCvarType.IntValue;
	g_iCvarBots = g_hCvarBots.IntValue;
	g_fCvarDelaySmoker = g_hCvarDelaySmoker.FloatValue;
	g_fCvarDelaySpitter = g_hCvarDelaySpitter.FloatValue;
	g_fCvarDelayTank = g_hCvarDelayTank.FloatValue;
}

void IsAllowed()
{
	g_iCvarAllow = g_hCvarAllow.IntValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && g_iCvarAllow && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("round_end",			Event_Reset);
		HookEvent("round_start",		Event_Reset);
		HookEvent("ability_use",		Event_Use);
		HookEvent("player_team",		Event_Death);
		HookEvent("player_death",		Event_Death);
		HookEvent("tongue_release",		Event_Death);
	}
	else if( g_bCvarAllow == true && (g_iCvarAllow == 0 || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvent("round_end",		Event_Reset);
		UnhookEvent("round_start",		Event_Reset);
		UnhookEvent("ability_use",		Event_Use);
		UnhookEvent("player_team",		Event_Death);
		UnhookEvent("player_death",		Event_Death);
		UnhookEvent("tongue_release",	Event_Death);
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		if( g_bMapStarted == false )
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if( IsValidEntity(entity) )
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
void Event_Reset(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

void ResetPlugin()
{
	for( int i = 0; i < sizeof(g_fTime); i++ )
	{
		g_fTime[i] = 0.0;
	}
}

void Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( !client || !IsClientInGame(client) ) return;

	SDKUnhook(client, SDKHook_PostThinkPost, OnThinkFunk);
	SDKUnhook(client, SDKHook_PreThink, OnThinkFunk);
	SDKUnhook(client, SDKHook_PreThinkPost, OnThinkFunk);

	if( GetClientTeam(client) == 3 )
	{
		int class = GetEntProp(client, Prop_Send, "m_zombieClass");
		if( class == 1 || class == 4 || class == g_iClassTank )
		{
			SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", class == 1 ? g_fSpeedSmokeDef : class == 4 ? g_fSpeedSpitDef : g_fSpeedTankDef);
		}
	}
}

void Event_Use(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( !client || !IsClientInGame(client) ) return;


	// Class check
	// Smoker = 1; Spitter = 4; Tank = 8
	int class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if( !g_bLeft4Dead2 && class == 5 ) class = 8;
	switch( class )
	{
		case 1: class = 0;
		case 4: class = 1;
		case 8: class = 2;
		default: class = 99;
	}

	if( IsFakeClient(client) )
	{
		if( !(g_iCvarBots & (1 << class)) ) return;
	}
	else
	{
		if( !(g_iCvarType & (1 << class)) ) return;
	}


	// Bots check
	if( g_iCvarAllow != 3 )
	{
		bool fake = IsFakeClient(client);
		if( g_iCvarAllow == 1 && fake ) return;
		if( g_iCvarAllow == 2 && !fake ) return;
	}


	// Event check
	int type;
	char sUse[16];
	event.GetString("ability", sUse, sizeof(sUse));
	if( (g_bLeft4Dead2 && strcmp(sUse, "ability_spit") == 0) )		type = ENUM_SPITS;
	else if( strcmp(sUse, "ability_throw") == 0 )					type = ENUM_TANKS;
	else if( strcmp(sUse, "ability_tongue") == 0 )					type = ENUM_SMOKE;

	if( type )
	{
		if( g_fTime[client] - GetGameTime() < 0.0 )
		{
			g_fTime[client] = GetGameTime() + 3.0;

			float delay;

			switch( type )
			{
				case ENUM_SMOKE: delay = g_fCvarDelaySmoker;
				case ENUM_SPITS: delay = g_fCvarDelaySpitter;
				case ENUM_TANKS: delay = g_fCvarDelayTank;
			}

			if( delay )
			{
				CreateTimer(delay, TimerDelay, GetClientUserId(client));
			}
			else
			{
				// Hooked 3 times, because each alone is not enough, this creates the smoothest play with minimal movement stutter
				SDKHook(client, SDKHook_PostThinkPost, OnThinkFunk);
				SDKHook(client, SDKHook_PreThink, OnThinkFunk);
				SDKHook(client, SDKHook_PreThinkPost, OnThinkFunk);
			}
		}
	}
}

Action TimerDelay(Handle timer, int client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) )
	{
		g_fTime[client] = GetGameTime() + 3.0;
		SDKHook(client, SDKHook_PostThinkPost, OnThinkFunk);
		SDKHook(client, SDKHook_PreThink, OnThinkFunk);
		SDKHook(client, SDKHook_PreThinkPost, OnThinkFunk);
	}

	return Plugin_Continue;
}

void OnThinkFunk(int client) //Dance
{
	if( IsClientInGame(client) )
	{
		int class = GetEntProp(client, Prop_Send, "m_zombieClass");

		if( g_fTime[client] - GetGameTime() > 0.0 )
		{
			if( class == 1 || class == 4 || class == g_iClassTank )
			{
				SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", class == 1 ? g_fSpeedSmoke : class == 4 ? g_fSpeedSpit : g_fSpeedTank);
			}

			// Allow continuous smoker movement while pulling someone.
			if( class == 1 )
			{
				// Allow continuous smoker movement when victim hanging from tongue
				// Only on shooting
				if( g_iCvarSmoker == 0 )
				{
					if( g_fTime[client] - GetGameTime() > 1.2 ) g_fTime[client] = GetGameTime() + 1.2;
				}
				else
				{
					// Always or Not hanging (31) and not missed hit (2|5), else restore
					int anim = GetEntProp(client, Prop_Send, "m_nSequence");

					if( (g_iCvarSmoker == 2 || anim != 31) && (anim != 2 && anim != 5) )
					{
						g_fTime[client] = GetGameTime() + 0.5;
					}
					else
					{
						g_fTime[client] = 0.0;
						SDKUnhook(client, SDKHook_PostThinkPost, OnThinkFunk);
						SDKUnhook(client, SDKHook_PreThink, OnThinkFunk);
						SDKUnhook(client, SDKHook_PreThinkPost, OnThinkFunk);

						SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", g_fSpeedSmokeDef);
					}
				}
			}

			SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
		} else {
			g_fTime[client] = 0.0;
			SDKUnhook(client, SDKHook_PostThinkPost, OnThinkFunk);
			SDKUnhook(client, SDKHook_PreThink, OnThinkFunk);
			SDKUnhook(client, SDKHook_PreThinkPost, OnThinkFunk);

			if( class == 1 || class == 4 || class == g_iClassTank )
			{
				SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", class == 1 ? g_fSpeedSmokeDef : class == 4 ? g_fSpeedSpitDef : g_fSpeedTankDef);
			}
		}
	}
}