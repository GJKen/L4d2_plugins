#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define PLUGIN_VERSION	"2.1.4"
#define CVAR_FLAGS		FCVAR_NOTIFY

char g_sWrite[][][] = 
{
	{"启用设置服务器tick插件? 0=禁用, 1=启用.", "1"},
	{"设置服务器的最大tick(最大值:100)(注意:需要安装tick解锁扩展).", "100"},
	{"设置服务器的最大FPS帧率(需要注意FPS必须大于tick). 0=不限制.", "0"},
	{"设置客户端的cl_interp_ratio值(lerp). -1=客户端自行设置.", "-1"},
	{"设置客户端的cl_interp_ratio值(lerp),当sv_client_min_interp_ratio的值为-1时此参数无效.", "0"},
	{"设置每帧可发送的拆分数据包的片段数(默认值:1).", "2"},
	{"设置服务器世界的更新频率(默认值:0.1),数值越低丧尸和女巫的更新频率越高,非常耗费CPU.", "0.024"},
	{"根据速率设置,等待发送下一个数据包的最大秒数(默认值:4). 0=无限制.", "0.0001"}
	
};

public Plugin myinfo = 
{
	name = "设置服务器tick",
	author = "豆瓣酱な",
	description = "根据用户设置的值自动设置tick参数",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	IsReadFileValues();
	CreateConVar("l4d2_tickrate_version", PLUGIN_VERSION, "设置服务器tick插件的版本.(注意:启动项的值决定服务器的最大tick,没有设置启动项则使用默认值30.)", CVAR_FLAGS|FCVAR_SPONLY|FCVAR_REPLICATED);
}

public void OnMapStart()
{
	IsReadFileValues();
}

void IsReadFileValues()
{
	char g_sKvPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, g_sKvPath, sizeof(g_sKvPath), "configs/l4d2_tickrate_enabler.cfg");
	KeyValues kv = new KeyValues("Values");
	if (!FileExists(g_sKvPath))
	{
		File file = OpenFile(g_sKvPath, "w");
		if (!file)
			LogError("无法读取文件: \"%s\"", g_sKvPath);
		// 写入内容.
		for (int i = 0; i < sizeof(g_sWrite); i++)
			kv.SetString(g_sWrite[i][0], g_sWrite[i][1]);
		// 返回上一页.
		kv.Rewind();
		// 把内容写入文件.
		kv.ExportToFile(g_sKvPath);
		delete file;
	}
	else if (kv.ImportFromFile(g_sKvPath)) //文件存在就导入kv数据,false=文件存在但是读取失败.
	{
		char sData[sizeof(g_sWrite)][128];
		// 获取Kv文本内信息写入变量中.
		for (int i = 0; i < sizeof(sData); i++)
			kv.GetString(g_sWrite[i][0], sData[i], sizeof(sData[]), g_sWrite[i][1]);
		if (StringToInt(sData[0]) > 0)
			GetCvarValues(StringToInt(sData[1]), StringToInt(sData[2]), StringToInt(sData[3]), StringToInt(sData[4]), StringToInt(sData[5]), StringToFloat(sData[6]), StringToFloat(sData[7]));
	}
	delete kv;
}

void GetCvarValues(int iMaxTick, int iMaxFps, int iMinRatio, int iMaxRatio, int iSplitrate, float fFrequency, float fMaxcleartime)
{
	if (iMaxTick > 100)
		iMaxTick = 100;

	if (iMaxFps > 0 && iMaxFps < 100)
		iMaxFps = 100;

	GetCommandParamInt(iMaxTick, iMaxFps, iMinRatio, iMaxRatio, iSplitrate, fFrequency, fMaxcleartime);
}

//获取启动项-tickrate的值.
void GetCommandParamInt(int iMaxTick, int iMaxFps, int iMinRatio, int iMaxRatio, int iSplitrate, float fFrequency, float fMaxcleartime)
{
	int g_iStartupItem = GetCommandLineParamInt("-tickrate", 30);//没有获取到启动项的值则使用这里的默认值:30.
	
	if(g_iStartupItem < iMaxTick)
		iMaxTick = g_iStartupItem;
	
	SetServerCvarValues(iMaxTick, iMaxFps, iMinRatio, iMaxRatio, iSplitrate, fFrequency, fMaxcleartime);//设置tick参数.
}

