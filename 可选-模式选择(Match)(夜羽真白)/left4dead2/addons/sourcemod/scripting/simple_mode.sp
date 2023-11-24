/**
 * @Author 夜羽真白
 * @Date 2023-06-11 00:26:22
 * @Description 模式选择 & 模式投票
 * @Version 1.0.0.0
 * @GitHub https://github.com/GlowingTree880/L4D2_LittlePlugins
 **/

#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <builtinvotes>
#include <logger>
#include "treeutil/treeutil.sp"

#define MODULE_PREFIX "SimpleMode"

#define CVAR_FLAG FCVAR_NOTIFY

#define CFG_PATH "../../cfg"
#define PERM_DIR 777
#define MAX_CONFIG_COUNT 32
#define MAP_RESTART_TIME 3.0

ConVar
	g_hModeConfig,
	g_hModeDir,
	g_hAutoLoadConfig,
	g_hAutoCreateConfig,
	g_hMatchStartConfig,
	g_hMatchStartOnceConfig,
	g_hMatchEndConfig,
	g_hRestartMap,
	g_hLogging;
ConVar
	g_hAllBotGame,
	g_hIsReloaded,
	g_hChangedMap,
	g_hModeName;

Logger
	log;

bool
	// 模式是否激活，加载模式时为 true
	isModeActive,
	// 模式是否加载完毕，第一次加载完配置且重启地图后为 true
	isModeLoaded,
	// 模式的只加载一次的配置是否加载完毕，由插件自动控制
	isModePluginLoaded,
	// 当前地图是否重启过
	isMapRestarted;

char
	modeFilePath[PLATFORM_MAX_PATH],
	modeDirPath[PLATFORM_MAX_PATH],
	thisPluginName[PLATFORM_MAX_PATH];

Handle
	fwdMatchLoaded,
	fwdMatchUnloaded;

enum {
	RESTART_NONE,
	RESTART_START,
	RESTART_END,
	RESTART_BOTH
}

