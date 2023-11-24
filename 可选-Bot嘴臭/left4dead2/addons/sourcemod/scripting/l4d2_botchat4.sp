#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <colors>

#include <l4d2_skill_detect>

#define DEBUG 0
#define IS_VALID_INGAME(%1)	 (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_CLIENT(%1)	 (%1 > 0 && %1 <= MaxClients)
new	 bool:		   g_bLateLoad										 = false;
new	 Handle:		 g_hTrieEntityCreated								= INVALID_HANDLE;
new	 Handle:		 g_hWitchTrie										= INVALID_HANDLE;

new bool:g_bIsTankAlive;
new bool:IsRoundEnd;
new bool:DoorClosed;

new String:botchat[256];

// trie values: OnEntityCreated classname
enum strOEC
{
	OEC_WITCH
};


public Plugin:myinfo = 
{
	name = "L4D2 Bot Troll & Tank Sound",
	author = "Blazers Team",
	description = "Bot is now taunt?",
	version = "1.0",
	url = ""
};

public OnMapStart()
{
	PrecacheSound("ui/pickup_secret01.wav");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bLateLoad = late;	
	return APLRes_Success;
}


public OnPluginStart()
{
	HookEvent("survivor_rescued", SurvivorRescued);
	HookEvent("player_incapacitated", PlayerIncap);
	HookEvent("door_close", DoorClose);
	HookEvent("lunge_pounce", HunterCapped);
	HookEvent("player_entered_checkpoint", OnReachSafe);
	HookEvent("door_open",DoorOpen);
	HookEvent("friendly_fire",FriendlyFire);
	HookEvent("heal_begin",HealBegin);
	HookEvent("defibrillator_used",DefibrillatorUsed);
	//HookEvent("L4D_OnShovedBySurvivor",ShoveBySurvivor);
	//HookEvent("L4D_OnFirstSurvivorLeftSafeArea",PlayerGo);
	
	g_hWitchTrie = CreateTrie();
	g_hTrieEntityCreated = CreateTrie();
	SetTrieValue(g_hTrieEntityCreated, "witch", OEC_WITCH);
	
	if (g_bLateLoad) {
		for (new client = 1; client <= MaxClients; client++) {
			if (IS_VALID_INGAME(client)) {
				SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamageByWitch);
			}
		}
	}
	

	HookEvent("tank_spawn", EventHook:OnTankSpawn, EventHookMode_PostNoCopy);
	HookEvent("round_start", EventHook:OnRoundStart, EventHookMode_PostNoCopy);
}

public OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	IsRoundEnd = false;
	g_bIsTankAlive = false;
	DoorClosed = false;
}

// player damage tracking
public OnClientPostAdminCheck(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamageByWitch);
}
public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamageByWitch);
}

public OnTankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bIsTankAlive)
	{
		g_bIsTankAlive = true;
		EmitSoundToAll("ui/pickup_secret01.wav");
	}
}

public OnReachSafe(Handle:event, const String:name[], bool:dontBroadcast)
{
	IsRoundEnd = true;
}

