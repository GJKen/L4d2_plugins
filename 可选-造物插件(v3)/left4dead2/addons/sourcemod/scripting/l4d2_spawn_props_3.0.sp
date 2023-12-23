#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#pragma semicolon 2
#pragma newdecls required
#define DEBUG 0

#define GETVERSION "3.0"
#define ARRAY_SIZE 5000
#define MAX_PATHS 20

#define DESIRED_ADM_FLAGS ADMFLAG_UNBAN //Edit here the flags to fit your needs!

#define RouteType_Easy		0
#define	RouteType_Medium	1
#define RouteType_Hard		2

char FolderNames[][] = {
	"addons/stripper",
	"addons/stripper/maps",
	"addons/stripper/routing",
	"addons/stripper/plugin_cache"
};

TopMenu g_TopMenuHandle;

int g_iCategory[MAXPLAYERS+1]				= 0;
int g_iSubCategory[MAXPLAYERS+1]			= 0;
int g_iFileCategory[MAXPLAYERS+1]			= 0;
int g_iMoveCategory[MAXPLAYERS+1]			= 0;
int g_iLastObject[MAXPLAYERS+1]			= -1;
int g_iLastGrabbedObject[MAXPLAYERS+1]	= -1;

bool g_bSpawned[ARRAY_SIZE]				= false;
bool g_bGrabbed[ARRAY_SIZE]				= false;
bool g_bGrab[MAXPLAYERS+1]				= false;
bool g_bUnsolid[ARRAY_SIZE]				= false;
bool g_bLoaded							= false;

float g_vecEntityAngles[ARRAY_SIZE][3];
float g_vecLastEntityAngles[MAXPLAYERS+1][3];

char g_sPath[128];

// Global variables to hold menu position
int g_iRotateMenuPosition[MAXPLAYERS+1]	= 0;
int g_iVehiclesMenuPosition[MAXPLAYERS+1]	= 0;
int g_iFoliageMenuPosition[MAXPLAYERS+1]	= 0;
int g_iInteriorMenuPosition[MAXPLAYERS+1]	= 0;
int g_iExteriorMenuPosition[MAXPLAYERS+1]	= 0;
int g_iDecorMenuPosition[MAXPLAYERS+1]	= 0;
int g_iMiscMenuPosition[MAXPLAYERS+1]		= 0;

ConVar g_cvarPhysics;
ConVar g_cvarDynamic;
ConVar g_cvarStatic;
ConVar g_cvarVehicles;
ConVar g_cvarFoliage;
ConVar g_cvarInterior;
ConVar g_cvarExterior;
ConVar g_cvarDecorative;
ConVar g_cvarMisc;
ConVar g_cvarLog;
ConVar g_cvarAutoload;
ConVar g_cvarAutoloadType;

public Plugin myinfo = 
{
	name = "[L4D2] Objects Spawner",
	author = "honorcode23 & $atanic $pirit",
	description = "Let admins spawn any kind of objects",
	version = GETVERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=1186503"
}

public void OnPluginStart()
{
	//Left 4 dead 2 only
	char sGame[256];
	GetGameFolderName(sGame, sizeof(sGame));
	if (!StrEqual(sGame, "left4dead2", false))
	{
		SetFailState("[L4D2] Objects Spawner supports Left 4 dead 2 only!");
	}
	
	CreateConVar("l4d2_spawn_props_version", GETVERSION, "Version of the Plugin", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY); //Version
	g_cvarPhysics = CreateConVar("l4d2_spawn_props_physics", "1", "开启物理物体菜单", FCVAR_NOTIFY);
	g_cvarDynamic = CreateConVar("l4d2_spawn_props_dynamic", "1", "在菜单中启用动态（非实体）对象", FCVAR_NOTIFY);
	g_cvarStatic = CreateConVar("l4d2_spawn_props_static", "1", "在菜单中启用静态（实体）对象", FCVAR_NOTIFY);
	g_cvarVehicles = CreateConVar("l4d2_spawn_props_category_vehicles", "1", "启用车辆类别", FCVAR_NOTIFY);
	g_cvarFoliage = CreateConVar("l4d2_spawn_props_category_foliage", "1", "启用植物类别", FCVAR_NOTIFY);
	g_cvarInterior = CreateConVar("l4d2_spawn_props_category_interior", "1", "启用内景类别", FCVAR_NOTIFY);
	g_cvarExterior = CreateConVar("l4d2_spawn_props_category_exterior", "1", "启用外景类别", FCVAR_NOTIFY);
	g_cvarDecorative = CreateConVar("l4d2_spawn_props_category_decorative", "1", "启用装饰类别", FCVAR_NOTIFY);
	g_cvarMisc = CreateConVar("l4d2_spawn_props_category_misc", "1", "启用杂项类别", FCVAR_NOTIFY);
	g_cvarLog = CreateConVar("l4d2_spawn_props_log_actions", "1", "生成制造的物件日志?", FCVAR_NOTIFY);
	g_cvarAutoload = CreateConVar("l4d2_spawn_props_autoload", "1", "启用插件自动载入?", FCVAR_NOTIFY);
	g_cvarAutoloadType = CreateConVar("l4d2_spawn_props_autoload_different", "1", "队伍的路径该是相同或不同?", FCVAR_NOTIFY);
	
	RegAdminCmd("sm_spawnprop", CmdSpawnProp, DESIRED_ADM_FLAGS, "生成具有给定信息的对象");
	RegAdminCmd("sm_savemap", CmdSaveMap, DESIRED_ADM_FLAGS, "将所有生成的对象保存在剥离器文件中");
	RegAdminCmd("sm_grabprop", CmdGrab, DESIRED_ADM_FLAGS, "抓住最后一个物体来移动它");
	RegAdminCmd("sm_grablook", CmdGrabLook, DESIRED_ADM_FLAGS, "抓住正在寻找的物体并移动它");
	
	RegAdminCmd("sm_prop_rotate", CmdRotate, DESIRED_ADM_FLAGS, "以所需角度旋转最后生成的对象");
	RegAdminCmd("sm_prop_removelast", CmdRemoveLast, DESIRED_ADM_FLAGS, "删除最后生成的对象");
	RegAdminCmd("sm_prop_removelook", CmdRemoveLook, DESIRED_ADM_FLAGS, "删除正在寻找的对象");
	RegAdminCmd("sm_prop_removeall", CmdRemoveAll, DESIRED_ADM_FLAGS, "删除所有对象");
	RegAdminCmd("sm_prop_move", CmdMove, DESIRED_ADM_FLAGS, "以所需的移动类型移动对象");
	RegAdminCmd("sm_prop_setang", CmdSetAngles, DESIRED_ADM_FLAGS, "强制物体角度");
	RegAdminCmd("sm_prop_setpos", CmdSetPosition, DESIRED_ADM_FLAGS, "设置最后一个对象位置");
	
	RegAdminCmd("sm_debugprop", CmdDebugProp, ADMFLAG_ROOT, "DEBUG");
	
	
	AutoExecConfig(true, "l4d2_spawn_props_3.0");
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}
	
	//DEV
	RegAdminCmd("sm_spload", CmdLoad, DESIRED_ADM_FLAGS, "Load map");
	
	//Events
	HookEvent("survival_round_start", Event_SurvivalRoundStart);
	HookEvent("scavenge_round_start", Event_ScavengeRoundStart);
	HookEvent("round_start_post_nav", Event_RoundStart);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_end", Event_RoundEnd);
	
	//Create required folders
	BuildFileDirectories();
}

public Action CmdDebugProp(int client, int args)
{
	char name[256];
	int Object = g_iLastObject[client];
	if(Object > 0 && IsValidEntity(Object))
	{
		GetEntPropString(Object, Prop_Data, "m_iName", name, sizeof(name));
		PrintToChat(client, "支柱: %s", name);
	}
	return Plugin_Handled;
}

public void Event_SurvivalRoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if(g_cvarAutoload.BoolValue && !g_bLoaded)
	{
		g_bLoaded = true;
		SpawnObjects();
	}
}

public void Event_ScavengeRoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	LogSpawn("Scavenge Round Has Started");
	if(g_cvarAutoload.BoolValue && !g_bLoaded)
	{
		g_bLoaded = true;
		SpawnObjects();
	}
}
public void Event_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if(g_cvarAutoload.BoolValue && g_cvarAutoloadType.BoolValue)
	{
		GetRandomMapPath(g_sPath, sizeof(g_sPath));
	}
}

public void Event_PlayerSpawn(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if(g_cvarAutoload.BoolValue && !g_bLoaded)
	{
		g_bLoaded = true;
		SpawnObjects();
	}
}

public void Event_RoundEnd(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	g_bLoaded = false;
}

public void OnMapEnd()
{
	g_bLoaded = false;
}

public void OnMapStart()
{
	for(int i=MaxClients; i < ARRAY_SIZE; i++)
	{
		g_bSpawned[i] = false;
		g_bUnsolid[i] = false;
		g_vecEntityAngles[i][0] = 0.0;
		g_vecEntityAngles[i][1] = 0.0;
		g_vecEntityAngles[i][2] = 0.0;
	}
	if(g_cvarAutoload.BoolValue && !g_cvarAutoloadType.BoolValue)
	{
		GetRandomMapPath(g_sPath, sizeof(g_sPath));
	}
}

