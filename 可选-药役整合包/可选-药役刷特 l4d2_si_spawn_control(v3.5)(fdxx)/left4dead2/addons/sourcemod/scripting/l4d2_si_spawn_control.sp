/*=======================================================================================

Change Log:

v3.3
	- Cvar changed: l4d2_si_spawn_control_radical_spawn ==> l4d2_si_spawn_control_spawn_mode
	- Optimize performance.
	- Prioritize spawning SI near real players. (for SpawnMode == 1)
	- After changing the SI spawn time, immediately spawn SI at the set time.
	- Fix the number of SI spawn may be abnormal.

v3.4
	- Add more spawn mode.

v3.5
	- When max SI are being spawned, Allow respawning of killed SI.

=======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <sdktools>
//#include <profiler>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

#define VERSION "3.5"
#define DEBUG 1

#define	SMOKER	1
#define	BOOMER	2
#define	HUNTER	3
#define	SPITTER	4
#define	JOCKEY	5
#define	CHARGER 6
#define	SI_CLASS_SIZE	7

#define BOT			0
#define PLAYER		1

#define SPAWN_NO_HANDLE 0
#define SPAWN_MAX_PRE	1
#define SPAWN_MAX		2
#define SPAWN_REVIVE	10

#define NEAREST_RANGE_ADD 400.0

enum
{
	SpawnMode_Normal			= 0, // L4D_GetRandomPZSpawnPosition + l4d2_si_spawn_control_spawn_range_normal
	SpawnMode_NavAreaNearest	= 1, // GetSpawnPosByNavArea + nearest invisible place
	SpawnMode_NavArea			= 2, // GetSpawnPosByNavArea + l4d2_si_spawn_control_spawn_range_navarea
	SpawnMode_NormalEnhanced	= 3, // SpawnMode_Normal + SpawnMode_NavArea auto switch.
}

ConVar
	z_special_limit[SI_CLASS_SIZE],
	z_attack_flow_range,
	z_spawn_flow_limit,
	director_spectate_specials,
	z_spawn_safety_range,
	z_finale_spawn_safety_range,
	z_spawn_range,
	z_discard_range,
	g_cvSpecialLimit[SI_CLASS_SIZE],
	g_cvMaxSILimit,
	g_cvSpawnTime,
	g_cvFirstSpawnTime,
	g_cvKillSITime,
	g_cvBlockSpawn,
	g_cvSpawnMode,
	g_cvNormalSpawnRange,
	g_cvNavAreaSpawnRange,
	g_cvTogetherSpawn;

int
	g_iSpecialLimit[SI_CLASS_SIZE],
	g_iMaxSILimit,
	g_iSpawnMode,
	g_iSpawnAttributesOffset,
	g_iFlowDistanceOffset,
	g_iNavCountOffset,
	g_iSurvivors[MAXPLAYERS+1],
	g_iSurCount;

float
	g_fSpawnTime,
	g_fFirstSpawnTime,
	g_fKillSITime,
	g_fNormalSpawnRange,
	g_fNavAreaSpawnRange,
	g_fNearestSpawnRange,
	g_fSpecialActionTime[MAXPLAYERS+1];

bool
	g_bBlockSpawn,
	g_bCanSpawn,
	g_bFinalMap,
	g_bLeftSafeArea,
	g_bMark[MAXPLAYERS+1],
	g_bTogetherSpawn;

Handle
	g_hSpawnTimer[MAXPLAYERS+1],
	g_hSDKIsVisibleToPlayer,
	g_hSDKFindRandomSpot;

Address
	g_pPanicEventStage; 

ArrayList g_aSurPosData;
int g_iSurPosDataLen;

enum struct SurPosData
{
	float fFlow;
	float fPos[3];
}

enum struct SpawnData
{
	float fDist;
	float fPos[3];
}

// https://developer.valvesoftware.com/wiki/List_of_L4D_Series_Nav_Mesh_Attributes:zh-cn
#define	TERROR_NAV_NO_NAME1				(1 << 0)
#define	TERROR_NAV_EMPTY				(1 << 1)
#define	TERROR_NAV_STOP_SCAN			(1 << 2)
#define	TERROR_NAV_NO_NAME2				(1 << 3)
#define	TERROR_NAV_NO_NAME3				(1 << 4)
#define	TERROR_NAV_BATTLESTATION		(1 << 5)
#define	TERROR_NAV_FINALE				(1 << 6)
#define	TERROR_NAV_PLAYER_START			(1 << 7)
#define	TERROR_NAV_BATTLEFIELD			(1 << 8)
#define	TERROR_NAV_IGNORE_VISIBILITY	(1 << 9)
#define	TERROR_NAV_NOT_CLEARABLE		(1 << 10)
#define	TERROR_NAV_CHECKPOINT			(1 << 11)
#define	TERROR_NAV_OBSCURED				(1 << 12)
#define	TERROR_NAV_NO_MOBS				(1 << 13)
#define	TERROR_NAV_THREAT				(1 << 14)
#define	TERROR_NAV_RESCUE_VEHICLE		(1 << 15)
#define	TERROR_NAV_RESCUE_CLOSET		(1 << 16)
#define	TERROR_NAV_ESCAPE_ROUTE			(1 << 17)
#define	TERROR_NAV_DOOR					(1 << 18)
#define	TERROR_NAV_NOTHREAT				(1 << 19)
#define	TERROR_NAV_LYINGDOWN			(1 << 20)
#define	TERROR_NAV_COMPASS_NORTH		(1 << 24)
#define	TERROR_NAV_COMPASS_NORTHEAST	(1 << 25)
#define	TERROR_NAV_COMPASS_EAST			(1 << 26)
#define	TERROR_NAV_COMPASS_EASTSOUTH	(1 << 27)
#define	TERROR_NAV_COMPASS_SOUTH		(1 << 28)
#define	TERROR_NAV_COMPASS_SOUTHWEST	(1 << 29)
#define	TERROR_NAV_COMPASS_WEST			(1 << 30)
#define	TERROR_NAV_COMPASS_WESTNORTH	(1 << 31)

methodmap TheNavAreas
{
	public int Count()
	{
		return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iNavCountOffset), NumberType_Int32);
	}

	public Address Dereference()
	{
		return LoadFromAddress(view_as<Address>(this), NumberType_Int32);
	}

	public NavArea GetArea(int i, bool bDereference = true)
	{
		if (!bDereference)
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(i*4), NumberType_Int32);
		return LoadFromAddress(this.Dereference() + view_as<Address>(i*4), NumberType_Int32);
	}
}

methodmap NavArea
{
	public bool IsNull()
	{
		return view_as<Address>(this) == Address_Null;
	}
	
	public void GetSpawnPos(float fPos[3])
	{
		SDKCall(g_hSDKFindRandomSpot, this, fPos);
	}

	property int SpawnAttributes
	{
		public get()
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iSpawnAttributesOffset), NumberType_Int32);

		public set(int value)
			StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iSpawnAttributesOffset), value, NumberType_Int32);
	}
	
	public float GetFlow()
	{
		return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iFlowDistanceOffset), NumberType_Int32);
	}
}

TheNavAreas g_pTheNavAreas;

public Plugin myinfo = 
{
	name = "L4D2 Special infected spawn control",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	Init();

	CreateConVar("l4d2_si_spawn_control_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	z_special_limit[SMOKER] =		FindConVar("z_smoker_limit");
	z_special_limit[BOOMER] =		FindConVar("z_boomer_limit");
	z_special_limit[HUNTER] =		FindConVar("z_hunter_limit");
	z_special_limit[SPITTER] =		FindConVar("z_spitter_limit");
	z_special_limit[JOCKEY] =		FindConVar("z_jockey_limit");
	z_special_limit[CHARGER] =		FindConVar("z_charger_limit");
	z_attack_flow_range =			FindConVar("z_attack_flow_range");
	z_spawn_flow_limit =			FindConVar("z_spawn_flow_limit");
	director_spectate_specials =	FindConVar("director_spectate_specials");
	z_spawn_safety_range =			FindConVar("z_spawn_safety_range");
	z_finale_spawn_safety_range =	FindConVar("z_finale_spawn_safety_range");
	z_spawn_range =					FindConVar("z_spawn_range");
	z_discard_range =				FindConVar("z_discard_range");

	g_cvSpecialLimit[HUNTER] =	CreateConVar("l4d2_si_spawn_control_hunter_limit",	"1", "Hunter limit.", FCVAR_NONE, true, 0.0, true, 32.0);
	g_cvSpecialLimit[JOCKEY] =	CreateConVar("l4d2_si_spawn_control_jockey_limit",	"1", "Jockey limit.", FCVAR_NONE, true, 0.0, true, 32.0);
	g_cvSpecialLimit[SMOKER] =	CreateConVar("l4d2_si_spawn_control_smoker_limit",	"1", "Smoker limit.", FCVAR_NONE, true, 0.0, true, 32.0);
	g_cvSpecialLimit[BOOMER] =	CreateConVar("l4d2_si_spawn_control_boomer_limit",	"1", "Boomer limit.", FCVAR_NONE, true, 0.0, true, 32.0);
	g_cvSpecialLimit[SPITTER] = CreateConVar("l4d2_si_spawn_control_spitter_limit",	"1", "Spitter limit.", FCVAR_NONE, true, 0.0, true, 32.0);
	g_cvSpecialLimit[CHARGER] =	CreateConVar("l4d2_si_spawn_control_charger_limit",	"1", "Charger limit.", FCVAR_NONE, true, 0.0, true, 32.0);

	g_cvMaxSILimit =		CreateConVar("l4d2_si_spawn_control_max_specials",			"6",	"Max SI limit.", FCVAR_NONE, true, 0.0, true, 32.0);
	g_cvSpawnTime =			CreateConVar("l4d2_si_spawn_control_spawn_time",			"10.0",	"SI spawn time.", FCVAR_NONE, true, 1.0);
	g_cvFirstSpawnTime =	CreateConVar("l4d2_si_spawn_control_first_spawn_time",		"10.0",	"SI first spawn time (after leaving the safe area).", FCVAR_NONE, true, 0.1);
	g_cvKillSITime =		CreateConVar("l4d2_si_spawn_control_kill_si_time",			"25.0",	"Auto kill SI time. if it 'slack off'.", FCVAR_NONE, true, 0.1);
	g_cvBlockSpawn = 		CreateConVar("l4d2_si_spawn_control_block_other_si_spawn",	"1",	"Block other SI spawn (by L4D_OnSpawnSpecial).", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSpawnMode =			CreateConVar("l4d2_si_spawn_control_spawn_mode",			"0",	"Spawn mode, See enum SpawnMode_*");
	g_cvNormalSpawnRange =	CreateConVar("l4d2_si_spawn_control_spawn_range_normal",	"1500", "Normal mode spawn range, randomly spawn from 1 to this range.", FCVAR_NONE, true, 1.0);
	g_cvNavAreaSpawnRange =	CreateConVar("l4d2_si_spawn_control_spawn_range_navarea",	"1500", "NavArea mode spawn range, randomly spawn from 1 to this range.", FCVAR_NONE, true, 1.0);
	g_cvTogetherSpawn =		CreateConVar("l4d2_si_spawn_control_together_spawn",		"0",	"After SI dies, wait for other SI to spawn together.", FCVAR_NONE, true, 0.0, true, 1.0);

	GetCvars();

	for (int i = 1; i < SI_CLASS_SIZE; i++)
	{
		g_cvSpecialLimit[i].AddChangeHook(ConVarChanged);
	}
	g_cvMaxSILimit.AddChangeHook(ConVarChanged);
	g_cvSpawnTime.AddChangeHook(ConVarChanged);
	g_cvFirstSpawnTime.AddChangeHook(ConVarChanged);
	g_cvKillSITime.AddChangeHook(ConVarChanged);
	g_cvBlockSpawn.AddChangeHook(ConVarChanged);
	g_cvSpawnMode.AddChangeHook(ConVarChanged);
	g_cvNormalSpawnRange.AddChangeHook(ConVarChanged);
	g_cvNavAreaSpawnRange.AddChangeHook(ConVarChanged);
	g_cvTogetherSpawn.AddChangeHook(ConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);

	CreateTimer(1.0, KillSICheck_Timer, _, TIMER_REPEAT);
}

void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();

	if (!g_bLeftSafeArea)
		return;
		
	if (convar == g_cvMaxSILimit)
	{
		if (StringToInt(newValue) > StringToInt(oldValue))
		{
			for (int i; i <= MAXPLAYERS; i++)
				delete g_hSpawnTimer[i];
			SpawnSpecial_Timer(null, SPAWN_MAX_PRE);
		}
	}

	else if (convar == g_cvSpawnTime)
	{
		for (int i; i <= MAXPLAYERS; i++)
			delete g_hSpawnTimer[i];
		g_hSpawnTimer[SPAWN_MAX_PRE] = CreateTimer(g_fSpawnTime, SpawnSpecial_Timer, SPAWN_MAX_PRE);
	}
}

void GetCvars()
{
	for (int i = 1; i < SI_CLASS_SIZE; i++)
	{
		g_iSpecialLimit[i] = g_cvSpecialLimit[i].IntValue;
	}

	g_iMaxSILimit = g_cvMaxSILimit.IntValue;
	g_fSpawnTime = g_cvSpawnTime.FloatValue;
	g_fFirstSpawnTime = g_cvFirstSpawnTime.FloatValue;
	g_fKillSITime = g_cvKillSITime.FloatValue;
	g_bBlockSpawn = g_cvBlockSpawn.BoolValue;
	g_iSpawnMode = g_cvSpawnMode.IntValue;
	g_fNormalSpawnRange = g_cvNormalSpawnRange.FloatValue;
	g_fNavAreaSpawnRange = g_cvNavAreaSpawnRange.FloatValue;
	g_bTogetherSpawn = g_cvTogetherSpawn.BoolValue;

	z_spawn_range.IntValue = RoundToNearest(g_fNormalSpawnRange);
}

public void OnConfigsExecuted()
{
	for (int i = 1; i < SI_CLASS_SIZE; i++)
		z_special_limit[i].IntValue = 0;

	z_attack_flow_range.IntValue = 50000;
	z_spawn_flow_limit.IntValue = 50000;
	director_spectate_specials.IntValue = 1;
	z_spawn_safety_range.IntValue = 1;
	z_finale_spawn_safety_range.IntValue = 1;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

public void OnMapEnd()
{
	Reset();
}

void Reset()
{
	g_bLeftSafeArea = false;
	g_fNearestSpawnRange = L4D2_GetScriptValueFloat("ZombieDiscardRange", z_discard_range.FloatValue);

	for (int i; i <= MAXPLAYERS; i++)
	{
		delete g_hSpawnTimer[i];
		g_bMark[i] = false;
	}
}

public void OnMapStart()
{
	g_bFinalMap = L4D_IsMissionFinalMap();
}

public void OnClientPutInServer(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public void OnClientDisconnect(int client)
{
	// Special Infected are kicked by other plugin before dying. Or be take over by other real players.
	if (g_bMark[client])
	{
		Event event = CreateEvent("player_death", true);
		event.SetInt("userid", GetClientUserId(client));
		Event_PlayerDeath(event, "shit", true);
		event.Cancel();
	}
}

void Event_PlayerLeftSafeArea(Event event, const char[] name, bool dontBroadcast)
{
	g_bLeftSafeArea = true;

	delete g_hSpawnTimer[SPAWN_MAX_PRE];
	g_hSpawnTimer[SPAWN_MAX_PRE] = CreateTimer(g_fFirstSpawnTime, SpawnSpecial_Timer, SPAWN_MAX_PRE);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (g_bLeftSafeArea && g_bMark[client] && client > 0 && IsClientInGame(client) && (GetClientTeam(client) == 3 || !strcmp(name, "shit")) && IsFakeClient(client))
	{
		int iClass = GetZombieClass(client);
		if (iClass > 0 && iClass < SI_CLASS_SIZE)
		{
			// Kick the bot to release client index.
			// Exclude SPITTER to avoid sputum without sound.
			if (iClass != SPITTER)
				CreateTimer(0.1, KickBot_Timer, userid);
			
			if (!g_hSpawnTimer[SPAWN_MAX_PRE])
			{
				if (g_bTogetherSpawn)
					RequestFrame(PlayerDeath_NextFrame);
				else
				{
					static int num = SPAWN_REVIVE;
					if (++num >= MAXPLAYERS) num = SPAWN_REVIVE;
					g_hSpawnTimer[num] = CreateTimer(g_fSpawnTime, SpawnSpecial_Timer, num);
				}
			}
		}
	}

	g_bMark[client] = false;
	
}

void PlayerDeath_NextFrame()
{
	if (GetAllSpecialsTotal() == 0)
	{
		delete g_hSpawnTimer[SPAWN_MAX_PRE];
		g_hSpawnTimer[SPAWN_MAX_PRE] = CreateTimer(g_fSpawnTime, SpawnSpecial_Timer, SPAWN_MAX_PRE);
	}
}

Action SpawnSpecial_Timer(Handle timer, int num)
{
	if (g_bLeftSafeArea)
	{
		static int iSpawnCount;

		switch (num)
		{
			case SPAWN_MAX_PRE:
			{
				iSpawnCount = 0;
				delete g_hSpawnTimer[SPAWN_MAX];
				g_hSpawnTimer[SPAWN_MAX] = CreateTimer(0.1, SpawnSpecial_Timer, SPAWN_MAX, TIMER_REPEAT);
			}

			case SPAWN_MAX:
			{
				if (iSpawnCount++ < g_iMaxSILimit)
				{
					SpawnSpecial();
					return Plugin_Continue;
				}
			}

			default:
				SpawnSpecial();
		}
	}

	g_hSpawnTimer[num] = null;
	return Plugin_Stop;
}

void SpawnSpecial()
{
	if (!g_bLeftSafeArea)
		return;

	static float fSpawnPos[3];
	static int iClass, iPanicEventStage, index;
	static bool bFound;

	bFound = false;
	index = -1;

	if (GetAllSpecialsTotal() >= g_iMaxSILimit)
		return;

	iClass = GetSpawnClass();
	if (iClass <= 0)
		return;

	switch (g_iSpawnMode)
	{
		case SpawnMode_Normal:
			bFound = L4D_GetRandomPZSpawnPosition(GetRandomSur(), iClass, 30, fSpawnPos);
		
		case SpawnMode_NormalEnhanced:
		{
			iPanicEventStage = LoadFromAddress(g_pPanicEventStage, NumberType_Int8);

			if (!g_bFinalMap && iPanicEventStage > 0)
			{
				// After the panic event starts,
				// The GetRandomPZSpawnPosition function spawn SI very far away.
				// c8m3, c3m2...
				bFound = GetSpawnPosByNavArea(fSpawnPos, g_fNormalSpawnRange);
			}
			else
			{
				bFound = L4D_GetRandomPZSpawnPosition(GetRandomSur(), iClass, 7, fSpawnPos);
				if (!bFound)
				{
					// Use GetRandomPZSpawnPosition first, use GetSpawnPosByNavArea when it fails.
					bFound = GetSpawnPosByNavArea(fSpawnPos, g_fNormalSpawnRange);
				}
			}
		}

		case SpawnMode_NavArea:
			bFound = GetSpawnPosByNavArea(fSpawnPos, g_fNavAreaSpawnRange);

		case SpawnMode_NavAreaNearest:
			bFound = GetSpawnPosByNavArea(fSpawnPos, g_fNearestSpawnRange, true);
	}
	
	if (bFound)
	{
		g_bCanSpawn = true;
		index = L4D2_SpawnSpecial(iClass, fSpawnPos, NULL_VECTOR);
		g_bCanSpawn = false;

		if (index > 0)
		{
			g_bMark[index] = true;
			return;
		}
	}

	if (!bFound || index < 1)
	{
		CreateTimer(1.0, SpawnSpecial_Timer, SPAWN_NO_HANDLE, TIMER_FLAG_NO_MAPCHANGE);

		#if DEBUG
		char sMap[128];
		GetCurrentMap(sMap, sizeof(sMap));
		LogMessage("Failed to SpawnSpecial, map = %s, SpawnMode = %i, bFound = %b, index = %i", sMap, g_iSpawnMode, bFound, index);
		#endif
	}
}

bool GetSpawnPosByNavArea(float fPos[3], float fSpawnRange, bool bNearest = false)
{
	static TheNavAreas pTheNavAreas;
	static NavArea pArea;
	static float fSpawnPos[3], fFlow, fDist, fMapMaxFlowDist;
	static bool bFound, bFinaleArea;
	static int i, iAreaCount, iArrayLen, iMaxRandomBound;
	static SpawnData data;

	if (!GetSurPosData())
		return false;

	ArrayList array = new ArrayList(sizeof(data));
	pTheNavAreas = view_as<TheNavAreas>(g_pTheNavAreas.Dereference());
	fMapMaxFlowDist = L4D2Direct_GetMapMaxFlowDistance();
	iAreaCount = g_pTheNavAreas.Count();
	bFinaleArea = g_bFinalMap && L4D2_GetCurrentFinaleStage() < 18;

	for (i = 0; i < iAreaCount; i++)
	{
		pArea = pTheNavAreas.GetArea(i, false);
		if (!pArea || !IsValidFlags(pArea.SpawnAttributes, bFinaleArea))
			continue;

		fFlow = pArea.GetFlow();
		if (fFlow < 0.0 || fFlow > fMapMaxFlowDist)
			continue;

		pArea.GetSpawnPos(fSpawnPos);
		if (IsNearTheSur(fSpawnRange, fFlow, fSpawnPos, fDist))
		{
			if (!IsVisible(fSpawnPos, pArea) && !WillStuck(fSpawnPos))
			{
				data.fDist = fDist;
				data.fPos = fSpawnPos;
				array.PushArray(data);
			}
		}
	}

	iArrayLen = array.Length;
	if (iArrayLen > 0)
	{
		if (bNearest)
		{
			array.Sort(Sort_Ascending, Sort_Float);
			iMaxRandomBound = iArrayLen > 2 ? 2 : 0;
		}
		else
			iMaxRandomBound = iArrayLen-1;
		
		array.GetArray(GetRandomIntEx(0, iMaxRandomBound), data);
		fPos = data.fPos;
		if (bNearest)
			g_fNearestSpawnRange = data.fDist + NEAREST_RANGE_ADD;
		bFound = true;
	}
	else
	{
		if (bNearest)
			g_fNearestSpawnRange = L4D2_GetScriptValueFloat("ZombieDiscardRange", z_discard_range.FloatValue);
		bFound = false;
	}

	delete array;
	return bFound;
}

bool GetSurPosData()
{
	static SurPosData data;
	static int i, type;

	ArrayList array[2];
	array[BOT] = new ArrayList(sizeof(data));
	array[PLAYER] = new ArrayList(sizeof(data));

	g_iSurPosDataLen = 0;
	g_iSurCount = 0;

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
		{
			data.fFlow = L4D2Direct_GetFlowDistance(i);
			GetClientEyePosition(i, data.fPos);

			if (IsFakeClient(i))
				array[BOT].PushArray(data);
			else
				array[PLAYER].PushArray(data);

			g_iSurvivors[g_iSurCount++] = i;
		}
	}

	// Prioritize spawning near real players.
	type = array[PLAYER].Length > 0 ? PLAYER : BOT;

	if (type || array[type].Length > 0)
	{
		delete g_aSurPosData;
		g_aSurPosData = array[type].Clone();
		g_iSurPosDataLen = g_aSurPosData.Length;
	}

	delete array[BOT];
	delete array[PLAYER];
	return g_iSurPosDataLen > 0;
}

bool IsValidFlags(int iFlags, bool bFinaleArea)
{
	if (!iFlags)
		return true;

	if (bFinaleArea && (iFlags & TERROR_NAV_FINALE) == 0)
		return false;

	return (iFlags & (TERROR_NAV_RESCUE_CLOSET|TERROR_NAV_RESCUE_VEHICLE)) == 0;
}

bool IsNearTheSur(float fSpawnRange, float fFlow, const float fPos[3], float &fDist)
{
	static SurPosData data;
	static int i;

	for (i = 0; i < g_iSurPosDataLen; i++)
	{
		g_aSurPosData.GetArray(i, data);
		if (FloatAbs(fFlow - data.fFlow) < fSpawnRange)
		{
			fDist = GetVectorDistance(data.fPos, fPos);
			if (fDist < fSpawnRange)
				return true;
		}
	}
	return false;
}

bool IsVisible(const float fPos[3], NavArea pArea)
{
	static int i;
	static float fTargetPos[3];

	fTargetPos = fPos;
	fTargetPos[2] += 62.0; // Eye position.

	for (i = 0; i < g_iSurCount; i++)
	{
		if (SDKCall(g_hSDKIsVisibleToPlayer, fTargetPos, g_iSurvivors[i], 2, 3, 0.0, 0, pArea, true))
			return true;
	}

	return false;
}

bool WillStuck(const float fPos[3])
{
	// All clients seem to be the same size.
	static const float fClientMinSize[3] = {-16.0, -16.0, 0.0};
	static const float fClientMaxSize[3] = {16.0, 16.0, 71.0};

	static bool bHit;
	static Handle hTrace;

	hTrace = TR_TraceHullFilterEx(fPos, fPos, fClientMinSize, fClientMaxSize, MASK_PLAYERSOLID, TraceFilter_Stuck);
	bHit = TR_DidHit(hTrace);

	delete hTrace;
	return bHit;
}

bool TraceFilter_Stuck(int entity, int contentsMask)
{
	if (entity <= MaxClients || !IsValidEntity(entity))
		return false;
	return true;
}

int GetRandomSur()
{
	ArrayList array = new ArrayList();
	int client;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
			array.Push(i);
	}

	if (array.Length > 0)
		client = array.Get(GetRandomIntEx(0, array.Length-1));

	delete array;
	return client;
}

int GetSpawnClass()
{
	int iCount[SI_CLASS_SIZE];
	int iClass, i;
	ArrayList array = new ArrayList();

	for (i = 1; i <= MaxClients; i++)
	{
		if (!g_bMark[i] || !IsClientInGame(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i) || !IsFakeClient(i))
			continue;

		iClass = GetZombieClass(i);
		if (iClass < 1 || iClass > 6)
			continue;

		iCount[iClass]++;
	}

	for (i = 1; i < SI_CLASS_SIZE; i++)
	{
		if (iCount[i] < g_iSpecialLimit[i])
			array.Push(i);
	}

	iClass = -1;
	if (array.Length > 0)
		iClass = array.Get(GetRandomIntEx(0, array.Length-1));

	delete array;
	return iClass;
}

int GetAllSpecialsTotal()
{
	int iCount, iClass;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!g_bMark[i] || !IsClientInGame(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i) || !IsFakeClient(i))
			continue;

		iClass = GetZombieClass(i);
		if (iClass < 1 || iClass > 6)
			continue;

		iCount++;
	}

	return iCount;
}

int GetRandomIntEx(int min, int max)
{
	return GetURandomInt() % (max - min + 1) + min;
}

Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	static float fEngineTime;
	fEngineTime = GetEngineTime();

	if (attacker > 0 && attacker <= MaxClients)
		g_fSpecialActionTime[attacker] = fEngineTime;
	g_fSpecialActionTime[victim] = fEngineTime;

	return Plugin_Continue;
}

public void L4D_OnSpawnSpecial_Post(int client, int zombieClass, const float vecPos[3], const float vecAng[3])
{
	if (client > 0)
		g_fSpecialActionTime[client] = GetEngineTime();
}

Action KillSICheck_Timer(Handle timer)
{
	if (!g_bLeftSafeArea)
		return Plugin_Continue;

	float fEngineTime = GetEngineTime();
	int class;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i) || !IsFakeClient(i))
			continue;

		class = GetZombieClass(i);
		if (class < 1 || class > 6)
			continue;

		if (fEngineTime - g_fSpecialActionTime[i] > g_fKillSITime)
		{
			if (!GetEntProp(i, Prop_Send, "m_hasVisibleThreats") && !HasSurVictim(i, class))
				ForcePlayerSuicide(i);
			else
				g_fSpecialActionTime[i] = fEngineTime;
		}
	}
	return Plugin_Continue;
}

bool HasSurVictim(int client, int iClass)
{
	switch (iClass)
	{
		case SMOKER:
			return GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0;
		case HUNTER:
			return GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0;
		case JOCKEY:
			return GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0;
		case CHARGER:
			return GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 || GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0;
	}
	return false;
}

int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

static const char g_sSpecialName[][] =
{
	"", "Smoker", "Boomer", "Hunter", "Spitter", "Jockey", "Charger"
};

public Action L4D_OnSpawnSpecial(int &zombieClass, const float vecPos[3], const float vecAng[3])
{
	if (!g_bCanSpawn && g_bBlockSpawn)
	{
		LogMessage("%s not spawned by this plugin, blocked.", g_sSpecialName[zombieClass]);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

Action KickBot_Timer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0 && IsClientInGame(client) && IsFakeClient(client) && !IsClientInKickQueue(client))
		KickClient(client);
	return Plugin_Continue;
}

void GetOffset(GameData hGameData, int &offset, const char[] name)
{
	offset = hGameData.GetOffset(name);
	if (offset == -1)
		SetFailState("Failed to get offset: %s", name);
}

void GetAddress(GameData hGameData, Address &address, const char[] name)
{
	address = hGameData.GetAddress(name);
	if (address == Address_Null)
		SetFailState("Failed to get address: %s", name);
}

void Init()
{
	char sBuffer[128];

	strcopy(sBuffer, sizeof(sBuffer), "l4d2_si_spawn_control");
	GameData hGameData = new GameData(sBuffer);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", sBuffer);

	GetOffset(hGameData, g_iSpawnAttributesOffset, "TerrorNavArea::SpawnAttributes");
	GetOffset(hGameData, g_iFlowDistanceOffset, "TerrorNavArea::FlowDistance");
	GetOffset(hGameData, g_iNavCountOffset, "TheNavAreas::Count");
	
	GetAddress(hGameData, view_as<Address>(g_pTheNavAreas), "TheNavAreas");
	GetAddress(hGameData, g_pPanicEventStage, "CDirectorScriptedEventManager::m_PanicEventStage");

	// Vector CNavArea::GetRandomPoint( void ) const
	strcopy(sBuffer, sizeof(sBuffer), "TerrorNavArea::FindRandomSpot");
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue);
	g_hSDKFindRandomSpot = EndPrepSDKCall();
	if(g_hSDKFindRandomSpot == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	// IsVisibleToPlayer(Vector const&, CBasePlayer *, int, int, float, CBaseEntity const*, TerrorNavArea **, bool *);
	// SDKCall(g_hSDKIsVisibleToPlayer, fTargetPos, i, 2, 3, 0.0, 0, pArea, true);
	strcopy(sBuffer, sizeof(sBuffer), "IsVisibleToPlayer");
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);			// target position
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);		// client
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);		// client team
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);		// target position team, related to the client's angle.
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);				// unknown
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);		// unknown
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer);	// target position NavArea
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Pointer);			// if false, will auto get the NavArea of the target position (GetNearestNavArea)
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKIsVisibleToPlayer = EndPrepSDKCall();
	if (g_hSDKIsVisibleToPlayer == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	// Unlock Max SI limit.
	strcopy(sBuffer, sizeof(sBuffer), "CDirector::GetMaxPlayerZombies");
	MemoryPatch mPatch = MemoryPatch.CreateFromConf(hGameData, sBuffer);
	if (!mPatch.Validate())
		SetFailState("Failed to verify patch: %s", sBuffer);
	if (!mPatch.Enable())
		SetFailState("Failed to Enable patch: %s", sBuffer);

	delete hGameData;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("L4D2_CanSpawnSpecial", Native_CanSpawnSpecial);
	RegPluginLibrary("l4d2_si_spawn_control");
	return APLRes_Success;
}

// L4D2_CanSpawnSpecial(bool bCanSpawn);
int Native_CanSpawnSpecial(Handle plugin, int numParams)
{
	bool bCanSpawn = GetNativeCell(1);
	g_bCanSpawn = bCanSpawn;
	return 0;
}
