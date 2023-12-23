/*
*	Christmas Tree
*	Copyright (C) 2022 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.8"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Christmas Tree
*	Author	:	SilverShot
*	Descrp	:	Spawns gift packages under a Christmas Tree.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=319552
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.8 (30-Jul-2022)
	- Changed cvar "l4d_tree_effects" to turn gifts smoke on or off. This may fix a random rare server crash. Thanks to "Hawkins" for reporting.

1.7 (06-Dec-2021)
	- L4D2: Added cvar "l4d_tree_melee" to control melee type spawn chance. Requested by "CaRmilla".
	- L4D2: Modified cvar "l4d_tree_items" adding an entry to the end for melee chance spawn.
	- Changes to fix warnings when compiling on SourceMod 1.11.

1.6 (30-Sep-2020)
	- Fixed compile errors on SM 1.11.

1.5 (10-May-2020)
	- Blocked glow command from L4D1 which does not support glows.
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.

1.4 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.3 (19-Dec-2019)
	- Versus gamemodes now spawn the same items for both teams.

1.2 (07-Nov-2019)
	- Fixed incorrect gamedata path not loading dissolve if available.

1.1 (07-Nov-2019)
	- Fixed gamedata missing error.
	- Fixed gifts spawning in the ground in L4D1.

1.0 (07-Nov-2019)
	- Initial release.

========================================================================================
	Thanks:

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	"Zuko & McFlurry" for "[L4D2] Weapon/Zombie Spawner" - Modified SetTeleportEndPoint function.
	https://forums.alliedmods.net/showthread.php?t=109659

======================================================================================*/

// Test melee only spawn:
//	l4d_tree_items "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,100"
// Knife only:
//	l4d_tree_melee "0,0,0,0,0,0,0,0,0,0,1,0,0"


#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>



#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d_dissolve_infected"
#define CHAT_TAG			"\x04[\x05Tree\x04] \x01"
#define CONFIG_SPAWNS		"data/l4d_christmas_tree.cfg"

#define MAX_ITEMS			30 // Don't change
#define MAX_MELEE			13 // Don't change
#define MAX_SPAWNS			32
#define MAX_TREES			2
#define LIGHTS_HEIGHT		190.0

#define MODEL_L4D1			"models/props_junk/cardboard_box05.mdl"
#define MODEL_GIFT			"models/items/l4d_gift.mdl"
#define MODEL_TREE			"models/props_foliage/cedar01.mdl"
#define MODEL_GNOME			"models/props_junk/gnome.mdl"
#define SPRITE_HALO			"models/sprites/glow01.spr"
#define PARTICLE_SMOKE		"particle/SmokeStack.vmt"
#define PARTICLE_FIREWORK	"mini_fireworks"
#define SOUND_GIFT			"items/suitchargeok1.wav"


// Rainbow stuff
float g_fRainbowFrame;
int g_iTargR = 255;
int g_iTargG;
int g_iTargB;
int g_iColR = 255;
int g_iColG = 0;
int g_iColB = 0;

// Cvars etc
Menu g_hMenuAng, g_hMenuPos;
ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarBallNum, g_hCvarBallCol, g_hCvarBallRad, g_hCvarCGift, g_hCvarCTree, g_hCvarEffects, g_hCvarGifts, g_hCvarGlow, g_hCvarHealth, g_hCvarItems, g_hCvarMelee, g_hCvarRainbow, g_hCvarRate, g_hCvarSpeed;
float g_fCvarBallRad, g_fCvarSpeed;
int g_iCvarBallNum, g_iCvarBallCol, g_iCvarEffects, g_iCvarGifts, g_iCvarHealth, g_iCvarGlow, g_iCvarRainbow, g_iCvarRate, g_iTotalChance, g_iTotalChanceM, g_iPlayerSpawn, g_iRoundStart, g_iRoundNumber, g_iSpawnCount, g_iTreesCount, g_iSpawns[MAX_SPAWNS][4], g_iChances[MAX_ITEMS], g_iChanceMelee[MAX_MELEE];
bool g_bCvarAllow, g_bMapStarted, g_bLeft4Dead2, g_bLoaded;
char g_sCvarCGift[12], g_sCvarCTree[12];
Handle g_hSDK_Dissolve;
ArrayList g_aGifts;
ArrayList g_aItems;
ArrayList g_aSelected;
StringMap g_aMeleeIDs;

// Weapon Cvars
ConVar g_hAmmoAutoShot, g_hAmmoChainsaw, g_hAmmoGL, g_hAmmoHunting, g_hAmmoM60, g_hAmmoRifle, g_hAmmoShotgun, g_hAmmoSmg, g_hAmmoSniper;
int g_iAmmoAutoShot, g_iAmmoChainsaw, g_iAmmoGL, g_iAmmoHunting, g_iAmmoM60, g_iAmmoRifle, g_iAmmoShotgun, g_iAmmoSmg, g_iAmmoSniper;

enum
{
	TYPE_GIFT = 0,
	TYPE_TREE
}

enum // Must match g_iSpawns size.
{
	INDEX_TREE,
	INDEX_GNOME,
	INDEX_INDEX,
	INDEX_TYPE
}

enum
{
	EFFECTS_LIGHTS		= (1<<0),
	EFFECTS_BALLS		= (1<<1),
	EFFECTS_SPARKS		= (1<<2),
	EFFECTS_DISSOLVE	= (1<<3),
	EFFECTS_SMOKE		= (1<<4)
}

// Ball colors: more reds and greens
char g_sColors[][] =
{
	"255 0 0 255", // Red
	"255 0 0 255", // Red
	"255 0 0 255", // Red
	"255 0 0 255", // Red
	"255 0 0 255", // Red
	"0 255 0 255", // Green
	"0 255 0 255", // Green
	"0 255 0 255", // Green
	"0 255 0 255", // Green
	"0 255 0 255", // Green
	"0 0 255 255", // Blue
	"0 0 255 255", // Blue
	"0 0 255 255", // Blue
	"255 0 255 255", // Purple
	"255 255 0 255" // Yellow
};

// Do not remove or re-arrange items or weapons. Their exact position index is used to identify them.
// Only set their chance to enable or disable with the "l4d_tree_items" cvar.
char g_sItems[][] =
{
	// ITEMS
	"weapon_adrenaline",
	"weapon_pain_pills",
	"weapon_molotov",
	"weapon_pipe_bomb",
	"weapon_vomitjar",
	"weapon_first_aid_kit",
	"weapon_defibrillator",
	"weapon_upgradepack_explosive",
	"weapon_upgradepack_incendiary",

	// WEAPONS L4D1 + L4D2
	"weapon_rifle",
	"weapon_autoshotgun",
	"weapon_hunting_rifle",
	"weapon_smg",
	"weapon_pumpshotgun",
	"weapon_pistol",

	// WEAPONS L4D2
	"weapon_shotgun_chrome",
	"weapon_rifle_desert",
	"weapon_grenade_launcher",
	"weapon_rifle_m60",
	"weapon_rifle_ak47",
	"weapon_rifle_sg552",
	"weapon_shotgun_spas",
	"weapon_smg_silenced",
	"weapon_smg_mp5",
	"weapon_sniper_awp",
	"weapon_sniper_military",
	"weapon_sniper_scout",
	"weapon_pistol_magnum",
	"weapon_chainsaw",
	"weapon_melee"
};

