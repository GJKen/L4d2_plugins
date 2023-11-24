#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <LinGe_Function>
#include <builtinvotes>

public Plugin myinfo = {
	name = "l4d2 votes",
	author = "LinGe",
	description = "多功能投票：弹药、自动红外、友伤、服务器人数设置、特感击杀回血等",
	version = "1.8",
	url = "https://github.com/Lin515/L4D_LinGe_Plugins"
};

ConVar cv_svmaxplayers; // sv_maxplayers
ConVar cv_smVoteDelay; // sm_vote_delay
ConVar cv_adminPass; // 管理员是否不需要经过投票即可直接执行设置
ConVar cv_voteDelay;
ConVar cv_voteTime; // 投票应在多少秒内完成
ConVar cv_ammoMode; // 弹药模式
int g_ammoMode;
ConVar cv_autoLaser; // 自动红外
int g_autoLaser;
ConVar cv_teamHurt; // 是否允许投票改变友伤系数
ConVar cv_restartChapter; // 是否允许投票重启当前章节
ConVar cv_players; // 服务器默认人数
int g_players;
ConVar cv_playersLower; // 投票改变服务器人数下限
ConVar cv_playersUpper; // 投票改变服务器人数上限
ConVar cv_returnBlood; // 击杀回血
int g_returnBlood;
ConVar cv_specialReturn; // 特感击杀回血量
ConVar cv_witchReturn; // witch击杀回血量
ConVar cv_healthLimit; // 回血上限
ConVar cv_restore;
int g_zombieClassOffset; // 感染者类型的网络属性偏移量
bool g_hasMapTransitioned = false; // 是否发生地图过渡

// votes
enum struct VoteAction {
	char action[64];
	char params[64];
}
enum struct ExtraItem {
	bool isServerCommand; // 如果是服务器指令，则会发起投票执行
	char display[64];
	char command[128];
}
ArrayList g_extraItem;

// 友伤系数
ConVar cv_thFactor[4];
// 武器备弹量设置
ConVar cv_ammoInfinite; // 无限弹药无需换弹
ConVar cv_ammoMax[7]; // 最大弹药量
char cvar_ammoMax[][] = { // 控制台变量名
	"ammo_shotgun_max", // 单喷
	"ammo_autoshotgun_max", // 连喷
	"ammo_assaultrifle_max", // 步枪
	"ammo_grenadelauncher_max", // 榴弹
	"ammo_huntingrifle_max", // 连狙
	"ammo_sniperrifle_max", // 狙击
	"ammo_smg_max" // 冲锋枪
};

