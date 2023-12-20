#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法

#include <sourcemod>
#include <multicolors> 
#include <builtinvotes> //https://github.com/L4D-Community/builtinvotes/actions

#define PLUGIN_VERSION			"1.4-2023/6/30"
#define PLUGIN_NAME			    "match_vote"
#define DEBUG 0

public Plugin myinfo = 
{
	name = "Match Vote",
	author = "HarryPotter",
	description = "Type !match/!load/!mode to vote a new mode",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/profiles/76561198026784913/"
}

//bool g_bL4D2Version;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test == Engine_Left4Dead )
	{
		//g_bL4D2Version = false;
	}
	else if( test == Engine_Left4Dead2 )
	{
		//g_bL4D2Version = true;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

#define MATCHMODES_PATH		"configs/Match_votes.txt"

#define CVAR_FLAGS                    FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION     FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

#define TEAM_SPECTATOR		1
#define TEAM_SURVIVOR		2
#define TEAM_INFECTED		3

#define VOTE_TIME 20

ConVar g_hCvarEnable, g_hCvarVoteDealy, g_hCvarVoteRequired;
bool g_bCvarEnable;
int g_iCvarVoteDealy, g_iCvarVoteRequired;

Handle g_hMatchVote, VoteDelayTimer;
KeyValues g_hModesKV;
char g_sCfg[128];
int g_iLocalVoteDelay;
bool g_bVoteInProgress;

public void OnPluginStart()
{
	g_hCvarEnable 		    = CreateConVar( PLUGIN_NAME ... "_enable",       "1",   "0=Plugin off, 1=Plugin on.", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hCvarVoteDealy        = CreateConVar( PLUGIN_NAME ... "_delay",        "15",  "Delay to start another vote after vote ends.", CVAR_FLAGS, true, 1.0);
	g_hCvarVoteRequired     = CreateConVar( PLUGIN_NAME ... "_required",     "1",   "Numbers of real survivor and infected player required to start a match vote.", CVAR_FLAGS, true, 1.0);
	CreateConVar(                           PLUGIN_NAME ... "_version",      PLUGIN_VERSION, PLUGIN_NAME ... " Plugin Version", CVAR_FLAGS_PLUGIN_VERSION);
	AutoExecConfig(true,                    "match_vote");

	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarVoteDealy.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarVoteRequired.AddChangeHook(ConVarChanged_Cvars);

	RegConsoleCmd("sm_votes", MatchRequest);
	RegConsoleCmd("sm_v", MatchRequest);
	RegAdminCmd("sm_restartmap", RestartMap, ADMFLAG_ROOT, "重启当前地图");
}

public void OnPluginEnd()
{
	StopVote();
	delete VoteDelayTimer;
}

//Cvars-------------------------------

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
	g_bCvarEnable = g_hCvarEnable.BoolValue;
	g_iCvarVoteDealy = g_hCvarVoteDealy.IntValue;
	g_iCvarVoteRequired = g_hCvarVoteRequired.IntValue;
}

//Sourcemod API Forward-------------------------------

public void OnMapStart()
{
    StopVote();
    g_bVoteInProgress = false;
}

public void OnMapEnd()
{
	g_iLocalVoteDelay = 0;
	delete VoteDelayTimer;
}

public void OnConfigsExecuted()
{
	delete g_hModesKV;

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), MATCHMODES_PATH);
	if( !FileExists(sPath) )
	{
		SetFailState("File Not Found: %s", sPath);
		return;
	}
	
	g_hModesKV = new KeyValues("Match_votes");
	if ( !g_hModesKV.ImportFromFile(sPath) )
	{
		SetFailState("File Format Not Correct: %s", sPath);
		delete g_hModesKV;
		return;
	}
}

//Commands-------------------------------

Action MatchRequest(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("[TS] This command cannot be used by server.");
		return Plugin_Handled;
	}

	if (g_bCvarEnable == false)
	{
		ReplyToCommand(client, "This command is disable.");
		return Plugin_Handled;
	}

	//show main menu
	MatchModeMenu(client);

	return Plugin_Handled;
}

//Menu-------------------------------

void MatchModeMenu(int client)
{
	if(g_hModesKV == null) return;
	g_hModesKV.Rewind();

	Menu hMenu = new Menu(MatchModeMenuHandler);
	hMenu.SetTitle("选择配置:");
	static char sBuffer[64];
	if (g_hModesKV.GotoFirstSubKey())
	{
		do
		{
			g_hModesKV.GetSectionName(sBuffer, sizeof(sBuffer));
			hMenu.AddItem(sBuffer, sBuffer);
		} while (g_hModesKV.GotoNextKey());
	}
	hMenu.Display(client, 20);
}

int MatchModeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if(g_hModesKV == null) return 0;
		g_hModesKV.Rewind();
		
		static char sInfo[64], sBuffer[64];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		if (g_hModesKV.JumpToKey(sInfo) && g_hModesKV.GotoFirstSubKey())
		{
			Menu hMenu = new Menu(ConfigsMenuHandler);
			Format(sBuffer, sizeof(sBuffer), "投票-%s", sInfo);
			hMenu.SetTitle(sBuffer);

			do
			{
				g_hModesKV.GetSectionName(sInfo, sizeof(sInfo));
				g_hModesKV.GetString("name", sBuffer, sizeof(sBuffer));
				hMenu.AddItem(sInfo, sBuffer);
			} while (g_hModesKV.GotoNextKey());

			hMenu.Display(param1, 20);
		}
		else
		{
			CPrintToChat(param1, "No configs for such mode were found.");
			MatchModeMenu(param1);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

int ConfigsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		static char sInfo[128], sBuffer[64];
		menu.GetItem(param2, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));
		if (StartMatchVote(param1, sInfo, sBuffer))
		{
			strcopy(g_sCfg, sizeof(g_sCfg), sInfo);
			CPrintToChatAll("杂鱼♥{lightgreen}%N{default} 发起了投票♥: {green}%s", param1, sBuffer);
			return 0;
		}

		MatchModeMenu(param1);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		MatchModeMenu(param1);
	}

	return 0;
}

//Vote-------------------------------

bool StartMatchVote(int client, const char[] cfgpatch, const char[] cfgname)
{
	static char sBuffer[256];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "../../cfg/%s.cfg", cfgpatch);
	if (!FileExists(sBuffer))
	{
		CPrintToChat(client, "[{olive}!]{default}文件 {green}%s{default} 不存在", sBuffer);
		return false;
	}

	if (GetClientTeam(client) == TEAM_SPECTATOR)
	{
		CPrintToChat(client, "旁观杂鱼♥不给投票~");
		return false;
	}

	if (g_bVoteInProgress || IsBuiltinVoteInProgress())
	{
		CPrintToChat(client, "死杂鱼♥没看到正在进行的投票吗?");
		return false;
	}

	if (VoteDelayTimer != null)
	{
		CPrintToChat(client, "杂鱼♥再等{green}%d{default}才能射精呢", g_iLocalVoteDelay);

		return false;
	}

	int iNumPlayers;
	int[] iPlayers = new int[MaxClients+1];
	//list of non-spectators players
	for (int i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == TEAM_SPECTATOR))
		{
			continue;
		}

		iPlayers[iNumPlayers++] = i;
	}

	if (iNumPlayers < g_iCvarVoteRequired)
	{
		CPrintToChat(client, "Match vote cannot be started. Not enough {green}%d{default} players.", g_iCvarVoteRequired);
		return false;
	}

	g_hMatchVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

	FormatEx(sBuffer, sizeof(sBuffer), "投票 '%s' 配置?", cfgname);
	SetBuiltinVoteArgument(g_hMatchVote, sBuffer);
	SetBuiltinVoteInitiator(g_hMatchVote, client);
	SetBuiltinVoteResultCallback(g_hMatchVote, VoteResultHandler);
	DisplayBuiltinVote(g_hMatchVote, iPlayers, iNumPlayers, VOTE_TIME);
	FakeClientCommand(client, "Vote Yes");

	return true;
}

int VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
    switch (action)
    {
        case BuiltinVoteAction_End:
        {
            delete vote;
            g_hMatchVote = null;
            VoteEnd();
        }
        case BuiltinVoteAction_Cancel:
        {

        }
    }

    return 0;
}

void VoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    for (int i=0; i<num_items; i++)
    {
        if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				DisplayBuiltinVotePass(vote, "配置加载中♥");
				CPrintToChatAll("[{olive}Votes{default}] 配置 {green}3{default} 秒后执行");
				
				CreateTimer(3.0, Timer_VotePass, _, TIMER_FLAG_NO_MAPCHANGE);

				return;
			}
        }
    }

    DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

Action Timer_VotePass(Handle timer, int client)
{
	ServerCommand("exec %s", g_sCfg);

	return Plugin_Continue;
}

Action Timer_VoteDelay(Handle timer, any client)
{
    g_iLocalVoteDelay--;

    if(g_iLocalVoteDelay<=0)
    {
        VoteDelayTimer = null;
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

//Others-------------------------------

void StopVote()
{
    if(g_hMatchVote!=null)
    {
        CancelBuiltinVote();
    }

    g_bVoteInProgress = false;
}

void VoteEnd()
{
    g_iLocalVoteDelay = g_iCvarVoteDealy;
    delete VoteDelayTimer;
    VoteDelayTimer = CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT);

    g_bVoteInProgress = false;
}

//重启地图
public Action RestartMap(int client,int args)
{
	PrintHintTextToAll("地图将在3秒后重启");
	CreateTimer(3.0, Timer_Restartmap);
	return Plugin_Handled;
}
public Action Timer_Restartmap(Handle timer)
{
	char mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));
	ServerCommand("changelevel %s", mapname);
	return Plugin_Handled;
}