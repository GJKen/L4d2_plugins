#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#include <sdktools>
#define CVAR_FLAGS		FCVAR_NOTIFY
#define PLUGIN_VERSION	"1.2.7"

#define DefaultPlayers	"8"	//设置创建配置文件时写入的默认人数.

char g_sMaxPlayers[32], g_skvPath[PLATFORM_MAX_PATH];
int g_iDataWriteFile, g_iMaxPlayers;

TopMenu hTopMenu;
TopMenuObject hAddToTopMenu = INVALID_TOPMENUOBJECT;
ConVar g_hMaxPlayers, g_hDataWriteFile;

public Plugin myinfo = 
{
	name 			= "l4d2_sv_maxplayers",
	author 			= "豆瓣酱な",
	description 	= "设置服务器最大人数.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public void OnPluginStart()
{
	g_hMaxPlayers = FindConVar("sv_maxplayers");
	RegConsoleCmd("sm_sset", Command_sset, "更改服务器人数.");
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
	BuildPath(Path_SM, g_skvPath, sizeof(g_skvPath), "configs/l4d2_sv_maxplayers.cfg");
	IsReadFileValues(DefaultPlayers, true);
	g_hDataWriteFile = CreateConVar("l4d2_data_write_file", "1", "设置人数文件位置:\n*/addons/sourcemod/configs/l4d2_sv_maxplayers.cfg里修改最大人数.\n管理员指令更改人数后写入到文件. 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hDataWriteFile.AddChangeHook(ConVarChanged);
	AutoExecConfig(true, "l4d2_sv_maxplayers");//生成指定文件名的CFG.
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetConVarValue();
}

//每次加载地图都会执行(比函数 OnConfigsExecuted 早一点执行).
public void OnMapStart()
{
	GetConVarValue();
}
//获取ConVar的值.
void GetConVarValue()
{
	g_iDataWriteFile = g_hDataWriteFile.IntValue;
}
//每次加载地图都会执行(比函数 OnMapStart 晚一点执行).
public void OnConfigsExecuted()
{
	IsReadFileValues(DefaultPlayers, false);
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
	
	hAddToTopMenu= AddToTopMenu(hTopMenu,"sm_sset",TopMenuObject_Item,InfectedMenuHandler,objDifficultyMenu,"sm_sset",ADMFLAG_ROOT);
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
			Format(buffer, maxlength, "设置人数", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hAddToTopMenu)
			IsConVarValue(param, 0, true);
	}
}

void IsReadFileValues(char[] sDefaultPlayers, bool bDefaultPlayers)
{
	KeyValues kv = new KeyValues("maxplayers");
	if (!FileExists(g_skvPath))
	{
		File file = OpenFile(g_skvPath, "w");//读取指定文件.
		if (!file)//读取文件失败.
			LogError("无法读取文件: \"%s\"", g_skvPath);//显示错误信息.
		kv.SetString("设置最大人数. 0=禁用.", sDefaultPlayers);//写入指定的内容.
		kv.Rewind();//返回上一层.
		kv.ExportToFile(g_skvPath);//把数据写入到文件.
		delete file;//删除句柄.
	}
	else if (kv.ImportFromFile(g_skvPath)) //文件存在就导入kv数据,false=文件存在但是读取失败.
	{
		// 获取Kv文本内信息写入变量中.
		kv.GetString("设置最大人数. 0=禁用.", g_sMaxPlayers, sizeof(g_sMaxPlayers), GetMaxPlayers());//获取文件里指定的内容.
		int iMaxplayers = StringToInt(g_sMaxPlayers);//把字符串格式化为整形数字.

		if (g_hMaxPlayers != null)//设置人数ConVar有效.
		{
			if(g_iDataWriteFile != 0 || bDefaultPlayers == true)
				g_iMaxPlayers = iMaxplayers;

			if (g_iMaxPlayers > MaxClients)//设置的人数大于最大人数时执行.
				g_iMaxPlayers = MaxClients;//重新赋值最大人数.
			
			SetMaxPlayers(g_iMaxPlayers);//设置服务器最大人数.
		}
		else
			LogError("设置人数ConVar无效:\"sv_maxplayers\".");//显示错误信息.
	}
	delete kv;//删除句柄.
}

public Action Command_sset(int client, int args)
{
	if(bCheckClientAccess(client))
		if (g_hMaxPlayers != null)//设置人数ConVar有效.
			IsConVarValue(client, 0, false);
		else
			PrintToChat(client, "\x04[提示]\x05设置人数ConVar无效,请确认多人破解扩展已安装或已加载.");
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

void IsConVarValue(int client, int index, bool bButton = false)
{
	if (g_hMaxPlayers != null)//设置人数ConVar有效.
		DisplaySLMenu(client, index, bButton);
	else
		PrintToChat(client, "\x04[提示]\x05设置人数ConVar无效,请确认多人破解扩展已安装或已加载.");
}

void DisplaySLMenu(int client, int index, bool bButton = false)
{
	char sLine[32], sInfo[32], sNumber[32];
	Menu menu = new Menu(SLMenuHandler);
	menu.SetTitle("设置人数:");
	
	int i = 1;
	int iNumber = !IsDedicatedServer() ? 8 : MaxClients;
	IntToString(iNumber, sNumber, sizeof(sNumber));
	menu.AddItem("-1", "默认");
	while (i <= iNumber)
	{
		IntToString(i, sLine, sizeof(sLine));
		int iMax = strlen(sNumber) - strlen(sLine);
		FormatEx(sInfo, sizeof(sInfo), "%s%s人", IsWritesData(iMax, "  "), sLine);
		menu.AddItem(sLine, sInfo);
		i++;
	}
	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = bButton;//菜单首页显示数字8返回上一页选项.
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int SLMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Select:
		{
			char sData[32], sInfo[32];
			GetMenuItem(menu, itemNum, sData, sizeof(sData), _, sInfo, sizeof(sInfo));
			int iMaxplayers = StringToInt(sData);
			g_iMaxPlayers = iMaxplayers;
			if (g_hMaxPlayers != null)//设置人数ConVar有效.
			{
				TrimString(sInfo);
				SetMaxPlayers(g_iMaxPlayers);//设置服务器最大人数.
				PrintToChat(client, "\x04[提示]\x05更改最大人数为\x04:\x03%s.", sInfo);
			}
			else
				PrintToChat(client, "\x04[提示]\x05设置人数ConVar无效,请确认多人破解扩展已安装或已加载.");

			IsCreateData(sData);//把新值写入到文件.
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack && hTopMenu != null)
				hTopMenu.Display(client, TopMenuPosition_LastCategory);
		}
	}
	return 0;
}
//填入对应数量的内容.
stock char[] IsWritesData(int iNumber, char[] sValue)
{
	char sInfo[128];
	if(iNumber > 0)
	{
		int iLength = strlen(sValue) + 1;
		char[][] sData = new char[iNumber][iLength];//动态数组.
		for (int i = 0; i < iNumber; i++)
			strcopy(sData[i], iLength, sValue);
		ImplodeStrings(sData, iNumber, "", sInfo, sizeof(sInfo));//打包字符串.
	}
	return sInfo;
}
//设置指定的最大人数.
void SetMaxPlayers(int iMaxplayers)
{
	if (iMaxplayers == 0)
		LogError("未开启设置服务器最大人数功能.");//显示错误信息.
	else
	{
		SetConVarInt(FindConVar("sv_maxplayers"), iMaxplayers, false, false);//设置服务器最大人数.
		SetConVarInt(FindConVar("sv_visiblemaxplayers"), iMaxplayers, false, false);//设置服务器显示的最大人数(这个值不影响实际人数,该值为-1时服务器没人加入前会显示为0-4).
	}
}
//打包指定的数据.
void IsCreateData(char[] sData)
{
	DataPack hPack = new DataPack();//创建数据包.
	hPack.WriteString(sData);//写入数据(字符串).
	RequestFrame(IsDataWriteFile, hPack);//下一帧执行.
}
//把数据写入文件.
void IsDataWriteFile(DataPack hPack)
{
	hPack.Reset();//重置数据包位置.
	char sMaxPlayers[32];
	hPack.ReadString(sMaxPlayers, sizeof(sMaxPlayers));//获取数据包里的字符串内容.

	KeyValues kv = new KeyValues("maxplayers");
	if (!FileExists(g_skvPath))
	{
		kv.SetString("设置最大人数. 0=禁用.", g_iDataWriteFile != 0 ? sMaxPlayers : DefaultPlayers);//写入指定的内容.
		kv.Rewind();//返回上一层.
		kv.ExportToFile(g_skvPath);//把数据写入到文件.
		//PrintToChatAll("文件不存在");
	}
	else
	{
		if(g_iDataWriteFile != 0)
		{
			File file = OpenFile(g_skvPath, "w");//读取指定文件.
			if (!file)//读取文件失败.
				LogError("无法读取文件: \"%s\"", g_skvPath);//显示错误信息.
			
			kv.SetString("设置最大人数. 0=禁用.", sMaxPlayers);//写入指定的内容.
			kv.Rewind();//返回上一层.
			kv.ExportToFile(g_skvPath);//把数据写入到文件.
		
			delete file;//删除句柄.
			//PrintToChatAll("文件已存在");
		}
	}
	delete kv;//删除句柄.
	delete hPack;//删除句柄.
}
//获取服务器最大人数.
char[] GetMaxPlayers()
{
	char sNumber[32];
	IntToString(g_hMaxPlayers == null ? 0 : g_hMaxPlayers.IntValue, sNumber, sizeof(sNumber));
	return sNumber;
}
