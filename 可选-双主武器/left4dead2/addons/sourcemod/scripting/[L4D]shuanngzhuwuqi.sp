//预加:增加游戏提示,修改buttons
#include <sourcemod>
#include <sdktools> 

public Plugin:myinfo = 
{
	name = "双主武器",
	author = "非本龟",
	description = "双主武器",
	version = "0.2.2",
	url = "",
};

new String:weapon_d[MAXPLAYERS+1][64];
new danjia_d[MAXPLAYERS+1] = 0;
new houbei_d[MAXPLAYERS+1] = 0;
new txammo_d[MAXPLAYERS+1] = 0;
new txanum_d[MAXPLAYERS+1] = 0;
new bool: C_Timer[MAXPLAYERS+1] = false;
new String:game[64];
		
public OnPluginStart()
{
	HookEvent("finale_win", RoundEnd);
	HookEvent("mission_lost", RoundEnd);
	HookEvent("player_death", Player_Death);
	HookEvent("player_team", Player_Team);
	
	for(new i=1; i<=MAXPLAYERS; i++) weapon_d[i] = "weapon_none";
	
	GetGameFolderName(game, sizeof(game));
}

public Action:RoundEnd(Handle:event, String:event_name[], bool:dontBroadcast)
{
	for(new i=1; i<=MaxClients; i++) 	
	{
		weapon_d[i] = "weapon_none";
		danjia_d[i] = 0;
		houbei_d[i] = 0;
		txammo_d[i] = 0;
		txanum_d[i] = 0;
		C_Timer[i] = false;
	}
}

public Action:Player_Death(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid")); 
	weapon_d[client] = "weapon_none";
	danjia_d[client] = 0;
	houbei_d[client] = 0;
	txammo_d[client] = 0;
	txanum_d[client] = 0;
	C_Timer[client] = false;
}

public Action:Player_Team(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new newteam = GetEventInt(event, "team");
	if(newteam == 3)
	{
		weapon_d[client] = "weapon_none";
		danjia_d[client] = 0;
		houbei_d[client] = 0;
		txammo_d[client] = 0;
		txanum_d[client] = 0;
		C_Timer[client] = false;
	}
}

public Action:C_Timer_End(Handle:timer,any:client) 
{
	C_Timer[client] = false;
}

stock CheatCommand(Client, const String:command[], const String:arguments[])
{
    if (!Client) return;
    new admindata = GetUserFlagBits(Client);
    SetUserFlagBits(Client, ADMFLAG_ROOT);
    new flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    FakeClientCommand(Client, "%s %s", command, arguments);
    SetCommandFlags(command, flags);
    SetUserFlagBits(Client, admindata);
}		

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
	{
		if (buttons & IN_USE && buttons & IN_ATTACK2)
		{
			if(C_Timer[client] == false)
			{	
				C_Timer[client] = true;
				new ent = GetPlayerWeaponSlot(client, 0);
				if(ent != -1)
				{
					new String:weapon_f[64];
					new danjia_f;
					new houbei_f;
					new txammo_f;
					new txanum_f;
					GetEdictClassname(ent, weapon_f, 64);
					if(StrEqual(game, "left4dead")) GetClientWeaponInfo_l4d1(client, houbei_f, danjia_f);
					if(StrEqual(game, "left4dead2")) GetClientWeaponInfo_l4d2(client, houbei_f, danjia_f);
					txammo_f = GetEntProp(ent, Prop_Send, "m_upgradeBitVec");
					txanum_f = GetEntProp(ent, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
					RemovePlayerItem(client, ent);
					if(!StrEqual(weapon_d[client], "weapon_none")) 
					{
						CheatCommand(client, "give", weapon_d[client]);
						if(StrEqual(game, "left4dead")) SetClientWeaponInfo_l4d1(client, houbei_d[client], danjia_d[client]);
						if(StrEqual(game, "left4dead2")) SetClientWeaponInfo_l4d2(client, houbei_d[client], danjia_d[client]);
						SetEntProp(GetPlayerWeaponSlot(client, 0), Prop_Send, "m_upgradeBitVec", txammo_d[client]);
						SetEntProp(GetPlayerWeaponSlot(client, 0), Prop_Send, "m_nUpgradedPrimaryAmmoLoaded",  txanum_d[client]);
					}
					weapon_d[client] = weapon_f;
					danjia_d[client] = danjia_f;
					houbei_d[client] = houbei_f;
					txammo_d[client] = txammo_f;
					txanum_d[client] = txanum_f;
				}
				else
				{
					if(!StrEqual(weapon_d[client], "weapon_none")) 
					{
						CheatCommand(client, "give", weapon_d[client]);
						if(StrEqual(game, "left4dead")) SetClientWeaponInfo_l4d1(client, houbei_d[client], danjia_d[client]);
						if(StrEqual(game, "left4dead2")) SetClientWeaponInfo_l4d2(client, houbei_d[client], danjia_d[client]);
						SetEntProp(GetPlayerWeaponSlot(client, 0), Prop_Send, "m_upgradeBitVec", txammo_d[client]);
						SetEntProp(GetPlayerWeaponSlot(client, 0), Prop_Send, "m_nUpgradedPrimaryAmmoLoaded",  txanum_d[client]);
					}
					weapon_d[client] = "weapon_none";
					danjia_d[client] = 0;
					houbei_d[client] = 0;
					txammo_d[client] = 0;
					txanum_d[client] = 0;
				}
				CreateTimer(GetConVarFloat(FindConVar("z_gun_swing_interval")), C_Timer_End,client);
			}
		}
	}
	return Plugin_Continue;	
}					

