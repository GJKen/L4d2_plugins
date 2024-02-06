#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

bool CanRm;
ConVar pillsLimit;

public Plugin myinfo = 
{
	name 			= "Remove And Replace kits",
	author 			= "kita",
	description 	= "玩家离开安全区域后移除(非救援)或者替换(救援)已经缓存在地图上的急救包,限制药的数量值",
	version 		= "1.0",
	url 			= "问就是复制粘贴来的"
}

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_MissionLost, EventHookMode_Post);
	pillsLimit = CreateConVar("l4d2_pillsLimit", "4", "限制药最多出现数量");
}

public void OnMapStart()
{
	CanRm = false;
}

public void OnMapEnd()
{
	CanRm = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CanRm = false;
}

void Event_PlayerLeftSafeArea(Event event, const char[] name, bool dontBroadcast)
{
	CanRm = true;
	CreateTimer(3.0, RoundStartTimer);
}

void Event_MissionLost(Event event, const char [] name, bool dontBroadcast)
{
	CanRm = false;
}

public Action RoundStartTimer(Handle timer)
{
	RemoveOrReplaceKits();
	return Plugin_Continue;
}



public Action RemoveOrReplaceKits()
{
	int pillsCount = 0;
	ArrayList arrPills = new ArrayList(1);
	ArrayList arrMed = new ArrayList(1);
	ArrayList arrDef = new ArrayList(1);
	for (int entity = 1; entity <= GetEntityCount(); entity++)
	{
		if (IsValidEntity(entity) && IsValidEdict(entity))
		{
			char entityname[128];
			GetEdictClassname(entity, entityname, sizeof(entityname));
			if (strcmp(entityname, "weapon_spawn") == 0)
			{
				if (GetEntProp(entity, Prop_Data, "m_weaponID") == 12)
				{
					arrMed.Push(entity);
				}
				if (GetEntProp(entity, Prop_Data, "m_weaponID") == 15)
				{
					arrPills.Push(entity);
				}		
				if (GetEntProp(entity, Prop_Data, "m_weaponID") == 24)
				{
					arrDef.Push(entity);
				}
			}
			else
			{
				if (strcmp(entityname, "weapon_first_aid_kit_spawn") == 0)
				{
					arrMed.Push(entity);
				}
				if (strcmp(entityname, "weapon_pain_pills_spawn") == 0)
				{
					arrPills.Push(entity);
				}
				if (strcmp(entityname, "weapon_defibrillator_spawn") == 0)
				{
					arrDef.Push(entity);
				}
			}
		}
	}
	if(L4D_IsMissionFinalMap())
	{
		while(arrMed.Length)
		{
			if(pillsCount >= pillsLimit.IntValue)
			{
				RemoveItem(arrMed.Get(0));
			}	
			else
			{
				ReplaceItem(arrMed.Get(0));
				pillsCount ++;
			}
			arrMed.Erase(0);
		}
		while(arrPills.Length)
		{
			if(pillsCount >= pillsLimit.IntValue)
			{
				RemoveItem(arrPills.Get(0));
			}	
			else
			{
				ReplaceItem(arrPills.Get(0));
				pillsCount ++;
			}
			arrPills.Erase(0);
		}
	}
	else
	{
		while(arrPills.Length)
		{
			if(pillsCount > pillsLimit.IntValue)
			{
				RemoveItem(arrPills.Get(0));
			}	
			else
			{
				ReplaceItem(arrPills.Get(0));
				pillsCount ++;
			}
			arrPills.Erase(0);
		}
		while(arrMed.Length)
		{
			if(pillsCount > pillsLimit.IntValue)
			{
				RemoveItem(arrMed.Get(0));
			}	
			else
			{
				ReplaceItem(arrMed.Get(0));
				pillsCount ++;
			}
			arrMed.Erase(0);
		}
	}
	while(arrDef.Length)
	{
		if(pillsCount > pillsLimit.IntValue)
		{
			RemoveItem(arrDef.Get(0));
		}	
		else
		{
			ReplaceItem(arrDef.Get(0));
			pillsCount ++;
		}
		arrDef.Erase(0);
	}
	delete arrDef, arrPills, arrMed;
	return Plugin_Continue;
}

