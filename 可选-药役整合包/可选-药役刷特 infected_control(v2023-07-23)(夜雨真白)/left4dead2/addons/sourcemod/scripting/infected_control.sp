/**
* @Author 夜羽真白
* @Date 2023-07-23 13:43:35
* @Description 特感刷新控制
* @Version 1.0.0.0
* @GitHub https://github.com/GlowingTree880/L4D2_LittlePlugins
**/

#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <profiler>
#include <logger>
#include <treeutil>

#define CVAR_FLAG FCVAR_NOTIFY

#define PLUGIN_PREFIX "[Infected-Control]"

#define SDK_HOOK_TYPE SDKHook_PreThink

#define INVALID_CLIENT_INDEX -1

// 场上特感数量检测时钟周期 (默认 1 秒检测一次场上特感数量, 分散刷新模式下不检测)
#define SPAWN_CHECK_TIMER_INTERVAL 1.0
// round_start 事件触发多少秒后获取第一波刷特队列
#define ROUND_START_DELAY 0.5
// 每局开始设置 z_max_player_zombie 延迟
#define MAX_SPECIAL_SET_DELAY 1.0
// 分散刷新模式时, 新增的特感复活延迟
#define NEW_INFECTED_RESPAWN_DELAY 0.5

ConVar
	g_hInfectedLimit,
	g_hSpawnDuration,
	g_hSpawnStrategy,
	g_hSpawnMethodStrategy,
	g_hDisperseSpawnPercent,
	g_hFindPosStrategy,
	g_hEachPosInfectedCount,
	g_hFirstWaveDelay,
	g_hDeadKickTime,
	g_hIncapExtraTime,
	g_hStartSpawnControl;

ConVar
	g_hLoggingLevel;

// 游戏自带 Cvar
ConVar
	game_zMaxPlayerZombie,
	game_directorNoSpecials;

ArrayList
	// 特感刷新队列
	infectedQueue;

Logger
	log;

Handle
	infectedCountCheckTimer;

float
	// 基准时钟时钟周期
	standardTimerInterval,
	// 固定时钟时钟周期
	regularTimerInterval,
	// 动态时钟时钟周期
	autoTimerInterval,
	// 一波刷特从开始找位到刷完所耗费的时间
	findPosSpawnTimeCost,
	// 距离上一波刷特完成间隔时间, For Debug
	spawnInterval,
	// 固定刷特时钟创建时间, For Debug
	regularTimerCreatedTime,
	// 动态刷特时钟创建时间, For Debug
	autoTimerCreatedTime;

bool
	isLeftSafeArea,
	// 是否可以生成新的特感
	canSpawnNewInfected,
	// 是否在一波刷新完成后的等待时间中
	isInSpawnFinishedTime,
	// 是否在找位失败后的延迟时间中
	isInFindPosFailedDelay,
	// 插件是否延迟加载
	isLateLoad;

int
	// 跑男客户端索引
	runnerIndex,
	// 当前刷新特感的波数
	currentSpawnWaveCount,
	// 分散刷新方式下, 当前重生完成的特感数量
	respawnFinishedCount,
	// 分散刷新方式下, 允许开始刷新时的特感数量
	targetCount;

// 刷新时间策略 SpawnStrategy
enum {
	SPS_NONE,
	SPS_REGULAR,
	SPS_AUTO,
	SPS_SIZE
};

// 找位策略 FindPosStrategy
enum {
	FPS_NONE,
	FPS_ALL_SURVIVOR,
	FPS_RANDOM_SURVIVOR,
	FPS_SIZE
};

// 刷新方式策略 SpawnMethodStrategy
enum {
	SMS_NONE,
	SMS_CENTERALIZE,
	SMS_DISPERSE,
	SMS_SIZE
};

enum {
	SSC_NONE,
	SSC_AUTO,
	SSC_MANUAL,
	SSC_SIZE
};

// 基本时钟类
enum struct BaseTimer {
	// 基础时钟句柄
	Handle timer;

	// 本时钟内记录的特感刷新波数
	int recordSpawnWaveCount;

	// 时钟 Flag
	int flag;
	// 时钟周期
	float interval;
	// 是否被触发
	bool isTriggered;
	// 触发次数
	int triggerCount;
	// 上次触发时间
	float lastTriggerTime;
	// 下次触发时间
	float nextTriggerTime;
	// 初始化函数
	void init() {
		this.timer = null;
		this.recordSpawnWaveCount = 0;
		this.flag = 0;
		this.interval = 0.0;
		this.isTriggered = false;
		this.triggerCount = 0;
		this.lastTriggerTime = 0.0;
		this.nextTriggerTime = 0.0;
	}
}

// 特感状态类
enum struct InfectedState {
	// 重生时钟句柄
	Handle timer;
	// 客户端名称
	char name[64];
	// 客户端特感类型
	int infectedType;
	// 客户端死亡时间
	float deathTime;
	// 下次允许重生的时间
	float nextRespawnTime;
	// 客户端是否重生完毕
	bool isRespawnFinished;
	// 是否有效
	bool valid;
	// 初始化函数
	void init() {
		this.timer = null;
		this.infectedType = 0;
		this.deathTime = 0.0;
		this.nextRespawnTime = 0.0;
		this.isRespawnFinished = false;
		this.valid = false;
	}
}

InfectedState infectedStates[MAXPLAYERS + 1];

// 基准时钟, 固定时钟, 动态时钟
BaseTimer
	standardInfectedSpawnTimer,
	regularInfectedSpawnTimer,
	autoInfectedSpawnTimer;

