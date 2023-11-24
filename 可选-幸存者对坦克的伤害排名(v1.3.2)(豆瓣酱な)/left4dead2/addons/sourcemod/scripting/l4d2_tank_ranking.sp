/* 已知问题:如果有插件中途给坦克增加血会导致统计严重不准(例如某些通过给坦克加血或减血达到减伤或增伤目的的插件).*/
#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>

//数组最大数量.
#define Array 30
#define PLUGIN_VERSION "1.3.2"

int    g_iTankRanking;
ConVar g_hTankRanking;

int iTankHP[MAXPLAYERS+1], iTankHurt[MAXPLAYERS+1], iSurvivorTankHurt[MAXPLAYERS+1][MAXPLAYERS+1];

public Plugin myinfo =  
{
	name = "l4d2_tank_ranking",
	author = "豆瓣酱な",  
	description = "生还者对坦克的伤害排名.",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public void OnPluginStart()
{
	HookEvent("tank_spawn", Event_TankSpawn);//坦克出现.
	HookEvent("player_hurt", Event_PlayerHurt);//玩家受伤.
	HookEvent("player_death", Event_PlayerDeath);//玩家死亡.

	g_hTankRanking = CreateConVar("l4d2_tank_Ranking", "5", "设置生还者对坦克的伤害的最大排名. 0=禁用.", FCVAR_NOTIFY);
	g_hTankRanking.AddChangeHook(IsConVarChanged);
	AutoExecConfig(true, "l4d2_tank_ranking");//生成指定文件名的CFG.
}

//地图开始.
public void OnMapStart()
{
	IsGetCvars();
}

public void IsConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsGetCvars();
}

void IsGetCvars()
{
	g_iTankRanking = g_hTankRanking.IntValue;

	if (g_iTankRanking > Array)
		g_iTankRanking = Array;
}

//坦克出现.
public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsValidClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
	{	
		RequestFrame(FrameGetTankHealth, GetClientUserId(client));//坦克出现时延迟一帧获取血量.
		IsResetPlayerVariables(client);//坦克出现时重置整型变量.
	}
}

//坦克出现时获取血量.
void FrameGetTankHealth(int client)
{
	if ((client = GetClientOfUserId(client)) && IsClientInGame(client))
		iTankHP[client] = GetClientHealth(client);//记录坦克出现时的血量.
}