public Plugin myinfo =
{
	name		= "Simple Mode Manager",
	author		= "夜羽真白",
	description = "模式选择及模式投票",
	version		= "1.0.0.0",
	url			= "https://steamcommunity.com/id/saku_ra/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion version = GetEngineVersion();
	if (version != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "[不支持的游戏]：此插件仅支持 Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	fwdMatchLoaded = CreateGlobalForward("LGO_OnMatchModeLoaded", ET_Ignore);
	fwdMatchUnloaded = CreateGlobalForward("LGO_OnMatchModeUnloaded", ET_Ignore);
	CreateNative("LGO_IsMatchModeLoaded", native_IsMatchModeLoaded);
	return APLRes_Success;
}

// 模式投票模块
#include "simple_mode_vote/simple_mode_vote.sp"

public void OnPluginStart()
{
	g_hModeConfig = CreateConVar("simple_mode_config_path", "configs/match_modes.cfg", "模式选择文件所在目录", CVAR_FLAG);
	g_hModeDir = CreateConVar("simple_mode_dir_path", "../../cfg/cfgogl", "模式配置文件目录", CVAR_FLAG);
	g_hLogging = CreateConVar("simple_mode_enable_logging", "1", "是否开启插件日志记录", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAutoLoadConfig = CreateConVar("simple_mode_autoload_config", "", "玩家连接时默认加载哪个模式的配置文件, 为空则不默认加载模式", CVAR_FLAG);
	g_hAutoCreateConfig = CreateConVar("simple_mode_autocreate_config", "confogl.cfg;confogl_plugins.cfg;confogl_off.cfg;shared_plugins.cfg;shared_settings.cfg;shared_cvars.cfg", "创建新模式时默认创建哪些配置文件, 为空则不默认创建（; 分割）", CVAR_FLAG);
	g_hMatchStartOnceConfig = CreateConVar("simple_mode_modestart_once_config", "generalfixes.cfg;confogl_plugins.cfg;sharedplugins.cfg", "每个模式加载时默认加载哪个配置文件（配置在这里的配置文件只会在每个模式加载时加载一次, 用于初始化模式，; 分割）", CVAR_FLAG);
	g_hMatchStartConfig = CreateConVar("simple_mode_modestart_config", "confogl.cfg", "每个模式加载时及每个地图加载时默认加载哪个配置文件", CVAR_FLAG);
	g_hMatchEndConfig = CreateConVar("simple_mode_modeend_config", "confogl_off.cfg", "每个模式卸载时加载哪个配置文件", CVAR_FLAG);
	g_hRestartMap = CreateConVar("simple_mode_restart_map", "3", "是否在模式加载完成及卸载完成后重启地图, 0:不重启, 1:模式加载完成后重启, 2:模式卸载完成后重启, 3:加载完成及卸载完成后重启", CVAR_FLAG, true, view_as<float>(RESTART_START), true, view_as<float>(RESTART_BOTH));
	g_hAllBotGame = FindConVar("sb_all_bot_game");
	
	g_hIsReloaded = FindConVar("simple_mode_is_reloaded");
	if (g_hIsReloaded == null) {
		g_hIsReloaded = CreateConVar("simple_mode_is_reloaded", "0", "无需更改这个 CVAR, 由插件自动更改", CVAR_FLAG | FCVAR_DONTRECORD | FCVAR_UNLOGGED, true, 0.0, true, 1.0);
	}
	g_hChangedMap = FindConVar("simple_mode_changed_map");
	if (g_hChangedMap == null) {
		g_hChangedMap = CreateConVar("simple_mode_changed_map", "", "无需更改这个 CVAR, 由插件自动更改", CVAR_FLAG | FCVAR_DONTRECORD | FCVAR_UNLOGGED);
	}
	g_hModeName = FindConVar("simple_mode_name");
	if (g_hModeName == null) {
		g_hModeName = CreateConVar("simple_mode_name", "", "无需更改这个 CVAR, 由插件自动更改", CVAR_FLAG | FCVAR_DONTRECORD | FCVAR_UNLOGGED);
	}

	// 挂钩 cvar 变动
	g_hModeConfig.AddChangeHook(configPathChangeHook);
	g_hModeDir.AddChangeHook(configPathChangeHook);
	// 获取模式配置文件路径
	g_hModeConfig.GetString(modeFilePath, sizeof(modeFilePath));
	g_hModeDir.GetString(modeDirPath, sizeof(modeDirPath));
	// 注册指令
	RegAdminCmd("sm_forcematch", forceMatchCmdHandler, ADMFLAG_CONFIG, "强制开始新的模式");
	RegAdminCmd("sm_fm", forceMatchCmdHandler, ADMFLAG_CONFIG, "强制开始新的模式");
	RegAdminCmd("sm_resetmatch", resetMatchCmdHandler, ADMFLAG_CONFIG, "重置当前的模式回到默认模式");
	RegAdminCmd("sm_addmode", addModeCmdHandler, ADMFLAG_CONFIG, "增加一个新的模式");
	RegAdminCmd("sm_delmode", deleteModeCmdHandler, ADMFLAG_CONFIG, "删除一个已有的模式");
	GetPluginFilename(null, thisPluginName, sizeof(thisPluginName));
	// 日志记录
	log = new Logger(g_hLogging.BoolValue);
	// 文件校验
	if (!validateFile()) {
		SetFailState("[%s]: 配置文件路径错误, 插件将不会正确加载, 请重新配置", MODULE_PREFIX);
	}

	char modeName[PLATFORM_MAX_PATH];
	if (g_hIsReloaded.BoolValue) {
		g_hModeName.GetString(modeName, sizeof(modeName));

		log.info("[%s]: 模式: %s 首次加载完成, 即将重启当前地图", MODULE_PREFIX, modeName);

		isModePluginLoaded = true;
		g_hIsReloaded.SetInt(0);
		doLoadMatchMode(modeName);
	} else {
		g_hAutoLoadConfig.GetString(modeName, sizeof(modeName));
		if (!IsNullString(modeName) && strlen(modeName) > 0) {
			log.info("[%s]: 自动加载模式: %s", MODULE_PREFIX, modeName);
			doLoadMatchMode(modeName);
		}
	}

	voteModulePluginStart();
}

public void configPathChangeHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_hModeConfig.GetString(modeFilePath, sizeof(modeFilePath));
	g_hModeDir.GetString(modeDirPath, sizeof(modeDirPath));
}

/**
* 增加模式指令 !addmode 处理函数
* @param client 指令发起者
* @param args 指令参数
* @return Action
**/
public Action addModeCmdHandler(int client, int args)
{
	// 玩家无效
	if (client == 0) {
		PrintToServer("[%s]: 新增模式指令不能于服务器控制台使用", MODULE_PREFIX);
		return Plugin_Handled;
	}
	if (!IsValidClient(client) || IsFakeClient(client)) {
		return Plugin_Handled;
	}
	// 非法参数
	if (args != 1) {
		CPrintToChat(client, "{B}[{W}%s{B}]: {G}请使用: {O}!addmode *模式名称* {G}来添加一个模式", MODULE_PREFIX);
		return Plugin_Handled;
	}

	char cmdModeName[PLATFORM_MAX_PATH];
	GetCmdArgString(cmdModeName, sizeof(cmdModeName));
	// 创建对应模式文件夹
	char tempPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, tempPath, sizeof(tempPath), "%s/%s", modeDirPath, cmdModeName);
	if (DirExists(tempPath)) {
		CPrintToChat(client, "{B}[{W}%s{B}]: {G}模式目录: {O}%s {G}已经存在, 创建失败", MODULE_PREFIX, tempPath);
		return Plugin_Handled;
	}

	if (!CreateDirectory(tempPath, PERM_DIR)) {
		log.error("[%s]: 无法为模式: %s 创建目录: %s", MODULE_PREFIX, cmdModeName, tempPath);
		CPrintToChat(client, "{B}[{W}%s{B}]: {G}模式目录: {O}%s {G}创建失败, 请手动创建", MODULE_PREFIX, tempPath);
		return Plugin_Continue;
	}
	createCustomConfigFile(cmdModeName);
	CPrintToChat(client, "{B}[{W}%s{B}]: {G}模式: {O}%s {G}配置文件创建完成", MODULE_PREFIX, cmdModeName);
	return Plugin_Continue;
}

