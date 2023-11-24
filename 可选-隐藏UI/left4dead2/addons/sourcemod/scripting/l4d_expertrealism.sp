#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#define TIMER_START 30.0

#include <sourcemod>
#include <multicolors>

ConVar mp_playerid_hold;

ConVar g_hCvarEnable, hGlow, hHideHud, sv_glowenable, hHardCoreHUDMODE, hHardCoreHUDButton, 
	hHardCoreKeepHUDTime, hHardCoreWaitHUDTime, hHardCoreHUDAnnounceType;
int iHideHudFlags, iHardCoreHUDButton, iHardCoreKeepHUDTime, iHardCoreHUDAnnounceType;
bool g_bCvarEnable, g_bGlow, bHardCoreHUDMODE;
float g_hHardCoreWaitHUDTime;

int g_iRoundStart, g_iPlayerSpawn;
int g_iShowHardCoreHud_TimeLeft[MAXPLAYERS+1];
Handle g_hHideHardCoreHudTimer[MAXPLAYERS+1];
bool g_bHideHardCoreHud[MAXPLAYERS+1];
float g_fKeyTime[MAXPLAYERS+1];
int g_iKeyState[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "L4D1/2 Real Realism Mode",
	author = "JNC & HarryPotter",
	description = "Real Realism Mode + HardCore Mode",
	version = "1.5",
	url = "https://steamcommunity.com/profiles/76561198026784913/"
};

bool g_bLateLoad, g_bL4D2Version;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion test = GetEngineVersion();

    if( test == Engine_Left4Dead )
    {
        g_bL4D2Version = false;
    }
    else if( test == Engine_Left4Dead2 )
    {
        g_bL4D2Version = true;
    }
    else
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
        return APLRes_SilentFailure;
    }

    g_bLateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
	mp_playerid_hold = FindConVar("mp_playerid_hold");

	// Trick
	g_hCvarEnable = 				CreateConVar("l4d_expertrealism_enable",        	"1",    "0=Plugin off, 1=Plugin on.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sv_glowenable = 				CreateConVar("sv_glowenable", 						"1", 	"Turns on and off the terror glow highlight effects (Hidden Value Cvar)", FCVAR_REPLICATED, true, 0.0, true,1.0);
	hGlow = 						CreateConVar("l4d_survivor_glowenable", 			"0", 	"If 1, Enable Server Glows for survivor team. (0=Hide Glow)", FCVAR_NOTIFY,true,0.0,true,1.0);
	hHideHud = 						CreateConVar("l4d_survivor_hidehud", 				"64", 	"HUD hidden flag for survivor team. (1=weapon selection, 2=flashlight, 4=all, 8=health, 16=player dead, 32=needssuit, 64=misc, 128=chat, 256=crosshair, 512=vehicle crosshair, 1024=in vehicle)", FCVAR_NOTIFY,true,0.0);
	hHardCoreHUDMODE = 				CreateConVar("l4d_survivor_hardcore_enable", 		"1", 	"If 1, Enable HardCore Mode, enable HUD and Glow if survivors hold hardcore_buttons.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hHardCoreHUDButton = 			CreateConVar("l4d_survivor_hardcore_buttons", 		"4", 	"For HardCore Mode, HUD and Glow will show while survivors 1: stay still, 2: Walk(Shift), 4: Crouch(DUCK), 8: Crouch(DUCK) and stay still, add numbers together (0: None).", FCVAR_NOTIFY, true, 0.0);
	hHardCoreKeepHUDTime = 			CreateConVar("l4d_survivor_hardcore_keep_time", 	"0", 	"For HardCore Mode, How long to keep the hud and glow enabled after surviors release hardcore_buttons. (0=Instant Disable)", FCVAR_NOTIFY, true, 0.0);
	hHardCoreWaitHUDTime = 			CreateConVar("l4d_survivor_hardcore_wait_time", 	"1.0", 	"For HardCore Mode, How long does it take to enable the hud and glow after surviors hold hardcore_buttons. (0=Instant Enable)", FCVAR_NOTIFY, true, 0.0);
	hHardCoreHUDAnnounceType = 		CreateConVar("l4d_survivor_hardcore_announce_type", "0", 	"For HardCore Mode, changes how message displays. (0: Disable, 1:In chat, 2: In Hint Box, 3: In center text)", FCVAR_NOTIFY, true, 0.0, true, 3.0);

	// Optional
	RegAdminCmd( "sm_glowoff", Command_GlowOff, ADMFLAG_BAN, "Hide one client glow");
	RegAdminCmd( "sm_glowon", Command_GlowOn, ADMFLAG_BAN, "Show one client glow");
	RegAdminCmd( "sm_hidehud", Command_HideHud, ADMFLAG_BAN, "Hide your hud flag");
	RegAdminCmd( "sm_hud", Command_HideHud, ADMFLAG_BAN, "Hide your hud flag");

	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChange_EnableCvar);
	hGlow.AddChangeHook(ConVarChange_GlowCvar);
	hHideHud.AddChangeHook(ConVarChange_HudCvar);
	hHardCoreHUDMODE.AddChangeHook(ConVarChange_HudCvar);
	hHardCoreHUDButton.AddChangeHook(ConVarChange_HudCvar);
	hHardCoreKeepHUDTime.AddChangeHook(ConVarChange_HudCvar);
	hHardCoreWaitHUDTime.AddChangeHook(ConVarChange_HudCvar);
	hHardCoreHUDAnnounceType.AddChangeHook(ConVarChange_HudCvar);
	
	HookEvent("player_death", evtPlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", evtPlayerTeam);
	HookEvent("player_spawn", evtPlayerSpawn);
	HookEvent("round_start", evtRoundStart);
	HookEvent("round_end", evtRoundEnd);
	HookEvent("map_transition", evtRoundEnd); //戰役過關到下一關的時候 (沒有觸發round_end)
	HookEvent("mission_lost", evtRoundEnd); //戰役滅團重來該關卡的時候 (之後有觸發round_end)
	HookEvent("finale_vehicle_leaving", evtRoundEnd); //救援載具離開之時  (沒有觸發round_end)
	

	AutoExecConfig(true, "l4d_expertrealism");
	
	if( g_bLateLoad )
	{
		for( int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			{
				SetHideHudClient(i, iHideHudFlags);
				SetGlowClient(i, g_bGlow);
			}
		}
	}
}

public void OnPluginEnd()
{
	ResetTimer();
}

public void OnMapStart()
{
}

public void OnMapEnd()
{
	g_iRoundStart = g_iPlayerSpawn = 0;
	ResetTimer();
}

public void OnConfigsExecuted()
{
	GetCvars();
	if(g_bCvarEnable)
	{
		//This is just for nicknames
		mp_playerid_hold.SetFloat(0.0);	// only supported on coop expert
	}
}

public void ConVarChange_EnableCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
	if(g_bCvarEnable)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			{
				HardCoreHideHud(i);
			}
		}
		mp_playerid_hold.SetFloat(0.0);
	}
	else
	{
		sv_glowenable.SetInt(1);
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i))
			{
				SetGlowClient(i, true);
				SetHideHudClient(i, 0);
			}
		}
		mp_playerid_hold.SetFloat(0.25);
	}
}