public PlayerIncap(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidPlayer(client) && GetClientTeam(client) == 2 && !IsFakeClient(client))
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsValidPlayer(i))
			{
				if (IsFakeClient(i) && GetClientTeam(i) == 2)
				{
					switch (GetRandomInt(1, 37))
					{
						case 1:
						{
							Format(botchat,sizeof(botchat),"%N,杂鱼~你打的就是个JB,倒地还比老子快~",client);
						}
						case 2:
						{
							Format(botchat,sizeof(botchat),"杂鱼~又倒了,你是不是哈皮~");
						}
						case 3:
						{
							Format(botchat,sizeof(botchat),"太弱了~太弱了,这个生还者不行的啊~");
						}
						case 4:
						{
							Format(botchat,sizeof(botchat),"杂鱼~,怎么又有个杂鱼倒地了?");
						}
						case 5:
						{
							Format(botchat,sizeof(botchat),"%N,我是你爸爸~,快叫爸~我来扶你起来~",client);
						}
						case 6:
						{
							Format(botchat,sizeof(botchat),"%N好厉害哦~,倒地都是第一哦~,真的是太棒了呢~",client);
						}
						case 7:
						{
							Format(botchat,sizeof(botchat),"%N,你个杂鱼~再倒我们bot就跑分了,太菜受不了了~",client);
						}
						case 8:
						{
							Format(botchat,sizeof(botchat),"%N杂鱼~,我都比你厉害",client);
						}
						case 9:
						{
							Format(botchat,sizeof(botchat),"%N,你先躺着不要动,我去给你买几个橘子",client);
						}
						case 10:
						{
							Format(botchat,sizeof(botchat),"%N,NTMD又倒地了,WBNMSL真的!",client);
						}
						case 11:
						{
							Format(botchat,sizeof(botchat),"%N哥哥好棒哦~ 倒地都是第一个呢~ 这就是大佬吗,i了i了",client);
						}
						case 12:
						{
							Format(botchat,sizeof(botchat),"电脑人请求踢出:杂鱼~%N",client);
						}
						case 13:
						{
							Format(botchat,sizeof(botchat),"杂鱼~会不会玩?不会玩赶紧退了~");
						}
						case 14:
						{
							Format(botchat,sizeof(botchat),"杂鱼~你打的就是个锤子~");
						}
						case 15:
						{
							Format(botchat,sizeof(botchat),"好像有杂鱼~倒地,算了不管它~");
						}
						case 16:
						{
							Format(botchat,sizeof(botchat),"杂鱼~,拖累我们速度");
						}
						case 17:
						{
							Format(botchat,sizeof(botchat),"你咋不去死一死啊杂鱼~");
						}
						case 18:
						{
							Format(botchat,sizeof(botchat),"什么杂鱼~,咋又倒了~");
						}
						case 19:
						{
							Format(botchat,sizeof(botchat),"你是不是脑子有点问题?");
						}
						case 20:
						{
							Format(botchat,sizeof(botchat),"杂鱼~我要在你的头上拉屎!");
						}
						case 21:
						{
							Format(botchat,sizeof(botchat),"性感 ~%N~ 在线倒地",client);
						}
						case 22:
						{
							Format(botchat,sizeof(botchat),"~WRNM~");
						}
						case 23:
						{
							Format(botchat,sizeof(botchat),"能不能不扶他啊,每次都是他倒麻烦的一批");
						}
						case 24:
						{
							Format(botchat,sizeof(botchat),"求求你了杂鱼~,别倒地了SB");
						}
						case 25:
						{
							Format(botchat,sizeof(botchat),"看看 %N 摔了个狗啃泥",client);
						}
						case 26:
						{
							Format(botchat,sizeof(botchat),"杂鱼~,那么牛逼的吗");
						}
						case 27:
						{
							Format(botchat,sizeof(botchat),"嗯哼杂鱼~ 嗯哼杂鱼~");
						}
						case 28:
						{
							Format(botchat,sizeof(botchat),"跑分了,杂鱼~告辞");
						}
						case 29:
						{
							Format(botchat,sizeof(botchat),"杂鱼~这波啊,是满地找牙~");
						}
						case 30:
						{
							Format(botchat,sizeof(botchat),"你在赣深麽");
						}
						case 31:
						{
							Format(botchat,sizeof(botchat),"欸~,小杂鱼~你很骚啊~");
						}
						case 32:
						{
							Format(botchat,sizeof(botchat),"~WDNMD~");
						}
						case 33:
						{
							Format(botchat,sizeof(botchat),"臭杂鱼~,你妈死了");
						}
						case 34:
						{
							Format(botchat,sizeof(botchat),"你说你倒地,犯了错,你给我的信心动了火");
						}
						case 35:
						{
							Format(botchat,sizeof(botchat),"希望之花~~");
						}
						case 36:
						{
							Format(botchat,sizeof(botchat),"不要停下来啊!");
						}
						case 37:
						{
							Format(botchat,sizeof(botchat),"只见那霹雳闪电,一个人便倒了地");
						}
					}
					CPrintToChatAll("{blue}%N{default} :  %s", i, botchat);
				}
			}
		}
	}
}

public DoorOpen(Handle:event, const String:name[], bool:dontBroadcast)
{
	new bool:safedoor = GetEventBool(event, "checkpoint");
	if (safedoor)
	{
		if (!DoorClosed) DoorClosed = false;
	}
}

