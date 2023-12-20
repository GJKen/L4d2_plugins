#define PLUGIN_VERSION  "3.3"
#define PLUGIN_NAME     "Thirdstrike Glow"
#define PLUGIN_PREFIX   "thirdstrike_glow"

#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "little_froy",
	description = "game play",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=340159"
};

GlobalForward Forward_OnSetGlow;
GlobalForward Forward_OnResetGlow;

ConVar C_color;
int O_color;
ConVar C_range;
int O_range;
ConVar C_range_min;
int O_range_min;
ConVar C_through_wall;
bool O_through_wall;
ConVar C_flash;
bool O_flash;

bool Added[MAXPLAYERS+1];

bool is_survivor_on_thirdstrike(int client)
{
	return !!GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");
}

void set_glow(int client)
{
    if(!Added[client])
    {
        Added[client] = true;
        SetEntProp(client, Prop_Send, "m_iGlowType", O_through_wall ? 3 : 2);
        SetEntProp(client, Prop_Send, "m_glowColorOverride", O_color);
        SetEntProp(client, Prop_Send, "m_nGlowRange", O_range);
        SetEntProp(client, Prop_Send, "m_nGlowRangeMin", O_range_min);
        SetEntProp(client, Prop_Send, "m_bFlashing", O_flash ? 1 : 0);
        Call_StartForward(Forward_OnSetGlow);
        Call_PushCell(client);
        Call_Finish();
    }
}

void reset_glow(int client)
{
    if(Added[client])
    {
        Added[client] = false;
        SetEntProp(client, Prop_Send, "m_iGlowType", 0);
        SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
        SetEntProp(client, Prop_Send, "m_nGlowRange", 0);
        SetEntProp(client, Prop_Send, "m_nGlowRangeMin", 0);
        SetEntProp(client, Prop_Send, "m_bFlashing", 0);
        Call_StartForward(Forward_OnResetGlow);
        Call_PushCell(client);
        Call_Finish();
    }
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
    if(GetClientTeam(client) == 2 && IsPlayerAlive(client) && is_survivor_on_thirdstrike(client))
    {
        set_glow(client);
    }
    else
    {
        reset_glow(client);
    }
}

public void OnClientDisconnect_Post(int client)
{
	Added[client] = false;
}

void reset_all()
{
    for(int client = 1; client <= MAXPLAYERS; client++)
    {
        if(client <= MaxClients && IsClientInGame(client))
        {
            reset_glow(client);
        }
        Added[client] = false;
    }
}

void event_round_start(Event event, const char[] name, bool dontBroadcast)
{
    reset_all();
}

void get_cvars()
{
    char cvar_colors[13];
    C_color.GetString(cvar_colors, sizeof(cvar_colors));
	char colors_get[3][4];
	ExplodeString(cvar_colors, " ", colors_get, 3, 4);
    O_color = StringToInt(colors_get[0]) + StringToInt(colors_get[1]) * 256 + StringToInt(colors_get[2]) * 65536;
    O_range = C_range.IntValue;
    O_range_min = C_range_min.IntValue;
    O_through_wall = C_through_wall.BoolValue;
    O_flash = C_flash.BoolValue;

    reset_all();
}

void convar_changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	get_cvars();
}

public void OnConfigsExecuted()
{
	get_cvars();
}

any native_ThirdstrikeGlow_HasSetGlow(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_INDEX, "client index %d is out of bound", client);
	}
	return Added[client];
}

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
    if(GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "this plugin only runs in \"Left 4 Dead 2\"");
        return APLRes_SilentFailure;
    }
    Forward_OnSetGlow = new GlobalForward("ThirdstrikeGlow_OnSetGlow", ET_Ignore, Param_Cell);
    Forward_OnResetGlow = new GlobalForward("ThirdstrikeGlow_OnResetGlow", ET_Ignore, Param_Cell);
    CreateNative("ThirdstrikeGlow_HasSetGlow", native_ThirdstrikeGlow_HasSetGlow);
    RegPluginLibrary(PLUGIN_PREFIX);
    return APLRes_Success;
}

public void OnPluginStart()
{
    HookEvent("round_start", event_round_start);

    C_color = CreateConVar(PLUGIN_PREFIX ... "_color", "255 255 255", "color of glow, split up with space");
    C_color.AddChangeHook(convar_changed);
    C_range = CreateConVar(PLUGIN_PREFIX ... "_range", "0", "max visible range of glow. 0 = infinite", _, true, 0.0);
    C_range.AddChangeHook(convar_changed);
    C_range_min = CreateConVar(PLUGIN_PREFIX ... "_range_min", "0", "min range far away to visible the glow, 0 = no limit", _, true, 0.0);
    C_range_min.AddChangeHook(convar_changed);
    C_through_wall = CreateConVar(PLUGIN_PREFIX ... "_through_wall", "1", "1 = enable, 0 = disable. can the glow be seen through wall?");
    C_through_wall.AddChangeHook(convar_changed);
    C_flash = CreateConVar(PLUGIN_PREFIX ... "_flash", "0", "1 = enable, 0 = disable. will the glow flash?");
    C_flash.AddChangeHook(convar_changed);
    CreateConVar(PLUGIN_PREFIX ... "_version", PLUGIN_VERSION, "version of " ... PLUGIN_NAME, FCVAR_NOTIFY | FCVAR_DONTRECORD);
    AutoExecConfig(true, PLUGIN_PREFIX);
}

public void OnPluginEnd()
{
    reset_all();
}