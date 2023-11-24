#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <l4d2_nativevote>

#define PLUGIN_VERSION "0.2"

enum struct Vote {
	bool InProgress;
	bool VoteStarted;
	char Title[64];
	char Info[512];
	any Value;
	int Initiator;
	int YesCount;
	int NoCount;
	int PlayerCount;
	bool CanVote[MAXPLAYERS + 1];
}

Vote
	g_Vote;

int
	g_iVote = -1;

PrivateForward
	g_fwdCreateVote;

Handle
	g_hVoteYesTimer,
	g_hEndVoteTimer;

ConVar
	g_cvAutoVoteYes;

public Plugin myinfo = {
	name = "L4D2 Native vote",
	author = "Powerlord, fdxx",
	description = "Voting API to use the game's native vote panels",
	version = PLUGIN_VERSION,
	url = "https://github.com/fdxx/l4d2_nativevote"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	if (GetEngineVersion() != Engine_Left4Dead2) 
		LogError("Plugin only supports L4D2"); // Only throw error, try to continue loading.

	CreateNative("L4D2NativeVote.L4D2NativeVote", Native_CreateVote);
	CreateNative("L4D2NativeVote.SetTitle", Native_SetTitle);
	CreateNative("L4D2NativeVote.GetTitle", Native_GetTitle);
	CreateNative("L4D2NativeVote.Value.set", Native_SetValue);
	CreateNative("L4D2NativeVote.Value.get", Native_GetValue);
	CreateNative("L4D2NativeVote.SetInfo", Native_SetInfo);
	CreateNative("L4D2NativeVote.GetInfo", Native_GetInfo);
	CreateNative("L4D2NativeVote.Initiator.set", Native_SetInitiator);
	CreateNative("L4D2NativeVote.Initiator.get", Native_GetInitiator);
	CreateNative("L4D2NativeVote.DisplayVote", Native_DisplayVote);
	CreateNative("L4D2NativeVote.YesCount.get", Native_GetYesCount);
	CreateNative("L4D2NativeVote.NoCount.get", Native_GetNoCount);
	CreateNative("L4D2NativeVote.PlayerCount.get", Native_GetPlayerCount);
	CreateNative("L4D2NativeVote.SetPass", Native_SetPass);
	CreateNative("L4D2NativeVote.SetFail", Native_SetFail);
	CreateNative("L4D2NativeVote_IsAllowNewVote", Native_IsAllowNewVote);

	RegPluginLibrary("l4d2_nativevote");

	return APLRes_Success;
}

public void OnPluginStart() {
	CreateConVar("l4d2_nativevote_version", PLUGIN_VERSION, "L4D2 Native vote plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cvAutoVoteYes = CreateConVar("l4d2_nativevote_initiator_auto_voteyes", "1", "启用投票发起人自动赞成投票? 0=建议,1=启用.", FCVAR_NONE);

	AddCommandListener(Listener_vote, "vote");
	RegAdminCmd("sm_pass", cmdPass, ADMFLAG_VOTE);
	RegAdminCmd("sm_veto", cmdVeto, ADMFLAG_VOTE);
}

Action cmdPass(int client, int args) {
	if (g_Vote.InProgress) {
		g_Vote.NoCount = 0;
		g_Vote.YesCount = g_Vote.PlayerCount;
		UpdateVotes(VoteAction_End, VOTEEND_FULLVOTED);
	}
	else if (CheckVoteController() && IsGameVoteActive()){
		SetEntProp(g_iVote, Prop_Send, "m_votesNo", 0);
		SetEntProp(g_iVote, Prop_Send, "m_votesYes", GetEntProp(g_iVote, Prop_Send, "m_potentialVotes"));

		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i))
				continue;

			FakeClientCommand(i, "Vote Yes");
		}
	}

	return Plugin_Handled;
}

Action cmdVeto(int client, int args) {
	if (g_Vote.InProgress) {
		g_Vote.YesCount = 0;
		g_Vote.NoCount = g_Vote.PlayerCount;
		UpdateVotes(VoteAction_End, VOTEEND_FULLVOTED);
	}
	else if (CheckVoteController() && IsGameVoteActive()){
		SetEntProp(g_iVote, Prop_Send, "m_votesYes", 0);
		SetEntProp(g_iVote, Prop_Send, "m_votesNo", GetEntProp(g_iVote, Prop_Send, "m_potentialVotes"));

		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i))
				continue;

			FakeClientCommand(i, "Vote No");
		}
	}

	return Plugin_Handled;
}

public void OnClientDisconnect(int client) {
	if (!g_Vote.InProgress)
		return;

	if (!g_Vote.CanVote[client])
		return;

	g_Vote.PlayerCount--;
	g_Vote.CanVote[client] = false;
	if (!g_Vote.PlayerCount)
		UpdateVotes(VoteAction_End, VOTEEND_FULLVOTED);
}

public void OnMapStart() {
	delete g_hVoteYesTimer;
	delete g_hEndVoteTimer;
	g_Vote.InProgress = false;
	g_Vote.VoteStarted = false;
}