public void ConVarChange_HudCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
	if(g_bCvarEnable)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
				SetHideHudClient(i, iHideHudFlags);
		}
	}
}

public void ConVarChange_GlowCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
	if(g_bCvarEnable)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
				SetGlowClient(i, g_bGlow);
		}
	}
}

void GetCvars()
{
	g_bCvarEnable = g_hCvarEnable.BoolValue;
	g_bGlow = hGlow.BoolValue;
	iHideHudFlags = hHideHud.IntValue;
	bHardCoreHUDMODE = hHardCoreHUDMODE.BoolValue;
	iHardCoreHUDButton = hHardCoreHUDButton.IntValue;
	iHardCoreKeepHUDTime = hHardCoreKeepHUDTime.IntValue;
	g_hHardCoreWaitHUDTime = hHardCoreWaitHUDTime.FloatValue;
	iHardCoreHUDAnnounceType = hHardCoreHUDAnnounceType.IntValue;
}

public Action Command_GlowOff(int client, int args)
{
	if (!g_bCvarEnable) return Plugin_Handled;

	if (args < 1) {
		ReplyToCommand(client, "[SM] Usage: !glowoff <name/#userid>");
		return Plugin_Handled;
	}
	
	char arg[32];
	GetCmdArg(1, arg, sizeof(arg));
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		int victim = target_list[i];
		if (!IsFakeClient(victim))
		{
			SetGlowClient(victim, false);
			PrintToChat(client, "You set %N glow off", victim);
		}
	}
	
	return Plugin_Handled;
}

