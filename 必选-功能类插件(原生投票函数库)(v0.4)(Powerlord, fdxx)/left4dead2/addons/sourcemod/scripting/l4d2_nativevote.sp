#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <l4d2_nativevote>

#define VERSION "0.4"

enum struct VoteData
{
	bool bVoteInProgress;
	bool bVoteStart;
	char sDisplayText[64];
	any Value;
	char sInfoStr[512];
	int iInitiator;
	int iYesCount;
	int iNoCount;
	int iPlayerCount;
	bool bCanVote[MAXPLAYERS+1];
}

VoteData g_VoteData;
int g_iVoteController;
PrivateForward g_hFwd;
ConVar g_cvInitiatorAutoVoteYes;
Handle g_hEndVoteTimer;

public Plugin myinfo = 
{
	name = "L4D2 Native vote",
	author = "Powerlord, fdxx",
	description = "Voting API to use the game's native vote panels",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_nativevote"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2) 
		LogError("Plugin only supports L4D2"); // Only throw error, try to continue loading.

	CreateNative("L4D2NativeVote.L4D2NativeVote", Native_CreateVote);
	CreateNative("L4D2NativeVote.SetDisplayText", Native_SetDisplayText);
	CreateNative("L4D2NativeVote.SetTitle", Native_SetDisplayText);
	CreateNative("L4D2NativeVote.GetDisplayText", Native_GetDisplayText);
	CreateNative("L4D2NativeVote.GetTitle", Native_GetDisplayText);
	CreateNative("L4D2NativeVote.Value.set", Native_SetValue);
	CreateNative("L4D2NativeVote.Value.get", Native_GetValue);
	CreateNative("L4D2NativeVote.SetInfoString", Native_SetInfoStr);
	CreateNative("L4D2NativeVote.SetInfo", Native_SetInfoStr);
	CreateNative("L4D2NativeVote.GetInfoString", Native_GetInfoStr);
	CreateNative("L4D2NativeVote.GetInfo", Native_GetInfoStr);
	CreateNative("L4D2NativeVote.Initiator.set", Native_SetInitiator);
	CreateNative("L4D2NativeVote.Initiator.get", Native_GetInitiator);
	CreateNative("L4D2NativeVote.DisplayVote", Native_DisplayVote);
	CreateNative("L4D2NativeVote.YesCount.get", Native_GetYesCount);
	CreateNative("L4D2NativeVote.YesCount.set", Native_SetYesCount);
	CreateNative("L4D2NativeVote.NoCount.get", Native_GetNoCount);
	CreateNative("L4D2NativeVote.NoCount.set", Native_SetNoCount);
	CreateNative("L4D2NativeVote.PlayerCount.get", Native_GetPlayerCount);
	CreateNative("L4D2NativeVote.SetPass", Native_SetPass);
	CreateNative("L4D2NativeVote.SetFail", Native_SetFail);
	CreateNative("L4D2NativeVote_IsAllowNewVote", Native_IsAllowNewVote);

	RegPluginLibrary("l4d2_nativevote");

	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d2_nativevote_version", VERSION, "version", FCVAR_NOTIFY);
	g_cvInitiatorAutoVoteYes = CreateConVar("l4d2_nativevote_initiator_auto_voteyes", "1", "If 1, initiator will auto vote yes", FCVAR_NONE, true, 0.0, true, 1.0);
	AddCommandListener(vote_Listener, "vote");
}

public void OnMapStart()
{
	delete g_hEndVoteTimer;
	g_VoteData.bVoteInProgress = false;
}

public void OnMapEnd()
{
	delete g_hEndVoteTimer;
	g_VoteData.bVoteInProgress = false;
}

// public native L4D2NativeVote CreateVote(L4D2VoteHandler handler);
any Native_CreateVote(Handle plugin, int numParams)
{
	if (!IsAllowNewVote())
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Failed to create new vote");
		return 0;
	}

	ResetVote();
	g_hFwd = new PrivateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_hFwd.AddFunction(plugin, GetNativeFunction(1));
	SetVoteEntityStatus(0);
	g_VoteData.bVoteInProgress = true;

	return 1;
}

// public native void SetDisplayText(const char[] fmt, any ...);
any Native_SetDisplayText(Handle plugin, int numParams)
{
	FormatNativeString(0, 2, 3, sizeof(g_VoteData.sDisplayText), _, g_VoteData.sDisplayText);
	return 0;
}

