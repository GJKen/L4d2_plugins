#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define MAX_MELEE		16
#define GAMEDATA		"l4d2_melee_spawn_control"
#define MELEE_MANIFEST	"scripts\\melee\\melee_manifest.txt"
#define DEFAULT_MELEES	"fireaxe;frying_pan;machete;baseball_bat;crowbar;cricket_bat;tonfa;katana;electric_guitar;knife;golfclub;shovel;pitchfork"

StringMap
	g_aMissionDefaultMelees;

Handle
	g_hSDK_CTerrorGameRules_GetMissionInfo,
	g_hSDK_KeyValues_GetString,
	g_hSDK_KeyValues_SetString,
	g_hSDK_CTerrorGameRules_GetMissionFirstMap;

ConVar
	g_hBaseMelees,
	g_hExtraMelees;

public Plugin myinfo=
{
	name = "l4d2 melee spawn control",
	author = "IA/NanaNana, sorallll",
	description = "Unlock melee weapons",
	version = "1.6",
	url = "https://forums.alliedmods.net/showthread.php?p=2719531"
}

public void OnPluginStart()
{
	vInitGameData();
	g_aMissionDefaultMelees = new StringMap();

	g_hBaseMelees = 	CreateConVar("l4d2_melee_spawn", 	"", "Melee weapon list for unlock, use ';' to separate between names, e.g: pitchfork;shovel. Empty for no change");
	g_hExtraMelees =	CreateConVar("l4d2_add_melee", 		"machete;katana;fireaxe;shovel;crowbar;golfclub;electric_guitar;knife;frying_pan;tonfa;baseball_bat;cricket_bat;pitchfork", 
	"Add melee weapons to map basis melee spawn or l4d2_melee_spawn, use ';' to separate between names. Empty for don't add");
	AutoExecConfig(true, "l4d2_melee_spawn_control");
}

MRESReturn DD_CMeleeWeaponInfoStore_LoadScripts_Pre(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
	int infoPointer = SDKCall(g_hSDK_CTerrorGameRules_GetMissionInfo);
	if (!infoPointer)
		return MRES_Ignored;

	char sMissionFirstMap[64];
	int iKeyValue = SDKCall(g_hSDK_CTerrorGameRules_GetMissionFirstMap, 0);
	if (!iKeyValue)
		return MRES_Ignored;

	SDKCall(g_hSDK_KeyValues_GetString, iKeyValue, sMissionFirstMap, sizeof sMissionFirstMap, "map", "");
	if (!sMissionFirstMap[0])
		return MRES_Ignored;

	char sMissionDefault[512];
	if (!g_aMissionDefaultMelees.GetString(sMissionFirstMap, sMissionDefault, sizeof sMissionDefault)) {
		char sMapCurrent[512];
		SDKCall(g_hSDK_KeyValues_GetString, infoPointer, sMapCurrent, sizeof sMapCurrent, "meleeweapons", "");

		if (sMapCurrent[0])
			strcopy(sMissionDefault, sizeof sMissionDefault, sMapCurrent);
		else
			LoadScriptsFromManifest(sMissionDefault, sizeof sMissionDefault); //Dark Wood (Extended), Divine Cybermancy

		if (!sMissionDefault[0])
			strcopy(sMissionDefault, sizeof sMissionDefault, DEFAULT_MELEES);

		g_aMissionDefaultMelees.SetString(sMissionFirstMap, sMissionDefault, false);
	}

	char sMapSet[512];
	sMapSet = sGetMapSetMelees(sMissionDefault);
	if (!sMapSet[0])
		return MRES_Ignored;

	SDKCall(g_hSDK_KeyValues_SetString, infoPointer, "meleeweapons", sMapSet);
	return MRES_Ignored;
}

MRESReturn DD_CDirectorItemManager_IsMeleeWeaponAllowedToExistPost(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
	/**char sScriptName[32];
	hParams.GetString(1, sScriptName, sizeof sScriptName);
	if (strcmp(sScriptName, "knife", false) == 0) {
		hReturn.Value = 1;
		return MRES_Override;
	}
	
	return MRES_Ignored;*/

	hReturn.Value = 1;
	return MRES_Override;
}

void LoadScriptsFromManifest(char[] buffer, int maxlength)
{
	File hFile = OpenFile(MELEE_MANIFEST, "r", true);
	if (!hFile)
		return;

	char sLine[PLATFORM_MAX_PATH];
	char sBuff[PLATFORM_MAX_PATH];

	while (!hFile.EndOfFile()) {
		if (!hFile.ReadLine(sLine, sizeof sLine))
			break;

		TrimString(sLine);

		if (!KV_GetValue(sLine, "file", sBuff))
			continue;

		if (SplitString(sBuff, ".txt", sBuff, sizeof sBuff) == -1)
			continue;

		if (SplitStringRight(sBuff, "scripts/melee/", sBuff, sizeof sBuff))
			Format(buffer, maxlength, "%s;%s", buffer, sBuff);
	}
	
	delete hFile;
	strcopy(buffer, maxlength, buffer[1]);
}

// [L4D1 & L4D2] Map changer with rating system (https://forums.alliedmods.net/showthread.php?t=311161)
bool KV_GetValue(char[] str, char[] key, char buffer[PLATFORM_MAX_PATH])
{
	buffer[0] = '\0';
	int posKey, posComment, sizeKey;
	char substr[64];
	FormatEx(substr, sizeof substr, "\"%s\"", key);
	
	posKey = StrContains(str, substr, false);
	if (posKey != -1) {
		posComment = StrContains(str, "//", true);
		
		if (posComment == -1 || posComment > posKey) {
			sizeKey = strlen(substr);
			buffer = UnQuote(str[posKey + sizeKey]);
			return true;
		}
	}
	return false;
}