//设置tick参数.
void SetServerCvarValues(int iMaxTick, int iMaxFps, int iMinRatio, int iMaxRatio, int iSplitrate, float fFrequency, float fMaxcleartime)
{
	int iMinRate		= iMaxTick * 1000;
	int iMaxRate		= iMaxTick * 1000;
	int iMinCmdRate		= iMaxTick;
	int iMaxCmdRate		= iMaxTick;
	int iMinUpdateRate	= iMaxTick;
	int iMaxUpdateRate	= iMaxTick;
	int iNetMaxRate		= RoundFloat((float(iMaxTick) / 2.0) * 1000.0);
	
	SetConVarInt(FindConVar("fps_max"), iMaxFps, false, false);//设置服务器的最大帧率. 0=无限制.
	SetConVarInt(FindConVar("sv_minrate"), iMinRate, false, false);//设置允许的最小带宽速率. 0=无限制.
	SetConVarInt(FindConVar("sv_maxrate"), iMaxRate, false, false);//设置允许的最大带宽速率. 0=无限制.
	SetConVarInt(FindConVar("sv_mincmdrate"), iMinCmdRate, false, false);//不清楚有什么用.
	SetConVarInt(FindConVar("sv_maxcmdrate"), iMaxCmdRate, false, false);//不清楚有什么用.
	SetConVarInt(FindConVar("sv_minupdaterate"), iMinUpdateRate, false, false);//设置服务器每秒允许的最小更新数.
	SetConVarInt(FindConVar("sv_maxupdaterate"), iMaxUpdateRate, false, false);//设置服务器每秒允许的最大更新数.
	SetConVarInt(FindConVar("net_splitpacket_maxrate"), iNetMaxRate, false, false);//排队拆分数据包块时每秒的最大字节数.
	SetConVarInt(FindConVar("net_splitrate"), iSplitrate, false, false);//设置每帧可发送的拆分数据包的片段数(默认值:1).
	SetConVarInt(FindConVar("sv_client_min_interp_ratio"), iMinRatio, false, false);//设置客户端的cl_interp_ratio值(仅当客户端已连接时). -1 = 客户端自行设置.
	SetConVarInt(FindConVar("sv_client_max_interp_ratio"), iMaxRatio, false, false);//设置客户端的cl_interp_ratio值(仅当客户端已连接时),当sv_client_min_interp_ratio设为-1时此cvar无效.
	SetConVarFloat(FindConVar("net_maxcleartime"), fMaxcleartime, false, false);//根据速率设置,等待发送下一个数据包的最大秒数(默认值:4). 0=无限制.
	SetConVarFloat(FindConVar("nb_update_frequency"), fFrequency, false, false);//设置服务器世界的更新频率(默认值:0.1),数值越低丧尸和女巫的更新频率越高,非常耗费CPU.
	
	if (iMaxTick > 30)//设置的tick大于30,所以这里验证下设置tick成功没有
	{
		//这里使用下一帧写入管理员.
		DataPack hPack = new DataPack();
		hPack.WriteCell(iMaxTick);
		hPack.WriteCell(iMaxFps);
		hPack.WriteCell(iMinRatio);
		hPack.WriteCell(iMaxRatio);
		hPack.WriteCell(iSplitrate);
		hPack.WriteFloat(fFrequency);
		hPack.WriteFloat(fMaxcleartime);
		RequestFrame(IsWriteValues, hPack);//延迟一帧获取服务器的tick值.
	}
		
}

//获取服务器的tick值.
void IsWriteValues(DataPack hPack)
{
	hPack.Reset();
	int iMaxTick = hPack.ReadCell();
	int iMaxFps = hPack.ReadCell();
	int iMinRatio = hPack.ReadCell();
	int iMaxRatio = hPack.ReadCell();
	int iSplitrate = hPack.ReadCell();
	float fFrequency = hPack.ReadFloat();
	float fMaxcleartime = hPack.ReadFloat();

	int iGetTick = RoundToNearest(1.0 / GetTickInterval());//如果没有安装tick解锁扩展的话这个值最大为:30.

	if (iMaxTick > iGetTick)//需要设置的tick大于服务器当前的tick,可能是设置30tick以上失败.
	{
		iMaxTick = iGetTick;//把当前获取到的服务器tick值用来重新设置tick.
		SetServerCvarValues(iMaxTick, iMaxFps, iMinRatio, iMaxRatio, iSplitrate, fFrequency, fMaxcleartime);//使用新值重新设置服务器tick.
	}
}
/*
bool IsJudgeString(char[] g_sArg, int g_iArg)
{
	for (int i = 0; i < g_iArg; i++)
		if(IsCharNumeric(g_sArg[i]))
			return false;
	
	return true;
}*/