char g_sScripts[MAX_MELEE][] =
{
	"fireaxe",
	"baseball_bat",
	"cricket_bat",
	"crowbar",
	"frying_pan",
	"golfclub",
	"electric_guitar",
	"katana",
	"machete",
	"tonfa",
	"knife",
	"pitchfork",
	"shovel"
	// "riotshield"
};



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Christmas Tree",
	author = "SilverShot",
	description = "Spawns gift packages under a Christmas Tree.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=319552"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	// SDKCalls
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) )
	{
		Handle hGameConf = LoadGameConfigFile(GAMEDATA);
		if( hGameConf != null )
		{
			StartPrepSDKCall(SDKCall_Static);
			if( PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEntityDissolve_Create") == false )
			{
				LogError("Could not load the \"CEntityDissolve_Create\" gamedata signature.");
			} else {
				PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
				PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
				PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
				PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
				PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
				PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
				g_hSDK_Dissolve = EndPrepSDKCall();
				if( g_hSDK_Dissolve == null )
					LogError("Could not prep the \"CEntityDissolve_Create\" function.");
			}
			delete hGameConf;
		}
	}



	// CVARS
	g_hCvarAllow =		CreateConVar(	"l4d_tree_allow",			"1",			"0=插件禁用, 1=插件启用.", CVAR_FLAGS );
	g_hCvarModes =		CreateConVar(	"l4d_tree_modes",			"",				"在这些游戏模式中启用插件, 用英文逗号隔开(无空格). (无内容=全部游戏模式)", CVAR_FLAGS );
	g_hCvarModesOff =	CreateConVar(	"l4d_tree_modes_off",		"",				"在这些游戏模式中关闭插件, 用英文逗号隔开(无空格). (无内容=无)", CVAR_FLAGS );
	g_hCvarModesTog =	CreateConVar(	"l4d_tree_modes_tog",		"0",			"在这些游戏模式中启用插件. 0=全部游戏模式, 1=战役, 2=生还者, 4=对抗, 8=清道夫. 将这些数字叠加在一起", CVAR_FLAGS );
	g_hCvarBallNum =	CreateConVar(	"l4d_tree_ball_count",		"8",			"每一列要显示多少个球", CVAR_FLAGS );
	g_hCvarBallCol =	CreateConVar(	"l4d_tree_ball_columns",	"4",			"要显示多少列球", CVAR_FLAGS );
	g_hCvarBallRad =	CreateConVar(	"l4d_tree_ball_radius",		"45.0",			"从树底开始显示球的距离", CVAR_FLAGS );
	g_hCvarCGift =		CreateConVar(	"l4d_tree_col_gift",		"255 0 0",		"礼物颜色, 0=关闭(默认的礼物颜色)三个数值在0-255之间,用空格分隔, RGB:红绿蓝", CVAR_FLAGS );
	g_hCvarCTree =		CreateConVar(	"l4d_tree_col_tree",		"0 255 0",		"树的颜色, 0=关闭(默认的礼物颜色)三个数值在0-255之间,用空格分隔, RGB:红绿蓝", CVAR_FLAGS );
	g_hCvarEffects =	CreateConVar(	"l4d_tree_effects",			"23",			"0=关闭, 1=灯光,2=球,4=火花,8=溶解(礼物),16=烟雾(礼物-可能导致服务器罕见的崩溃),31=全部, 数字相加", CVAR_FLAGS );
	g_hCvarGifts =		CreateConVar(	"l4d_tree_gifts",			"0",			"在树下产生多少个包裹", CVAR_FLAGS );
	g_hCvarHealth =		CreateConVar(	"l4d_tree_health",			"1",			"0:不破坏或掉落物品 >0:礼物在破裂和掉落物品之前的健康状况", CVAR_FLAGS );
	if( g_bLeft4Dead2 )
	{
		g_hCvarGlow =	CreateConVar(	"l4d_tree_glow",			"255 0 0",		"礼物发光轮廓颜色, 0=关闭(默认的礼物颜色)三个数值在0-255之间,用空格分隔, RGB:红绿蓝", CVAR_FLAGS );
		g_hCvarItems =	CreateConVar(	"l4d_tree_items",			"80,100,25,25,25,25,15,15,15,2,2,2,5,5,5,2,0,0,0,2,0,2,5,0,0,2,0,5,0,5",		"以下物品武器生成百分比几率 数值必须用逗号分隔 肾上腺素, 药丸, 燃烧瓶, 自制手雷, 胆汁, 医疗包, 电击器, 高爆弹药包, 燃烧弹药包, M4步枪, 1代连喷, 木狙, mac冲锋枪, 木喷, 小手枪, 铁喷, 三连发步枪, 榴弹发射器, M60, AK47, Sg552瞄准步枪, SPAS连喷, SMG消音冲锋枪, MP5冲锋枪, AWP, 军狙, 鸟狙, 马格南, 电锯, 其他近战", CVAR_FLAGS );
		g_hCvarMelee =	CreateConVar(	"l4d_tree_melee",			"0,0,0,10,0,0,0,50,50,0,50,10,10",		"以下近战武器生成几率 数值必须用逗号分隔:消防斧, 棒球棍, 板球棍, 撬棍, 平底锅, 高尔夫球棍, 吉他, 武士刀, 看到, 警棍, 小刀, 草叉, 铲子.", CVAR_FLAGS );
	}
	else
	{
		g_hCvarItems =	CreateConVar(	"l4d_tree_items",			"0,100,25,25,0,40,0,0,0,2,2,2,5,5,5",	"Item chance - values must be comma separated: 肾上腺素, 药丸, 燃烧瓶, 自制手雷, 胆汁, 医疗包, 电击器, 高爆弹药包, 燃烧弹药包, M4步枪, 1代连喷, 木狙, mac冲锋枪, 木喷, 小手枪", CVAR_FLAGS );
	}
	g_hCvarRainbow =	CreateConVar(	"l4d_tree_rainbow",			"2",			"0=关闭 1=礼物随时间变化颜色 2=树木随着时间的推移而改变颜色, 3=两个都有", CVAR_FLAGS );
	g_hCvarRate =		CreateConVar(	"l4d_tree_rate",			"10",			"使用彩虹选项时颜色变化的速度", CVAR_FLAGS, true, 1.0, true, 255.0 );
	g_hCvarSpeed =		CreateConVar(	"l4d_tree_speed",			"0.2",			"每秒更新颜色的频率(秒)", CVAR_FLAGS, true, 0.1 );
	CreateConVar(						"l4d_tree_version",			PLUGIN_VERSION, "Christmas Tree plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD );
	AutoExecConfig(true,				"l4d_christmas_tree");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarBallCol.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarBallNum.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarBallRad.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCGift.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCTree.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarEffects.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarGifts.AddChangeHook(ConVarChanged_Cvars);
	if( g_bLeft4Dead2 )
	{
		g_hCvarGlow.AddChangeHook(ConVarChanged_Cvars);
		g_hCvarMelee.AddChangeHook(ConVarChanged_Cvars);
	}
	g_hCvarHealth.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarItems.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRainbow.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRate.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSpeed.AddChangeHook(ConVarChanged_Cvars);



	// WEAPON CVARS
	if( g_bLeft4Dead2 )
	{
		g_hAmmoShotgun =	FindConVar("ammo_shotgun_max");
		g_hAmmoGL =			FindConVar("ammo_grenadelauncher_max");
		g_hAmmoChainsaw =	FindConVar("ammo_chainsaw_max");
		g_hAmmoAutoShot =	FindConVar("ammo_autoshotgun_max");
		g_hAmmoM60 =		FindConVar("ammo_m60_max");
		g_hAmmoSniper =		FindConVar("ammo_sniperrifle_max");

		g_hAmmoGL.AddChangeHook(ConVarChanged_Weapon);
		g_hAmmoChainsaw.AddChangeHook(ConVarChanged_Weapon);
		g_hAmmoAutoShot.AddChangeHook(ConVarChanged_Weapon);
		g_hAmmoM60.AddChangeHook(ConVarChanged_Weapon);
		g_hAmmoSniper.AddChangeHook(ConVarChanged_Weapon);
	} else {
		g_hAmmoShotgun =	FindConVar("ammo_buckshot_max");
	}

	g_hAmmoRifle =			FindConVar("ammo_assaultrifle_max");
	g_hAmmoSmg =			FindConVar("ammo_smg_max");
	g_hAmmoHunting =		FindConVar("ammo_huntingrifle_max");

	g_hAmmoRifle.AddChangeHook(ConVarChanged_Weapon);
	g_hAmmoSmg.AddChangeHook(ConVarChanged_Weapon);
	g_hAmmoHunting.AddChangeHook(ConVarChanged_Weapon);
	g_hAmmoShotgun.AddChangeHook(ConVarChanged_Weapon);



	// COMMANDS
	RegAdminCmd("sm_tree_spawn",	CmdSpawnerTemp,		ADMFLAG_ROOT, 	"在你的十字准线处生成一棵临时的礼物/树, 用法:sm_tree_spawn [0=礼物, 1=树]");
	RegAdminCmd("sm_tree_save",		CmdSpawnerSave,		ADMFLAG_ROOT, 	"在你的十字准线处生成一棵礼物/树并保存到配置中, 用法:sm_tree_save[0=礼物, 1=树]");
	RegAdminCmd("sm_tree_del",		CmdSpawnerDel,		ADMFLAG_ROOT, 	"删除您指向的礼物/树, 并从配置中删除(如果已保存)");
	RegAdminCmd("sm_tree_clear",	CmdSpawnerClear,	ADMFLAG_ROOT, 	"从当前地图中删除此插件生成的所有礼物/树木");
	RegAdminCmd("sm_tree_wipe",		CmdSpawnerWipe,		ADMFLAG_ROOT, 	"从当前地图中删除所有礼物/树木并从配置中删除它们");
	RegAdminCmd("sm_tree_reload",	CmdSpawnerReload,	ADMFLAG_ROOT, 	"重置插件并重新加载数据配置和保存的数据");
	if( g_bLeft4Dead2 )
	RegAdminCmd("sm_tree_glow",		CmdSpawnerGlow,		ADMFLAG_ROOT, 	"切换以启用所有礼物/树木的发光, 以查看它们的放置位置");
	RegAdminCmd("sm_tree_list",		CmdSpawnerList,		ADMFLAG_ROOT, 	"显示礼物/树位置列表和总数");
	RegAdminCmd("sm_tree_tele",		CmdSpawnerTele,		ADMFLAG_ROOT, 	"传送到礼物/树(用法:sm_tree_tele <索引:1 到 MAX_SPAWNS (32)>)");
	RegAdminCmd("sm_tree_ang",		CmdSpawnerAng,		ADMFLAG_ROOT, 	"显示一个菜单来调整十字准线上方的礼物/树角度");
	RegAdminCmd("sm_tree_pos",		CmdSpawnerPos,		ADMFLAG_ROOT, 	"显示一个菜单来调整十字准线结束时的礼物/树原点");



	// OTHER
	g_aGifts = CreateArray();
	g_aItems = CreateArray();
	g_aSelected = CreateArray();
}

public void OnPluginEnd()
{
	ResetPlugin();
}

public void OnMapStart()
{
	g_bMapStarted = true;

	PrecacheParticle(PARTICLE_FIREWORK);

	PrecacheModel(MODEL_TREE, true);
	PrecacheModel(MODEL_GNOME, true);
	PrecacheModel(SPRITE_HALO, true);
	PrecacheModel(PARTICLE_SMOKE, true);
	if( g_bLeft4Dead2 )
		PrecacheModel(MODEL_GIFT, true);
	else
		PrecacheModel(MODEL_L4D1, true);

	PrecacheSound(SOUND_GIFT);

	// Melee ID
	if( g_bLeft4Dead2 )
	{
		delete g_aMeleeIDs;

		g_aMeleeIDs = new StringMap();

		for( int i = 0 ; i < MAX_MELEE; i++ )
		{
			g_aMeleeIDs.SetValue(g_sScripts[i], -1);
		}

		int iTable = FindStringTable("meleeweapons");
		if( iTable != INVALID_STRING_TABLE )
		{
			// Get actual IDs
			int iNum = GetStringTableNumStrings(iTable);
			char sName[PLATFORM_MAX_PATH];

			for( int i = 0; i < iNum; i++ )
			{
				ReadStringTable(iTable, i, sName, sizeof(sName));
				g_aMeleeIDs.SetValue(sName, i);
			}
		}
	}
}

public void OnMapEnd()
{
	ResetPlugin(false);
	g_bMapStarted = false;
	g_iRoundNumber = 0;
	g_aSelected.Clear();
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void ConVarChanged_Weapon(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetWeaponCvars();
}

void GetWeaponCvars()
{
	g_iAmmoRifle		= g_hAmmoRifle.IntValue;
	g_iAmmoShotgun		= g_hAmmoShotgun.IntValue;
	g_iAmmoSmg			= g_hAmmoSmg.IntValue;
	g_iAmmoHunting		= g_hAmmoHunting.IntValue;

	if( g_bLeft4Dead2 )
	{
		g_iAmmoGL			= g_hAmmoGL.IntValue;
		g_iAmmoChainsaw		= g_hAmmoChainsaw.IntValue;
		g_iAmmoAutoShot		= g_hAmmoAutoShot.IntValue;
		g_iAmmoM60			= g_hAmmoM60.IntValue;
		g_iAmmoSniper		= g_hAmmoSniper.IntValue;
	}
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	// Weapons
	GetWeaponCvars();

	// Cvars
	g_iCvarBallCol = g_hCvarBallCol.IntValue;
	g_iCvarBallNum = g_hCvarBallNum.IntValue;
	g_fCvarBallRad = g_hCvarBallRad.FloatValue;
	g_hCvarCGift.GetString(g_sCvarCGift, sizeof(g_sCvarCGift));
	g_hCvarCTree.GetString(g_sCvarCTree, sizeof(g_sCvarCTree));
	g_iCvarEffects = g_hCvarEffects.IntValue;
	g_iCvarGifts = g_hCvarGifts.IntValue;
	if( g_bLeft4Dead2 )
		g_iCvarGlow = GetColor(g_hCvarGlow);
	g_iCvarHealth = g_hCvarHealth.IntValue;
	g_iCvarRainbow = g_hCvarRainbow.IntValue;
	g_iCvarRate = g_hCvarRate.IntValue;
	g_fCvarSpeed = g_hCvarSpeed.FloatValue;

	// Weighted chance
	char temp[128];
	g_hCvarItems.GetString(temp, sizeof(temp));

	char buffers[MAX_ITEMS][4];
	ExplodeString(temp, ",", buffers, sizeof(buffers), sizeof(buffers[]));

	g_iTotalChance = 0;

	int chance;
	for( int i = 0; i < MAX_ITEMS; i++ )
	{
		// L4D2 only: Adrenaline, VomitJar, Defibrillator, Explosive Ammo, Incendiary Ammo, Weapons
		if( !g_bLeft4Dead2 && (i == 0 || i == 4 || (i >= 6 && i <= 8) || i >= 15) )
		{
			g_iChances[i] = 0;
		} else {
			chance = StringToInt(buffers[i]);
			if( chance )
			{
				g_iTotalChance += chance;
				g_iChances[i] = g_iTotalChance;
			} else {
				g_iChances[i] = 0;
			}
		}
	}

	if( g_bLeft4Dead2 )
	{
		// Weighted chance
		g_hCvarMelee.GetString(temp, sizeof(temp));

		char sMelee[MAX_MELEE][4];
		ExplodeString(temp, ",", sMelee, sizeof(sMelee), sizeof(sMelee[]));

		g_iTotalChanceM = 0;

		chance = 0;
		for( int i = 0; i < MAX_MELEE; i++ )
		{
			chance = StringToInt(sMelee[i]);
			if( chance )
			{
				g_iTotalChanceM += chance;
				g_iChanceMelee[i] = g_iTotalChanceM;
			} else {
				g_iChanceMelee[i] = 0;
			}
		}
	}
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		CreateTimer(0.1, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
		g_bCvarAllow = true;
		HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		ResetPlugin();
		g_bCvarAllow = false;
		UnhookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		UnhookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		UnhookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_bMapStarted == false )
		return false;

	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	g_iCurrentMode = 0;

	int entity = CreateEntityByName("info_gamemode");
	if( IsValidEntity(entity) )
	{
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
			RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
	}

	if( iCvarModesTog != 0 )
	{
		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin(false);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(0.5, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(0.5, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

Action TimerStart(Handle timer)
{
	g_iRoundNumber++;
	ResetPlugin();
	LoadSpawns();

	return Plugin_Continue;
}



// ====================================================================================================
//					LOAD SPAWNS
// ====================================================================================================
void LoadSpawns()
{
	if( g_bLoaded ) return;
	g_bLoaded = true;

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	if( !FileExists(sPath) )
		return;

	// Load config
	KeyValues hFile = new KeyValues("spawns");
	if( !hFile.ImportFromFile(sPath) )
	{
		delete hFile;
		return;
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !hFile.JumpToKey(sMap) )
	{
		delete hFile;
		return;
	}

	// Retrieve how many Trees to display
	int iCount = hFile.GetNum("num", 0);
	if( iCount == 0 )
	{
		delete hFile;
		return;
	}

	if( iCount > MAX_SPAWNS )
		iCount = MAX_SPAWNS;

	// Get the Tree origins and spawn
	char sTemp[4];
	float vPos[3], vAng[3];
	int type;

	for( int i = 1; i <= iCount; i++ )
	{
		IntToString(i, sTemp, sizeof(sTemp));

		if( hFile.JumpToKey(sTemp) )
		{
			hFile.GetVector("ang", vAng);
			hFile.GetVector("pos", vPos);
			type = hFile.GetNum("type");

			if( vPos[0] == 0.0 && vPos[0] == 0.0 && vPos[0] == 0.0 ) // Should never happen.
				LogError("Error: 0,0,0 origin. Index=%d. Count=%d.", i, iCount);
			else
				CreateSpawn(vPos, vAng, i, type);
			hFile.GoBack();
		}
	}

	delete hFile;
}



// ====================================================================================================
//					CREATE SPAWN
// ====================================================================================================
void CreateSpawn(const float vOrigin[3], const float vAngles[3], int index = 0, int type)
{
	// ==========
	// INDEX
	// ==========
	if( g_iSpawnCount >= MAX_SPAWNS )
		return;

	int iSpawnIndex = -1;
	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		if( g_iSpawns[i][INDEX_TREE] == 0 )
		{
			iSpawnIndex = i;
			break;
		}
	}

	if( iSpawnIndex == -1 )
		return;

	if( type != TYPE_GIFT && type != TYPE_TREE )
		type = TYPE_GIFT;

	float vPos[3], vAng[3];
	int entity, tree;



	// ==========
	// TREE
	// ==========
	if( type == TYPE_TREE )
	{
		if(  g_iTreesCount >= MAX_TREES )
			return;
		g_iTreesCount++;



		entity = CreateEntityByName("prop_dynamic");
		if( entity == -1 )
			ThrowError("Failed to create prop_dynamic.");

		if( strcmp(g_sCvarCTree, "0") )
			DispatchKeyValue(entity, "rendercolor", g_sCvarCTree);
		SetEntityModel(entity, MODEL_TREE);
		TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(entity);



		if( g_iCvarRainbow & (1<<1) )
			CreateTimer(g_fCvarSpeed, Timer_Rainbow, EntIndexToEntRef(entity), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

		g_iSpawns[iSpawnIndex][INDEX_TREE] = EntIndexToEntRef(entity);
		g_iSpawns[iSpawnIndex][INDEX_INDEX] = index;
		g_iSpawns[iSpawnIndex][INDEX_TYPE] = type;

		tree = entity;



		// ==========
		// BALLS
		// ==========
		if( g_iCvarEffects & EFFECTS_BALLS )
		{
			DataPack dPack;
			CreateDataTimer(0.2, Timer_DrawAngle, dPack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			dPack.WriteCell(EntIndexToEntRef(tree));
			dPack.WriteCell(0);
			dPack.WriteFloat(vAngles[0]);
			dPack.WriteFloat(vAngles[1]);
			dPack.WriteFloat(vAngles[2]);
		} else {
			// Teleport tree to correct angles after positioning and parenting other ents
			TeleportEntity(tree, NULL_VECTOR, vAngles, NULL_VECTOR);
		}



		// ==========
		// LIGHTS
		// ==========
		if( g_iCvarEffects & EFFECTS_LIGHTS )
		{
			vPos = vOrigin;
			vPos[0] += 60.0;
			vPos[1] += 60.0;
			vPos[2] += 100.0;
			int light = MakeLightDynamic(tree, vPos);
			SetVariantEntity(light);
			SetVariantString("255 0 0"); // Red
			AcceptEntityInput(light, "color");
			AcceptEntityInput(light, "TurnOn");

			vPos = vOrigin;
			vPos[0] -= 60.0;
			vPos[1] -= 60.0;
			vPos[2] += 120.0;
			light = MakeLightDynamic(tree, vPos);
			SetVariantEntity(light);
			SetVariantString("0 255 0"); // Green
			AcceptEntityInput(light, "color");
			AcceptEntityInput(light, "TurnOn");

			vPos = vOrigin;
			vPos[0] += 60.0;
			vPos[1] -= 60.0;
			vPos[2] += 60.0;
			light = MakeLightDynamic(tree, vPos);
			SetVariantEntity(light);
			SetVariantString("0 0 255"); // Blue
			AcceptEntityInput(light, "color");
			AcceptEntityInput(light, "TurnOn");

			vPos = vOrigin;
			vPos[0] += 15.0;
			vPos[1] += 35.0;
			vPos[2] += 220.0;
			light = MakeLightDynamic(tree, vPos);
			SetVariantEntity(light);
			SetVariantString("255 150 0"); // Orange
			AcceptEntityInput(light, "color");
			AcceptEntityInput(light, "TurnOn");
		}



		// ==========
		// GNOME
		// ==========
		entity = CreateEntityByName("prop_dynamic_override");
		if( entity == -1 ) ThrowError("Failed to create prop_dynamic_override.");
		g_iSpawns[iSpawnIndex][INDEX_GNOME] = EntIndexToEntRef(entity);

		SetEntityModel(entity, MODEL_GNOME);

		DispatchKeyValue(entity, "color", "255 0 0");
		DispatchKeyValue(entity, "solid", "6");
		DispatchSpawn(entity);
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", tree);

		vPos = vOrigin;
		vPos = view_as<float>({ 0.0, 0.0, 0.0 });
		vAng = view_as<float>({ 0.0, 0.0, 0.0 });
		vPos[1] -= 25.0;
		vPos[2] += 195.0;
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);



		// ==========
		// SPARKS
		// ==========
		if( g_iCvarEffects & EFFECTS_SPARKS )
		{
			vPos = vOrigin;
			vPos[0] += 1.0;
			vPos[0] -= 3.0;
			vPos[1] -= 11.0;
			vPos[2] += 218.0;
			int spark = CreateEntityByName("env_spark");
			DispatchKeyValue(spark, "spawnflags", "256");
			DispatchKeyValue(spark, "angles", "-90 0 0");
			DispatchKeyValue(spark, "TrailLength", "1");
			DispatchKeyValue(spark, "Magnitude", "1");
			TeleportEntity(spark, vPos, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(spark);
			ActivateEntity(spark);
			AcceptEntityInput(spark, "StartSpark");
			SetVariantString("!activator");
			AcceptEntityInput(spark, "SetParent", tree);
		}
	}



	// ==========
	// GIFTS
	// ==========
	int count = g_iCvarGifts;
	if( type == TYPE_GIFT )			count = 1;
	else							count = g_iCvarGifts;

	float angle;
	for( int i = 1; i <= count; i++ )
	{
		vPos = vOrigin;

		if( type == TYPE_TREE )
		{
			angle = i * 270.0 / g_iCvarGifts;

			// Draw in a circle
			vPos[0] += 75.0 * Cosine(angle);
			vPos[1] += 75.0 * Sine(angle);
		}

		entity = CreateEntityByName("prop_dynamic_override");
		if( entity == -1 )
			ThrowError("Failed to create prop_dynamic_override.");

		if( strcmp(g_sCvarCGift, "0") )
			DispatchKeyValue(entity, "rendercolor", g_sCvarCGift);
		DispatchKeyValue(entity, "solid", "6");
		SetEntityModel(entity, g_bLeft4Dead2 ? MODEL_GIFT : MODEL_L4D1);

		// Match ground height
		vAng[0] = 89.0;
		vAng[1] = GetRandomFloat(0.0, 180.0);
		vPos[2] += 10.0;
		SetTeleportEndPoint(0, vPos, vAng);
		if( !g_bLeft4Dead2 ) vPos[2] += 9.0;
		vAng[0] = 0.0;
		vAng[2] = 0.0;

		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "DisableShadow");

		if( type == TYPE_GIFT )
		{
			g_iSpawns[iSpawnIndex][INDEX_TREE] = EntIndexToEntRef(entity);
			g_iSpawns[iSpawnIndex][INDEX_INDEX] = index;
			g_iSpawns[iSpawnIndex][INDEX_TYPE] = type;
		} else {
			// SetVariantString("!activator");
			// AcceptEntityInput(entity, "SetParent", tree);

			SetEntProp(entity, Prop_Data, "m_iHammerID", EntIndexToEntRef(tree));
			g_aGifts.Push(EntIndexToEntRef(entity)); // Because in L4D1 objects parented cannot be shot. So have to use this to clean up instead.
		}

		if( g_iCvarGlow )
		{
			SetEntProp(entity, Prop_Send, "m_nGlowRange", 200);
			SetEntProp(entity, Prop_Send, "m_iGlowType", 1);
			SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iCvarGlow);
			AcceptEntityInput(entity, "StartGlowing");
		}

		if( g_iCvarHealth )
		{
			if( g_iCvarHealth != 1 )
				SetEntProp(entity, Prop_Data, "m_iHealth", g_iCvarHealth);

			SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
		}

		if( g_iCvarRainbow & (1<<0) )
			CreateTimer(g_fCvarSpeed, Timer_Rainbow, EntIndexToEntRef(entity), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}



	g_iSpawnCount++;
}

Action OnTakeDamage(int gift, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if( g_iCvarHealth != 1 )
	{
		int health = RoundToFloor(GetEntProp(gift, Prop_Data, "m_iHealth") - damage);
		if( health > 0 )
		{
			SetEntProp(gift, Prop_Data, "m_iHealth", health);
			return Plugin_Continue;
		}
	}

	if( g_bLeft4Dead2 )
		AcceptEntityInput(gift, "StopGlowing");

	SDKUnhook(gift, SDKHook_OnTakeDamage, OnTakeDamage);

	int entity;
	float vPos[3], vNew[3];
	GetEntPropVector(gift, Prop_Data, "m_vecAbsOrigin", vNew);
	vPos = vNew;



	// Remove temporary types
	entity = EntIndexToEntRef(gift);
	int index = -1;

	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		if( g_iSpawns[i][INDEX_TREE] == entity )
		{
			if( g_iSpawns[i][INDEX_TYPE] == TYPE_GIFT && g_iSpawns[i][INDEX_INDEX] == 0 )
			{
				g_iSpawns[i][INDEX_TREE] = 0;
				g_iSpawnCount--;
			}
			break;
		}
	}



	// Sound
	EmitSoundToAll(SOUND_GIFT, gift, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER);



	// Dissolve
	int hammer = GetEntProp(gift, Prop_Data, "m_iHammerID");

	if( g_hSDK_Dissolve != null && g_iCvarEffects & EFFECTS_DISSOLVE )
	{
		SetEntProp(gift, Prop_Send, "m_fEffects", 32); // EF_NODRAW (1<<5)

		InputKill(gift, 1.0);

		int dissolver = SDKCall(g_hSDK_Dissolve, gift, "", GetGameTime() + 2.0, 2, false);
		if( IsValidEntity(dissolver) )
			SetEntPropFloat(dissolver, Prop_Send, "m_flFadeOutStart", 0.0); // Fixes broken particles
	} else {
		RemoveEntity(gift);
	}



	// Particles
	vPos[2] -= 25;
	entity = DisplayParticle(0, PARTICLE_FIREWORK, vPos, NULL_VECTOR);
	InputKill(entity, 1.0);
	vPos[2] -= 5;
	entity = DisplayParticle(0, PARTICLE_FIREWORK, vPos, NULL_VECTOR);
	InputKill(entity, 1.0);
	vPos[2] -= 5;
	entity = DisplayParticle(0, PARTICLE_FIREWORK, vPos, NULL_VECTOR);
	InputKill(entity, 1.0);
	vPos[2] -= 5;
	entity = DisplayParticle(0, PARTICLE_FIREWORK, vPos, NULL_VECTOR);
	InputKill(entity, 1.0);



	// Smoke
	if( g_iCvarEffects & EFFECTS_SMOKE )
	{
		vPos[0] += 10;
		vPos[2] += 40;
		MakeSmokestack(vPos, "155 0 0");

		vPos[0] -= 15;
		vPos[1] -= 15;
		MakeSmokestack(vPos, "0 0 155");

		vPos[1] += 30;
		MakeSmokestack(vPos, "155 0 50");
	}



	// Weighted selection
	index = -1;
	if( (g_iCurrentMode == 4 || g_iCurrentMode == 8) && g_iRoundNumber > 1 && g_aSelected.Length > 0 )
	{
		index = g_aSelected.Get(0);
		g_aSelected.Erase(0);
	} else {
		int rand = GetRandomInt(1, g_iTotalChance);
		for( int i = 0; i < MAX_ITEMS; i++ )
		{
			if( rand <= g_iChances[i] )
			{
				index = i;
				break;
			}
		}
	}

	if( index == -1 ) return Plugin_Continue;

	if( (g_iCurrentMode == 4 || g_iCurrentMode == 8) && g_iRoundNumber == 1 )
		g_aSelected.Push(index);


	// Melee chance
	int melee;
	int indexMelee;
	if( g_bLeft4Dead2 && index == 29 ) // Melee index
	{
		int rand = GetRandomInt(1, g_iTotalChanceM);

		for( int i = 0; i < MAX_MELEE; i++ )
		{
			if( rand <= g_iChanceMelee[i] )
			{
				if( g_aMeleeIDs.GetValue(g_sScripts[i], melee) == true )
				{
					if( melee != -1 )
					{
						indexMelee = i;
						break;
					}
				}
			}
		}

		if( melee == -1 ) return Plugin_Continue;
	}

	// Item
	int item = CreateEntityByName(g_sItems[index]);
	if( g_bLeft4Dead2 )
		vNew[2] += 10;

	// Melee
	if( g_bLeft4Dead2 && index == 29 && melee != -1 ) // Melee index
	{
		DispatchKeyValue(item, "solid", "6");
		DispatchKeyValue(item, "melee_script_name", g_sScripts[indexMelee]);
	}

	TeleportEntity(item, vNew, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(item);

	if( IsValidEntRef(hammer) && index != 29 )
		SetEntProp(item, Prop_Data, "m_iSubType", hammer);

	g_aItems.Push(EntIndexToEntRef(item));



	// Weapons Ammo
	if( index >= 9 && index != 29 ) // Weapons and not melee
	{
		int ammo;

		switch( index )
		{
			case 9:					ammo = g_iAmmoRifle;
			case 10:				ammo = g_bLeft4Dead2 ? g_iAmmoAutoShot : g_iAmmoShotgun;
			case 11:				ammo = g_iAmmoHunting;
			case 12:				ammo = g_iAmmoSmg;
			case 13:				ammo = g_iAmmoShotgun;
		}

		if( g_bLeft4Dead2 )
		{
			switch( index )
			{
				case 15:			ammo = g_iAmmoShotgun;
				case 16, 19, 20:	ammo = g_iAmmoRifle;
				case 17:			ammo = g_iAmmoGL;
				case 18:			ammo = g_iAmmoM60;
				case 21:			ammo = g_iAmmoAutoShot;
				case 22, 23:		ammo = g_iAmmoSmg;
				case 24, 25, 26:	ammo = g_iAmmoSniper;
				case 27:			ammo = g_iAmmoChainsaw;
			}
		}

		SetEntProp(item, Prop_Send, "m_iExtraPrimaryAmmo", ammo, 4);
	}

	return Plugin_Continue;
}

Action Timer_Rainbow(Handle timer, any entity)
{
	entity = EntRefToEntIndex(entity);
	if( IsValidEntRef(entity) == false ) return Plugin_Stop;

	RainbowFun();

	static char temp[16];
	Format(temp, sizeof(temp), "%d %d %d", g_iColR, g_iColG, g_iColB);
	DispatchKeyValue(entity, "rendercolor", temp);

	return Plugin_Continue;
}

void RainbowFun()
{
	if( GetGameTime() - g_fRainbowFrame < 0.1 ) return;
	g_fRainbowFrame = GetGameTime();

	if( g_iColR >= 255 && g_iColB <= 0 )		{g_iTargG = 255; g_iTargB = 0;} // Red -> Yellow
	if( g_iColG >= 255 && g_iColR >= 255 )		{g_iTargR = 0;}		// Yellow -> Green
	// Takes too long to visually transition:
	// if( g_iColG >= 255 && g_iColR <= 0 )		{g_iTargB = 255;}	// Green to Turquoise
	// if( g_iColB >= 255 && g_iColG >= 255 )		{g_iTargG = 0;}		// Turquoise to Blue
	if( g_iColG >= 255 && g_iColR <= 0 )		{g_iTargB = 255; g_iTargG = 0;}		// Green to Blue
	if( g_iColB >= 255 && g_iColG <= 0 )		{g_iTargR = 255;}	// Blue to Purple
	if( g_iColB >= 255 && g_iColR >= 255 )		{g_iTargB = 0;}		// Purple to Red

	if		( g_iColR < g_iTargR )	g_iColR += g_iCvarRate;
	else if	( g_iColR > g_iTargR )	g_iColR -= g_iCvarRate;
	if		( g_iColG < g_iTargG )	g_iColG += g_iCvarRate;
	else if	( g_iColG > g_iTargG )	g_iColG -= g_iCvarRate;
	if		( g_iColB < g_iTargB )	g_iColB += g_iCvarRate;
	else if	( g_iColB > g_iTargB )	g_iColB -= g_iCvarRate;

	if( g_iColR < 0 )	g_iColR = 0;
	if( g_iColG < 0 )	g_iColG = 0;
	if( g_iColB < 0 )	g_iColB = 0;
	if( g_iColR > 255 )	g_iColR = 255;
	if( g_iColG > 255 )	g_iColG = 255;
	if( g_iColB > 255 )	g_iColB = 255;
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
//					sm_tree_spawn
// ====================================================================================================
Action CmdSpawnerTemp(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Trees] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}
	else if( g_iSpawnCount >= MAX_SPAWNS )
	{
		PrintToChat(client, "%sError: 无法添加更多的树或者礼物 用户: (\x05%d/%d\x01).", CHAT_TAG, g_iSpawnCount, MAX_SPAWNS);
		return Plugin_Handled;
	}

	int type;
	if( args == 1 )
	{
		char sArg[4];
		GetCmdArg(1, sArg, sizeof(sArg));
		type = StringToInt(sArg);
	}

	if( type == TYPE_TREE && g_iTreesCount >= MAX_TREES )
	{
		PrintToChat(client, "%sError: 无法添加更多的树 用户: (\x05%d/%d\x01).", CHAT_TAG, g_iTreesCount, MAX_TREES);
		return Plugin_Handled;
	}

	float vPos[3], vAng[3];
	if( !SetTeleportEndPoint(client, vPos, vAng) )
	{
		PrintToChat(client, "%s无法在此处生成树 请再次尝试", CHAT_TAG);
		return Plugin_Handled;
	}

	CreateSpawn(vPos, vAng, 0, type);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_tree_save
// ====================================================================================================
Action CmdSpawnerSave(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Trees] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}
	else if( g_iSpawnCount >= MAX_SPAWNS )
	{
		PrintToChat(client, "%sError: 无法添加更多的树或者礼物 用户: (\x05%d/%d\x01).", CHAT_TAG, g_iSpawnCount, MAX_SPAWNS);
		return Plugin_Handled;
	}

	char sTemp[4];
	int type;
	if( args == 1 )
	{
		GetCmdArg(1, sTemp, sizeof(sTemp));
		type = StringToInt(sTemp);
	}

	if( type != TYPE_GIFT && type != TYPE_TREE)
		type = TYPE_GIFT;

	if( type == TYPE_TREE && g_iTreesCount >= MAX_TREES )
	{
		PrintToChat(client, "%sError: 无法在此处生成树 用户: (\x05%d/%d\x01).", CHAT_TAG, g_iTreesCount, MAX_TREES);
		return Plugin_Handled;
	}

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		File hCfg = OpenFile(sPath, "w");
		hCfg.WriteLine("");
		delete hCfg;
	}

	// Load config
	KeyValues hFile = new KeyValues("spawns");
	if( !hFile.ImportFromFile(sPath) )
	{
		PrintToChat(client, "%sError: 无法读取插件配置 可能是空文件 路径:(\x05%s\x01).", CHAT_TAG, sPath);
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	if( !hFile.JumpToKey(sMap, true) )
	{
		PrintToChat(client, "%sError: 无法根据配置文件添加树", CHAT_TAG);
		delete hFile;
		return Plugin_Handled;
	}

	// Retrieve how many Trees are saved
	int iCount = hFile.GetNum("num", 0);
	if( iCount >= MAX_SPAWNS )
	{
		PrintToChat(client, "%sError: 无法生成更多的树 用户: (\x05%d/%d\x01).", CHAT_TAG, iCount, MAX_SPAWNS);
		delete hFile;
		return Plugin_Handled;
	}

	// Save count
	iCount++;
	hFile.SetNum("num", iCount);

	IntToString(iCount, sTemp, sizeof(sTemp));

	if( hFile.JumpToKey(sTemp, true) )
	{
		// Set player position as Tree spawn location
		float vPos[3], vAng[3];
		if( !SetTeleportEndPoint(client, vPos, vAng) )
		{
			PrintToChat(client, "%s无法放置树 请再次尝试", CHAT_TAG);
			delete hFile;
			return Plugin_Handled;
		}

		// Save angle / origin
		hFile.SetVector("ang", vAng);
		hFile.SetVector("pos", vPos);
		hFile.SetNum("type", type);

		CreateSpawn(vPos, vAng, iCount, type);

		// Save cfg
		hFile.Rewind();
		hFile.ExportToFile(sPath);

		PrintToChat(client, "%s(\x05%d/%d\x01) - 在pos:[\x05%f %f %f\x01] ang:[\x05%f %f %f\x01]保存树", CHAT_TAG, iCount, MAX_SPAWNS, vPos[0], vPos[1], vPos[2], vAng[0], vAng[1], vAng[2]);
	}
	else
		PrintToChat(client, "%s(\x05%d/%d\x01) - 保存失败", CHAT_TAG, iCount, MAX_SPAWNS);

	delete hFile;
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_tree_del
// ====================================================================================================
Action CmdSpawnerDel(int client, int args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[Trees] Plugin turned off.");
		return Plugin_Handled;
	}

	if( !client )
	{
		ReplyToCommand(client, "[Trees] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	int entity = GetClientAimTarget(client, false);
	if( entity == -1 ) return Plugin_Handled;
	entity = EntIndexToEntRef(entity);

	int index = -1;
	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		if( g_iSpawns[i][INDEX_GNOME] == entity || g_iSpawns[i][INDEX_TREE] == entity )
		{
			index = i;
			break;
		}
	}

	if( index == -1 )
		return Plugin_Handled;

	int cfgindex = g_iSpawns[index][INDEX_INDEX];
	int type = g_iSpawns[index][INDEX_TYPE];
	if( type == TYPE_TREE )
		g_iTreesCount--;

	g_iSpawnCount--;

	if( cfgindex == 0 )
	{
		RemoveSpawn(index);
		return Plugin_Handled;
	}

	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		if( g_iSpawns[i][INDEX_INDEX] > cfgindex )
			g_iSpawns[i][INDEX_INDEX]--;
	}

	// Load config
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		PrintToChat(client, "%sError: 无法找到配置文件 路径:(\x05%s\x01).", CHAT_TAG, CONFIG_SPAWNS);
		return Plugin_Handled;
	}

	KeyValues hFile = new KeyValues("spawns");
	if( !hFile.ImportFromFile(sPath) )
	{
		PrintToChat(client, "%sError: 无法加载配置文件 路径:(\x05%s\x01).", CHAT_TAG, sPath);
		delete hFile;
		return Plugin_Handled;
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !hFile.JumpToKey(sMap) )
	{
		PrintToChat(client, "%sError: 该地图没有在配置文件设置可生成的树", CHAT_TAG);
		delete hFile;
		return Plugin_Handled;
	}

	// Retrieve how many Trees
	int iCount = hFile.GetNum("num", 0);
	if( iCount == 0 )
	{
		delete hFile;
		return Plugin_Handled;
	}

	bool bMove;
	char sTemp[4];

	// Move the other entries down
	for( int i = cfgindex; i <= iCount; i++ )
	{
		IntToString(i, sTemp, sizeof(sTemp));

		if( hFile.JumpToKey(sTemp) )
		{
			if( !bMove )
			{
				bMove = true;
				hFile.DeleteThis();
				RemoveSpawn(index);
			}
			else
			{
				IntToString(i-1, sTemp, sizeof(sTemp));
				hFile.SetSectionName(sTemp);
			}
		}

		hFile.Rewind();
		hFile.JumpToKey(sMap);
	}

	if( bMove )
	{
		iCount--;
		hFile.SetNum("num", iCount);

		// Save to file
		hFile.Rewind();
		hFile.ExportToFile(sPath);

		PrintToChat(client, "%s(\x05%d/%d\x01) - 已从配置文件移除", CHAT_TAG, iCount, MAX_SPAWNS);
	}
	else
		PrintToChat(client, "%s(\x05%d/%d\x01) - 从配置文件移除失败", CHAT_TAG, iCount, MAX_SPAWNS);

	delete hFile;
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_tree_clear
// ====================================================================================================
Action CmdSpawnerClear(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Trees] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	ResetPlugin();

	PrintToChat(client, "%s(0/%d) - 全部的树和礼物已从配置文件中移除", CHAT_TAG, MAX_SPAWNS);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_tree_wipe
// ====================================================================================================
Action CmdSpawnerWipe(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Trees] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		PrintToChat(client, "%sError: 无法找到配置文件 路径:(\x05%s\x01).", CHAT_TAG, sPath);
		return Plugin_Handled;
	}

	// Load config
	KeyValues hFile = new KeyValues("spawns");
	if( !hFile.ImportFromFile(sPath) )
	{
		PrintToChat(client, "%sError: 无法加载配置文件 路径:(\x05%s\x01).", CHAT_TAG, sPath);
		delete hFile;
		return Plugin_Handled;
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !hFile.JumpToKey(sMap, false) )
	{
		PrintToChat(client, "%sError: 该地图没有在配置文件设置可生成的树", CHAT_TAG);
		delete hFile;
		return Plugin_Handled;
	}

	hFile.DeleteThis();
	ResetPlugin();

	// Save to file
	hFile.Rewind();
	hFile.ExportToFile(sPath);
	delete hFile;

	PrintToChat(client, "%s(0/%d) - 全部的树和礼物已从配置文件中移除, 以及\x05sm_tree_save\x01.", CHAT_TAG, MAX_SPAWNS);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_tree_reload
// ====================================================================================================
Action CmdSpawnerReload(int client, int args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[Trees] Plugin turned off.");
		return Plugin_Handled;
	}

	ResetPlugin();
	CreateTimer(0.1, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	ReplyToCommand(client, "[Trees] Reset and reloaded data config.");

	return Plugin_Handled;
}

// ====================================================================================================
//					sm_tree_glow
// ====================================================================================================
Action CmdSpawnerGlow(int client, int args)
{
	static bool glow;
	glow = !glow;
	PrintToChat(client, "%s高亮%s", CHAT_TAG, glow ? "启用" : "禁用");

	VendorGlow(glow);
	return Plugin_Handled;
}

void VendorGlow(int glow)
{
	int ent;

	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		ent = g_iSpawns[i][INDEX_TREE];
		if( IsValidEntRef(ent) )
		{
			SetEntProp(ent, Prop_Send, "m_iGlowType", 3);
			SetEntProp(ent, Prop_Send, "m_glowColorOverride", 65535);
			SetEntProp(ent, Prop_Send, "m_nGlowRange", glow ? 0 : 50);
			ChangeEdictState(ent, FindSendPropInfo("prop_dynamic", "m_nGlowRange"));
		}
	}
}

// ====================================================================================================
//					sm_tree_list
// ====================================================================================================
Action CmdSpawnerList(int client, int args)
{
	float vPos[3];
	int count;
	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		if( IsValidEntRef(g_iSpawns[i][INDEX_TREE]) )
		{
			count++;
			GetEntPropVector(g_iSpawns[i][INDEX_TREE], Prop_Data, "m_vecOrigin", vPos);
			PrintToChat(client, "%s%d) %f %f %f", CHAT_TAG, i+1, vPos[0], vPos[1], vPos[2]);
		}
	}
	PrintToChat(client, "%sTotal: %d.", CHAT_TAG, count);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_tree_tele
// ====================================================================================================
Action CmdSpawnerTele(int client, int args)
{
	if( args == 1 )
	{
		char arg[16];
		GetCmdArg(1, arg, sizeof(arg));
		int index = StringToInt(arg) - 1;
		if( index > -1 && index < MAX_SPAWNS && IsValidEntRef(g_iSpawns[index][INDEX_TREE]) )
		{
			float vPos[3];
			GetEntPropVector(g_iSpawns[index][INDEX_TREE], Prop_Data, "m_vecOrigin", vPos);
			vPos[2] += 20.0;
			TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
			PrintToChat(client, "%s传到到%d.", CHAT_TAG, index + 1);
			return Plugin_Handled;
		}

		PrintToChat(client, "%sCould not find index for teleportation.", CHAT_TAG);
	}
	else
		PrintToChat(client, "%sUsage: sm_tree_tele <index 1-%d>.", CHAT_TAG, MAX_SPAWNS);
	return Plugin_Handled;
}

// ====================================================================================================
//					MENU ANGLE
// ====================================================================================================
Action CmdSpawnerAng(int client, int args)
{
	ShowMenuAng(client);
	return Plugin_Handled;
}

void ShowMenuAng(int client)
{
	CreateMenus();
	g_hMenuAng.Display(client, MENU_TIME_FOREVER);
}

int AngMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Select )
	{
		if( index == 6 )
			SaveData(client);
		else
			SetAngle(client, index);
		ShowMenuAng(client);
	}

	return 0;
}

