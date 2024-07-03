#include <sourcemod>


public Plugin myinfo = {
	name = "[L4D2]  Restart The Chapter",
	author = "GJKen",
	description = "手动重启章节",
	version = "1.0",
	url = "https://github.com/GJKen/l4d2_plugins"
};

public void OnPluginStart() {
	RegAdminCmd("sm_restartmap", RestartMap, ADMFLAG_ROOT, "重启当前地图");
}

//重启地图
public Action RestartMap(int client,int args)
{
	PrintHintTextToAll("地图将在3秒后重启");
	CreateTimer(3.0, Timer_Restartmap);
	return Plugin_Handled;
}
public Action Timer_Restartmap(Handle timer)
{
	char mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));
	ServerCommand("changelevel %s", mapname);
	return Plugin_Handled;
}