public Plugin myinfo = 
{
	name 			= "[Infected-Control] 特感刷新控制",
	author 			= "夜羽真白",
	description 	= "特感刷新控制",
	version 		= "1.0.0.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// Natives 和 Forwards
#include "natives_and_forwards.sp"
// 特感刷新队列
#include "inf_queue.sp"
// 特感找位控制
#include "inf_pos_find.sp"
// 时钟控制
#include "timers.sp"
// 事件处理
#include "events.sp"
// 指令处理
#include "commands.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {

	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead2) {
		strcopy(error, err_max, "本插件仅支持 Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	setUpNatives();
	RegPluginLibrary("infected_control");

	isLateLoad = late;

	return APLRes_Success;
}

public void OnAllPluginsLoaded() {
	if (!LibraryExists("left4dhooks")) {
		LogMessage("\n==========\n 本插件需要前置插件 \"[L4D & L4D2] Left 4 DHooks Direct\" 方可运行 \n==========\n");
		SetFailState("\n==========\n 本插件需要前置插件 \"[L4D & L4D2] Left 4 DHooks Direct\" 方可运行 \n==========\n");
	}
}

public void OnPluginStart() {
	
	g_hInfectedLimit = CreateConVar("inf_limit", "4", "特感刷新数量", CVAR_FLAG, true, 0.0, true, float(MaxClients));
	g_hSpawnDuration = CreateConVar("inf_spawn_duration", "30", "两次刷新之间基本间隔", CVAR_FLAG, true, 0.0);
	// 刷新及找位控制
	g_hSpawnStrategy = CreateConVar("inf_spawn_strategy", "1", "特感刷新策略 (1: 每波之间间隔固定 [击杀特感数量达到设置数量 / 2 开始计时], 2: 每波之间间隔根据击杀情况自动调整 [击杀特感数量达到设置数量 / 2 或 击杀强控特感数量达到强控总数 / 2 + 1 特时开始计时])", CVAR_FLAG, true, float(SPS_NONE + 1), true, float(SPS_SIZE - 1));
	g_hSpawnMethodStrategy = CreateConVar("inf_spawn_method_strategy", "1", "特感刷新方式 (1: 集中刷新 [到时间一起刷新一波], 2: 分散刷新 [每个特感单独按 g_hSpawnDuration 计时, 到时间不会一起刷新一波])", CVAR_FLAG, true, float(SMS_NONE + 1), true, float(SMS_SIZE - 1));
	g_hDisperseSpawnPercent = CreateConVar("inf_disperse_spawn_per", "0.5", "采用分散刷新方式时, 先死亡的特感需要等待至少 [g_hDisperseSpawnPercent * g_hInfectedLimit] 取下整个特感复活时间完成或在场才允许复活, [如配置 5 特感, 本值为 0.5, 则先死亡的特感需要等待至少 3 只特感复活完成或在场至少 3 只特感才可复活]", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hFindPosStrategy = CreateConVar("inf_find_pos_strategy", "2", "特感找位策略 (1: 轮询所有生还者位置找位, 2: 以随机一个生还者为目标找位)", CVAR_FLAG, true, float(FPS_NONE + 1), true, float(FPS_SIZE - 1));
	g_hEachPosInfectedCount = CreateConVar("inf_each_pos_count", "1", "每个刷新位置允许刷新多少只特感", CVAR_FLAG, true, 1.0, true, float(MaxClients));
	g_hFirstWaveDelay = CreateConVar("inf_firstwave_delay", "15.0", "每局第一波特感刷新在首个生还者离开安全区域后延迟多少秒 (0: 不延迟)", CVAR_FLAG, true, 0.0);
	g_hIncapExtraTime = CreateConVar("inf_incap_extra_time", "5.0", "有一个生还者倒地则下一波刷特向后延迟多少秒 (0: 不延迟) [仅集中刷新模式可用]", CVAR_FLAG, true, 0.0);
	g_hDeadKickTime = CreateConVar("inf_dead_kick_time", "0.5", "多少秒后踢出死亡的特感 [除 Spitter]", CVAR_FLAG, true, 0.1);
	g_hStartSpawnControl = CreateConVar("inf_start_spawn_control", "1", "以何种方式开启特感刷新 (1: 自动控制 [首个生还者离开安全区域自动刷新], 2: 手动控制 [需要输入 !startspawn 指令])", CVAR_FLAG, true, float(SSC_NONE + 1), true, float(SSC_SIZE - 1));
	// 日志记录
	g_hLoggingLevel = CreateConVar("inf_log_level", "1", "插件日志级别 (1: 禁用, 2: DEBUG, 4: INFO, 8: MESSAGE, 16: SERVER, 32: ERROR) 数字相加", CVAR_FLAG, true, 0.0, true, 64.0);

	game_zMaxPlayerZombie = FindConVar("z_max_player_zombies");
	game_directorNoSpecials = FindConVar("director_no_specials");
	if (game_zMaxPlayerZombie != null) {
		int flags = game_zMaxPlayerZombie.Flags;
		game_zMaxPlayerZombie.SetBounds(ConVarBound_Upper, false);
		game_zMaxPlayerZombie.Flags = flags & ~FCVAR_CHEAT;
	}

	RegAdminCmd("sm_startspawn", cmdStartSpawn, ADMFLAG_BAN, "开始特感刷新");
	RegAdminCmd("sm_limit", cmdInfectedLimit, ADMFLAG_BAN, "更改特感数量");
	RegAdminCmd("sm_duration", cmdSpawnDuration, ADMFLAG_BAN, "更改特感刷新时间");
	RegAdminCmd("sm_type", cmdSingleInfectedMode, ADMFLAG_BAN, "启用单一特感模式");

	RegAdminCmd("sm_statelist", cmdStateList, ADMFLAG_BAN, "展示特感状态数组情况");

	g_hInfectedLimit.AddChangeHook(changeHookInfectedLimit);
	g_hSpawnDuration.AddChangeHook(changeHookSpawnDuration);
	g_hSpawnMethodStrategy.AddChangeHook(changeHookSpawnMethodStrategy);
	g_hLoggingLevel.AddChangeHook(changeHookLoggingLevel);

	// 事件挂钩
	HookEvent("round_start", eventRoundStartHandler);
	HookEvent("mission_lost", eventRoundEndHandler);
	HookEvent("round_end", eventRoundEndHandler);
	HookEvent("player_death", eventPlayerDeathHandler);
	HookEvent("player_incapacitated", eventPlayerIncapStartHandler);
	HookEvent("revive_success", eventReviveSucessHandler);

	log = new Logger(g_hLoggingLevel.IntValue);

	// 其他模块
	// 特感刷新队列模块
	infectedQueueOnModulStart();
	// 特感找位模块
	infectedPosFindOnModuleStart();
	// Natives And Forwards
	nativesAndForwardsOnModuleStart();

	getInfectedSpawnTimerInterval();
	getDisperseTargetInfectedCount();

	// 设置最大特感数量
	CreateTimer(MAX_SPECIAL_SET_DELAY, timerSetMaxSpecialHandler, _, _);

	if (isLateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i)) {
				continue;
			}
			SDKHook(i, SDK_HOOK_TYPE, sdkHookFindPosHandler);
		}
	}
}