/**
* 删除模式指令 !delmode 回调
* @param client 指令发起者
* @param args 指令参数
* @return Action
**/
public Action deleteModeCmdHandler(int client, int args) {
	// 玩家无效
	if (client == 0) {
		PrintToServer("{B}[{W}%s{B}]: {G}删除模式指令不能于服务器控制台使用", MODULE_PREFIX);
		return Plugin_Handled;
	}
	if (!IsValidClient(client) || IsFakeClient(client)) {
		return Plugin_Handled;
	}
	// 非法参数
	if (args != 1) {
		CPrintToChat(client, "{B}[{W}%s{B}]: {G}请使用: {O}!delmode *模式名称* {G}来删除一个模式", MODULE_PREFIX);
		return Plugin_Handled;
	}

	char modeName[PLATFORM_MAX_PATH], cmdModeName[PLATFORM_MAX_PATH];
	g_hModeName.GetString(modeName, sizeof(modeName));
	GetCmdArgString(cmdModeName, sizeof(cmdModeName));
	// 已加载模式
	if (isModeLoaded || isModeActive) {
		if (strlen(modeName) > 0 && strcmp(modeName, cmdModeName) == 0) {
			CPrintToChat(client, "{B}[{W}%s{B}]: {G}当前已经加载 %s 模式, 请先卸载模式再进行删除", modeName);
			return Plugin_Handled;
		}
	}

	char tempPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, tempPath, sizeof(tempPath), "%s/%s", modeDirPath, cmdModeName);
	if (!DirExists(tempPath)) {
		CPrintToChat(client, "{B}[{W}%s{B}]: {G}模式目录: {O}%s {G}不存在, 无法删除", MODULE_PREFIX, tempPath);
		return Plugin_Handled;
	}
	// 模式目录存在，删除里面所有文件最后删除目录
	DirectoryListing dirHandle = OpenDirectory(tempPath);
	if (dirHandle == null || !removeDir(dirHandle, tempPath)) {
		CPrintToChat(client, "{B}[{W}%s{B}]: {G}模式目录: {O}%s {G}删除失败, 请手动删除", MODULE_PREFIX, tempPath);
	}
	return Plugin_Continue;
}

