#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <l4d2_GetWitchNumber>
/* 定制版(v1.0.1) */
#define iArray	4
#define CVAR_FLAGS	FCVAR_NOTIFY
#define TankSound	"ui/pickup_secret01.wav"

#define	PrintChat		(1 << 0)
#define PrintHint		(1 << 1)

int g_iMultiplesCount;
float g_fMultiples[2][iArray];
char g_sDifficultyName[][] = {"简单", "普通", "高级", "专家"};
char g_sDifficultyCode[][] = {"Easy", "Normal", "Hard", "Impossible"};

ConVar g_hTankMultiple, g_hWitchMultiple;
int    g_iTankSwitch, g_iTankPrompt, g_iTankBasics, g_iTankHealth, g_iWitchSwitch, g_iWitchBasics, g_iWitchHealth;
ConVar g_hTankSwitch, g_hTankPrompt, g_hTankBasics, g_hTankHealth, g_hWitchSwitch, g_hWitchBasics, g_hWitchHealth;

public Plugin myinfo = 
{
	name = "L4D2 Tank Announcer",
	author = "Visor, 豆瓣酱な",
	description = "Announce in chat and via a sound when a Tank has spawned",
	version = "1.6.8",
	url = "https://github.com/Attano"
};

public void OnPluginStart()
{
	g_hTankSwitch		= CreateConVar("l4d2_tank_Switch", 		"1", 				"启用坦克出现时根据生还者人数而增加血量? 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hTankPrompt		= CreateConVar("l4d2_tank_prompt", 		"3", 				"设置坦克出现时的提示类型(启用多个就把数字相加). 0=禁用, 1=聊天窗, 2=屏幕中下.", CVAR_FLAGS);
	g_hTankMultiple		= CreateConVar("l4d2_tank_Multiples", 	"0.8;1.0;1.5;2.0",	"设置游戏难度对应的倍数(留空=使用默认值:1.0).", CVAR_FLAGS);
	g_hTankBasics		= CreateConVar("l4d2_tank_minimum", 	"4000",				"设置坦克的基础生命值(四名生还者或以内时).", CVAR_FLAGS);
	g_hTankHealth		= CreateConVar("l4d2_tank_health", 		"2500", 			"设置每多一个生还者坦克所增加的血量.", CVAR_FLAGS);
	
	g_hWitchSwitch		= CreateConVar("l4d2_witch_Switch", 	"1", 				"启用女巫出现时根据生还者人数而增加血量? 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hWitchMultiple	= CreateConVar("l4d2_witch_Multiples", 	"0.8;1.0;1.5;2.0",	"设置游戏难度对应的倍数(留空=使用默认值:1.0).", CVAR_FLAGS);
	g_hWitchBasics		= CreateConVar("l4d2_witch_minimum", 	"1000",				"设置女巫的基础生命值(四名生还者或以内时).", CVAR_FLAGS);
	g_hWitchHealth		= CreateConVar("l4d2_witch_health", 	"200",				"设置每多一个生还者女巫所增加的血量.", CVAR_FLAGS);
	
	g_hTankSwitch.AddChangeHook(iHealthConVarChanged);
	g_hTankPrompt.AddChangeHook(iHealthConVarChanged);
	g_hTankMultiple.AddChangeHook(iHealthConVarChanged);
	g_hTankBasics.AddChangeHook(iHealthConVarChanged);
	g_hTankHealth.AddChangeHook(iHealthConVarChanged);
	
	g_hWitchSwitch.AddChangeHook(iHealthConVarChanged);
	g_hWitchMultiple.AddChangeHook(iHealthConVarChanged);
	g_hWitchBasics.AddChangeHook(iHealthConVarChanged);
	g_hWitchHealth.AddChangeHook(iHealthConVarChanged);
	
	HookEvent("witch_spawn", Event_WitchSpawn);
	HookEvent("tank_spawn", Event_TankSpawn);
	
	AutoExecConfig(true, "l4d2_tank_announce");//生成指定文件名的CFG.
}

public void OnMapStart()
{
	PrecacheSound(TankSound);
}

public void OnConfigsExecuted()
{
	GetConVarCvars();
}

public void iHealthConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetConVarCvars();
}

void GetConVarCvars()
{
	g_iTankSwitch	= g_hTankSwitch.IntValue;
	g_iTankPrompt	= g_hTankPrompt.IntValue;
	g_iTankBasics	= g_hTankBasics.IntValue;
	g_iTankHealth	= g_hTankHealth.IntValue;
	
	g_iWitchSwitch	= g_hWitchSwitch.IntValue;
	g_iWitchBasics	= g_hWitchBasics.IntValue;
	g_iWitchHealth	= g_hWitchHealth.IntValue;

	char sCmds[2][256], g_sMultiples[2][iArray][32];
	g_hTankMultiple.GetString(sCmds[0], sizeof(sCmds[]));
	g_hWitchMultiple.GetString(sCmds[1], sizeof(sCmds[]));
	g_iMultiplesCount = ReplaceString(sCmds[0], sizeof(sCmds[]), ";", ";", false);
	g_iMultiplesCount = ReplaceString(sCmds[1], sizeof(sCmds[]), ";", ";", false);
	ExplodeString(sCmds[0], ";", g_sMultiples[0], g_iMultiplesCount + 1, sizeof(g_sMultiples[]));
	ExplodeString(sCmds[1], ";", g_sMultiples[1], g_iMultiplesCount + 1, sizeof(g_sMultiples[]));
	
	for (int i = 0; i < iArray; i++)
		g_fMultiples[0][i] = sCmds[0][0] == '\0' || IsCharSpace(sCmds[0][0]) || g_sMultiples[0][i][0] == '\0' || IsCharSpace(g_sMultiples[0][i][0]) || !IsCharNumeric(g_sMultiples[0][i][0]) ? 1.0 : StringToFloat(g_sMultiples[0][i]);
	for (int i = 0; i < iArray; i++)
		g_fMultiples[1][i] = sCmds[1][0] == '\0' || IsCharSpace(sCmds[1][0]) || g_sMultiples[1][i][0] == '\0' || IsCharSpace(g_sMultiples[1][i][0]) || !IsCharNumeric(g_sMultiples[1][i][0]) ? 1.0 : StringToFloat(g_sMultiples[1][i]);
}

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iWitchSwitch == 0)
		return;

	int Witchid = event.GetInt("witchid");
	for (int i = 0; i < iArray; i++)
		if (StrEqual(GetGameDifficulty(), g_sDifficultyCode[i], false))
			SetWitchMultiples(Witchid, g_fMultiples[1][i] == 0 ? 1.0 : g_fMultiples[1][i], g_sDifficultyName[i]);
}

