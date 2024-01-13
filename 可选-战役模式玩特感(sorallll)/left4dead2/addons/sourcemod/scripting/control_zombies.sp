#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
//#include <sdkhooks>
//#include <sdktools>
#include <colors>
#include <dhooks>
#include <left4dhooks>
#include <sourcescramble>

#define DEBUG 			1
#define BENCHMARK		0
#if BENCHMARK
	#include <profiler>
	Profiler g_profiler;
#endif

#define PLUGIN_NAME				"Control Zombies In Co-op"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"3.6.1"
#define PLUGIN_URL				"https://steamcommunity.com/id/sorallll"

#define GAMEDATA 				"control_zombies"
#define CVAR_FLAGS 				FCVAR_NOTIFY
#define SOUND_CLASSMENU			"ui/helpful_event_1.wav"

#define SI_MAX_SIZE				6
#define COLOR_NORMAL			0
#define COLOR_INCAPA			1
#define COLOR_BLACKW			2
#define COLOR_VOMITED			3

Data
	g_eData[MAXPLAYERS + 1];

ArrayList
	g_aPatches;

Handle
	g_hTimer,
	//g_hSDK_CTerrorPlayer_SetBecomeGhostAt,
	g_hSDK_CTerrorGameRules_HasPlayerControlledZombies;

MemoryPatch
	g_mpStatsCondition;

DynamicDetour
	g_ddForEachTerrorPlayer_SpawnablePZScan;

ConVar
	g_cGameMode,
	g_cMaxTankPlayer,
	g_cMapFilterTank,
	g_cSurvivorLimit,
	g_cSurvivorChance,
	g_cSbAllBotGame,
	g_cAllowAllBotSur,
	g_cSurvivorMaxInc,
	g_cExchangeTeam,
	g_cPZSuicideTime,
	g_cPZPunishTime,
	g_cPZPunishHealth,
	g_cAutoDisplayMenu,
	g_cPZTeamLimit,
	g_cTakeOverGhost,
	g_cCmdCooldownTime,
	g_cCmdEnterCooling,
	g_cLotTargetPlayer,
	g_cPZChangeTeamTo,
	g_cGlowColorEnable,
	g_cGlowColor[4],
	g_cUserFlagBits,
	g_cImmunityLevels;

static const char
	g_sZombieName[][] = {
		"smoker",
		"boomer",
		"hunter",
		"spitter",
		"jockey",
		"charger"
	};

char
	g_sGameMode[32];

bool
	g_bLateLoad,
	g_bLeftSafeArea,
	g_bSbAllBotGame,
	g_bAllowAllBotSur,
	g_bExchangeTeam,
	g_bTakeOverGhost,
	g_bGlowColorEnable,
	g_bOnPassPlayerTank,
	g_bOnMaterializeFromGhost;

int
	g_iControlled = -1,
	g_iRoundStart,
	g_iPlayerSpawn,
	g_iSpawnablePZ,
	g_iTransferTankBot,
	m_hHiddenWeapon,
	RestartScenarioTimer,
	g_iSurvivorMaxInc,
	g_iMaxTankPlayer,
	g_iMapFilterTank,
	g_iSurvivorLimit,
	g_iPZSuicideTime,
	g_iPZPunishTime,
	g_iPZTeamLimit,
	g_iPZChangeTeamTo,
	g_iAutoDisplayMenu,
	g_iCmdEnterCooling,
	g_iLotTargetPlayer,
	g_iGlowColor[4],
	g_iUserFlagBits[7],
	g_iImmunityLevels[7];

float
	g_fPZPunishHealth,
	g_fSurvivorChance,
	g_fCmdCooldownTime;

enum struct Player {
	char AuthId[MAX_AUTHID_LENGTH];

	bool IsPlayerPB;
	bool ClassCmdUsed;

	int TankBot;
	int Bot;
	int Player;
	int LastTeamID;
	int ModelIndex;
	int ModelEntRef;
	int Materialized;
	int EnteredGhost;

	float LastUsedTime;
	float SuicideStart;
}

Player
	g_ePlayer[MAXPLAYERS + 1];

// 如果签名失效, 请到此处更新https://github.com/Psykotikism/L4D1-2_Signatures
public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

#if DEBUG
Handle g_hSDK_CTerrorPlayer_PlayerZombieAbortControl;
#endif

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	if (!IsDedicatedServer()) {
		strcopy(error, err_max, "插件仅支持专用服务器.");
		return APLRes_SilentFailure;
	}

	CreateNative("CZ_SetSpawnablePZ", Native_SetSpawnablePZ);

	RegPluginLibrary("control_zombies");

	g_bLateLoad = late;
	return APLRes_Success;
}

any Native_SetSpawnablePZ(Handle plugin, int numParams) {
	g_iSpawnablePZ = GetNativeCell(1);
	return 0;
}

