#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4dhooks>

enum
{
	TEAM_SPECTATOR = 1,
	TEAM_SURVIVOR,
	TEAM_INFECTED
}

enum
{
	L4D2Infected_Common = 0,
	L4D2Infected_Smoker = 1,
	L4D2Infected_Boomer,
	L4D2Infected_Hunter,
	L4D2Infected_Spitter,
	L4D2Infected_Jockey,
	L4D2Infected_Charger,
	L4D2Infected_Witch,
	L4D2Infected_Tank,
	L4D2Infected_Survivor,
	L4D2Infected_Size //10 size
};


ConVar SS_1_SiNum;
ConVar SS_Time;
ConVar SS_EnableRelax, SS_EnableFastRespawn;
ConVar SS_DPSLimit;
ConVar g_cAutoMode, g_cAutoTime, g_cAutoPerPTimeDe, g_cAutoSiLim, g_cAutoSiPIn;
ConVar g_cEnableM4Fix;

bool g_bFixUnlimitSpawnsEnable = true;

Handle g_TResetSpecialsTimer;

public Plugin myinfo =
{
	name = "[L4D2] Director SI Spawn",
	author = "Sir.P, kita",
	description = "修改特感脚本的刷新数量",
	version = "1.1",
	url = "https://github.com/PencilMario/L4D2-Not0721Here-CoopSvPlugins/blob/main/addons/sourcemod/scripting/Si_SpawnSetting.sp"
	//原插件插件出处为url链接,此版本进为修改版,功能无变化,仅移除部分include依赖,去除对script_reloader插件的依赖。
};

public void OnPluginStart()
{
	RegAdminCmd("sm_silimit", Cmd_SetAiSpawns, ADMFLAG_ROOT);
	RegAdminCmd("sm_sitimer", Cmd_SetAiTime, ADMFLAG_ROOT);
	RegAdminCmd("sm_sidps", Cmd_SetDpsLim, ADMFLAG_ROOT);
	RegAdminCmd("sm_reloadscript", Cmd_Reload, ADMFLAG_ROOT);
	
	SS_1_SiNum = CreateConVar("sss_1P", "8", "特感数量");
	SS_Time = CreateConVar("SS_Time", "25", "刷新间隔");
	SS_EnableRelax = CreateConVar("SS_Relax", "1", "允许relax");
	SS_EnableFastRespawn = CreateConVar("SS_FastRespawn", "0", "跳过relax时, 是否快速补特");
	SS_DPSLimit = CreateConVar("SS_DPSSiLimit", "4", "DPS特感数量限制(口水和胖子)");
	g_cAutoMode = CreateConVar("sm_ss_automode", "0", "自动调整刷特模式(4+生还玩家)");
	g_cAutoPerPTimeDe = CreateConVar("sm_ss_autoperdetime", "1", "每多一名生还,特感的复活时间减少多少s");
	g_cAutoTime = CreateConVar("sm_ss_autotime", "25", "一只特感的基础复活时间");
	g_cAutoSiLim = CreateConVar("sm_ss_autosilim", "8", "在4名玩家时,基础特感数量");
	g_cAutoSiPIn = CreateConVar("sm_ss_autoperinsi", "2", "每多一名生还,增加几只特感");
	g_cEnableM4Fix = CreateConVar("sm_ss_fixm4spawn", "0", "是否启用绝境修复");
	

	HookEvent("round_start", RoundStart_Event);

	HookConVarChange(SS_1_SiNum, reload_script);
	HookConVarChange(SS_Time, reload_script);
	HookConVarChange(g_cAutoMode, reload_script);
	HookConVarChange(SS_DPSLimit, reload_script);
	HookConVarChange(SS_EnableRelax, OnRelaxChanged);
	HookConVarChange(g_cEnableM4Fix, OnM4FixChanged)
}


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("director_si_spawn");
	return APLRes_Success;
}


public void OnMapInit()
{
	if (g_cEnableM4Fix.IntValue == 1) CheckValues();
}

public Action RoundStart_Event(Event event, const String:name[], bool:dontBroadcast){
	if (g_cAutoMode.IntValue == 1) AutoSetSi();
	Reload();
	if (SS_EnableRelax.IntValue == 1){
		if (g_TResetSpecialsTimer != INVALID_HANDLE){
			KillTimer(g_TResetSpecialsTimer);
			g_TResetSpecialsTimer = INVALID_HANDLE;
		}
	}else{
		g_TResetSpecialsTimer = CreateTimer(1.0, Timer_ResetSpecialsCountdownTime, _, TIMER_REPEAT);
	}
	return Plugin_Continue;
}

