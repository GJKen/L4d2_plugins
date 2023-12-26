# 📌强化每个特感的行为与提高智商, 积极攻击幸存者

> Improves the behaviour of special infected

**原作 [GIthub](https://github.com/fbef0102/L4D2-Plugins/tree/c0d3044c996ee5c68ae544b3641c2412cea8d304/AI_HardSI)**


<details><summary>每个特感增效</summary>

<br>

<details><summary>Tank</summary>

靠近幸存者一定范围内不会主动丢石头

连跳
</details>

<details><summary>Witch</summary>

无
</details>

<details><summary>Smoker</summary>

插件官方的变量

```SourcePawn
// Smoker的舌头准备拉走幸存者的期间, 被攻击超过250HP或自身血量才会死亡 (预设: 50)
tongue_break_from_damage_amount 250

// 当幸存者靠近范围内的0.1秒后立刻吐舌头 (预设: 1.5)
smoker_tongue_delay 0.1
```
</details>

<details><summary>Boomer</summary>

插件官方的变量

```SourcePawn
// 被人类看见1000秒之后才会逃跑 (预设: 1.0)
boomer_exposed_time_tolerance 1000.0

// 当幸存者靠近范围内的0.1秒后立刻呕吐 (预设: 1.0)
boomer_vomit_delay 0.1
```
</details>

<details><summary>Hunter</summary>

被攻击的时候不会自动逃跑跳走 (只会出现在战役/写实模式)

插件官方的变量

```SourcePawn
// 1000公尺范围内才会蹲下准备扑人 (预设: 1000)
hunter_pounce_ready_range 1000

// 10000公尺范围内才会扑人 (预设: 75)
hunter_committed_attack_range 10000

// 0公尺范围内没有蹲下的Hunter被攻击时会逃跑跳走 (只会出现在战役/写实模式, 预设: 1000)
hunter_leap_away_give_up_range 0

// Hunter跳跃的最大倾角 (避免飞过头或飞太高, 预设: 45)
hunter_pounce_max_loft_angle 0

// Hunter飞扑在空中的过程中受到150HP伤害或自身血量以上才会死亡 (避免飞扑过程中容易被杀死, 预设: 50)
z_pounce_damage_interrupt 150
```
插件自带的变量

```SourcePawn
// 强迫Hunter在1000公尺范围内蹲下准备扑人
ai_fast_pounce_proximity 1000

// 强迫Hunter跳跃的最大倾角 (避免飞过头或飞太高)
ai_pounce_vertical_angle 7

// 强制左右飞扑靠近目标, 不要垂直飞向目标
ai_pounce_angle_mean 10
ai_pounce_angle_std 20

// 离目标200公尺范围内考虑直接垂直飞向目标
ai_straight_pounce_proximity 200

// 目标幸存者的准心如果在瞄自身Hunter的身体低于30度视野范围内则强制飞扑
ai_aim_offset_sensitivity_hunter 30

// 前面有墙壁的范围内则飞扑的角度会变高, 尝试越过障碍物 (-1: 无限范围)
ai_wall_detection_distance -1
```
</details>

<details><summary>Spitter</summary>

连跳
</details>

<details><summary>Jockey</summary>

插件官方的变量

```SourcePawn
// 1000公尺范围内才会飞扑 (预设: 200)
z_jockey_leap_range 1000
```
插件自带的变量

```SourcePawn
// 强迫Jockey在500公尺范围内开始连跳
ai_hop_activation_proximity 500
```
</details>

<details><summary>Charger</summary>

插件自带的变量

```SourcePawn
// 强迫Charger在300公尺范围内开始冲刺
ai_charge_proximity 300

// 目标幸存者的准心如果在瞄自身Charger的身体低于20度视野范围内则强制冲刺
ai_aim_offset_sensitivity_Charger 20
```
</details>
</details>

什么是 ```nb_assault```?
- 这是官方的指令, 强迫所有特感Bots主动往前攻击幸存者而非像智障一样待在原地等幸存者过来
- Server 没有开启 `sv_cheats` 作弊模式就不能输入这条指令
- 插件预设会每2秒执行这条指令

---
Command | 指令
<br>None

Video | 影片展示
<br/>None

Image｜ 图示
<br/>None<details><summary>ConVar | 控制台变量</summary>

cfg\sourcemod\AI_HardSI_fbef0102.cfg
```SourcePawn
// ConVars for plugin "AI_HardSI_fbef0102.smx"

// 触发"nb_assault"命令特感进行攻击的频率(秒)
ai_assault_reminder_interval "2"

// 改善Bommer行为, 0=关闭 1=开启
ai_hardsi_boomer_enable "1"

// 改善Charger行为, 0=关闭 1=开启
ai_hardsi_charger_enable "1"

// 改善Hunter行为, 0=关闭 1=开启
ai_hardsi_hunter_enable "1"

// 改善Jockey行为, 0=关闭 1=开启
ai_hardsi_jockey_enable "1"

// 改善Smoker行为, 0=关闭 1=开启
ai_hardsi_smoker_enable "1"

// 改善Spitter行为, 0=关闭 1=开启
ai_hardsi_spitter_enable "1"

// 改善Tank行为, 0=关闭 1=开启
ai_hardsi_tank_enable "1"

// 目标幸存者的准心如果在瞄自身Charger的身体低于20度视野范围内则强制冲刺
// 如果Charger有目标, 如果目标在水平轴上的瞄准点在此半径范围内, 则Charger不会直扑
ai_aim_offset_sensitivity_Charger "20"

// 强迫Charger在300公尺范围内开始冲刺
ai_charge_proximity "300"

// 如果Charger的健康状况降至此水平, 则会冲撞
ai_health_threshold_Charger "300"

// 如果Hunter有目标, 如果目标在横轴上的瞄准点在这个半径范围内, 它就不会直扑
ai_aim_offset_sensitivity_hunter "30"

// 强迫Hunter在1000公尺范围内蹲下准备扑人
ai_fast_pounce_proximity "1000"

// 强制左右飞扑靠近目标, 不要垂直飞向目标
ai_pounce_angle_mean "10" // 高斯 RNG 产生的平均角度
ai_pounce_angle_std "20" // 高斯 RNG 产生的平均值的一个标准差

// Hunter猛扑的垂直角度将会受到限制, 
// Hunter跳跃折角值, 越小Hunter跳跃角度越大
ai_pounce_vertical_angle "7"

// 前面有墙壁的范围内则飞扑的角度会变高, 尝试越过障碍物 (-1: 无限范围)
// 受感染的机器人将在自己前方多远的地方检查墙壁  使用 "-1"禁用功能
ai_wall_detection_distance "-1"

// Hunter距离最近的幸存者的距离值, 会考虑直接猛扑
ai_straight_pounce_proximity "200"

// 强迫Jockey在500公尺范围內开始连跳
ai_hop_activation_proximity "500"

// 启用Spitter连跳
ai_spitter_bhop "1"

// Tank连跳 0=关 1=开
ai_tank_bhop "0"

// 启用坦克岩石的标志
ai_tank_rock "1"

//------ 插件官方的变量 start ------//
// Smoker的舌头准备拉走幸存者的期间, 被攻击超过250HP或自身血量才会死亡 (预设: 50)
tongue_break_from_damage_amount 250

// 当幸存者靠近范围内的0.1秒后立刻吐舌头 (预设: 1.5)
smoker_tongue_delay 0.1

// 被人类看见1000秒之后才会逃跑 (预设: 1.0)
boomer_exposed_time_tolerance 1000.0

// 当幸存者靠近范围内的0.1秒后立刻呕吐 (预设: 1.0)
boomer_vomit_delay 0.1

// 1000公尺范围内才会蹲下准备扑人 (预设: 1000)
hunter_pounce_ready_range 1000

// 10000公尺范围内才会扑人 (预设: 75)
hunter_committed_attack_range 10000

// 0公尺范围内没有蹲下的Hunter被攻击时会逃跑跳走 (只会出现在战役/写实模式, 预设: 1000)
hunter_leap_away_give_up_range 0

// Hunter跳跃的最大倾角 (避免飞过头或飞太高, 预设: 45)
hunter_pounce_max_loft_angle 0

// Hunter飞扑在空中的过程中受到150HP伤害或自身血量以上才会死亡 (避免飞扑过程中容易被杀死, 预设: 50)
z_pounce_damage_interrupt 150

// 1000公尺范围内才会飞扑 (预设: 200)
z_jockey_leap_range 1000
//------ 插件官方的变量 end ------//

```
</details>

Translation Support | 支持语言
<br>None

<details><summary>Apply to | 适用于</summary>

```php
L4D2
```
</details>

<details><summary>Require | 需求</summary>

1. [[L4D & L4D2] Left 4 DHooks Direct](https://forums.alliedmods.net/showthread.php?t=321696)
</details>

<details><summary>Changelog | 版本日志</summary>

- v1.6 (2023-6-4)
	- Enable or Disable Each special infected behaviour

- v1.5 (2023-5-4)
	- Use server console to execute command "nb_assault"

- v1.4
	- Remake code
	- Replace left4downtown with left4dhooks
	- Compatibility support for SourceMod 1.11. Fixed various warnings.
</details>