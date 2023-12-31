/* Plugin Template generated by Pawn Studio */
#include <sourcemod>

new IMPULS_FLASHLIGHT 						= 100;
new Float:PressTime[MAXPLAYERS+1];
 
new Mode; 
new bool:EnableSuvivor; 
new bool:EnableInfected; 
new Handle:l4d_nt_team;

public Plugin:myinfo = 
{
	name = "Night Vision",
	author = "Pan Xiaohai & Mr. Zero",
	description = "<- Description ->",
	version = "1.0",
	url = "<- URL ->"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_ysy", sm_nightvision);
	l4d_nt_team = CreateConVar("l4d_nt_team", "3", "0:禁用，1:为幸存者和感染者启用，2:为幸存者启用，3:为感染者启用");	
	//AutoExecConfig(true, "l4d_nightvision"); 
	HookConVarChange(l4d_nt_team, ConVarChange);
	GetConVar();
	
}
public ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVar(); 
}
GetConVar()
{
	Mode=GetConVarInt(l4d_nt_team);
	EnableSuvivor=(Mode==1 || Mode==2);
	EnableInfected=(Mode==1 || Mode==3);
}
public Action:sm_nightvision(client,args)
{
	if(IsClientInGame(client))SwitchNightVision(client);
}
//code from "Block Flashlight",
public Action:OnPlayerRunCmd(client, &buttons, &impuls, Float:vel[3], Float:angles[3], &weapon)
{
	if(Mode==0)return;	
	if(impuls==IMPULS_FLASHLIGHT)
	{
		new team=GetClientTeam(client);
		if(team==2 && EnableSuvivor )
		{		 	
			new Float:time=GetEngineTime();
			if(time-PressTime[client]<0.3)
			{
				SwitchNightVision(client); 				 
			}
			PressTime[client]=time; 
			 
		}	 
		if(team==3 && EnableInfected)
		{				
			new Float:time=GetEngineTime();
			if(time-PressTime[client]>0.1)
			{
				SwitchNightVision(client); 
			}
			PressTime[client]=time;			 
		}
	}
}
SwitchNightVision(client)
{
	new d=GetEntProp(client, Prop_Send, "m_bNightVisionOn");
	if(d==0)
	{
		SetEntProp(client, Prop_Send, "m_bNightVisionOn",1); 
		PrintHintText(client, "夜视仪开启");
		
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_bNightVisionOn",0);
		PrintHintText(client, "夜视仪关闭");	
	}

}