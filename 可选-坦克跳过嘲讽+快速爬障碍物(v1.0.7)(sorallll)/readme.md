# 📌跳过坦克的嘲讽动画并加快攀爬障碍物动画

**原作 [alliedmods](https://forums.alliedmods.net/showthread.php?t=336707)**

> 自用重新编译, 添加原版没有的插件信息
---
Command | 指令
<br>None

Video | 影片展示
<br>None

Image | 图示
<br>None

<details><summary>ConVar | 控制台变量</summary>

cfg/sourcemod/skip_tank_taunt.cfg
```sourcepawn
// Obstacle animation playback rate
// 障碍物动画播放速率
tank_animation_playbackrate "5.0" 
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

Related Plugin | 相关插件
<br>None

<details><summary>Changelog | 版本日志</summary>

- 1.0.7 (20-Oct-2022)
	- Fixed using the wrong tank type in L4D1

- 1.0.6 (20-Oct-2022)
	- Added L4D1 support
	- Thanks to Silvers for help with coding

- 1.0.5 (11-Apr-2022)
	- Use the AnimHookEnable function in left4dhooks instead

- 1.0.4 (10-Mar-2022)
	- Fix 'Client 3 is not in game' error
</details>