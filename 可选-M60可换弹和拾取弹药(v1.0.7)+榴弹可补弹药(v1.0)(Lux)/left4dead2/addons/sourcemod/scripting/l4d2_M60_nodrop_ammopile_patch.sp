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
#define PLUGIN_VERSION	"1.0.7"

int G_hCVARM60;
ConVar hCVAR_M60;

Address M60_Drop = Address_Null;
int M60_Drop_PatchRestoreBytes;

Address Ammo_Use = Address_Null;
int Ammo_Use_PatchRestoreBytes;

bool g_bM60AddedClip[2048+1];
int g_iM60Ref[2048+1];

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
	name = "[L4D2]M60_NoDrop_AmmoPile_patch",
	author = "Lux",
	description = "Prevents m60 from dropping and allows use of ammo piles",
	version = PLUGIN_VERSION,
	url = "https://github.com/LuxLuma"
};

public void OnPluginStart()
{
	hCVAR_M60 = CreateConVar("l4d2_M60_nodrop_ammopile_patch", "950", "设置机枪M60后备弹药数量.", FCVAR_NOTIFY);
	hCVAR_M60.AddChangeHook(CVARChangedM60);
	AutoExecConfig(true, "l4d2_M60_NoDrop_AmmoPile_patch");
	
	Handle hGamedata = LoadGameConfigFile(GAMEDATA);
	if(hGamedata == null) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
	
	Patch_M60_Drop(hGamedata);
	Patch_M60_Ammo(hGamedata);
	
	delete hGamedata;
}

public void CVARChangedM60(ConVar convar, const char[] oldValue, const char[] newValue)
{
	l4d2_M60AmmoPile();
}

void l4d2_M60AmmoPile()
{
	G_hCVARM60 = hCVAR_M60.IntValue;
}

public void OnMapStart()
{
	l4d2_M60AmmoPile();
}

public void OnConfigsExecuted()
{
	SetConVarInt(FindConVar("ammo_m60_max"), G_hCVARM60, false, false);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnM60AllowPreserveClip);
	SDKHook(client, SDKHook_WeaponDrop, OnM60PreservePickup);
}

public void OnM60AllowPreserveClip(int client, int weapon)
{
	if(weapon < MaxClients+1 || !IsValidEntRef(g_iM60Ref[weapon]))
		return;
	
	if(!g_bM60AddedClip[weapon])
		return;
	
	g_bM60AddedClip[weapon] = false;
	
	int iClip = GetEntProp(weapon, Prop_Data, "m_iClip1");// just incase clip is set higher than 1 when on floor
	if(iClip >= 1)
		SetEntProp(weapon, Prop_Data, "m_iClip1", --iClip);
}

public void OnM60PreservePickup(int client, int weapon)
{
	if(weapon < MaxClients+1 || !IsValidEntRef(g_iM60Ref[weapon]))
		return;
	
	int iClip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	if(iClip <= 0)
	{
		g_bM60AddedClip[weapon] = true;
		SetEntProp(weapon, Prop_Data, "m_iClip1", 1);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(entity < 1)
		return;
	
	g_bM60AddedClip[entity] = false;
	
	if(classname[0] != 'w' || !StrEqual(classname, "weapon_rifle_m60", false))
		return;
	
	g_iM60Ref[entity] = EntIndexToEntRef(entity);
}

void Patch_M60_Drop(Handle &hGamedata)
{
	Address patch;
	int offset;
	int byte;
	
	patch = GameConfGetAddress(hGamedata, "CRifle_M60::PrimaryAttack");
	if(!patch) 
	{
		LogError("Error finding the 'CRifle_M60::PrimaryAttack' signature.");
		return;
	}
	
	offset = GameConfGetOffset(hGamedata, "CRifle_M60::PrimaryAttack");
	if(offset == -1)
	{
		LogError("Invalid offset for 'CRifle_M60::PrimaryAttack'.");
		return;
	}
	
	byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if(byte == 0x75 || byte == 0x85)
	{
		M60_Drop = patch + view_as<Address>(offset);
		M60_Drop_PatchRestoreBytes = LoadFromAddress(M60_Drop, NumberType_Int8);
		
		if(byte == 0x75)
		{
			StoreToAddress(M60_Drop, 0xEB, NumberType_Int8);
		}
		else
		{
			StoreToAddress(M60_Drop, 0x8D, NumberType_Int8);
		}
	}
	else
	{
		LogError("Incorrect offset for 'CRifle_M60::PrimaryAttack'.");
		return;
	}
	
	PrintToServer("M60_NoDrop_AmmoPile_patch:Prevent drop patch applied 'CRifle_M60::PrimaryAttack'");
}

void Patch_M60_Ammo(Handle &hGamedata)
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
	
	offset = GameConfGetOffset(hGamedata, "CWeaponAmmoSpawn::Use_M60_Patch");
	if(offset == -1)
	{
		LogError("Invalid offset for 'CWeaponAmmoSpawn::Use_M60_Patch'.");
		return;
	}
	
	byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if(byte != 0x25)
	{
		LogError("Incorrect offset for 'CWeaponAmmoSpawn::Use_M60_Patch'.");
		return;
	}
	
	Ammo_Use = patch + view_as<Address>(offset);
	Ammo_Use_PatchRestoreBytes = LoadFromAddress(Ammo_Use, NumberType_Int8);
	StoreToAddress(Ammo_Use, 0xFF, NumberType_Int8);
	
	PrintToServer("M60_NoDrop_AmmoPile_patch:Ammo piles allow use 'CWeaponAmmoSpawn::Use_M60_Patch'");
}

public void OnPluginEnd()
{
	if(M60_Drop != Address_Null)
	{
		StoreToAddress(M60_Drop, M60_Drop_PatchRestoreBytes, NumberType_Int8);
		PrintToServer("M60_NoDrop_AmmoPile_patch:'CRifle_M60::PrimaryAttack' restored");
	}
	
	if(Ammo_Use != Address_Null)
	{
		StoreToAddress(Ammo_Use, Ammo_Use_PatchRestoreBytes, NumberType_Int8);
		PrintToServer("M60_NoDrop_AmmoPile_patch:'CWeaponAmmoSpawn::Use_M60_Patch' restored");
	}
}

static bool IsValidEntRef(int iEntRef)
{
	return (iEntRef != 0 && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE);
}