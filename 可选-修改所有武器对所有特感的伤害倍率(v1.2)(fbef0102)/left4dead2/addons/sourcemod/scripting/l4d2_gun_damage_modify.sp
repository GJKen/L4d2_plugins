#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#define DEBUG 0

public Plugin myinfo = 
{
	name = "Modify every weapon damage done to Tank,SI,Witch,Common in l4d2",
	author = "Harry Potter",
	description = "as the name says, you dumb fuck",
	version = "1.2-2024/1/25",
	url = "https://steamcommunity.com/profiles/76561198026784913"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

#define L4D_TEAM_INFECTED  	3
#define L4D_TEAM_SURVIVOR  	2
#define L4D_TEAM_SPECTATOR 	1

#define ZC_SMOKER       	1
#define ZC_BOOMER       	2
#define ZC_HUNTER       	3
#define ZC_JOCKEY       	5
#define ZC_CHARGER      	6
#define ZC_TANK         	8

#define CLASSNAME_LENGTH 	64

//enum
enum WeaponID
{
	ID_NONE,
	ID_PISTOL,
	//ID_DUAL_PISTOL,
	ID_SMG,
	ID_PUMPSHOTGUN,
	ID_RIFLE,
	ID_AUTOSHOTGUN,
	ID_HUNTING_RIFLE,
	ID_SMG_SILENCED,
	ID_SMG_MP5,
	ID_CHROMESHOTGUN,
	ID_MAGNUM,
	ID_AK47,
	ID_RIFLE_DESERT,
	ID_SNIPER_MILITARY,
	ID_GRENADE,
	ID_SG552,
	ID_M60,
	ID_AWP,
	ID_SCOUT,
	ID_SPASSHOTGUN,
	//ID_Melee,
	ID_WEAPON_MAX
}

enum VictimID
{
	Victim_NONE,
	Victim_Tank,
	Victim_Witch,
	Victim_SI,
	Victim_Common,
	Victim_MAX
}
//convar
ConVar g_hCvarAllow;
ConVar g_hCvarWeaponDamageModfiy[view_as<int>(ID_WEAPON_MAX)][view_as<int>(Victim_MAX)];

//value
bool g_bEnable,bCvarAllow;
char Weapon_Name[view_as<int>(ID_WEAPON_MAX)][CLASSNAME_LENGTH];
int g_iOffset_Incapacitated;
WeaponID Cw[view_as<int>(ID_WEAPON_MAX)];
VictimID Cv[view_as<int>(Victim_MAX)];

public void OnPluginStart()
{
	g_hCvarAllow = CreateConVar(	"l4d_gun_damage_modify_enable", "1",
								"Enable gun damage modify plugin. [0-Disable,1-Enable]",
								FCVAR_NOTIFY, true, 0.0, true, 1.0 );			


	for(WeaponID i = ID_NONE ; i < ID_WEAPON_MAX ; ++i)
		Cw[i] = i;
	for(VictimID i = Victim_NONE ; i < Victim_MAX; ++i)
		Cv[i] = i;

	g_hCvarWeaponDamageModfiy[Cw[ID_PISTOL]][Cv[Victim_Tank]] = CreateConVar("l4d_pistol_damage_tank_multi", "1.0",
								"Modfiy pistol Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_PISTOL]][Cv[Victim_Witch]] = CreateConVar("l4d_pistol_damage_witch_multi", "1.0",
								"Modfiy pistol Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_PISTOL]][Cv[Victim_SI]] = CreateConVar("l4d_pistol_damage_SI_multi", "1.0",
								"Modfiy pistol Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_PISTOL]][Cv[Victim_Common]] = CreateConVar("l4d_pistol_damage_common_multi", "1.0",
								"Modfiy pistol Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_SMG]][Cv[Victim_Tank]] = CreateConVar("l4d_smg_damage_tank_multi", "1.0",
								"Modfiy smg Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_SMG]][Cv[Victim_Witch]] = CreateConVar("l4d_smg_damage_witch_multi", "1.0",
								"Modfiy smg Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SMG]][Cv[Victim_SI]] = CreateConVar("l4d_smg_damage_SI_multi", "1.0",
								"Modfiy smg Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SMG]][Cv[Victim_Common]] = CreateConVar("l4d_smg_damage_common_multi", "1.0",
								"Modfiy smg Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);																														
	g_hCvarWeaponDamageModfiy[Cw[ID_PUMPSHOTGUN]][Cv[Victim_Tank]] = CreateConVar("l4d_pumpshotgun_damage_tank_multi", "1.0",
								"Modfiy pumpshotgun Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_PUMPSHOTGUN]][Cv[Victim_Witch]] = CreateConVar("l4d_pumpshotgun_damage_witch_multi", "1.0",
								"Modfiy pumpshotgun Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_PUMPSHOTGUN]][Cv[Victim_SI]] = CreateConVar("l4d_pumpshotgun_damage_SI_multi", "1.0",
								"Modfiy pumpshotgun Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_PUMPSHOTGUN]][Cv[Victim_Common]] = CreateConVar("l4d_pumpshotgun_damage_common_multi", "1.0",
								"Modfiy pumpshotgun Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);	
	g_hCvarWeaponDamageModfiy[Cw[ID_RIFLE]][Cv[Victim_Tank]] = CreateConVar("l4d_rifle_damage_tank_multi", "1.0",
								"Modfiy rifle Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_RIFLE]][Cv[Victim_Witch]] = CreateConVar("l4d_rifle_damage_witch_multi", "1.0",
								"Modfiy rifle Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_RIFLE]][Cv[Victim_SI]] = CreateConVar("l4d_rifle_damage_SI_multi", "1.0",
								"Modfiy rifle Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_RIFLE]][Cv[Victim_Common]] = CreateConVar("l4d_rifle_damage_common_multi", "1.0",
								"Modfiy rifle Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);	
	g_hCvarWeaponDamageModfiy[Cw[ID_AUTOSHOTGUN]][Cv[Victim_Tank]] = CreateConVar("l4d_autoshotgun_damage_tank_multi", "1.0",
								"Modfiy auto shotgun Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_AUTOSHOTGUN]][Cv[Victim_Witch]] = CreateConVar("l4d_autoshotgun_damage_witch_multi", "1.0",
								"Modfiy auto shotgun Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_AUTOSHOTGUN]][Cv[Victim_SI]] = CreateConVar("l4d_autoshotgun_damage_SI_multi", "1.0",
								"Modfiy auto shotgun Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_AUTOSHOTGUN]][Cv[Victim_Common]] = CreateConVar("l4d_autoshotgun_damage_common_multi", "1.0",
								"Modfiy auto shotgun Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);	
	g_hCvarWeaponDamageModfiy[Cw[ID_HUNTING_RIFLE]][Cv[Victim_Tank]] = CreateConVar("l4d_huntingrifle_damage_tank_multi", "1.0",
								"Modfiy hunting rifle Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_HUNTING_RIFLE]][Cv[Victim_Witch]] = CreateConVar("l4d_huntingrifle_damage_witch_multi", "1.0",
								"Modfiy hunting rifle Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_HUNTING_RIFLE]][Cv[Victim_SI]] = CreateConVar("l4d_huntingrifle_damage_SI_multi", "1.0",
								"Modfiy hunting rifle Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_HUNTING_RIFLE]][Cv[Victim_Common]] = CreateConVar("l4d_huntingrifle_damage_common_multi", "1.0",
								"Modfiy hunting rifle Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);	
	g_hCvarWeaponDamageModfiy[Cw[ID_SMG_SILENCED]][Cv[Victim_Tank]] = CreateConVar("l4d_smgsilenced_damage_tank_multi", "1.0",
								"Modfiy silenced smg Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_SMG_SILENCED]][Cv[Victim_Witch]] = CreateConVar("l4d_smgsilenced_damage_witch_multi", "1.0",
								"Modfiy silenced smg Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SMG_SILENCED]][Cv[Victim_SI]] = CreateConVar("l4d_smgsilenced_damage_SI_multi", "1.0",
								"Modfiy silenced smg Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SMG_SILENCED]][Cv[Victim_Common]] = CreateConVar("l4d_smgsilenced_damage_common_multi", "1.0",
								"Modfiy silenced smg Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);	
	g_hCvarWeaponDamageModfiy[Cw[ID_SMG_MP5]][Cv[Victim_Tank]] = CreateConVar("l4d_mp5_damage_tank_multi", "1.0",
								"Modfiy mp5 Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_SMG_MP5]][Cv[Victim_Witch]] = CreateConVar("l4d_mp5_damage_witch_multi", "1.0",
								"Modfiy mp5 Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SMG_MP5]][Cv[Victim_SI]] = CreateConVar("l4d_mp5_damage_SI_multi", "1.0",
								"Modfiy mp5 Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SMG_MP5]][Cv[Victim_Common]] = CreateConVar("l4d_mp5_damage_common_multi", "1.0",
								"Modfiy mp5 Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);	
	g_hCvarWeaponDamageModfiy[Cw[ID_CHROMESHOTGUN]][Cv[Victim_Tank]] = CreateConVar("l4d_chromeshotgun_damage_tank_multi", "1.0",
								"Modfiy chrome shotgun Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_CHROMESHOTGUN]][Cv[Victim_Witch]] = CreateConVar("l4d_chromeshotgun_damage_witch_multi", "1.0",
								"Modfiy chrome shotgun Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_CHROMESHOTGUN]][Cv[Victim_SI]] = CreateConVar("l4d_chromeshotgun_damage_SI_multi", "1.0",
								"Modfiy chrome shotgun Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_CHROMESHOTGUN]][Cv[Victim_Common]] = CreateConVar("l4d_chromeshotgun_damage_common_multi", "1.0",
								"Modfiy chrome shotgun Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);								
	g_hCvarWeaponDamageModfiy[Cw[ID_MAGNUM]][Cv[Victim_Tank]] = CreateConVar("l4d_magnum_damage_tank_multi", "1.0",
								"Modfiy magnum Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_MAGNUM]][Cv[Victim_Witch]] = CreateConVar("l4d_magnum_damage_witch_multi", "1.0",
								"Modfiy magnum Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_MAGNUM]][Cv[Victim_SI]] = CreateConVar("l4d_magnum_damage_SI_multi", "1.0",
								"Modfiy magnum Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_MAGNUM]][Cv[Victim_Common]] = CreateConVar("l4d_magnum_damage_common_multi", "1.0",
								"Modfiy magnum Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);	
	g_hCvarWeaponDamageModfiy[Cw[ID_AK47]][Cv[Victim_Tank]] = CreateConVar("l4d_ak47_damage_tank_multi", "1.0",
								"Modfiy ak47 Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_AK47]][Cv[Victim_Witch]] = CreateConVar("l4d_ak47_damage_witch_multi", "1.0",
								"Modfiy ak47 Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_AK47]][Cv[Victim_SI]] = CreateConVar("l4d_ak47_damage_SI_multi", "1.0",
								"Modfiy ak47 Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_AK47]][Cv[Victim_Common]] = CreateConVar("l4d_ak47_damage_common_multi", "1.0",
								"Modfiy ak47 Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);	
	g_hCvarWeaponDamageModfiy[Cw[ID_RIFLE_DESERT]][Cv[Victim_Tank]] = CreateConVar("l4d_rifledesert_damage_tank_multi", "1.0",
								"Modfiy rifle desert Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_RIFLE_DESERT]][Cv[Victim_Witch]] = CreateConVar("l4d_rifledesert_damage_witch_multi", "1.0",
								"Modfiy rifle desert Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_RIFLE_DESERT]][Cv[Victim_SI]] = CreateConVar("l4d_rifledesert_damage_SI_multi", "1.0",
								"Modfiy rifle desert Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_RIFLE_DESERT]][Cv[Victim_Common]] = CreateConVar("l4d_rifledesert_damage_common_multi", "1.0",
								"Modfiy rifle desert Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);	
	g_hCvarWeaponDamageModfiy[Cw[ID_SNIPER_MILITARY]][Cv[Victim_Tank]] = CreateConVar("l4d_militarysniper_damage_tank_multi", "1.0",
								"Modfiy military sniper Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_SNIPER_MILITARY]][Cv[Victim_Witch]] = CreateConVar("l4d_militarysniper_damage_witch_multi", "1.0",
								"Modfiy military sniper Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SNIPER_MILITARY]][Cv[Victim_SI]] = CreateConVar("l4d_militarysniper_damage_SI_multi", "1.0",
								"Modfiy military sniper Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SNIPER_MILITARY]][Cv[Victim_Common]] = CreateConVar("l4d_militarysniper_damage_common_multi", "1.0",
								"Modfiy military sniper Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_GRENADE]][Cv[Victim_Tank]] = CreateConVar("l4d_grenadelauncher_damage_tank_multi", "1.0",
								"Modfiy grenade launcher Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_GRENADE]][Cv[Victim_Witch]] = CreateConVar("l4d_grenadelauncher_damage_witch_multi", "1.0",
								"Modfiy grenade launcher Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_GRENADE]][Cv[Victim_SI]] = CreateConVar("l4d_grenadelauncher_damage_SI_multi", "1.0",
								"Modfiy grenade launcher Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_GRENADE]][Cv[Victim_Common]] = CreateConVar("l4d_grenadelauncher_damage_common_multi", "1.0",
								"Modfiy grenade launcher Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);																					
	g_hCvarWeaponDamageModfiy[Cw[ID_SG552]][Cv[Victim_Tank]] = CreateConVar("l4d_sg552_damage_tank_multi", "1.0",
								"Modfiy sg552 Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_SG552]][Cv[Victim_Witch]] = CreateConVar("l4d_sg552_damage_witch_multi", "1.0",
								"Modfiy sg552 Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SG552]][Cv[Victim_SI]] = CreateConVar("l4d_sg552_damage_SI_multi", "1.0",
								"Modfiy sg552 Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SG552]][Cv[Victim_Common]] = CreateConVar("l4d_sg552_damage_common_multi", "1.0",
								"Modfiy sg552 Damage to Common multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_M60]][Cv[Victim_Tank]] = CreateConVar("l4d_m60_damage_tank_multi", "1.0",
								"Modfiy m60 Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_M60]][Cv[Victim_Witch]] = CreateConVar("l4d_m60_damage_witch_multi", "1.0",
								"Modfiy m60 Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_M60]][Cv[Victim_SI]] = CreateConVar("l4d_m60_damage_SI_multi", "1.0",
								"Modfiy m60 Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_M60]][Cv[Victim_Common]] = CreateConVar("l4d_m60_damage_common_multi", "1.0",
								"Modfiy m60 Damage to Common multi.",	
								FCVAR_NOTIFY, true, 0.0);	
	g_hCvarWeaponDamageModfiy[Cw[ID_AWP]][Cv[Victim_Tank]] = CreateConVar("l4d_awp_damage_tank_multi", "1.0",
								"Modfiy awp Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_AWP]][Cv[Victim_Witch]] = CreateConVar("l4d_awp_damage_witch_multi", "1.0",
								"Modfiy awp Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_AWP]][Cv[Victim_SI]] = CreateConVar("l4d_awp_damage_SI_multi", "1.0",
								"Modfiy awp Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_AWP]][Cv[Victim_Common]] = CreateConVar("l4d_awp_damage_common_multi", "1.0",
								"Modfiy awp Damage to Common multi.",	
								FCVAR_NOTIFY, true, 0.0);	
	g_hCvarWeaponDamageModfiy[Cw[ID_SCOUT]][Cv[Victim_Tank]] = CreateConVar("l4d_scout_damage_tank_multi", "1.0",
								"Modfiy scout Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_SCOUT]][Cv[Victim_Witch]] = CreateConVar("l4d_scout_damage_witch_multi", "1.0",
								"Modfiy scout Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SCOUT]][Cv[Victim_SI]] = CreateConVar("l4d_scout_damage_SI_multi", "1.0",
								"Modfiy scout Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SCOUT]][Cv[Victim_Common]] = CreateConVar("l4d_scout_damage_common_multi", "1.0",
								"Modfiy scout Damage to Common multi.",	
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SPASSHOTGUN]][Cv[Victim_Tank]] = CreateConVar("l4d_spasshotgun_damage_tank_multi", "1.0",
								"Modfiy spas shotgun Damage to tank multi.",
								FCVAR_NOTIFY, true, 0.0);
	g_hCvarWeaponDamageModfiy[Cw[ID_SPASSHOTGUN]][Cv[Victim_Witch]] = CreateConVar("l4d_spasshotgun_damage_witch_multi", "1.0",
								"Modfiy spas shotgun Damage to witch multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SPASSHOTGUN]][Cv[Victim_SI]] = CreateConVar("l4d_spasshotgun_damage_SI_multi", "1.0",
								"Modfiy spas shotgun Damage to SI multi.",
								FCVAR_NOTIFY, true, 0.0);		
	g_hCvarWeaponDamageModfiy[Cw[ID_SPASSHOTGUN]][Cv[Victim_Common]] = CreateConVar("l4d_spasshotgun_damage_common_multi", "1.0",
								"Modfiy spas shotgun Damage to Common multi.",	
								FCVAR_NOTIFY, true, 0.0);																	

	g_hCvarAllow.AddChangeHook(ConVarChanged_Allowed);
	
	AutoExecConfig(true, "l4d2_gun_damage_modify");
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Allowed(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void IsAllowed()
{
	bCvarAllow = g_hCvarAllow.BoolValue;
	if( g_bEnable == false && bCvarAllow == true ) 
	{
		g_bEnable = true;
		SetSettings();
	}
	else if( g_bEnable == true && bCvarAllow == false )
	{
		g_bEnable = false;
	}
}

void SetSettings()
{
	g_iOffset_Incapacitated = FindSendPropInfo("Tank", "m_isIncapacitated");

	Weapon_Name[ID_NONE] = "";
	Weapon_Name[ID_PISTOL] = "weapon_pistol";
	//Weapon_Name[ID_DUAL_PISTOL] = "weapon_pistol";
	Weapon_Name[ID_SMG] = "weapon_smg";
	Weapon_Name[ID_PUMPSHOTGUN] = "weapon_pumpshotgun";
	Weapon_Name[ID_RIFLE] = "weapon_rifle";
	Weapon_Name[ID_AUTOSHOTGUN] = "weapon_autoshotgun";
	Weapon_Name[ID_HUNTING_RIFLE] = "weapon_hunting_rifle";
	Weapon_Name[ID_SMG_SILENCED] = "weapon_smg_silenced";
	Weapon_Name[ID_SMG_MP5] = "weapon_smg_mp5";
	Weapon_Name[ID_CHROMESHOTGUN] = "weapon_shotgun_chrome";
	Weapon_Name[ID_MAGNUM] = "weapon_pistol_magnum";
	Weapon_Name[ID_AK47] = "weapon_rifle_ak47";
	Weapon_Name[ID_RIFLE_DESERT] = "weapon_rifle_desert";
	Weapon_Name[ID_SNIPER_MILITARY] = "weapon_sniper_military";
	Weapon_Name[ID_GRENADE] = "weapon_grenade_launcher";
	Weapon_Name[ID_SG552] = "weapon_rifle_sg552";
	Weapon_Name[ID_M60] = "weapon_rifle_m60";
	Weapon_Name[ID_AWP] = "weapon_sniper_awp";
	Weapon_Name[ID_SCOUT] = "weapon_sniper_scout";
	Weapon_Name[ID_SPASSHOTGUN] = "weapon_shotgun_spas";
	//Weapon_Name[ID_Melee] = "weapon_melee";
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage); 
}

public void OnEntityCreated(int entity, const char[] classname) 
{ 
	if (!IsValidEntityIndex(entity))
		return;

	switch (classname[0])
	{
		case 'i':
		{
			if(strncmp(classname, "infected", 18) == 0)
			{
				SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage); 
			}
		}
		case 'w':
		{
			if(strncmp(classname, "witch", 18) == 0)
			{
				SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
	}
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(damage <= 0.0 || g_bEnable == false) return Plugin_Continue;
	if(!IsClientAndInGame(attacker) || 
		GetClientTeam(attacker) != L4D_TEAM_SURVIVOR ||
		attacker == victim
	) return Plugin_Continue;

	VictimID victimId = Victim_NONE;

	if(IsClientAndInGame(victim) && GetClientTeam(victim) == L4D_TEAM_INFECTED && IsPlayerAlive(victim))
	{
		if(GetEntProp(victim, Prop_Send, "m_zombieClass") == ZC_TANK)
		{
			if(IsTankDying(victim)) return Plugin_Continue;

			victimId = Victim_Tank;
		}
		else
			victimId = Victim_SI;
	}

	if(IsCommonInfected(victim)) victimId = Victim_Common;
	if(IsWitch(victim)) victimId = Victim_Witch;
	
	if(victimId == Victim_NONE) return Plugin_Continue;

	damage = float(RoundToNearest(damage));

	char sWeaponName[CLASSNAME_LENGTH];
	GetClientWeapon(attacker,sWeaponName, sizeof(sWeaponName));
	#if DEBUG
		PrintToChatAll("%N use %s to attack %d, damage: %f - > %f",attacker,sWeaponName,victim,damage,damage * g_hCvarWeaponDamageModfiy[weaponId][victimId].FloatValue);
	#endif
	WeaponID weaponId = GetWeaponID(sWeaponName);
	if(weaponId == ID_NONE) return Plugin_Continue; //找不到武器名稱

	damage = damage * g_hCvarWeaponDamageModfiy[weaponId][victimId].FloatValue;

	return Plugin_Changed;
}

stock bool IsClientAndInGame(int client)
{
	if (0 < client && client <= MaxClients)
	{	
		return IsClientInGame(client);
	}
	return false;
}

WeaponID GetWeaponID(char[] sWeaponName)
{
	for(WeaponID i = ID_NONE; i < ID_WEAPON_MAX ; ++i)
	{
		if(StrEqual(sWeaponName, Weapon_Name[i],false))
			return i;
	}
	return ID_NONE;
}

bool IsCommonInfected(int entity)
{
	if(entity && IsValidEntity(entity) && IsValidEdict(entity))
	{
		char classname[32];
		GetEdictClassname(entity, classname, sizeof(classname));
		return StrEqual(classname, "infected");
	}
	return false;
} 

bool IsWitch(int entity)
{
	if(entity && IsValidEntity(entity) && IsValidEdict(entity))
	{
		char classname[32];
		GetEdictClassname(entity, classname, sizeof(classname));
		return StrEqual(classname, "witch");
	}
	return false;
}  

bool IsTankDying(int tankclient)
{
	if (!tankclient) return false;
 
	return view_as<bool>(GetEntData(tankclient, g_iOffset_Incapacitated));
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}