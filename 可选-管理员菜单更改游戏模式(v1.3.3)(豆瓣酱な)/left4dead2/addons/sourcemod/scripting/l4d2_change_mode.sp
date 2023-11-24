#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>

#define PLUGIN_VERSION	"1.3.3"
#define CVAR_FLAGS		FCVAR_NOTIFY

char g_sModeCoop[][][] = 
{
	{"coop", "普通战役"},
	{"mutation3", "血流不止"}, 
	{"realism", "普通写实"}, 
	{"community1", "特感速递"}, 
	{"community5", "死亡之门"}, 
	{"mutation4", "绝境求生"}, 
	{"mutation2", "枪枪爆头"}, 
	{"mutation16", "猎人派对"}, 
	{"mutation14", "无法近身"}, 
	{"community2", "感染季节"}, 
	{"mutation9", "侏儒卫队"}, 
	{"mutation8", "铁人意志"}
};

//对抗模式.
char g_sModeVersus[][][] = 
{
	{"versus", "普通对抗"},
	{"teamversus ", "团队对抗"},
	{"scavenge", "清道夫"},
	{"teamscavenge", "团队清道夫"},
	{"community3", "骑师派对"},
	{"community6", "官方药抗"},
	{"mutation11", "没有救赎"},
	{"mutation12", "写实对抗"},
	{"mutation13", "清道肆虐"},
	{"mutation15", "生存对抗"},
	{"mutation18", "失血对抗"},
	{"mutation19", "坦克派对"}
};

//单人模式.
char g_sModeSingle[][][] = 
{
	{"mutation1", "孤身一人"},
	{"mutation17", "孤胆枪手"}
};

bool g_bButton;
int    g_iChangeMode;
float  g_fChangeTime;
ConVar g_hChangeMode, g_hChangeTime;

Handle g_hGameMode;

TopMenu hTopMenu;
TopMenuObject hAddToTopMenu = INVALID_TOPMENUOBJECT;

public Plugin myinfo =
{
	name = "l4d2_change_mode", 
	author = "豆瓣酱な", 
	description = "管理员指令!mode更改游戏模式.", 
	version = PLUGIN_VERSION, 
	url = "N/A"
};

public void OnPluginStart()
{
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
	
	RegConsoleCmd("sm_mode", MenuMode, "管理员更换游戏模式.");
	
	g_hChangeMode	= CreateConVar("l4d2_change_mode","1","启用管理员指令!mode更换游戏模式(指令!mode空格+模式代码更换其它模式)? 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hChangeTime	= CreateConVar("l4d2_change_time","6.0","管理员更换模式后延迟几秒重启当前章节?", CVAR_FLAGS);

	g_hChangeMode.AddChangeHook(CvarChanged);
	g_hChangeTime.AddChangeHook(CvarChanged);

	AutoExecConfig(true, "l4d2_change_mode");
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
	
	hAddToTopMenu= AddToTopMenu(hTopMenu,"sm_mode",TopMenuObject_Item,InfectedMenuHandler,objDifficultyMenu,"sm_mode",ADMFLAG_ROOT);
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
		if (object_id == hAddToTopMenu)
			Format(buffer, maxlength, "更改模式", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hAddToTopMenu)
			GetAllModeMenu(param, 0, true);
	}
}

//地图开始.
public void OnMapStart()
{
	GetCvars();
	StopTimer();
}

//地图结束.
public void OnMapEnd()
{
	StopTimer();
}

void StopTimer()
{
	delete g_hGameMode;
}

public void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iChangeMode = g_hChangeMode.IntValue;
	g_fChangeTime = g_hChangeTime.FloatValue;
}

