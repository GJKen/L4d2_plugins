Admin Reserved Slots (剩餘通道只能管理員加入.. Sorry, Reserverd Slots for Admin..)

-Require-
L4dtoolz: https://github.com/Accelerator74/l4dtoolz/releases

-Changelog-
v1.5
-Remake Code
-Add ConVars

v1.0
-Original Post: https://bbs.3dmgame.com/thread-2804070-1-1.html

-ConVar-
cfg/sourcemod/l4d_reservedslots.cfg
// Reserved how many slots for Admin. 預留多少位置給管理員加入. (0=關閉 Off)
l4d_reservedslots_adm "1"

// Players with these flags have access to use admin reserved slots. (Empty = Everyone, -1: Nobody)
l4d_reservedslots_flag "z"

// If set to 1, reserved slots will hidden (subtracted 'l4d_reservedslots_adm' from the max slot 'sv_maxplayers')
l4d_reservedslots_hide "1"

-Message when kicked-
"剩餘位子只限管理員.. Sorry, Reserverd Slots for Admin.."
