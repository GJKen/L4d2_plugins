#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0.1"
#define CVAR_FLAGS			FCVAR_NOTIFY
#define DEBUGSERVER 0
#define DEBUGCLIENTS 0
#define DEBUGTANK 0
#define DEBUGHUD 0
#define DEVELOPER 0

#define TEAM_SPECTATOR		1
#define TEAM_SURVIVORS 		2
#define TEAM_INFECTED 		3

#define ZOMBIECLASS_SMOKER	1
#define ZOMBIECLASS_BOOMER	2
#define ZOMBIECLASS_HUNTER	3
#define ZOMBIECLASS_SPITTER	4
#define ZOMBIECLASS_JOCKEY	5
#define ZOMBIECLASS_CHARGER	6

// Variables
static int InfectedRealCount; // Holds the amount of real infected players
static int InfectedBotCount; // Holds the amount of infected bots in any gamemode
static int InfectedBotQueue; // Holds the amount of bots that are going to spawn

static int GameMode; // Holds the GameMode, 1 for coop and realism, 2 for versus, teamversus, scavenge and teamscavenge, 3 for survival

static int BoomerLimit; // Sets the Boomer Limit, related to the boomer limit cvar
static int SmokerLimit; // Sets the Smoker Limit, related to the smoker limit cvar
static int HunterLimit; // Sets the Hunter Limit, related to the hunter limit cvar
static int SpitterLimit; // Sets the Spitter Limit, related to the Spitter limit cvar
static int JockeyLimit; // Sets the Jockey Limit, related to the Jockey limit cvar
static int ChargerLimit; // Sets the Charger Limit, related to the Charger limit cvar

static int Default_MaxPlayerZombies;
static int MaxPlayerZombies; // Holds the amount of the maximum amount of special zombies on the field
static int BotReady; // Used to determine how many bots are ready, used only for the coordination feature
static int ZOMBIECLASS_TANK; // This value varies depending on which L4D game it is, holds the the tank class value
static int GetSpawnTime[MAXPLAYERS+1]; // Used for the HUD on getting spawn times of players
static int PlayersInServer;
static int InfectedSpawnTimeMax;
static int InfectedSpawnTimeMin;
static int InitialSpawnInt;
static int TankLimit;

// Booleans
static bool b_HasRoundStarted; // Used to state if the round started or not
static bool b_HasRoundEnded; // States if the round has ended or not
static bool b_LeftSaveRoom; // States if the survivors have left the safe room
static bool canSpawnBoomer; // States if we can spawn a boomer (releated to spawn restrictions)
static bool canSpawnSmoker; // States if we can spawn a smoker (releated to spawn restrictions)
static bool canSpawnHunter; // States if we can spawn a hunter (releated to spawn restrictions)
static bool canSpawnSpitter; // States if we can spawn a spitter (releated to spawn restrictions)
static bool canSpawnJockey; // States if we can spawn a jockey (releated to spawn restrictions)
static bool canSpawnCharger; // States if we can spawn a charger (releated to spawn restrictions)
static bool DirectorSpawn; // Can allow either the director to spawn the infected (normal l4d behavior), or allow the plugin to spawn them
static bool SpecialHalt; // Loop Breaker, prevents specials spawning, while Director is spawning, from spawning again
//new bool:TankHalt; // Loop Breaker, prevents player tanks from spawning over and over
static bool PlayerLifeState[MAXPLAYERS+1]; // States whether that player has the lifestate changed from switching the gamemode
static bool InitialSpawn; // Related to the coordination feature, tells the plugin to let the infected spawn when the survivors leave the safe room
static bool b_IsL4D2; // Holds the version of L4D; false if its L4D, true if its L4D2
static bool AlreadyGhosted[MAXPLAYERS+1]; // Loop Breaker, prevents a player from spawning into a ghost over and over again
static bool AlreadyGhostedBot[MAXPLAYERS+1]; // Prevents bots taking over a player from ghosting
static bool DirectorCvarsModified; // Prevents reseting the director class limit cvars if the server or admin modifed them
static bool PlayerHasEnteredStart[MAXPLAYERS+1];
static bool AdjustSpawnTimes;
static bool Coordination;
static bool DisableSpawnsTank;

// Handles
static ConVar h_BoomerLimit; // Related to the Boomer limit cvar
static ConVar h_SmokerLimit; // Related to the Smoker limit cvar
static ConVar h_HunterLimit; // Related to the Hunter limit cvar
static ConVar h_SpitterLimit; // Related to the Spitter limit cvar
static ConVar h_JockeyLimit; // Related to the Jockey limit cvar
static ConVar h_ChargerLimit; // Related to the Charger limit cvar
static ConVar h_MaxPlayerZombies; // Related to the max specials cvar
static ConVar h_InfectedSpawnTimeMax; // Related to the spawn time cvar
static ConVar h_InfectedSpawnTimeMin; // Related to the spawn time cvar
static ConVar h_DirectorSpawn; // yeah you're getting the idea
static ConVar h_GameMode; // uh huh
static ConVar h_Coordination;
static ConVar h_idletime_b4slay;
static ConVar h_InitialSpawn;
static Handle FightOrDieTimer[MAXPLAYERS+1]; // kill idle bots
static ConVar h_BotGhostTime;
static ConVar h_DisableSpawnsTank;
static ConVar h_TankLimit;
static ConVar h_AdjustSpawnTimes;

/*********************MicroLeo's Code_CVar*******************************/
//The CVar of Fix This Plugin BUG
static bool OldData = false;
static int OnlyClient;

//AIMode_CVar
static ConVar AI_Enabled_Infectedbots = null;
static ConVar AI_DefaultPlayerCount = null;
static ConVar AI_PlayerCountOfAutoAddBot = null;
static ConVar AI_CountOfAutoAddBot = null;
/*********************MicroLeo's Code End*******************************/

public Plugin myinfo = 
{
	name = "[L4D/L4D2] Infected Bots Control",
	author = "djromero (SkyDavid), MI 5, ivanlee（汉化）",
	description = "无限特感（Control）修复版",
	version = PLUGIN_VERSION,
	url = "http://il4d2.lofter.com/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	// Checks to see if the game is a L4D game. If it is, check if its the sequel. L4DVersion is L4D if false, L4D2 if true.
	char GameName[64];
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrContains(GameName, "left4dead", false) == -1)
		return APLRes_Failure; 
	else if (StrEqual(GameName, "left4dead2", false))
		b_IsL4D2 = true;
	
	return APLRes_Success; 
}

