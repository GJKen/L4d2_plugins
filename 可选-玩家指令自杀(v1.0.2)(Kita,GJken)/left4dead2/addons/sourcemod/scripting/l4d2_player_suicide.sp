#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <colors>

public Plugin myinfo =  
{
	name = "[L4D2] Player Suicide",
	author = "kita, GJKen",
	description = "玩家自杀指令",
	version = "1.0",
	url = "ni cai"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_zs", Kill_Survivor, "幸存者自杀指令");
	RegConsoleCmd("sm_kill", Kill_Survivor, "幸存者自杀指令");
}

public Action Kill_Survivor(int client, int args)
{
	if(IsSurvivor(client))
	{
		int Rand = GetRandomInt(0, 39);
		switch (Rand)
		{
			case 0: {
				CPrintToChatAll("天上突然打雷把 {blue}%N {default}劈死", client);
			}
			case 1: {
				CPrintToChatAll("{blue}%N {default}转到异世界当蜘蛛", client);
			}
			case 2: {
				CPrintToChatAll("{blue}%N {default}转到异世界当烧火棍", client);
			}
			case 3: {
				CPrintToChatAll(" {blue}%N {default}的枪走火把自己打死", client);
			}
			case 4: {
				CPrintToChatAll("{blue}%N {default}转到异世界成为平凡职业", client);
			}
			case 5: {
				CPrintToChatAll("Jockey用腿夹死了 {blue}%N", client);
			}
			case 6: {
				CPrintToChatAll("{blue}%N {default}为美好的L4D2献上祝福", client);
			}
			case 7: {
				CPrintToChatAll("{blue}%N {default}想和Spiter洗澡被毒死", client);
			}
			case 8: {
				CPrintToChatAll("{blue}%N {default}转到异世界当烧火棍", client);
			}
			case 9: {
				CPrintToChatAll("{blue}%N {default}被Hunter榨精死亡", client);
			}
			case 10: {
				CPrintToChatAll("{blue}%N {default}转到异世界当兽耳娘", client);
			}
			case 11: {
				CPrintToChatAll("{blue}%N {default}转到异世界当史莱姆", client);
			}
			case 12: {
				CPrintToChatAll("{blue}%N {default}偷偷闻了Witch的小穴幸福死", client);
			}
			case 13: {
				CPrintToChatAll("{blue}%N {default}转到异世界当魔王", client);
			}
			case 14: {
				CPrintToChatAll("{blue}%N {default}被Tank冲死", client);
			}
			case 15: {
				CPrintToChatAll("{blue}%N {default}转到异世界当盾之勇者", client);
			}
			case 16: {
				CPrintToChatAll("{blue}%N {default}不想活紫砂了", client);
			}
			case 17: {
				CPrintToChatAll("{blue}%N {default}转到异世界当舅舅", client);
			}
			case 18: {
				CPrintToChatAll("{blue}%N {default}想和Spitter舌吻中毒死", client);
			}
			case 19: {
				CPrintToChatAll("{blue}%N {default}转到异世界非常谨慎", client);
			}
			case 20: {
				CPrintToChatAll("{blue}%N {default}使用Bommer倒模冲晕了", client);
			}
			case 21: {
				CPrintToChatAll("{blue}%N {default}转到异世界当Magic Girl", client);
			}
			case 22: {
				CPrintToChatAll("{blue}%N {default}偷偷摸Witch奶子被反杀", client);
			}
			case 23: {
				CPrintToChatAll("{blue}%N {default}转到异世界当勇者", client);
			}
			case 24: {
				CPrintToChatAll("{blue}%N {default}抑郁紫砂了", client);
			}
			case 25: {
				CPrintToChatAll("{blue}%N {default}转到异世界当使魔", client);
			}
			case 26: {
				CPrintToChatAll("{default}Tank把 {blue}%N {default}手冲至死", client);
			}
			case 27: {
				CPrintToChatAll("{blue}%N {default}被Bommer臭死", client);
			}
			case 28: {
				CPrintToChatAll("{blue}%N {default}碰到了地雷被炸死", client);
			}
			case 29: {
				CPrintToChatAll("{blue}%N {default}转生成为OVERLORD", client);
			}
			case 30: {
				CPrintToChatAll("{blue}%N {default}被Bommer炸裂死亡", client);
			}
			case 31: {
				CPrintToChatAll("{blue}%N {default}转到异世界从零开始", client);
			}
			case 32: {
				CPrintToChatAll("{blue}%N {default}被Smoker捆绑Play,窒息死亡", client);
			}
			case 33: {
				CPrintToChatAll("{blue}%N {default}转到异世界当孔明", client);
			}
			case 34: {
				CPrintToChatAll("{blue}%N {default}嗝屁了", client);
			}
			case 35: {
				CPrintToChatAll("{blue}%N {default}转生后世界线变动了", client);
			}
			case 36: {
				CPrintToChatAll("牛牛突然冲过来把 {blue}%N {default}撅死", client);
			}
			case 37: {
				CPrintToChatAll("{blue}%N {default}今天没吃饭饿死了", client);
			}
			case 38: {
				CPrintToChatAll("{blue}%N {default}转到异世界当科比", client);
			}
			case 39: {
				CPrintToChatAll("{blue}%N {default}死亡后传送队友最后的波纹", client);
			}
			default: {
				CPrintToChatAll("%N {blue}死了", client);
			}
		}
		ForcePlayerSuicide(client);
	}
	return Plugin_Handled;
}

stock bool IsSurvivor(int client)
{
	if (client < 1 || client > MaxClients)
		return false;
	if (!IsClientConnected(client) || !IsClientInGame(client))
		return false;
	if (IsFakeClient(client))
		return false;
	if (!IsPlayerAlive(client))
		return false;
	if (GetClientTeam(client) != 2)
		return false;
		
	return true;
}