public void OnPluginStart() {
	InitData();
	LoadTranslations("common.phrases");
	CreateConVar("control_zombies_version", PLUGIN_VERSION, "Control Zombies In Co-op plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_cMaxTankPlayer =				CreateConVar("cz_max_tank_player",					"1",					"坦克玩家达到多少后插件将不再控制玩家接管(0=不接管坦克)", CVAR_FLAGS, true, 0.0);
	g_cMapFilterTank =				CreateConVar("cz_map_filter_tank",					"3",					"在哪些地图上才允许叛变和接管坦克(0=禁用叛变和接管坦克,1=非结局地图,2=结局地图,3=所有地图)", CVAR_FLAGS, true, 0.0);
	g_cSurvivorLimit =				CreateConVar("cz_allow_survivor_limit",				"1",					"至少有多少名正常生还者(未被控,未倒地,未死亡)时,才允许玩家接管坦克", CVAR_FLAGS, true, 0.0);
	g_cSurvivorChance =				CreateConVar("cz_survivor_allow_chance",			"0.0",					"准备叛变的玩家数量为0时,自动抽取生还者和感染者玩家的几率(排除闲置旁观玩家)(0.0=不自动抽取)", CVAR_FLAGS);
	g_cExchangeTeam =				CreateConVar("cz_exchange_team",					"0",					"特感玩家杀死生还者玩家后是否互换队伍?(0=否,1=是)", CVAR_FLAGS);
	g_cPZSuicideTime =				CreateConVar("cz_pz_suicide_time",					"120",					"特感玩家复活后自动处死的时间(0=不会处死复活后的特感玩家)", CVAR_FLAGS, true, 0.0);
	g_cPZPunishTime =				CreateConVar("cz_pz_punish_time",					"10",					"特感玩家在ghost状态下切换特感类型后下次复活延长的时间(0=插件不会延长复活时间)", CVAR_FLAGS, true, 0.0);
	g_cPZPunishHealth =				CreateConVar("cz_pz_punish_health",					"0.5",					"特感玩家在ghost状态下切换特感类型是否进行血量惩罚(0.0=不惩罚.计算方式为当前血量乘以该值)", CVAR_FLAGS, true, 0.0);
	g_cAutoDisplayMenu =			CreateConVar("cz_atuo_display_menu",				"1",					"在感染玩家进入灵魂状态后自动向其显示更改类型的菜单?(0=不显示,-1=每次都显示,大于0=每回合总计显示的最大次数)", CVAR_FLAGS, true, -1.0);
	g_cPZTeamLimit =				CreateConVar("cz_pz_team_limit",					"2",					"感染玩家数量达到多少后将限制使用sm_team3命令(-1=感染玩家不能超过生还玩家,大于等于0=感染玩家不能超过该值)", CVAR_FLAGS, true, -1.0);
	g_cTakeOverGhost =				CreateConVar("cz_takeover_ghost",					"1",					"插件在控制玩家接管坦克后是否进入ghost状态", CVAR_FLAGS);
	g_cCmdCooldownTime =			CreateConVar("cz_cmd_cooldown_time",				"60.0",					"sm_team2,sm_team3命令的冷却时间(0.0-无冷却)", CVAR_FLAGS, true, 0.0);
	g_cCmdEnterCooling =			CreateConVar("cz_return_enter_cooling",				"31",					"什么情况下sm_team2,sm_team3命令会进入冷却(1=使用其中一个命令,2=坦克玩家掉控,4=坦克玩家死亡,8=坦克玩家未及时重生,16=特感玩家杀掉生还者玩家,31=所有)", CVAR_FLAGS);
	g_cLotTargetPlayer =			CreateConVar("cz_lot_target_player",				"7",					"抽取哪些玩家来接管坦克?(-1=由游戏自身控制,0=不抽取,1=叛变玩家,2=生还者,4=感染者)", CVAR_FLAGS);
	g_cPZChangeTeamTo =				CreateConVar("cz_pz_change_team_to",				"0",					"换图,过关以及任务失败时是否自动将特感玩家切换到哪个队伍?(0=不切换,1=旁观者,2=生还者)", CVAR_FLAGS);
	g_cGlowColorEnable =			CreateConVar("cz_survivor_color_enable",			"1",					"是否给生还者创发光建模型?(0=否,1=是)", CVAR_FLAGS);
	g_cGlowColor[COLOR_NORMAL] =	CreateConVar("cz_survivor_color_normal",			"0 180 0",				"特感玩家看到的正常状态生还者发光颜色", CVAR_FLAGS);
	g_cGlowColor[COLOR_INCAPA] =	CreateConVar("cz_survivor_color_incapacitated",		"180 0 0",				"特感玩家看到的倒地状态生还者发光颜色", CVAR_FLAGS);
	g_cGlowColor[COLOR_BLACKW] =	CreateConVar("cz_survivor_color_blackwhite",		"255 255 255",			"特感玩家看到的黑白状态生还者发光颜色", CVAR_FLAGS);
	g_cGlowColor[COLOR_VOMITED] =	CreateConVar("cz_survivor_color_nowit",				"155 0 180",			"特感玩家看到的被Boomer喷或炸中过的生还者发光颜色", CVAR_FLAGS);
	g_cUserFlagBits =				CreateConVar("cz_user_flagbits",					";z;;z;z;;z",			"哪些标志能绕过sm_team2,sm_team3,sm_pb,sm_tt,sm_pt,sm_class,鼠标中键重置冷却的使用限制(留空表示所有人都不会被限制)", CVAR_FLAGS);
	g_cImmunityLevels =				CreateConVar("cz_immunity_levels",					"99;99;99;99;99;99;99", "要达到什么免疫级别才能绕过sm_team2,sm_team3,sm_pb,sm_tt,sm_pt,sm_class,鼠标中键重置冷的使用限制", CVAR_FLAGS);

	AutoExecConfig(true, "controll_zombies");
	// 想要生成cfg的,把上面那一行的注释去掉保存后重新编译就行

	g_cGameMode =		FindConVar("mp_gamemode");
	g_cSbAllBotGame =	FindConVar("sb_all_bot_game");
	g_cAllowAllBotSur =	FindConVar("allow_all_bot_survivor_team");
	g_cSurvivorMaxInc =	FindConVar("survivor_max_incapacitated_count");
	FindConVar("z_max_player_zombies").SetBounds(ConVarBound_Upper, true, float(MaxClients));

	g_cGameMode.AddChangeHook(CvarChanged_Mode);
	g_cSbAllBotGame.AddChangeHook(CvarChanged);
	g_cAllowAllBotSur.AddChangeHook(CvarChanged);
	g_cSurvivorMaxInc.AddChangeHook(CvarChanged_Color);

	g_cMaxTankPlayer.AddChangeHook(CvarChanged);
	g_cMapFilterTank.AddChangeHook(CvarChanged);
	g_cSurvivorLimit.AddChangeHook(CvarChanged);
	g_cSurvivorChance.AddChangeHook(CvarChanged);
	g_cExchangeTeam.AddChangeHook(CvarChanged);
	g_cPZSuicideTime.AddChangeHook(CvarChanged);
	g_cPZPunishTime.AddChangeHook(CvarChanged);
	g_cPZPunishHealth.AddChangeHook(CvarChanged);
	g_cAutoDisplayMenu.AddChangeHook(CvarChanged);
	g_cPZTeamLimit.AddChangeHook(CvarChanged);
	g_cTakeOverGhost.AddChangeHook(CvarChanged);
	g_cCmdCooldownTime.AddChangeHook(CvarChanged);
	g_cCmdEnterCooling.AddChangeHook(CvarChanged);
	g_cLotTargetPlayer.AddChangeHook(CvarChanged);
	g_cPZChangeTeamTo.AddChangeHook(CvarChanged);

	g_cGlowColorEnable.AddChangeHook(CvarChanged_Color);
	for (int i; i < 4; i++)
		g_cGlowColor[i].AddChangeHook(CvarChanged_Color);

	g_cUserFlagBits.AddChangeHook(CvarChanged_Access);
	g_cImmunityLevels.AddChangeHook(CvarChanged_Access);

	//RegAdminCmd("sm_cz", cmdCz, ADMFLAG_ROOT, "测试");

	RegConsoleCmd("sm_team2",	cmdTeam2,			"切换到Team 2.");
	RegConsoleCmd("sm_team3",	cmdTeam3,			"切换到Team 3.");
	RegConsoleCmd("sm_pb",		cmdPanBian,			"提前叛变.");
	RegConsoleCmd("sm_tt",		cmdTakeOverTank,	"接管坦克.");
	RegConsoleCmd("sm_pt",		cmdTransferTank,	"转交坦克.");
	RegConsoleCmd("sm_class",	cmdChangeClass,		"更改特感类型.");

	if (g_bLateLoad)
		g_bLeftSafeArea = L4D_HasAnySurvivorLeftSafeArea();

	PluginStateChanged();
}

public void OnPluginEnd() {
	for (int i = 1; i <= MaxClients; i++)
		RemoveSurGlow(i);
}

public void OnConfigsExecuted() {
	GetCvars_General();
	GetCvars_Color();
	GetCvars_Access();
	PluginStateChanged();
}

void CvarChanged_Mode(ConVar convar, const char[] oldValue, const char[] newValue) {
	PluginStateChanged();
}

void PluginStateChanged() {
	g_cGameMode.GetString(g_sGameMode, sizeof g_sGameMode);

	int last = g_iControlled;
	g_iControlled = SDKCall(g_hSDK_CTerrorGameRules_HasPlayerControlledZombies);
	if (g_iControlled == 1) {
		Toggle(false);
		if (last != g_iControlled) {
			delete g_hTimer;
			for (int i = 1; i <= MaxClients; i++) {
				ResetClientData(i);
				RemoveSurGlow(i);
			}
		}
	}
	else {
		Toggle(true);
		if (last != g_iControlled) {
			if (HasPZ()) {
				float time = GetEngineTime();
				for (int i = 1; i <= MaxClients; i++) {
					if (!IsClientInGame(i))
						continue;

					switch (GetClientTeam(i)) {
						case 2:
							CreateSurGlow(i);

						case 3: {
							if (g_iPZSuicideTime > 0 && !IsFakeClient(i) && IsPlayerAlive(i))
								g_ePlayer[i].SuicideStart = time;
						}
					}
				}

				delete g_hTimer;
				g_hTimer = CreateTimer(0.1, tmrPlayer, _, TIMER_REPEAT);
			}
		}
	}
}

void Toggle(bool enable) {
	static bool enabled;
	if (!enabled && enable) {
		enabled = true;
		TogglePatches(true);
		ToggleDetours(true);

		HookEvent("round_start",				Event_RoundStart,		EventHookMode_PostNoCopy);
		HookEvent("round_end",					Event_RoundEnd,			EventHookMode_PostNoCopy);
		HookEvent("map_transition",				Event_RoundEnd,			EventHookMode_PostNoCopy);
		HookEvent("finale_vehicle_leaving",		Event_RoundEnd,			EventHookMode_PostNoCopy);
		HookEvent("player_team",				Event_PlayerTeam);
		HookEvent("player_spawn",				Event_PlayerSpawn);
		HookEvent("ghost_spawn_time",			Event_GhostSpawnTime,	EventHookMode_Pre);
		HookEvent("player_death",				Event_PlayerDeath,		EventHookMode_Pre);
		HookEvent("tank_frustrated",			Event_TankFrustrated);
		HookEvent("player_bot_replace",			Event_PlayerBotReplace);
		HookEvent("player_disconnect",			Event_PlayerDisconnect,	EventHookMode_Pre);

		AddCommandListener(Listener_callvote, "callvote");
	}
	else if (enabled && !enable) {
		enabled = false;
		TogglePatches(false);
		ToggleDetours(false);

		UnhookEvent("round_start",				Event_RoundStart,		EventHookMode_PostNoCopy);
		UnhookEvent("round_end",				Event_RoundEnd,			EventHookMode_PostNoCopy);
		UnhookEvent("map_transition",			Event_RoundEnd,			EventHookMode_PostNoCopy);
		UnhookEvent("finale_vehicle_leaving",	Event_RoundEnd,			EventHookMode_PostNoCopy);
		UnhookEvent("player_team",				Event_PlayerTeam);
		UnhookEvent("player_spawn",				Event_PlayerSpawn);
		UnhookEvent("ghost_spawn_time",			Event_GhostSpawnTime,	EventHookMode_Pre);
		UnhookEvent("player_death",				Event_PlayerDeath,		EventHookMode_Pre);
		UnhookEvent("tank_frustrated",			Event_TankFrustrated);
		UnhookEvent("player_bot_replace",		Event_PlayerBotReplace);
		UnhookEvent("player_disconnect",		Event_PlayerDisconnect,	EventHookMode_Pre);

		RemoveCommandListener(Listener_callvote, "callvote");
	}
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_General();
}

void GetCvars_General() {
	g_iMaxTankPlayer =		g_cMaxTankPlayer.IntValue;
	g_iMapFilterTank =		g_cMapFilterTank.IntValue;
	g_iSurvivorLimit =		g_cSurvivorLimit.IntValue;
	g_fSurvivorChance =		g_cSurvivorChance.FloatValue;
	g_bSbAllBotGame =		g_cSbAllBotGame.BoolValue;
	g_bAllowAllBotSur =		g_cAllowAllBotSur.BoolValue;
	g_bExchangeTeam =		g_cExchangeTeam.BoolValue;
	g_iPZSuicideTime =		g_cPZSuicideTime.IntValue;
	g_iPZPunishTime =		g_cPZPunishTime.IntValue;
	g_fPZPunishHealth =		g_cPZPunishHealth.FloatValue;
	g_iAutoDisplayMenu =	g_cAutoDisplayMenu.IntValue;
	g_iPZTeamLimit =		g_cPZTeamLimit.IntValue;
	g_bTakeOverGhost =		g_cTakeOverGhost.BoolValue;
	g_fCmdCooldownTime =	g_cCmdCooldownTime.FloatValue;
	g_iCmdEnterCooling =	g_cCmdEnterCooling.IntValue;
	g_iLotTargetPlayer =	g_cLotTargetPlayer.IntValue;
	g_iPZChangeTeamTo =		g_cPZChangeTeamTo.IntValue;
}

void CvarChanged_Color(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_Color();
}

void GetCvars_Color() {
	bool last = g_bGlowColorEnable;
	g_bGlowColorEnable = g_cGlowColorEnable.BoolValue;
	g_iSurvivorMaxInc = g_cSurvivorMaxInc.IntValue;

	int i;
	for (; i < 4; i++)
		g_iGlowColor[i] = GetColor(g_cGlowColor[i]);

	if (last != g_bGlowColorEnable) {
		if (g_bGlowColorEnable) {
			if (HasPZ()) {
				for (i = 1; i <= MaxClients; i++)
					CreateSurGlow(i);
			}
		}
		else {
			for (i = 1; i <= MaxClients; i++)
				RemoveSurGlow(i);
		}
	}
}

int GetColor(ConVar convar) {
	char sTemp[12];
	convar.GetString(sTemp, sizeof sTemp);

	if (sTemp[0] == '\0')
		return 1;

	char sColors[3][4];
	int color = ExplodeString(sTemp, " ", sColors, sizeof sColors, sizeof sColors[]);

	if (color != 3)
		return 1;

	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);

	return color > 0 ? color : 1;
}

void CvarChanged_Access(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_Access();
}

void GetCvars_Access() {
	GetFlagBits();
	GetImmunitys();
}

void GetFlagBits() {
	char sTemp[512];
	g_cUserFlagBits.GetString(sTemp, sizeof sTemp);

	char sUserFlagBits[7][32];
	ExplodeString(sTemp, ";", sUserFlagBits, sizeof sUserFlagBits, sizeof sUserFlagBits[]);

	for (int i; i < 7; i++)
		g_iUserFlagBits[i] = ReadFlagString(sUserFlagBits[i]);
}

void GetImmunitys() {
	char sTemp[512];
	g_cImmunityLevels.GetString(sTemp, sizeof sTemp);

	char sImmunityLevels[7][12];
	ExplodeString(sTemp, ";", sImmunityLevels, sizeof sImmunityLevels, sizeof sImmunityLevels[]);

	for (int i; i < 7; i++)
		g_iImmunityLevels[i] = StringToInt(sImmunityLevels[i]);
}

bool CheckClientAccess(int client, int iIndex) {
	if (!g_iUserFlagBits[iIndex])
		return true;

	static int bits;
	if ((bits = GetUserFlagBits(client)) & ADMFLAG_ROOT == 0 && bits & g_iUserFlagBits[iIndex] == 0)
		return false;

	if (!CacheSteamID(client))
		return false;

	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, g_ePlayer[client].AuthId);
	if (admin == INVALID_ADMIN_ID)
		return true;

	return admin.ImmunityLevel >= g_iImmunityLevels[iIndex];
}

bool CacheSteamID(int client) {
	if (g_ePlayer[client].AuthId[0] != '\0')
		return true;

	if (GetClientAuthId(client, AuthId_Steam2, g_ePlayer[client].AuthId, sizeof Player::AuthId))
		return true;

	g_ePlayer[client].AuthId[0] = '\0';
	return false;
}
/*
Action cmdCz(int client, int args) {
	ReplyToCommand(client, "SpawnTime %f", L4D_GetPlayerSpawnTime(client));
	return Plugin_Handled;
}*/

Action cmdTeam2(int client, int args) {
	if (g_iControlled == 1) {
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!CheckClientAccess(client, 0)) {
		// ReplyToCommand(client, "无权使用该指令");
		// return Plugin_Handled;
		float time = GetEngineTime();
		if (g_ePlayer[client].LastUsedTime > time) {
			PrintToChat(client, "\x01请等待 \x05%.1f秒 \x01再使用该指令", g_ePlayer[client].LastUsedTime - time);
			return Plugin_Handled;
		}
	}

	if (GetClientTeam(client) != 3) {
		PrintToChat(client, "只有感染者才能使用该指令");
		return Plugin_Handled;
	}

	if (g_iCmdEnterCooling & (1 << 0))
		g_ePlayer[client].LastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
	ChangeTeamToSurvivor(client);
	return Plugin_Handled;
}

