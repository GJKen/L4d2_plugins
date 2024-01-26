# 📌允许玩家在非对抗模式下扮演特感及坦克

此功能需要安装2个插件:

<details><summary>control_zombies.smx</summary>

└─ 控制特感<br>
└─ **原作 [Github](https://github.com/umlka/l4d2/tree/3b9084b5a55b689bf9df409fdcf1a1109532c393/control_zombies)**, 无修改
</details>

<details><summary>l4d2_dominatorscontrol.smx</summary>

└─ 解除控制性特感数量限制<br>
└─ **原作 [Github](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/a89e98ab9f54ba4fb8f04d7af3135a339b7e8445/addons/sourcemod/scripting/l4d2_dominatorscontrol.sp#L4)**, 无修改
</details>

---

<details><summary>Command | 指令</summary>

|指令|功能|权限|
|-|-|-|
|`!team3`|切换到特感方|Console|
|`!team2`|切换到生还方|Console|
|`!pb`|提前叛变|Admin|
|`!pt`|转交坦克|Admin|
|`!tt`|接管坦克|Admin|
|`!class`|灵魂状态下更改特感类型或鼠标中键|Console|
|鼠标中键|非灵魂状态下管理员重置特感技能冷却时间|Admin|
---
</details>

Video | 影片展示
<br>None

Image | 图示
<br>None

<details><summary>ConVar | 控制台变量</summary>

<details><summary>[control_zombies.smx]</summary>

```sourcepawn
// 至少有多少名正常生还者(未被控,未倒地,未死亡)时,才允许玩家接管坦克
// Default: "1"
// Minimum: "0.000000"
cz_allow_survivor_limit "1"

// 在感染玩家进入灵魂状态后自动向其显示更改类型的菜单?(0=不显示,-1=每次都显示,大于0=每回合总计显示的最大次数)
// Default: "3"
// Minimum: "-1.000000"
cz_atuo_display_menu "3"

// sm_team2,sm_team3命令的冷却时间(0.0-无冷却)
// Default: "60.0"
// Minimum: "0.000000"
cz_cmd_cooldown_time "60.0"

// 特感玩家杀死生还者玩家后是否互换队伍?(0=否,1=是)
// Default: "0"
cz_exchange_team "0"

// 要达到什么免疫级别才能绕过sm_team2,sm_team3,sm_pb,sm_tt,sm_pt,sm_class,鼠标中键重置冷的使用限制
// Default: "99;99;99;99;99;99;99"
cz_immunity_levels "99;99;99;99;99;99;99"

// 抽取哪些玩家来接管坦克?(-1=由游戏自身控制,0=不抽取,1=叛变玩家,2=生还者,4=感染者)
// Default: "7"
cz_lot_target_player "7"

// 在哪些地图上才允许叛变和接管坦克(0=禁用叛变和接管坦克,1=非结局地图,2=结局地图,3=所有地图)
// Default: "3"
// Minimum: "0.000000"
cz_map_filter_tank "3"

// 坦克玩家达到多少后插件将不再控制玩家接管(0=不接管坦克)
// Default: "1"
// Minimum: "0.000000"
cz_max_tank_player "1"

// 换图,过关以及任务失败时是否自动将特感玩家切换到哪个队伍?(0=不切换,1=旁观者,2=生还者)
// Default: "0"
cz_pz_change_team_to "0"

// 特感玩家在ghost状态下切换特感类型是否进行血量惩罚(0.0=不惩罚.计算方式为当前血量乘以该值)
// Default: "0"
// Minimum: "0.000000"
cz_pz_punish_health "0"

// 特感玩家在ghost状态下切换特感类型后下次复活延长的时间(0=插件不会延长复活时间)
// Default: "0"
// Minimum: "0.000000"
cz_pz_punish_time "0"

// 特感玩家复活后自动处死的时间(0=不会处死复活后的特感玩家)
// Default: "120"
// Minimum: "0.000000"
cz_pz_suicide_time "120"

// 感染玩家数量达到多少后将限制使用sm_team3命令(-1=感染玩家不能超过生还玩家,大于等于0=感染玩家不能超过该值)
// Default: "-1"
// Minimum: "-1.000000"
cz_pz_team_limit "-1"

// 什么情况下sm_team2,sm_team3命令会进入冷却(1=使用其中一个命令,2=坦克玩家掉控,4=坦克玩家死亡,8=坦克玩家未及时重生,16=特感玩家杀掉生还者玩家,31=所有)
// Default: "31"
cz_return_enter_cooling "31"

// 准备叛变的玩家数量为0时,自动抽取生还者和感染者玩家的几率(排除闲置旁观玩家)(0.0=不自动抽取)
// Default: "100"
cz_survivor_allow_chance "100"

// 特感玩家看到的黑白状态生还者发光颜色
// Default: "255 255 255"
cz_survivor_color_blackwhite "255 255 255"

// 是否给生还者创发光建模型?(0=否,1=是)
// Default: "1"
cz_survivor_color_enable "1"

// 特感玩家看到的倒地状态生还者发光颜色
// Default: "180 0 0"
cz_survivor_color_incapacitated "180 0 0"

// 特感玩家看到的正常状态生还者发光颜色
// Default: "0 180 0"
cz_survivor_color_normal "0 180 0"

// 特感玩家看到的被Boomer喷或炸中过的生还者发光颜色
// Default: "155 0 180"
cz_survivor_color_nowit "155 0 180"

// 插件在控制玩家接管坦克后是否进入ghost状态
// Default: "1"
cz_takeover_ghost "1"

// 哪些标志能绕过sm_team2,sm_team3,sm_pb,sm_tt,sm_pt,sm_class,鼠标中键重置冷却的使用限制(留空表示所有人都不会被限制)
// Default: ";z;;z;z;;z"
cz_user_flagbits ";z;;z;z;;z"
```
---
</details>

<details><summary>[l4d2_dominatorscontrol.smx]</summary>

建议配置
```sourcepawn
//哪个受感染阶层被视为统治者
//1=Smoker, 2=Bommer, 4=Hunter, 8=Spitter, 16=Jockey, 32=Charger
sm_cvar l4d2_dominators 0

// 复活时间
sm_cvar z_ghost_delay_min 5
sm_cvar z_ghost_delay_max 10
sm_cvar z_ghost_delay_minspawn 0

// 复活最小距离
sm_cvar z_spawn_safety_range 1

// 特感数量限制
sm_cvar z_max_player_zombies 28
sm_cvar z_versus_smoker_limit 5
sm_cvar z_versus_boomer_limit 5
sm_cvar z_versus_hunter_limit 5
sm_cvar z_versus_spitter_limit 5
sm_cvar z_versus_jockey_limit 5
sm_cvar z_versus_charger_limit 5
```
</details>

---

</details>

<details><summary>Translation Support | 支持语言</summary>

```
简体中文
```
</details>

<details><summary>Apply to | 适用于</summary>

```php
L4D2 only
```
</details>

<details><summary>Require | 需求</summary>

1. [[L4D & L4D2] Left 4 DHooks Direct](https://forums.alliedmods.net/showthread.php?t=321696)
2. [Source Scramble](https://forums.alliedmods.net/showthread.php?t=317175)
</details>

<details><summary>Related Plugin | 相关插件</summary>

1. [Zombie Spawn Fix](https://forums.alliedmods.net/showthread.php?p=2751992) 防止加载卡特, 结局卡特, 特感玩家在玩家加载时无法从灵魂状态下重生以及`director_no_specials`设置为1时提示的重生已禁用
</details>

Changelog | 版本日志
<br>None