public Action Command_GlowOn(int client, int args)
{
	if (!g_bCvarEnable) return Plugin_Handled;

	if (args < 1) {
		ReplyToCommand(client, "[SM] Usage: !glowon <name/#userid>");
		return Plugin_Handled;
	}
	
	char arg[32];
	GetCmdArg(1, arg, sizeof(arg));
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count; 
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		int victim = target_list[i];
		if (!IsFakeClient(victim))
		{
			SetGlowClient(victim, true);
			PrintToChat(client, "You set %N glow on", victim);
		}
	}
	
	return Plugin_Handled;
}

public Action Command_HideHud(int client, int args)
{
	if (!g_bCvarEnable) return Plugin_Handled;

	if (client == 0) {
		ReplyToCommand(client, "[SM] Can't be used by Server");
		return Plugin_Handled;
	}
	
	char arg[32];
	GetCmdArg(1, arg, sizeof(arg));
	
	int iFlag = StringToInt(arg);
	SetHideHudClient(client, iFlag);
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!g_bCvarEnable) return Plugin_Continue;
	if(bHardCoreHUDMODE == false) return Plugin_Continue;

	if(IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) )
	{
		if(IsPlayerIncap(client) || //倒地
			IsBeingPwnt(client)) //被控
		{
			HardCoreHideHud(client);
			g_iKeyState[client] = 0;
			return Plugin_Continue;
		}
		
		float flVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", flVel);
		if(IsPlayerOnTheGround(client)) 
		{
			if(flVel[0] == 0.0 && flVel[1] == 0.0 && flVel[2] == 0.0) // 靜止
			{
				if(iHardCoreHUDButton & 1)
				{
					CheckKeyState(client);

					delete g_hHideHardCoreHudTimer[client];
					return Plugin_Continue;
				}

				if(buttons & IN_DUCK && iHardCoreHUDButton & 8)
				{
					CheckKeyState(client);

					delete g_hHideHardCoreHudTimer[client];
					return Plugin_Continue;
				}
			}

			if( (buttons & IN_DUCK && iHardCoreHUDButton & 4) ||
				(buttons & IN_SPEED && iHardCoreHUDButton & 2) )  //shift: IN_SPEED
			{
				CheckKeyState(client);
				
				delete g_hHideHardCoreHudTimer[client];
				return Plugin_Continue;
			}
		}

		g_iKeyState[client] = 0;
		if(g_hHideHardCoreHudTimer[client] == null && g_bHideHardCoreHud[client] == false)
		{
			if(iHardCoreKeepHUDTime == 0)
			{
				HardCoreHideHud(client);
			}
			else
			{
				g_iShowHardCoreHud_TimeLeft[client] = iHardCoreKeepHUDTime;
				switch(iHardCoreHUDAnnounceType)
				{
					case 0: {/*nothing*/}
					case 1: {
						CPrintToChat(client, "[{olive}TS{default}] 剩餘 %d 秒顯示 Hud", g_iShowHardCoreHud_TimeLeft[client]);
					}
					case 2: {
						PrintHintText(client, "[TS] 剩餘 %d 秒顯示 Hud", g_iShowHardCoreHud_TimeLeft[client]);
					}
					case 3: {
						PrintCenterText(client, "[TS] 剩餘 %d 秒顯示 Hud", g_iShowHardCoreHud_TimeLeft[client]);
					}
				}
				g_hHideHardCoreHudTimer[client] = CreateTimer(1.0, Timer_CountDown, client ,TIMER_REPEAT);
			}
		}
	}

	return Plugin_Continue;
}

public Action Timer_CountDown(Handle timer, int client)
{
	if (!g_bCvarEnable
	|| !IsClientInGame(client) 
	|| GetClientTeam(client) != 2
	|| !IsPlayerAlive(client))
	{
		g_hHideHardCoreHudTimer[client] = null;
		return Plugin_Stop;
	}

	g_iShowHardCoreHud_TimeLeft[client] -= 1;
	if (g_iShowHardCoreHud_TimeLeft[client] <= 0)
	{
		HardCoreHideHud(client);
		g_hHideHardCoreHudTimer[client] = null;
		return Plugin_Stop;
	}
	else
	{
		switch(iHardCoreHUDAnnounceType)
		{
			case 0: {/*nothing*/}
			case 1: {
				CPrintToChat(client, "[{olive}TS{default}] 剩餘 %d 秒顯示 Hud", g_iShowHardCoreHud_TimeLeft[client]);
			}
			case 2: {
				PrintHintText(client, "[TS] 剩餘 %d 秒顯示 Hud", g_iShowHardCoreHud_TimeLeft[client]);
			}
			case 3: {
				PrintCenterText(client, "[TS] 剩餘 %d 秒顯示 Hud", g_iShowHardCoreHud_TimeLeft[client]);
			}
		}
		return Plugin_Continue;
	}
}