void SetWitchMultiples(int Witchid, float Multiples, char[] sName)
{
	if(IsCountPlayersTeam() > 4)
		SetWitchHealth(Witchid, RoundFloat(((IsCountPlayersTeam() - 4) * g_iWitchHealth + g_iWitchBasics) * Multiples), sName);
	else
		SetWitchHealth(Witchid, RoundFloat(g_iWitchBasics * Multiples), sName);
}

void SetWitchHealth(int Witchid, int iHealth, char[] sName)
{
	//这里使用下一帧显示提示.
	DataPack hPack = new DataPack();
	hPack.WriteCell(Witchid);
	hPack.WriteString(sName);
	RequestFrame(IsWitchidPrint, hPack);
	SetClientHealth(Witchid, iHealth);
}

void IsWitchidPrint(DataPack hPack)
{
	hPack.Reset();
	char sName[32];
	int  Witchid = hPack.ReadCell();
	hPack.ReadString(sName, sizeof(sName));
	if(IsValidEdict(Witchid))
		PrintToChatAll("\x04[提示]\x03%s\x05出现\x04,\x05难度\x04:\x03%s\x04,\x05总共\x03%d\x05名幸存者,血量\x04:\x03%d", GetWitchName(Witchid), sName, IsCountPlayersTeam(), GetEntProp(Witchid, Prop_Data, "m_iMaxHealth"));//聊天窗提示.
	delete hPack;
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iTankSwitch == 0)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsValidTank(client))
	{
		EmitSoundToAll(TankSound);//给所有玩家播放声音.
		for (int i = 0; i < iArray; i++)
			if (StrEqual(GetGameDifficulty(), g_sDifficultyCode[i], false))
				SetTankHealth(client, g_fMultiples[0][i] == 0 ? 1.0 : g_fMultiples[0][i], g_sDifficultyName[i]);
	}
}

