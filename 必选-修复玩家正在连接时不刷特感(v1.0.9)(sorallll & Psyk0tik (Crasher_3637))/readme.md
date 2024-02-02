📌 僵尸生成修复

**原作 [alliedmods](https://forums.alliedmods.net/showthread.php?t=333351**)

> 修复某些情况下特殊感染和玩家僵尸生成失败的问题

> 修补寻位函数以及玩家特感灵魂状态检测函数以使其放宽过滤条件或跳过某些条件限制

MemoryPatch(按需启用)
//转换期间生成失败
ZombieManager::CanZombieSpawnHere::IsInTransi tionCondition - Spawn failure during transition

//转换期间的玩家僵尸无法从幽灵状态重生
CTerrorPlayer::OnPreThinkGhostState::IsInTran sitionCondition - Player Zombie during transition cannot respawn from ghost state

//玩家僵尸无法重生，director_no_specials 设置为 1
CTerrorPlayer::OnPreThinkGhostState::SpawnDis abledCondition - Player Zombie fails to respawn with director_no_specials set to 1

//在结束地图中触发无线电期间生成失败
ZombieManager::AccumulateSpawnAreaCollection: :EnforceFinaleNavSpawnRulesCondition - Spawn failure during trigger radio in ending map

---