public DoorClose(Handle:event, const String:name[], bool:dontBroadcast)
{
	new bool:safedoor = GetEventBool(event, "checkpoint");
	if (safedoor && IsRoundEnd && !DoorClosed)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsClientConnected(i) || !IsValidPlayer(i)) return;
			if (IsFakeClient(i) && GetClientTeam(i) == 2)
			{
				switch (GetRandomInt(1, 13))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"杂鱼~对面特感太菜了!");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"SB特感给爷爬~");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"杂鱼~我们bot都能进屋");
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"弱智特感不灵的~");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"好家伙,对面这特感我狂吃两大碗");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"这波啊,这波是杂鱼特感太弱我们强");
					}
					case 7:
					{
						Format(botchat,sizeof(botchat),"杂鱼特感求求了,别让我们进屋吧");
					}
					case 8:
					{
						Format(botchat,sizeof(botchat),"杂鱼~,对面简直不值一提");
					}
					case 9:
					{
						Format(botchat,sizeof(botchat),"GG,NT,WP,GL,开玩笑的,怎么可能呢");
					}
					case 10:
					{
						Format(botchat,sizeof(botchat),"年度大戏:为什么bot能进屋,原来是杂鱼特感太菜了啊~");
					}
					case 11:
					{
						Format(botchat,sizeof(botchat),"加油加油接着送,我就喜欢这些,继续");
					}
					case 12:
					{
						Format(botchat,sizeof(botchat),"对面智商就在地下19层,连魔鬼都比他们聪明");
					}
					case 13:
					{
						Format(botchat,sizeof(botchat),"就这?就这?就这?就这?");
					}
					case 14:
					{
						Format(botchat,sizeof(botchat),"杂鱼~杂鱼~杂鱼~杂鱼~");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", i, botchat);
			}
		}
		DoorClosed = true;
	}
}

public OnBoomerPop( attacker, victim, shoveCount, Float:timeAlive )
{
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
		if (IsFakeClient(attacker))
		{
			switch (GetRandomInt(1, 4))
			{
				case 1:
				{
					Format(botchat,sizeof(botchat),"useless boomer");
				}
				case 2:
				{
					Format(botchat,sizeof(botchat),"lol noob boomer %N",victim);
				}
				case 3:
				{
					Format(botchat,sizeof(botchat),"不明所以... %N",victim);
				}
				case 4:
				{
					Format(botchat,sizeof(botchat),"我把在虐菜鸟");
				}
			}
			CPrintToChatAll("{blue}%N{default} :  %s", attacker, botchat);
		}
	}
}