// public native void GetDisplayText(char[] buffer, int maxlength);
any Native_GetDisplayText(Handle plugin, int numParams)
{
	SetNativeString(2, g_VoteData.sDisplayText, GetNativeCell(3));
	return 0;
}

any Native_SetValue(Handle plugin, int numParams)
{
	g_VoteData.Value = GetNativeCell(2);
	return 0;
}

any Native_GetValue(Handle plugin, int numParams)
{
	return g_VoteData.Value;
}

// public native void SetInfoString(const char[] fmt, any ...);
any Native_SetInfoStr(Handle plugin, int numParams)
{
	FormatNativeString(0, 2, 3, sizeof(g_VoteData.sInfoStr), _, g_VoteData.sInfoStr);
	return 0;
}

// public native void GetInfoString(char[] buffer, int maxlength);
any Native_GetInfoStr(Handle plugin, int numParams)
{
	SetNativeString(2, g_VoteData.sInfoStr, GetNativeCell(3));
	return 0;
}

any Native_SetInitiator(Handle plugin, int numParams)
{
	g_VoteData.iInitiator = GetNativeCell(2);
	return 0;
}

any Native_GetInitiator(Handle plugin, int numParams)
{
	return g_VoteData.iInitiator;
}

// public native bool DisplayVote(int[] clients, int numClients, int time);
any Native_DisplayVote(Handle plugin, int numParams)
{
	if (!GetNativeCell(1) || !g_VoteData.bVoteInProgress || g_VoteData.bVoteStart)
		return false;

	int numClients = GetNativeCell(3);
	int[] buffer = new int[numClients];
	GetNativeArray(2, buffer, numClients);

	int client;
	int[] clients = new int[numClients];
	
	for (int i = 0; i < numClients; i++)
	{
		client = buffer[i];
		if (client > 0 && client <= MaxClients && IsClientInGame(client))
		{
			clients[g_VoteData.iPlayerCount++] = client;
			g_VoteData.bCanVote[client] = true;
		}
	}
	
	if (g_VoteData.iPlayerCount < 1)
	{
		ResetVote();
		return false;
	}
	
	int initiator = g_VoteData.iInitiator;
	char sName[128];
	if (initiator > 0 && initiator <= MaxClients && IsClientInGame(initiator))
	{
		FormatEx(sName, sizeof(sName), "%N", initiator);
		if (g_cvInitiatorAutoVoteYes.BoolValue)
			CreateTimer(0.1, InitiatorVote_Timer, GetClientUserId(initiator));
	}

	BfWrite bf = UserMessageToBfWrite(StartMessage("VoteStart", clients, g_VoteData.iPlayerCount, USERMSG_RELIABLE));
	bf.WriteByte(-1);							// team. Valve represents no team as -1
	bf.WriteByte(initiator);					// initiator
	bf.WriteString("#L4D_TargetID_Player");		// issue. L4D_TargetID_Player which will let you create any vote you want.
	bf.WriteString(g_VoteData.sDisplayText);	// Vote issue text
	bf.WriteString(sName);						// initiatorName
	EndMessage();

	g_VoteData.bVoteStart = true;

	int time = GetNativeCell(4);
	delete g_hEndVoteTimer;
	g_hEndVoteTimer = CreateTimer(float(time), EndVote_Timer);

	UpdateVotes(VoteAction_Start, initiator);
	return true;
}

Action InitiatorVote_Timer(Handle timer, int userid)
{
	if (!g_VoteData.bVoteInProgress)
		return Plugin_Continue;

	int client = GetClientOfUserId(userid);
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
		FakeClientCommand(client, "Vote Yes");
	return Plugin_Continue;
}

any Native_GetYesCount(Handle plugin, int numParams)
{
	return g_VoteData.iYesCount;
}

any Native_SetYesCount(Handle plugin, int numParams)
{
	g_VoteData.iYesCount = GetNativeCell(2);
	return 0;
}

any Native_GetNoCount(Handle plugin, int numParams)
{
	return g_VoteData.iNoCount;
}

any Native_SetNoCount(Handle plugin, int numParams)
{
	g_VoteData.iNoCount = GetNativeCell(2);
	return 0;
}

any Native_GetPlayerCount(Handle plugin, int numParams)
{
	return g_VoteData.iPlayerCount;
}

Action EndVote_Timer(Handle timer)
{
	if (g_VoteData.bVoteInProgress)
	{
		UpdateVotes(VoteAction_End, VOTEEND_TIMEEND);
	}
	g_hEndVoteTimer = null;
	return Plugin_Continue;
}

