#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>

bool g_bIsPaused = false;

Handle g_hPausable;

int iCountdown;

Handle CountdownTimer = null;

public void OnPluginStart()
{
	RegConsoleCmd("sm_pause", Command_SMForcePause, "管理员强制暂停游戏,再次输入指令开始游戏.");
	
	g_hPausable = FindConVar("sv_pausable");
	SetConVarInt(g_hPausable, 0);
	
	HookEvent("round_end", Event_RoundEnd);//回合结束.
}

//回合结束.
public void Event_RoundEnd(Event event, const char [] name, bool dontBroadcast)
{
	OnMapEnd();
}

//地图结束.
public void OnMapEnd()
{
	g_bIsPaused = false;
	delete CountdownTimer;
}

//地图开始.
public void OnMapStart()
{
	g_bIsPaused = false;
	
	SetConVarInt(g_hPausable, 1);
	ServerCommand("unpause");
	SetConVarInt(g_hPausable, 0);
}

public Action Command_SMForcePause(int client, int args)
{
	if(bCheckClientAccess(client))
	{
		if(CountdownTimer == null)
		{
			if (g_bIsPaused)
			{
				g_bIsPaused = false;
				PrintToChatAll("\x04[提示]\x05游戏被管理员取消暂停.");
				iCountdown = 5;
				delete CountdownTimer;
				CountdownTimer = CreateTimer(1.0, UnpauseCountdown, client, TIMER_REPEAT);
			}
			else
			{
				g_bIsPaused = true;
				PrintToChatAll("\x04[提示]\x05游戏已经被管理员暂停.");
				Pause(client);
			}
		}
		else
			PrintToChatAll("\x04[提示]\x05当前已存在计时器.");
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

public Action UnpauseCountdown(Handle timer, any client)
{
	if(iCountdown == 0)
	{
		PrintHintTextToAll("→ 游戏继续 ←");
		PrintToChatAll("\x04[提示]\x05游戏继续.");
		iCountdown = 5;
		Unpause(client);
		CountdownTimer = null;
		return Plugin_Stop;
	}
	else if (iCountdown == 5)
	{
		PrintToChatAll("\x04[提示]\x05游戏将在\x03%d秒\x05之后开始.", iCountdown);
		iCountdown--;
		return Plugin_Continue;
	}
	else
	{
		PrintToChatAll("\x04[提示]\x05游戏开始还剩\x03%d\x05秒.", iCountdown);
		iCountdown--;
		return Plugin_Continue;
	}
}

//暂停游戏.
void Pause(int client)
{
	SetConVarInt(g_hPausable, 1);
	FakeClientCommand(client, "setpause");
	SetConVarInt(g_hPausable, 0);
}

//继续游戏.
void Unpause(int client)
{
	SetConVarInt(g_hPausable, 1);
	FakeClientCommand(client, "unpause");
	SetConVarInt(g_hPausable, 0);
}