public OnBoomerVomitLanded( boomer, amount )
{
	if (IsValidPlayer(boomer) && IsClientInGame(boomer))
	{
		if (IsFakeClient(boomer))
		{
			if (amount > 0)
				CPrintToChatAll("{red}Boomer{default}:欸嘿,炸了傻逼一脸屎");
		}
	}
}
public OnTankRockEaten( attacker, victim )
{
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsClientConnected(i) || !IsValidPlayer(i)) return;
			if (IsFakeClient(i) && GetClientTeam(i) == 2)
			{
				switch (GetRandomInt(1, 27))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"好吃,真好吃");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"你是饿了吗,这么急着找屎吃?");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"%N别吃了别吃了,吃不下了都",victim);
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"没吃饭吗?");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"这个饼真香啊,让你都要去恰一恰");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"别看了,别看了,赶紧卡控去吧,傻逼");
					}
					case 7:
					{
						Format(botchat,sizeof(botchat),"弱智,你TMD去躲着会死吗?");
					}
					case 8:
					{
						Format(botchat,sizeof(botchat),"又吃了个饼,真棒呢~ 再多吃点啊~");
					}
					case 9:
					{
						Format(botchat,sizeof(botchat),"说吧,对面给了你多少钱?");
					}
					case 10:
					{
						Format(botchat,sizeof(botchat),"你是不是腿脚不利索啊?");
					}
					case 11:
					{
						Format(botchat,sizeof(botchat),"下一届大胃王比赛没你我不看");
					}
					case 12:
					{
						Format(botchat,sizeof(botchat),"打不中就躲着嘛,恰饼干嘛?");
					}
					case 13:
					{
						Format(botchat,sizeof(botchat),"?");
					}
					case 14:
					{
						Format(botchat,sizeof(botchat),"我滚你妈的");
					}
					case 15:
					{
						Format(botchat,sizeof(botchat),"对面控制条被这傻逼回满了");
					}
					case 16:
					{
						Format(botchat,sizeof(botchat),"He Will He Will Rock You!");
					}
					case 17:
					{
						Format(botchat,sizeof(botchat),"我请你吃饭,你不要再吃饼了啦");
					}
					case 18:
					{
						Format(botchat,sizeof(botchat),"你这不随机硬辩一波?");
					}
					case 19:
					{
						Format(botchat,sizeof(botchat),"吃了几个了,嗨搁那吃吃吃呢");
					}
					case 20:
					{
						Format(botchat,sizeof(botchat),"咋不吃死你呢");
					}
					case 21:
					{
						Format(botchat,sizeof(botchat),"对面得亏碰到了这铁脑瘫");
					}
					case 22:
					{
						Format(botchat,sizeof(botchat),"走位,走位,欸嘿");
					}
					case 23:
					{
						Format(botchat,sizeof(botchat),"答应我,不要再吃了好不好");
					}
					case 24:
					{
						Format(botchat,sizeof(botchat),"绝对弱智,实属傻逼");
					}
					case 25:
					{
						Format(botchat,sizeof(botchat),"这石头你能吃到,你这是在地下十八层呢");
					}
					case 26:
					{
						Format(botchat,sizeof(botchat),"小老板很皮哦");
					}
					case 27:
					{
						Format(botchat,sizeof(botchat),"白给少年他来了");
					}
				}
				CPrintToChatAll("{blue}%N{default}:%s", i, botchat);
			}
		}
	}
	if (IsFakeClient(attacker) && IsValidPlayer(victim) && !IsFakeClient(victim))
			{
				switch (GetRandomInt(1, 20))
				{
					case 1:
					{
						CPrintToChatAll("{red}Tank{default}:好家伙,我个电脑Tank都能砸中你,你反思下");
					}
					case 2:
					{
						CPrintToChatAll("{red}Tank{default}:全垒打!");
					}
					case 3:
					{
						CPrintToChatAll("{red}Tank{default}:吃我跟踪石头!");
					}
					case 4:
					{
						CPrintToChatAll("{red}Tank{default}:能吃上我电脑的石头,你不是一个人");
					}
					case 5:
					{
						CPrintToChatAll("{red}Tank{default}:哇塞");
					}
					case 6:
					{
						CPrintToChatAll("{red}Tank{default}:WoW,我竟然扔中人了");
					}
					case 7:
					{
						CPrintToChatAll("{red}Tank{default}:Cyka Blyat!");
					}
					case 8:
					{
						CPrintToChatAll("{red}Tank{default}:Idi Nahui!");
					}
					case 9:
					{
						CPrintToChatAll("{red}Tank{default}:握着我的抱枕~");
					}
					case 10:
					{
						CPrintToChatAll("{red}Tank{default}:OH Shit");
					}
					case 11:
					{
						CPrintToChatAll("{red}Tank{default}:黑人抬走");
					}
					case 12:
					{
						CPrintToChatAll("{red}Tank{default}:我要再砸十个!");
					}
					case 13:
					{
						CPrintToChatAll("{red}Tank{default}:好球");
					}
					case 14:
					{
						CPrintToChatAll("{red}Tank{default}:你听听这声,多完美啊");
					}
					case 15:
					{
						CPrintToChatAll("{red}Tank{default}:Rock You!");
					}
					case 16:
					{
						CPrintToChatAll("{red}Tank{default}:C U Again!");
					}
					case 17:
					{
						CPrintToChatAll("{red}Tank{default}:只因我刚好遇见你~");
					}
					case 18:
					{
						CPrintToChatAll("{red}Tank{default}:我没想到,你会因为我吃了石头~");
					}
					case 19:
					{
						CPrintToChatAll("{red}Tank{default}:第一天,第一次呼吸畅快~");
					}
					case 20:
					{
						CPrintToChatAll("{red}Tank{default}:吼吼哈嘿~");
					}
				}
			}
}

public OnCarAlarmTriggered( attacker, victim )
{
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsClientConnected(i) || !IsValidPlayer(i)) return;
			if (IsFakeClient(i) && GetClientTeam(i) == 2)
			{
				switch (GetRandomInt(1, 8))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"你打你马警报呢");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"我把你妈杀了,咋把警报打了");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"%N,别打了别打了",attacker);
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"你牛逼,能打警报");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"SB东西,给爷爬");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"这60秒的警报你来负责,我们在旁边看戏");
					}
					case 7:
					{
						Format(botchat,sizeof(botchat),"要不是我打人没友伤,你早就倒了");
					}
					case 8:
					{
						Format(botchat,sizeof(botchat),"快滚吧,别玩了");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", i, botchat);
			}
		}
	}
}

