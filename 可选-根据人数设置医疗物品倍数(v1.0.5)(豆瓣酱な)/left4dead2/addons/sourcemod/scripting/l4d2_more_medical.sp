#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#define CVAR_FLAGS		FCVAR_NOTIFY
#define PLUGIN_VERSION	"1.0.5"

//玩家连接时播放的声音.
#define IsConnected		"buttons/button11.wav"
//玩家离开时播放的声音.
#define IsDisconnect	"buttons/button4.wav"

#define	SurvivorsSound		(1 << 0)
#define SurvivorsMultiple	(1 << 1)
#define SurvivorsPrompt		(1 << 2)

//对抗模式.
char g_sModeVersus[][] = 
{
	"versus",		//对抗模式
	"teamversus ",	//团队对抗
	"scavenge",		//团队清道夫
	"teamscavenge",	//团队清道夫
	"community3",	//骑师派对
	"community6",	//药抗模式
	"mutation11",	//没有救赎
	"mutation12",	//写实对抗
	"mutation13",	//清道肆虐
	"mutation15",	//生存对抗
	"mutation18",	//失血对抗
	"mutation19"	//坦克派对?
};

//单人模式.
char g_sModeSingle[][] = 
{
	"mutation1", //孤身一人
	"mutation17" //孤胆枪手
};

bool g_bPlayerPrompt, g_bMoreMedical, g_bMedicalCheck;

int g_iPlayerNumber;

int    g_iMoreMedical;
ConVar g_hMoreMedical;

public Plugin myinfo = 
{
	name 			= "l4d2_more_medical",
	author 			= "豆瓣酱な",
	description 	= "根据玩家人数设置医疗物品倍数.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public void OnPluginStart()
{
	g_hMoreMedical = CreateConVar("l4d2_more_medical", "7", "把需要启用的功能数字相加. 0=禁用, 1=声音, 2=倍数, 4=提示.", CVAR_FLAGS);
	g_hMoreMedical.AddChangeHook(ConVarChanged);
	AutoExecConfig(true, "l4d2_more_medical");//生成指定文件名的CFG.
	HookEvent("round_end", Event_RoundEnd);//回合结束.
	HookEvent("round_start", Event_RoundStart);//回合开始.
}

//地图开始
public void OnMapStart()
{	
	GetCvarsMedical();
	g_iPlayerNumber = 0;
	g_bMoreMedical = false;
	g_bMedicalCheck = false;
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvarsMedical();
}

void GetCvarsMedical()
{
	g_iMoreMedical = g_hMoreMedical.IntValue;
}

//玩家连接成功.
public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;
	
	if(!g_bMedicalCheck)
	{
		g_bMedicalCheck = true;
		DataPack hPack;
		CreateDataTimer(1.0, IsCreateMoreMedicalTimer, hPack, TIMER_FLAG_NO_MAPCHANGE);
		hPack.WriteCell(false);
	}
}

//玩家连接
public void OnClientConnected(int client)
{   
	if(IsFakeClient(client))
		return;

	g_iPlayerNumber += 1;
	IsPlayerMultiple(true, true, true, client, g_iPlayerNumber, GetMaxPlayers());
}

//玩家退出
public void OnClientDisconnect(int client)
{   
	if(IsFakeClient(client))
		return;
	
	g_iPlayerNumber -=1 ;
	IsPlayerMultiple(true, false, true, client, g_iPlayerNumber, GetMaxPlayers());
}

//回合结束.
public void Event_RoundEnd(Event event, const char [] name, bool dontBroadcast)
{
	g_bMoreMedical = true;
}

//回合开始.
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bMoreMedical)
	{
		g_bMoreMedical = false;
		DataPack hPack;
		CreateDataTimer(1.0, IsCreateMoreMedicalTimer, hPack, TIMER_FLAG_NO_MAPCHANGE);
		hPack.WriteCell(true);
	}
}

//回合开始或玩家连接成功.
public Action IsCreateMoreMedicalTimer(Handle Timer, DataPack hPack)
{
	hPack.Reset();
	bool g_bMoreCheck = hPack.ReadCell();
	IsPlayerMultiple(false, false, g_bMoreCheck, 0, GetAllPlayerCount(), GetMaxPlayers());
	return Plugin_Continue;
}

