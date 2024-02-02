function randomSetu(){
	var images = [
		"http://pan.cangg.cn/file/20200242015507936.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_2_qnBFef42FU.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_3_2XMatFmYCc.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_4_YC6ECb8cm2.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_5_HIUL1b7Css.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_6_eZxD4P3bd0.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_7_vQujhDBwqd.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_8_Wq7IZuumAS.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_9_bWMVMdCWUH.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_10_wBhY0EK5aT.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_11_nGtzaH1fnr.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_12_DxTNFIucSq.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_13_cR5hHNloNU.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_14_aRUh8wEvxE.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_15_DsWHjnXTFv.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_16_h7FeIZiQCV.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_17_tvVW3Zl51A.jpg",
		"http://cdn-us.imgs.moe/2024/02/02/l4d2_motd_18_q0mqpddLcw.jpg"
	];
	//生成随机索引值
	var randomIndex = Math.floor(Math.random() * images.length);
	console.log(randomIndex);
	document.querySelector("#bgimg").style.backgroundImage = 'url(' + images[randomIndex] + ')';
}