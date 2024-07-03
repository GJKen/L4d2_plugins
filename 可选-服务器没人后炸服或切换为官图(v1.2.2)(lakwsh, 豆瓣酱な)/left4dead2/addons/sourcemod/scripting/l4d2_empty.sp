#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#include <dhooks>
#include <left4dhooks>

#define PLUGIN_VERSION	"1.2.2"
#define CVAR_FLAGS		FCVAR_NOTIFY
int g_iCountdown;
Handle g_hPlayerTimer;

char chatFile[128], g_sEmptyCode[128], g_sEmptyMode[128];
ConVar g_hGamemode, g_hEmptyCode, g_hEmptyMode;
int    g_iEmptyLog, g_iEmptySwitch, g_iEmptyCrash, g_iEmptyType, g_iEmptyCommand;
ConVar g_hEmptyLog, g_hEmptySwitch, g_hEmptyCrash, g_hEmptyType, g_hEmptyCommand;

TopMenu g_hTopMenu_Other;
TopMenuObject g_hOther = INVALID_TOPMENUOBJECT;

public Plugin myinfo = {
	name = "[L4D2] Empty",
	author = "lakwsh, 豆瓣酱な",
	version = PLUGIN_VERSION,
	url = "https://github.com/lakwsh"
}

public void OnPluginStart()
{
	LoadGameCFG();

	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);

	RegConsoleCmd("sm_bom", Command_BomServer, "手动爆炸服务端.");

	g_hGamemode 	= FindConVar("mp_gamemode");
	g_hEmptyLog 	= CreateConVar("l4d2_empty_Log",	"1", "服务器无人后记录日志内容? 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hEmptySwitch 	= CreateConVar("l4d2_empty_Switch",	"1", "服务器无人后执行什么功能? 0=禁用, 1=炸服, 2=切换为指定地图.", CVAR_FLAGS);
	g_hEmptyCode 	= CreateConVar("l4d2_empty_code",	"c2m1_highway", "服务器无人后设置什么地图(填入建图代码).", CVAR_FLAGS);
	g_hEmptyMode 	= CreateConVar("l4d2_empty_mode",	"coop", "服务器无人后设置什么模式(填入模式代码.", CVAR_FLAGS);
	g_hEmptyCrash 	= CreateConVar("l4d2_empty_crash",	"1", "允许什么系统的服务器崩溃? 1=linux, 2=windows, 3=两者.", CVAR_FLAGS);
	g_hEmptyType 	= CreateConVar("l4d2_empty_type",	"1", "允许什么类型的服务器崩溃? 1=专用服务器, 2=本地服务器, 3=两者.", CVAR_FLAGS);
	g_hEmptyCommand = CreateConVar("l4d2_empty_Command","10", "设置玩家使用!Bom指令手动炸服的倒计时时间/秒. 0=禁用.", CVAR_FLAGS);
	
	g_hEmptyLog.AddChangeHook(EmptyConVarChanged);
	g_hEmptySwitch.AddChangeHook(EmptyConVarChanged);
	g_hEmptyCode.AddChangeHook(EmptyConVarChanged);
	g_hEmptyMode.AddChangeHook(EmptyConVarChanged);
	g_hEmptyCrash.AddChangeHook(EmptyConVarChanged);
	g_hEmptyType.AddChangeHook(EmptyConVarChanged);
	g_hEmptyCommand.AddChangeHook(EmptyConVarChanged);

	AutoExecConfig(true, "l4d2_empty");
}

public void EmptyConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetEmptyCvars();
}

public void OnConfigsExecuted()
{
	GetEmptyCvars();
}

void GetEmptyCvars()
{
	g_iEmptyLog = g_hEmptyLog.IntValue;
	g_iEmptySwitch = g_hEmptySwitch.IntValue;
	g_iEmptyCrash = g_hEmptyCrash.IntValue;
	g_iEmptyType = g_hEmptyType.IntValue;
	g_iEmptyCommand = g_hEmptyCommand.IntValue;
	g_hEmptyCode.GetString(g_sEmptyCode, sizeof(g_sEmptyCode));
	g_hEmptyMode.GetString(g_sEmptyMode, sizeof(g_sEmptyMode));
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		g_hTopMenu_Other = null;
}
 
public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == g_hTopMenu_Other)
		return;
	
	g_hTopMenu_Other = topmenu;
	
	TopMenuObject objMenu_Other = FindTopMenuCategory(g_hTopMenu_Other, "OtherFeatures");
	if (objMenu_Other == INVALID_TOPMENUOBJECT)
		objMenu_Other = AddToTopMenu(g_hTopMenu_Other, "OtherFeatures", TopMenuObject_Category, AdminMenuHandler_Other, INVALID_TOPMENUOBJECT);
	
	g_hOther = AddToTopMenu(g_hTopMenu_Other,"sm_bom",TopMenuObject_Item,InfectedMenuHandler_Other,objMenu_Other,"sm_bom",ADMFLAG_ROOT);
}

