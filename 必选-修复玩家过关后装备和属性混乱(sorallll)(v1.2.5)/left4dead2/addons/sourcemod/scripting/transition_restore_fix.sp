#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <sourcescramble>

#define PLUGIN_NAME				"Transition Restore Fix"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		"Restoring transition data by player's UserId instead of character"
#define PLUGIN_VERSION			"1.2.5"
#define PLUGIN_URL				"https://forums.alliedmods.net/showthread.php?t=336287"

#define GAMEDATA				"transition_restore_fix"

Handle
	g_hSDK_KeyValues_GetString,
	g_hSDK_KeyValues_SetString,
	g_hSDK_CDirector_IsInTransition;

ConVar
	g_cChooseBotData,
	g_cvPrecacheAllSur;

ArrayList
	g_aBotData;

Address
	g_pThis,
	g_pData,
	g_pDirector,
	g_pSavedPlayersCount,
	g_pSavedSurvivorBotsCount,
	g_pSavedLevelRestartSurvivorBotsCount;

MemoryPatch
	g_mpRestoreByUserId;

bool
	g_bOnRestart,
	g_bChooseBotData;

enum struct PlayerSaveData {
	char ModelName[128];
	char character[4];
}

PlayerSaveData
	g_eSavedData;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	InitGameData();
	g_aBotData = new ArrayList();

	CreateConVar("transition_restore_fix_version", PLUGIN_VERSION, "Transition Restore Fix plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cChooseBotData =		CreateConVar("choose_bot_data", "0", "重启后根据什么选择机器人数据? 0=模式名称, 1=生还者名称.", FCVAR_NOTIFY);
	g_cvPrecacheAllSur =	FindConVar("precache_all_survivors");

	g_cChooseBotData.AddChangeHook(CvarChanged);
	AutoExecConfig(true, "transition_restore_fix");//创建指定名称的CFG.
}

public void OnPluginEnd() {
	if (g_pThis)
		StoreToAddress(g_pThis, g_pData, NumberType_Int32);
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_bChooseBotData = g_cChooseBotData.BoolValue;
}

public void OnMapStart() {
	g_cvPrecacheAllSur.SetInt(1);
}

void InitGameData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pDirector = hGameData.GetAddress("CDirector");
	if (!g_pDirector)
		SetFailState("Failed to find address: \"CDirector\"");

	g_pSavedPlayersCount = hGameData.GetAddress("SavedPlayersCount");
	if (!g_pSavedPlayersCount)
		SetFailState("Failed to find address: \"SavedPlayersCount\"");

	g_pSavedSurvivorBotsCount = hGameData.GetAddress("SavedSurvivorBotsCount");
	if (!g_pSavedSurvivorBotsCount)
		SetFailState("Failed to find address: \"SavedSurvivorBotsCount\"");

	g_pSavedLevelRestartSurvivorBotsCount = hGameData.GetAddress("SavedLevelRestartSurvivorBotsCount");
	if (!g_pSavedLevelRestartSurvivorBotsCount)
		SetFailState("Failed to find address: \"SavedLevelRestartSurvivorBotsCount\"");

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

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::IsInTransition"))
		SetFailState("Failed to find signature: \"CDirector::IsInTransition\"");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_CDirector_IsInTransition = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CDirector::IsInTransition\"");

	InitPatchs(hGameData);
	SetupDetours(hGameData);

	delete hGameData;
}

void InitPatchs(GameData hGameData = null) {
	g_mpRestoreByUserId = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::TransitionRestore::RestoreByUserId");
	if (!g_mpRestoreByUserId.Validate())
		SetFailState("Failed to verify patch: \"CTerrorPlayer::TransitionRestore::RestoreByUserId\"");

	MemoryPatch patch = MemoryPatch.CreateFromConf(hGameData, "RestoreTransitionedSurvivorBots::MaxRestoreSurvivorBots");
	if (!patch.Validate())
		SetFailState("Failed to verify patch: \"RestoreTransitionedSurvivorBots::MaxRestoreSurvivorBots\"");
	else if (patch.Enable()) {
		StoreToAddress(patch.Address + view_as<Address>(2), !hGameData.GetOffset("OS") ? MaxClients : MaxClients - 1, NumberType_Int8);
		PrintToServer("[%s] Enabled patch: \"RestoreTransitionedSurvivorBots::MaxRestoreSurvivorBots\"", GAMEDATA);
	}
}

