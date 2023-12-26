/**
// ====================================================================================================
Change Log:

1.0.5 (04-June-2021)
    - Added gascan option.

1.0.4 (10-November-2020)
    - Added cvar to select which weapons should have a skin option.

1.0.3 (03-November-2020)
    - Fixed weapon skins on bots.

1.0.2 (03-November-2020)
    - Added client preferences support (cookies).
    - Improved menu layout and options.
    - Added all weapons (with skins) to menu.
    - Removed "Invalid Equipment" phrase.
    - Added missing value on !setwskin command to spawner entities.
    - Added Russian (ru) and Ukrainian (ua) translation (thanks to "Dragokas")
    - Fixed compatibility with the RNG skin plugin.

1.0.1 (30-September-2020)
    - Added intro message. (thanks to "KasperH" for requesting)
    - Added !getwskin command to get the current weapon target skin value.
    - Added !setwskin <value> command to set the target weapon skin value.
    - Improved the melee detection through "m_strMapSetScriptName" netprop. (thanks to "Silvers")
    - Improved the menu navigation.
    - Updated translation file to be more color friendly.
    - Added Hungarian (hu) translation. (thanks to "KasperH")
    - Added Simplified Chinese (chi) and Traditional Chinese (zho) translations. (thanks to "HarryPotter")

1.0.0 (29-September-2020)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D2] Weapons Skins Menu"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Opens a menu for the client to choose their own weapons skin"
#define PLUGIN_VERSION                "1.0.5"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=327611"

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
#include <clientprefs>

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
#define CONFIG_FILENAME               "l4d2_wskin_menu"
#define TRANSLATION_FILENAME          "l4d2_wskin_menu.phrases"

// ====================================================================================================
// Defines
// ====================================================================================================
#define TEAM_SURVIVOR                 2
#define TEAM_HOLDOUT                  4

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;
ConVar g_hCvar_Intro;
ConVar g_hCvar_Cookies;
ConVar g_hCvar_SortEquippedFirst;
ConVar g_hCvar_ShowEquippedIcon;
ConVar g_hCvar_PistolMagnum;
ConVar g_hCvar_PumpShotgun;
ConVar g_hCvar_ShotgunChrome;
ConVar g_hCvar_AutoShotgun;
ConVar g_hCvar_SMGUzi;
ConVar g_hCvar_SMGSilenced;
ConVar g_hCvar_RifleM16;
ConVar g_hCvar_RifleAK47;
ConVar g_hCvar_HuntingRifle;
ConVar g_hCvar_CricketBat;
ConVar g_hCvar_Crowbar;
ConVar g_hCvar_Gascan;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bCvar_Enabled;
bool g_bCvar_Intro;
bool g_bCvar_Cookies;
bool g_bCvar_SortEquippedFirst;
bool g_bCvar_ShowEquippedIcon;
bool g_bCvar_PistolMagnum;
bool g_bCvar_PumpShotgun;
bool g_bCvar_ShotgunChrome;
bool g_bCvar_AutoShotgun;
bool g_bCvar_SMGUzi;
bool g_bCvar_SMGSilenced;
bool g_bCvar_RifleM16;
bool g_bCvar_RifleAK47;
bool g_bCvar_HuntingRifle;
bool g_bCvar_CricketBat;
bool g_bCvar_Crowbar;
bool g_bCvar_Melee;
bool g_bCvar_Gascan;

// ====================================================================================================
// float - Plugin Variables
// ====================================================================================================
float g_fCvar_Intro;

// ====================================================================================================
// client - Plugin Variables
// ====================================================================================================
bool gc_bWeaponSwitchPostHooked[MAXPLAYERS+1];
int gc_iMenuWeaponRef[MAXPLAYERS+1];
char gc_sMenuWeaponSkinName[MAXPLAYERS+1][22];
int gc_iMenuPageIndex[MAXPLAYERS+1];
int gc_iSkin_PistolMagnum[MAXPLAYERS+1];
int gc_iSkin_SMGUzi[MAXPLAYERS+1];
int gc_iSkin_SMGSilenced[MAXPLAYERS+1];
int gc_iSkin_PumpShotgun[MAXPLAYERS+1];
int gc_iSkin_ShotgunChrome[MAXPLAYERS+1];
int gc_iSkin_AutoShotgun[MAXPLAYERS+1];
int gc_iSkin_RifleM16[MAXPLAYERS+1];
int gc_iSkin_RifleAK47[MAXPLAYERS+1];
int gc_iSkin_HuntingRifle[MAXPLAYERS+1];
int gc_iSkin_CricketBat[MAXPLAYERS+1];
int gc_iSkin_Crowbar[MAXPLAYERS+1];
int gc_iSkin_Gascan[MAXPLAYERS+1];

// ====================================================================================================
// StringMap - Plugin Variables
// ====================================================================================================
StringMap g_smWeaponCount;
StringMap g_smWeaponName;

// ====================================================================================================
// Cookies - Plugin Variables
// ====================================================================================================
Cookie g_ciSkin_PistolMagnum;
Cookie g_ciSkin_SMGUzi;
Cookie g_ciSkin_SMGSilenced;
Cookie g_ciSkin_PumpShotgun;
Cookie g_ciSkin_ShotgunChrome;
Cookie g_ciSkin_AutoShotgun;
Cookie g_ciSkin_RifleM16;
Cookie g_ciSkin_RifleAK47;
Cookie g_ciSkin_HuntingRifle;
Cookie g_ciSkin_CricketBat;
Cookie g_ciSkin_Crowbar;
Cookie g_ciSkin_Gascan;

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
    g_smWeaponCount = new StringMap();
    g_smWeaponName = new StringMap();

    LoadPluginTranslations();

    CreateConVar("l4d2_wskin_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled           = CreateConVar("l4d2_wskin_enable", "1", "Enable/Disable the plugin.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Intro             = CreateConVar("l4d2_wskin_intro", "60.0", "Show intro message in chat this many seconds after a client joins.\n0 = OFF.", CVAR_FLAGS, true, 0.0);
    g_hCvar_SortEquippedFirst = CreateConVar("l4d2_wskin_sort_equipped_first", "1", "Equipped weapons appear first in the menu.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_ShowEquippedIcon  = CreateConVar("l4d2_wskin_show_equipped_icon", "1", "Shows a different icon for equipped weapons in menu if sorted (l4d2_wskin_sort_equipped_first = \"1\").\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Cookies           = CreateConVar("l4d2_wskin_cookies", "1", "Allow cookies for storing client preferences.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_PistolMagnum      = CreateConVar("l4d2_wskin_pistol_magnum", "1", "Weapon skin option for Pistol Magnum.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_PumpShotgun       = CreateConVar("l4d2_wskin_pump_shotgun", "1", "Weapon skin option for Pump Shotgun.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_ShotgunChrome     = CreateConVar("l4d2_wskin_shotgun_chrome", "1", "Weapon skin option for Chrome Shotgun.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_AutoShotgun       = CreateConVar("l4d2_wskin_auto_shotgun", "1", "Weapon skin option for Auto Shotgun.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_SMGUzi            = CreateConVar("l4d2_wskin_smg_uzi", "1", "Weapon skin option for SMG Uzi.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_SMGSilenced       = CreateConVar("l4d2_wskin_smg_silenced", "1", "Weapon skin option for Silenced SMG.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_RifleM16          = CreateConVar("l4d2_wskin_rifle_m16", "1", "Weapon skin option for M16 Rifle.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_RifleAK47         = CreateConVar("l4d2_wskin_rifle_ak47", "1", "Weapon skin option for AK47 Rifle.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_HuntingRifle      = CreateConVar("l4d2_wskin_hunting_rifle", "1", "Weapon skin option for Hunting Rifle.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_CricketBat        = CreateConVar("l4d2_wskin_cricket_bat", "1", "Weapon skin option for Cricket Bat melee.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Crowbar           = CreateConVar("l4d2_wskin_crowbar", "1", "Weapon skin option for Crowbar melee.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Gascan            = CreateConVar("l4d2_wskin_gascan", "0", "Weapon skin option for Gascan.\nNote: Enabling this may glitch some plugins that check the gascan skin to detect if is a scavenge one.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Intro.AddChangeHook(Event_ConVarChanged);
    g_hCvar_SortEquippedFirst.AddChangeHook(Event_ConVarChanged);
    g_hCvar_ShowEquippedIcon.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Cookies.AddChangeHook(Event_ConVarChanged);
    g_hCvar_PistolMagnum.AddChangeHook(Event_ConVarChanged);
    g_hCvar_PumpShotgun.AddChangeHook(Event_ConVarChanged);
    g_hCvar_ShotgunChrome.AddChangeHook(Event_ConVarChanged);
    g_hCvar_AutoShotgun.AddChangeHook(Event_ConVarChanged);
    g_hCvar_SMGUzi.AddChangeHook(Event_ConVarChanged);
    g_hCvar_SMGSilenced.AddChangeHook(Event_ConVarChanged);
    g_hCvar_RifleM16.AddChangeHook(Event_ConVarChanged);
    g_hCvar_RifleAK47.AddChangeHook(Event_ConVarChanged);
    g_hCvar_HuntingRifle.AddChangeHook(Event_ConVarChanged);
    g_hCvar_CricketBat.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Crowbar.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Gascan.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Cookies
    g_ciSkin_PistolMagnum = new Cookie("l4d2_wskin_pistol_magnum", "Weapons Skins Menu Cookie - Pistol Magnum", CookieAccess_Protected);
    g_ciSkin_SMGUzi = new Cookie("l4d2_wskin_smg_uzi", "Weapons Skins Menu Cookie - SMG Uzi", CookieAccess_Protected);
    g_ciSkin_SMGSilenced = new Cookie("l4d2_wskin_smg_silenced", "Weapons Skins Menu Cookie - SMG Silenced", CookieAccess_Protected);
    g_ciSkin_PumpShotgun = new Cookie("l4d2_wskin_pump_shotgun", "Weapons Skins Menu Cookie - Pump Shotgun", CookieAccess_Protected);
    g_ciSkin_ShotgunChrome = new Cookie("l4d2_wskin_shotgun_chrome", "Weapons Skins Menu Cookie - Shotgun Chrome", CookieAccess_Protected);
    g_ciSkin_AutoShotgun = new Cookie("l4d2_wskin_auto_shotgun", "Weapons Skins Menu Cookie - Auto Shotgun", CookieAccess_Protected);
    g_ciSkin_RifleM16 = new Cookie("l4d2_wskin_rifle", "Weapons Skins Menu Cookie - Rifle M16", CookieAccess_Protected);
    g_ciSkin_RifleAK47 = new Cookie("l4d2_wskin_rifle_ak47", "Weapons Skins Menu Cookie - Rifle AK47", CookieAccess_Protected);
    g_ciSkin_HuntingRifle = new Cookie("l4d2_wskin_hunting_rifle", "Weapons Skins Menu Cookie - Hunting Rifle", CookieAccess_Protected);
    g_ciSkin_CricketBat = new Cookie("l4d2_wskin_cricket_bat", "Weapons Skins Menu Cookie - Cricket Bat Melee", CookieAccess_Protected);
    g_ciSkin_Crowbar = new Cookie("l4d2_wskin_crowbar", "Weapons Skins Menu Cookie - Crowbar Melee", CookieAccess_Protected);
    g_ciSkin_Gascan = new Cookie("l4d2_wskin_gascan", "Weapons Skins Menu Cookie - Gascan", CookieAccess_Protected);

    // Commands
    RegConsoleCmd("sm_wskin", CmdWSkin, "Opens a menu to select and configure the weapon skins.");

    // Admin Commands
    RegAdminCmd("sm_getwskin", CmdGetWeaponSkin, ADMFLAG_ROOT, "Output to the chat the target skin/classname/model value of entities with \"weapon_*\" classname.");
    RegAdminCmd("sm_setwskin", CmdSetWeaponSkin, ADMFLAG_ROOT, "Set the target skin value of entities with \"weapon_*\" classname. Usage: sm_setwskin <value>.");
    RegAdminCmd("sm_print_cvars_l4d2_wskin", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");
}

/****************************************************************************************************/