public void OnPluginEnd() {

	delete infectedQueue;
	setDirectorNoSpecials(false);

	// 其他模块
	// 特感刷新队列模块
	infectedQueueOnModuleEnd();
}

public void OnMapStart() {
	resetTimersAndStates();
	// 重新获取时钟周期
	getInfectedSpawnTimerInterval();
	getDisperseTargetInfectedCount();
}

/**
* 玩家连接服务器
* @param client 连接服务器的玩家
* @return void
**/
public void OnClientPutInServer(int client) {
	if (g_hFindPosStrategy.IntValue != FPS_ALL_SURVIVOR) {
		return;
	}
	// 集中刷新模式, Hook 加入的生还者
	SDKHook(client, SDK_HOOK_TYPE, sdkHookFindPosHandler);
}

/**
* 第一个生还者离开起始安全区域
* @param client 离开安全区域的客户端索引
* @return Action
**/
public Action L4D_OnFirstSurvivorLeftSafeArea(int client) {
	// 客户端索引无效或不是有效生还者, 不允许触发事件
	if (!IsValidClient(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client)) {
		return Plugin_Handled;
	}

	// 创建特感数量检测时钟, 开始刷新特感
	delete infectedCountCheckTimer;
	infectedCountCheckTimer = CreateTimer(SPAWN_CHECK_TIMER_INTERVAL, timerInfectedCountCheckHandler, _, TIMER_REPEAT);

	// 开始刷新第一波特感
	static int i;
	if (g_hFindPosStrategy.IntValue == FPS_RANDOM_SURVIVOR) {
		i = getRandomSurvivor();
		if (!IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) {
			log.debugAndInfo("\n%s: 当前找位策略为针对某个生还者找位, 目标生还者 %d (%N) 无效, 将不会触发找位!\n", PLUGIN_PREFIX, i, i);
			return Plugin_Continue;
		}
		SDKHook(i, SDK_HOOK_TYPE, sdkHookFindPosHandler);
		log.debugAndInfo("%s: 当前找位策略为针对某个生还者找位, 目标生还者 %N", PLUGIN_PREFIX, i);
	}

	// 自动控制模式, 允许刷新特感
	if (g_hStartSpawnControl.IntValue == SSC_AUTO) {
		// 允许刷新新的特感, 是否需要延迟刷新第一波特感
		if (g_hFirstWaveDelay.BoolValue) {
			CreateTimer(g_hFirstWaveDelay.FloatValue, timerFirstWaveDelaySpawnHandler, _, _);
		} else {
			canSpawnNewInfected = true;
		}
	}

	log.debugAndInfo("%s: 第一个玩家 %N 出安全区域, 当前刷新控制模式 %d, 是否允许刷新第 1 波特感 %b, 延迟 %.2f s", PLUGIN_PREFIX, client, g_hStartSpawnControl.IntValue, canSpawnNewInfected, g_hFirstWaveDelay.FloatValue);

	isLeftSafeArea = true;
	return Plugin_Continue;
}

// ********** Timer Handles Start **********