public void OnPluginStart()
{
	cv_svmaxplayers	= FindConVar("sv_maxplayers");
	cv_smVoteDelay	= FindConVar("sm_vote_delay");
	cv_ammoInfinite = FindConVar("sv_infinite_ammo"); // 该变量为1时 主副武器开枪均不消耗子弹
	for (int i=0; i<7; i++)
	{
		cv_ammoMax[i] = FindConVar(cvar_ammoMax[i]);
		cv_ammoMax[i].SetBounds(ConVarBound_Upper, true, 9999.0);
	}
	cv_thFactor[0]	= FindConVar("survivor_friendly_fire_factor_easy");
	cv_thFactor[1]	= FindConVar("survivor_friendly_fire_factor_normal");
	cv_thFactor[2]	= FindConVar("survivor_friendly_fire_factor_hard");
	cv_thFactor[3]	= FindConVar("survivor_friendly_fire_factor_expert");
	cv_adminPass	= CreateConVar("l4d2_votes_admin_pass", "1", "管理员发起的指令无需进行投票", _, true, 0.0, true, 1.0);
	cv_voteTime		= CreateConVar("l4d2_votes_time", "20", "投票应在多少秒内完成？", _, true, 10.0, true, 60.0);
	cv_voteDelay	= CreateConVar("l4d2_votes_delay", "10", "玩家需要等待多久才能再次发起投票？将一直锁定sm_vote_delay为本变量的值。", _, true, 0.0);
	cv_ammoMode		= CreateConVar("l4d2_votes_ammomode", "1", "多倍弹药模式 -1:完全禁用 0:禁用多倍但允许投票补满所有人弹药 1:一倍且允许开启多倍弹药 2:双倍 3:三倍 4:无限(需换弹) 5:无限(无需换弹)",  _, true, -1.0, true, 5.0);
	cv_autoLaser	= CreateConVar("l4d2_votes_autolaser", "0", "自动获得红外 -1:完全禁用 0:关闭 1:开启", _, true, -1.0, true, 1.0);
	cv_teamHurt		= CreateConVar("l4d2_votes_teamhurt", "0", "是否允许投票改变友伤系数 -1:不允许 0:允许", _, true, -1.0, true, 0.0);
	cv_restartChapter = CreateConVar("l4d2_votes_restartchapter", "0", "是否允许投票重启当前章节 -1:不允许 0:允许", _, true, -1.0, true, 0.0);
	cv_players		= CreateConVar("l4d2_votes_players", "8", "服务器人数，若为0则不改变人数。游戏时改变本参数是无效的。", _, true, 0.0, true, 32.0);
	cv_playersLower	= CreateConVar("l4d2_votes_players_lower", "4", "投票更改服务器人数的下限", _, true, 1.0, true, 32.0);
	cv_playersUpper	= CreateConVar("l4d2_votes_players_upper", "12", "投票更改服务器人数的上限。若下限>=上限，则不允许投票更改服务器人数。（这不影响本插件更改默认人数）", _, true, 1.0, true, 32.0);
	cv_returnBlood	= CreateConVar("ReturnBlood", "0", "特感击杀回血总开关 -1:完全禁用 0:关闭 1:开启", _, true, -1.0, true, 1.0);
	cv_specialReturn = CreateConVar("l4d2_votes_returnblood_special", "2", "击杀一只特感回多少血", _, true, 0.0, true, 100.0);
	cv_witchReturn	= CreateConVar("l4d2_votes_returnblood_witch", "10", "击杀一只Witch回多少血", _, true, 0.0, true, 100.0);
	cv_healthLimit	= CreateConVar("l4d2_votes_returnblood_limit", "100", "最高回血上限。（仅影响回血时的上限，不影响其它情况下的血量上限）", _, true, 40.0, true, 500.0);
	cv_restore		= CreateConVar("l4d2_votes_changelevel_restore", "1", "更换地图后重置多倍弹药、自动红外、玩家人数、击杀回血、友伤系数（正常过关不会重置）", _, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_votes");
	cv_ammoMode.AddChangeHook(AmmoModeChanged);
	cv_autoLaser.AddChangeHook(AutoLaserChanged);
	cv_voteDelay.AddChangeHook(VoteDelayChanged);
	cv_smVoteDelay.AddChangeHook(VoteDelayChanged);
	HookEvent("player_death", Event_player_death, EventHookMode_Post);
	HookEvent("weapon_reload", Event_weapon_reload, EventHookMode_Post); // 玩家换弹
	HookEvent("map_transition", Event_map_transition, EventHookMode_PostNoCopy);
	AddNormalSoundHook(OnNormalSound); // 挂钩声音

	RegServerCmd("l4d2_votes_additem", Cmd_additem, "给投票菜单增加选项");
	RegServerCmd("l4d2_votes_removeitem", Cmd_removeitem, "移除额外的添加项");
	RegConsoleCmd("sm_votes", Cmd_votes, "多功能投票菜单");

	g_zombieClassOffset = FindSendPropInfo("CTerrorPlayer", "m_zombieClass");
	g_extraItem = new ArrayList(sizeof(ExtraItem));
	// 防止游戏中途加载插件时无法正常触发自动红外
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
			SDKHook(i, SDKHook_WeaponDropPost, OnWeaponDropPost);
		}
	}
}

public Action Event_map_transition(Event event, const char[] name, bool dontBroadcast)
{
	g_hasMapTransitioned = true;
}
public void OnMapStart()
{
	g_ammoMode = cv_ammoMode.IntValue;
	g_autoLaser = cv_autoLaser.IntValue;
	g_players = cv_players.IntValue;
	g_returnBlood = cv_returnBlood.IntValue;
}

