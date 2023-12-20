#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#if DEBUG
#include <profiler>
#endif

public Plugin myinfo = {
	name = "Tank and Witch ifier!",
	author = "CanadaRox, Sir, devilesk, Derpduck, Forgetest",
	version = "2.4.1",
	description = "Sets a tank spawn and has the option to remove the witch spawn point on every map",
	url = "https://github.com/devilesk/rl4d2l-plugins"
};

// ======================================
// Variables
// ======================================

ConVar
	g_cvVsBossBuffer,
	g_cvVsBossFlowMax,
	g_cvVsBossFlowMin;
	
StringMap
	g_smStaticTankMaps,
	g_smStaticWitchMaps;
	
ConVar
	g_cvDebug,
	g_cvTankCanSpawn,
	g_cvWitchCanSpawn,
	g_cvWitchAvoidTank;
	
char
	g_sCurrentMap[64];
	
ArrayList
	g_aValidTankFlows,
	g_aValidWitchFlows;

KeyValues
	g_kvMIData;

// ======================================
// Plugin Setup
// ======================================

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNative("IsStaticTankMap", Native_IsStaticTankMap);
	CreateNative("IsStaticWitchMap", Native_IsStaticWitchMap);
	CreateNative("IsTankPercentValid", Native_IsTankPercentValid);
	CreateNative("IsWitchPercentValid", Native_IsWitchPercentValid);
	CreateNative("IsWitchPercentBlockedForTank", Native_IsWitchPercentBlockedForTank);
	CreateNative("SetTankPercent", Native_SetTankPercent);
	CreateNative("SetWitchPercent", Native_SetWitchPercent);

	RegPluginLibrary("witch_and_tankifier");
	return APLRes_Success;
}

