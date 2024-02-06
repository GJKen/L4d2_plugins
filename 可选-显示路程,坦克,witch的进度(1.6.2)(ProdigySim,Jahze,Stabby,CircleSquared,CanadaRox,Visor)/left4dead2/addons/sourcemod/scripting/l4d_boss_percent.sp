#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define TEAM_SURVIVORS 2

public Plugin myinfo =
{
	name = "L4D2 Boss Flow Announce",
	author = "ProdigySim, Jahze, Stabby, CircleSquared, CanadaRox, Visor",
	version = "1.6.2",
	description = "Announce boss flow percents!",
	url = "https://github.com/ConfoglTeam/ProMod"
};

int g_fWitchPercent = 0;
int g_fTankPercent = 0;

// Dark Carnival: Remix Work Around Variables
char g_sCurrentMap[64]; 												// Stores the current map name
bool g_bIsRemix; 														// Stores if the current map is Dark Carnival: Remix. So we don't have to keep checking via IsDKR()
//int g_idkrwaAmount; 													// Stores the amount of times the DKRWorkaround method has been executed. We only want to execute it twice, one to get the tank percentage, and a second time to get the witch percentage.

ConVar g_hVsBossBuffer;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("UpdateBossPercents", Native_UpdateBossPercents);
	RegPluginLibrary("l4d_boss_percent");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");

	RegConsoleCmd("sm_boss", BossCmd);
	RegConsoleCmd("sm_tank", BossCmd);
	RegConsoleCmd("sm_witch", BossCmd);
	RegConsoleCmd("sm_cur", BossCmd);
	RegConsoleCmd("sm_current", BossCmd);

	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);
	HookEvent("player_say", DKRWorkaround, EventHookMode_Post); // Called when a message is sent in chat. Used to grab the Dark Carnival: Remix boss percentages.

	AddCommandListener(SetTank_Listener, "sm_settank");
	AddCommandListener(SetTank_Listener, "sm_setwitch");
}

// Called when a new map is loaded
public void OnMapStart()
{

	// Get Current Map
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	
	// Check if the current map is part of the Dark Carnival: Remix Campaign -- and save it
	g_bIsRemix = IsDKR();
	
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	PrintBossPercents(client);
	return Plugin_Continue;
}

public Action SetTank_Listener(int client, const char[] command, int argc)
{
	CreateTimer(0.1, SaveBossFlows);
	return Plugin_Continue;
}

public Action RoundStartEvent(Handle event, const char[] name, bool dontBroadcast)
{
	CreateTimer(5.0, SaveBossFlows);
	return Plugin_Continue;
}

public int Native_UpdateBossPercents(Handle plugin, int numParams)
{
	CreateTimer(0.1, SaveBossFlows);
	return true;
}

public Action SaveBossFlows(Handle timer)
{
	g_fWitchPercent = 0;
	g_fTankPercent = 0;

	if (L4D2Direct_GetVSWitchToSpawnThisRound(0))
	{
		g_fWitchPercent = RoundToNearest(GetWitchFlow(0) * 100.0);
	}
	if (L4D2Direct_GetVSTankToSpawnThisRound(0))
	{
		g_fTankPercent = RoundToNearest(GetTankFlow(0) * 100.0);
	}
	return Plugin_Continue;
}

stock void PrintBossPercents(int client)
{
	int boss_proximity = RoundToNearest(GetBossProximity() * 100.0);
	char message[512];
	char buffer[256];
	Format(message, sizeof(message), "\x01<\x05Current\x01> \x04%d%%%%    ", boss_proximity);

	if (g_fTankPercent) {
		Format(buffer, sizeof(buffer), "\x01<\x05Tank\x01> \x04%d%%%%    ", g_fTankPercent);
	} else {
		Format(buffer, sizeof(buffer), "\x01<\x05Tank\x01> \x04Static Tank    ");
	}
	StrCat(message, sizeof(message), buffer);

	if (g_fWitchPercent) {
		Format(buffer, sizeof(buffer), "\x01<\x05Witch\x01> \x04%d%%%%", g_fWitchPercent);
	} else {
		Format(buffer, sizeof(buffer), "\x01<\x05Witch\x01> \x04Static Witch");
	}
	StrCat(message, sizeof(message), buffer);
	
	if (client) {
		PrintToChatAll(message);
	} else {
		PrintToServer(message);
	}
}

public Action BossCmd(int client, int args)
{
	PrintBossPercents(client);
	return Plugin_Continue;
}

stock float GetTankFlow(int round)
{
	return L4D2Direct_GetVSTankFlowPercent(round);
}

stock float GetWitchFlow(int round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round);
}

float GetBossProximity()
{
	float proximity = GetMaxSurvivorCompletion() + g_hVsBossBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance();

	return (proximity > 1.0) ? 1.0 : proximity;
}

