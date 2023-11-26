#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION			"1.4h-2023/6/11"
#define PLUGIN_NAME			    "l4d2_cs_kill_hud"
#define DEBUG 0

public Plugin myinfo =
{
	name = "[L4D2] CS Kill Hud",
	author = "Miuwiki, Harry",
	description = "HUD with cs kill info list.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/profiles/76561198026784913/"
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

#define CVAR_FLAGS                    FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION     FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

#define TEAM_SURVIVOR		2
#define TEAM_INFECTED		3

#define CLASSNAME_INFECTED            "infected"
#define CLASSNAME_WITCH               "witch"

#define HUD_LEFT_TOP	0
#define HUD_LEFT_BOT	1
#define HUD_MID_TOP		2
#define HUD_MID_BOT		3
#define HUD_RIGHT_TOP	4
#define HUD_RIGHT_BOT	5
#define HUD_TICKER		6
#define HUD_FAR_LEFT	7
#define HUD_FAR_RIGHT	8
#define HUD_MID_BOX		9
#define HUD_SCORE_TITLE	10
#define HUD_SCORE_1		11
#define HUD_SCORE_2		12
#define HUD_SCORE_3		13
#define HUD_SCORE_4		14

#define MAX_SIZE_HUD	15

// custom flags for background, time, alignment, which team, pre or postfix, etc
#define HUD_FLAG_PRESTR			(1<<0)	//	do you want a string/value pair to start(pre) or end(post) with the static string (default is PRE)
#define HUD_FLAG_POSTSTR		(1<<1)	//	ditto
#define HUD_FLAG_BEEP			(1<<2)	//	Makes a countdown timer blink
#define HUD_FLAG_BLINK			(1<<3)  //	do you want this field to be blinking
#define HUD_FLAG_AS_TIME		(1<<4)	//	to do..
#define HUD_FLAG_COUNTDOWN_WARN	(1<<5)	//	auto blink when the timer gets under 10 seconds
#define HUD_FLAG_NOBG			(1<<6) 	//	dont draw the background box for this UI element
#define HUD_FLAG_ALLOWNEGTIMER	(1<<7) 	//	by default Timers stop on 0:00 to avoid briefly going negative over network, this keeps that from happening
#define HUD_FLAG_ALIGN_LEFT		(1<<8) 	//	Left justify this text
#define HUD_FLAG_ALIGN_CENTER	(1<<9)	//	Center justify this text
#define HUD_FLAG_ALIGN_RIGHT	(3<<8)	//	Right justify this text
#define HUD_FLAG_TEAM_SURVIVORS	(1<<10) //	only show to the survivor team
#define HUD_FLAG_TEAM_INFECTED	(1<<11) //	only show to the special infected team
#define HUD_FLAG_TEAM_MASK		(3<<10) //	link HUD_FLAG_TEAM_SURVIVORS and HUD_FLAG_TEAM_INFECTED
#define HUD_FLAG_UNKNOWN1		(1<<12)	//	?
#define HUD_FLAG_TEXT			(1<<13)	//	?
#define HUD_FLAG_NOTVISIBLE		(1<<14) //	if you want to keep the slot data but keep it from displaying

ConVar g_hCvarEnable, g_hCvarKillInfoNumber, g_hCvarHudDecrease, g_hCvarBlockMessage, 
	g_hCvarHUDBlink, g_hCvarHUDBackground;
bool g_bCvarEnable, g_bCvarBlockMessage, g_bCvarHUDBlink, g_bCvarHUDBackground;
int g_iCvarKillInfoNumber;
float g_fCvarHudDecrease;

static StringMap g_weapon_name;
ArrayList g_hud_killinfo;
Handle g_hKillHUDDecreaseTimer;
int g_iHUDFlags;

static const char g_event_weapon_string[][] = 
{
	"melee",

	"pistol",
	"pistol_magnum",
	"dual_pistols",

	"smg",
	"smg_silenced",
	"smg_mp5",

	"rifle",
	"rifle_ak47",
	"rifle_sg552",
	"rifle_desert",

	"pumpshotgun",
	"shotgun_chrome",
	"autoshotgun",
	"shotgun_spas",

	"hunting_rifle",
	"sniper_military",
	"sniper_scout",
	"sniper_awp",

	"pipe_bomb",

	"inferno",
	"entityflame",

	"rifle_m60",

	"grenade_launcher_projectile",

	"boomer",
	"player",

	"prop_minigun_l4d1",
	"prop_minigun",

	"world",
	"worldspawn",
	"trigger_hurt",
};

static const char g_kill_type[][] =
{
	"■■‖:::::::>",     //0 melee

	"/̵͇̿̿/’̿’̿ ̿ ̿̿ ̿̿ ̿̿",        //1 pistol

	"⌐╤═─",         //2 smg

	"︻╦╦═─",   //3 rifle

	"▄︻═══∶∷",      //4 shotgun

	"︻╦̵̵͇̿̿̿̿╤───",    //5 sniper

	"☆BOMB☆",          //6 pipe bomb

	"__∫∫∫∫__",      //7 inferno, entityflame

	"▄︻╤■══一",		//8 M60

	"︻■■■■ ●",	    //9 grenade_launcher_projectile

	"(●｀・ω・)=Ｏ",	     //10 killed by push

	"↼■╦══",	     //11 killed by mini gun

	"X_X",           //12 killed by world

	"*皿*彡",         //13 killed by special infected,

	"→‖",           //14 kill behind wall
	
	"→⊙",           //15 headshot

	"(ﾒﾟДﾟ)ﾒ彡",           //16 killed by witch

	"☠",         //17 killed by common infected
};

#define KILL_HUD_BASE 8
#define KILL_INFO_MAX 7

static const float g_HUDpos[][] =
{
    {0.00,0.00,0.00,0.00}, // 0
    {0.00,0.00,0.00,0.00},
    {0.00,0.00,0.00,0.00},
    {0.00,0.00,0.00,0.00},
    {0.00,0.00,0.00,0.00},
    {0.00,0.00,0.00,0.00},
    {0.00,0.00,0.00,0.00},
    {0.00,0.00,0.00,0.00},

    // kill list
    {0.50,0.06,0.49,0.04}, // 8
    {0.50,0.10,0.49,0.04},
    {0.50,0.14,0.49,0.04}, // 10
    {0.50,0.18,0.49,0.04},
    {0.50,0.22,0.49,0.04},
    {0.50,0.26,0.49,0.04},
    {0.50,0.30,0.49,0.04}, // 14
};

enum struct HUD
{
	int slot;
	int flag;
	float pos[4];
	char info[128];
	void Place()
	{
		HUDSetLayout(this.slot, HUD_FLAG_TEXT|this.flag, this.info);
		HUDPlace(this.slot, this.pos[0], this.pos[1], this.pos[2], this.pos[3]);
	}
}

public void OnPluginStart()
{
	g_weapon_name = new StringMap();
	g_hud_killinfo = new ArrayList(128);
	LoadEventWeaponName();

	g_hCvarEnable 			= CreateConVar( PLUGIN_NAME ... "_enable",        				"1",   "0=Plugin off, 1=Plugin on.", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hCvarKillInfoNumber 	= CreateConVar( PLUGIN_NAME ... "_number",        				"5",   "Numbers of kill list on hud (Default: 5, MAX: 7)", CVAR_FLAGS, true, 1.0, true, 8.0);
	g_hCvarHudDecrease 		= CreateConVar( PLUGIN_NAME ... "_notice_time",   				"7.0", "Time in seconds to erase kill list on hud.", CVAR_FLAGS, true, 1.0);
	g_hCvarBlockMessage 	= CreateConVar( PLUGIN_NAME ... "_disable_standard_message", 	"1",   "If 1, disable offical player death message (the red font of kill info)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hCvarHUDBlink         = CreateConVar( PLUGIN_NAME ... "_blink", 						"1",   "If 1, Makes the text blink from white to red.", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hCvarHUDBackground    = CreateConVar( PLUGIN_NAME ... "_background", 					"0",   "If 1, Shows the text inside a black transparent background.\nNote: the background may not draw properly when initialized as \"0\", start the map with \"1\" to render properly.\n", CVAR_FLAGS, true, 0.0, true, 1.0);
	CreateConVar(                       	PLUGIN_NAME ... "_version",       PLUGIN_VERSION, PLUGIN_NAME ... " Plugin Version", CVAR_FLAGS_PLUGIN_VERSION);
	AutoExecConfig(true,                	PLUGIN_NAME);

	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarKillInfoNumber.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHudDecrease.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarBlockMessage.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHUDBlink.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHUDBackground.AddChangeHook(ConVarChanged_Cvars);

	HookEvent("player_death",Event_PlayerDeathInfo,EventHookMode_Pre);
}

//Cvars-------------------------------

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bCvarEnable = g_hCvarEnable.BoolValue;
	g_iCvarKillInfoNumber = g_hCvarKillInfoNumber.IntValue;
	g_fCvarHudDecrease = g_hCvarHudDecrease.FloatValue;
	g_bCvarBlockMessage = g_hCvarBlockMessage.BoolValue;
	g_bCvarHUDBlink = g_hCvarHUDBlink.BoolValue;
	g_bCvarHUDBackground = g_hCvarHUDBackground.BoolValue;

	g_iHUDFlags = HUD_FLAG_ALIGN_RIGHT;

	if(!g_bCvarHUDBackground)
		g_iHUDFlags |= HUD_FLAG_NOBG;

	if(g_bCvarHUDBlink)
		g_iHUDFlags |= HUD_FLAG_BLINK;
}

//Sourcemod API Forward-------------------------------

public void OnMapStart()
{
	/**
	 * 启用HUD绘制.
	 * 在OnMapStart()函数内部启用即可.	
	 */
	GameRules_SetProp("m_bChallengeModeActive", true, _, _, true);
}

public void OnConfigsExecuted()
{
	GetCvars();

	for (int slot = KILL_HUD_BASE; slot < MAX_SIZE_HUD; slot++)
		RemoveHUD(slot);

	g_hud_killinfo.Clear();
}

//Event-------------------------------

void Event_PlayerDeathInfo(Event event, const char[] name, bool dontBroadcast)
{
	if( !g_bCvarEnable )
		return;

	int victim = GetClientOfUserId( event.GetInt("userid") );
	bool bIsVictimPlayer = true;
	if( victim <= 0 || victim > MaxClients || !IsClientInGame(victim) )
		bIsVictimPlayer = false;

	int attacker = GetClientOfUserId( event.GetInt("attacker") );
	bool bIsAttackerPlayer = true;
	if( attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker) ) // because attacker = 0 mean it is world.
		bIsAttackerPlayer = false;

	int entityid = event.GetInt("entityid");
	bool headshot = event.GetBool("headshot");

	if(g_bCvarBlockMessage) event.BroadcastDisabled = true; // by prehook, set this to prevent the red font of kill info.

	static char killinfo[128];
	if( bIsAttackerPlayer == false)
	{
		if(bIsVictimPlayer == true) // something killed player
		{
			int attackid = event.GetInt("attackerentid");
			if(IsWitch(attackid))
			{
				FormatEx(killinfo,sizeof(killinfo),"    %s  %N",g_kill_type[16],victim);
			}
			else if(IsCommonInfected(attackid))
			{
				FormatEx(killinfo,sizeof(killinfo),"    %s  %N",g_kill_type[17],victim);
			}
			else
			{
				FormatEx(killinfo,sizeof(killinfo),"    %s  %N",g_kill_type[12],victim);
			}
			
			DisplayKillList(killinfo);
		}

		return;
	}

	if( GetClientTeam(attacker) == TEAM_INFECTED 
		&& bIsVictimPlayer && GetClientTeam(victim) == TEAM_SURVIVOR ) // infected kill survivor
	{
		static char attacker_name[64];
		if( IsFakeClient(attacker) )
		{
			FormatEx(attacker_name, sizeof(attacker_name), "%N", attacker);
			int index = StrContains(attacker_name,")");
			if( index != -1 )
				FormatEx(attacker_name,sizeof(attacker_name),"%s", attacker_name[index + 1]);
		}
		else
		{
			FormatEx(attacker_name, sizeof(attacker_name), "%N", attacker);
		}

		FormatEx(killinfo,sizeof(killinfo),"%s  %s  %N",attacker_name,g_kill_type[13],victim);
		DisplayKillList(killinfo);
		return;
	}

	static char weapon_type[64], victim_name[64];
	event.GetString("weapon",weapon_type,sizeof(weapon_type));
	if(bIsVictimPlayer)
	{
		if( IsFakeClient(victim) )
		{
			FormatEx(victim_name,sizeof(victim_name),"%N",victim);
			int index = StrContains(victim_name,")");
			if( index != -1 )
				FormatEx(victim_name,sizeof(victim_name),"%s",victim_name[index + 1]);
		}
		else
		{
			FormatEx(victim_name,sizeof(victim_name),"%N",victim);
		}
	}
	else
	{
		if(IsWitch(entityid))
		{
			FormatEx(victim_name,sizeof(victim_name),"Witch");
		}
		else
		{
			return;
		}
	}

	// add kill type
	if( strncmp(weapon_type, "world", 5, false) == 0 || // "wordl", "worldspawn"
		strncmp(weapon_type, "trigger_hurt", 12, false) == 0 ) // "trigger_hurt"
	{
		FormatEx(killinfo,sizeof(killinfo),"    %s  %s",g_kill_type[12],victim_name);
		DisplayKillList(killinfo);
		return;
	}

	if( !g_weapon_name.ContainsKey(weapon_type) )
		return;
		
	static char sWeaponType[64];
	g_weapon_name.GetString(weapon_type, sWeaponType, sizeof(sWeaponType));

	if(strcmp(weapon_type, "pipe_bomb", false) == 0 ||
		strcmp(weapon_type, "inferno", false) == 0 ||
		strcmp(weapon_type, "entityflame", false) == 0 ||
		strcmp(weapon_type, "boomer", false) == 0 ||
		strcmp(weapon_type, "player", false) == 0 )
	{
		FormatEx(killinfo,sizeof(killinfo),"%N  %s  %s",attacker, sWeaponType, victim_name);
	}
	else
	{
		if(bIsVictimPlayer)
		{

			if( headshot )
			{
				if( IsPlayerKilledBehindWall(attacker, victim) )
					FormatEx(killinfo,sizeof(killinfo),"%N  %s %s %s  %s",attacker,g_kill_type[14],g_kill_type[15],sWeaponType,victim_name);
				else
					FormatEx(killinfo,sizeof(killinfo),"%N  %s %s  %s",attacker,g_kill_type[15],sWeaponType,victim_name);
			}
			else
			{
				if( IsPlayerKilledBehindWall(attacker, victim) )
					FormatEx(killinfo,sizeof(killinfo),"%N  %s %s  %s",attacker,g_kill_type[14],sWeaponType,victim_name);
				else
					FormatEx(killinfo,sizeof(killinfo),"%N  %s  %s",attacker,sWeaponType,victim_name);
			}
		}
		else
		{
			if( headshot )
			{
				if( IsEntityKilledBehindWall(attacker, entityid) )
					FormatEx(killinfo,sizeof(killinfo),"%N  %s %s %s  %s",attacker,g_kill_type[14],g_kill_type[15],sWeaponType,victim_name);
				else
					FormatEx(killinfo,sizeof(killinfo),"%N  %s %s  %s",attacker,g_kill_type[15],sWeaponType,victim_name);
			}
			else
			{
				if( IsEntityKilledBehindWall(attacker, entityid) )
					FormatEx(killinfo,sizeof(killinfo),"%N  %s %s  %s",attacker,g_kill_type[14],sWeaponType,victim_name);
				else
					FormatEx(killinfo,sizeof(killinfo),"%N  %s  %s",attacker,sWeaponType,victim_name);
			}
		}
	}

	DisplayKillList(killinfo);
}

