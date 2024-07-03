#pragma semicolon 1
#pragma newdecls required

#define VERSION "0.4"

#include <sourcemod>
#include <sdktools>

Handle
	g_hSDKOperatorNew,
	g_hSDKConstructor,
	g_hSDKDeleteThis,
	g_hSDKUsesEscapeSequences,
	g_hSDKLoadFromFile,
	g_hSDKLoadFromFile_PathID,
	g_hSDKGetName,
	g_hSDKSetName,
	g_hSDKGetNameSymbol,
	g_hSDKGetDataType,
	g_hSDKGetString,
	g_hSDKSetString,
	g_hSDKSetStringValue,
	g_hSDKGetInt,
	g_hSDKSetInt,
	g_hSDKGetFloat,
	g_hSDKSetFloat,
	g_hSDKGetPtr,
	g_hSDKFindKey,
	g_hSDKFindKeyFromSymbol,
	g_hSDKGetFirstSubKey,
	g_hSDKGetNextKey,
	g_hSDKGetFirstTrueSubKey,
	g_hSDKGetNextTrueSubKey,
	g_hSDKGetFirstValue,
	g_hSDKGetNextValue,
	g_hSDKSaveToFile,
	g_hSDKSaveToFile_PathID;

Address
	g_pFileSystem;

int 
	g_iKeyValuesSize;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2) 
		LogError("Plugin only supports L4D2");

	CreateNative("SourceKeyValues.SourceKeyValues", Native_Create);
	CreateNative("SourceKeyValues.deleteThis", Native_DeleteThis);
	CreateNative("SourceKeyValues.UsesEscapeSequences", Native_UsesEscapeSequences);
	CreateNative("SourceKeyValues.LoadFromFile", Native_LoadFromFile);

	CreateNative("SourceKeyValues.IsNull", Native_IsNull);
	CreateNative("SourceKeyValues.GetName", Native_GetName);
	CreateNative("SourceKeyValues.SetName", Native_SetName);
	CreateNative("SourceKeyValues.GetNameSymbol", Native_GetNameSymbol);
	CreateNative("SourceKeyValues.GetDataType", Native_GetDataType);
	CreateNative("SourceKeyValues.GetString", Native_GetString);
	CreateNative("SourceKeyValues.SetString", Native_SetString);
	CreateNative("SourceKeyValues.SetStringValue", Native_SetStringValue);
	CreateNative("SourceKeyValues.GetInt", Native_GetInt);
	CreateNative("SourceKeyValues.SetInt", Native_SetInt);
	CreateNative("SourceKeyValues.GetFloat", Native_GetFloat);
	CreateNative("SourceKeyValues.SetFloat", Native_SetFloat);
	CreateNative("SourceKeyValues.GetPtr", Native_GetPtr);
	CreateNative("SourceKeyValues.FindKey", Native_FindKey);
	CreateNative("SourceKeyValues.FindKeyFromSymbol", Native_FindKeyFromSymbol);
	CreateNative("SourceKeyValues.GetFirstSubKey", Native_GetFirstSubKey);
	CreateNative("SourceKeyValues.GetNextKey", Native_GetNextKey);
	CreateNative("SourceKeyValues.GetFirstTrueSubKey", Native_GetFirstTrueSubKey);
	CreateNative("SourceKeyValues.GetNextTrueSubKey", Native_GetNextTrueSubKey);
	CreateNative("SourceKeyValues.GetFirstValue", Native_GetFirstValue);
	CreateNative("SourceKeyValues.GetNextValue", Native_GetNextValue);
	CreateNative("SourceKeyValues.SaveToFile", Native_SaveToFile);

	RegPluginLibrary("l4d2_source_keyvalues");

	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "L4D2 Source KeyValues",
	author = "fdxx",
	description = "Call the game's own KeyValues function",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_source_keyvalues"
}