Action cmdTeam3(int client, int args) {
	if (g_iControlled == 1) {
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if (!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 3)
		return Plugin_Handled;

	if (!CheckClientAccess(client, 1)) {
		// ReplyToCommand(client, "无权使用该指令");
		// return Plugin_Handled;
		float time = GetEngineTime();
		if (g_ePlayer[client].LastUsedTime > time) {
			PrintToChat(client, "\x01请等待 \x05%.1f秒 \x01再使用该指令", g_ePlayer[client].LastUsedTime - time);
			return Plugin_Handled;
		}

		int team3 = _GetTeamCount(3);
		int team2 = _GetTeamCount(2);
		if ((g_iPZTeamLimit >= 0 && team3 >= g_iPZTeamLimit) || (g_iPZTeamLimit == -1 && team3 >= team2)) {
			PrintToChat(client, "已到达感染玩家数量限制");
			return Plugin_Handled;
		}
	}

	if (g_iCmdEnterCooling & (1 << 0))
		g_ePlayer[client].LastUsedTime = GetEngineTime() + g_fCmdCooldownTime;

	g_eData[client].Clean();
	int bot = GetBotOfIdlePlayer(client);
	g_eData[client].Save(bot ? bot : client, false);
	ChangeClientTeam(client, 3);
	return Plugin_Handled;
}

Action cmdPanBian(int client, int args) {
	if (g_iControlled == 1) {
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!CheckClientAccess(client, 2)) {
		ReplyToCommand(client, "无权使用该指令");
		return Plugin_Handled;
	}

	if (!MapFilterTank()) {
		ReplyToCommand(client, "当前地图已禁用该指令");
		return Plugin_Handled;
	}

	if (!g_ePlayer[client].IsPlayerPB) {
		g_ePlayer[client].IsPlayerPB = true;
		CPrintToChat(client, "已加入叛变列表");
		CPrintToChat(client, "再次输入该指令可退出叛变列表");
		CPrintToChat(client, "坦克出现后将会随机从叛变列表中抽取1人接管");
		CPrintToChat(client, "{olive}当前叛变玩家列表:");

		for (int i = 1; i <= MaxClients; i++) {
			if (g_ePlayer[i].IsPlayerPB && IsClientInGame(i) && !IsFakeClient(i))
				CPrintToChat(client, "-> {red}%N", i);
		}
	}
	else {
		g_ePlayer[client].IsPlayerPB = false;
		CPrintToChat(client, "已退出叛变列表");
	}

	return Plugin_Handled;
}

bool MapFilterTank() {
	if (!L4D_IsMissionFinalMap())
		return g_iMapFilterTank & (1 << 0) != 0;

	return g_iMapFilterTank & (1 << 1) != 0;
}

Action cmdTakeOverTank(int client, int args) {
	if (g_iControlled == 1) {
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if (OnEndScenario()) {
		ReplyToCommand(client, "回合尚未开始");
		return Plugin_Handled;
	}

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!CheckClientAccess(client, 3)) {
		ReplyToCommand(client, "无权使用该指令");
		return Plugin_Handled;
		/*float time = GetEngineTime();
		if (g_ePlayer[client].LastUsedTime > time) {
			PrintToChat(client, "\x01请等待 \x05%.1f秒 \x01再使用该指令", g_ePlayer[client].LastUsedTime - time);
			return Plugin_Handled;
		}*/
	}

	if (!MapFilterTank()) {
		ReplyToCommand(client, "当前地图已禁用该指令");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8) {
		ReplyToCommand(client, "你当前已经是坦克");
		return Plugin_Handled;
	}

	int tank;
	if (args) {
		char arg[32];
		GetCmdArg(1, arg, sizeof arg);
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		if ((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof target_name, tn_is_ml)) <= 0) {
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}

		if (IsFakeClient(target_list[0]) && GetClientTeam(target_list[0]) == 3 && GetEntProp(target_list[0], Prop_Send, "m_zombieClass") == 8)
			tank = target_list[0];
	}
	else {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8) {
				tank = i;
				break;
			}
		}
	}

	if (!tank) {
		ReplyToCommand(client, "无可供接管的坦克存在");
		return Plugin_Handled;
	}

	if (!TakeOverLimit(tank, client, client))
		return Plugin_Handled;

	int team = GetClientTeam(client);
	switch (team) {
		case 1: {
			g_eData[client].Clean();
			int bot = GetBotOfIdlePlayer(client);
			g_eData[client].Save(bot ? bot : client, false);
			ChangeClientTeam(client, 3);
		}

		case 2: {
				g_eData[client].Clean();
				g_eData[client].Save(client, false);
				ChangeClientTeam(client, 3);
		}

		case 3: {
			if (IsPlayerAlive(client)) {
				L4D_CleanupPlayerState(client);
				ForcePlayerSuicide(client);
			}
		}

		default:
			ChangeClientTeam(client, 3);
	}

	if (GetClientTeam(client) == 3)
		g_ePlayer[client].LastTeamID = g_ePlayer[client].LastTeamID == 2 ? 2 : team != 3 ? 2 : 3;

	if (TakeOverZombieBot(client, tank, false) == 8 && IsPlayerAlive(client)) {
		if (g_iCmdEnterCooling & (1 << 0))
			g_ePlayer[client].LastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
	}

	return Plugin_Handled;
}

bool TakeOverLimit(int tank, int target, int reply) {
	switch (GetClientTeam(target)) {
		case 2: {
			if (!AllowSurTakeOver()) {
				PrintToChat(reply, "生还者接管坦克将会导致任务失败, 请等待生还者玩家足够后再尝试");
				return false;
			}
		}

		case 3: {
			if (IsPlayerAlive(target) && GetEntProp(target, Prop_Send, "m_zombieClass") == 8) {
				PrintToChat(reply, "拟接管玩家目前已经是坦克");
				return false;
			}
		}
	}

	if (GetTankCount(1) - (IsFakeClient(tank) ? 0 : 1) >= g_iMaxTankPlayer) {
		PrintToChat(reply, "\x01坦克玩家数量已达到预设值 ->\x05%d", g_iMaxTankPlayer);
		return false;
	}

	if (GetNormalCount() < g_iSurvivorLimit) {
		PrintToChat(reply, "\x01完全正常的生还者数量小于预设值 ->\x05%d", g_iSurvivorLimit);
		return false;
	}

	return true;
}

bool CanTarget(int client, int target) {
	return client == target || CanUserTarget(client, target) && !CanUserTarget(target, client);
}

Action cmdTransferTank(int client, int args) {
	if (g_iControlled == 1) {
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if (OnEndScenario()) {
		ReplyToCommand(client, "回合尚未开始");
		return Plugin_Handled;
	}

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!MapFilterTank()) {
		ReplyToCommand(client, "当前地图已禁用该指令");
		return Plugin_Handled;
	}

	bool access = CheckClientAccess(client, 4);
	bool isAliveTank = GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
	if (!access && !isAliveTank) {
		ReplyToCommand(client, "你当前不是存活的坦克");
		return Plugin_Handled;
	}

	if (args && isAliveTank) {
		char arg[32];
		GetCmdArg(1, arg, sizeof arg);
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		if ((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, target_name, sizeof target_name, tn_is_ml)) <= 0) {
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}

		if (!CanTarget(client, target_list[0])) {
			PrintToChat(client, "权限低于目标玩家");
			return Plugin_Handled;
		}

		OfferTankMenu(client, target_list[0], client, access);
	}
	else {
		if (GetTankCount(-1)) {
			if (access)
				ShowTankListMenu(client);
			else
				ShowPlayerListMenu(client, client);
		}
		else
			ReplyToCommand(client, "无存活的坦克存在");
	}

	return Plugin_Handled;
}

void OfferTankMenu(int tank, int target, int reply, bool access = false) {
	if (!TakeOverLimit(tank, target, reply))
		return;

	if (access && CanTarget(reply, target))
		TransferTank(tank, target, reply);
	else {
		Menu menu = new Menu(OfferTank_MenuHandler);
		menu.SetTitle("是否接受 %N 的坦克控制权转移?", tank);

		char info[12];
		FormatEx(info, sizeof info, "%d", GetClientUserId(tank));
		menu.AddItem(info, "是");
		menu.AddItem("no", "否");
		menu.ExitButton = false;
		menu.ExitBackButton = false;
		menu.Display(target, 15);
	}
}

int OfferTank_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			if (GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
				ReplyToCommand(client, "你当前已经是坦克");
			else {
				char item[12];
				menu.GetItem(param2, item, sizeof item);
				if (item[0] == 'n')
					return 0;

				int tank = GetClientOfUserId(StringToInt(item));
				if (tank && IsClientInGame(tank) && GetClientTeam(tank) == 3 && IsPlayerAlive(tank) && GetEntProp(tank, Prop_Send, "m_zombieClass") == 8)
					TransferTank(tank, client, client);
				else
					ReplyToCommand(client, "目标玩家已不是存活的坦克");
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void ShowTankListMenu(int client) {
	char uid[12];
	char disp[MAX_NAME_LENGTH + 24];
	Menu menu = new Menu(ShowTankList_MenuHandler);
	menu.SetTitle("选择要转交的坦克");
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i) || GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
			continue;

		FormatEx(uid, sizeof uid, "%d", GetClientUserId(i));
		FormatEx(disp, sizeof disp, "%d HP - %N", GetEntProp(i, Prop_Data, "m_iHealth"), i);
		menu.AddItem(uid, disp);
	}

	menu.ExitBackButton = false;
	menu.Display(client, 30);
}

