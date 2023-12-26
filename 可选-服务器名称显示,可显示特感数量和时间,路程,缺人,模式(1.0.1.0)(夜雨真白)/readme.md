# 📌服务器名称显示,可显示特感数量和时间,路程,缺人,模式

原作 [Github](https://github.com/GlowingTree880/L4D2_LittlePlugins/tree/main/ServerNamer)

> 从 kita 修改的源码再次修改, 修改了部分文案

> 增加[哈利波特](https://github.com/GJKen/L4d2_plugins/tree/main/%E5%8F%AF%E9%80%89-%E5%A4%9A%E7%89%B9%E6%8F%92%E4%BB%B6(fbef0102)23.9.20)刷特插件判断

`scripting/treeutil/treeutil.sp` 为编译插件所需文件

---
Command | 指令
<br>None

Video | 影片展示
<br>None

<details><summary>Image | 图示</summary>

![l4d2_server_name.smx](imgs/01.jpg)
</details>

<details><summary>服务器名称配置</summary>

1. 打开 `sourcemod/configs/hostname/hostname.txt` 文件

2. 编辑 `hostname.txt` 配置服名, 示例如下(`27015`, `27025` 为服务器端口

	用于未在 `sn_base_server_name` 中配置服名时使用服务器当前端口配置相应服名
	configs/hostname/hostname.txt
	```sourcepawn
	ServerName
	{
		"27015"
		{
			"baseName"	"JKChan's Server#1"
		}
		"27025"
		{
			"baseName"	"JKChan's Server#2"
		}
	}
	```
<br>❗若基本服名与端口服名同时未配置, 或者端口配置错误, 最终**基本服名**将会显示为 Left 4 Dead 2
<br>❗`hostname.txt` 不存在或 `configs/hostname` 文件夹未创建插件将不会正确加载并会提示无法找到 `hostname.txt` 文件
</details>

<details><summary>ConVar | 控制台变量</summary>

此为自用 cvar 配置

no cfg
```sourcepawn
//是否在服名中显示刷特参数 1=开,0=关
sn_display_infected_info "1"
//是否在服名中显示当前路程信息 1=开,0=关
sn_display_current_info "0"
//是否在当前服名中显示是什么模式 1=开,0=关
sn_display_mode_info "1"
//是否在当前服名中显示是否缺人 1=开,0=关
sn_display_need_people "0"
//服名的刷新时间,单位:秒
sn_refresh_time "10"
//基本服名,配置则使用当前服名,未配置则使用文件中的服名
// 开启时, 服务器中没有玩家则会显示无人, 服务器中有玩家但仍有生还者 bot 存在时, 则会显示缺人, 当没有生还者 bot 存在时, 将不会显示任何信息
sn_base_server_name ""
//基本模式名称,未配置则不显示
//a=纯净战役, b=多特战役 c=增强多特 d=坐牢战役 e=简单药役 f=正常药役 g=坐牢药役 h=单人战役 i=单人药役 j=单人多特 k=普通战役 l=无限火力 m=高级无限 n=HT训练
sn_base_mode_name ""
```
❗cvar 设置服名不支持中文
<br>❗`sn_base_mode_name` 和 `sn_display_infected_info` 这两个 cvar 未配置或者检测不到刷特插件的 cvar
<br>会在控制台报错, 服名会显示不出模式或刷特参数
<br>❗插件显示的模式在源码里面, 更改需要自己编译
</details>

<details><summary>Apply to | 适用于</summary>

```php
L4D2
```
</details>

<details><summary>Require | 需求</summary>

1. [[L4D & L4D2] Left 4 DHooks Direct](https://forums.alliedmods.net/showthread.php?t=321696)
</details>

<details><summary>Related Plugin | 相关插件</summary>

1. [服务器出安全区提示,配合match更改游戏模式使用(kita, Hatsune Imagine)](https://github.com/GJKen/L4d2_plugins/tree/main/%E5%8F%AF%E9%80%89-%E6%9C%8D%E5%8A%A1%E5%99%A8%E5%87%BA%E5%AE%89%E5%85%A8%E5%8C%BA%E6%8F%90%E7%A4%BA%2C%E9%85%8D%E5%90%88match%E6%9B%B4%E6%94%B9%E6%B8%B8%E6%88%8F%E6%A8%A1%E5%BC%8F%E4%BD%BF%E7%94%A8(kita%2C%20Hatsune%20Imagine)/left4dead2/addons/sourcemod)

2. [自定义投票 Match_votes(1.3)(东, 修改GJken)](https://github.com/GJKen/L4d2_plugins/tree/main/%E5%8F%AF%E9%80%89-%E8%87%AA%E5%AE%9A%E4%B9%89%E6%8A%95%E7%A5%A8%20Match_votes(1.3)(%E4%B8%9C%2C%20%E4%BF%AE%E6%94%B9GJken))
</details>

<details><summary>Changelog | 版本日志</summary>

- 2022.12.18
	- 上传插件与 `readme` 文件
- 2023.7.31
	- 增加无插件刷特时特感数量与时间使用导演系统 `MaxSpecials` 与 `SpecialRespawnInterval` 值
- 2023.12.23
	- 更新哈利波特的刷特判断, `l4d_infectedbots_max_specials` `l4d_infectedbots_spawn_time_max`