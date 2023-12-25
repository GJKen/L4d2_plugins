# Description | 內容
**📌原作[Github](https://github.com/fbef0102/L4D1_2-Plugins/tree/master/match_vote)**

**输入`!votes`   `!v`, 投票更改cvar, 不同的cvar需要自定义`configs/Match_votes.txt`里面的内容**

<br>

> 修改并汉化了源码的一些文案, 修改RegConsoleCmd指令

> 修改原版的配置文件名称为 Match_votes

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

* <details><summary>Changelog | 版本日誌</summary>

	* v1.0 (2023-6-30)
        * Initial Release
</details>

* <details><summary>Require | 必要安裝</summary>

	1. [[INC] Multi Colors](https://github.com/fbef0102/L4D1_2-Plugins/releases/tag/Multi-Colors)
	2. [builtinvotes](https://github.com/L4D-Community/builtinvotes/actions)
</details>

* <details><summary>Configs 设定示例</summary>

	* configs/Match_votes.cfg
		```SourcePawn
			"Match_votes"
			{
				"全体转生?" //名称随意
				{
					"match_votesrestartmap_on" //执行cfg文件的路径为: cfg/test.cfg, 也可以是cvar
					{
						"name" "人生重开!!!!" //出现在菜单界面面上的名称
					}
					"match_votesrestartmap_off"
					{
						"name" "我不想重开T_T"
					}
				}
			}
		```
  </details>

* <details><summary>ConVar | 指令</summary>

	* cfg\sourcemod\match_vote.cfg
		```SourcePawn
		// 0=Plugin off, 1=Plugin on.
		// Default: "1"
		// Minimum: "0.000000"
		// Maximum: "1.000000"
		match_vote_enable "1"
		
		// 投票结束后延迟开始另一次投票(s)
		// Default: "60"
		// Minimum: "1.000000"
		match_vote_delay "5"
		
		// 开始比赛投票所需的真实幸存者和受感染玩家的数量
		// Default: "1"
		// Minimum: "1.000000"
		match_vote_required "1"
		```
</details>


* <details><summary>Command | 命令</summary>

	`sm_votes` | `sm_v` > 发起cvar更改投票
</details>