void SetAngle(int client, int index)
{
	int aim = GetClientAimTarget(client, false);
	if( aim != -1 )
	{
		float vAng[3];
		int entity;
		aim = EntIndexToEntRef(aim);

		for( int i = 0; i < MAX_SPAWNS; i++ )
		{
			entity = g_iSpawns[i][INDEX_GNOME];

			if( entity == aim  )
			{
				entity = g_iSpawns[i][INDEX_TREE];
				GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);

				switch( index )
				{
					case 0: vAng[0] += 5.0;
					case 1: vAng[1] += 5.0;
					case 2: vAng[2] += 5.0;
					case 3: vAng[0] -= 5.0;
					case 4: vAng[1] -= 5.0;
					case 5: vAng[2] -= 5.0;
				}

				TeleportEntity(entity, NULL_VECTOR, vAng, NULL_VECTOR);

				PrintToChat(client, "%sNew angles: %f %f %f", CHAT_TAG, vAng[0], vAng[1], vAng[2]);
				break;
			}
		}
	}
}

// ====================================================================================================
//					MENU ORIGIN
// ====================================================================================================
Action CmdSpawnerPos(int client, int args)
{
	ShowMenuPos(client);
	return Plugin_Handled;
}

void ShowMenuPos(int client)
{
	CreateMenus();
	g_hMenuPos.Display(client, MENU_TIME_FOREVER);
}

int PosMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Select )
	{
		if( index == 6 )
			SaveData(client);
		else
			SetOrigin(client, index);
		ShowMenuPos(client);
	}

	return 0;
}

void SetOrigin(int client, int index)
{
	int aim = GetClientAimTarget(client, false);
	if( aim != -1 )
	{
		float vPos[3];
		int entity;
		aim = EntIndexToEntRef(aim);

		for( int i = 0; i < MAX_SPAWNS; i++ )
		{
			entity = g_iSpawns[i][INDEX_GNOME];

			if( entity == aim  )
			{
				entity = g_iSpawns[i][INDEX_TREE];
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);

				switch( index )
				{
					case 0: vPos[0] += 0.5;
					case 1: vPos[1] += 0.5;
					case 2: vPos[2] += 0.5;
					case 3: vPos[0] -= 0.5;
					case 4: vPos[1] -= 0.5;
					case 5: vPos[2] -= 0.5;
				}

				TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

				PrintToChat(client, "%sNew origin: %f %f %f", CHAT_TAG, vPos[0], vPos[1], vPos[2]);
				break;
			}
		}
	}
}

void SaveData(int client)
{
	int aim = GetClientAimTarget(client, false);
	if( aim == -1 )
		return;

	aim = EntIndexToEntRef(aim);

	int entity, index;
	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		entity = g_iSpawns[i][INDEX_GNOME];

		if( entity == aim  )
		{
			entity = g_iSpawns[i][INDEX_TREE];
			index = g_iSpawns[i][INDEX_INDEX];
			break;
		}
	}

	if( index == 0 )
		return;

	// Load config
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		PrintToChat(client, "%sError: 无法找到配置文件 路径:(\x05%s\x01).", CHAT_TAG, CONFIG_SPAWNS);
		return;
	}

	KeyValues hFile = new KeyValues("spawns");
	if( !hFile.ImportFromFile(sPath) )
	{
		PrintToChat(client, "%sError: 无法加载配置文件 路径:(\x05%s\x01).", CHAT_TAG, sPath);
		delete hFile;
		return;
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !hFile.JumpToKey(sMap) )
	{
		PrintToChat(client, "%sError: 该地图没有在配置文件设置可生成的树", CHAT_TAG);
		delete hFile;
		return;
	}

	float vAng[3], vPos[3];
	char sTemp[4];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);

	IntToString(index, sTemp, sizeof(sTemp));
	if( hFile.JumpToKey(sTemp) )
	{
		hFile.SetVector("ang", vAng);
		hFile.SetVector("pos", vPos);

		// Save cfg
		hFile.Rewind();
		hFile.ExportToFile(sPath);

		PrintToChat(client, "%s已将生成数据保存到配置文件", CHAT_TAG);
	}
}