void LoadPluginTranslations()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "translations/%s.txt", TRANSLATION_FILENAME);
    if (FileExists(path))
        LoadTranslations(TRANSLATION_FILENAME);
    else
        SetFailState("Missing required translation file on \"translations/%s.txt\", please re-download.", TRANSLATION_FILENAME);
}

/****************************************************************************************************/

public void OnConfigsExecuted()
{
    GetCvars();

    LateLoad();
}

/****************************************************************************************************/

void Event_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();
}

/****************************************************************************************************/

void GetCvars()
{
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
    g_fCvar_Intro = g_hCvar_Intro.FloatValue;
    g_bCvar_Intro = (g_fCvar_Intro > 0.0);
    g_bCvar_Cookies = g_hCvar_Cookies.BoolValue;
    g_bCvar_SortEquippedFirst = g_hCvar_SortEquippedFirst.BoolValue;
    g_bCvar_ShowEquippedIcon = g_hCvar_ShowEquippedIcon.BoolValue;
    g_bCvar_PistolMagnum = g_hCvar_PistolMagnum.BoolValue;
    g_bCvar_PumpShotgun = g_hCvar_PumpShotgun.BoolValue;
    g_bCvar_ShotgunChrome = g_hCvar_ShotgunChrome.BoolValue;
    g_bCvar_AutoShotgun = g_hCvar_AutoShotgun.BoolValue;
    g_bCvar_SMGUzi = g_hCvar_SMGUzi.BoolValue;
    g_bCvar_SMGSilenced = g_hCvar_SMGSilenced.BoolValue;
    g_bCvar_RifleM16 = g_hCvar_RifleM16.BoolValue;
    g_bCvar_RifleAK47 = g_hCvar_RifleAK47.BoolValue;
    g_bCvar_HuntingRifle = g_hCvar_HuntingRifle.BoolValue;
    g_bCvar_CricketBat = g_hCvar_CricketBat.BoolValue;
    g_bCvar_Crowbar = g_hCvar_Crowbar.BoolValue;
    g_bCvar_Melee = (g_bCvar_CricketBat || g_bCvar_Crowbar);
    g_bCvar_Gascan = g_hCvar_Gascan.BoolValue;

    BuildMaps();
}

