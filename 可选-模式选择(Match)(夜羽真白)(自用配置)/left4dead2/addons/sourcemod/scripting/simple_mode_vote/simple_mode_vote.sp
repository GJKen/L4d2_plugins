/**
* @Author 夜羽真白
* @Date 2023-06-12 10:56:32
* @Description 模式投票
* @Version 1.0.0.0
* @GitHub https://github.com/GlowingTree880/L4D2_LittlePlugins
**/

#define CVAR_FLAG FCVAR_NOTIFY
#define MODULE_VOTE_PREFIX "Match"
#define MENU_DISPLAY_TIME 20

Handle
    g_hVote;

KeyValues
    modeKey;

ConVar
    g_hRootKeyName,
    g_hKeyName,
    g_hModeMaxPlayers,
    g_hVotePlayerLimit;
ConVar
    g_hMaxPlayers;

char
    g_sCfg[PLATFORM_MAX_PATH];

public void voteModulePluginStart()
{

    g_hRootKeyName = CreateConVar("simple_mode_rootkey_name", "MatchModes", "模式文件中的根目录键名称", CVAR_FLAG);
    g_hKeyName = CreateConVar("simple_mode_key_name", "name", "每个模式显示名称的键名称", CVAR_FLAG);
    g_hModeMaxPlayers = CreateConVar("simpl_mode_maxplayers", "4", "模式加载完成后, 设置服务器位置为多少", CVAR_FLAG, true, 1.0, true, 31.0);
    g_hVotePlayerLimit = CreateConVar("simple_mode_vote_player_limit", "1", "发起模式投票的最小玩家数量", CVAR_FLAG, true, 1.0, true, 31.0);

    g_hMaxPlayers = FindConVar("sv_maxplayers");

    char config[PLATFORM_MAX_PATH], rootKeyName[64];
    if (g_hModeConfig != null) {
        g_hModeConfig.GetString(config, sizeof(config));
        BuildPath(Path_SM, config, sizeof(config), "%s", config);

        g_hRootKeyName.GetString(rootKeyName, sizeof(rootKeyName));
        modeKey = new KeyValues(rootKeyName);
        if (!modeKey.ImportFromFile(config)) {
            SetFailState("[%s]: 无法找到根目录键名: %s", MODULE_VOTE_PREFIX, rootKeyName);
        }
    }

    RegConsoleCmd("sm_match", matchVoteCmdHandler);
    RegConsoleCmd("sm_rmatch", matchResetVoteCmdHandler);
}

public void OnConfigsExecuted() {
    if (g_hMaxPlayers == null) {
        return;
    }
    g_hMaxPlayers.SetInt(g_hModeMaxPlayers.IntValue);
}

public void OnPluginEnd() {
    g_hMaxPlayers.RestoreDefault();
}

/**
* !match 命令回调
* @param client 使用命令的客户端索引
* @param args 参数
* @return Action
**/
public Action matchVoteCmdHandler(int client, int args)
{
    if (!IsValidClient(client) || IsFakeClient(client)) {
        return Plugin_Handled;
    }

    if (args > 0) {
        char argStr[64], modeDisplayName[PLATFORM_MAX_PATH];
        GetCmdArg(1, argStr, sizeof(argStr));
        if (findConfigName(argStr, modeDisplayName, sizeof(modeDisplayName)) && startMatchVote(client, argStr)) {
            strcopy(g_sCfg, sizeof(g_sCfg), argStr);
            FakeClientCommand(client, "Vote Yes");
        }
        
        return Plugin_Handled;
    }

    // 不带参数则显示更换模式菜单
    showMatchModeMenu(client);
    return Plugin_Continue;
}

/**
* !rmatch 卸载模式命令回调
* @param client 使用命令的客户端索引
* @param args 参数
* @return Action
**/
public Action matchResetVoteCmdHandler(int client, int args) {
    if (!IsValidClient(client)) {
        return Plugin_Handled;
    }
    
    startResetMatchVote(client);
    return Plugin_Continue;
}

