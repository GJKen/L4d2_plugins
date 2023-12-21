#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
ConVar hCvarBoomerExposedTimeTolerance;
ConVar hCvarBoomerVomitDelay;

static ConVar g_hCvarEnable; 
static bool g_bCvarEnable;

public void Boomer_OnModuleStart() {
	g_hCvarEnable 		= CreateConVar( "AI_HardSI_Boomer_enable",   "1",   "0=Improves the Boomer behaviour off, 1=Improves the Boomer behaviour on.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_EnableCvars);
	
	hCvarBoomerExposedTimeTolerance = FindConVar("boomer_exposed_time_tolerance");	
	hCvarBoomerVomitDelay = FindConVar("boomer_vomit_delay");	

	if(g_bCvarEnable) _OnModuleStart();
	hCvarBoomerExposedTimeTolerance.AddChangeHook(OnBoomerCvarChange);  
	hCvarBoomerVomitDelay.AddChangeHook(OnBoomerCvarChange);    
}

static void _OnModuleStart()
{
	hCvarBoomerExposedTimeTolerance.SetFloat(10000.0);
	hCvarBoomerVomitDelay.SetFloat(0.1);
}

public void Boomer_OnModuleEnd() {
	ResetConVar(hCvarBoomerExposedTimeTolerance);
	ResetConVar(hCvarBoomerVomitDelay);
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
        Boomer_OnModuleEnd();
    }
}

static void GetCvars()
{
    g_bCvarEnable = g_hCvarEnable.BoolValue;
}

// Game tries to reset these cvars
public void OnBoomerCvarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
    if(g_bCvarEnable) _OnModuleStart();
}