//Timer-------------------------------

Action Timer_KillHUDDecrease(Handle timer)
{
	if( g_hud_killinfo.Length == 0 )
	{
		g_hKillHUDDecreaseTimer = null;
		return Plugin_Stop;
	}

	g_hud_killinfo.Erase(0);

	HUD kill_list;
	int index;
	for(index = 0; index < KILL_INFO_MAX && index < g_hud_killinfo.Length; index++)
	{
		g_hud_killinfo.GetString(index, kill_list.info, sizeof(kill_list.info));
		kill_list.slot = index + KILL_HUD_BASE;
		kill_list.flag = g_iHUDFlags;
		kill_list.pos  = g_HUDpos[kill_list.slot];
		kill_list.Place();
	}

	while(index < KILL_INFO_MAX)
	{
		RemoveHUD(index + KILL_HUD_BASE);
		index++;
	}

	return Plugin_Continue;
}

//Function-------------------------------

void DisplayKillList(const char[] info)
{
	HUD kill_list;
	FormatEx(kill_list.info, sizeof(kill_list.info), "%s", info);
	g_hud_killinfo.PushString(info);

	if( g_hud_killinfo.Length <= g_iCvarKillInfoNumber )
	{
		kill_list.slot = g_hud_killinfo.Length-1 + KILL_HUD_BASE;
		kill_list.flag = g_iHUDFlags;
		kill_list.pos  = g_HUDpos[kill_list.slot];
		kill_list.Place();
	}
	else
	{
		g_hud_killinfo.Erase(0);
		for(int index = 0; index < KILL_INFO_MAX && index < g_hud_killinfo.Length; index++)
		{
			g_hud_killinfo.GetString(index, kill_list.info, sizeof(kill_list.info));
			kill_list.slot = index+KILL_HUD_BASE;
			kill_list.flag = g_iHUDFlags;
			kill_list.pos  = g_HUDpos[kill_list.slot];
			kill_list.Place();
		}
	}

	delete g_hKillHUDDecreaseTimer;
	g_hKillHUDDecreaseTimer = CreateTimer(g_fCvarHudDecrease, Timer_KillHUDDecrease, _, TIMER_REPEAT);
}

