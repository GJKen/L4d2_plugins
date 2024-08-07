# 📌自动换图

**原作 [GitHub](https://github.com/umlka/l4d2/tree/main/map_changer)**

- 救援关会自动弹出投票菜单, 如果谁都没投票会随机换官图

- 可设置关卡团灭N次后自动换图

- 已知bug
	- `mapchanger_finale_random_nextmap` cvar为0和1都不生效

> 修改了源码的一些文案

> 修改默认cvar, 自用配置

> 修改RegAdminCmd指令
---
<details><summary>Command | 命令</summary>

|指令|效果|权限|
|-|-|-|
|`!nmaps`|发起下一关地图投票, 仅限救援关投票|Console|
</details>

Video | 影片展示
<br>None

Image | 图示
<br>None

<details><summary>ConVar | 指令</summary>

❗此为自用配置

cfg/sourcemod/map_changer.cfg
```sourcepawn
// 0=终局不换地图(返回大厅), 1=救援载具离开时, 2=终局获胜时, 4=统计屏幕出现时, 8=统计屏幕结束时
mapchanger_finale_change_type "4"

// 终局团灭几次自动换到下一张图
mapchanger_finale_failure_count "0"

// 终局是否启用随机下一关地图
mapchanger_finale_random_nextmap "1"
```
</details>

<details><summary>Translation Support | 支持语言</summary>

```
简体中文
```
</details>

<details><summary>Apply to | 适用于</summary>

```php
L4D2
```
</details>

Require | 需求
<br>None

<details><summary>Related Plugin | 相关插件</summary>

[投票换图(fdxx, sorallll)(v0.9)](https://github.com/GJKen/L4d2_plugins/tree/main/%E5%8F%AF%E9%80%89-%E6%8A%95%E7%A5%A8%E6%8D%A2%E5%9B%BE(v0.9)(fdxx%2Csorallll))
</details>

Changelog | 版本日志
<br>None