int ShowTankList_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[12];
			menu.GetItem(param2, item, sizeof item);
			int target = GetClientOfUserId(StringToInt(item));
			if (target && IsClientInGame(target) && GetClientTeam(target) == 3 && IsPlayerAlive(target) && GetEntProp(target, Prop_Send, "m_zombieClass") == 8)
				ShowPlayerListMenu(client, target);
			else {
				ReplyToCommand(client, "目标坦克已失效, 请重新选择");
				ShowTankListMenu(client);
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void ShowPlayerListMenu(int client, int target) {
	char info[32];
	char uid[2][12];
	char disp[MAX_NAME_LENGTH + 12];
	Menu menu = new Menu(ShowPlayerList_MenuHandler);
	menu.SetTitle("选择要给予控制权的玩家");
	FormatEx(uid[0], sizeof uid[], "%d", GetClientUserId(target));
	for (int i = 1; i <= MaxClients; i++) {
		if (i == target || !IsClientInGame(i) || IsFakeClient(i))
			continue;

		FormatEx(uid[1], sizeof uid[], "%d", GetClientUserId(i));
		switch (GetClientTeam(i)) {
			case 1:
				FormatEx(disp, sizeof disp, "%s - %N", GetBotOfIdlePlayer(i) ? "闲置" : "观众", i);

			case 2:
				FormatEx(disp, sizeof disp, "生还 - %N", i);

			case 3:
				FormatEx(disp, sizeof disp, "感染 - %N", i);
		}

		ImplodeStrings(uid, sizeof uid, "|", info, sizeof info);
		menu.AddItem(info, disp);
	}

	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

int ShowPlayerList_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			char info[2][16];
			menu.GetItem(param2, item, sizeof item);
			ExplodeString(item, "|", info, sizeof info, sizeof info[]);
			int tank = GetClientOfUserId(StringToInt(info[0]));
			if (!tank || !IsClientInGame(tank) || GetClientTeam(tank) != 3 || !IsPlayerAlive(tank) || GetEntProp(tank, Prop_Send, "m_zombieClass") != 8) {
				ReplyToCommand(client, "目标坦克已失效");
				return 0;
			}

			int target = GetClientOfUserId(StringToInt(info[1]));
			if (!target || !IsClientInGame(target)) {
				ReplyToCommand(client, "目标玩家已失效, 请重新选择");
				ShowPlayerListMenu(client, tank);
			}
			else
				OfferTankMenu(tank, target, client, CheckClientAccess(client, 4));
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void TransferTank(int tank, int target, int reply) {
	if (!TakeOverLimit(tank, target, reply))
		return;

	int team = GetClientTeam(target);
	switch (team) {
		case 1: {
			g_eData[target].Clean();
			int bot = GetBotOfIdlePlayer(target);
			g_eData[target].Save(bot ? bot : target, false);
			ChangeClientTeam(target, 3);
		}

		case 2: {
				g_eData[target].Clean();
				g_eData[target].Save(target, false);
				ChangeClientTeam(target, 3);
		}

		case 3: {
			if (IsPlayerAlive(target)) {
				L4D_CleanupPlayerState(target);
				ForcePlayerSuicide(target);
			}
		}

		default:
			ChangeClientTeam(target, 3);
	}

	if (GetClientTeam(target) == 3)
		g_ePlayer[target].LastTeamID = g_ePlayer[target].LastTeamID == 2 ? 2 : team != 3 ? 2 : 3;

	int ghost = GetEntProp(tank, Prop_Send, "m_isGhost");
	if (ghost)
		SetEntProp(tank, Prop_Send, "m_isGhost", 0);

	if (IsFakeClient(tank))
		g_iTransferTankBot = tank;
	else {
		Event event = CreateEvent("tank_frustrated", true);
		event.SetInt("userid", GetClientUserId(tank));
		event.Fire(false);

		g_iTransferTankBot = 0;
		g_bOnPassPlayerTank = true;
		L4D_ReplaceWithBot(tank);
		g_bOnPassPlayerTank = false;
		L4D_SetClass(tank, 3);
		L4D_State_Transition(tank, STATE_GHOST);
	}

	if (g_iTransferTankBot && TakeOverZombieBot(target, g_iTransferTankBot, !!ghost) == 8 && IsPlayerAlive(target)) {
		if (g_iCmdEnterCooling & (1 << 0))
			g_ePlayer[target].LastUsedTime = GetEngineTime() + g_fCmdCooldownTime;

		/*if (ghost)
			EnterGhostMode(target);*/

		CPrintToChatAll("{green}★ {olive}%N{default}({red}坦克控制权{default}) 已由 {olive}%N {default}转交给 {olive}%N", tank, reply, target);
	}
}

Action cmdChangeClass(int client, int args) {
	if (g_iControlled == 1) {
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!CheckClientAccess(client, 5)) {
		ReplyToCommand(client, "无权使用该指令");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) != 3 || !IsPlayerAlive(client) || !GetEntProp(client, Prop_Send, "m_isGhost")) {
		PrintToChat(client, "灵魂状态下的特感才能使用该指令");
		return Plugin_Handled;
	}

	if (g_ePlayer[client].Materialized > 0) {
		PrintToChat(client, "第一次灵魂状态下才能使用该指令");
		return Plugin_Handled;
	}

	if (args == 1) {
		char arg[16];
		GetCmdArg(1, arg, sizeof arg);
		int zombieClass;
		int class = GetZombieClass(arg);
		if (class == -1) {
			CPrintToChat(client, "{olive}!class{default}/{olive}sm_class {default}<{red}class{default}>.");
			CPrintToChat(client, "<{olive}class{default}> [ {red}smoker {default}| {red}boomer {default}| {red}hunter {default}| {red}spitter {default}| {red}jockey {default}| {red}charger {default}]");
		}
		else if (++class == (zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass")))
			CPrintToChat(client, "目标特感类型与当前特感类型相同");
		else if (zombieClass == 8)
			CPrintToChat(client, "{red}Tank {default}无法更改特感类型");
		else
			SetClassAndPunish(client, class);
	}
	else {
		if (GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
			SelectClassMenu(client);
		else
			CPrintToChat(client, "{red}Tank {default}无法更改特感类型");
	}

	return Plugin_Handled;
}

void DisplayClassMenu(int client) {
	Menu menu = new Menu(DisplayClass_MenuHandler);
	menu.SetTitle("!class付出一定代价更改特感类型?");
	menu.AddItem("yes", "是");
	menu.AddItem("no", "否");
	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.Display(client, 15);
}

int DisplayClass_MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			if (param2 == 0 && !IsFakeClient(param1) && GetClientTeam(param1) == 3 && IsPlayerAlive(param1) && GetEntProp(param1, Prop_Send, "m_isGhost"))
				SelectClassMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void SelectClassMenu(int client) {
	char info[2];
	Menu menu = new Menu(SelectClass_MenuHandler);
	menu.SetTitle("选择要切换的特感");
	int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass") - 1;
	for (int i; i < SI_MAX_SIZE; i++) {
		if (i == zombieClass)
			continue;

		FormatEx(info, sizeof info, "%d", i);
		menu.AddItem(info, g_sZombieName[i]);
	}
	menu.ExitButton = true;
	menu.ExitBackButton = false;
	menu.Display(client, 30);
}

int SelectClass_MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			int zombieClass;
			if (!IsFakeClient(param1) && GetClientTeam(param1) == 3 && IsPlayerAlive(param1) && (zombieClass = GetEntProp(param1, Prop_Send, "m_zombieClass")) != 8 && GetEntProp(param1, Prop_Send, "m_isGhost")) {
				char item[2];
				menu.GetItem(param2, item, sizeof item);
				int class = StringToInt(item);
				if (++class != zombieClass)
					SetClassAndPunish(param1, class);
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int GetZombieClass(const char[] sClass) {
	for (int i; i < 6; i++) {
		if (strcmp(sClass, g_sZombieName[i], false) == 0)
			return i;
	}
	return -1;
}

Action Listener_callvote(int client, const char[] command, int argc) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;

	if (GetClientTeam(client) == 3) {
		CPrintToChat(client, "{red}感染者无人权");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

// https://gist.github.com/ProdigySim/04912e5e76f69027f8c4
// Spawn State - These look like flags, but get used like static values quite often.
// These names were pulled from reversing client.dll--specifically CHudGhostPanel::OnTick()'s uses of the "#L4D_Zombie_UI_*" strings
//
// SPAWN_OK             0
// SPAWN_DISABLED       1  "Spawning has been disabled..." (e.g. director_no_specials 1)
// WAIT_FOR_SAFE_AREA   2  "Waiting for the Survivors to leave the safe area..."
// WAIT_FOR_FINALE      4  "Waiting for the finale to begin..."
// WAIT_FOR_TANK        8  "Waiting for Tank battle conclusion..."
// SURVIVOR_ESCAPED    16  "The Survivors have escaped..."
// DIRECTOR_TIMEOUT    32  "The Director has called a time-out..." (lol wat)
// WAIT_FOR_STAMPEDE   64  "Waiting for the next stampede of Infected..."
// CAN_BE_SEEN        128  "Can't spawn here" "You can be seen by the Survivors"
// TOO_CLOSE          256  "Can't spawn here" "You are too close to the Survivors"
// RESTRICTED_AREA    512  "Can't spawn here" "This is a restricted area"
// INSIDE_ENTITY     1024  "Can't spawn here" "Something is blocking this spot"
public void OnPlayerRunCmdPost(int client) {
	if (g_iControlled == 1)
		return;

	if (IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client))
		return;

	if (GetEntProp(client, Prop_Data, "m_afButtonPressed") & IN_ZOOM == 0)
		return;

	if (GetEntProp(client, Prop_Send, "m_isGhost")) {
		if (!g_ePlayer[client].Materialized && CheckClientAccess(client, 5))
			SetClassAndPunish(client, GetNextClass(client));
	}
	else if (CheckClientAccess(client, 6))
		SetNextActivationTime(client, 0.1); // 管理员鼠标中键重置技能冷却
}

bool SetClassAndPunish(int client, int class) {
	if (class < 1 || class > 6)
		return false;

	L4D_SetClass(client, class);
	if (g_fPZPunishHealth)
		SetEntityHealth(client, RoundToCeil(GetClientHealth(client) * g_fPZPunishHealth));
	g_ePlayer[client].ClassCmdUsed = true;
	return true;
}

int GetNextClass(int client) {
	int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (zombieClass < 1 || zombieClass > 6)
		return -1;

	return zombieClass % SI_MAX_SIZE + 1;
}

void SetNextActivationTime(int client, float time) {
	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if (ability > MaxClients) {
		SetEntPropFloat(ability, Prop_Send, "m_duration", time);
		SetEntPropFloat(ability, Prop_Send, "m_timestamp", GetGameTime() + time);
	}
}

public void OnMapStart() {
	PrecacheSound(SOUND_CLASSMENU);
}

public void OnMapEnd() {
	delete g_hTimer;

	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bLeftSafeArea = false;
}

public void OnClientPutInServer(int client) {
	if (!IsFakeClient(client))
		ResetClientData(client);
}

public void OnClientDisconnect(int client) {
	RemoveSurGlow(client);
	if (IsFakeClient(client))
		return;

	g_ePlayer[client].AuthId[0] = '\0';
	if (!IsClientInGame(client) || GetClientTeam(client) != 3)
		g_ePlayer[client].LastTeamID = 0;
}

void ResetClientData(int client) {
	g_eData[client].Clean();

	g_ePlayer[client].EnteredGhost = 0;
	g_ePlayer[client].Materialized = 0;
	g_ePlayer[client].SuicideStart = 0.0;

	g_ePlayer[client].IsPlayerPB = false;
	g_ePlayer[client].ClassCmdUsed = false;
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client) {
	g_bLeftSafeArea = true;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		RemoveInfectedClips();
	g_iRoundStart = 1;

	for (int i = 1; i <= MaxClients; i++)
		g_ePlayer[i].SuicideStart = 0.0;
}

// 移除一些限制特感的透明墙体, 增加活动空间
void RemoveInfectedClips() {
	int iEnt = MaxClients + 1;
	while ((iEnt = FindEntityByClassname(iEnt, "func_playerinfected_clip")) != -1)
		RemoveEntity(iEnt);

	iEnt = MaxClients + 1;
	while ((iEnt = FindEntityByClassname(iEnt, "func_playerghostinfected_clip")) != -1)
		RemoveEntity(iEnt);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bLeftSafeArea = false;

	for (int i = 1; i <= MaxClients; i++) {
		ResetClientData(i);
		ForceChangeTeam(i, g_ePlayer[i].LastTeamID == 2 ? 2 : g_iPZChangeTeamTo);
	}
}

void ForceChangeTeam(int client, int targetTeam) {
	if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3) {
		switch (targetTeam) {
			case 1:
				ChangeClientTeam(client, 1);

			case 2:
				ChangeTeamToSurvivor(client);
		}
	}
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;

	RemoveSurGlow(client);
	if (IsFakeClient(client))
		return;

	g_ePlayer[client].Materialized = 0;
	g_ePlayer[client].SuicideStart = 0.0;

	int team = event.GetInt("team");
	if (team == 3)
		CreateTimer(0.1, tmrLadderAndGlow, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);

	switch (event.GetInt("oldteam")) {
		case 0: {
			if (team == 3 && (g_iPZChangeTeamTo || g_ePlayer[client].LastTeamID == 2)) {
				DataPack pack = new DataPack();
				RequestFrame(NextFrame_ForceChangeTeam, pack);
				pack.WriteCell(event.GetInt("userid"));
				pack.WriteCell(g_ePlayer[client].LastTeamID == 2 ? 2 : g_iPZChangeTeamTo);
			}

			g_ePlayer[client].LastTeamID = 0;
		}

		case 3: {
			g_ePlayer[client].LastTeamID = 0;

			if (team == 2 && GetEntProp(client, Prop_Send, "m_isGhost"))
				SetEntProp(client, Prop_Send, "m_isGhost", 0);

			CreateTimer(0.1, tmrLadderAndGlow, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

Action tmrLadderAndGlow(Handle timer, int client) {
	if (g_iControlled == 1)
		return Plugin_Stop;

	client = GetClientOfUserId(client);
	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	if (GetClientTeam(client) == 3) {
		// g_cGameMode.ReplicateToClient(client, "versus");
		if (_GetTeamCount(3) == 1) {
			for (int i = 1; i <= MaxClients; i++)
				CreateSurGlow(i);

			delete g_hTimer;
			g_hTimer = CreateTimer(0.1, tmrPlayer, _, TIMER_REPEAT);
		}
	}
	else {
		g_cGameMode.ReplicateToClient(client, g_sGameMode);

		int i = 1;
		for (; i <= MaxClients; i++)
			RemoveSurGlow(i);

		if (!HasPZ())
			delete g_hTimer;
		else {
			for (i = 1; i <= MaxClients; i++)
				CreateSurGlow(i);
		}
	}

	return Plugin_Continue;
}

void NextFrame_ForceChangeTeam(DataPack pack) {
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int targetTeam = pack.ReadCell();
	delete pack;

	if (!g_iControlled && client)
		ForceChangeTeam(client, targetTeam);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		RemoveInfectedClips();
	g_iPlayerSpawn = 1;

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client)/* || !IsPlayerAlive(client)*/)
		return;

	g_ePlayer[client].TankBot = 0;

	if (g_bOnPassPlayerTank)
		g_iTransferTankBot = client;
	else if (!g_bOnMaterializeFromGhost)
		RequestFrame(NextFrame_PlayerSpawn, userid); // player_bot_replace在player_spawn之后触发, 延迟一帧进行接管判断
}

void NextFrame_PlayerSpawn(int client) {
	if (g_iControlled == 1)
		return;

	if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client) || IsClientInKickQueue(client) || !IsPlayerAlive(client))
		return;

	switch (GetClientTeam(client)) {
		case 2: {
			if (g_hTimer)
				CreateSurGlow(client);
		}

		case 3: {
			if (g_ePlayer[client].TankBot == 2)
				return;

			if (IsFakeClient(client) && !OnEndScenario() && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && GetTankCount(1) < g_iMaxTankPlayer)
				TakeOverTank(client);
		}
	}
}

Action Event_GhostSpawnTime(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 3)
		return Plugin_Continue;

	if (g_iPZPunishTime > 0 && g_ePlayer[client].ClassCmdUsed) {
		int time = event.GetInt("spawntime") + g_iPZPunishTime;
		// left4dhooks-v1.123
		L4D_SetBecomeGhostAt(client, GetGameTime() + float(time)); // SDKCall(g_hSDK_CTerrorPlayer_SetBecomeGhostAt, client, GetGameTime() + float(time));
		event.SetInt("spawntime", time);
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;

	g_ePlayer[client].Materialized = 0;
	g_ePlayer[client].SuicideStart = 0.0;

	switch (GetClientTeam(client)) {
		case 2:	{
			RemoveSurGlow(client);
			if (g_bExchangeTeam && !IsFakeClient(client)) {
				int attacker = GetClientOfUserId(event.GetInt("attacker"));
				if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && !IsFakeClient(attacker) && GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass") != 8) {
					ChangeClientTeam(client, 3);
					CPrintToChat(client, "{green}★ {red}生还者玩家 {default}被 {red}特感玩家 {default}杀死后, {olive}二者互换队伍");

					if (g_iCmdEnterCooling & (1 << 4))
						g_ePlayer[client].LastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
					RequestFrame(NextFrame_ForceChangeTeamSurvivor, event.GetInt("attacker"));
					CPrintToChat(attacker, "{green}★ {red}特感玩家 {default}杀死 {red}生还者玩家 {default}后, {olive}二者互换队伍");
				}
			}
		}

		case 3: {
			if (!IsFakeClient(client) && g_ePlayer[client].LastTeamID == 2) {
				RequestFrame(NextFrame_ForceChangeTeamSurvivor, event.GetInt("userid"));
				if (g_iCmdEnterCooling & (1 << 2))
					g_ePlayer[client].LastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
			}
		}
	}
}

Action tmrPlayer(Handle timer) {
	if (g_iControlled == 1) {
		g_hTimer = null;
		return Plugin_Stop;
	}

	#if BENCHMARK
	g_profiler = new Profiler();
	g_profiler.Start();
	#endif

	static float time;
	time = GetEngineTime();

	static int i;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i))
			continue;

		switch (GetClientTeam(i)) {
			case 2: {
				if (!g_bGlowColorEnable)
					continue;

				if (!IsPlayerAlive(i)) {
					if (IsValidEntRef(g_ePlayer[i].ModelEntRef))
						RemoveSurGlow(i);

					continue;
				}

				if (!IsValidEntRef(g_ePlayer[i].ModelEntRef)) {
					CreateSurGlow(i);
					continue;
				}

				if (GetEntPropEnt(g_ePlayer[i].ModelEntRef, Prop_Send, "moveparent") != i)
					SetAttached(EntRefToEntIndex(g_ePlayer[i].ModelEntRef), i);

				static int modelIndex;
				modelIndex = GetEntProp(i, Prop_Data, "m_nModelIndex");
				if (g_ePlayer[i].ModelIndex != modelIndex) {
					g_ePlayer[i].ModelIndex = modelIndex;

					static char model[128];
					GetClientModel(i, model, sizeof model);
					SetEntityModel(g_ePlayer[i].ModelEntRef, model);
				}

				SetGlowColor(i);
			}

			case 3: {
				if (IsFakeClient(i))
					continue;

				static float lastQuery[MAXPLAYERS + 1];
				if (time - lastQuery[i] >= 5.0) {
					QueryClientConVar(i, "mp_gamemode", queryMpGamemode); //g_cGameMode.ReplicateToClient(i, "versus");
					lastQuery[i] = time;
				}

				if (!IsPlayerAlive(i))
					continue;

				if (!g_bLeftSafeArea) {
					// 生还未离开安全区域则重置处死时间
					if (g_iPZSuicideTime > 0)
						g_ePlayer[i].SuicideStart = time;
					continue;
				}

				if (GetEntProp(i, Prop_Send, "m_zombieClass") != 8) {
					if (g_ePlayer[i].SuicideStart && time - g_ePlayer[i].SuicideStart >= g_iPZSuicideTime) {
						ForcePlayerSuicide(i);
						CPrintToChat(i, "{olive}特感玩家存活时限{default}-> {red}%d秒", g_iPZSuicideTime);
						g_ePlayer[i].SuicideStart = 0.0;
					}
				}
				/*else if (!GetEntProp(i, Prop_Send, "m_isGhost")) {
					static bool frustrated[MAXPLAYERS + 1];
					if (frustrated[i] && L4D_GetTankFrustration(i) > 99 && GetEntityFlags(i) & FL_ONFIRE == 0) {
						frustrated[i] = false;
						// CTerrorPlayer::UpdateZombieFrustration(CTerrorPlayer *__hidden this)
						Event event = CreateEvent("tank_frustrated", true);
						event.SetInt("userid", GetClientUserId(i));
						event.Fire(false);

						L4D_ReplaceWithBot(i);
						L4D_SetClass(i, 3);
						L4D_State_Transition(i, STATE_GHOST);
					}
					else {
						frustrated[i] = L4D_GetTankFrustration(i) > 99;
						// 这里延迟0.1秒等待系统自动掉控, 如果出了Bug系统没进行掉控操作, 则由插件进行
					}
				}*/
			}
		}
	}

	#if BENCHMARK
	g_profiler.Stop();
	PrintToServer("ProfilerTime: %f", g_profiler.Time);
	#endif

	return Plugin_Continue;
}

