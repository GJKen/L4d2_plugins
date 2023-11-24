/*
*	Ragdoll Fader
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



#define PLUGIN_VERSION 		"1.2"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Ragdoll Fader
*	Author	:	SilverShot
*	Descrp	:	Fades common infected ragdolls.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=306789
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.2 (12-Dec-2022)
	- Changes to fix compile warnings on SourceMod 1.11.

1.1 (20-Jan-2022)
	- Fixed not working on map change. Thanks to "Cloud talk" for reporting.

1.0 (24-Dec-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

int g_iRagdollFader, g_iPlayerSpawn, g_iRoundStart;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Ragdoll Fader",
	author = "SilverShot",
	description = "Fades common infected ragdolls.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=306789"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d_ragdoll_fader", PLUGIN_VERSION, "Ragdoll Fader plugin version.", FCVAR_DONTRECORD);

	HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
}

public void OnPluginEnd()
{
	ResetPlugin();
}



// ====================================================================================================
//					LOAD RAGDOLL FADER
// ====================================================================================================
void ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	DeleteFader();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

public void OnMapEnd()
{
	ResetPlugin();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(2.0, TimerLoad, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(2.0, TimerLoad, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

Action TimerLoad(Handle timer)
{
	CreateFader();
	return Plugin_Continue;
}

void CreateFader()
{
	if( g_iRagdollFader && EntRefToEntIndex(g_iRagdollFader) != INVALID_ENT_REFERENCE )
		return;

	g_iRagdollFader = CreateEntityByName("func_ragdoll_fader");
	if( g_iRagdollFader != -1 )
	{
		DispatchSpawn(g_iRagdollFader);
		SetEntPropVector(g_iRagdollFader, Prop_Send, "m_vecMaxs", view_as<float>({ 999999.0, 999999.0, 999999.0 }));
		SetEntPropVector(g_iRagdollFader, Prop_Send, "m_vecMins", view_as<float>({ -999999.0, -999999.0, -999999.0 }));
		SetEntProp(g_iRagdollFader, Prop_Send, "m_nSolidType", 2);
		g_iRagdollFader = EntIndexToEntRef(g_iRagdollFader);
	}
}

void DeleteFader()
{
	if( g_iRagdollFader && EntRefToEntIndex(g_iRagdollFader) != INVALID_ENT_REFERENCE )
	{
		AcceptEntityInput(g_iRagdollFader, "Kill");
		g_iRagdollFader = 0;
	}
}