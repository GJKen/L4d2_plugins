# server_namer

- 本插件提供基本服名显示，支持显示基本服名、特感数量、刷新时间、当前路程、是否缺人、当前模式名称等功能

## 使用步骤：

1. 在 `sourcemod/configs/` 目录下建立 hostname 文件夹
2. 进入 `sourcemod/configs/hostname` 文件夹，新建 hostname.txt 文件
3. 编辑 hostname.txt 配置服名，示例如下（27015、27020 为服务器端口，用于未在插件中配置服名时使用服务器当前端口配置相应服名，若基本服名与端口服名同时未配置，最终服名将会显示为 Left 4 Dead 2）

```Java
ServerName
{
	"27015"
	{
		"baseName"	"测试名称1"
	}
    "27020"
    {
        "baseName" "测试名称2"
    }
}
```

4. 将 server_namer.smx 放至 plugins 文件夹下，重启服务器即可使用

## Notes：

1. 当开启在服名中显示是否缺人的功能时，服务器中没有玩家，则会显示无人，当服务器中有玩家但仍有生还者 bot 存在时，则会显示缺人，当没有生还者 bot 存在时，将不会显示任何信息
2. 当未在插件中配置基本服名而同时未在 hostname.txt 文件中配置服名，则使用默认基本服名 `Left 4 Dead 2`
3. hostname.txt 不存在或 hostname 文件夹未创建插件将不会正确加载并会提示无法找到 hostname.txt 文件

# Cvars

```Java
// 是否在服名中显示特感信息
sn_display_infected_info 1
// 是否在服名中显示当前路程信息
sn_display_current_info 1
// 是否在当前服名中显示模式信息
sn_display_mode_info 1
// 是否在当前服名中显示是否缺人
sn_display_need_people 1
// 服名默认刷新时间（秒）
sn_refresh_time 2
// 基本服名，未配置则使用 hostname.txt 中的配置
sn_base_server_name ""
// 服务器基本模式名称
sn_base_mode_name "普通药役"
```

# 更新日志

- 2022-12-18：上传插件与 readme 文件
- 2023-7-31：增加无插件刷特时特感数量与时间使用导演系统 MaxSpecials 与 SpecialRespawnInterval 值