public void OnClientDisconnect(int client)
{
	delete g_hHideHardCoreHudTimer[client];
}

public void evtRoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(TIMER_START, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public void evtRoundEnd (Event event, const char[] name, bool dontBroadcast) 
{
	g_iRoundStart = g_iPlayerSpawn = 0;
	ResetTimer();
}

public void evtPlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(TIMER_START, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!g_bCvarEnable ||
		!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2) return;
	
	SetHideHudClient(client, iHideHudFlags);
	SetGlowClient(client, g_bGlow);
}

Action TimerStart(Handle timer)
{
	if (!g_bCvarEnable) return Plugin_Continue;

	//PrintToChatAll("TimerStart");
	g_iRoundStart = g_iPlayerSpawn = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			SetHideHudClient(i, iHideHudFlags);
			SetGlowClient(i, g_bGlow);
		}
	}

	return Plugin_Continue;
}
public void evtPlayerTeam(Event event, const char[] name, bool dontBroadcast) 
{
	if (!g_bCvarEnable) return;

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	CreateTimer(0.1, PlayerChangeTeamCheck, userid);//延遲一秒檢查	

	delete g_hHideHardCoreHudTimer[client];
}

Action PlayerChangeTeamCheck(Handle timer,int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client) || IsFakeClient(client)) return Plugin_Continue;
	
	if(GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		SetHideHudClient(client, iHideHudFlags);
		SetGlowClient(client, g_bGlow);
	}
	else
	{
		SetHideHudClient(client, 0);
		SetGlowClient(client, true);	
	}

	return Plugin_Continue;
}

public void	evtPlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
	if (!g_bCvarEnable) return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client)) return;
	
	SetHideHudClient(client, 0);
	SetGlowClient(client, true);
	delete g_hHideHardCoreHudTimer[client];
}

void CheckKeyState(int client)
{
	if(g_iKeyState[client] == 0)
	{
		g_fKeyTime[client] = GetEngineTime() + g_hHardCoreWaitHUDTime;
		g_iKeyState[client] = 1;
	}

	if(g_iKeyState[client] == 1)
	{
		if(g_fKeyTime[client] <= GetEngineTime() )
		{
			HardCoreShowHud(client);
		}
	}
}

stock bool IsPlayerFalling(int client)
{
	return GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0;
}

stock bool IsPlayerFallen(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0;
}

stock bool IsPlayerAlright(int client)
{
	return !(IsPlayerFalling(client) || IsPlayerFallen(client));
}

bool IsPlayerOnTheGround(int client)
{
	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1)
		return true;

	return false;
}

bool IsPlayerIncap(int client)
{
	if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		return true;

	return false;
}
bool IsBeingPwnt(int client)
{
	if(g_bL4D2Version)
	{
		/* Charger */
		if ( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		{
			return true;
		}

		if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		{
			return true;
		}
		/* Jockey */
		if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		{
			return true;
		}
	}

	/* Hunter */
	if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
	{
		return true;
	}

	/* Smoker */
	if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
	{
		return true;
	}

	return false;
}

void HardCoreShowHud(int client)
{
	SetHideHudClient(client, 0);
	SetGlowClient(client, true);
	g_bHideHardCoreHud[client] = false;
}

void HardCoreHideHud(int client)
{
	SetHideHudClient(client, iHideHudFlags);
	SetGlowClient(client, g_bGlow);
	g_bHideHardCoreHud[client] = true;
}

// Manual Trick, no matter if you server is on sv_glowenable 1 or 0, the client will have a different value, but you already know that
void SetGlowClient(int client, bool enable)
{
	if (enable)
		SendConVarValue(client, sv_glowenable, "1");
	else
		SendConVarValue(client, sv_glowenable, "0");
}

void SetHideHudClient(int client, int flag)
{
	SetEntProp(client, Prop_Send, "m_iHideHUD", flag);
}

void ResetTimer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		delete g_hHideHardCoreHudTimer[i];
	}
}