public void AdminMenuHandler_Other(Handle topmenu_Other, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength_Other)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength_Other, "选择功能:", param);
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength_Other, "其它功能", param);
	}
}

public void InfectedMenuHandler_Other(Handle topmenu_Other, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength_Other)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == g_hOther)
			Format(buffer, maxlength_Other, "执行炸服", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == g_hOther)
			IsFriedSuitMenu(param, true);
	}
}

public Action Command_BomServer(int client, int args)
{
	if(bCheckClientAccess(client))
		IsFriedSuitMenu(client, false);
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

void IsFriedSuitMenu(int client, bool bButton = false)
{
	if(g_iEmptyCommand > 0)
	{
		char line[32], sButton[32];
		IntToString(bButton, sButton, sizeof(sButton));
		Menu menu = new Menu(Menu_HandlerFriedSuitMenu);
		Format(line, sizeof(line), "%s炸服?", g_hPlayerTimer == null ? "确认" : "取消");
		SetMenuTitle(menu, "%s", line);
		menu.AddItem(sButton, "确认");
		menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
		menu.ExitBackButton = bButton;//显示数字8返回上一层.
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		if (bButton == true && g_hTopMenu_Other != null)
			g_hTopMenu_Other.Display(client, TopMenuPosition_LastCategory);
		PrintToChat(client, "\x04[提示]\x05服主未开启手动炸服指令.");
	}
}

int Menu_HandlerFriedSuitMenu(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(itemNum, sItem, sizeof(sItem));
			//if (g_hTopMenu_Other != null)
				//g_hTopMenu_Other.Display(client, TopMenuPosition_LastCategory);
			if(g_hPlayerTimer == null)
			{
				IsCreateTimer(client);
				PrintHintTextToAll("已开启炸服倒计时.");//屏幕中下提示.
			}
			else
			{
				delete g_hPlayerTimer;
				PrintHintTextToAll("已关闭炸服倒计时.");//屏幕中下提示.
			}
			bool bButton = view_as<bool>(StringToInt(sItem));
			IsFriedSuitMenu(client, bButton);
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack && g_hTopMenu_Other != null)
				g_hTopMenu_Other.Display(client, TopMenuPosition_LastCategory);
		}
	}
	return 0;
}

void IsCreateTimer(int client)
{
	DataPack hPack;
	g_iCountdown = g_iEmptyCommand;
	g_hPlayerTimer = CreateDataTimer(1.0, DataTimerCallback, hPack, TIMER_REPEAT);
	hPack.WriteString(WriteFriedSuitWhys(client));
}

public Action DataTimerCallback(Handle Timer, DataPack hPack)
{
	hPack.Reset();
	char sWhys[64];
	hPack.ReadString(sWhys, sizeof(sWhys)); //读取打包的内容，"ReadString"为字符串变量参数读取
	
	if(g_iCountdown <= 0)
	{
		PrintHintTextToAll("服务器已被爆破!");//屏幕中下提示.
		IsDelayExecute(sWhys);
		g_hPlayerTimer = null;
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("服务器将在 %d 秒后被爆破!", g_iCountdown);//屏幕中下提示.
		g_iCountdown -= 1;
	}
	return Plugin_Continue;
}

void IsDelayExecute(char[] sWhys)
{
	DataPack hPack = new DataPack();
	RequestFrame(IsNextFrameFriedSuit, hPack);
	hPack.WriteString(sWhys);
}

void IsNextFrameFriedSuit(DataPack hPack)
{
	hPack.Reset();
	char sWhys[64];
	hPack.ReadString(sWhys, sizeof(sWhys)); //读取打包的内容，"ReadString"为字符串变量参数读取
	IsLoggingAndExecutionCrashes(L4D_GetServerOS(), sWhys);//记录日志和执行崩溃服务器.
	delete hPack;
}

char[] WriteFriedSuitWhys(int client)
{
	char sWhys[64], sName[32], sSteamId[32];
	GetClientName(client, sName, sizeof(sName));
	GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId));
	FormatEx(sWhys, sizeof(sWhys), "(%s)(%s)手动执行炸服", sName, sSteamId);
	return sWhys;
}

void LoadGameCFG()
{
	GameData hGameData = new GameData("l4d2_empty");
	if(!hGameData) 
		SetFailState("Failed to load 'l4d2_empty.txt' gamedata.");
	DHookSetup hDetour = DHookCreateFromConf(hGameData, "HibernationUpdate");
	CloseHandle(hGameData);
	if(!hDetour || !DHookEnableDetour(hDetour, true, OnHibernationUpdate)) 
		SetFailState("Failed to hook HibernationUpdate");
}

