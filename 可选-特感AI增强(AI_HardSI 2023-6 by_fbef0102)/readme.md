
# Description | 內容
Improves the AI behaviour of special infected

* Video | 影片展示
<br/>None

* Image｜ 圖示
<br/>None

* Apply to | 適用於
    ```
    L4D2
    ```

* <details><summary>Changelog | 版本日誌</summary>

    * v1.5 (2023-5-4)
        * Use server console to execute command "nb_assault"

    * v1.4
        * Remake code
        * Replace left4downtown with left4dhooks
        *Compatibility support for SourceMod 1.11. Fixed various warnings.
    </details>

* Require | 必要安裝
    1. [left4dhooks](https://forums.alliedmods.net/showthread.php?t=321696)

* <details><summary>ConVar | 指令</summary>

	* cfg\sourcemod\AI_HardSI.cfg
		```php
        // If the charger has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius
        ai_aim_offset_sensitivity_charger "20"

        // If the hunter has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius
        ai_aim_offset_sensitivity_hunter "30"

        // Frequency(sec) at which the 'nb_assault' command is fired to make SI attack
        ai_assault_reminder_interval "2"

        // How close a charger will approach before charging
        ai_charge_proximity "300"

        // At what distance to start pouncing fast
        ai_fast_pounce_proximity "1000"

        // Charger will charge if its health drops to this level
        ai_health_threshold_charger "300"

        // How close a jockey will approach before it starts hopping
        ai_hop_activation_proximity "500"

        // Mean angle produced by Gaussian RNG
        ai_pounce_angle_mean "10"

        // One standard deviation from mean as produced by Gaussian RNG
        ai_pounce_angle_std "20"

        // Vertical angle to which AI hunter pounces will be restricted
        ai_pounce_vertical_angle "7"

        // Distance to nearest survivor at which hunter will consider pouncing straight
        ai_straight_pounce_proximity "200"

        // Flag to enable bhop facsimile on AI tanks
        ai_tank_bhop "1"

        // Flag to enable rocks on AI tanks
        ai_tank_rock "1"

        // How far in front of himself infected bot will check for a wall. Use '-1' to disable feature
        ai_wall_detection_distance "-1"
		```
</details>

* <details><summary>Command | 命令</summary>

	None
</details>

* Improve Infected
    * <details><summary><b>AI Tank</b></summary>

        * Stop throwing the rock after approaching the survivors
        * Behop
    </details>

    * <details><summary><b>Witch</b></summary>

        * None
    </details>

    * <details><summary><b>AI Smoker</b></summary>

        * Modify Official ConVar
            ```php
            // How much damage to the smoker makes him let go of his victim. (Default: 50)
            tongue_break_from_damage_amount 250

            // Start to shoot his tongue after 0.1 seconds (Default: 1.5)
            smoker_tongue_delay 0.1
            ```
    </details>

    * <details><summary><b>AI Boomer</b></summary>

        * Modify Official ConVar
            ```php
            // How long an out-of-range Boomer will tolerate being visible before fleeing (Default: 1.0)
            boomer_exposed_time_tolerance 1000.0

            // How long the Boomer waits before he vomits on his target on Normal difficulty (Default: 1.0)
            boomer_vomit_delay 0.1
            ```
    </details>

    * <details><summary><b>AI Hunter</b></summary>

        * Won't leap away (Coop/Realism)
        * Modify Official ConVar
            ```php
            // Range at which hunter prepares pounce	 (Default: 1000)
            hunter_pounce_ready_range 1000

            // Range at which hunter is committed to attack	 (Default: 75)
            hunter_committed_attack_range 10000

            // Range at which shooting a non-committed hunter will cause it to leap away (Coop/Realis, Default: 1000)
            hunter_leap_away_give_up_range 0

            // Maximum vertical angle hunters can pounce (Default: 45)
            hunter_pounce_max_loft_angle 0

            // AI Hunter skeet damage (Default: 50)
            z_pounce_damage_interrupt 150
            ```
        * Plugin ConVar
            ```php
            // At what distance to start pouncing fast
            ai_fast_pounce_proximity 1000

            // Vertical angle to which AI hunter pounces will be restricted
            ai_pounce_vertical_angle 7

            // Mean angle produced by Gaussian RNG
            ai_pounce_angle_mean 10

            // One standard deviation from mean as produced by Gaussian RNG
            ai_pounce_angle_std 20

            // Distance to nearest survivor at which hunter will consider pouncing straight
            ai_straight_pounce_proximity 200

            // If the hunter has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius
            ai_aim_offset_sensitivity_hunter 30

            // How far in front of himself infected bot will check for a wall. Use '-1' to disable feature
            ai_wall_detection_distance -1
            ```
    </details>

    * <details><summary><b>AI Spitter</b></summary>

        * None
    </details>

    * <details><summary><b>AI Jockey</b></summary>

        * Modify Official ConVar
            ```php
            // AI Jockeys will move to attack survivors within this range (Default: 200)
            z_jockey_leap_range 1000
            ```
        * Plugin ConVar
            ```php
            // How close a jockey will approach before it starts hopping
            ai_hop_activation_proximity 500
            ```
    </details>

    * <details><summary><b>AI Charger</b></summary>

        * Plugin ConVar
            ```php
            // How close a charger will approach before charging
            ai_charge_proximity 300

            // If the charger has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius
            ai_aim_offset_sensitivity_charger 20
            ```
    </details>

* What is ```nb_assault```?
    * Tell all special infected bots to assault, attack survivors actively instead of not moving like idiots
    * This is official command
    * Can't use this command in multiplayer, unless the server has sv_cheats set to 1
    * By Default, the plugin forces server to execue this command every 2 seconds

- - - -
# 中文說明
強化每個AI 特感的行為與提高智商，積極攻擊倖存者

* 原理
    * 改變各種特感的行為

* 功能
    * <details><summary><b>AI Tank</b></summary>

        * 靠近倖存者一定範圍內不會主動丟石頭
        * 連跳
    </details>

    * <details><summary><b>Witch</b></summary>

        * 無
    </details>

    * <details><summary><b>AI Smoker</b></summary>

        * 更動的官方指令
            ```php
            // AI Smoker的舌頭準備拉走倖存者的期間，被攻擊超過250HP或自身血量才會死亡 (預設: 50)
            tongue_break_from_damage_amount 250

            // 當倖存者靠近範圍內的0.1秒後立刻吐舌頭 (預設: 1.5)
            smoker_tongue_delay 0.1
            ```
    </details>

    * <details><summary><b>AI Boomer</b></summary>

        * 更動的官方指令
            ```php
            // 被人類看見1000秒之後才會逃跑 (預設: 1.0)
            boomer_exposed_time_tolerance 1000.0

            // 當倖存者靠近範圍內的0.1秒後立刻嘔吐 (預設: 1.0)
            boomer_vomit_delay 0.1
            ```
    </details>

    * <details><summary><b>AI Hunter</b></summary>

        * 被攻擊的時候不會自動逃跑跳走 (只會出現在戰役/寫實模式)
        * 更動的官方指令
            ```php
            // 1000公尺範圍內才會蹲下準備撲人 (預設: 1000)
            hunter_pounce_ready_range 1000

            // 10000公尺範圍內才會撲人 (預設: 75)
            hunter_committed_attack_range 10000

            // 0公尺範圍內沒有蹲下的AI Hunter被攻擊時會逃跑跳走 (只會出現在戰役/寫實模式，預設: 1000)
            hunter_leap_away_give_up_range 0

            // AI Hunter跳躍的最大傾角 (避免飛過頭或飛太高，預設: 45)
            hunter_pounce_max_loft_angle 0

            // AI Hunter飛撲在空中的過程中受到150HP傷害或自身血量以上才會死亡 (避免飛撲過程中容易被殺死，預設: 50)
            z_pounce_damage_interrupt 150
            ```
        * 插件自帶的指令
            ```php
            // 強迫AI Hunter在1000公尺範圍內蹲下準備撲人
            ai_fast_pounce_proximity 1000

            // 強迫AI Hunter跳躍的最大傾角 (避免飛過頭或飛太高)
            ai_pounce_vertical_angle 7

            // 強制左右飛撲靠近目標，不要垂直飛向目標
            ai_pounce_angle_mean 10
            ai_pounce_angle_std 20

            // 離目標200公尺範圍內考慮直接垂直飛向目標
            ai_straight_pounce_proximity 200

            // 目標倖存者的準心如果在瞄自身AI Hunter的身體低於30度視野範圍內則強制飛撲
            ai_aim_offset_sensitivity_hunter 30

            // 前面有牆壁的範圍內則飛撲的角度會變高，嘗試越過障礙物 (-1: 無限範圍)
            ai_wall_detection_distance -1
            ```
    </details>

    * <details><summary><b>AI Spitter</b></summary>

        * 無
    </details>

    * <details><summary><b>AI Jockey</b></summary>

        * 更動的官方指令
            ```php
            // 1000公尺範圍內才會飛撲 (預設: 200)
            z_jockey_leap_range 1000
            ```
        * 插件自帶的指令
            ```php
            // 強迫AI Jockey在500公尺範圍內開始連跳
            ai_hop_activation_proximity 500
            ```
    </details>

    * <details><summary><b>AI Charger</b></summary>

        * 插件自帶的指令
            ```php
            // 強迫AI Charger在300公尺範圍內開始衝刺
            ai_charge_proximity 300

            // 目標倖存者的準心如果在瞄自身AI Charger的身體低於20度視野範圍內則強制衝刺
            ai_aim_offset_sensitivity_charger 20
            ```
    </details>

* 甚麼是 ```nb_assault```?
    * 強迫所有特感Bots主動往前攻擊倖存者而非像智障一樣待在原地等倖存者過來
    * 這是官方的指令
    * Server沒有開啟sv_cheats 作弊模式就不能輸入這條指令
    * 這插件預設會每2秒執行這條指令