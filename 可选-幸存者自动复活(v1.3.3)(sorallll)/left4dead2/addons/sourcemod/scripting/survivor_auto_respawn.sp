#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <Defib_Fix>

#define GAMEDATA	"survivor_auto_respawn"
#define CVAR_FLAGS	FCVAR_NOTIFY
#define MAX_SLOTS	5

Handle
	g_hSDKRoundRespawn,
	g_hSDKGoAwayFromKeyboard;

ArrayList
	g_aMeleeScripts;


Address
	g_pStatsCondition;

ConVar
	g_hRespawnTime,
	g_hRespawnAdd,
	g_hRespawnMax,
	g_hRespawnLimit,
	g_hAllowSurvivorBot,
	g_hAllowSurvivorIdle,
	g_hAllowSurvivorDaze,
	g_hGiveWeaponType,
	g_hRemoveDeathDrop,
	g_hSbAllBotGame,
	g_hAllowAllBotSur;

bool
	g_bGiveWeaponType,
	g_bRemoveDeathDrop,
	g_bAllowSurvivorBot,
	g_bAllowSurvivorIdle;

float
	LastEyeAngles [MAXPLAYERS+1][3], 
	CurrEyeAngles [MAXPLAYERS+1][3];

int
	g_iRespawnTime,
	g_iRespawnAdd,
	g_iRespawnMax,
	g_iRespawnLimit,
	g_iAllowSurvivorDaze;

enum struct esWeapon
{
	ConVar cFlags;

	int iCount;
	int iAllowed[20];
}

esWeapon
	g_esWeapon[MAX_SLOTS];

enum struct esPlayer
{
	Handle hTimer;
	Handle hSurvivorNothing;

	bool bPlayerButtons;

	int iDynamic;
	int iRespawned;
	int iCountdown;
	int iDeathModel;
	int iSurvivorNothing;
}

esPlayer
	g_esPlayer[MAXPLAYERS + 1];