public void OnPluginStart()
{
	Init();
	CreateConVar("l4d2_source_keyvalues_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
}

// public native SourceKeyValues(const char[] name);
any Native_Create(Handle plugin, int numParams)
{
	int maxlength;
	GetNativeStringLength(1, maxlength);
	maxlength += 1;
	char[] setName = new char[maxlength];
	GetNativeString(1, setName, maxlength);
	
	// void* KeyValues::operator new( size_t iAllocSize )
	Address pkv = SDKCall(g_hSDKOperatorNew, g_iKeyValuesSize);
	
	// void KeyValues::KeyValues( const char *setName )
	SDKCall(g_hSDKConstructor, pkv, setName, 0, false);
	return pkv;
}

// public native void deleteThis();
any Native_DeleteThis(Handle plugin, int numParams)
{
	if (GetNativeCell(1))
		SDKCall(g_hSDKDeleteThis, GetNativeCell(1));
	return 0;
}

// public native void UsesEscapeSequences(bool state);
any Native_UsesEscapeSequences(Handle plugin, int numParams)
{
	SDKCall(g_hSDKUsesEscapeSequences, GetNativeCell(1), GetNativeCell(2));
	return 0;
}

// public native bool LoadFromFile(const char[] file, const char[] pathID = NULL_STRING);
any Native_LoadFromFile(Handle plugin, int numParams)
{
	int fileLen;
	GetNativeStringLength(2, fileLen);
	fileLen += 1;
	char[] file = new char[fileLen];
	GetNativeString(2, file, fileLen);

	// bool KeyValues::LoadFromFile( IBaseFileSystem *filesystem, const char *resourceName, const char *pathID);
	if (IsNativeParamNullString(3))
		return SDKCall(g_hSDKLoadFromFile, GetNativeCell(1), g_pFileSystem, file, 0);
	
	int pathidLen;
	GetNativeStringLength(3, pathidLen);
	pathidLen += 1;
	char[] pathID = new char[pathidLen];
	GetNativeString(3, pathID, pathidLen);
	
	return SDKCall(g_hSDKLoadFromFile_PathID, GetNativeCell(1), g_pFileSystem, file, pathID);
}

// public native bool IsNull();
any Native_IsNull(Handle plugin, int numParams)
{
	return view_as<Address>(GetNativeCell(1)) == Address_Null;
}

// public native void GetName(char[] name, int maxlength);
any Native_GetName(Handle plugin, int numParams)
{
	int maxlength = GetNativeCell(3);
	char[] name = new char[maxlength];
	SDKCall(g_hSDKGetName, GetNativeCell(1), name, maxlength);
	SetNativeString(2, name, maxlength);
	return 0;
}

// public native void SetName(const char[] setName);
any Native_SetName(Handle plugin, int numParams)
{
	int maxlength;
	GetNativeStringLength(2, maxlength);
	maxlength += 1;
	char[] setName = new char[maxlength];
	GetNativeString(2, setName, maxlength);
	SDKCall(g_hSDKSetName, GetNativeCell(1), setName);
	return 0;
}

any Native_GetNameSymbol(Handle plugin, int numParams)
{
	if (!GetNativeCell(1))
		return -1;
	return SDKCall(g_hSDKGetNameSymbol, GetNativeCell(1));
}

// public native DataType GetDataType(const char[] key);
any Native_GetDataType(Handle plugin, int numParams)
{
	if (!IsNativeParamNullString(2))
	{
		int maxlength;
		GetNativeStringLength(2, maxlength);
		maxlength += 1;
		char[] key = new char[maxlength];
		GetNativeString(2, key, maxlength);
		return SDKCall(g_hSDKGetDataType, GetNativeCell(1), key);
	}
	return SDKCall(g_hSDKGetDataType, GetNativeCell(1), NULL_STRING);
}

// public native void GetString(const char[] key, char[] value, int maxlength, const char[] defvalue = "");
any Native_GetString(Handle plugin, int numParams)
{
	int keyLength, valueLength, defvalueLength;

	valueLength = GetNativeCell(4);
	char[] value = new char[valueLength];

	GetNativeStringLength(5, defvalueLength);
	defvalueLength += 1;
	char[] defvalue = new char[defvalueLength];
	GetNativeString(5, defvalue, defvalueLength);

	if (!IsNativeParamNullString(2))
	{
		GetNativeStringLength(2, keyLength);
		keyLength += 1;
		char[] key = new char[keyLength];
		GetNativeString(2, key, keyLength);
		SDKCall(g_hSDKGetString, GetNativeCell(1), value, valueLength, key, defvalue);
	}
	else
		SDKCall(g_hSDKGetString, GetNativeCell(1), value, valueLength, NULL_STRING, defvalue);
	
	SetNativeString(3, value, valueLength);
	return 0;
}

// public native void SetString(const char[] key, const char[] value);
any Native_SetString(Handle plugin, int numParams)
{
	int keyLength, valueLength;

	GetNativeStringLength(2, keyLength);
	keyLength += 1;
	char[] key = new char[keyLength];
	GetNativeString(2, key, keyLength);

	GetNativeStringLength(3, valueLength);
	valueLength += 1;
	char[] value = new char[valueLength];
	GetNativeString(3, value, valueLength);

	SDKCall(g_hSDKSetString, GetNativeCell(1), key, value);
	return 0;
}

// public native void SetStringValue(const char[] value);
any Native_SetStringValue(Handle plugin, int numParams)
{
	int maxlength;
	GetNativeStringLength(2, maxlength);
	maxlength += 1;
	char[] value = new char[maxlength];
	GetNativeString(2, value, maxlength);
	SDKCall(g_hSDKSetStringValue, GetNativeCell(1), value);
	return 0;
}

// public native int GetInt(const char[] key, int defvalue = 0);
any Native_GetInt(Handle plugin, int numParams)
{
	if (!IsNativeParamNullString(2))
	{
		int keyLength;
		GetNativeStringLength(2, keyLength);
		keyLength += 1;
		char[] key = new char[keyLength];
		GetNativeString(2, key, keyLength);
		return SDKCall(g_hSDKGetInt, GetNativeCell(1), key, GetNativeCell(3));
	}
	return SDKCall(g_hSDKGetInt, GetNativeCell(1), NULL_STRING, GetNativeCell(3));
}

// public native void SetInt(const char[] key, int value);
any Native_SetInt(Handle plugin, int numParams)
{
	int keyLength;
	GetNativeStringLength(2, keyLength);
	keyLength += 1;
	char[] key = new char[keyLength];
	GetNativeString(2, key, keyLength);

	SDKCall(g_hSDKSetInt, GetNativeCell(1), key, GetNativeCell(3));
	return 0;
}

// public native float GetFloat(const char[] key, float defvalue = 0.0);
any Native_GetFloat(Handle plugin, int numParams)
{
	if (!IsNativeParamNullString(2))
	{
		int keyLength;
		GetNativeStringLength(2, keyLength);
		keyLength += 1;
		char[] key = new char[keyLength];
		GetNativeString(2, key, keyLength);
		return SDKCall(g_hSDKGetFloat, GetNativeCell(1), key, GetNativeCell(3));
	}
	return SDKCall(g_hSDKGetFloat, GetNativeCell(1), NULL_STRING, GetNativeCell(3));
}

// public native void SetFloat(const char[] key, float value);
any Native_SetFloat(Handle plugin, int numParams)
{
	int keyLength;
	GetNativeStringLength(2, keyLength);
	keyLength += 1;
	char[] key = new char[keyLength];
	GetNativeString(2, key, keyLength);

	SDKCall(g_hSDKSetFloat, GetNativeCell(1), key, GetNativeCell(3));
	return 0;
}

// public native Address GetPtr(const char[] key, Address defvalue = Address_Null);
any Native_GetPtr(Handle plugin, int numParams)
{
	if (!IsNativeParamNullString(2))
	{
		int keyLength;
		GetNativeStringLength(2, keyLength);
		keyLength += 1;
		char[] key = new char[keyLength];
		GetNativeString(2, key, keyLength);
		return SDKCall(g_hSDKGetPtr, GetNativeCell(1), key, GetNativeCell(3));
	}
	return SDKCall(g_hSDKGetPtr, GetNativeCell(1), NULL_STRING, GetNativeCell(3));
}

// public native SourceKeyValues FindKey(const char[] key, bool bCreate = false);
any Native_FindKey(Handle plugin, int numParams)
{
	int keyLength;
	GetNativeStringLength(2, keyLength);
	keyLength += 1;
	char[] key = new char[keyLength];
	GetNativeString(2, key, keyLength);

	if (GetNativeCell(1))
		return SDKCall(g_hSDKFindKey, GetNativeCell(1), key, GetNativeCell(3));
	return 0;
}

any Native_FindKeyFromSymbol(Handle plugin, int numParams)
{
	if (GetNativeCell(1))
		return SDKCall(g_hSDKFindKeyFromSymbol, GetNativeCell(1), GetNativeCell(2));
	return 0;
}

// public native SourceKeyValues GetFirstSubKey();
any Native_GetFirstSubKey(Handle plugin, int numParams)
{
	if (GetNativeCell(1))
		return SDKCall(g_hSDKGetFirstSubKey, GetNativeCell(1));
	return 0;
}

// public native SourceKeyValues GetNextKey();
any Native_GetNextKey(Handle plugin, int numParams)
{
	if (GetNativeCell(1))
		return SDKCall(g_hSDKGetNextKey, GetNativeCell(1));
	return 0;
}

// public native SourceKeyValues GetFirstTrueSubKey();
any Native_GetFirstTrueSubKey(Handle plugin, int numParams)
{
	if (GetNativeCell(1))
		return SDKCall(g_hSDKGetFirstTrueSubKey, GetNativeCell(1));
	return 0;
}

// public native SourceKeyValues GetNextTrueSubKey();
any Native_GetNextTrueSubKey(Handle plugin, int numParams)
{
	if (GetNativeCell(1))
		return SDKCall(g_hSDKGetNextTrueSubKey, GetNativeCell(1));
	return 0;
}

// public native SourceKeyValues GetFirstValue();
any Native_GetFirstValue(Handle plugin, int numParams)
{
	if (GetNativeCell(1))
		return SDKCall(g_hSDKGetFirstValue, GetNativeCell(1));
	return 0;
}

// public native SourceKeyValues GetNextValue();
any Native_GetNextValue(Handle plugin, int numParams)
{
	if (GetNativeCell(1))
		return SDKCall(g_hSDKGetNextValue, GetNativeCell(1));
	return 0;
}

// public native bool SaveToFile(const char[] file, const char[] pathID = NULL_STRING);
any Native_SaveToFile(Handle plugin, int numParams)
{
	int fileLen;
	GetNativeStringLength(2, fileLen);
	fileLen += 1;
	char[] file = new char[fileLen];
	GetNativeString(2, file, fileLen);

	if (IsNativeParamNullString(3))
		return SDKCall(g_hSDKSaveToFile, GetNativeCell(1), g_pFileSystem, file, 0);
	
	int pathidLen;
	GetNativeStringLength(3, pathidLen);
	pathidLen += 1;
	char[] pathID = new char[pathidLen];
	GetNativeString(3, pathID, pathidLen);
	
	return SDKCall(g_hSDKSaveToFile_PathID, GetNativeCell(1), g_pFileSystem, file, pathID);
}

void Init()
{
	char sBuffer[128];

	strcopy(sBuffer, sizeof(sBuffer), "l4d2_source_keyvalues");
	GameData hGameData = new GameData(sBuffer);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" file", sBuffer);

	// ------- address ------- 
	strcopy(sBuffer, sizeof(sBuffer), "fileSystem");
	g_pFileSystem = hGameData.GetAddress(sBuffer);
	if (g_pFileSystem == Address_Null)
		SetFailState("Failed to GetAddress: \"%s\"", sBuffer);
	
	// sizof(KeyValues)
	strcopy(sBuffer, sizeof(sBuffer), "KeyValuesSize");
	g_iKeyValuesSize = hGameData.GetOffset(sBuffer);
	if (g_iKeyValuesSize == -1)
		SetFailState("Failed to GetOffset: \"%s\"", sBuffer);

	// ------- Prep SDKCall ------- 
	// void* KeyValues::operator new( size_t iAllocSize )
	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::operator_new");
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKOperatorNew = EndPrepSDKCall();
	if (g_hSDKOperatorNew == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	// KeyValues::KeyValues(char const* setName, IKeyValuesSystem *, bool)
	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::KeyValues");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hSDKConstructor = EndPrepSDKCall();
	if (g_hSDKConstructor == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	// void KeyValues::deleteThis();
	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::deleteThis");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	g_hSDKDeleteThis = EndPrepSDKCall();
	if (g_hSDKDeleteThis == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	// void KeyValues::UsesEscapeSequences(bool state); // default false
	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::UsesEscapeSequences");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hSDKUsesEscapeSequences = EndPrepSDKCall();
	if (g_hSDKUsesEscapeSequences == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	// bool KeyValues::LoadFromFile( IBaseFileSystem *filesystem, const char *resourceName, const char *pathID);
	
	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::LoadFromFile");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // Why doesn't NULL_STRING work?
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKLoadFromFile = EndPrepSDKCall();
	if (g_hSDKLoadFromFile == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::LoadFromFile");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKLoadFromFile_PathID = EndPrepSDKCall();
	if (g_hSDKLoadFromFile_PathID == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::GetName");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	g_hSDKGetName = EndPrepSDKCall();
	if (g_hSDKGetName == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::SetName");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_hSDKSetName = EndPrepSDKCall();
	if (g_hSDKSetName == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::GetNameSymbol");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetNameSymbol = EndPrepSDKCall();
	if (g_hSDKGetNameSymbol == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::GetDataType");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetDataType = EndPrepSDKCall();
	if (g_hSDKGetDataType == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::GetString");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	g_hSDKGetString = EndPrepSDKCall();
	if (g_hSDKGetString == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::SetString");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_hSDKSetString = EndPrepSDKCall();
	if (g_hSDKSetString == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::SetStringValue");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_hSDKSetStringValue = EndPrepSDKCall();
	if (g_hSDKSetStringValue == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::GetInt");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetInt = EndPrepSDKCall();
	if (g_hSDKGetInt == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::SetInt");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKSetInt = EndPrepSDKCall();
	if (g_hSDKSetInt == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::GetFloat");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	g_hSDKGetFloat = EndPrepSDKCall();
	if (g_hSDKGetFloat == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::SetFloat");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	g_hSDKSetFloat = EndPrepSDKCall();
	if (g_hSDKSetFloat == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer); 

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::GetPtr");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetPtr = EndPrepSDKCall();
	if (g_hSDKGetPtr == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::FindKey");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKFindKey = EndPrepSDKCall();
	if (g_hSDKFindKey == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::FindKeyFromSymbol");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKFindKeyFromSymbol = EndPrepSDKCall();
	if (g_hSDKFindKeyFromSymbol == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::GetFirstSubKey");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetFirstSubKey = EndPrepSDKCall();
	if (g_hSDKGetFirstSubKey == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::GetNextKey");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetNextKey = EndPrepSDKCall();
	if (g_hSDKGetNextKey == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::GetFirstTrueSubKey");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetFirstTrueSubKey = EndPrepSDKCall();
	if (g_hSDKGetFirstTrueSubKey == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::GetNextTrueSubKey");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetNextTrueSubKey = EndPrepSDKCall();
	if (g_hSDKGetNextTrueSubKey == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::GetFirstValue");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetFirstValue = EndPrepSDKCall();
	if (g_hSDKGetFirstValue == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::GetNextValue");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetNextValue = EndPrepSDKCall();
	if (g_hSDKGetNextValue == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::SaveToFile");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKSaveToFile = EndPrepSDKCall();
	if (g_hSDKSaveToFile == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "KeyValues::SaveToFile");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer))
		SetFailState("Failed to find signature: \"%s\"", sBuffer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKSaveToFile_PathID = EndPrepSDKCall();
	if (g_hSDKSaveToFile_PathID == null)
		SetFailState("Failed to create SDKCall: \"%s\"", sBuffer);

	delete hGameData;
}