void SetupDetours(GameData hGameData = null) {
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CDirector::Restart");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CDirector::Restart\"");

	if (!dDetour.Enable(Hook_Pre, DD_CDirector_Restart_Pre))
		SetFailState("Failed to detour pre: \"DD::CDirector::Restart\"");
		
	if (!dDetour.Enable(Hook_Post, DD_CDirector_Restart_Post))
		SetFailState("Failed to detour post: \"DD::CDirector::Restart\"");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::TransitionRestore");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::TransitionRestore\"");

	if (!dDetour.Enable(Hook_Pre, DD_CTerrorPlayer_TransitionRestore_Pre))
		SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::TransitionRestore\"");

	if (!dDetour.Enable(Hook_Post, DD_CTerrorPlayer_TransitionRestore_Post))
		SetFailState("Failed to detour post: \"DD::CTerrorPlayer::TransitionRestore\"");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::PlayerSaveData::Restore");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::PlayerSaveData::Restore\"");

	if (!dDetour.Enable(Hook_Pre, DD_PlayerSaveData_Restore_Pre))
		SetFailState("Failed to detour pre: \"DD::PlayerSaveData::Restore\"");

	if (!dDetour.Enable(Hook_Post, DD_PlayerSaveData_Restore_Post))
		SetFailState("Failed to detour post: \"DD::PlayerSaveData::Restore\"");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CDirector::IsHumanSpectatorValid");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CDirector::IsHumanSpectatorValid\"");

	if (!dDetour.Enable(Hook_Pre, DD_CDirector_IsHumanSpectatorValid_Pre))
		SetFailState("Failed to detour pre: \"DD::CDirector::IsHumanSpectatorValid\"");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CDirectorSessionManager::FillRemainingSurvivorTeamSlotsWithBots");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CDirectorSessionManager::FillRemainingSurvivorTeamSlotsWithBots\"");

	if (!dDetour.Enable(Hook_Pre, DD_CDSManager_FillRemainingSurvivorTeamSlotsWithBots_Pre))
		SetFailState("Failed to detour pre: \"DD::CDirectorSessionManager::FillRemainingSurvivorTeamSlotsWithBots\"");
}

MRESReturn DD_CDirector_Restart_Pre(Address pThis, DHookReturn hReturn) {
	g_aBotData.Clear();
	g_bOnRestart = true;
	return MRES_Ignored;
}