static const char
	g_sWeaponName[5][17][] =
	{
		{//slot 0(主武器)
			"smg",						//1 UZI微冲
			"smg_mp5",					//2 MP5
			"smg_silenced",				//4 MAC微冲
			"pumpshotgun",				//8 木喷
			"shotgun_chrome",			//16 铁喷
			"rifle",					//32 M16步枪
			"rifle_desert",				//64 三连步枪
			"rifle_ak47",				//128 AK47
			"rifle_sg552",				//256 SG552
			"autoshotgun",				//512 一代连喷
			"shotgun_spas",				//1024 二代连喷
			"hunting_rifle",			//2048 木狙
			"sniper_military",			//4096 军狙
			"sniper_scout",				//8192 鸟狙
			"sniper_awp",				//16384 AWP
			"rifle_m60",				//32768 M60
			"grenade_launcher"			//65536 榴弹发射器
		},
		{//slot 1(副武器)
			"pistol",					//1 小手枪
			"pistol_magnum",			//2 马格南
			"chainsaw",					//4 电锯
			"fireaxe",					//8 斧头
			"frying_pan",				//16 平底锅
			"machete",					//32 砍刀
			"baseball_bat",				//64 棒球棒
			"crowbar",					//128 撬棍
			"cricket_bat",				//256 球拍
			"tonfa",					//512 警棍
			"katana",					//1024 武士刀
			"electric_guitar",			//2048 电吉他
			"knife",					//4096 小刀
			"golfclub",					//8192 高尔夫球棍
			"shovel",					//16384 铁铲
			"pitchfork",				//32768 草叉
			"riotshield",				//65536 盾牌
		},
		{//slot 2(投掷物)
			"molotov",					//1 燃烧瓶
			"pipe_bomb",				//2 管制炸弹
			"vomitjar",					//4 胆汁瓶
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			""
		},
		{//slot 3
			"first_aid_kit",			//1 医疗包
			"defibrillator",			//2 电击器
			"upgradepack_incendiary",	//4 燃烧弹药包
			"upgradepack_explosive",	//8 高爆弹药包
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			""
		},
		{//slot 4
			"pain_pills",				//1 止痛药
			"adrenaline",				//2 肾上腺素
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			""
		}
	},
	g_sWeaponModels[][] =
	{
		"models/w_models/weapons/w_smg_uzi.mdl",
		"models/w_models/weapons/w_smg_mp5.mdl",
		"models/w_models/weapons/w_smg_a.mdl",
		"models/w_models/weapons/w_pumpshotgun_A.mdl",
		"models/w_models/weapons/w_shotgun.mdl",
		"models/w_models/weapons/w_rifle_m16a2.mdl",
		"models/w_models/weapons/w_desert_rifle.mdl",
		"models/w_models/weapons/w_rifle_ak47.mdl",
		"models/w_models/weapons/w_rifle_sg552.mdl",
		"models/w_models/weapons/w_autoshot_m4super.mdl",
		"models/w_models/weapons/w_shotgun_spas.mdl",
		"models/w_models/weapons/w_sniper_mini14.mdl",
		"models/w_models/weapons/w_sniper_military.mdl",
		"models/w_models/weapons/w_sniper_scout.mdl",
		"models/w_models/weapons/w_sniper_awp.mdl",
		"models/w_models/weapons/w_m60.mdl",
		"models/w_models/weapons/w_grenade_launcher.mdl",
	
		"models/w_models/weapons/w_pistol_a.mdl",
		"models/w_models/weapons/w_desert_eagle.mdl",
		"models/weapons/melee/w_chainsaw.mdl",
		"models/weapons/melee/v_fireaxe.mdl",
		"models/weapons/melee/w_fireaxe.mdl",
		"models/weapons/melee/v_frying_pan.mdl",
		"models/weapons/melee/w_frying_pan.mdl",
		"models/weapons/melee/v_machete.mdl",
		"models/weapons/melee/w_machete.mdl",
		"models/weapons/melee/v_bat.mdl",
		"models/weapons/melee/w_bat.mdl",
		"models/weapons/melee/v_crowbar.mdl",
		"models/weapons/melee/w_crowbar.mdl",
		"models/weapons/melee/v_cricket_bat.mdl",
		"models/weapons/melee/w_cricket_bat.mdl",
		"models/weapons/melee/v_tonfa.mdl",
		"models/weapons/melee/w_tonfa.mdl",
		"models/weapons/melee/v_katana.mdl",
		"models/weapons/melee/w_katana.mdl",
		"models/weapons/melee/v_electric_guitar.mdl",
		"models/weapons/melee/w_electric_guitar.mdl",
		"models/v_models/v_knife_t.mdl",
		"models/w_models/weapons/w_knife_t.mdl",
		"models/weapons/melee/v_golfclub.mdl",
		"models/weapons/melee/w_golfclub.mdl",
		"models/weapons/melee/v_shovel.mdl",
		"models/weapons/melee/w_shovel.mdl",
		"models/weapons/melee/v_pitchfork.mdl",
		"models/weapons/melee/w_pitchfork.mdl",
		"models/weapons/melee/v_riotshield.mdl",
		"models/weapons/melee/w_riotshield.mdl",

		"models/w_models/weapons/w_eq_molotov.mdl",
		"models/w_models/weapons/w_eq_pipebomb.mdl",
		"models/w_models/weapons/w_eq_bile_flask.mdl",

		"models/w_models/weapons/w_eq_medkit.mdl",
		"models/w_models/weapons/w_eq_defibrillator.mdl",
		"models/w_models/weapons/w_eq_incendiary_ammopack.mdl",
		"models/w_models/weapons/w_eq_explosive_ammopack.mdl",

		"models/w_models/weapons/w_eq_adrenaline.mdl",
		"models/w_models/weapons/w_eq_painpills.mdl"
	};

public Plugin myinfo = 
{
	name = "Survivor Auto Respawn",
	author = "sorallll",
	description = "",
	version = "1.3.3",
	url = "https://steamcommunity.com/id/sorallll"
}

