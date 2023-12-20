/*
*	https://github.com/LuxLuma/Left-4-fix/tree/master/left%204%20fix/Defib_Fix
*/

#if defined _Defib_Fix_included
#endinput
#endif
#define _Defib_Fix_included

/**
*	@Note only called if Defib_Fix is installed
*	
*	Deathmodels are "survivor_death_model" that can be used with defibrillator.
*
*	@param	iClient		Client Index who died.
*	@param	iDeathModel	Entity Index of Deathmodel for client who died
*	@no return
*/
forward void L4D2_OnSurvivorDeathModelCreated(int iClient, int iDeathModel);

public SharedPlugin __pl_Defib_Fix  =
{
    name = "Defib_Fix",
    file = "Defib_Fix.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