public HunterCapped(Handle:event, const String:name[], bool:dontBroadcast)
{
	new hunter = GetClientOfUserId(GetEventInt(event, "userid"));
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	
	if (IsValidPlayer(hunter) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
		if (IsFakeClient(hunter))
		{
			switch (GetRandomInt(1, 8))
				{
					case 1:
					{
						CPrintToChatAll("{red}Hunter{default}:杂鱼就这?,我个AI Hunter都能扑倒你,你反思下");
					}
					case 2:
					{
						CPrintToChatAll("{red}Hunter{default}:杂鱼~杂鱼~,被我扑倒了吧~");
					}
					case 3:
					{
						CPrintToChatAll("{red}Hunter{default}:感谢杂鱼帮我实现扑中人的愿望");
					}
					case 4:
					{
						CPrintToChatAll("{red}Hunter{default}:嗯~~,骑在你身上很舒服 kimochi ii~~");
					}
					case 5:
					{
						CPrintToChatAll("{red}Hunter{default}:杂鱼~我要对你使用骑乘冲击");
					}
					case 6:
					{
						CPrintToChatAll("{red}Hunter{default}:走位,走位,杂鱼~打不着");
					}
					case 7:
					{
						CPrintToChatAll("{red}Hunter{default}:杂鱼~建议生还者直接自杀捏~");
					}
					case 8:
					{
						CPrintToChatAll("{red}Hunter{default}:杂鱼~我这灵巧的走位帅不帅捏");
					}
				}
			
		}
	}	
}

public OnSkeet( attacker, victim )
{
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
			if (!IsClientInGame(attacker) || !IsClientConnected(attacker) || !IsValidPlayer(attacker)) return;
			if (IsFakeClient(attacker) && GetClientTeam(attacker) == 2)
			{
				switch (GetRandomInt(1, 14))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"被我bot空爆咯,好气哦~");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"这个杂鱼Hunter有点菜");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"这个Hunter的轨迹堪称完美~");
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"EZ,我要打十个!");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"这个Hunter飞的跟个憨憨一样");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"傻逼Hunter,你别玩了");
					}
					case 7:
					{
						Format(botchat,sizeof(botchat),"这个Hunter很牛逼,牛逼在很像牛逼");
					}
					case 8:
					{
						Format(botchat,sizeof(botchat),"Boom,NiceShot!");
					}
					case 9:
					{
						Format(botchat,sizeof(botchat),"太菜了,太菜了!");
					}
					case 10:
					{
						Format(botchat,sizeof(botchat),"感谢Hunter送上的一个空爆");
					}
					case 11:
					{
						Format(botchat,sizeof(botchat),"就很舒服,欸嘿");
					}
					case 12:
					{
						Format(botchat,sizeof(botchat),"你看看你像话吗");
					}
					case 13:
					{
						Format(botchat,sizeof(botchat),"没有劲!这么直飞还想要来高扑!");
					}
					case 14:
					{
						Format(botchat,sizeof(botchat),"WA,我可真厉害");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", attacker, botchat);
			}
	}
}

public OnSkeetMelee( attacker, victim )
{
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
			if (!IsClientInGame(attacker) || !IsClientConnected(attacker) || !IsValidPlayer(attacker)) return;
			if (IsFakeClient(attacker) && GetClientTeam(attacker) == 2)
			{
				switch (GetRandomInt(1, 8))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"被我电脑近战空爆咯,好气哦~");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"这个Hunter有点菜,我拿近战都能打死他");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"这个Hunter的轨迹堪称完美~");
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"好家伙,这Hunter直接撞我近战上");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"Nice Melee-skeet!");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"好好反思你为什么会被电脑近战空爆");
					}
					case 7:
					{
						Format(botchat,sizeof(botchat),"白嫖25分爽到");
					}
					case 8:
					{
						Format(botchat,sizeof(botchat),"这个Hunter太憨了");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", attacker, botchat);
			}
	}
}

public OnSkeetMeleeHurt( attacker, victim )
{
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
			if (!IsClientInGame(attacker) || !IsClientConnected(attacker) || !IsValidPlayer(attacker)) return;
			if (IsFakeClient(attacker) && GetClientTeam(attacker) == 2)
			{
				switch (GetRandomInt(1, 8))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"被我电脑近战空爆咯,好气哦~");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"这个Hunter有点菜,我拿近战都能打死他");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"这个Hunter的轨迹堪称完美~");
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"好家伙,这Hunter直接撞我近战上");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"Nice Melee-skeet!");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"好好反思你为什么会被电脑近战空爆");
					}
					case 7:
					{
						Format(botchat,sizeof(botchat),"白嫖25分爽到");
					}
					case 8:
					{
						Format(botchat,sizeof(botchat),"这个Hunter太憨了");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", attacker, botchat);
			}
	}
}

public OnSkeetSniper( attacker, victim )
{
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
			if (!IsClientInGame(attacker) || !IsClientConnected(attacker) || !IsValidPlayer(attacker)) return;
			if (IsFakeClient(attacker) && GetClientTeam(attacker) == 2)
			{
				switch (GetRandomInt(1, 8))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"被我电脑爆头空爆咯,好气哦~");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"这个Hunter有点菜");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"这个Hunter的轨迹堪称完美~");
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"Nice!!!");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"看看我这自瞄,吴姐!");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"这个Hunter飞的太常规了!");
					}
					case 7:
					{
						Format(botchat,sizeof(botchat),"来嘛,来嘛!");
					}
					case 8:
					{
						Format(botchat,sizeof(botchat),"Boom,HeadShot!");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", attacker, botchat);
			}
	}
}

