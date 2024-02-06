#include <sourcemod>
#include <sdktools>

new Handle:g_hLimitTank;
new g_LimitTank

public Plugin:myinfo = 
{
	name = "L4D2 Limit Tank",
	author = "Harry Potter",
	description = "limit tank in server",
	version = "1.1",
	url = "https://steamcommunity.com/id/fbef0102/"
}

public OnPluginStart()
{
	g_hLimitTank	= CreateConVar("z_tank_limit", "3", "Maximum of tanks in server.",FCVAR_NOTIFY);
	HookEvent("tank_spawn", PD_ev_TankSpawn);
	
	g_LimitTank = GetConVarInt(g_hLimitTank);
	HookConVarChange(g_hLimitTank, Limit_CvarChange);
	
	AutoExecConfig(true, "l4d_tanklimit");
}

public Action:PD_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientInGame(client) || !IsFakeClient(client)) return;
	
	
	if(g_LimitTank >= 0)
	{
		CreateTimer(1.5, CheckAndKickTank,client);
	}
	
}
public Action:CheckAndKickTank(Handle:timer,any:client)
{
	if(IsClientConnected(client) && IsClientInGame(client)&&IsPlayerTank(client)&&IsFakeClient(client))
	{
		new tank_count = 0;
		for (new i=1;i<=MaxClients;i++)
			if(IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i)==3 && IsPlayerTank(i) && IsPlayerAlive(i))
				tank_count++;
		
		//PrintToChatAll("tank_count: %d, g_LimitTank: %d", tank_count,g_LimitTank);		
		if(tank_count > g_LimitTank)
		{
			TeleportEntity(client,
			Float:{0.0, 0.0, 0.0}, // Teleport to map center
			NULL_VECTOR, 
			NULL_VECTOR);
			KickClient(client);
		}
	}
}
public Limit_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	g_LimitTank = GetConVarInt(g_hLimitTank);
}

stock bool:IsPlayerTank(tank_index)
{
	return GetEntProp(tank_index, Prop_Send, "m_zombieClass") == 8;
}