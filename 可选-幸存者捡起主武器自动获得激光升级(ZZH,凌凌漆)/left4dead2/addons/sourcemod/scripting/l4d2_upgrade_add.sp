//每行代码结束需填写“;”
#pragma semicolon 1
//强制新语法
#pragma newdecls required
//加载需要的头文件
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

EngineVersion g_eGame; 

//定义插件信息
#define NAME 			"L4D2 Primary Weapon Upgrades Plugin | L4D2主武器升级插件" //定义插件名字
#define AUTHOR 			"ZZH | 凌凌漆" //定义作者
#define DESCRIPTION 	"L4D2 Primary Weapon Upgrades Plugin | L4D2主武器升级插件"	//定义插件描述
#define	VERSION 		"1.0.0.0" //定义插件版本
#define URL 			"https://steamcommunity.com/id/ChengChiHou/" //定义作者联系地址

/* Weapon upgrade bit flags */
#define L4D2_WEPUPGFLAG_NONE            (0 << 0) //无
#define L4D2_WEPUPGFLAG_INCENDIARY      (1 << 0) //燃烧子弹
#define L4D2_WEPUPGFLAG_EXPLOSIVE       (1 << 1) //爆炸子弹
#define L4D2_WEPUPGFLAG_LASER           (1 << 2) //激光瞄准器

int    g_iUpgradeAddSwitch, g_iUpgradeAddDefault;
ConVar g_hUpgradeAddSwitch, g_hUpgradeAddDefault;

bool g_bUpgradeAddSwitch, g_bUpgradeAddDefault;

//写入插件信息
public Plugin myinfo =
{
	name			=	NAME,
	author			=	AUTHOR,
	description		=	DESCRIPTION,
	version			=	VERSION,
	url				=	URL
};

//插件加载
public void OnPluginStart()
{
	g_eGame = GetEngineVersion(); //获取游戏版本
	if(g_eGame != Engine_Left4Dead2) //如果游戏版本不等于L4D和L4D2
		SetFailState("This plugin only for L4D2 | 此插件仅适用于L4D2"); //设置插件失效，并说明失效原因
	
	RegConsoleCmd("sm_laser", l4d2_upgrade_add_on, "管理员开启或关闭幸存者自动获得激光升级.");
	
	g_hUpgradeAddSwitch		= CreateConVar("l4d2_enabled_add_laser_sight_switch", "1", "启用幸存者捡起武器或物品自动获得激光升级? (指令 !laser 关闭或开启) 0=禁用, 1=启用.");
	g_hUpgradeAddDefault	= CreateConVar("l4d2_enabled_add_laser_sight_default", "1", "设置幸存者默认获得激光升级? 0=默认关闭自动获得激光, 1=默认开启自动获得激光.");
	g_hUpgradeAddSwitch.AddChangeHook(IsUpgradeAddConVarChanged);
	g_hUpgradeAddDefault.AddChangeHook(IsUpgradeAddConVarChanged);
	AutoExecConfig(true, "l4d2_upgrade_add");//生成指定文件名的CFG.
}

public void OnMapStart()
{
	IsUpgradeAddCvars();
}

public void IsUpgradeAddConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsUpgradeAddCvars();
}

void IsUpgradeAddCvars()
{
	g_iUpgradeAddSwitch		= g_hUpgradeAddSwitch.IntValue;
	g_iUpgradeAddDefault	= g_hUpgradeAddDefault.IntValue;
}

public void OnConfigsExecuted()
{
	if(!g_bUpgradeAddDefault)
	{
		switch (g_iUpgradeAddDefault)
		{
			case 0:
				g_bUpgradeAddSwitch = false;
			case 1:
				g_bUpgradeAddSwitch = true;
		}
	}
}