bool g_isValidConVar = false;
public void OnConfigsExecuted()
{
	if ((g_hasMapTransitioned || !cv_restore.BoolValue)
	&& g_isValidConVar)
	{
		// 如果是正常过关，或者设定更换地图不重置功能开关，则还原为之前的功能设置
		cv_ammoMode.IntValue = g_ammoMode;
		cv_autoLaser.IntValue = g_autoLaser;
		cv_players.IntValue	= g_players;
		cv_returnBlood.IntValue = g_returnBlood;
	}
	else
	{
		// 否则，则不保留之前的设置
		for (int i=0; i<4; i++)
			cv_thFactor[i].RestoreDefault();
	}
	g_hasMapTransitioned = false;
	g_isValidConVar = true;

	if (cv_players.IntValue > 0 && null != cv_svmaxplayers)
		cv_svmaxplayers.IntValue = cv_players.IntValue;
	cv_smVoteDelay.IntValue = cv_voteDelay.IntValue;
}

public void VoteDelayChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	cv_smVoteDelay.IntValue = cv_voteDelay.IntValue;
}

public Action Event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	// 特感击杀回血
	if (1 == cv_returnBlood.IntValue)
	{
		int victim = GetClientOfUserId(event.GetInt("userid"));
		int attacker = GetClientOfUserId(event.GetInt("attacker"));
		// 被攻击者必须是有效特感 攻击者必须是有效生还者并且没有倒地
		if (IsValidClient(victim) && GetClientTeam(victim) == 3
		&& IsValidClient(attacker) && GetClientTeam(attacker) == 2
		&& !IsIncapacitated(attacker) )
		{
			int surHealth = GetHealth(attacker);
			int zombieClass = GetEntData(victim, g_zombieClassOffset); // 获取特感类型
			if (zombieClass >= 1 && zombieClass <= 6
			&& cv_specialReturn.IntValue > 0) // 如果是普通特感
				surHealth += cv_specialReturn.IntValue;
			else if (7 == zombieClass
			&& cv_witchReturn.IntValue > 0) // 如果是witch
				surHealth += cv_witchReturn.IntValue;
			else
				return Plugin_Continue;
			if (surHealth > cv_healthLimit.IntValue)
				surHealth = cv_healthLimit.IntValue;
			SetHealth(attacker, surHealth);
		}
	}
	return Plugin_Continue;
}

// 添加额外的选项
public Action Cmd_additem(int args)
{
	if (args != 3)
	{
		PrintToServer("l4d2_votes_additem 是否是服务器指令[0或1] 选项名 指令");
		return Plugin_Handled;
	}
	char buffer[5];
	ExtraItem item;

	GetCmdArg(1, buffer, sizeof(buffer));
	if (strcmp(buffer, "0") == 0)
		item.isServerCommand = false;
	else
		item.isServerCommand = true;
	GetCmdArg(2, item.display, sizeof(item.display));
	GetCmdArg(3, item.command, sizeof(item.command));
	int idx = FindItem(item.display);
	if (-1 == idx)
		g_extraItem.PushArray(item);
	else
		g_extraItem.SetArray(idx, item);

	return Plugin_Handled;
}
// 移除额外的添加项
public Action Cmd_removeitem(int args)
{
	if (args != 1)
	{
		PrintToServer("l4d2_votes_removeitem 选项名");
		return Plugin_Handled;
	}
	char display[64];
	GetCmdArg(1, display, sizeof(display));
	int idx = FindItem(display);
	if (-1 == idx)
		PrintToServer("l4d2_votes_removeitem 未找到选项：%s", display);
	else
		g_extraItem.Erase(idx);
	return Plugin_Handled;
}
int FindItem(const char[] itemDisplay)
{
	ExtraItem item;
	int len = g_extraItem.Length;
	for (int i=0; i<len; i++)
	{
		g_extraItem.GetArray(i, item);
		if (strcmp(item.display, itemDisplay) == 0)
			return i;
	}
	return -1;
}

