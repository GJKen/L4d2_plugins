/*
*	Coop Markers - Flow Distance
*	Copyright (C) 2021 Silvers
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



#define PLUGIN_VERSION 		"1.11"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Coop Markers - Flow Distance
*	Author	:	SilverShot
*	Descrp	:	Displays messages when Survivors progress through certain distances of the map.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=321288
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.11 (01-Dec-2021)
	- Changes to fix warnings when compiling on SourceMod 1.11.
	- Minor change to fix bad coding practice.

1.10 (29-Jun-2021)
	- Fixed the plugin not always deactivating in finales. Thanks to "KoMiKoZa" for reporting.

1.9 (15-Feb-2021)
	- Fixed flow distance being tracked in some finales. Thanks to "Xanaguy" for reporting.

1.8 (10-May-2020)
	- Added better error log message when gamedata file is missing.
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.

1.7 (05-Apr-2020)
	- Added translations support with 24 languages by default. Thanks to "Stepan Zolotarev" for requesting.
	- Added ding sound when printing to chat in L4D2.
	- Changed ding sound volume to SNDLEVEL_NORMAL from SNDLEVEL_RAIDSIREN and pitch to normal.
	- Fixed "IsAllowedGameMode" from throwing errors when the "_modes" cvar was changed before MapStart.

1.6 (04-Mar-2020)
	- Fixed potential server hanging/crashing on map change with the error:
		"Host_Error: SV_CreatePacketEntities: GetEntServerClass failed for ent 2."
	- This was caused by spawning the "info_gamemode" entity in OnMapStart. Fixed by adding a 0.1 delay.

	- Changed the GetFlowDistance method to prevent crashing on server start. Not sure why this didn't affect others.
	- Fixed late loading not working.
	- Plugin and GameData file updated.

1.5 (02-Mar-2020)
	- Fixed server freezing on map start. Thanks to "Alex101192" for reporting.

1.4 (06-Feb-2020)
	- Panel in L4D1 can block 1,2,3,4,5 keys from changing weapons. But closes when pressed once.
	- Added cvar "l4d_coop_markers_panel" to control displaying a panel or printing to chat.
	- Fixed counting dead players distance toward the total. Thanks to "BHaType" for reporting.

1.3 (05-Feb-2020)
	- Removed support for Listen servers. Get a real server.

1.2 (05-Feb-2020)
	- Disabled displaying in the Finale.
	- L4D1: Changed from printing to chat to displaying in a Panel. Thanks to "Aya Supay".

1.1 (04-Feb-2020)
	- Fixed setting the wrong mode if not "coop".

1.0 (04-Feb-2020)
	- Initial release.

======================================================================================================
	Thanks:

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	"ProdigySim" for "L4D2Direct" offsets and addresses.
	https://forums.alliedmods.net/showthread.php?t=180028

*	"raziEiL" for "L4D_Direct Port" offsets and addresses.
	https://github.com/raziEiL/l4d_direct-port

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d_coop_markers"
#define SOUND_RECORD1		"ui/holdout_teamrec.wav"
#define SOUND_RECORD2		"ui/survival_teamrec.wav"


ConVar g_hCvarAllow, g_hCvarModes, g_hCvarPanel, g_hCvarPercent, g_hCvarTimer, g_hCvarMPGameMode;
Handle g_hPlayerGetLastKnownArea, g_hPlayerGetFlowDistance, g_hTimer;
Address g_PtrGetMapMaxFlowDistance;
bool g_bCvarAllow, g_bMapStarted, g_bLeft4Dead2, g_bIsFinale;
int m_flow, g_iCvarPanel, g_iCvarPercent, g_iDistance;
float g_fCvarTimer, g_fDistance;



// ====================================================================================================
//					PLUGIN
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2/1] Coop Markers - Flow Distance",
	author = "SilverShot",
	description = "Displays messages when Survivors progress through certain distances of the map.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=321288"
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

	if( !IsDedicatedServer() )
	{
		strcopy(error, err_max, "Get a dedicated server. This plugin does not work on Listen servers.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	// ====================================================================================================
	// GAMEDATA
	// ====================================================================================================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);



	// From L4D2Direct
	Address TheNavMesh = GameConfGetAddress(hGameData, "TerrorNavMesh");
	if( TheNavMesh == view_as<Address>(-1) ) SetFailState("Failed to load offset \"TheNavMesh\" address.", GAMEDATA);

	int offs = GameConfGetOffset(hGameData, "TerrorNavMesh::m_fMapMaxFlowDistance");
	if( offs == -1 ) SetFailState("Failed to load \"m_fMapMaxFlowDistance\" offset.", GAMEDATA);
	g_PtrGetMapMaxFlowDistance = TheNavMesh + view_as<Address>(offs);

	m_flow = GameConfGetOffset(hGameData, "m_flow");
	if( m_flow == -1 ) SetFailState("Failed to load \"m_flow\" offset.", GAMEDATA);



	// SDKCalls
	StartPrepSDKCall(SDKCall_Player);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTerrorPlayer::GetLastKnownArea") == false )
		SetFailState("Failed to find signature: CTerrorPlayer::GetLastKnownArea");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hPlayerGetLastKnownArea = EndPrepSDKCall();
	if( g_hPlayerGetLastKnownArea == null )
		SetFailState("Failed to create SDKCall: CTerrorPlayer::GetLastKnownArea");

	StartPrepSDKCall(SDKCall_Player);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "PlayerGetFlowDistance") == false )
		SetFailState("Failed to find signature: PlayerGetFlowDistance");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	g_hPlayerGetFlowDistance = EndPrepSDKCall();
	if( g_hPlayerGetFlowDistance == null )
		SetFailState("Failed to create SDKCall: PlayerGetFlowDistance");

	delete hGameData;



	// ====================================================================================================
	// TRANSLATIONS
	// ====================================================================================================
	char test[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, test, sizeof(test), "translations/coop_markers.phrases.txt");
	if( FileExists(test) == false )
		SetFailState("Missing required file \"coop_markers.phrases.txt\" for translations. Please download and install.");
	LoadTranslations("coop_markers.phrases");



	// ====================================================================================================
	// CVARS
	// ====================================================================================================
	g_hCvarAllow =		CreateConVar(	"l4d_coop_markers_allow",			"1",					"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	if( !g_bLeft4Dead2 )
	g_hCvarModes =		CreateConVar(	"l4d_coop_markers_modes",			"5",					"在这些游戏模式中打开插件. 0=All, 1=Coop, 2=Survival, 4=Versus. 将数字相加.", CVAR_FLAGS );
	g_hCvarPanel =		CreateConVar(	"l4d_coop_markers_panel",			"1",					"0=打印聊天,1=显示面板.", CVAR_FLAGS );
	g_hCvarPercent =	CreateConVar(	"l4d_coop_markers_percent",			"25",					"在显示标记的进度百分比之后.", CVAR_FLAGS );
	g_hCvarTimer =		CreateConVar(	"l4d_coop_markers_timer",			"2.0",					"计时器多久触发一次以检查进度.", CVAR_FLAGS );
	CreateConVar(						"l4d_coop_markers_version",			PLUGIN_VERSION,			"Coop Markers plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d_coop_markers");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	if( !g_bLeft4Dead2 )
		g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarPanel.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarPercent.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTimer.AddChangeHook(ConVarChanged_Cvars);
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iCvarPanel = g_hCvarPanel.IntValue;
	g_iCvarPercent = g_hCvarPercent.IntValue;
	g_fCvarTimer = g_hCvarTimer.FloatValue;

	if( g_iCvarPercent > g_iDistance ) g_iDistance = g_iCvarPercent;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;

		g_bIsFinale = FindEntityByClassname(MaxClients + 1, "trigger_finale") != INVALID_ENT_REFERENCE;

		if( !g_bIsFinale && g_bMapStarted )
		{
			g_fDistance = GetMapMaxFlowDistance();
			g_hTimer = CreateTimer(g_fCvarTimer, TimerUpdate, _, TIMER_REPEAT);
		}

		HookEvent("round_start",	Event_RoundStart,	EventHookMode_PostNoCopy);
		HookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;

		delete g_hTimer;

		UnhookEvent("round_start",	Event_RoundStart,	EventHookMode_PostNoCopy);
		UnhookEvent("round_end",	Event_RoundEnd,		EventHookMode_PostNoCopy);
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_bMapStarted == false )
		return false;

	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_bLeft4Dead2 ? 1 : g_hCvarModes.IntValue;
	if( iCvarModesTog != 0 )
	{
		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if( IsValidEntity(entity) )
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			// HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
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

	return true;
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	// else if( strcmp(output, "OnScavenge") == 0 )
		// g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_fDistance = GetMapMaxFlowDistance();

	delete g_hTimer;

	if( g_bCvarAllow && !g_bIsFinale )
		g_hTimer = CreateTimer(g_fCvarTimer, TimerUpdate, _, TIMER_REPEAT);
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

public void OnMapEnd()
{
	g_bIsFinale = false;
	g_bMapStarted = false;
	ResetPlugin();
}

public void OnMapStart()
{
	CreateTimer(0.1, TimerDelayCheck, _, TIMER_FLAG_NO_MAPCHANGE);

	g_bMapStarted = true;

	if( g_bLeft4Dead2 )		PrecacheSound(SOUND_RECORD2);
	else					PrecacheSound(SOUND_RECORD1);
}

void ResetPlugin()
{
	g_iDistance = g_iCvarPercent;
	delete g_hTimer;
}

public Action TimerDelayCheck(Handle timer)
{
	g_bIsFinale = FindEntityByClassname(-1, "trigger_finale") != INVALID_ENT_REFERENCE;

	IsAllowed();

	delete g_hTimer;

	if( g_bCvarAllow && !g_bIsFinale )
		g_hTimer = CreateTimer(g_fCvarTimer, TimerUpdate, _, TIMER_REPEAT);

	return Plugin_Continue;
}



// ====================================================================================================
//					UPDATE
// ====================================================================================================
public Action TimerUpdate(Handle timer)
{
	if( g_bMapStarted )
	{
		float dist;
		int total;
		int area;

		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
			{
				area = SDKCall(g_hPlayerGetLastKnownArea, i);

				if( area )
				{
					dist += view_as<float>(LoadFromAddress(view_as<Address>(area + m_flow), NumberType_Int32));
					total++;
				}
			}
		}

		if( total )
		{
			dist /= total;
			int range = RoundToCeil(dist / g_fDistance * 100);
			// PrintToServer("range(%d) g_iDistance(%d) dist(%f) g_fDistance(%f)", range, g_iDistance, dist, g_fDistance);

			if( range >= g_iDistance )
			{
				// PrintToServer("range(%d) total(%d) g_iDistance(%d) dist(%f) g_fDistance(%f) send(%d)", range, total, g_iDistance, dist, g_fDistance, g_iCvarPercent * RoundToFloor(float(range) / g_iCvarPercent));
				g_iDistance = g_iCvarPercent * RoundToFloor(float(range) / g_iCvarPercent);
				FireMarker(g_iDistance);
				g_iDistance += g_iCvarPercent;
			}
		}
	}

	return Plugin_Continue;
}



// ====================================================================================================
//					MARKER
// ====================================================================================================
void FireMarker(int value)
{
	if( !g_iCvarPanel )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) )
			{
				PrintToChat(i, "\x04%T", "Coop_Marker", i, value); // L4D_VS_REACHED_MARKER
			}
		}

		PlaySound();
	} else {
		if( !g_bLeft4Dead2 )
		{
			Panel hPanel = new Panel();
			static char sBuffer[96];

			for( int i = 1; i <= MaxClients; i++ )
			{
				if( IsClientInGame(i) )
				{
					Format(sBuffer, sizeof(sBuffer), "%T", "Coop_Marker", i, value);
					hPanel.DrawText(sBuffer);
					hPanel.Send(i, MarkerPanel, 5);
				}
			}

			PlaySound();
			delete hPanel;
		}
		else
		{
			int clients[MAXPLAYERS+1];
			int count;
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( IsClientInGame(i) && !IsFakeClient(i) )
				{
					clients[count++] = i;
				}
			}

			if( count )
			{
				char mode[64];
				g_hCvarMPGameMode.GetString(mode, sizeof(mode));

				// Clients only display the value when they think it's Versus.
				for( int i = 0; i < count; i++ )
				{
					SendConVarValue(clients[i], g_hCvarMPGameMode, "versus");
				}

				// Fire marker
				Event test = CreateEvent("versus_marker_reached", true);
				test.SetInt("userid", GetClientUserId(clients[count - 1]));
				test.SetInt("marker", value);
				test.Fire();

				// Reset
				for( int i = 0; i < count; i++ )
				{
					SendConVarValue(clients[i], g_hCvarMPGameMode, mode);
				}
			}
		}
	}
}

public int MarkerPanel(Handle menu, MenuAction action, int param1, int param2) 
{
	return 0;
}

void PlaySound()
{
	EmitSoundToAll(g_bLeft4Dead2 ? SOUND_RECORD2 : SOUND_RECORD1, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}



// ====================================================================================================
//					L4D2Direct
// ====================================================================================================
stock float GetMapMaxFlowDistance()
{
	return view_as<float>(LoadFromAddress(g_PtrGetMapMaxFlowDistance, NumberType_Int32));
}