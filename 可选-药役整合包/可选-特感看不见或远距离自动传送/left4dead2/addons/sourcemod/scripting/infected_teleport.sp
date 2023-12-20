/*
 * @Author: 夜羽真白
 * @Date: 2023-03-23 00:51 周四
 * @Type: Left 4 Dead 2 Plugin
 * @Description: Infected Teleport 特感传送
 * @URL: https://github.com/GlowingTree880/L4D2_LittlePlugins
 */

#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <logger>
#include "treeutil/treeutil.sp"

#define CVAR_FLAG FCVAR_NOTIFY
#define INVALID_CLIENT -1
#define RAY_DOWN_ANGLE view_as<float>({90.0, 0.0, 0.0})
#define NAV_HEIGHT 20.0
#define PLAYER_HEIGHT 72.0
#define SDK_HOOK_TYPE SDKHook_PreThink
#define FIND_POS_DELAY 5.0
#define EXPAND_COUNT_PRE_FRAME 3
#define ALPHA_TRANSPARENT 0
#define PLUGIN_PREFIX "[InfectedTeleport]"

public Plugin myinfo = 
{
	name 			= "Infected Teleport",
	author 			= "夜羽真白",
	description 	= "特感传送",
	version 		= "2023/4/20",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

ConVar
	g_hEnable,
	g_hCheckTime,
	g_hCheckInterval,
	g_hAllowInfetedClass,
	g_hMinDistance,
	g_hMaxDistance,
	g_hMaxNavDistance,
	g_hExpandFrame,
	g_hTeleportDistance,
	g_hMaxTeleportCount,
	g_hIgnoreIncap,
	g_hHealthRestore,
	g_hShouldAhead,
	g_hAllowTeleportSpeed,
	g_hAllowInSaferoom,
	g_hTargetType,
	g_hTransParentTeleport,
	g_hEnableLog;

// 目标策略
enum
{
	TARGET_RANDOM,
	TARGET_CLOSEST,
	TARGET_HIGHEST_FLOW,
	TARGET_LOWEST_FLOW,
	TARGET_STRATERGY_SIZE
};

enum
{
	BLOCK_TYPE_EVERYONE,
	BLOCK_TYPE_SURVIVORS,
	BLOCK_TYPE_PLAYER_INFECTED,
	BLOCK_TYPE_ALL_INFECTED,
	BLOCK_TYPE_ALL_PLAYERS_AND_PHYSICS_OBJECTS
};

int
	teleportCheckTime[MAXPLAYERS + 1],
	teleportCount[MAXPLAYERS + 1],
	// expandFrame[client][0] 为未超过拓展帧数时的计数，[1] 为超过拓展帧数从拓展帧数到最大 Nav 距离的计数
	expandFrame[MAXPLAYERS + 1][2],
	offset;

bool
	allowedTeleportInfected[9],
	canFindTeleportPos[MAXPLAYERS + 1],
	pluginLateLoad = false;

float
	resetFindPosTime[MAXPLAYERS + 1];

Handle
	teleportCheckTimer = null;

ArrayList
	teleportInfecteds[MAXPLAYERS + 1];

Logger
	log;

static const char validEntityName[][] =
{
	"prop_dynamic",
	"prop_physics",
	"prop_physics_multiplayer",
	"func_rotating",
	"infected",
	"tank_rock",
	"witch"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion version = GetEngineVersion();
	if (version != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "[不支持的游戏]：此插件仅支持 Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	pluginLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hEnable = CreateConVar("teleport_enable", "1", "是否开启特感传送插件", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hCheckTime = CreateConVar("teleport_check_time", "2.0", "特感多少秒看不见生还者就会传送", CVAR_FLAG, true, 0.0);
	g_hCheckInterval = CreateConVar("teleport_check_interval", "1.0", "每隔多少秒检测一次在场特感的可视状态", CVAR_FLAG, true, 0.0);
	g_hAllowInfetedClass = CreateConVar("teleport_infected_class", "1,2,3,4,5,6", "哪种特感允许被传送", CVAR_FLAG);
	g_hMinDistance = CreateConVar("teleport_min_distance", "150.0", "特感传送的位置距离目标生还者的最小距离", CVAR_FLAG, true, 0.0);
	g_hMaxDistance = CreateConVar("teleport_max_distance", "800.0", "特感传送的位置距离目标生还者的最大距离", CVAR_FLAG, true, 0.0);
	g_hMaxNavDistance = CreateConVar("teleport_max_nav_distance", "800.0", "特感传送的位置距离目标生还者的最大 Nav 距离", CVAR_FLAG, true, g_hMaxDistance.FloatValue + 1.0);
	g_hTeleportDistance = CreateConVar("teleport_start_distance", "600.0", "特感落后目标生还者这么远就尝试将其传送", CVAR_FLAG, true, 0.0);
	g_hExpandFrame = CreateConVar("teleport_expand_frame", "50", "传送的特感这么多帧数没有找到位置则开始扩大找位范围，直到 z_spawn_range", CVAR_FLAG, true, 0.0);
	g_hMaxTeleportCount = CreateConVar("teleport_max_count", "-1", "每只特感允许传送的最大次数，-1: 无限制", CVAR_FLAG, true, -1.0);
	g_hHealthRestore = CreateConVar("teleport_health_restore", "50", "特感每次传送回复失去血量的这么多百分比", CVAR_FLAG, true, 0.0, true, 100.0);
	g_hAllowTeleportSpeed = CreateConVar("teleport_allow_speed", "50", "特感的当前速度低于这个值允许进行传送检测", CVAR_FLAG, true, 0.0);
	g_hShouldAhead = CreateConVar("teleport_pos_ahead", "0", "特感传送的位置的路程是否需要在目标生还者之前", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hIgnoreIncap = CreateConVar("teleport_ignore_incap", "0", "特感传送是否无视倒地生还者视野", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hTargetType = CreateConVar("teleport_target_type", "3", "特感传送目标选择: 1=随机生还者, 2=离自身最近的生还者, 3=路程最高的生还者, 4=路程最低的生还者", CVAR_FLAG, true, float(TARGET_RANDOM), true, float(TARGET_STRATERGY_SIZE - 1));
	g_hAllowInSaferoom = CreateConVar("teleport_allow_in_saferoom", "0", "特感传送时是否允许传送到安全屋内", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hTransParentTeleport = CreateConVar("teleport_transparent", "1", "是否在特感传送前将其设置为透明，传送后恢复", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hEnableLog = CreateConVar("teleport_log_level", "1", "插件日志记录级别 (1: 禁用, 2: DEBUG, 4: INFO, 8: MESSAGE, 16: SERVER, 32: ERROR) 数字相加", CVAR_FLAG, true, 0.0, true, 1.0);

	log = new Logger(g_hEnableLog.IntValue);

	// offset
	offset = intAbs(g_hMaxNavDistance.IntValue - g_hMaxDistance.IntValue);
	// cvar change hook
	g_hAllowInfetedClass.AddChangeHook(allowedInfectedClassChangedHandler);
	g_hMaxDistance.AddChangeHook(offsetChangedHandler);
	g_hMaxNavDistance.AddChangeHook(offsetChangedHandler);
	// event hook
	HookEvent("round_start", roundStartHandler);
	getAllowedTeleportInfected();

	// 插件延迟加载
	if (pluginLateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i)) {
				continue;
			}
			OnClientPutInServer(i);
		}
		RequestFrame(nextFrameOnPluginStart);
	}
}

void nextFrameOnPluginStart() {
	onSurvivorLeftSafeArea();
}

public void OnAllPluginsLoaded() {
	if (!LibraryExists("left4dhooks")) {
		LogMessage("\n==========\n本插件需要前置插件 \"[L4D & L4D2] Left 4 DHooks Direct\" 方可运行\n");
		SetFailState("\n==========\n本插件需要前置插件 \"[L4D & L4D2] Left 4 DHooks Direct\" 方可运行\n");
	}
}

public void OnMapStart()
{
	clearTeleportInfo();
}

public void allowedInfectedClassChangedHandler(ConVar convar, const char[] oldValue, const char[] newValue)
{
	getAllowedTeleportInfected();
}

public void offsetChangedHandler(ConVar convar, const char[] oldValue, const char[] newValue)
{
	offset = intAbs(g_hMaxNavDistance.IntValue - g_hMaxDistance.IntValue);
}

public void roundStartHandler(Event event, const char[] name, bool dontBroadcast)
{
	clearTeleportInfo();
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDK_HOOK_TYPE, sdkHookThinkCallback);
	if (client > 0 && client <= MaxClients && teleportInfecteds[client] == null) {
		teleportInfecteds[client] = new ArrayList();
	} else {
		teleportInfecteds[client].Clear();
	}
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	onSurvivorLeftSafeArea();
	return Plugin_Continue;
}

/*
 * @Description: 特感是否需要传送检查时钟回调函数
 * @param: {timer} 时钟句柄
 * @return: {Action} 
 */
public Action checkInfectedCanBeTeleportHandler(Handle timer)
{
	static int
				i,
				target;
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_INFECTED || !IsPlayerAlive(i) || IsInGhostState(i)) {
			continue;
		}

		target = getTargetSurvivor(i);
		if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) {
			continue;
		}
		if (!canBeTeleport(i, target)) {
			teleportCheckTime[i] = 0;
			continue;
		}
		// 检查通过，增加传送次数
		teleportCheckTime[i]++;
		if (teleportCheckTime[i] > g_hCheckTime.IntValue) {
			canFindTeleportPos[target] = true;
			// 当前特感 UserId 不在目标的传送集合中，则添加
			int userId = GetClientUserId(i);
			if (teleportInfecteds[target].FindValue(userId) < 0) {
				teleportInfecteds[target].Push(userId);
			}
		}
		canFindTeleportPos[target] = canFindTeleportPos[target] ? true : false;
	}
	return Plugin_Continue;
}

