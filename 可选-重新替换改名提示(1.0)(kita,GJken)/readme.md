# 📌重新替换改名提示

**原作 [Github](https://github.com/txuk1x/g10/blob/main/%E5%BF%85%E9%80%89-%E6%9C%8D%E5%8A%A1%E5%99%A8%E5%8A%9F%E8%83%BD%EF%BC%88kita%EF%BC%89/left4dead2/addons/sourcemod/scripting/serverfunction/changename.sp)**

> 提取自kita的serverFunction
> 代码复制过来的, `show_player_team_chat_spec`不生效管它的
---
Command | 指令
<br>None

Video | 影片展示
<br>None

<details><summary>Image | 图示</summary>

![l4d2_change_name.smx](imgs/01.png)
</details>

<details><summary>ConVar | 控制台变量</summary>

cfg/sourcemod/l4d2_player_suicide.cfg
```sourcepawn
//屏蔽原来的改名提示 0=关
name_change_suppress 1
//屏蔽闲置玩家原来的改名提示 0=关
name_change_spec_suppress 1
//向旁观展示幸存者和受感染团队的聊天内容 0=关
show_player_team_chat_spec 1
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

Related Plugin | 相关插件
<br>None

Changelog | 版本日志
<br>None