#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#define SMOKER_TONGUE_DELAY 0.1

ConVar hCvarTongueDelay;
ConVar hCvarSmokerHealth;
ConVar hCvarChokeDamageInterrupt;

static ConVar g_hCvarEnable; 
static bool g_bCvarEnable;

public void Smoker_OnModuleStart() {

    g_hCvarEnable 		= CreateConVar( "AI_HardSI_Smoker_enable",   "1",   "0=Improves the Smoker behaviour off, 1=Improves the Smoker behaviour on.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    
    GetCvars();
    g_hCvarEnable.AddChangeHook(ConVarChanged_EnableCvars);

	// Smoker health
    hCvarSmokerHealth = FindConVar("z_gas_health");
    
    // Damage required to kill a smoker that is pulling someone
    hCvarChokeDamageInterrupt = FindConVar("tongue_break_from_damage_amount"); 

    // Delay before smoker shoots its tongue
    hCvarTongueDelay = FindConVar("smoker_tongue_delay"); 

    if(g_bCvarEnable) _OnModuleStart();
    hCvarSmokerHealth.AddChangeHook(OnSmokerHealthChanged); 
    hCvarChokeDamageInterrupt.AddChangeHook(OnTongueCvarChange);    
    hCvarTongueDelay.AddChangeHook(OnTongueCvarChange);
}

static void _OnModuleStart()
{
    hCvarChokeDamageInterrupt.SetInt(hCvarSmokerHealth.IntValue); // default 50
    hCvarTongueDelay.SetFloat(SMOKER_TONGUE_DELAY); // default 1.5
}

public void Smoker_OnModuleEnd() {
	hCvarChokeDamageInterrupt.RestoreDefault();
	hCvarTongueDelay.RestoreDefault();
}

static void ConVarChanged_EnableCvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
    GetCvars();
    if(g_bCvarEnable)
    {
        _OnModuleStart();
    }
    else
    {
        Smoker_OnModuleEnd();
    }
}

static void GetCvars()
{
    g_bCvarEnable = g_hCvarEnable.BoolValue;
}

// Game tries to reset these cvars
public void OnTongueCvarChange(ConVar convar, const char[] oldValue, const char[] newValue) {

    if(g_bCvarEnable) _OnModuleStart();
}

// Update choke damage interrupt to match smoker max health
public void OnSmokerHealthChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    if(g_bCvarEnable) _OnModuleStart();
}