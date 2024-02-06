// 团队类型
enum
{
	TEAM_SPECTATOR = 1,
	TEAM_SURVIVOR,
	TEAM_INFECTED
}

// 感染者类型
enum
{
	ZC_SMOKER = 1,
	ZC_BOOMER,
	ZC_HUNTER,
	ZC_SPITTER,
	ZC_JOCKEY,
	ZC_CHARGER,
	ZC_WITCH,
	ZC_TANK,
}

// PreferredSpecialDirection 值
enum
{
	SPAWN_NO_PREFERENCE = -1,
	SPAWN_ANYWHERE,
	SPAWN_BEHIND_SURVIVORS,
	SPAWN_NEAR_IT_VICTIM,
	SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS,
	SPAWN_SPECIALS_ANYWHERE,
	SPAWN_FAR_AWAY_FROM_SURVIVORS,
	SPAWN_ABOVE_SURVIVORS,
	SPAWN_IN_FRONT_OF_SURVIVORS,
	SPAWN_VERSUS_FINALE_DISTANCE,
	SPAWN_LARGE_VOLUME,
	SPAWN_NEAR_POSITION
}

// Nav Area Spawn Attribute
enum
{
	EMPTY = 2,
	STOP_SCAN = 4,
	BATTLESTATION = 32,
	FINALE = 64,
	PLAYER_START = 128,
	BATTLEFIELD = 256,
	IGNORE_VISIBILITY = 512,
	NOT_CLEARABLE = 1024,
	CHECKPOINT = 2048,
	OBSCURED = 4096,
	NO_MOBS = 8192,
	THREAT = 16384,
	RESCUE_VEHICLE = 32768,
	RESCUE_CLOSET = 65536,
	ESCAPE_ROUTE = 131072,
	DOOR_OR_DESTROYED_DOOR = 262144,
	NOTHREAT = 524288,
	LYINGDOWN = 1048576,
	COMPASS_NORTH = 16777216,
	COMPASS_NORTHEAST = 33554432,
	COMPASS_EAST = 67108864,
	COMPASS_EASTSOUTH = 134217728,
	COMPASS_SOUTH = 268435456,
	COMPASS_SOUTHWEST = 536870912,
	COMPASS_WEST = 1073741824,
	COMPASS_WESTNORTH = -2147483648
}

enum
{
	ID_HUNTER,
	ID_CHARGER,
	ID_CHARGER_WALL,
	ID_CHARGER_GROUND,
	ID_PINNED_GETUPANIM_SIZE_SPACE
}
enum
{
	ID_SINGLE_PISTOL,
	ID_DUAL_PISTOLS,
	ID_INCAPANIM_SIZE_SPACE
}
enum SurvivorCharacter
{
	SC_INVALID = -1,
	SC_NICK = 0,
	SC_ROCHELLE,
	SC_COACH,
	SC_ELLIS,
	SC_BILL,
	SC_ZOEY,
	SC_LOUIS,
	SC_FRANCIS,
	SC_SIZE_SPACE
};
stock const char SurvivorModels[SC_SIZE_SPACE][] =
{
	"models/survivors/survivor_gambler.mdl",	// 西装
	"models/survivors/survivor_producer.mdl",	// 女人
	"models/survivors/survivor_coach.mdl",		// 黑胖
	"models/survivors/survivor_mechanic.mdl",	// 帽子
	"models/survivors/survivor_namvet.mdl",		// 比尔
	"models/survivors/survivor_teenangst.mdl",	// 佐伊
	"models/survivors/survivor_manager.mdl",	// 路易斯
	"models/survivors/survivor_biker.mdl"		// 弗朗西斯
};
stock const int GetUpAnimations[SC_SIZE_SPACE][ID_PINNED_GETUPANIM_SIZE_SPACE] =
{
	{620, 667, 671, 672},	// 西装
	{629, 674, 678, 679},	// 女人
	{621, 656, 660, 661},	// 黑胖
	{625, 671, 675, 676},	// 帽子
	{528, 759, 763, 764},	// 比尔
	{537, 819, 823, 824},	// 佐伊
	{528, 759, 763, 764},	// 路易斯
	{531, 762, 766, 767}	// 弗朗西斯
};
stock const int IncappAnimations[SC_SIZE_SPACE][ID_PINNED_GETUPANIM_SIZE_SPACE] =
{
	// 0 位为持单手枪倒地的动画序列，1 位为持双手枪倒地的动画序列
	{612, 613},	// 西装
	{621, 622},	// 女人
	{613, 614},	// 黑胖
	{617, 618},	// 帽子
	{520, 521},	// 比尔
	{525, 526},	// 佐伊
	{520, 521},	// 路易斯
	{523, 524}	// 弗朗西斯
};