//坦克出现时重置整型变量.
void IsResetPlayerVariables(int client)
{
	for(int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			iSurvivorTankHurt[i][client] = 0;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int Dmg = event.GetInt("dmg_health");
	//int health = event.GetInt("health");
	
	if(IsTank(client) && IsSurvivor(attacker))
	{	
		if (IsPlayerState(client))//判断坦克是正常状态.
		{
			int iBot = IsClientIdle(attacker);
			iTankHurt[client] = GetClientHealth(client);//记录坦克剩余的血量.
			iSurvivorTankHurt[!iBot ? attacker : iBot][client] += Dmg;
			//PrintToChat(!iBot ? attacker : iBot, "\x04[提示]\x05当前\x03%N\x05受到了\x04:\x03%d\x05点伤害,总计受到了\x04:\x03%.0f点伤害,总血量\x04:\x03%d.", client, Dmg, iSurvivorTankHurt[!iBot ? attacker : iBot][client], eventhealth);
		}
	}
}

//坦克死亡,显示幸存者对坦克的伤害量.
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if(IsValidClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
	{
		if(IsValidClient(attacker) && client != attacker)
		{
			iSurvivorTankHurt[attacker][client] += iTankHurt[client];//坦克死亡后把剩余血量+给击杀者.
			//PrintToChat(attacker, "\x04[提示]\x05总共对\x03%N\x05造成了\x04:\x03%d\x05点伤害,总血量\x04:\x03%d.", client, iSurvivorTankHurt[attacker][client], iTankHP[client]);
		}
		char g_sName[32];
		if(IsFakeClient(client))
		{
			FormatEx(g_sName, sizeof(g_sName), "%N", client);
			SplitString(g_sName, "Tank", g_sName, sizeof(g_sName));
		}
		else
			FormatEx(g_sName, sizeof(g_sName), "\x03%N", client);
		if (g_iTankRanking > 0)
			IsTankDamageSort(client, g_sName);
		IsGetTankDeath(client);//坦克死亡后重置整型变量.
	}
}

//坦克伤害排行榜.
void IsTankDamageSort(int client, char[] g_sName)
{
	int assisters[16][2];
	int assister_count;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			int iBot = IsClientIdle(i);
			if (iSurvivorTankHurt[!iBot ? i : iBot][client] > 0)
			{
				assisters[assister_count][0] = !iBot ? i : iBot;
				assisters[assister_count][1] = iSurvivorTankHurt[!iBot ? i : iBot][client];
				assister_count++;
			}
		}
	}
	if (assister_count > 0)
	{
		int count, temp[3], iMax[3];
		char g_sRanking[Array][32], g_sPercent[Array][32];
		char g_sDamage[Array][32], g_sAttack[Array][32];
		char g_sBlank1[15][64], g_sBlank2[15][64], g_sBlank3[15][64];
		
		SortCustom2D(assisters, assister_count, ClientValue2DSortDesc);
		PrintToChatAll("\x04坦克%s\x05死亡,伤害排名\x04:\x03%d\x05HP", g_sName, iTankHP[client]);
		for (int x = 0; x < g_iTankRanking; x++)
		{
			int attacker = assisters[x][0];
			int damage   = assisters[x][1];
			
			if (IsValidClient(attacker)/* && !IsFakeClient(client)*/)
			{
				//PrintToChatAll("\x04%d\x05:\x03%.1f%%\x05,\x04伤害量\x05:\x03%d\x05,\x04名字\x05:\x03%N", x + 1, IsTankDamagePercentage(damage, client), damage, attacker);
				FormatEx(g_sRanking[x], sizeof(g_sRanking[]), "%d", x + 1);
				FormatEx(g_sPercent[x], sizeof(g_sPercent[]), "%.1f", IsTankDamagePercentage(damage, client));
				FormatEx(g_sDamage [x], sizeof(g_sDamage []), "%d", damage);
				FormatEx(g_sAttack [x], sizeof(g_sAttack []), "%N", attacker);
				count += 1;
			}
		}
		
		temp[0] = strlen(g_sRanking[0]);
		temp[1] = strlen(g_sPercent[0]);
		temp[2] = strlen(g_sDamage [0]);

		for (int y = 0; y < count; y++)
		{ 
			if(strlen(g_sRanking[y]) > temp[0])
				temp[0] = strlen(g_sRanking[y]);
			if(strlen(g_sPercent[y]) > temp[1])
				temp[1] = strlen(g_sPercent[y]);
			if(strlen(g_sDamage[y]) > temp[2])
				temp[2] = strlen(g_sDamage[y]);

			iMax[0] = temp[0] - strlen(g_sRanking[y]);
			iMax[1] = temp[1] - strlen(g_sPercent[y]);
			iMax[2] = temp[2] - strlen(g_sDamage [y]);

			if(iMax[0] > 0)
				strcopy(g_sBlank1[y], sizeof(g_sBlank1[]), GetAddSpaces(iMax[0]));
			if(iMax[1] > 0)
				strcopy(g_sBlank2[y], sizeof(g_sBlank2[]), GetAddSpaces(iMax[1]));
			if(iMax[2] > 0)
				strcopy(g_sBlank3[y], sizeof(g_sBlank3[]), GetAddSpaces(iMax[2]));

			PrintToChatAll("%s\x04%s%s\x05:\x03[%s\x04%s%%%s\x03]\x03(\x04%s%s%s\x03)\x05%s", 
			g_sBlank1[y], g_sRanking[y], g_sBlank1[y], g_sBlank2[y], g_sPercent[y], g_sBlank2[y], g_sBlank3[y], g_sDamage[y], g_sBlank3[y], g_sAttack[y]);
		}
	}
}

//填入对应数量的空格.
char[] GetAddSpaces(int Value)
{
	char g_sBlank[64], g_sFill[10][64];

	if(Value > 0)
	{
		for (int i = 0; i < Value; i++)
		{
			strcopy(g_sFill[i], sizeof(g_sFill[]), " ");
		}
		ImplodeStrings(g_sFill, 10, "", g_sBlank, sizeof(g_sBlank));//打包字符串.
	}
	return g_sBlank;
}

//百分比取整.
float IsTankDamagePercentage(int damage, int client)
{
	return float(damage)/float(iTankHP[client]) * 100.0;
}

public int ClientValue2DSortDesc(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	if (elem1[1] > elem2[1])
		return -1;
	else if (elem2[1] > elem1[1])
		return 1;
		
	return 0;
}

//坦克死亡后重置整型变量.
void IsGetTankDeath(int client)
{
	iTankHurt[client] = 0;
	
	for(int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			iSurvivorTankHurt[i][client] = 0;
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

//正常状态.
stock bool IsPlayerState(int client)
{
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

stock bool IsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

stock bool IsInfected(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

stock bool IsTank(int client)  
{
	return IsInfected(client) && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}
/*
char[] GetTrueName(int client)
{
	char g_sName[32];
	int Bot = IsClientIdle(client);
	
	if(Bot != 0)
		Format(g_sName, sizeof(g_sName), "★闲置:%N★", Bot);
	else
		GetClientName(client, g_sName, sizeof(g_sName));
	return g_sName;
}
*/
int IsClientIdle(int client)
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}