public Action Cmd_votes(int client, int args)
{
	if (0 == client)
		return Plugin_Handled;

	Menu menu = new Menu(VotesMenu_Selected);
	menu.SetTitle("发起投票");

	if (cv_playersUpper.IntValue > cv_playersLower.IntValue
	&& cv_svmaxplayers != null)
		menu.AddItem("Menu_MaxPlayers", "服务器人数");
	if (0 == cv_teamHurt.IntValue)
		menu.AddItem("Menu_TeamHurt", "友伤设置");

	if (0 == cv_ammoMode.IntValue)
		menu.AddItem("Vote_GiveAmmo", "补满弹药");
	else if (1 <= cv_ammoMode.IntValue)
		menu.AddItem("Menu_Ammo", "弹药设置");

	if (0 == cv_autoLaser.IntValue)
		menu.AddItem("Vote_AutoLaser_1", "开启自动红外");
	else if (1 == cv_autoLaser.IntValue)
		menu.AddItem("Vote_AutoLaser_0", "关闭自动红外");

	if (0 == cv_returnBlood.IntValue)
		menu.AddItem("Vote_ReturnBlood_1", "开启击杀回血");
	else if (1 == cv_returnBlood.IntValue)
		menu.AddItem("Vote_ReturnBlood_0", "关闭击杀回血");

	if (0 == cv_restartChapter.IntValue)
		menu.AddItem("Vote_Restart", "重启当前章节");

	// 额外添加项
	int len = g_extraItem.Length;
	ExtraItem item;
	char buffer[20];
	for (int i=0; i<len; i++)
	{
		g_extraItem.GetArray(i, item);
		FormatEx(buffer, sizeof(buffer), "ExtraItem_%d", i);
		menu.AddItem(buffer, item.display);
	}
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int VotesMenu_Selected(Menu menu, MenuAction action, int client, int curSel)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char info[128], disp[128];
			menu.GetItem(curSel, info, sizeof(info), _, disp, sizeof(disp));
			if (StrContains(info, "Menu_") == 0)
			{
				Menu_Exec(client, info);
			}
			else if (StrContains(info, "Vote_") == 0)
			{
				Vote_Exec(client, info, disp);
			}
			else if (StrContains(info, "ExtraItem_") == 0)
			{
				ExtraItem_Exec(client, StringToInt(info[strlen("ExtraItem_")]));
			}
		}
	}
}

void Menu_Exec(int client, const char[] str)
{
	Menu menu = new Menu(VotesTowMenu_Selected);
	char info[128], disp[128];
	if (strcmp(str, "Menu_MaxPlayers") == 0)
	{
		int i = cv_playersLower.IntValue;
		int max = cv_playersUpper.IntValue;
		while (i <= max)
		{
			FormatEx(info, sizeof(info), "Vote_MaxPlayers_%d", i);
			FormatEx(disp, sizeof(disp), "%d 人", i);
			menu.AddItem(info, disp);
			i++;
		}
		menu.SetTitle("设置服务器人数");
	}
	else if (strcmp(str, "Menu_TeamHurt") == 0)
	{
		menu.AddItem("Vote_TeamHurt_-1.0", "恢复默认");
		menu.AddItem("Vote_TeamHurt_0.0", "0.0(简单)");
		menu.AddItem("Vote_TeamHurt_0.1", "0.1(普通)");
		menu.AddItem("Vote_TeamHurt_0.2", "0.2");
		menu.AddItem("Vote_TeamHurt_0.3", "0.3(困难)");
		menu.AddItem("Vote_TeamHurt_0.4", "0.4");
		menu.AddItem("Vote_TeamHurt_0.5", "0.5(专家)");
		menu.AddItem("Vote_TeamHurt_0.6", "0.6");
		menu.AddItem("Vote_TeamHurt_0.7", "0.7");
		menu.AddItem("Vote_TeamHurt_0.8", "0.8");
		menu.AddItem("Vote_TeamHurt_0.9", "0.9");
		menu.AddItem("Vote_TeamHurt_1.0", "1.0");
		menu.SetTitle("设置友伤系数");
	}
	else if (strcmp(str, "Menu_Ammo") == 0)
	{
		menu.AddItem("Vote_GiveAmmo", "补满弹药");
		menu.AddItem("Vote_AmmoMode_1", "一倍");
		menu.AddItem("Vote_AmmoMode_2", "双倍");
		menu.AddItem("Vote_AmmoMode_3", "三倍");
		menu.AddItem("Vote_AmmoMode_4", "无限(需换弹)");
		menu.AddItem("Vote_AmmoMode_5", "无限(无需换弹)");
		menu.SetTitle("弹药设置");
	}
	else
	{
		delete menu;
		return;
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int VotesTowMenu_Selected(Menu menu, MenuAction action, int client, int curSel)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if( curSel == MenuCancel_ExitBack )
				Cmd_votes(client, 0);
		}
		case MenuAction_Select:
		{
			char info[128], disp[128];
			menu.GetItem(curSel, info, sizeof(info), _, disp, sizeof(disp));
			if (StrContains(info, "Vote_") == 0)
				Vote_Exec(client, info, disp);
		}
	}
}