stock static StringMap mSurvivorModelsTrie = null;

stock const float INFECTED_SIZE_MIN[][3] =
{
	{-20.0, -20.0, 0.0},
	{-25.0, -25.0, 0.0},
	{-25.0, -25.0, 0.0},
	{-20.0, -20.0, 0.0},
	{-20.0, -20.0, 0.0},
	{-25.0, -25.0, 0.0}
};
stock const float INFECTED_SIZE_MAX[ZC_CHARGER][3] =
{
	{20.0, 20.0, 80.0},
	{25.0, 25.0, 65.0},
	{25.0, 25.0, 60.0},
	{20.0, 20.0, 70.0},
	{20.0, 20.0, 40.0},
	{25.0, 25.0, 70.0}
};

#define PLUGIN_SCRIPTLOGIC "plugin_scripting_logic_entity"
#define COMMANDABOT_ATTACK "CommandABot({cmd = 0, bot = GetPlayerFromUserID(%i), target = GetPlayerFromUserID(%i)})"
#define COMMANDABOT_MOVE   "CommandABot({cmd = 1, pos = Vector(%f, %f, %f), bot = GetPlayerFromUserID(%i)})"
#define COMMANDABOT_RESET  "CommandABot({cmd = 3, bot = GetPlayerFromUserID(%i)})"