/****************************************************************************************************/

void BuildMaps()
{
    g_smWeaponCount.Clear();
    g_smWeaponName.Clear();

    if (g_bCvar_PistolMagnum)
    {
        g_smWeaponCount.SetValue("weapon_pistol_magnum", 2);
        g_smWeaponName.SetString("weapon_pistol_magnum", "Magnum");
    }

    if (g_bCvar_SMGUzi)
    {
        g_smWeaponCount.SetValue("weapon_smg", 1);
        g_smWeaponName.SetString("weapon_smg", "Uzi");
    }

    if (g_bCvar_SMGSilenced)
    {
        g_smWeaponCount.SetValue("weapon_smg_silenced", 1);
        g_smWeaponName.SetString("weapon_smg_silenced", "Silenced");
    }

    if (g_bCvar_PumpShotgun)
    {
        g_smWeaponCount.SetValue("weapon_pumpshotgun", 1);
        g_smWeaponName.SetString("weapon_pumpshotgun", "Pump Shotgun");
    }

    if (g_bCvar_ShotgunChrome)
    {
        g_smWeaponCount.SetValue("weapon_shotgun_chrome", 1);
        g_smWeaponName.SetString("weapon_shotgun_chrome", "Chrome Shotgun");
    }

    if (g_bCvar_AutoShotgun)
    {
        g_smWeaponCount.SetValue("weapon_autoshotgun", 1);
        g_smWeaponName.SetString("weapon_autoshotgun", "Auto Shotgun");
    }

    if (g_bCvar_RifleM16)
    {
        g_smWeaponCount.SetValue("weapon_rifle", 2);
        g_smWeaponName.SetString("weapon_rifle", "M16");
    }

    if (g_bCvar_RifleAK47)
    {
        g_smWeaponCount.SetValue("weapon_rifle_ak47", 2);
        g_smWeaponName.SetString("weapon_rifle_ak47", "AK47");
    }

    if (g_bCvar_HuntingRifle)
    {
        g_smWeaponCount.SetValue("weapon_hunting_rifle", 1);
        g_smWeaponName.SetString("weapon_hunting_rifle", "Hunting Rifle");
    }

    if (g_bCvar_CricketBat)
    {
        g_smWeaponCount.SetValue("crowbar", 1);
        g_smWeaponName.SetString("crowbar", "Crowbar");
    }

    if (g_bCvar_Crowbar)
    {
        g_smWeaponCount.SetValue("cricket_bat", 1);
        g_smWeaponName.SetString("cricket_bat", "Cricket Bat");
    }

    if (g_bCvar_Gascan)
    {
        g_smWeaponCount.SetValue("weapon_gascan", 3);
        g_smWeaponName.SetString("weapon_gascan", "Gascan");
    }
}