/**
* 检测特感数量时钟回调函数（周期 1.0s）
* @param timer 时钟句柄
* @return Aciton
**/
public Action timerInfectedCountCheckHandler(Handle timer) {
	// 总特感数量, 强控特感数量, DPS 特感数量
	static int count, dominativeCount, dpsCount;

	count = getTeamClientCount(TEAM_INFECTED, true, false),
	dominativeCount = getDominativeInfectedCount(),
	dpsCount = count - dominativeCount > 0 ? count - dominativeCount : 0;

	// 如果正在刷新特感, 则停止检测
	if (canSpawnNewInfected) {
		return Plugin_Continue;
	}

	// 如果是分散刷新, 停止检测
	if (g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE) {
		return Plugin_Continue;
	}

	// 触发固定刷特时钟
	if (g_hSpawnStrategy.IntValue == SPS_REGULAR &&
	 	isInSpawnFinishedTime && 
		canTriggerRegularInfectedSpawnTimer(count, dominativeCount, dpsCount)) {
		// 满足固定时钟创建条件, 但有生还者倒地, 不创建固定时钟
		if (g_hIncapExtraTime.BoolValue && hasAnySurvivorIncap()) {
			return Plugin_Continue;
		}

		// 未创建固定刷特时钟则创建
		if (regularInfectedSpawnTimer.timer == null) {
			regularTimerCreatedTime = GetEngineTime();

			log.debugAndInfo("\n%s: 检测到当前在刷特间隔内, 满足固定时钟触发条件且当前固定时钟为 null, 创建固定时钟, 周期 %.2f, 距离上次创建固定时钟经过 %.3f s\n", PLUGIN_PREFIX, g_hSpawnDuration.FloatValue, GetEngineTime() - regularTimerCreatedTime);

			regularInfectedSpawnTimer.init();

			regularInfectedSpawnTimer.timer = CreateTimer(regularTimerInterval, timerRegularInfectedSpawnHandler, _, _);
			// 设置固定刷特时钟参数
			regularInfectedSpawnTimer.interval = g_hSpawnDuration.FloatValue;
			regularInfectedSpawnTimer.lastTriggerTime = GetGameTime();
			regularInfectedSpawnTimer.nextTriggerTime = GetGameTime() + g_hSpawnDuration.FloatValue;
		}
	} else if (g_hSpawnStrategy.IntValue == SPS_AUTO && 
		isInSpawnFinishedTime && 
		canTriggerAutoInfectedSpawnTimer(count, dominativeCount, dpsCount)) {
		// 满足动态时钟创建条件, 但有生还者倒地, 不创建动态时钟
		if (g_hIncapExtraTime.BoolValue && hasAnySurvivorIncap()) {
			return Plugin_Continue;
		}

		// 触发自动刷特时钟, 未创建自动刷特时钟则创建
		if (autoInfectedSpawnTimer.timer == null) {
			autoTimerCreatedTime = GetEngineTime();

			log.debugAndInfo("\n%s: 检测到当前在刷特间隔内, 且满足动态时钟触发条件且当前动态时钟为 null, 创建动态时钟, 周期 %.2f, 距离上次创建动态时钟经过 %.3f s\n", PLUGIN_PREFIX, autoTimerInterval, GetEngineTime() - autoTimerCreatedTime);

			autoInfectedSpawnTimer.init();
			autoInfectedSpawnTimer.timer = CreateTimer(autoTimerInterval, timerAutoInfectedSpawnHandler, _, _);
			// 设置动态时钟参数
			autoInfectedSpawnTimer.interval = g_hSpawnDuration.FloatValue;
			autoInfectedSpawnTimer.lastTriggerTime = GetGameTime();
			autoInfectedSpawnTimer.nextTriggerTime = GetGameTime() + g_hSpawnDuration.FloatValue;
		}
	}

	return Plugin_Continue;
}

// ********** Timer Handles End **********