// 与Silvers的[L4D & L4D2] Coop Markers - Flow Distance插件进行兼容 (https://forums.alliedmods.net/showthread.php?p=2682584)
void queryMpGamemode(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue) {
	if (g_iControlled == 1)
		return;

	if (result != ConVarQuery_Okay)
		return;

	if (GetClientTeam(client) != 3)
		return;

	if (strcmp(cvarValue, "versus", false) == 0)
		return;

	g_cGameMode.ReplicateToClient(client, "versus");
}

void Event_TankFrustrated(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsFakeClient(client) || g_ePlayer[client].LastTeamID != 2)
		return;

	RequestFrame(NextFrame_ForceChangeTeamSurvivor, GetClientUserId(client));
	CPrintToChat(client, "{green}★ {default}丢失 {olive}Tank控制权 {default}后自动返回 {blue}生还者队伍");

	if (g_iCmdEnterCooling & (1 << 1))
		g_ePlayer[client].LastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
}

void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast) {
	int botId = event.GetInt("bot");
	int playerId = event.GetInt("player");
	int bot = GetClientOfUserId(botId);
	int player = GetClientOfUserId(playerId);

	g_ePlayer[player].Bot = botId;
	g_ePlayer[bot].Player = playerId;

	if (GetClientTeam(bot) == 3 && GetEntProp(bot, Prop_Send, "m_zombieClass") == 8) {
		if (IsFakeClient(player))
			g_ePlayer[bot].TankBot = 1; // 防卡功能中踢出FakeClient后, 第二次触发Tank产生并替换原有的Tank(BOT替换BOT)
		else
			g_ePlayer[bot].TankBot = 2; // 主动或被动放弃Tank控制权(BOT替换玩家)

		SetEntProp(bot, Prop_Data, "m_iHealth", GetEntProp(player, Prop_Data, "m_iHealth"));
		SetEntProp(bot, Prop_Data, "m_iMaxHealth", GetEntProp(player, Prop_Data, "m_iMaxHealth"));
	}
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 2)
		return;

	int jockey = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	if (jockey != -1) {
		int flags = GetCommandFlags("dismount");
		SetCommandFlags("dismount", flags & ~FCVAR_CHEAT);
		FakeClientCommand(jockey, "dismount");
		SetCommandFlags("dismount", flags);
	}
}

bool HasPZ() {
	static int i;
	for (i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
			return true;
	}
	return false;
}

int _GetTeamCount(int team = -1) {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && (team == -1 || GetClientTeam(i) == team))
			count++;
	}
	return count;
}

int GetTankCount(int filter = -1) {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i) || GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
			continue;

		if (filter == -1 || !IsFakeClient(i) == view_as<bool>(filter))
			count++;
	}
	return count;
}

void TeleportToSurvivor(int client) {
	int target = 1;
	ArrayList aClients = new ArrayList(2);

	for (; target <= MaxClients; target++) {
		if (target == client || !IsClientInGame(target) || GetClientTeam(target) != 2 || !IsPlayerAlive(target))
			continue;

		aClients.Set(aClients.Push(!GetEntProp(target, Prop_Send, "m_isIncapacitated") ? 0 : !GetEntProp(target, Prop_Send, "m_isHangingFromLedge") ? 1 : 2), target, 1);
	}

	if (!aClients.Length)
		target = 0;
	else {
		aClients.Sort(Sort_Descending, Sort_Integer);

		target = aClients.Length - 1;
		target = aClients.Get(Math_GetRandomInt(aClients.FindValue(aClients.Get(target, 0)), target), 1);
	}

	delete aClients;

	if (target) {
		SetInvincibilityTime(client, 1.0);
		SetEntProp(client, Prop_Send, "m_bDucked", 1);
		SetEntityFlags(client, GetEntityFlags(client)|FL_DUCKING);

		float vPos[3];
		GetClientAbsOrigin(target, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
	}
}

void SetInvincibilityTime(int client, float flDuration) {
	static int m_invulnerabilityTimer = -1;
	if (m_invulnerabilityTimer == -1)
		m_invulnerabilityTimer = FindSendPropInfo("CTerrorPlayer", "m_noAvoidanceTimer") - 12;

	SetEntDataFloat(client, m_invulnerabilityTimer + 4, flDuration);
	SetEntDataFloat(client, m_invulnerabilityTimer + 8, GetGameTime() + flDuration);
}

int FindUselessSurBot(bool alive) {
	int client;
	ArrayList aClients = new ArrayList(2);

	for (int i = MaxClients; i >= 1; i--) {
		if (!IsValidSurBot(i))
			continue;

		client = GetClientOfUserId(g_ePlayer[i].Player);
		aClients.Set(aClients.Push(IsPlayerAlive(i) == alive ? (!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 2 ? 0 : 1) : (!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 2 ? 2 : 3)), i, 1);
	}

	if (!aClients.Length)
		client = 0;
	else {
		aClients.Sort(Sort_Descending, Sort_Integer);

		client = aClients.Length - 1;
		client = aClients.Get(Math_GetRandomInt(aClients.FindValue(aClients.Get(client, 0)), client), 1);
	}

	delete aClients;
	return client;
}

bool IsValidSurBot(int client) {
	return IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && GetClientTeam(client) == 2 && !GetIdlePlayerOfBot(client);
}

int GetBotOfIdlePlayer(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && GetIdlePlayerOfBot(i) == client)
			return i;
	}
	return 0;
}