/*
 * @Description: 生还者 SDKHook 回调函数
 * @param: {client} 目标生还者
 * @return: {void}
 */
void sdkHookThinkCallback(int client)
{
	// 插件未开启或不允许找位，返回
	if (!g_hEnable.BoolValue || !canFindTeleportPos[client] || GetGameTime() - resetFindPosTime[client] < FIND_POS_DELAY) {
		return;
	}
	if (!IsPlayerAlive(client)) {
		return;
	}
	// 这个生还者的待传送特感集合中没有特感，返回
	if (teleportInfecteds[client].Length < 1)
	{
		if (expandFrame[client][0] > 0) {
			expandFrame[client][0] = expandFrame[client][1] = 0;
		}
		return;
	}
	// 可以传送
	static float
			selfPos[3],
			leftFront[3],
			rightBack[3],
			rayStartPos[3],
			rayEndPos[3],
			navPos[3],
			visiblePos[3],
			vecDistance,
			navDistance;
	static int
			i,
			teleportInfected,
			currentHealth,
			maxHealth,
			healthRestore,
			renderColor[4];
	static DataPack
			pack;
	// 获取一个待传送的特感，判断是否有效
	teleportInfected = GetClientOfUserId(teleportInfecteds[client].Get(0));
	if (!IsValidInfected(teleportInfected) || !IsPlayerAlive(teleportInfected))
	{
		teleportInfecteds[client].Erase(0);
		teleportInfected = INVALID_CLIENT;
		return;
	}
	// 待传送的特感有效
	GetClientAbsOrigin(client, selfPos);
	CopyVectors(selfPos, leftFront);
	CopyVectors(selfPos, rightBack);
	// 计算网格边界
	leftFront[0] -= g_hMaxDistance.FloatValue;
	leftFront[1] -= g_hMaxDistance.FloatValue;
	rightBack[0] += g_hMaxDistance.FloatValue;
	rightBack[1] += g_hMaxDistance.FloatValue;
	// 未超出开始拓展限制范围且帧数小于拓展限制帧数，拓展帧数增加
	if (expandFrame[client][0] < g_hExpandFrame.IntValue && expandFrame[client][1] < offset) {
		expandFrame[client][0]++;
	} else if (expandFrame[client][0] >= g_hExpandFrame.IntValue && expandFrame[client][1] < offset) {
		// 增加距离时拓展帧数不变
		expandFrame[client][1] += expandFrame[client][1] < offset ? EXPAND_COUNT_PRE_FRAME : 0;
		leftFront[0] -= expandFrame[client][1];
		leftFront[1] -= expandFrame[client][1];
		rightBack[0] += expandFrame[client][1];
		rightBack[1] += expandFrame[client][1];
	} else if (expandFrame[client][1] >= offset) {
		// 网格拓展到最大限度，且超过 2s 有特感未刷出，则清空传送集合，否则继续找位容易导致卡顿
		expandFrame[client][0]++;
		if (expandFrame[client][0] > 2 * GetServerTickRate() + g_hExpandFrame.IntValue && teleportInfecteds[client].Length > 0)
		{
			log.info("%s: 找位超出限制范围, 暂时停止, 将在 %.1f 秒后重新开始", PLUGIN_PREFIX, FIND_POS_DELAY);
			expandFrame[client][0] = expandFrame[client][1] = 0;
			teleportInfecteds[client].Clear();
			canFindTeleportPos[client] = false;
			resetFindPosTime[client] = GetGameTime();
		}
		return;
	}
	// 循环 tickrace 次，获取随机射线起始位置
	for(i = 0; i < GetServerTickRate(); i++) {
		rayStartPos[0] = GetRandomFloatInRange(leftFront[0], rightBack[0]);
		rayStartPos[1] = GetRandomFloatInRange(leftFront[1], rightBack[1]);
		rayStartPos[2] = GetRandomFloatInRange(selfPos[2], selfPos[2] + g_hMaxDistance.FloatValue);
		// 发射射线
		TR_TraceRay(rayStartPos, RAY_DOWN_ANGLE, MASK_PLAYERSOLID, RayType_Infinite);
		if (!TR_DidHit()) {
			continue;
		}
		TR_GetEndPosition(rayEndPos);

		CopyVectors(rayEndPos, navPos);
		CopyVectors(rayEndPos, visiblePos);
		navPos[2] += NAV_HEIGHT;
		visiblePos[2] += PLAYER_HEIGHT;
		// 检查射线中止位置是否有效
		static Address rayEndNav;
		rayEndNav = isValidNavArea(navPos);
		if (rayEndNav != Address_Null && 
			!isPlayerStuck(rayEndPos) && 
			!isVisibleTo(visiblePos) && 
			L4D2_NavAreaBuildPath(L4D2Direct_GetTerrorNavArea(navPos), L4D2Direct_GetTerrorNavArea(selfPos), g_hMaxNavDistance.FloatValue, TEAM_INFECTED, false)) {
			// rayEndPos[2] 等于目标 z 坐标判断直线距离
			rayEndPos[2] = selfPos[2];
			vecDistance = GetVectorDistance(rayEndPos, selfPos);
			navDistance = L4D2_NavAreaTravelDistance(rayEndPos, selfPos, false);

			if (vecDistance < g_hMinDistance.FloatValue || vecDistance > g_hMaxDistance.FloatValue || navDistance == -1.0 || navDistance < g_hMinDistance.FloatValue || navDistance > g_hMaxNavDistance.FloatValue) {
				continue;
			}
			// 传送的位置在目标生还者后面则跳过本次循环
			if (g_hShouldAhead.BoolValue && !isPosAheadTarget(navPos, selfPos)) {
				continue;
			}
			// 传送位置在安全区域内则跳过本次循环
			if (g_hAllowInSaferoom.BoolValue && L4D_GetNavArea_SpawnAttributes(rayEndNav) & NAV_SPAWN_CHECKPOINT) {
				continue;
			}
			log.info("%s: 即将传送特感 %N 到目标 %N 旁, 检测 %d 次", PLUGIN_PREFIX, teleportInfected, client, teleportCheckTime[teleportInfected]);
			if (!IsValidInfected(teleportInfected) || !IsPlayerAlive(teleportInfected)) {
				teleportInfecteds[client].Erase(0);
				teleportInfected = INVALID_CLIENT;
				break;
			}
			// 当前特感不允许被传送，传送检测设置为 0 并跳出
			if (!canBeTeleport(teleportInfected, client))
			{
				teleportCheckTime[teleportInfected] = 0;
				break;
			}
			navPos[2] -= 15.0;
			// 实体传送时是否设置透明，传送完成恢复
			if (g_hTransParentTeleport.BoolValue)
			{
				GetEntityRenderColor(teleportInfected, renderColor[0], renderColor[1], renderColor[2], renderColor[3]);
				SetEntityRenderColor(teleportInfected, renderColor[0], renderColor[1], renderColor[2], ALPHA_TRANSPARENT);
				pack = new DataPack();
				pack.Reset();
				pack.WriteCell(teleportInfected);
				pack.WriteFloatArray(navPos, sizeof(navPos));
				pack.WriteCellArray(renderColor, sizeof(renderColor));
				// 延迟一帧传送
				RequestFrame(nextFrameDoTeleportInfected, pack);
			}
			else
			{
				TeleportEntity(teleportInfected, navPos, NULL_VECTOR, NULL_VECTOR);
			}
			teleportInfecteds[client].Erase(0);
			log.info("%s: 即将传送落后特感 %N, 直线距离 %.1f, Nav 距离 %.1f, 检测 %d 次", PLUGIN_PREFIX, teleportInfected, vecDistance, navDistance, teleportCheckTime[teleportInfected]);
			teleportCheckTime[teleportInfected] = 0;
			// 传送回血
			if (g_hHealthRestore.BoolValue)
			{
				currentHealth = GetEntProp(teleportInfected, Prop_Data, "m_iHealth");
				maxHealth = GetEntProp(teleportInfected, Prop_Data, "m_iMaxHealth");
				if (currentHealth <= maxHealth)
				{
					healthRestore = RoundToNearest((maxHealth - currentHealth) * (g_hHealthRestore.FloatValue * 0.01));
					log.info("%s: 传送特感 %N, 并回复 %d 点血量 (Cur: %d / Max: %d / Restore: %d)", PLUGIN_PREFIX, teleportInfected, healthRestore, currentHealth, maxHealth, healthRestore);
					SetEntProp(teleportInfected, Prop_Data, "m_iHealth", currentHealth + healthRestore);
				}
			}
			break;
		}
		return;
	}
}