/**
* 生还者 SDKHook 找位刷新回调函数
* @param client 客户端索引
* @return void
**/
void sdkHookFindPosHandler(int client) {
	// 生还者无效, 停止 Hook
	if (!IsValidClient(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client)) {
		return;
	}

	// 不允许刷新新的特感, 返回
	if (!canSpawnNewInfected || isInFindPosFailedDelay || isInSpawnFinishedTime) {
		return;
	}

	// 存在跑男, UnHook 不是跑男的生还者
	if (runnerIndex != INVALID_CLIENT_INDEX && runnerIndex != client) {
		SDKUnhook(client, SDK_HOOK_TYPE, sdkHookFindPosHandler);
		return;
	}

	// 特感刷新队列为 null, 重新获取一个
	if (infectedQueue == null) {
		infectedQueue = getInfectedQueue();
	}

	static int i;
	if (FloatCompare(findPosSpawnTimeCost, 0.0) == 0) {
		// 当前是第一波刷特, 时间还没有记录, 将距离上一波刷特完成时间记为当前时间
		if (FloatCompare(spawnInterval, 0.0) == 0) {
			spawnInterval = GetEngineTime();
		}

		if (g_hSpawnMethodStrategy.IntValue == SMS_CENTERALIZE)
			log.debugAndInfo("\n%s: 开始第 %d 次特感刷新, 开始记录找位刷新时间, 当前时间: %.2f, 距离上一波刷特完成经过 %.3f s", PLUGIN_PREFIX, currentSpawnWaveCount, GetEngineTime(), GetEngineTime() - spawnInterval);
		else if (g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE)
			log.debugAndInfo("\n%s: 当前为分散刷新模式, 开始刷新特感, 记录找位刷新时间, 当前时间: %.2f, 距离上一波刷特完成经过 %.3f s", PLUGIN_PREFIX, GetEngineTime(), GetEngineTime() - spawnInterval);

		// 开始记录找位刷新所花费的时间
		findPosSpawnTimeCost = GetEngineTime();
		// 置是否在一波刷新完成时间为 false, 当前准备刷新新一波特感
		isInSpawnFinishedTime = false;

		// 发布一波特感开始找位刷新自定义事件
		Call_StartForward(onOnceSpawnStarted);
		Call_Finish();
	}
	
	// 没有新的特感可以刷新, 返回
	if (infectedQueue.Length < 1) {
		// 找位刷新计时未启动, 返回
		if (FloatCompare(findPosSpawnTimeCost, 0.0) == 0) {
			return;
		} else if (FloatCompare(GetEngineTime(), findPosSpawnTimeCost) > 0) {
			// 当前是第一波刷特, 将距离上一波刷特完成时间记为当前时间
			if (currentSpawnWaveCount == 1) {
				spawnInterval = GetEngineTime();
			}

			// 找位刷新计时大于 0 时, 判断为找位刷新已经开始, 队列中没有特感可以刷新, 判断为刷新完成
			log.debugAndInfo("%s: 第 %d 波特感刷新完成, 当前时间 %.2f, 共耗时: %.3f s, 距离上一波刷特完成经过 %.3f s", PLUGIN_PREFIX, currentSpawnWaveCount, GetEngineTime(), GetEngineTime() - findPosSpawnTimeCost, GetEngineTime() - spawnInterval);

			// 刷新完成, 删除当前刷新队列, 并置是否可以刷新新的特感为 false, 记录这波特感刷新完成时间, 网格拓展次数置 0
			delete infectedQueue;
			infectedQueue = null;

			// 刷新完成后处理接口
			postProcessOnOnceSpawnFinished();

			// 发布一波特感刷新完成自定义事件
			Call_StartForward(onOnceSpawnFinished);
			Call_Finish();

			canSpawnNewInfected = false;
			isInSpawnFinishedTime = true;
			spawnInterval = GetEngineTime();
			respawnFinishedCount = 0;
			expandCount = 0;

			// 重置找位刷特消耗时间
			findPosSpawnTimeCost = 0.0;

			// 全局记录特感刷新波次自增, 不是第一波刷特允许自增
			if (currentSpawnWaveCount >= 1) {
				currentSpawnWaveCount++;
			}

			// 针对某个生还者找位, 找位完成 UnHook
			if (g_hFindPosStrategy.IntValue == FPS_RANDOM_SURVIVOR) {
				SDKUnhook(client, SDK_HOOK_TYPE, sdkHookFindPosHandler);
			}
			// 解除本波次的跑男检测
			if (runnerIndex != INVALID_CLIENT_INDEX) {
				runnerIndex = INVALID_CLIENT_INDEX;
			}
		}
		return;
	}

	// 特感刷新找位
	float spawnPos[3];
	if (GetEngineTime() - findPosSpawnTimeCost <= g_hStartExpandTime.FloatValue) {
		// 不进行网格拓展
		getSpawnPos(client, _, spawnPos);
	} else if (FloatCompare(g_hFindPosMaxTime.FloatValue, 0.0) > 0 &&
			 GetEngineTime() - findPosSpawnTimeCost >= g_hFindPosMaxTime.FloatValue) {
		log.debugAndInfo("%s: 当前找位超出一次找位最大限制时长, 当前耗时 %.2f s, 限制 %.2fs", PLUGIN_PREFIX, GetEngineTime() - findPosSpawnTimeCost, g_hFindPosMaxTime.FloatValue);
		// 找位刷新用时超出一次找位刷新用时时间
		findPosSpawnTimeCost = 0.0;
		canSpawnNewInfected = false;
		isInFindPosFailedDelay = true;
		CreateTimer(g_hFailedFindPosNextDelay.FloatValue, timerFindPosFailedHandler, _, _);
	} else {
		// 开始进行网格拓展
		getSpawnPos(client, g_hExpandUnit.FloatValue, spawnPos);
	}

	// 无效刷新位置, 返回
	if (IsZeroVector(spawnPos)) {
		return;
	}

	// 开始刷新特感
	static int infectedType, queueIndex;
	for (i = 0; i < g_hEachPosInfectedCount.IntValue; i++) {
		// 集中刷新方式, 从特感刷新队列头部获取特感类型刷新
		if (g_hSpawnMethodStrategy.IntValue == SMS_CENTERALIZE) {
			if (infectedQueue.Length < 1) {
				return;
			}

			infectedType = infectedQueue.Get(0);
			if (infectedType < ZC_SMOKER || infectedType > ZC_CHARGER) {
				infectedQueue.Erase(0);
				return;
			}

			infectedQueue.Erase(0);
			L4D2_SpawnSpecial(infectedType, spawnPos, view_as<float>({0.0, 0.0, 0.0}));
		} else if (g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE) {
			static int stateArrIndex = -1;
			bool findRespawnFinished;
			InfectedState state;
			// 分散刷新时, 可以刷新新的特感, 遍历状态数组, 找到一个已经重生完毕的特感, 从下一波刷新队列中寻找相同类型的特感
			if (currentSpawnWaveCount > 1) {
				for (i = 1; i <= MaxClients; i++) {
					state = infectedStates[i];
					if (!state.valid || !state.isRespawnFinished) {
						continue;
					}
					log.debugAndInfo("%s: 当前为分散刷新模式, 在特感状态队列中找到一个重生完成的特感 [名称 %s]", PLUGIN_PREFIX, INFECTED_NAME[state.infectedType]);
					stateArrIndex = i;
					findRespawnFinished = true;
					break;
				}
				log.debugAndInfo("%s: 是否找到任何一个重生完成的特感 %b", PLUGIN_PREFIX, findRespawnFinished);
				if (!findRespawnFinished) {
					log.debugAndInfo("\n%s: 当前为分散刷新模式, 遍历完成状态数组, 没有找到重生完成的特感, 不允许刷新新的特感, 删除特感队列\n", PLUGIN_PREFIX);
					canSpawnNewInfected = false;
					delete infectedQueue;
					infectedQueue = null;
					return;
				}
			}

			// 找到相同特感类型, 刷新该特感, 第一波 state 中的 type 为 0, 直接从刷新队列中刷新
			if ((queueIndex = infectedQueue.FindValue(state.infectedType)) > -1) {
				infectedType = state.infectedType;
				L4D2_SpawnSpecial(state.infectedType, spawnPos, view_as<float>({0.0, 0.0, 0.0}));
				if (stateArrIndex > -1) {
					infectedStates[stateArrIndex].init();
				}
				infectedQueue.Erase(queueIndex);

				log.debugAndInfo("%s: 当前为分散刷新模式, 在新一波刷新队列中找到 %s 类型特感, 索引为 %d, 在 [%.2f, %.2f, %.2f] 处刷新一只 %s, 该特感数量 %d", PLUGIN_PREFIX, INFECTED_NAME[state.infectedType], queueIndex, spawnPos[0], spawnPos[1], spawnPos[2], INFECTED_NAME[state.infectedType], getSpecificInfectedCount(state.infectedType));
			} else {
				if (infectedQueue.Length < 1) {
					return;
				}
				// 没有找到 或 是第一波刷特, 从刷新队列头部获取一个特感类型刷新
				infectedType = infectedQueue.Get(0);
				if (infectedType < ZC_SMOKER || infectedType > ZC_CHARGER) {
					infectedQueue.Erase(0);
					return;
				}
				// 不是第一波刷特
				if (currentSpawnWaveCount > 1) {
					log.debugAndInfo("%s: 当前为分散刷新模式, 在新一波刷新队列中没有找到 %s 类型特感, 从队首获取一个特感, 类型 %s, 在 [%.2f %.2f %.2f] 处刷新", PLUGIN_PREFIX, INFECTED_NAME[state.infectedType], INFECTED_NAME[infectedType], spawnPos[0], spawnPos[1], spawnPos[2]);
				}
				
				infectedQueue.Erase(0);
				L4D2_SpawnSpecial(infectedType, spawnPos, view_as<float>({0.0, 0.0, 0.0}));
				if (stateArrIndex > -1) {
					infectedStates[stateArrIndex].init();
				}
			}
			respawnFinishedCount = respawnFinishedCount > 0 ? respawnFinishedCount - 1 : 0;
		}

		if (g_hSpawnMethodStrategy.IntValue == SMS_CENTERALIZE)
			log.debugAndInfo("%s: 在 [%.2f, %.2f, %.2f] 处刷新一只 %s, 当前在场 %s 数量 %d 只, 还剩 %d 只特感待刷新, 耗时 %.3f s", PLUGIN_PREFIX, spawnPos[0], spawnPos[1], spawnPos[2], INFECTED_NAME[infectedType], INFECTED_NAME[infectedType], getSpecificInfectedCount(infectedType), infectedQueue.Length, GetEngineTime() - findPosSpawnTimeCost);
		else if (g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE)
			log.debugAndInfo("%s: 分散刷新模式, 在 [%.2f, %.2f, %.2f] 处刷新一只 %s, 当前在场 %s 数量 %d 只, 耗时 %.3f s", PLUGIN_PREFIX, spawnPos[0], spawnPos[1], spawnPos[2], INFECTED_NAME[infectedType], INFECTED_NAME[infectedType], getSpecificInfectedCount(infectedType), GetEngineTime() - findPosSpawnTimeCost);
	}

}