public void OnPluginStart() {
	LoadMapInfo();

	g_cvDebug = CreateConVar("sm_tank_witch_debug", "0", "Tank and Witch ifier debug mode", FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	g_cvTankCanSpawn = CreateConVar("sm_tank_can_spawn", "1", "Tank and Witch ifier enables tanks to spawn", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvWitchCanSpawn = CreateConVar("sm_witch_can_spawn", "1", "Tank and Witch ifier enables witches to spawn", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvWitchAvoidTank = CreateConVar("sm_witch_avoid_tank_spawn", "20", "Minimum flow amount witches should avoid tank spawns by, by half the value given on either side of the tank spawn", FCVAR_NOTIFY, true, 0.0, true, 100.0);

	g_cvVsBossBuffer = FindConVar("versus_boss_buffer");
	g_cvVsBossFlowMax = FindConVar("versus_boss_flow_max");
	g_cvVsBossFlowMin = FindConVar("versus_boss_flow_min");

	g_smStaticTankMaps = new StringMap();
	g_smStaticWitchMaps = new StringMap();

	g_aValidTankFlows = new ArrayList(2);
	g_aValidWitchFlows = new ArrayList(2);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	RegServerCmd("static_tank_map", StaticTank_Command);
	RegServerCmd("static_witch_map", StaticWitch_Command);
	RegServerCmd("reset_static_maps", Reset_Command);

	RegAdminCmd("sm_tank_witch_debug_info", Info_Cmd, ADMFLAG_KICK, "Dump spawn state info");

#if DEBUG
	RegConsoleCmd("sm_tank_witch_debug_test", Test_Cmd);
	RegConsoleCmd("sm_tank_witch_debug_profiler", Profiler_Cmd);
#endif
}

void LoadMapInfo() {
	char file[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, file, sizeof file, "configs/confogl/mapinfo.txt");
	if (FileExists(file)) {
		g_kvMIData = new KeyValues("MapInfo");
		if (!g_kvMIData.ImportFromFile(file))
			delete g_kvMIData;
	}
}

// ======================================
// Boss Spawn Control
// ======================================

public Action L4D_OnSpawnTank(const float vecPos[3], const float vecAng[3]) {
	return g_cvTankCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}

public Action L4D_OnSpawnWitch(const float vecPos[3], const float vecAng[3]) {
	return g_cvWitchCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}

public Action L4D2_OnSpawnWitchBride(const float vecPos[3], const float vecAng[3]) {
	return g_cvWitchCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}

// ======================================
// Current Map Cache
// ======================================

public void OnMapStart() {
	GetCurrentMapLower(g_sCurrentMap, sizeof g_sCurrentMap);
	if (g_kvMIData) {
		g_kvMIData.Rewind();
		g_kvMIData.JumpToKey(g_sCurrentMap);
	}
}

// ======================================
// Flow Handling
// ======================================

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	CreateTimer(0.5, AdjustBossFlow, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action AdjustBossFlow(Handle timer) {
	if (InSecondHalfOfRound())
		return Plugin_Stop;
	
	g_aValidTankFlows.Clear();
	g_aValidWitchFlows.Clear();

	int iMinFlow = RoundToCeil(g_cvVsBossFlowMin.FloatValue * 100);
	int iMaxFlow = RoundToFloor(g_cvVsBossFlowMax.FloatValue * 100);
	
	// mapinfo override
	if (g_kvMIData) {
		iMinFlow = g_kvMIData.GetNum("versus_boss_flow_min", iMinFlow);
		iMaxFlow = g_kvMIData.GetNum("versus_boss_flow_max", iMaxFlow);
	}
	PrintDebug("[AdjustBossFlow] flow: (%i, %i).", iMinFlow, iMaxFlow);

	if (g_cvTankCanSpawn.BoolValue && !IsStaticTankMap(g_sCurrentMap)) {
		PrintDebug("[AdjustBossFlow] Not static tank map. Flow tank enabled.");
		
		ArrayList aBannedFlows = new ArrayList(2);

		int interval[2];
		interval[0] = 0, interval[1] = iMinFlow - 1;
		if (IsValidInterval(interval))
			aBannedFlows.PushArray(interval);

		interval[0] = iMaxFlow + 1, interval[1] = 100;
		if (IsValidInterval(interval))
			aBannedFlows.PushArray(interval);

		if (g_kvMIData.JumpToKey("tank_ban_flow", false)) {
			if (g_kvMIData.GotoFirstSubKey()) {
				do {
					interval[0] = g_kvMIData.GetNum("min", -1);
					interval[1] = g_kvMIData.GetNum("max", -1);
					PrintDebug("[AdjustBossFlow] ban (%i, %i).", interval[0], interval[1]);
					if (IsValidInterval(interval))
						aBannedFlows.PushArray(interval);
				} while (g_kvMIData.GotoNextKey());
				g_kvMIData.GoBack();
			}
			g_kvMIData.GoBack();
		}

		MergeIntervals(aBannedFlows);
		MakeComplementaryIntervals(aBannedFlows, g_aValidTankFlows);
		
		delete aBannedFlows;
		
		// check each array index to see if it is within a ban range
		int iValidSpawnTotal = g_aValidTankFlows.Length;
		if (iValidSpawnTotal == 0) {
			SetTankPercent(0);
			PrintDebug("[AdjustBossFlow] Ban range covers entire flow range. Flow tank disabled.");
		}
		else {
			int iTankFlow = GetRandomIntervalNum(g_aValidTankFlows);
			PrintDebug("[AdjustBossFlow] iTankFlow: %i. iValidSpawnTotal: %i", iTankFlow, iValidSpawnTotal);
			SetTankPercent(iTankFlow);
		}
	}
	else {
		SetTankPercent(0);
		PrintDebug("[AdjustBossFlow] Static tank map. Flow tank disabled.");
	}
	
	if (g_cvWitchCanSpawn.BoolValue && !IsStaticWitchMap(g_sCurrentMap)) {
		PrintDebug("[AdjustBossFlow] Not static witch map. Flow witch enabled.");

		ArrayList aBannedFlows = new ArrayList(2);
		
		int interval[2];
		interval[0] = 0, interval[1] = iMinFlow - 1;
		if (IsValidInterval(interval))
			aBannedFlows.PushArray(interval);

		interval[0] = iMaxFlow + 1, interval[1] = 100;
		if (IsValidInterval(interval))
			aBannedFlows.PushArray(interval);

		if (g_kvMIData.JumpToKey("witch_ban_flow", false)) {
			if (g_kvMIData.GotoFirstSubKey()) {
				do {
					interval[0] = g_kvMIData.GetNum("min", -1);
					interval[1] = g_kvMIData.GetNum("max", -1);
					PrintDebug("[AdjustBossFlow] ban (%i, %i).", interval[0], interval[1]);
					if (IsValidInterval(interval))
						aBannedFlows.PushArray(interval);
				} while (g_kvMIData.GotoNextKey());
				g_kvMIData.GoBack();
			}
			g_kvMIData.GoBack();
		}

		if (GetTankAvoidInterval(interval)) {
			PrintDebug("[AdjustBossFlow] tank avoid (%i, %i)", interval[0], interval[1]);
			if (IsValidInterval(interval))
				aBannedFlows.PushArray(interval);
		}

		MergeIntervals(aBannedFlows);
		MakeComplementaryIntervals(aBannedFlows, g_aValidWitchFlows);

		delete aBannedFlows;
		
		// check each array index to see if it is within a ban range
		int iValidSpawnTotal = g_aValidWitchFlows.Length;
		if (iValidSpawnTotal == 0) {
			SetWitchPercent(0);
			PrintDebug("[AdjustBossFlow] Ban range covers entire flow range. Flow witch disabled.");
		}
		else {
			int iWitchFlow = GetRandomIntervalNum(g_aValidWitchFlows);
			PrintDebug("[AdjustBossFlow] iWitchFlow: %i. iValidSpawnTotal: %i", iWitchFlow, iValidSpawnTotal);
			SetWitchPercent(iWitchFlow);
		}
	}
	else {
		SetWitchPercent(0);
		PrintDebug("[AdjustBossFlow] Static witch map or witch not enabled. Flow witch disabled.");
	}
	
	PrintDebugInfoDump();

	return Plugin_Stop;
}

// ======================================
// Dynamic Adjust Witch
// ======================================

// Must be called before tank flow is changed
void DynamicAdjustWitchFlow(int iNewTankFlow) {
	if (g_cvWitchCanSpawn.BoolValue == false)
		return;
		
	int interval[2];
	if (!GetTankAvoidInterval(interval))
		return;

	if (!IsValidInterval(interval))
		return;
	
	// Restore the avoidance flow
	g_aValidWitchFlows.PushArray(interval);
	MergeIntervals(g_aValidWitchFlows);

	// Convert valid flows into banned flows
	ArrayList aBannedFlows = new ArrayList(2);
	MakeComplementaryIntervals(g_aValidWitchFlows, aBannedFlows);
	
	// New avoidance flow
	interval[0] = RoundToFloor(iNewTankFlow - (g_cvWitchAvoidTank.FloatValue / 2));
	interval[1] = RoundToCeil(iNewTankFlow + (g_cvWitchAvoidTank.FloatValue / 2));
	PrintDebug("[DynamicAdjustWitchFlow] new tank avoid (%i, %i)", interval[0], interval[1]);
	if (IsValidInterval(interval))
		aBannedFlows.PushArray(interval);

	// Convert it back
	MakeComplementaryIntervals(aBannedFlows, g_aValidWitchFlows);
	
	// You're done here
	delete aBannedFlows;

	// Sanity checks
	int iValidSpawnTotal = g_aValidWitchFlows.Length;
	if (iValidSpawnTotal == 0) {
		SetWitchPercent(0);
		PrintDebug("[DynamicAdjustWitchFlow] Ban range covers entire flow range. Flow witch disabled.");
	}
	else {
		// Check if old witch flow is banned this time
		int iWitchFlow = RoundFloat(L4D2Direct_GetVSWitchFlowPercent(0) * 100);
		if (interval[0] <= iWitchFlow <= interval[1]) {
			// Change it next to the borders first
			if (
				!IsWitchPercentValid((iWitchFlow = interval[1] + 1))
				&& !IsWitchPercentValid((iWitchFlow = interval[0] - 1))
			) {
				// Move onto a random flow otherwise
				iWitchFlow = GetRandomIntervalNum(g_aValidWitchFlows);
			}
			
			// Just do it
			PrintDebug("[DynamicAdjustWitchFlow] iWitchFlow: %i. iValidSpawnTotal: %i", iWitchFlow, iValidSpawnTotal);
			SetWitchPercent(iWitchFlow);
		}
	}
}

// ======================================
// Tank Avoid Flow
// ======================================

bool GetTankAvoidInterval(int interval[2]) {
	if (g_cvWitchAvoidTank.FloatValue == 0.0) {
		return false;
	}
	
	float flow = L4D2Direct_GetVSTankFlowPercent(0);
	if (flow == 0.0) {
		return false;
	}
	
	interval[0] = RoundToFloor((flow * 100) - (g_cvWitchAvoidTank.FloatValue / 2));
	interval[1] = RoundToCeil((flow * 100) + (g_cvWitchAvoidTank.FloatValue / 2));
	
	return true;
}

// ======================================
// Interval Methods
//   - based on ArrayList and int[2]
// ======================================

bool IsValidInterval(int interval[2]) {
	return interval[0] > -1 && interval[1] >= interval[0];
}

void MergeIntervals(ArrayList merged) {
	if (merged.Length < 2)
		return;

	ArrayList intervals = merged.Clone();
	SortADTArray(intervals, Sort_Ascending, Sort_Integer);

	merged.Clear();

	int current[2];
	intervals.GetArray(0, current);
	merged.PushArray(current);

	int intv_size = intervals.Length;
	for (int i = 1; i < intv_size; ++i) {
		intervals.GetArray(i, current);

		int back_index = merged.Length - 1;
		int back_R = merged.Get(back_index, 1);

		if (back_R < current[0]) { // not coincide
			merged.PushArray(current);
		} else {
			back_R = (back_R > current[1] ? back_R : current[1]); // override the right value with maximum
			merged.Set(back_index, back_R, 1);
		}
	}
	
	delete intervals;
}

void MakeComplementaryIntervals(ArrayList intervals, ArrayList dest) {
	int intv_size = intervals.Length;
	if (intv_size < 2)
		return;
	
	int intv[2];
	for (int i = 1; i < intv_size; ++i) {
		intv[0] = intervals.Get(i-1, 1) + 1;
		intv[1] = intervals.Get(i, 0) - 1;
		if (IsValidInterval(intv))
			dest.PushArray(intv);
	}
}

int GetRandomIntervalNum(ArrayList aList) {
	int total_length, size = aList.Length;
	int[] arrLength = new int[size];
	for (int i; i < size; ++i) {
		arrLength[i] = aList.Get(i, 1) - aList.Get(i, 0) + 1;
		total_length += arrLength[i];
	}
	
	int random = Math_GetRandomInt(0, total_length-1);
	
	PrintDebug("GetRandomIntervalNum - random: %i, total_length: %i", random, total_length);
	
	for (int i; i < size; ++i) {
		if (random < arrLength[i]) {
			return aList.Get(i, 0) + random;
		} else {
			random -= arrLength[i];
		}
	}
	return 0;
}

// ======================================
// Boss Spawn Scheme Commands
// ======================================

Action StaticTank_Command(int args) {
	char mapname[64];
	GetCmdArg(1, mapname, sizeof mapname);
	StrToLower(mapname);
	g_smStaticTankMaps.SetValue(mapname, true);
#if DEBUG
	PrintDebug("[StaticTank_Command] Added: %s", mapname);
#endif
	return Plugin_Handled;
}

Action StaticWitch_Command(int args) {
	char mapname[64];
	GetCmdArg(1, mapname, sizeof mapname);
	StrToLower(mapname);
	g_smStaticWitchMaps.SetValue(mapname, true);
#if DEBUG
	PrintDebug("[StaticWitch_Command] Added: %s", mapname);
#endif
	return Plugin_Handled;
}

Action Reset_Command(int args) {
	g_smStaticTankMaps.Clear();
	g_smStaticWitchMaps.Clear();
	return Plugin_Handled;
}

// ======================================
// Debug Commands
// ======================================

Action Info_Cmd(int client, int args) {
	PrintDebugInfoDump();
	return Plugin_Handled;
}

#if DEBUG
Action Test_Cmd(int client, int args) {
	PrintDebug("[Test_Cmd] Starting AdjustBossFlow timer...");
	CreateTimer(0.5, AdjustBossFlow, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

Action Profiler_Cmd(int client, int args) {
	if (args != 1) {
		ReplyToCommand(client, "[SM] Usage: sm_tank_witch_debug_profiler <times>");
		return Plugin_Handled;
	}
	char buffer[32];
	GetCmdArg(1, buffer, sizeof buffer);
	
	int times = StringToInt(buffer);
	FormatEx(buffer, sizeof buffer, "%i time%s", times, times > 1 ? "s" : "");
	PrintDebug("[Profiler_Cmd] Starting AdjustBossFlow profiler (%s)...", buffer);
	
	bool temp = g_cvDebug.BoolValue;
	g_cvDebug.BoolValue = false;
	
	Profiler profiler = new Profiler();
	profiler.Start();
	for (int i; i < times; ++i) {
		AdjustBossFlow(null);
	}
	
	profiler.Stop();
	
	g_cvDebug.BoolValue = temp;
	PrintDebug("[Profiler_Cmd] Spent %f seconds (%s)...", profiler.Time, buffer);
	
	delete profiler;
	return Plugin_Handled;
}
#endif

// ======================================
// Natives
// ======================================

int Native_IsStaticTankMap(Handle plugin, int numParams) {
	int bytes;

	char mapname[64];
	GetNativeString(1, mapname, sizeof mapname, bytes);

	if (bytes) {
		StrToLower(mapname);
		return IsStaticTankMap(mapname);
	} else {
		return IsStaticTankMap(g_sCurrentMap);
	}
}

int Native_IsStaticWitchMap(Handle plugin, int numParams) {
	int bytes;

	char mapname[64];
	GetNativeString(1, mapname, sizeof mapname, bytes);
	
	if (bytes) {
		StrToLower(mapname);
		return IsStaticWitchMap(mapname);
	} else {
		return IsStaticWitchMap(g_sCurrentMap);
	}
}

int Native_IsTankPercentValid(Handle plugin, int numParams) {
	int flow = GetNativeCell(1);
	return IsTankPercentValid(flow);
}

int Native_IsWitchPercentValid(Handle plugin, int numParams) {
	int flow = GetNativeCell(1);
	bool ignoreBlock = GetNativeCell(2);
	
	if (ignoreBlock) {
		ArrayList aValidFlows = g_aValidWitchFlows.Clone(), aTemp = g_aValidWitchFlows;
		
		int interval[2];
		if (GetTankAvoidInterval(interval) && IsValidInterval(interval)) {
			// Restore the avoidance flow
			aValidFlows.PushArray(interval);
			MergeIntervals(aValidFlows);
			g_aValidWitchFlows = aValidFlows;
		}
		
		bool result = IsWitchPercentValid(flow);
		
		g_aValidWitchFlows = aTemp;
		delete aValidFlows;
		
		return result;
	} else {
		return IsWitchPercentValid(flow);
	}
}

int Native_IsWitchPercentBlockedForTank(Handle plugin, int numParams) {
	int interval[2];
	if (GetTankAvoidInterval(interval) && IsValidInterval(interval)) {
		int flow = GetNativeCell(1);
		return (interval[0] <= flow <= interval[1]);
	}
	return false;
}

int Native_SetTankPercent(Handle plugin, int numParams) {
	int flow = GetNativeCell(1);
	if (!IsTankPercentValid(flow)) return false;
	DynamicAdjustWitchFlow(flow);
	SetTankPercent(flow);
	return true;
}

int Native_SetWitchPercent(Handle plugin, int numParams) {
	int flow = GetNativeCell(1);
	if (!IsWitchPercentValid(flow)) return false;
	SetWitchPercent(flow);
	return true;
}

// ======================================
// Helper Functions
// ======================================

bool IsStaticTankMap(const char[] map) {
	bool dummy;
	return g_smStaticTankMaps.GetValue(map, dummy);
}

bool IsStaticWitchMap(const char[] map) {
	bool dummy;
	return g_smStaticWitchMaps.GetValue(map, dummy);
}

bool IsTankPercentValid(int flow) {
	if (flow == 0) {
		return true;
	}
	int size = g_aValidTankFlows.Length;
	if (!size) {
		return false;
	}
	if (flow > g_aValidTankFlows.Get(size-1, 1)
		|| flow < g_aValidTankFlows.Get(0, 0)
	){ // out of bounds
		return false;
	}
	for (int i; i < size; ++i) {
		if (flow <= g_aValidTankFlows.Get(i, 1)) {
			return flow >= g_aValidTankFlows.Get(i, 0);
		}
	}
	return false;
}

bool IsWitchPercentValid(int flow){
	if (flow == 0) {
		return true;
	}
	int size = g_aValidWitchFlows.Length;
	if (!size) {
		return false;
	}
	if (flow > g_aValidWitchFlows.Get(size-1, 1)
		|| flow < g_aValidWitchFlows.Get(0, 0)
	){ // out of bounds
		return false;
	}
	for (int i; i < size; ++i) {
		if (flow <= g_aValidWitchFlows.Get(i, 1)) {
			return flow >= g_aValidWitchFlows.Get(i, 0);
		}
	}
	return false;
}

void SetTankPercent(int percent) {
	if (percent == 0) {
		L4D2Direct_SetVSTankFlowPercent(0, 0.0);
		L4D2Direct_SetVSTankFlowPercent(1, 0.0);
		L4D2Direct_SetVSTankToSpawnThisRound(0, false);
		L4D2Direct_SetVSTankToSpawnThisRound(1, false);
	} else {
		float newPercent = (float(percent) / 100);
		L4D2Direct_SetVSTankFlowPercent(0, newPercent);
		L4D2Direct_SetVSTankFlowPercent(1, newPercent);
		L4D2Direct_SetVSTankToSpawnThisRound(0, true);
		L4D2Direct_SetVSTankToSpawnThisRound(1, true);
	}
}

void SetWitchPercent(int percent) {
	if (percent == 0) {
		L4D2Direct_SetVSWitchFlowPercent(0, 0.0);
		L4D2Direct_SetVSWitchFlowPercent(1, 0.0);
		L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
		L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
	} else {
		float newPercent = (float(percent) / 100);
		L4D2Direct_SetVSWitchFlowPercent(0, newPercent);
		L4D2Direct_SetVSWitchFlowPercent(1, newPercent);
		L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
		L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
	}
}

// ======================================
// Stock Functions
// ======================================

stock float GetTankProgressFlow(int round) {
	return L4D2Direct_GetVSTankFlowPercent(round) - GetBossBuffer();
}

stock float GetWitchProgressFlow(int round) {
	return L4D2Direct_GetVSWitchFlowPercent(round) - GetBossBuffer();
}

stock float GetBossBuffer() {
	return g_cvVsBossBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance();
}

stock void PrintDebugInfoDump() {
	if (g_cvDebug.BoolValue) {
		PrintDebug("[Round 1] tank enabled: %i, tank flow: %f, display: %f, witch enabled: %i, witch flow: %f, display: %f", L4D2Direct_GetVSTankToSpawnThisRound(0), L4D2Direct_GetVSTankFlowPercent(0), GetTankProgressFlow(0), L4D2Direct_GetVSWitchToSpawnThisRound(0), L4D2Direct_GetVSWitchFlowPercent(0), GetWitchProgressFlow(0));
		PrintDebug("[Round 2] tank enabled: %i, tank flow: %f, display: %f, witch enabled: %i, witch flow: %f, display: %f", L4D2Direct_GetVSTankToSpawnThisRound(1), L4D2Direct_GetVSTankFlowPercent(1), GetTankProgressFlow(1), L4D2Direct_GetVSWitchToSpawnThisRound(1), L4D2Direct_GetVSWitchFlowPercent(1), GetWitchProgressFlow(0));
		
		char buffer[256] = "Valid Tank Intervals: ";
		
		int size = g_aValidTankFlows.Length;
		for (int i; i < size; ++i) {
			char sInterval[16];
			FormatEx(sInterval, 16, "[%i, %i]", g_aValidTankFlows.Get(i, 0), g_aValidTankFlows.Get(i, 1));
			StrCat(buffer, sizeof buffer, sInterval);
			if (i != size - 1) StrCat(buffer, sizeof buffer, ", ");
		}
		PrintDebug(buffer);
		
		strcopy(buffer, sizeof buffer, "Valid Witch Intervals: ");
		
		size = g_aValidWitchFlows.Length;
		for (int i; i < size; ++i) {
			char sInterval[16];
			FormatEx(sInterval, 16, "[%i, %i]", g_aValidWitchFlows.Get(i, 0), g_aValidWitchFlows.Get(i, 1));
			StrCat(buffer, sizeof buffer, sInterval);
			if (i != size - 1) StrCat(buffer, sizeof buffer, ", ");
		}
		PrintDebug(buffer);
	}
}

stock void PrintDebug(const char[] Message, any ...) {
	if (g_cvDebug.BoolValue) {
		char DebugBuff[256];
		VFormat(DebugBuff, sizeof DebugBuff, Message, 2);
		LogMessage(DebugBuff);
#if DEBUG
		PrintToChatAll(DebugBuff);
#endif
	}
}

/**
 * Is the second round of this map currently being played?
 *
 * @return bool
 */
stock bool InSecondHalfOfRound()
{
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}

#define SIZE_OF_INT	2147483647 // without 0
stock int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0) {
		random++;
	}

	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}

stock void StrToLower(char[] arg) {
	int length = strlen(arg);
	for (int i; i < length; i++) {
		arg[i] = CharToLower(arg[i]);
	}
}

stock int GetCurrentMapLower(char[] buffer, int buflen) {
	int iBytesWritten = GetCurrentMap(buffer, buflen);
	StrToLower(buffer);
	return iBytesWritten;
}
