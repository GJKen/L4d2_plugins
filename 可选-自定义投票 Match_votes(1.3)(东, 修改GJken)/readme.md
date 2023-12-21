# Description | 內容
**📌原作[Github](https://github.com/fantasylidong/anne/blob/main/left4dead2/addons/sourcemod/scripting/vote.sp)**

输入指令投票更改cvar, 不同的cvar需要自定义`data/match_votes_file/*.txt`里面的内容, 默认读取sourcemod/data/match_votes_file/default.txt

投票执行配置文件的位置, 位于sourcemod/data/match_votes_file/文件夹里面的任意路径

不同模式可以用cvar指定读取配置文件 `sm_cvar votecfgfile "data/match_votes_file/*.txt"`
<br>

> 修改源码的一些文案, 修改RegConsoleCmd指令

>修改配置文件路径

> 添加重启地图代码
---
* Video | 影片展示
<br/>None

* Image | 圖示
<br/>None

* <details><summary>Apply to | 適用於</summary>

	```
	l4d1
	l4d2
	```
</details>

* Changelog | 版本日誌</summary>
<br/>None

* <details><summary>Require | 必要安裝</summary>

	1. [[INC] Multi Colors](https://github.com/fbef0102/L4D1_2-Plugins/releases/tag/Multi-Colors)
	2. [builtinvotes](https://github.com/L4D-Community/builtinvotes/actions)
</details>

* <details><summary>Configs 设定示例</summary>

	- data/match_votes_file/*.txt
		```SourcePawn
			"Cfgs"
			{
				"全体转生?" //名称随意
				{
					"exec match_votes/restartmap_on" //执行cfg文件的路径为: cfg/match_votes, 也可以是cvar
					{
						"message" "人生重开!!!!" //出现在菜单界面面上的名称
					}
					"exec match_votes/restartmap_off"
					{
						"name" "我不想重开T_T"
					}
				}
				//以此类推
			}
		```
  </details>

* <details><summary>ConVar | 指令</summary>

	```SourcePawn
	votecfgfile "data/match_votes_file/default.txt" //投票文件的位置(位于sourcemod/文件夹)
	```
</details>

* <details><summary>Command | 命令</summary>

	|指令|功能|
	|-|-|
	|`!v` `!vt` `votes`|投票菜单|
	|`!vk`|投票踢出玩家|
	|`!cv`|管理员终止此次投票|
	|`!restartmap`|重启当前地图|
</details>