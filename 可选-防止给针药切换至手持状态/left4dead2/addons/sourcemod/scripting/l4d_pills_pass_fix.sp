#include <sourcemod>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
    name = "[L4D/L4D2] Pills Pass Fix",
    author = "MasterMind420",
    description = "Prevents auto switching to pills or adrenaline when passed to you",
    version = "1.1",
    url = ""
};

public void OnPluginStart()
{
	HookEvent("weapon_given", eWeaponGiven, EventHookMode_Pre);
}

public Action OnWeaponSwitch(int client, int weapon)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		if(IsValidEntity(weapon))
		{
			char sClsName[32];
			GetEntityClassname(weapon, sClsName, sizeof(sClsName));

			if(StrContains(sClsName, "adrenaline") > -1 || StrContains(sClsName, "pills") > -1)
			{
				SDKUnhook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

public void eWeaponGiven(Event event, const char[] name, bool dontBroadcast)
{
	int receiver = GetClientOfUserId(event.GetInt("userid"));

	char item[32];
	GetEventString(event, "weapon", item, sizeof(item));

	if(StrEqual(item, "15") || StrEqual(item, "23"))
		SDKHook(receiver, SDKHook_WeaponSwitch, OnWeaponSwitch);
}