public Action CmdSpawnProp(int client, int args)
{
	if(args < 3)
	{
		PrintToChat(client, "[SM] 用法: sm_spawnprop <model> [static | dynamic | physics] [cursor | origin]");
		return Plugin_Handled;
	}
	char arg1[256];
	char arg2[256];
	char arg3[256];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	char model[256];
	strcopy(model, sizeof(model), arg1);
	if(!IsModelPrecached(model))
	{
		if(PrecacheModel(model) <= 0)
		{
			PrintToChat(client, "[SM] 生成所选模型时出现错误 [错误: 无效的模型]");
			return Plugin_Handled;
		}
	}
	if(StrContains(arg2, "static") >= 0)
	{
		float  VecOrigin[3];
		float VecAngles[3];
		int prop = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(prop, "model", model);
		DispatchKeyValue(prop, "targetname", "l4d2_spawn_props_prop");
		SetEntProp(prop, Prop_Send, "m_nSolidType", 6);
		if(StrEqual(arg3, "cursor"))
		{
			GetClientEyePosition(client, VecOrigin);
			GetClientEyeAngles(client, VecAngles);
			TR_TraceRayFilter(VecOrigin, VecAngles, MASK_OPAQUE, RayType_Infinite, TraceRayDontHitSelf, client);
			if(TR_DidHit(null))
			{
				TR_GetEndPosition(VecOrigin);
			}
			else
			{
				PrintToChat(client, "[SM] 坐标超出当前世界几何. 生成在当前站立位置");
			}
		}
		else if(StrEqual(arg3, "origin"))
		{
			GetClientEyePosition(client, VecOrigin);
			GetClientEyeAngles(client, VecAngles);
		}
		else
		{
			PrintToChat(client, "[SM] 指定生成方法无效. 用法: [cursor | origin]");
			return Plugin_Handled;
		}
		VecAngles[0] = 0.0;
		VecAngles[2] = 0.0;
		g_vecLastEntityAngles[client][0] = VecAngles[0];
		g_vecLastEntityAngles[client][1] = VecAngles[1];
		g_vecLastEntityAngles[client][2] = VecAngles[2];
		g_iLastObject[client] = prop;
		DispatchKeyValueVector(prop, "angles", VecAngles);
		DispatchSpawn(prop);
		TeleportEntity(prop, VecOrigin, NULL_VECTOR, NULL_VECTOR);
		g_bSpawned[prop] = true;
		g_vecEntityAngles[prop] = VecAngles;
		char name[256];
		GetClientName(client, name, sizeof(name));
		LogSpawn("%s spawned a static object with model <%s>", name, model);
	}
	else if(StrContains(arg2, "dynamic") >= 0)
	{
		float  VecOrigin[3];
		float VecAngles[3];
		int prop = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(prop, "model", model);
		DispatchKeyValue(prop, "targetname", "l4d2_spawn_props_prop");
		if(StrEqual(arg3, "cursor"))
		{
			GetClientEyePosition(client, VecOrigin);
			GetClientEyeAngles(client, VecAngles);
			TR_TraceRayFilter(VecOrigin, VecAngles, MASK_OPAQUE, RayType_Infinite, TraceRayDontHitSelf, client);
			if(TR_DidHit(null))
			{
				TR_GetEndPosition(VecOrigin);
			}
			else
			{
				PrintToChat(client, "[SM] 坐标超出当前世界几何. 生成在当前站立位置");
			}
		}
		else if(StrEqual(arg3, "origin"))
		{
			GetClientEyePosition(client, VecOrigin);
			GetClientEyeAngles(client, VecAngles);
		}
		else
		{
			PrintToChat(client, "[SM] 指定生成方法无效. 用法: [cursor | origin]");
			return Plugin_Handled;
		}
		VecAngles[0] = 0.0;
		VecAngles[2] = 0.0;
		g_vecLastEntityAngles[client][0] = VecAngles[0];
		g_vecLastEntityAngles[client][1] = VecAngles[1];
		g_vecLastEntityAngles[client][2] = VecAngles[2];
		g_iLastObject[client] = prop;
		DispatchKeyValueVector(prop, "angles", VecAngles);
		DispatchSpawn(prop);
		TeleportEntity(prop, VecOrigin, NULL_VECTOR, NULL_VECTOR);
		g_bSpawned[prop] = true;
		g_vecEntityAngles[prop] = VecAngles;
		g_bUnsolid[prop] = true;
		char name[256];
		GetClientName(client, name, sizeof(name));
		LogSpawn("%s spawned a dynamic object with model <%s>", name, model);
	}
	else if(StrContains(arg2, "physics") >= 0)
	{
		float  VecOrigin[3];
		float VecAngles[3];
		int prop = CreateEntityByName("prop_physics_override");
		DispatchKeyValue(prop, "model", model);
		DispatchKeyValue(prop, "targetname", "l4d2_spawn_props_prop");
		if(StrEqual(arg3, "cursor"))
		{
			GetClientEyePosition(client, VecOrigin);
			GetClientEyeAngles(client, VecAngles);
			TR_TraceRayFilter(VecOrigin, VecAngles, MASK_OPAQUE, RayType_Infinite, TraceRayDontHitSelf, client);
			if(TR_DidHit(null))
			{
				TR_GetEndPosition(VecOrigin);
			}
			else
			{
				PrintToChat(client, "[SM] 坐标超出当前世界几何. 生成在当前站立位置");
			}
		}
		else if(StrEqual(arg3, "origin"))
		{
			GetClientEyePosition(client, VecOrigin);
			GetClientEyeAngles(client, VecAngles);
		}
		else
		{
			PrintToChat(client, "[SM] 指定生成方法无效. 用法: : [cursor | origin]");
			return Plugin_Handled;
		}
		VecAngles[0] = 0.0;
		VecAngles[2] = 0.0;
		g_vecLastEntityAngles[client][0] = VecAngles[0];
		g_vecLastEntityAngles[client][1] = VecAngles[1];
		g_vecLastEntityAngles[client][2] = VecAngles[2];
		g_iLastObject[client] = prop;
		DispatchKeyValueVector(prop, "angles", VecAngles);
		DispatchSpawn(prop);
		TeleportEntity(prop, VecOrigin, NULL_VECTOR, NULL_VECTOR);
		g_bSpawned[prop] = true;
		g_vecEntityAngles[prop] = VecAngles;
		char name[256];
		GetClientName(client, name, sizeof(name));
		LogSpawn("%s spawned a physics object with model <%s>", name, model);
	}
	else
	{
		PrintToChat(client, "[SM] 无效的渲染模式. 用法: [static | dynamic | physics]");
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

//Admin Menu ready
public void OnAdminMenuReady(Handle topmenu)
{
	if (topmenu == g_TopMenuHandle)
	{
		return;
	}
	g_TopMenuHandle = view_as<TopMenu>(topmenu);
	TopMenuObject menu_category_prop = g_TopMenuHandle.AddCategory("Object Spawner", Category_Handler);
	
	if (menu_category_prop != INVALID_TOPMENUOBJECT)
    {
		g_TopMenuHandle.AddItem("sm_spdelete", AdminMenu_Delete, menu_category_prop, "sm_spdelete", DESIRED_ADM_FLAGS); //Delete
		g_TopMenuHandle.AddItem("sm_spedit", AdminMenu_Edit, menu_category_prop, "sm_spedit", DESIRED_ADM_FLAGS); //Edit
		g_TopMenuHandle.AddItem("sm_spspawn", AdminMenu_Spawn, menu_category_prop, "sm_spspawn", DESIRED_ADM_FLAGS); //Spawn
		g_TopMenuHandle.AddItem("sm_spsave", AdminMenu_Save, menu_category_prop, "sm_spsave", DESIRED_ADM_FLAGS); //Save
		g_TopMenuHandle.AddItem("sm_spload", AdminMenu_Load, menu_category_prop, "sm_spload", DESIRED_ADM_FLAGS); //Load
	}
}

//Admin Category Name
public int Category_Handler(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "选择一项功能:");
	}
	else if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "造物插件3.0");
	}
}
/*
////////////////////////////////////////////////////////////////////////////|
						D E L E T E        M E N U							|
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\|
*/

public void AdminMenu_Delete(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "删除物体");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		BuildDeleteMenu(param);
	}
}

Menu BuildDeleteMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Delete);
	menu.SetTitle("选择删除的范围");
	menu.AddItem("sm_spdeleteall", "删除所有物体");
	menu.AddItem("sm_spdeletelook", "删除准心所指的物体");
	menu.AddItem("sm_spdeletelast", "删除上一个物体");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

Menu BuildDeleteAllAskMenu(int client)
{
	Menu menu = new Menu(MenuHandler_DA_Ask);
	menu.SetTitle("你确定吗?");	
	menu.AddItem("sm_spyes", "是");
	menu.AddItem("sm_spno", "否");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_DA_Ask(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "sm_spyes"))
			{
				DeleteAllProps();
				PrintToChat(param1, "[SM] 成功删除所有生成的物体");
			}
			else
			{
				PrintToChat(param1, "[SM] 取消");
			}
			BuildDeleteMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_Delete(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "sm_spdeleteall"))
			{
				BuildDeleteAllAskMenu(param1);
				PrintToChat(param1, "[SM] 你确定要删除所有生成的物体?");
			}
			else if(StrEqual(menucmd, "sm_spdeletelook"))
			{
				DeleteLookingEntity(param1);
				BuildDeleteMenu(param1);
			}
			else if(StrEqual(menucmd, "sm_spdeletelast"))
			{
				DeleteLastProp(param1);
				BuildDeleteMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

/*
////////////////////////////////////////////////////////////////////////////|
						E D I T        M E N U							    |
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\|
*/

public void AdminMenu_Edit(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "编辑物体");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		BuildEditPropMenu(param);
	}
}

/*
////////////////////////////////////////////////////////////////////////////|
						S P A W N        M E N U							|
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\|
*/

public void AdminMenu_Spawn(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "生成物体");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		BuildSpawnMenu(param);
	}
}

Menu BuildSpawnMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Spawn);
	menu.SetTitle("选择生成的方式");
	
	if(g_cvarPhysics.BoolValue)
	{
		menu.AddItem("sm_spawnpc", "在光标处生成物理碰撞物体");
		menu.AddItem("sm_spawnpo", "在站着位置生成物理碰撞物体");
	}
	if(g_cvarDynamic.BoolValue)
	{
		menu.AddItem("sm_spawndc", "在光标处生成虚体物体");
		menu.AddItem("sm_spawndo", "在站着位置生成虚体物体");
	}
	if(g_cvarStatic.BoolValue)
	{
		menu.AddItem("sm_spawnsc", "在光标处生成实体物体");
		menu.AddItem("sm_spawnso", "在站着位置生成实体物体");
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Spawn(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "sm_spawnpc"))
			{
				BuildPhysicsCursorMenu(param1);
			}
			else if(StrEqual(menucmd, "sm_spawnpo"))
			{
				BuildPhysicsPositionMenu(param1);
			}
			else if(StrEqual(menucmd, "sm_spawndc"))
			{
				BuildDynamicCursorMenu(param1);
			}
			else if(StrEqual(menucmd, "sm_spawndo"))
			{
				BuildDynamicPositionMenu(param1);
			}
			else if(StrEqual(menucmd, "sm_spawnsc"))
			{
				BuildStaticCursorMenu(param1);
			}
			else if(StrEqual(menucmd, "sm_spawnso"))
			{
				BuildStaticPositionMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

/*
////////////////////////////////////////////////////////////////////////////|
						S A V E       M E N U							    |
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\|
*/

public void AdminMenu_Save(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "保存物体");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		BuildSaveMenu(param);
	}
}

Menu BuildSaveMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Save);
	menu.SetTitle("选择保存的方式");
	menu.AddItem("sm_spsavestripper", "保存在Stripper文件夹中");
	menu.AddItem("sm_spsaverouting", "保存在Routing文件夹中");
	menu.AddItem("sm_spsaveplugin", "保存在Spawn Objects文件夹中");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

Menu BuildRoutingMenu(int client)
{
	Menu menu = new Menu(MenuHandler_PathDiff);
	menu.SetTitle("选择路径难度");
	menu.AddItem("sm_speasy", "简单路径");
	menu.AddItem("sm_spmedium", "中等路径");
	menu.AddItem("sm_sphard", "困难路径");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_PathDiff(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "sm_speasy"))
			{
				SaveRoutingPath(param1, RouteType_Easy);
			}
			else if(StrEqual(menucmd, "sm_spmedium"))
			{
				SaveRoutingPath(param1, RouteType_Medium);
			}
			else if(StrEqual(menucmd, "sm_sphard"))
			{
				SaveRoutingPath(param1, RouteType_Hard);
			}
			BuildSaveMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_Save(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "sm_spsavestripper"))
			{
				SaveMapStripper(param1);
				BuildSaveMenu(param1);
			}
			else if(StrEqual(menucmd, "sm_spsaverouting"))
			{
				BuildRoutingMenu(param1);
			}
			else if(StrEqual(menucmd, "sm_spsaveplugin"))
			{
				SavePluginProps(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

/*
////////////////////////////////////////////////////////////////////////////|
						L O A D       M E N U							    |
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\|
*/

public void AdminMenu_Load(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "加载物体");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		BuildLoadAskMenu(param);
		PrintToChat(param, "[SM] 您确定要加载地图数据缓存吗?");
	}
}

Menu BuildLoadAskMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Load_Ask);
	menu.SetTitle("你确定吗?");
	menu.AddItem("sm_spyes", "是");
	menu.AddItem("sm_spno", "否");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

