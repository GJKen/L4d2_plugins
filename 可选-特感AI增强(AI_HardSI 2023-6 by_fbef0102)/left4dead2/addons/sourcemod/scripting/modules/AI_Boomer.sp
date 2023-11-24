#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
ConVar hCvarBoomerExposedTimeTolerance;
ConVar hCvarBoomerVomitDelay;

public void Boomer_OnModuleStart() {
	hCvarBoomerExposedTimeTolerance = FindConVar("boomer_exposed_time_tolerance");	
	hCvarBoomerExposedTimeTolerance.SetFloat(10000.0);
	hCvarBoomerExposedTimeTolerance.AddChangeHook(OnBoomerCvarChange);  

	hCvarBoomerVomitDelay = FindConVar("boomer_vomit_delay");	
	hCvarBoomerVomitDelay.SetFloat(0.1);
	hCvarBoomerVomitDelay.AddChangeHook(OnBoomerCvarChange);    
}

public void OnConfigsExecuted()
{
	SetConVarFloat(hCvarBoomerExposedTimeTolerance, 10000.0);
	SetConVarFloat(hCvarBoomerVomitDelay, 0.1);
}

public void Boomer_OnModuleEnd() {
	ResetConVar(hCvarBoomerExposedTimeTolerance);
	ResetConVar(hCvarBoomerVomitDelay);
}

// Game tries to reset these cvars
public void OnBoomerCvarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	hCvarBoomerExposedTimeTolerance.SetFloat(10000.0);
	hCvarBoomerVomitDelay.SetFloat(0.1);
}