/*
 * @Description: 特感透明传送回调函数
 * @param: {pack} 数据包
 * @return: {void} 
 */
void nextFrameDoTeleportInfected(DataPack pack)
{
	if (pack == null) { return; }
	static int
				teleportInfected,
				renderColor[4];
	static float navPos[3];
	pack.Reset();
	teleportInfected = pack.ReadCell();
	pack.ReadFloatArray(navPos, sizeof(navPos));
	pack.ReadCellArray(renderColor, sizeof(renderColor));
	delete pack;
	if (!IsValidInfected(teleportInfected) || !IsPlayerAlive(teleportInfected)) { return; }
	TeleportEntity(teleportInfected, navPos, NULL_VECTOR, NULL_VECTOR);
	SetEntityRenderColor(teleportInfected, renderColor[0], renderColor[1], renderColor[2], renderColor[3]);
}

/*
 * @Description: 检查指定坐标是否在有效 Nav Area 上（Nav 地址不为 Address_Null）
 * @param: {pos} 需要检查的坐标
 * @return: {bool}
 */
static Address isValidNavArea(float pos[3])
{
	return L4D2Direct_GetTerrorNavArea(pos);
}

/*
 * @Description: 检查特定坐标是否会卡住客户端
 * @param: {pos} 特定坐标
 * @return: {bool}
 */