void CreateMenus()
{
	if( g_hMenuAng == null )
	{
		g_hMenuAng = new Menu(AngMenuHandler);
		g_hMenuAng.AddItem("", "X + 5.0");
		g_hMenuAng.AddItem("", "Y + 5.0");
		g_hMenuAng.AddItem("", "Z + 5.0");
		g_hMenuAng.AddItem("", "X - 5.0");
		g_hMenuAng.AddItem("", "Y - 5.0");
		g_hMenuAng.AddItem("", "Z - 5.0");
		g_hMenuAng.AddItem("", "SAVE");
		g_hMenuAng.SetTitle("Set Angle");
		g_hMenuAng.ExitButton = true;
	}

	if( g_hMenuPos == null )
	{
		g_hMenuPos = new Menu(PosMenuHandler);
		g_hMenuPos.AddItem("", "X + 0.5");
		g_hMenuPos.AddItem("", "Y + 0.5");
		g_hMenuPos.AddItem("", "Z + 0.5");
		g_hMenuPos.AddItem("", "X - 0.5");
		g_hMenuPos.AddItem("", "Y - 0.5");
		g_hMenuPos.AddItem("", "Z - 0.5");
		g_hMenuPos.AddItem("", "SAVE");
		g_hMenuPos.SetTitle("Set Position");
		g_hMenuPos.ExitButton = true;
	}
}