int GetIdlePlayerOfBot(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis) {
	if (g_iControlled == 1)
		return Plugin_Continue;

	if (g_iLotTargetPlayer == -1)
		return Plugin_Continue;

	if (!IsFakeClient(tank_index)) {
		L4D_SetTankFrustration(tank_index, 100);
		L4D2Direct_SetTankPassedCount(L4D2Direct_GetTankPassedCount() + 1);
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

int GetPendingPlayer() {
	int client = 1;
	ArrayList aClients = new ArrayList(2);

	bool allowSur = AllowSurTakeOver();
	for (; client <= MaxClients; client++) {
		if (!IsClientInGame(client) || IsFakeClient(client))
			continue;

		switch (GetClientTeam(client)) {
			case 2: {
				if (!allowSur)
					continue;

				if (g_ePlayer[client].IsPlayerPB) {
					if (g_iLotTargetPlayer & (1 << 0))
						aClients.Set(aClients.Push(0), client, 1);
				}
				else if (g_iLotTargetPlayer & (1 << 1))
					aClients.Set(aClients.Push(1), client, 1);
			}

			case 3: {
				if (IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
					continue;

				/*if (GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_pendingTankPlayerIndex") == client)
					continue;*/

				if (g_ePlayer[client].IsPlayerPB) {
					if (g_iLotTargetPlayer & (1 << 0))
						aClients.Set(aClients.Push(0), client, 1);
				}
				else if (g_iLotTargetPlayer & (1 << 2))
					aClients.Set(aClients.Push(1), client, 1);
			}
		}
	}

	if (!aClients.Length)
		client = 0;
	else {
		if (aClients.FindValue(0) != -1) {
			aClients.Sort(Sort_Descending, Sort_Integer);
			client = aClients.Get(Math_GetRandomInt(aClients.FindValue(0), aClients.Length - 1), 1);
		}
		else if (g_fSurvivorChance > 0.0 && Math_GetRandomFloat(0.0, 1.0) <= g_fSurvivorChance)
			client = aClients.Get(Math_GetRandomInt(0, aClients.Length - 1), 1);
		else
			client = 0;
	}

	delete aClients;
	return client;
}

int TakeOverTank(int tank) {
	if (g_iLotTargetPlayer == -1)
		return 0;

	if (GetNormalCount() < g_iSurvivorLimit)
		return 0;

	int client = GetPendingPlayer();
	if (!client)
		return 0;

	int team = GetClientTeam(client);
	switch (team) {
		case 2: {
			g_eData[client].Clean();
			g_eData[client].Save(client, false);
			ChangeClientTeam(client, 3);
		}

		case 3: {
			if (IsPlayerAlive(client)) {
				L4D_CleanupPlayerState(client);
				ForcePlayerSuicide(client);
			}
		}
	}

	if (GetClientTeam(client) == 3)
		g_ePlayer[client].LastTeamID = g_ePlayer[client].LastTeamID == 2 ? 2 : team != 3 ? 2 : 3;

	if (TakeOverZombieBot(client, tank, true) == 8 && IsPlayerAlive(client)) {
		return client;
	}

	return 0;
}

int GetNormalCount() {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !IsPinned(i))
			count++;
	}
	return count;
}

bool AllowSurTakeOver() {
	if (g_bSbAllBotGame || g_bAllowAllBotSur)
		return true;

	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			count++;
	}
	return count > 1;
}

bool IsPinned(int client) {
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	return false;
}

// https://github.com/alliedmodders/hl2sdk/blob/0ef5d3d482157bc0bb3aafd37c08961373f87bfd/public/const.h#L281-L298
// entity effects
enum
{
	EF_BONEMERGE			= 0x001,	// Performs bone merge on client side
	EF_BRIGHTLIGHT 			= 0x002,	// DLIGHT centered at entity origin
	EF_DIMLIGHT 			= 0x004,	// player flashlight
	EF_NOINTERP				= 0x008,	// don't interpolate the next frame
	EF_NOSHADOW				= 0x010,	// Don't cast no shadow
	EF_NODRAW				= 0x020,	// don't draw entity
	EF_NORECEIVESHADOW		= 0x040,	// Don't receive no shadow
	EF_BONEMERGE_FASTCULL	= 0x080,	// For use with EF_BONEMERGE. If this is set, then it places this ent's origin at its
										// parent and uses the parent's bbox + the max extents of the aiment.
										// Otherwise, it sets up the parent's bones every frame to figure out where to place
										// the aiment, which is inefficient because it'll setup the parent's bones even if
										// the parent is not in the PVS.
	EF_ITEM_BLINK			= 0x100,	// blink an item so that the user notices it.
	EF_PARENT_ANIMATES		= 0x200,	// always assume that the parent entity is animating
	EF_MAX_BITS = 10
};

/* edict->solid values
 * NOTE: Some movetypes will cause collisions independent of SOLID_NOT/SOLID_TRIGGER when the entity moves
 * SOLID only effects OTHER entities colliding with this one when they move - UGH!
 *
 * Solid type basically describes how the bounding volume of the object is represented
 * NOTE: These numerical values are used in the FGD by the prop code (see prop_dynamic)
 * Taken from: hl2sdk-ob-valve\public\const.h
 */

enum
{
	FSOLID_CUSTOMRAYTEST		= 0x0001,	// Ignore solid type + always call into the entity for ray tests
	FSOLID_CUSTOMBOXTEST		= 0x0002,	// Ignore solid type + always call into the entity for swept box tests
	FSOLID_NOT_SOLID			= 0x0004,	// Are we currently not solid?
	FSOLID_TRIGGER				= 0x0008,	// This is something may be collideable but fires touch functions
											// even when it's not collideable (when the FSOLID_NOT_SOLID flag is set)
	FSOLID_NOT_STANDABLE		= 0x0010,	// You can't stand on this
	FSOLID_VOLUME_CONTENTS		= 0x0020,	// Contains volumetric contents (like water)
	FSOLID_FORCE_WORLD_ALIGNED	= 0x0040,	// Forces the collision rep to be world-aligned even if it's SOLID_BSP or SOLID_VPHYSICS
	FSOLID_USE_TRIGGER_BOUNDS	= 0x0080,	// Uses a special trigger bounds separate from the normal OBB
	FSOLID_ROOT_PARENT_ALIGNED	= 0x0100,	// Collisions are defined in root parent's local coordinate space
	FSOLID_TRIGGER_TOUCH_DEBRIS	= 0x0200,	// This trigger will touch debris objects

	FSOLID_MAX_BITS	= 10
};

void CreateSurGlow(int client) {
	if (!g_bGlowColorEnable || !IsClientInGame(client) || IsClientInKickQueue(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return;

	if (IsValidEntRef(g_ePlayer[client].ModelEntRef)) {
		if (GetEntPropEnt(g_ePlayer[client].ModelEntRef, Prop_Send, "moveparent") != client)
			SetAttached(EntRefToEntIndex(g_ePlayer[client].ModelEntRef), client);

		return;
	}

	int iEnt = CreateEntityByName("prop_dynamic_ornament");
	if (iEnt == -1)
		return;

	g_ePlayer[client].ModelEntRef = EntIndexToEntRef(iEnt);
	g_ePlayer[client].ModelIndex = GetEntProp(client, Prop_Data, "m_nModelIndex");

	static char model[128];
	GetClientModel(client, model, sizeof model);
	DispatchKeyValue(iEnt, "model", model);
	DispatchKeyValue(iEnt, "solid", "0");
	DispatchKeyValue(iEnt, "glowrangemin", "0");
	DispatchKeyValue(iEnt, "glowrange", "20000");
	DispatchSpawn(iEnt);

	SetEntProp(iEnt, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(iEnt, Prop_Send, "m_noGhostCollision", 1);

	SetAttached(iEnt, client);

	SetEntityRenderMode(iEnt, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iEnt, 0, 0, 0, 0);

	SDKHook(iEnt, SDKHook_SetTransmit, Hook_SetTransmit);

	SetGlowColor(client);
	AcceptEntityInput(iEnt, "StartGlowing");
}

// LMCCore.inc ([L4D/L4D2]Lux's Model Changer https://forums.alliedmods.net/showthread.php?p=2449184)
void SetAttached(int iEnt, int client) {
	SetVariantString("!activator");
	AcceptEntityInput(iEnt, "SetParent", client);
	SetVariantString("!activator");
	AcceptEntityInput(iEnt, "SetAttached", client);

	SetEntityMoveType(iEnt, MOVETYPE_NONE);

	SetEntProp(iEnt, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL|EF_PARENT_ANIMATES);
	SetEntProp(iEnt, Prop_Data, "m_usSolidFlags", GetEntProp(iEnt, Prop_Data, "m_usSolidFlags", 2)|FSOLID_NOT_SOLID, 2);

	TeleportEntity(iEnt, view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), NULL_VECTOR);
}

Action Hook_SetTransmit(int entity, int client) {
	if (!IsFakeClient(client) && GetClientTeam(client) == 3)
		return Plugin_Continue;

	return Plugin_Handled;
}

void SetGlowColor(int client) {
	static int type;
	type = GetColorType(client);
	if (g_iGlowColor[type] != GetEntProp(g_ePlayer[client].ModelEntRef, Prop_Send, "m_glowColorOverride"))
		SetEntProp(g_ePlayer[client].ModelEntRef, Prop_Send, "m_glowColorOverride", g_iGlowColor[type]);
}

int GetColorType(int client) {
	if (GetEntPropFloat(client, Prop_Send, "m_itTimer", 1) > 0.0)
		return 3;
	else {
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
			return 1;
		else
			return GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_iSurvivorMaxInc ? 2 : 0;
	}
}

void RemoveSurGlow(int client) {
	static int iEnt;
	iEnt = g_ePlayer[client].ModelEntRef;
	g_ePlayer[client].ModelEntRef = 0;

	if (IsValidEntRef(iEnt))
		RemoveEntity(iEnt);
}

bool IsValidEntRef(int iEnt) {
	return iEnt && EntRefToEntIndex(iEnt) != -1;
}

// ------------------------------------------------------------------------------
// 切换回生还者
void NextFrame_ForceChangeTeamSurvivor(int client) {
	if (g_iControlled == 1)
		return;

	if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client))
		return;

	ChangeTeamToSurvivor(client);
}

void ChangeTeamToSurvivor(int client) {
	int team = GetClientTeam(client);
	if (team == 2)
		return;

	// 防止因切换而导致正处于Ghost状态的坦克丢失
	if (GetEntProp(client, Prop_Send, "m_isGhost"))
		L4D_MaterializeFromGhost(client);

	int bot = GetClientOfUserId(g_ePlayer[client].Bot);
	if (!bot || !IsValidSurBot(bot))
		bot = FindUselessSurBot(true);

	if (team != 1)
		ChangeClientTeam(client, 1);

	if (bot) {
		L4D_SetHumanSpec(bot, client);
		L4D_TakeOverBot(client);
	}
	else
		ChangeClientTeam(client, 2);

	if (!OnEndScenario()) {
		if (!IsPlayerAlive(client))
			RoundRespawn(client);

		TeleportToSurvivor(client);
	}

	g_eData[client].Restore(client, false);
	g_eData[client].Clean();
}

enum struct Data {
	int recorded;
	int character;
	int health;
	int tempHealth;
	int bufferTime;
	int reviveCount;
	int thirdStrike;
	int goingToDie;

	char model[128];

	int clip0;
	int ammo;
	int upgrade;
	int upgradeAmmo;
	int weaponSkin0;
	int clip1;
	int weaponSkin1;
	bool dualWielding;

	char slot0[32];
	char slot1[32];
	char slot2[32];
	char slot3[32];
	char slot4[32];
	char active[32];

	// Save Weapon 4.3 (forked)(https://forums.alliedmods.net/showthread.php?p=2398822#post2398822)
	void Clean() {
		if (!this.recorded)
			return;

		this.recorded = 0;
		this.character = -1;
		this.reviveCount = 0;
		this.thirdStrike = 0;
		this.goingToDie = 0;
		this.health = 0;
		this.tempHealth = 0;
		this.bufferTime = 0;

		this.model[0] = '\0';

		this.clip0 = 0;
		this.ammo = 0;
		this.upgrade = 0;
		this.upgradeAmmo = 0;
		this.weaponSkin0 = 0;
		this.clip1 = -1;
		this.weaponSkin1 = 0;
		this.dualWielding = false;

		this.slot0[0] = '\0';
		this.slot1[0] = '\0';
		this.slot2[0] = '\0';
		this.slot3[0] = '\0';
		this.slot4[0] = '\0';
		this.active[0] = '\0';
	}

