#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.1.1"

public Plugin myinfo =
{
	name = "[L4D & 2] Lag-compensated Skeet",
	author = "Forgetest",
	description = "Make hunter skeets more consistent across different pings.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

methodmap CountdownTimer
{
	public bool HasStarted() {
		return (this.m_timestamp > 0.0);
	}

	property float m_duration {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(4), NumberType_Int32); }
	}

	property float m_timestamp {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(8), NumberType_Int32); }
	}
}

methodmap CUserCmd
{
	property int tick_count {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(8), NumberType_Int32); }
	}
}

bool g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	if (g_bLateLoad)
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i)) HookClient(i, true);
		}
	}
}

public void OnClientPutInServer(int client)
{
	HookClient(client, true);
}

void HookClient(int client, bool toggle)
{
	if (toggle)
	{
		SDKHook(client, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
		SDKHook(client, SDKHook_OnTakeDamagePost, SDK_OnTakeDamage_Post);
	}
	else
	{
		SDKUnhook(client, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
		SDKUnhook(client, SDKHook_OnTakeDamagePost, SDK_OnTakeDamage_Post);
	}
}

Action SDK_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	int ability = GetEntPropEnt(victim, Prop_Send, "m_customAbility");
	if (ability == -1 || !IsAbilityLunge(ability))
		return Plugin_Continue;

	if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2 || IsFakeClient(attacker))
		return Plugin_Continue;

	float flTargetTime = GetLagCompTargetTime(attacker);

	if (GetEntProp(ability, Prop_Send, "m_isLunging"))
	{
		float flLungeStartTime = GetEntPropFloat(ability, Prop_Send, "m_lungeStartTime");

		SetEntProp(victim, Prop_Send, "m_isAttemptingToPounce", flTargetTime >= flLungeStartTime);
	}
	else
	{
		CountdownTimer lungeCooldownTiemr = GetLungeCooldownTimer(ability);
		if (lungeCooldownTiemr.HasStarted())
		{
			float flLungeEndTime = lungeCooldownTiemr.m_timestamp - lungeCooldownTiemr.m_duration;

			SetEntProp(victim, Prop_Send, "m_isAttemptingToPounce", flTargetTime < flLungeEndTime);
		}
	}

	return Plugin_Continue;
}

void SDK_OnTakeDamage_Post(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	int ability = GetEntPropEnt(victim, Prop_Send, "m_customAbility");
	if (ability == -1 || !IsAbilityLunge(ability))
		return;

	SetEntProp(victim, Prop_Send, "m_isAttemptingToPounce", GetEntProp(ability, Prop_Send, "m_isLunging"));
}

float GetLagCompTargetTime(int client)
{
	/*

	// correct is the amount of time we have to correct game time
	float correct = 0.0f;

	// Get true latency
	INetChannelInfo *nci = engine->GetPlayerNetInfo( player->entindex() );
	if ( nci )
	{
		// add network latency
		correct+= nci->GetLatency( FLOW_OUTGOING );
	}

	// NOTE:  do these computations in float time, not ticks, to avoid big roundoff error accumulations in the math
	// add view interpolation latency see C_BaseEntity::GetInterpolationAmount()
	correct += player->m_fLerpTime;

	// check bounds [0,sv_maxunlag]
	correct = clamp( correct, 0.0f, sv_maxunlag.GetFloat() );

	// correct tick send by player
	float flTargetTime = TICKS_TO_TIME( cmd->tick_count ) - player->m_fLerpTime;

	// calculate difference between tick sent by player and our latency based tick
	float deltaTime =  correct - ( gpGlobals->curtime - flTargetTime );

	if ( fabs( deltaTime ) > 0.2f )
	{
		// difference between cmd time and latency is too big > 200ms, use time correction based on latency
		// DevMsg("StartLagCompensation: delta too big (%.3f)\n", deltaTime );
		flTargetTime = gpGlobals->curtime - correct;
	}

	flTargetTime += TICKS_TO_TIME( sv_lagpushticks.GetInt() );

	*/

	static ConVar sv_maxunlag = null, sv_lagpushticks = null;
	if (!sv_maxunlag || !sv_lagpushticks)
	{
		sv_maxunlag = FindConVar("sv_maxunlag");
		sv_lagpushticks = FindConVar("sv_lagpushticks");
	}

	// correct is the amount of time we have to correct game time
	float correct = GetClientLatency(client, NetFlow_Outgoing); // Get true latency

	// NOTE:  do these computations in float time, not ticks, to avoid big roundoff error accumulations in the math
	// add view interpolation latency see C_BaseEntity::GetInterpolationAmount()
	correct += GetEntPropFloat(client, Prop_Data, "m_fLerpTime");

	// check bounds [0,sv_maxunlag]
	if (sv_maxunlag) correct = Math_Clamp( correct, 0.0, sv_maxunlag.FloatValue );

	// correct tick send by player
	float flTargetTime = GetTickInterval() * GetPlayerCurrentCommand(client).tick_count - GetEntPropFloat(client, Prop_Data, "m_fLerpTime");

	// calculate difference between tick sent by player and our latency based tick
	float deltaTime =  correct - ( GetGameTime() - flTargetTime );

	if ( FloatAbs(deltaTime) > 0.2 )
	{
		// difference between cmd time and latency is too big > 200ms, use time correction based on latency
		flTargetTime = GetGameTime() - correct;
	}

	if (sv_lagpushticks) flTargetTime += GetTickInterval() * sv_lagpushticks.IntValue;

	return flTargetTime;
}

CountdownTimer GetLungeCooldownTimer(int ability)
{
	static int s_iOffs_m_lungeCooldownTimer = -1;
	if (s_iOffs_m_lungeCooldownTimer == -1)
		s_iOffs_m_lungeCooldownTimer = FindSendPropInfo("CLunge", "m_isLunging") + 4;

	return view_as<CountdownTimer>(GetEntityAddress(ability) + view_as<Address>(s_iOffs_m_lungeCooldownTimer));
}

CUserCmd GetPlayerCurrentCommand(int player)
{
	static int s_iOffs_m_pCurrentCommand = -1;
	if (s_iOffs_m_pCurrentCommand == -1)
		s_iOffs_m_pCurrentCommand = FindDataMapInfo(player, "m_hViewModel")
									+ 4*2 /* CHandle<CBaseViewModel> * MAX_VIEWMODELS */
									+ 88 /* sizeof(m_LastCmd) */;

	return view_as<CUserCmd>(GetEntData(player, s_iOffs_m_pCurrentCommand, 4));
}

bool IsAbilityLunge(int ability)
{
	char cls[64];
	GetEdictClassname(ability, cls, sizeof(cls));
	return strcmp(cls, "ability_lunge") == 0;
}

stock any Math_Clamp(any inc, any low, any high)
{
	return (inc > high) ? high : ((inc < low) ? low : inc);
}