public void OnPluginStart()
{
	vLoadGameData();

	g_aMeleeScripts = new ArrayList(64);

	
	g_hRespawnTime 			= 	CreateConVar("sar_respawn_survivor_time",		"90", 	"玩家自动复活的默认时间(秒).", CVAR_FLAGS);
	g_hRespawnAdd 			= 	CreateConVar("sar_respawn_survivor_time_add",	"10", 	"玩家每次死亡增加多少复活时间(秒).", CVAR_FLAGS);
	g_hRespawnMax 			= 	CreateConVar("sar_respawn_survivor_time_max",	"144", 	"玩家自动复活的最大时间(秒).", CVAR_FLAGS);

	g_hRespawnLimit 		= 	CreateConVar("sar_respawn_survivor_limit",		"2", 	"玩家每回合自动复活次数.", CVAR_FLAGS);
	g_hAllowSurvivorBot		= 	CreateConVar("sar_respawn_survivor_bot",		"1", 	"启用电脑幸存者自动复活? 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hAllowSurvivorIdle	= 	CreateConVar("sar_respawn_survivor_idle",		"1", 	"启用闲置幸存者自动复活? 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hAllowSurvivorDaze	= 	CreateConVar("sar_respawn_survivor_daze",		"5",	"复活后几秒无操作自动闲置. 0=禁用.", CVAR_FLAGS);


	g_esWeapon[0].cFlags	=	CreateConVar("sar_respawn_slot0", 	"0", 		"主武器给什么 \n0=不给,131071=所有,7=微冲,1560=霰弹,30720=狙击,31=Tier1,32736=Tier2,98304=Tier0.");
	g_esWeapon[1].cFlags	=	CreateConVar("sar_respawn_slot1", 	"0", 		"副武器给什么 \n0=不给,131071=所有.如果选中了近战且该近战在当前地图上未解锁,则会随机给一把.");
	g_esWeapon[2].cFlags	=	CreateConVar("sar_respawn_slot2", 	"0", 		"投掷物给什么 \n0=不给,7=所有.", CVAR_FLAGS);
	g_esWeapon[3].cFlags	=	CreateConVar("sar_respawn_slot3", 	"0", 		"槽位3给什么 \n0=不给,15=所有.", CVAR_FLAGS);
	g_esWeapon[4].cFlags	= 	CreateConVar("sar_respawn_slot4", 	"0", 		"槽位4给什么 \n0=不给,3=所有.", CVAR_FLAGS);
	g_hGiveWeaponType		= 	CreateConVar("sar_give_type", 		"0", 		"根据什么来给玩家装备. \n0=不给,1=根据每个槽位的设置,2=根据当前所有生还者的平均装备质量(仅主副武器).");
	g_hRemoveDeathDrop		= 	CreateConVar("sar_remove_drop", 	"0", 		"玩家死亡移除掉落的武器(建议启用). 0=禁用, 1=启用.", CVAR_FLAGS);

	g_hSbAllBotGame = FindConVar("sb_all_bot_game");
	g_hAllowAllBotSur = FindConVar("allow_all_bot_survivor_team");

	g_hRespawnTime.AddChangeHook(vConVarChanged);
	g_hRespawnAdd.AddChangeHook(vConVarChanged);
	g_hRespawnMax.AddChangeHook(vConVarChanged);
	g_hRespawnLimit.AddChangeHook(vConVarChanged);
	g_hAllowSurvivorBot.AddChangeHook(vConVarChanged);
	g_hAllowSurvivorIdle.AddChangeHook(vConVarChanged);
	g_hAllowSurvivorDaze.AddChangeHook(vConVarChanged);

	for(int i; i < MAX_SLOTS; i++)
		g_esWeapon[i].cFlags.AddChangeHook(vWeaponConVarChanged);
	g_hRemoveDeathDrop.AddChangeHook(vWeaponConVarChanged);
		
	AutoExecConfig(true, "survivor_auto_respawn");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_bot_replace", Event_PlayerBotReplace, EventHookMode_Pre);
}

public void OnPluginEnd()
{
	vStatsConditionPatch(false);
}

public void OnConfigsExecuted()
{
	vGetCvars();
	vGetWeaponCvars();
}

void vConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetCvars();
}

void vWeaponConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetWeaponCvars();
}

void vGetCvars()
{
	g_iRespawnTime = g_hRespawnTime.IntValue;
	g_iRespawnAdd = g_hRespawnAdd.IntValue;
	g_iRespawnMax = g_hRespawnMax.IntValue;
	g_iRespawnLimit = g_hRespawnLimit.IntValue;
	g_bRemoveDeathDrop = g_hRemoveDeathDrop.BoolValue;
	g_bAllowSurvivorBot = g_hAllowSurvivorBot.BoolValue;
	g_bAllowSurvivorIdle = g_hAllowSurvivorIdle.BoolValue;
	g_iAllowSurvivorDaze = g_hAllowSurvivorDaze.IntValue;
}

