#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define PLUGIN_VERSION			"1.0.1"

ConVar
	g_cvSbAllBotGame,
	g_cvSvHibernateWhe;

public Plugin myinfo = {
	name = "[L4D2] Server Auto Restart",
	author = "sorallll, 修改GJKen",
	description = "服务器没人自动重启",
	version = PLUGIN_VERSION,
	url = "https://github.com/umlka/l4d2/tree/main/restart"
};

public void OnPluginStart() {
	CreateConVar("restart_version", PLUGIN_VERSION, "Restart Server/Map plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cvSbAllBotGame = FindConVar("sb_all_bot_game");
	g_cvSvHibernateWhe = FindConVar("sv_hibernate_when_empty");

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsFakeClient(client)) {
		char networkid[5];
		event.GetString("networkid", networkid, sizeof networkid);
		if (strcmp(networkid, "BOT") && IsServerEmpty(client)) {
			g_cvSbAllBotGame.IntValue = 1;
			g_cvSvHibernateWhe.IntValue = 0;
			CreateTimer(0.1, tmrRestartServer);
		}
	}
}

bool IsServerEmpty(int exclude = 0) {
	for (int i = 1; i <= MaxClients; i++) {
		if (i != exclude && IsClientConnected(i) && !IsFakeClient(i))
			return false;
	}
	return true;
}

Action tmrRestartServer(Handle timer) {
	if (!IsServerEmpty())
		return Plugin_Stop;

	RestartServer();
	return Plugin_Continue;
}

void RestartServer() {
	UnloadAccelerator();
	LogTo("服务器重启...");
	SetCommandFlags("crash", GetCommandFlags("crash") & ~FCVAR_CHEAT);
	ServerCommand("crash");
}

void UnloadAccelerator() {
	int id = GetAcceleratorId();
	if (id != -1) {
		ServerCommand("sm exts unload %i 0", id);
		ServerExecute();
	}
}

int GetAcceleratorId() {
	char buffer[512];
	ServerCommandEx(buffer, sizeof buffer, "sm exts list");
	int idx = SplitString(buffer, "] Accelerator (", buffer, sizeof buffer);
	if (idx == -1)
		return -1;

	for (int i = strlen(buffer); i >= 0; i--) {
		if (buffer[i] == '[')
			return StringToInt(buffer[i + 1]);
	}

	return -1;
}

void LogTo(const char[] format, any ...) {
	char time[32];
	FormatTime(time, sizeof time, "%x %X");

	char map[64];
	GetCurrentMap(map, sizeof map);

	char buffer[512];
	VFormat(buffer, sizeof buffer, format, 2);
	Format(buffer, sizeof buffer, "[%s] [%s] %s", time, map, buffer);

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "logs/restart.log");
	File file = OpenFile(sPath, "a+");
	file.WriteLine("%s", buffer);
	file.Flush();
	delete file;
}