Action vote_Listener(int client, const char[] command, int argc)
{
	if (g_VoteData.bVoteInProgress && g_VoteData.bCanVote[client])
	{
		g_VoteData.bCanVote[client] = false;
		char sVote[4];
		if (GetCmdArgString(sVote, sizeof(sVote)) > 1)
		{
			if (strcmp(sVote, "Yes", false) == 0)
			{
				g_VoteData.iYesCount++;
				UpdateVotes(VoteAction_PlayerVoted, client, VOTE_YES);
			}
			else if (strcmp(sVote, "No", false) == 0)
			{
				g_VoteData.iNoCount++;
				UpdateVotes(VoteAction_PlayerVoted, client, VOTE_NO);
			}
		}
	}

	return Plugin_Continue;
}

// function void (L4D2NativeVote vote, VoteAction action, int param1, int param2);
void UpdateVotes(VoteAction action, int param1 = -1, int param2 = -1)
{
	if (!g_VoteData.bVoteInProgress) return;

	Event event = CreateEvent("vote_changed", true);
	event.SetInt("yesVotes", g_VoteData.iYesCount);
	event.SetInt("noVotes", g_VoteData.iNoCount);
	event.SetInt("potentialVotes", g_VoteData.iPlayerCount);
	event.Fire();

	switch (action)
	{
		case VoteAction_Start, VoteAction_PlayerVoted:
		{
			Call_StartForward(g_hFwd);
			Call_PushCell(0);
			Call_PushCell(action);
			Call_PushCell(param1);
			Call_PushCell(param2);
			Call_Finish();

			if (g_VoteData.iYesCount + g_VoteData.iNoCount >= g_VoteData.iPlayerCount)
			{
				for (int i; i <= MaxClients; i++)
					g_VoteData.bCanVote[i] = false;
					
				UpdateVotes(VoteAction_End, VOTEEND_FULLVOTED);
			}
		}
		case VoteAction_End:
		{
			Call_StartForward(g_hFwd);
			Call_PushCell(0);
			Call_PushCell(action);
			Call_PushCell(param1);
			Call_PushCell(param2);
			Call_Finish();
		}
	}
}

int Native_SetPass(Handle plugin, int numParams)
{
	char sMsg[64];
	FormatNativeString(0, 2, 3, sizeof(sMsg), _, sMsg);

	BfWrite bf = UserMessageToBfWrite(StartMessageAll("VotePass", USERMSG_RELIABLE));
	bf.WriteByte(-1);
	bf.WriteString("#L4D_TargetID_Player");
	bf.WriteString(sMsg);
	EndMessage();
	CreateTimer(1.0, ResetVote_Timer);
	return 0;
}

int Native_SetFail(Handle plugin, int numParams)
{
	BfWrite bf = UserMessageToBfWrite(StartMessageAll("VoteFail", USERMSG_RELIABLE));
	bf.WriteByte(-1);
	EndMessage();
	CreateTimer(1.0, ResetVote_Timer);
	return 0;
}

Action ResetVote_Timer(Handle timer)
{
	ResetVote();
	return Plugin_Continue;
}

void ResetVote()
{
	g_VoteData.bVoteInProgress = false;
	g_VoteData.bVoteStart = false;

	delete g_hEndVoteTimer;
	delete g_hFwd;

	if (CheckVoteController())
		SetVoteEntityStatus(-1);

	g_VoteData.sDisplayText[0] = '\0';
	g_VoteData.Value = 0;
	g_VoteData.sInfoStr[0] = '\0';
	g_VoteData.iInitiator = 0;
	g_VoteData.iYesCount = 0;
	g_VoteData.iNoCount = 0;
	g_VoteData.iPlayerCount = 0;

	for (int i; i <= MaxClients; i++)
		g_VoteData.bCanVote[i] = false;
}

any Native_IsAllowNewVote(Handle plugin, int numParams)
{
	return IsAllowNewVote();
}

bool IsAllowNewVote()
{
	if (!g_VoteData.bVoteInProgress && CheckVoteController())
	{
		return GetVoteEntityStatus() == -1;
	}
	return false;
}

bool CheckVoteController()
{
	g_iVoteController = FindEntityByClassname(MaxClients+1, "vote_controller");
	return g_iVoteController != -1;
}

int GetVoteEntityStatus()
{
	return GetEntProp(g_iVoteController, Prop_Send, "m_activeIssueIndex");
}

void SetVoteEntityStatus(int value)
{
	SetEntProp(g_iVoteController, Prop_Send, "m_activeIssueIndex", value);
}


