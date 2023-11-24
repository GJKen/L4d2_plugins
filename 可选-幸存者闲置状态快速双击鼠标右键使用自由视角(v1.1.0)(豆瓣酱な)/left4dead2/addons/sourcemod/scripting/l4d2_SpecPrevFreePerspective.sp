#pragma semicolon 1
#include <sourcemod>
#pragma newdecls required

#define PLUGIN_VERSION	"1.1.0"

int FreePrev[MAXPLAYERS+1];
float DoubleTime[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name 			= "l4d2_SpecPrevFreePerspective",
	author 			= "豆瓣酱な",
	description 	= "管理员!玩家闲置时快速双击鼠标右键打开自由视角,再次双击鼠标右键恢复(或单击空格键)",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public void OnPluginStart()
{
	//玩家闲置时快速双击鼠标右键打开自由视角,再次双击鼠标右键恢复(或单击空格键).
	AddCommandListener(CommandListener_SpecPrev, "spec_prev");
}

//玩家闲置时快速双击鼠标右键打开自由视角,再次单击鼠标右键恢复.
public Action CommandListener_SpecPrev(int client, char[] command, int argc)
{
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 1 || !iGetBotOfIdle(client))
		return Plugin_Continue;

	float iTime = GetEngineTime();
	if(iTime - DoubleTime[client] < 0.3)
	{
		if (miObserverMode(client, 6))
		{
			//加入自由视角之前把当前值存入变量.
			FreePrev[client] = GetEntProp(client, Prop_Send, "m_iObserverMode");
			PrintCenterText(client, "当前为自由视角.");
			SetEntProp(client, Prop_Send, "m_iObserverMode", 6);
		}
		else
		{
			switch (FreePrev[client])
			{
				case 4:
				{
					PrintCenterText(client, "当前为第一人称视角.");
					SetEntProp(client, Prop_Send, "m_iObserverMode", FreePrev[client]);
				}
				case 5:
				{
					PrintCenterText(client, "当前为第三人称视角.");
					SetEntProp(client, Prop_Send, "m_iObserverMode", FreePrev[client]);
				}
				default:
				{
					PrintCenterText(client, "当前为第三人称视角.");
					SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
				}
			}
		}
	}
	DoubleTime[client] = iTime;
	return Plugin_Continue;
}

//判断玩家视角值.
int miObserverMode(int client, int iFreePrev)
{
	return GetEntProp(client, Prop_Send, "m_iObserverMode") != iFreePrev;
}

stock int iGetBotOfIdle(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && (iHasIdlePlayer(i) == client))
			return i;
	}
	return 0;
}

stock int iHasIdlePlayer(int client)
{
	char sNetClass[64];
	if(!GetEntityNetClass(client, sNetClass, sizeof(sNetClass)))
		return 0;

	if(FindSendPropInfo(sNetClass, "m_humanSpectatorUserID") < 1)
		return 0;

	client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));			
	if(client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 1)
		return client;

	return 0;
}