#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
//#include <colors>
#include <left4dhooks>
#include <sourcescramble>

#define PLUGIN_NAME					"Coop Boss Spawning"
#define PLUGIN_AUTHOR				"sorallll"
#define PLUGIN_DESCRIPTION			""
#define PLUGIN_VERSION				"1.0.4"
#define PLUGIN_URL					""

#define GAMEDATA					"coop_boss_spawning"

#define PATCH_NO_DIRECTOR_BOSS		"CDirector::OnThreatEncountered::Block"
#define PATCH_COOP_VERSUS_BOSS		"CDirectorVersusMode::UpdateNonVirtual::IsVersusMode"
#define PATCH_BLOCK_MARKERSTIMER	"CDirectorVersusMode::UpdateNonVirtual::UpdateMarkersTimer"
#define PATCH_TANKCOUNT_SPAWN_WITCH	"CDirectorVersusMode::UpdateVersusBossSpawning::m_iTankCount"

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	InitGameData();
	CreateConVar("coop_boss_spawning_version", PLUGIN_VERSION, "Coop Boss Spawning plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal) {
	if (strcmp(key, "ProhibitBosses", false) == 0 || strcmp(key, "DisallowThreatType", false) == 0) {
		retVal = 0;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}
/*
public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client) {
	int flow;
	int round = GameRules_GetProp("m_bInSecondHalfOfRound");
	if (!L4D2Direct_GetVSTankToSpawnThisRound(round)) {
		flow = RoundToCeil(L4D2Direct_GetVSTankFlowPercent(round) * 100.0);
		if (flow > 0)
			CPrintToChatAll("{olive}Tank{default}: {red}%d%%", flow);
	}

	if (!L4D2Direct_GetVSWitchToSpawnThisRound(round)) {
		flow = RoundToCeil(L4D2Direct_GetVSWitchFlowPercent(round) * 100.0);
		if (flow > 0)
			CPrintToChatAll("{olive}Witch{default}: {red}%d%%", flow);
	}
}*/

void InitGameData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	Patch(hGameData, PATCH_NO_DIRECTOR_BOSS);
	Patch(hGameData, PATCH_COOP_VERSUS_BOSS);
	Patch(hGameData, PATCH_BLOCK_MARKERSTIMER);
	Patch(hGameData, PATCH_TANKCOUNT_SPAWN_WITCH);

	delete hGameData;
}

void Patch(GameData hGameData = null, const char[] name) {
	MemoryPatch patch = MemoryPatch.CreateFromConf(hGameData, name);
	if (!patch.Validate())
		SetFailState("Failed to verify patch: \"%s\"", name);
	else if (patch.Enable())
		PrintToServer("Enabled patch: \"%s\"", name);
}