bool IsPlayerKilledBehindWall(int attacker,int client)
{
	float vPos_a[3],vPos_c[3];
	GetClientEyePosition(attacker, vPos_a);
	GetClientEyePosition(client,vPos_c);
	Handle hTrace = TR_TraceRayFilterEx(vPos_a, vPos_c,MASK_PLAYERSOLID, RayType_EndPoint,TraceRayNoPlayers,client);
	if( hTrace != null )
	{
		if( TR_DidHit(hTrace) )
		{
			delete hTrace;
			return true;
		}
	}
	delete hTrace;
	return false;
}

bool TraceRayNoPlayers(int entity, int mask, any data)
{
    if( entity == data || (entity >= 1 && entity <= MaxClients) )
    {
        return false;
    }
    return true;
}

bool IsEntityKilledBehindWall(int attacker, int entity)
{
	float vAngles[3],vOrigin[3];
	
	GetClientEyePosition(attacker, vOrigin);
	GetClientEyeAngles(attacker, vAngles);
	
	//get endpoint for teleport
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceRayNoEntities);
	
	if(TR_DidHit(trace))
	{
		if(TR_GetEntityIndex(trace)==entity)
		{
			delete trace;
			return false;
		}
	}

	delete trace;
	return true;
}

bool TraceRayNoEntities(int entity, int mask, any data)
{
    if( entity == data || (entity >= 1 && entity <= MaxClients) )
    {
        return false;
    }
    return true;
}