GetClientWeaponInfo_l4d2(client, &ammo, &clip)
{
	new slot=0;
	if (GetPlayerWeaponSlot(client, slot) > 0)
	{
		new String:weapon[32]; 
		new ammoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
		GetEdictClassname(GetPlayerWeaponSlot(client, slot), weapon, 32);
		new bool:set=false;
		if (slot == 0)
		{
			clip = GetEntProp(GetPlayerWeaponSlot(client, 0), Prop_Send, "m_iClip1");
			if (StrEqual(weapon, "weapon_rifle") || StrEqual(weapon, "weapon_rifle_sg552") || StrEqual(weapon, "weapon_rifle_desert") || StrEqual(weapon, "weapon_rifle_ak47"))
			{
				ammo = GetEntData(client, ammoOffset+(12));
				if(set)SetEntData(client, ammoOffset+(12), 0);
			}
			else if (StrEqual(weapon, "weapon_smg") || StrEqual(weapon, "weapon_smg_silenced") || StrEqual(weapon, "weapon_smg_mp5"))
			{
				ammo = GetEntData(client, ammoOffset+(20));
				if(set)SetEntData(client, ammoOffset+(20), 0);
			}
			else if (StrEqual(weapon, "weapon_pumpshotgun") || StrEqual(weapon, "weapon_shotgun_chrome"))
			{
				ammo = GetEntData(client, ammoOffset+(28));
				if(set)SetEntData(client, ammoOffset+(28), 0);
			}
			else if (StrEqual(weapon, "weapon_autoshotgun") || StrEqual(weapon, "weapon_shotgun_spas"))
			{
				ammo = GetEntData(client, ammoOffset+(32));
				if(set)SetEntData(client, ammoOffset+(32), 0);
			}
			else if (StrEqual(weapon, "weapon_hunting_rifle"))
			{
				ammo = GetEntData(client, ammoOffset+(36));
				if(set)SetEntData(client, ammoOffset+(36), 0);
			}
			else if (StrEqual(weapon, "weapon_sniper_scout") || StrEqual(weapon, "weapon_sniper_military") || StrEqual(weapon, "weapon_sniper_awp"))
			{
				ammo = GetEntData(client, ammoOffset+(40));
				if(set)SetEntData(client, ammoOffset+(40), 0);
			}
			else if (StrEqual(weapon, "weapon_grenade_launcher"))
			{
				ammo = GetEntData(client, ammoOffset+(68));
				if(set)SetEntData(client, ammoOffset+(68), 0);
			}
		}
	}
}