char[] UnQuote(char[] Str)
{
	int pos;
	static char buf[64];
	strcopy(buf, sizeof buf, Str);
	TrimString(buf);
	if (buf[0] == '\"') {
		strcopy(buf, sizeof buf, buf[1]);
	}
	pos = FindCharInString(buf, '\"');
	if (pos != -1) {
		buf[pos] = '\x0';
	}
	return buf;
}

// https://forums.alliedmods.net/showpost.php?p=2094396&postcount=6
bool SplitStringRight(const char[] source, const char[] split, char[] part, int partLen)
{
	int index = StrContains(source, split);
	if (index == -1)
		return false;
	
	index += strlen(split);
	if (index == strlen(source) - 1)
		return false;
	
	strcopy(part, partLen, source[index]);
	return true;
}

char[] sGetMapSetMelees(const char[] str)
{
	char sBase[512];
	char sExtra[512];
	g_hBaseMelees.GetString(sBase, sizeof sBase);
	g_hExtraMelees.GetString(sExtra, sizeof sExtra);

	if (!sBase[0]) {
		if (!sExtra[0])
			return sBase;

		strcopy(sBase, sizeof sBase, str);
	}

	ArrayList aMelee = new ArrayList(ByteCountToCells(32));
	ParseMeleeString(sBase, aMelee);

	if (sExtra[0])
		ParseMeleeString(sExtra, aMelee);

	sBase[0] = '\0';
	int length = aMelee.Length;
	if (!length) {
		delete aMelee;
		return sBase;
	}

	if (length > MAX_MELEE)
		length = MAX_MELEE;

	char buffer[32];
	aMelee.GetString(0, buffer, sizeof buffer);
	StrCat(sBase, sizeof sBase, buffer);

	for (int i = 1; i < length; i++) {
		StrCat(sBase, sizeof sBase, ";");
		aMelee.GetString(i, buffer, sizeof buffer);
		StrCat(sBase, sizeof sBase, buffer);
	}

	delete aMelee;
	return sBase;
}

void ParseMeleeString(const char[] source, ArrayList array)
{
	int reloc_idx, idx;
	char buffer[32];
	char path[PLATFORM_MAX_PATH];

	while ((idx = SplitString(source[reloc_idx], ";", buffer, sizeof buffer)) != -1) {
		reloc_idx += idx;
		TrimString(buffer);
		if (!buffer[0])
			continue;

		StringToLowerCase(buffer);
		if (array.FindString(buffer) != -1)
			continue;
			
		FormatEx(path, sizeof path, "scripts/melee/%s.txt", buffer);
		if (!FileExists(path, true))
			continue;

		array.PushString(buffer);
	}

	if (reloc_idx > 0) {
		strcopy(buffer, sizeof buffer, source[reloc_idx]);

		TrimString(buffer);
		if (buffer[0]) {
			StringToLowerCase(buffer);
			if (array.FindString(buffer) == -1) {
				FormatEx(path, sizeof path, "scripts/melee/%s.txt", buffer);
				if (FileExists(path, true))
					array.PushString(buffer);
			}
		}
	}
}

/**
 * Converts the given string to lower case
 *
 * @param szString	Input string for conversion and also the output
 * @return			void
 */
void StringToLowerCase(char[] szInput)
{
	int iIterator;
	while (szInput[iIterator] != EOS) {
		szInput[iIterator] = CharToLower(szInput[iIterator]);
		++iIterator;
	}
}

void vInitGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::GetMissionInfo"))
		SetFailState("Failed to find signature: \"CTerrorGameRules::GetMissionInfo\"");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if (!(g_hSDK_CTerrorGameRules_GetMissionInfo = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorGameRules::GetMissionInfo\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetString"))
		SetFailState("Failed to find signature: \"KeyValues::GetString\"");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	if (!(g_hSDK_KeyValues_GetString = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"KeyValues::GetString\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetString"))
		SetFailState("Failed to find signature: \"KeyValues::SetString\"");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if (!(g_hSDK_KeyValues_SetString = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"KeyValues::SetString\"");

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::GetMissionFirstMap"))
		SetFailState("Failed to find signature: \"CTerrorGameRules::GetMissionFirstMap\"");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain, VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if (!(g_hSDK_CTerrorGameRules_GetMissionFirstMap = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorGameRules::GetMissionFirstMap\"");

	vSetupDetours(hGameData);

	delete hGameData;
}

void vSetupDetours(GameData hGameData = null)
{
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CMeleeWeaponInfoStore::LoadScripts");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CMeleeWeaponInfoStore::LoadScripts\"");
		
	if (!dDetour.Enable(Hook_Pre, DD_CMeleeWeaponInfoStore_LoadScripts_Pre))
		SetFailState("Failed to detour pre: \"DD::CMeleeWeaponInfoStore::LoadScripts\"");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CDirectorItemManager::IsMeleeWeaponAllowedToExist");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CDirectorItemManager::IsMeleeWeaponAllowedToExist\"");
		
	if (!dDetour.Enable(Hook_Post, DD_CDirectorItemManager_IsMeleeWeaponAllowedToExistPost))
		SetFailState("Failed to detour post: \"DD::CDirectorItemManager::IsMeleeWeaponAllowedToExist\"");
}