float GetMaxSurvivorCompletion()
{
	float flow = 0.0, tmp_flow = 0.0, origin[3];
	Address pNavArea;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS) {
			GetClientAbsOrigin(i, origin);
			pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if (pNavArea != Address_Null) {
				tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				flow = (flow > tmp_flow) ? flow : tmp_flow;
			}
		}
	}

	return (flow / L4D2Direct_GetMapMaxFlowDistance());
}

/* ========================================================
// ====================== Section #4 ======================
// ============ Dark Carnival: Remix Workaround ===========
// ========================================================
 *
 * This section is where all of our DKR work around stuff
 * well be kept. DKR has it's own boss flow "randomizer"
 * and therefore needs to be set as a static map to avoid
 * having 2 tanks on the map. Because of this, we need to 
 * do a few extra steps to determine the boss spawn percents.
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

// Check if the current map name is equal to and of the Dark Carnival: Remix map names
bool IsDKR()
{
	if (StrEqual(g_sCurrentMap, "dkr_m1_motel", true) || StrEqual(g_sCurrentMap, "dkr_m2_carnival", true) || StrEqual(g_sCurrentMap, "dkr_m3_tunneloflove", true) || StrEqual(g_sCurrentMap, "dkr_m4_ferris", true) || StrEqual(g_sCurrentMap, "dkr_m5_stadium", true))
	{
		return true;
	}
	return false;
	
}

// Finds a percentage from a string
int GetPercentageFromText(const char[] text)
{
	// Check to see if text contains '%' - Store the index if it does
	int index = StrContains(text, "%", false);
	
	// If the index isn't -1 (No '%' found) then find the percentage
	if (index > -1) {
		char sBuffer[12]; // Where our percentage will be kept.
		
		// If the 3rd character before the '%' symbol is a number it's 100%.
		if (IsCharNumeric(text[index-3])) {
			return 100;
		}
		
		// Check to see if the characters that are 1 and 2 characters before our '%' symbol are numbers
		if (IsCharNumeric(text[index-2]) && IsCharNumeric(text[index-1])) {
		
			// If both characters are numbers combine them into 1 string
			Format(sBuffer, sizeof(sBuffer), "%c%c", text[index-2], text[index-1]);
			
			// Convert our string to an int
			return StringToInt(sBuffer);
		}
	}
	
	// Couldn't find a percentage
	return -1;
}

/*
 *
 * On Dark Carnival: Remix there is a script to display custom boss percentages to users via chat.
 * We can "intercept" this message and read the boss percentages from the message.
 * From there we can add them to our Ready Up menu and to our !boss commands
 *
 */
public void DKRWorkaround(Event event, const char[] name, bool dontBroadcast)
{
	// If the current map is not part of the Dark Carnival: Remix campaign, don't continue
	if (!g_bIsRemix) return;
	
	// Check if the function has already ran more than twice this map
	//if (g_bDKRFirstRoundBossesSet || InSecondHalfOfRound()) return;
	
	// Check if the message is not from a user (Which means its from the map script)
	int UserID = GetEventInt(event, "userid", 0);
	if (!UserID/* && !InSecondHalfOfRound()*/)
	{
	
		// Get the message text
		char sBuffer[128];
		GetEventString(event, "text", sBuffer, sizeof(sBuffer), "");
		
		// If the message contains "The Tank" we can try to grab the Tank Percent from it
		if (StrContains(sBuffer, "The Tank", false) > -1)
		{	
			// Create a new int and find the percentage
			int percentage;
			percentage = GetPercentageFromText(sBuffer);
			
			// If GetPercentageFromText didn't return -1 that means it returned our boss percentage.
			// So, if it did return -1, something weird happened, set our boss to 0 for now.
			if (percentage > -1) {
				g_fTankPercent = percentage;
			} else {
				g_fTankPercent = 0;					
			} 
			
			// 不用保存上第一回合刷新位置
			// g_fDKRFirstRoundTankPercent = g_fTankPercent;
		}
		
		// If the message contains "The Witch" we can try to grab the Witch Percent from it
		if (StrContains(sBuffer, "The Witch", false) > -1)
		{
			// Create a new int and find the percentage
			int percentage;
			percentage = GetPercentageFromText(sBuffer);
			
			// If GetPercentageFromText didn't return -1 that means it returned our boss percentage.
			// So, if it did return -1, something weird happened, set our boss to 0 for now.
			if (percentage > -1){
				g_fWitchPercent = percentage;
			
			} else {
				g_fWitchPercent = 0;
			}
			
			// 不用保存上第一回合刷新位置
			// g_fDKRFirstRoundWitchPercent = g_fWitchPercent;
		}
		
		// Increase the amount of times we've done this function. We only want to do it twice. Once for each boss, for each map.
		//g_idkrwaAmount = g_idkrwaAmount + 1;
		
		// Check if both bosses have already been set 
		//if (g_idkrwaAmount > 1)
		//{
			// This function has been executed two or more times, so we should be done here for this map.
		//	g_bDKRFirstRoundBossesSet = true;
		//}
	}

	PrintBossPercents(1);
}