SetClientWeaponInfo_l4d2(client, ammo, clip)
{ 
	new slot=0;
	new ent=GetPlayerWeaponSlot(client, slot);
	if (ent>0)
	{
		new String:weapon[32];  
		new ammoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
		GetEdictClassname(ent, weapon, 32);
		new bool:set=true;

		SetEntProp(ent, Prop_Send, "m_iClip1", clip); 
		if (StrEqual(weapon, "weapon_rifle") || StrEqual(weapon, "weapon_rifle_sg552") || StrEqual(weapon, "weapon_rifle_desert") || StrEqual(weapon, "weapon_rifle_ak47"))
		{
			if(set)SetEntData(client, ammoOffset+(12), ammo);
		}
		else if (StrEqual(weapon, "weapon_smg") || StrEqual(weapon, "weapon_smg_silenced") || StrEqual(weapon, "weapon_smg_mp5"))
		{
			if(set)SetEntData(client, ammoOffset+(20), ammo);
		}
		else if (StrEqual(weapon, "weapon_pumpshotgun") || StrEqual(weapon, "weapon_shotgun_chrome"))
		{
			if(set)SetEntData(client, ammoOffset+(28), ammo);
		}
		else if (StrEqual(weapon, "weapon_autoshotgun") || StrEqual(weapon, "weapon_shotgun_spas"))
		{
			if(set)SetEntData(client, ammoOffset+(32), ammo);
		}
		else if (StrEqual(weapon, "weapon_hunting_rifle"))
		{
			if(set)SetEntData(client, ammoOffset+(36), ammo);
		}
		else if (StrEqual(weapon, "weapon_sniper_scout") || StrEqual(weapon, "weapon_sniper_military") || StrEqual(weapon, "weapon_sniper_awp"))
		{
			if(set)SetEntData(client, ammoOffset+(40), ammo);
		}
		else if (StrEqual(weapon, "weapon_grenade_launcher"))
		{
			if(set)SetEntData(client, ammoOffset+(68), ammo);
		}
	} 
}

GetClientWeaponInfo_l4d1(client, &ammo, &clip)
{
	new slot=0;
	if (GetPlayerWeaponSlot(client, slot) > 0)
	{
		new String:weapon[32]; 
 
		new ammoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
		GetEdictClassname(GetPlayerWeaponSlot(client, slot), weapon, 32);
 
		if (slot == 0)
		{
			clip = GetEntProp(GetPlayerWeaponSlot(client, 0), Prop_Send, "m_iClip1");
 
			if (StrEqual(weapon, "weapon_pumpshotgun") || StrEqual(weapon, "weapon_autoshotgun"))
			{
				ammo = GetEntData(client, ammoOffset+(24)); 
			}
			else if (StrEqual(weapon, "weapon_smg"))
			{
				ammo = GetEntData(client, ammoOffset+(20)); 
			}
			else if (StrEqual(weapon, "weapon_rifle"))
			{
				ammo = GetEntData(client, ammoOffset+(12)); 
			}
			else if (StrEqual(weapon, "weapon_hunting_rifle"))
			{
				ammo = GetEntData(client, ammoOffset+(8)); 
			} 
		}
	}
}

SetClientWeaponInfo_l4d1(client, ammo, clip)
{ 	
	new slot=0;
	if (GetPlayerWeaponSlot(client, slot) > 0)
	{
		new String:weapon[32];  	
		new ammoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");	
		GetEdictClassname(slot, weapon, 32);

		SetEntProp(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_iClip1", clip); 
 
		if (StrEqual(weapon, "weapon_pumpshotgun") || StrEqual(weapon, "weapon_autoshotgun"))
		{ 
			SetEntData(client, ammoOffset+(24), ammo);
		}
		else if (StrEqual(weapon, "weapon_smg"))
		{
			SetEntData(client, ammoOffset+(20), ammo);
		}
		else if (StrEqual(weapon, "weapon_rifle"))
		{
			SetEntData(client, ammoOffset+(12), ammo);
		}
		else if (StrEqual(weapon, "weapon_hunting_rifle"))
		{
			SetEntData(client, ammoOffset+(8), ammo);
		} 
	} 
}