/****************************************************************************************************/

void LateLoad()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
            continue;

        OnClientPutInServer(client);

        if (AreClientCookiesCached(client))
            OnClientCookiesCached(client);
    }
}

/****************************************************************************************************/

public void OnClientPutInServer(int client)
{
    if (IsFakeClient(client))
        return;

    if (gc_bWeaponSwitchPostHooked[client])
        return;

    gc_bWeaponSwitchPostHooked[client] = true;
    SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);

    if (g_bCvar_Intro)
        CreateTimer(g_fCvar_Intro, TimerIntro, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

/****************************************************************************************************/

public void OnClientDisconnect(int client)
{
    gc_bWeaponSwitchPostHooked[client] = false;
    gc_iMenuWeaponRef[client] = 0;
    gc_sMenuWeaponSkinName[client] = "";
    gc_iMenuPageIndex[client] = 0;
    gc_iSkin_PistolMagnum[client] = 0;
    gc_iSkin_SMGUzi[client] = 0;
    gc_iSkin_SMGSilenced[client] = 0;
    gc_iSkin_PumpShotgun[client] = 0;
    gc_iSkin_ShotgunChrome[client] = 0;
    gc_iSkin_AutoShotgun[client] = 0;
    gc_iSkin_RifleM16[client] = 0;
    gc_iSkin_RifleAK47[client] = 0;
    gc_iSkin_HuntingRifle[client] = 0;
    gc_iSkin_CricketBat[client] = 0;
    gc_iSkin_Crowbar[client] = 0;
    gc_iSkin_Gascan[client] = 0;
}

/****************************************************************************************************/

public void OnClientCookiesCached(int client)
{
    if (IsFakeClient(client))
        return;

    if (!g_bCvar_Cookies)
        return;

    char cookiePistolMagnum[2];
    g_ciSkin_PistolMagnum.Get(client, cookiePistolMagnum, sizeof(cookiePistolMagnum));
    gc_iSkin_PistolMagnum[client] = StringToInt(cookiePistolMagnum);

    char cookieSMGUzi[2];
    g_ciSkin_SMGUzi.Get(client, cookieSMGUzi, sizeof(cookieSMGUzi));
    gc_iSkin_SMGUzi[client] = StringToInt(cookieSMGUzi);

    char cookieSMGSilenced[2];
    g_ciSkin_SMGSilenced.Get(client, cookieSMGSilenced, sizeof(cookieSMGSilenced));
    gc_iSkin_SMGSilenced[client] = StringToInt(cookieSMGSilenced);

    char cookiePumpShotgun[2];
    g_ciSkin_PumpShotgun.Get(client, cookiePumpShotgun, sizeof(cookiePumpShotgun));
    gc_iSkin_PumpShotgun[client] = StringToInt(cookiePumpShotgun);

    char cookieShotgunChrome[2];
    g_ciSkin_ShotgunChrome.Get(client, cookieShotgunChrome, sizeof(cookieShotgunChrome));
    gc_iSkin_ShotgunChrome[client] = StringToInt(cookieShotgunChrome);

    char cookieAutoShotgun[2];
    g_ciSkin_AutoShotgun.Get(client, cookieAutoShotgun, sizeof(cookieAutoShotgun));
    gc_iSkin_AutoShotgun[client] = StringToInt(cookieAutoShotgun);

    char cookieRifleM16[2];
    g_ciSkin_RifleM16.Get(client, cookieRifleM16, sizeof(cookieRifleM16));
    gc_iSkin_RifleM16[client] = StringToInt(cookieRifleM16);

    char cookieRifleAK47[2];
    g_ciSkin_RifleAK47.Get(client, cookieRifleAK47, sizeof(cookieRifleAK47));
    gc_iSkin_RifleAK47[client] = StringToInt(cookieRifleAK47);

    char cookieHuntingRifle[2];
    g_ciSkin_HuntingRifle.Get(client, cookieHuntingRifle, sizeof(cookieHuntingRifle));
    gc_iSkin_HuntingRifle[client] = StringToInt(cookieHuntingRifle);

    char cookieCricketBat[2];
    g_ciSkin_CricketBat.Get(client, cookieCricketBat, sizeof(cookieCricketBat));
    gc_iSkin_CricketBat[client] = StringToInt(cookieCricketBat);

    char cookieCrowbar[2];
    g_ciSkin_Crowbar.Get(client, cookieCrowbar, sizeof(cookieCrowbar));
    gc_iSkin_Crowbar[client] = StringToInt(cookieCrowbar);

    char cookieGascan[2];
    g_ciSkin_Gascan.Get(client, cookieGascan, sizeof(cookieGascan));
    gc_iSkin_Gascan[client] = StringToInt(cookieGascan);

    UpdateClientWeaponSkin(client);
}

/****************************************************************************************************/

void OnWeaponSwitchPost(int client, int weapon)
{
    if (!IsValidEntity(weapon))
        return;

    UpdateClientWeaponSkin(client);
}

/****************************************************************************************************/

void UpdateClientWeaponSkin(int client)
{
    if (!g_bCvar_Enabled)
        return;

    if (!IsValidClient(client))
        return;

    int team = GetClientTeam(client);

    if (team != TEAM_SURVIVOR && team != TEAM_HOLDOUT)
        return;

    int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

    if (activeWeapon == -1)
        return;

    char classname[36];
    GetEntityClassname(activeWeapon, classname, sizeof(classname));

    int skin = -1;

    if (StrEqual(classname, "weapon_pistol_magnum"))
    {
        if (!g_bCvar_PistolMagnum)
            return;

        skin = gc_iSkin_PistolMagnum[client];
    }
    else if (StrEqual(classname, "weapon_smg"))
    {
        if (!g_bCvar_SMGUzi)
            return;

        skin = gc_iSkin_SMGUzi[client];
    }
    else if (StrEqual(classname, "weapon_smg_silenced"))
    {
        if (!g_bCvar_SMGSilenced)
            return;

        skin = gc_iSkin_SMGSilenced[client];
    }
    else if (StrEqual(classname, "weapon_pumpshotgun"))
    {
        if (!g_bCvar_PumpShotgun)
            return;

        skin = gc_iSkin_PumpShotgun[client];
    }
    else if (StrEqual(classname, "weapon_shotgun_chrome"))
    {
        if (!g_bCvar_ShotgunChrome)
            return;

        skin = gc_iSkin_ShotgunChrome[client];
    }
    else if (StrEqual(classname, "weapon_autoshotgun"))
    {
        if (!g_bCvar_AutoShotgun)
            return;

        skin = gc_iSkin_AutoShotgun[client];
    }
    else if (StrEqual(classname, "weapon_rifle"))
    {
        if (!g_bCvar_RifleM16)
            return;

        skin = gc_iSkin_RifleM16[client];
    }
    else if (StrEqual(classname, "weapon_rifle_ak47"))
    {
        if (!g_bCvar_RifleAK47)
            return;

        skin = gc_iSkin_RifleAK47[client];
    }
    else if (StrEqual(classname, "weapon_hunting_rifle"))
    {
        if (!g_bCvar_HuntingRifle)
            return;

        skin = gc_iSkin_HuntingRifle[client];
    }
    else if (StrEqual(classname, "weapon_melee"))
    {
        if (!g_bCvar_Melee)
            return;

        char sMeleeName[16];
        GetEntPropString(activeWeapon, Prop_Data, "m_strMapSetScriptName", sMeleeName, sizeof(sMeleeName));

        if (StrEqual(sMeleeName, "cricket_bat"))
        {
            if (!g_bCvar_CricketBat)
                return;

            skin = gc_iSkin_CricketBat[client];
        }
        else if (StrEqual(sMeleeName, "crowbar"))
        {
            if (!g_bCvar_Crowbar)
                return;

            skin = gc_iSkin_Crowbar[client];
        }
    }
    else if (StrEqual(classname, "weapon_gascan"))
    {
        if (!g_bCvar_Gascan)
            return;

        skin = gc_iSkin_Gascan[client];
    }

    if (skin == -1)
        return;

    if (skin == GetEntProp(activeWeapon, Prop_Send, "m_nSkin"))
        return;

    SetEntProp(activeWeapon, Prop_Send, "m_nSkin", skin);

    int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");

    if (viewModel == -1)
        return;

    SetEntProp(viewModel, Prop_Send, "m_nSkin", skin);
}

/****************************************************************************************************/

Action TimerIntro(Handle timer, int userid)
{
    if (!g_bCvar_Enabled)
        return Plugin_Stop;

    int client = GetClientOfUserId(userid);

    if (client == 0)
        return Plugin_Stop;

    int team = GetClientTeam(client);

    if (team != TEAM_SURVIVOR && team != TEAM_HOLDOUT)
        return Plugin_Stop;

    CPrintToChat(client, "%t", "Intro");

    return Plugin_Stop;
}

// ====================================================================================================
// Commands
// ====================================================================================================
Action CmdWSkin(int client, int args)
{
    if (!g_bCvar_Enabled)
        return Plugin_Handled;

    if (!IsValidClient(client))
        return Plugin_Handled;

    gc_iMenuPageIndex[client] = 0;

    CreateWeaponMenu(client);

    return Plugin_Handled;
}

// ====================================================================================================
// Menus
// ====================================================================================================
void CreateWeaponMenu(int client)
{
    Menu menu = new Menu(HandleWeaponMenu);
    menu.SetTitle("%T", "Weapon skins", client);

    char sWeaponSlot1[36];
    char sWeaponSlot2[36];
    char sWeaponSlot5[36];
    char buffer[19];

    if (g_bCvar_SortEquippedFirst)
    {
        int entity;
        char sTemp[36];
        char sTemp2[36];

        entity = GetPlayerWeaponSlot(client, 0);

        if (IsValidEntity(entity))
        {
            GetEntityClassname(entity, sTemp, sizeof(sTemp));

            if (g_smWeaponName.GetString(sTemp, sTemp2, sizeof(sTemp2)))
                sWeaponSlot1 = sTemp;
        }

        entity = GetPlayerWeaponSlot(client, 1);

        if (IsValidEntity(entity))
        {
            GetEntityClassname(entity, sTemp, sizeof(sTemp));

            if (StrEqual(sTemp, "weapon_melee"))
            {
                if (g_bCvar_Melee)
                {
                    GetEntPropString(entity, Prop_Data, "m_strMapSetScriptName", sTemp, sizeof(sTemp));

                    if (g_smWeaponName.GetString(sTemp, sTemp2, sizeof(sTemp2)))
                        sWeaponSlot2 = sTemp;
                }
            }
            else
            {
                if (g_smWeaponName.GetString(sTemp, sTemp2, sizeof(sTemp2)))
                    sWeaponSlot2 = sTemp;
            }
        }

        entity = GetPlayerWeaponSlot(client, 5);

        if (IsValidEntity(entity))
        {
            GetEntityClassname(entity, sTemp, sizeof(sTemp));

            if (g_smWeaponName.GetString(sTemp, sTemp2, sizeof(sTemp2)))
                sWeaponSlot5 = sTemp;
        }

        if (sWeaponSlot1[0] != 0)
        {
            g_smWeaponName.GetString(sWeaponSlot1, buffer, sizeof(buffer));

            if (g_bCvar_ShowEquippedIcon)
                Format(buffer, sizeof(buffer), "❶ %s", buffer);

            menu.AddItem(sWeaponSlot1, buffer);
        }

        if (sWeaponSlot2[0] != 0)
        {
            g_smWeaponName.GetString(sWeaponSlot2, buffer, sizeof(buffer));

            if (g_bCvar_ShowEquippedIcon)
                Format(buffer, sizeof(buffer), "❷ %s", buffer);

            menu.AddItem(sWeaponSlot2, buffer);
        }

        if (sWeaponSlot5[0] != 0)
        {
            g_smWeaponName.GetString(sWeaponSlot5, buffer, sizeof(buffer));

            if (g_bCvar_ShowEquippedIcon)
                Format(buffer, sizeof(buffer), "✖ %s", buffer);

            menu.AddItem(sWeaponSlot5, buffer);
        }
    }

    if (!StrEqual(sWeaponSlot2, "weapon_pistol_magnum"))
    {
        if (g_smWeaponName.GetString("weapon_pistol_magnum", buffer, sizeof(buffer)))
            menu.AddItem("weapon_pistol_magnum", buffer);
    }

    if (!StrEqual(sWeaponSlot1, "weapon_smg"))
    {
        if (g_smWeaponName.GetString("weapon_smg", buffer, sizeof(buffer)))
            menu.AddItem("weapon_smg", buffer);
    }

    if (!StrEqual(sWeaponSlot1, "weapon_smg_silenced"))
    {
        if (g_smWeaponName.GetString("weapon_smg_silenced", buffer, sizeof(buffer)))
            menu.AddItem("weapon_smg_silenced", buffer);
    }

    if (!StrEqual(sWeaponSlot1, "weapon_pumpshotgun"))
    {
        if (g_smWeaponName.GetString("weapon_pumpshotgun", buffer, sizeof(buffer)))
            menu.AddItem("weapon_pumpshotgun", buffer);
    }

    if (!StrEqual(sWeaponSlot1, "weapon_shotgun_chrome"))
    {
        if (g_smWeaponName.GetString("weapon_shotgun_chrome", buffer, sizeof(buffer)))
            menu.AddItem("weapon_shotgun_chrome", buffer);
    }

    if (!StrEqual(sWeaponSlot1, "weapon_autoshotgun"))
    {
        if (g_smWeaponName.GetString("weapon_autoshotgun", buffer, sizeof(buffer)))
            menu.AddItem("weapon_autoshotgun", buffer);
    }

    if (!StrEqual(sWeaponSlot1, "weapon_rifle"))
    {
        if (g_smWeaponName.GetString("weapon_rifle", buffer, sizeof(buffer)))
            menu.AddItem("weapon_rifle", buffer);
    }

    if (!StrEqual(sWeaponSlot1, "weapon_rifle_ak47"))
    {
        if (g_smWeaponName.GetString("weapon_rifle_ak47", buffer, sizeof(buffer)))
            menu.AddItem("weapon_rifle_ak47", buffer);
    }

    if (!StrEqual(sWeaponSlot1, "weapon_hunting_rifle"))
    {
        if (g_smWeaponName.GetString("weapon_hunting_rifle", buffer, sizeof(buffer)))
            menu.AddItem("weapon_hunting_rifle", buffer);
    }

    if (!StrEqual(sWeaponSlot2, "cricket_bat"))
    {
        if (g_smWeaponName.GetString("cricket_bat", buffer, sizeof(buffer)))
            menu.AddItem("cricket_bat", buffer);
    }

    if (!StrEqual(sWeaponSlot2, "crowbar"))
    {
        if (g_smWeaponName.GetString("crowbar", buffer, sizeof(buffer)))
            menu.AddItem("crowbar", buffer);
    }

    if (!StrEqual(sWeaponSlot5, "weapon_gascan"))
    {
        if (g_smWeaponName.GetString("weapon_gascan", buffer, sizeof(buffer)))
            menu.AddItem("weapon_gascan", buffer);
    }

    menu.DisplayAt(client, gc_iMenuPageIndex[client], MENU_TIME_FOREVER);
}

/****************************************************************************************************/

int HandleWeaponMenu(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            int client = param1;

            char sArg[22];
            menu.GetItem(param2, sArg, sizeof(sArg));

            gc_iMenuPageIndex[client] = GetMenuSelectionPosition();
            gc_sMenuWeaponSkinName[client] = sArg;

            CreateWeaponSkinMenu(client);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

/****************************************************************************************************/

void CreateWeaponSkinMenu(int client)
{
    char sArg[22];
    sArg = gc_sMenuWeaponSkinName[client];

    int count;
    if (!g_smWeaponCount.GetValue(sArg, count))
        return;

    Menu menu = new Menu(HandleWeaponSkinMenu);
    menu.SetTitle("%T", "Select a skin", client);
    menu.ExitBackButton = true;

    char sSkin[32];
    char sSkinIndex[2];

    int skin;

    if (StrEqual(sArg, "weapon_pistol_magnum"))
        skin = gc_iSkin_PistolMagnum[client];
    else if (StrEqual(sArg, "weapon_smg"))
        skin = gc_iSkin_SMGUzi[client];
    else if (StrEqual(sArg, "weapon_smg_silenced"))
        skin = gc_iSkin_SMGSilenced[client];
    else if (StrEqual(sArg, "weapon_pumpshotgun"))
        skin = gc_iSkin_PumpShotgun[client];
    else if (StrEqual(sArg, "weapon_shotgun_chrome"))
        skin = gc_iSkin_ShotgunChrome[client];
    else if (StrEqual(sArg, "weapon_autoshotgun"))
        skin = gc_iSkin_AutoShotgun[client];
    else if (StrEqual(sArg, "weapon_rifle"))
        skin = gc_iSkin_RifleM16[client];
    else if (StrEqual(sArg, "weapon_rifle_ak47"))
        skin = gc_iSkin_RifleAK47[client];
    else if (StrEqual(sArg, "weapon_hunting_rifle"))
        skin = gc_iSkin_HuntingRifle[client];
    else if (StrEqual(sArg, "cricket_bat"))
        skin = gc_iSkin_CricketBat[client];
    else if (StrEqual(sArg, "crowbar"))
        skin = gc_iSkin_Crowbar[client];
    else if (StrEqual(sArg, "weapon_gascan"))
        skin = gc_iSkin_Gascan[client];

    for (int i = 0; i <= count; i++)
    {
        FormatEx(sSkin, sizeof(sSkin), "%s %s %i", skin == i ? "☑" : "☐", Translate(client, "%t", "Skin"), i + 1);
        IntToString(i, sSkinIndex, sizeof(sSkinIndex));
        menu.AddItem(sSkinIndex, sSkin);
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

/****************************************************************************************************/

int HandleWeaponSkinMenu(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            int client = param1;

            char sArg[10];
            menu.GetItem(param2, sArg, sizeof(sArg));

            int skin = StringToInt(sArg);

            char sWeaponSkinName[22];
            sWeaponSkinName = gc_sMenuWeaponSkinName[client];

            if (g_bCvar_Cookies)
            {
                if (StrEqual(sWeaponSkinName, "weapon_pistol_magnum"))
                {
                    gc_iSkin_PistolMagnum[client] = skin;
                    g_ciSkin_PistolMagnum.Set(client, sArg);
                }
                else if (StrEqual(sWeaponSkinName, "weapon_smg"))
                {
                    gc_iSkin_SMGUzi[client] = skin;
                    g_ciSkin_SMGUzi.Set(client, sArg);
                }
                else if (StrEqual(sWeaponSkinName, "weapon_smg_silenced"))
                {
                    gc_iSkin_SMGSilenced[client] = skin;
                    g_ciSkin_SMGSilenced.Set(client, sArg);
                }
                else if (StrEqual(sWeaponSkinName, "weapon_pumpshotgun"))
                {
                    gc_iSkin_PumpShotgun[client] = skin;
                    g_ciSkin_PumpShotgun.Set(client, sArg);
                }
                else if (StrEqual(sWeaponSkinName, "weapon_shotgun_chrome"))
                {
                    gc_iSkin_ShotgunChrome[client] = skin;
                    g_ciSkin_ShotgunChrome.Set(client, sArg);
                }
                else if (StrEqual(sWeaponSkinName, "weapon_autoshotgun"))
                {
                    gc_iSkin_AutoShotgun[client] = skin;
                    g_ciSkin_AutoShotgun.Set(client, sArg);
                }
                else if (StrEqual(sWeaponSkinName, "weapon_rifle"))
                {
                    gc_iSkin_RifleM16[client] = skin;
                    g_ciSkin_RifleM16.Set(client, sArg);
                }
                else if (StrEqual(sWeaponSkinName, "weapon_rifle_ak47"))
                {
                    gc_iSkin_RifleAK47[client] = skin;
                    g_ciSkin_RifleAK47.Set(client, sArg);
                }
                else if (StrEqual(sWeaponSkinName, "weapon_hunting_rifle"))
                {
                    gc_iSkin_HuntingRifle[client] = skin;
                    g_ciSkin_HuntingRifle.Set(client, sArg);
                }
                else if (StrEqual(sWeaponSkinName, "cricket_bat"))
                {
                    gc_iSkin_CricketBat[client] = skin;
                    g_ciSkin_CricketBat.Set(client, sArg);
                }
                else if (StrEqual(sWeaponSkinName, "crowbar"))
                {
                    gc_iSkin_Crowbar[client] = skin;
                    g_ciSkin_Crowbar.Set(client, sArg);
                }
                else if (StrEqual(sWeaponSkinName, "weapon_gascan"))
                {
                    gc_iSkin_Gascan[client] = skin;
                    g_ciSkin_Gascan.Set(client, sArg);
                }
            }

            UpdateClientWeaponSkin(client);

            CreateWeaponSkinMenu(client);
        }
        case MenuAction_Cancel:
        {
            int client = param1;

            if (param2 == MenuCancel_ExitBack)
                CreateWeaponMenu(client);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
Action CmdGetWeaponSkin(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    int entity = GetClientAimTarget(client, false);

    if (!IsValidEntity(entity))
    {
        PrintToChat(client, "\x05Invalid target. \x03Usable only on entities with \x04weapon_* \x03classname.");
        return Plugin_Handled;
    }

    char classname[36];
    GetEntityClassname(entity, classname, sizeof(classname));

    if (classname[0] != 'w' || classname[1] != 'e') // weapon_*
    {
        PrintToChat(client, "\x05Invalid target. \x03Usable only on entities with \x04weapon_* \x03classname.");
        return Plugin_Handled;
    }

    int skin = GetEntProp(entity, Prop_Send, "m_nSkin");

    char modelname[PLATFORM_MAX_PATH];
    GetEntPropString(entity, Prop_Data, "m_ModelName", modelname, sizeof(modelname));

    PrintToChat(client, "\x05Skin: \x03%i\n\x05Class: \x03%s\n\x05Model: \x03%s", skin, classname, modelname);

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdSetWeaponSkin(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    if (args < 1)
    {
        PrintToChat(client, "\x05Usage: \x03!setwskin \x04<value>");
        return Plugin_Handled;
    }

    int entity = GetClientAimTarget(client, false);

    if (!IsValidEntity(entity))
    {
        PrintToChat(client, "\x05Invalid target. \x03Usable only on entities with \x04weapon_* \x03classname.");
        return Plugin_Handled;
    }

    char classname[36];
    GetEntityClassname(entity, classname, sizeof(classname));

    if (classname[0] != 'w' || classname[1] != 'e') // weapon_*
    {
        PrintToChat(client, "\x05Invalid target. \x03Usable only on entities with \x04weapon_* \x03classname.");
        return Plugin_Handled;
    }

    int skin_old = GetEntProp(entity, Prop_Send, "m_nSkin");

    char sTemp[3];
    GetCmdArg(1, sTemp, sizeof(sTemp));

    int skin_new = StringToInt(sTemp);

    SetEntProp(entity, Prop_Send, "m_nSkin", skin_new);

    if (HasEntProp(entity, Prop_Data, "m_nWeaponSkin"))
        SetEntProp(entity, Prop_Data, "m_nWeaponSkin", skin_new);

    PrintToChat(client, "\x05Skin \x03changed from \x04%i \x03to \x04%i", skin_old, skin_new);

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "--------------------- Plugin Cvars (l4d2_wskin) ----------------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d2_wskin_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d2_wskin_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_intro : %.1f (%s)", g_fCvar_Intro, g_bCvar_Intro ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_cookies : %b (%s)", g_bCvar_Cookies, g_bCvar_Cookies ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_sort_equipped_first : %b (%s)", g_bCvar_SortEquippedFirst, g_bCvar_SortEquippedFirst ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_show_equipped_icon : %b (%s)", g_bCvar_ShowEquippedIcon, g_bCvar_ShowEquippedIcon ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_pistol_magnum : %b (%s)", g_bCvar_PistolMagnum, g_bCvar_PistolMagnum ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_pump_shotgun : %b (%s)", g_bCvar_PumpShotgun, g_bCvar_PumpShotgun ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_shotgun_chrome : %b (%s)", g_bCvar_ShotgunChrome, g_bCvar_ShotgunChrome ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_auto_shotgun : %b (%s)", g_bCvar_AutoShotgun, g_bCvar_AutoShotgun ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_smg_uzi : %b (%s)", g_bCvar_SMGUzi, g_bCvar_SMGUzi ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_smg_silenced : %b (%s)", g_bCvar_SMGSilenced, g_bCvar_SMGSilenced ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_rifle_m16 : %b (%s)", g_bCvar_RifleM16, g_bCvar_RifleM16 ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_rifle_ak47 : %b (%s)", g_bCvar_RifleAK47, g_bCvar_RifleAK47 ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_hunting_rifle : %b (%s)", g_bCvar_HuntingRifle, g_bCvar_HuntingRifle ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_cricket_bat : %b (%s)", g_bCvar_CricketBat, g_bCvar_CricketBat ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_crowbar : %b (%s)", g_bCvar_Crowbar, g_bCvar_Crowbar ? "true" : "false");
    PrintToConsole(client, "l4d2_wskin_gascan : %b (%s)", g_bCvar_Gascan, g_bCvar_Gascan ? "true" : "false");
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}

// ====================================================================================================
// Helpers
// ====================================================================================================
/**
 * Validates if is a valid client index.
 *
 * @param client          Client index.
 * @return                True if client index is valid, false otherwise.
 */
bool IsValidClientIndex(int client)
{
    return (1 <= client <= MaxClients);
}

/****************************************************************************************************/

/**
 * Validates if is a valid client.
 *
 * @param client          Client index.
 * @return                True if client index is valid and client is in game, false otherwise.
 */
bool IsValidClient(int client)
{
    return (IsValidClientIndex(client) && IsClientInGame(client));
}

/****************************************************************************************************/

/**
 * Convert string to its translated value.
 *
 * @param  client          Client index. Translation based on this client index.
 * @param message         Message (formatting rules). Must have a "%t" specifier.
 * @return char[512]       Resulting string.
 */
char[] Translate(int client, const char[] message, any ...)
{
    char buffer[512];
    SetGlobalTransTarget(client);
    VFormat(buffer, sizeof(buffer), message, 3);
    return buffer;
}

// ====================================================================================================
// colors.inc replacement (Thanks to Silvers)
// ====================================================================================================
/**
 * Prints a message to a specific client in the chat area.
 * Supports color tags.
 *
 * @param client          Client index.
 * @param message         Message (formatting rules).
 *
 * On error/Errors:       If the client is not connected an error will be thrown.
 */
void CPrintToChat(int client, char[] message, any ...)
{
    char buffer[512];
    SetGlobalTransTarget(client);
    VFormat(buffer, sizeof(buffer), message, 3);

    ReplaceString(buffer, sizeof(buffer), "{default}", "\x01");
    ReplaceString(buffer, sizeof(buffer), "{white}", "\x01");
    ReplaceString(buffer, sizeof(buffer), "{cyan}", "\x03");
    ReplaceString(buffer, sizeof(buffer), "{lightgreen}", "\x03");
    ReplaceString(buffer, sizeof(buffer), "{orange}", "\x04");
    ReplaceString(buffer, sizeof(buffer), "{green}", "\x04"); // Actually orange in L4D1/L4D2, but replicating colors.inc behaviour
    ReplaceString(buffer, sizeof(buffer), "{olive}", "\x05");

    PrintToChat(client, buffer);
}