// ====================================================================================================
//					STUFF
// ====================================================================================================
bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

void InputKill(int entity, float time)
{
	static char temp[40];
	Format(temp, sizeof(temp), "OnUser4 !self:Kill::%f:-1", time);
	SetVariantString(temp);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser4");
}

int GetColor(ConVar hCvar)
{
	char sTemp[12];
	hCvar.GetString(sTemp, sizeof(sTemp));

	if( sTemp[0] == 0 )
		return 0;

	char sColors[3][4];
	int color = ExplodeString(sTemp, " ", sColors, sizeof(sColors), sizeof(sColors[]));

	if( color != 3 )
		return 0;

	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);

	return color;
}

void ResetPlugin(bool all = true)
{
	g_bLoaded = false;
	g_iSpawnCount = 0;
	g_iTreesCount = 0;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_fRainbowFrame = 0.0;
	g_iTargR = 255;
	g_iTargG = 0;
	g_iTargB = 0;
	g_iColR = 255;
	g_iColG = 0;
	g_iColB = 0;

	if( all )
	{
		for( int i = 0; i < MAX_SPAWNS; i++ )
			RemoveSpawn(i);

		// Delete gifts
		int entity, len = g_aGifts.Length;
		for( int i = 0; i < len; i++ )
		{
			entity = g_aGifts.Get(i);

			if( IsValidEntRef(entity) && GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == -1 )
				RemoveEntity(entity);
		}

		g_aGifts.Clear();

		// Delete items
		len = g_aItems.Length;
		for( int i = 0; i < len; i++ )
		{
			entity = g_aItems.Get(i);

			if( IsValidEntRef(entity) && GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == -1 )
				RemoveEntity(entity);
		}

		g_aItems.Clear();
	}
}