/**
* 强制开始模式 !forcematch 指令处理函数
* @param client 指令发起者
* @param args 指令参数
* @return Action
**/
public Action forceMatchCmdHandler(int client, int args)
{
	if (client < 0 || client > MaxClients || (IsValidClient(client) && IsFakeClient(client))) {
		return Plugin_Handled;
	}

	char modeName[PLATFORM_MAX_PATH], tempPath[PLATFORM_MAX_PATH];
	g_hModeName.GetString(modeName, sizeof(modeName));
	// 模式已经加载则需要先卸载再重新加载新的模式
	// if (isModeLoaded) {
	// 	CPrintToChat(client, "{O}[%s]: {G}当前已经加载: {O}%s {G}模式, 请先卸载模式再重新加载新的模式", MODULE_PREFIX, modeName);
	// 	return Plugin_Handled;
	// }

	if (args < 1) {
		CPrintToChat(client, "{B}[{W}%s{B}]: {G}请使用 {O}!forcematch **模式名** {G}来指定加载模式", MODULE_PREFIX);
		return Plugin_Handled;
	}
	char cmdModeName[PLATFORM_MAX_PATH];
	GetCmdArg(1, cmdModeName, sizeof(cmdModeName));
	BuildPath(Path_SM, tempPath, sizeof(tempPath), "%s/%s", modeDirPath, cmdModeName);
	if (!DirExists(tempPath)) {
		if (IsValidClient(client)) {
			CPrintToChat(client, "{B}[{W}%s{B}]: {G}模式配置文件: {O}%s {G}不存在, 无法加载模式", MODULE_PREFIX, cmdModeName);
		} else {
			CPrintToChatAll("{B}[{W}%s{B}]: {G}模式配置文件: {O}%s {G}不存在, 无法加载模式", MODULE_PREFIX, cmdModeName);
		}

		log.info("[%s]: 模式配置文件: %s 不存在, 无法加载模式", MODULE_PREFIX, cmdModeName);
		return Plugin_Handled;
	}
	CPrintToChatAll("{B}[{W}%s{B}]: {G}准备加载: {O}%s {G}模式", MODULE_PREFIX, cmdModeName);

	char mapName[64], displayMapName[PLATFORM_MAX_PATH];
	if (args == 2) {
		GetCmdArg(2, mapName, sizeof(mapName));
		if (FindMap(mapName, displayMapName, sizeof(displayMapName)) == FindMap_NotFound) {
			if (IsValidClient(client)) {
				CPrintToChat(client, "{B}[{W}%s{B}]: {G}无法找到地图: {O}%s", MODULE_PREFIX, mapName);
			}
			
			log.info("[%s]: 无法找到地图: %s", MODULE_PREFIX, mapName);
			return Plugin_Handled;
		}
		GetMapDisplayName(displayMapName, displayMapName, sizeof(displayMapName));
		g_hChangedMap.SetString(displayMapName);
	}

	if (isModeLoaded) {
		log.info("[%s]: 当前已经加载: %s 模式, 准备加载: %s 模式, 正在卸载: %s 模式", MODULE_PREFIX, modeName, cmdModeName, modeName);
		CPrintToChatAll("{B}[{W}%s{B}]: {G}准备卸载当前: {O}%s {G}模式, 加载: {O}%s 模式", MODULE_PREFIX, modeName, cmdModeName);
		doUnloadMatchMode(true);
	}

	doLoadMatchMode(cmdModeName);
	return Plugin_Continue;
}

