#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#define SMOKER_TONGUE_DELAY 0.1

ConVar hCvarTongueDelay;
ConVar hCvarSmokerHealth;
ConVar hCvarChokeDamageInterrupt;

public void Smoker_OnModuleStart() {
	 // Smoker health
    hCvarSmokerHealth = FindConVar("z_gas_health");
    hCvarSmokerHealth.AddChangeHook(OnSmokerHealthChanged); 
    
    // Damage required to kill a smoker that is pulling someone
    // hCvarChokeDamageInterrupt = FindConVar("tongue_break_from_damage_amount"); 
    // hCvarChokeDamageInterrupt.SetInt(hCvarSmokerHealth.IntValue); // default 50
    // hCvarChokeDamageInterrupt.AddChangeHook(OnTongueCvarChange);    
    // Delay before smoker shoots its tongue
    hCvarTongueDelay = FindConVar("smoker_tongue_delay"); 
    hCvarTongueDelay.SetFloat(SMOKER_TONGUE_DELAY); // default 1.5
    hCvarTongueDelay.AddChangeHook(OnTongueCvarChange);
}

public void Smoker_OnModuleEnd() {
	hCvarChokeDamageInterrupt.RestoreDefault();
	hCvarTongueDelay.RestoreDefault();
}

// Game tries to reset these cvars
public void OnTongueCvarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	hCvarTongueDelay.SetFloat(SMOKER_TONGUE_DELAY);	
	hCvarChokeDamageInterrupt.SetInt(hCvarSmokerHealth.IntValue);
}

// Update choke damage interrupt to match smoker max health
public void OnSmokerHealthChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	hCvarChokeDamageInterrupt.SetInt(hCvarSmokerHealth.IntValue);
}