void RemoveSpawn(int index)
{
	// Delete tree
	int entity = g_iSpawns[index][INDEX_TREE];
	g_iSpawns[index][INDEX_TREE] = 0;
	if( IsValidEntRef(entity) )
	{
		// Delete gifts
		int gift, len = g_aGifts.Length;
		for( int i = len - 1; i >= 0; i-- )
		{
			gift = g_aGifts.Get(i);

			if( IsValidEntRef(gift) && GetEntProp(gift, Prop_Data, "m_iHammerID") == entity )
			{
				g_aGifts.Erase(i);
				RemoveEntity(gift);
			}
		}

		// Delete items
		len = g_aItems.Length;
		for( int i = len - 1; i >= 0; i-- )
		{
			gift = g_aItems.Get(i);

			if( IsValidEntRef(gift) && GetEntPropEnt(gift, Prop_Send, "m_hOwnerEntity") == -1 && GetEntProp(gift, Prop_Data, "m_iSubType") == entity )
			{
				g_aItems.Erase(i);
				RemoveEntity(gift);
			}
		}

		// Delete tree (since everything else is parented they delete too)
		RemoveEntity(entity);
	}
}



// ====================================================================================================
//					POSITION
// ====================================================================================================
bool SetTeleportEndPoint(int client, float vPos[3], float vAng[3])
{
	if( client )
	{
		GetClientEyePosition(client, vPos);
		GetClientEyeAngles(client, vAng);
	}

	Handle trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, _TraceFilter);

	if( TR_DidHit(trace) )
	{
		float vNorm[3];
		TR_GetEndPosition(vPos, trace);
		TR_GetPlaneNormal(trace, vNorm);
		float angle = vAng[1];
		GetVectorAngles(vNorm, vAng);

		if( vNorm[2] == 1.0 )
		{
			vAng[0] = 0.0;
			vAng[1] += angle;
		}
		else
		{
			vAng[0] = 0.0;
			vAng[1] += angle - 90.0;
		}
	}
	else
	{
		delete trace;
		return false;
	}

	delete trace;
	return true;
}