	void Save(int client, bool identity = true) {
		this.Clean();

		if (GetClientTeam(client) != 2)
			return;

		this.recorded = 1;

		if (identity) {
			this.character = GetEntProp(client, Prop_Send, "m_survivorCharacter");
			GetClientModel(client, this.model, sizeof Data::model);
		}

		if (!IsPlayerAlive(client)) {
			static ConVar cZSurvivorRespa;
			if (!cZSurvivorRespa)
				cZSurvivorRespa = FindConVar("z_survivor_respawn_health");

			this.health = cZSurvivorRespa.IntValue;
			return;
		}

		if (GetEntProp(client, Prop_Send, "m_isIncapacitated")) {
			if (!GetEntProp(client, Prop_Send, "m_isHangingFromLedge")) {
				static ConVar cSurvivorReviveH;
				if (!cSurvivorReviveH)
					cSurvivorReviveH = FindConVar("survivor_revive_health");

				static ConVar cSurvivorMaxInc;
				if (!cSurvivorMaxInc)
					cSurvivorMaxInc = FindConVar("survivor_max_incapacitated_count");

				this.health = 1;
				this.tempHealth = cSurvivorReviveH.IntValue;
				this.bufferTime = 0;
				this.reviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount") + 1;
				this.thirdStrike = this.reviveCount >= cSurvivorMaxInc.IntValue ? 1 : 0;
				this.goingToDie = 1;
			}
			else {
				static ConVar cSurvivorIncapH;
				if (!cSurvivorIncapH)
					cSurvivorIncapH = FindConVar("survivor_incap_health");

				int m_preHangingHealth = L4D2Direct_GetPreIncapHealth(client);																		// 玩家挂边前的实血
				int m_preHangingHealthBuffer = L4D2Direct_GetPreIncapHealthBuffer(client);															// 玩家挂边前的虚血
				int preTotalHealth = m_preHangingHealth + m_preHangingHealthBuffer;																	// 玩家挂边前的总血量
				int revivedTotalHealth = RoundToFloor(GetEntProp(client, Prop_Data, "m_iHealth") / cSurvivorIncapH.FloatValue * preTotalHealth);	// 玩家挂边起身后的总血量

				int deltaHealth = preTotalHealth - revivedTotalHealth;
				if (m_preHangingHealthBuffer > deltaHealth) {
					this.health = m_preHangingHealth;
					this.tempHealth = m_preHangingHealthBuffer - deltaHealth;
				}
				else {
					this.health = m_preHangingHealth - (deltaHealth - m_preHangingHealthBuffer);
					this.tempHealth = 0;
				}

				this.bufferTime = 0;
				this.reviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount");
				this.thirdStrike = GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");
				this.goingToDie = GetEntProp(client, Prop_Send, "m_isGoingToDie");
			}
		}
		else {
			this.health = GetEntProp(client, Prop_Data, "m_iHealth");
			this.tempHealth = RoundToNearest(GetEntPropFloat(client, Prop_Send, "m_healthBuffer"));
			this.bufferTime = RoundToNearest(GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime"));
			this.reviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount");
			this.thirdStrike = GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");
			this.goingToDie = GetEntProp(client, Prop_Send, "m_isGoingToDie");
		}

		char weapon[32];
		int slot = GetPlayerWeaponSlot(client, 0);
		if (slot > MaxClients) {
			GetEntityClassname(slot, weapon, sizeof weapon);
			strcopy(this.slot0, sizeof Data::slot0, weapon);

			this.clip0 = GetEntProp(slot, Prop_Send, "m_iClip1");
			this.ammo = GetOrSetPlayerAmmo(client, slot);
			this.upgrade = GetEntProp(slot, Prop_Send, "m_upgradeBitVec");
			this.upgradeAmmo = GetEntProp(slot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
			this.weaponSkin0 = GetEntProp(slot, Prop_Send, "m_nSkin");
		}

		// Mutant_Tanks (https://github.com/Psykotikism/Mutant_Tanks)
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated")) {
			int secondary = GetEntDataEnt2(client, m_hHiddenWeapon);
			switch (secondary > MaxClients && IsValidEntity(secondary)) {
				case true:
					slot = secondary;

				case false:
					slot = GetPlayerWeaponSlot(client, 1);
			}
		}
		else
			slot = GetPlayerWeaponSlot(client, 1);

		if (slot > MaxClients) {
			GetEntityClassname(slot, weapon, sizeof weapon);
			if (strcmp(weapon, "weapon_melee") == 0) {
				GetEntPropString(slot, Prop_Data, "m_strMapSetScriptName", weapon, sizeof weapon);
				if (weapon[0] == '\0') {
					// 防爆警察掉落的警棍m_strMapSetScriptName为空字符串 (感谢little_froy的提醒)
					char ModelName[128];
					GetEntPropString(slot, Prop_Data, "m_ModelName", ModelName, sizeof ModelName);
					if (strcmp(ModelName, "models/weapons/melee/v_tonfa.mdl") == 0)
						strcopy(weapon, sizeof weapon, "tonfa");
				}
			}
			else {
				if (strncmp(weapon, "weapon_pistol", 13) == 0 || strcmp(weapon, "weapon_chainsaw") == 0)
					this.clip1 = GetEntProp(slot, Prop_Send, "m_iClip1");

				this.dualWielding = strcmp(weapon, "weapon_pistol") == 0 && GetEntProp(slot, Prop_Send, "m_isDualWielding");
			}

			strcopy(this.slot1, sizeof Data::slot1, weapon);
			this.weaponSkin1 = GetEntProp(slot, Prop_Send, "m_nSkin");
		}

		slot = GetPlayerWeaponSlot(client, 2);
		if (slot > MaxClients && (slot != GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon") || GetEntPropFloat(slot, Prop_Data, "m_flNextPrimaryAttack") < GetGameTime())) {	//Method from HarryPotter (https://forums.alliedmods.net/showpost.php?p=2768411&postcount=5)
			GetEntityClassname(slot, weapon, sizeof weapon);
			strcopy(this.slot2, sizeof Data::slot2, weapon);
		}

		slot = GetPlayerWeaponSlot(client, 3);
		if (slot > MaxClients) {
			GetEntityClassname(slot, weapon, sizeof weapon);
			strcopy(this.slot3, sizeof Data::slot3, weapon);
		}

		slot = GetPlayerWeaponSlot(client, 4);
		if (slot > MaxClients) {
			GetEntityClassname(slot, weapon, sizeof weapon);
			strcopy(this.slot4, sizeof Data::slot4, weapon);
		}

		slot = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (slot > MaxClients) {
			GetEntityClassname(slot, weapon, sizeof weapon);
			strcopy(this.active, sizeof Data::active, weapon);
		}
	}

	void Restore(int client, bool identity = true) {
		if (!this.recorded)
			return;

		if (GetClientTeam(client) != 2)
			return;

		if (identity) {
			if (this.character != -1)
				SetEntProp(client, Prop_Send, "m_survivorCharacter", this.character);

			if (this.model[0] != '\0')
				SetEntityModel(client, this.model);
		}

		if (!IsPlayerAlive(client))
			return;

		if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
			L4D_ReviveSurvivor(client);

		SetEntProp(client, Prop_Send, "m_iHealth", this.health);
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 1.0 * this.tempHealth);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime() - 1.0 * this.bufferTime);
		SetEntProp(client, Prop_Send, "m_currentReviveCount", this.reviveCount);
		SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", this.thirdStrike);
		SetEntProp(client, Prop_Send, "m_isGoingToDie", this.goingToDie);

		if (!GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike"))
			StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");

		int slot;
		int weapon;
		for (; slot < 5; slot++) {
			if ((weapon = GetPlayerWeaponSlot(client, slot)) > MaxClients) {
				RemovePlayerItem(client, weapon);
				RemoveEntity(weapon);
			}
		}

		bool given;
		if (this.slot0[0] != '\0') {
			GivePlayerItem(client, this.slot0);

			slot = GetPlayerWeaponSlot(client, 0);
			if (slot > MaxClients) {
				SetEntProp(slot, Prop_Send, "m_iClip1", this.clip0);
				GetOrSetPlayerAmmo(client, slot, this.ammo);

				if (this.upgrade > 0)
					SetEntProp(slot, Prop_Send, "m_upgradeBitVec", this.upgrade);

				if (this.upgradeAmmo > 0)
					SetEntProp(slot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", this.upgradeAmmo);

				if (this.weaponSkin0 > 0)
					SetEntProp(slot, Prop_Send, "m_nSkin", this.weaponSkin0);

				given = true;
			}
		}

		if (this.slot1[0] != '\0') {
			switch (this.dualWielding) {
				case true: {
					GivePlayerItem(client, "weapon_pistol");
					GivePlayerItem(client, "weapon_pistol");
				}

				case false:
					GivePlayerItem(client, this.slot1);
			}

			slot = GetPlayerWeaponSlot(client, 1);
			if (slot > MaxClients) {
				if (this.clip1 != -1)
					SetEntProp(slot, Prop_Send, "m_iClip1", this.clip1);

				if (this.weaponSkin1 > 0)
					SetEntProp(slot, Prop_Send, "m_nSkin", this.weaponSkin1);

				given = true;
			}
		}

		if (this.slot2[0] != '\0') {
			GivePlayerItem(client, this.slot2);

			if (GetPlayerWeaponSlot(client, 2) > MaxClients)
				given = true;
		}

		if (this.slot3[0] != '\0') {
			GivePlayerItem(client, this.slot3);

			if (GetPlayerWeaponSlot(client, 3) > MaxClients)
				given = true;
		}

		if (this.slot4[0] != '\0') {
			GivePlayerItem(client, this.slot4);

			if (GetPlayerWeaponSlot(client, 4) > MaxClients)
				given = true;
		}

		if (given) {
			if (this.active[0] != '\0')
				FakeClientCommand(client, "use %s", this.active);
		}
		else
			GivePlayerItem(client, "weapon_pistol");
	}
}

int GetOrSetPlayerAmmo(int client, int weapon, int ammo = -1) {
	int m_iPrimaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (m_iPrimaryAmmoType != -1) {
		if (ammo != -1)
			SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, m_iPrimaryAmmoType);
		else
			return GetEntProp(client, Prop_Send, "m_iAmmo", _, m_iPrimaryAmmoType);
	}
	return 0;
}

// ------------------------------------------------------------------------------
//SDKCall
void InitData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	m_hHiddenWeapon = FindSendPropInfo("CTerrorPlayer", "m_knockdownTimer") + 116;
	/*m_hHiddenWeapon = hGameData.GetOffset("m_hHiddenWeapon");
	if (m_hHiddenWeapon == -1)
		SetFailState("Failed to find offset: \"m_hHiddenWeapon\"");*/

	RestartScenarioTimer = hGameData.GetOffset("RestartScenarioTimer");
	if (RestartScenarioTimer == -1)
		SetFailState("Failed to find offset: \"RestartScenarioTimer\"");

	/*StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::SetBecomeGhostAt"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::SetBecomeGhostAt\"");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	g_hSDK_CTerrorPlayer_SetBecomeGhostAt = EndPrepSDKCall();
	if (!g_hSDK_CTerrorPlayer_SetBecomeGhostAt)
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::SetBecomeGhostAt\"");*/

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::HasPlayerControlledZombies"))
		SetFailState("Failed to find signature: \"CTerrorGameRules::HasPlayerControlledZombies\"");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_CTerrorGameRules_HasPlayerControlledZombies = EndPrepSDKCall();
	if (!g_hSDK_CTerrorGameRules_HasPlayerControlledZombies)
		SetFailState("Failed to create SDKCall: \"CTerrorGameRules::HasPlayerControlledZombies\"");

	#if DEBUG
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::PlayerZombieAbortControl"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::PlayerZombieAbortControl\"");
	g_hSDK_CTerrorPlayer_PlayerZombieAbortControl = EndPrepSDKCall();
	if (!g_hSDK_CTerrorPlayer_PlayerZombieAbortControl)
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::PlayerZombieAbortControl\"");
	#endif

	InitPatchs(hGameData);
	SetupDetours(hGameData);

	delete hGameData;
}

