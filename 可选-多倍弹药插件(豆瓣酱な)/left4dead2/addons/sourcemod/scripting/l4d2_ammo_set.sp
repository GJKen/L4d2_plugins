#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

bool ammo_g_Switch_true = true;
bool l4d2_Theammoset;
bool l4d2_Rloadammoset;
bool l4d2_hActive;

ConVar ammo_set_Switch, l4d2_ammo_set, AssaultAmmoCVAR, AutoShotgunAmmoCVAR, GrenadeLauncherAmmoCVAR, ShotgunAmmoCVAR, HRAmmoCVAR, SMGAmmoCVAR, SniperRifleAmmoCVAR;

int G_l4d2_ammo, G_l4d2_ammo_set ,G_AssaultAmmo, G_AutoShotgunAmmo, G_GrenadeLauncherAmmo, G_ShotgunAmmo, G_HRAmmo, G_SMGAmmo, G_SniperRifleAmmo;

public void OnPluginStart()
{
	RegConsoleCmd("sm_onammo", l4d2_Onammosets, "管理员开启更多或无限后备弹药.");
	RegConsoleCmd("sm_offammo", l4d2_Offammosets, "管理员关闭更多或无限后备弹药.");

	l4d2_ammo_set			= CreateConVar("l4d2_ammo_set_enabled_ammo_Ammosets", "1", "启用更多后备弹药? 0=禁用(关闭游戏后重开游戏恢复默认,禁用后指令开关也不可用), 1=启用.", FCVAR_NOTIFY);
	ammo_set_Switch			= CreateConVar("l4d2_ammo_set_enabled_ammo_Ammosets_switch", "1", "设置默认关闭或开启更多或开启无限后备弹药? (指令 !offammo 关闭更多, !onammo 开启更多或无限) 0=关闭, 1=更多, 2=无限.", FCVAR_NOTIFY);
	AssaultAmmoCVAR			= CreateConVar("l4d2_ammo_set_enabled_ammo_assaultammo", "720", "设置步枪的备用子弹(最大999,游戏默认弹药量为:360)(设为:-2等于无限后备弹药,需要换弹夹).", FCVAR_NOTIFY);
	AutoShotgunAmmoCVAR		= CreateConVar("l4d2_ammo_set_enabled_ammo_autoshotgunammo", "180", "设置连喷的备用弹药量(最大999,游戏默认弹药量为:90)(设为:-2等于无限后备弹药,需要换弹夹).", FCVAR_NOTIFY);
	GrenadeLauncherAmmoCVAR	= CreateConVar("l4d2_ammo_set_enabled_ammo_grenadelauncherammo", "60", "设置榴弹备用弹药量(最大999,游戏默认弹药量为:30)(设为:-2等于无限后备弹药,需要换弹夹).", FCVAR_NOTIFY);
	ShotgunAmmoCVAR			= CreateConVar("l4d2_ammo_set_enabled_ammo_hotgunammo", "144", "设置单喷的备用弹药量(最大999,游戏默认弹药量为:72)(设为:-2等于无限后备弹药,需要换弹夹).", FCVAR_NOTIFY);
	HRAmmoCVAR				= CreateConVar("l4d2_ammo_set_enabled_ammo_huntingrifleammo", "300", "设置猎枪的备用弹药量(最大999,游戏默认弹药量为:150)(设为:-2等于无限后备弹药,需要换弹夹).", FCVAR_NOTIFY);
	SMGAmmoCVAR				= CreateConVar("l4d2_ammo_set_enabled_ammo_smgammo", "999", "设置冲锋枪的备用弹药量(最大999,游戏默认弹药量为:650)(设为:-2等于无限后备弹药,需要换弹夹).", FCVAR_NOTIFY);
	SniperRifleAmmoCVAR		= CreateConVar("l4d2_ammo_set_enabled_ammo_sniperrifleammo", "360", "设置狙击枪的备用弹药量(最大999,游戏默认弹药量为:180)(设为:-2等于无限后备弹药,需要换弹夹).", FCVAR_NOTIFY);
	
	HookEvent("round_start", Event_RoundStart_ammo);//回合开始.
	
	l4d2_ammo_set.AddChangeHook(CVARChanged);
	ammo_set_Switch.AddChangeHook(CVARChanged);
	AssaultAmmoCVAR.AddChangeHook(CVARChanged);
	AutoShotgunAmmoCVAR.AddChangeHook(CVARChanged);
	GrenadeLauncherAmmoCVAR.AddChangeHook(CVARChanged);
	ShotgunAmmoCVAR.AddChangeHook(CVARChanged);
	HRAmmoCVAR.AddChangeHook(CVARChanged);
	SMGAmmoCVAR.AddChangeHook(CVARChanged);
	SniperRifleAmmoCVAR.AddChangeHook(CVARChanged);
	
	AutoExecConfig(true, "l4d2_ammo_set");//生成指定文件名的CFG.
}

