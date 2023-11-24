
// TANK is not included. need use https://github.com/fdxx/l4d2_plugins/blob/main/l4d2_activate_tank.sp

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VERSION "1.3"

#define MAX_PATCH_LEN 64
#define WINDOWS 1

ArrayList g_aRevert;
ConVar g_cvEnable;

enum struct RevertInfo 
{
	Address address;
	int bytes[MAX_PATCH_LEN];
	int numBytes;
}

public Plugin myinfo = 
{
	name = "Aggresive Specials Patch",
	author = "sorallll, fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	CreateConVar("aggresive_specials_patch_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvEnable = CreateConVar("aggresive_specials_patch_enable", "1");
	OnConVarChanged(null, "", "");
	g_cvEnable.AddChangeHook(OnConVarChanged);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	OnPluginEnd();
	if (g_cvEnable.BoolValue)
		EnablePatch();
}

void EnablePatch()
{
	delete g_aRevert;
	g_aRevert = new ArrayList(sizeof(RevertInfo));

	GameData hGameData = new GameData("aggresive_specials_patch");
	if (hGameData == null)
		SetFailState("Failed to load \"aggresive_specials_patch.txt\" gamedata.");

	Address pTargetFunc;
	int verify[MAX_PATCH_LEN], patch[MAX_PATCH_LEN];
	int numVerify, numPatch;

	pTargetFunc = GetTargetFuncAddress(hGameData, "AggresiveSpecials");
	numVerify = GetBytesByGameDataKey(hGameData, "AggresiveSpecials_Verify", verify);
	numPatch = GetBytesByGameDataKey(hGameData, "AggresiveSpecials_Patch", patch);
	SetupPatch(verify, numVerify, patch, numPatch, "AggresiveSpecials", pTargetFunc);

	pTargetFunc = GetTargetFuncAddress(hGameData, "SpecialsShouldAssault");
	numVerify = GetBytesByGameDataKey(hGameData, "SpecialsShouldAssault_Verify", verify);
	numPatch = GetBytesByGameDataKey(hGameData, "SpecialsShouldAssault_Patch", patch);
	SetupPatch(verify, numVerify, patch, numPatch, "SpecialsShouldAssault", pTargetFunc);

	delete hGameData;	
}

Address GetTargetFuncAddress(GameData hGameData, const char[] name)
{
	Address	pAdr = hGameData.GetAddress(name);
	if (pAdr == Address_Null)
		SetFailState("Failed to GetAddress: %s", name);

	int os = hGameData.GetOffset("os");
	if (os == -1)
		SetFailState("Failed to GetOffset: os");

	if (os == WINDOWS)
	{
		Address pRelativeOffset = LoadFromAddress(pAdr + view_as<Address>(1), NumberType_Int32);
		return pAdr + view_as<Address>(5) + pRelativeOffset;
	}
	
	return pAdr;
}

int GetBytesByGameDataKey(GameData hGameData, const char[] key, int[] bytes)
{
	char sBuffer[MAX_PATCH_LEN*4+1];
	char sBytes[MAX_PATCH_LEN][4];
	int num;

	if (!hGameData.GetKeyValue(key, sBuffer, sizeof(sBuffer)))
		SetFailState("Failed to GetKeyValue: %s", key);

	num = ExplodeString(sBuffer[2], "\\x", sBytes, sizeof(sBytes), sizeof(sBytes[]));
	for (int i = 0; i < num; i++)
		bytes[i] = StringToInt(sBytes[i], 16);
	
	return num;
}

void SetupPatch(const int[] verify, int numVerify, const int[] patch, int numPatch, const char[] name, Address pBase, int offset = 0)
{
	Address address = pBase + view_as<Address>(offset);

	for (int i = 0; i < numVerify; i++)
	{
		if (verify[i] != LoadFromAddress(address + view_as<Address>(i), NumberType_Int8))
			SetFailState("Failed to verify patch: %s", name);
	}

	RevertInfo revert;

	for (int i = 0; i < numPatch; i++)
	{
		revert.bytes[i] = LoadFromAddress(address + view_as<Address>(i), NumberType_Int8);
		StoreToAddress(address + view_as<Address>(i), patch[i], NumberType_Int8);
	}

	revert.address = address;
	revert.numBytes = numPatch;
	g_aRevert.PushArray(revert);
}

public void OnPluginEnd()
{
	if (g_aRevert == null)
		return;

	RevertInfo revert;

	for (int i = 0; i < g_aRevert.Length; i++)
	{
		g_aRevert.GetArray(i, revert);
		for (int num = 0; num < revert.numBytes; num++)
			StoreToAddress(revert.address + view_as<Address>(num), revert.bytes[num], NumberType_Int8);
	}

	delete g_aRevert;
}

// server_srv.so!Action<Jockey>::InvokeUpdate -> BossZombiePlayerBot::ShouldAdvanceOnSurvivors() -> CDirector::SpecialsShouldAdvanceOnSurvivors -> CDirectorChallengeMode::AggresiveSpecials -> CDirector::GetScriptValue(TheDirector, "cm_AggressiveSpecials", 0) != 0
// JockeyBehavior::InitialContainedAction -> CDirector::SpecialsShouldAssault -> CDirectorChallengeMode::SpecialsShouldAssault -> CDirector::GetScriptValue(TheDirector, "SpecialInfectedAssault", 0) > 0