void vGetWeaponCvars()
{
	int iNullSlot;
	for(int i; i < MAX_SLOTS; i++)
	{
		g_esWeapon[i].iCount = 0;
		if(!g_esWeapon[i].cFlags.BoolValue || !iGetSlotAllowed(i))
			iNullSlot++;
	}

	g_bGiveWeaponType = iNullSlot < MAX_SLOTS ? g_hGiveWeaponType.BoolValue : false;
}

int iGetSlotAllowed(int iSlot)
{
	for(int i; i < 17; i++)
	{
		if(g_sWeaponName[iSlot][i][0] == '\0')
			break;

		if((1 << i) & g_esWeapon[iSlot].cFlags.IntValue)
			g_esWeapon[iSlot].iAllowed[g_esWeapon[iSlot].iCount++] = i;
	}
	return g_esWeapon[iSlot].iCount;
}

public void L4D2_OnSurvivorDeathModelCreated(int iClient, int iDeathModel)
{
	g_esPlayer[iClient].iDeathModel = EntIndexToEntRef(iDeathModel);
}

public void OnClientPutInServer(int client)
{
	g_esPlayer[client].iRespawned = 0;
	g_esPlayer[client].iDynamic = g_iRespawnTime;
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDropPost);
}

public void OnWeaponDropPost(int client, int weapon)
{
	if(!g_bRemoveDeathDrop)
		return;

	if(GetClientTeam(client) != 2 || GetClientHealth(client) > 0)
		return;

	if(weapon <= MaxClients || !IsValidEntity(weapon) || HasEntProp(weapon, Prop_Send, "m_isCarryable"))
		return;

	RemoveEntity(weapon);
}

public void OnClientDisconnect(int client)
{
	delete g_esPlayer[client].hTimer;
	vRemoveSurvivorDeathModel(client);
}

public void OnMapEnd()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_esPlayer[i].iRespawned = 0;
		g_esPlayer[i].iDynamic = g_iRespawnTime;
		delete g_esPlayer[i].hTimer;
	}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
		delete g_esPlayer[i].hTimer;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRespawnTime == 0 || g_iRespawnLimit == 0)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client))
		return;

	if(IsPlayerAlive(client))
	{
		vRemoveSurvivorDeathModel(client);
		return;
	}

	if(g_esPlayer[client].hTimer != null || GetClientTeam(client) != 2 || (!g_bAllowSurvivorBot && IsFakeClient(client)))
		return;

	if(bCalculateRespawnLimit(client))
	{
		delete g_esPlayer[client].hTimer;
		g_esPlayer[client].hTimer = CreateTimer(1.0, tmrRespawnSurvivor, GetClientUserId(client), TIMER_REPEAT);
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRespawnTime == 0 || g_iRespawnLimit == 0)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if(IsFakeClient(client))
	{
		int iIdlePlayer = iGetIdlePlayerOfBot(client);
		if(!iIdlePlayer)
		{
			if(!g_bAllowSurvivorBot)
				return;
		}
		else
		{
			if(!g_bAllowSurvivorIdle)
				return;
			else
				client = iIdlePlayer;
		}
	}

	if(bCalculateRespawnLimit(client))
	{
		delete g_esPlayer[client].hTimer;
		g_esPlayer[client].hTimer = CreateTimer(1.0, tmrRespawnSurvivor, GetClientUserId(client), TIMER_REPEAT);
	}
}

static int iGetIdlePlayerOfBot(int client)
{
	static char sNetClass[64];
	GetEntityNetClass(client, sNetClass, sizeof sNetClass);
	if(FindSendPropInfo(sNetClass, "m_humanSpectatorUserID") < 1)
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast)
{
	if(g_iRespawnTime == 0 || g_iRespawnLimit == 0 || !g_bAllowSurvivorBot)
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	if(!IsFakeClient(bot) || IsPlayerAlive(bot))
		return;

	if(bCalculateRespawnLimit(bot))
	{
		delete g_esPlayer[bot].hTimer;
		g_esPlayer[bot].hTimer = CreateTimer(1.0, tmrRespawnSurvivor, GetClientUserId(bot), TIMER_REPEAT);
	}
}

