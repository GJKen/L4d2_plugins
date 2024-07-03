#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2_nativevote>			// https://github.com/fdxx/l4d2_nativevote 0.4
#include <l4d2_source_keyvalues>	// https://github.com/fdxx/l4d2_source_keyvalues 0.3
#include <colors>
#include "savelog.sp"

#define VERSION "1.0"
#define COMMAND_MAX_LENGTH 511

#define TEAMFLAGS_SPEC	2
#define TEAMFLAGS_SUR	4
#define TEAMFLAGS_INF	8
#define TEAMFLAGS_DEFAULT	(TEAMFLAGS_SPEC|TEAMFLAGS_SUR|TEAMFLAGS_INF)

enum ConfigType
{
	Type_NotFound = 0,
	Type_ServerCommand,
	Type_ClientCommand,
	Type_ExternalVote,
	Type_CheatCommand,
}

enum struct ConfigData
{
	ConfigType type;
	int menuTeamFlags;
	int voteTeamFlags;
	bool bAdminOneVotePassed;
	bool bAdminOneVoteAgainst;
	char description[128];
	char cmd[COMMAND_MAX_LENGTH];
}

SourceKeyValues
	g_kvSelect[MAXPLAYERS+1],
	g_kvRoot;

ConVar g_cvVoteFilePath, g_cvAdminTeamFlags;
ConfigData g_cfgData[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "L4D2 Config Vote",
	author = "fdxx, kita",
	version = VERSION,
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("l4d2_config_vote");
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d2_config_vote_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvVoteFilePath = CreateConVar("l4d2_config_vote_path", "data/vote.kv", "Vote config file path");
	g_cvAdminTeamFlags = CreateConVar("l4d2_config_vote_adminteamflags", "1", "Admin bypass TeamFlags.");
	g_cvVoteFilePath.AddChangeHook(OnCvarChanged);
}

void OnCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	Init();
}

public void OnConfigsExecuted()
{
	static bool shit;
	if (shit) return;
	shit = true;

	Init();
	RegAdminCmdEx("sm_votecfg_reload", Cmd_Reload, ADMFLAG_ROOT, "Reload config file.");
	RegConsoleCmdEx("sm_v", Cmd_Vote);
	RegConsoleCmdEx("sm_vt", Cmd_Vote);
	RegConsoleCmdEx("sm_votes", Cmd_Vote);
	RegConsoleCmdEx("sm_si", Cmd_Vote);
}

Action Cmd_Reload(int client, int args)
{
	Init();
	return Plugin_Handled;
}

Action Cmd_Vote(int client, int args)
{
	ShowMenu(client, g_kvRoot, false);
	return Plugin_Handled;
}

void ShowMenu(int client, SourceKeyValues kv, bool bBackButton = true)
{
	if (client < 1 || !IsClientInGame(client) || IsFakeClient(client))
		return;
	
	if (!kv)
		ThrowError("Invalid SourceKeyValues pointer!");

	g_kvSelect[client] = kv;

	char title[128], display[128], sKv[16];
	kv.GetName(title, sizeof(title));

	Menu menu = new Menu(MenuHandlerCB);
	menu.SetTitle("%s:", title);
	
	for (SourceKeyValues sub = kv.GetFirstTrueSubKey(); sub; sub = sub.GetNextTrueSubKey())
	{
		if (!IsValidTeamFlags(client, sub.GetInt("MenuTeamFlags", TEAMFLAGS_DEFAULT)))
			continue;
		
		sub.GetName(display, sizeof(display));
		IntToString(view_as<int>(sub), sKv, sizeof(sKv));
		menu.AddItem(sKv, display);
	}

	menu.ExitBackButton = bBackButton;
	menu.Display(client, 20);
}

