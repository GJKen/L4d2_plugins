#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_NAME				"Map Changer"
#define PLUGIN_AUTHOR			"Alex Dragokas, fdxx, sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.5"
#define PLUGIN_URL				""

#define CVAR_FLAGS				FCVAR_NOTIFY
#define CONFIG_DATA				"data/map_changer.cfg"

enum {
	FINAL,
	FIRST,
	TRANSLATE
}

enum {
	FINALE_CHANGE_NONE			= 0,
	FINALE_CHANGE_VEHICLE_LEAVE	= 1,
	FINALE_CHANGE_FINALE_WIN	= 2,
	FINALE_CHANGE_CREDITS_START	= 4,
	FINALE_CHANGE_CREDITS_END	= 8
}

static const char
	g_sValveMaps[][][] = {
		{"c14m2_lighthouse",		"c1m1_hotel",			"死亡中心"		},
		{"c1m4_atrium",				"c2m1_highway",			"黑色狂欢节"	},
		{"c2m5_concert",			"c3m1_plankcountry",	"沼泽激战"		},
		{"c3m4_plantation",			"c4m1_milltown_a",		"暴风骤雨"		},
		{"c4m5_milltown_escape",	"c5m1_waterfront",		"教区"			},
		{"c5m5_bridge",				"c6m1_riverbank",		"短暂时刻"		},
		{"c6m3_port",				"c7m1_docks",			"牺牲"			},
		{"c7m3_port",				"c8m1_apartment",		"毫不留情"		},
		{"c8m5_rooftop",			"c9m1_alleys",			"坠机险途"		},
		{"c9m2_lots",				"c10m1_caves",			"死亡丧钟"		},
		{"c10m5_houseboat",			"c11m1_greenhouse",		"寂静时分"		},
		{"c11m5_runway",			"c12m1_hilltop",		"血腥收获"		},
		{"c12m5_cornfield",			"c13m1_alpinecreek",	"刺骨寒溪"		},
		{"c13m4_cutthroatcreek",	"c14m1_junkyard",		"临死一搏"		},
};

StringMap
	g_smNextMap,
	g_smTranslation;

ArrayList
	g_aRandomNextMap;

char
	g_sNextMap[64];

bool
	g_bUMHooked,
	g_bIsFinalMap,
	g_bChangeLevel,
	g_bFinaleRandomNextMap;

UserMsg
	g_umDisconnectToLobby;

ConVar
	g_cvFinaleChangeType,
	g_cvFinaleFailureCount,
	g_cvFinaleRandomNextMap;

int
	g_iFailureCount,
	g_iFinaleChangeType,
	g_iFinaleFailureCount;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

native void L4D2_ChangeLevel(const char[] map);
public void OnLibraryAdded(const char[] name) {
	if (strcmp(name, "l4d2_changelevel") == 0)
		g_bChangeLevel = true;
}

public void OnLibraryRemoved(const char[] name) {
	if (strcmp(name, "l4d2_changelevel") == 0)
		g_bChangeLevel = false;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	MarkNativeAsOptional("L4D2_ChangeLevel");
	
	CreateNative("MC_SetNextMap", Native_SetNextMap);
	RegPluginLibrary("map_changer");
	return APLRes_Success;
}

int Native_SetNextMap(Handle plugin, int numParams) {
	int maxlength;
	GetNativeStringLength(1, maxlength);
	maxlength += 1;
	char[] buffer = new char[maxlength];
	GetNativeString(1, buffer, maxlength);
	if (!IsMapValidEx(buffer))
		return 0;

	strcopy(g_sNextMap, sizeof g_sNextMap, buffer);
	return 1;
}