#define PATCH_STATS_CONDITION		"CTerrorPlayer::RoundRespawn::StatsCondition"
#define PATCH_UPDATE_PZ_RESPAWN		"CDirector::Update::PZSpawn"
#define PATCH_CANBECOMEGHOST		"CTerrorPlayer::CanBecomeGhost::SpawnDisabled"
#define PATCH_UNLOCKSETTING			"CTerrorPlayer::CanBecomeGhost::UnlockSetting"
#define PATCH_CONVERTZOMBIECLASS	"CTerrorPlayer::Spawn::ConvertZombieClass"
#define PATCH_WARPGHOST_BUG_BLOCK	"CTerrorPlayer::PlayerZombieAbortControl::PZDisabled"
#define PATCH_WARPGHOST_BUG_BLOCK1	"CTerrorPlayer::WarpGhostToInitialPosition::PZDisabled"
void InitPatchs(GameData hGameData = null) {
	g_mpStatsCondition = MemoryPatch.CreateFromConf(hGameData, PATCH_STATS_CONDITION);
	if (!g_mpStatsCondition.Validate())
		SetFailState("Failed to verify patch: \"%s\"", PATCH_STATS_CONDITION);

	MemoryPatch patch;
	g_aPatches = new ArrayList();
	Patch(hGameData, patch, PATCH_UPDATE_PZ_RESPAWN);
	Patch(hGameData, patch, PATCH_CANBECOMEGHOST);
	//Patch(hGameData, patch, PATCH_UNLOCKSETTING);
	Patch(hGameData, patch, PATCH_CONVERTZOMBIECLASS);
	Patch(hGameData, patch, PATCH_WARPGHOST_BUG_BLOCK);
	Patch(hGameData, patch, PATCH_WARPGHOST_BUG_BLOCK1);
}

void Patch(GameData hGameData = null, MemoryPatch &patch, const char[] name) {
	patch = MemoryPatch.CreateFromConf(hGameData, name);
	if (!patch.Validate())
		SetFailState("Failed to verify patch: \"%s\"", name);

	g_aPatches.Push(patch);
}

void SetupDetours(GameData hGameData = null) {
	//Method from MicroLeo (https://forums.alliedmods.net/showthread.php?t=329183)
	Address addr = hGameData.GetMemSig("ForEachTerrorPlayer<SpawnablePZScan>");
	if (!addr)
		SetFailState("Failed to find address: \"ForEachTerrorPlayer<SpawnablePZScan>\" in \"z_spawn_old(CCommand const&)\"");
	if (!hGameData.GetOffset("OS")) {
		Address offset = view_as<Address>(LoadFromAddress(addr + view_as<Address>(1), NumberType_Int32));	// (addr+5) + *(addr+1) = call function addr
		if (!offset)
			SetFailState("Failed to find address: \"ForEachTerrorPlayer<SpawnablePZScan>\"");

		addr += offset + view_as<Address>(5); // sizeof(instruction)
	}

	g_ddForEachTerrorPlayer_SpawnablePZScan = new DynamicDetour(addr, CallConv_CDECL, ReturnType_Void, ThisPointer_Ignore);
	if (!g_ddForEachTerrorPlayer_SpawnablePZScan)
		SetFailState("Failed to create DynamicDetour: \"ForEachTerrorPlayer<SpawnablePZScan>\"");

	g_ddForEachTerrorPlayer_SpawnablePZScan.AddParam(HookParamType_CBaseEntity);
}

bool OnEndScenario() {
	return view_as<float>(LoadFromAddress(L4D_GetPointer(POINTER_DIRECTOR) + view_as<Address>(RestartScenarioTimer + 8), NumberType_Int32)) > 0.0;
}

int TakeOverZombieBot(int client, int target, bool ghost) {
	int m_iHealth = GetEntProp(target, Prop_Data, "m_iHealth");
	int m_iMaxHealth = GetEntProp(target, Prop_Data, "m_iMaxHealth");
	if (IsPlayerAlive(client) && !GetEntProp(client, Prop_Send, "m_isGhost"))
		L4D_ReplaceWithBot(client);

	L4D_TakeOverZombieBot(client, target);
	if (ghost && g_bTakeOverGhost)
		EnterGhostMode(client);

	SetEntProp(client, Prop_Data, "m_iHealth", m_iHealth);
	SetEntProp(client, Prop_Data, "m_iMaxHealth", m_iMaxHealth);
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

void EnterGhostMode(int client) {
	if (GetClientTeam(client) == 3 && IsPlayerAlive(client) && !GetEntProp(client, Prop_Send, "m_isGhost")) {
		float vPos[3];
		float vAng[3];
		float vVel[3];
		GetClientAbsOrigin(client, vPos);
		GetClientEyeAngles(client, vAng);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);

		int class = GetEntProp(client, Prop_Send, "m_zombieClass");
		L4D_State_Transition(client, STATE_GHOST);
		L4D_SetClass(client, class);
		TeleportEntity(client, vPos, vAng, vVel);
		if (class == 8)
			CreateTimer(1.0, tmrTank, GetClientUserId(client), TIMER_REPEAT);
	}
}

#define CD 30
Action tmrTank(Handle timer, int client) {
	static int i;
	static int cd[MAXPLAYERS + 1] = {CD, ...};

	if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client)) {
		i = cd[client] = CD;
		return Plugin_Stop;
	}

	if (GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || !GetEntProp(client, Prop_Send, "m_isGhost")) {
		i = cd[client] = CD;
		return Plugin_Stop;
	}

	i = cd[client]--;
	if (i > 0)
		PrintHintText(client, "%d 秒后强制脱离灵魂状态", i);
	else {
		if (g_ePlayer[client].LastTeamID == 2)
			ChangeTeamToSurvivor(client);
		else {
			L4D_MaterializeFromGhost(client);
			SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime() + 5.0);
		}

		if (g_iCmdEnterCooling & (1 << 3))
			g_ePlayer[client].LastUsedTime = GetEngineTime() + g_fCmdCooldownTime;

		i = cd[client] = CD;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

void RoundRespawn(int client) {
	g_mpStatsCondition.Enable();
	L4D_RespawnPlayer(client);
	g_mpStatsCondition.Disable();
}

void TogglePatches(bool enable) {
	static bool enabled;
	if (!enabled && enable) {
		enabled = true;

		MemoryPatch patch;
		int count = g_aPatches.Length;
		for (int i; i < count; i++) {
			patch = g_aPatches.Get(i);
			patch.Enable();
		}
	}
	else if (enabled && !enable) {
		enabled = false;

		MemoryPatch patch;
		int count = g_aPatches.Length;
		for (int i; i < count; i++) {
			patch = g_aPatches.Get(i);
			patch.Disable();
		}
	}
}

void ToggleDetours(bool enable) {
	static bool enabled;
	if (!enabled && enable) {
		enabled = true;

		if (!g_ddForEachTerrorPlayer_SpawnablePZScan.Enable(Hook_Pre, DD_ForEachTerrorPlayer_SpawnablePZScan_Pre))
			SetFailState("Failed to detour pre: \"ForEachTerrorPlayer<SpawnablePZScan>\"");

		if (!g_ddForEachTerrorPlayer_SpawnablePZScan.Enable(Hook_Post, DD_ForEachTerrorPlayer_SpawnablePZScan_Post))
			SetFailState("Failed to detour post: \"ForEachTerrorPlayer<SpawnablePZScan>\"");
	}
	else if (enabled && !enable) {
		enabled = false;

		if (!g_ddForEachTerrorPlayer_SpawnablePZScan.Disable(Hook_Pre, DD_ForEachTerrorPlayer_SpawnablePZScan_Pre))
			SetFailState("Failed to disable detour pre: \"ForEachTerrorPlayer<SpawnablePZScan>\"");

		if (!g_ddForEachTerrorPlayer_SpawnablePZScan.Disable(Hook_Post, DD_ForEachTerrorPlayer_SpawnablePZScan_Post))
			SetFailState("Failed to disable detour post: \"ForEachTerrorPlayer<SpawnablePZScan>\"");
	}
}

public void L4D_OnEnterGhostState(int client) {
	if (g_iControlled == 1)
		return;

	if (g_ePlayer[client].Materialized)
		return;

	if (IsFakeClient(client) || !GetEntProp(client, Prop_Send, "m_isGhost"))
		return;

	if (GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_bAlive", _, client))
		return;

	g_ePlayer[client].ClassCmdUsed = false;
	RequestFrame(NextFrame_EnteredGhostState, GetClientUserId(client));
}

public Action L4D_OnMaterializeFromGhostPre(int client) {
	if (g_iControlled == 1)
		return Plugin_Continue;

	g_bOnMaterializeFromGhost = true;

	#if DEBUG
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 1)
		return Plugin_Continue;

	static float vPos[3];
	GetClientAbsOrigin(client, vPos);
	if (L4D_GetLastKnownArea(client) != L4D_GetNearestNavArea(vPos, 1200.0, false, false, false, 0)) {
		SDKCall(g_hSDK_CTerrorPlayer_PlayerZombieAbortControl, client);
		CPrintToChat(client, "{red}这里是受限制区域!");
		return Plugin_Handled;
	}
	#endif

	return Plugin_Continue;
}

public void L4D_OnMaterializeFromGhost(int client) {
	if (g_iControlled == 1)
		return;

	g_bOnMaterializeFromGhost = false;

	if (GetEntProp(client, Prop_Send, "m_isGhost"))
		return;

	if (!GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_isGhost", _, client))
		return;

	g_ePlayer[client].Materialized++;

	if (!IsFakeClient(client)) {
		if (g_ePlayer[client].Materialized == 1 && g_iPZPunishTime > 0 && g_ePlayer[client].ClassCmdUsed && GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
			CPrintToChat(client, "{olive}下次重生时间 {default}-> {red}+%d秒", g_iPZPunishTime);
	}
}

MRESReturn DD_ForEachTerrorPlayer_SpawnablePZScan_Pre(DHookParam hParams) {
	SpawnablePZScan(true);
	return MRES_Ignored;
}

MRESReturn DD_ForEachTerrorPlayer_SpawnablePZScan_Post(DHookParam hParams) {
	SpawnablePZScan(false);
	return MRES_Ignored;
}

void NextFrame_EnteredGhostState(int client) {
	if (g_iControlled)
		return;

	if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client) || GetClientTeam(client) != 3)
		return;

	if (!IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") == 8 || !GetEntProp(client, Prop_Send, "m_isGhost"))
		return;

	DelaySelectClass(client);
	g_ePlayer[client].EnteredGhost++;

	if (g_iPZSuicideTime > 0)
		g_ePlayer[client].SuicideStart = GetEngineTime();

	if (!g_ePlayer[client].EnteredGhost) {
		if (CheckClientAccess(client, 0))
			CPrintToChat(client, "{default}聊天栏输入 {olive}!team2 {default}可返回{blue}生还者");

		if (CheckClientAccess(client, 5))
			CPrintToChat(client, "{red}灵魂状态下{default} 按下 {red}[鼠标中键] {default}可以快速切换特感");
	}
}

void DelaySelectClass(int client) {
	if ((g_iAutoDisplayMenu == -1 || g_ePlayer[client].EnteredGhost < g_iAutoDisplayMenu) && CheckClientAccess(client, 5)) {
		DisplayClassMenu(client);
		EmitSoundToClient(client, SOUND_CLASSMENU, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	}
}

void SpawnablePZScan(bool protect) {
	static int i;
	static bool ghost[MAXPLAYERS + 1];
	static bool lifeState[MAXPLAYERS + 1];

	switch (protect) {
		case true:  {
			for (i = 1; i <= MaxClients; i++) {
				if (i == g_iSpawnablePZ || !IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 3)
					continue;

				if (GetEntProp(i, Prop_Send, "m_isGhost")) {
					ghost[i] = true;
					SetEntProp(i, Prop_Send, "m_isGhost", 0);
				}
				else if (!IsPlayerAlive(i)) {
					lifeState[i] = true;
					SetEntProp(i, Prop_Send, "m_lifeState", 0);
				}
			}
		}

		case false:  {
			for (i = 1; i <= MaxClients; i++) {
				if (ghost[i])
					SetEntProp(i, Prop_Send, "m_isGhost", 1);

				if (lifeState[i])
					SetEntProp(i, Prop_Send, "m_lifeState", 1);

				ghost[i] = false;
				lifeState[i] = false;
			}
		}
	}
}

// https://github.com/bcserv/smlib/blob/2c14acb85314e25007f5a61789833b243e7d0cab/scripting/include/smlib/math.inc#L144-L163
#define SIZE_OF_INT	2147483647 // without 0
int Math_GetRandomInt(int min, int max) {
	int random = GetURandomInt();
	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}

float Math_GetRandomFloat(float min, float max) {
	return (GetURandomFloat() * (max  - min)) + min;
}
