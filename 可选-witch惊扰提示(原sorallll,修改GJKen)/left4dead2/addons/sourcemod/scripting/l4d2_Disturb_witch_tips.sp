#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#include <sdktools>
#include <colors>

ConVar g_cvWitchstartled;
bool g_bWitchstartled;

public Plugin myinfo =
{
	name = "[L4d2] Disturb Witch Tips(Witch惊扰提示)",
	author = "原:sorallll, 修改:GJKen", 
	description = "提取自sorallll的sms插件",
	version = "1.0",
	url = "https://github.com/GJKen/L4d2_plugins"
};

public void OnPluginStart() {
	HookEvent("witch_harasser_set",	Event_WitchHarasserSet);

	g_cvWitchstartled =	CreateConVar("sms_witchstartled_notify", "1", "Witch惊扰提示 1=开,0=关");
	
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

void Event_WitchHarasserSet(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bWitchstartled)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;

	switch (GetClientTeam(client)) {
		case 2: {
			int idleplayer = GetIdlePlayerOfBot(client);
			if (!idleplayer){
				int aRand = GetRandomInt(0, 7);
				switch (aRand){
					case 0: {
						CPrintToChatAll("{R}Witch{W}:不要摸我的奶子啊啊啊啊啊啊啊!", client);}
					case 1: {
						CPrintToChatAll("{B}%N {W}被Witch榨精❤", client);}
					case 2: {
						CPrintToChatAll("{R}Witch{W}:想不想看看批?", client);}
					case 3: {
						CPrintToChatAll("{B}%N {W}被Witch盯上了❤", client);}
					case 4: {
						CPrintToChatAll("{R}Witch{W}:我的奶子好玩吗?", client);}
					case 5: {
						CPrintToChatAll("{B}%N {W}已获得成就 {G}摸Wtich奶子", client);}
					case 6: {
						CPrintToChatAll("{R}Witch{W}:臭杂鱼,我想你了{R}❤❤❤", client);}
					case 7: {
						CPrintToChatAll("{R}Witch{W}:想不想看看我的奶子?", client);}
				}
			}
			else{
				CPrintToChatAll("[{O}打酱油{W}]{B}%N {W}对 witch {W}嫖娼", idleplayer);
			}
		}

		case 3: {
			CPrintToChatAll("{red}witch{default}:左拐的红灯最难等了啊啊啊啊啊!", client);
		}
	}
}

int GetIdlePlayerOfBot(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}