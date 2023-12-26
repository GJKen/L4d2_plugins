/**
// ====================================================================================================
Change Log:

1.0.1 (11-November-2020)
    - Fixed weapon_*_spawn entities not being affected by the plugin. (thanks "user2000" for reporting)

1.0.0 (11-November-2020)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D2] Weapons Skins Switch"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Allow to change an equipped weapon skin by pressing IN_USE (E) in the same weapon with a different skin"
#define PLUGIN_VERSION                "1.0.1"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=328478"

// ====================================================================================================
// Plugin Info
// ====================================================================================================
public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = PLUGIN_URL
}

// ====================================================================================================
// Includes
// ====================================================================================================
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// ====================================================================================================
// Pragmas
// ====================================================================================================
#pragma semicolon 1
#pragma newdecls required

// ====================================================================================================
// Cvar Flags
// ====================================================================================================
#define CVAR_FLAGS                    FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION     FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

// ====================================================================================================
// Filenames
// ====================================================================================================
#define CONFIG_FILENAME               "l4d2_wskin_switch"

// ====================================================================================================
// Defines
// ====================================================================================================
#define L4D2_WEPID_PISTOL_MAGNUM      "32"
#define L4D2_WEPID_SMG_UZI            "2"
#define L4D2_WEPID_SMG_SILENCED       "7"
#define L4D2_WEPID_PUMP_SHOTGUN       "3"
#define L4D2_WEPID_SHOTGUN_CHROME     "8"
#define L4D2_WEPID_AUTO_SHOTGUN       "4"
#define L4D2_WEPID_RIFLE_M16          "5"
#define L4D2_WEPID_RIFLE_AK47         "26"
#define L4D2_WEPID_HUNTING_RIFLE      "6"

#define MODEL_W_CROWBAR               "models/weapons/melee/w_crowbar.mdl"
#define MODEL_W_CRICKET_BAT           "models/weapons/melee/w_cricket_bat.mdl"

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;
ConVar g_hCvar_Swap;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bEventsHooked;
bool g_bCvar_Enabled;
bool g_bCvar_Swap;

// ====================================================================================================
// StringMap - Plugin Variables
// ====================================================================================================
StringMap g_smWeaponName;
StringMap g_smWeaponMeleeName;
StringMap g_smWeaponIdToClassname;
StringMap g_smWeaponModelToClassname;

// ====================================================================================================
// Plugin Start
// ====================================================================================================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion engine = GetEngineVersion();

    if (engine != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "This plugin only runs in \"Left 4 Dead 2\" game");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

/****************************************************************************************************/

