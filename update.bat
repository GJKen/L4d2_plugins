@echo off
echo 更新l4d2_plugins代码
set /p info="输入更新的信息(例如:update %date:~0,10% %time:~0,5%):"
git init
git add .
git commit -m "%info%"
git push
set /p qr=是否打开git主页检查?(Y or N):
if /I %qr%==Y start https://github.com/GJKen/L4d2_plugins