public OnSkeetSniperHurt( attacker, victim )
{
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
			if (!IsClientInGame(attacker) || !IsClientConnected(attacker) || !IsValidPlayer(attacker)) return;
			if (IsFakeClient(attacker) && GetClientTeam(attacker) == 2)
			{
				switch (GetRandomInt(1, 8))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"被我电脑爆头空爆咯,好气哦~");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"这个Hunter有点菜");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"这个Hunter的轨迹堪称完美~");
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"Nice!!!");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"看看我这自瞄,吴姐!");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"这个Hunter飞的太常规了!");
					}
					case 7:
					{
						Format(botchat,sizeof(botchat),"来嘛,来嘛!");
					}
					case 8:
					{
						Format(botchat,sizeof(botchat),"Boom,HeadShot!");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", attacker, botchat);
			}
	}
}

public OnHunterDeadstop( attacker, victim )
{
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
			if (!IsClientInGame(attacker) || !IsClientConnected(attacker) || !IsValidPlayer(attacker)) return;
			if (IsFakeClient(attacker) && GetClientTeam(attacker) == 2)
			{
				switch (GetRandomInt(1, 12))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"被我电脑推掉咯,好气哦~");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"随手一推,Hunter白飞");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"看看我这反应,把Hunter都推掉了");
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"小Hunter,再飞一个看看");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"别飞了,别飞了,我一手就把你整下来了");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"你的飞扑很精彩,我的推特更牛逼");
					}
					case 7:
					{
						Format(botchat,sizeof(botchat),"我要推十个!");
					}
					case 8:
					{
						Format(botchat,sizeof(botchat),"Bye~See yar Later~");
					}
					case 9:
					{
						Format(botchat,sizeof(botchat),"再强的Hunter在我的推下也得甘拜下风");
					}
					case 10:
					{
						Format(botchat,sizeof(botchat),"听说你想要25?");
					}
					case 11:
					{
						Format(botchat,sizeof(botchat),"我可真是太牛了");
					}
					case 12:
					{
						Format(botchat,sizeof(botchat),"这不把对面推翻天?");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", attacker, botchat);
			}
	}
}

public FriendlyFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
	new victim = GetClientOfUserId( GetEventInt(event, "victim") );
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(attacker))
	{
			if (!IsClientInGame(victim) || !IsClientConnected(victim) || !IsValidPlayer(victim)) return;
			if (IsFakeClient(victim) && GetClientTeam(victim) == 2)
			{
				switch (GetRandomInt(1, 8))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"会不会射枪啊?");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"CNMD射的是友军!");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"TMD,别射我,快停火!");
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"我说杂鱼,你是不是眼睛有点问题?");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"杂鱼!专家建议不会用枪就不要拿枪");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"杂鱼~别打了,杂鱼~别打了");
					}
					case 7:
					{
						Format(botchat,sizeof(botchat),"死杂鱼,别击中了友军");
					}
					case 8:
					{
						Format(botchat,sizeof(botchat),"杂鱼!把你那子弹打在丧尸上而不是我!!");
					}
					case 9:
					{
						Format(botchat,sizeof(botchat),"杂鱼!!!!!");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", victim, botchat);
			}
	}
}

public HealBegin(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId( GetEventInt(event, "userid") );
	new victim = GetClientOfUserId( GetEventInt(event, "subject") );
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(attacker))
	{
			if (!IsClientInGame(victim) || !IsClientConnected(victim) || !IsValidPlayer(victim)) return;
			if (IsFakeClient(victim) && GetClientTeam(victim) == 2)
			{
				switch (GetRandomInt(1, 12))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"我谢谢你哦,给bot打包真奢侈");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"滚蛋杂鱼~,我稀罕你那破包?");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"不用了不用了,真不用了");
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"你是不是按错键了?");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"大哥大哥,不至于不至于");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"我惊了,当儿子的竟然会给爸爸打包");
					}
					case 7:
					{
						Format(botchat,sizeof(botchat),"你这包还不如给你自己用");
					}
					case 8:
					{
						Format(botchat,sizeof(botchat),"拜托,我只是个bot,没那必要");
					}
					case 9:
					{
						Format(botchat,sizeof(botchat),"请把包留给有需要的人,谢谢");
					}
					case 10:
					{
						Format(botchat,sizeof(botchat),"推脱几下,BALA BALA,好了快打包吧");
					}
					case 11:
					{
						Format(botchat,sizeof(botchat),"感谢杂鱼~送上急救包,最喜欢你了~");
					}
					case 12:
					{
						Format(botchat,sizeof(botchat),"看我生龙活虎虐翻对面");
					}
					case 13:
					{
						Format(botchat,sizeof(botchat),"杂鱼~别对我的身体指手画脚");
					}
					case 14:
					{
						Format(botchat,sizeof(botchat),"杂鱼~这么喜欢摸我的身子~");
					}
					case 15:
					{
						Format(botchat,sizeof(botchat),"不用了谢谢,我的血量还能撑下去");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", victim, botchat);
			}
	}
}