void LoadEventWeaponName()
{
	for(int i = 0; i < sizeof(g_event_weapon_string); i++)
	{
		switch(i)
		{
			case 0: // melee
				g_weapon_name.SetString(g_event_weapon_string[i],g_kill_type[0]);

			case 1,2,3: // pistol,pistol_magnum,dual_pistols
				g_weapon_name.SetString(g_event_weapon_string[i],g_kill_type[1]);

			case 4,5,6: // smg,smg_silenced,smg_mp5
				g_weapon_name.SetString(g_event_weapon_string[i],g_kill_type[2]);

			case 7,8,9,10: // rifle,rifle_ak47,rifle_sg552,rifle_desert
				g_weapon_name.SetString(g_event_weapon_string[i],g_kill_type[3]);

			case 11,12,13,14: // pumpshotgun,shotgun_chrome,autoshotgun,shotgun_spas
				g_weapon_name.SetString(g_event_weapon_string[i],g_kill_type[4]);

			case 15,16,17,18: // hunting_rifle,sniper_military,sniper_scout,sniper_awp
				g_weapon_name.SetString(g_event_weapon_string[i],g_kill_type[5]);

			case 19: // pipe boomb
				g_weapon_name.SetString(g_event_weapon_string[i],g_kill_type[6]);

			case 20,21: // inferno,entityflame
				g_weapon_name.SetString(g_event_weapon_string[i],g_kill_type[7]);
			
			case 22: // rifle_m60,
				g_weapon_name.SetString(g_event_weapon_string[i],g_kill_type[8]);

			case 23: // grenade_launcher_projectile
				g_weapon_name.SetString(g_event_weapon_string[i],g_kill_type[9]);
			
			case 24,25: // boomer,player killed by push
				g_weapon_name.SetString(g_event_weapon_string[i],g_kill_type[10]);
			
			case 26,27: // prop_minigun_l4d1, prop_minigun
				g_weapon_name.SetString(g_event_weapon_string[i],g_kill_type[11]);

			case 28,29,30: // world, worldspawn, trigger_hurt
				g_weapon_name.SetString(g_event_weapon_string[i],g_kill_type[12]);
		}
	}
}

