#!/bin/sh
cd /home/ubuntu/steamcmd/l4d2
./srcds_run -game left4dead2 -insecure -tickrate 60 +map c2m1 +sv_lan 0 +port 27025 +servercfgfile server3.cfg +hostfile "host2.txt" +motdfile "motd2.txt"

#可选-游戏模式
#+mp_gamemode "coop"

#黑色嘉年华
#c2m1_highway

#教区
#c5m5_bridge

#暴风骤雨
#c4m1_milltown_a

#再见了晨茗
#msd1_town

#广州增城7.3
#zc_m1

#宜昌市
#yichang_01

#血迹
#bloodtracks_01

#深埋
#bdp_bunker01