void ExtraItem_Exec(int client, int index)
{
	ExtraItem item;
	g_extraItem.GetArray(index, item);
	if (item.isServerCommand)
	{
		char buffer[128];
		FormatEx(buffer, sizeof(buffer), "ServerCommand_%s", item.command);
		Vote_Exec(client, buffer, item.display);
	}
	else
		ClientCommand(client, item.command);
}

VoteAction g_vote;
Handle g_voteExt = INVALID_HANDLE;
char g_votepassDisp[128];
void Vote_Exec(int client, const char[] info, const char[] disp)
{
	if (GetClientTeam(client) == 1)
	{
		PrintToChat(client, "\x04旁观者不能发起投票");
		return;
	}
	if (!IsNewBuiltinVoteAllowed())
	{
		PrintToChat(client, "\x04暂时还不能发起新投票");
		return;
	}

	char voteDisp[128];
	if (strcmp(info, "Vote_GiveAmmo") == 0)
	{
		strcopy(g_vote.action, sizeof(g_vote.action), "GiveAmmo");
		strcopy(voteDisp, sizeof(voteDisp), "是否同意补满所有生还者弹药？");
		strcopy(g_votepassDisp, sizeof(g_votepassDisp), "补充所有生还者弹药");
	}
	else if (strcmp(info, "Vote_Restart") == 0)
	{
		strcopy(g_vote.action, sizeof(g_vote.action), "Restart");
		strcopy(voteDisp, sizeof(voteDisp), "是否同意重启当前章节？");
		strcopy(g_votepassDisp, sizeof(g_votepassDisp), "重启当前章节");
	}
	else if (StrContains(info, "Vote_AmmoMode_") == 0)
	{
		strcopy(g_vote.action, sizeof(g_vote.action), "AmmoMode");
		strcopy(g_vote.params, sizeof(g_vote.params), info[strlen("Vote_AmmoMode_")]);
		FormatEx(voteDisp, sizeof(voteDisp), "是否同意设置弹药为 %s ？", disp);
		FormatEx(g_votepassDisp, sizeof(g_votepassDisp), "设置弹药为 %s", disp);
	}
	else if (StrContains(info, "Vote_TeamHurt_") == 0)
	{
		strcopy(g_vote.action, sizeof(g_vote.action), "TeamHurt");
		strcopy(g_vote.params, sizeof(g_vote.params), info[strlen("Vote_TeamHurt_")]);
		FormatEx(voteDisp, sizeof(voteDisp), "是否同意设置友伤系数为 %s？", disp);
		FormatEx(g_votepassDisp, sizeof(g_votepassDisp), "设置友伤系数为 %s", disp);
	}
	else if (StrContains(info, "Vote_MaxPlayers_") == 0)
	{
		strcopy(g_vote.action, sizeof(g_vote.action), "MaxPlayers");
		strcopy(g_vote.params, sizeof(g_vote.params), info[strlen("Vote_MaxPlayers_")]);
		FormatEx(voteDisp, sizeof(voteDisp), "是否同意设置服务器人数为 %s 人？", g_vote.params);
		FormatEx(g_votepassDisp, sizeof(g_votepassDisp), "设置服务器人数为 %s 人", g_vote.params);
	}
	else if (StrContains(info, "Vote_ReturnBlood_") == 0)
	{
		strcopy(g_vote.action, sizeof(g_vote.action), "ReturnBlood");
		strcopy(g_vote.params, sizeof(g_vote.params), info[strlen("Vote_ReturnBlood_")]);
		FormatEx(voteDisp, sizeof(voteDisp), "是否同意%s？", disp);
		FormatEx(g_votepassDisp, sizeof(g_votepassDisp), "%s", disp);
	}
	else if (StrContains(info, "Vote_AutoLaser_") == 0)
	{
		strcopy(g_vote.action, sizeof(g_vote.action), "AutoLaser");
		strcopy(g_vote.params, sizeof(g_vote.params), info[strlen("Vote_AutoLaser_")]);
		FormatEx(voteDisp, sizeof(voteDisp), "是否同意%s？", disp);
		FormatEx(g_votepassDisp, sizeof(g_votepassDisp), "%s", disp);
	}
	else if (StrContains(info, "ServerCommand_") == 0)
	{
		strcopy(g_vote.action, sizeof(g_vote.action), "ServerCommand");
		strcopy(g_vote.params, sizeof(g_vote.params), info[strlen("ServerCommand_")]);
		FormatEx(voteDisp, sizeof(voteDisp), "是否同意%s？", disp);
		FormatEx(g_votepassDisp, sizeof(g_votepassDisp), "%s", disp);
	}
	else
	{
		LogMessage("什么也没做 info:%s disp:%s", info, disp);
		return;
	}

	if (GetUserAdmin(client) != INVALID_ADMIN_ID && cv_adminPass.IntValue == 1)
	{
		// 如果管理员不需要经过投票，则跳过投票流程
		char name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));
		PrintToChatAll("\04管理员\x03 %s \x04执行了指令：\x03%s", name, g_votepassDisp);
		Delay_VotePass(INVALID_HANDLE);
	}
	else
	{
		// 正常发起投票流程
		int[] players = new int[MaxClients];
		int count = 0;
		for (int i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == 1))
				continue;
			players[count++] = i;
		}
		g_voteExt = CreateBuiltinVote(Vote_ActionHandler_Ext, BuiltinVoteType_Custom_YesNo,
			BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(g_voteExt, voteDisp);
		SetBuiltinVoteInitiator(g_voteExt, client);
		DisplayBuiltinVote(g_voteExt, players, count, cv_voteTime.IntValue);
		FakeClientCommand(client, "Vote Yes"); // 发起投票的人默认同意
	}
}

