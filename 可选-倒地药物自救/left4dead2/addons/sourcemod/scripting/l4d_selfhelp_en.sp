#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0.1"

#define SOUND_KILL1  "/weapons/knife/knife_hitwall1.wav"
#define SOUND_KILL2  "/weapons/knife/knife_deploy.wav"

#define INCAP	         1
#define INCAP_GRAB	     2
#define INCAP_POUNCE     3
#define INCAP_RIDE		 4
#define INCAP_PUMMEL	 5
#define INCAP_EDGEGRAB	 6

#define TICKS 10
#define STATE_NONE 0
#define STATE_SELFHELP 1
#define STATE_OK 2
#define STATE_FAILED 3

new HelpState[MAXPLAYERS+1];
new HelpOhterState[MAXPLAYERS+1];
new Attacker[MAXPLAYERS+1];
new IncapType[MAXPLAYERS+1];
new Handle:Timers[MAXPLAYERS+1];

new Float:HelpStartTime[MAXPLAYERS+1];
  
new Handle:l4d_selfhelp_delay = INVALID_HANDLE;
new Handle:l4d_selfhelp_hintdelay = INVALID_HANDLE;
new Handle:l4d_selfhelp_durtaion = INVALID_HANDLE;

new Handle:l4d_selfhelp_incap = INVALID_HANDLE;
new Handle:l4d_selfhelp_grab = INVALID_HANDLE;
new Handle:l4d_selfhelp_pounce = INVALID_HANDLE;
new Handle:l4d_selfhelp_ride = INVALID_HANDLE;
new Handle:l4d_selfhelp_pummel = INVALID_HANDLE;
new Handle:l4d_selfhelp_edgegrab = INVALID_HANDLE;
new Handle:l4d_selfhelp_eachother = INVALID_HANDLE;
new Handle:l4d_selfhelp_pickup = INVALID_HANDLE;

new Handle:l4d_selfhelp_kill = INVALID_HANDLE;

new Handle:l4d_selfhelp_versus = INVALID_HANDLE;
new L4D2Version=false;
public Plugin:myinfo = 
{
	name = "Self Help ",
	author = "Pan Xiaohai",
	description = " ",
	version = PLUGIN_VERSION,	
}