public Action MenuMode(int client, int args)
{
	if(bCheckClientAccess(client))
		GetModeMenu(client, args);
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

void GetModeMenu(int client, int args)
{
	switch (g_iChangeMode)
	{
		case 0:
			PrintToChat(client, "\x05[提示]\x03更换游戏模式已禁用,请在CFG中设为1启用.");
		case 1:
			ShowModeMenu(client, args);
	}
}

void ShowModeMenu(int client, int args)
{
	switch (args)
	{
		case 0:
		{
			GetAllModeMenu(client, 0, false);
		}
		case 1:
		{
			char sMode[32];
			GetCmdArgString(sMode, sizeof(sMode));

			if(strcmp(sMode, GetGameMode(), false) == 0)
				PrintToChat(client, "\x04[提示]\x05当前已是\x04(\x03%s\x04)\x05模式.", GetModeName());
			else
			{
				SetConVarString(FindConVar("mp_gamemode"), sMode);
				
				if (!StrEqual(sMode, GetGameMode(), false) == true)
					PrintToChat(client, "\x04[模式]\x05请确认你输入的模式代码\x04[\x03%s\x04]\x05是否正确.", sMode);
				else
				{
					if(g_hGameMode == null)
					{
						PrintToChatAll("\x04[模式]\x05游戏模式更改为\x04(\x03%s\x04)\x04,\x05将在\x03%.1f秒\x05后重启当前章节.", GetModeName(), g_fChangeTime);
						PrintHintTextToAll("[模式] 游戏模式更改为(%s),期间可能出现黑屏,请等待数秒.", GetModeName());
						g_hGameMode = CreateTimer(g_fChangeTime, DelaySetGameMode);//延迟重启当前章节
					}
					else
						PrintToChat(client, "\x04[提示]\x05当前正在更改游戏模式,请勿重复设置游戏模式.", GetModeName());
				}
			}
		}
	}
}

void GetAllModeMenu(int client, int index, bool bButton)
{
	char line[128], sButton[32];
	Menu menu = new Menu(Menu_HandlerAllMode);
	IntToString(bButton, sButton, sizeof(sButton));
	Format(line, sizeof(line), "当前:%s\n其它:!mode空格+代码.", GetModeName());
	SetMenuTitle(menu, "%s", line);
	menu.AddItem(sButton, "重启章节");
	menu.AddItem(sButton, "战役模式");
	menu.AddItem(sButton, "对抗模式");
	menu.AddItem(sButton, "单人模式");

	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = bButton;//菜单首页显示数字8返回上一页选项.
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

int Menu_HandlerAllMode(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[32], sName[32];
			menu.GetItem(itemNum, sItem, sizeof(sItem), _, sName, sizeof(sName));
			bool bButton = view_as<bool>(StringToInt(sItem));

			switch(itemNum)
			{
				case 0:
					IsRestartGameMenu(client, 0, sName, bButton);
				case 1:
					GetGameModeMenu(client, 0, sName, g_sModeCoop, sizeof(g_sModeCoop), bButton);
				case 2:
					GetGameModeMenu(client, 0, sName, g_sModeVersus, sizeof(g_sModeVersus), bButton);
				case 3:
					GetGameModeMenu(client, 0, sName, g_sModeSingle, sizeof(g_sModeSingle), bButton);
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack && hTopMenu != null)
				hTopMenu.Display(client, TopMenuPosition_LastCategory);
		}
	}
	return 0;
}

void IsRestartGameMenu(int client, int index, char[] sModeName, bool bButton)
{
	if(g_hGameMode == null)
	{
		char line[32];
		Menu menu = new Menu(Menu_HandlerRestartGameMenu);
		Format(line, sizeof(line), "%s:", sModeName);
		SetMenuTitle(menu, "%s", line);
		menu.AddItem("0", "确认");
		menu.AddItem("1", "取消");
		menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
		menu.ExitBackButton = true;
		menu.DisplayAt(client, index, MENU_TIME_FOREVER);
		g_bButton = bButton;
	}
	else
		PrintToChat(client, "\x04[提示]\x05当前正在重启当前章节.");
}

int Menu_HandlerRestartGameMenu(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(itemNum, sItem, sizeof(sItem));
			if(StringToInt(sItem) == 0)
				IsForceRestartGame();
		}
			
		case MenuAction_Cancel:
			if(itemNum == MenuCancel_ExitBack)
				GetAllModeMenu(client, 0, g_bButton);
	}
	return 0;
}

void IsForceRestartGame()
{
	delete g_hGameMode;
	g_hGameMode = CreateTimer(g_fChangeTime, DelaySetGameMode);//延迟重启当前章节
	PrintHintTextToAll("[提示] 服务器将在 %.1f秒 后重启当前章节.", g_fChangeTime);
	PrintToChatAll("\x04[提示]\x05服务器将在\x03%.1f秒\x05后重启当前章节.", g_fChangeTime);
}

