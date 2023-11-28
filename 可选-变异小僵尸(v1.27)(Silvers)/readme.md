# Description | 內容
**📌原作 [alliedmods](https://forums.alliedmods.net/showthread.php?t=175242), 做了汉化文案 <br><br>
🔹变异小僵尸**

> 汉化了 data/l4d_mutants.cfg 文件, 修改了部分小僵尸生成概率

## Config | 配置:

### 🛠️根据"z_difficulty"值加载配置:
- 从版本 1.16 开始, 插件将从不同的配置加载(如果存在), 具体取决于难度
- 有效的文件名是 "l4d_mutants_easy.cfg", "l4d_mutants_normal.cfg", "l4d_mutants_hard.cfg", "l4d_mutants_impossible.cfg" 或默认配置(如果文件不存在)

### 🔧"设置"部分:

- "check"- 防止[可变大小的感染者和女巫](https://forums.alliedmods.net/showthread.php?t=165905?t=165905)插件影响僵尸.
- "random"- 如果设置为"0", 僵尸将在满足其各自的"随机"值时生成.这对于对抗来说是最好的, 因此每个团队在相 同数量的受感染产卵后都会收到相同的僵尸.将数字设置为 0 以上时, 当许多感染者生成时, 将生成随机突变体.
- "types"- 您可以通过将这些类型值加在一起来限制允许哪些突变体:
1=炸弹, 2=火焰, 4=幽灵, 8=心灵, 16=烟雾, 32=吐痰, 64=特斯拉, 127=全部.

### 🔗Example Config | 配置示例:
- <details><summary>PHP Code:</summary>

	```php
	"Mutants"
	{
		"Settings"
		{
			// 0=Off, 1=Check for other plugin's uncommon infected to stop Mutant Zombies affecting them.
			// Default:    "0"
			"check"        "0"

			// 0=Off. Limit the number of Mutants at any one time to this amount.
			// Minimum: "0"
			// Maximum: "70"
			// Default:    "14"
			"limit"        "14"

			// 0=Mutants spawn when their individual "random" values are met (this is fair in Versus). Otherwise a random Mutant type is selected after this many common infected spawn.
			// Default:    "50"
			"random"    "50"

			// 1=Bomb, 2=Fire, 4=Ghost, 8=Mind, 16=Smoke, 32=Spit, 64=Tesla, 127=All.
			// Minimum: "0"
			// Maximum: "127"
			// Default:    "127"
			"types"        "127"

			// Should uncommon infected change into Mutant Zombies. 0=Ignore uncommon types. 1=Allow uncommon to be Mutant Zombies also.
			// Default: "0"
			"uncommon" "0"
		}

		"Bomb"
		{
			// 0=Default game damage. How much damage each hit does to a survivor.
			// Default:    "0"
			"damage"    "0"

			// How much damage does the explosion cause at the center.
			// Default:    "25"
			"damage_bomb"    "25"

			// Range at which explosions can damage.
			// Default:    "250"
			"distance"    "250"

			// Chance out of 100 to detonate the bomb when hitting survivors.
			// Default:    "50"
			"explode_attack"    "50"

			// Chance out of 100 to detonate the bomb when taking damage from survivors.
			// Default:    "15"
			"explode_defend"    "15"

			// Chance out of 100 to detonate the bomb when dieing from a headshot.
			// Default:    "75"
			"explode_headshot"    "75"

			// 0=Off. Range at which Bomb mutants glow.
			// Default:    "0"
			"glow"    "0"

			// R,G,B color values for the glow. 3 values between 0 and 255.
			// Default:    "255 255 0"
			"glow_color"    "255 255 0"

			// 0=Default. How much health the zombie has.
			// Default:    "150"
			"health"    "150"

			// How many Bomb mutants are allowed on the map at once.
			// Minimum: "0"
			// Maximum: "10"
			// Default:    "2"
			"limit"    "2"

			// 0=Off. Spawn a Bomb mutant after this many common spawn.
			// Minimum: "10"
			// Maximum: "1000"
			// Default:    "105"
			"random"    "105"

			// 0=Off. 1=Create a camera shake when the bomb explodes.
			// Default:    "1"
			"shake"    "1"
		}

		"Fire"
		{
			// 0=Default game damage. How much damage each hit does to a survivor.
			// Default:    "0"
			"damage"    "0"

			// 0=Off, Chance of dropping fires when hurting players, between 1 and 100.
			// Default:    "10"
			"drop_attack"    "10"

			// 0=Off, Chance of dropping fires when receiving damage, between 1 and 100.
			// Default:    "5"
			"drop_defend"    "5"

			// How much damage each dropped fire causes per second.
			// Default:    "3"
			"drop_damage"    "3.0"

			// 0=Off. Range at which Fire mutants glow.
			// Default:    "0"
			"glow"    "0"

			// R,G,B color values for the glow. 3 values between 0 and 255.
			// Default:    "255 0 0"
			"glow_color"    "255 0 0"

			// 0=Default. How much health the zombie has.
			// Default:    "0"
			"health"    "0"

			// How many Fire mutants are allowed on the map at once.
			// Minimum: "0"
			// Maximum: "10"
			// Default:    "2"
			"limit"    "2"

			// 0=Off. Spawn a Fire mutant after this many common spawn.
			// Minimum: "10"
			// Maximum: "1000"
			// Default:    "133"
			"random"    "133"

			// How long do dropped fires last for.
			// Default:    "10.0"
			"time"        "10.0"

			// 0=Off, 100=All. The chance to turn common infected into Fire mutants when they walk through molotov fires or firework explosions.
			// Default:    "20"
			"walk"    "20"

			// 0=Off, 100=All. The chance to turn common infected into Fire mutants when they they are shot with incendiary bullets.
			// Default:    "20"
			"incendiary"    "20"
		}

		"Ghost"
		{
			// 0=Default game damage. How much damage each hit does to a survivor.
			// Default:    "0"
			"damage"    "0"

			// 0=Off. Range at which Ghost mutants glow.
			// Default:    "0"
			"glow"    "0"

			// R,G,B color values for the glow. 3 values between 0 and 255.
			// Default:    "100 100 100"
			"glow_color"    "100 100 100"

			// 0=Default. How much health the zombie has.
			// Default:    "0"
			"health"    "0"

			// How many Ghost mutants are allowed on the map at once.
			// Minimum: "0"
			// Maximum: "10"
			// Default:    "2"
			"limit"    "2"

			// 0=Transparent, 255=Opague. How solid do you want ghosts to appear?
			// Default:    "75"
			"opacity"    "75"

			// 0=Off. Spawn a Ghost mutant after this many common spawn.
			// Minimum: "10"
			// Maximum: "1000"
			// Default:    "49"
			"random"    "49"
		}

		"Mind"
		{
			// 0=Default game damage. How much damage each hit does to a survivor.
			// Default:    "0"
			"damage"    "0"

			// How far does the effect range.
			// Default:    "300"
			"distance"    "300"

			// 1=Ghost, 2=Red, 4=Lightning, 8=Yellow, 16=Infected, 32=Thirdstrike, 64=Blue, 128=Sunrise, 255=All. Effects to randomly select from. Add the numbers together.
			// Minimum: "1"
			// Maximum: "255"
			// Default:    "255"
			"effects"    "255"

			// 0=Off. Range at which Mind mutants glow.
			// Default:    "0"
			"glow"    "0"

			// R,G,B color values for the glow. 3 values between 0 and 255.
			// Default:    "100 50 100"
			"glow_color"    "100 50 100"

			// 0=Default. How much health the zombie has.
			// Default:    "0"
			"health"    "0"

			// How many Mind mutants are allowed on the map at once.
			// Minimum: "0"
			// Maximum: "10"
			// Default:    "2"
			"limit"    "2"

			// 0=Off. Spawn a Mind mutant after this many common spawn.
			// Minimum: "10"
			// Maximum: "1000"
			// Default:    "63"
			"random"    "63"
		}

		"Smoke"
		{
			// 0=Default game damage. How much damage each hit does to a survivor.
			// Default:    "0"
			"damage"    "0"

			// How much damage does the smoke cloud do?
			// Default:    "1"
			"damage_smoke"    "1"

			// How far does the smoke cloud damage?
			// Default:    "100"
			"distance"    "100"

			// Color of the smoke
			// Default:    "20 20 30"
			"color"    "20 20 30"

			// 0=Off. Range at which Smoke mutants glow.
			// Default:    "0"
			"glow"    "0"

			// R,G,B color values for the glow. 3 values between 0 and 255.
			// Default:    "0 100 100"
			"glow_color"    "0 100 100"

			// 0=Default. How much health the zombie has.
			// Default:    "0"
			"health"    "0"

			// How many Smoke mutants are allowed on the map at once.
			// Minimum: "0"
			// Maximum: "10"
			// Default:    "2"
			"limit"    "2"

			// 0=Off. Spawn a Smoke mutant after this many common spawn.
			// Minimum: "10"
			// Maximum: "1000"
			// Default:    "91"
			"random"    "91"
		}

		"Spit"
		{
			// 0=Default game damage. How much damage each hit does to a survivor.
			// Default:    "1"
			"damage"    "1"

			// How many times the player gets hurt after being hit by Spit mutants.
			// Default:    "3"
			"damage_multiple"    "3"

			// 0=Off, 1=Goo Dribble, 2=Smoke Trail, 3=Goo Dribble + Smoke Trail.
			// Minimum:    "0"
			// Maximum:    "6"
			// Default:    "3"
			"effects"    "3"

			// 0=Off. Range at which Spit mutants glow.
			// Default:    "0"
			"glow"    "0"

			// R,G,B color values for the glow. 3 values between 0 and 255.
			// Default:    "0 255 0"
			"glow_color"    "0 255 0"

			// 0=Default. How much health the zombie has.
			// Default:    "0"
			"health"    "0"

			// How many Spit mutants are allowed on the map at once.
			// Minimum: "0"
			// Maximum: "10"
			// Default:    "2"
			"limit"    "2"

			// 0=Off. Spawn a Spit mutant after this many common spawn.
			// Minimum: "10"
			// Maximum: "1000"
			// Default:    "119"
			"random"    "119"

			// The interval to hurt players after being hit by Spit mutants.
			// Default:    "0.5"
			"time"    "0.5"

			// 0=Off, The chance to turn common infected into Spit mutants when they walk through spitter acid.
			// Default:    "20"
			"walk"    "20"
		}

		"Tesla"
		{
			// 0=Default game damage. How much damage each hit does to a survivor.
			// Default:    "5"
			"damage"    "5"

			// 1=Electrical Arc, 2=Electrical Arc B, 4=St Elmos Fire, 8=Lightning, 16=Lightning B, 31=All.
			// Minimum:    "1"
			// Maximum: "31"
			// Default:    "31"
			"effects"    "31"

			// Use this much force to push away players
			// Default:    "400.0"
			"force"        "400.0"

			// Add this much vertical velocity. Must be above 250.0 or players will not be pushed at all.
			// Default:    "300.0"
			"force_z"    "300.0"

			// 0=Off. Range at which Tesla mutants glow.
			// Default:    "0"
			"glow"    "0"

			// R,G,B color values for the glow. 3 values between 0 and 255.
			// Default:    "0 100 255"
			"glow_color"    "0 100 255"

			// 0=Default. How much health the zombie has.
			// Default:    "0"
			"health"    "0"

			// How many Tesla mutants are allowed on the map at once.
			// Minimum: "0"
			// Maximum: "10"
			// Default:    "2"
			"limit"    "2"

			// 0=Off. Spawn a Tesla mutant after this many common spawn.
			// Minimum: "10"
			// Maximum: "1000"
			// Default:    "77"
			"random"    "77"
		}
	}
	```
</details>

---
* <details><summary>Types | 类型:</summary>

	* Bomb-炸弹:
		* There are random chances for Bomb mutants to explode when attacking, being hurt (defending) or shot in the head.
		* 炸弹变种在攻击, 受伤(防御)或头部中弹时会随机爆炸.
	
	* Fire-火:
		* Common which walk through molotov fires or firework crate explosions have a random chance to mutate into Fire mutants. These zombies are fireproof and have chances to drop fires when attacking or defending.
		* 穿过火焰或烟花箱爆炸的僵尸会随机突变为火焰变种.这些僵尸是防火的, 在攻击或防御时有机会掉落火焰.
	
	* Ghost-幽灵:
		* Semi transparent zombie.
		* 半透明僵尸
	
	* Mind-思维:
		* Getting near to these zombies will change your screen color.
		* 靠近这些僵尸会改变你的屏幕颜色.
	
	* Smoke-烟:
		* Players near to these zombies receive damage.
		* 靠近这些僵尸的玩家会受到伤害.
	
	* Spit-吐:
		* Common which walk through Spitter acid have a random chance to mutate into to Spit mutants. When hit by these zombies, players take damage for a few seconds.
		* 穿过痰水的僵尸会随机突变为Spitter变种.当被这些僵尸击中时, 玩家会受到几秒钟的伤害.
	
	* Tesla-特斯拉:
		* Nikola Tesla mutant, flings players away from the Mutant.
		* 尼古拉·特斯拉变种, 会将玩家从身边击飞.
</details>

* Video | 影片展示
<br>None

* <details><summary>Image | 图示</summary>

	<br>
	变种僵尸类型:
	
	![l4d_mutant_zombies.smx](http://imgur.com/5rkkxIu.jpg)
	
	[Bomb 1-炸弹1](http://imgur.com/gdSp7AQ.jpg), [Bomb 2-炸弹2](http://imgur.com/tYdGeAv.jpg), 
	[Fire-火](http://imgur.com/7gG4uci.jpg), 
	[Ghost-幽灵](http://imgur.com/XlN2lxx.jpg), 
	[Mind-思维](http://imgur.com/OkxtUdF.jpg), 
	[Smoke-烟](http://imgur.com/eGLeiN9.jpg), 
	[Tesla-特斯拉](http://imgur.com/wMpcO08.jpg)

	<br>
	Mind type effects-思维类型效果:
	
	![l4d_mutant_zombies.smx](http://imgur.com/CwTuujU.jpg)
	</details>

* <details><summary>Translation Support | 支持语言</summary>

	```
	English
	繁體中文
	简体中文
	```
</details>

* <details><summary>Changelog | 版本日志</summary>

	- 1.27 (19-Feb-2023)
    - Fixed Fire Mutants taking fire damage from other sources. Thanks to "BystanderZK" for reporting.

	- 1.26 (10-Feb-2023)
		- Fixed invincible Fire Mutants. Thanks to "sonic155" and "Maur0" for reporting and testing.
		- Fixed Survivor bots from killing common infected instead of converting them to Fire Mutants.
		- Removed the "Smoke" type key value "color" since it was never meant to exist, the smoke is a particle and color cannot be changed. Thanks to "sonic155" for reporting.

	- 1.25 (03-Feb-2023)
		- Changed the method of converting and preventing Fire Mutants from dying. Thanks to "sonic155" for reporting.
		- Added another check to prevent invisible common remaining alive.

	- 1.24 (02-Feb-2023)
		- Fixed Fire Mutants not attacking when initially ignited.
		- Fixed invincible Fire Mutants bug from the last 3 plugin updates. Thanks to "Mi.Cura" for reporting.

	- 1.23 (27-Jan-2023)
		- Fixed invisible Fire Mutants bug from the last 2 plugin updates. Thanks to "Mi.Cura" for reporting.

	- 1.22 (25-Jan-2023)
		- Added "drop_damage" data config setting to Fire Mutants, allowing dropped fire damage to be controlled independently from the "damage" key.
		- Fixed converting common infected into Fire Mutants when shot by normal bullets.
		- Fixed incendiary bullets not always converting common infected to Fire Mutants.

	- 1.21 (24-Jan-2023)
		- Fixed incendiary bullets not always converting common infected to Fire Mutants.
		- Fixed not setting the config health value on Fire Mutants in some circumstances.
		- Fixed various fire damage causing Fire Mutants to die prematurely.
		- Thanks to "BystanderZK" for reporting and testing.

	- 1.20 (20-Jan-2023)
		- L4D2: Added "incendiary" data config setting to Fire Mutants, allowing common infected to convert to Fire Mutants when shot with Incendiary ammo.
		- Fixed common infected walking through fire not having the charred model effect.

	- 1.19 (15-Dec-2022)
		- Fixed changing "attacker" to entity reference in OnTakeDamage which affects other plugins. Thanks to "Hawkins" for reporting.

	- 1.18 (12-Dec-2022)
		- Fixed "Fire" type not spawning when walking through fire. Thanks to "BystanderZK" for reporting.

	- 1.17 (03-Dec-2022)
		- Fixed invalid entity errors. Thanks to "Mi.Cura" for reporting.

	- 1.16 (15-Aug-2022)
		- Changes to load the "l4d_mutants.cfg" data config based on the z_difficulty value if the file exists.
		- Valid filenames are "l4d_mutants_easy.cfg", "l4d_mutants_normal.cfg", "l4d_mutants_hard.cfg" and "l4d_mutants_impossible.cfg".
		- Requested by "Hawkins".

	- 1.15 (30-Jul-2022)
		- Potential fix for rare server crashes caused by "CBaseEntityOutput::FireOutput". Thanks to "Hawkins" for reporting.

	- 1.14 (07-Jun-2022)
		- Fixed mutant zombies spawning when their "random" data config setting values were set to "0". Thanks to "Winn" for reporting.
		- Removed minimum and maximum value restriction for individual mutants "random" data config setting.

	- 	1.13 (12-Sep-2021)
		- L4D1: Fixed constantly spawning Mutant Zombies due to not restricting a line of code for L4D2.

	- 1.12 (09-Oct-2020)
		- Changed "OnClientPostAdminCheck" to "OnClientPutInServer" - to fix any issues if Steam service is down.

	- 1.11 (30-Sep-2020)
		- Fixed compile errors on SM 1.11.

	- 1.10 (15-May-2020)
		- Replaced "point_hurt" entity with "SDKHooks_TakeDamage" function.

	- 1.9 (10-May-2020)
		- Extra checks to prevent "IsAllowedGameMode" throwing errors.
		- Various changes to tidy up code.
		- Various optimizations and fixes.

	- 	1.8 (08-Apr-2020)
		- Fixed invalid entity index errors. Thanks to "sxslmk" reporting.

	- 1.7 (01-Apr-2020)
		- Fixed not precaching "env_shake" causing the Bomb type to stutter on first explosion. Thanks to "TiTz" for reporting.
		- Fixed clients giving themselves damage instead of from the server. Thanks to "TiTz" for reporting.
		- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

	- 1.6 (18-Mar-2020)
		- Changed the random spawn selection method to use >= instead of > value.
		- Now you can specify "random" "1" in the config to make every common infected spawned a Mutant Zombie.
		- This also applies to each types individual "random" setting.

		- Added "uncommon" data config setting. This allows uncommon infected to also be Mutants. Default off.
		- Fixed "check" data config setting from never actually being read.

	- 1.5.1 (28-Jun-2019)
		- Changed PrecacheParticle method.

	- 1.5.0 (05-May-2018)
		- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
		- Changed cvar "l4d_mutants_modes_tog" now supports L4D1.

	- 1.4.3 (01-Apr-2018)
		- Fixed bug in L4D2.
		- Uploaded correct data config for L4D2, previous one broke Tesla and Spit mutants.

	- 1.4.2 (31-Mar-2018)
		- Tesla Mutants now working in L4D1, with reduced visual effects.

	- 1.4.1 (31-Mar-2018)
		- Added check for very rare and very strange error - "Dragokas".
		- Fixed particle error in L4D1.
		- Fixed bomb position in L4D1.
		- Data config renamed to "l4d_mutants.cfg".

	- 1.4 (23-Mar-2018)
		- Initial support for L4D1.

	- 1.3 (10-May-2012)
		- Added cvar "l4d2_mutants_modes_off" to control which game modes the plugin works in.
		- Added cvar "l4d2_mutants_modes_tog" same as above, but only works for L4D2.
		- Fixed a bug when gascans etc exploded, which prevented common from being ignited.
		- Fixed a bug with the "random" option in the config not working as expected.

	- 1.2 (15-Jan-2012)
		- Fixed "effects" not setting correctly on "Mind" type.

	- 1.1 (14-Jan-2012)
		- Added command "sm_mutantsrefresh" to refresh the plugin and reload the data config.
		- Fixed "types" config not setting when "random" was set to 0.

	- 1.0 (01-Jan-2012)
		- Initial release.
</details>

* Require | 需求
<br>None

* Related Plugin | 相关插件
<br>None

* <details><summary>ConVar | 指令</summary>

	* cfg/sourcemod/l4d_mutants.cfg
	```php
	// ConVars for plugin "l4d_mutant_zombies.smx"

	// 0 =关闭插件,1 =打开插件.
	// Default: "1"
	l4d_mutants_allow "1"

	// 在这些游戏模式下打开插件,并以逗号分隔(无空格). (空=全部).
	// Default: ""
	l4d_mutants_modes ""

	// 在这些游戏模式下关闭插件,并以逗号分隔(无空格). (空=全部).
	// Default: ""
	l4d_mutants_modes_off ""

	// 在这些游戏模式下打开插件.0 =全部,1=战役,2=生存,4=对抗,8=清道夫,将数字加在一起.
	// Default: "0"
	l4d_mutants_modes_tog "0"

	// 突变僵尸插件版本
	l4d2_mutants_version
	```
</details>

* <details><summary>Command | 命令</summary>

	|指令|用法|
	|-|-|
	|`sm_mutantsrefresh`|刷新插件并重新加载数据配置(data/l4d_mutants.cfg)|
	|`sm_mutantbomb`|生成一个炸弹僵尸|
	|`sm_mutantfire`|生成一个火僵尸|
	|`sm_mutantghost`|生成一个幽灵僵尸|
	|`sm_mutantmind`|生成一个变异的思维僵尸<br>用法: sm_mutantmind <type 1=Ghost, 2=Red, 4=Lightning, 8=Yellow,| 16=Infected, 32=Thirdstrike, 64=Blue, 128=Sunrise>
	|`sm_mutantsmoke`|生成一个烟雾僵尸|
	|`sm_mutantspit`|生成一个喷吐僵尸|
	|`sm_mutanttesla`|生成一个特斯拉僵尸|
	|`sm_mutants`|生成所有变种僵尸|
</details>