bool _TraceFilter(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}

// ====================================================================================================
//					LIGHTS VECTORS
// ====================================================================================================
Action Timer_DrawAngle(Handle timer, DataPack dPack)
{
	dPack.Reset();
	int entity = dPack.ReadCell();
	if( IsValidEntRef(entity) == false ) return Plugin_Stop;

	int counts = dPack.ReadCell();
	float vAng[3];
	vAng[0] = dPack.ReadFloat();
	vAng[1] = dPack.ReadFloat();
	vAng[2] = dPack.ReadFloat();

	// Exit when columns done
	if( counts++ == g_iCvarBallCol )
	{
		// Teleport tree to correct angles after positioning and parenting balls
		TeleportEntity(entity, NULL_VECTOR, vAng, NULL_VECTOR);
		return Plugin_Stop;
	}

	// Update pack count
	dPack.Reset();
	dPack.WriteCell(entity);
	dPack.WriteCell(counts);
	dPack.WriteFloat(vAng[0]);
	dPack.WriteFloat(vAng[1]);
	dPack.WriteFloat(vAng[2]);

	// Draw balls
	float vPos[3], vNew[3], angle, height, radius;
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);
	height = LIGHTS_HEIGHT / g_iCvarBallNum;
	radius = g_fCvarBallRad / g_iCvarBallNum;
	radius *= 2;
	angle = counts * 270.0 / g_iCvarBallCol;

	vPos[0] -= 3.0;
	vPos[1] -= 11.0;
	vPos[2] += LIGHTS_HEIGHT + height;

	// From 2 to avoid drawing top.
	for( int i = 2; i <= g_iCvarBallNum + 1; i++ )
	{
		vNew = vPos;
		vNew[0] += i * radius * Cosine(angle);
		vNew[1] += i * radius * Sine(angle);
		vNew[2] -= i * height;

		CreateEnvSprite(entity, g_sColors[GetRandomInt(1, sizeof(g_sColors)) - 1], vNew);
	}

	return Plugin_Continue;
}



// ====================================================================================================
//					STOCKS - PARTICLES
// ====================================================================================================
int DisplayParticle(int target, const char[] sParticle, const float vPos[3], const float vAng[3], float refire = 0.0)
{
	int entity = CreateEntityByName("info_particle_system");
	if( entity == -1)
	{
		LogError("Failed to create 'info_particle_system'");
		return 0;
	}

	DispatchKeyValue(entity, "effect_name", sParticle);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "start");

	// Attach
	if( target )
	{
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", target);
	}

	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

	// Refire
	if( refire )
	{
		static char sTemp[64];
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:Stop::%f:-1", refire - 0.05);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:FireUser2::%f:-1", refire);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");

		SetVariantString("OnUser2 !self:Start::0:-1");
		AcceptEntityInput(entity, "AddOutput");
		SetVariantString("OnUser2 !self:FireUser1::0:-1");
		AcceptEntityInput(entity, "AddOutput");
	}

	return entity;
}

int PrecacheParticle(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	if( table == INVALID_STRING_TABLE )
	{
		table = FindStringTable("ParticleEffectNames");
	}

	int index = FindStringIndex(table, sEffectName);
	if( index == INVALID_STRING_INDEX )
	{
		bool save = LockStringTables(false);
		AddToStringTable(table, sEffectName);
		LockStringTables(save);
		index = FindStringIndex(table, sEffectName);
	}

	return index;
}



// ====================================================================================================
//					EFFECTS
// ====================================================================================================
int MakeLightDynamic(int target, const float vPos[3])
{
	int entity = CreateEntityByName("light_dynamic");
	if( entity == -1 )
	{
		LogError("Failed to create 'light_dynamic'");
		return 0;
	}

	DispatchKeyValue(entity, "_light", "0 0 0 0");
	DispatchKeyValue(entity, "brightness", "0.1");
	DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
	DispatchKeyValueFloat(entity, "distance", 600.0);
	DispatchKeyValue(entity, "style", "0");
	DispatchSpawn(entity);

	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

	// Attach
	if( target )
	{
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", target);
	}

	return entity;
}

void CreateEnvSprite(int target, const char[] sColor, const float vPos[3])
{
	int entity = CreateEntityByName("env_sprite");
	if( entity == -1)
	{
		LogError("Failed to create 'env_sprite'");
		return;
	}

	DispatchKeyValue(entity, "rendercolor", sColor);
	DispatchKeyValue(entity, "model", SPRITE_HALO);
	DispatchKeyValue(entity, "spawnflags", "3");
	DispatchKeyValue(entity, "rendermode", "9");
	DispatchKeyValue(entity, "GlowProxySize", "0.1");
	DispatchKeyValue(entity, "renderamt", "200");
	DispatchKeyValue(entity, "scale", "0.01");
	DispatchSpawn(entity);

	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

	// Attach
	if( target )
	{
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", target);
	}
}

void MakeSmokestack(const float vPos[3], const char[] sColor)
{
	int entity = CreateEntityByName("env_smokestack");
	DispatchKeyValue(entity, "WindSpeed", "0");
	DispatchKeyValue(entity, "WindAngle", "0");
	DispatchKeyValue(entity, "twist", "0");
	DispatchKeyValue(entity, "StartSize", "30");
	DispatchKeyValue(entity, "SpreadSpeed", "1");
	DispatchKeyValue(entity, "Speed", "30");
	DispatchKeyValue(entity, "SmokeMaterial", PARTICLE_SMOKE);
	DispatchKeyValue(entity, "roll", "0");
	DispatchKeyValue(entity, "rendercolor", sColor);
	DispatchKeyValue(entity, "renderamt", "50");
	DispatchKeyValue(entity, "Rate", "10");
	DispatchKeyValue(entity, "JetLength", "30");
	DispatchKeyValue(entity, "InitialState", "0");
	DispatchKeyValue(entity, "EndSize", "25");
	DispatchKeyValue(entity, "BaseSpread", "15");

	DispatchSpawn(entity);
	ActivateEntity(entity);
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entity, "TurnOn");

	SetVariantString("OnUser1 !self:TurnOff::0.6:1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");

	InputKill(entity, 3.0);
}