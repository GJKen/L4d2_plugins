#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "3.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Coop Tank Sweep Fist Patch",
	author = "Forgetest, Crasher_3637 (Psykotikism), Dragokas",
	description = "Kinda destroyed by AIs won't be suck anymore! well nah it is.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart()
{
	GameData gd = new GameData("l4d_sweep_fist_patch");
	if (gd == null)
		SetFailState("Missing gamedata \"l4d_sweep_fist_patch\"");
	
	CreateEnabledPatch(gd, "CTankClaw::SweepFist__HasPlayerControlledZombies_skip");
	
	delete gd;
	
	CreateConVar("l4d_sweep_fist_patch_version", PLUGIN_VERSION, "Sweep Fist Patch Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_REPLICATED);
}

MemoryPatch CreateEnabledPatch(GameData gd, const char[] name)
{
	MemoryPatch hPatch = MemoryPatch.CreateFromConf(gd, name);
	if (!hPatch.Enable())
		SetFailState("Failed to patch \"%s\"", name);
	
	return hPatch;
}
