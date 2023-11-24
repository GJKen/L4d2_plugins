#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo =
{
	name = "LagFixer",
	author = "tRololo312312",
	description = "Might solve some lag issues on some maps.",
	version = "1.0",
	url = ""
};

public OnEntityCreated(entity, const String:classname[])
{
	if(StrEqual(classname, "phys_bone_follower"))
	{
		if(IsValidEntity(entity))
		{
			SDKHook(entity, SDKHook_SetTransmit, HideIt);
		}
	}
}

public Action HideIt(int iEntity, int iClient)
{
	if(!IsFakeClient(iClient))
		return Plugin_Handled;
	return Plugin_Continue;
}
