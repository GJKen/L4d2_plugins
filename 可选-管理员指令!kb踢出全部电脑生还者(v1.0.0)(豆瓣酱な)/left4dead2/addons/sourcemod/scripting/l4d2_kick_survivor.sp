#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
//#include <adminmenu>
#include <dhooks>

#define PLUGIN_VERSION	"1.0.0"
/*
TopMenu g_hTopMenu;
TopMenuObject hAddToTopMenu = INVALID_TOPMENUOBJECT;
*/
public Plugin myinfo =
{
	name = "l4d2_kick_survivor", 
	author = "豆瓣酱な", 
	description = "踢出所有生还者电脑(包含闲置玩家的生还者电脑).", 
	version = PLUGIN_VERSION, 
	url = "N/A"
};

public void OnPluginStart()
{
	/*
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
	*/
	RegConsoleCmd("sm_kb", Command_KickAllSurvivorBot, "踢出所有电脑幸存者.");
}
/*
public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == g_hTopMenu)
		return;
	
	g_hTopMenu = topmenu;
	
	TopMenuObject objOtherMenu = FindTopMenuCategory(g_hTopMenu, "OtherFeatures");
	if (objOtherMenu == INVALID_TOPMENUOBJECT)
		objOtherMenu = AddToTopMenu(g_hTopMenu, "OtherFeatures", TopMenuObject_Category, MenuOtherHandler, INVALID_TOPMENUOBJECT);
	
	hAddToTopMenu= AddToTopMenu(g_hTopMenu,"sm_remove",TopMenuObject_Item,OtherMenuHandler,objOtherMenu,"sm_remove",ADMFLAG_ROOT);
}

public void MenuOtherHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
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

public void OtherMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == hAddToTopMenu)
			Format(buffer, maxlength, "踢出电脑", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hAddToTopMenu)
			IsKickAllSurvivorBot(param);
	}
}
 */
public Action Command_KickAllSurvivorBot(int client, int args) 
{
	if(bCheckClientAccess(client))
		IsKickAllSurvivorBot(client);
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

void IsKickAllSurvivorBot(int client)
{
	if(IsExecuteKickAllSurvivorBot())
		PrintToChat(client, "\x04[提示]\x05已踢出全部电脑生还者.");//此提示使用指令的玩家可见.
	else
		PrintToChat(client, "\x04[提示]\x05没有多余的电脑生还者.");
}

bool IsExecuteKickAllSurvivorBot()
{
	bool bKickAllSurvivorBot;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsClientIdle(i) == 0)
		{
			StripWeapons(i);//踢出前清理生还者全部物品.
			KickClient(i, "踢出全部电脑生还者.");
			bKickAllSurvivorBot = true;
		}
	}
	return bKickAllSurvivorBot;
}

bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}

int IsClientIdle(int client)
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

void StripWeapons(int client)
{
	int itemIdx;
	for (int x = 0; x <= 4; x++)
	{
		if((itemIdx = GetPlayerWeaponSlot(client, x)) != -1)
		{  
			RemovePlayerItem(client, itemIdx);
			RemoveEdict(itemIdx);
		}
	}
}