public void OnPluginStart() {
	g_smNextMap = new StringMap();
	g_smTranslation = new StringMap();
	g_aRandomNextMap = new ArrayList(ByteCountToCells(64));
	g_umDisconnectToLobby = GetUserMessageId("DisconnectToLobby");
	HookUserMessage(GetUserMessageId("StatsCrawlMsg"), umStatsCrawlMsg, false, umStatsCrawlMsgPost);
	CreateConVar("map_changer_version", PLUGIN_VERSION, "Map Changer plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_cvFinaleChangeType = 		CreateConVar("mapchanger_finale_change_type",		"12",	"0 - 终局不换地图(返回大厅); 1 - 救援载具离开时; 2 - 终局获胜时; 4 - 统计屏幕出现时; 8 - 统计屏幕结束时", CVAR_FLAGS);
	g_cvFinaleFailureCount =	CreateConVar("mapchanger_finale_failure_count",		"2",	"终局团灭几次自动换到下一张图", CVAR_FLAGS);
	g_cvFinaleRandomNextMap =	CreateConVar("mapchanger_finale_random_nextmap",	"0",	"终局是否启用随机下一关地图", CVAR_FLAGS);
	g_cvFinaleChangeType.AddChangeHook(CvarChanged);
	g_cvFinaleFailureCount.AddChangeHook(CvarChanged);
	g_cvFinaleRandomNextMap.AddChangeHook(CvarChanged);

	//AutoExecConfig(true);

	HookEvent("round_end", 				Event_RoundEnd, 		EventHookMode_PostNoCopy);
	HookEvent("finale_win", 			Event_FinaleWin,		EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving",	Event_VehicleLeaving,	EventHookMode_PostNoCopy);

	RegAdminCmd("sm_nmaps", cmdSetNext, ADMFLAG_RCON, "设置下一张地图");
}

Action cmdSetNext(int client, int args) {
	if (!g_bIsFinalMap) {
		ReplyToCommand(client, "当前地图非终局地图.");
		return Plugin_Handled;
	}
		
	if (args != 1) {
		ReplyToCommand(client, "\x01!setnext/sm_setnext <\x05第一章节地图代码\x01>.");
		return Plugin_Handled;
	}

	char map[64];
	GetCmdArg(1, map, sizeof map);
	if (!IsMapValidEx(map)) {
		ReplyToCommand(client, "无效的地图名.");
		return Plugin_Handled;
	}

	char buffer[254];
	int Id = FindMapId(map, FIRST);
	strcopy(g_sNextMap, sizeof g_sNextMap, map);
	if (Id == -1)
		Format(buffer, sizeof buffer, "\x01下一张地图已设置为 \x05%s\x01.", map);
	else
		Format(buffer, sizeof buffer, "\x01下一张地图已设置为 \x05%s \x01(\x05%s\x01)\x01.", map, g_sValveMaps[Id][TRANSLATE]);

	ReplyToCommand(client, "%s", buffer);
	return Plugin_Handled;
}

void ParseNextMapData() {
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof path, CONFIG_DATA);
	KeyValues kv = new KeyValues("NextMap");
	if (!FileExists(path)) {
		File file = OpenFile(path, "w");
		file.WriteLine("");
		delete file;

		for (int i; i < sizeof g_sValveMaps; i++) {
			if (kv.JumpToKey(g_sValveMaps[i][FINAL], true)) {
				kv.SetString("map", g_sValveMaps[i][FIRST]);
				kv.SetString("name", g_sValveMaps[i][TRANSLATE]);
				kv.Rewind();
				kv.ExportToFile(path);
			}
		}
	}

	g_smNextMap.Clear();
	g_smTranslation.Clear();
	if (kv.ImportFromFile(path)) {
		char buffer[64];
		for (int i; i < sizeof g_sValveMaps; i++) {
			if (kv.JumpToKey(g_sValveMaps[i][FINAL], true)) {
				kv.GetString("map", buffer, sizeof buffer, g_sValveMaps[i][FIRST]);
				StringToLowerCase(buffer);
				g_smNextMap.SetString(g_sValveMaps[i][FINAL], buffer, true);
				kv.GetString("name", buffer, sizeof buffer, g_sValveMaps[i][TRANSLATE]);
				StringToLowerCase(buffer);
				g_smTranslation.SetString(g_sValveMaps[i][FINAL], buffer, true);
				kv.Rewind();
			}
		}
	}

	delete kv;
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_iFinaleChangeType =		g_cvFinaleChangeType.IntValue;
	g_iFinaleFailureCount =		g_cvFinaleFailureCount.IntValue;
	g_bFinaleRandomNextMap =	g_cvFinaleRandomNextMap.BoolValue;
}

public void OnMapEnd() {
	g_iFailureCount = 0;
	g_sNextMap[0] = '\0';
	UnhookDisconnectToLobby();
}

public void OnMapStart() {
	ParseNextMapData();
	g_bIsFinalMap = L4D_IsMissionFinalMap();

	if (!g_aRandomNextMap.Length)
		InitRandomNextMapArray();

	if (L4D_IsFirstMapInScenario()) {
		char map[64];
		GetCurrentMap(map, sizeof map);
		StringToLowerCase(map);
		int idx = g_aRandomNextMap.FindString(map);
		if (idx != -1)
			g_aRandomNextMap.Erase(idx);
	}
}

void InitRandomNextMapArray() {
	for (int i; i < sizeof g_sValveMaps; i++)
		g_aRandomNextMap.PushString(g_sValveMaps[i][FIRST]);
}

void HookDisconnectToLobby() {
	if (!g_bUMHooked) {
		g_bUMHooked = true;
		HookUserMessage(g_umDisconnectToLobby, umDisconnectToLobby, true);
	}
}

void UnhookDisconnectToLobby() {
	if (g_bUMHooked) {
		UnhookUserMessage(g_umDisconnectToLobby, umDisconnectToLobby, true);
		g_bUMHooked = false;
	}
}

Action umStatsCrawlMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	if (!g_bIsFinalMap)
		return Plugin_Continue;

	if (g_iFinaleChangeType & FINALE_CHANGE_CREDITS_END)
		HookDisconnectToLobby();

	return Plugin_Continue;
}