Menu BuildLoadPropsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Load_Props);
	menu.SetTitle("请选择一个地图编号");
	char buffer[16];
	char buffer2[16];
	for(int i=1; i <= MAX_PATHS; i++)
	{
		Format(buffer, sizeof(buffer), "map%i", i);
		Format(buffer2, sizeof(buffer2), "地图 %i", i);
		menu.AddItem(buffer, buffer2);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Load_Props(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			ReplaceString(menucmd, sizeof(menucmd), "map", "", false);
			int number = StringToInt(menucmd);
			LoadPluginProps(param1, number);
			g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_Load_Ask(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "sm_spyes"))
			{
				BuildLoadPropsMenu(param1);
			}
			else
			{
				PrintToChat(param1, "[SM] 取消");
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

/*
////////////////////////////////////////////////////////////////////////////|
						Build Secondary Menus							    |
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\|
*/
Menu BuildPhysicsCursorMenu(int client)
{
	Menu menu = new Menu(MenuHandler_PhysicsCursor);
	CheckSecondaryMenuCategories(menu, client);
}

Menu BuildPhysicsPositionMenu(int client)
{
	Menu menu = new Menu(MenuHandler_PhysicsPosition);
	CheckSecondaryMenuCategories(menu, client);
}

Menu BuildDynamicCursorMenu(int client)
{
	Menu menu = new Menu(MenuHandler_DynamicCursor);
	CheckSecondaryMenuCategories(menu, client);
}

Menu BuildDynamicPositionMenu(int client)
{
	Menu menu = new Menu(MenuHandler_DynamicPosition);
	CheckSecondaryMenuCategories(menu, client);
}
Menu BuildStaticCursorMenu(int client)
{
	Menu menu = new Menu(MenuHandler_StaticCursor);
	CheckSecondaryMenuCategories(menu, client);
}
Menu BuildStaticPositionMenu(int client)
{
	Menu menu = new Menu(MenuHandler_StaticPosition);
	CheckSecondaryMenuCategories(menu, client);
}

Menu CheckSecondaryMenuCategories(Menu menu, int client)
{	
	if(g_cvarVehicles.BoolValue)
	{
		menu.AddItem("vehicles", "车辆类型");
	}
	if(g_cvarFoliage.BoolValue)
	{
		menu.AddItem("foliage", "植物类型");
	}
	if(g_cvarInterior.BoolValue)
	{
		menu.AddItem("interior", "内景类型");
	}
	if(g_cvarExterior.BoolValue)
	{
		menu.AddItem("exterior", "外景类型");
	}
	if(g_cvarDecorative.BoolValue)
	{
		menu.AddItem("decorative", "装饰物");
	}
	if(g_cvarMisc.BoolValue)
	{
		menu.AddItem("misc", "杂项");
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);	
}

Menu BuildEditPropMenu(int client)
{
	Menu menu = new Menu(MenuHandler_EditProp);
	menu.SetTitle("选择一个方式:");
	menu.AddItem("rotate", "旋转");
	menu.AddItem("move", "移动");
	menu.AddItem("grab", "抓取");
	menu.AddItem("release", "释放");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_PhysicsCursor(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			g_iCategory[param1] = 1;
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "vehicles"))
			{
				DisplayVehiclesMenu(param1);
			}
			else if(StrEqual(menucmd, "foliage"))
			{
				DisplayFoliageMenu(param1);
			}
			else if(StrEqual(menucmd, "interior"))
			{
				DisplayInteriorMenu(param1);
			}
			else if(StrEqual(menucmd, "exterior"))
			{
				DisplayExteriorMenu(param1);
			}
			else if(StrEqual(menucmd, "decorative"))
			{
				DisplayDecorativeMenu(param1);
			}
			else if(StrEqual(menucmd, "misc"))
			{
				DisplayMiscMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_PhysicsPosition(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			g_iCategory[param1] = 2;
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "vehicles"))
			{
				DisplayVehiclesMenu(param1);
			}
			else if(StrEqual(menucmd, "foliage"))
			{
				DisplayFoliageMenu(param1);
			}
			else if(StrEqual(menucmd, "interior"))
			{
				DisplayInteriorMenu(param1);
			}
			else if(StrEqual(menucmd, "exterior"))
			{
				DisplayExteriorMenu(param1);
			}
			else if(StrEqual(menucmd, "decorative"))
			{
				DisplayDecorativeMenu(param1);
			}
			else if(StrEqual(menucmd, "misc"))
			{
				DisplayMiscMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_DynamicCursor(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			g_iCategory[param1] = 3;
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "vehicles"))
			{
				DisplayVehiclesMenu(param1);
			}
			else if(StrEqual(menucmd, "foliage"))
			{
				DisplayFoliageMenu(param1);
			}
			else if(StrEqual(menucmd, "interior"))
			{
				DisplayInteriorMenu(param1);
			}
			else if(StrEqual(menucmd, "exterior"))
			{
				DisplayExteriorMenu(param1);
			}
			else if(StrEqual(menucmd, "decorative"))
			{
				DisplayDecorativeMenu(param1);
			}
			else if(StrEqual(menucmd, "misc"))
			{
				DisplayMiscMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_DynamicPosition(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			g_iCategory[param1] = 4;
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "vehicles"))
			{
				DisplayVehiclesMenu(param1);
			}
			else if(StrEqual(menucmd, "foliage"))
			{
				DisplayFoliageMenu(param1);
			}
			else if(StrEqual(menucmd, "interior"))
			{
				DisplayInteriorMenu(param1);
			}
			else if(StrEqual(menucmd, "exterior"))
			{
				DisplayExteriorMenu(param1);
			}
			else if(StrEqual(menucmd, "decorative"))
			{
				DisplayDecorativeMenu(param1);
			}
			else if(StrEqual(menucmd, "misc"))
			{
				DisplayMiscMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_StaticCursor(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			g_iCategory[param1] = 5;
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "vehicles"))
			{
				DisplayVehiclesMenu(param1);
			}
			else if(StrEqual(menucmd, "foliage"))
			{
				DisplayFoliageMenu(param1);
			}
			else if(StrEqual(menucmd, "interior"))
			{
				DisplayInteriorMenu(param1);
			}
			else if(StrEqual(menucmd, "exterior"))
			{
				DisplayExteriorMenu(param1);
			}
			else if(StrEqual(menucmd, "decorative"))
			{
				DisplayDecorativeMenu(param1);
			}
			else if(StrEqual(menucmd, "misc"))
			{
				DisplayMiscMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_StaticPosition(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			g_iCategory[param1] = 6;
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "vehicles"))
			{
				DisplayVehiclesMenu(param1);
			}
			else if(StrEqual(menucmd, "foliage"))
			{
				DisplayFoliageMenu(param1);
			}
			else if(StrEqual(menucmd, "interior"))
			{
				DisplayInteriorMenu(param1);
			}
			else if(StrEqual(menucmd, "exterior"))
			{
				DisplayExteriorMenu(param1);
			}
			else if(StrEqual(menucmd, "decorative"))
			{
				DisplayDecorativeMenu(param1);
			}
			else if(StrEqual(menucmd, "misc"))
			{
				DisplayMiscMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_EditProp(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "rotate"))
			{
				DisplayRotateMenu(param1);
			}
			else if(StrEqual(menucmd, "move"))
			{
				DisplayMoveMenu(param1);
			}
			else if(StrEqual(menucmd, "grab"))
			{
				GrabLookingObject(param1);
				BuildEditPropMenu(param1);
			}
			else if(StrEqual(menucmd, "release"))
			{
				ReleaseLookingObject(param1);
				BuildEditPropMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && g_TopMenuHandle != null)
			{
				g_TopMenuHandle.Display(param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

Menu DisplayVehiclesMenu(int client)
{
	g_iSubCategory[client] =  1;
	Menu menu = new Menu(MenuHandler_DoAction);
	SetFileCategory(menu, client);
	menu.SetTitle("车辆类型");
	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iVehiclesMenuPosition[client], MENU_TIME_FOREVER);
}

Menu DisplayFoliageMenu(int client)
{
	g_iSubCategory[client] =  2;
	Menu menu = new Menu(MenuHandler_DoAction);
	SetFileCategory(menu, client);
	menu.SetTitle("植物类型");
	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iFoliageMenuPosition[client], MENU_TIME_FOREVER);
}

Menu DisplayInteriorMenu(int client)
{
	g_iSubCategory[client] =  3;
	Menu menu = new Menu(MenuHandler_DoAction);
	SetFileCategory(menu, client);
	menu.SetTitle("内景类型");
	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iInteriorMenuPosition[client], MENU_TIME_FOREVER);
}

Menu DisplayExteriorMenu(int client)
{
	g_iSubCategory[client] =  4;
	Menu menu = new Menu(MenuHandler_DoAction);
	SetFileCategory(menu, client);
	menu.SetTitle("外景类型");
	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iExteriorMenuPosition[client], MENU_TIME_FOREVER);
}

Menu DisplayDecorativeMenu(int client)
{
	g_iSubCategory[client] =  5;
	Menu menu = new Menu(MenuHandler_DoAction);
	SetFileCategory(menu, client);
	menu.SetTitle("装饰物");
	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iDecorMenuPosition[client], MENU_TIME_FOREVER);
}

Menu DisplayMiscMenu(int client)
{
	g_iSubCategory[client] =  6;
	Menu menu = new Menu(MenuHandler_DoAction);
	SetFileCategory(menu, client);
	menu.SetTitle("杂项");
	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iMiscMenuPosition[client], MENU_TIME_FOREVER);
}

Menu SetFileCategory(Menu menu, int client)
{
	File file;
	char FileName[256];
	char ItemModel[256];
	char ItemTag[256];
	char buffer[256];
	BuildPath(Path_SM, FileName, sizeof(FileName), "data/l4d2_spawn_props_models.txt");
	int len;
	if(!FileExists(FileName))
	{
		SetFailState("无法找到文件l4d2_spawn_props_models.txt");
	}
	file = OpenFile(FileName, "r");
	if(file == null)
	{
		SetFailState("打开模型文件错误");
	}
	g_iFileCategory[client] = 0;
	while(file.ReadLine(buffer, sizeof(buffer)))
	{
		len = strlen(buffer);
		if (buffer[len-1] == 'n')
		{
			buffer[--len] = '0';
		}
		if(StrContains(buffer, "//Category Vehicles") >= 0)
		{
			g_iFileCategory[client] = 1;
			continue;
		}
		else if(StrContains(buffer, "//Category Foliage") >= 0)
		{
			g_iFileCategory[client] = 2;
			continue;
		}
		else if(StrContains(buffer, "//Category Interior") >= 0)
		{
			g_iFileCategory[client] = 3;
			continue;
		}
		else if(StrContains(buffer, "//Category Exterior") >= 0)
		{
			g_iFileCategory[client] = 4;
			continue;
		}
		else if(StrContains(buffer, "//Category Decorative") >= 0)
		{
			g_iFileCategory[client] = 5;
			continue;
		}
		else if(StrContains(buffer, "//Category Misc") >= 0)
		{
			g_iFileCategory[client] = 6;
			continue;
		}
		if(g_iFileCategory[client] != g_iSubCategory[client])
		{
			continue;
		}
		SplitString(buffer, " TAG-", ItemModel, sizeof(ItemModel));
	
		strcopy(ItemTag, sizeof(ItemTag), buffer);
		
		ReplaceString(ItemTag, sizeof(ItemTag), ItemModel, "", false);
		ReplaceString(ItemTag, sizeof(ItemTag), " TAG- ", "", false);
		menu.AddItem(ItemModel, ItemTag);
		
		if(IsEndOfFile(file))
		{
			break;
		}
	}
	CloseHandle(file);
}

Menu DisplayRotateMenu(int client)
{
	g_iMoveCategory[client] = 1;
	Menu menu = new Menu(MenuHandler_PropPosition);
	menu.AddItem("rotate1x", "X轴旋转1度");
	menu.AddItem("rotate10x", "X轴旋转10度");
	menu.AddItem("rotate15x", "X轴旋转15度");
	menu.AddItem("rotate45x", "X轴旋转45度");
	menu.AddItem("rotate90x", "X轴旋转90度");
	menu.AddItem("rotate180x", "X轴旋转180度");
	menu.AddItem("rotate1y", "Y轴旋转1度");
	menu.AddItem("rotate10y", "Y轴旋转10度");
	menu.AddItem("rotate15y", "Y轴旋转15度");
	menu.AddItem("rotate45y", "Y轴旋转45度");
	menu.AddItem("rotate90y", "Y轴旋转90度");
	menu.AddItem("rotate180y", "Y轴旋转180度");
	menu.AddItem("rotate1z", "Z轴旋转1度");
	menu.AddItem("rotate10z", "Z轴旋转10度");
	menu.AddItem("rotate15z", "Z轴旋转15度");
	menu.AddItem("rotate45z", "Z轴旋转45度");
	menu.AddItem("rotate90z", "Z轴旋转90度");
	menu.AddItem("rotate180z", "Z轴旋转180度");
	menu.SetTitle("旋转");
	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iRotateMenuPosition[client], MENU_TIME_FOREVER);
}

