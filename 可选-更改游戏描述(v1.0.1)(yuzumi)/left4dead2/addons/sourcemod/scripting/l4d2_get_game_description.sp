/*
 * 野生作者添加了一个配置文件方便萌新更改默认内容.
 */

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sourcescramble>

#define GAMEDATA	"l4d2_get_game_description"

MemoryPatch g_mGameDesPatch;	//记录内存修补数据
bool g_bPatchEnable;			//记录内存补丁状态
int g_iOS;						//记录不同系统下的修改位置起始点
char g_sPath[PLATFORM_MAX_PATH], g_sGameDes[128];			//最大128长度, 中文占3字节(UTF8), 全中文最多42(服务器文件函数里写死0x80(128)长度)
public Plugin myinfo =
{
	name = "Set Game Description",
	author = "yuzumi | 修改: 豆瓣酱な",
	version	= "1.0.1",
	description	= "Change Description at any time!",
	url = "https://github.com/joyrhyme/L4D2-Plugins/tree/main/Set_GameDescription"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion iEngineVersion = GetEngineVersion();
	if(iEngineVersion != Engine_Left4Dead2 && !IsDedicatedServer())
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2 and Dedicated Server!");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_set", Command_SetGameDes, "更改游戏描述 - Change Game Description");
	GetFileContent();//获取文件里的内容.
	GetInitGameData();//加载签名文件.
}

public void OnConfigsExecuted()
{
	GetFileContent();//获取文件里的内容.
}

//获取文件里的服名.
void GetFileContent()
{
	BuildPath(Path_SM, g_sPath, sizeof(g_sPath), "configs/l4d2_get_game_description.txt");
	if(FileExists(g_sPath))//判断文件是否存在.
		SetGameDescription();//文件已存在,获取文件里的内容.
	else
		IsWriteGameDescription("生存之旅 3");//文件不存在,创建文件并写入默认内容.
}

//获取文件里的内容.
void SetGameDescription()
{
	File file = OpenFile(g_sPath, "rb");

	if(file)
	{
		while(!file.EndOfFile())
			file.ReadLine(g_sGameDes, sizeof(g_sGameDes));
		TrimString(g_sGameDes);//整理获取到的字符串.
	}
	delete file;
}

//写入内容到文件里.
void IsWriteGameDescription(char[] sDescription)
{
	File file = OpenFile(g_sPath, "w");
	strcopy(g_sGameDes, sizeof(g_sGameDes), sDescription);
	TrimString(g_sGameDes);//写入内容前整理字符串.

	if(file)
		WriteFileString(file, g_sGameDes, false);//这个方法写入内容不会自动添加换行符.
	delete file;
}

void GetInitGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_mGameDesPatch = MemoryPatch.CreateFromConf(hGameData, "GetGameDescription::GameDescription");
	if (!g_mGameDesPatch.Validate())
		SetFailState("Failed to verify patch: \"GetGameDescription::GameDescription\"");
	else if (g_mGameDesPatch.Enable()) 
	{
		g_iOS = hGameData.GetOffset("OS") ? 4 : 1; //Linux从第5位开始,Win从第2位开始(从0开始算)
		StoreToAddress(g_mGameDesPatch.Address + view_as<Address>(g_iOS), view_as<int>(GetAddressOfString(g_sGameDes)), NumberType_Int32);
		PrintToServer("[%s] Enabled patch: \"GetGameDescription::GameDescription\"", GAMEDATA);
		g_bPatchEnable = true; //上面校验不通过的话应该不会Enable,所以记录这个就行?
	}
	delete hGameData;
}

Action Command_SetGameDes(int client, int args)
{
	if(IsCheckClientAccess(client))
	{
		if(args == 0)
		{
			GetFileContent();
			ReplyToCommand(client, "\x04[提示]\x05已重新加载配置文件(使用指令!set空格+内容设置新描述).");
			ReplyToCommand(client, "\x04[提示]\x05已设置新描述为\x04:\x05(\x03%s\x05)\x04.", g_sGameDes);
		}
		else
		{
			if (g_bPatchEnable)
			{
				char sArg[128];
				GetCmdArgString(sArg, sizeof(sArg));
				IsWriteGameDescription(sArg);//写入内容到文件里.
				ReplyToCommand(client, "\x04[提示]\x05已设置新描述为\x04:\x05(\x03%s\x05)\x04.", g_sGameDes);
			}
			else
				ReplyToCommand(client, "\x04[提示]\x05游戏签名文件未加载或无效.");
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05只限管理员使用该指令.");
	return Plugin_Handled;
}

bool IsCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}