public MRESReturn OnHibernationUpdate(DHookParam hParams)
{
	bool hibernating = DHookGetParam(hParams, 1);

	if(!hibernating || !g_iEmptySwitch) 
		return MRES_Ignored;
		
	switch (g_iEmptySwitch)
	{
		case 1:
		{
			IsDetermineSystemType(L4D_GetServerOS(), "服务器没人了");//判断系统类型:0=windows,1=linux.
		}
		case 2:
		{
			g_hGamemode.SetString(g_sEmptyMode);
			ForceChangeLevel(g_sEmptyCode, "自动更换为指定的地图.");
		}
	}
	return MRES_Handled;
}

//判断系统类型.
void IsDetermineSystemType(int iType, char[] sWhys)
{
	switch (iType)
	{
		case 0:
		{
			if(g_iEmptyCrash == 2 || g_iEmptyCrash == 3)
				IsDetermineTheServerType(iType, sWhys);//判断服务器类型.
		}
		case 1:
		{
			if(g_iEmptyCrash == 1 || g_iEmptyCrash == 3)
				IsDetermineTheServerType(iType, sWhys);//判断服务器类型.
		}
	}
}

//判断服务器类型.
void IsDetermineTheServerType(int iType, char[] sWhys)
{
	if(IsDedicatedServer())//判断服务器类型:true=专用服务器,false=本地服务器.
	{
		if(g_iEmptyType == 1 || g_iEmptyType == 3)
			IsLoggingAndExecutionCrashes(iType, sWhys);//记录日志和执行崩溃服务器.
	}
	else
	{
		if(g_iEmptyType == 2 || g_iEmptyType == 3)
			IsLoggingAndExecutionCrashes(iType, sWhys);//记录日志和执行崩溃服务器.
	}
}
	
//记录日志和执行崩溃服务器.
void IsLoggingAndExecutionCrashes(int iType, char[] sWhys)
{
	UnloadAccelerator();//卸载崩溃记录扩展.
	IsRecordLogContent(iType, sWhys);//写入日志内容到文件.
	IsExecuteCrashServerCode();//执行崩溃服务端代码.
}

//卸载崩溃记录扩展.
void UnloadAccelerator()
{
	int Id = GetAcceleratorId();
	if (Id != -1)
	{
		ServerCommand("sm exts unload %i 0", Id);
		ServerExecute();//立即执行.
	}
}

//by sorallll
int GetAcceleratorId()
{
	char sBuffer[512];
	ServerCommandEx(sBuffer, sizeof(sBuffer), "sm exts list");
	int index = SplitString(sBuffer, "] Accelerator (", sBuffer, sizeof(sBuffer));
	if(index == -1)
		return -1;

	for(int i = strlen(sBuffer); i >= 0; i--)
	{
		if(sBuffer[i] == '[')
			return StringToInt(sBuffer[i + 1]);
	}
	return -1;
}

//写入日志内容到文件.
void IsRecordLogContent(int iType, char[] sWhys)
{
	//记录日志.
	if (g_iEmptyLog == 1)
	{
		char Msg[256], Time[32];
		IsCreateLogFile();//初始化日志文件,如果没有就创建.
		FormatTime(Time, sizeof(Time), "%Y-%m-%d %H:%M:%S", -1);
		Format(Msg, sizeof(Msg), "时间:%s.\n系统类型:%s.\n服务器类型:%s.\n炸服原因:%s.", Time, iType == 0 ? "windows" : iType == 1 ? "linux" : "其它", IsDedicatedServer() ? "专用" : "本地", sWhys);

		IsSaveMessage("--=============================================================--");
		IsSaveMessage(Msg);
		IsSaveMessage("--=============================================================--");
	}
}

//创建日志文件.
void IsCreateLogFile()
{
	char Date[32], logFile[128];
	FormatTime(Date, sizeof(Date), "%y%m%d", -1);
	Format(logFile, sizeof(logFile), "/logs/Empty%s.log", Date);
	BuildPath(Path_SM, chatFile, PLATFORM_MAX_PATH, logFile);
}

//把日志内容写入文本里.
void IsSaveMessage(const char[] Message)
{
	File fileHandle = OpenFile(chatFile, "a");  /* Append */
	fileHandle.WriteLine(Message);
	delete fileHandle;
}

//执行崩溃服务端代码.
void IsExecuteCrashServerCode()
{
	SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
	ServerCommand("crash");
	SetCommandFlags("sv_crash", GetCommandFlags("sv_crash") &~ FCVAR_CHEAT);
	ServerCommand("sv_crash");
}
