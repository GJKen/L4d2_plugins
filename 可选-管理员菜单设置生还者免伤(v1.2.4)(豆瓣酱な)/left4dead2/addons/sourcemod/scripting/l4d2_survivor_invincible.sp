#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#include <sdkhooks>

#define PLUGIN_VERSION	"1.2.4"

bool bAllInvincible, bInvincible[MAXPLAYERS+1] = {false, ...};
int    g_iSurvivorLimit;
ConVar g_hSurvivorLimit;
TopMenu hTopMenu;
TopMenuObject hDifficulty = INVALID_TOPMENUOBJECT;

public Plugin myinfo = 
{
	name 			= "l4d2_survivor_invincible",
	author 			= "豆瓣酱な",
	description 	= "生还者免伤(单次受到的伤害不能超过100)",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public void OnPluginStart()
{
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);

	HookEvent("player_disconnect", Event_Playerdisconnect);//玩家离开.

	g_hSurvivorLimit = CreateConVar("l4d2_survivor_Limit", "100", "生还者免疫单次受到的伤害上限(单次受到的伤害超过该值时临时禁用免伤).", FCVAR_NOTIFY);
	g_hSurvivorLimit.AddChangeHook(ConVarChanged);
	AutoExecConfig(true, "l4d2_survivor_invincible");//生成指定文件名的CFG.
}

//地图开始.
public void OnMapStart()
{
	IsGetChange();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsGetChange();
}

void IsGetChange()
{
	g_iSurvivorLimit = g_hSurvivorLimit.IntValue;
}

//玩家离开.
public void Event_Playerdisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client > 0 && !IsFakeClient(client))
		bInvincible[client] = false;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		hTopMenu = null;
}
 
public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == hTopMenu)
		return;
	
	hTopMenu = topmenu;
	
	TopMenuObject objDifficultyMenu = FindTopMenuCategory(hTopMenu, "OtherFeatures");
	if (objDifficultyMenu == INVALID_TOPMENUOBJECT)
		objDifficultyMenu = AddToTopMenu(hTopMenu, "OtherFeatures", TopMenuObject_Category, AdminMenuHandler, INVALID_TOPMENUOBJECT);
	
	hDifficulty = AddToTopMenu(hTopMenu,"sm_god",TopMenuObject_Item,InfectedMenuHandler,objDifficultyMenu,"sm_god",ADMFLAG_ROOT);
}

public void AdminMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "选择功能:", param);
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "其它功能", param);
	}
}

public void InfectedMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == hDifficulty)
			Format(buffer, maxlength, "玩家免伤", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hDifficulty)
			GetPlayerListMenu(param, 0);
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (bAllInvincible)
		bInvincible[client] = true;
}

void GetPlayerListMenu(int client, int item)
{
	char sUID[32], sList[32];
	char sName[MAX_NAME_LENGTH];
	Menu menu = new Menu(MenuPlayerHandler);
	FormatEx(sList, sizeof(sList), "%s全部免伤", bAllInvincible ? "[关闭]" : "[开启]");
	menu.SetTitle("选择玩家:");
	menu.AddItem("a", sList);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && /*!IsFakeClient(i) && */GetClientTeam(i) == 2)
		{
			int bot = IsClientIdle(i);
			FormatEx(sUID, sizeof(sUID), "%d", GetClientUserId(!bot ? i : bot));
			FormatEx(sName, sizeof(sName), "%s%s", bInvincible[!bot ? i : bot] ? "[关闭]" : "[开启]", GetTrueName(i));
			menu.AddItem(sUID, sName);
		}
	}
	menu.ExitBackButton = true;//菜单首页显示数字8返回上一页选项.
	menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int MenuPlayerHandler(Menu menu, MenuAction action, int client, int param2) 
{
	switch (action) 
	{
		case MenuAction_Select: 
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if (sItem[0] == 'a')
			{
				SetAllSurvivorImmunity(client, bAllInvincible = !bAllInvincible);
				GetPlayerListMenu(client, 0);//这个必须放最后.
			}
			else 
			{
				int target = GetClientOfUserId(StringToInt(sItem));
				if (IsValidClient(target))
					SetSurvivorImmunity(target, client, false, false);
				GetPlayerListMenu(client, menu.Selection);//这个必须放最后.
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack && hTopMenu != null)
				hTopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void SetAllSurvivorImmunity(int client, bool bImmunity)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			SetSurvivorImmunity(i, client, bImmunity, true);
}

void SetSurvivorImmunity(int target, int client, bool bImmunity, bool bState)
{
	if(bState)
	{
		bInvincible[target] = bImmunity;
		if(client == target)
			PrintHintText(client, "[%s]全部玩家免疫单次[%d]以下的伤害.", bImmunity ? "已开启" : "已关闭", g_iSurvivorLimit);
		else
			PrintHintText(target, "%s[%s]了%s免疫单次[%d]以下的伤害.", target != client ? "管理员" : "你", bInvincible[target] ? "开启" : "关闭", target != client ? "你" : "自己", g_iSurvivorLimit);
	}
	else
	{
		bInvincible[target] = !bInvincible[target];
		PrintHintText(target, "%s[%s]了%s免疫单次[%d]以下的伤害.", target != client ? "管理员" : "你", bInvincible[target] ? "开启" : "关闭", target != client ? "你" : "自己", g_iSurvivorLimit);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{ 
	if(IsValidClient(client) && GetClientTeam(client) == 2)
	{	
		int bot = IsClientIdle(client);

		if(bInvincible[bot !=0 ? bot : client] && damage <= g_iSurvivorLimit)
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

char[] GetTrueName(int client)
{
	char g_sName[32];
	int Bot = IsClientIdle(client);
	
	if(Bot != 0)
		Format(g_sName, sizeof(g_sName), "闲置:%N", Bot);
	else
		GetClientName(client, g_sName, sizeof(g_sName));
	return g_sName;
}

int IsClientIdle(int client) 
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}