int MenuHandlerCB(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sKv[16];
			menu.GetItem(itemNum, sKv, sizeof(sKv));

			SourceKeyValues kv = view_as<SourceKeyValues>(StringToInt(sKv));
			ConfigType type = GetConfigType(kv);

			switch (type)
			{
				case Type_NotFound:
				{
					ShowMenu(client, kv);
				}
				case Type_ExternalVote:
				{
					char cmd[COMMAND_MAX_LENGTH];
					kv.GetString("Command", cmd, sizeof(cmd));
					ClientCommand(client, "%s", cmd);
				}
				default:
				{
					StartVote(client, kv, type);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
			{
				SourceKeyValues kv = GetPreviousNode(g_kvRoot, g_kvSelect[client]);
				ShowMenu(client, kv, kv != g_kvRoot);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void StartVote(int client, SourceKeyValues kv, ConfigType type)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		CPrintToChat(client, "<{green}提示{default}>{blue}投票正在进行中, 暂不能发起新的投票.");
		return;
	}

	g_cfgData[client].type = type;
	g_cfgData[client].voteTeamFlags = kv.GetInt("VoteTeamFlags", TEAMFLAGS_DEFAULT);
	g_cfgData[client].bAdminOneVotePassed = kv.GetInt("AdminOneVotePassed", 1) > 0;
	g_cfgData[client].bAdminOneVoteAgainst = kv.GetInt("AdminOneVoteAgainst", 1) > 0;
	kv.GetString("Description", g_cfgData[client].description, sizeof(g_cfgData[].description));
	kv.GetString("Command", g_cfgData[client].cmd, sizeof(g_cfgData[].cmd));
	
	L4D2NativeVote vote = L4D2NativeVote(Vote_Handler);
	vote.SetDisplayText("%s", g_cfgData[client].description);
	vote.Initiator = client;

	int iPlayerCount = 0;
	int[] iClients = new int[MaxClients];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (!IsValidTeamFlags(i, g_cfgData[client].voteTeamFlags))
				continue;

			iClients[iPlayerCount++] = i;
		}
	}

	if (!vote.DisplayVote(iClients, iPlayerCount, 20))
		LogMessage("发起投票失败");
}

void Vote_Handler(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	switch (action)
	{
		case VoteAction_Start:
		{
			CPrintToChatAll("<{green}提示{default}> {blue}%N{default}发起了一个投票 {green}%s", param1, g_cfgData[vote.Initiator].description);
			LogTo("%N 投票执行 %s ", param1, g_cfgData[vote.Initiator].description);
		}
		case VoteAction_PlayerVoted:
		{
			if (!CheckCommandAccess(param1, "sm_admin", ADMFLAG_ROOT))
				return;
			
			if (param2 == VOTE_YES && g_cfgData[vote.Initiator].bAdminOneVotePassed)
			{
				vote.YesCount = vote.PlayerCount;
				vote.NoCount = 0;
			}
			else if (param2 == VOTE_NO && g_cfgData[vote.Initiator].bAdminOneVoteAgainst)
			{
				vote.YesCount = 0;
				vote.NoCount = vote.PlayerCount;
			}
		}
		case VoteAction_End:
		{
			if (vote.YesCount > vote.PlayerCount/2)
			{
				vote.SetPass("加载中...");

				switch (g_cfgData[vote.Initiator].type)
				{
					case Type_ServerCommand:
					{
						ServerCommand("%s", g_cfgData[vote.Initiator].cmd);
					}
					case Type_ClientCommand:
					{
						if (IsClientInGame(vote.Initiator))
							ClientCommand(vote.Initiator, "%s", g_cfgData[vote.Initiator].cmd);
					}
					case Type_CheatCommand:
					{
						if (!IsClientInGame(vote.Initiator))
							return;

						char cmd[COMMAND_MAX_LENGTH], cmdArgs[COMMAND_MAX_LENGTH];

						int index = SplitString(g_cfgData[vote.Initiator].cmd, " ", cmd, sizeof(cmd));
						if (index != -1)
							strcopy(cmdArgs, sizeof(cmdArgs), g_cfgData[vote.Initiator].cmd[index]);
						else
							strcopy(cmd, sizeof(cmd), g_cfgData[vote.Initiator].cmd);

						int iFlags = GetCommandFlags(cmd);
						SetCommandFlags(cmd, iFlags & ~FCVAR_CHEAT);
						FakeClientCommand(vote.Initiator, "%s %s", cmd, cmdArgs);
						SetCommandFlags(cmd, iFlags);
					}
				}
			}
			else
				vote.SetFail();
		}
	}
}

