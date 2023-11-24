#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>

#define PLUGIN_VERSION	"1.0.2"

#define iArray	4

char g_sDifficultyName[iArray][32] = {"简单", "普通", "高级", "专家"};
char g_sDifficultyCode[iArray][32] = {"Easy", "Normal", "Hard", "Impossible"};

TopMenu hTopMenu_Difficulty;
TopMenuObject hDifficulty = INVALID_TOPMENUOBJECT;

public Plugin myinfo = 
{
	name 			= "l4d2_z_difficulty",
	author 			= "豆瓣酱な",
	description 	= "管理员!admid指令更改游戏难度",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public void OnPluginStart()
{
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		hTopMenu_Difficulty = null;
}
 
public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == hTopMenu_Difficulty)
		return;
	
	hTopMenu_Difficulty = topmenu;
	
	TopMenuObject objDifficultyMenu_Difficulty = FindTopMenuCategory(hTopMenu_Difficulty, "OtherFeatures");
	if (objDifficultyMenu_Difficulty == INVALID_TOPMENUOBJECT)
		objDifficultyMenu_Difficulty = AddToTopMenu(hTopMenu_Difficulty, "OtherFeatures", TopMenuObject_Category, AdminMenuHandler_Difficulty, INVALID_TOPMENUOBJECT);
	
	hDifficulty = AddToTopMenu(hTopMenu_Difficulty,"sm_the",TopMenuObject_Item,InfectedMenuHandler_Difficulty,objDifficultyMenu_Difficulty,"sm_the",ADMFLAG_ROOT);
}

public void AdminMenuHandler_Difficulty(Handle topmenu_Difficulty, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength_Difficulty)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength_Difficulty, "选择功能:", param);
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength_Difficulty, "其它功能", param);
	}
}

public void InfectedMenuHandler_Difficulty(Handle topmenu_Difficulty, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength_Difficulty)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == hDifficulty)
			Format(buffer, maxlength_Difficulty, "选择难度", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hDifficulty)
			DisplayDifficultyMenu(param);
	}
}

void DisplayDifficultyMenu(int client)
{
	char line[32];
	char sInfo[32];
	char sData[2][32];
	Menu menu = new Menu(Menu_Difficulty);
	
	Format(line, sizeof(line),	"选择难度:");
	SetMenuTitle(menu, "%s", 	line);

	for (int i = 0; i < iArray; i++)
	{
		strcopy(sData[0], sizeof(sData[]), g_sDifficultyCode[i]);
		strcopy(sData[1], sizeof(sData[]), g_sDifficultyName[i]);
		ImplodeStrings(sData, 2, "|", sInfo, sizeof(sInfo));//打包字符串.
		menu.AddItem(sInfo, g_sDifficultyName[i]);
	}

	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = true;
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

int Menu_Difficulty(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32], sDifficulty[32];
			GetConVarString(FindConVar("z_Difficulty"), sDifficulty, sizeof(sDifficulty));
			
			if(menu.GetItem(itemNum, sItem, sizeof(sItem)))
			{
				char sInfo[2][32];
				DisplayDifficultyMenu(client);
				ExplodeString(sItem, "|", sInfo, 2, 32);//拆分字符串.
				
				if(strcmp(sInfo[0], sDifficulty, false) == 0)
					PrintToChat(client, "\x04[提示]\x05选择的难度与当前难度相同.");
				else
				{
					SetConVarString(FindConVar("z_Difficulty"), sInfo[0]);
					PrintToChat(client, "\x04[提示]\x05难度已更改为\x04:\x03%s\x05.", sInfo[1]);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack && hTopMenu_Difficulty != null)
				hTopMenu_Difficulty.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}