static bool isPlayerStuck(float pos[3])
{
	Handle trace = TR_TraceHullFilterEx(pos, pos, view_as<float>({-25.0, -25.0, 0.0}), view_as<float>({25.0, 25.0, PLAYER_HEIGHT}), MASK_PLAYERSOLID, traceRayFilter);
	if (trace == null) { return false; }
	if (!TR_DidHit(trace))
	{
		delete trace;
		return true;
	}
	delete trace;
	return false;
}

/*
 * @Description: 检查 pos 坐标路程是否高于 targetPos 坐标
 * @param: {pos} 需要检查的坐标
 * @param: {targetPos} 目标坐标
 * @return: {bool}
 */
static bool isPosAheadTarget(float pos[3], float targetPos[3])
{
	Address
		posNav,
		targetPosNav;
	posNav = L4D2Direct_GetTerrorNavArea(pos);
	targetPosNav = L4D2Direct_GetTerrorNavArea(targetPos);
	if (posNav == Address_Null) { posNav = L4D_GetNearestNavArea(pos); }
	if (targetPosNav == Address_Null) { targetPosNav = L4D_GetNearestNavArea(targetPos); }
	return L4D2Direct_GetTerrorNavAreaFlow(posNav) > L4D2Direct_GetTerrorNavAreaFlow(targetPosNav);
}

