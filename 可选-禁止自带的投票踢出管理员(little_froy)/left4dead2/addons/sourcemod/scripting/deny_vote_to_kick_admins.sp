#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <colors>

#define PLUGIN_VERSION	"2.0"
#define PLUGIN_NAME     "Deny Vote To Kick Admins"

public Plugin myinfo =
{
	name = "deny_vote_to_kick_admins",
	author = "little_froy",
	description = "game play",
	version = PLUGIN_VERSION,
	url = ""
};

ConVar C_admin_flag;

AdminFlag O_admin_flag;

public Action on_cmd_callvote(int client, const char[] command, int argc)
{
    if(argc < 2)
    {
        return Plugin_Continue;
    }
    static char arg[PLATFORM_MAX_PATH];
    GetCmdArg(1, arg, sizeof(arg));
    {
        if(strcmp(arg, "kick", false) != 0)
        {
            return Plugin_Continue;
        }
    }
    GetCmdArg(2, arg, sizeof(arg));
    int target = GetClientOfUserId(StringToInt(arg));
    if(target > 0 && target <= MaxClients && IsClientInGame(target))
    {
        AdminId admin_id = GetUserAdmin(target);
        if(admin_id != INVALID_ADMIN_ID && admin_id.HasFlag(O_admin_flag, Access_Effective))
        {
            if(client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
            {
                CPrintToChat(client, "%t", "tip");
            }
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

void get_cvars()
{
    O_admin_flag = view_as<AdminFlag>(C_admin_flag.IntValue);
}

public void convar_changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	get_cvars();
}

public void OnConfigsExecuted()
{
	get_cvars();
}

public void OnPluginStart()
{
    LoadTranslations("deny_vote_to_kick_admins.phrases");

    AddCommandListener(on_cmd_callvote, "callvote");

    C_admin_flag = CreateConVar("deny_vote_to_kick_admins_flag", "1", "admin flag required of admins to deny vote to kick", _, true, 0.0, true, 20.0);

    CreateConVar("deny_vote_to_kick_admins_version", PLUGIN_VERSION, "version of " ... PLUGIN_NAME, FCVAR_NOTIFY | FCVAR_DONTRECORD);

    C_admin_flag.AddChangeHook(convar_changed);

    AutoExecConfig(true, "deny_vote_to_kick_admins");
}