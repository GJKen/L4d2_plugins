#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_NAME				"L4D 1/2 Remove Lobby Reservation"
#define PLUGIN_AUTHOR			"Downtown1, Anime4000, sorallll, HatsuneImagine"
#define PLUGIN_DESCRIPTION		"Removes lobby reservation when server is full"
#define PLUGIN_VERSION			"2.0.8"
#define PLUGIN_URL				"http://forums.alliedmods.net/showthread.php?t=87759"

ConVar cv_unreserveMode, cv_unreserveTrigger;
int unreserveMode, unreserveTrigger;
char reservationID[20];

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	SetConVarInt(FindConVar("sv_reservation_timeout"), 10);
	CreateConVar("l4d_unreserve_version", PLUGIN_VERSION, "Version of the Lobby Unreserve plugin.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	cv_unreserveMode = CreateConVar("l4d_unreserve_mode", "1", "Unreserve Mode.\n0 = Disabled.\n1 = Automatically unreserve when full, and automatically restores the lobby reservation when there is a vacancy.\n2 = Automatically unreserve when full, and no longer automatically restores the lobby reservation.", FCVAR_SPONLY|FCVAR_NOTIFY);
	cv_unreserveTrigger = CreateConVar("l4d_unreserve_trigger", "0", "Unreserve Trigger. When player number reaches the following number, the server unreserves.\n-1 = Get lobby slots num from server RAM.\n0 = Versus and Scavenge are 8, other gamemodes are 4.\n>0 = Any user-defined num greater than zero.");

	cv_unreserveMode.AddChangeHook(CvarChanged);
	cv_unreserveTrigger.AddChangeHook(CvarChanged);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	RegAdminCmd("sm_unreserve", cmdUnreserve, ADMFLAG_BAN, "sm_unreserve - manually force removes the lobby reservation");
	RegAdminCmd("sm_reserve", cmdReserve, ADMFLAG_BAN, "sm_reserve - manually restores the lobby reservation");

	AutoExecConfig(true, "l4d2_unreservelobby");//生成指定文件名的CFG.

	CreateTimer(60.0, Timer_Heartbeat, _, TIMER_REPEAT);
}

public void OnConfigsExecuted() {
	GetCvars();

	if (IsServerLobbyFull(-1)) {
		Unreserve();
	}
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	unreserveMode = GetConVarInt(cv_unreserveMode);
	unreserveTrigger = GetConVarInt(cv_unreserveTrigger);
}

Action cmdUnreserve(int client, int args) {
	Unreserve();
	ReplyToCommand(client, "[UL] Lobby reservation has been removed.");
	return Plugin_Handled;
}

Action cmdReserve(int client, int args) {
	Reserve();
	ReplyToCommand(client, "[UL] Lobby reservation has been restored.");
	return Plugin_Handled;
}

Action Timer_Heartbeat(Handle timer) {
	if (unreserveMode == 0 || unreserveMode == 2)
		return Plugin_Continue;

	if (IsServerLobbyFull(-1)) {
		Reserve();
		CreateTimer(5.0, Timer_Unreserve);
	}

	return Plugin_Continue;
}

Action Timer_Unreserve(Handle timer) {
	Unreserve();
	return Plugin_Continue;
}

public void OnClientConnected(int client) {
	if (unreserveMode == 0)
		return;

	if (IsFakeClient(client))
		return;

	if (!IsServerLobbyFull(-1))
		return;

	Unreserve();
}

//OnClientDisconnect will fired when changing map, issued by gH0sTy at http://docs.sourcemod.net/api/index.php?fastload=show&id=390&
void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	if (unreserveMode == 0 || unreserveMode == 2)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	if (IsFakeClient(client))
		return;

	if (IsServerLobbyFull(client))
		return;

	if (IsServerEmpty(client)) {
		ClearSavedLobbyId();
		return;
	}

	Reserve();
}

bool IsServerEmpty(int client) {
	return GetConnectedPlayer(client) == 0;
}

bool IsServerLobbyFull(int client) {
	int slots;

	if (unreserveTrigger < 0)
		slots = LoadFromAddress(L4D_GetPointer(POINTER_SERVER) + view_as<Address>(L4D_GetServerOS() ? 380 : 384), NumberType_Int32);
	else if (unreserveTrigger == 0)
		slots = L4D_IsVersusMode() || L4D2_IsScavengeMode() ? 8 : 4;
	else
		slots = unreserveTrigger;

	return GetConnectedPlayer(client) >= slots;
}

int GetConnectedPlayer(int client) {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientConnected(i) && !IsFakeClient(i))
			count++;
	}
	return count;
}

void Unreserve() {
	if (L4D_LobbyIsReserved())
		L4D_GetLobbyReservation(reservationID, sizeof reservationID);

	L4D_LobbyUnreserve();
	SetAllowLobby(0);
}

void Reserve() {
	if (!L4D_LobbyIsReserved() && reservationID[0])
		L4D_SetLobbyReservation(reservationID);

	// SetAllowLobby(1);
	ServerCommand("heartbeat");
}

void ClearSavedLobbyId() {
	reservationID = "";
	SetAllowLobby(1);
}

void SetAllowLobby(int value) {
	SetConVarInt(FindConVar("sv_allow_lobby_connect_only"), value);
}