bool bCalculateRespawnLimit(int client)
{
	if(g_esPlayer[client].iRespawned >= g_iRespawnLimit)
	{
		if(!IsFakeClient(client))
			PrintHintText(client, "杂鱼,不能复活了,我会想念你的TwT");

		return false;
	}

	g_esPlayer[client].iCountdown = g_esPlayer[client].iDynamic;
	return true;
}

Action tmrRespawnSurvivor(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) == 0)
		return Plugin_Stop;

	if(IsClientInGame(client) && GetClientTeam(client) == 2 && !IsPlayerAlive(client))
	{
		if(g_esPlayer[client].iCountdown > 0)
		{
			if(!IsFakeClient(client))
				PrintCenterText(client, "杂鱼~死了吧,不过你会在%d秒后复活,放心吧!(还剩%d次)", g_esPlayer[client].iCountdown, g_iRespawnLimit - g_esPlayer[client].iRespawned);

			g_esPlayer[client].iCountdown--;
		}
		else
		{
			vRespawnSurvivor(client);
			g_esPlayer[client].hTimer = null;
			return Plugin_Stop;
		}

		return Plugin_Continue;
	}

	g_esPlayer[client].hTimer = null;
	return Plugin_Stop;	
}

void vRespawnSurvivor(int client)
{
	vRoundRespawn(client);
	vGiveWeapon(client);
	vTeleportToSurvivor(client);
	//vRemoveSurvivorDeathModel(client);
	g_esPlayer[client].iRespawned += 1;

	if(!IsFakeClient(client))
	{
		if(bCanIdle(client))
			SurvivorDoesNothing(client);

		g_esPlayer[client].iDynamic += g_iRespawnAdd;

		if(g_esPlayer[client].iDynamic > g_iRespawnMax)
			g_esPlayer[client].iDynamic = g_iRespawnMax;

		CreateTimer(1.0, DelayDisplayPrompt, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action DelayDisplayPrompt(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) == 0)
		return Plugin_Continue;

	if(IsClientInGame(client) && !IsFakeClient(client))
		PrintHintText(client, "你个杂鱼还剩%d次复活,多注意点,哼~下一次复活时间:%d秒.", g_iRespawnLimit - g_esPlayer[client].iRespawned, g_esPlayer[client].iDynamic);
	return Plugin_Continue;
}

bool bCanIdle(int client)
{
	if(g_hSbAllBotGame.BoolValue || g_hAllowAllBotSur.BoolValue)
		return true;

	int iSurvivor;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			iSurvivor++;
	}
	return iSurvivor > 0;
}

void vRemoveSurvivorDeathModel(int client)
{
	if(!bIsValidEntRef(g_esPlayer[client].iDeathModel))
		return;

	RemoveEntity(g_esPlayer[client].iDeathModel);
	g_esPlayer[client].iDeathModel = 0;
}

bool bIsValidEntRef(int entity)
{
	return entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE;
}

void SurvivorDoesNothing(int client)
{
	g_esPlayer[client].iSurvivorNothing = 0;
	delete g_esPlayer[client].hSurvivorNothing;
	g_esPlayer[client].hSurvivorNothing = CreateTimer(1.0, iSurvivorDoesNothing, GetClientUserId(client), TIMER_REPEAT);
}