public OnPluginStart()
{
	CreateConVar("l4d_selfhelp_version", PLUGIN_VERSION, " ", FCVAR_PLUGIN|FCVAR_DONTRECORD);
	
	l4d_selfhelp_incap = CreateConVar("l4d_selfhelp_incap", "3", " 倒地自救 ,  0:禁止, 1:止痛药、肾上腺素, 2:医疗包, 3:①②选项都可以", FCVAR_PLUGIN);
	l4d_selfhelp_grab = CreateConVar("l4d_selfhelp_grab", "3", " 被烟鬼控制自救,  0:禁止, 1:止痛药、肾上腺素, 2:医疗包, 3:①②选项都可以", FCVAR_PLUGIN);
	l4d_selfhelp_pounce = CreateConVar("l4d_selfhelp_pounce", "3", " 被猎人控制自救, 0:禁止, 1:止痛药、肾上腺素, 2:医疗包, 3:①②选项都可以", FCVAR_PLUGIN);
	l4d_selfhelp_ride = CreateConVar("l4d_selfhelp_ride", "3", " 被猴子控制自救, 0:禁止, 1:止痛药、肾上腺素, 2:医疗包, 3:①②选项都可以", FCVAR_PLUGIN);
	l4d_selfhelp_pummel = CreateConVar("l4d_selfhelp_pummel", "3", " 被大牛控制自救, 0:禁止, 1:止痛药、肾上腺素, 2:医疗包, 3:①②选项都可以", FCVAR_PLUGIN);
	l4d_selfhelp_edgegrab = CreateConVar("l4d_selfhelp_edgegrab", "3", " 挂边自救 , 0:禁止, 1:止痛药、肾上腺素, 2:医疗包, 3:①②选项都可以", FCVAR_PLUGIN);
	l4d_selfhelp_eachother = CreateConVar("l4d_selfhelp_eachother", "1", " 倒地互救 , 0: 禁止, 1 :启动", FCVAR_PLUGIN);
	l4d_selfhelp_pickup = CreateConVar("l4d_selfhelp_pickup", "1", " 倒地捡东西 , 0: 禁止, 1 :启动", FCVAR_PLUGIN);
	l4d_selfhelp_kill = CreateConVar("l4d_selfhelp_kill", "1", " 被控自救会杀死控制你的特感", FCVAR_PLUGIN);
	l4d_selfhelp_hintdelay = CreateConVar("l4d_selfhelp_hintdelay", "2", " 弹出提示的延时", FCVAR_PLUGIN);
	l4d_selfhelp_delay = CreateConVar("l4d_selfhelp_delay", "1", " 多少秒后可以自救", FCVAR_PLUGIN);
	l4d_selfhelp_durtaion = CreateConVar("l4d_selfhelp_durtaion", "3", " 自救需要多少秒", FCVAR_PLUGIN);
	l4d_selfhelp_versus = CreateConVar("l4d_selfhelp_versus", "1", " 对抗模式自救, 0:禁止, 1:启动", FCVAR_PLUGIN);	
	
	AutoExecConfig(true, "l4d_selfhelp_en");
	GameCheck();
 
	HookEvent("player_incapacitated", Event_Incap);

	HookEvent("lunge_pounce", lunge_pounce);
	HookEvent("pounce_stopped", pounce_stopped);
	
	HookEvent("tongue_grab", tongue_grab);
	HookEvent("tongue_release", tongue_release);

	HookEvent("player_ledge_grab", player_ledge_grab);

	HookEvent("round_start", RoundStart);
  	 
	if(L4D2Version)
	{
		HookEvent("jockey_ride", jockey_ride);
		HookEvent("jockey_ride_end", jockey_ride_end);
		
		HookEvent("charger_pummel_start", charger_pummel_start);
		HookEvent("charger_pummel_end", charger_pummel_end);
		 
	}

}
new GameMode;
GameCheck()
{
	decl String:GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	
	if (StrEqual(GameName, "survival", false))
		GameMode = 3;
	else if (StrEqual(GameName, "versus", false) || StrEqual(GameName, "teamversus", false) || StrEqual(GameName, "scavenge", false) || StrEqual(GameName, "teamscavenge", false))
		GameMode = 2;
	else if (StrEqual(GameName, "coop", false) || StrEqual(GameName, "realism", false))
		GameMode = 1;
	else
	{
		GameMode = 0;
 	}
	
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrEqual(GameName, "left4dead2", false))
	{
	 
		L4D2Version=true;
	}	
	else
	{
		 
		L4D2Version=false;
	}
}
public OnMapStart()
{
 	if(L4D2Version)	PrecacheSound(SOUND_KILL2, true) ;
	else PrecacheSound(SOUND_KILL1, true) ;
	 
}
public Action:RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	reset();
	return Plugin_Continue;
}
public lunge_pounce (Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GameMode==2 && GetConVarInt(l4d_selfhelp_versus)==0)return;
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!victim) return;
	if (!attacker) return;
	Attacker[victim] = attacker;
	IncapType[victim]=INCAP_POUNCE;
	if(	GetConVarInt(l4d_selfhelp_pounce)>0)
	{
		CreateTimer(GetConVarFloat(l4d_selfhelp_delay), WatchPlayer, victim);	
 		CreateTimer(GetConVarFloat(l4d_selfhelp_hintdelay), AdvertisePills, victim); 
	}
	//PrintToChatAll("start prounce"); 
}
public pounce_stopped (Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GameMode==2 && GetConVarInt(l4d_selfhelp_versus)==0)return;	
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	if (!victim) return;
	Attacker[victim] = 0;
	//PrintToChatAll("end prounce"); 
}
  public tongue_grab (Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GameMode==2 && GetConVarInt(l4d_selfhelp_versus)==0)return;
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!victim) return;
	if (!attacker) return;
	Attacker[victim] = attacker;
	IncapType[victim]=INCAP_GRAB;
	if(	GetConVarInt(l4d_selfhelp_grab)>0)
	{
 		CreateTimer(GetConVarFloat(l4d_selfhelp_delay), WatchPlayer, victim);	
 		CreateTimer(GetConVarFloat(l4d_selfhelp_hintdelay), AdvertisePills, victim); 
	}
}