public int Vote_ActionHandler_Ext(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		// 已完成投票
		case BuiltinVoteAction_VoteEnd:
		{
			if (param1 == BUILTINVOTES_VOTE_YES)
			{
				DisplayBuiltinVotePass(vote, g_votepassDisp);
				CreateTimer(3.0, Delay_VotePass);
			}
			else if (param1 == BUILTINVOTES_VOTE_NO)
			{
				DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
			}
			else
			{
				// Should never happen, but is here as a diagnostic
				DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
				LogMessage("Vote failure. winner = %d", param1);
			}
		}
		// 投票动作结束
		case BuiltinVoteAction_End:
		{
			g_voteExt = INVALID_HANDLE;
			CloseHandle(vote);
		}
	}
}
public Action Delay_VotePass(Handle timer)
{
	if (strcmp(g_vote.action, "GiveAmmo") == 0)
		GiveSurvivorsAmmo();
	else if (strcmp(g_vote.action, "Restart") == 0)
		SetConVarInt(FindConVar("mp_restartgame"), 1);
	else if (strcmp(g_vote.action, "AmmoMode") == 0)
		cv_ammoMode.SetString(g_vote.params);
	else if (strcmp(g_vote.action, "TeamHurt") == 0)
	{
		if (strcmp(g_vote.params, "-1.0") == 0)
		{
			for (int i=0; i<4; i++)
				cv_thFactor[i].RestoreDefault();
		}
		else
		{
			for (int i=0; i<4; i++)
				cv_thFactor[i].SetString(g_vote.params);
		}
	}
	else if (strcmp(g_vote.action, "MaxPlayers") == 0)
	{
		cv_players.SetString(g_vote.params);
		cv_svmaxplayers.SetString(g_vote.params);
	}
	else if (strcmp(g_vote.action, "ReturnBlood") == 0)
		cv_returnBlood.SetString(g_vote.params);
	else if (strcmp(g_vote.action, "AutoLaser") == 0)
		cv_autoLaser.SetString(g_vote.params);
	else if (strcmp(g_vote.action, "ServerCommand") == 0)
		ServerCommand(g_vote.params);
}