public void OnMapStart()
{
	l4d2_ammosetGetCvars();
}

public void OnConfigsExecuted()
{
	if(ammo_g_Switch_true)
	{
		switch(G_l4d2_ammo_set)
		{
			case 0:
			{
				l4d2_hActive = false;
				l4d2_Theammoset = true;
				l4d2_Rloadammoset = false;
			}
			case 1:
			{
				l4d2_Theammoset = true;
				l4d2_Rloadammoset = true;
			}
			case 2:
			{
				l4d2_Theammoset = false;
				l4d2_Rloadammoset = true;
			}
		}
	}
	l4d2_ammosetStartDelays();
}

public void CVARChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	l4d2_ammosetGetCvars();
}

void l4d2_ammosetGetCvars()
{
	G_l4d2_ammo = l4d2_ammo_set.IntValue;
	G_l4d2_ammo_set = ammo_set_Switch.IntValue;
	G_AssaultAmmo = AssaultAmmoCVAR.IntValue;
	G_AutoShotgunAmmo = AutoShotgunAmmoCVAR.IntValue;
	G_GrenadeLauncherAmmo = GrenadeLauncherAmmoCVAR.IntValue;
	G_ShotgunAmmo = ShotgunAmmoCVAR.IntValue;
	G_HRAmmo = HRAmmoCVAR.IntValue;
	G_SMGAmmo = SMGAmmoCVAR.IntValue;
	G_SniperRifleAmmo = SniperRifleAmmoCVAR.IntValue;
}

public void Event_RoundStart_ammo(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(15.0, ammosetStartDelays, _, TIMER_FLAG_NO_MAPCHANGE);//后备弹药.
}

public Action ammosetStartDelays(Handle timer)
{
	l4d2_ammosetStartDelays_prompt();
	return Plugin_Continue;
}

