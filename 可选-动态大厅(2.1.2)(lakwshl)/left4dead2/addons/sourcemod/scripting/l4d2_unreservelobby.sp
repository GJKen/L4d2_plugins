#include <sourcemod>

#define PLUGIN_NAME				"[L4D2] Remove Lobby Reservation"
#define PLUGIN_AUTHOR			"Downtown1, Anime4000, sorallll, lakwsh"
#define PLUGIN_DESCRIPTION		"Removes lobby reservation when server is full"
#define PLUGIN_VERSION			"2.1.2"
#define PLUGIN_URL				"http://forums.alliedmods.net/showthread.php?t=87759"

ConVar g_cvUnreserve, g_cvGameMode, g_cvCookie, g_cvLobbyOnly, g_cvMaxPlayers;
bool g_bUnreserve;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	CreateConVar("l4d_unreserve_version", PLUGIN_VERSION, "Version of the Lobby Unreserve plugin.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cvUnreserve = CreateConVar("l4d_unreserve_full", "1", "Automatically unreserve server after a full lobby joins", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_cvUnreserve.AddChangeHook(CvarChanged);
	g_cvGameMode = FindConVar("mp_gamemode");
	g_cvCookie = FindConVar("sv_lobby_cookie");
	g_cvLobbyOnly = FindConVar("sv_allow_lobby_connect_only");
	g_cvMaxPlayers = FindConVar("sv_maxplayers");

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

	RegAdminCmd("sm_unreserve", cmdUnreserve, ADMFLAG_BAN, "sm_unreserve - manually force removes the lobby reservation");
}

Action cmdUnreserve(int client, int args) {
	ServerCommand("sv_cookie 0");
	ReplyToCommand(client, "[UL] Lobby reservation has been removed.");
	return Plugin_Handled;
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_bUnreserve = g_cvUnreserve.BoolValue;
}

public void OnClientPutInServer(int client) {
	if (!g_bUnreserve || g_cvMaxPlayers.IntValue == -1)
		return;

	if (IsFakeClient(client))
		return;

	if (!IsServerLobbyFull(-1))
		return;

	ServerCommand("sv_cookie 0");
}

//OnClientDisconnect will fired when changing map, issued by gH0sTy at http://docs.sourcemod.net/api/index.php?fastload=show&id=390&
void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	if (g_cvMaxPlayers.IntValue == -1)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	if (IsFakeClient(client))
		return;

	if (!GetConnectedPlayer(client))
	{
		g_cvCookie.SetString("0");
		g_cvLobbyOnly.SetInt(1);
		return;
	}

	if (IsServerLobbyFull(client))
		return;

	char sCookie[20];
	g_cvCookie.GetString(sCookie, sizeof(sCookie));
	if (StrEqual(sCookie, "0"))
		return;

	ServerCommand("sv_cookie %s", sCookie);
}

bool IsServerLobbyFull(int client)
{
	int humans = GetConnectedPlayer(client);

	char sGameMode[32];
	g_cvGameMode.GetString(sGameMode, sizeof(sGameMode));
	if (StrEqual(sGameMode, "versus") || StrEqual(sGameMode, "scavenge"))
	{
		return humans >= 8;
	}
	return humans >= 4;
}

int GetConnectedPlayer(int client) {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientConnected(i) && !IsFakeClient(i))
			count++;
	}
	return count;
}