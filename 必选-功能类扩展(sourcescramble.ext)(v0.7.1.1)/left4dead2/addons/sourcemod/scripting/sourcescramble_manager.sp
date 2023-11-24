/**
 * SourceScramble Manager
 * 
 * A loader for simple memory patches.
 */
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "1.2.0"
public Plugin myinfo =
{
	name = "Source Scramble Manager",
	author = "nosoop",
	description = "Helper plugin to load simple assembly patches from a configuration file.",
	version = PLUGIN_VERSION,
	url = "https://github.com/nosoop/SMExt-SourceScramble"
}

public void OnPluginStart()
{
	SMCParser parser = new SMCParser();
	parser.OnKeyValue = smcPatchMemConfigEntry;
	
	char configFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configFile, sizeof configFile, "configs/sourcescramble_manager.cfg");
	parser.ParseFile(configFile);
	
	char configDirectory[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configDirectory, sizeof configDirectory, "configs/sourcescramble");
	if (DirExists(configDirectory)) {
		DirectoryListing dlConfig = OpenDirectory(configDirectory, true);
		if (dlConfig) {
			char fileEntry[PLATFORM_MAX_PATH];
			FileType dirEntryType;
			while (dlConfig.GetNext(fileEntry, sizeof fileEntry, dirEntryType)) {
				if (dirEntryType != FileType_File)
					continue;

				FormatEx(configFile, sizeof configFile, "%s/%s", configDirectory, fileEntry);
				parser.ParseFile(configFile);
			}

			delete dlConfig;
		}
	}

	delete parser;
}

SMCResult smcPatchMemConfigEntry(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	GameData hGameData = new GameData(key);
	if (!hGameData) {
		LogError("Failed to load \"%s.txt\" gamedata.", key);
		return SMCParse_Continue;
	}

	// patches are cleaned up when the plugin is unloaded
	MemoryPatch patch = MemoryPatch.CreateFromConf(hGameData, value);
	delete hGameData;

	if (!patch.Validate())
		LogError("[sourcescramble] Failed to verify patch \"%s\" from \"%s\"", value, key);
	else if (patch.Enable())
		PrintToServer("[sourcescramble] Enabled patch \"%s\" from \"%s\" at address: 0x%08X", value, key, patch.Address);

	return SMCParse_Continue;
}