// *************************
// 			生还者
// *************************
// 判断是否有效玩家 id，有效返回 true，无效返回 false
// @client：需要判断的生还者客户端索引
stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
// 判断生还者是否有效，有效返回 true，无效返回 false
// @client：需要判断的生还者客户端索引
stock bool IsValidSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR);
}
// 判断玩家是否倒地，倒地返回 true，未倒地返回 false
// @client：需要判断的生还者客户端索引
stock bool IsClientIncapped(int client)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client)) { return false; }
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}
// 判断生还者是否被控，被控返回 true，未被控返回 false
// @client：需要判断的生还者客户端索引
stock bool IsClientPinned(int client)
{
	if (!IsValidSurvivor(client) || !IsPlayerAlive(client)) { return false; }
	return GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 
			|| GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 
			|| GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 || GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 
			|| GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0;
}
// 判断感染者是否正在控制生还者，正在控制返回 true，否则返回 false
// @client：需要判断的感染者客户端索引
stock bool IsPinningSurvivor(int client)
{
	if (!IsValidInfected(client) || !IsPlayerAlive(client)) { return false; }
	return GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0 || 
			GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0 || 
			GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0 || GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 || 
			GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0;
}
// 判断生还者被哪种类型的特感控制，生还者无效或未被控返回 -1
// @client：需要判断的生还者客户端索引
stock int GetClientPinnedInfectedType(int client)
{
	if (!IsValidClient(client)) { return -1; }
	else if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) { return ZC_SMOKER; }
	else if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) { return ZC_HUNTER; }
	else if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 || GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) { return ZC_CHARGER; }
	else if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) { return ZC_JOCKEY; }
	return -1;
}
// 判断生还者是否处于挂边状态，正在挂边返回 true，不在挂边返回 false
// @client：需要判断的生还者客户端索引
stock bool IsClientHanging(int client)
{
	if (!IsValidSurvivor(client)) { return false; }
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) || view_as<bool>(GetEntProp(client, Prop_Send, "m_isFallingFromLedge", 1)));
}
// 使用客户端 ID 识别生还者索引，有效返回生还者索引 ID，无效返回 -1
stock int IdentifySurvivor(int client)
{
	if (IsValidSurvivor(client))
	{
		char model_name[64] = {'\0'};
		GetClientModel(client, model_name, sizeof(model_name));
		return ModelToSorce(model_name);
	}
	return view_as<int>(SC_INVALID);
}
// 通过生还者模型名称返回生还者索引
stock int ModelToSorce(const char[] model_name)
{
	if (mSurvivorModelsTrie == null)
	{
		InitSurvivorModelTrie();
	}
	int sorce_index = -1;
	if (mSurvivorModelsTrie.GetValue(model_name, sorce_index))
	{
		return sorce_index;
	}
	return view_as<int>(SC_INVALID);
}
stock void InitSurvivorModelTrie()
{
	mSurvivorModelsTrie = new StringMap();
	for (int i = 0; i < view_as<int>(SC_SIZE_SPACE); i++)
	{
		mSurvivorModelsTrie.SetValue(SurvivorModels[i], i);
	}
}
// 获取当前客户端实血数量，返回实血数量，客户端无效则返回 -1
stock int GetPermanentHealth(int client)
{
	return IsValidClient(client) ? GetEntProp(client, Prop_Send, "m_iHealth") : -1;
}
// 获取当前生还者虚血数量，返回虚血数量，生还者无效则返回 -1
stock int GetSurvivorTempHealth(int client)
{
	if (!IsValidSurvivor(client)) { return -1; }
	int temp_health = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return temp_health > 0 ? temp_health : 0;
}
// 获取当前生还者倒地次数，返回倒地次数，生还者无效则返回 -1
stock int GetClientIncappedCount(int client)
{
	return IsValidSurvivor(client) ? GetEntProp(client, Prop_Send, "m_currentReviveCount") : -1;
}
// 随机获取一个生还者，可指定是否仅选择（未死亡，未被控，未倒地）的生还者，有则返回生还者 id，无则返回 0
// valid 参数为 false 仅过滤死亡生还者
stock int GetRandomSurvivorAndValid(int excludeSurvivor = -1, bool valid)
{
	ArrayList targetList = new ArrayList();
	int i;
	for(i = 1; i <= MaxClients; i++)
	{
		if (valid)
		{
			if (i == excludeSurvivor || !IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i) || IsClientIncapped(i) || IsClientPinned(i)) { continue; }
			targetList.Push(i);
		}
		else
		{
			if (i == excludeSurvivor || !IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) { continue; }
			targetList.Push(i);
		}
	}
	if (targetList.Length == 0)
	{
		delete targetList;
		return 0;
	}
	i = targetList.Get(GetRandomIntInRange(0, targetList.Length - 1));
	delete targetList;
	return i;
}
// 获取距离某玩家最近的有效（未死亡，未倒地，未被控）生还者，如有则返回生还者 id，玩家无效或未找到则返回 0
stock int GetClosetMobileSurvivor(int client, int exclude_client = -1)
{
	if (IsValidClient(client))
	{
		int target = -1;
		float selfPos[3] = {0.0}, targetPos[3] = {0.0};
		GetClientAbsOrigin(client, selfPos);
		// 遍历所有玩家
		ArrayList targetList = new ArrayList(2);
		for (int newTarget = 1; newTarget <= MaxClients; newTarget++)
		{
			// 找到了一个有效玩家
			if (IsValidSurvivor(newTarget) && IsPlayerAlive(newTarget) && !IsClientIncapped(newTarget) &&!IsClientPinned(newTarget) && newTarget != client && newTarget != exclude_client)
			{
				GetClientAbsOrigin(newTarget, targetPos);
				float dist = GetVectorDistance(selfPos, targetPos);
				targetList.Set(targetList.Push(dist), newTarget, 1);
			}
		}
		if (targetList.Length == 0)
		{
			delete targetList;
			return 0;
		}
		targetList.Sort(Sort_Ascending, Sort_Float);
		target = targetList.Get(0, 1);
		delete targetList;
		return target;
	}
	return 0;
}
// 获取距离某玩家最近的生还者，不无视倒地，被控，如有则返回生还者 id，玩家无效或未找到则返回 0
stock int GetClosetSurvivor(int client, int exclude_client = -1)
{
	if (!IsValidClient(client)) { return 0; }
	static int target;
	static float selfPos[3], targetPos[3];
	static ArrayList targetList;
	targetList = new ArrayList(2);
	GetClientAbsOrigin(client, selfPos);
	for (int newTarget = 1; newTarget <= MaxClients; newTarget++)
	{
		if (!IsClientInGame(newTarget) || !IsPlayerAlive(newTarget) || GetClientTeam(newTarget) != TEAM_SURVIVOR || newTarget == exclude_client) { continue; }
		GetClientAbsOrigin(newTarget, targetPos);
		targetList.Set(targetList.Push(GetVectorDistance(selfPos, targetPos)), newTarget, 1);
	}
	if (targetList.Length == 0)
	{
		delete targetList;
		return 0;
	}
	targetList.Sort(Sort_Ascending, Sort_Float);
	target = targetList.Get(0, 1);
	delete targetList;
	return target;
}
// 获取某个客户端到指定客户端的距离
stock int GetClientDistance(int source, int dest)
{
	if (!IsValidClient(source) || !IsValidClient(dest)) { return -1; }
	float selfPos[3], targetPos[3];
	GetClientAbsOrigin(source, selfPos);
	GetEntPropVector(dest, Prop_Send, "m_vecOrigin", targetPos);
	return RoundToNearest(GetVectorDistance(selfPos, targetPos));
}
// 获取某玩家到最近或指定生还者的距离，如果存在有效最近或指定生还者则返回距离，无则返回 -1
stock int GetClosetSurvivorDistance(int client, int specific_survivor = -1)
{
	if (!IsValidClient(client)) { return -1; }
	float selfPos[3] = {0.0}, targetPos[3] = {0.0};
	int target = -1;
	GetClientAbsOrigin(client, selfPos);
	if (IsValidSurvivor(specific_survivor)) { target = specific_survivor; }
	else { target = GetClosetMobileSurvivor(client); }
	if (!IsValidSurvivor(target)) { return -1; }
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPos);
	return RoundToNearest(GetVectorDistance(selfPos, targetPos));
}