MRESReturn DD_CDirector_Restart_Post(Address pThis, DHookReturn hReturn) {
	g_bOnRestart = false;
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_TransitionRestore_Pre(int pThis, DHookReturn hReturn) {
	if (IsFakeClient(pThis) || GetClientTeam(pThis) > 2)
		return MRES_Ignored;

	Address pData = FindPlayerDataByUserId(GetClientUserId(pThis));
	if (!pData)
		return MRES_Ignored;

	char value[4];
	SDKCall(g_hSDK_KeyValues_GetString, pData, value, sizeof value, "teamNumber", "0");
	if (StringToInt(value) != 2)
		return MRES_Ignored;

	g_mpRestoreByUserId.Enable();
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_TransitionRestore_Post(int pThis, DHookReturn hReturn) {
	g_mpRestoreByUserId.Disable();
	return MRES_Ignored;
}

MRESReturn DD_PlayerSaveData_Restore_Pre(Address pThis, DHookParam hParams) {
	if (!g_bOnRestart)
		return MRES_Ignored;

	int player = hParams.Get(1);
	if (GetClientTeam(player) > 2)
		return MRES_Ignored;

	Address pData;
	char ModelName[128];
	int m_survivorCharacter = GetEntProp(player, Prop_Send, "m_survivorCharacter");
	if (IsFakeClient(player) || !FindPlayerDataByUserId(GetClientUserId(player))) {
		GetClientModel(player, ModelName, sizeof ModelName);
		pData = !g_bChooseBotData ? FindBotDataByModelName(ModelName) : FindBotDataByCharacter(m_survivorCharacter);
		if (pData) {
			g_pThis = pThis;
			g_pData = LoadFromAddress(pThis, NumberType_Int32);
			StoreToAddress(pThis, pData, NumberType_Int32);
		}
	}

	if (!pData) {
		pData = LoadFromAddress(pThis, NumberType_Int32);

		char value[4];
		SDKCall(g_hSDK_KeyValues_GetString, pData, value, sizeof value, "teamNumber", "0");
		if (StringToInt(value) != 2)
			return MRES_Ignored;
	}

	char character[4];
	SDKCall(g_hSDK_KeyValues_GetString, pData, ModelName, sizeof ModelName, "ModelName", "");
	SDKCall(g_hSDK_KeyValues_GetString, pData, character, sizeof character, "character", "0");
	strcopy(g_eSavedData.ModelName, sizeof PlayerSaveData::ModelName, ModelName);
	strcopy(g_eSavedData.character, sizeof PlayerSaveData::character, character);

	GetClientModel(player, ModelName, sizeof ModelName);
	SDKCall(g_hSDK_KeyValues_SetString, pData, "ModelName", ModelName);

	IntToString(m_survivorCharacter, character, sizeof character);
	SDKCall(g_hSDK_KeyValues_SetString, pData, "character", character);

	return MRES_Ignored;
}

MRESReturn DD_PlayerSaveData_Restore_Post(Address pThis, DHookParam hParams) {
	if (!g_bOnRestart)
		return MRES_Ignored;

	if (g_eSavedData.character[0]) {
		Address pData = LoadFromAddress(pThis, NumberType_Int32);
		if (pData) {
			SDKCall(g_hSDK_KeyValues_SetString, pData, "ModelName", g_eSavedData.ModelName);
			SDKCall(g_hSDK_KeyValues_SetString, pData, "character", g_eSavedData.character);
		}

		g_eSavedData.ModelName[0] = '\0';
		g_eSavedData.character[0] = '\0';
	}

	if (g_pThis)
		StoreToAddress(g_pThis, g_pData, NumberType_Int32);

	g_pThis = Address_Null;
	g_pData = Address_Null;
	return MRES_Ignored;
}

/**
* Prevents players joining the game during transition from taking over the Survivor Bot of transitioning players
**/
MRESReturn DD_CDirector_IsHumanSpectatorValid_Pre(Address pThis, DHookReturn hReturn, DHookParam hParams) {
	if (!GetClientOfUserId(GetEntProp(hParams.Get(1), Prop_Send, "m_humanSpectatorUserID")))
		return MRES_Ignored;

	hReturn.Value = 1;
	return MRES_Supercede;
}

/**
* Prevent CDirectorSessionManager::FillRemainingSurvivorTeamSlotsWithBots from triggering before RestoreTransitionedSurvivorBots(void) during transition
**/
MRESReturn DD_CDSManager_FillRemainingSurvivorTeamSlotsWithBots_Pre(Address pThis, DHookReturn hReturn) {
	if (!SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector))
		return MRES_Ignored;

	if (!LoadFromAddress(g_pSavedSurvivorBotsCount, NumberType_Int32))
		return MRES_Ignored;

	hReturn.Value = 0;
	return MRES_Supercede;
}

// 读取玩家过关时保存的userID
Address FindPlayerDataByUserId(int userid) {
	int count = LoadFromAddress(g_pSavedPlayersCount, NumberType_Int32);
	if (!count)
		return Address_Null;

	Address kv = view_as<Address>(LoadFromAddress(g_pSavedPlayersCount + view_as<Address>(4), NumberType_Int32));
	if (!kv)
		return Address_Null;

	Address ptr;
	char value[12];
	for (int i; i < count; i++) {
		ptr = view_as<Address>(LoadFromAddress(kv + view_as<Address>(4 * i), NumberType_Int32));
		if (!ptr)
			continue;

		SDKCall(g_hSDK_KeyValues_GetString, ptr, value, sizeof value, "userID", "0");
		if (StringToInt(value) == userid)
			return ptr;
	}

	return Address_Null;
}

//数据选用优先级
//没有用过且ModelName相同的数据 >= 没有用过且ModelName不相同的数据 >= 用过且ModelName相同的数据 >= 用过且ModelName不相同的数据
Address FindBotDataByModelName(const char[] model) {
	int count = LoadFromAddress(g_pSavedLevelRestartSurvivorBotsCount, NumberType_Int32);
	if (!count)
		return Address_Null;

	Address kv = view_as<Address>(LoadFromAddress(g_pSavedLevelRestartSurvivorBotsCount + view_as<Address>(4), NumberType_Int32));
	if (!kv)
		return Address_Null;

	Address ptr;
	char value[128];
	ArrayList al_Kv = new ArrayList(2);
	for (int i; i < count; i++) {
		ptr = view_as<Address>(LoadFromAddress(kv + view_as<Address>(4 * i), NumberType_Int32));
		if (!ptr)
			continue;

		SDKCall(g_hSDK_KeyValues_GetString, ptr, value, sizeof value, "teamNumber", "0");
		if (StringToInt(value) != 2)
			continue;

		SDKCall(g_hSDK_KeyValues_GetString, ptr, value, sizeof value, "ModelName", "");
		al_Kv.Set(al_Kv.Push(g_aBotData.FindValue(ptr) == -1 ? (strcmp(value, model, false) == 0 ? 0 : 1) : strcmp(value, model, false) == 0 ? 2 : 3), ptr, 1);
	}

	if (!al_Kv.Length)
		ptr = Address_Null;
	else {
		al_Kv.Sort(Sort_Ascending, Sort_Integer);

		ptr = al_Kv.Get(0, 1);
		if (al_Kv.Get(0, 0) < 2)
			g_aBotData.Push(ptr);
	}

	delete al_Kv;
	return ptr;
}

//没有用过且character相同的数据 >= 没有用过且character不相同的数据 >= 用过且character相同的数据 >= 用过且character不相同的数据
Address FindBotDataByCharacter(int character) {
	int count = LoadFromAddress(g_pSavedLevelRestartSurvivorBotsCount, NumberType_Int32);
	if (!count)
		return Address_Null;

	Address kv = view_as<Address>(LoadFromAddress(g_pSavedLevelRestartSurvivorBotsCount + view_as<Address>(4), NumberType_Int32));
	if (!kv)
		return Address_Null;

	Address ptr;
	char value[128];
	ArrayList al_Kv = new ArrayList(2);
	for (int i; i < count; i++) {
		ptr = view_as<Address>(LoadFromAddress(kv + view_as<Address>(4 * i), NumberType_Int32));
		if (!ptr)
			continue;

		SDKCall(g_hSDK_KeyValues_GetString, ptr, value, sizeof value, "teamNumber", "0");
		if (StringToInt(value) != 2)
			continue;

		SDKCall(g_hSDK_KeyValues_GetString, ptr, value, sizeof value, "character", "0");
		al_Kv.Set(al_Kv.Push(g_aBotData.FindValue(ptr) == -1 ? (StringToInt(value) == character ? 0 : 1) : StringToInt(value) == character ? 2 : 3), ptr, 1);
	}

	if (!al_Kv.Length)
		ptr = Address_Null;
	else {
		al_Kv.Sort(Sort_Ascending, Sort_Integer);

		ptr = al_Kv.Get(0, 1);
		if (al_Kv.Get(0, 0) < 2)
			g_aBotData.Push(ptr);
	}

	delete al_Kv;
	return ptr;
}
