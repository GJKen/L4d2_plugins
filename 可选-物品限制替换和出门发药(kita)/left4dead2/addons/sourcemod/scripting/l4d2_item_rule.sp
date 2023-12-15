#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <l4d2_weapons_spawn> // https://github.com/fdxx/l4d2_plugins/blob/main/include/l4d2_weapons_spawn.inc

#define VERSION "1.3"

StringMap
	g_smModelToName,
	g_smItemReplace,
	g_smItemLimit;

ConVar
	g_cvFinalPills,
	g_cvStartItems,
	g_cvRemoveBox;

bool
	g_bFinalMap,
	g_bFinalPills,
	g_bRemoveBox;
	
char g_sStartItems[512];
ArrayList g_aEnt;
KeyValues g_kv;

enum struct EntityData
{
	int entity;
	char sName[64];
}

public Plugin myinfo = 
{
	name = "L4D2 Item rule",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	Init();

	CreateConVar("l4d2_item_rule_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvFinalPills = CreateConVar("l4d2_item_rule_finalmap_pills", "1", "Replace final map medkit with pills.");
	g_cvRemoveBox = CreateConVar("l4d2_item_rule_remove_box", "1", "remove item box");
	g_cvStartItems = CreateConVar("l4d2_item_rule_start_items", "health;ammo", "give start items");

	OnConVarChanged(null, "", "");

	g_cvFinalPills.AddChangeHook(OnConVarChanged);
	g_cvRemoveBox.AddChangeHook(OnConVarChanged);
	g_cvStartItems.AddChangeHook(OnConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);

	RegAdminCmd("sm_item_rule_reload", Cmd_Reload, ADMFLAG_ROOT);
	RegAdminCmd("sm_item_limit_test", Cmd_LimitTest, ADMFLAG_ROOT);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bFinalPills = g_cvFinalPills.BoolValue;
	g_bRemoveBox = g_cvRemoveBox.BoolValue;
	g_cvStartItems.GetString(g_sStartItems, sizeof(g_sStartItems));
}

void Init()
{
	char sBuffer[PLATFORM_MAX_PATH];
	char sItem[64], sNewItem[64];
	int iLimit;

	delete g_smModelToName;
	delete g_smItemReplace;
	delete g_smItemLimit;
	delete g_kv;
	delete g_aEnt;

	g_smModelToName = new StringMap();
	g_smItemReplace = new StringMap();
	g_smItemLimit = new StringMap();
	g_kv = new KeyValues("");
	g_aEnt = new ArrayList(sizeof(EntityData));
	
	for (int i; i < sizeof(g_sWeapons); i++)
	{
		strcopy(sBuffer, sizeof(sBuffer), g_sWeapons[i][WEAPON_MODEL]);
		CharToLowerCase(sBuffer, strlen(sBuffer));
		g_smModelToName.SetString(sBuffer, g_sWeapons[i][WEAPON_NAME]);
	}

	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "data/l4d2_item_rule.cfg");
	if (!g_kv.ImportFromFile(sBuffer))
		SetFailState("Failed to load l4d2_item_rule.cfg");

	// 保存物品替换数据
	if (g_kv.JumpToKey("item_replace") && g_kv.GotoFirstSubKey(false))
	{
		do
		{
			g_kv.GetSectionName(sItem, sizeof(sItem));
			g_kv.GetString(NULL_STRING, sNewItem, sizeof(sNewItem));
			if (sNewItem[0] != '\0')
				g_smItemReplace.SetString(sItem, sNewItem);
		}
		while (g_kv.GotoNextKey(false));
	}

	g_kv.Rewind();

	// 保存物品限制数据
	if (g_kv.JumpToKey("item_limit") && g_kv.GotoFirstSubKey(false))
	{
		do
		{
			g_kv.GetSectionName(sItem, sizeof(sItem));
			iLimit = g_kv.GetNum(NULL_STRING, -1);
			if (iLimit >= 0)
				g_smItemLimit.SetValue(sItem, iLimit);
		}
		while (g_kv.GotoNextKey(false));
	}
}