void umStatsCrawlMsgPost(UserMsg msg_id, bool sent) {
	if (!g_bIsFinalMap)
		return;

	if (g_iFinaleChangeType & FINALE_CHANGE_CREDITS_START)
		FinaleMapChange();
}

Action umDisconnectToLobby(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	UnhookUserMessage(g_umDisconnectToLobby, umDisconnectToLobby, true);
	g_bUMHooked = false;

	if (!g_bIsFinalMap)
		return Plugin_Continue;

	if (g_iFinaleChangeType & FINALE_CHANGE_CREDITS_END) {
		FinaleMapChange();
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bIsFinalMap)
		return;

	g_iFailureCount++;
	if (g_iFinaleFailureCount && g_iFailureCount >= g_iFinaleFailureCount)
		FinaleMapChange();
}

void Event_FinaleWin(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bIsFinalMap)
		return;

	if (g_iFinaleChangeType & FINALE_CHANGE_FINALE_WIN)
		FinaleMapChange();
}

void Event_VehicleLeaving(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bIsFinalMap)
		return;

	if (g_iFinaleChangeType & FINALE_CHANGE_VEHICLE_LEAVE)
		FinaleMapChange();
}

void FinaleMapChange() {
	if (IsMapValidEx(g_sNextMap))
		ChangeLevel(g_sNextMap);
	else {
		char nextMap[64];
		if (g_bFinaleRandomNextMap)
			GetRandomStandard(nextMap, sizeof nextMap);
		else {
			char map[64];
			GetCurrentMap(map, sizeof map);
			if (!GetNextStandard(map, nextMap, sizeof nextMap)) {
				int Id = FindMapId(map, FINAL);
				strcopy(nextMap, sizeof nextMap, g_sValveMaps[Id == -1 ? 0 : Id][FIRST]);
			}
		}

		ChangeLevel(nextMap);
	}
}

bool GetNextStandard(const char[] map, char[] nextMap, int maxlength) {
	char buffer[64];
	strcopy(buffer, sizeof buffer, map);
	StringToLowerCase(buffer);
	if (!g_smNextMap.GetString(buffer, buffer, sizeof buffer))
		return false;

	strcopy(nextMap, maxlength, buffer);
	return IsMapValidEx(nextMap);
}

void GetRandomStandard(char[] nextMap, int maxlength) {
	char buffer[64];
	int idx = Math_GetRandomInt(0, g_aRandomNextMap.Length - 1);
	g_aRandomNextMap.GetString(idx, buffer, sizeof buffer);
	strcopy(nextMap, maxlength, buffer);
}

int FindMapId(const char[] map, const int type) {
	for (int i; i < sizeof g_sValveMaps; i++) {
		if (strcmp(map, g_sValveMaps[i][type], false) == 0)
			return i;
	}
	return -1;
}

void StringToLowerCase(char[] szInput) {
	int iIterator;
	while (szInput[iIterator] != EOS) {
		szInput[iIterator] = CharToLower(szInput[iIterator]);
		++iIterator;
	}
}

void ChangeLevel(const char[] map) {
	if (g_bChangeLevel)
		L4D2_ChangeLevel(map);
	else
		ServerCommand("changelevel %s", map);
}

bool IsMapValidEx(const char[] map) {
	if (!map[0])
		return false;

	char foundmap[1];
	return FindMap(map, foundmap, sizeof foundmap) == FindMap_Found;
}

// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/math.inc
/**
 * Returns a random, uniform Integer number in the specified (inclusive) range.
 * This is safe to use multiple times in a function.
 * The seed is set automatically for each plugin.
 * Rewritten by MatthiasVance, thanks.
 *
 * @param min			Min value used as lower border
 * @param max			Max value used as upper border
 * @return				Random Integer number between min and max
 */
int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0) {
		random++;
	}

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}