// *************************
// 			特感方
// *************************
// 判断特感是否有效，有效返回 true，无效返回 false
stock bool IsValidInfected(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == TEAM_INFECTED;
}
// 判断是否 Bot 特感，是返回 true，否返回 false
stock bool IsBotInfected(int client)
{
	return IsValidInfected(client) && IsFakeClient(client);
}
// 获取特感类型，成功返回特感类型，失败返回 -1
stock int GetInfectedClass(int client)
{
	return IsValidInfected(client) ? GetEntProp(client, Prop_Send, "m_zombieClass") : -1;
}
// 判断特感是否处于灵魂状态，是返回 1，否返回 0，无效返回 -1
stock bool IsInGhostState(int client)
{
	return IsValidInfected(client) ? view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost")) : false;
}

// *************************
// 			其他类
// *************************
/*
 * @Description: 判断当前客户端是否在地面
 * @param: {client} 需要判断的客户端
 * @return: {bool} 
 */
stock bool IsClientOnGround(int client)
{
	return IsValidClient(client) && GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1;
}
/*
 * @Description: 获取客户端当前速度值，客户端无效则返回 -1.0
 * @param: {client} 需要获取速度的客户端
 * @return: {float} 
 */
stock float GetClientCurrentSpeed(int client)
{
	if (!IsValidClient(client)) { return -1.0; }
	float speedVector[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", speedVector);
	return SquareRoot(Pow(speedVector[0], 2.0) + Pow(speedVector[1], 2.0));
}

// 获取生还者数量，可指定是否包含 bot 和死亡的玩家
stock int GetSurvivorCount(bool include_bot = true, bool include_death = false)
{
	int count = 0;
	static int i;
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR) { continue; }
		if (!include_bot && IsFakeClient(i)) { continue; }
		if (!include_death && !IsPlayerAlive(i)) { continue; }
		count++;
	}
	return count;
}
// 检测某个坐标是否能被任意生还者看到，如果有一个生还者能看见这个位置，返回 true，所有生还者都不可见这个位置，返回 false
stock bool Pos_IsVisibleTo_Player(int self, float refpos[3])
{
	float target_pos[3] = {0.0};
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR) && IsPlayerAlive(client))
		{
			GetClientEyePosition(client, target_pos);
			Handle hTrace = TR_TraceRayFilterEx(refpos, target_pos, MASK_VISIBLE, RayType_EndPoint, TR_RayFilter, self);
			if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == client)
			{
				delete hTrace;
				hTrace = INVALID_HANDLE;
				return true;
			}
			delete hTrace;
			hTrace = INVALID_HANDLE;
		}
	}
	return false;
}
// 检测某个玩家是否能看到指定生还者，能看见返回 true，不能看见则返回 false
stock bool Player_IsVisible_To(int client, int target)
{
	float self_pos[3] = {0.0}, target_pos[3] = {0.0}, look_at[3] = {0.0}, vec_angles[3] = {0.0};
	GetClientEyePosition(client, self_pos);
	GetClientEyePosition(target, target_pos);
	MakeVectorFromPoints(self_pos, target_pos, look_at);
	GetVectorAngles(look_at, vec_angles);
	Handle hTrace = TR_TraceRayFilterEx(self_pos, vec_angles, MASK_VISIBLE, RayType_Infinite, TR_RayFilter, client);
	if (TR_DidHit(hTrace))
	{
		if(TR_GetEntityIndex(hTrace) == target)
		{
			delete hTrace;
			hTrace = INVALID_HANDLE;
			return true;
		}
	}
	delete hTrace;
	hTrace = INVALID_HANDLE;
	return false;
}
// 检测某个玩家是否能看到任意生还者，能看见返回 true，不能看见则返回 false
stock bool Player_IsVisible_To_AnyPlayer(int client)
{
	float self_pos[3] = {0.0};
	GetClientEyePosition(client, self_pos);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == view_as<int>(TEAM_SURVIVOR) && IsPlayerAlive(i))
		{
			float target_pos[3] = {0.0};
			GetClientEyePosition(i, target_pos);
			Handle hTrace = TR_TraceRayFilterEx(self_pos, target_pos, MASK_VISIBLE, RayType_EndPoint, TR_RayFilter, client);
			if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == i)
			{
				delete hTrace;
				hTrace = INVALID_HANDLE;
				return true;
			}
			delete hTrace;
			hTrace = INVALID_HANDLE;
		}
	}
	return false;
}
// 查找指定玩家指定范围内生还者或感染者团队成员数量，使用入参成员数组保存范围内的成员客户端索引，同时返回成员数量，无效则返回 -1
stock int Find_Ranged_Clients(int client, int[] targets, int team, float range, bool include_incapped = false, bool include_visible = true)
{
	// 检查入参合法性
	if (!IsValidClient(client) || team < view_as<int>(TEAM_SURVIVOR) || team > view_as<int>(TEAM_INFECTED))
	{
		return -1
	}
	int index = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && (GetClientTeam(i) == team) && IsPlayerAlive(i) && (!include_incapped && GetEntProp(i, Prop_Send, "m_isIncapacitated") != 1))
		{
			float self_pos[3] = {0.0}, target_pos[3] = {0.0};
			GetClientEyePosition(client, self_pos);
			GetClientEyePosition(i, target_pos);
			// 自身与目标距离小于给定范围
			if (GetVectorDistance(self_pos, target_pos) <= range)
			{
				if (include_visible)
				{
					Handle hTrace = TR_TraceRayFilterEx(self_pos, target_pos, MASK_VISIBLE, RayType_EndPoint, TR_RayFilter, client);
					if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == i)
					{
						targets[index] = i;
						index += 1;
					}
					continue;
				}
				targets[index] = i;
				index += 1;
			}
		}
	}
	return index;
}
// 射线碰撞过滤器，返回 true 则通过检测，返回 false 则不通过检测
stock bool TR_RayFilter(int entity, int mask, int self)
{
	return entity != self;
}
// 运行脚本命令
stock void Logic_RunScript(const char[] code, any ...)
{
	int scriptent = FindEntityByTargetname(-1, PLUGIN_SCRIPTLOGIC);
	if (!scriptent || !IsValidEntity(scriptent))
	{
		scriptent = CreateEntityByName("logic_script");
		DispatchKeyValue(scriptent, "targetname", PLUGIN_SCRIPTLOGIC);
		DispatchSpawn(scriptent);
	}
	char buffer[512] = {'\0'};
	VFormat(buffer, sizeof(buffer), code, 2);
	SetVariantString(buffer);
	AcceptEntityInput(scriptent, "RunScriptCode");
}
// 找到脚本实体
stock int FindEntityByTargetname(int index, const char[] name)
{
	for (int entity = index; entity < GetMaxEntities(); entity++)
	{
		if (IsValidEntity(entity))
		{
			char entname[128] = {'\0'};
			GetEntPropString(entity, Prop_Data, "m_iName", entname, sizeof(entname));
			if (strcmp(name, entname) == 0)
			{
				return entity;
			}
		}
	}
	return -1;
}
// 获取玩家当前速度向量长度，成功返回速度大小，失败返回 -1.0
stock float GetCurrentSpeed(int client)
{
	if (IsValidClient(client) && GetClientTeam(client) != view_as<int>(TEAM_SPECTATOR))
	{
		float vec_speed[3] = {0.0};
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vec_speed);
		return (SquareRoot(Pow(vec_speed[0], 2.0) + Pow(vec_speed[1], 2.0)));
	}
	return -1.0
}
// 获取当前是否在对抗第二轮
stock bool InVersusSecondRound()
{
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}
// KMP 算法求解子串位置，主串中存在子串返回子串出现索引，否则返回 -1
stock int KMPGetPatternIndex(const char[] mainString, const char[] pattern)
{
	int p1 = 0, p2 = 0, i = 2, last = 0, len1 = strlen(mainString), len2 = strlen(pattern);
	int[] next = new int[len2];
	// 人为规定 next[0] = -1，next[1] = 0
	next[0] = -1;
	next[1] = 0;
	while (i < len2)
	{
		if (pattern[i - 1] == pattern[last]) next[i++] = ++last;
		else if (last > 0) last = next[last];
		else pattern[i++] = 0;
	}
	// 遍历两个字符串
	while (p1 < len1 && p2 < len2)
	{
		if (mainString[p1] == pattern[p2])
		{
			p1++;
			p2++;
		}
		else if (next[p2] == -1) p1++;
		else p2 = next[p2];
	}
	return p2 == len2 ? p1 - len2 : -1;
}
/*
 * @Description: 播放指定声音文件给所有人
 * @param: {source} 声音文件路径
 * @return: {void} 
 */