public reload_script(Handle:convar, const String:oldValue[], const String:newValue[]){
	if (g_cAutoMode.IntValue == 1) AutoSetSi();
	Reload();
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client)) return;
	if (g_cAutoMode.IntValue != 1) return;
	AutoSetSi();
	CPrintToChatAll("[{G}!{default}]刷新配置:最高同屏{O}%d{default},单类至少{O}%d{default}只,单SlotCD{O}%ds{default},DPS特感限制{O}%d{default}只,Relax阶段:{O}%d{default}",	SS_1_SiNum.IntValue, SILimit(SS_1_SiNum.IntValue), SS_Time.IntValue, SS_DPSLimit.IntValue, SS_EnableRelax.IntValue);
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client)) return;
	if (g_cAutoMode.IntValue != 1) return;
	CreateTimer(2.0, SetSi,client);
}

public Action SetSi(Handle timer, int client)
{
	AutoSetSi();
	CPrintToChatAll("[{G}!{default}]刷新配置:最高同屏{O}%d{default},单类至少{O}%d{default}只,单SlotCD{O}%ds{default},DPS特感限制{O}%d{default}只,Relax阶段:{O}%d{default}",	SS_1_SiNum.IntValue, SILimit(SS_1_SiNum.IntValue), SS_Time.IntValue, SS_DPSLimit.IntValue, SS_EnableRelax.IntValue);
	return Plugin_Stop;
}

public OnM4FixChanged(Handle:convar, const String:oldValue[], const String:newValue[]){
	if (g_cEnableM4Fix.IntValue == 1){
		CheckValues();
	}else{
		g_bFixUnlimitSpawnsEnable = false;
		CPrintToChatAll("[{G}!{default}]即将重启地图");
		CreateTimer(5.0, Timer_RestartMap);
	}
}

public OnRelaxChanged(Handle:convar, const String:oldValue[], const String:newValue[]){
	if (SS_EnableRelax.IntValue == 1){
		if (g_TResetSpecialsTimer != INVALID_HANDLE){
			KillTimer(g_TResetSpecialsTimer);
			g_TResetSpecialsTimer = INVALID_HANDLE;
		}
	}else{
		g_TResetSpecialsTimer = CreateTimer(1.0, Timer_ResetSpecialsCountdownTime, _, TIMER_REPEAT);
	}
}

public Action Timer_RestartMap(Handle Timer){
	char mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));
	ServerCommand("changelevel %s", mapname);
	return Plugin_Handled;
}

public Action Timer_ResetSpecialsCountdownTime(Handle Timer)
{
	if (SS_EnableFastRespawn.IntValue < 1) return Plugin_Continue;
	float nowTime;
	for (int i = 1; i < 7; i++)
	{
		CountdownTimer SiTimer = L4D2Direct_GetSIClassSpawnTimer(i);
		nowTime = CTimer_GetTimestamp(SiTimer);
		CTimer_SetTimestamp(SiTimer, nowTime - 20.0);
		
		IntervalTimer SITimer2 = L4D2Direct_GetSIClassDeathTimer(i);
		nowTime = ITimer_GetTimestamp(SITimer2);
		ITimer_SetTimestamp(SITimer2, nowTime - 20.0);
	}
	if (SS_EnableFastRespawn.IntValue < 2) return Plugin_Continue;
	for (int i = 1; i <= MaxClients; i++){
		if (!IsClientInGame(i)) continue;
		if (!IsFakeClient(i)) continue;
		if (!IsInfected(i)) continue;
		if (L4D2_GetPlayerZombieClass(i) == L4D2Infected_Spitter) continue;
		if (!IsPlayerAlive(i)) KickClient(i);
	}
	return Plugin_Continue;
}

void AutoSetSi()
{
	int players = GetConnectedPlayer(0);
	if (players <= 4)
	{
		SS_1_SiNum.IntValue = g_cAutoSiLim.IntValue;
		SS_Time.IntValue = g_cAutoTime.IntValue;
		isLegalSetting();
		Reload();
		return;
	}
	SS_1_SiNum.IntValue = g_cAutoSiLim.IntValue + g_cAutoSiPIn.IntValue * (players - 4);
	SS_Time.IntValue = g_cAutoTime.IntValue - g_cAutoPerPTimeDe.IntValue * (players - 4);
	isLegalSetting();
	Reload();
	return;
}

void isLegalSetting()
{
	ConVar sv_setmax = FindConVar("sv_setmax");
	int players = GetConnectedPlayer(0);
	if (players + SS_1_SiNum.IntValue > sv_setmax.IntValue) SS_1_SiNum.IntValue = sv_setmax.IntValue - players;
	if (SS_Time.IntValue < 0) SS_Time.IntValue = 0;
	return;
}

public int SILimit(int num){
	int Si = num/6;
	if (Si*6 != num) Si++;
	if (Si <= 0) Si=1;
	return Si
}

int GetConnectedPlayer(int client) {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientAuthorized(i) && !IsFakeClient(i))
			count++;
	}
	return count;
}