public tongue_release (Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GameMode==2 && GetConVarInt(l4d_selfhelp_versus)==0)return;
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!victim) return;
	if (!attacker) return;
	if(Attacker[victim] ==attacker)
	{
		Attacker[victim] = 0;
	}
	//PrintToChatAll("end grab"); 

}
  public jockey_ride (Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GameMode==2 && GetConVarInt(l4d_selfhelp_versus)==0)return;
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!victim) return;
	if (!attacker) return;
	Attacker[victim] = attacker;
	IncapType[victim]=INCAP_RIDE;
	if(	GetConVarInt(l4d_selfhelp_ride)>0)
	{
 		CreateTimer(GetConVarFloat(l4d_selfhelp_delay), WatchPlayer, victim);	
 		CreateTimer(GetConVarFloat(l4d_selfhelp_hintdelay), AdvertisePills, victim); 
	}
	//PrintToChatAll("jockey_ride"); 
}

public jockey_ride_end (Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GameMode==2 && GetConVarInt(l4d_selfhelp_versus)==0)return;
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!victim) return;
	if (!attacker) return;
	if(Attacker[victim] ==attacker)
	{
		Attacker[victim] = 0;
	}
	//PrintToChatAll("jockey_ride_end"); 

}

 public charger_pummel_start (Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GameMode==2 && GetConVarInt(l4d_selfhelp_versus)==0)return;
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!victim) return;
	if (!attacker) return;
	Attacker[victim] = attacker;
	IncapType[victim]=INCAP_PUMMEL;
	if(	GetConVarInt(l4d_selfhelp_pummel)>0)
	{
 		CreateTimer(GetConVarFloat(l4d_selfhelp_delay), WatchPlayer, victim);	
 		CreateTimer(GetConVarFloat(l4d_selfhelp_hintdelay), AdvertisePills, victim); 
	}
	//PrintToChatAll("charger_pummel_start"); 
}

public charger_pummel_end (Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GameMode==2 && GetConVarInt(l4d_selfhelp_versus)==0)return;
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!victim) return;
	if (!attacker) return;
	if(Attacker[victim] ==attacker)
	{
		Attacker[victim] = 0;
	}
	//PrintToChatAll("charger_pummel_end"); 

}
 
