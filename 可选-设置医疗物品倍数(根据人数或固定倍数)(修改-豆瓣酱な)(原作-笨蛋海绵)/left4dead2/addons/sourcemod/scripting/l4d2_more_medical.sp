#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define lianjie		"buttons/button11.wav"//玩家连接时播放的声音.
#define tuichu		"buttons/button4.wav"//玩家退出时播放的声音.


int supply;
int medical;

int usermnums;

int l4d2_player_num = 0;

bool l4d2_more_medical;
bool l4d2_more_medical_PutIn;

bool l4d2_more_medical_usermnums = false;

ConVar l4d2_supply;
ConVar l4d2_medical;

public Plugin myinfo =
{
	name = "多倍医疗补给.",
	author = "笨蛋海绵",
	description = "多倍医疗补给.",
	version = "5.0.0",
	url = "QQ群：133102253"
};

public void OnPluginStart()   
{
	RegConsoleCmd("sm_mmn", Command_mmn, "设置补给倍数.");
	
	l4d2_supply		= CreateConVar("l4d2_more_enabled_Supply",	"1", "玩家连接或退出时根据人数设置医疗物品倍数? (输入指令 !mmn 设置医疗物品倍数) 0=禁用, 1=启用, 2=只显示玩家连接和退出提示.", FCVAR_NOTIFY);
	l4d2_medical	= CreateConVar("l4d2_more_enabled_medical",	"2", "设置医疗物品的固定倍数(l4d2_more_enabled_Supply = 2 时这里设置倍数才会生效,使用指令更改倍数后这里的值失效).", FCVAR_NOTIFY);
	l4d2_supply.AddChangeHook(l4d2ConVarChanged);
	l4d2_medical.AddChangeHook(l4d2ConVarChanged);
	HookEvent("round_start", Event_RoundStart);//回合开始.
	HookEvent("round_end", Event_RoundEnd);//回合结束.
	HookEvent("player_left_start_area", Event_playerleftstartarea);//玩家离开安全区.

	AutoExecConfig(true, "l4d2_more_medical");//生成指定文件名的CFG.
}

