/*  
*    Copyright (C) 2021  LuxLuma
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU General Public License as published by
*    the Free Software Foundation, either version 3 of the License, or
*    (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU General Public License for more details.
*
*    You should have received a copy of the GNU General Public License
*    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define REQUIRE_EXTENSIONS
#include <sourcescramble>

#pragma newdecls required

#define PLUGIN_VERSION	"1.0"
#define GAMEDATA "l4d2_cs_ladders"

#define PLUGIN_NAME_KEY "[cs_ladders]"
#define TERROR_CAN_DEPLOY_FOR_KEY "CTerrorWeapon::CanDeployFor__movetype_patch"
#define TERROR_PRE_THINK_KEY "CTerrorPlayer::PreThink__SafeDropLogic_patch"
#define TERROR_ON_LADDER_MOUNT_KEY "CTerrorPlayer::OnLadderMount__WeaponHolster_patch"
#define TERROR_ON_LADDER_DISMOUNT_KEY "CTerrorPlayer::OnLadderDismount__WeaponDeploy_patch"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion CurrentEngine = GetEngineVersion();
	if(CurrentEngine != Engine_Left4Dead && CurrentEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "[L4D & L4D2]cs_ladders",
	author = "Lux",
	description = "Makes ladders similar to counter-strike",
	version = PLUGIN_VERSION,
	url = "https://github.com/LuxLuma/L4D-small-plugins/tree/master/L4D2_cs_ladders"
};

public void OnPluginStart()
{
	CreateConVar("l4d2_cs_ladders", PLUGIN_VERSION, "", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if(hGameData == null) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
	
	
	MemoryPatch patcher;
	patcher = MemoryPatch.CreateFromConf(hGameData, TERROR_CAN_DEPLOY_FOR_KEY);
	if(!patcher.Validate())
	{
		SetFailState("%s Failed to validate patch \"%s\"", PLUGIN_NAME_KEY, TERROR_CAN_DEPLOY_FOR_KEY);
	}
	else if(patcher.Enable())
	{
		PrintToServer("%s Enabled \"%s\" patch", PLUGIN_NAME_KEY, TERROR_CAN_DEPLOY_FOR_KEY);
	}
	
	patcher = MemoryPatch.CreateFromConf(hGameData, TERROR_PRE_THINK_KEY);
	if(!patcher.Validate())
	{
		SetFailState("%s Failed to validate patch \"%s\"", PLUGIN_NAME_KEY, TERROR_PRE_THINK_KEY);
	}
	else if(patcher.Enable())
	{
		PrintToServer("%s Enabled \"%s\" patch", PLUGIN_NAME_KEY, TERROR_PRE_THINK_KEY);
	}
	
	// not as important as first 2 patches, can still function enough to be good enough.
	patcher = MemoryPatch.CreateFromConf(hGameData, TERROR_ON_LADDER_MOUNT_KEY);
	if(!patcher.Validate())
	{
		LogError("%s Failed to validate patch \"%s\"", PLUGIN_NAME_KEY, TERROR_ON_LADDER_MOUNT_KEY);
	}
	else if(patcher.Enable())
	{
		PrintToServer("%s Enabled \"%s\" patch", PLUGIN_NAME_KEY, TERROR_ON_LADDER_MOUNT_KEY);
	}
	
	patcher = MemoryPatch.CreateFromConf(hGameData, TERROR_ON_LADDER_DISMOUNT_KEY);
	if(!patcher.Validate())
	{
		LogError("%s Failed to validate patch \"%s\"", PLUGIN_NAME_KEY, TERROR_ON_LADDER_DISMOUNT_KEY);
	}
	else if(patcher.Enable())
	{
		PrintToServer("%s Enabled \"%s\" patch", PLUGIN_NAME_KEY, TERROR_ON_LADDER_DISMOUNT_KEY);
	}
	delete hGameData;
}