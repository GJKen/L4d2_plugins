# 📌反弹队友伤害

**原作 [Github](https://github.com/fbef0102/L4D1_2-Plugins/tree/master/anti-friendly_fire), 无修改**

---

Command | 指令
<br>None

Video | 影片展示
<br>None

Image | 图示
<br>None

<details><summary>ConVar | 控制台变量</summary>

cfg/sourcemod/anti-friendly_fire.cfg
```php
// 启用插件? 0=关 1=开
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
anti_friendly_fire_enable "1"

// 友伤 x 数值，然后再反弹 (1.0 = 反弹一样的伤害)
// Default: "1.5"
// Minimum: "1.000000"
anti_friendly_fire_damage_multi "1.0"

// 友伤低于此数值时,不造成友伤也不反弹友伤 0=关
// Default: "0"
// Minimum: "0.000000"
anti_friendly_fire_damage_sheild "0"

// 1=土制炸弹,瓦斯罐,氧气罐不造成友伤也不反弹友伤
// 0=恢复正常
// Default: "0"
// Minimum: "0.000000"
// Maximum: "1.000000"
anti_friendly_fire_immue_explode "0"

// 1=汽油,油桶,烟花盒不造成友伤也不反弹友伤
// 0=恢复正常
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
anti_friendly_fire_immue_fire "0"

// 1=榴弹发射器不造成友伤并反弹友伤(仅限L4D2) 
// 0=启动友伤
anti_friendly_fire_immue_GL "1"
```
</details>

Translation Support | 支持语言
<br>None

<details><summary>Apply to | 适用于</summary>

```php
L4D1
L4D2
```
</details>

<details><summary>Require | 需求</summary>

1. [[L4D & L4D2] Left 4 DHooks Direct](https://forums.alliedmods.net/showthread.php?t=321696)
</details>

Related Plugin | 相关插件</summary>
<br>None

<details><summary>Changelog | 版本日志</summary>

- v1.7 (2023-12-17)
	- Optimize code and improve performance

- v1.6 (2023-11-18)
	- Add grenade launcher damage

- v1.5 (2022-12-6)
	- Disable Pipe Bomb Explosive friendly fire
	- Disable Fire friendly fire.
	- Friendly fire now will not incap player
</details>