Menu DisplayMoveMenu(int client)
{
	g_iMoveCategory[client] = 2;
	Menu menu = new Menu(MenuHandler_PropPosition);
	menu.AddItem("moveup", "向上移动");
	menu.AddItem("movedown", "向下移动");
	menu.AddItem("moveright", "向右移动");
	menu.AddItem("moveleft", "向左移动");
	menu.AddItem("moveforward", "向前移动");
	menu.AddItem("movebackward", "向后移动");
	menu.SetTitle("移动");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_DoAction(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char model[256];
			GetMenuItem(menu, param2, model, sizeof(model));
			if(!IsModelPrecached(model))
			{
				PrecacheModel(model);
			}
			if(g_iCategory[param1] == 1)
			{
				float  VecOrigin[3];
				float VecAngles[3];
				int prop = CreateEntityByName("prop_physics_override");
				DispatchKeyValue(prop, "model", model);
				DispatchKeyValue(prop, "targetname", "l4d2_spawn_props_prop");
				DispatchSpawn(prop);
				GetClientEyePosition(param1, VecOrigin);
				GetClientEyeAngles(param1, VecAngles);
				
				TR_TraceRayFilter(VecOrigin, VecAngles, MASK_OPAQUE, RayType_Infinite, TraceRayDontHitSelf, param1);
				if(TR_DidHit(null))
				{
					TR_GetEndPosition(VecOrigin);
				}
				else
				{
					PrintToChat(param1, "[SM] 坐标超出当前世界几何. 生成在当前站立位置");
				}
				VecAngles[0] = 0.0;
				VecAngles[2] = 0.0;
				g_vecLastEntityAngles[param1] = VecAngles;
				g_iLastObject[param1] = prop;
				DispatchKeyValueVector(prop, "angles", VecAngles);
				DispatchSpawn(prop);
				g_bSpawned[prop] = true;
				g_vecEntityAngles[prop] = VecAngles;
				TeleportEntity(prop, VecOrigin, NULL_VECTOR, NULL_VECTOR);
				char name[256];
				GetClientName(param1, name, sizeof(name));
				LogSpawn("%s spawned a physics object with model <%s>", name, model);
			}
			else if(g_iCategory[param1] == 2)
			{
				float  VecOrigin[3];
				float VecAngles[3];
				int prop = CreateEntityByName("prop_physics_override");
				DispatchKeyValue(prop, "model", model);
				DispatchKeyValue(prop, "targetname", "l4d2_spawn_props_prop");
				DispatchSpawn(prop);
				GetClientAbsOrigin(param1, VecOrigin);
				GetClientEyeAngles(param1, VecAngles);
				VecAngles[0] = 0.0;
				VecAngles[2] = 0.0;
				g_vecLastEntityAngles[param1] = VecAngles;
				g_iLastObject[param1] = prop;
				DispatchKeyValueVector(prop, "angles", VecAngles);
				DispatchSpawn(prop);
				g_bSpawned[prop] = true;
				g_vecEntityAngles[prop] = VecAngles;
				TeleportEntity(prop, VecOrigin, NULL_VECTOR, NULL_VECTOR);
				char name[256];
				GetClientName(param1, name, sizeof(name));
				LogSpawn("%s spawned a physics object with model <%s>", name, model);
			}
			else if(g_iCategory[param1] == 3)
			{
				float  VecOrigin[3];
				float VecAngles[3];
				int prop = CreateEntityByName("prop_dynamic_override");
				DispatchKeyValue(prop, "model", model);
				DispatchKeyValue(prop, "targetname", "l4d2_spawn_props_prop");
				DispatchSpawn(prop);
				GetClientEyePosition(param1, VecOrigin);
				GetClientEyeAngles(param1, VecAngles);
				
				TR_TraceRayFilter(VecOrigin, VecAngles, MASK_OPAQUE, RayType_Infinite, TraceRayDontHitSelf, param1);
				if(TR_DidHit(null))
				{
					TR_GetEndPosition(VecOrigin);
				}
				else
				{
					PrintToChat(param1, "[SM] 坐标超出当前世界几何. 生成在当前站立位置");
				}
				VecAngles[0] = 0.0;
				VecAngles[2] = 0.0;
				g_vecLastEntityAngles[param1] = VecAngles;
				g_iLastObject[param1] = prop;
				DispatchKeyValueVector(prop, "angles", VecAngles);
				DispatchSpawn(prop);
				TeleportEntity(prop, VecOrigin, NULL_VECTOR, NULL_VECTOR);
			
				g_bSpawned[prop] = true;
				g_bUnsolid[prop] = true;
				g_vecEntityAngles[prop] = VecAngles;
				char name[256];
				GetClientName(param1, name, sizeof(name));
				LogSpawn("%s spawned a dynamic object with model <%s>", name, model);
			}
			else if(g_iCategory[param1] == 4)
			{
				float  VecOrigin[3];
				float VecAngles[3];
				int prop = CreateEntityByName("prop_dynamic_override");
				DispatchKeyValue(prop, "model", model);
				DispatchKeyValue(prop, "targetname", "l4d2_spawn_props_prop");
				DispatchSpawn(prop);
				GetClientAbsOrigin(param1, VecOrigin);
				GetClientEyeAngles(param1, VecAngles);
				VecAngles[0] = 0.0;
				VecAngles[2] = 0.0;
				g_vecLastEntityAngles[param1] = VecAngles;
				g_iLastObject[param1] = prop;
				DispatchKeyValueVector(prop, "angles", VecAngles);
				DispatchSpawn(prop);
				TeleportEntity(prop, VecOrigin, NULL_VECTOR, NULL_VECTOR);
				g_bSpawned[prop] = true;
				g_bUnsolid[prop] = true;
				g_vecEntityAngles[prop] = VecAngles;
				char name[256];
				GetClientName(param1, name, sizeof(name));
				LogSpawn("%s spawned a dynamic object with model <%s>", name, model);
			}
			else if(g_iCategory[param1] == 5)
			{
				float  VecOrigin[3];
				float VecAngles[3];
				int prop = CreateEntityByName("prop_dynamic_override");
				DispatchKeyValue(prop, "model", model);
				DispatchKeyValue(prop, "targetname", "l4d2_spawn_props_prop");
				GetClientEyePosition(param1, VecOrigin);
				GetClientEyeAngles(param1, VecAngles);
				SetEntProp(prop, Prop_Send, "m_nSolidType", 6);
				
				TR_TraceRayFilter(VecOrigin, VecAngles, MASK_OPAQUE, RayType_Infinite, TraceRayDontHitSelf, param1);
				if(TR_DidHit(null))
				{
					TR_GetEndPosition(VecOrigin);
				}
				else
				{
					PrintToChat(param1, "[SM] 坐标超出当前世界几何. 生成在当前站立位置");
				}
				VecAngles[0] = 0.0;
				VecAngles[2] = 0.0;
				g_vecLastEntityAngles[param1] = VecAngles;
				g_iLastObject[param1] = prop;
				DispatchKeyValueVector(prop, "angles", VecAngles);
				DispatchSpawn(prop);
				TeleportEntity(prop, VecOrigin, NULL_VECTOR, NULL_VECTOR);
				g_bSpawned[prop] = true;
				g_vecEntityAngles[prop] = VecAngles;
				char name[256];
				GetClientName(param1, name, sizeof(name));
				LogSpawn("%s spawned a static object with model <%s>", name, model);
			}
			else if(g_iCategory[param1] == 6)
			{
				float  VecOrigin[3];
				float VecAngles[3];
				int prop = CreateEntityByName("prop_dynamic_override");
				DispatchKeyValue(prop, "model", model);
				DispatchKeyValue(prop, "targetname", "l4d2_spawn_props_prop");
				SetEntProp(prop, Prop_Send, "m_nSolidType", 6);
				DispatchSpawn(prop);
				GetClientAbsOrigin(param1, VecOrigin);
				GetClientEyeAngles(param1, VecAngles);
				VecAngles[0] = 0.0;
				VecAngles[2] = 0.0;
				g_vecLastEntityAngles[param1] = VecAngles;
				g_iLastObject[param1] = prop;
				DispatchKeyValueVector(prop, "angles", VecAngles);
				DispatchSpawn(prop);
				TeleportEntity(prop, VecOrigin, NULL_VECTOR, NULL_VECTOR);
				g_bSpawned[prop] = true;
				g_vecEntityAngles[prop] = VecAngles;
				char name[256];
				GetClientName(param1, name, sizeof(name));
				LogSpawn("%s spawned a static object with model <%s>", name, model);
			}
			switch(g_iSubCategory[param1])
			{
				case 1:
				{
					g_iVehiclesMenuPosition[param1] = menu.Selection;
					DisplayVehiclesMenu(param1);
				}
				case 2:
				{
					g_iFoliageMenuPosition[param1] = menu.Selection;
					DisplayFoliageMenu(param1);
				}
				case 3:
				{
					g_iInteriorMenuPosition[param1] = menu.Selection;
					DisplayInteriorMenu(param1);
				}
				case 4:
				{
					g_iExteriorMenuPosition[param1] = menu.Selection;
					DisplayExteriorMenu(param1);
					
				}
				case 5:
				{
					g_iDecorMenuPosition[param1] = menu.Selection;
					DisplayDecorativeMenu(param1);
					
				}
				case 6:
				{
					g_iMiscMenuPosition[param1] = menu.Selection;
					DisplayMiscMenu(param1);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				switch(g_iCategory[param1])
				{
					case 1:
					{
						BuildPhysicsCursorMenu(param1);
					}
					case 2:
					{
						BuildPhysicsPositionMenu(param1);
					}
					case 3:
					{
						BuildDynamicCursorMenu(param1);
					}
					case 4:
					{
						BuildDynamicPositionMenu(param1);
					}
					case 5:
					{
						BuildStaticCursorMenu(param1);
					}
					case 6:
					{
						BuildStaticPositionMenu(param1);
					}
				}
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_PropPosition(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			switch(g_iMoveCategory[param1])
			{
				case 1:
				{
					if(g_iLastObject[param1] <= 0 || !IsValidEntity(g_iLastObject[param1]))
					{
						PrintToChat(param1, "[SM] 上个物体不再有效或者你还没生成任何物体");
						DisplayRotateMenu(param1);
						return;
					}
					int Object = g_iLastObject[param1];
					
					float  vecAngles[3];
					vecAngles[0] = g_vecLastEntityAngles[param1][0];
					vecAngles[1] = g_vecLastEntityAngles[param1][1];
					vecAngles[2] = g_vecLastEntityAngles[param1][2];
					
					if(StrEqual(menucmd, "rotate1x"))
					{
						vecAngles[0] += 1;
					}
					else if(StrEqual(menucmd, "rotate10x"))
					{
						vecAngles[0] += 10;
					}
					else if(StrEqual(menucmd, "rotate15x"))
					{
						vecAngles[0] += 15;
					}
					else if(StrEqual(menucmd, "rotate45x"))
					{
						vecAngles[0] += 45;
					}
					else if(StrEqual(menucmd, "rotate90x"))
					{
						vecAngles[0] += 90;
					}
					else if(StrEqual(menucmd, "rotate180x"))
					{
						vecAngles[0] += 180;
					}
					else if(StrEqual(menucmd, "rotate1y"))
					{
						vecAngles[1] += 1;
					}
					else if(StrEqual(menucmd, "rotate10y"))
					{
						vecAngles[1] += 10;
					}
					else if(StrEqual(menucmd, "rotate15y"))
					{
						vecAngles[1] += 15;
					}
					else if(StrEqual(menucmd, "rotate45y"))
					{
						vecAngles[1] += 45;
					}
					else if(StrEqual(menucmd, "rotate90y"))
					{
						vecAngles[1] += 90;
					}
					else if(StrEqual(menucmd, "rotate180y"))
					{
						vecAngles[1] += 180;
					}
					else if(StrEqual(menucmd, "rotate1z"))
					{
						vecAngles[2] += 1;
					}
					else if(StrEqual(menucmd, "rotate10z"))
					{
						vecAngles[2] += 10;
					}
					else if(StrEqual(menucmd, "rotate15z"))
					{
						vecAngles[2] += 15;
					}
					else if(StrEqual(menucmd, "rotate45z"))
					{
						vecAngles[2] += 45;
					}
					else if(StrEqual(menucmd, "rotate90z"))
					{
						vecAngles[2] += 90;
					}
					else if(StrEqual(menucmd, "rotate180z"))
					{
						vecAngles[2] += 180;
					}
					
					g_vecLastEntityAngles[param1] = vecAngles;
					TeleportEntity(Object, NULL_VECTOR, vecAngles, NULL_VECTOR);
					g_vecEntityAngles[g_iLastObject[param1]] = vecAngles;
					
					g_iRotateMenuPosition[param1] = menu.Selection;
					DisplayRotateMenu(param1);
				}
				case 2:
				{
					if(g_iLastObject[param1] <= 0 || !IsValidEntity(g_iLastObject[param1]))
					{
						PrintToChat(param1, "[SM] 上个物体不再有效或者你还没生成任何物体");
						DisplayMoveMenu(param1);
						return;
					}
					
					int Object = g_iLastObject[param1];
					float  vecOrigin[3];
					GetEntPropVector(Object, Prop_Data, "m_vecOrigin", vecOrigin);
					
					if(StrEqual(menucmd, "moveup"))
					{
						vecOrigin[2]+= 30;
					}
					else if(StrEqual(menucmd, "movedown"))
					{
						vecOrigin[2]-= 30;
					}
					else if(StrEqual(menucmd, "moveright"))
					{
						vecOrigin[1]+= 30;
					}
					else if(StrEqual(menucmd, "moveleft"))
					{
						vecOrigin[1]-= 30;
					}
					else if(StrEqual(menucmd, "moveforward"))
					{
						vecOrigin[0]+= 30;
					}
					else if(StrEqual(menucmd, "movebackward"))
					{
						vecOrigin[0]-= 30;
					}
					TeleportEntity(Object, vecOrigin, NULL_VECTOR, NULL_VECTOR);
					
					DisplayMoveMenu(param1);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				BuildEditPropMenu(param1);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	if(entity == data) // Check if the TraceRay hit the itself.
	{
		return false; // Don't let the entity be hit
	}
	return true; // It didn't hit itself
}

void DeleteLookingEntity(int client)
{
	float  VecOrigin[3];
	float VecAngles[3];
	GetClientEyePosition(client, VecOrigin);
	GetClientEyeAngles(client, VecAngles);
	TR_TraceRayFilter(VecOrigin, VecAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
	if(TR_DidHit(null))
	{
		int Object = TR_GetEntityIndex(null);
		if(Object > 0 && IsValidEntity(Object) && IsValidEdict(Object))
		{
			char class[256];
			GetEdictClassname(Object, class, sizeof(class));
			if(StrEqual(class, "prop_physics")
			|| StrEqual(class, "prop_dynamic")
			|| StrEqual(class, "prop_physics_override")
			|| StrEqual(class, "prop_dynamic_override"))
			{
				g_bSpawned[Object] = false;
				g_bUnsolid[Object] = false;
				g_vecEntityAngles[Object][0] = 0.0;
				g_vecEntityAngles[Object][1] = 0.0;
				g_vecEntityAngles[Object][2] = 0.0;
				AcceptEntityInput(Object, "KillHierarchy");
				PrintToChat(client, "[SM] 成功移除一个物体");
				if(Object == g_iLastObject[client])
				{
					g_iLastObject[client] = -1;
					g_vecLastEntityAngles[client][0] = 0.0;
					g_vecLastEntityAngles[client][1] = 0.0;
					g_vecLastEntityAngles[client][2] = 0.0;
					g_bGrab[client] = false;
					g_bGrabbed[Object] = false;
				}
				if(Object == g_iLastGrabbedObject[client])
				{
					g_iLastGrabbedObject[client] = -1;
				}
				return;
			}
		}
	}
	else
	{
		int Object = GetClientAimTarget(client, false);
		if(Object == -2)
		{
			PrintToChat(client, "[SM] 在这场游戏中插件不再生效");
			SetFailState("Unhandled Behaviour");
		}
		if(Object > 0 && IsValidEntity(Object))
		{
			char class[256];
			GetEdictClassname(Object, class, sizeof(class));
			if(StrEqual(class, "prop_physics")
			|| StrEqual(class, "prop_dynamic")
			|| StrEqual(class, "prop_physics_override")
			|| StrEqual(class, "prop_dynamic_override"))
			{
				g_bSpawned[Object] = false;
				g_bUnsolid[Object] = false;
				g_vecEntityAngles[Object][0] = 0.0;
				g_vecEntityAngles[Object][1] = 0.0;
				g_vecEntityAngles[Object][2] = 0.0;
				AcceptEntityInput(Object, "KillHierarchy");
				PrintToChat(client, "[SM] 成功移除一个物体");
				if(Object == g_iLastObject[client])
				{
					g_iLastObject[client] = -1;
					g_vecLastEntityAngles[client][0] = 0.0;
					g_vecLastEntityAngles[client][1] = 0.0;
					g_vecLastEntityAngles[client][2] = 0.0;
					if(Object == g_iLastGrabbedObject[client])
					{
						g_iLastGrabbedObject[client] = -1;
					}
				}
				return;
			}
		}
	}
	PrintToChat(client, "[SM] 您不是在寻找有效的物体");
}

void DeleteAllProps()
{
	CheatCommand(_, "ent_fire", "l4d2_spawn_props_prop KillHierarchy");
	for(int i=1; i<=MaxClients; i++)
	{
		g_iLastObject[i] = -1;
		g_vecLastEntityAngles[i][0] = 0.0;
		g_vecLastEntityAngles[i][1] = 0.0;
		g_vecLastEntityAngles[i][2] = 0.0;
		g_bGrab[i] = false;
		g_iLastGrabbedObject[i] = -1;
	}
	for(int i=MaxClients; i < ARRAY_SIZE; i++)
	{
		if(g_bSpawned[i])
		{
			g_bGrabbed[i] = false;
			g_bSpawned[i] = false;
			g_bUnsolid[i] = false;
			g_vecEntityAngles[i][0] = 0.0;
			g_vecEntityAngles[i][1] = 0.0;
			g_vecEntityAngles[i][2] = 0.0;
			if(IsValidEntity(i))
			{
				AcceptEntityInput(i, "Kill");
			}
		}
	}
}

void CheatCommand(int client = 0, char[] command, char[] arguments="")
{
	if (!client || !IsClientInGame(client))
	{
		for (int target = 1; target <= MaxClients; target++)
		{
			if (IsClientInGame(target))
			{
				client = target;
				break;
			}
		}
		
		if (!client || !IsClientInGame(client)) return;
	}
	
	int userflags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userflags);
}

//Disabled right now
void DeleteLastProp(int client)
{
	int Object = g_iLastObject[client];
	if(Object > 0 && IsValidEntity(Object))
	{
		char class[256];
		GetEdictClassname(Object, class, sizeof(class));
		if(StrEqual(class, "prop_physics")
		|| StrEqual(class, "prop_dynamic")
		|| StrEqual(class, "prop_physics_override")
		|| StrEqual(class, "prop_dynamic_override"))
		{
			AcceptEntityInput(g_iLastObject[client], "KillHierarchy");
			PrintToChat(client, "[SM] 成功删除上一个生成的物体");
			g_iLastObject[client] = -1;
			g_vecLastEntityAngles[client][0] = 0.0;
			g_vecLastEntityAngles[client][1] = 0.0;
			g_vecLastEntityAngles[client][2] = 0.0;
			g_bSpawned[Object] = false;
			g_bUnsolid[Object] = false;
			g_vecEntityAngles[Object][0] = 0.0;
			g_vecEntityAngles[Object][1] = 0.0;
			g_vecEntityAngles[Object][2] = 0.0;
			g_bGrab[client] = false;
			g_bGrabbed[Object] = false;
			if(Object == g_iLastGrabbedObject[client])
			{
				g_iLastGrabbedObject[client] = -1;
			}
			return;
		}
		else
		{
			PrintToChat(client, "[SM] 上一个生成的指数 %i 不再是一个物体!", Object);
			g_iLastObject[client] = -1;
			g_vecLastEntityAngles[client][0] = 0.0;
			g_vecLastEntityAngles[client][1] = 0.0;
			g_vecLastEntityAngles[client][2] = 0.0;
			g_bSpawned[Object] = false;
			g_bUnsolid[Object] = false;
			g_vecEntityAngles[Object][0] = 0.0;
			g_vecEntityAngles[Object][1] = 0.0;
			g_vecEntityAngles[Object][2] = 0.0;
		}
	}
	else if(Object > 0 && !IsValidEntity(Object))
	{
		PrintToChat(client, "[SM] 上一个物体不再有效");
	}
	else if(Object <= 0)
	{
		PrintToChat(client, "[SM] 你还没生成任何物体");
	}
}

void LogSpawn(const char[] format, any ...)
{
	if(!g_cvarLog.BoolValue)
	{
		return;
	}
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	File file;
	char FileName[256];
	char sTime[256];
	FormatTime(sTime, sizeof(sTime), "%Y%m%d");
	BuildPath(Path_SM, FileName, sizeof(FileName), "logs/objects_%s.log", sTime);
	file = OpenFile(FileName, "a+");
	FormatTime(sTime, sizeof(sTime), "%b %d |%H:%M:%S| %Y");
	file.WriteLine("%s: %s", sTime, buffer);
	FlushFile(file);
	CloseHandle(file);
}

public Action CmdSaveMap(int client, int args)
{
	SaveMapStripper(client);
	return Plugin_Handled;
}

void SaveMapStripper(int client)
{
	#if DEBUG
	LogSpawn("[DEBUG] <SaveMapStripper> was called by %N", client);
	#endif
	LogSpawn("%N saved the objects for this map on a 'Stripper' file format", client);
	PrintToChat(client, "\x04[SM] Saving the content. Please Wait");
	char FileName[256];
	char map[256];
	char classname[256];
	File file;
	GetCurrentMap(map, sizeof(map));
	BuildPath(Path_SM, FileName, sizeof(FileName), "../stripper/maps/%s.cfg", map);
	
	if(FileExists(FileName))
	{
		PrintHintText(client, "该文件已存在.较旧的内容不会被删除.");
	}
	#if DEBUG
	LogSpawn("[DEBUG] <SaveMapStripper> File stated, proceed");
	#endif
	file = OpenFile(FileName, "a+");
	#if DEBUG
	LogSpawn("[DEBUG] <SaveMapStripper> File Opened, proceed");
	#endif
	if(file == null)
	{
		#if DEBUG
		LogSpawn("[DEBUG] <SaveMapStripper> File Invalid, proceed");
		#endif
		PrintToChat(client, "[SM] 无法创建或覆盖地图文件");
		PrintToChat(client, "\x04[SM] 安装过程中可能缺少某些东西");
		PrintHintText(client, "[SM] 可能缺少addons/stripper文件夹");
		PrintToConsole(client, "[SM] 无法打开,写入或查找文件!");
		PrintCenterText(client, "[SM] 失败");
		return;
	}
	
	float  vecOrigin[3];
	float vecAngles[3];
	char sModel[256];
	char sTime[256];
	int iOrigin[3], iAngles[3];
	FormatTime(sTime, sizeof(sTime), "%Y/%m/%d");
	file.WriteLine(";----------FILE MODIFICATION (YY/MM/DD): [%s] ---------------||", sTime);
	file.WriteLine(";----------BY: %N----------------------||", client);
	file.WriteLine("");
	file.WriteLine("add:");
	#if DEBUG
	LogSpawn("[DEBUG] <SaveMapStripper> Wrote first information line");
	#endif
	for(int i=MaxClients; i < ARRAY_SIZE; i++)
	{
		#if DEBUG
		LogSpawn("[DEBUG] <SaveMapStripper> CHECK: %i", i);
		#endif
		if(g_bSpawned[i] && IsValidEntity(i))
		{
			GetEdictClassname(i, classname, sizeof(classname));
			#if DEBUG
			LogSpawn("[DEBUG] <SaveMapStripper> Possible Entity Found: %i <%s>", i, classname);
			#endif
			if(StrContains(classname, "prop_dynamic") >= 0 || StrContains(classname, "prop_physics") >= 0)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", vecOrigin);
				vecAngles = g_vecEntityAngles[i];
				GetEntPropString(i, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
				iOrigin[0] = RoundToFloor(vecOrigin[0]);
				iOrigin[1] = RoundToFloor(vecOrigin[1]);
				iOrigin[2] = RoundToFloor(vecOrigin[2]);
				
				iAngles[0] = RoundToFloor(vecAngles[0]);
				iAngles[1] = RoundToFloor(vecAngles[1]);
				iAngles[2] = RoundToFloor(vecAngles[2]);
				file.WriteLine("{");
				if(StrContains(classname, "physics") < 0)
				{
					if(g_bUnsolid[i])
					{
						file.WriteLine("	\"solid\" \"0\"");
					}
					else
					{
						file.WriteLine("	\"solid\" \"6\"");
					}
				}
				file.WriteLine("	\"origin\" \"%i %i %i\"", iOrigin[0], iOrigin[1], iOrigin[2]);
				file.WriteLine("	\"angles\" \"%i %i %i\"", iAngles[0], iAngles[1], iAngles[2]);
				file.WriteLine("	\"model\"	 \"%s\"", sModel);
				file.WriteLine("	\"classname\"	\"%s\"", classname);
				file.WriteLine("}");
				file.WriteLine("");
				#if DEBUG
				LogSpawn("[DEBUG] <SaveMapStripper> END: %i", i);
				#endif
			}
		}
	}
	#if DEBUG
	LogSpawn("[DEBUG] <SaveMapStripper> Wrote all entities");
	#endif
	FlushFile(file);
	CloseHandle(file);
	PrintToChat(client, "\x03[SM] Succesfully saved the map data (%s)", FileName);
	#if DEBUG
	LogSpawn("[DEBUG] <SaveMapStripper> END");
	#endif
}

void SaveRoutingPath(int client, int type)
{
	#if DEBUG
	LogSpawn("[DEBUG] <SaveRoutingPath> was called by %N", client);
	#endif
	LogSpawn("%N saved the objects for this map on a \"Routing\" file format", client);
	PrintToChat(client, "\x04[SM] Saving the content. Please Wait");
	char FileName[256];
	char map[256];
	char classname[256];
	char targetname[256];
	File file;
	bool Exists = false;
	GetCurrentMap(map, sizeof(map));
	BuildPath(Path_SM, FileName, sizeof(FileName), "../stripper/routing/%s.cfg", map);
	if(FileExists(FileName))
	{
		PrintHintText(client, "该文件已存在.较旧的内容不会被删除.");
		Exists = true;
	}
	file = OpenFile(FileName, "a+");
	if(file == null)
	{
		PrintToChat(client, "[SM] 无法创建或覆盖地图文件");
		PrintToChat(client, "\x04[SM] 安装过程中可能缺少某些东西");
		PrintHintText(client, "[SM] 可能缺少addons/stripper/maps/routing文件夹");
		PrintToConsole(client, "[SM] 无法打开,写入或查找文件!");
		PrintCenterText(client, "[SM] 失败");
		return;
	}
	float  vecOrigin[3];
	float vecAngles[3];
	char sModel[256];
	char sTime[256];
	int iOrigin[3], iAngles[3];
	FormatTime(sTime, sizeof(sTime), "%Y/%m/%d");
	file.WriteLine(";----------FILE MODIFICATION (YY/MM/DD): [%s] ---------------||", sTime);
	file.WriteLine(";----------BY: %N----------------------||", client);
	file.WriteLine("");
	switch(type)
	{
		case RouteType_Easy:
		{
			file.WriteLine(";This part was generated for an \"Easy\" routing path.");
			Format(targetname, sizeof(targetname), "easy_route_blocker");
		}
		case RouteType_Medium:
		{
			file.WriteLine(";This part was generated for a \"Medium\" routing path.");
			Format(targetname, sizeof(targetname), "medium_route_blocker");
		}
		case RouteType_Hard:
		{
			file.WriteLine(";This part was generated for a \"Hard\" routing path.");
			Format(targetname, sizeof(targetname), "hard_route_blocker");
		}
	}
	file.WriteLine("");
	file.WriteLine("add:");
	
	if(!Exists)
	{
		//First, wee add the necessary relays
		
		file.WriteLine("; plugin trigger relay");
		file.WriteLine("; will get fired by Plugin ONLY IN VERSUS, so it doesnt break coop");
		file.WriteLine("{");
		file.WriteLine("	\"origin\" \"0 0 0\"");
		file.WriteLine("	\"spawnflags\" \"1\"");
		file.WriteLine("	\"targetname\" \"relay_routing_init\"");
		file.WriteLine("	\"classname\" \"logic_relay\"");
		file.WriteLine("	");
		file.WriteLine("	; destroy Valve routing entities so they dont interfere");
		file.WriteLine("	");
		file.WriteLine("	\"OnTrigger\" \"director_queryKill0-1\"");
		file.WriteLine("}");
		file.WriteLine("");
		file.WriteLine("{");
		file.WriteLine("	\"origin\" \"0 0 0\"");
		file.WriteLine("	\"spawnflags\" \"1\"");
		file.WriteLine("	\"targetname\" \"relay_routing_disabledbydefault\"");
		file.WriteLine("	\"classname\" \"logic_auto\"");
		file.WriteLine("	");
		file.WriteLine("	\"OnMapSpawn\" \"easy_route_blockerDisable0-1\"");
		file.WriteLine("	\"OnMapSpawn\" \"easy_route_blockerDisableCollision0-1\"");
		file.WriteLine("	\"OnMapSpawn\" \"medium_route_blockerDisable0-1\"");
		file.WriteLine("	\"OnMapSpawn\" \"medium_route_blockerDisableCollision0-1\"");
		file.WriteLine("	\"OnMapSpawn\" \"hard_route_blockerDisable0-1\"");
		file.WriteLine("	\"OnMapSpawn\" \"hard_route_blockerDisableCollision0-1\"");
		file.WriteLine("}");
		file.WriteLine("; config existence checking entity");
		file.WriteLine("{");
		file.WriteLine("	\"origin\" \"0 0 0\"");
		file.WriteLine("	\"targetname\" \"map_has_routing\"");
		file.WriteLine("	\"noise\" \"0\"");
		file.WriteLine("	\"minAngerRange\" \"1\"");
		file.WriteLine("	\"maxAngerRange\" \"10\"");
		file.WriteLine("	\"classname\" \"logic_director_query\"");
		file.WriteLine("	\"OutAnger\" \"DoHeadBangInValue0-1\"");
		file.WriteLine("}");
		file.WriteLine("");
		file.WriteLine("; easy path");
		file.WriteLine("{");
		file.WriteLine("	\"origin\" \"0 0 0\"");
		file.WriteLine("	\"targetname\" \"relay_easy_route_spawn\"");
		file.WriteLine("	\"spawnflags\" \"0\"");
		file.WriteLine("	\"classname\" \"logic_relay\"");
		file.WriteLine("	\"OnTrigger\" \"easy_route_blockerEnable0-1\"");
		file.WriteLine("	\"OnTrigger\" \"easy_route_blockerEnableCollision0-1\"");
		file.WriteLine("}");
		file.WriteLine("");
		file.WriteLine("; medium path");
		file.WriteLine("{");
		file.WriteLine("	\"origin\" \"0 0 0\"");
		file.WriteLine("	\"targetname\" \"relay_medium_route_spawn\"");
		file.WriteLine("	\"spawnflags\" \"0\"");
		file.WriteLine("	\"classname\" \"logic_relay\"");
		file.WriteLine("	\"OnTrigger\" \"medium_route_blockerEnable0-1\"");
		file.WriteLine("	\"OnTrigger\" \"medium_route_blockerEnableCollision0-1\"");
		file.WriteLine("}");
		file.WriteLine("");
		file.WriteLine("; hard path");
		file.WriteLine("{");
		file.WriteLine("	\"origin\" \"0 0 0\"");
		file.WriteLine("	\"targetname\" \"relay_hard_route_spawn\"");
		file.WriteLine("	\"spawnflags\" \"0\"");
		file.WriteLine("	\"classname\" \"logic_relay\"");
		file.WriteLine("	\"OnTrigger\" \"hard_route_blockerEnable0-1\"");
		file.WriteLine("	\"OnTrigger\" \"hard_route_blockerEnableCollision0-1\"");
		file.WriteLine("}");
		file.WriteLine("");
	}
	for(int i=MaxClients; i < ARRAY_SIZE; i++)
	{
		if(g_bSpawned[i] && IsValidEntity(i))
		{
			GetEdictClassname(i, classname, sizeof(classname));
			if(StrContains(classname, "prop_dynamic") >= 0 || StrContains(classname, "prop_physics") >= 0)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", vecOrigin);
				vecAngles = g_vecEntityAngles[i];
				GetEntPropString(i, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
				iOrigin[0] = RoundToFloor(vecOrigin[0]);
				iOrigin[1] = RoundToFloor(vecOrigin[1]);
				iOrigin[2] = RoundToFloor(vecOrigin[2]);
				
				iAngles[0] = RoundToFloor(vecAngles[0]);
				iAngles[1] = RoundToFloor(vecAngles[1]);
				iAngles[2] = RoundToFloor(vecAngles[2]);
				file.WriteLine("{");
				if(StrContains(classname, "physics") < 0)
				{
					if(g_bUnsolid[i])
					{
						file.WriteLine("	\"solid\" \"0\"");
					}
					else
					{
						file.WriteLine("	\"solid\" \"6\"");
					}
				}
				file.WriteLine("	\"origin\" \"%i %i %i\"", iOrigin[0], iOrigin[1], iOrigin[2]);
				file.WriteLine("	\"angles\" \"%i %i %i\"", iAngles[0], iAngles[1], iAngles[2]);
				file.WriteLine("	\"model\"	 \"%s\"", sModel);
				file.WriteLine("	\"targetname\" \"%s\"", targetname);
				file.WriteLine("	\"classname\"	\"%s\"", classname);
				file.WriteLine("}");
				file.WriteLine("");
			}
		}
	}
	FlushFile(file);
	CloseHandle(file);
	PrintToChat(client, "\x03[SM] 成功保存地图数据 (%s)", FileName);
}

void SavePluginProps(int client)
{
	LogSpawn("%N saved the objects for this map on a \"Plugin Cache\" file format", client);
	PrintToChat(client, "\x04[SM] 保存内容.请稍候");
	char FileName[256];
	char map[256];
	char classname[256];
	char FileNameS[256];
	char FileNameT[256];
	File file;
	GetCurrentMap(map, sizeof(map));
	BuildPath(Path_SM, FileNameS, sizeof(FileNameS), "../stripper/plugin_cache/%s", map);
	Format(FileName, sizeof(FileName), "%s_1.txt", FileNameS);
	int map_number = 0;
	if(FileExists(FileName))
	{
		map_number = GetNextMapNumber(FileNameS);
		if(map_number <= 0)
		{
			PrintToChat(client, "\x04[SM] 致命错误:此映射的路径文件太多! (最大: %i)", MAX_PATHS);
			return;
		}
		Format(FileNameT, sizeof(FileNameT), "%s_%i.txt", FileNameS, map_number);
	}
	else
	{
		Format(FileNameT, sizeof(FileNameT), "%s_1.txt", FileNameS);
	}
	file = OpenFile(FileNameT, "a+");
	if(file == null)
	{
		PrintToChat(client, "[SM] 无法创建或覆盖地图文件");
		PrintToChat(client, "\x04[SM] 安装过程中可能缺少某些东西");
		PrintHintText(client, "[SM] 可能缺少addons/stripper/maps/plugin_cache文件夹");
		PrintToConsole(client, "[SM] 无法打开,写入或查找文件!");
		PrintCenterText(client, "[SM] 失败");
		return;
	}
	CreateInitFile();
	float  vecOrigin[3];
	float vecAngles[3];
	char sModel[256];
	char sTime[256];
	int iOrigin[3], iAngles[3];
	int count = 0;
	FormatTime(sTime, sizeof(sTime), "%Y/%m/%d");
	file.WriteLine("//----------FILE MODIFICATION (YY/MM/DD): [%s] ---------------||", sTime);
	file.WriteLine("//----------BY: %N----------------------||", client);
	file.WriteLine("");
	file.WriteLine("\"Objects_Cache\"");
	file.WriteLine("{");
	for(int i=MaxClients; i < ARRAY_SIZE; i++)
	{
		if(g_bSpawned[i] && IsValidEntity(i))
		{
			GetEdictClassname(i, classname, sizeof(classname));
			if(StrContains(classname, "prop_dynamic") >= 0 || StrContains(classname, "prop_physics") >= 0)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", vecOrigin);
				vecAngles = g_vecEntityAngles[i];
				GetEntPropString(i, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
				iOrigin[0] = RoundToFloor(vecOrigin[0]);
				iOrigin[1] = RoundToFloor(vecOrigin[1]);
				iOrigin[2] = RoundToFloor(vecOrigin[2]);
				
				iAngles[0] = RoundToFloor(vecAngles[0]);
				iAngles[1] = RoundToFloor(vecAngles[1]);
				iAngles[2] = RoundToFloor(vecAngles[2]);
				count++;
				
				file.WriteLine("	\"object_%i\"", count);
				file.WriteLine("	{");
				if(StrContains(classname, "physics") < 0)
				{
					if(g_bUnsolid[i])
					{
						file.WriteLine("		\"solid\" \"0\"");
					}
					else
					{
						file.WriteLine("		\"solid\" \"6\"");
					}
				}
				file.WriteLine("		\"origin\" \"%i %i %i\"", iOrigin[0], iOrigin[1], iOrigin[2]);
				file.WriteLine("		\"angles\" \"%i %i %i\"", iAngles[0], iAngles[1], iAngles[2]);
				file.WriteLine("		\"model\"	 \"%s\"", sModel);
				file.WriteLine("		\"classname\"	\"%s\"", classname);
				file.WriteLine("	}");
				file.WriteLine("	");
			}
		}
	}
	file.WriteLine("	\"total_cache\"");
	file.WriteLine("	{");
	file.WriteLine("		\"total\" \"%i\"", count);
	file.WriteLine("	}");
	file.WriteLine("}");
	
	FlushFile(file);
	CloseHandle(file);
	PrintToChat(client, "\x03[SM] 成功保存地图数据 (%s)", FileNameT);
}

public Action CmdLoad(int client, int args)
{
	if(args < 1)
	{
		PrintToChat(client, "[SM] 指定地图号码");
	}
	char arg[5];
	GetCmdArgString(arg, sizeof(arg));
	int number = StringToInt(arg);
	LoadPluginProps(client, number);
	return Plugin_Handled;
}

void LoadPluginProps(int client, int number)
{
	LogSpawn("%N loaded the objects for this map", client);
	PrintToChat(client, "\x04[SM] 正在加载内容.请稍候");
	char FileName[256];
	char map[256];
	char name[256];
	GetCurrentMap(map, sizeof(map));
	BuildPath(Path_SM, FileName, sizeof(FileName), "../stripper/plugin_cache/%s_%i.txt", map, number);
	if(!FileExists(FileName))
	{
		PrintToChat(client, "\x04[SM] 该文件不存在");
		PrintHintText(client, "\x04[SM] 该文件不存在");
		return;
	}
	KeyValues keyvalues = new KeyValues("Objects_Cache");
	keyvalues.ImportFromFile(FileName);
	keyvalues.Rewind();
	if(keyvalues.JumpToKey("total_cache"))
	{
		int max = keyvalues.GetNum("total", 0);
		if(max <= 0)
		{
			PrintToChat(client, "\x04[SM] 在缓存中找不到物体");
			return;
		}
		char model[256];
		char class[64];
		float vecOrigin[3];
		float vecAngles[3];
		int solid;
		keyvalues.Rewind();
		for(int count=1; count <= max; count++)
		{
			Format(name, sizeof(name), "object_%i", count);
			if(keyvalues.JumpToKey(name))
			{
				solid = keyvalues.GetNum("solid");
				keyvalues.GetVector("origin", vecOrigin);
				keyvalues.GetVector("angles", vecAngles);
				keyvalues.GetString("model", model, sizeof(model));
				keyvalues.GetString("classname", class, sizeof(class));
				int prop = -1;
				keyvalues.Rewind();
				if(StrContains(class, "prop_physics") >= 0)
				{
					prop = CreateEntityByName("prop_physics_override");
				}
				else
				{
					prop = CreateEntityByName("prop_dynamic_override");
					SetEntProp(prop, Prop_Send, "m_nSolidType", solid);
				}
				DispatchKeyValue(prop, "model", model);
				DispatchKeyValue(prop, "targetname", "l4d2_spawn_props_prop");
				
				g_vecLastEntityAngles[client][0] = vecAngles[0];
				g_vecLastEntityAngles[client][1] = vecAngles[1];
				g_vecLastEntityAngles[client][2] = vecAngles[2];
				DispatchKeyValueVector(prop, "angles", vecAngles);
				DispatchSpawn(prop);
				TeleportEntity(prop, vecOrigin, NULL_VECTOR, NULL_VECTOR);
				g_bSpawned[prop] = true;
				g_vecEntityAngles[prop] = vecAngles;				
			}
			else
			{
				break;
			}
		}
	}
	CloseHandle(keyvalues);
	PrintToChat(client, "\x03[SM] 成功加载地图数据");
	PrintHintText(client, "[SM] 如果看不到任何东西,则可能是在安装过程中忘记了一些东西");
}

public Action CmdRotate(int client, int args)
{
	if(args < 2)
	{
		PrintToChat(client, "[SM] 用法: sm_prop_rotate <轴> <角度> [示例: !prop_rotate x 30]");
		return Plugin_Handled;
	}
	int Object = g_iLastObject[client];
	char arg1[16];
	char arg2[16];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	float  vecAngles[3];
	vecAngles[0] = g_vecLastEntityAngles[client][0];
	vecAngles[1] = g_vecLastEntityAngles[client][1];
	vecAngles[2] = g_vecLastEntityAngles[client][2];
	int iAngles = StringToInt(arg2);
	if(StrEqual(arg1, "x"))
	{
		vecAngles[0] += iAngles;
	}
	else if(StrEqual(arg1, "y"))
	{
		vecAngles[1] += iAngles;
	}
	else if(StrEqual(arg1, "z"))
	{
		vecAngles[2] += iAngles;
	}
	else
	{
		PrintToChat(client, "[SM] 无效的轴 (请使用x,y,z)");
	}
	g_vecLastEntityAngles[client] = vecAngles;
	TeleportEntity(Object, NULL_VECTOR, vecAngles, NULL_VECTOR);
	g_vecEntityAngles[g_iLastObject[client]] = vecAngles;
	return Plugin_Handled;
}

public Action CmdRemoveLast(int client, int args)
{
	DeleteLastProp(client);
	return Plugin_Handled;
}

public Action CmdRemoveLook(int client, int args)
{
	DeleteLookingEntity(client);
	return Plugin_Handled;
}

public Action CmdRemoveAll(int client, int args)
{
	PrintToChat(client, "\x04[SM] 你确定要删除所有物体吗?");
	BuildDeleteAllCmd(client);
	return Plugin_Handled;
}

Menu BuildDeleteAllCmd(int client)
{
	Menu menu = new Menu(MenuHandler_cmd_Ask);
	menu.SetTitle("你确定吗?");
	menu.AddItem("sm_spyes", "是");
	menu.AddItem("sm_spno", "否");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_cmd_Ask(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char menucmd[256];
			GetMenuItem(menu, param2, menucmd, sizeof(menucmd));
			if(StrEqual(menucmd, "sm_spyes"))
			{
				DeleteAllProps();
				PrintToChat(param1, "[SM] 成功删除使用生成的物体");
			}
			else
			{
				PrintToChat(param1, "[SM] 取消");
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				BuildDeleteAllCmd(param1);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

int GetNextMapNumber(char[] FileName)
{
	char FileNameS[256];
	for(int i=1; i <= MAX_PATHS; i++)
	{
		Format(FileNameS, sizeof(FileNameS), "%s_%i.txt", FileName, i);
		if(FileExists(FileNameS))
		{
			continue;
		}
		else
		{
			return i;
		}
	}
	return -1;
}

void SpawnObjects()
{
	//if disabled
	if(!g_cvarAutoload.BoolValue)
	{
		return;
	}
	char FileName[256];
	char name[256];
	BuildPath(Path_SM, FileName, sizeof(FileName), "../stripper/plugin_cache/%s.txt", g_sPath);
	LogSpawn("Spawning props from file %s", FileName);
	if(!FileExists(FileName))
	{
		LogError("Attempted to load an object file which does not exist (%s)", FileName);
		LogSpawn("[ERROR] Attempted to load an object file which does not exist (%s)", FileName);
		return;
	}
	KeyValues keyvalues = new KeyValues("Objects_Cache");
	keyvalues.ImportFromFile(FileName);
	keyvalues.Rewind();
	if(keyvalues.JumpToKey("total_cache"))
	{
		int max = keyvalues.GetNum("total", 0);
		if(max <= 0)
		{
			LogError("No Objects found for the map number cache");
			LogSpawn("[ERROR] No Objects found for the map number cache");
			return;
		}
		char model[256];
		char class[64];
		float vecOrigin[3];
		float vecAngles[3];
		int solid;
		keyvalues.Rewind();
		for(int count=1; count <= max; count++)
		{
			Format(name, sizeof(name), "object_%i", count);
			if(keyvalues.JumpToKey(name))
			{
				solid = keyvalues.GetNum("solid");
				keyvalues.GetVector("origin", vecOrigin);
				keyvalues.GetVector("angles", vecAngles);
				keyvalues.GetString("model", model, sizeof(model));
				keyvalues.GetString("classname", class, sizeof(class));
				int prop = -1;
				keyvalues.Rewind();
				if(StrContains(class, "prop_physics") >= 0)
				{
					prop = CreateEntityByName("prop_physics_override");
				}
				else
				{
					prop = CreateEntityByName("prop_dynamic_override");
					SetEntProp(prop, Prop_Send, "m_nSolidType", solid);
				}
				DispatchKeyValue(prop, "model", model);
				DispatchKeyValue(prop, "targetname", "l4d2_spawn_props_prop");
				
				DispatchKeyValueVector(prop, "angles", vecAngles);
				DispatchSpawn(prop);
				TeleportEntity(prop, vecOrigin, NULL_VECTOR, NULL_VECTOR);
				g_bSpawned[prop] = true;
				g_vecEntityAngles[prop] = vecAngles;				
			}
			else
			{
				break;
			}
		}
	}
	CloseHandle(keyvalues);
}
void CreateInitFile()
{
	char FileName[256];
	char map[256];
	File file;
	GetCurrentMap(map, sizeof(map));
	BuildPath(Path_SM, FileName, sizeof(FileName), "../stripper/plugin_cache/%s_init.txt", map);
	
	if(!FileExists(FileName))
	{
		file = OpenFile(FileName, "a+");
		if(file == null)
		{
			return;
		}
		file.WriteLine("//Init file for map %s", map);
		file.WriteLine("//DO NOT FORGET TO REPLACE \" FOR QUOTES!");
		file.WriteLine("//");
		file.WriteLine("//The format of the file is:");
		file.WriteLine("//");
		file.WriteLine("//	\"coop\" --------> This is the gamemode where the following object list will be loaded");
		file.WriteLine("//	{");
		file.WriteLine("//		\"total\"	\"2\" ---------> This is the total object list availables. Randomly, one will be selected");
		file.WriteLine("//		\"path1\"	\"c5m2_park_1\" -------------> If the plugin chooses the option 1, the file c5m2_park_1.txt will be loaded");
		file.WriteLine("//		\"path2\"	\"c5m2_park_3\" -------------> Same if the option is 2");
		file.WriteLine("//	}");
		file.WriteLine("//");
		file.WriteLine("// If you have any doubts, please check the example_init.txt file or ask on the plugin topic.");
		file.WriteLine("//");
		file.WriteLine("");
		file.WriteLine("\"PathInit\"");
		file.WriteLine("{");
		file.WriteLine("	\"coop\"");
		file.WriteLine("	{");
		file.WriteLine("		");
		file.WriteLine("	}");
		file.WriteLine("	");
		file.WriteLine("	\"versus\"");
		file.WriteLine("	{");
		file.WriteLine("		");
		file.WriteLine("	}");
		file.WriteLine("	");
		file.WriteLine("	\"survival\"");
		file.WriteLine("	{");
		file.WriteLine("		");
		file.WriteLine("	}");
		file.WriteLine("	");
		file.WriteLine("	\"scavenge\"");
		file.WriteLine("	{");
		file.WriteLine("		");
		file.WriteLine("	}");
		file.WriteLine("}");
		FlushFile(file);
		CloseHandle(file);
	}
}

void GetRandomMapPath(char[] MapName, int maxlen)
{
	char FileName[256];
	char sMap[128];
	char GameMode[128];
	GetCurrentMap(sMap, sizeof(sMap));
	BuildPath(Path_SM, FileName, sizeof(FileName), "../stripper/plugin_cache/%s_init.txt", sMap);
	if(!FileExists(FileName))
	{
		LogError("Unable to find the init file!");
	}
	else
	{
		KeyValues keyvalues = new KeyValues("PathInit");
		keyvalues.ImportFromFile(FileName);
		keyvalues.Rewind();
		ConVar cvarGameMode = FindConVar("mp_gamemode");
		cvarGameMode.GetString(GameMode, sizeof(GameMode));
		if(keyvalues.JumpToKey(GameMode))
		{
			char sNumber[11];
			int total_paths = keyvalues.GetNum("total");
			int random = GetRandomInt(1, total_paths);
			Format(sNumber, sizeof(sNumber), "path%i", random);
			keyvalues.GetString(sNumber, MapName, maxlen);
			CloseHandle(keyvalues);
			return;
		}
		else
		{
			LogError("Unable to find the gamemode");
			Format(MapName, maxlen, "invalid");
			CloseHandle(keyvalues);
			return;
		}
		
	}
	Format(MapName, maxlen, "invalid");
	return;
}

public Action CmdMove(int client, int args)
{
	if(args < 2)
	{
		PrintToChat(client, "[SM] 用法: sm_prop_move <轴> <距离> [示例: !prop_move x 30]");
		return Plugin_Handled;
	}
	int Object = g_iLastObject[client];
	char arg1[16];
	char arg2[16];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	float  vecPosition[3];
	GetEntPropVector(Object, Prop_Data, "m_vecOrigin", vecPosition);
	float flPosition = StringToFloat(arg2);
	if(StrEqual(arg1, "x"))
	{
		vecPosition[0] += flPosition;
	}
	else if(StrEqual(arg1, "y"))
	{
		vecPosition[1] += flPosition;
	}
	else if(StrEqual(arg1, "z"))
	{
		vecPosition[2] += flPosition;
	}
	else
	{
		PrintToChat(client, "[SM] 无效的 (请使用x,y,z)");
	}
	g_bGrab[client] = false;
	g_bGrabbed[Object] = false;
	TeleportEntity(Object, vecPosition, NULL_VECTOR, NULL_VECTOR);
	return Plugin_Handled;
}

public Action CmdSetAngles(int client, int args)
{
	if(args < 3)
	{
		PrintToChat(client, "[SM] 用法: sm_prop_setang <X Y Z> [示例: !prop_setang 30 0 34");
		return Plugin_Handled;
	}
	int Object = g_iLastObject[client];
	char arg1[16];
	char arg2[16];
	char arg3[16];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	float  vecAngles[3];
	
	vecAngles[0] = StringToFloat(arg1);
	vecAngles[1] = StringToFloat(arg2);
	vecAngles[2] = StringToFloat(arg3);
	g_vecLastEntityAngles[client] = vecAngles;
	g_vecEntityAngles[Object] = vecAngles;
	
	g_bGrab[client] = false;
	g_bGrabbed[Object] = false;
	TeleportEntity(Object, NULL_VECTOR, vecAngles, NULL_VECTOR);
	return Plugin_Handled;
}

public Action CmdSetPosition(int client, int args)
{
	if(args < 3)
	{
		PrintToChat(client, "[SM] 用法: sm_prop_setpos <X Y Z> [示例: !prop_setpos 505 -34 17");
		return Plugin_Handled;
	}
	int Object = g_iLastObject[client];
	char arg1[16];
	char arg2[16];
	char arg3[16];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	float  vecPosition[3];
	
	vecPosition[0] = StringToFloat(arg1);
	vecPosition[1] = StringToFloat(arg2);
	vecPosition[2] = StringToFloat(arg3);
	TeleportEntity(Object, vecPosition, NULL_VECTOR, NULL_VECTOR);
	return Plugin_Handled;
}

public Action CmdGrab(int client, int args)
{
	if(!g_bGrab[client])
	{
		GrabObject(client);
	}
	else
	{
		ReleaseObject(client);
	}
	return Plugin_Handled;
}

public Action CmdGrabLook(int client, int args)
{
	if(!g_bGrab[client])
	{
		GrabLookingObject(client);
	}
	else
	{
		ReleaseLookingObject(client);
	}
	return Plugin_Handled;
}

void GrabObject(int client)
{
	int Object = g_iLastObject[client];
	if(g_bGrab[client])
	{
		PrintToChat(client, "[SM] 你已经抓取了物体");
		return;
	}
	else if(g_bGrabbed[Object])
	{
		PrintToChat(client, "[SM] 上个物体已经移动");
		return;
	}
	if(Object > 0 && IsValidEntity(Object))
	{
		char class[256];
		GetEdictClassname(Object, class, sizeof(class));
		if(StrEqual(class, "prop_physics")
		|| StrEqual(class, "prop_dynamic")
		|| StrEqual(class, "prop_physics_override")
		|| StrEqual(class, "prop_dynamic_override"))
		{
			g_bGrab[client] = true;
			g_bGrabbed[Object] = true;
			PrintToChat(client, "[SM] 你正在抓取一个物体");
			
			float position[3];
			GetEntPropVector(Object, Prop_Send, "m_vecOrigin", position);
			PrintToChat(client, "[SM] 物体坐标 %f, %f, %f.", position[0], position[1], position[2]);
			
			char sName[64];
			char sObjectName[64];
			int userid = GetClientUserId(client);
			Format(sName, sizeof(sName), "%d", userid+25);
			Format(sObjectName, sizeof(sObjectName), "%d", Object+100);
			DispatchKeyValue(Object, "targetname", sObjectName);
			DispatchKeyValue(client, "targetname", sName);
			GetEntPropString(client, Prop_Data, "m_iName", sName, sizeof(sName));
			DispatchKeyValue(Object, "parentname", sName);
			SetVariantString(sName);
			AcceptEntityInput(Object, "SetParent", Object, Object);
			SetEntityRenderColor(Object, 189, 9 , 13, 100);
			return;
		}
		else
		{
			PrintToChat(client, "[SM] 上一个生成的物体索引%i不再是一个物体!", Object);
			g_bGrabbed[Object] = false;
			g_iLastObject[client] = -1;
			g_vecLastEntityAngles[client][0] = 0.0;
			g_vecLastEntityAngles[client][1] = 0.0;
			g_vecLastEntityAngles[client][2] = 0.0;
			g_bSpawned[Object] = false;
			g_bUnsolid[Object] = false;
			g_vecEntityAngles[Object][0] = 0.0;
			g_vecEntityAngles[Object][1] = 0.0;
			g_vecEntityAngles[Object][2] = 0.0;
			g_bGrab[client] = false;
		}
	}
	else if(Object > 0 && !IsValidEntity(Object))
	{
		PrintToChat(client, "[SM] 上一个物体不再有效");
	}
	else if(Object <= 0)
	{
		PrintToChat(client, "[SM] 你还没有生成任何物体");
	}
}

void ReleaseObject(int client)
{
	int Object = g_iLastObject[client];
	if(Object > 0 && IsValidEntity(Object))
	{
		char class[256];
		GetEdictClassname(Object, class, sizeof(class));
		if(StrEqual(class, "prop_physics")
		|| StrEqual(class, "prop_dynamic")
		|| StrEqual(class, "prop_physics_override")
		|| StrEqual(class, "prop_dynamic_override"))
		{
			g_bGrab[client] = false;
			g_bGrabbed[Object] = false;
			PrintToChat(client, "[SM] 你不在抓取物体");
			DispatchKeyValue(Object, "targetname", "l4d2_spawn_props_prop");
			DispatchKeyValue(Object, "parentname", "NULL_PARENT");
			SetEntityRenderColor(Object, 255, 255 ,255, 255);
			AcceptEntityInput(Object, "SetParent");
			
			//Set client angles
			float  vecAngles[3];
			GetClientEyeAngles(client, vecAngles);
			g_vecLastEntityAngles[client][0] = vecAngles[0];
			g_vecLastEntityAngles[client][1] = vecAngles[1];
			g_vecLastEntityAngles[client][2] = vecAngles[2];
			g_vecEntityAngles[Object][0] = vecAngles[0];
			g_vecEntityAngles[Object][1] = vecAngles[1];
			g_vecEntityAngles[Object][2] = vecAngles[2];
			return;
		}
		else
		{
			PrintToChat(client, "[SM] 上一个生成的物体索引%i不再是一个物体!", Object);
			g_bGrabbed[Object] = false;
			g_iLastObject[client] = -1;
			g_vecLastEntityAngles[client][0] = 0.0;
			g_vecLastEntityAngles[client][1] = 0.0;
			g_vecLastEntityAngles[client][2] = 0.0;
			g_bSpawned[Object] = false;
			g_bUnsolid[Object] = false;
			g_vecEntityAngles[Object][0] = 0.0;
			g_vecEntityAngles[Object][1] = 0.0;
			g_vecEntityAngles[Object][2] = 0.0;
			g_bGrab[client] = false;
		}
	}
	else if(Object > 0 && !IsValidEntity(Object))
	{
		PrintToChat(client, "[SM] 上一个生成的物体不再有效");
	}
	else if(Object <= 0)
	{
		PrintToChat(client, "[SM] 你还没生成任何物体");
	}
}

void GrabLookingObject(int client)
{
	int Object = GetLookingObject(client);
	if(Object >= ARRAY_SIZE)
	{
		PrintToChat(client, "[SM] 找不到有效的物体");
		return;
	}
	if(g_bGrab[client])
	{
		PrintToChat(client, "[SM] 你已经在抓取物体");
		return;
	}
	if(Object > 0 && IsValidEntity(Object))
	{
		char class[256];
		GetEdictClassname(Object, class, sizeof(class));
		if(StrEqual(class, "prop_physics")
		|| StrEqual(class, "prop_dynamic")
		|| StrEqual(class, "prop_physics_override")
		|| StrEqual(class, "prop_dynamic_override"))
		{
			g_bGrab[client] = true;
			g_bGrabbed[Object] = true;
			g_iLastGrabbedObject[client] = Object;
			PrintToChat(client, "[SM] 你现在正在抓取一个物体");
			float position[3];
			GetEntPropVector(Object, Prop_Send, "m_vecOrigin", position);
			PrintToChat(client, "[SM] 物体坐标 %f, %f, %f.", position[0], position[1], position[2]);
			
			char sName[64];
			char sObjectName[64];
			int userid = GetClientUserId(client);
			Format(sName, sizeof(sName), "%d", userid+25);
			Format(sObjectName, sizeof(sObjectName), "%d", Object+100);
			DispatchKeyValue(Object, "targetname", sObjectName);
			DispatchKeyValue(client, "targetname", sName);
			GetEntPropString(client, Prop_Data, "m_iName", sName, sizeof(sName));
			DispatchKeyValue(Object, "parentname", sName);
			SetVariantString(sName);
			AcceptEntityInput(Object, "SetParent", Object, Object);
			SetEntityRenderColor(Object, 189, 9 , 13, 100);
			return;
		}
		else
		{
			PrintToChat(client, "[SM] 上一个生成的物体索引%i不再是物体", Object);
			g_bGrabbed[Object] = false;
			g_bSpawned[Object] = false;
			g_bUnsolid[Object] = false;
			g_vecEntityAngles[Object][0] = 0.0;
			g_vecEntityAngles[Object][1] = 0.0;
			g_vecEntityAngles[Object][2] = 0.0;
			g_bGrab[client] = false;
		}
	}
	else if(Object > 0 && !IsValidEntity(Object))
	{
		PrintToChat(client, "[SM] 上一个对象不再有效");
	}
	else if(Object <= 0)
	{
		PrintToChat(client, "[SM] 你还没生成任何物体");
	}
}

void ReleaseLookingObject(int client)
{
	int Object = g_iLastGrabbedObject[client];
	if(Object > 0 && IsValidEntity(Object))
	{
		char class[256];
		GetEdictClassname(Object, class, sizeof(class));
		if(StrEqual(class, "prop_physics")
		|| StrEqual(class, "prop_dynamic")
		|| StrEqual(class, "prop_physics_override")
		|| StrEqual(class, "prop_dynamic_override"))
		{
			g_bGrab[client] = false;
			g_bGrabbed[Object] = false;
			PrintToChat(client, "[SM] You are no longer grabbing an object");
			DispatchKeyValue(Object, "targetname", "l4d2_spawn_props_prop");
			DispatchKeyValue(Object, "parentname", "NULL_PARENT");
			SetEntityRenderColor(Object, 255, 255 ,255, 255);
			AcceptEntityInput(Object, "SetParent");
			
			//Set client angles
			float  vecAngles[3];
			GetClientEyeAngles(client, vecAngles);
			g_vecEntityAngles[Object][0] = vecAngles[0];
			g_vecEntityAngles[Object][1] = vecAngles[1];
			g_vecEntityAngles[Object][2] = vecAngles[2];
			return;
		}
		else
		{
			PrintToChat(client, "[SM] 上一个生成的物体索引%i不再是物体!", Object);
			g_bGrabbed[Object] = false;
			g_bSpawned[Object] = false;
			g_bUnsolid[Object] = false;
			g_vecEntityAngles[Object][0] = 0.0;
			g_vecEntityAngles[Object][1] = 0.0;
			g_vecEntityAngles[Object][2] = 0.0;
			g_bGrab[client] = false;
		}
	}
	else if(Object > 0 && !IsValidEntity(Object))
	{
		PrintToChat(client, "[SM] 上一个物体不再有效");
	}
	else if(Object <= 0)
	{
		PrintToChat(client, "[SM] 你还没生成任何物体");
	}
}

int GetLookingObject(int client)
{
	float  VecOrigin[3];
	float VecAngles[3];
	GetClientEyePosition(client, VecOrigin);
	GetClientEyeAngles(client, VecAngles);
	TR_TraceRayFilter(VecOrigin, VecAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
	if(TR_DidHit(null))
	{
		int Object = TR_GetEntityIndex(null);
		if(Object > 0 && IsValidEntity(Object) && IsValidEdict(Object))
		{
			char class[256];
			GetEdictClassname(Object, class, sizeof(class));
			if(StrEqual(class, "prop_physics")
			|| StrEqual(class, "prop_dynamic")
			|| StrEqual(class, "prop_physics_override")
			|| StrEqual(class, "prop_dynamic_override"))
			{
				return Object;
			}
		}
	}
	return -1;
}

/*
////////////////////////////////////////////////////////////////////////////|
						Build File Directories							    |
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\|
*/

public void BuildFileDirectories()
{
	for(int Num; Num < sizeof(FolderNames); Num++)
	{
		if(!DirExists(FolderNames[Num]))
		{
			CreateDirectory(FolderNames[Num], 509);
		}
	}
}