/**
* 重启模式指令 !resetmatch 处理函数
* @param client 指令发起者
* @param args 指令参数
* @return Action
**/
public Action resetMatchCmdHandler(int client, int args)
{
	if (client < 0 || client > MaxClients || (IsValidClient(client) && IsFakeClient(client))) {
		return Plugin_Handled;
	}

	if (!isModeLoaded) {
		CPrintToChat(client, "{B}[{W}%s{B}]: {G}当前未加载任何配置模式", MODULE_PREFIX);
		return Plugin_Handled;
	}
	doUnloadMatchMode(true);
	return Plugin_Continue;
}

public void OnMapStart() {
	if (!isModeLoaded) {
		return;
	}
	char curMapName[64], modeName[PLATFORM_MAX_PATH];
	GetCurrentMap(curMapName, sizeof(curMapName));
	g_hModeName.GetString(modeName, sizeof(modeName));
	if (!IsNullString(modeName)) {
		log.info("[%s]: 切换至地图: %s 重新加载当前模式: %s 配置文件", MODULE_PREFIX, curMapName, modeName);
	} else {
		log.info("[%s]: 切换至地图: %s 没有加载任何模式", MODULE_PREFIX, curMapName);
	}
	
	doLoadMatchMode(modeName);
}

/**
* 玩家进入服务器
* @param client 客户端索引
* @return void
**/
public void OnClientPutInServer(int client)
{
	if (client < 0 || client > MaxClients || IsFakeClient(client)) {
		return;
	}

	char config[PLATFORM_MAX_PATH];
	g_hAutoLoadConfig.GetString(config, sizeof(config));
	if (IsNullString(config) || strlen(config) == 0 || isModeActive) {
		return;
	}

	doLoadMatchMode(config);
}

/**
* 加载模式配置文件
* @param modeName 模式名称
* @return void
**/
static void doLoadMatchMode(const char[] modeName)
{
	if (!isModeActive) {
		isModeActive = true;
	}
	g_hAllBotGame.SetInt(1);
	log.info("[%s]: 准备加载 %s 模式", MODULE_PREFIX, modeName);

	char config[PLATFORM_MAX_PATH];

	// 第一次换模式，每个模式的默认加载一次的配置未加载
	if (!isModePluginLoaded) {
		log.info("[%s]: 第一次更换 %s 模式, 准备加载 MatchStartOnceConfig", MODULE_PREFIX, modeName);
		// 设置插件重载的 CVAR 为 1
		g_hIsReloaded.SetInt(1);
		// 设置需要加载的模式名称
		g_hModeName.SetString(modeName);

		int count, i;
		char configBuffer[MAX_CONFIG_COUNT][PLATFORM_MAX_PATH];
		g_hMatchStartOnceConfig.GetString(config, sizeof(config));
		count = ExplodeString(config, ";", configBuffer, MAX_CONFIG_COUNT, PLATFORM_MAX_PATH);

		log.info("[%s]: 正在卸载当前所有插件 (包括自身: %s)...", MODULE_PREFIX, thisPluginName);
		ServerCommand("sm plugins load_unlock");
		unloadAllPlugins(true);

		// 先从模式文件夹中加载 g_hMatchStartOnceConfig 的配置，如果没有就从 cfg 文件夹下加载
		for (i = 0; i < count; i++) {
			execModeCfgThenDefault(modeName, configBuffer[i]);
		}
		return;
	}

	g_hModeName.GetString(config, sizeof(config));
	log.info("[%s]: 当前不是第一次更换 %s 模式, 可能是重启地图或换图调用 doLoadMatchMode 函数", MODULE_PREFIX, config);
	// 不是第一次换模式，可能是换图，触发这个函数，只需要加载 g_hMatchStartConfig 配置即可 ../../cfg/cfgogl/模式名称/confogl.cfg
	g_hMatchStartConfig.GetString(config, sizeof(config));
	execModeCfgThenDefault(modeName, config);

	// 如果模式已经加载，则直接返回，不进行以下重启地图等操作
	if (isModeLoaded) {
		return;
	}

	isModeLoaded = true;
	CPrintToChatAll("{B}[{W}%s{B}]: {G}正在加载: {O}%s {G}模式", MODULE_PREFIX, modeName);

	if (!isMapRestarted && (g_hRestartMap.IntValue == RESTART_START || g_hRestartMap.IntValue == RESTART_BOTH)) {
		// 如果在 forceMatch 命令中指定地图，则加载到指定的地图
		char mapName[64];
		g_hChangedMap.GetString(mapName, sizeof(mapName));

		if (strlen(mapName) > 0) {
			CPrintToChatAll("{B}[{W}%s{B}]: {G}正在切换到地图: {O}%s", MODULE_PREFIX, mapName);
			g_hChangedMap.RestoreDefault();
		} else {
			GetCurrentMap(mapName, sizeof(mapName));
			CPrintToChatAll("{B}[{W}%s{B}]: {G}正在重启当前地图: {O}%s", MODULE_PREFIX, mapName);
		}
		DataPack pack = new DataPack();
		pack.Reset();
		pack.WriteString(mapName);
		CreateTimer(MAP_RESTART_TIME, mapRestartHandler, pack, _);
		log.info("[%s]: 模式: %s 加载完成，正在重启地图: %s", MODULE_PREFIX, modeName, mapName);
	}

	Call_StartForward(fwdMatchLoaded);
	Call_Finish();
}