void GetGameModeMenu(int client, int index, char[] g_sModeName, char[][][] g_sModeCode, int g_iModeCode, bool bButton)
{
	g_bButton = bButton;
	char line[128], sInfo[128], sData[3][128];
	Menu menu = new Menu(Menu_HandlerGameMode);
	Format(line, sizeof(line), "当前模式:%s\n选择更换的%s:", GetModeName(), g_sModeName);
	SetMenuTitle(menu, "%s", 	line);
	for (int i = 0; i < g_iModeCode; i++)
	{
		strcopy(sData[0], sizeof(sData[]), g_sModeCode[i][0]);
		strcopy(sData[1], sizeof(sData[]), g_sModeCode[i][1]);
		IntToString(bButton, sData[2], sizeof(sData[]));
		ImplodeStrings(sData, sizeof(sData), "|", sInfo, sizeof(sInfo));//打包字符串.
		menu.AddItem(sInfo, g_sModeCode[i][1]);
	}
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = true;
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

int Menu_HandlerGameMode(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[128], sInfo[3][128];
			menu.GetItem(itemNum, sItem, sizeof(sItem));
			ExplodeString(sItem, "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
			bool bButton = view_as<bool>(StringToInt(sInfo[2]));
			if(strcmp(sInfo[0], GetGameMode(), false) == 0)
			{
				GetAllModeMenu(client, 0, bButton);//重新打开游戏模式选择菜单.
				PrintToChat(client, "\x04[提示]\x05当前已是\x04(\x03%s\x04)\x05模式.", sInfo[1]);
			}
			else
			{
				if(g_hGameMode == null)
				{
					g_hGameMode = CreateTimer(g_fChangeTime, DelaySetGameMode);//延迟重启当前章节
					SetConVarString(FindConVar("mp_gamemode"), sInfo[0]);//设置游戏模式.
					PrintHintTextToAll("[模式] 游戏模式更改为(%s),期间可能出现黑屏,请等待数秒.", sInfo[1]);
					PrintToChatAll("\x04[模式]\x05游戏模式更改为\x04(\x03%s\x04)\x04,\x05将在\x03%.1f秒\x05后重启当前章节.", sInfo[1], g_fChangeTime);
				}
				else
					PrintToChat(client, "\x04[提示]\x05当前正在更改模式,请勿重复设置游戏模式.");
			}
		}
		case MenuAction_Cancel:
			if(itemNum == MenuCancel_ExitBack)
				GetAllModeMenu(client, 0, g_bButton);//重新打开游戏模式选择菜单.
	}
	return 0;
}

public Action DelaySetGameMode(Handle timer)
{
	ForceChangeLevel(GetMapCode(), "sm_map Command");
	g_hGameMode = null;
	return Plugin_Stop;
}

bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}

char[] GetMapCode()
{
	char sMapCode[32];
	GetCurrentMap(sMapCode, sizeof(sMapCode));
	return sMapCode;
}

char[] GetModeName()
{
	char sModeName[32];
	strcopy(sModeName, sizeof(sModeName), GetGameMode());
	for (int i = 0; i < sizeof(g_sModeCoop); i++)
		if(strcmp(g_sModeCoop[i][0], sModeName, false) == 0)
		{
			strcopy(sModeName, sizeof(sModeName), g_sModeCoop[i][1]);
			return sModeName;
		}
	for (int i = 0; i < sizeof(g_sModeVersus); i++)
		if(strcmp(g_sModeVersus[i][0], sModeName, false) == 0)
		{
			strcopy(sModeName, sizeof(sModeName), g_sModeVersus[i][1]);
			return sModeName;
		}
	for (int i = 0; i < sizeof(g_sModeSingle); i++)
		if(strcmp(g_sModeSingle[i][0], sModeName, false) == 0)
		{
			strcopy(sModeName, sizeof(sModeName), g_sModeSingle[i][1]);
			return sModeName;
		}
	return sModeName;
}

char[] GetGameMode()
{
	char g_sMode[32];
	GetConVarString(FindConVar("mp_gamemode"), g_sMode, sizeof(g_sMode));
	return g_sMode;
}