public Event_Incap (Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GameMode==2 && GetConVarInt(l4d_selfhelp_versus)==0)return;
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	IncapType[victim]=INCAP;
	if(GetConVarInt(l4d_selfhelp_incap)>0)
	{
		CreateTimer(GetConVarFloat(l4d_selfhelp_delay), WatchPlayer, victim);	
 		CreateTimer(GetConVarFloat(l4d_selfhelp_hintdelay), AdvertisePills, victim); 
	}
}
public Action:player_ledge_grab(Handle:event, String:event_name[], bool:dontBroadcast)
{
	if(GameMode==2 && GetConVarInt(l4d_selfhelp_versus)==0)return;
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	IncapType[victim]=INCAP_EDGEGRAB;
	if(GetConVarInt(l4d_selfhelp_edgegrab)>0)
	{
		CreateTimer(GetConVarFloat(l4d_selfhelp_delay), WatchPlayer, victim);	
 		CreateTimer(GetConVarFloat(l4d_selfhelp_hintdelay), AdvertisePills, victim); 
 	}
}

 
public Action:WatchPlayer(Handle:timer, any:client)
{
 
 	if (!client) return;
	if (!IsClientInGame(client)) return;
	if (!IsPlayerAlive(client)) return;
	if (!IsPlayerIncapped(client) && !IsPlayerGrapEdge(client) && Attacker[client]==0 )return;
	
 	if(Timers[client]!=INVALID_HANDLE)return;
 
 	HelpOhterState[client]=HelpState[client]=STATE_NONE;

	Timers[client]=CreateTimer(1.0/TICKS, PlayerTimer, client, TIMER_REPEAT);
}
public Action:AdvertisePills(Handle:timer, any:client)
{
	
 	if (!client) return;
	if (!IsClientInGame(client)) return;
	if (!IsPlayerAlive(client)) return;
 
	if(CanSelfHelp(client))
	{
	    //PrintHintText(client, "[提示] 按住 Ctrl 键,使用药物自救.");
	}

}
bool:CanSelfHelp(client)
{
	new bool:pills=HavePills(client);
	new bool:kid=HaveKid(client);
	new bool:adrenaline=HaveAdrenaline(client);
	new bool:ok=false;
	new self;
	if(IncapType[client]==INCAP)
	{
		self=GetConVarInt( l4d_selfhelp_incap);
		if((self==1 || self==3) && (pills || adrenaline))ok=true;
		else if ((self==2 || self==3) && kid)ok=true;
	}
	else if(IncapType[client]== INCAP_EDGEGRAB)
	{
		self=GetConVarInt( l4d_selfhelp_edgegrab);
		if((self==1 || self==3) && (pills || adrenaline))ok=true;
		else if ((self==2 || self==3) && kid)ok=true;
	}
	else if(IncapType[client]== INCAP_GRAB)
	{
		self=GetConVarInt( l4d_selfhelp_grab);
		if((self==1 || self==3) && (pills || adrenaline))ok=true;
		else if ((self==2 || self==3) && kid)ok=true;
	}
	else if(IncapType[client]== INCAP_POUNCE)
	{
		self=GetConVarInt( l4d_selfhelp_pounce);
		if((self==1 || self==3) && (pills || adrenaline))ok=true;
		else if ((self==2 || self==3) && kid)ok=true;
	}
	else if(IncapType[client]== INCAP_RIDE)
	{
		self=GetConVarInt( l4d_selfhelp_ride);
		if((self==1 || self==3) && (pills || adrenaline))ok=true;
		else if ((self==2 || self==3) && kid)ok=true;
	}
	else if(IncapType[client]== INCAP_PUMMEL)
	{
		self=GetConVarInt( l4d_selfhelp_pummel);
		if((self==1 || self==3) && (pills || adrenaline))ok=true;
		else if ((self==2 || self==3) && kid)ok=true;
	}
	return ok;
}
SelfHelpUseSlot(client)
{
	new pills = GetPlayerWeaponSlot(client, 4);
	new kid=GetPlayerWeaponSlot(client, 3);
	new solt=-1;
	new self;
	if(IncapType[client]==INCAP)
	{
		self=GetConVarInt( l4d_selfhelp_incap);
		if((self==1 || self==3) && pills!=-1)solt=4;
		else if ((self==2 || self==3) && kid)solt=3;
	}
	else if(IncapType[client]== INCAP_EDGEGRAB)
	{
		self=GetConVarInt( l4d_selfhelp_edgegrab);
		if((self==1 || self==3) && pills!=-1)solt=4;
		else if ((self==2 || self==3) && kid)solt=3;
	}
	else if(IncapType[client]== INCAP_GRAB)
	{
		self=GetConVarInt( l4d_selfhelp_grab);
		if((self==1 || self==3) && pills!=-1)solt=4;
		else if ((self==2 || self==3) && kid)solt=3;
	}
	else if(IncapType[client]== INCAP_POUNCE)
	{
		self=GetConVarInt( l4d_selfhelp_pounce);
		if((self==1 || self==3) && pills!=-1)solt=4;
		else if ((self==2 || self==3) && kid)solt=3;
	}
	else if(IncapType[client]== INCAP_RIDE)
	{
		self=GetConVarInt( l4d_selfhelp_ride);
		if((self==1 || self==3) && pills!=-1)solt=4;
		else if ((self==2 || self==3) && kid)solt=3;
	}
	else if(IncapType[client]== INCAP_PUMMEL)
	{
		self=GetConVarInt( l4d_selfhelp_pummel);
		if((self==1 || self==3) && pills!=-1)solt=4;
		else if ((self==2 || self==3) && kid)solt=3;
	}
	return solt;
}