bool IsWitch(int entity)
{
    if (entity > 0 && IsValidEntity(entity))
    {
        char strClassName[64];
        GetEntityClassname(entity, strClassName, sizeof(strClassName));
        return strcmp(strClassName, CLASSNAME_WITCH, false) == 0;
    }
    return false;
}

bool IsCommonInfected(int entity)
{
	if (entity > 0 && IsValidEntity(entity))
	{
		char entType[64];
		GetEntityClassname(entity, entType, sizeof(entType));
		return StrEqual(entType, CLASSNAME_INFECTED);
	}
	return false;
}

// HUD-------------------------------

/**
 * Passes a table that defines your in-game HUD to the engine.
 * From there on, you can modify the table to cause changes.
 * Though often you wont, you will instead use a dataval entry to define a simple lambda that
 * returns the up-to-date value to the HUD system.
*/
/**
 * Passes a table that defines your in-game HUD to the engine.
 *
 * @param slot			HUD slot.
 * @param flags			flags(出于某些未知原因需要添加HUD_FLAG_TEXT falg才能正常绘制)..
 * @param dataval		used for data of destination string buffer.
 * @param ...			Variable number of format parameters.
 * @noreturn
 * @error				Invalid HUD slot.
 */
void HUDSetLayout(int slot, int flags, const char[] dataval, any ...) {
	static char str[128];
	VFormat(str, sizeof str, dataval, 4);

	GameRules_SetProp("m_iScriptedHUDFlags", flags, _, slot, true);
	GameRules_SetPropString("m_szScriptedHUDStringSet", str, true, slot);
}

