#include <sourcemod>
#include <sdktools>
//#include <colors>

new Handle:g_hLimitTank;
new g_LimitTank
int tanknum;

public Plugin:myinfo = 
{
	name = "Limit Tank",
	author = "kita",
	description = "每一关的坦克数量限制",
	version = "1.3",
	url = "nicai"
}

public OnPluginStart()
{
	g_hLimitTank = CreateConVar("z_tank_limit", "2", "本次关卡中坦克最多生成数量.",FCVAR_NOTIFY);
	HookEvent("tank_spawn", PD_ev_TankSpawn);
	HookEvent("round_start", Event_Reset, EventHookMode_Pre);
	HookEvent("mission_lost", Event_Reset, EventHookMode_Post);
	HookConVarChange(g_hLimitTank, Limit_CvarChange);
	g_LimitTank = GetConVarInt(g_hLimitTank);
	//AutoExecConfig(true, "l4d_tanklimit");
}


public Action Event_Reset(Event event, const char []name, bool dontBroadcast)
{
	tanknum = 0; //回合开始或任务失败重置计数
	return Plugin_Continue;
}

public Action:PD_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientInGame(client) || !IsFakeClient(client)) return;
	tanknum +=1;
	//CPrintToChatAll("{G}[提示]{B}  第%d个坦克计数", tanknum);
	if(g_LimitTank >= 0)
	{
		CreateTimer(1.0, CheckAndKickTank,client);
	}
	
}
public Action:CheckAndKickTank(Handle:timer,any:client)
{
	if(IsClientConnected(client) && IsClientInGame(client)&&IsPlayerTank(client)&&IsFakeClient(client))
	{
		for (new i=1;i<=MaxClients;i++)
		if(IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i)==3 && IsPlayerTank(i) && IsPlayerAlive(i))
	
		if(tanknum > g_LimitTank)
		{
			TeleportEntity(client,
			Float:{0.0, 0.0, 0.0}, // 先传送走tank
			NULL_VECTOR, 
			NULL_VECTOR);
			KickClient(client); //送走tank
		}
	}
}
public Limit_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	g_LimitTank = GetConVarInt(g_hLimitTank); //cvar变动
}

stock bool:IsPlayerTank(tank_index)
{
	return GetEntProp(tank_index, Prop_Send, "m_zombieClass") == 8; //tank检测
}