public Action:PlayerTimer(Handle:timer, any:client)
{
	new Float:time=GetEngineTime();
	 
	if (client==0 )
	{
		HelpOhterState[client]=HelpState[client]=STATE_NONE;
		Timers[client]=INVALID_HANDLE;
 		return Plugin_Stop;
	}
	if(!IsClientInGame(client) || !IsPlayerAlive(client)  ) 
	{
		HelpOhterState[client]=HelpState[client]=STATE_NONE;
		Timers[client]=INVALID_HANDLE;
 		return Plugin_Stop;
	}
 
	if( !IsPlayerIncapped(client) && !IsPlayerGrapEdge(client) && Attacker[client]==0)
	{
	
		HelpOhterState[client]=HelpState[client]=STATE_NONE;
		Timers[client]=INVALID_HANDLE;
 		return Plugin_Stop;
	}
	
	if(!IsPlayerIncapped(client) && !IsPlayerGrapEdge(client) && Attacker[client]!=0)
	{
 		if (!IsClientInGame(Attacker[client]) || !IsPlayerAlive(Attacker[client]))
		{
			HelpOhterState[client]=HelpState[client]=STATE_NONE;
			Timers[client]=INVALID_HANDLE;
			Attacker[client]=0;
 			return Plugin_Stop;
		}

	}
	if(HelpState[client]==STATE_OK )
	{
 		HelpOhterState[client]=HelpState[client]=STATE_NONE;
		Timers[client]=INVALID_HANDLE;
		return Plugin_Stop;
	}
 
	new buttons = GetClientButtons(client);
  
	new haveone=0;
	new PillSlot = GetPlayerWeaponSlot(client, 4);  
	new KidSlot=GetPlayerWeaponSlot(client, 3);
	if (PillSlot != -1)  
	{
		haveone++;
	}
	if(KidSlot !=-1)
	{
		if(HaveKid(client))haveone++;
 	}
	
	if(haveone>0)
	{
		if((buttons & IN_DUCK) ||  (buttons & IN_USE)) 
		{
			if(CanSelfHelp(client))
			{
				if(L4D2Version)
				{
					if(HelpState[client]==STATE_NONE)
					{
						HelpStartTime[client]=time;
						SetupProgressBar(client, GetConVarFloat(l4d_selfhelp_durtaion));
						//PrintHintText(client, "[提示] 你正在使用自救功能.");
					}
			
				}
				else
				{
					if(HelpState[client]==STATE_NONE) HelpStartTime[client]=time;
					ShowBar(client,"self help ", time-HelpStartTime[client], GetConVarFloat(l4d_selfhelp_durtaion));
				}
				HelpState[client]=STATE_SELFHELP;
				//PrintToChatAll("%f  %f", time-HelpStartTime[client], GetConVarFloat(l4d_selfhelp_durtaion));
				if( time-HelpStartTime[client]>GetConVarFloat(l4d_selfhelp_durtaion))
				{
					if(HelpState[client]!=STATE_OK)
					{
						SelfHelp(client);
						if(L4D2Version)KillProgressBar(client);
					}
				
				}					
			}
			else if(HelpState[client]==STATE_SELFHELP)
			{
				if(L4D2Version)KillProgressBar(client);
				HelpState[client]=STATE_NONE;
			}
		}
		else
		{
			if(HelpState[client]==STATE_SELFHELP)
			{
				if(L4D2Version)
				{
					KillProgressBar(client);
				}
				else 
				{
					ShowBar(client, "self help ", 0.0, GetConVarFloat(l4d_selfhelp_durtaion));
				}
				HelpState[client]=STATE_NONE;
			}
			
		}
	
	}
	else if(GetConVarInt(l4d_selfhelp_eachother)>0)
	{

		if ((buttons & IN_DUCK) ||  (buttons & IN_USE)) 
		{

			new Float:dis=50.0;
			new Float:pos[3];
			new Float:targetVector[3];
			GetClientEyePosition(client, pos);
			new bool:findone=false;
			new other=0;
			for (new target = 1; target <= MaxClients; target++)
			{
				if (IsClientInGame(target) && target!=client)
				{
					if (IsPlayerAlive(target))
					{
						if(GetClientTeam(target)==2 && (IsPlayerIncapped(target) || IsPlayerGrapEdge(target)))
						{ 
							GetClientAbsOrigin(target, targetVector);
							new Float:distance = GetVectorDistance(targetVector, pos);
							if(distance<dis)
							{
								findone=true;
								other=target;
								break;
							}
						}
					}
				}
			}
			if(findone)
			{
				decl String:msg[30];
				Format(msg, sizeof(msg), "[提示] 你正在帮助 %N 站起来.", other);
				if(HelpOhterState[client]==STATE_NONE)
				{
					if(L4D2Version) 
					{
						SetupProgressBar(client, GetConVarFloat(l4d_selfhelp_durtaion));
						PrintHintText(client, msg);											 
					}
					PrintHintText(other, "[提示] %N 正在帮助你站起来.", client);
					HelpStartTime[client]=time;
				}
				HelpOhterState[client]=STATE_SELFHELP;
			 
				if(!L4D2Version) ShowBar(client, msg, time-HelpStartTime[client], GetConVarFloat(l4d_selfhelp_durtaion));

				if(time-HelpStartTime[client]>GetConVarFloat(l4d_selfhelp_durtaion))
				{
					HelpOther(other, client);
					HelpOhterState[client]=STATE_NONE;
					if(L4D2Version) KillProgressBar(client);							
 				}

			}
			else
			{
				if(HelpOhterState[client]!=STATE_NONE)
				{
					if(L4D2Version) KillProgressBar(client);
					else ShowBar(client, "help other", 0.0, GetConVarFloat(l4d_selfhelp_durtaion));
				}
				HelpOhterState[client]=STATE_NONE;
			
			}
		}
		else
		{
			if(HelpOhterState[client]!=STATE_NONE)
			{
				if(L4D2Version) KillProgressBar(client);
				else ShowBar(client, "help other", 0.0, GetConVarFloat(l4d_selfhelp_durtaion));
			}
			HelpOhterState[client]=STATE_NONE;

		}
	}
 
	if ((buttons & IN_DUCK) && GetConVarInt(l4d_selfhelp_pickup)>0 ) 
	{	
		new bool:pickup=false;
		new Float:dis=100.0;
 		new ent = -1;
		if (PillSlot == -1)  
		{
 			decl Float:targetVector1[3];
			decl Float:targetVector2[3];
			GetClientEyePosition(client, targetVector1);
			ent=-1;
			while ((ent = FindEntityByClassname(ent,  "weapon_pain_pills" )) != -1)
			{
				if (IsValidEntity(ent))
				{
					GetEntPropVector(ent, Prop_Send, "m_vecOrigin", targetVector2);
					if(GetVectorDistance(targetVector1  , targetVector2)<dis)
					{
					 
						CheatCommand(client, "give", "pain_pills", "");
						RemoveEdict(ent);
						pickup=true;
						PrintHintText(client,"[提示] 你找到了止痛药.");
					
						break;
					}
				}
 			}
			if(!pickup)
			{
				ent = -1;
				while ((ent = FindEntityByClassname(ent,  "weapon_adrenaline" )) != -1)
				{
					if (IsValidEntity(ent))
					{
						GetEntPropVector(ent, Prop_Send, "m_vecOrigin", targetVector2);
						if(GetVectorDistance(targetVector1  , targetVector2)<dis)
						{
						 
							CheatCommand(client, "give", "adrenaline", "");
							RemoveEdict(ent);
							pickup=true;
							PrintHintText(client,"[提示] 你找到了肾上腺素.");
							
							break;
						}
					}
 				}

			}
		}
 		if (KidSlot == -1 && !pickup)  
		{
 			decl Float:targetVector1[3];
			decl Float:targetVector2[3];
			GetClientEyePosition(client, targetVector1);
			ent = -1;
			while ((ent = FindEntityByClassname(ent,  "weapon_first_aid_kit" )) != -1)
			{
				if (IsValidEntity(ent))
				{
					GetEntPropVector(ent, Prop_Send, "m_vecOrigin", targetVector2);
					if(GetVectorDistance(targetVector1  , targetVector2)<dis)
					{
						 
						CheatCommand(client, "give", "first_aid_kit", "");
						RemoveEdict(ent);
						pickup=true;
						PrintHintText(client,"[提示] 你找到了医疗包.");
						break;
					}
				}
 			}
		}
 		if (GetPlayerWeaponSlot(client, 1)==-1 && !pickup)  
		{
 			decl Float:targetVector1[3];
			decl Float:targetVector2[3];
			GetClientEyePosition(client, targetVector1);
			ent = -1;
			while ((ent = FindEntityByClassname(ent,  "weapon_pistol" )) != -1)
			{
				if (IsValidEntity(ent))
				{
					GetEntPropVector(ent, Prop_Send, "m_vecOrigin", targetVector2);
					if(GetVectorDistance(targetVector1  , targetVector2)<dis)
					{
 						CheatCommand(client, "give", "pistol", "");
						RemoveEdict(ent);
						pickup=true;
						PrintHintText(client,"[提示] 你找到了手枪.");
						break;
					}
				}
 			}
		}
	}
 	return Plugin_Continue;
}