/*
 * @Description: 生还者是否可视某个坐标
 * @param: {pos} 特定坐标
 * @return: {bool}
 */
static bool isVisibleTo(float pos[3])
{
	static int i;
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) { continue; }
		if (g_hIgnoreIncap.BoolValue && IsClientIncapped(i)) { continue; }
		if (L4D2_IsVisibleToPlayer(i, TEAM_SURVIVOR, TEAM_INFECTED, 0, pos)) { return true; }
	}
	return false;
}

static bool traceRayFilter(int entity, int contentsMask, any data)
{
	// 射线撞击到自身或客户端实体，不允许穿过
	if (entity == data || (entity >= 1 && entity <= MaxClients)) { return false; }
	// 撞击到其他实体，检测类型
	static char className[64];
	GetEntityClassname(entity, className, sizeof(className));
	if (checkRayImpactEntityValid(className)) { return false; }
	// blocker 类型的，获取是否阻塞与阻塞类型
	if (strcmp(className, "env_physics_blocker") == 0 || strcmp(className, "env_player_blocker") == 0)
	{
		if (!HasEntProp(entity, Prop_Send, "m_bBlocked")) { return false; }
		if (GetEntProp(entity, Prop_Send, "m_bBlocked") != 1) { return true; }
		static int blockType;
		blockType = GetEntProp(entity, Prop_Send, "m_nBlockType");
		return (blockType == BLOCK_TYPE_SURVIVORS || blockType == BLOCK_TYPE_PLAYER_INFECTED);
	}
	return true;
}

