#if defined _shop_included
 #endinput
#endif
#define _shop_included

public SharedPlugin __pl_shop = 
{
	name = "shop",
	file = "shop.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_shop_SetNTVOptional()
{
	MarkNativeAsOptional("Shop_Get_TotalPoint");
	MarkNativeAsOptional("Shop_Get_KillCI");
	MarkNativeAsOptional("Shop_Get_KillSI");
	MarkNativeAsOptional("Shop_Get_KillTank");
	MarkNativeAsOptional("Shop_Get_KillWitch");
	MarkNativeAsOptional("Shop_Get_HeadShotCount");
	MarkNativeAsOptional("Shop_Get_FFCount");
	MarkNativeAsOptional("Shop_Get_GotFFCount");
	MarkNativeAsOptional("Shop_Get_GetPlayerTime");
}
#endif

/**
* @根据id返回累计得分
*
* @client	需要获取数据的玩家id
*
* @return	总计分数
*
*/
native int Shop_Get_TotalPoint(int client);

/**
* @根据id返回击杀僵尸数量
*
* @client	需要获取数据的玩家id
*
* @return	击杀僵尸数量
*
*/
native int Shop_Get_KillCI(int client);

/**
* @根据id返回击杀特感数量
*
* @client	需要获取数据的玩家id
*
* @return	击杀特感数量
*
*/
native int Shop_Get_KillSI(int client);

/**
* @根据id返回击杀坦克数量
*
* @client	需要获取数据的玩家id
*
* @return	击杀坦克数量
*
*/
native int Shop_Get_KillTank(int client);

/**
* @根据id返回击杀女巫数量
*
* @client	需要获取数据的玩家id
*
* @return	击杀女巫数量
*
*/
native int Shop_Get_KillWitch(int client);

/**
* @根据id返回爆头率
*
* @client	需要获取数据的玩家id
*
* @return	float爆头率，不带%
*
*/
native any Shop_Get_HeadShotCount(int client);

/**
* @根据id返回黑枪数量
*
* @client	需要获取数据的玩家id
*
* @return	累计造成友伤
*
*/
native int Shop_Get_FFCount(int client);

/**
* @根据id返回被黑枪数量
*
* @client	需要获取数据的玩家id
*
* @return	累计被黑
*
*/
native int Shop_Get_GotFFCount(int client);

/**
* @根据id返回爆头率
*
* @client	需要获取数据的玩家id
*
* @return	float服务器游玩时间
*
*/
native any Shop_Get_GetPlayerTime(int client);