public DefibrillatorUsed(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId( GetEventInt(event, "userid") );
	new victim = GetClientOfUserId( GetEventInt(event, "subject") );
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(attacker))
	{
			if (!IsClientInGame(victim) || !IsClientConnected(victim) || !IsValidPlayer(victim)) return;
			if (IsFakeClient(victim) && GetClientTeam(victim) == 2)
			{
				switch (GetRandomInt(1, 8))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"我谢谢你哦,给电脑电起来真奢侈");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"我起来了,我摸鱼,你们加油");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"起来都起来了,那就勉为其难的走走路吧");
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"我好感动啊,居然会有人来电我");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"这一套按摩很舒服~");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"啊拉,看来你还蛮喜欢bot捏~");
					}
					case 7:
					{
						Format(botchat,sizeof(botchat),"是不是队伍里有两个憨批才选择了电我?");
					}
					case 8:
					{
						Format(botchat,sizeof(botchat),"我才不会感谢你电我呢~(傲娇)");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", victim, botchat);
			}
	}
}

public OnHunterHighPounce( attacker, victim, actualDamage, Float:calculatedDamage, Float:height, bool:reportedHigh )
{
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsClientConnected(i) || !IsValidPlayer(i)) return;
			if (IsFakeClient(i) && GetClientTeam(i) == 2 && height > 400)
			{
				switch (GetRandomInt(1, 12))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"看看天上吧,弱智");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"好家伙,直接被砸了个25");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"%N您可光心关心四周吧",victim);
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"真好看,真好看");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"你是弱智吗?这个Hunter都搞不定");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"不会看路直接把眼睛扣下来");
					}
					case 7:
					{
						Format(botchat,sizeof(botchat),"又被砸了个25呢,真棒呢~ 再被多砸点啊~");
					}
					case 8:
					{
						Format(botchat,sizeof(botchat),"SB");
					}
					case 9:
					{
						Format(botchat,sizeof(botchat),"Hunter在天上,不是地上!");
					}
					case 10:
					{
						Format(botchat,sizeof(botchat),"埋了吧,没救了");
					}
					case 11:
					{
						Format(botchat,sizeof(botchat),"这波我看你怎么解释");
					}
					case 12:
					{
						Format(botchat,sizeof(botchat),"司马玩意,滚");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", i, botchat);
			}
		}
	}
}

public SurvivorRescued(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsValidPlayer(i))
		{
			if (IsFakeClient(i) && GetClientTeam(i) == 2)
			{
				switch (GetRandomInt(1, 6))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"太弱太弱,就这?就这?");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"好家伙,我狂吃十大碗饭");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"特感太菜了,救援都上了,超分了咯");
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"小葱拌豆腐,轻轻松松");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"弱智特感滚回去玩你的战役吧");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"傻逼特感,给爷爬");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", i, botchat);
			}
		}
	}
}