SelfHelp(client)
{
 	 
 	if (!IsClientInGame(client) || !IsPlayerAlive(client) )
	{
		return;
	} 
	if( !IsPlayerIncapped(client) && !IsPlayerGrapEdge(client) && Attacker[client]==0) 
	{
		return;
	} 
	new bool:pills=HavePills(client);
 
	new bool:adrenaline=HaveAdrenaline(client);
	new slot=SelfHelpUseSlot(client);
	if(slot!=-1)
	{
		new weaponslot=GetPlayerWeaponSlot(client, slot);
		if(slot ==4)
		{
			if(GetConVarInt(l4d_selfhelp_kill)>0) KillAttack(client);
			RemovePlayerItem(client, weaponslot);

			ReviveClientWithPills(client);
			

			HelpState[client]=STATE_OK;
			
			if(adrenaline)	PrintToChatAll("\x04★ \x03%N \x05使用了肾上腺素自救.", client);  
			if(pills)	PrintToChatAll("\x04★ \x03%N \x05使用了止痛药自救.", client); 	
			//EmitSoundToClient(client, "player/items/pain_pills/pills_use_1.wav"); // add some sound

		}
		else if(slot==3)
		{
			if(GetConVarInt(l4d_selfhelp_kill)>0) KillAttack(client);
			RemovePlayerItem(client, weaponslot);
			 
			ReviveClientWithKid(client);
			
			HelpState[client]=STATE_OK;
			PrintToChatAll("\x04★★ \x03%N \x05使用了医疗包自救.", client); 
	 
			//EmitSoundToClient(client, "player/items/pain_pills/pills_use_1.wav"); // add some sound
		}

	}
	else 
	{
		PrintHintText(client, "自救失败");
		HelpState[client]=STATE_FAILED;
	}
 }
 HelpOther(client, helper)
{
 	 
 	if (!IsClientInGame(client) || !IsPlayerAlive(client) )
	{
		return;
	} 
	if( !IsPlayerIncapped(client) && !IsPlayerGrapEdge(client) && Attacker[client]==0) 
	{
		return;
	} 
	new propincapcounter = FindSendPropInfo("CTerrorPlayer", "m_currentReviveCount");
	new count = GetEntData(client, propincapcounter, 1);

		count++;
		if(count>2)count=2;
			
		new userflags = GetUserFlagBits(client);
		SetUserFlagBits(client, ADMFLAG_ROOT);
		new iflags=GetCommandFlags("give");
		SetCommandFlags("give", iflags & ~FCVAR_CHEAT);
		FakeClientCommand(client,"give health");
		SetCommandFlags("give", iflags);
		SetUserFlagBits(client, userflags);
			
		SetEntData(client, propincapcounter, count, 1);
			
		new Handle:revivehealth = FindConVar("pain_pills_health_value");  
	 
		new temphpoffset = FindSendPropOffs("CTerrorPlayer","m_healthBuffer");
		SetEntDataFloat(client, temphpoffset, GetConVarFloat(revivehealth), true);
		SetEntityHealth(client, 1);
 		PrintToChatAll("\x04★★★ \x03%N \x05使用倒地互救,帮助 \x03%N \x05站了起来.", helper, client);  
		//first(client);
 }
