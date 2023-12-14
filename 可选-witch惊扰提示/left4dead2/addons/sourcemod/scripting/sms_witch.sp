#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#include <sdktools>
#include <colors>

#define PLUGIN_NAME				"witch Startled(惊扰witch提示)"
#define PLUGIN_AUTHOR			"GJKen"
#define PLUGIN_DESCRIPTION		"惊扰witch提示"
#define PLUGIN_VERSION			"1.0"
#define PLUGIN_URL				"N/A"
ConVar g_cvWitchstartled;
bool g_bWitchstartled;

public void OnPluginStart() {
	HookEvent("witch_harasser_set",	Event_WitchHarasserSet);

	g_cvWitchstartled =	CreateConVar("sms_witchstartled_notify", "1", "Witch惊扰提示");
	
	g_cvWitchstartled.AddChangeHook(CvarChanged);
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_bWitchstartled =	g_cvWitchstartled.BoolValue;
}

// Witch惊扰提示
void Event_WitchHarasserSet(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bWitchstartled)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;

	// switch (GetClientTeam(client)) {
	// 	case 2: {
	// 		int idleplayer = GetIdlePlayerOfBot(client);
	// 		if (!idleplayer)
	// 			CPrintToChatAll("{olive}%N {default}已获得成就 {lightgreen}摸 {red}witch 奶子", client);
	// 		else
	// 			// CPrintToChatAll("{green}◈ {default}[{olive}打酱油{default}]{blue}%N {default}对 {olive}witch {default}嫖娼", idleplayer);
	// 			CPrintToChatAll("{olive}%N[{olive}打酱油] {default}已获得成就 {lightgreen}摸 {red}witch 奶子", idleplayer);
	// 	}

	// 	case 3:
	// 		CPrintToChatAll("{olive}%N {default}已获得成就 {lightgreen}摸 {red}witch 奶子", client);
	switch (GetClientTeam(client)) {
		case 2: {
			int idleplayer = GetIdlePlayerOfBot(client);
			if (!idleplayer)
				// CPrintToChatAll("{olive}%N 已获得成就 摸 witch 奶子", client);
				CPrintToChatAll("witch:\x03左拐的红灯最难等了啊啊啊啊啊!", client);
			else
				// CPrintToChatAll("{green}◈ {default}[{olive}打酱油{default}]{blue}%N {default}对 {olive}witch {default}嫖娼", idleplayer);
				// CPrintToChatAll("{olive}%N[打酱油] 已获得成就 摸 witch 奶子", idleplayer);
				CPrintToChatAll("witch:\x03左拐的红灯最难等了啊啊啊啊啊!", idleplayer);
		}

		case 3:
			// CPrintToChatAll("{olive}%N 已获得成就 摸 witch 奶子", client);
			CPrintToChatAll("witch:\x03左拐的红灯最难等了啊啊啊啊啊!", client);
	}
}

int GetIdlePlayerOfBot(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}