bool IsValidTeamFlags(int client, int flags)
{
	if (g_cvAdminTeamFlags.BoolValue && CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT))
		return true;

	int team = GetClientTeam(client);
	return (flags & (1 << team)) != 0;
}

SourceKeyValues GetPreviousNode(SourceKeyValues kvRoot, SourceKeyValues kvTarget)
{
	for (SourceKeyValues sub = kvRoot.GetFirstTrueSubKey(); sub; sub = sub.GetNextTrueSubKey())
	{
		if (sub == kvTarget)
			return kvRoot;

		if (sub.GetFirstTrueSubKey())
		{
			SourceKeyValues result = GetPreviousNode(sub, kvTarget);
			if (result)
				return result;
		}
	}
	return view_as<SourceKeyValues>(0);
}

ConfigType GetConfigType(SourceKeyValues kv)
{
	char type[32];
	kv.GetString("Type", type, sizeof(type));

	if (!strcmp(type, "ServerCommand", false))
		return Type_ServerCommand;

	if (!strcmp(type, "ClientCommand", false))
		return Type_ClientCommand;

	if (!strcmp(type, "ExternalVote", false))
		return Type_ExternalVote;

	if (!strcmp(type, "CheatCommand", false))
		return Type_CheatCommand;
	
	return Type_NotFound;
}

void RegAdminCmdEx(const char[] cmd, ConCmd callback, int adminflags, const char[] description="", const char[] group="", int flags=0)
{
	if (!CommandExists(cmd))
		RegAdminCmd(cmd, callback, adminflags, description, group, flags);
	else
	{
		char pluginName[PLATFORM_MAX_PATH];
		FindPluginNameByCmd(pluginName, sizeof(pluginName), cmd);
		LogError("The command \"%s\" already exists, plugin: \"%s\"", cmd, pluginName);
	}
}

void RegConsoleCmdEx(const char[] cmd, ConCmd callback, const char[] description="", int flags=0)
{
	if (!CommandExists(cmd))
		RegConsoleCmd(cmd, callback, description, flags);
	else
	{
		char pluginName[PLATFORM_MAX_PATH];
		FindPluginNameByCmd(pluginName, sizeof(pluginName), cmd);
		LogError("The command \"%s\" already exists, plugin: \"%s\"", cmd, pluginName);
	}
}

bool FindPluginNameByCmd(char[] buffer, int maxlength, const char[] cmd)
{
	char cmdBuffer[128];
	bool result = false;
	CommandIterator iter = new CommandIterator();

	while (iter.Next())
	{
		iter.GetName(cmdBuffer, sizeof(cmdBuffer));
		if (strcmp(cmdBuffer, cmd, false))
			continue;

		GetPluginFilename(iter.Plugin, buffer, maxlength);
		result = true;
		break;
	}

	if (!result)
	{
		ConVar cvar = FindConVar(cmd);
		if (cvar)
		{
			GetPluginFilename(cvar.Plugin, buffer, maxlength);
			result = true;
		}
	}

	delete iter;
	return result;
}

void Init()
{
	if (g_kvRoot)
		g_kvRoot.deleteThis();

	char file[PLATFORM_MAX_PATH];
	char g_sVoteFile[128];
	GetConVarString(g_cvVoteFilePath, g_sVoteFile, sizeof(g_sVoteFile));
	BuildPath(Path_SM, file, sizeof(file), g_sVoteFile);

	g_kvRoot = SourceKeyValues("");
	g_kvRoot.UsesEscapeSequences(true);
	if (!g_kvRoot.LoadFromFile(file))
		SetFailState("Failed to load %s", file);
}

public void OnPluginEnd()
{
	if (g_kvRoot)
		g_kvRoot.deleteThis();
}