ReviveClientWithKid(client)
{
 
	new propincapcounter = FindSendPropInfo("CTerrorPlayer", "m_currentReviveCount");
 
		new userflags = GetUserFlagBits(client);
		SetUserFlagBits(client, ADMFLAG_ROOT);
		new iflags=GetCommandFlags("give");
		SetCommandFlags("give", iflags & ~FCVAR_CHEAT);
		FakeClientCommand(client,"give health");
		SetCommandFlags("give", iflags);
		SetUserFlagBits(client, userflags);
			
		SetEntData(client, propincapcounter, 0, 1);
			
		new Handle:revivehealth = FindConVar("first_aid_heal_percent"); 
		new temphpoffset = FindSendPropOffs("CTerrorPlayer","m_healthBuffer");
		SetEntDataFloat(client, temphpoffset, GetConVarFloat(revivehealth)*100.0, true);
		SetEntityHealth(client, 1);
}
ReviveClientWithPills(client)
{
 
	new propincapcounter = FindSendPropInfo("CTerrorPlayer", "m_currentReviveCount");
	new count = GetEntData(client, propincapcounter, 1);
	count++;
	if(count>2)count=2;
	CheatCommand(client, "give", "health", "");
	
	SetEntData(client, propincapcounter,count, 1);
	
	new Handle:revivehealth = FindConVar("pain_pills_health_value");  
	new temphpoffset = FindSendPropOffs("CTerrorPlayer","m_healthBuffer");
	SetEntDataFloat(client, temphpoffset, GetConVarFloat(revivehealth), true);
	SetEntityHealth(client, 1);
}
 
