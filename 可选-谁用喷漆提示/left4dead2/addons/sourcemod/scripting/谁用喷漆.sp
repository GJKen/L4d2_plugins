#include <sourcemod>
#include <sdktools>

public OnPluginStart() 
{
    AddTempEntHook("Player Decal", PlayerSpray);
}

public Action:PlayerSpray(const String:szTempEntName[], const arrClients[], iClientCount, Float:flDelay) 
{
    new client = TE_ReadNum("m_nPlayer");
	
	new String:sAuthString[32];
	GetClientName(client, sAuthString, sizeof(sAuthString));
	
    if(IsValidClient(client)) 
    {
        PrintToChatAll("\x03%N\x01 使用了色图喷漆 ( ﹁ ﹁ ) ~", client);
    }
}

public bool:IsValidClient(client) 
{
    if(client <= 0)
        return false;
    if(client > MaxClients)
        return false;

    return IsClientInGame(client);
}