public Action: OnTakeDamageByWitch(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (IsValidPlayer(victim) && !IsFakeClient(victim)) 
	{
		if (IsWitch(attacker) && !isPlayerIncap(victim)) 
		{
			{
				switch (GetRandomInt(1, 50))
				{
					case 1:
					{
						CPrintToChatAll("{red}Witch{default}:杂鱼~会不会秒妹?");
					}
					case 2:
					{
						CPrintToChatAll("{red}Witch{default}:NMLGBD");
					}
					case 3:
					{
						CPrintToChatAll("{red}Witch{default}:杂鱼~我都秒不掉你去死吧~");
					}
					case 4:
					{
						CPrintToChatAll("{red}Witch{default}:杂鱼~,杂鱼~,杂鱼~,来一爪~");
					}
					case 5:
					{
						CPrintToChatAll("{red}Witch{default}:哇塞");
					}
					case 6:
					{
						CPrintToChatAll("{red}Witch{default}:好活,整的挺好");
					}
					case 7:
					{
						CPrintToChatAll("{red}Witch{default}:你别拿你那破枪了");
					}
					case 8:
					{
						CPrintToChatAll("{red}Witch{default}:Idi Nahui!");
					}
					case 9:
					{
						CPrintToChatAll("{red}Witch{default}:握着我的抱枕~");
					}
					case 10:
					{
						CPrintToChatAll("{red}Witch{default}:OH Shit");
					}
					case 11:
					{
						CPrintToChatAll("{red}Witch{default}:黑人抬走");
					}
					case 12:
					{
						CPrintToChatAll("{red}Witch{default}:杂鱼~你打的是个什么JB~");
					}
					case 13:
					{
						CPrintToChatAll("{red}Witch{default}:SB东西,给爷死");
					}
					case 14:
					{
						CPrintToChatAll("{red}Witch{default}:听说秒妹都不会的人脑壳都有点问题哦");
					}
					case 15:
					{
						CPrintToChatAll("{red}Witch{default}:我拿喷子都比你会秒妹");
					}
					case 16:
					{
						CPrintToChatAll("{red}Witch{default}:这波啊,这波是秒妹失败");
					}
					case 17:
					{
						CPrintToChatAll("{red}Witch{default}:你脑子有点问题,不过别担心,我给你P好了");
					}
					case 18:
					{
						CPrintToChatAll("{red}Witch{default}:整活带屎");
					}
					case 19:
					{
						CPrintToChatAll("{red}Witch{default}:NMMDW");
					}
					case 20:
					{
						CPrintToChatAll("{red}Witch{default}:全体起立!");
					}
					case 21:
					{
						CPrintToChatAll("{red}Witch{default}:杂鱼~你可以去死了!");
					}
					case 22:
					{
						CPrintToChatAll("{red}Witch{default}:想想你的队伍,怎么会出了你这么一个弱智");
					}
					case 23:
					{
						CPrintToChatAll("{red}Witch{default}:秒妹都整不明白,你滚蛋吧");
					}
					case 24:
					{
						CPrintToChatAll("{red}Witch{default}:还别说,你挺厉害的");
					}
					case 25:
					{
						CPrintToChatAll("{red}Witch{default}:不是把啊Sir,这都秒不掉");
					}
					case 26:
					{
						CPrintToChatAll("{red}Witch{default}:Cyka Blyat!");
					}
					case 27:
					{
						CPrintToChatAll("{red}Witch{default}:我替你队友说一句,WCNM");
					}
					case 28:
					{
						CPrintToChatAll("{red}Witch{default}:绝对弱智,实属傻逼,人间极品,康复脑瘫");
					}
					case 29:
					{
						CPrintToChatAll("{red}Witch{default}:杂鱼~专家建议不会秒妹就不要秒妹");
					}
					case 30:
					{
						CPrintToChatAll("{red}Witch{default}:杂鱼~我真服了你了");
					}
					case 31:
					{
						CPrintToChatAll("{red}Witch{default}:你这表现放我这里你可以死114514回了");
					}
					case 32:
					{
						CPrintToChatAll("{red}Witch{default}:是谁,在敲打我窗");
					}
					case 33:
					{
						CPrintToChatAll("{red}Witch{default}:我直接一抓把你这个憨批打飞");
					}
					case 34:
					{
						CPrintToChatAll("{red}Witch{default}:不好意思,刚刚把你妈打没了,请见谅");
					}
					case 35:
					{
						CPrintToChatAll("{red}Witch{default}:因为机枪秒不掉妹所以UZI不行");
					}
					case 36:
					{
						CPrintToChatAll("{red}Witch{default}:魔兽世界!这也秒不掉!");
					}
					case 37:
					{
						CPrintToChatAll("{red}Witch{default}:好送");
					}
					case 38:
					{
						CPrintToChatAll("{red}Witch{default}:不会吧,真有人连妹子都秒不掉吧");
					}
				}
			}
		}
	}
}

static bool:IsValidPlayer(client)
{
	if (0 < client <= MaxClients)
		return true;
	return false;
}

stock bool: IsWitch(entity)
{
	if (!IsValidEntity(entity)) {
		return false;
	}
	
	decl String: classname[24];
	new strOEC: classnameOEC;
	GetEdictClassname(entity, classname, sizeof(classname));

	return !(!GetTrieValue(g_hTrieEntityCreated, classname, classnameOEC) || classnameOEC != OEC_WITCH);
}


stock bool:isPlayerIncap(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}