void IsPlayerMultiple(bool g_bPrompt, bool g_bContent, bool g_bMoreCheck, int client, int g_iClientNumber, int g_iSurvivorLimit)
{
	switch (g_iClientNumber)
	{
		case 1,2,3,4:
			IsUpdateEntCount(client, 1, g_bPrompt, g_bContent, g_bMoreCheck, g_iClientNumber, g_iSurvivorLimit);
		case 5,6,7,8:
			IsUpdateEntCount(client, 2, g_bPrompt, g_bContent, g_bMoreCheck, g_iClientNumber, g_iSurvivorLimit);
		case 9,10,11,12:
			IsUpdateEntCount(client, 3, g_bPrompt, g_bContent, g_bMoreCheck, g_iClientNumber, g_iSurvivorLimit);
		case 13,14,15,16:
			IsUpdateEntCount(client, 4, g_bPrompt, g_bContent, g_bMoreCheck, g_iClientNumber, g_iSurvivorLimit);
		case 17,18,19,20:
			IsUpdateEntCount(client, 5, g_bPrompt, g_bContent, g_bMoreCheck, g_iClientNumber, g_iSurvivorLimit);
		case 21,22,23,24:
			IsUpdateEntCount(client, 6, g_bPrompt, g_bContent, g_bMoreCheck, g_iClientNumber, g_iSurvivorLimit);
	}
}

void IsUpdateEntCount(int client, int g_Multiple, bool g_bPrompt, bool g_bContent, bool g_bMoreCheck, int g_iClientNumber, int g_iSurvivorLimit)
{
	if(g_iMoreMedical == 0)
		return;

	char g_sMedical[32];
	IntToString(g_Multiple, g_sMedical, sizeof(g_sMedical));
	g_bPlayerPrompt = false;

	if(g_iMoreMedical & SurvivorsSound)
	{
		if(g_bPrompt)
			IsPlaySound(g_bContent);//播放声音.
	}
	if(g_iMoreMedical & SurvivorsMultiple)
	{
		g_bPlayerPrompt = true;
		SetUpdateEntCount("weapon_defibrillator_spawn", g_sMedical);	//电击器
		SetUpdateEntCount("weapon_first_aid_kit_spawn", g_sMedical);	//医疗包
		SetUpdateEntCount("weapon_pain_pills_spawn", g_sMedical);		//止痛药
		//SetUpdateEntCount("weapon_molotov_spawn", g_sMedical);		//燃烧瓶
		//SetUpdateEntCount("weapon_vomitjar_spawn", g_sMedical);		//胆汁罐
		//SetUpdateEntCount("weapon_pipe_bomb_spawn", g_sMedical);		//土质炸弹
		//SetUpdateEntCount("weapon_melee_spawn", g_sMedical);			//设置所有近战的倍数
	}
	if(g_iMoreMedical & SurvivorsPrompt && g_bMoreCheck)
	{
		if(g_bPrompt)
			if(!g_bPlayerPrompt)
				PrintToChatAll("\x04[提示]\x03%N\x05%s\x04(\x03%i\x05/\x03%d\x04)\x03...\x04%s", client, g_bContent ? "正在连接" : "离开游戏", g_iPlayerNumber, g_iSurvivorLimit, g_bContent ? "(づˉ*ˉ)づ" : "╮(๑•́ ₃•̀๑)╭");
			else
				PrintToChatAll("\x04[提示]\x03%N\x05%s\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x03%s\x05倍医疗物品.", client, g_bContent ? "正在连接" : "离开游戏", g_iPlayerNumber, g_iSurvivorLimit, g_sMedical);
		else
			PrintToChatAll("\x04[提示]\x05当前人数为\x03:\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x03%s\x05倍医疗物品.", g_iClientNumber, g_iSurvivorLimit, g_sMedical);
	}
}

//播放声音.
void IsPlaySound(bool g_bContent)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			EmitSoundToClient(i, g_bContent ? IsConnected : IsDisconnect);
}

//设置物品倍数.
void SetUpdateEntCount(const char [] entname, const char [] count)
{
	int edict_index = FindEntityByClassname(-1, entname);
	
	while(edict_index != -1)
	{
		DispatchKeyValue(edict_index, "count", count);
		edict_index = FindEntityByClassname(edict_index, entname);
	}
}

//返回最大人数.
int GetMaxPlayers()
{
	static Handle g_hMaxPlayers;
	g_hMaxPlayers = FindConVar("sv_maxplayers");
	if (g_hMaxPlayers == null)
		return GetDefaultNumber();
		
	int g_iMaxPlayers = GetConVarInt(g_hMaxPlayers);
	if(g_iMaxPlayers <= -1)
		return GetDefaultNumber();
	
	return g_iMaxPlayers;
}

int GetDefaultNumber()
{
	for (int i = 0; i < sizeof(g_sModeVersus); i++)
		if(strcmp(GetGameMode(), g_sModeVersus[i]) == 0)
			return 8;
	for (int i = 0; i < sizeof(g_sModeSingle); i++)
		if(strcmp(GetGameMode(), g_sModeSingle[i]) == 0)
			return 1;
	return 4;
}

char[] GetGameMode()
{
	char g_sMode[32];
	GetConVarString(FindConVar("mp_gamemode"), g_sMode, sizeof(g_sMode));
	return g_sMode;
}

//获取玩家数量.
int GetAllPlayerCount()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && !IsFakeClient(i))
				count++;
	
	return count;
}