/*
 * @Description: 检查射线撞击的实体是否在 validEntityName 中
 * @param: {className} 实体名称
 * @return: {bool} 在返回 true，否则返回 false
 */
static bool checkRayImpactEntityValid(const char[] className)
{
	static int i;
	for (i = 0; i < sizeof(validEntityName); i++)
	{
		if (strcmp(className, validEntityName[i]) == 0) { return false; }
	}
	return true;
}

/*
 * @Description: 根据目标选择策略获取某个特感的目标生还者
 * @param: {infected} 目标特感
 * @return: {int} 目标客户端
 */
static int getTargetSurvivor(int infected)
{
	if (!IsValidInfected(infected) || !IsPlayerAlive(infected)) { return INVALID_CLIENT; }
	switch(g_hTargetType.IntValue)
	{
		case TARGET_CLOSEST: { return getClosestSurvivor(infected); }
		case TARGET_HIGHEST_FLOW: { return getFlowSurvivor(false); }
		case TARGET_LOWEST_FLOW: { return getFlowSurvivor(true); }
		case TARGET_RANDOM: { return GetRandomSurvivorAndValid(INVALID_CLIENT, true); }
		default: { return INVALID_CLIENT; }
	}
}

/*
 * @Description: 获取距离特定感染者最近的未死亡未倒地的生还者
 * @param: {infected} 特定感染者
 * @return: {int} 生还者客户端 ID
 */
int getClosestSurvivor(int infected)
{
	if (!IsValidInfected(infected) || !IsPlayerAlive(infected)) { return INVALID_CLIENT; }
	static float
				selfPos[3],
				targetPos[3];
	static int i;
	static ArrayList targetList;
	targetList = new ArrayList(2);
	for (i = 1; i <= MaxClients; i++)
	{
		if (i == infected || !IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i) || IsClientIncapped(i) || IsClientPinned(i)) { continue; }
		GetClientAbsOrigin(infected, selfPos);
		GetEntPropVector(i, Prop_Send, "m_vecOrigin", targetPos);
		targetList.Set(targetList.Push(GetVectorDistance(selfPos, targetPos)), i, 1, false);
	}
	if (targetList.Length == 0)
	{
		delete targetList;
		return INVALID_CLIENT;
	}
	targetList.Sort(Sort_Ascending, Sort_Float);
	i = targetList.Get(0, 1);
	delete targetList;
	return i;
}