stock int GetPillsCount()
{
	int pillsCount = 0;
	for (int entity = 1; entity <= GetEntityCount(); entity++)
	{
		if (IsValidEntity(entity) && IsValidEdict(entity))
		{
			char entityname[128];
			GetEdictClassname(entity, entityname, sizeof(entityname));
			if (strcmp(entityname, "weapon_spawn") == 0)
			{
				if (GetEntProp(entity, Prop_Data, "m_weaponID") == 15)
				{
					pillsCount++;
				}

			}
			else
			{
				if (strcmp(entityname, "weapon_pain_pills_spawn") == 0)
				{
					pillsCount++;
				}
			}
		}
	}
	return pillsCount;
}

public Action ReplaceKits()
{
	for (int entity = 1; entity <= GetEntityCount(); entity++)
	{
		if (IsValidEntity(entity) && IsValidEdict(entity))
		{
			char entityname[128];
			GetEdictClassname(entity, entityname, sizeof(entityname));
			if (strcmp(entityname, "weapon_spawn") == 0)
			{
				if (GetEntProp(entity, Prop_Data, "m_weaponID") == 12)
				{
					ReplaceItem(entity);
				}
				if (GetEntProp(entity, Prop_Data, "m_weaponID") == 24)
				{
					RemoveItem(entity);
				}
			}
			else
			{
				if (strcmp(entityname, "weapon_first_aid_kit_spawn") == 0)
				{
					ReplaceItem(entity);
				}
				if (strcmp(entityname, "weapon_defibrillator_spawn") == 0)
				{
					RemoveItem(entity);
				}
			}
		}
	}
	return Plugin_Continue;
}

void ReplaceItem(int entity)
{
	float fPos[3], fAngles[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", fPos);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", fAngles);
	// 获取原来位置医疗包的位置与角度，先清除原来位置的医疗包
	RemoveEdict(entity);
	int iPills = CreateEntityByName("weapon_spawn");
	SetEntProp(iPills, Prop_Data, "m_weaponID", 15);
	DispatchKeyValue(iPills, "count", "1");
	TeleportEntity(iPills, fPos, fAngles, NULL_VECTOR);
	DispatchSpawn(iPills);
	SetEntityMoveType(iPills, MOVETYPE_NONE);
}

void RemoveItem(int entity)
{
	RemoveEdict(entity);
}


/*=================================================================
修复基于战役的药役模式中，生还血量阈值低时导演系统自动刷包
此功能仅仅用于离开安全区域后将所有后续生成的包全部移除
==================================================================*/

public void OnEntityCreated(int entity, const char[] classname)
{
	if(strcmp(classname, "weapon_spawn") == 0) 
	{
		if(CanRm == true)
		{
			SDKHook(entity, SDKHook_Spawn, on_weapon_sapwn);
		}
	}
	else
	{
		if(strcmp(classname, "weapon_first_aid_kit_spawn") == 0)
		{
			if(CanRm == true)
			{
				SDKHook(entity, SDKHook_Spawn, Remove_Medical);
			}
		}
	}
}

public Action Remove_Medical(int entity)
{
	RemoveEntity(entity);
	return Plugin_Continue;
}

public Action on_weapon_sapwn(int entity)
{
	RequestFrame(RemoveThing, EntIndexToEntRef(entity));
	return Plugin_Continue;
}

public void RemoveThing(int ref)
{
	int entity = EntRefToEntIndex(ref);
	if(entity != -1 && GetEntProp(entity, Prop_Data, "m_weaponID") == 12)
	{
		RemoveEntity(entity);
	}
}


