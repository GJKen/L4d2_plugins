/*
 * Revote Support for BuiltinVotes.  This plugin overrides basecommands if a BuiltinVotes vote is in progress.
 */

#include <sourcemod>
#include <builtinvotes>

public Plugin:myinfo = 
{
	name = "BuiltinVotes Revote",
	author = "Powerlord",
	description = "Adds support for sm_revote, /revote, and !revote commands to BuiltinVotes",
	version = "1.0",
	url = "https://forums.alliedmods.net/showthread.php?t=162164"
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	AddCommandListener(Command_Revote, "sm_revote");
}

public Action:Command_Revote(client, const String:command[], argc)
{
	if (IsBuiltinVoteInProgress())
	{
		if (!IsClientInBuiltinVotePool(client))
		{
			ReplyToCommand(client, "[BV] %t", "Cannot participate in vote");
			// Block basecommands from doing anything, also prevent the vote redraw
			return Plugin_Stop;
		}
		
		if (!RedrawClientBuiltinVote(client))
		{
			ReplyToCommand(client, "[BV] %t", "Cannot change vote");
		}
		
		// Block basecommands from doing anything.
		return Plugin_Stop;
	}
	
	// Not running, send back to basecommands.
	return Plugin_Continue;
}