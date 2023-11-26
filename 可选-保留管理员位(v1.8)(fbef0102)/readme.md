# Description | 內容
**📌保留管理员位置**

当服务器满人时, 管理员可以使用预留通道进入, 其他人加入会被踢出

Admin Reserved Slots (剩余通道只能管理員加入.. Sorry, Reserverd Slots for Admin..)

---
* Video | 影片展示
<br>None

* Image | 图示
<br>None

* <details><summary>Translation Support | 支持语言</summary>

	```
	English
	繁體中文
	简体中文
	```
</details>

* <details><summary>Changelog | 版本日志</summary>

	*v1.5
		*-Remake Code
		*-Add ConVars

	*v1.0
		*-Original Post: https://bbs.3dmgame.com/thread-2804070-1-1.html
</details>

* <details><summary>Require | 需求</summary>

	1. L4dtoolz
</details>

* Related Plugin | 相关插件
<br>None

* <details><summary>ConVar | 指令</summary>

	* cfg/sourcemod/l4d_reservedslots.cfg
	```
	// Reserved how many slots for Admin.(0=Off)
	//预留多少位置给管理員加入. (0=关闭)
	l4d_reservedslots_adm "1"

	// Players with these flags have access to use admin reserved slots. (Empty = Everyone, -1: Nobody)
	// 具有这些标志的玩家可以使用管理员保留的插槽 (空=每个人, -1:没有人)
	l4d_reservedslots_flag "z"

	// If set to 1, reserved slots will hidden (subtracted 'l4d_reservedslots_adm' from the max slot 'sv_maxplayers')
	//为 1时, 服务器会只会显示最大人数, 预留通道被隐藏
	//为0时, 服务器会显示最大人数+预留通道
	l4d_reservedslots_hide "1"
	```
</details>

* Command | 命令
<br>None