/**
* 模式卸载
* @param force 是否强制卸载，强制卸载则不会检查服务器内是否有玩家
* @return void
**/
static void doUnloadMatchMode(bool force = false)
{
	bool hasPlayer = isPlayerInServer();
	char modeName[PLATFORM_MAX_PATH];
	g_hModeName.GetString(modeName, sizeof(modeName));

	if (!hasPlayer || force) {
		log.info("[%s]: 准备卸载当前模式: %s, 服务器内是否有玩家: %b, 是否强制卸载: %b", MODULE_PREFIX, modeName, hasPlayer, force);

		isModeActive = false;
		g_hAllBotGame.SetInt(0);
	}

	if (!force && hasPlayer) {
		log.info("[%s]: 当前服务器内有玩家或非强制卸载, 不会加载模式卸载 cfg", MODULE_PREFIX);
		return;
	}
	log.info("[%s]: 正在卸载当前模式: %s", MODULE_PREFIX, modeName);

	isModeLoaded = isMapRestarted = isModePluginLoaded = false;
	Call_StartForward(fwdMatchUnloaded);
	Call_Finish();
	CPrintToChatAll("{B}[{W}%s{B}]: {G}模式: {O}%s {G}已经卸载", MODULE_PREFIX, modeName);

	ServerCommand("sm plugins load_unlock");

	// 卸载模式，加载 ../../cfg/模式名称/confogl_off.cfg 配置
	char config[PLATFORM_MAX_PATH];
	g_hMatchEndConfig.GetString(config, sizeof(config));
	execModeCfgThenDefault(modeName, config);
	g_hModeName.RestoreDefault();

	// 重启地图
	if (g_hRestartMap.IntValue == RESTART_END || g_hRestartMap.IntValue == RESTART_BOTH) {
		char mapName[64];
		GetCurrentMap(mapName, sizeof(mapName));
		CPrintToChatAll("{B}[{W}%s{B}]: {G}正在重启当前地图: {O}%s", MODULE_PREFIX, mapName);

		DataPack pack = new DataPack();
		pack.Reset();
		pack.WriteString(mapName);
		CreateTimer(MAP_RESTART_TIME, mapRestartHandler, pack, _);
		log.info("[%s]: 正在重启地图: %s", MODULE_PREFIX, mapName);
	}
}