public void OnMapEnd() {
	delete g_hVoteYesTimer;
	delete g_hEndVoteTimer;
	g_Vote.InProgress = false;
	g_Vote.VoteStarted = false;
}

// public native L4D2NativeVote CreateVote(L4D2VoteHandler handler);
any Native_CreateVote(Handle plugin, int numParams) {
	if (!IsAllowNewVote()) {
		ThrowNativeError(SP_ERROR_NATIVE, "Failed to create new vote");
		return Invalid_Vote;
	}

	ResetVote();
	g_fwdCreateVote = new PrivateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_fwdCreateVote.AddFunction(plugin, GetNativeFunction(1));
	SetEntProp(g_iVote, Prop_Send, "m_activeIssueIndex", 0);
	g_Vote.InProgress = true;

	return Valid_Vote;
}

// public native void SetTitle(const char[] fmt, any ...);
int Native_SetTitle(Handle plugin, int numParams) {
	FormatNativeString(0, 2, 3, sizeof g_Vote.Title, _, g_Vote.Title);
	return 0;
}

// public native void GetTitle(char[] buffer, int maxlength);
int Native_GetTitle(Handle plugin, int numParams) {
	SetNativeString(2, g_Vote.Title, GetNativeCell(3));
	return 0;
}

// public native void SetInfo(const char[] fmt, any ...);
int Native_SetInfo(Handle plugin, int numParams) {
	FormatNativeString(0, 2, 3, sizeof g_Vote.Info, _, g_Vote.Info);
	return 0;
}

// public native void GetInfo(char[] buffer, int maxlength);
int Native_GetInfo(Handle plugin, int numParams) {
	SetNativeString(2, g_Vote.Info, GetNativeCell(3));
	return 0;
}

int Native_SetValue(Handle plugin, int numParams) {
	g_Vote.Value = GetNativeCell(2);
	return 0;
}

any Native_GetValue(Handle plugin, int numParams) {
	return g_Vote.Value;
}

int Native_SetInitiator(Handle plugin, int numParams) {
	g_Vote.Initiator = GetNativeCell(2);
	return 0;
}

int Native_GetInitiator(Handle plugin, int numParams) {
	return g_Vote.Initiator;
}

// public native bool DisplayVote(int[] clients, int numClients, int time);
any Native_DisplayVote(Handle plugin, int numParams) {
	L4D2NativeVote vote = GetNativeCell(1);
	if (vote != Valid_Vote || !g_Vote.InProgress)
		return false;

	int size = GetNativeCell(3);
	int[] clients = new int[size];
	GetNativeArray(2, clients, size);

	int i;
	int client;
	int numVote;
	for (; i < size; i++) {
		client = clients[i];
		if (client > 0 && client <= MaxClients && IsClientInGame(client)) {
			clients[numVote++] = client;
			g_Vote.CanVote[client] = true;
		}
	}

	if (!numVote) {
		if (!g_Vote.PlayerCount)
			ResetVote();

		return false;
	}

	g_Vote.PlayerCount += numVote;
	int initiator = g_Vote.Initiator;
	char name[MAX_NAME_LENGTH];
	if (initiator > 0 && initiator <= MaxClients && IsClientInGame(initiator))
		FormatEx(name, sizeof name, "%N", initiator);

	BfWrite bf = UserMessageToBfWrite(StartMessage("VoteStart", clients, numVote, USERMSG_RELIABLE));
	bf.WriteByte(-1);							// team. Valve represents no team as -1
	bf.WriteByte(initiator);					// initiator
	bf.WriteString("#L4D_TargetID_Player");		// issue. L4D_TargetID_Player which will let you create any vote you want.
	bf.WriteString(g_Vote.Title);				// Vote issue text
	bf.WriteString(name);						// initiatorName
	EndMessage();

	if (!g_Vote.VoteStarted) {
		g_Vote.VoteStarted = true;
		UpdateVotes(VoteAction_Start, initiator);

		if (name[0] && g_cvAutoVoteYes.BoolValue) {
			delete g_hVoteYesTimer;
			g_hVoteYesTimer = CreateTimer(0.1, tmrVoteYes, GetClientUserId(initiator));
		}
	}

	delete g_hEndVoteTimer;
	g_hEndVoteTimer = CreateTimer(float(GetNativeCell(4)), tmrEndVote);

	return true;
}

Action tmrVoteYes(Handle timer, int client) {
	g_hVoteYesTimer = null;

	if (!g_Vote.InProgress)
		return Plugin_Stop;

	if ((client = GetClientOfUserId(client)) && IsClientInGame(client))
		FakeClientCommand(client, "Vote Yes");

	return Plugin_Continue;
}

int Native_GetYesCount(Handle plugin, int numParams) {
	return g_Vote.YesCount;
}

int Native_GetNoCount(Handle plugin, int numParams) {
	return g_Vote.NoCount;
}

int Native_GetPlayerCount(Handle plugin, int numParams) {
	return g_Vote.PlayerCount;
}