public Action l4d2_upgrade_add_on(int client, int args)
{
	if(bCheckClientAccess(client))
	{
		switch (g_iUpgradeAddDefault)
		{
			case 0:
			{
				PrintToChat(client, "\x04[提示]\x05幸存者捡起主武器自动获得激光升级已禁用,请在CFG中设为1启用.");
			}
			case 1:
			{
				if (g_bUpgradeAddSwitch)
				{
					g_bUpgradeAddSwitch = false;
					g_bUpgradeAddDefault = true;
					PrintToChatAll("\x04[提示]\x03已关闭\x05幸存者捡起主武器自动获得激光升级.");
					
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && GetClientTeam(i) == 2)
						{
							int weapon = GetPlayerWeaponSlot(i, 0);
							IsRemoveAutomaticLaser(weapon);
						}
					}
				}
				else
				{
					g_bUpgradeAddSwitch = true;
					g_bUpgradeAddDefault = true;
					PrintToChatAll("\x04[提示]\x03已开启\x05幸存者捡起主武器自动获得激光升级.");
					
					for (int i = 1; i <= MaxClients; i++)
						if(IsClientInGame(i) && GetClientTeam(i) == 2)
							IsPlayerWeaponEquip(client);
				}
			}
		}
	}
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

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, OnClientWeaponEquip);//幸存者的主武器自动获得激光.
	SDKHook(client, SDKHook_WeaponDropPost, OnClientWeaponDrop);//删除幸存者主武器的激光.
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_WeaponEquipPost, OnClientWeaponEquip);//幸存者的主武器自动获得激光.
	SDKUnhook(client, SDKHook_WeaponDropPost, OnClientWeaponDrop);//删除幸存者主武器的激光.
}

//幸存者的主武器自动获得激光.
public void OnClientWeaponEquip(int client, int weapon)
{
	if (!g_iUpgradeAddSwitch)
		return;

	if (!g_bUpgradeAddSwitch)
		return;

	if (IsValidClient(client) && GetClientTeam(client) == 2)
		IsPlayerWeaponEquip(client);
}

void IsPlayerWeaponEquip(int client)
{
	int iWeapon = GetPlayerWeaponSlot(client, 0); // Get primary weapon
	if(iWeapon > 0 && IsValidEdict(iWeapon) && IsValidEntity(iWeapon))
	{
		char netclass[128];
		GetEntityNetClass(iWeapon, netclass, sizeof(netclass));
		if(FindSendPropInfo(netclass, "m_upgradeBitVec") < 1)
			return; // This weapon does not support iUpgrades

		int iUpgrades = IsGetWeaponUpgrades(iWeapon); // Get iUpgrades of primary weapon
		if(iUpgrades & L4D2_WEPUPGFLAG_LASER)
			return; // Primary weapon already have laser sight, return
		
		IsSetWeaponUpgrades(iWeapon, iUpgrades | L4D2_WEPUPGFLAG_LASER); // Add laser sight to primary weapon
	}
}

//删除幸存者主武器的激光.
public void OnClientWeaponDrop(int client, int weapon)
{
	if (IsValidClient(client) && GetClientTeam(client) == 2)
		IsRemoveAutomaticLaser(weapon);
}

void IsRemoveAutomaticLaser(int iWeapon)
{
	if(iWeapon > 0 && IsValidEdict(iWeapon) && IsValidEntity(iWeapon))
	{
		char netclass[128];
		GetEntityNetClass(iWeapon, netclass, sizeof(netclass));
		if(FindSendPropInfo(netclass, "m_upgradeBitVec") < 1)
			return; // This weapon does not support iUpgrades

		int iUpgrades = IsGetWeaponUpgrades(iWeapon); // Get iUpgrades of dropped iWeapon
		if(!(iUpgrades & L4D2_WEPUPGFLAG_LASER))
			return; // iWeapon did not have laser sight, return
		
		IsSetWeaponUpgrades(iWeapon, iUpgrades ^ L4D2_WEPUPGFLAG_LASER); // Remove laser sight from iWeapon
	}
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}

int IsGetWeaponUpgrades(int weapon)
{
	return GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
}

void IsSetWeaponUpgrades(int weapon, int upgrades)
{
	SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", upgrades);
}