stock void PlaySoundToAll(const char[] source)
{
	EmitSoundToAll(source, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}
/*
 * @Description: 播放指定声音文件给指定客户端
 * @param: {source} 声音文件路径
 * @param: {target} 指定客户端
 * @return: {void} 
 */
stock void PlaySoundToClient(const char[] source, int target)
{
	if (!IsValidClient(target)) { return; }
	EmitSoundToClient(target, source, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}
/*
 * @Description: 使用 FakeClientCommand 执行需要 s_cheats 1 权限的指令
 * @param: {client} 需要使用 FakeClientCommand 的客户端
 * @param: {command}: 指令头
 * @param: {options}: 指令参数
 * @return: {void}
 * 
 */
stock void ExecuteCheatCommand(int client, const char[] command, char[] options = "")
{
	if (!IsValidClient(client)) { return; }
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	if (strlen(options) > 0) { FakeClientCommand(client, "%s %s", command, options); }
	else { FakeClientCommand(client, "%s", command); }
	SetCommandFlags(command, flags);
}

// *************************
// 			向量类
// *************************
// 向量复制
stock void CopyVectors(float origin[3], float result[3])
{
	result[0] = origin[0];
	result[1] = origin[1];
	result[2] = origin[2];
}
// 向量置零
stock void ZeroVector(float origin[3])
{
	origin = NULL_VECTOR;
}
// 是否为零向量
stock bool IsZeroVector(float origin[3])
{
	return origin[0] == NULL_VECTOR[0] && origin[1] == NULL_VECTOR[1] && origin[2] == NULL_VECTOR[2];
}

// *************************
// 			数据类
// *************************
// 获取服务器 tickrate 值，成功返回 tickrate 值，失败返回 -1
stock int GetServerTickRate()
{
	int tick_rate = -1;
	if (tick_rate == -1 && IsServerProcessing())
	{
		tick_rate = RoundToNearest(1.0 / GetTickInterval());
	}
	return tick_rate;
}

// 获取随机范围内整数
stock int GetRandomIntInRange(int min, int max)
{
	int num = GetURandomInt();
	if (num == 0) { num++; }
	return RoundToCeil(float(num) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

// 获取随机范围内小数
stock float GetRandomFloatInRange(float min, float max)
{
	return (GetURandomFloat() * (max - min)) + min;
}

// *************************
// 			字符串类
// *************************

/*
 * @Description: 检查给定字符数组是否是空的字符串数组
 * @param: {string} 字符串数组
 * @param: {len} 字符串数组长度
 * @return: {bool} 
 */
stock bool isEmptyString(const char[] string, int len)
{
	int i;
	for (i = 0; i < len; i++) { if (string[i] != '\0') { return false; } }
	return true;
}