/*
 * @Description: 根据 mode 获取路程最高或路程最低的生还者
 * @param: {mode} 获取模式，true 为最低路程，false 为最高路程
 * @return: {int} 生还者客户端 ID
 */
static int getFlowSurvivor(bool mode)
{
	static int i;
	static float flow;
	static ArrayList flowList;
	flowList = new ArrayList(2);
	for(i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i) || IsClientIncapped(i) || IsClientPinned(i)) { continue; }
		flow = L4D2Direct_GetFlowDistance(i);
		if (flow && flow != -9999.0 && flow != 9999.0) { flowList.Set(flowList.Push(flow), i, 1); }
	}
	if (flowList.Length == 0)
	{
		delete flowList;
		return INVALID_CLIENT;
	}
	switch (mode)
	{
		case true: { flowList.Sort(Sort_Ascending, Sort_Float); }
		case false: { flowList.Sort(Sort_Descending, Sort_Float); }
	}
	i = flowList.Get(0, 1);
	delete flowList;
	return i;
}

void clearTeleportInfo()
{
	delete teleportCheckTimer;
	static int i;
	for (i = 1; i <= MaxClients; i++)
	{
		canFindTeleportPos[i] = false;
		teleportCheckTime[i] = 0;
		teleportCount[i] = 0;
		resetFindPosTime[i] = GetGameTime();
		if (teleportInfecteds[i] == null) { continue; }
		teleportInfecteds[i].Clear();
	}
}

/*
 * @Description: 根据 Cvar 值获取可以被传送的特感类型
 * @param: {} 
 * @return: {void} 
 */
void getAllowedTeleportInfected()
{
	static char
			cvarString[16],
			tempString[8][4];
	g_hAllowInfetedClass.GetString(cvarString, sizeof(cvarString));
	ExplodeString(cvarString, ",", tempString, sizeof(tempString), sizeof(tempString[]));
	static int i;
	for (i = 0; i < sizeof(tempString); i++)
	{
		allowedTeleportInfected[StringToInt(tempString[i])] = true;
	}
}

void onSurvivorLeftSafeArea()
{
	delete teleportCheckTimer;
	teleportCheckTimer = CreateTimer(g_hCheckInterval.FloatValue, checkInfectedCanBeTeleportHandler, _, TIMER_REPEAT);
}

/*
 * @Description: 判断特感是否可以被传送
 * @param: {client} 需要被判断的特感
 * @param: {target} 当前特感的目标
 * @return: {bool} 
 */
static bool canBeTeleport(int client, int target)
{
	// 不是有效特感，不允许传送
	if (!IsValidInfected(client) || IsInGhostState(client) || !IsPlayerAlive(client)) { return false; }
	// 当前特感不在地上或正在控人，不允许传送
	if (!IsClientOnGround(client) || IsPinningSurvivor(client)) { return false; }
	// 当前特感类型不允许传送
	if (!allowedTeleportInfected[GetEntProp(client, Prop_Send, "m_zombieClass")]) { return false; }
	// 最大允许传送次数不为 -1，且当前特感达到最大允许传送次数，不允许传送
	if (g_hMaxTeleportCount.IntValue > -1 && teleportCount[client] > g_hMaxTeleportCount.IntValue) { return false; }
	// 当前特感目标无效，不允许传送
	if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) { return false; }
	// 当前特感直线距离小于允许传送距离，且速度大于允许传送速度，不允许传送
	static float
				selfPos[3],
				selfEyePos[3],
				targetPos[3];
	GetClientAbsOrigin(client, selfPos);
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPos);
	if (GetVectorDistance(selfPos, targetPos) < g_hTeleportDistance.FloatValue && GetClientCurrentSpeed(client) > g_hAllowTeleportSpeed.FloatValue) { return false; }
	// 当前特感可以被生还者看见，不允许传送
	GetClientEyePosition(client, selfEyePos);
	if (isVisibleTo(selfEyePos)) { return false; }
	return true;
}

/*
 * @Description: 获取一个整数的绝对值 
 * @param: {digit} 输入的整数 
 * @return: {int} 输入的整数的绝对值 
 */
int intAbs(int digit)
{
	return digit > 0 ? digit : -digit;
}