KillAttack(client)
{
	new a=Attacker[client];
	if(GetConVarInt(l4d_selfhelp_kill)==1 && a!=0)
	{
		if(IsClientInGame(a) && GetClientTeam(a)==3 &&  IsPlayerAlive(a))
		{
			ForcePlayerSuicide(a);		
			if(L4D2Version)	EmitSoundToAll(SOUND_KILL2, client); 
			else EmitSoundToAll(SOUND_KILL1, client); 
		}
	}
}

new String:Gauge1[2] = "-";
new String:Gauge3[2] = "#";
ShowBar(client, String:msg[], Float:pos, Float:max)	 
{
	new i ;
	new String:ChargeBar[100];
	Format(ChargeBar, sizeof(ChargeBar), "");
 
	new Float:GaugeNum = pos/max*100;
	if(GaugeNum > 100.0)
		GaugeNum = 100.0;
	if(GaugeNum<0.0)
		GaugeNum = 0.0;
 	for(i=0; i<100; i++)
		ChargeBar[i] = Gauge1[0];
	new p=RoundFloat( GaugeNum);
	 
	if(p>=0 && p<100)ChargeBar[p] = Gauge3[0]; 
 	/* Display gauge */
	PrintCenterText(client, "%s  %3.0f %\n<< %s >>", msg, GaugeNum, ChargeBar);
}
bool:HaveKid(client)
{
	decl String:weapon[32];
	new KidSlot=GetPlayerWeaponSlot(client, 3);
 
	if(KidSlot !=-1)
	{
		GetEdictClassname(KidSlot, weapon, 32);
		 if(StrEqual(weapon, "weapon_first_aid_kit"))
		 {
			 return true;
		 }
 	}
	return false;
}
bool:HavePills(client)
{
	decl String:weapon[32];
	new KidSlot=GetPlayerWeaponSlot(client, 4);
 
	if(KidSlot !=-1)
	{
		GetEdictClassname(KidSlot, weapon, 32);
		 if(StrEqual(weapon, "weapon_pain_pills"))
		 {
			 return true;
		 }
 	}
	return false;
}
bool:HaveAdrenaline(client)
{
	decl String:weapon[32];
	new KidSlot=GetPlayerWeaponSlot(client, 4);
 
	if(KidSlot !=-1)
	{
		GetEdictClassname(KidSlot, weapon, 32);
		 if(StrEqual(weapon, "weapon_adrenaline"))
		 {
			 return true;
		 }
 	}
	return false;
}


 
stock CheatCommand(client, String:command[], String:parameter1[], String:parameter2[])
{
	new userflags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s %s", command, parameter1, parameter2);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userflags);
}


bool:IsPlayerIncapped(client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1)) return true;
 	return false;
}
bool:IsPlayerGrapEdge(client)
{
 	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))return true;
	return false;
}
reset()
{
	for (new x = 0; x < MAXPLAYERS+1; x++)
	{
 			HelpOhterState[x]=HelpState[x]=STATE_NONE;
			Attacker[x]=0;
			HelpStartTime[x]=0.0;
			if(Timers[x]!=INVALID_HANDLE)
			{
				KillTimer(Timers[x]);
			 
			}
			Timers[x]=INVALID_HANDLE;
	}
}
stock SetupProgressBar(client, Float:time)
{
	//KillProgressBar(client);
	//SetEntPropEnt(client, Prop_Send, "m_reviveOwner", -1);
	SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", time);
	//SetEntPropEnt(client, Prop_Send, "m_reviveOwner", client);
	//SetEntPropEnt(client, Prop_Send, "m_reviveTarget", client);

}

stock KillProgressBar(client)
{
	//SetEntPropEnt(client, Prop_Send, "m_reviveOwner", -1);
	//SetEntityMoveType(client, MOVETYPE_WALK);
	//SetEntPropEnt(client, Prop_Send, "m_reviveTarget", 0);
	SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", 0.0);
	//SetEntPropEnt(client, Prop_Send, "m_reviveOwner", 0);
}
/*
public Action:sm_ht(client, args)
{
	new o=GetEntPropEnt(client, Prop_Send, "m_reviveOwner");
	new t=GetEntPropEnt(client, Prop_Send, "m_reviveTarget");
	if(o > 0 && t >0)	PrintToChatAll("onwer %N, target %N", o, t);
	else PrintToChatAll("onwer %d, target %d", o, t);
}
*/