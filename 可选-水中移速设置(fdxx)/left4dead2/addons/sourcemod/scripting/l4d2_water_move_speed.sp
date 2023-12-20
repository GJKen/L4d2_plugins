#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

#define VERSION	"0.1"

ConVar
	g_cvNormalSpeed,
	g_cvTankAliveSpeed;

float
	g_fSpeed,
	g_fNormalSpeed,
	g_fTankAliveSpeed;

public Plugin myinfo =
{
	name = "L4D2 Water move speed",
	author = "fdxx",
	description = "Adjust Survivor's speed in water (coop mode only).",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_water_move_speed_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvNormalSpeed = CreateConVar("l4d2_water_move_speed_normal", "115.0", "Survivor's normal speed in water.");
	g_cvTankAliveSpeed = CreateConVar("l4d2_water_move_speed_tankalive", "220.0", "Survivor's speed in water when TANK is alive.");

	OnConVarChanged(null, "", "");
	g_fSpeed = g_fNormalSpeed;

	g_cvNormalSpeed.AddChangeHook(OnConVarChanged);
	g_cvTankAliveSpeed.AddChangeHook(OnConVarChanged);

	ReplaceMemoryAddress();
	CreateTimer(0.5, TankAliveCheck_Timer, _, TIMER_REPEAT);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fNormalSpeed = g_cvNormalSpeed.FloatValue;
	g_fTankAliveSpeed = g_cvTankAliveSpeed.FloatValue;
}

void ReplaceMemoryAddress()
{
	GameData hGameData = new GameData("l4d2_water_move_speed");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_water_move_speed.txt\" gamedata.");

	MemoryPatch mPatch = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::GetRunTopSpeed::WaterMoveSpeed");
	if (!mPatch.Validate())
		SetFailState("Verify patch failed.");
	if (!mPatch.Enable())
		SetFailState("Enable patch failed.");

	StoreToAddress(mPatch.Address + view_as<Address>(4), GetAddressOfCell(g_fSpeed), NumberType_Int32);

	delete hGameData;
}

Action TankAliveCheck_Timer(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && GetEntProp(i, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
		{
			g_fSpeed = g_fTankAliveSpeed;
			return Plugin_Continue;
		}
	}
	
	g_fSpeed = g_fNormalSpeed;
	return Plugin_Continue;
}