public Action iSurvivorDoesNothing(Handle timer, any client)
{
	if((client = GetClientOfUserId(client)))
	{
		if (!IsClientInGame(client))
			return Plugin_Continue;
		
		if (GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		{
			g_esPlayer[client].iSurvivorNothing = 0;
			g_esPlayer[client].hSurvivorNothing = null;
			return Plugin_Stop;
		}
		if (GetClientTeam(client) == 2 && !IsFakeClient(client))
		{
			g_esPlayer[client].iSurvivorNothing += 1;
			//PrintToChatAll("\x04[提示]\x03%N\x05的计数+1当前值为%d.", client, g_esPlayer[client].iSurvivorNothing);

			if (!g_esPlayer[client].bPlayerButtons)
			{
				//PrintToChatAll("\x04[提示]\x03%N\x05无按键操作.", client);

				if (GazeMovement(client))
				{
					//PrintToChatAll("\x04[提示]\x03%N\x05无鼠标操作.", client);
				
					if (g_esPlayer[client].iSurvivorNothing < g_iAllowSurvivorDaze)
					{
						//PrintToChatAll("\x04[提示]\x03%N\x05当前值小于:%d(返回并继续).", client, g_iAllowSurvivorDaze);
						return Plugin_Continue;
					}
					else
					{
						//PrintToChatAll("\x04[提示]\x03%N\x05计时结束,执行闲置.", client, g_iAllowSurvivorDaze);
						SDKCall(g_hSDKGoAwayFromKeyboard, client);//玩家复活后自动闲置.
						g_esPlayer[client].iSurvivorNothing = 0;
						g_esPlayer[client].hSurvivorNothing = null;
						return Plugin_Stop;
					}
					
				}
				else
				{
					if (g_iRespawnTime > 1 && g_esPlayer[client].iSurvivorNothing == 1)
					{
						//PrintToChatAll("\x04[提示]\x03%N\x05移动了鼠标,当前值=1(返回并继续).", client);
						return Plugin_Continue;
					}
					g_esPlayer[client].iSurvivorNothing = 0;
					g_esPlayer[client].hSurvivorNothing = null;
					//PrintToChatAll("\x04[提示]\x03%N\x05移动了鼠标,停止计时器.", client);
					return Plugin_Stop;
				}
			}
			else
			{
				g_esPlayer[client].iSurvivorNothing = 0;
				g_esPlayer[client].hSurvivorNothing = null;
				//PrintToChatAll("\x04[提示]\x03%N\x05按下了按键,停止计时器.", client);
				return Plugin_Stop;
			}
		}
	}
	return Plugin_Continue;
}

//只是检测幸存者视线移动.
bool GazeMovement(int client)
{
	GetClientEyeAngles(client, CurrEyeAngles[client]);
	if (LastEyeAngles[client][0] == CurrEyeAngles[client][0] && LastEyeAngles[client][1] == CurrEyeAngles[client][1] && LastEyeAngles[client][2] == CurrEyeAngles[client][2])
	{
		return true;
	}
	else
	{
		LastEyeAngles[client] = CurrEyeAngles[client];
		return false;
	}
}

//检测玩家是不是在发呆或按下某些按键.
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	
	if(buttons & IN_ATTACK || buttons & IN_JUMP || buttons & IN_DUCK 
	|| buttons & IN_USE || buttons & IN_ATTACK2 || buttons & IN_SCORE 
	|| buttons & IN_SPEED || buttons & IN_ZOOM || buttons & IN_RELOAD)
	{
		g_esPlayer[client].bPlayerButtons = true;
		//PrintToChatAll("\x04[提示]\x03%N\x05有操作.", client);
		return Plugin_Continue;
	}
	g_esPlayer[client].bPlayerButtons = false;
	//PrintToChatAll("\x04[提示]\x03%N\x05无操作.", client);
	return Plugin_Continue;
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}
/*
//https://forums.alliedmods.net/showthread.php?t=327928
void vTerror_SetAdrenalineTime(int client, float fDuration)
{
    // Get CountdownTimer address
    static int iTimerAddress = -1;
    if(iTimerAddress == -1)
        iTimerAddress = FindSendPropInfo("CTerrorPlayer", "m_bAdrenalineActive") - 12;
    
    //iTimerAddress + 4 = Duration
    //iTimerAddress + 8 = TimeStamp
    SetEntDataFloat(client, iTimerAddress + 4, fDuration);
    SetEntDataFloat(client, iTimerAddress + 8, GetGameTime() + fDuration);
    SetEntProp(client, Prop_Send, "m_bAdrenalineActive", 1);
} 
*/
void vGiveWeapon(int client)
{
	if(!g_bGiveWeaponType)
		return;

	vRemovePlayerWeapons(client);

	for(int i = 4; i >= 2; i--)
	{
		if(!g_esWeapon[i].iCount)
			continue;

		vCheatCommand(client, "give", g_sWeaponName[i][g_esWeapon[i].iAllowed[GetRandomInt(0, g_esWeapon[i].iCount - 1)]]);
	}

	vGiveSecondary(client);

	switch(g_hGiveWeaponType.IntValue)
	{
		case 1:
			vGivePresetPrimary(client);
		
		case 2:
			vGiveAveragePrimary(client);
	}
}