public void OnMapStart()
{
	L4D2Wep_PrecacheModel();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.3, RoundStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action RoundStart_Timer(Handle timer)
{
	g_bFinalMap = L4D_IsMissionFinalMap();

	RemoveItemBox();
	EntityHandling();
	EntityLimit();
	C4WeaponSpawn();

	return Plugin_Continue;
}

void Event_PlayerLeftSafeArea(Event event, const char[] name, bool dontBroadcast)
{
	RemoveItemBox();
	EntityHandling();
	EntityLimit();
	GiveStartItem();
}

// C6地图上大量物品的箱子
void RemoveItemBox()
{
	if (!g_bRemoveBox)
		return;

	static int iButton, iBox;
	static char sBoxModel[PLATFORM_MAX_PATH];

	iButton = -1;
	while ((iButton = FindEntityByClassname(iButton, "func_button")) != -1)
	{
		iBox = GetEntPropEnt(iButton, Prop_Send, "m_glowEntity");
		if (iBox > MaxClients && IsValidEntity(iBox))
		{
			if (GetEntPropString(iBox, Prop_Data, "m_ModelName", sBoxModel, sizeof(sBoxModel)) > 1)
			{
				if (!strcmp(sBoxModel, "models/props_waterfront/footlocker01.mdl", false))
				{
					RemoveEntity(iButton);
					RemoveEntity(iBox);
				}
			}
		}
	}
}

void EntityHandling()
{
	static int iLimit;
	static EntityData data;
	static char sClass[64], sItem[64], sNewItem[64], sModel[PLATFORM_MAX_PATH];

	g_aEnt.Clear();

	for (int i = MaxClients+1; i < 2049; i++)
	{
		if (IsValidEntity(i) && GetEdictClassname(i, sClass, sizeof(sClass)))
		{
			if (sClass[0] != 'w' && sClass[0] != 'p' && sClass[0] != 'u')
				continue;

			if (IsCarriedByClient(i))
				continue;
				
			if (GetEntPropString(i, Prop_Data, "m_ModelName", sModel, sizeof(sModel)) > 1)
			{
				CharToLowerCase(sModel, strlen(sModel));
				if (g_smModelToName.GetString(sModel, sItem, sizeof(sItem)))
				{
					if (!strcmp(sClass, "predicted_viewmodel")) // 部分物品的模型和视图模型一样
						continue;

					if (!strcmp(sItem, "weapon_gascan") && IsEventGascan(i))
						continue;
						
					if (g_bFinalMap && g_bFinalPills)
					{
						if (!strcmp(sItem, "weapon_pain_pills"))
							continue;
							
						if (!strcmp(sItem, "weapon_first_aid_kit"))
						{
							ReplaceEntity(i, sClass, "weapon_pain_pills", 1, MOVETYPE_NONE);
							continue;
						}
					}

					if (g_smItemReplace.GetString(sItem, sNewItem, sizeof(sNewItem)))
					{
						ReplaceEntity(i, sClass, sNewItem, 3, MOVETYPE_NONE);
						continue;
					}

					if (g_smItemLimit.GetValue(sItem, iLimit) && iLimit >= 0)
					{
						if (iLimit == 0)
							RemoveEntity(i);
						else
						{
							data.entity = i;
							data.sName = sItem;
							g_aEnt.PushArray(data);
						}
					}
				}
			}
		}
	}
}

void ReplaceEntity(int entity, const char[] sClass, const char[] sNewItem, int count = 1, MoveType movetype = MOVETYPE_CUSTOM)
{
	static float fPos[3], fAng[3];

	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fPos);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", fAng);

	RemoveEntity(entity);

	if (!IsValidEntity(L4D2Wep_Spawn(sNewItem, fPos, fAng, count, movetype)))
		LogError("Failed to replace %s to %s", sClass, sNewItem);
}