void SetTankHealth(int client, float Multiples, char[] sName)
{
	//这里使用下一帧显示提示.
	DataPack hPack = new DataPack();
	hPack.WriteCell(client);
	hPack.WriteString(sName);
	RequestFrame(IsTankPrint, hPack);
	if(IsCountPlayersTeam() > 4)
		SetClientHealth(client, RoundFloat(((IsCountPlayersTeam() - 4) * g_iTankHealth + g_iTankBasics) * Multiples));
	else
		SetClientHealth(client, RoundFloat(g_iTankBasics * Multiples));
}

void SetClientHealth(int client, int iHealth)
{
	SetEntProp(client, Prop_Data, "m_iHealth", iHealth);
	SetEntProp(client, Prop_Data, "m_iMaxHealth", iHealth);
}

void IsTankPrint(DataPack hPack)
{
	hPack.Reset();
	char sName[32];
	int  client = hPack.ReadCell();
	hPack.ReadString(sName, sizeof(sName));
	if(IsValidTank(client) && g_iTankPrompt != 0)
	{
		if(g_iTankPrompt & PrintChat)
			PrintToChatAll("\x04[提示]\x03坦克%s\x05出现\x04,\x05难度\x04:\x03%s\x04,\x05总共\x03%d\x05名幸存者,血量\x04:\x03%d", GetSurvivorName(client, true), sName, IsCountPlayersTeam(), GetEntProp(client, Prop_Data, "m_iMaxHealth"));//聊天窗提示.
		if(g_iTankPrompt & PrintHint)
			PrintHintTextToAll("坦克%s出现,难度:%s ,总共%d名幸存者,血量:%d", GetSurvivorName(client, false), sName, IsCountPlayersTeam(), GetEntProp(client, Prop_Data, "m_iMaxHealth"));//屏幕中下提示.
	}
	delete hPack;
}

char[] GetWitchName(int iWitchid)
{
	char clName[32];
	if(GetWitchNumber(iWitchid) == 0) 
		strcopy(clName, sizeof(clName), "女巫");
	else
		FormatEx(clName, sizeof(clName), "女巫(%d)", GetWitchNumber(iWitchid));
	
	return clName;
}

char[] GetSurvivorName(int client, bool bPromptType)
{
	char sName[32];
	if (!IsFakeClient(client))
		FormatEx(sName, sizeof(sName), "%s%s", !bPromptType ? "" : "\x04", sName);
	else
	{
		GetClientName(client, sName, sizeof(sName));
		SplitString(sName, "Tank", sName, sizeof(sName));
	}
	return sName;
}

char[] GetGameDifficulty()
{
	char sGameDifficulty[32];
	GetConVarString(FindConVar("z_difficulty"), sGameDifficulty, sizeof(sGameDifficulty));
	return sGameDifficulty;
}

stock char[] GetDifficultyName()
{
	char sDifficultyName[32];
	for (int i = 0; i < sizeof(g_sDifficultyCode); i++)
		if (StrEqual(GetGameDifficulty(), g_sDifficultyCode[i], false))
			strcopy(sDifficultyName, sizeof(sDifficultyName), g_sDifficultyName[i]);
	return sDifficultyName;
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock bool IsValidTank(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(client);
}

int IsCountPlayersTeam()
{
	int iCount;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
			iCount++;
	
	return iCount;
}