#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <sdktools>
#include <colors>

ConVar hCvarNameChange, hCvarSpecNameChange, hCvarSpecSeeChat;

public Plugin myinfo =
{
	name = "[L4D2] Change Name",
	author = "Kita, GJken", 
	description = "重新替换改名提示",
	version = "1.0",
	url = "ni cai"
};

public void OnPluginStart()
{
	hCvarNameChange = CreateConVar("name_change_suppress", "1", "屏蔽原来的改名提示 0=关", FCVAR_SPONLY);
	hCvarSpecNameChange = CreateConVar("name_change_spec_suppress", "1", "屏蔽闲置玩家原来的改名提示 0=关", FCVAR_SPONLY);
	hCvarSpecSeeChat = CreateConVar("show_player_team_chat_spec", "1", "向旁观展示幸存者和受感染团队的聊天内容 0=关", FCVAR_SPONLY);
	
	HookEvent("player_changename", Event_PlayerChangeName);
	HookUserMessage(GetUserMessageId("SayText2"), UserMsg_OnSayText2, true);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	static char s_sPubChatTrigger[8] = "!", s_sPrivChatTrigger[8] = "/";
	static int s_iPubTriggerLen = 1, s_iPrivTriggerLen = 1;

#if SOURCEMOD_V_MAJOR > 1
  || (SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR >= 12 && SOURCEMOD_V_REV >= 6944)
	static bool bInit = false;
	if (!bInit)
	{
		s_iPubTriggerLen = GetPublicChatTriggers(s_sPubChatTrigger, sizeof(s_sPubChatTrigger));
		s_iPrivTriggerLen = GetSilentChatTriggers(s_sPrivChatTrigger, sizeof(s_sPrivChatTrigger));
		
		if (!s_iPubTriggerLen)
			s_iPubTriggerLen = strcopy(s_sPubChatTrigger, sizeof(s_sPubChatTrigger), "!");
		if (!s_iPrivTriggerLen)
			s_iPrivTriggerLen = strcopy(s_sPrivChatTrigger, sizeof(s_sPrivChatTrigger), "/");
		
		bInit = true;
	}
#endif

	if (strncmp(sArgs, s_sPubChatTrigger, s_iPubTriggerLen) == 0
	  || strncmp(sArgs, s_sPrivChatTrigger, s_iPrivTriggerLen) == 0)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (!IsValidClient(client))
		return;
	
	if (!hCvarSpecSeeChat.BoolValue || strcmp(command, "say_team") != 0)
		return;
	
	static const char s_ChatFormats[][] = {
		"L4D_Chat_Survivor",
		"L4D_Chat_Infected",
	};
	
	int idxTeam = GetClientTeam(client) - 2;
	if (idxTeam != 0 && idxTeam != 1)
		return;

	int[] clients = new int[MaxClients];
	int numClients = 0;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 1 && (!IsFakeClient(i) || IsClientSourceTV(i)))
			clients[numClients++] = i;
	}
	
	if (numClients <= 0)
		return;
	
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	UTIL_SayText2Filter(client, clients, numClients, true, s_ChatFormats[idxTeam], name, sArgs);
}


Action UserMsg_OnSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	int client = msg.ReadByte();
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	msg.ReadByte();
	

	static char sMessage[128];
	msg.ReadString(sMessage, sizeof(sMessage), true);
	
	if (GetClientTeam(client) == 1)
	{
		if (!hCvarSpecNameChange.BoolValue)
			return Plugin_Continue;
	}
	else if (!hCvarNameChange.BoolValue)
		return Plugin_Continue;
	
	if (strcmp(sMessage, "#Cstrike_Name_Change") != 0)
		return Plugin_Continue;
	
	return Plugin_Handled;
}

stock bool IsValidClient(int client)
{ 
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock void UTIL_SayText2Filter( int entity, const int[] recipients, int numRecipient, bool bChat, const char[] msg_name, const char[] param1 = NULL_STRING, const char[] param2 = NULL_STRING, const char[] param3 = NULL_STRING, const char[] param4 = NULL_STRING )
{
	BfWrite bf = UserMessageToBfWrite(StartMessage( "SayText2", recipients, numRecipient, USERMSG_RELIABLE ));
	
	if ( entity < 0 )
		entity = 0;
	
	bf.WriteByte( entity );
	bf.WriteByte( bChat );
	bf.WriteString( msg_name );
	
	if ( !IsNullString(param1) )
		bf.WriteString( param1 );
	else
		bf.WriteString( "" );
	
	if ( !IsNullString(param2) )
		bf.WriteString( param2 );
	else
		bf.WriteString( "" );
	
	if ( !IsNullString(param3) )
		bf.WriteString( param3 );
	else
		bf.WriteString( "" );
	
	if ( !IsNullString(param4) )
		bf.WriteString( param4 );
	else
		bf.WriteString( "" );
	
	EndMessage();
}

public void Event_PlayerChangeName(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsFakeClient(client))
		return;

	char sOldname[MAX_NAME_LENGTH], sNewname[MAX_NAME_LENGTH];
	event.GetString("oldname", sOldname, sizeof(sOldname));
	event.GetString("newname", sNewname, sizeof(sNewname));
	CPrintToChatAll("{blue}%s{default}转生后叫做{blue}%s", sOldname, sNewname);
}