void vRemovePlayerWeapons(int client)
{
	int iWeapon;
	for(int i; i < MAX_SLOTS; i++)
	{
		if((iWeapon = GetPlayerWeaponSlot(client, i)) > MaxClients)
		{
			RemovePlayerItem(client, iWeapon);
			RemoveEdict(iWeapon);
		}
	}
}

void vGiveSecondary(int client)
{
	if(g_esWeapon[1].iCount)
	{
		int iRandom = g_esWeapon[1].iAllowed[GetRandomInt(0, g_esWeapon[1].iCount - 1)];
		if(iRandom > 2)
			vGiveMelee(client, g_sWeaponName[1][iRandom]);
		else
			vCheatCommand(client, "give", g_sWeaponName[1][iRandom]);
	}
}

void vGivePresetPrimary(int client)
{
	if(g_esWeapon[0].iCount)
		vCheatCommand(client, "give", g_sWeaponName[0][g_esWeapon[0].iAllowed[GetRandomInt(0, g_esWeapon[0].iCount - 1)]]);
}

bool bIsWeaponTier1(int iWeapon)
{
	char sWeapon[32];
	GetEntityClassname(iWeapon, sWeapon, sizeof sWeapon);
	for(int i; i < 5; i++)
	{
		if(strcmp(sWeapon[7], g_sWeaponName[0][i]) == 0)
			return true;
	}
	return false;
}