void startResetMatchVote(int client) {
    if (!IsValidClient(client)) {
        return;
    }
    if (GetClientTeam(client) <= TEAM_SPECTATOR) {
        CPrintToChat(client, "[{G}%s{W}] {G}杂鱼旁观不能发起卸载配置投票捏❤", MODULE_VOTE_PREFIX);
        return;
    }
    if (!isModeLoaded) {
        CPrintToChat(client, "[{G}%s{W}] {G}当前未加载任何配置模式", MODULE_VOTE_PREFIX);
        return;
    }
    if (!IsNewBuiltinVoteAllowed()) {
        CPrintToChat(client, "[{G}%s{W}] {G}没看到正在进行的投票吗?", MODULE_VOTE_PREFIX);
        return;
    }
    
    int i, index, connectCount;
    int[] players = new int[MaxClients];
    for (i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i)) {
            connectCount++;
        }
        if (!IsValidClient(i) || IsFakeClient(i) || GetClientTeam(i) <= TEAM_SPECTATOR) {
            continue;
        }
        players[index++] = i;
    }
    if (connectCount > 0) {
        CPrintToChat(client, "[{G}%s{W}] {G}当前有 {O}%d {G}位正在连接中的玩家,不能发起卸载配置投票捏❤", MODULE_VOTE_PREFIX, connectCount);
        return;
    }

    char title[PLATFORM_MAX_PATH];
    FormatEx(title, sizeof(title), "是否卸载现有模式");
    g_hVote = CreateBuiltinVote(ResetVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
    SetBuiltinVoteArgument(g_hVote, title);
    DisplayBuiltinVote(g_hVote, players, index, MENU_DISPLAY_TIME);
    // CPrintToChatAll("[{G}%s{W}] {G}玩家 {O}%N {G}发起了一个卸载当前模式的投票", MODULE_VOTE_PREFIX, client);
    CPrintToChatAll("[{G}%s{W}] {B}%N {G}杂鱼发起一个卸载当前模式的投票❤", MODULE_VOTE_PREFIX, client);
    FakeClientCommand(client, "Vote Yes");
}

public int ResetVoteActionHandler(Handle vote, BuiltinVoteAction action, int item, int client) {
    switch (action) {
        case BuiltinVoteAction_End: {
            delete g_hVote;
            g_hVote = null;
        } case BuiltinVoteAction_Cancel: {
            DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(item));
        } case BuiltinVoteAction_VoteEnd: {
            if (item == BUILTINVOTES_VOTE_YES) {
                char buffer[PLATFORM_MAX_PATH];
                FormatEx(buffer, sizeof(buffer), "正在卸载当前模式❤", g_sCfg);
                DisplayBuiltinVotePass(vote, buffer);
                ServerCommand("sm_resetmatch");
            } else if (item == BUILTINVOTES_VOTE_NO) {
                DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
            }
        }
    }
    return 0;
}

/**
* 模式选择菜单
* @param client 呼出菜单的客户端 ID
* @return void
**/
void showMatchModeMenu(int client) {
    if (!IsValidClient(client)) {
        return;
    }

    Menu menu = new Menu(MatchModeMenuHandler);
    menu.SetTitle("♥你喜欢什么?");
    
    char buffer[64];
    modeKey.Rewind();
    if (modeKey.GotoFirstSubKey()) {
        do {
            modeKey.GetSectionName(buffer, sizeof(buffer));
            menu.AddItem(buffer, buffer);
        } while (modeKey.GotoNextKey(false));
    }
    menu.Display(client, MENU_DISPLAY_TIME);
}

/**
* 模式选择菜单回调函数
* @param menu 菜单句柄
* @param action 行为
* @param client 做出行为的客户端索引
* @param item 选择的选项
* @return int
**/
public int MatchModeMenuHandler(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_End) {
        delete menu;
    } else if (action == MenuAction_Select) {
        char info[64], keyStr[64], buffer[64];
        menu.GetItem(item, info, sizeof(info));

        // 读取当前 section 名称以及 section 下的模式名称 ZoneModConfig -> ZoneMod -> name: "ZoneMod"
        modeKey.Rewind();
        if (modeKey.JumpToKey(info) && modeKey.GotoFirstSubKey()) {
            Menu configMenu = new Menu(ConfigsMenuHandler);
            FormatEx(buffer, sizeof(buffer), "%s:", info);
            configMenu.SetTitle(buffer);

            g_hKeyName.GetString(keyStr, sizeof(keyStr));
            do {
                modeKey.GetSectionName(info, sizeof(info));
                modeKey.GetString(keyStr, buffer, sizeof(buffer));
                configMenu.AddItem(info, buffer);
            } while (modeKey.GotoNextKey());
            configMenu.Display(client, MENU_DISPLAY_TIME);
        } else {
            CPrintToChat(client, "[{G}%s{W}] {G}无法找到配置文件 {O}%s", MODULE_VOTE_PREFIX, info);
            showMatchModeMenu(client);
        }
    }
    return 0;
}