/**
* 地图重启时钟回调
* @param timer 时钟句柄
* @param mapName 地图名称
* @return Action
**/
public Action mapRestartHandler(Handle timer, DataPack pack)
{
	if (pack == null) {
		return Plugin_Stop;
	}

	ServerCommand("sm plugins load_lock");

	char mapName[64];
	pack.Reset();
	pack.ReadString(mapName, sizeof(mapName));
	delete pack;

	ServerCommand("changelevel %s", mapName);
	isMapRestarted = true;
	return Plugin_Stop;
}

/**
* 校验模式配置文件与模式配置文件夹是否有效
* @param void
* @return bool 有效返回 true，无效返回 false，插件报错退出
**/
bool validateFile()
{
	char filePath[PLATFORM_MAX_PATH], dirPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "%s", modeFilePath);
	BuildPath(Path_SM, dirPath, sizeof(dirPath), "%s", modeDirPath);

	if (!FileExists(filePath)) {
		log.info("[%s]: 模式配置文件路径: %s 无效, 尝试自动创建文件", MODULE_PREFIX, filePath);
		if (OpenFile(filePath, "w+") == null) {
			log.error("[%s]: 自动创建模式配置文件: %s 失败, 请手动创建", MODULE_PREFIX, filePath);
			return false;
		}
	}
	if (!DirExists(dirPath)) {
		log.info("[%s]: 模式目录路径: %s 无效, 尝试自动创建目录", MODULE_PREFIX, dirPath);
		if (!CreateDirectory(dirPath, PERM_DIR)) {
			log.error("[%s]: 自动创建模式目录: %s 失败, 请手动创建", MODULE_PREFIX, dirPath);
			return false;
		}
	}
	return true;
}

/**
* 创建自定义模式的配置文件，根据 g_hAutoCreateConfig 的值来确定创建什么配置文件
* @param modeName 模式名称
* @return void
**/
void createCustomConfigFile(const char[] modeName)
{
	char config[PLATFORM_MAX_PATH];
	g_hAutoCreateConfig.GetString(config, sizeof(config));
	if (IsNullString(config) || strlen(config) == 0) {
		return;
	}

	Handle file;
	int count, successCount, failCount;
	char configBuffer[MAX_CONFIG_COUNT][PLATFORM_MAX_PATH];
	count = ExplodeString(config, ";", configBuffer, MAX_CONFIG_COUNT, PLATFORM_MAX_PATH);

	for (int i = 0; i < MAX_CONFIG_COUNT; i++) {
		if (configBuffer[i][0] == '\0') {
			continue;
		}
		// ../../cfg/cfgogl/模式名/shared_plugins.cfg
		BuildPath(Path_SM, config, sizeof(config), "%s/%s/%s", modeDirPath, modeName, configBuffer[i]);
		if (FileExists(config)) {
			log.info("[%s]: 模式: %s 配置文件：%s 已经存在, 不再重复创建", MODULE_PREFIX, modeName, configBuffer[i]);
			continue;
		}
		if ((file = OpenFile(config, "w+")) == null) {
			log.error("[%s]: 创建模式: %s 配置文件: %s 失败, 请手动创建", MODULE_PREFIX, modeName, config);
			failCount++;
			continue;
		}
		log.info("[%s]: 成功创建模式: %s 配置文件: %s", MODULE_PREFIX, modeName, configBuffer[i]);
		successCount++;
		delete file;
		file = null;
	}
	log.info("[%s]: 创建模式: %s 配置文件完成, 共: %d 个, 成功: %d 个, 失败: %d 个, 如有无法创建的配置文件, 请手动创建", MODULE_PREFIX, modeName, count, successCount, failCount);
}