public void OnPluginStart()
{
    g_smWeaponName = new StringMap();
    g_smWeaponMeleeName = new StringMap();
    g_smWeaponIdToClassname = new StringMap();
    g_smWeaponModelToClassname = new StringMap();

    BuildMaps();

    CreateConVar("l4d2_wskin_switch_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled = CreateConVar("l4d2_wskin_switch_enable", "1", "Enable/Disable the plugin.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Swap    = CreateConVar("l4d2_wskin_switch_swap", "1", "Swap the targeted weapon skin with the holding weapon skin.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Swap.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d2_wskin_switch", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");
}

/****************************************************************************************************/

void BuildMaps()
{
    g_smWeaponName.Clear();
    g_smWeaponName.SetString("weapon_pistol_magnum", "weapon_pistol_magnum");
    g_smWeaponName.SetString("weapon_pistol_magnum_spawn", "weapon_pistol_magnum");
    g_smWeaponName.SetString("weapon_smg", "weapon_smg");
    g_smWeaponName.SetString("weapon_smg_spawn", "weapon_smg");
    g_smWeaponName.SetString("weapon_smg_silenced", "weapon_smg_silenced");
    g_smWeaponName.SetString("weapon_smg_silenced_spawn", "weapon_smg_silenced");
    g_smWeaponName.SetString("weapon_pumpshotgun", "weapon_pumpshotgun");
    g_smWeaponName.SetString("weapon_pumpshotgun_spawn", "weapon_pumpshotgun");
    g_smWeaponName.SetString("weapon_shotgun_chrome", "weapon_shotgun_chrome");
    g_smWeaponName.SetString("weapon_shotgun_chrome_spawn", "weapon_shotgun_chrome");
    g_smWeaponName.SetString("weapon_autoshotgun", "weapon_autoshotgun");
    g_smWeaponName.SetString("weapon_autoshotgun_spawn", "weapon_autoshotgun");
    g_smWeaponName.SetString("weapon_rifle", "weapon_rifle");
    g_smWeaponName.SetString("weapon_rifle_spawn", "weapon_rifle");
    g_smWeaponName.SetString("weapon_rifle_ak47", "weapon_rifle_ak47");
    g_smWeaponName.SetString("weapon_rifle_ak47_spawn", "weapon_rifle_ak47");
    g_smWeaponName.SetString("weapon_hunting_rifle", "weapon_hunting_rifle");
    g_smWeaponName.SetString("weapon_hunting_rifle_spawn", "weapon_hunting_rifle");

    g_smWeaponMeleeName.Clear();
    g_smWeaponMeleeName.SetString("cricket_bat", "cricket_bat");
    g_smWeaponMeleeName.SetString("crowbar", "crowbar");

    g_smWeaponIdToClassname.Clear();
    g_smWeaponIdToClassname.SetString(L4D2_WEPID_PISTOL_MAGNUM, "weapon_pistol_magnum");
    g_smWeaponIdToClassname.SetString(L4D2_WEPID_SMG_UZI, "weapon_smg");
    g_smWeaponIdToClassname.SetString(L4D2_WEPID_SMG_SILENCED, "weapon_smg_silenced");
    g_smWeaponIdToClassname.SetString(L4D2_WEPID_PUMP_SHOTGUN, "weapon_pumpshotgun");
    g_smWeaponIdToClassname.SetString(L4D2_WEPID_SHOTGUN_CHROME, "weapon_shotgun_chrome");
    g_smWeaponIdToClassname.SetString(L4D2_WEPID_AUTO_SHOTGUN, "weapon_autoshotgun");
    g_smWeaponIdToClassname.SetString(L4D2_WEPID_RIFLE_M16, "weapon_rifle");
    g_smWeaponIdToClassname.SetString(L4D2_WEPID_RIFLE_AK47, "weapon_rifle_ak47");
    g_smWeaponIdToClassname.SetString(L4D2_WEPID_HUNTING_RIFLE, "weapon_hunting_rifle");

    g_smWeaponModelToClassname.Clear();
    g_smWeaponModelToClassname.SetString(MODEL_W_CRICKET_BAT, "cricket_bat");
    g_smWeaponModelToClassname.SetString(MODEL_W_CROWBAR, "crowbar");
}

/****************************************************************************************************/

public void OnConfigsExecuted()
{
    GetCvars();

    HookEvents();
}

/****************************************************************************************************/

void Event_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();

    HookEvents();
}

/****************************************************************************************************/

void GetCvars()
{
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
    g_bCvar_Swap = g_hCvar_Swap.BoolValue;
}

/****************************************************************************************************/

void HookEvents()
{
    if (g_bCvar_Enabled && !g_bEventsHooked)
    {
        g_bEventsHooked = true;

        HookEvent("player_use", Event_PlayerUse);

        return;
    }

    if (!g_bCvar_Enabled && g_bEventsHooked)
    {
        g_bEventsHooked = false;

        UnhookEvent("player_use", Event_PlayerUse);

        return;
    }
}

/****************************************************************************************************/

void Event_PlayerUse(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int entity = event.GetInt("targetid");

    if (client == 0)
        return;

    if (!IsValidEntity(entity))
        return;

    char pickupClassname[36];
    GetEntityClassname(entity, pickupClassname, sizeof(pickupClassname));

    if (pickupClassname[0] != 'w' || pickupClassname[1] != 'e') // weapon_*
        return;

    char pickupName[36];
    if (StrEqual(pickupClassname, "weapon_melee"))
    {
        char meleeName[16];
        GetEntPropString(entity, Prop_Data, "m_strMapSetScriptName", meleeName, sizeof(meleeName));

        if (!g_smWeaponMeleeName.GetString(meleeName, pickupName, sizeof(pickupName)))
            return;
    }
    else if (StrEqual(pickupClassname, "weapon_melee_spawn"))
    {
        char modelname[PLATFORM_MAX_PATH];
        GetEntPropString(entity, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
        StringToLowerCase(modelname);

        if (!g_smWeaponModelToClassname.GetString(modelname, pickupName, sizeof(pickupName)))
            return;
    }
    else if (StrEqual(pickupClassname, "weapon_spawn"))
    {
        int weaponId = GetEntProp(entity, Prop_Data, "m_weaponID");
        char sWeaponId[3];
        IntToString(weaponId, sWeaponId, sizeof(sWeaponId));

        if (!g_smWeaponIdToClassname.GetString(sWeaponId, pickupName, sizeof(pickupName)))
            return;
    }
    else
    {
        if (!g_smWeaponName.GetString(pickupClassname, pickupName, sizeof(pickupName)))
            return;
    }

    bool found;

    int slot = -1;

    if (!found)
    {
        int slot1 = GetPlayerWeaponSlot(client, 0);

        if (IsValidEntity(slot1))
        {
            char slot1Classname[36];
            GetEntityClassname(slot1, slot1Classname, sizeof(slot1Classname));

            char slot1Name[36];

            if (StrEqual(slot1Classname, "weapon_melee"))
            {
                char meleeName[16];
                GetEntPropString(slot1, Prop_Data, "m_strMapSetScriptName", meleeName, sizeof(meleeName));

                if (g_smWeaponMeleeName.GetString(meleeName, slot1Name, sizeof(slot1Name)))
                    found = StrEqual(pickupName, slot1Name);
            }
            else
            {
                if (g_smWeaponName.GetString(slot1Classname, slot1Name, sizeof(slot1Name)))
                    found = StrEqual(pickupName, slot1Name);
            }

            slot = (found ? slot1 : slot);
        }
    }

    int slot2;

    if (!found)
    {
        slot2 = GetPlayerWeaponSlot(client, 1);

        if (IsValidEntity(slot2))
        {
            char slot2Classname[36];
            GetEntityClassname(slot2, slot2Classname, sizeof(slot2Classname));

            char slot2Name[36];

            if (StrEqual(slot2Classname, "weapon_melee"))
            {
                char meleeName[16];
                GetEntPropString(slot2, Prop_Data, "m_strMapSetScriptName", meleeName, sizeof(meleeName));

                if (g_smWeaponMeleeName.GetString(meleeName, slot2Name, sizeof(slot2Name)))
                    found = StrEqual(pickupName, slot2Name);
            }
            else
            {
                if (g_smWeaponName.GetString(slot2Classname, slot2Name, sizeof(slot2Name)))
                    found = StrEqual(pickupName, slot2Name);
            }

            slot = (found ? slot2 : slot);
        }
    }

    if (!found)
        return;

    int pickupSkin = GetEntProp(entity, Prop_Send, "m_nSkin");
    int slotSkin = GetEntProp(slot, Prop_Send, "m_nSkin");

    if (pickupSkin == slotSkin)
        return;

    if (g_bCvar_Swap)
    {
        SetEntProp(entity, Prop_Send, "m_nSkin", slotSkin);

        if (HasEntProp(entity, Prop_Data, "m_nWeaponSkin"))
            SetEntProp(entity, Prop_Data, "m_nWeaponSkin", slotSkin);
    }

    SetEntProp(slot, Prop_Send, "m_nSkin", pickupSkin);

    int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

    if (activeWeapon == -1)
        return;

    if (activeWeapon != slot)
        return;

    int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");

    if (viewModel == -1)
        return;

    SetEntProp(viewModel, Prop_Send, "m_nSkin", pickupSkin);
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "------------------ Plugin Cvars (l4d2_wskin_switch) ------------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d2_wskin_switch_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d2_wskin_switch_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_switch_swap : %b (%s)", g_bCvar_Swap, g_bCvar_Swap ? "true" : "false");
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}

// ====================================================================================================
// Helpers
// ====================================================================================================
/**
 * Converts the string to lower case.
 *
 * @param input         Input string.
 */
void StringToLowerCase(char[] input)
{
    for (int i = 0; i < strlen(input); i++)
    {
        input[i] = CharToLower(input[i]);
    }
}