var setu;

function ReplaceCmds(type, setu) {
	if (type == 1) {
		cmds.innerHTML = ("<text>本服为拉稀酱赞助的绝境服</text><br><br>\
	<text class='title'>进服闪退,音效卡顿掉帧的解决方法:</text>\
	<ul>\
	<li>检查服务器当前地图是否为三方图,检查本地是否能正常进入三方图,如果本地三方图能正常进入,进不来服务器可能是别的原因</li>\
	<li>在选项→视频→高级设置中将'可用的页池内存'改为低可解决闪退问题<br> </li>\
	<li>在游戏启动项添加<br><code>-heapsize 1500000 -num_edicts 4096 -processheap -highpriority</code>可解决音效卡顿掉帧问题</li>\
	</ul><br>")
	}
	else if (type == 2) {
		cmds.innerHTML = ('\
		<ul class="title_mode">\
		<p>介绍一下本服游戏的特性:<br>默认进服之后为绝境模式,有基本Sourcemod插件和部分常用插件</p>\
		<ul>\
		<li id="btn6">刷特时间调整↴</li>\
		<table>\
			<tbody>\
				<tr>\
					<td>所有特感刷特时间20s</td>\
					<td>玩家离开安全区30s后刷特</td>\
					<td>Tank存在不刷特</td>\
				</tr>\
			</tbody>\
		</table>\
		<li>特感同时出现的最大数量18</li><br>\
		<li id="btn6" onclick="ReplaceCmds(6)">控制类特感同时出现的总数↴</li>\
		<table>\
			<tbody>\
				<tr>\
					<td>Boomer*4</td>\
					<td>Charger*3</td>\
					<td>Hunter*3</td>\
				</tr>\
				<tr>\
					<td>Jockey*3</td>\
					<td>Smoker*3</td>\
					<td>Spitter*2</td>\
				</tr>\
			</tbody>\
		</table>\
		<li id="btn6">武器调整↴\
		<table>\
			<tbody>\
				<tr>\
					<td>awp 2.2倍伤害(253)</td>\
					<td>scout 2.5倍伤害(262.5)</td>\
				</tr>\
				<tr>\
					<td>sg552 1.2倍伤害(38)</td>\
					<td>mp5 1.2倍伤害(28)</td>\
				</tr>\
				<tr>\
					<td>M60增加备弹至450,打空弹夹不会掉落</td>\
				</tr>\
			</tbody>\
		</table>\
		<li>特感主动出击?可能</li>\
		</ul>')
	}
	else if (type == 3) {
		cmds.innerHTML = ('\
		<code>!v</code> | <code>!votes</code>: 多功能投票, 不同游戏模式不同的投票内容<br />\
		<code>!maps</code>: 投票换地图 可更换三方图 自选地图章节<br />\
		<code>!nxmaps</code>: 下一张地图投票(需在救援关才能投票)<br />\
		<code>!afk</code>: 闲置 | <code>!away / !s</code>: 旁观 | <code>!join / !jg</code>: 加入生还<br />\
		<code>!teams</code>: 查看团队信息<br />\
		<code>!b</code> | <code>!buy</code> | <code>!rpg</code>: 商店<br />\
		<code>!zs</code>: 转生异世界<br />\
		<code>!g</code>: 丢物品<br />\
		<code>z(订购键)</code>: 订购键的<code class="light">看</code>可标记物品 / 路线<br />')
	}
	else if (type == 4) {
		bgimg.style.zIndex = "9"
	}
	else if (setu == 1) {
		randomSetu();
	}
}
