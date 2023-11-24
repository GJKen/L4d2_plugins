/*  
*    Copyright (C) 2019  LuxLuma		acceliacat@gmail.com
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
#include <sdkhooks>

#pragma newdecls required

#define GAMEDATA "l4d2_M60_GrenadeLauncher_patches"
#define PLUGIN_VERSION	"1.0"


Address Ammo_Use = Address_Null;
int Ammo_Use_PatchRestoreBytes;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "[L4D2]GrenadeLauncher_AmmoPile_patch",
	author = "Lux",
	description = "Allows GrenadeLauncher to use ammo piles",
	version = PLUGIN_VERSION,
	url = "https://github.com/LuxLuma"
};

public void OnPluginStart()
{
	Handle hGamedata = LoadGameConfigFile(GAMEDATA);
	if(hGamedata == null) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
		
	GrenadeLauncher_M60_Ammo(hGamedata);
	
	delete hGamedata;
}

void GrenadeLauncher_M60_Ammo(Handle &hGamedata)
{
	Address patch;
	int offset;
	int byte;
	
	patch = GameConfGetAddress(hGamedata, "CWeaponAmmoSpawn::Use");
	if(!patch) 
	{
		LogError("Error finding the 'CWeaponAmmoSpawn::Use' signature.");
		return;
	}
	
	offset = GameConfGetOffset(hGamedata, "CWeaponAmmoSpawn::Use_NadeLauncher_Patch");
	if(offset == -1)
	{
		LogError("Invalid offset for 'CWeaponAmmoSpawn::Use_NadeLauncher_Patch'.");
		return;
	}
	
	byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if(byte != 0x15)
	{
		LogError("Incorrect offset for 'CWeaponAmmoSpawn::Use_NadeLauncher_Patch'.");
		return;
	}
	
	Ammo_Use = patch + view_as<Address>(offset);
	Ammo_Use_PatchRestoreBytes = LoadFromAddress(Ammo_Use, NumberType_Int8);
	StoreToAddress(Ammo_Use, 0xFF, NumberType_Int8);
	
	PrintToServer("GrenadeLauncher_AmmoPile_patch: Ammo pile allow use for GrenadeLauncher");
}

public void OnPluginEnd()
{
	if(Ammo_Use != Address_Null)
	{
		StoreToAddress(Ammo_Use, Ammo_Use_PatchRestoreBytes, NumberType_Int8);
		PrintToServer("GrenadeLauncher_AmmoPile_patch 'CWeaponAmmoSpawn::Use_NadeLauncher_Patch' restored");
	}
}