public Action Command_mmn(int client, int args)
{
	if(bCheckClientAccess(client))
	{
		switch (supply)
		{
			case 0:
				PrintToChat(client, "\x04[提示]\x05多倍医疗物品补给和玩家连接离开提示已禁用,请在CFG中设为1或2启用.");
			case 1:
				PrintToChat(client, "\x04[提示]\x05当前为根据人数设置医疗物品倍数,设置为只显示玩家连接或离开时才能使用指令更改倍数.");
			case 2:
				DisplaySLMOREMenu(client);
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}

void DisplaySLMOREMenu(int client)
{
	char namelist[32];
	char nameno[4];
	Handle menu = CreateMenu(MORESLMenuHandler);
	SetMenuTitle(menu, "设置补给倍数:");
	
	int i = 1;
	while (i <= 12)
	{
		Format(namelist, sizeof(namelist), "%d", i);
		Format(nameno, sizeof(nameno), "%i", i);
		AddMenuItem(menu, nameno, namelist);
		i++;
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MORESLMenuHandler(Handle menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char clientinfos[12];
		GetMenuItem(menu, itemNum, clientinfos, sizeof(clientinfos));
		int userids = StringToInt(clientinfos);
		usermnums = userids;
		l4d2_UpdateEntCount(usermnums);
		PrintToChatAll("\x04[提示]\x05更改医疗补给倍数为\x04:\x03%i\x05倍.", usermnums);
		l4d2_more_medical_usermnums = true;
	}
	return 0;
}

//地图开始
public void OnMapStart()
{	
	l4d2_player_num = 0;
	l4d2_cvar_more_medical();
	l4d2_more_medical = false;
	l4d2_more_medical_PutIn = false;
}

public void l4d2ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	l4d2_cvar_more_medical();
}

void l4d2_cvar_more_medical()
{
	supply = l4d2_supply.IntValue;
	medical = l4d2_medical.IntValue;
}

//玩家离开安全区.
public void Event_playerleftstartarea(Event event, const char[] name, bool dontBroadcast)
{
	switch (supply)
	{
		case 2:
		{
			if (!l4d2_more_medical_usermnums)
			{
				PrintToChatAll("\x04[提示]\x05当前医疗物品倍数为\x04:\x03%d\x05倍.", medical);
			}
			else
			{
				PrintToChatAll("\x04[提示]\x05当前医疗物品倍数为\x04:\x03%d\x05倍.", usermnums);
			}
		}
	}
}

//玩家连接成功.
public void OnClientPostAdminCheck(int client)
{
	if (supply == 0)
		return;
	
	if(IsFakeClient(client))
		return;
	
	if (l4d2_more_medical_usermnums && supply == 1)
	{
		usermnums = medical;
		l4d2_more_medical_usermnums = false;
	}
	if(!l4d2_more_medical_PutIn)
	{
		l4d2_more_medical_PutIn = true;
		CreateTimer(1.0, l4d2_more_medical_time, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

//回合结束.
public void Event_RoundEnd(Event event, const char [] name, bool dontBroadcast)
{
	if (supply == 0)
		return;
	
	if(!l4d2_more_medical)
	{
		l4d2_more_medical = true;
	}
}


//回合开始.
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (supply == 0)
		return;
	
	if(l4d2_more_medical)
	{
		l4d2_more_medical = false;
		CreateTimer(1.0, l4d2_more_medical_time, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

//回合开始或玩家连接成功.
public Action l4d2_more_medical_time(Handle timer)
{
	if (supply == 0)
		return Plugin_Stop;
	
	int connectnum = GetAllPlayerCount();
	int connectnum1 = GetConnectingPlayerNum(false);
	int connectnum2 = connectnum + connectnum1;
	
	switch (supply)
	{
		case 1:
		{
			switch (connectnum2)
			{
				case 1,2,3,4:
				{
					l4d2_UpdateEntCount(1);
				}
				case 5,6,7,8:
				{
					l4d2_UpdateEntCount(2);
				}
				case 9,10,11,12:
				{
					l4d2_UpdateEntCount(3);
				}
				case 13,14,15,16:
				{
					l4d2_UpdateEntCount(4);
				}
				case 17,18,19,20:
				{
					l4d2_UpdateEntCount(5);
				}
				case 21,22,23,24:
				{
					l4d2_UpdateEntCount(6);
				}
			}
		}
		case 2:
		{
			if (!l4d2_more_medical_usermnums)
			{
				if(medical < 1)
					medical = 1;
				
				l4d2_UpdateEntCount(medical);
			}
			else
			{
				if (usermnums < 1)
					usermnums = 1;
				
				l4d2_UpdateEntCount(usermnums);
			}
		}
	}
	return Plugin_Continue;
}

//玩家连接
public void OnClientConnected(int client)
{   
	if(supply == 0)
		return;
	
	if(IsFakeClient(client))
		return;

	l4d2_player_num += 1;
	int Survivor_Limit = SurvivorLimit();
	
	switch (supply)
	{
		case 1:
		{
			switch (l4d2_player_num)
			{
				case 1,2,3,4:
				{
					PrintToChatAll("\x04[提示]\x03%N\x05正在连接\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x031\x05倍医疗补给.", client, l4d2_player_num, Survivor_Limit);
					l4d2_UpdateEntCount(1);
					l4d2_lianjie(); 
				}
				case 5,6,7,8:
				{
					PrintToChatAll("\x04[提示]\x03%N\x05正在连接\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x032\x05倍医疗补给.", client, l4d2_player_num, Survivor_Limit);
					l4d2_UpdateEntCount(2);
					l4d2_lianjie(); 
				}
				case 9,10,11,12:
				{
					PrintToChatAll("\x04[提示]\x03%N\x05正在连接\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x033\x05倍医疗补给.", client, l4d2_player_num, Survivor_Limit);
					l4d2_UpdateEntCount(3);
					l4d2_lianjie(); 
				}
				case 13,14,15,16:
				{
					PrintToChatAll("\x04[提示]\x03%N\x05正在连接\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x034\x05倍医疗补给.", client, l4d2_player_num, Survivor_Limit);
					l4d2_UpdateEntCount(4);
					l4d2_lianjie(); 
				}
				case 17,18,19,20:
				{
					PrintToChatAll("\x04[提示]\x03%N\x05正在连接\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x035\x05倍医疗补给.", client, l4d2_player_num, Survivor_Limit);
					l4d2_UpdateEntCount(5);
					l4d2_lianjie(); 
				}
				case 21,22,23,24:
				{
					PrintToChatAll("\x04[提示]\x03%N\x05正在连接\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x036\x05倍医疗补给.", client, l4d2_player_num, Survivor_Limit);
					l4d2_UpdateEntCount(6);
					l4d2_lianjie(); 
				}
			}
		}
		case 2:
		{
			PrintToChatAll("\x04[提示]\x03%N\x05正在连接\x04...\x05(づˉ*ˉ)づ\x04(\x03%d\x05/\x03%d\x04)\x05.", client, l4d2_player_num, Survivor_Limit);
			l4d2_lianjie(); 
		}
	}
}

void l4d2_lianjie()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			EmitSoundToClient(i, lianjie);
	}
}

//玩家退出
public void OnClientDisconnect(int client)
{   
	if(supply == 0)
		return;
	
	if(IsFakeClient(client))
		return;
	
	l4d2_player_num -=1 ;
	int Survivor_Limit = SurvivorLimit(); 
	
	switch (supply)
	{
		case 1:
		{
			switch (l4d2_player_num)
			{
				case 1,2,3,4:
				{
					PrintToChatAll("\x04[提示]\x03%N\x05离开游戏\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x031\x05倍医疗补给.", client, l4d2_player_num, Survivor_Limit);
					l4d2_UpdateEntCount(1);
					l4d2_tuichu(); 
				}
				case 5,6,7,8:
				{
					PrintToChatAll("\x04[提示]\x03%N\x05离开游戏\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x032\x05倍医疗补给.", client, l4d2_player_num, Survivor_Limit);
					l4d2_UpdateEntCount(2);
					l4d2_tuichu(); 
				}
				case 9,10,11,12:
				{
					PrintToChatAll("\x04[提示]\x03%N\x05离开游戏\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x033\x05倍医疗补给.", client, l4d2_player_num, Survivor_Limit);
					l4d2_UpdateEntCount(3);
					l4d2_tuichu(); 
				}
				case 13,14,15,16:
				{
					PrintToChatAll("\x04[提示]\x03%N\x05离开游戏\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x034\x05倍医疗补给.", client, l4d2_player_num, Survivor_Limit);
					l4d2_UpdateEntCount(4);
					l4d2_tuichu(); 
				}
				case 17,18,19,20:
				{
					PrintToChatAll("\x04[提示]\x03%N\x05离开游戏\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x035\x05倍医疗补给.", client, l4d2_player_num, Survivor_Limit);
					l4d2_UpdateEntCount(5);
					l4d2_tuichu(); 
				}
				case 21,22,23,24:
				{
					PrintToChatAll("\x04[提示]\x03%N\x05离开游戏\x04(\x03%i\x05/\x03%d\x04)\x03,\x05更改为\x036\x05倍医疗补给.", client, l4d2_player_num, Survivor_Limit);
					l4d2_UpdateEntCount(6);
					l4d2_tuichu(); 
				}
			}
		}
		case 2:
		{
			PrintToChatAll("\x04[提示]\x03%N\x05离开游戏\x04...\x05oヾ(￣▽￣)Bye~Bye~\x04(\x03%i\x05/\x03%d\x04)\x05.", client, l4d2_player_num, Survivor_Limit);
			l4d2_tuichu(); 
		}
	}
}

void l4d2_tuichu()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			EmitSoundToClient(i, tuichu);
	}
}

int SurvivorLimit()
{
	int maxcl;
	Handle invalid = null;
	Handle downtownrun = FindConVar("l4d_maxplayers");
	Handle toolzrun = FindConVar("sv_maxplayers");
	if (downtownrun != (invalid))
	{
		int downtown = (GetConVarInt(FindConVar("l4d_maxplayers")));
		if (downtown >= 1)
		{
			maxcl = (GetConVarInt(FindConVar("l4d_maxplayers")));
		}
	}
	if (toolzrun != (invalid))
	{
		int toolz = (GetConVarInt(FindConVar("sv_maxplayers")));
		if (toolz >= 1)
		{
			maxcl = (GetConVarInt(FindConVar("sv_maxplayers")));
		}
	}
	if (downtownrun == (invalid) && toolzrun == (invalid))
	{
		maxcl = (MaxClients);
	}
	return maxcl;
}

void l4d2_UpdateEntCount(int multiple)
{
	char sMedical[32];
	IntToString(multiple, sMedical, sizeof(sMedical));
	
	//UpdateEntCount("weapon_defibrillator_spawn", sMedical);     //电击器
	UpdateEntCount("weapon_first_aid_kit_spawn", sMedical);     //医疗包
	UpdateEntCount("weapon_pain_pills_spawn", sMedical);        //止痛药
	UpdateEntCount("weapon_adrenaline_spawn", sMedical);        //肾上腺素
	//UpdateEntCount("weapon_molotov_spawn", sMedical);           //燃烧瓶
	//UpdateEntCount("weapon_vomitjar_spawn", sMedical);          //胆汁罐
	//UpdateEntCount("weapon_pipe_bomb_spawn", sMedical);         //土质炸弹
	//UpdateEntCount("weapon_melee_spawn", sMedical);             //设置所有近战的倍数
}

void UpdateEntCount(const char [] entname, const char [] count)
{
	int edict_index = FindEntityByClassname(-1, entname);
	
	while(edict_index != -1)
	{
		DispatchKeyValue(edict_index, "count", count);
		edict_index = FindEntityByClassname(edict_index, entname);
	}
}

int GetAllPlayerCount()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidPlayer(i) && !IsFakeClient(i))
		{
			count++;
		}
	}
	
	return count;
}

int GetConnectingPlayerNum(bool allowbot)
{
	int num;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsClientInGame(i))
		{
			if (!allowbot)
			{
				if (!IsFakeClient(i))
					num++;
			}
			else
				num++;
		}
	}
	
	return num;
}

bool IsValidPlayer(int client, bool AllowBot = true, bool AllowDeath = true)
{
	if (client < 1 || client > MaxClients)
		return false;
	if (!IsClientConnected(client) || !IsClientInGame(client))
		return false;
	if (!AllowBot)
	{
		if (IsFakeClient(client))
			return false;
	}
	if (!AllowDeath)
	{
		if (!IsPlayerAlive(client))
			return false;
	}	
	return true;
}
