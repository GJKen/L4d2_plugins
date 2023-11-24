#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name = "[L4D2]坦克名字",
	author = "奈",
	description = "修改坦克名字为碧蓝档案角色名",
	version = "1.0",
	url = "https://github.com/NanakaNeko/l4d2_plugins_coop"
};

public void OnPluginStart()
{
	HookEvent("tank_spawn", Tank_Spawn, EventHookMode_PostNoCopy);
}

public void Tank_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client =  GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && IsFakeClient(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
		ChangeTankName(client);
}

void ChangeTankName(int client)
{
	int num = GetRandomInt(0, 132);
	switch(num)
	{
		case 0:
		{
			SetClientInfo(client, "name", "阿洛娜");
		}
		case 1:
		{
			SetClientInfo(client, "name", "普拉娜");
		}
		case 2:
		{
			SetClientInfo(client, "name", "七神琳");
		}
		case 3:
		{
			SetClientInfo(client, "name", "由良木桃香");
		}
		case 4:
		{
			SetClientInfo(client, "name", "岩柜步梦");
		}
		case 5:
		{
			SetClientInfo(client, "name", "不知火花耶");
		}
		case 6:
		{
			SetClientInfo(client, "name", "扇喜葵");
		}
		case 7:
		{
			SetClientInfo(client, "name", "灰音");
		}
		case 8:
		{
			SetClientInfo(client, "name", "砂狼白子");
		}
		case 9:
		{
			SetClientInfo(client, "name", "小鸟游星野");
		}
		case 10:
		{
			SetClientInfo(client, "name", "黑见茜香");
		}
		case 11:
		{
			SetClientInfo(client, "name", "奥空绫音");
		}
		case 12:
		{
			SetClientInfo(client, "name", "十六夜野乃美");
		}
		case 13:
		{
			SetClientInfo(client, "name", "羽沼真琴");
		}
		case 14:
		{
			SetClientInfo(client, "name", "枣伊吕波");
		}
		case 15:
		{
			SetClientInfo(client, "name", "伊吹");
		}
		case 16:
		{
			SetClientInfo(client, "name", "皋月");
		}
		case 17:
		{
			SetClientInfo(client, "name", "空崎阳奈");
		}
		case 18:
		{
			SetClientInfo(client, "name", "银镜伊织");
		}
		case 19:
		{
			SetClientInfo(client, "name", "天雨亚子");
		}
		case 20:
		{
			SetClientInfo(client, "name", "火宫千夏");
		}
		case 21:
		{
			SetClientInfo(client, "name", "陆八魔亚瑠");
		}
		case 22:
		{
			SetClientInfo(client, "name", "鬼方佳世子");
		}
		case 23:
		{
			SetClientInfo(client, "name", "浅黄无月");
		}
		case 24:
		{
			SetClientInfo(client, "name", "伊草遥香");
		}
		case 25:
		{
			SetClientInfo(client, "name", "黑馆羽留奈");
		}
		case 26:
		{
			SetClientInfo(client, "name", "狮子堂泉");
		}
		case 27:
		{
			SetClientInfo(client, "name", "赤司淳子");
		}
		case 28:
		{
			SetClientInfo(client, "name", "鳄渊亚伽里");
		}
		case 29:
		{
			SetClientInfo(client, "name", "爱清风华");
		}
		case 30:
		{
			SetClientInfo(client, "name", "牛牧茱莉");
		}
		case 31:
		{
			SetClientInfo(client, "name", "冰室濑奈");
		}
		case 32:
		{
			SetClientInfo(client, "name", "霞");
		}
		case 33:
		{
			SetClientInfo(client, "name", "下仓惠");
		}
		case 34:
		{
			SetClientInfo(client, "name", "绮罗罗");
		}
		case 35:
		{
			SetClientInfo(client, "name", "绘里香");
		}
		case 36:
		{
			SetClientInfo(client, "name", "调月莉央");
		}
		case 37:
		{
			SetClientInfo(client, "name", "早濑优香");
		}
		case 38:
		{
			SetClientInfo(client, "name", "生盐乃爱");
		}
		case 39:
		{
			SetClientInfo(client, "name", "黑崎小雪");
		}
		case 40:
		{
			SetClientInfo(client, "name", "才羽绿");
		}
		case 41:
		{
			SetClientInfo(client, "name", "才羽桃井");
		}
		case 42:
		{
			SetClientInfo(client, "name", "花冈柚子");
		}
		case 43:
		{
			SetClientInfo(client, "name", "天童爱丽丝");
		}
		case 44:
		{
			SetClientInfo(client, "name", "美甘宁瑠");
		}
		case 45:
		{
			SetClientInfo(client, "name", "角楯花凛");
		}
		case 46:
		{
			SetClientInfo(client, "name", "室笠朱音");
		}
		case 47:
		{
			SetClientInfo(client, "name", "一之濑明日奈");
		}
		case 48:
		{
			SetClientInfo(client, "name", "飞鸟马时");
		}
		case 49:
		{
			SetClientInfo(client, "name", "各务千寻");
		}
		case 50:
		{
			SetClientInfo(client, "name", "音濑小玉");
		}
		case 51:
		{
			SetClientInfo(client, "name", "小涂真纪");
		}
		case 52:
		{
			SetClientInfo(client, "name", "小钩晴");
		}
		case 53:
		{
			SetClientInfo(client, "name", "猫冢响");
		}
		case 54:
		{
			SetClientInfo(client, "name", "丰见亚都梨");
		}
		case 55:
		{
			SetClientInfo(client, "name", "乙花堇");
		}
		case 56:
		{
			SetClientInfo(client, "name", "和泉元英美");
		}
		case 57:
		{
			SetClientInfo(client, "name", "明星阳葵");
		}
		case 58:
		{
			SetClientInfo(client, "name", "圣园弥香");
		}
		case 59:
		{
			SetClientInfo(client, "name", "桐藤渚");
		}
		case 60:
		{
			SetClientInfo(client, "name", "百合园圣亚");
		}
		case 61:
		{
			SetClientInfo(client, "name", "剑先弦生");
		}
		case 62:
		{
			SetClientInfo(client, "name", "静山麻白");
		}
		case 63:
		{
			SetClientInfo(client, "name", "羽川莲实");
		}
		case 64:
		{
			SetClientInfo(client, "name", "一花");
		}
		case 65:
		{
			SetClientInfo(client, "name", "歌住樱子");
		}
		case 66:
		{
			SetClientInfo(client, "name", "若叶日向");
		}
		case 67:
		{
			SetClientInfo(client, "name", "伊落玛丽");
		}
		case 68:
		{
			SetClientInfo(client, "name", "古关忧");
		}
		case 69:
		{
			SetClientInfo(client, "name", "圆堂志美子");
		}
		case 70:
		{
			SetClientInfo(client, "name", "阿慈谷日富美");
		}
		case 71:
		{
			SetClientInfo(client, "name", "白洲梓");
		}
		case 72:
		{
			SetClientInfo(client, "name", "下江小春");
		}
		case 73:
		{
			SetClientInfo(client, "name", "浦和花子");
		}
		case 74:
		{
			SetClientInfo(client, "name", "柚鸟夏");
		}
		case 75:
		{
			SetClientInfo(client, "name", "杏山千纱");
		}
		case 76:
		{
			SetClientInfo(client, "name", "栗村爱莉");
		}
		case 77:
		{
			SetClientInfo(client, "name", "伊原木喜美");
		}
		case 78:
		{
			SetClientInfo(client, "name", "苍森美祢");
		}
		case 79:
		{
			SetClientInfo(client, "name", "朝颜花绘");
		}
		case 80:
		{
			SetClientInfo(client, "name", "鹫见芹奈");
		}
		case 81:
		{
			SetClientInfo(client, "name", "守月铃美");
		}
		case 82:
		{
			SetClientInfo(client, "name", "宇泽澪纱");
		}
		case 83:
		{
			SetClientInfo(client, "name", "天地妮娅");
		}
		case 84:
		{
			SetClientInfo(client, "name", "和乐知世");
		}
		case 85:
		{
			SetClientInfo(client, "name", "桑上佳穗");
		}
		case 86:
		{
			SetClientInfo(client, "name", "菖蒲");
		}
		case 87:
		{
			SetClientInfo(client, "name", "御棱名草");
		}
		case 88:
		{
			SetClientInfo(client, "name", "河和静子");
		}
		case 89:
		{
			SetClientInfo(client, "name", "朝比奈菲娜");
		}
		case 90:
		{
			SetClientInfo(client, "name", "海花");
		}
		case 91:
		{
			SetClientInfo(client, "name", "久田伊树菜");
		}
		case 92:
		{
			SetClientInfo(client, "name", "大野月夜");
		}
		case 93:
		{
			SetClientInfo(client, "name", "千鸟三千留");
		}
		case 94:
		{
			SetClientInfo(client, "name", "水羽三森");
		}
		case 95:
		{
			SetClientInfo(client, "name", "勇美枫");
		}
		case 96:
		{
			SetClientInfo(client, "name", "春日椿");
		}
		case 97:
		{
			SetClientInfo(client, "name", "狐坂若藻");
		}
		case 98:
		{
			SetClientInfo(client, "name", "葛叶");
		}
		case 99:
		{
			SetClientInfo(client, "name", "连河洁莉诺");
		}
		case 100:
		{
			SetClientInfo(client, "name", "池仓玛丽娜");
		}
		case 101:
		{
			SetClientInfo(client, "name", "佐城智惠");
		}
		case 102:
		{
			SetClientInfo(client, "name", "间宵时雨");
		}
		case 103:
		{
			SetClientInfo(client, "name", "天见和香");
		}
		case 104:
		{
			SetClientInfo(client, "name", "秋泉红叶");
		}
		case 105:
		{
			SetClientInfo(client, "name", "姬木爱瑠");
		}
		case 106:
		{
			SetClientInfo(client, "name", "安守实里");
		}
		case 107:
		{
			SetClientInfo(client, "name", "荒槙八云");
		}
		case 108:
		{
			SetClientInfo(client, "name", "三善贵音");
		}
		case 109:
		{
			SetClientInfo(client, "name", "龙华妃姬");
		}
		case 110:
		{
			SetClientInfo(client, "name", "近卫美奈");
		}
		case 111:
		{
			SetClientInfo(client, "name", "朱城瑠美");
		}
		case 112:
		{
			SetClientInfo(client, "name", "鹿山丽情");
		}
		case 113:
		{
			SetClientInfo(client, "name", "春原旬");
		}
		case 114:
		{
			SetClientInfo(client, "name", "春原心菜");
		}
		case 115:
		{
			SetClientInfo(client, "name", "药子沙耶");
		}
		case 116:
		{
			SetClientInfo(client, "name", "申谷海");
		}
		case 117:
		{
			SetClientInfo(client, "name", "尾刃环奈");
		}
		case 118:
		{
			SetClientInfo(client, "name", "中务桐乃");
		}
		case 119:
		{
			SetClientInfo(client, "name", "合欢垣吹雪");
		}
		case 120:
		{
			SetClientInfo(client, "name", "月雪宫子");
		}
		case 121:
		{
			SetClientInfo(client, "name", "空井咲");
		}
		case 122:
		{
			SetClientInfo(client, "name", "霞泽美游");
		}
		case 123:
		{
			SetClientInfo(client, "name", "风仓萌");
		}
		case 124:
		{
			SetClientInfo(client, "name", "七度雪乃");
		}
		case 125:
		{
			SetClientInfo(client, "name", "妮可");
		}
		case 126:
		{
			SetClientInfo(client, "name", "胡桃");
		}
		case 127:
		{
			SetClientInfo(client, "name", "音葵");
		}
		case 128:
		{
			SetClientInfo(client, "name", "戒野美咲");
		}
		case 129:
		{
			SetClientInfo(client, "name", "秤亚津子");
		}
		case 130:
		{
			SetClientInfo(client, "name", "锭前纱织");
		}
		case 131:
		{
			SetClientInfo(client, "name", "清澄晶");
		}
		case 132:
		{
			SetClientInfo(client, "name", "初音未来");
		}
	}
}