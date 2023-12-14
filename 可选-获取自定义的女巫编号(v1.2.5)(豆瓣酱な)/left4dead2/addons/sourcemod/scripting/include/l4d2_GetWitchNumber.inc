#if defined _EvilWitchNumber
 #endinput
#endif
#define _EvilWitchNumber

/**
 * 获取自定义的女巫编号.
 *
 * @param iWitchid			传入女巫实体ID.
 *
 * @return				    -1=数组里没有该女巫的索引.
 */
native int GetWitchNumber(int iWitchid);

/**
 * 获取女巫死亡时的类型.      建议在 HookEvent("witch_killed", EventHookMode_Post) 事件里使用.
 *
 * @param iWitchid			传入女巫实体ID.
 * @param sDeathType		获取女巫的死亡类型.
 * @param maxlength			设置字符串最大大小.
 *
 * @return					0=击杀,1=爆头,2=秒杀.
 */
native int GetWitchkilled(int iWitchid, char[] sDeathType = "", int maxlength = 128);