public Action l4d2_Offammosets(int client, int args)
{
	if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
	{
		switch(G_l4d2_ammo)
		{
			case 0:
			{
				PrintToChat(client, "\x04[提示]\x05更多后备弹药已禁用,请在CFG中设为1启用.");
			}
			case 1,2:
			{
				if (l4d2_Rloadammoset)
				{
					l4d2_Theammoset = false;
					l4d2_Rloadammoset = false;
					ammo_g_Switch_true = false;
				}
				else
				{
					l4d2_Theammoset = false;
					l4d2_Rloadammoset = false;
					ammo_g_Switch_true = false;
				}
				l4d2_hActive = false;
				l4d2_ammosetStartDelays();
				l4d2_ammosetStartDelays_prompt();
			}
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

public Action l4d2_Onammosets(int client, int args)
{
	if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
	{
		switch(G_l4d2_ammo)
		{
			case 0:
			{
				PrintToChat(client, "\x04[提示]\x05更多后备弹药已禁用,请在CFG中设为1启用.");
			}
			case 1,2:
			{
				if (l4d2_Rloadammoset)
				{
					if (l4d2_Theammoset)
					{
						l4d2_Theammoset = false;
						l4d2_Rloadammoset = true;
						ammo_g_Switch_true = false;
					}
					else
					{
						l4d2_Theammoset = true;
						l4d2_Rloadammoset = true;
						ammo_g_Switch_true = false;
						
						if (!l4d2_hActive)
							l4d2_ammosetStartDelays_hActive();
					}
				}
				else
				{
					if (l4d2_Theammoset)
					{
						l4d2_Theammoset = false;
						l4d2_Rloadammoset = true;
						ammo_g_Switch_true = false;
					}
					else
					{
						l4d2_Theammoset = true;
						l4d2_Rloadammoset = true;
						ammo_g_Switch_true = false;
						
						if (!l4d2_hActive)
						{
							l4d2_ammosetStartDelays_hActive();
						}
					}
				}
				l4d2_hActive = true;
				l4d2_ammosetStartDelays();
				l4d2_ammosetStartDelays_prompt();
			}
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

void l4d2_ammosetStartDelays_hActive()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			//int weapon = GetEntPropEnt(i, Prop_Data, "m_hActiveWeapon");
			int weapon = GetPlayerWeaponSlot(i, 0);
			
			if(weapon != -1)
			{
				int Clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
				int PrimType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
				int Ammo = GetEntProp(i, Prop_Send, "m_iAmmo", _, PrimType);
				
				//步枪.
				switch(PrimType)
				{
					case 3:
					{
						int Ammo2;
						if(Ammo < G_AssaultAmmo)
						{
							Ammo2 = G_AssaultAmmo - 360 + Ammo;
							if(Ammo2 >= G_AssaultAmmo)
								Ammo2 = G_AssaultAmmo;
							SetEntProp(weapon, Prop_Send, "m_iClip1", Clip);
							SetEntProp(i, Prop_Send, "m_iAmmo",  Ammo2, _, PrimType);
						}
					}
					//冲锋枪
					case 5:
					{
						int Ammo2;
						if(Ammo < G_SMGAmmo)
						{
							Ammo2 = G_SMGAmmo - 650 + Ammo;
							if(Ammo2 >= G_SMGAmmo)
								Ammo2 = G_SMGAmmo;
							SetEntProp(weapon, Prop_Send, "m_iClip1", Clip);
							SetEntProp(i, Prop_Send, "m_iAmmo",  Ammo2, _, PrimType);
						}
					}
					//单喷
					case 7:
					{
						int Ammo2;
						if(Ammo < G_ShotgunAmmo)
						{
							Ammo2 = G_ShotgunAmmo - 72 + Ammo;
							if(Ammo2 >= G_ShotgunAmmo)
								Ammo2 = G_ShotgunAmmo;
							SetEntProp(weapon, Prop_Send, "m_iClip1", Clip);
							SetEntProp(i, Prop_Send, "m_iAmmo",  Ammo2, _, PrimType);
						}
					}
					//连喷
					case 8:
					{
						int Ammo2;
						if(Ammo < G_AutoShotgunAmmo)
						{
							Ammo2 = G_AutoShotgunAmmo - 90 + Ammo;
							if(Ammo2 >= G_AutoShotgunAmmo)
								Ammo2 = G_AutoShotgunAmmo;
							SetEntProp(weapon, Prop_Send, "m_iClip1", Clip);
							SetEntProp(i, Prop_Send, "m_iAmmo",  Ammo2, _, PrimType);
						}
					}
					//猎枪
					case 9:
					{
						int Ammo2;
						if(Ammo < G_HRAmmo)
						{
							Ammo2 = G_HRAmmo - 150 + Ammo;
							if(Ammo2 >= G_HRAmmo)
								Ammo2 = G_HRAmmo;
							SetEntProp(weapon, Prop_Send, "m_iClip1", Clip);
							SetEntProp(i, Prop_Send, "m_iAmmo",  Ammo2, _, PrimType);
						}
					}
					//狙击枪
					case 10:
					{
						int Ammo2;
						if(Ammo < G_SniperRifleAmmo)
						{
							Ammo2 = G_SniperRifleAmmo - 180 + Ammo;
							if(Ammo2 >= G_SniperRifleAmmo)
								Ammo2 = G_SniperRifleAmmo;
							SetEntProp(weapon, Prop_Send, "m_iClip1", Clip);
							SetEntProp(i, Prop_Send, "m_iAmmo",  Ammo2, _, PrimType);
						}
					}
					//榴弹发射器
					case 17:
					{
						int Ammo2;
						if(Ammo < G_GrenadeLauncherAmmo)
						{
							Ammo2 = G_GrenadeLauncherAmmo - 30 + Ammo;
							if(Ammo2 >= G_GrenadeLauncherAmmo)
								Ammo2 = G_GrenadeLauncherAmmo;
							SetEntProp(weapon, Prop_Send, "m_iClip1", Clip);
							SetEntProp(i, Prop_Send, "m_iAmmo",  Ammo2, _, PrimType);
						}
					}
				}
			}
		}
	}
}

bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}

int iGetClientImmunityLevel(int client)
{
	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, sSteamID);
	if(admin == INVALID_ADMIN_ID)
		return -999;

	return admin.ImmunityLevel;
}

void l4d2_ammosetStartDelays()
{
	if (l4d2_Rloadammoset)
	{
		if (l4d2_Theammoset)
		{
			SetConVarInt(FindConVar("ammo_assaultrifle_max"), G_AssaultAmmo, false, false);//获取步枪的最大后备弹药量
			SetConVarInt(FindConVar("ammo_autoshotgun_max"), G_AutoShotgunAmmo, false, false);//获取连喷的最大后备弹药量
			SetConVarInt(FindConVar("ammo_grenadelauncher_max"), G_GrenadeLauncherAmmo, false, false);//获取榴弹的最大后备弹药量
			SetConVarInt(FindConVar("ammo_shotgun_max"), G_ShotgunAmmo, false, false);//获取单喷的最大后备弹药量
			SetConVarInt(FindConVar("ammo_huntingrifle_max"), G_HRAmmo, false, false);//获取猎枪的最大后备弹药量
			SetConVarInt(FindConVar("ammo_smg_max"), G_SMGAmmo, false, false);//获取冲锋枪的最大后备弹药量
			SetConVarInt(FindConVar("ammo_sniperrifle_max"), G_SniperRifleAmmo, false, false);//获取狙击枪的最大后备弹药量
		}
		else
		{
			SetConVarInt(FindConVar("ammo_assaultrifle_max"), -2, false, false);
			SetConVarInt(FindConVar("ammo_autoshotgun_max"), -2, false, false);
			SetConVarInt(FindConVar("ammo_grenadelauncher_max"), -2, false, false);
			SetConVarInt(FindConVar("ammo_shotgun_max"), -2, false, false);
			SetConVarInt(FindConVar("ammo_huntingrifle_max"), -2, false, false);
			SetConVarInt(FindConVar("ammo_smg_max"), -2, false, false);
			SetConVarInt(FindConVar("ammo_sniperrifle_max"), -2, false, false);
		}
	}
	else
	{
		SetConVarInt(FindConVar("ammo_assaultrifle_max"), 360, false, false);
		SetConVarInt(FindConVar("ammo_autoshotgun_max"), 90, false, false);
		SetConVarInt(FindConVar("ammo_grenadelauncher_max"), 30, false, false);
		SetConVarInt(FindConVar("ammo_shotgun_max"), 72, false, false);
		SetConVarInt(FindConVar("ammo_huntingrifle_max"), 150, false, false);
		SetConVarInt(FindConVar("ammo_smg_max"), 650, false, false);
		SetConVarInt(FindConVar("ammo_sniperrifle_max"), 180, false, false);
	}
}

void l4d2_ammosetStartDelays_prompt()
{
	if (l4d2_Rloadammoset)
	{
		if (l4d2_Theammoset)
		{
			PrintToChatAll("\x04[提示]\x05已开启\x03更多\x05后备弹药.");
		}
		else
		{
			PrintToChatAll("\x04[提示]\x05已开启\x03无限\x05后备弹药.");
		}
	}
	else
	{
		PrintToChatAll("\x04[提示]\x05已关闭\x03更多\x05后备弹药.");
	}
}
