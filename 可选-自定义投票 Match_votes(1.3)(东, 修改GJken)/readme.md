# 📌投票执行更改cvar

输入指令投票更改cvar

**原作 [Github](https://github.com/fantasylidong/anne/blob/main/left4dead2/addons/sourcemod/scripting/vote.sp)**

> 修改源码的一些文案和RegConsoleCmd指令

> 修改配置文件路径

> 添加重启地图代码

投票执行配置文件的位置, 位于 `sourcemod/data/match_votes_file/` 文件夹里面的任意路径

默认读取 `sourcemod/data/match_votes_file/default.txt`

不同模式可以用cvar指定读取配置文件 `sm_cvar votecfgfile "data/match_votes_file/*.txt"`

<details><summary>Configs | 设定示例</summary>

此为自用配置

data/match_votes_file/*.txt
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
  
---
<details><summary>Command | 指令</summary>

|指令|功能|权限|
|-|-|-|
|`!v` \ `!vt` \ `!votes`|投票菜单|Console|
|`!vk`|投票踢出玩家|Console|
|`!cv`|管理员终止此次投票|Admin|
|`!restartmap`|重启当前地图|Admin|
</details>

Video | 影片展示
<br/>None

Image | 图示
<br/>None

<details><summary>ConVar | 控制台变量</summary>

```SourcePawn
//投票文件的位置(位于sourcemod/文件夹)
votecfgfile "data/match_votes_file/default.txt"
```
</details>

<details><summary>Translation Support | 支持语言</summary>

```
简体中文
```
</details>

<details><summary>Apply to | 适用于</summary>

```
l4d2
```
</details>

<details><summary>Require | 需求</summary>

1. [builtinvotes 0.5.8](https://github.com/mvandorp/builtinvotes/releases)
</details>

Related Plugin | 相关插件
<br>None

Changelog | 版本日志</summary>
<br/>None