public void OnPluginStart()
{
	// Tank Class value is different in L4D2
	if (b_IsL4D2)
		ZOMBIECLASS_TANK = 8;
	else
	ZOMBIECLASS_TANK = 5;
	
	// We register the version cvar
	CreateConVar("l4d_infectedbots_version", PLUGIN_VERSION, "Version of L4D Infected Bots", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	h_GameMode = FindConVar("mp_gamemode");
	
	#if DEVELOPER
	RegConsoleCmd("sm_sp", JoinSpectator);
	RegConsoleCmd("sm_gamemode", CheckGameMode);
	RegConsoleCmd("sm_count", CheckQueue);
	#endif
	
	// console variables
	h_BoomerLimit = CreateConVar("l4d_infectedbots_boomer_limit", "5", "设定 Boomer 数量(胖子).", CVAR_FLAGS);
	h_SmokerLimit = CreateConVar("l4d_infectedbots_smoker_limit", "5", "设定 Smoker 数量(舌头).", CVAR_FLAGS);
	h_TankLimit = CreateConVar("l4d_infectedbots_tank_limit", "0", "设定 Tank 数量(持续刷坦克,慎用).", CVAR_FLAGS);
	if (b_IsL4D2)
	{
		h_SpitterLimit = CreateConVar("l4d_infectedbots_spitter_limit", "5", "设定 Spitter 数量(口水).", CVAR_FLAGS);
		h_JockeyLimit = CreateConVar("l4d_infectedbots_jockey_limit", "5", "设定 Jockey 数量(猴子).", CVAR_FLAGS);
		h_ChargerLimit = CreateConVar("l4d_infectedbots_charger_limit", "5", "设定 Charger 数量(牛牛).", CVAR_FLAGS);
		h_HunterLimit = CreateConVar("l4d_infectedbots_hunter_limit", "5", "设定 Hunter 数量(猎人).", CVAR_FLAGS);
	}
	else
	{
		h_HunterLimit = CreateConVar("l4d_infectedbots_hunter_limit", "5", "设定 Hunter 数量(猎人).", CVAR_FLAGS);
	}
	h_MaxPlayerZombies = CreateConVar("l4d_infectedbots_max_specials", "3", "设定特感组总数量(越高越难).", CVAR_FLAGS); 
	h_InfectedSpawnTimeMax = CreateConVar("l4d_infectedbots_spawn_time_max", "8", "设定特感最大刷新间隔(秒).", CVAR_FLAGS);
	h_InfectedSpawnTimeMin = CreateConVar("l4d_infectedbots_spawn_time_min", "6", "设定特感最小刷新间隔(秒).", CVAR_FLAGS);
	h_DirectorSpawn = CreateConVar("l4d_infectedbots_director_spawn_times", "0", "0=启用插件, 1=关闭插件(使用游戏默认时间和数量产生特感)", CVAR_FLAGS);
	h_Coordination = CreateConVar("l4d_infectedbots_coordination", "0", "特感将会等待其他特感产生完成后才能产生.", CVAR_FLAGS);
	h_idletime_b4slay = CreateConVar("l4d_infectedbots_lifespan", "20", "多少秒后处死产生的特感(防止特感无限增多和长时间卡住不动占位置).", CVAR_FLAGS);
	h_InitialSpawn = CreateConVar("l4d_infectedbots_initial_spawn_timer", "10", "离开开始区域多少秒后才产生特感(建议不低于10秒).", CVAR_FLAGS);
	h_BotGhostTime = CreateConVar("l4d_infectedbots_ghost_time", "2", "设置大于0时,特感产生后为鬼魂状态(对抗,清道夫).", CVAR_FLAGS);
	h_DisableSpawnsTank = CreateConVar("l4d_infectedbots_spawns_disabled_tank", "0", "坦克出现时继续刷出特感? 0=继续, 1=停止.", CVAR_FLAGS);
	h_AdjustSpawnTimes = CreateConVar("l4d_infectedbots_adjust_spawn_times", "1", "0=使用游戏默认刷特方式, 1=根据游戏模式及幸存者数量自动调整特感数量(战役,对抗,清道夫).", CVAR_FLAGS);
	
	//AIMode_AutoAddBotCount
	AI_Enabled_Infectedbots = CreateConVar("l4d_ai_enabled_infectedbots", "1", "启用智能模式. 0=关闭, 1=开启.", CVAR_FLAGS);
	AI_DefaultPlayerCount = CreateConVar("l4d_ai_DefPlayerCount_infectedbots", "3", "幸存者大于此数组时启用智能模式.", CVAR_FLAGS);//默認爲3,即玩家大於3個，就開始啟用智能模式
	AI_PlayerCountOfAutoAddBot = CreateConVar("l4d_ai_playercountOfAutoAdd_infectedbots", "1", "每增加?个幸存者,特感组数量随即增加:?(标签A).", CVAR_FLAGS);
	AI_CountOfAutoAddBot = CreateConVar("l4d_ai_conuntOfAutoAdd_infectedbots", "1", "(标签A)特感组数量随幸存者增加的数量.", CVAR_FLAGS);//默認每增加2個玩家,特感組數量就增加1個
	//AIMode_Code_END
	
	HookConVarChange(h_BoomerLimit, ConVarBoomerLimit);
	BoomerLimit = GetConVarInt(h_BoomerLimit);
	HookConVarChange(h_SmokerLimit, ConVarSmokerLimit);
	SmokerLimit = GetConVarInt(h_SmokerLimit);
	HookConVarChange(h_HunterLimit, ConVarHunterLimit);
	HunterLimit = GetConVarInt(h_HunterLimit);
	if (b_IsL4D2)
	{
		HookConVarChange(h_SpitterLimit, ConVarSpitterLimit);
		SpitterLimit = GetConVarInt(h_SpitterLimit);
		HookConVarChange(h_JockeyLimit, ConVarJockeyLimit);
		JockeyLimit = GetConVarInt(h_JockeyLimit);
		HookConVarChange(h_ChargerLimit, ConVarChargerLimit);
		ChargerLimit = GetConVarInt(h_ChargerLimit);
	}
	HookConVarChange(h_MaxPlayerZombies, ConVarMaxPlayerZombies);
	Default_MaxPlayerZombies = GetConVarInt(h_MaxPlayerZombies);
	MaxPlayerZombies = GetConVarInt(h_MaxPlayerZombies);
	
	HookConVarChange(h_DirectorSpawn, ConVarDirectorSpawn);
	DirectorSpawn = GetConVarBool(h_DirectorSpawn);
	HookConVarChange(h_GameMode, ConVarGameMode);
	AdjustSpawnTimes = GetConVarBool(h_AdjustSpawnTimes);
	HookConVarChange(h_AdjustSpawnTimes, ConVarAdjustSpawnTimes);
	Coordination = GetConVarBool(h_Coordination);
	HookConVarChange(h_Coordination, ConVarCoordination);
	DisableSpawnsTank = GetConVarBool(h_DisableSpawnsTank);
	HookConVarChange(h_DisableSpawnsTank, ConVarDisableSpawnsTank);
	HookConVarChange(h_InfectedSpawnTimeMax, ConVarInfectedSpawnTimeMax);
	InfectedSpawnTimeMax = GetConVarInt(h_InfectedSpawnTimeMax);
	HookConVarChange(h_InfectedSpawnTimeMin, ConVarInfectedSpawnTimeMin);
	InfectedSpawnTimeMin = GetConVarInt(h_InfectedSpawnTimeMin);
	HookConVarChange(h_InitialSpawn, ConVarInitialSpawn);
	InitialSpawnInt = GetConVarInt(h_InitialSpawn);
	HookConVarChange(h_TankLimit, ConVarTankLimit);
	TankLimit = GetConVarInt(h_TankLimit);
	
	// If the admin wanted to change the director class limits with director spawning on, the plugin will not reset those cvars to their defaults upon startup.
	
	HookConVarChange(FindConVar("z_hunter_limit"), ConVarDirectorCvarChanged);
	if (!b_IsL4D2)
	{
		HookConVarChange(FindConVar("z_gas_limit"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("z_exploding_limit"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("holdout_max_boomers"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("holdout_max_smokers"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("holdout_max_hunters"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("holdout_max_specials"), ConVarDirectorCvarChanged);
	}
	else
	{
		HookConVarChange(FindConVar("z_smoker_limit"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("z_boomer_limit"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("z_jockey_limit"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("z_spitter_limit"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("z_charger_limit"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("survival_max_boomers"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("survival_max_smokers"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("survival_max_hunters"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("survival_max_jockeys"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("survival_max_spitters"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("survival_max_chargers"), ConVarDirectorCvarChanged);
		HookConVarChange(FindConVar("survival_max_specials"), ConVarDirectorCvarChanged);
	}
	
	HookEvent("round_start", evtRoundStart);
	HookEvent("round_end", evtRoundEnd, EventHookMode_Pre);
	// We hook some events ...
	HookEvent("player_death", evtPlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", evtPlayerTeam);
	HookEvent("player_spawn", evtPlayerSpawn);
	HookEvent("create_panic_event", evtSurvivalStart);
	HookEvent("finale_start", evtFinaleStart);
	HookEvent("player_bot_replace", evtBotReplacedPlayer);
	HookEvent("player_first_spawn", evtPlayerFirstSpawned);
	HookEvent("player_entered_start_area", evtPlayerEnteredStartArea);
	HookEvent("player_entered_checkpoint", evtPlayerEnteredCheckpoint);
	HookEvent("player_transitioned", evtPlayerTransitioned);
	HookEvent("player_left_start_area", evtLeftStartArea);
	HookEvent("player_left_checkpoint", evtLeftCheckpoint);
	
	//Autoconfig for plugin
	AutoExecConfig(true, "l4d2_infectedbots_fix_ch");
}

public void ConVarBoomerLimit(ConVar convar, const char[] oldValue, const char[] newValue)
{
	BoomerLimit = GetConVarInt(h_BoomerLimit);
}

public void ConVarSmokerLimit(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SmokerLimit = GetConVarInt(h_SmokerLimit);
}

public void ConVarHunterLimit(ConVar convar, const char[] oldValue, const char[] newValue)
{
	HunterLimit = GetConVarInt(h_HunterLimit);
}

public void ConVarSpitterLimit(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SpitterLimit = GetConVarInt(h_SpitterLimit);
}

public void ConVarJockeyLimit(ConVar convar, const char[] oldValue, const char[] newValue)
{
	JockeyLimit = GetConVarInt(h_JockeyLimit);
}

public void ConVarChargerLimit(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ChargerLimit = GetConVarInt(h_ChargerLimit);
}

public void ConVarInfectedSpawnTimeMax(ConVar convar, const char[] oldValue, const char[] newValue)
{
	InfectedSpawnTimeMax = GetConVarInt(h_InfectedSpawnTimeMax);
}

public void ConVarInfectedSpawnTimeMin(ConVar convar, const char[] oldValue, const char[] newValue)
{
	InfectedSpawnTimeMin = GetConVarInt(h_InfectedSpawnTimeMin);
}

public void ConVarInitialSpawn(ConVar convar, const char[] oldValue, const char[] newValue)
{
	InitialSpawnInt = GetConVarInt(h_InitialSpawn);
}

public void ConVarTankLimit(ConVar convar, const char[] oldValue, const char[] newValue)
{
	TankLimit = GetConVarInt(h_TankLimit);
}

public void ConVarDirectorCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	DirectorCvarsModified = true;
}

public void ConVarAdjustSpawnTimes(ConVar convar, const char[] oldValue, const char[] newValue)
{
	AdjustSpawnTimes = GetConVarBool(h_AdjustSpawnTimes);
}

public void ConVarCoordination(ConVar convar, const char[] oldValue, const char[] newValue)
{
	Coordination = GetConVarBool(h_Coordination);
}

public void ConVarDisableSpawnsTank(ConVar convar, const char[] oldValue, const char[] newValue)
{
	DisableSpawnsTank = GetConVarBool(h_DisableSpawnsTank);
}

public void ConVarMaxPlayerZombies(ConVar convar, const char[] oldValue, const char[] newValue)
{
	MaxPlayerZombies = GetConVarInt(h_MaxPlayerZombies);
	CreateTimer(0.1, MaxSpecialsSet);
	
	#if DEBUGSERVER
	PrintToServer("特感組數量髮生變化");
	#endif
}

public void ConVarDirectorSpawn(ConVar convar, const char[] oldValue, const char[] newValue)
{
	DirectorSpawn = GetConVarBool(h_DirectorSpawn);
	if (!DirectorSpawn)
	{
		//ResetCvars();
		TweakSettings();
		CheckIfBotsNeeded(true, false);
	}
	else
	{
		//ResetCvarsDirector();
		DirectorStuff();
	}
}

public void ConVarGameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GameModeCheck();
	
	if (!DirectorSpawn)
	{
		//ResetCvars();
		TweakSettings();
	}
	else
	{
		//ResetCvarsDirector();
		DirectorStuff();
	}
}

public Action JoinSpectator(int client, int args)
{
	if (client)
		ChangeClientTeam(client, TEAM_SPECTATOR);
	
	return Plugin_Handled;
}

void TweakSettings()
{
	// We tweak some settings ...
	
	// Some interesting things about this. There was a bug I discovered that in versions 1.7.8 and below, infected players would not spawn as ghosts in VERSUS. This was
	// due to the fact that the coop class limits were not being reset (I didn't think they were linked at all, but I should have known better). This bug has been fixed
	// with the coop class limits being reset on every gamemode except coop of course.
	
	// Reset the cvars
	ResetCvars();
	
	switch (GameMode)
	{
		case 1: // Coop, We turn off the ability for the director to spawn the bots, and have the plugin do it while allowing the director to spawn tanks and witches, 
		// MI 5
		{
			// If the game is L4D 2...
			if (b_IsL4D2)
			{
				SetConVarInt(FindConVar("z_smoker_limit"), 0);
				SetConVarInt(FindConVar("z_boomer_limit"), 0);
				SetConVarInt(FindConVar("z_hunter_limit"), 0);
				SetConVarInt(FindConVar("z_spitter_limit"), 0);
				SetConVarInt(FindConVar("z_jockey_limit"), 0);
				SetConVarInt(FindConVar("z_charger_limit"), 0);
			}
			else
			{
				SetConVarInt(FindConVar("z_gas_limit"), 0);
				SetConVarInt(FindConVar("z_exploding_limit"), 0);
				SetConVarInt(FindConVar("z_hunter_limit"), 0);
			}
		}
		case 2: // Versus, Better Versus Infected Bot AI
		{
			// If the game is L4D 2...
			if (b_IsL4D2)
			{
				SetConVarInt(FindConVar("z_smoker_limit"), 0);
				SetConVarInt(FindConVar("z_boomer_limit"), 0);
				SetConVarInt(FindConVar("z_hunter_limit"), 0);
				SetConVarInt(FindConVar("z_spitter_limit"), 0);
				SetConVarInt(FindConVar("z_jockey_limit"), 0);
				SetConVarInt(FindConVar("z_charger_limit"), 0);
				SetConVarInt(FindConVar("z_jockey_leap_time"), 0);
				SetConVarInt(FindConVar("z_spitter_max_wait_time"), 0);
			}
			else
			{
				SetConVarInt(FindConVar("z_gas_limit"), 999);
				SetConVarInt(FindConVar("z_exploding_limit"), 999);
				SetConVarInt(FindConVar("z_hunter_limit"), 999);
			}
			// Enhance Special Infected AI
			SetConVarFloat(FindConVar("smoker_tongue_delay"), 0.0);
			SetConVarFloat(FindConVar("boomer_vomit_delay"), 0.0);
			SetConVarFloat(FindConVar("boomer_exposed_time_tolerance"), 0.0);
			SetConVarInt(FindConVar("hunter_leap_away_give_up_range"), 0);
			SetConVarInt(FindConVar("z_hunter_lunge_distance"), 5000);
			SetConVarInt(FindConVar("hunter_pounce_ready_range"), 1500);
			SetConVarFloat(FindConVar("hunter_pounce_loft_rate"), 0.055);
			SetConVarFloat(FindConVar("z_hunter_lunge_stagger_time"), 0.0);
		}
		case 3: // Survival, Turns off the ability for the director to spawn infected bots in survival, MI 5
		{
			if (b_IsL4D2)
			{
				SetConVarInt(FindConVar("survival_max_smokers"), 0);
				SetConVarInt(FindConVar("survival_max_boomers"), 0);
				SetConVarInt(FindConVar("survival_max_hunters"), 0);
				SetConVarInt(FindConVar("survival_max_spitters"), 0);
				SetConVarInt(FindConVar("survival_max_jockeys"), 0);
				SetConVarInt(FindConVar("survival_max_chargers"), 0);
				SetConVarInt(FindConVar("survival_max_specials"), MaxPlayerZombies);
				SetConVarInt(FindConVar("z_smoker_limit"), 0);
				SetConVarInt(FindConVar("z_boomer_limit"), 0);
				SetConVarInt(FindConVar("z_hunter_limit"), 0);
				SetConVarInt(FindConVar("z_spitter_limit"), 0);
				SetConVarInt(FindConVar("z_jockey_limit"), 0);
				SetConVarInt(FindConVar("z_charger_limit"), 0);
			}
			else
			{
				SetConVarInt(FindConVar("holdout_max_smokers"), 0);
				SetConVarInt(FindConVar("holdout_max_boomers"), 0);
				SetConVarInt(FindConVar("holdout_max_hunters"), 0);
				SetConVarInt(FindConVar("holdout_max_specials"), MaxPlayerZombies);
				SetConVarInt(FindConVar("z_gas_limit"), 0);
				SetConVarInt(FindConVar("z_exploding_limit"), 0);
				SetConVarInt(FindConVar("z_hunter_limit"), 0);
			}
		}
	}
	
	//Some cvar tweaks
	SetConVarInt(FindConVar("z_attack_flow_range"), 50000);
	SetConVarInt(FindConVar("director_spectate_specials"), 1);
	SetConVarInt(FindConVar("z_spawn_safety_range"), 0);
	SetConVarInt(FindConVar("z_spawn_flow_limit"), 50000);
	DirectorCvarsModified = false;
	if (b_IsL4D2)
	{
		// Prevents the Director from spawning bots in versus
		SetConVarInt(FindConVar("versus_special_respawn_interval"), 99999999);
	}
	#if DEBUGSERVER
	PrintToServer("調整參數設置中...");
	#endif
}

void ResetCvars()
{
	#if DEBUGSERVER
	PrintToServer("重置插件變量參數");
	#endif
	if (GameMode == 1)
	{
		ResetConVar(FindConVar("director_no_specials"), true, true);
		ResetConVar(FindConVar("boomer_vomit_delay"), true, true);
		ResetConVar(FindConVar("smoker_tongue_delay"), true, true);
		ResetConVar(FindConVar("hunter_leap_away_give_up_range"), true, true);
		ResetConVar(FindConVar("boomer_exposed_time_tolerance"), true, true);
		ResetConVar(FindConVar("z_hunter_lunge_distance"), true, true);
		ResetConVar(FindConVar("hunter_pounce_ready_range"), true, true);
		ResetConVar(FindConVar("hunter_pounce_loft_rate"), true, true);
		ResetConVar(FindConVar("z_hunter_lunge_stagger_time"), true, true);
		if (b_IsL4D2)
		{
			ResetConVar(FindConVar("survival_max_smokers"), true, true);
			ResetConVar(FindConVar("survival_max_boomers"), true, true);
			ResetConVar(FindConVar("survival_max_hunters"), true, true);
			ResetConVar(FindConVar("survival_max_spitters"), true, true);
			ResetConVar(FindConVar("survival_max_jockeys"), true, true);
			ResetConVar(FindConVar("survival_max_chargers"), true, true);
			ResetConVar(FindConVar("survival_max_specials"), true, true);
			ResetConVar(FindConVar("z_jockey_leap_time"), true, true);
			ResetConVar(FindConVar("z_spitter_max_wait_time"), true, true);
		}
		else
		{
			ResetConVar(FindConVar("holdout_max_smokers"), true, true);
			ResetConVar(FindConVar("holdout_max_boomers"), true, true);
			ResetConVar(FindConVar("holdout_max_hunters"), true, true);
			ResetConVar(FindConVar("holdout_max_specials"), true, true);
		}
	}
	else if (GameMode == 2)
	{
		if (b_IsL4D2)
		{
			ResetConVar(FindConVar("survival_max_smokers"), true, true);
			ResetConVar(FindConVar("survival_max_boomers"), true, true);
			ResetConVar(FindConVar("survival_max_hunters"), true, true);
			ResetConVar(FindConVar("survival_max_spitters"), true, true);
			ResetConVar(FindConVar("survival_max_jockeys"), true, true);
			ResetConVar(FindConVar("survival_max_chargers"), true, true);
			ResetConVar(FindConVar("survival_max_specials"), true, true);
		}
		else
		{
			ResetConVar(FindConVar("holdout_max_smokers"), true, true);
			ResetConVar(FindConVar("holdout_max_boomers"), true, true);
			ResetConVar(FindConVar("holdout_max_hunters"), true, true);
			ResetConVar(FindConVar("holdout_max_specials"), true, true);
		}
	}
	else if (GameMode == 3)
	{
		ResetConVar(FindConVar("z_hunter_limit"), true, true);
		if (b_IsL4D2)
		{
			ResetConVar(FindConVar("z_smoker_limit"), true, true);
			ResetConVar(FindConVar("z_boomer_limit"), true, true);
			ResetConVar(FindConVar("z_hunter_limit"), true, true);
			ResetConVar(FindConVar("z_spitter_limit"), true, true);
			ResetConVar(FindConVar("z_jockey_limit"), true, true);
			ResetConVar(FindConVar("z_charger_limit"), true, true);
			ResetConVar(FindConVar("z_jockey_leap_time"), true, true);
			ResetConVar(FindConVar("z_spitter_max_wait_time"), true, true);
		}
		else
		{
			ResetConVar(FindConVar("z_gas_limit"), true, true);
			ResetConVar(FindConVar("z_exploding_limit"), true, true);
		}
		ResetConVar(FindConVar("boomer_vomit_delay"), true, true);
		ResetConVar(FindConVar("director_no_specials"), true, true);
		ResetConVar(FindConVar("smoker_tongue_delay"), true, true);
		ResetConVar(FindConVar("hunter_leap_away_give_up_range"), true, true);
		ResetConVar(FindConVar("boomer_exposed_time_tolerance"), true, true);
		ResetConVar(FindConVar("z_hunter_lunge_distance"), true, true);
		ResetConVar(FindConVar("hunter_pounce_ready_range"), true, true);
		ResetConVar(FindConVar("hunter_pounce_loft_rate"), true, true);
		ResetConVar(FindConVar("z_hunter_lunge_stagger_time"), true, true);
	}
}

void ResetCvarsDirector()
{
	#if DEBUGSERVER
	PrintToServer("重置控制變量參數");
	#endif
	if (GameMode != 2)//對抗模式
	{
		if (b_IsL4D2)
		{
			ResetConVar(FindConVar("z_smoker_limit"), true, true);
			ResetConVar(FindConVar("z_boomer_limit"), true, true);
			ResetConVar(FindConVar("z_hunter_limit"), true, true);
			ResetConVar(FindConVar("z_spitter_limit"), true, true);
			ResetConVar(FindConVar("z_jockey_limit"), true, true);
			ResetConVar(FindConVar("z_charger_limit"), true, true);
			ResetConVar(FindConVar("survival_max_smokers"), true, true);
			ResetConVar(FindConVar("survival_max_boomers"), true, true);
			ResetConVar(FindConVar("survival_max_hunters"), true, true);
			ResetConVar(FindConVar("survival_max_spitters"), true, true);
			ResetConVar(FindConVar("survival_max_jockeys"), true, true);
			ResetConVar(FindConVar("survival_max_chargers"), true, true);
			ResetConVar(FindConVar("survival_max_specials"), true, true);
		}
		else
		{
			ResetConVar(FindConVar("z_hunter_limit"), true, true);
			ResetConVar(FindConVar("z_exploding_limit"), true, true);
			ResetConVar(FindConVar("z_gas_limit"), true, true);
			ResetConVar(FindConVar("holdout_max_smokers"), true, true);
			ResetConVar(FindConVar("holdout_max_boomers"), true, true);
			ResetConVar(FindConVar("holdout_max_hunters"), true, true);
			ResetConVar(FindConVar("holdout_max_specials"), true, true);
		}
	}
	else
	{
		if (b_IsL4D2)
		{
			//ResetConVar(FindConVar("z_smoker_limit"), true, true);
			SetConVarInt(FindConVar("z_smoker_limit"), 2);
			ResetConVar(FindConVar("z_boomer_limit"), true, true);
			//ResetConVar(FindConVar("z_hunter_limit"), true, true);
			SetConVarInt(FindConVar("z_hunter_limit"), 2);
			ResetConVar(FindConVar("z_spitter_limit"), true, true);
			ResetConVar(FindConVar("z_jockey_limit"), true, true);
			ResetConVar(FindConVar("z_charger_limit"), true, true);
		}
		else
		{
			ResetConVar(FindConVar("z_hunter_limit"), true, true);
			ResetConVar(FindConVar("z_exploding_limit"), true, true);
			ResetConVar(FindConVar("z_gas_limit"), true, true);
		}
	}
}

public void evtRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	// If round has started ...
	if (b_HasRoundStarted)
		return;
	
	b_LeftSaveRoom = false;
	b_HasRoundEnded = false;
	b_HasRoundStarted = true;
	
	//Check the GameMode
	GameModeCheck();
	
	if (GameMode == 0)
		return;
	
	#if DEBUGCLIENTS
	PrintToChatAll("會合開始");
	#endif
	#if DEBUGSERVER
	PrintToServer("會合開始");
	#endif
	
	// Removes the boundaries for z_max_player_zombies and notify flag
	int flags = GetConVarFlags(FindConVar("z_max_player_zombies"));
	SetConVarBounds(FindConVar("z_max_player_zombies"), ConVarBound_Upper, false);
	SetConVarFlags(FindConVar("z_max_player_zombies"), flags & ~FCVAR_NOTIFY);
	
	// Added a delay to setting MaxSpecials so that it would set correctly when the server first starts up
	CreateTimer(0.4, MaxSpecialsSet);
	
	//reset some variables
	InfectedBotQueue = 0;
	BotReady = 0;
	SpecialHalt = false;
	InitialSpawn = false;
	
	// Start up TweakSettings or Director Stuff
	if (!DirectorSpawn)
		TweakSettings();
	else
	DirectorStuff();
	
	if (GameMode != 3)
	{
		#if DEBUGSERVER
		PrintToServer("玩家離開起始區域中... 對抗/戰役模式");
		#endif
		CreateTimer(1.0, PlayerLeftStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void evtPlayerFirstSpawned(Event event, const char[] name, bool dontBroadcast)
{
	// This event's purpose is to execute when a player first enters the server. This eliminates a lot of problems when changing variables setting timers on clients.
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || !IsValidEntity(client))
		return;
		
	if(!IsFakeClient(client))
	{
		#if DEBUGSERVER
		PrintToServer("玩家首次生成實體");
		PrintToServer("此玩家UserID: %d,OnlyClient: %d",GetClientUserId(client),OnlyClient);
		#endif
		
		if(OnlyClient && GetClientUserId(client)==OnlyClient)
		{
			CreateTimer(15.0, PlayerLeftStart, _, TIMER_FLAG_NO_MAPCHANGE);
			OnlyClient = 0;
			
			#if DEBUGSERVER
			PrintToServer("修復不出特感BUG");
			#endif
		}
	}
	
	if (b_HasRoundEnded)
		return;
	if (IsFakeClient(client))
		return;
	// If player has already entered the start area, don't go into this
	if (PlayerHasEnteredStart[client])
		return;
	
	#if DEBUGCLIENTS
	PrintToChatAll("玩家首次生成實體");
	#endif
	
	AlreadyGhosted[client] = false;
	PlayerHasEnteredStart[client] = true;
	
}

public void evtPlayerEnteredStartArea(Event event, const char[] name, bool dontBroadcast)
{
	// This event's purpose is to execute when a player first enters the server. This eliminates a lot of problems when changing variables setting timers on clients.
	
	if (b_HasRoundEnded)
		return;
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!client)
		return;
	
	if (IsFakeClient(client))
		return;
	
	// If player has already entered the start area, don't go into this
	if (PlayerHasEnteredStart[client])
		return;
	
	#if DEBUGCLIENTS
	PrintToChatAll("玩家進入起始區域");
	#endif
	
	AlreadyGhosted[client] = false;
	PlayerHasEnteredStart[client] = true;
	
}

public void evtPlayerEnteredCheckpoint(Event event, const char[] name, bool dontBroadcast)
{
	// This event's purpose is to execute when a player first enters the server. This eliminates a lot of problems when changing variables setting timers on clients.
	
	if (b_HasRoundEnded)
		return;
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!client)
		return;
	
	if (IsFakeClient(client))
		return;
	
	// If player has already entered the start area, don't go into this
	if (PlayerHasEnteredStart[client])
		return;
	
	#if DEBUGCLIENTS
	PrintToChatAll("玩家進入安全屋");
	#endif
	
	AlreadyGhosted[client] = false;
	PlayerHasEnteredStart[client] = true;
}

public void evtPlayerTransitioned(Event event, const char[] name, bool dontBroadcast)
{
	// This event's purpose is to execute when a player first enters the server. This eliminates a lot of problems when changing variables setting timers on clients.
	
	if (b_HasRoundEnded)
		return;
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!client)
		return;
	
	if (IsFakeClient(client))
		return;
	
	// If player has already entered the start area, don't go into this
	if (PlayerHasEnteredStart[client])
		return;
	
	#if DEBUGCLIENTS
	PrintToChatAll("玩家過渡");
	#endif
	
	AlreadyGhosted[client] = false;
	PlayerHasEnteredStart[client] = true;
}

public void evtLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{
	// This event's purpose is to execute when a player first enters the server. This eliminates a lot of problems when changing variables setting timers on clients.
	
	if (b_HasRoundEnded)
		return;
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!client)
		return;
	
	if (IsFakeClient(client))
		return;
	
	// If player has already entered the start area, don't go into this
	if (PlayerHasEnteredStart[client])
		return;
	
	#if DEBUGCLIENTS
	PrintToChatAll("離開起始區域");
	#endif
	
	AlreadyGhosted[client] = false;
	PlayerHasEnteredStart[client] = true;
	
	#if DEBUGSERVER
	PrintToServer("離開起始區域");
	#endif
}

public void evtLeftCheckpoint(Event event, const char[] name, bool dontBroadcast)
{
	// This event's purpose is to execute when a player first enters the server. This eliminates a lot of problems when changing variables setting timers on clients.
	
	if (b_HasRoundEnded)
		return;
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!client)
		return;
	
	if (IsFakeClient(client))
		return;
	
	// If player has already entered the start area, don't go into this
	if (PlayerHasEnteredStart[client])
		return;
	
	#if DEBUGCLIENTS
	PrintToChatAll("離開安全室");
	#endif
	
	AlreadyGhosted[client] = false;
	PlayerHasEnteredStart[client] = true;
	
	#if DEBUGSERVER
	PrintToServer("離開安全室");
	#endif
}

void GameModeCheck()
{
	#if DEBUGSERVER
	PrintToServer("檢查遊戲模式中...");
	#endif
	// We determine what the gamemode is
	char GameName[16];
	GetConVarString(h_GameMode, GameName, sizeof(GameName));
	if (StrEqual(GameName, "survival", false))
		GameMode = 3;
	else if (StrEqual(GameName, "versus", false) || StrEqual(GameName, "teamversus", false) || StrEqual(GameName, "scavenge", false) || StrEqual(GameName, "teamscavenge", false) || StrEqual(GameName, "mutation12", false) || StrEqual(GameName, "mutation13", false) || StrEqual(GameName, "mutation15", false) || StrEqual(GameName, "mutation11", false))
		GameMode = 2;
	else if (StrEqual(GameName, "coop", false) || StrEqual(GameName, "realism", false) || StrEqual(GameName, "mutation3", false) || StrEqual(GameName, "mutation9", false) || StrEqual(GameName, "mutation1", false) || StrEqual(GameName, "mutation7", false) || StrEqual(GameName, "mutation10", false) || StrEqual(GameName, "mutation2", false) || StrEqual(GameName, "mutation4", false) || StrEqual(GameName, "mutation5", false) || StrEqual(GameName, "mutation14", false))
		GameMode = 1;
	else
		GameMode = 1;
	
}

public Action MaxSpecialsSet(Handle Timer)
{
	SetConVarInt(FindConVar("z_max_player_zombies"), MaxPlayerZombies);
	#if DEBUGSERVER
	PrintToServer("設置特感最大數量");//對應特感組數量
	#endif
	return Plugin_Continue;
}

void DirectorStuff()
{	
	SpecialHalt = false;
	SetConVarInt(FindConVar("z_spawn_safety_range"), 0);
	SetConVarInt(FindConVar("director_spectate_specials"), 1);
	if (b_IsL4D2)
		ResetConVar(FindConVar("versus_special_respawn_interval"), true, true);
	
	// if the server changes the director spawn limits in any way, don't reset the cvars
	if (!DirectorCvarsModified)
		ResetCvarsDirector();
	
	#if DEBUGSERVER
	//PrintToServer("Director Stuff has been executed");
	PrintToServer("插件使用游戏默认时间和数量产生特感");
	#endif
	
}

public void evtRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	// If round has not been reported as ended ..
	if (!b_HasRoundEnded)
	{
		// we mark the round as ended
		b_HasRoundEnded = true;
		b_HasRoundStarted = false;
		b_LeftSaveRoom = false;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			PlayerHasEnteredStart[i] = false;
			if (FightOrDieTimer[i] != INVALID_HANDLE)
			{
				KillTimer(FightOrDieTimer[i]);
				FightOrDieTimer[i] = INVALID_HANDLE;
			}
		}
		
		#if DEBUGCLIENTS
		PrintToChatAll("會合結束");
		#endif
		#if DEBUGSERVER
		PrintToServer("會合結束");
		#endif
	}
}

public void OnMapEnd()
{
	#if DEBUGSERVER
	PrintToServer("地圖關閉");
	#endif
	
	b_HasRoundStarted = false;
	b_HasRoundEnded = true;
	b_LeftSaveRoom = false;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (FightOrDieTimer[i] != INVALID_HANDLE)
		{
			KillTimer(FightOrDieTimer[i]);
			FightOrDieTimer[i] = INVALID_HANDLE;
		}
	}
}

public Action PlayerLeftStart(Handle Timer)
{
	if (LeftStartArea())
	{	
		// We don't care who left, just that at least one did
		if (!b_LeftSaveRoom)
		{
			char GameName[16];
			GetConVarString(h_GameMode, GameName, sizeof(GameName));
			if (StrEqual(GameName, "mutation15", false))
			{
				SetConVarInt(FindConVar("survival_max_smokers"), 0);
				SetConVarInt(FindConVar("survival_max_boomers"), 0);
				SetConVarInt(FindConVar("survival_max_hunters"), 0);
				SetConVarInt(FindConVar("survival_max_jockeys"), 0);
				SetConVarInt(FindConVar("survival_max_spitters"), 0);
				SetConVarInt(FindConVar("survival_max_chargers"), 0);
				return Plugin_Continue; 
			}
			
			#if DEBUGSERVER
			PrintToServer("有玩家離開起始區域，準備生產特感的數據");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("A player left the start area, spawning bots");
			#endif
			b_LeftSaveRoom = true;
			
			// We reset some settings
			canSpawnBoomer = true;
			canSpawnSmoker = true;
			canSpawnHunter = true;
			if (b_IsL4D2)
			{
				canSpawnSpitter = true;
				canSpawnJockey = true;
				canSpawnCharger = true;
			}
			InitialSpawn = true;
			
			// We check if we need to spawn bots
			CheckIfBotsNeeded(false, true);
			/*
			服務器輸出：
			檢查Bot...
			準備啟動創建Bot(AI)			“至於輸出多少句取決於特感組數量是多少”
			*/
			#if DEBUGSERVER
			PrintToServer("檢查需要產生多少Bot");
			#endif
			CreateTimer(3.0, InitialSpawnReset, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else
	{
		CreateTimer(1.0, PlayerLeftStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

// This is hooked to the panic event, but only starts if its survival. This is what starts up the bots in survival.
public Action evtSurvivalStart(Event event, const char[] name, bool dontBroadcast)
{
	if (GameMode == 3)
	{  
		// We don't care who left, just that at least one did
		if (!b_LeftSaveRoom)
		{
			#if DEBUGSERVER
			PrintToServer("有玩家觸發警報，生產Bot中");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("A player triggered the survival event, spawning bots");
			#endif
			b_LeftSaveRoom = true;
			
			// We reset some settings
			canSpawnBoomer = true;
			canSpawnSmoker = true;
			canSpawnHunter = true;
			if (b_IsL4D2)
			{
				canSpawnSpitter = true;
				canSpawnJockey = true;
				canSpawnCharger = true;
			}
			InitialSpawn = true;
			
			// We check if we need to spawn bots
			CheckIfBotsNeeded(false, true);
			#if DEBUGSERVER
			PrintToServer("檢查需要產生多少Bot");
			#endif
			CreateTimer(3.0, InitialSpawnReset, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Continue;
}

public Action InitialSpawnReset(Handle Timer)
{
	InitialSpawn = false;
	return Plugin_Continue;
}

public Action BotReadyReset(Handle Timer)
{
	BotReady = 0;
	return Plugin_Continue;
}

public Action InfectedBotBooterVersus(Handle Timer)
{
	//This is to check if there are any extra bots and boot them if necessary, excluding tanks, versus only
	if (GameMode != 2 || b_IsL4D2)
		return Plugin_Continue;
	
	// current count ...
	int total;
	
	for (int i=1; i<=MaxClients; i++)
	{
		// if player is ingame ...
		if (IsClientInGame(i))
		{
			// if player is on infected's team
			if (GetClientTeam(i) == TEAM_INFECTED)
			{
				// We count depending on class ...
				if (!IsPlayerTank(i) || (IsPlayerTank(i) && !PlayerIsAlive(i)))
				{
					total++;
				}
			}
		}
	}
	if (total + InfectedBotQueue > MaxPlayerZombies)
	{
		int kick = total + InfectedBotQueue - MaxPlayerZombies; 
		int kicked = 0;
		
		// We kick any extra bots ....
		for (int i=1;(i<=MaxClients)&&(kicked < kick);i++)
		{
			// If player is infected and is a bot ...
			if (IsClientInGame(i) && IsFakeClient(i))
			{
				//  If bot is on infected ...
				if (GetClientTeam(i) == TEAM_INFECTED)
				{
					// If player is not a tank
					if (!IsPlayerTank(i) || ((IsPlayerTank(i) && !PlayerIsAlive(i))))
					{
						// timer to kick bot
						CreateTimer(0.1,kickbot,i);
						
						// increment kicked count ..
						kicked++;
						#if DEBUGSERVER
						PrintToServer("自動踢出Bot,因爲此Bot超過生存時間");
						#endif
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public void OnClientConnected(int client)
{
	// If is a bot, skip this function
	if (IsFakeClient(client))
		return;
	
	
	PlayersInServer++;
	
	#if DEBUGSERVER
	PrintToServer("有玩家連接服務器成功，目前玩家數量：%d",PlayersInServer);
	#endif
	
	//Fix code
	if (PlayersInServer == 1 && OldData)
	{
		OnlyClient = GetClientUserId(client);
		OldData = false;
		
		b_HasRoundEnded = false;
		b_HasRoundStarted = true;
		InfectedBotQueue = 0;
		
		#if DEBUGSERVER
		PrintToServer("目前玩家人數爲1個,重新修復不出特感的BUG,此玩家UserID:%d",OnlyClient);
		#endif
	}
	
}

public Action CheckGameMode(int client, int args)
{
	if (client)
	{
		char GameMode_Name[32];
		switch(GameMode)
		{
			case 1: Format(GameMode_Name,sizeof(GameMode_Name),"戰役模式");
			case 2: Format(GameMode_Name,sizeof(GameMode_Name),"對抗模式");
			case 3: Format(GameMode_Name,sizeof(GameMode_Name),"生存模式");
		}
		
		PrintToChat(client, "目前模式: %s", GameMode_Name);
	}
	return Plugin_Handled;
}

public Action CheckQueue(int client, int args)
{
	if (client)
	{
		CountInfected();
		
		PrintToChat(client, "特感組 = %i, 特感數量 = %i, 特感實際數量 = %i", InfectedBotQueue, InfectedBotCount, InfectedRealCount);
	}
	return Plugin_Handled;
}

public void evtPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	// We get the client id and time
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	// If client is valid
	if (!client || !IsClientInGame(client))
		return;
	
	if (GetClientTeam(client) != TEAM_INFECTED)
		return;
	
	if (DirectorSpawn && GameMode != 2)
	{
		if (IsPlayerSmoker(client))
		{
			if (IsFakeClient(client))
			{
				if (!SpecialHalt)
				{
					CreateTimer(0.1, kickbot, client);
					
					#if DEBUGSERVER
					PrintToServer("踢出Smoker");
					#endif
					
					int BotNeeded = 1;
					CreateTimer(0.2, Spawn_InfectedBot_Director, BotNeeded);
					
					#if DEBUGSERVER
					PrintToServer("產生 Smoker");
					#endif
				}
			}
		}
		else if (IsPlayerBoomer(client))
		{
			if (IsFakeClient(client))
			{
				if (!SpecialHalt)
				{
					CreateTimer(0.1, kickbot, client);
					
					#if DEBUGSERVER
					PrintToServer("踢出Boomer");
					#endif
					
					int BotNeeded = 2;
					CreateTimer(0.2, Spawn_InfectedBot_Director, BotNeeded);
					
					#if DEBUGSERVER
					PrintToServer("生產Booomer");
					#endif
				}
			}
		}
		else if (IsPlayerHunter(client))
		{
			if (IsFakeClient(client))
			{
				if (!SpecialHalt)
				{
					CreateTimer(0.1, kickbot, client);
					
					#if DEBUGSERVER
					PrintToServer("踢出Hunter");
					#endif
					
					int BotNeeded = 3;
					
					CreateTimer(0.2, Spawn_InfectedBot_Director, BotNeeded);
					
					
					#if DEBUGSERVER
					PrintToServer("生產Hunter");
					#endif
				}
			}
		}
		else if (IsPlayerSpitter(client) && b_IsL4D2)
		{
			if (IsFakeClient(client))
			{
				if (!SpecialHalt)
				{
					CreateTimer(0.1, kickbot, client);
					
					#if DEBUGSERVER
					PrintToServer("踢出Spitter");
					#endif
					
					int BotNeeded = 4;
					
					CreateTimer(0.2, Spawn_InfectedBot_Director, BotNeeded);
					
					
					#if DEBUGSERVER
					PrintToServer("生產Spitter");
					#endif
				}
			}
		}
		else if (IsPlayerJockey(client) && b_IsL4D2)
		{
			if (IsFakeClient(client))
			{
				if (!SpecialHalt)
				{
					CreateTimer(0.1, kickbot, client);
					
					#if DEBUGSERVER
					PrintToServer("踢出Jockey");
					#endif
					
					int BotNeeded = 5;
					
					CreateTimer(0.2, Spawn_InfectedBot_Director, BotNeeded);
					
					
					#if DEBUGSERVER
					PrintToServer("生產Jockey");
					#endif
				}
			}
		}
		else if (IsPlayerCharger(client) && b_IsL4D2)
		{
			if (IsFakeClient(client))
			{
				if (!SpecialHalt)
				{
					CreateTimer(0.1, kickbot, client);
					
					#if DEBUGSERVER
					PrintToServer("踢出Charger");
					#endif
					
					int BotNeeded = 6;
					
					CreateTimer(0.2, Spawn_InfectedBot_Director, BotNeeded);
					
					
					#if DEBUGSERVER
					PrintToServer("生產Charger");
					#endif
				}
			}
		}
	}
	
	if (!IsPlayerTank(client) && IsFakeClient(client))
	{
		if (FightOrDieTimer[client] != INVALID_HANDLE)
		{
			KillTimer(FightOrDieTimer[client]);
			FightOrDieTimer[client] = INVALID_HANDLE;
		}
		FightOrDieTimer[client] = CreateTimer(GetConVarFloat(h_idletime_b4slay), DisposeOfCowards, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	// If its Versus and the bot is not a tank, make the bot into a ghost
	if (IsFakeClient(client) && GameMode == 2 && !IsPlayerTank(client))
		CreateTimer(0.1, Timer_SetUpBotGhost, client, TIMER_FLAG_NO_MAPCHANGE);
}

public void evtBotReplacedPlayer(Event event, const char[] name, bool dontBroadcast)
{
	// The purpose of using this event, is to prevent a bot from ghosting after the player leaves or joins another team
	
	int bot = GetClientOfUserId(GetEventInt(event, "bot"));
	AlreadyGhostedBot[bot] = true;
}

public Action DisposeOfCowards(Handle timer, any coward)
{
	if (IsClientInGame(coward) && IsFakeClient(coward) && GetClientTeam(coward) == TEAM_INFECTED && !IsPlayerTank(coward) && PlayerIsAlive(coward))
	{
		// Check to see if the infected thats about to be slain sees the survivors. If so, kill the timer and make a new one.
		int threats = GetEntProp(coward, Prop_Send, "m_hasVisibleThreats");
		
		if (threats)
		{
			FightOrDieTimer[coward] = INVALID_HANDLE;
			FightOrDieTimer[coward] = CreateTimer(GetConVarFloat(h_idletime_b4slay), DisposeOfCowards, coward);
			#if DEBUGCLIENTS
			PrintToChatAll("%N saw survivors after timer is up, creating new timer", coward);
			#endif
			return Plugin_Continue;
		}
		else
		{
			CreateTimer(0.1, kickbot, coward);
			if (!DirectorSpawn)
			{
				int SpawnTime = GetURandomIntRange(InfectedSpawnTimeMin, InfectedSpawnTimeMax);
				
				if (GameMode == 2 && AdjustSpawnTimes && MaxPlayerZombies != HumansOnInfected())
					SpawnTime = SpawnTime / (MaxPlayerZombies - HumansOnInfected());
				else if (GameMode == 1 && AdjustSpawnTimes)
					SpawnTime = SpawnTime - TrueNumberOfSurvivors();
				
				CreateTimer(float(SpawnTime), Spawn_InfectedBot, _, 0);
				InfectedBotQueue++;
				
				#if DEBUGCLIENTS
				PrintToChatAll("Kicked bot %N for not attacking", coward);
				PrintToChatAll("An infected bot has been added to the spawn queue due to lifespan timer expiring");
				#endif
			}
		}
	}
	FightOrDieTimer[coward] = INVALID_HANDLE;

	return Plugin_Continue;
}

public Action Timer_SetUpBotGhost(Handle timer, any client)
{
	// This will set the bot a ghost, stop the bot's movement, and waits until it can spawn
	if (IsValidEntity(client))
	{
		if (!AlreadyGhostedBot[client])
		{
			SetGhostStatus(client, true);
			SetEntityMoveType(client, MOVETYPE_NONE);
			CreateTimer(GetConVarFloat(h_BotGhostTime), Timer_RestoreBotGhost, client, TIMER_FLAG_NO_MAPCHANGE);
		}
		else
			AlreadyGhostedBot[client] = false;
	}
	return Plugin_Continue;
}

public Action Timer_RestoreBotGhost(Handle timer, any client)
{
	if (IsValidEntity(client))
	{
		SetGhostStatus(client, false);
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
	return Plugin_Continue;
}

public void evtPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	// If round has ended .. we ignore this
	if (b_HasRoundEnded || !b_LeftSaveRoom) 
		return;
	
	// We get the client id and time
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (FightOrDieTimer[client] != INVALID_HANDLE)
	{
		KillTimer(FightOrDieTimer[client]);
		FightOrDieTimer[client] = INVALID_HANDLE;
	}
	
	if (!client || !IsClientInGame(client))
		return;
	
	if (GetClientTeam(client) !=TEAM_INFECTED)
		return;
	
	/*
	if (!DirectorSpawn)
	{
	if (L4DVersion)
	{
	if (IsPlayerBoomer(client))
	{
	canSpawnBoomer = false;
	CreateTimer(float(GetConVarInt(h_InfectedSpawnTimeMin)), ResetSpawnRestriction, 3);
	#if DEBUGSERVER
	PrintToServer("Boomer died, setting spawn restrictions");
	#endif
	}
	else if (IsPlayerSmoker(client))
	{
	canSpawnSmoker = false;
	CreateTimer(float(GetConVarInt(h_InfectedSpawnTimeMin)), ResetSpawnRestriction, 2);
	}
	else if (IsPlayerHunter(client))
	{
	canSpawnHunter = false;
	CreateTimer(float(GetConVarInt(h_InfectedSpawnTimeMin)), ResetSpawnRestriction, 1);
	}
	else if (IsPlayerSpitter(client))
	{
	canSpawnSpitter = false;
	CreateTimer(float(GetConVarInt(h_InfectedSpawnTimeMin)), ResetSpawnRestriction, 4);
	}
	else if (IsPlayerJockey(client))
	{
	canSpawnJockey = false;
	CreateTimer(float(GetConVarInt(h_InfectedSpawnTimeMin)), ResetSpawnRestriction, 5);
	}
	else if (IsPlayerCharger(client))
	{
	canSpawnCharger = false;
	CreateTimer(float(GetConVarInt(h_InfectedSpawnTimeMin)), ResetSpawnRestriction, 6);
	}
	}
	else
	{
	if (IsPlayerBoomer(client))
	{
	canSpawnBoomer = false;
	CreateTimer(float(GetConVarInt(h_InfectedSpawnTimeMin) * 0), ResetSpawnRestriction, 3);
	#if DEBUGSERVER
	PrintToServer("Boomer died, setting spawn restrictions");
	#endif
	}
	else if (IsPlayerSmoker(client))
	{
	canSpawnSmoker = false;
	CreateTimer(float(GetConVarInt(h_InfectedSpawnTimeMin) * 0), ResetSpawnRestriction, 2);
	}
	}
	}
	*/
	
	// if victim was a bot, we setup a timer to spawn a new bot ...
	if (GetEventBool(event, "victimisbot") && (!DirectorSpawn))
	{
		if (!IsPlayerTank(client))
		{
			int SpawnTime = GetURandomIntRange(InfectedSpawnTimeMin, InfectedSpawnTimeMax);
			if (AdjustSpawnTimes && MaxPlayerZombies != HumansOnInfected())
				SpawnTime = SpawnTime / (MaxPlayerZombies - HumansOnInfected());
			CreateTimer(float(SpawnTime), Spawn_InfectedBot, _, 0);
			InfectedBotQueue++;
		}
		
		#if DEBUGCLIENTS
		PrintToChatAll("An infected bot has been added to the spawn queue...");
		#endif
	}
	
	if (IsPlayerTank(client))
		CheckIfBotsNeeded(false, false);
	
	#if DEBUGCLIENTS
	PrintToChatAll("An infected bot has been added to the spawn queue...");
	#endif
	
	else if (GameMode != 2 && DirectorSpawn)
	{
		int SpawnTime = GetURandomIntRange(InfectedSpawnTimeMin, InfectedSpawnTimeMax);
		GetSpawnTime[client] = SpawnTime;
	}
	
	// This fixes the spawns when the spawn timer is set to 5 or below and fixes the spitter spit glitch
	if (IsFakeClient(client) && !IsPlayerSpitter(client))
		CreateTimer(0.1, kickbot, client);
}

public Action Spawn_InfectedBot_Director(Handle timer, any BotNeeded)
{
	bool resetGhost[MAXPLAYERS+1];
	bool resetLife[MAXPLAYERS+1];
	
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && (!IsFakeClient(i))) // player is connected and is not fake and it's in game ...
		{
			// If player is on infected's team and is dead ..
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				// If player is a ghost ....
				if (IsPlayerGhost(i))
				{
					resetGhost[i] = true;
					SetGhostStatus(i, false);
				}
				else if (!PlayerIsAlive(i))
				{
					AlreadyGhosted[i] = false;
					SetLifeState(i, true);
				}
			}
		}
	}
	
	int anyclient = GetAnyClient();
	bool temp = false;
	if (anyclient == -1)
	{
		#if DEBUGSERVER
		PrintToServer("[Infected bots] 創建一個臨時Bot(需要Kick一次才能生成智能AI)");
		#endif
		
		// we create a fake client
		anyclient = CreateFakeClient("Bot");
		if (anyclient == 0)
		{
			LogError("[L4D] 臨時Bot創建失敗");
		}
		temp = true;
	}
	
	SpecialHalt = true;
	
	switch (BotNeeded)
	{
		case 1: // Smoker
		CheatCommand(anyclient, "z_spawn_old", "smoker auto");
		case 2: // Boomer
		CheatCommand(anyclient, "z_spawn_old", "boomer auto");
		case 3: // Hunter
		CheatCommand(anyclient, "z_spawn_old", "hunter auto");
		case 4: // Spitter
		CheatCommand(anyclient, "z_spawn_old", "spitter auto");
		case 5: // Jockey
		CheatCommand(anyclient, "z_spawn_old", "jockey auto");
		case 6: // Charger
		CheatCommand(anyclient, "z_spawn_old", "charger auto");
	}
	
	SpecialHalt = false;
	
	// We restore the player's status
	for (int i=1;i<=MaxClients;i++)
	{
		if (resetGhost[i])
			SetGhostStatus(i, true);
		if (resetLife[i])
			SetLifeState(i, true);
	}
	// If client was temp, we setup a timer to kick the fake player
	if (temp)
		CreateTimer(0.1, kickbot, anyclient);

	return Plugin_Continue;
}

/*
public Action:ResetSpawnRestriction (Handle:timer, any:bottype)
{
#if DEBUGSERVER
PrintToServer("Resetting spawn restrictions");
#endif
switch (bottype)
{
case 1: // hunter
canSpawnHunter = true;
case 2: // smoker
canSpawnSmoker = true;
case 3: // boomer
canSpawnBoomer = true;
case 4: // spitter
canSpawnSpitter = true;
case 5: // jockey
canSpawnJockey = true;
case 6: // charger
canSpawnCharger = true;
}

}
*/
public Action evtPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	// If player is a bot, we ignore this ...
	if (GetEventBool(event, "isbot"))
		return Plugin_Continue;
	
	// We get some data needed ...
	int newteam = GetEventInt(event, "team");
	int oldteam = GetEventInt(event, "oldteam");
	
	// If player's new/old team is infected, we recount the infected and add bots if needed ...
	if (!b_HasRoundEnded && b_LeftSaveRoom && GameMode == 2)
	{
		if (oldteam == 3||newteam == 3)
		{
			CheckIfBotsNeeded(false, false);
		}
		if (newteam == 3)
		{
			//Kick Timer
			CreateTimer(1.0, InfectedBotBooterVersus, _, TIMER_FLAG_NO_MAPCHANGE);
			#if DEBUGSERVER
			PrintToServer("有玩家切換到感染者隊伍，試圖控制Bot");
			#endif
		}
	}
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	// If is a bot, skip this function
	if (IsFakeClient(client))
		return;
	
	// Reset all other arrays
	PlayerLifeState[client] = false;
	GetSpawnTime[client] = 0;
	AlreadyGhosted[client] = false;
	PlayerHasEnteredStart[client] = false;
	PlayersInServer--;
	
	// If no real players are left in game ... MI 5
	if (PlayersInServer == 0)
	{
		#if DEBUGSERVER
		PrintToServer("所有玩家離開了服務器，目前玩家人數爲: 0");
		#endif
		
		b_LeftSaveRoom = false;
		b_HasRoundEnded = true;
		b_HasRoundStarted = false;
		DirectorCvarsModified = false;
		
		//Fix
		OldData = true;
		
		// Zero all respawn times ready for the next round
		for (int i = 1; i <= MaxClients; i++)
		{
			AlreadyGhosted[i] = false;
			PlayerHasEnteredStart[i] = false;
		}
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (FightOrDieTimer[i] != INVALID_HANDLE)
			{
				KillTimer(FightOrDieTimer[i]);
				FightOrDieTimer[i] = INVALID_HANDLE;
			}
		}
		
	}
	
}

public Action CheckIfBotsNeededLater(Handle timer, any spawn_immediately)
{
	CheckIfBotsNeeded(spawn_immediately, false);

	return Plugin_Continue;
}

void CheckIfBotsNeeded(bool spawn_immediately, bool initial_spawn)
{
	if (!DirectorSpawn)
	{
		#if DEBUGSERVER
		PrintToServer("檢查Bot...");
		#endif
		#if DEBUGCLIENTS
		PrintToChatAll("Checking bots");
		#endif
		
		if (b_HasRoundEnded || !b_LeftSaveRoom) return;
		
		//嵌入智能增加特感組數量
		if(GetConVarInt(AI_Enabled_Infectedbots))
		{
			if(GameMode != 2 && TotalSurvivors_()>GetConVarInt(AI_DefaultPlayerCount))
			{
				int Add_PlayerZombies = (TotalSurvivors_()-GetConVarInt(AI_DefaultPlayerCount))/GetConVarInt(AI_PlayerCountOfAutoAddBot);
				if(Add_PlayerZombies>=1)
					MaxPlayerZombies = Default_MaxPlayerZombies+(Add_PlayerZombies*GetConVarInt(AI_CountOfAutoAddBot));
			}
			else if(GameMode != 2 && TotalSurvivors_()<=GetConVarInt(AI_DefaultPlayerCount))
				MaxPlayerZombies = Default_MaxPlayerZombies;
			
			if(GetConVarInt(FindConVar("z_max_player_zombies"))!=MaxPlayerZombies)
			{
				SetConVarInt(FindConVar("z_max_player_zombies"), MaxPlayerZombies);
				PrintToChatAll("\x04[提示]\x05幸存者\x04:\x03%d\x05人\x04,\x05特感\x04:\x03%d\x05特\x04,\x05刷新间隔\x04:\x03%d\x04~\x03%d\x05秒.", TotalSurvivors_(), MaxPlayerZombies, InfectedSpawnTimeMin, InfectedSpawnTimeMax);//聊天窗提示.
				#if DEBUGSERVER
				PrintToServer("玩家增加,重新初始化特感數量,目前特感組數量爲: %d 個",MaxPlayerZombies);
				#endif
			}
			
		}
		//嵌入結束
		
		// First, we count the infected
		CountInfected();
		
		int diff = MaxPlayerZombies - (InfectedBotCount + InfectedRealCount + InfectedBotQueue);
		
		#if DEBUGSERVER
		PrintToServer("diff: %d,MaxPlayerZombies: %d",diff,MaxPlayerZombies);
		#endif
		
		// If we need more infected bots
		if (diff > 0)
		{
			for (int i;i<diff;i++)
			{
				// If we need them right away ...
				if (spawn_immediately)
				{
					InfectedBotQueue++;
					CreateTimer(0.5, Spawn_InfectedBot, _, 0);
					#if DEBUGSERVER
					PrintToServer("馬上創建Bot");
					#endif
				}
				else if (initial_spawn)
				{
					InfectedBotQueue++;
					CreateTimer(float(InitialSpawnInt), Spawn_InfectedBot, _, 0);
					#if DEBUGSERVER
					PrintToServer("準備啟動創建Bot(AI)");
					#endif
				}
				else // We use the normal time ..
				{
					InfectedBotQueue++;
					if (GameMode == 2 && AdjustSpawnTimes && MaxPlayerZombies != HumansOnInfected())
						CreateTimer(float(InfectedSpawnTimeMax) / (MaxPlayerZombies - HumansOnInfected()), Spawn_InfectedBot, _, 0);
					else if (GameMode == 1 && AdjustSpawnTimes)
						CreateTimer(float(InfectedSpawnTimeMax - TrueNumberOfSurvivors()), Spawn_InfectedBot, _, 0);
					else
						CreateTimer(float(InfectedSpawnTimeMax), Spawn_InfectedBot, _, 0);
				}
			}
		}
		
	}
}

void CountInfected()
{
	// reset counters
	InfectedBotCount = 0;
	InfectedRealCount = 0;
	
	// First we count the ammount of infected real players and bots
	for (int i=1;i<=MaxClients;i++)
	{
		// We check if player is in game
		if (!IsClientInGame(i))
			continue;
		
		// Check if client is infected ...
		if (GetClientTeam(i) == TEAM_INFECTED)
		{
			// If player is a bot ...
			if (IsFakeClient(i))
				InfectedBotCount++;
			else
				InfectedRealCount++;
		}
	}
}

// This event serves to make sure the bots spawn at the start of the finale event. The director disallows spawning until the survivors have started the event, so this was
// definitely needed.
public void evtFinaleStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(1.0, CheckIfBotsNeededLater, true);
}

int BotTimePrepare()
{
	CreateTimer(1.0, BotTypeTimer);
	return 0;
}

public Action BotTypeTimer(Handle timer)
{
	BotTypeNeeded();
	return Plugin_Continue;
}

int BotTypeNeeded()
{
	#if DEBUGSERVER
	PrintToServer("確定Bot的類型及其數量...");
	#endif
	#if DEBUGCLIENTS
	PrintToChatAll("Determining Bot type now");
	#endif
	
	// current count ...
	int boomers=0;
	int smokers=0;
	int hunters=0;
	int spitters=0;
	int jockeys=0;
	int chargers=0;
	int tanks=0;
	
	for (int i=1;i<=MaxClients;i++)
	{
		// if player is connected and ingame ...
		if (IsClientInGame(i))
		{
			// if player is on infected's team
			if (GetClientTeam(i) == TEAM_INFECTED && PlayerIsAlive(i))
			{
				// We count depending on class ...
				if (IsPlayerSmoker(i))
					smokers++;
				else if (IsPlayerBoomer(i))
					boomers++;	
				else if (IsPlayerHunter(i))
					hunters++;	
				else if (IsPlayerTank(i))
					tanks++;	
				else if (b_IsL4D2 && IsPlayerSpitter(i))
					spitters++;	
				else if (b_IsL4D2 && IsPlayerJockey(i))
					jockeys++;	
				else if (b_IsL4D2 && IsPlayerCharger(i))
					chargers++;	
			}
		}
	}
	
	if  (b_IsL4D2)
	{
		int random = GetURandomIntRange(1, 7);
		
		if (random == 2)
		{
			if ((smokers < SmokerLimit) && (canSpawnSmoker))
			{
				#if DEBUGSERVER
				PrintToServer("Bot類型爲：Smoker");
				#endif
				return 2;
			}
		}
		else if (random == 3)
		{
			if ((boomers < BoomerLimit) && (canSpawnBoomer))
			{
				#if DEBUGSERVER
				PrintToServer("Bot類型爲：Boomer");
				#endif
				return 3;
			}
		}
		else if (random == 1)
		{
			if ((hunters < HunterLimit) && (canSpawnHunter))
			{
				#if DEBUGSERVER
				PrintToServer("Bot類型爲：Hunter");
				#endif
				return 1;
			}
		}
		else if (random == 4)
		{
			if ((spitters < SpitterLimit) && (canSpawnSpitter))
			{
				#if DEBUGSERVER
				PrintToServer("Bot類型爲：Spitter");
				#endif
				return 4;
			}
		}
		else if (random == 5)
		{
			if ((jockeys < JockeyLimit) && (canSpawnJockey))
			{
				#if DEBUGSERVER
				PrintToServer("Bot類型爲：Jockey");
				#endif
				return 5;
			}
		}
		else if (random == 6)
		{
			if ((chargers < ChargerLimit) && (canSpawnCharger))
			{
				#if DEBUGSERVER
				PrintToServer("Bot類型爲：Charger");
				#endif
				return 6;
			}
		}
		
		else if (random == 7)
		{
			if (tanks < TankLimit)
			{
				#if DEBUGSERVER
				PrintToServer("Bot類型爲：Tank");
				#endif
				return 7;
			}
		}
		
		return BotTimePrepare();
	}
	else//L4D1 1代遊戲
	{
		int random = GetURandomIntRange(1, 4);
		
		if (random == 2)
		{
			if ((smokers < SmokerLimit) && (canSpawnSmoker)) // we need a smoker ???? can we spawn a smoker ??? is smoker bot allowed ??
			{
				#if DEBUGSERVER
				PrintToServer("Returning Smoker");
				#endif
				return 2;
			}
		}
		else if (random == 3)
		{
			if ((boomers < BoomerLimit) && (canSpawnBoomer))
			{
				#if DEBUGSERVER
				PrintToServer("Returning Boomer");
				#endif
				return 3;
			}
		}
		else if (random == 1)
		{
			if (hunters < HunterLimit && canSpawnHunter)
			{
				#if DEBUGSERVER
				PrintToServer("Returning Hunter");
				#endif
				return 1;
			}
		}
		
		else if (random == 4)
		{
			if (tanks < GetConVarInt(h_TankLimit))
			{
				#if DEBUGSERVER
				PrintToServer("Bot type returned Tank");
				#endif
				return 7;
			}
		}
		
		return BotTimePrepare();
	}
}

public Action Spawn_InfectedBot(Handle timer)
{
	// If round has ended, we ignore this request ...
	if (b_HasRoundEnded || !b_HasRoundStarted || !b_LeftSaveRoom) 
		return Plugin_Stop;
	
	int Infected = MaxPlayerZombies;
	
	if (Coordination && !DirectorSpawn && !InitialSpawn)
	{
		BotReady++;
		
		for (int i=1;i<=MaxClients;i++)
		{
			// We check if player is in game
			if (!IsClientInGame(i))
				continue;
			
			// Check if client is infected ...
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				// If player is a real player 
				if (!IsFakeClient(i))
					Infected--;
			}
		}
		
		if (BotReady >= Infected)
		{
			CreateTimer(3.0, BotReadyReset, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			InfectedBotQueue--;
			return Plugin_Stop;
		}
	}
	
	// First we get the infected count
	CountInfected();
	
	// If infected's team is already full ... we ignore this request (a real player connected after timer started ) ..
	if ((InfectedRealCount + InfectedBotCount) >= MaxPlayerZombies || (InfectedRealCount + InfectedBotCount + InfectedBotQueue) > MaxPlayerZombies) 	
	{
		#if DEBUGSERVER
		PrintToServer("目前特感數量滿,將不生產特感");
		#endif
		InfectedBotQueue--;
		return Plugin_Stop;
	}
	
	// If there is a tank on the field and l4d_infectedbots_spawns_disable_tank is set to 1, the plugin will check for
	// any tanks on the field
	
	if (DisableSpawnsTank)
	{
		for (int i=1;i<=MaxClients;i++)
		{
			// We check if player is in game
			if (!IsClientInGame(i))
				continue;
			
			// Check if client is infected ...
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				// If player is a tank
				if (IsPlayerTank(i) && IsPlayerAlive(i))
				{
					InfectedBotQueue--;
					return Plugin_Stop;
				}
			}
		}
		
	}
	
	// The bread and butter of this plugin.
	
	bool resetGhost[MAXPLAYERS+1];
	bool resetLife[MAXPLAYERS+1];
	
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i)) // player is connected and is not fake and it's in game ...
		{
			// If player is on infected's team and is dead ..
			if (GetClientTeam(i) == TEAM_INFECTED)
			{
				// If player is a ghost ....
				if (IsPlayerGhost(i))
				{
					resetGhost[i] = true;
					SetGhostStatus(i, false);
					#if DEBUGSERVER
					PrintToServer("玩家目前是鬼魂狀態，防止玩家馬上重新復活");
					#endif
				}
				else if (!PlayerIsAlive(i)) // if player is just dead
				{
					resetLife[i] = true;
					SetLifeState(i, false);
				}
			}
		}
	}
	
	// We get any client ....
	int anyclient = GetAnyClient();
	bool temp = false;
	if (anyclient == -1)
	{
		#if DEBUGSERVER
		PrintToServer("[Infected bots]創建一個臨時Bot");
		#endif
		// we create a fake client
		anyclient = CreateFakeClient("Bot");
		if (!anyclient)
		{
			LogError("[L4D] Infected Bots: CreateFakeClient returned 0 -- Infected bot was not spawned");
			return Plugin_Stop;
		}
		temp = true;
	}
	
	if (b_IsL4D2 && GameMode != 2)
	{
		int bot = CreateFakeClient("Infected Bot");
		if (bot != 0)
		{
			ChangeClientTeam(bot,TEAM_INFECTED);
			CreateTimer(0.1,kickbot,bot);
		}
	}
	
	// Determine the bot class needed ...
	int bot_type = BotTypeNeeded();
	
	// We spawn the bot ...
	switch (bot_type)
	{
		case 0: // Nothing
		{
			#if DEBUGSERVER
			PrintToServer("Bot的類型爲空!");
			#endif
		}
		case 1: // Hunter
		{
			#if DEBUGSERVER
			PrintToServer("Spawning Hunter");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("Spawning Hunter");
			#endif
			CheatCommand(anyclient, "z_spawn_old", "hunter auto");
		}
		case 2: // Smoker
		{	
			#if DEBUGSERVER
			PrintToServer("Spawning Smoker");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("Spawning Smoker");
			#endif
			CheatCommand(anyclient, "z_spawn_old", "smoker auto");
		}
		case 3: // Boomer
		{
			#if DEBUGSERVER
			PrintToServer("Spawning Boomer");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("Spawning Boomer");
			#endif
			CheatCommand(anyclient, "z_spawn_old", "boomer auto");
		}
		case 4: // Spitter
		{
			#if DEBUGSERVER
			PrintToServer("Spawning Spitter");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("Spawning Spitter");
			#endif
			CheatCommand(anyclient, "z_spawn_old", "spitter auto");
		}
		case 5: // Jockey
		{
			#if DEBUGSERVER
			PrintToServer("Spawning Jockey");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("Spawning Jockey");
			#endif
			CheatCommand(anyclient, "z_spawn_old", "jockey auto");
		}
		case 6: // Charger
		{
			#if DEBUGSERVER
			PrintToServer("Spawning Charger");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("Spawning Charger");
			#endif
			CheatCommand(anyclient, "z_spawn_old", "charger auto");
		}
		case 7: // Tank
		{
			#if DEBUGSERVER
			PrintToServer("Spawning Tank");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("Spawning Tank");
			#endif
			CheatCommand(anyclient, "z_spawn_old", "tank auto");
		}
	}
	
	// We restore the player's status
	for (int i=1;i<=MaxClients;i++)
	{
		if (resetGhost[i] == true)
			SetGhostStatus(i, true);
		if (resetLife[i] == true)
			SetLifeState(i, true);
	}
	
	// If client was temp, we setup a timer to kick the fake player
	if (temp)
		CreateTimer(0.1,kickbot,anyclient);
	
	// Debug print
	#if DEBUGCLIENTS
	PrintToChatAll("Spawning an infected bot. Type = %i ", bot_type);
	#endif
	
	// We decrement the infected queue
	InfectedBotQueue--;
	
	CreateTimer(1.0, CheckIfBotsNeededLater, true);

	return Plugin_Continue;
}

stock int GetAnyClient() 
{ 
	for (int i = 1; i <= MaxClients; i++) 
	{ 
		if (IsClientInGame(i))
			return i; 
	} 
	return -1; 
} 

public Action kickbot(Handle timer, any client)
{
	if (IsClientInGame(client) && (!IsClientInKickQueue(client)))
	{
		if (IsFakeClient(client))
			KickClient(client);
	}
	return Plugin_Continue;
}

bool IsPlayerGhost (int client)
{
	if (GetEntProp(client, Prop_Send, "m_isGhost"))
		return true;
	return false;
}

bool PlayerIsAlive (int client)
{
	if (!GetEntProp(client,Prop_Send, "m_lifeState"))
		return true;
	return false;
}

bool IsPlayerSmoker (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_SMOKER)
		return true;
	return false;
}

bool IsPlayerBoomer (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_BOOMER)
		return true;
	return false;
}

bool IsPlayerHunter (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_HUNTER)
		return true;
	return false;
}

bool IsPlayerSpitter (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_SPITTER)
		return true;
	return false;
}

bool IsPlayerJockey (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_JOCKEY)
		return true;
	return false;
}

bool IsPlayerCharger (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_CHARGER)
		return true;
	return false;
}

bool IsPlayerTank (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_TANK)
		return true;
	return false;
}

void SetGhostStatus (int client, bool ghost)
{
	if (ghost)
		SetEntProp(client, Prop_Send, "m_isGhost", 1);
	else
		SetEntProp(client, Prop_Send, "m_isGhost", 0);
}

void SetLifeState (int client, bool ready)
{
	if (ready)
		SetEntProp(client, Prop_Send,  "m_lifeState", 1);
	else
		SetEntProp(client, Prop_Send, "m_lifeState", 0);
}

int TrueNumberOfSurvivors ()
{
	int TotalSurvivors;
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i))
			if (GetClientTeam(i) == TEAM_SURVIVORS)
				TotalSurvivors++;
		}
	return TotalSurvivors;
}

int HumansOnInfected ()
{
	int TotalHumans;
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && !IsFakeClient(i))
			TotalHumans++;
	}
	return TotalHumans;
}

bool LeftStartArea()
{
	int ent = -1, maxents = GetMaxEntities();
	for (int i = MaxClients+1; i <= maxents; i++)
	{
		if (IsValidEntity(i))
		{
			char netclass[64];
			GetEntityNetClass(i, netclass, sizeof(netclass));
			
			if (StrEqual(netclass, "CTerrorPlayerResource"))
			{
				ent = i;
				break;
			}
		}
	}
	
	if (ent > -1)
	{
		if (GetEntProp(ent, Prop_Send, "m_hasAnySurvivorLeftSafeArea"))
		{
			return true;
		}
	}
	return false;
}

stock int GetURandomIntRange(int min, int max)
{
	return (GetURandomInt() % (max-min+1)) + min;
}

stock void CheatCommand(int client, char[] command, char[] arguments = "")
{
	int userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}

/////////////////////////////////////////////////////////

stock int TotalSurvivors_() // total bots, including players
{
	int intt = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(IsClientInGame(i) && (GetClientTeam(i) == 2))
				intt++;
		}
	}
	return intt;
}