Action tmrEndVote(Handle timer) {
	g_hEndVoteTimer = null;

	if (g_Vote.InProgress)
		UpdateVotes(VoteAction_End, VOTEEND_TIMEEND);

	return Plugin_Continue;
}

Action Listener_vote(int client, const char[] command, int argc) {
	if (!g_Vote.InProgress || !g_Vote.CanVote[client])
		return Plugin_Continue;

	char buffer[5];
	if (!GetCmdArgString(buffer, sizeof buffer))
		return Plugin_Continue;

	if (strcmp(buffer, "Yes", false) == 0) {
		g_Vote.YesCount++;
		UpdateVotes(VoteAction_PlayerVoted, client, VOTE_YES);
	}
	else if (strcmp(buffer, "No", false) == 0) {
		g_Vote.NoCount++;
		UpdateVotes(VoteAction_PlayerVoted, client, VOTE_NO);
	}
	else
		return Plugin_Continue;
	
	g_Vote.CanVote[client] = false;
	return Plugin_Continue;
}

// function void (L4D2NativeVote vote, VoteAction action, int param1, int param2);
void UpdateVotes(VoteAction action, int param1 = -1, int param2 = -1) {
	if (!g_Vote.InProgress)
		return;

	Event event = CreateEvent("vote_changed", true);
	event.SetInt("yesVotes", g_Vote.YesCount);
	event.SetInt("noVotes", g_Vote.NoCount);
	event.SetInt("potentialVotes", g_Vote.PlayerCount);
	event.Fire();

	switch (action) {
		case VoteAction_Start: {
			Call_StartForward(g_fwdCreateVote);
			Call_PushCell(Valid_Vote);
			Call_PushCell(action);
			Call_PushCell(param1);
			Call_PushCell(param2);
			Call_Finish();
		}

		case VoteAction_PlayerVoted: {
			Call_StartForward(g_fwdCreateVote);
			Call_PushCell(Valid_Vote);
			Call_PushCell(action);
			Call_PushCell(param1);
			Call_PushCell(param2);
			Call_Finish();

			if (g_Vote.YesCount + g_Vote.NoCount >= g_Vote.PlayerCount)
				UpdateVotes(VoteAction_End, VOTEEND_FULLVOTED);
		}

		case VoteAction_End: {
			Call_StartForward(g_fwdCreateVote);
			Call_PushCell(Valid_Vote);
			Call_PushCell(action);
			Call_PushCell(param1);
			Call_PushCell(param2);
			Call_Finish();

			ResetVote();
		}
	}
}

int Native_SetPass(Handle plugin, int numParams) {
	char out_string[64];
	if (numParams > 1)
		FormatNativeString(0, 2, 3, sizeof out_string, _, out_string);

	BfWrite bf = UserMessageToBfWrite(StartMessageAll("VotePass", USERMSG_RELIABLE));
	bf.WriteByte(-1);
	bf.WriteString("#L4D_TargetID_Player");
	bf.WriteString(out_string);
	EndMessage();
	CreateTimer(0.1, tmrResetVote);
	return 0;
}

int Native_SetFail(Handle plugin, int numParams) {
	BfWrite bf = UserMessageToBfWrite(StartMessageAll("VoteFail", USERMSG_RELIABLE));
	bf.WriteByte(-1);
	EndMessage();
	CreateTimer(0.1, tmrResetVote);
	return 0;
}

Action tmrResetVote(Handle timer) {
	ResetVote();
	return Plugin_Continue;
}

void ResetVote() {
	delete g_hVoteYesTimer;
	delete g_hEndVoteTimer;
	delete g_fwdCreateVote;
	g_Vote.InProgress = false;
	g_Vote.VoteStarted = false;

	g_Vote.Title[0] = '\0';
	g_Vote.Info[0] = '\0';
	g_Vote.Value = 0;
	g_Vote.Initiator = 0;
	g_Vote.YesCount = 0;
	g_Vote.NoCount = 0;
	g_Vote.PlayerCount = 0;

	for (int i; i <= MaxClients; i++)
		g_Vote.CanVote[i] = false;

	if (CheckVoteController())
		SetEntProp(g_iVote, Prop_Send, "m_activeIssueIndex", -1);
}

any Native_IsAllowNewVote(Handle plugin, int numParams) {
	return IsAllowNewVote();
}

bool IsAllowNewVote() {
	if (!g_Vote.InProgress)
		return CheckVoteController() && !IsGameVoteActive();

	return false;
}

bool CheckVoteController() {
	int entity = -1;
	if (g_iVote != -1)
		entity = EntRefToEntIndex(g_iVote);

	if (entity == -1) {
		entity = FindEntityByClassname(MaxClients + 1, "vote_controller");
		if (entity == -1)
			return false;

		g_iVote = EntIndexToEntRef(entity);
	}

	return true;
}

bool IsGameVoteActive() {
	return GetEntProp(g_iVote, Prop_Send, "m_activeIssueIndex") > -1;
}