// ********** Interface Start **********

/**
* 一波特感刷新完成后处理接口
* @param 
* @return void
**/
stock void postProcessOnOnceSpawnFinished() {

	log.debugAndInfo("\n%s: 开始第 %d 波特感刷新完成后处理配置\n", PLUGIN_PREFIX, currentSpawnWaveCount);

	// ***** Timer Sync Start *****
	// 当前不是分散刷新模式, 且是本局第一波刷特, 开启基准时钟
	if (g_hSpawnMethodStrategy.IntValue != SMS_DISPERSE) {
		if (currentSpawnWaveCount == 1) {
			log.debugAndInfo("%s: 当前是第 1 波特感刷新, 创建基准时钟, 时钟周期为: %.2f s", PLUGIN_PREFIX, standardTimerInterval);
			// 设置基准时钟参数, 出门刷新第一波, 基准时钟波次设置为 1
			standardInfectedSpawnTimer.init();
			standardInfectedSpawnTimer.interval = standardTimerInterval;
			standardInfectedSpawnTimer.recordSpawnWaveCount = 1;
		} else {
			// 不是第一波刷特, 刷新完成, 删除基准时钟并重新创建
			delete standardInfectedSpawnTimer.timer;
			standardInfectedSpawnTimer.isTriggered = false;
			log.debugAndInfo("\n%s: 当前是第 %d 波特感刷新, 重新创建基准时钟, 时钟周期 %.2f s, 下次触发时间 %.2f s\n", PLUGIN_PREFIX, currentSpawnWaveCount, standardTimerInterval, standardInfectedSpawnTimer.nextTriggerTime);
		}
		standardInfectedSpawnTimer.lastTriggerTime = GetGameTime();
		standardInfectedSpawnTimer.nextTriggerTime = GetGameTime() + standardTimerInterval;
		standardInfectedSpawnTimer.timer = CreateTimer(standardTimerInterval, timerStandardInfectedSpawnHandler, _, _);
	}
	// ***** Timer Sync End *****

}

// ********** Interface End **********

// ********** Methods Start **********

/**
* 获取强控特感（SMOKER, HUNTER, JOCKEY, CHARGER）在场总数
* @param 
* @return int
**/
static int getDominativeInfectedCount() {
	static int i;
	int class, count = 0;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || GetClientTeam(i) != TEAM_INFECTED || !IsPlayerAlive(i) || IsClientIncapped(i) || IsInGhostState(i)) {
			continue;
		}
		class = GetEntProp(i, Prop_Send, "m_zombieClass");
		if (class == ZC_SMOKER || class == ZC_HUNTER || class == ZC_JOCKEY || class == ZC_CHARGER) {
			count++;
		}
	}
	return count;
}

/**
* 获取 Cvar 设置中强控特感（SMOKER, HUNTER, JOCKEY, CHARGER）总数
* @param 
* @return int 
**/
static int getCvarDominativeInfectedCount() {
	static int i;
	int count = 0;
	for (i = 0; i < INFECTED_ARRAY_SIZE - 1; i++) {
		if (i == ZC_BOOMER || i == ZC_SPITTER) {
			continue;
		}
		count += g_hInfectedCvarLimit[i].IntValue;
	}
	return count;
}

/**
* 随机获取一个有效生还者 (优先获取未被控, 未倒地的生还者, 如无则随机获取一个未死亡的生还者)
* @param excludeClient 排除的生还者
* @return int
**/
stock int getRandomSurvivor(int excludeClient = INVALID_CLIENT_INDEX) {
	static int i, ret;
	ret = INVALID_CLIENT_INDEX;

	static ArrayList list;
	list = new ArrayList();

	// 优先寻找未倒地, 未被控的生还者
	for (i = 1; i <= MaxClients; i++) {
		if (i == excludeClient || !IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i) || IsClientPinned(i) || IsClientIncapped(i)) {
			continue;
		}
		list.Push(i);
	}
	if (list.Length >= 1) {
		ret = list.Get(GetRandomIntInRange(0, list.Length - 1));
		delete list;
		return ret;
	}
	// 如果没有, 则随机选取一个活着的生还者
	for (i = 1; i <= MaxClients; i++) {
		if (i == excludeClient || !IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) {
			continue;
		}
		list.Push(i);
	}
	if (list.Length < 1) {
		delete list;
		return ret;
	}
	ret = list.Get(GetRandomIntInRange(0, list.Length - 1));
	delete list;
	return ret;
}

