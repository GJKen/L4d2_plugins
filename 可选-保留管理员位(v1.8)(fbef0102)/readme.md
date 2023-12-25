# 📌保留管理员位置

> Admin Reserved Slots

**原作 [Github](https://github.com/fbef0102/L4D1_2-Plugins/blob/master/l4d_reservedslots), 未任何修改**

当服务器满人时, 管理员可以使用预留通道进入, 其他人加入会被踢出

>(剩余通道只能管理员加入.. Sorry, Reserverd Slots for Admin..)
---
Command | 指令
<br>None

Video | 影片展示
<br>None

Image | 图示
<br>None

<details><summary>ConVar | 控制台变量</summary>

cfg/sourcemod/l4d_reservedslots.cfg
```sourcepawn
// Reserved how many slots for Admin.(0=Off)
// 预留多少位置给管理员加入. (0=关闭)
l4d_reservedslots_adm "1"

// Players with these flags have access to use admin reserved slots. (Empty = Everyone, -1: Nobody)
// 具有这些标志的玩家可以使用管理员保留的插槽 (空=每个人, -1:没有人)
l4d_reservedslots_flag "z"

// If set to 1, reserved slots will hidden (subtracted 'l4d_reservedslots_adm' from the max slot 'sv_maxplayers')
// 为1时, 服务器会只会显示最大人数, 预留通道被隐藏
// 为0时, 服务器会显示最大人数+预留通道
l4d_reservedslots_hide "1"
```
</details>

<details><summary>Translation Support | 支持语言</summary>

```
English
繁體中文
简体中文
```
</details>

<details><summary>Require | 需求</summary>

1. L4dtoolz
</details>

Related Plugin | 相关插件
<br>None

<details><summary>Changelog | 版本日志</summary>

- v1.8 (2023-8-18)
	- Remake code

- v1.6 (2023-8-17)
	- Fixed server kicks all players when map change

- v1.5 (2023-7-1)
	- Require lef4dhooks v1.33 or above
	- Remake code, convert code to latest syntax
	- Fix warnings when compiling on SourceMod 1.11.
	- Optimize code and improve performance
	- Translation Support

- v1.0 (2023-5-3)
	- [Original Plugin by fenghf](https://bbs.3dmgame.com/thread-2804070-1-1.html)
</details>