/**
* 二级子模式选择菜单回调函数
* @param menu 菜单句柄
* @param action 行为
* @param client 做出行为的客户端索引
* @param item 选择的选项
* @return int
**/
public int ConfigsMenuHandler(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_End) {
        delete menu;
    } else if (action == MenuAction_Cancel) {
        showMatchModeMenu(client);
    } else if (action == MenuAction_Select) {
        char info[64], buffer[64];
        menu.GetItem(item, info, sizeof(info), _, buffer, sizeof(buffer));

        if (startMatchVote(client, buffer)) {
            strcopy(g_sCfg, sizeof(g_sCfg), info);
            FakeClientCommand(client, "Vote Yes");
        } else {
            showMatchModeMenu(client);
        }
    }
    return 0;
}

/**
* 在模式配置文件中查找指定的模式名称是否存在
* @param name 模式名称
* @param modeDisplayName 模式的显示名称
* @param len 长度
* @return 
**/
static bool findConfigName(const char[] name, char[] modeDisplayName, int len) {
    if (modeKey == null) {
        return false;
    }
    modeKey.Rewind();

    char key[64];
    g_hKeyName.GetString(key, sizeof(key));
    
    if (modeKey.GotoFirstSubKey()) {
        do {
            if (modeKey.JumpToKey(name)) {
                modeKey.GetString(key, modeDisplayName, len);
                return true;
            }
        } while (modeKey.GotoNextKey(false));
    }
    return false;
}

bool startMatchVote(int client, const char[] name) {
    if (!IsValidClient(client)) {
        return false;
    }
    if (GetClientTeam(client) <= TEAM_SPECTATOR) {
        CPrintToChat(client, "[{G}%s{W}] {G}杂鱼旁观不能发起卸载配置投票捏❤", MODULE_VOTE_PREFIX);
        return false;
    }
    if (IsBuiltinVoteInProgress()) {
        CPrintToChat(client, "[{G}%s{W}] {G}没看到正在进行的投票吗?", MODULE_VOTE_PREFIX);
        return false;
    }
    if (!IsNewBuiltinVoteAllowed()) {
        CPrintToChat(client, "[{G}%s{W}] {G}当前不允许发起新的投票捏❤", MODULE_VOTE_PREFIX);
        return false;
    }

    // 可以发起新的投票
    int index = 0;
    int[] players = new int[MaxClients];
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsValidClient(i) || IsFakeClient(i) || GetClientTeam(i) <= TEAM_SPECTATOR) {
            continue;
        }
        players[index++] = i;
    }
    if (index < g_hVotePlayerLimit.IntValue) {
        CPrintToChat(client, "[{G}%s{W}] {G}当前玩家数量小于允许发起投票的最小玩家数量 {O}%d", MODULE_VOTE_PREFIX, g_hVotePlayerLimit.IntValue);
        log.info("[%s]: %N 准备发起一个投票, 当前玩家数量小于允许投票的最小玩家数量 %d, 无法发起投票", MODULE_VOTE_PREFIX, client, g_hVotePlayerLimit.IntValue);
        return false;
    }

    char title[PLATFORM_MAX_PATH];
    FormatEx(title, sizeof(title), "是否加载 %s 配置模式", name);
    g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
    SetBuiltinVoteArgument(g_hVote, title);
    DisplayBuiltinVote(g_hVote, players, index, MENU_DISPLAY_TIME);
    // CPrintToChatAll("[{G}%s{W}] {G}玩家 {O}%N {G}发起了一个将模式更改为 {O}%s {G}的投票", MODULE_VOTE_PREFIX, client, name);
    CPrintToChatAll("[{G}%s{W}] {B}%N {G}杂鱼发起一个将模式更改为 {O}%s {G}的投票❤", MODULE_VOTE_PREFIX, client, name);
    return true;
}

public int VoteActionHandler(Handle vote, BuiltinVoteAction action, int item, int client) {
    switch (action) {
        case BuiltinVoteAction_End: {
            delete g_hVote;
            g_hVote = null;
        } case BuiltinVoteAction_Cancel: {
            DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(item));
        } case BuiltinVoteAction_VoteEnd: {
            if (item == BUILTINVOTES_VOTE_YES) {
                char buffer[PLATFORM_MAX_PATH];
                FormatEx(buffer, sizeof(buffer), "正在加载 %s ❤❤❤", g_sCfg);
                DisplayBuiltinVotePass(vote, buffer);
                ServerCommand("sm_forcematch %s", g_sCfg);
            } else if (item == BUILTINVOTES_VOTE_NO) {
                DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
            }
        }
    }
    return 0;
}