/**
* 一局开始或地图开始重置状态
* @param 
* @return void
**/
void resetTimersAndStates() {
	delete infectedCountCheckTimer;
	delete infectedQueue;

	standardInfectedSpawnTimer.init();
	regularInfectedSpawnTimer.init();
	autoInfectedSpawnTimer.init();

	isLeftSafeArea = false;
	canSpawnNewInfected = false;
	isInSpawnFinishedTime = false;
	isInFindPosFailedDelay = false;

	findPosSpawnTimeCost = 0.0;
	spawnInterval = 0.0;
	regularTimerCreatedTime = 0.0;
	autoTimerCreatedTime = 0.0;
	currentSpawnWaveCount = 1;
	expandCount = 0;
	runnerIndex = INVALID_CLIENT_INDEX;

	respawnFinishedCount = 0;
	targetCount = 0;

	setDirectorNoSpecials(true);

	static int i;
	for (i = 1; i <= MaxClients; i++) {
		playerIncapRecord[i] = false;
		infectedStates[i].init();
	}
}

/**
* 是否可以触发固定刷特时钟
* @param infectedCount 当前在场特感总数
* @param dominativeCount 当前在场强控特感总数
* @param dpsCount 当前在场的 DPS 特感总数
* @return bool
**/
static bool canTriggerRegularInfectedSpawnTimer(int infectedCount, int dominativeCount, int dpsCount) {
	// 触发条件 1: 当前特感小于等于 (设定数量 / 2) + 1 特
	int threshold = infectedCount / 2 + 1;
	if (infectedCount <= threshold) {
		return true;
	}
	return false;
}

/**
* 是否可以触发动态刷特时钟
* @param infectedCount 当前在场特感总数
* @param dominativeCount 当前在场强控特感总数
* @param dpsCount 当前在场的 DPS 特感总数
* @return bool
**/
static bool canTriggerAutoInfectedSpawnTimer(int infectedCount, int dominativeCount, int dpsCount) {
	// 触发条件 1: 基准时钟被触发
	if (canTriggerRegularInfectedSpawnTimer(infectedCount, dominativeCount, dpsCount)) {
		return true;
	}
	// 触发条件 2: 当前强控数量 <= (强控总数 / 2) + 1 特
	static int cvarDominativeCount;
	cvarDominativeCount = getCvarDominativeInfectedCount();
	if (dominativeCount <= (cvarDominativeCount >> 1 | 1)) {
		return true;
	}
	return false;
}

/**
* 当前是否有任何生还者处于倒地状态
* @param void
* @return bool
**/
static bool hasAnySurvivorIncap() {
	static int i;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) {
			continue;
		}
		if (IsClientIncapped(i)) {
			return true;
		}
	}
	return false;
}

void getInfectedSpawnTimerInterval() {
	static int half;
	half = g_hInfectedLimit.IntValue / 2;
	// 基准时钟间隔: SpawnDuration + (Limit / 2 == 0 ? 1 : Limit / 2) * 4 (保底 4 s)
	standardTimerInterval = g_hSpawnDuration.FloatValue + (half > 0 ? half : 1) * 4;
	// 固定时钟间隔: SpawnDuration == 0 ? 4s : SpawnDuration (保底 4s)
	regularTimerInterval = float(g_hSpawnDuration.IntValue == 0 ? 4 : g_hSpawnDuration.IntValue);
	// 动态时钟间隔: SpawnDuration + (Limit / 2 - 1 == 0 ? 1 : Limit / 2 - 1) * 4 (保底 4 s)
	autoTimerInterval = g_hSpawnDuration.FloatValue + (half - 1 > 0 ? half - 1 : 1) * 4;
}

void getDisperseTargetInfectedCount() {
	targetCount = RoundToCeil(g_hDisperseSpawnPercent.FloatValue * g_hInfectedLimit.FloatValue);
}

// ********** Methods End **********

