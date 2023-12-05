# Description | 內容
**📌原作 [alliedmods](https://forums.alliedmods.net/showthread.php?t=309656)**, 未任何修改

- 该插件修复了 ConVars 过多的服务器, 这会导致服务器控制台中出现缓冲区溢出错误, 并且溢出的 ConVars 将使用其默认值而不是指定的值

- 这还应该修复由于相同缓冲区溢出而导致执行失败的命令

- 注意: 如果您的服务器正在休眠, 修复将在其唤醒时的下一帧进行

- 初始线程和插件版本在[这里](https://forums.alliedmods.net/showthread.php?t=273224)

- 这修复了 "Cbuf_AddText: buffer overflow" 错误消息

---
* <details><summary>Thanks | 感谢</summary>

	* Peace-Maker(用于 DHooks Dev Preview 并帮助编写此插件的脚本)
	* Dr!fter(用于最初创建 DHooks 扩展)
	* Dragokas(优化, 帮助我理解 .cpp 文件和函数)
	* Lux(各种脚本建议和帮助解决问题)
	* Timocop(L4D1 Linux 二进制文件和测试)
</details>

* Video | 影片展示
<br>None

* Image | 图示
<br>None

* Translation Support | 支持语言
<br>None

* <details><summary>Supported Games | 支持的游戏</summary>

	* CS:S
	* CSGO
	* L4D1
	* L4D2
	* OrangeBox
	* Team Fortress 2
	* Request support if your game suffers from this bug.
</details>

* <details><summary>Changelog | 版本日志</summary>

	* 2.8b (11-Feb-2023)
		- Updated GameData signature for CS:GO. Thanks to "foxsay" for reporting.

	* 2.8 (19-Jan-2022)
		- Fixed leaking handles when triggered to fix buffer issues.

	* 2.7 (06-Dec-2021)
		- Fixed the last version breaking plugin functionality. 
	Thanks to "sorallll" for reporting.

	* 2.6 (27-Nov-2021)
		- Fixed "Failed to grow array" error. Thanks to "azureblue" for reporting.

	* 2.5a (16-Jun-2021)
		- L4D2: Compatibility update for "2.2.1.3" update. 
	Thanks to "ProjectSky" for reporting and "bedildewo" for fixing.
		- GameData .txt file and plugin updated.

	* 2.5 (03-May-2021)
		- Fixed errors when inputting a string with format specifiers. 
	Thanks to "sorallll" for reporting and "Dragokas" for fix.

	* 2.4a (19-May-2020)
		- Added support for Team Fortress 2. Only GameData changed.

	* 2.4 (10-May-2020)
		- Added better error log message when gamedata file is missing.
		- Various changes to tidy up code.

	* 2.3 (03-Feb-2020)
		- Fixed debugging using the wrong methodmap. 
	Thanks to "Caaine" for reporting.

	* 2.2 (03-Feb-2020) by Dragokas
		- Added delete to an unused handle.
		- Changed "char" to "static char" in "OnNextFrame" to optimize performance.

	* 2.1 (07-Aug-2018)
		- Added support for GoldenEye and other games using the OrangeBox engine on Windows and Linux.
		- Added support for Left4Dead2 Windows.
		- Gamedata .txt and plugin updated.

	* 2.0.1 (02-Aug-2018)
		- Turned off debugging.

	* 2.0 (02-Aug-2018)
		- Now fixes all ConVars from being set to incorrect values.
		- Supports CSGO (win/nix), L4D1 (win/nix) and L4D2 (nix).
		- Other games with issues please request support.

	* 1.0 (27-Jun-2018)
		- Initial release.
</details>

* <details><summary>Require | 需求</summary>

	* SourceMod 1.11 或更高版本
	* 或者 >>[扩展: DHooks(实验性动态绕行支持)](https://forums.alliedmods.net/showthread.php?p=2588686#post2588686)和手动编译插件
</details>

* <details><summary>Related Plugin | 相关插件</summary>

	* [Cvar Configs Updater](https://forums.alliedmods.net/showthread.php?t=188756) - 适合更新 convar 配置以添加新的 convar, 并删除未使用的 convar

	* [ConVars Anomaly Fixer](https://forums.alliedmods.net/showthread.php?t=307804) - 适合检查和测试 convars 和配置是否有错误
</details>

* ConVar | 指令

	```php
	// Command and ConVar - Buffer Overflow Fixer plugin version.
	command_buffer_version 
	```
* Command | 命令
<br>None