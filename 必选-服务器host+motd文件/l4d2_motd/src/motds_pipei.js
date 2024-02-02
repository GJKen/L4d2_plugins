function ReplaceCmds(type, setu) {
	if (type == 1) {
		cmds.innerHTML = ('\
			<text class="title2">Q群:735468034</text><br />\
			<text>本服steam组 <a href="https://steamcommunity.com/groups/jkchan" title="jkchan" target="_blank">https://steamcommunity.com/groups/jkchan</a><br></text>\
			<text>打不过或有问题到<code>Telegram</code>联系我 <a href="https://t.me/GJK_en" title="@GJK_en" target="_blank">https://t.me/GJK_en</a></text><br><br>\
			<text class="title">为保持好的游玩环境,请路人玩家不要无理由投票踢出其他玩家<br>恶意黑枪和开挂等等不文明行为皆可游戏内使用!vk投票踢人</text><br><br>\
			<text class="title">想要匹配更多人,就设置steam下载地区为上海,加装<code>8 slots lobbies fixed</code>(8人大厅mod)可以匹配8人,不加装则4人匹配</text><br><br>\
			<text class="title">进服闪退,音效卡顿掉帧的解决方法:</text>\
			<ul>\
				<li>检查服务器当前地图是否为三方图,检查本地是否能正常进入三方图,如果本地三方图能正常进入,进不来服务器可能是别的原因</li>\
				<li>在选项→视频→高级设置中将"可用的页池内存"改为低可解决闪退问题<br></li>\
				<li>在游戏启动项添加<code>-heapsize 1500000 -num_edicts 4096 -processheap -highpriority</code>可解决音效卡顿掉帧问题</li>\
			</ul>\
		')
	}
	else if (type == 2) {
		cmds.innerHTML = ('\
		<p class="title_mode">介绍一下本服游戏的特性:<br>\
		默认进服之后的模式只有基本Sourcemod插件,<br>生还者随机叛变tank,!match投票更改游戏模式<br></p>\
		<ul>\
		</li>\
		<li>战役->普通战役: 和纯净没什么区别,只有基本Sourcemod插件</li>\
		<li>战役->多特战役: 部分常用插件,fbef0102刷特,2倍医疗</li>\
		<li>战役->多特增强: 部分常用插件,fbef0102刷特+特感加智插件,2倍医疗</li>\
		<li>药役->简单药役: 部分常用插件,fdxx刷特,击杀Witch回血,特感加智</li>\
		<li>药役->普通药役: 部分常用插件,GlowingTree880刷特件, 击杀Witch回血,特感加智</li>\
		<li>单人->HT训练: 部分常用插件,fbef0102刷特,2倍医疗</li>\
		</ul>\
		')
	}
	else if (type == 3) {
		cmds.innerHTML = ('\
		<code>!match</code>: 投票更改游戏模式<br />\
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
