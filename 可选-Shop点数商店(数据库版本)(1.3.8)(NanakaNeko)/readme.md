# Description | 內容
**📌感谢原作 [Github](https://github.com/NanakaNeko/l4d2_plugins_coop/blob/main/scripting/shop.sp "Github"), 基于源码增加了sm_rank直接显示个人数据的功能<br>
Shop点数商店, 每关提供几次机会白嫖部分武器, cvar可自行设定每关几次<br>
<br>
采用sqlite数据库保存数据, 功能和shop一样<br>
安装过插件的, 建议删除data/sqlite文件夹下的数据库文件, 再更新插件重建数据库表**

- - - -
* Video | 影片展示
<br>None

* Image | 图示
<br>None

* <details><summary>Translation Support | 支持语言</summary>

	```php
	简体中文
	```
</details>

* <details><summary>Changelog | 版本日志</summary>

	*  1.1.1 重构代码, 数据库增加点数, 救援关通关加1点, 增加医疗物品和投掷物品的购买
	
	* 1.1.3 增加死亡重置次数开关, 增加医疗物品购买上限, 提供设置获取点数cvar
		
	* 1.2.0 增加击杀坦克和女巫获取点数
		
	* 1.2.2 增加传送菜单
		
	* 1.2.7 投掷修改为杂项, 增加激光瞄准
		
	* 1.3.1 杂项增加子弹补充
		
	* 1.3.2 增加快捷买药, 随机单喷
		
	* 1.3.4 增加inc文件提供其他插件支持, 个人信息面板, 显示累计得分, 击杀僵尸、特感、坦克、女巫数量
		
	* 1.3.6 增加爆头率、累计黑枪
		
	* 1.3.8 新增服务器游玩时长统计
</details>

* Require | 需求
<br>None

* <details><summary>Related Plugin | 相关插件</summary>

	1. [shop_lite](https://github.com/NanakaNeko/l4d2_plugins_coop/blob/main/scripting/shop_lite.sp)
</details>

* <details><summary>ConVar | 指令</summary>

	* cfg/sourcemod/l4dinfectedbots.cfg
	```php
	// 救援通关获得的点数
	// Default: "2"
	// Minimum: "0.000000"
	//l4d2_get_point "5"
	
	// 击杀坦克或者女巫获得的点数
	// Default: "1"
	// Minimum: "0.000000"
	//l4d2_get_point_kill "2"
	
	// 补充子弹的最小间隔时间,小于0.0关闭功能
	// Default: "180.0"
	//l4d2_give_ammo_time "180.0"
	
	// 获取点数上限
	// Default: "5"
	// Minimum: "0.000000"
	//l4d2_max_point "20"
	
	// 玩家每回合传送使用次数.
	// Default: "2"
	// Minimum: "0.000000"
	//l4d2_max_transmit "2"
	
	// 医疗物品购买开关 开:1 关:0
	// Default: "1"
	// Minimum: "0.000000"
	// Maximum: "1.000000"
	//l4d2_medical_enable "1"
	
	// 玩家死亡后是否重置白嫖武器次数 开:1 关:0
	// Default: "0"
	// Minimum: "0.000000"
	// Maximum: "1.000000"
	//l4d2_reset_buy "0"
	
	// 商店开关 开:0 关:1
	// Default: "0"
	// Minimum: "0.000000"
	// Maximum: "1.000000"
	//l4d2_shop_disable "0"
	
	// 传送开关 开:1 关:0
	// Default: "1"
	// Minimum: "0.000000"
	// Maximum: "1.000000"
	//l4d2_transmit_enable "1"
	
	// 每关单人可用白嫖武器上限
	// Default: "2"
	// Minimum: "0.000000"
	//l4d2_weapon_number "2"
	```
</details>

* <details><summary>Command | 命令</summary>

	```php
	sm_shop | 开关商店
	sm_b \ sm_buy \ sm_rpg | 商店菜单
	sm_rank | 个人数据
	sm_tp | 传送菜单
	
	sm_ammo | 补充子弹
	sm_pen | 快速随机一把单喷
	sm_chr | 快速选铁喷
	sm_pum | 快速选木喷
	sm_smg | 快速选smg
	sm_uzi | 快速选uzi
	
	sm_pilll | 快速买药
	```
</details>