// HACK: 需要增加与减少特感数量的情况, Bug 发现, 排除, 修复
void changeHookInfectedLimit(ConVar convar, const char[] oldValue, const char[] newValue) {
	log.debugAndInfo("%s: 特感数量 Cvar 变动, 旧值 %s, 新值 %s", PLUGIN_PREFIX, oldValue, newValue);

	// 重新获取特感等待队列
	getInfectedQueuePositionList();

	// 生还者还没有离开安全区域, 重新获取特感刷新队列
	if (!isLeftSafeArea) {
		delete infectedQueue;
		infectedQueue = getInfectedQueue();
	} else {
		// 离开了安全区域调整特感数量, 当前是分散刷新方式
		if (g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE) {
			// 重新获取可刷新时已重生完成的特感上限
			getDisperseTargetInfectedCount();

			static int i, j, oldV, newV, class, offset;
			static ArrayList newInfectedQueue, handlingQueue;
			static InfectedState state;
			oldV = StringToInt(oldValue);
			newV = StringToInt(newValue);

			if (newV < oldV) {
				offset = oldV - newV;
				// 直接从状态数组中删除, 否则新死亡的特感加入到状态数组中超限则不加入
				log.debugAndInfo("\n%s: 当前为分散刷新方式, 减少特感数量, 原数量 %d, 新数量 %d, 需要减少 %d 只特感, 当前在场 %d 只特感\n", PLUGIN_PREFIX, oldV, newV, offset, getTeamClientCount(TEAM_INFECTED, true, false));
				for (i = 1; i <= MaxClients; i++) {
					if (!infectedStates[i].valid) {
						continue;
					}
					if (offset < 1) {
						break;
					}
					infectedStates[i].init();
					offset--;
				}
				log.debugAndInfo("%s: 已从状态数组中减少 %d 只特感", PLUGIN_PREFIX, (oldV - newV) - offset);
			} else {
				offset = newV - oldV;
				log.debugAndInfo("\n%s: 当前为分散刷新方式, 增加特感数量, 原数量 %d, 新数量 %d, 需要增加 %d 只特感, 当前在场 %d 只特感, 重新获取特感刷新队列\n", PLUGIN_PREFIX, oldV, newV, offset, getTeamClientCount(TEAM_INFECTED, true, false));
				// 获取一个新的特感队列, 从里面取出对应数量的特感
				newInfectedQueue = getInfectedQueue();
				handlingQueue = newInfectedQueue.Clone();

				// 向状态数组与加入 offset 数量的特感状态, 待刷新
				for (i = 0; i < offset; i++) {
					if (newInfectedQueue.Length < offset) {
						log.debugAndInfo("%s: 新特感刷新队列长度 %d, 少于需要的特感数量, 发生错误!", PLUGIN_PREFIX, newInfectedQueue.Length);
						delete newInfectedQueue;
						return;
					}
					class = handlingQueue.Get(0);
					handlingQueue.Erase(0);

					state.deathTime = GetGameTime();
					state.nextRespawnTime = GetGameTime() + 0.5;
					state.infectedType = class;
					state.isRespawnFinished = true;
					state.valid = true;
					// 刷新队列不为 null, 添加到刷新队列中本波刷出
					if (infectedQueue != null) {
						log.debugAndInfo("%s: 当前刷新队列不为 null, 将新特感 %s 添加到刷新队列中", PLUGIN_PREFIX, INFECTED_NAME[state.infectedType]);
						infectedQueue.Push(state.infectedType);
					}
					// 跳过有效的特感状态
					for (j = 1; j <= MaxClients; j++) {
						if (infectedStates[j].valid) {
							continue;
						}
						infectedStates[j] = state;
						state.timer = CreateTimer(NEW_INFECTED_RESPAWN_DELAY, timerRespawnFinishHandler, j, _);
						log.debugAndInfo("%s: 向状态数组中新增一只 %s, 索引 %d, %.2f 秒开始复活", PLUGIN_PREFIX, INFECTED_NAME[state.infectedType], j, NEW_INFECTED_RESPAWN_DELAY);
						break;
					}
				}
				delete handlingQueue;
				// 如果当前刷新队列为 null, 表示已经完成一波刷新, 替换刷新队列, 新特感下一波刷出
				if (infectedQueue == null) {
					log.debugAndInfo("\n%s: 当前刷新队列为 null, 使用新刷新队列替换原刷新队列\n", PLUGIN_PREFIX);
					infectedQueue = newInfectedQueue;
				} else {
					delete newInfectedQueue;
				}
			}
		}
	}

	CreateTimer(MAX_SPECIAL_SET_DELAY, timerSetMaxSpecialHandler, _, _);
}

void changeHookLoggingLevel(ConVar convar, const char[] oldValue, const char[] newValue) {
	log = new Logger(g_hLoggingLevel.IntValue);
}

void changeHookSpawnDuration(ConVar convar, const char[] oldValue, const char[] newValue) {
	getInfectedSpawnTimerInterval();
}

void changeHookSpawnMethodStrategy(ConVar convar, const char[] oldValue, const char[] newValue) {
	int i, oldV = StringToInt(oldValue), newV = StringToInt(newValue);
	if (newV == SMS_CENTERALIZE) {
		// 更改为集中刷新模式, Hook 所有人
		if (canSpawnNewInfected) {
			CreateTimer(1.0, timerChangeSpawnMethodStrategyHandler, true, TIMER_REPEAT);
		} else {
			for (i = 1; i <= MaxClients; i++) {
				if (!IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR) {
					continue;
				}
				SDKHook(i, SDK_HOOK_TYPE, sdkHookFindPosHandler);
			}
		}
		log.debugAndInfo("%s: 特感刷新方式变更, 旧值 %d, 新值 %d, Hook 所有人", PLUGIN_PREFIX, oldV, newV);
	} else if (newV == SMS_DISPERSE) {
		// 更改为分散刷新, UnHook 所有人
		if (canSpawnNewInfected) {
			CreateTimer(1.0, timerChangeSpawnMethodStrategyHandler, false, TIMER_REPEAT);
		} else {
			for (i = 1; i <= MaxClients; i++) {
				if (!IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR) {
					continue;
				}
				SDKUnhook(i, SDK_HOOK_TYPE, sdkHookFindPosHandler);
			}
		}
		log.debugAndInfo("%s: 特感刷新方式变更, 旧值 %d, 新值 %d, UnHook 所有人", PLUGIN_PREFIX, oldV, newV);
	}
}

/**
* 脚本读取 MaxSpecials 时设置最大特感数量, 战役模式解锁特感上限
* @param key 脚本 key 名称
* @param retVal 返回值
* @return Action
**/
public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal) {
	if (strcmp(key, "MaxSpecials", false) == 0 && retVal != g_hInfectedLimit.IntValue) {
		retVal = g_hInfectedLimit.IntValue;
		return Plugin_Handled;
	}
	if (strcmp(key, "cm_AggressiveSpecials", false) == 0 && retVal != 1) {
		retVal = 1;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

/**
* director_no_specials 设置
* @param set 是否关闭, 关闭为 1, 否则为 0
* @return void
**/
void setDirectorNoSpecials(bool set) {
	if (!game_directorNoSpecials.BoolValue && set) {
		game_directorNoSpecials.SetInt(1);
		log.debugAndInfo("%s: 关闭游戏导演系统特感刷新, 当前 director_no_specials 值为 %b", PLUGIN_PREFIX, game_directorNoSpecials.BoolValue);
	} else if (game_directorNoSpecials.BoolValue && !set) {
		game_directorNoSpecials.SetInt(0);
		log.debugAndInfo("%s: 开启游戏导演系统特感刷新, 当前 director_no_specials 值为 %b", PLUGIN_PREFIX, game_directorNoSpecials.BoolValue);
	}
}