# Description | 內容
**📌原作 [GitHub](https://github.com/umlka/l4d2/blob/main/map_changer/scripting/map_changer.sp)**, 自动换图插件

- 修改 `mapchanger_finale_change_type` 默认值为4(统计屏幕出现时换地图)
- 修改 `mapchanger_finale_failure_count` 默认值为0(终局团灭几次自动换到下一张图)
- 修改 `mapchanger_finale_random_nextmap` 默认值为1(终局是否启用随机下一关地图)
---
* Video | 影片展示
<br>None

* Image | 图示
<br>None

* Translation Support | 支持语言
<br>None

* Changelog | 版本日志
<br>None

* Require | 需求
<br>None

* <details><summary>Related Plugin | 相关插件</summary>

	- [投票换图(fdxx, sorallll)(v0.9)](https://github.com/GJKen/L4d2_plugins/tree/main/%E5%8F%AF%E9%80%89-%E6%8A%95%E7%A5%A8%E6%8D%A2%E5%9B%BE(fdxx%2C%20sorallll)(v0.9))
</details>

* <details><summary>ConVar | 指令</summary>
	
	* cfg/sourcemod/map_changer.cfg
	```php
	//0 - 终局不换地图(返回大厅); 1 - 救援载具离开时; 2 - 终局获胜时; 4 - 统计屏幕出现时; 8 - 统计屏幕结束时
	// Default: "12"
	mapchanger_finale_change_type "4"

	//终局团灭几次自动换到下一张图
	// Default: "2"
	mapchanger_finale_failure_count "0"

	//终局是否启用随机下一关地图
	// Default: "0"
	mapchanger_finale_random_nextmap "1"
	```
</details>

* <details><summary>Command | 命令</summary>

	`sm_nmaps` > 发起下一关地图投票, 仅限救援关投票
</details>