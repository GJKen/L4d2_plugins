# 📌服务器名称显示(模式,刷特感数量&时间)

**原作 [Github](https://github.com/txuk1x/g10/blob/main/%E5%BF%85%E9%80%89-%E6%9C%8D%E5%8A%A1%E5%99%A8%E5%8A%9F%E8%83%BD%EF%BC%88kita%EF%BC%89/left4dead2/addons/sourcemod/scripting/ServerName.sp)**

<details><summary>服务器名称配置</summary>

1. 打开 `sourcemod/configs/hostname.txt` 文件

2. 编辑 `hostname.txt` 配置服名, 示例如下(`27015`, `27025` 为服务器端口

	用于未在 `sn_base_server_name` 中配置服名时使用服务器当前端口配置相应服名
	```sourcepawn
	ServerName
	{
		"27015"
		{
			"baseName"	"JKChan#1"
		}
		"27025"
		{
			"baseName"	"JKChan#2"
		}
	}
	```
<br>❗若基本服名与端口服名同时未配置, 或者端口配置错误, 最终**基本服名**将会显示为 Left 4 Dead 2
<br>❗`hostname.txt` 不存在或文件夹未创建, 插件将不会正确加载并会提示无法找到 `hostname.txt` 文件
</details>

> 从 kita 修改的源码再次修改, 修改了部分文案

> 修改hostname.txt文件路径

> 增加[哈利波特](https://github.com/GJKen/L4d2_plugins/tree/main/%E5%8F%AF%E9%80%89-%E5%A4%9A%E7%89%B9%E6%8F%92%E4%BB%B6(v2.8.6)(fbef0102))
---
Command | 指令
<br>None

Video | 影片展示
<br>None

Image | 图示
<br>None

<details><summary>ConVar | 控制台变量</summary>

此为自用 cvar 配置, `sn_base_server_name` 推荐不设置

no cfg
```sourcepawn
//a纯净模式, b绝境战役18特, c多特模式, d写专多特, e无限火力, f困难无限, g药役A, h药役B, i药役C, j药役D, k单人药役, lHT训练, nHTx Witch
sn_display_infected_info 0 //是否在服名中显示特感信息 0=关
sn_display_mode_info 1 //是否在当前服名中显示什么模式 0=关
sn_refresh_time 10 //服名的刷新时间,单位:秒
//sn_base_server_name //基本服名,配置则使用当前服名,未配置则使用文件中的服名
sn_base_mode_name "a"//基本模式名称,未配置则不显示
sn_base_mode_code "a"//基本模式名称代码
```
❗ `sn_base_server_name` 设置服名不支持中文<br>
❗ 插件显示的模式在源码里面, 更改需要自己编译
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

1. [l4d2_server_mode_tips](https://github.com/GJKen/L4d2_plugins/tree/main/%E5%8F%AF%E9%80%89-%E6%9C%8D%E5%8A%A1%E5%99%A8%E5%87%BA%E5%AE%89%E5%85%A8%E5%8C%BA%E6%8F%90%E7%A4%BA%2C%E9%85%8D%E5%90%88match%E6%9B%B4%E6%94%B9%E6%B8%B8%E6%88%8F%E6%A8%A1%E5%BC%8F%E4%BD%BF%E7%94%A8(kita%2C%20Hatsune%20Imagine))

2. [Match_votes](https://github.com/GJKen/L4d2_plugins/tree/main/%E5%8F%AF%E9%80%89-%E8%87%AA%E5%AE%9A%E4%B9%89%E6%8A%95%E7%A5%A8%20Match_votes(1.3)(%E4%B8%9C%2C%20%E4%BF%AE%E6%94%B9GJken))
</details>

<details><summary>Changelog | 版本日志</summary>

- 2022.12.18
	- 上传插件与 `readme` 文件
- 2023.7.31
	- 增加无插件刷特时特感数量与时间使用导演系统 `MaxSpecials` 与 `SpecialRespawnInterval` 值
- 2023.12.23
	- 更新哈利波特的刷特判断, `l4d_infectedbots_max_specials` `l4d_infectedbots_spawn_time_max`
- 2024.1.29
	- 源插件重构部分代码逻辑 [b4ed4e5](https://github.com/txuk1x/g10/commit/b4ed4e57107540efebbc1624f96af88646b3676a)
- 2024.2.11
	- 添加 `绝境战役18特` 模式文案, 修改hostname.txt的路径, 优化部分细节