void EntityLimit()
{
	static char sItem[64];
	static EntityData data;
	static int iLimit, iRemove, i, len, index;
	
	ArrayList aTemp = new ArrayList(sizeof(EntityData));
	len = g_aEnt.Length;
	g_kv.Rewind();

	if (g_kv.JumpToKey("item_limit") && g_kv.GotoFirstSubKey(false))
	{
		do
		{
			iLimit = g_kv.GetNum(NULL_STRING, -1);
			if (iLimit > 0)
			{
				aTemp.Clear();
				g_kv.GetSectionName(sItem, sizeof(sItem));

				for (i = 0; i < len; i++)
				{
					g_aEnt.GetArray(i, data);
					if (!strcmp(data.sName, sItem))
						aTemp.PushArray(data);
				}

				iRemove = aTemp.Length - iLimit;
				for (i = 0; i < iRemove; i++)
				{
					index = GetRandomIntEx(0, aTemp.Length-1);
					aTemp.GetArray(index, data);
					RemoveEntity(data.entity);
					aTemp.Erase(index);
				}
			}
		}
		while (g_kv.GotoNextKey(false));
	}

	delete aTemp;
}

void GiveStartItem()
{
	if (g_sStartItems[0] == '\0')
		return;

	static char sItems[16][64];
	static int pieces, client, i;

	pieces = ExplodeString(g_sStartItems, ";", sItems, sizeof(sItems), sizeof(sItems[]));

	for (client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		{
			for (i = 0; i < pieces; i++)
			{
				if (!strcmp(sItems[i], "health"))
					RestoreHealth(client, GetEntProp(client, Prop_Send, "m_iMaxHealth"));
				else
					CheatCommand(client, "give", sItems[i]);
			}
		}
	}
}

bool IsCarriedByClient(int entity)
{
	if (HasEntProp(entity, Prop_Data, "m_iState"))
		return GetEntProp(entity, Prop_Data, "m_iState") > 0;
	return false;
}

void CharToLowerCase(char[] chr, int len)
{
	static int i;
	for (i = 0; i < len; i++)
		chr[i] = CharToLower(chr[i]);
}

bool IsEventGascan(int entity)
{
	return GetEntProp(entity, Prop_Send, "m_nSkin") > 0 || GetEntProp(entity, Prop_Send, "m_iGlowType") == 3;
}

// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/math.inc
int GetRandomIntEx(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

// 黑白发光插件依赖 heal_success 事件
void RestoreHealth(int client, int iHealth)
{
	Event event = CreateEvent("heal_success", true);
	event.SetInt("userid", GetClientUserId(client));
	event.SetInt("subject", GetClientUserId(client));
	event.SetInt("health_restored", iHealth - GetEntProp(client, Prop_Send, "m_iHealth"));

	CheatCommand(client, "give", "health");

	SetEntProp(client, Prop_Send, "m_iHealth", iHealth);
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());

	event.Fire();
}

void CheatCommand(int client, const char[] command, const char[] args = "")
{
	int iFlags = GetCommandFlags(command);
	SetCommandFlags(command, iFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, args);
	SetCommandFlags(command, iFlags);
}

// RestoreTransitionedEntities(void) -> Removing %s\n
// C4地图上安全屋的武器被自动删除
void C4WeaponSpawn()
{
	char sMap[18];
	GetCurrentMap(sMap, sizeof(sMap));

	if (!strcmp(sMap, "c4m3_sugarmill_b"))
	{
		L4D2Wep_Spawn("weapon_shotgun_chrome", view_as<float>({3552.0, -1767.0, 263.0}), view_as<float>({0.0, 180.0, 90.0}), 3, MOVETYPE_NONE);
		L4D2Wep_Spawn("weapon_smg_silenced", view_as<float>({3549.0, -1738.0, 263.0}), view_as<float>({0.0, 180.0, 90.0}), 3, MOVETYPE_NONE);
	}
	else if (!strcmp(sMap, "c4m4_milltown_b"))
	{
		L4D2Wep_Spawn("weapon_shotgun_chrome", view_as<float>({-3320.0, 7788.0, 156.0}), view_as<float>({0.0, 268.0, 270.0}), 3, MOVETYPE_NONE);
		L4D2Wep_Spawn("weapon_smg_silenced", view_as<float>({-3336.0, 7788.0, 156.0}), view_as<float>({0.0, 285.0, 270.0}), 3, MOVETYPE_NONE);
	}
}

Action Cmd_Reload(int client, int args)
{
	Init();
	return Plugin_Handled;
}

Action Cmd_LimitTest(int client, int args)
{
	RoundStart_Timer(null);
	return Plugin_Handled;
}