public Action Cmd_SetAiTime(int client, int args)
{
	int time;
	if (args < 1)
	{
		CReplyToCommand(client, "[{G}!{default}]使用方式: sm_sitimer <刷新间隔>");
		return Plugin_Handled;
	}
	time = GetCmdArgInt(1);
	SS_Time.IntValue = time;
	// char name[64];
	// GetClientName(client, name, sizeof(name));
	// CPrintToChatAll("[{G}!{default}]{O}%s{default}修改了特感配置", name);
	// CPrintToChatAll("[{G}!{default}]修改了特感配置");
	CPrintToChatAll("[{G}!{default}]刷新配置:最高同屏{O}%d{default},单类至少{O}%d{default}只,单SlotCD{O}%ds{default},DPS特感限制{O}%d{default}只,Relax阶段:{O}%d{default}",	SS_1_SiNum.IntValue, SILimit(SS_1_SiNum.IntValue), SS_Time.IntValue, SS_DPSLimit.IntValue, SS_EnableRelax.IntValue);
	Reload();
	return Plugin_Continue;
}

public Action Cmd_SetDpsLim(int client, int args)
{
	int SiNum;

	if (args < 1)
	{
		CReplyToCommand(client, "[{G}!{default}]使用方式: sm_silimit <特感数量>");
		return Plugin_Handled;
	}
	SiNum = GetCmdArgInt(1);
	SS_DPSLimit.IntValue = SiNum;
	
	// char name[64];
	// GetClientName(client, name, sizeof(name));
	// CPrintToChatAll("[{G}!{default}]{O}%s{default}修改了特感配置", name);
	// CPrintToChatAll("[{G}!{default}]修改了特感配置");
	CPrintToChatAll("[{G}!{default}]刷新配置:最高同屏{O}%d{default},单类至少{O}%d{default}只,单SlotCD{O}%ds{default},DPS特感限制{O}%d{default}只,Relax阶段:{O}%d{default}",	SS_1_SiNum.IntValue, SILimit(SS_1_SiNum.IntValue), SS_Time.IntValue, SS_DPSLimit.IntValue, SS_EnableRelax.IntValue);
	Reload();
	return Plugin_Continue;
}

public Action Cmd_SetAiSpawns(int client, int args)
{
	int SiNum;

	if (args < 1)
	{
		CReplyToCommand(client, "[{G}!{default}]使用方式: sm_silimit <特感数量>");
		return Plugin_Handled;
	}
	SiNum = GetCmdArgInt(1);
	SS_1_SiNum.IntValue = SiNum;
	
	// char name[64];
	// GetClientName(client, name, sizeof(name));
	// CPrintToChatAll("[{G}!{default}]{O}%s{default}修改了特感配置", name);
	CPrintToChatAll("[{G}!{default}]{default}刷新配置:最高同屏{O}%d{default},单类至少{O}%d{default}只,单SlotCD{O}%ds{default},DPS特感限制{O}%d{default}只,Relax阶段:{O}%d{default}",	SS_1_SiNum.IntValue, SILimit(SS_1_SiNum.IntValue), SS_Time.IntValue, SS_DPSLimit.IntValue, SS_EnableRelax.IntValue);
	Reload();
	return Plugin_Continue;
}

public Action Cmd_Reload(int client, int args)
{
	Reload();
	return Plugin_Handled;
}

public Action Reload()
{
	ConVar gamemode = FindConVar("mp_gamemode");
	char modestr[64];
	gamemode.GetString(modestr, 64);  //  convars.inc
	char file[64];
	Format(file, 64, "%s.nut", modestr);
	CheatCommand("script_reload_code", file);
	PrintToServer("Script %s.nut Reloaded", modestr);
	return Plugin_Handled;
}

public void CheatCommand(char[] strCommand, char[] strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	ServerCommand("%s %s", strCommand, strParam1);
	//SetCommandFlags(strCommand, flags);
	CreateTimer(0.5, RestoreCheatFlag);
}

public Action RestoreCheatFlag(Handle timer)
{
	int flags = GetCommandFlags("script_reload_code");
	SetCommandFlags("script_reload_code", flags | FCVAR_CHEAT);
	return Plugin_Stop;
}

public Action L4D2_OnGetScriptValueInt(const char[] key, int &retVal, int hScope)
{   
    if (!g_bFixUnlimitSpawnsEnable) return Plugin_Continue;
    if (StrEqual("ShouldAllowSpecialsWithTank", key)){
        if (retVal != 0) { retVal = 0; return Plugin_Handled;}
    }
    if (StrEqual("RelaxMaxInterval", key)){
        if (retVal != 45) {retVal = 45; return Plugin_Handled;}
    }
    if (StrEqual("RelaxMinInterval", key)){
        if (retVal < 15) {retVal = 15; return Plugin_Handled;}
    }
    if (StrEqual("LockTempo", key)){
        if (retVal != 0) {retVal = 0; return Plugin_Handled;}
    }
    return Plugin_Continue;
}

void CheckValues()
{
    ConVar c_GameMode = FindConVar("mp_gamemode");
    char mode[32]
    c_GameMode.GetString(mode, sizeof(mode));
    if (StrEqual("mutations4", mode)) g_bFixUnlimitSpawnsEnable = true;
}

stock bool IsInfected(int client)
{
	return (IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED);
}