void vGiveAveragePrimary(int client)
{
	int i = 1, iWeapon, iTier, iTotal;
	for(; i <= MaxClients; i++)
	{
		if(i == client || !IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
			continue;

		iTotal += 1;	
		iWeapon = GetPlayerWeaponSlot(i, 0);
		if(iWeapon <= MaxClients || !IsValidEntity(iWeapon))
			continue;

		iTier += bIsWeaponTier1(iWeapon) ? 1 : 2;
	}

	switch(iTotal > 0 ? RoundToNearest(1.0 * iTier / iTotal) : 0)
	{
		case 1:
			vCheatCommand(client, "give", g_sWeaponName[0][GetRandomInt(0, 4)]); // 随机给一把tier1武器

		case 2:
			vCheatCommand(client, "give", g_sWeaponName[0][GetRandomInt(5, 14)]); // 随机给一把tier2武器	
	}
}

void vCheatCommand(int client, const char[] sCommand, const char[] sArguments = "")
{
	static int iFlagBits, iCmdFlags;
	iFlagBits = GetUserFlagBits(client);
	iCmdFlags = GetCommandFlags(sCommand);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCommand, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", sCommand, sArguments);
	SetUserFlagBits(client, iFlagBits);
	SetCommandFlags(sCommand, iCmdFlags);
}

void vTeleportToSurvivor(int client, bool bRandom = true)
{
	int iSurvivor = 1;
	ArrayList aClients = new ArrayList(2);

	for(; iSurvivor <= MaxClients; iSurvivor++)
	{
		if(iSurvivor == client || !IsClientInGame(iSurvivor) || GetClientTeam(iSurvivor) != 2 || !IsPlayerAlive(iSurvivor))
			continue;
	
		aClients.Set(aClients.Push(!GetEntProp(iSurvivor, Prop_Send, "m_isIncapacitated") ? 0 : !GetEntProp(iSurvivor, Prop_Send, "m_isHangingFromLedge") ? 1 : 2), iSurvivor, 1);
	}

	if(!aClients.Length)
		iSurvivor = 0;
	else
	{
		aClients.Sort(Sort_Descending, Sort_Integer);

		if(!bRandom)
			iSurvivor = aClients.Get(aClients.Length - 1, 1);
		else
		{
			iSurvivor = aClients.Length - 1;
			iSurvivor = aClients.Get(GetRandomInt(aClients.FindValue(aClients.Get(iSurvivor, 0)), iSurvivor), 1);
		}
	}

	delete aClients;

	if(iSurvivor)
	{
		SetEntProp(client, Prop_Send, "m_bDucked", 1);
		SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);

		float vPos[3];
		GetClientAbsOrigin(iSurvivor, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
	}
}

//给玩家近战
//https://forums.alliedmods.net/showpost.php?p=2611529&postcount=484
public void OnMapStart()
{
	int i;
	int iLength = sizeof g_sWeaponModels;
	for(; i < iLength; i++)
	{
		if(!IsModelPrecached(g_sWeaponModels[i]))
			PrecacheModel(g_sWeaponModels[i], true);
	}

	char sBuffer[64];
	for(i = 3; i < 17; i++)
	{
		FormatEx(sBuffer, sizeof sBuffer, "scripts/melee/%s.txt", g_sWeaponName[1][i]);
		if(!IsGenericPrecached(sBuffer))
			PrecacheGeneric(sBuffer, true);
	}

	vGetMeleeWeaponsStringTable();
}

void vGetMeleeWeaponsStringTable()
{
	g_aMeleeScripts.Clear();

	int iTable = FindStringTable("meleeweapons");
	if(iTable != INVALID_STRING_TABLE)
	{
		int iNum = GetStringTableNumStrings(iTable);
		char sMeleeName[64];
		for(int i; i < iNum; i++)
		{
			ReadStringTable(iTable, i, sMeleeName, sizeof sMeleeName);
			g_aMeleeScripts.PushString(sMeleeName);
		}
	}
}

void vGiveMelee(int client, const char[] sMeleeName)
{
	char sScriptName[64];
	if(g_aMeleeScripts.FindString(sMeleeName) != -1)
		strcopy(sScriptName, sizeof sScriptName, sMeleeName);
	else
		g_aMeleeScripts.GetString(GetRandomInt(0, g_aMeleeScripts.Length - 1), sScriptName, sizeof sScriptName);
	
	vCheatCommand(client, "give", sScriptName);
}

void vLoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false) 
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::RoundRespawn") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::RoundRespawn");
	g_hSDKRoundRespawn = EndPrepSDKCall();
	if(g_hSDKRoundRespawn == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::RoundRespawn");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::GoAwayFromKeyboard") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::GoAwayFromKeyboard");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKGoAwayFromKeyboard = EndPrepSDKCall();
	if(g_hSDKGoAwayFromKeyboard == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::GoAwayFromKeyboard");

	vRegisterStatsConditionPatch(hGameData);

	delete hGameData;
}

void vRegisterStatsConditionPatch(GameData hGameData = null)
{
	int iOffset = hGameData.GetOffset("RoundRespawn_Offset");
	if(iOffset == -1)
		SetFailState("Failed to find offset: RoundRespawn_Offset");

	int iByteMatch = hGameData.GetOffset("RoundRespawn_Byte");
	if(iByteMatch == -1)
		SetFailState("Failed to find byte: RoundRespawn_Byte");

	g_pStatsCondition = hGameData.GetAddress("CTerrorPlayer::RoundRespawn");
	if(!g_pStatsCondition)
		SetFailState("Failed to find address: CTerrorPlayer::RoundRespawn");
	
	g_pStatsCondition += view_as<Address>(iOffset);
	
	int iByteOrigin = LoadFromAddress(g_pStatsCondition, NumberType_Int8);
	if(iByteOrigin != iByteMatch)
		SetFailState("Failed to load 'CTerrorPlayer::RoundRespawn', byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, iByteOrigin, iByteMatch);
}

void vRoundRespawn(int client)
{
	vStatsConditionPatch(true);
	SDKCall(g_hSDKRoundRespawn, client);
	vStatsConditionPatch(false);
}

//https://forums.alliedmods.net/showthread.php?t=323220
void vStatsConditionPatch(bool bPatch)
{
	static bool bPatched;
	if(!bPatched && bPatch)
	{
		bPatched = true;
		StoreToAddress(g_pStatsCondition, 0x79, NumberType_Int8);
	}
	else if(bPatched && !bPatch)
	{
		bPatched = false;
		StoreToAddress(g_pStatsCondition, 0x75, NumberType_Int8);
	}
}