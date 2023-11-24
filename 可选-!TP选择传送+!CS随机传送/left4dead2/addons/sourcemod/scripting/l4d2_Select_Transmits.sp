#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"

float G_SwitchMessageTime;

ConVar C_SwitchMessageTime, C_TransmitsLimit;

int G_TransmitsLimit;

int G_Player[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "l4d2_Select_Transmits",
	author = "X光",
	description = "指定传送菜单",
	version = PLUGIN_VERSION,
	url = "QQ群59046067"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_tp", MenuFunc_MainMenu, "选择传送玩家菜单");
	RegConsoleCmd("sm_cs", cmdTeleportClient, "随机传送玩家指令");

	C_SwitchMessageTime = CreateConVar("switch_message_time",	"10.0",		"设置开局提示卡住传送延迟显示时间/秒(如果为0同时关闭提示和传送功能).", FCVAR_NOTIFY);
	C_TransmitsLimit = CreateConVar("transmits_limit",			"5",		"玩家每回合传送使用次数.", FCVAR_NOTIFY);

	C_SwitchMessageTime.AddChangeHook(CvarChanged);
	C_TransmitsLimit.AddChangeHook(CvarChanged);

	//想要生成cfg把下面一行最前面双斜杠删除
	AutoExecConfig(true, "l4d2_Select_Transmits");
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;

	if (G_SwitchMessageTime > 0)
	{
		CreateTimer(G_SwitchMessageTime, TimerAnnounce, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action TimerAnnounce(Handle timer, any client)
{
	if ((client = GetClientOfUserId(client)))
	{
		if (IsClientInGame(client) && GetClientTeam(client) != 3) {
			PrintToChat(client,"\x04[提示]\x05如果卡住时可在聊天窗口输入\x03!tp(指定)或\x03!cs(随机)\x05传送到其它幸存者身边");
		}
	}
	return Plugin_Continue;
}

//被特感控制判定
bool go_away_from(int client)
{
	if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;
	return false;
}

//挂边判定
bool is_survivor_hanging(int client)
{
	return !!GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

//倒地判定
//bool is_survivor_down(int client)
//{
	//return !is_survivor_hanging(client) && GetEntProp(client, Prop_Send, "m_isIncapacitated");
//}

bool is_survivor_inthesky(int client)
{
	return !(GetEntityFlags(client) & FL_ONGROUND);
}

//传送时强制蹲下防止卡住
void ForceCrouch(int client)
{
	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
}

void get_cvars()
{
	G_SwitchMessageTime = C_SwitchMessageTime.FloatValue;
	G_TransmitsLimit = C_TransmitsLimit.IntValue;
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	get_cvars();
}

public void OnConfigsExecuted()
{
	get_cvars();
}

public void OnClientDisconnect_Post(int client)
{
	G_Player[client] = 0;
}

//传送主菜单
public Action MenuFunc_MainMenu(int client, int args)
{
	if (G_SwitchMessageTime <= 0)
	{
		PrintToChat(client, "\x04[提示]\x05传送功能已经关闭");
		return Plugin_Handled;
	}

	if(G_Player[client] >= G_TransmitsLimit)
	{
		PrintToChat(client, "\x04[提示]\x05你的传送次数已用完");
		return Plugin_Handled;
	}

	if(go_away_from(client))
	{
		PrintToChat(client, "\x04[提示]\x05被特感控制时禁止使用传送功能");
		return Plugin_Handled;
	}

	if(is_survivor_hanging(client))
	{
		PrintToChat(client, "\x04[提示]\x05挂边时禁止使用传送功能");
		return Plugin_Handled;
	}

	//if(is_survivor_down(client))
	//{
		//PrintToChat(client, "\x04[提示]\x05倒地时禁止使用传送功能.");
		//return Plugin_Handled;
	//}

	if(GetClientTeam(client) == 1)
	{
		PrintToChat(client, "\x04[提示]\x05闲置或旁观时禁止使用传送功能");
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "\x04[提示]\x05死亡状态时禁止使用传送功能");
		return Plugin_Handled;
	}

	Handle menu = CreateMenu(MenuHandler_EnablePlayer);
	SetMenuTitle(menu, "传送到谁旁边:");
	SetMenuExitBackButton(menu, true);
	char name[32];
	char info[32];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && i != client)
		{
			Format(name, sizeof(name), "%N", i);
			Format(info, sizeof(info), "%i", i);
			AddMenuItem(menu, info, name);
		}
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MenuHandler_EnablePlayer(Handle menu, MenuAction action, int client, int param)
{
	char name[32];
	char info[32];
	GetMenuItem(menu, param, info, sizeof(info), _, name, sizeof(name));
	int target = StringToInt(info);

	if (action == MenuAction_End)	
		CloseHandle(menu);

	if(action == MenuAction_Select)
	{
		if(!IsClientInGame(target))
		{
			PrintToChat(client, "\x04[提示]\x05传送目标已失效,传送失败");
			return 0;
		}
		if(GetClientTeam(target) == 3)
		{
			PrintToChat(client, "\x04[提示]\x05传送目标已变更感染者,传送失败");
			return 0;
		}
		if(is_survivor_hanging(target))
		{
			PrintToChat(client, "\x04[提示]\x05传送目标处于挂边状态,传送失败");
			return 0;
		}
		if(!IsPlayerAlive(target))
		{
			PrintToChat(client, "\x04[提示]\x05传送目标已死亡,传送失败");
			return 0;
		}
		if (GetClientTeam(client) == 2)
		{
			G_Player[client]++;
			float Origin[3];
			//传送时强制蹲下防止卡住
			ForceCrouch(client);
			GetClientAbsOrigin(target, Origin);
			TeleportEntity(client, Origin, NULL_VECTOR, NULL_VECTOR);
			PrintToChat(client, "\x04[提示]\x05你已传送到\x03%N\x05身边,传送次数还剩\x03%d\x05次", target, G_TransmitsLimit - G_Player[client]);
			PrintToChat(target, "\x04[提示]\x03%N传送到你身边", client);
		}
		else
			PrintToChat(client, "\x04[提示]\x05传送功能只限于幸存者使用");
	}
	return 0;
}

Action cmdTeleportClient(int client, int args) {
	int team2 = _GetTeam2Count(2);

	if (G_SwitchMessageTime <= 0) {
		PrintToChat(client, "\x04[提示]\x05传送功能已经关闭");
		return Plugin_Handled;
	}

	if (G_Player[client] >= G_TransmitsLimit) {
		PrintToChat(client, "\x04[提示]\x05你的传送次数已用完.");
		return Plugin_Handled;
	}

	if (team2 < 2) {
		PrintToChat(client, "\x04[提示]\x05没有多余的幸存者作为传送目标.");
		return Plugin_Handled;
	}

	if (go_away_from(client)) {
		PrintToChat(client, "\x04[提示]\x05被特感控制时禁止使用传送功能.");
		return Plugin_Handled;
	}

	if (is_survivor_hanging(client)) {
		PrintToChat(client, "\x04[提示]\x05挂边时禁止使用传送功能.");
		return Plugin_Handled;
	}

	//if (is_survivor_down(client)) {
		//PrintToChat(client, "\x04[提示]\x05倒地时禁止使用传送功能.");
		//return Plugin_Handled;
	//}

	if (GetClientTeam(client) == 1) {
		PrintToChat(client, "\x04[提示]\x05闲置或旁观时禁止使用传送功能.");
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(client)) {
		PrintToChat(client, "\x04[提示]\x05死亡状态时禁止使用传送功能.");
		return Plugin_Handled;
	}

	//if (is_survivor_inthesky(client)) {
		//PrintToChat(client, "\x04[提示]\x05空中使用传送功能时延迟\x035\x05秒传送.");
		//CreateTimer(5.0, DelayTeleport, client);
		//return Plugin_Handled;
	//}

	CreateTimer(0.0, DelayTeleport, client);
	return Plugin_Handled;
}

public Action DelayTeleport(Handle timer, any client) {
	if (!IsClientInGame(client))
		return Plugin_Stop;

	int iTarget = TeleportPlayer(client);

	if (iTarget != -1 && GetClientTeam(client) == 2) {
		G_Player[client]++;
		float vPos[3];
		GetClientAbsOrigin(iTarget, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
		PrintToChat(client, "\x04[提示]\x05你的传送还剩\x03%d\x05次", G_TransmitsLimit - G_Player[client]);
	}
	else
		PrintToChat(client, "\x04[提示]\x05传送功能只限于幸存者使用");

	return Plugin_Handled;
}

int TeleportPlayer(int client) {
	int target = 1;
	ArrayList aClients = new ArrayList(2);

	for (; target <= MaxClients; target++) {
		if (target == client || !IsClientInGame(target) || GetClientTeam(target) != 2 || !IsPlayerAlive(target) || is_survivor_inthesky(target))
			continue;
	
		aClients.Set(aClients.Push(!GetEntProp(target, Prop_Send, "m_isIncapacitated") ? 0 : !GetEntProp(target, Prop_Send, "m_isHangingFromLedge") ? 1 : 2), target, 1);
	}

	if (!aClients.Length)
		target = 0;
	else {
		aClients.Sort(Sort_Descending, Sort_Integer);

		target = aClients.Length - 1;
		target = aClients.Get(Math_GetRandomInt(aClients.FindValue(aClients.Get(target, 0)), target), 1);
	}

	delete aClients;

	if (target) {
		SetEntProp(client, Prop_Send, "m_bDucked", 1);
		SetEntityFlags(client, GetEntityFlags(client)|FL_DUCKING);

		float vPos[3];
		GetClientAbsOrigin(target, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
		return target;
	}
	else {
		Retransmission(client);
	}
	return client;
}

int Retransmission(int client) {
	int target = 1;
	ArrayList aClients = new ArrayList(2);

	for (; target <= MaxClients; target++) {
		if (target == client || !IsClientInGame(target) || GetClientTeam(target) != 2 || !IsPlayerAlive(target))
			continue;
	
		aClients.Set(aClients.Push(!GetEntProp(target, Prop_Send, "m_isIncapacitated") ? 0 : !GetEntProp(target, Prop_Send, "m_isHangingFromLedge") ? 1 : 2), target, 1);
	}

	if (!aClients.Length)
		target = 0;
	else {
		aClients.Sort(Sort_Descending, Sort_Integer);

		target = aClients.Length - 1;
		target = aClients.Get(Math_GetRandomInt(aClients.FindValue(aClients.Get(target, 0)), target), 1);
	}

	delete aClients;

	if (target) {
		SetEntProp(client, Prop_Send, "m_bDucked", 1);
		SetEntityFlags(client, GetEntityFlags(client)|FL_DUCKING);

		float vPos[3];
		GetClientAbsOrigin(target, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
		return target;
	}
	return client;
}

int _GetTeam2Count(int team = -1) {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && (team == -1 || GetClientTeam(i) == team))
			count++;
	}
	return count;
}

// https://github.com/bcserv/smlib/blob/2c14acb85314e25007f5a61789833b243e7d0cab/scripting/include/smlib/math.inc#L144-L163
#define SIZE_OF_INT	2147483647 // without 0
int Math_GetRandomInt(int min, int max) {
	int random = GetURandomInt();
	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}