/**
 * Note:HUDPlace(slot,x,y,w,h): moves the given HUD slot to the XY position specified, with new W and H.
 * This is for doing occasional highlight/make a point type things,
 * or small changes to layout w/o having to build a new .res to put in a VPK.
 * We suspect if you want to do a super fancy HUD you will want to create your own hudscriptedmode.res file,
 * just making sure to use the same element naming conventions so you can still talk to them from script.
 * x,y,w,h are all 0.0-1.0 screen relative coordinates (actually, a bit smaller than the screen, but anyway).
 * So a box near middle might be set as (0.4,0.45,0.2,0.1) or so.
 */
/**
 * Place a slot in game.
 *
 * @param slot			HUD slot.
 * @param x				screen x position.
 * @param y				screen y position.
 * @param width			screen slot width.
 * @param height		screen slot height.
 * @noreturn
 * @error				Invalid HUD slot.
 */
void HUDPlace(int slot, float x, float y, float width, float height) {
	GameRules_SetPropFloat("m_fScriptedHUDPosX", x, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosY", y, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDWidth", width, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDHeight", height, slot, true);
}

/**
 * Removes a slot from game.
 *
 * @param slot			HUD slot.
 * @noreturn
 * @error				Invalid HUD slot.
 */
void RemoveHUD(int slot) {
	GameRules_SetProp("m_iScriptedHUDInts", 0, _, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDFloats", 0.0, slot, true);
	GameRules_SetProp("m_iScriptedHUDFlags", HUD_FLAG_NOTVISIBLE, _, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosX", 0.0, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosY", 0.0, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDWidth", 0.0, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDHeight", 0.0, slot, true);
	GameRules_SetPropString("m_szScriptedHUDStringSet", "", true, slot);
}