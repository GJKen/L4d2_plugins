#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#include <dhooks>

#define PLUGIN_VERSION	"1.0.1"

ArrayList ListArray;

TopMenu g_hTopMenu;
TopMenuObject hAddToTopMenu = INVALID_TOPMENUOBJECT;

bool g_bWitchNumber;

native int GetWitchNumber(int iWitchid);

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	MarkNativeAsOptional("GetWitchNumber");
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bWitchNumber = LibraryExists("l4d2_GetWitchNumber");
}

public void OnLibraryAdded(const char[] sName)
{
	if(StrEqual(sName, "l4d2_GetWitchNumber"))
		g_bWitchNumber = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if(StrEqual(sName, "l4d2_GetWitchNumber"))
		g_bWitchNumber = false;
	if (StrEqual(sName, "adminmenu"))
		g_hTopMenu = null;
}

public Plugin myinfo =
{
	name = "l4d2_remove_witch", 
	author = "豆瓣酱な", 
	description = "管理员菜单删除女巫.", 
	version = PLUGIN_VERSION, 
	url = "N/A"
};

public void OnPluginStart()
{
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
	ListArray = new ArrayList();
	RegConsoleCmd("sm_remove", MenuRemoveWitch, "管理员菜单删除女巫.");
}
 
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
			Format(buffer, maxlength, "删除女巫", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hAddToTopMenu)
			GetWitchMenu(param, 0, true);
	}
}

public Action MenuRemoveWitch(int client, int args)
{
	if(bCheckClientAccess(client))
		GetWitchMenu(client, 0, false);
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}

void GetWitchMenu(int client, int index, bool bButton = false)
{
	IsWitchTotalNumber();//循环获取所有女巫存到数组里.
	int iNumber = ListArray.Length;//获取数组的数量(也可以算是女巫的数量).
	if(iNumber > 0)
	{
		char line[32], sInfo[64], sData[3][32];
		Menu menu = new Menu(Menu_HandlerWitchMenu);
		Format(line, sizeof(line), "选择女巫:");
		SetMenuTitle(menu, "%s", line);
		menu.AddItem("全部", "删除全部");
		for (int i = 0; i < iNumber; i++)
		{
			int iWitchId = ListArray.Get(i);
			IntToString(EntIndexToEntRef(iWitchId), sData[0], sizeof(sData[]));
			IntToString(bButton, sData[1], sizeof(sData[]));
			strcopy(sData[2], sizeof(sData[]), GetWitchIndex(iWitchId));
			ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
			menu.AddItem(sInfo, sData[2]);
		}
		menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
		menu.ExitBackButton = bButton;//菜单首页显示数字8返回上一页选项.
		menu.DisplayAt(client, index, MENU_TIME_FOREVER);
	}
	else
	{
		if (g_hTopMenu != null && bButton)
			g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
		PrintToChat(client, "\x04[提示]\x05当前地图没有发现女巫.");
	}
}

//获取自定义的女巫编号.
char[] GetWitchIndex(int iWitchid)
{
	char sName[32];
	if(g_bWitchNumber == true)
	{
		int iIndex = GetWitchNumber(iWitchid);
		if(iIndex == 0)
			FormatEx(sName, sizeof(sName), "女巫");
		else
			FormatEx(sName, sizeof(sName), "女巫(%d)", iIndex);
	}
	else
		FormatEx(sName, sizeof(sName), "女巫");
	return sName;
}

int Menu_HandlerWitchMenu(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[64], sInfo[3][32];
			menu.GetItem(itemNum, sItem, sizeof(sItem));
			
			ExplodeString(sItem, "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
			if(strcmp(sItem, "全部", false) == 0)//对比字符串.
			{
				if(IsRemoveAllWitch())
					PrintToChat(client, "\x04[提示]\x05已删除全部\x03女巫\x05.");
				else
					PrintToChat(client, "\x04[提示]\x05地图里没有女巫\x05.");
				if (g_hTopMenu != null && view_as<bool>(StringToInt(sInfo[1])))
					g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
			}
			else
			{
				
				int iWitchId = EntRefToEntIndex(StringToInt(sInfo[0]));
				if (IsValidEdict(iWitchId))
				{
					RemoveEntity(iWitchId);
					PrintToChat(client, "\x04[提示]\x05已删除\x03%s\x05.", sInfo[2]);
				}
				else
				{
					PrintToChat(client, "\x04[提示]\x03%s\x05不存在.", sInfo[2]);
				}
				//必须延迟至少0.1秒重新打开菜单.
				DataPack hPack;
				CreateDataTimer(0.1, DelayOpeningMenu, hPack, TIMER_FLAG_NO_MAPCHANGE);
				hPack.WriteCell(client);
				hPack.WriteCell(menu.Selection);
				hPack.WriteCell(view_as<bool>(StringToInt(sInfo[1])));
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack && g_hTopMenu != null)
				g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
		}
	}
	return 0;
}

void IsWitchTotalNumber()
{
	int inf = -1;
	ListArray.Clear();//清除数组内容.
	while ((inf = FindEntityByClassname(inf, "witch")) != INVALID_ENT_REFERENCE)
		ListArray.Push(inf);
}

bool IsRemoveAllWitch()
{
	int inf = -1;
	bool bBoolean = false;
	while ((inf = FindEntityByClassname(inf, "witch")) != INVALID_ENT_REFERENCE)
	{
		RemoveEntity(inf);
		bBoolean = true;
	}
	return bBoolean;
}

public Action DelayOpeningMenu(Handle Timer, DataPack hPack)
{
	hPack.Reset();
	int client = hPack.ReadCell();
	int iSelection = hPack.ReadCell();
	bool bButton = hPack.ReadCell();
	if(IsValidClient(client))
		GetWitchMenu(client, iSelection, bButton);//重新打开菜单.
	return Plugin_Continue;
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}