/**
* 遍历所有插件使用 sm plugins unload 卸载
* @param includeSelf 是否连同本插件一起卸载
* @return void
**/
public void unloadAllPlugins(bool includeSelf)
{
	char pluginName[PLATFORM_MAX_PATH];
	Handle 
		it = GetPluginIterator(),
		currentPlugin;
	ArrayList pluginNameList = new ArrayList(PLATFORM_MAX_PATH);

	while (MorePlugins(it)) {
		currentPlugin = ReadPlugin(it);
		GetPluginFilename(currentPlugin, pluginName, sizeof(pluginName));
		if (!includeSelf && strcmp(pluginName, thisPluginName) == 0) {
			continue;
		}
		pluginNameList.PushString(pluginName);
		delete currentPlugin;
	}
	delete it;

	ServerCommand("sm plugins load_unlock");

	for (int i = pluginNameList.Length - 1; i >= 0; i--) {
		pluginNameList.GetString(i, pluginName, sizeof(pluginName));
		ServerCommand("sm plugins unload %s", pluginName);
	}

	CreateTimer(0.1, refreshPluginHandler);
}

public Action refreshPluginHandler(Handle timer)
{
	ServerCommand("sm plugins refresh");
	return Plugin_Stop;
}

/**
* 检查服务器内是否有真人玩家
* @param void
* @return bool 有人时返回 true，否则返回 false
**/
static bool isPlayerInServer()
{
	static int i;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || IsFakeClient(i)) {
			continue;
		}
		return true;
	}
	return false;
}

public int native_IsMatchModeLoaded(Handle plugin, int numParams)
{
	return isModeLoaded;
}

/**
* 加载模式配置文件，先从模式目录中读取，读取不到则尝试读取默认配置文件
* @param modeName 模式名称
* @param fileName 文件名称
* @return void
**/
void execModeCfgThenDefault(const char[] modeName, const char[] fileName)
{
	char tempPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, tempPath, sizeof(tempPath), "%s/%s/%s", modeDirPath, modeName, fileName);
	if (!FileExists(tempPath)) {
		log.error("[%s]: 模式: %s 配置文件: %s 不存在, 尝试加载默认配置文件", MODULE_PREFIX, modeName, tempPath);
		BuildPath(Path_SM, tempPath, sizeof(tempPath), "%s/%s", CFG_PATH, fileName);
		if (!FileExists(tempPath)) {
			log.error("[%s]: 模式: %s 默认配置文件: %s 不存在, 加载失败", MODULE_PREFIX, modeName, tempPath);
		} else {
			// 默认配置文件：exec xxx.cfg
			log.info("[%s]: 成功加载模式: %s 默认配置文件: %s, 命令: exec %s", MODULE_PREFIX, modeName, fileName, fileName);
			ServerCommand("exec %s", fileName);
		}
	} else {
		// 普通配置文件：exec cfgogl/模式名/xxx.cfg
		FormatEx(tempPath, sizeof(tempPath), "%s/%s/%s", modeDirPath[strlen(CFG_PATH)], modeName, fileName);
		ServerCommand("exec %s", tempPath);
		log.info("[%s]: 成功加载模式：%s 配置文件: %s, 命令: exec %s", MODULE_PREFIX, modeName, fileName, tempPath);
	}
}

/**
* 递归删除目录
* @param dir 目录句柄
* @param path 目录路径
* @return bool
**/
bool removeDir(DirectoryListing dir, const char[] path) {
	if (dir == null) {
		return false;
	}
	FileType type;
	char fileName[PLATFORM_MAX_PATH], filePath[PLATFORM_MAX_PATH];

	while (dir.GetNext(fileName, sizeof(fileName), type)) {
		// 当前目录和上级目录不做处理
		if (strcmp(fileName, ".") == 0 || strcmp(fileName, "..") == 0) {
			continue;
		}
		FormatEx(filePath, sizeof(filePath), "%s/%s", path, fileName);
		// 是文件，直接删除
		if (type == FileType_File) {
			DeleteFile(filePath);
		} else if (type == FileType_Directory) {
			// 是文件夹，递归删除
			DirectoryListing nextDir = OpenDirectory(filePath);
			if (!removeDir(nextDir, filePath)) {
				break;
			}
		}
	}
	RemoveDir(path);
	return true;
}