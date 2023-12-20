#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME "[L4D1/2] Survivor Identity Fix for 5+ Survivors"
#define PLUGIN_AUTHOR "Merudo, Shadowysn"
#define PLUGIN_DESC "Fix bug where a survivor will change identity when a player connects/disconnects if there are 5+ survivors"
#define PLUGIN_VERSION "1.7"
#define PLUGIN_URL "https://forums.alliedmods.net/showthread.php?p=2403731#post2403731"
#define PLUGIN_NAME_SHORT "5+ Survivor Identity Fix"
#define PLUGIN_NAME_TECH "survivor_identity_fix"

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define TEAM_SURVIVOR 2
#define TEAM_PASSING 4

char g_Models[MAXPLAYERS+1][128];

#define GAMEDATA "l4d_survivor_identity_fix"

Handle hConf = null;
#define NAME_SetModel "CBasePlayer::SetModel"
static Handle hDHookSetModel = null;

#define SIG_SetModel_LINUX "@_ZN11CBasePlayer8SetModelEPKc"
#define SIG_SetModel_WINDOWS "\\x55\\x8B\\x2A\\x8B\\x2A\\x2A\\x56\\x57\\x50\\x8B\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\x8B\\x2A\\x2A\\x2A\\x2A\\x2A\\x8B\\x2A\\x8B\\x2A\\x2A\\x8B"

#define SIG_L4D1SetModel_WINDOWS "\\x8B\\x2A\\x2A\\x2A\\x56\\x57\\x50\\x8B\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\x8B\\x3D"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESC,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

public void OnPluginStart()
{
	GetGamedata();
	
	CreateConVar("l4d_survivor_identity_fix_version", PLUGIN_VERSION, "Survivor Change Fix Version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	HookEvent("player_bot_replace", Event_PlayerToBot, EventHookMode_Post);
	HookEvent("bot_player_replace", Event_BotToPlayer, EventHookMode_Post);
}

// ------------------------------------------------------------------------
//  Stores the client of each survivor each time it is changed
//  Needed because when Event_PlayerToBot fires, it's hunter model instead
// ------------------------------------------------------------------------
public MRESReturn SetModel_Pre(int client, Handle hParams)
{ 
	return MRES_Ignored;
} // We need this pre hook even though it's empty, or else the post hook will crash the game.

public MRESReturn SetModel(int client, Handle hParams)
{
	if (!IsValidClient(client))
		return MRES_Ignored;

	if (!IsSurvivor(client)) 
	{
		g_Models[client][0] = '\0';
		return MRES_Ignored;
	}
	
	char model[128];
	DHookGetParamString(hParams, 1, model, sizeof(model));
	if (StrContains(model, "survivors", false) >= 0)
		strcopy(g_Models[client], 128, model);
	
	return MRES_Ignored;
}

// ------------------------------------------------------------------------
//  Models & survivor names so bots can be renamed
// ------------------------------------------------------------------------
char survivor_names[8][] = { "Nick", "Rochelle", "Coach", "Ellis", "Bill", "Zoey", "Francis", "Louis"};
char survivor_models[8][] =
{
	"models/survivors/survivor_gambler.mdl",
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_coach.mdl",
	"models/survivors/survivor_mechanic.mdl",
	"models/survivors/survivor_namvet.mdl",
	"models/survivors/survivor_teenangst.mdl",
	"models/survivors/survivor_biker.mdl",
	"models/survivors/survivor_manager.mdl"
};

// --------------------------------------
// Bot replaced by player
// --------------------------------------
public void Event_BotToPlayer(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(event, "player"));
	int bot    = GetClientOfUserId(GetEventInt(event, "bot"));

	if (!IsValidClient(player) || !IsSurvivor(player) || IsFakeClient(player)) return;  // ignore fake players (side product of creating bots)

	char model[128];
	GetClientModel(bot, model, sizeof(model));
	SetEntityModel(player, model);
	SetEntProp(player, Prop_Send, "m_survivorCharacter", GetEntProp(bot, Prop_Send, "m_survivorCharacter"));
}

// --------------------------------------
// Player -> Bot
// --------------------------------------
public void Event_PlayerToBot(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(GetEventInt(event, "player"));
	int bot    = GetClientOfUserId(GetEventInt(event, "bot")); 

	if (!IsValidClient(player) || !IsSurvivor(player) || IsFakeClient(player)) return; // ignore fake players (side product of creating bots)
	
	if (g_Models[player][0] != '\0')
	{
		SetEntProp(bot, Prop_Send, "m_survivorCharacter", GetEntProp(player, Prop_Send, "m_survivorCharacter"));
		SetEntityModel(bot, g_Models[player]); // Restore saved model. Player model is hunter at this point
		for (int i = 0; i < 8; i++)
		{
			if (StrEqual(g_Models[player], survivor_models[i])) SetClientInfo(bot, "name", survivor_names[i]);
		}
	}
}

void GetGamedata()
{
	char filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(filePath) )
	{
		hConf = LoadGameConfigFile(GAMEDATA); // For some reason this doesn't return null even for invalid files, so check they exist first.
	}
	else
	{
		PrintToServer("[SM] %s plugin unable to get %i.txt gamedata file. Generating...", PLUGIN_NAME_SHORT, GAMEDATA);
		
		Handle fileHandle = OpenFile(filePath, "a+");
		if (fileHandle == null)
		{ SetFailState("[SM] Couldn't generate gamedata file!"); }
		
		WriteFileLine(fileHandle, "\"Games\"");
		WriteFileLine(fileHandle, "{");
		WriteFileLine(fileHandle, "	\"left4dead\"");
		WriteFileLine(fileHandle, "	{");
		WriteFileLine(fileHandle, "		\"Signatures\"");
		WriteFileLine(fileHandle, "		{");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_SetModel);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_SetModel_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_L4D1SetModel_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_SetModel_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "		}");
		WriteFileLine(fileHandle, "	}");
		WriteFileLine(fileHandle, "	\"left4dead2\"");
		WriteFileLine(fileHandle, "	{");
		WriteFileLine(fileHandle, "		\"Signatures\"");
		WriteFileLine(fileHandle, "		{");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_SetModel);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_SetModel_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_SetModel_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_SetModel_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "		}");
		WriteFileLine(fileHandle, "	}");
		WriteFileLine(fileHandle, "}");
		
		CloseHandle(fileHandle);
		hConf = LoadGameConfigFile(GAMEDATA);
		if (hConf == null)
		{ SetFailState("[SM] Failed to load auto-generated gamedata file!"); }
		
		PrintToServer("[SM] %s successfully generated %s.txt gamedata file!", PLUGIN_NAME_SHORT, GAMEDATA);
	}
	PrepDHooks();
}

void PrepDHooks()
{
	if (hConf == null)
	{
		SetFailState("Error: Gamedata not found");
	}
	
	hDHookSetModel = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
	DHookSetFromConf(hDHookSetModel, hConf, SDKConf_Signature, NAME_SetModel);
	DHookAddParam(hDHookSetModel, HookParamType_CharPtr);
	DHookEnableDetour(hDHookSetModel, false, SetModel_Pre);
	DHookEnableDetour(hDHookSetModel, true, SetModel);
}

bool IsValidClient(int client, bool replaycheck = true)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (replaycheck)
	{
		if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	}
	return true;
}

bool IsSurvivor(int client)
{
	if (GetClientTeam(client) != TEAM_SURVIVOR && GetClientTeam(client) != TEAM_PASSING) return false;
	return true;
}