// 多倍弹药
public void AmmoModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetAmmoMode();
}

void SetAmmoMode()
{
	int mode = cv_ammoMode.IntValue;

	if (mode < 2)
	{
		for (int i=0; i<7; i++)
			cv_ammoMax[i].RestoreDefault();
		return;
	}

	if (5 == mode) // 无限弹药无需换弹
	{
		cv_ammoInfinite.IntValue = 1;
		return;
	}
	cv_ammoInfinite.IntValue = 0;

	if (mode>=2 && mode<=3) // 2倍、3倍弹药
	{
		char buffer[10];
		// 设置的新弹药量
		for (int i=0; i<7; i++)
		{
			cv_ammoMax[i].GetDefault(buffer, sizeof(buffer));
			cv_ammoMax[i].IntValue = StringToInt(buffer) * mode;
		}
	}

	if (mode > 0)
		GiveSurvivorsAmmo();
}
// 补满生还者弹药
void GiveSurvivorsAmmo()
{
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
			CheatCommand(i, "give", "ammo");
	}
}

// 玩家换弹 自动补充弹药
bool g_mute = false;
public Action Event_weapon_reload(Event event, const char[] name, bool dontBroadcast)
{
	if (4 == cv_ammoMode.IntValue)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		if (IsValidClient(client) && GetClientTeam(client) == 2)
		{
			// 每次给予弹药都会出现拾物音效 会比较吵 所以在给予弹药时屏蔽下一次的拾物音效
			g_mute = true;
			CheatCommand(client, "give", "ammo");
			CreateTimer(0.01, Delay_SetMute); // 防止备弹已满，给予弹药时未触发拾物音效而导致g_mute一直滞留为true
		}
	}
}
public Action OnNormalSound(int clients[65], int &numClients, char sample[256], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[256], int &seed)
{
	// 屏蔽自动给弹药时的拾物音效
	// 不检查产生拾物音效的动作，一次屏蔽是针对所有人的屏蔽，一般不会出现什么问题
	// 因为很难出现同一tick中 一人换弹一人刚好在拾取物品
	// 就算出现了也不过是听不到这次的声音 也没啥大不了的 ╮(╯▽╰)╭
	if (g_mute && StrContains(sample, "items/itempickup.wav")!=-1)
	{
		g_mute = false;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
public Action Delay_SetMute(Handle timer)
{
	g_mute = false;
}

// 自动获得红外
#define UPGRADE_LASER  (1 << 2) // 100b
public void AutoLaserChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (1 == cv_autoLaser.IntValue)
	{
		for (int i=1; i<=MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == 2)
				SetWeaponLaser(GetPlayerWeaponSlot(i, 0));
		}
	}
}

public void OnClientPutInServer(int client)
{
	if (IsValidClient(client))
	{
		SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
		SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDropPost);
	}
}
public void OnClientDisconnect(int client)
{
	if (IsValidClient(client))
	{
		SDKUnhook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
		SDKUnhook(client, SDKHook_WeaponDropPost, OnWeaponDropPost);
	}
}

public Action OnWeaponEquipPost(int client, int weapon)
{
	if (1 == cv_autoLaser.IntValue)
	{
		if (IsValidClient(client) && GetClientTeam(client) == 2)
			SetWeaponLaser(weapon);
	}
}

// 武器丢掉时去除红外，如果不去除武器多了满地都是红外
public Action OnWeaponDropPost(int client, int weapon)
{
	if (1 == cv_autoLaser.IntValue)
		SetWeaponLaser(weapon, true);
}

void SetWeaponLaser(int weapon, bool remove=false)
{
	if (IsValidEntity(weapon) && HasEntProp(weapon, Prop_Send, "m_upgradeBitVec"))
	{
		int flags = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
		if (!(flags & UPGRADE_LASER) && !remove) // 如果没有红外，且要求获得
			SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", flags | UPGRADE_LASER);
		else if ((flags & UPGRADE_LASER) && remove) // 如果有红外，且要求去除
			SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", flags & (~UPGRADE_LASER));
	}
}