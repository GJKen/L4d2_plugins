/*
 *	v1.1.2
 *
 *	1:更换为动态数组.
 *
 *	v1.2.2
 *
 *	1:增加女巫死亡类型(建议在 HookEvent("witch_killed") 事件里使用,因为其它事件太早了).
 *
 *	v1.2.3
 *
 *	1:使用下一帧重置记录的数据,秒杀和爆头女巫提示写反了.
 *
 *	v1.2.4
 *
 *	1:击杀类型重置错了数据值,虽然没啥影响.
 *
 *	v1.2.5
 *
 *	1:女巫死亡事件 HookEvent("witch_killed", EventHookMode_Pre; 里获取和写入击杀类型.
 *	2:女巫死亡事件 HookEvent("witch_killed", EventHookMode_Post; 里延迟一帧删除储存的击杀类型.
 */

#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define PLUGIN_VERSION	"1.2.5"

bool g_bLateLoad;

ArrayList g_hWitchDeath;

enum struct IsWitchDeath
{
	int iIndex;
	int oneshot;
}
IsWitchDeath g_iWitchDeath;

public Plugin myinfo = 
{
	name 			= "l4d2_GetWitchNumber",
	author 			= "豆瓣酱な",
	description 	= "给女巫添加自定义编号,例如:witch(1)",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}
/*
** 该功能嫖至作者 NiCo-op, Edited By Ernecio (Satanael) 的,链接没找到.
*/
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GetWitchNumber", GetNativeWitchNumber);
	CreateNative("GetWitchkilled", GetNativeWitchkilled);
	RegPluginLibrary("l4d2_GetWitchNumber");
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hWitchDeath = new ArrayList(sizeof(IsWitchDeath));

	HookEvent("round_start",  Event_RoundStart);//回合开始.
	HookEvent("witch_spawn",  Event_WitchSpawn, EventHookMode_Pre);//女巫出现.
	HookEvent("witch_killed", Event_WitchkilledPre, EventHookMode_Pre);//女巫死亡(记录女巫死亡的类型).
	HookEvent("witch_killed", Event_WitchkilledPost);//女巫死亡(延迟一帧删除女巫死亡的类型).
	HookEvent("player_death", Event_PlayerDeath);//玩家死亡(记录女巫死亡的类型).

	if(g_bLateLoad)//如果插件延迟加载.
	{
		int iWitchid = -1;
		while ((iWitchid = FindEntityByClassname(iWitchid, "witch")) != INVALID_ENT_REFERENCE)
		{
			g_iWitchDeath.iIndex = iWitchid;
			g_iWitchDeath.oneshot = -1;
			g_hWitchDeath.PushArray(g_iWitchDeath);
		}
	}
}
public void Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	g_hWitchDeath.Clear();//清除数组内容.
}
public void Event_WitchSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	int iWitchid = event.GetInt( "witchid");

	if (IsValidEdict(iWitchid))
	{
		int iNumber = GetWitchNumber(-1);
		
		g_iWitchDeath.iIndex = iWitchid;
		g_iWitchDeath.oneshot = -1;

		if(iNumber != -1)//获取到空位置.
			g_hWitchDeath.SetArray(iNumber, g_iWitchDeath);//指定位置写入数据.
		else
			g_hWitchDeath.PushArray(g_iWitchDeath);//把数据推送的数组末尾.
	}
}
//实体删除.
public void OnEntityDestroyed(int iEntity)
{
	if(IsValidEdict(iEntity))
	{
		static char sEntity[64];
		GetEntityClassname(iEntity, sEntity, sizeof(sEntity));
		if(strcmp(sEntity,"witch") == 0)
		{
			int iNumber = GetWitchNumber(iEntity);

			if(iNumber != -1)
			{
				g_iWitchDeath.iIndex = -1;
				g_iWitchDeath.oneshot = -1;
				g_hWitchDeath.SetArray(iNumber, g_iWitchDeath);
			}
		}
	}
}
//玩家死亡.
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	char classname[32];
	int iWitchid = event.GetInt("entityid");
	GetEdictClassname(iWitchid, classname, sizeof(classname));
	
	if (IsValidEdict(iWitchid) && strcmp(classname, "witch") == 0)
	{
		int iNumber = GetWitchNumber(iWitchid);

		if(iNumber != -1)
		{
			g_iWitchDeath.oneshot = event.GetBool("headshot") ? 1 : 0;
			g_hWitchDeath.SetArray(iNumber, g_iWitchDeath);
		}
	}
}
public void Event_WitchkilledPre(Event event, const char[] name, bool dontBroadcast)
{
	int iWitchid = event.GetInt("witchid");

	if (IsValidEdict(iWitchid))
	{
		int iNumber = GetWitchNumber(iWitchid);

		if(iNumber != -1)
		{
			g_iWitchDeath.oneshot = event.GetBool("oneshot") ? 2 : g_iWitchDeath.oneshot;
			g_hWitchDeath.SetArray(iNumber, g_iWitchDeath);
		}
	}
}
public void Event_WitchkilledPost(Event event, const char[] name, bool dontBroadcast)
{
	int iWitchid = event.GetInt("witchid");

	if (IsValidEdict(iWitchid))
		RequestFrame(IsWitchDeathType, EntIndexToEntRef(iWitchid));//
}

void IsWitchDeathType(any iEntity)
{
	int iWitchid = EntRefToEntIndex(iEntity);
	int iNumber = GetWitchNumber(iWitchid);

	if(iNumber != -1)
	{
		g_iWitchDeath.iIndex = -1;
		g_iWitchDeath.oneshot = -1;
		g_hWitchDeath.SetArray(iNumber, g_iWitchDeath);
	}
}
//获取自定义的女巫编号.
int GetNativeWitchNumber(Handle plugin, int numParams)
{
	return GetWitchNumber(GetNativeCell(1));
}
//获取女巫的死亡类型(秒杀,爆头,击杀).
/* 建议在 HookEvent("witch_killed") 事件里使用此Native */
int GetNativeWitchkilled(Handle plugin, int numParams)
{
	int iWitchid = GetNativeCell(1);
	int iNumber = GetWitchNumber(iWitchid);
	int maxlength = GetNativeCell(3);
	char[] sDeathType = new char[maxlength];
	//GetNativeString(2, sNumber, maxlength);
	g_hWitchDeath.GetArray(iNumber, g_iWitchDeath);
	
	int iDeathType = g_iWitchDeath.oneshot;

	switch (iDeathType)
	{
		case 0:
		{
			strcopy(sDeathType, maxlength, "击杀");
		}
		case 1:
		{
			strcopy(sDeathType, maxlength, "爆头");
		}
		case 2:
		{
			strcopy(sDeathType, maxlength, "秒杀");
		}
		default:
		{
			strcopy(sDeathType, maxlength, "击杀");
		}
	}
	SetNativeString(2, sDeathType, maxlength);
	return iDeathType;
}
//获取自定义的女巫编号.
int GetWitchNumber(int iWitchid)
{
	for(int i = 0; i < g_hWitchDeath.Length; i ++)
	{
		g_hWitchDeath.GetArray(i, g_iWitchDeath);
		if(g_iWitchDeath.iIndex == iWitchid)
			return i;
	}
	return -1;
}