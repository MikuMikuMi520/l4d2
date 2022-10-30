#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define PLUGIN_NAME				"bots(coop)"
#define PLUGIN_AUTHOR			"DDRKhat, Marcus101RR, Merudo, Lux, Shadowysn, sorallll"
#define PLUGIN_DESCRIPTION		"coop"
#define PLUGIN_VERSION			"1.11.3"
#define PLUGIN_URL				"https://forums.alliedmods.net/showthread.php?p=2405322#post2405322"

#define GAMEDATA 		"bots"
#define CVAR_FLAGS 		FCVAR_NOTIFY
#define MAX_SLOTS		5
#define TEAM_NOTEAM		0
#define TEAM_SPECTATOR	1
#define TEAM_SURVIVOR	2
#define TEAM_INFECTED   3
#define JOIN_MANUAL		(1 << 0)
#define JOIN_AUTOMATIC	(1 << 1)
#define SOUND_SPECMENU	"ui/helpful_event_1.wav"

Handle
	g_hBotsTimer,
	g_hSDK_NextBotCreatePlayerBot_SurvivorBot,
	g_hSDK_CTerrorPlayer_RoundRespawn,
	g_hSDK_CCSPlayer_State_Transition,
	g_hSDK_SurvivorBot_SetHumanSpectator,
	g_hSDK_CTerrorPlayer_TakeOverBot,
	g_hSDK_CDirector_IsInTransition;

StringMap
	g_smSteamIDs;

ArrayList
	g_aMeleeScripts;

Address
	g_pDirector,
	g_pStatsCondition,
	g_pSavedSurvivorBotsCount;

ConVar
	g_cBotsLimit,
	g_cJoinFlags,
	g_cRespawn,
	g_cSpecLimit,
	g_cSpecNotify,
	g_cGiveType,
	g_cGiveTime,
	g_cSurvivorLimit;

int
	g_iSurvivorBot,
	g_iBotsLimit,
	g_iJoinFlags,
	g_iSpecLimit,
	g_iSpecNotify,
	g_iOff_m_hWeaponHandle,
	g_iOff_m_iRestoreAmmo,
	g_iOff_m_restoreWeaponID,
	g_iOff_m_hHiddenWeapon,
	g_iOff_m_isOutOfCheckpoint,
	g_iOff_RestartScenarioTimer;

bool
	g_bLateLoad,
	g_bRespawn,
	g_bGiveType,
	g_bGiveTime,
	g_bInSpawnTime,
	g_bRoundStart,
	g_bShouldFixAFK,
	g_bShouldIgnore,
	g_bBlockUserMsg;

enum struct Weapon {
	ConVar cFlags;

	int count;
	int allowed[20];
}

Weapon
	g_eWeapon[MAX_SLOTS];

enum struct Player {
	int bot;
	int player;

	bool notify;

	char model[PLATFORM_MAX_PATH];
	char AuthId[MAX_AUTHID_LENGTH];
}

Player
	g_ePlayer[MAXPLAYERS + 1];

static const char
	g_sSurvivorNames[][] = {
		"Nick",
		"Rochelle",
		"Coach",
		"Ellis",
		"Bill",
		"Zoey",
		"Francis",
		"Louis"
	},
	g_sSurvivorModels[][] = {
		"models/survivors/survivor_gambler.mdl",
		"models/survivors/survivor_producer.mdl",
		"models/survivors/survivor_coach.mdl",
		"models/survivors/survivor_mechanic.mdl",
		"models/survivors/survivor_namvet.mdl",
		"models/survivors/survivor_teenangst.mdl",
		"models/survivors/survivor_biker.mdl",
		"models/survivors/survivor_manager.mdl"
	},
	g_sWeaponName[MAX_SLOTS][][] = {
		{//slot 0(主武器)
			"weapon_smg",						//1 UZI微冲
			"weapon_smg_mp5",					//2 MP5
			"weapon_smg_silenced",				//4 MAC微冲
			"weapon_pumpshotgun",				//8 木喷
			"weapon_shotgun_chrome",			//16 铁喷
			"weapon_rifle",						//32 M16步枪
			"weapon_rifle_desert",				//64 三连步枪
			"weapon_rifle_ak47",				//128 AK47
			"weapon_rifle_sg552",				//256 SG552
			"weapon_autoshotgun",				//512 一代连喷
			"weapon_shotgun_spas",				//1024 二代连喷
			"weapon_hunting_rifle",				//2048 木狙
			"weapon_sniper_military",			//4096 军狙
			"weapon_sniper_scout",				//8192 鸟狙
			"weapon_sniper_awp",				//16384 AWP
			"weapon_rifle_m60",					//32768 M60
			"weapon_grenade_launcher"			//65536 榴弹发射器
		},
		{//slot 1(副武器)
			"weapon_pistol",					//1 小手枪
			"weapon_pistol_magnum",				//2 马格南
			"weapon_chainsaw",					//4 电锯
			"fireaxe",							//8 斧头
			"frying_pan",						//16 平底锅
			"machete",							//32 砍刀
			"baseball_bat",						//64 棒球棒
			"crowbar",							//128 撬棍
			"cricket_bat",						//256 球拍
			"tonfa",							//512 警棍
			"katana",							//1024 武士刀
			"electric_guitar",					//2048 电吉他
			"knife",							//4096 小刀
			"golfclub",							//8192 高尔夫球棍
			"shovel",							//16384 铁铲
			"pitchfork",						//32768 草叉
			"riotshield",						//65536 盾牌
		},
		{//slot 2(投掷物)
			"weapon_molotov",					//1 燃烧瓶
			"weapon_pipe_bomb",					//2 管制炸弹
			"weapon_vomitjar",					//4 胆汁瓶
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			""
		},
		{//slot 3
			"weapon_first_aid_kit",				//1 医疗包
			"weapon_defibrillator",				//2 电击器
			"weapon_upgradepack_incendiary",	//4 燃烧弹药包
			"weapon_upgradepack_explosive",		//8 高爆弹药包
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			""
		},
		{//slot 4
			"weapon_pain_pills",				//1 止痛药
			"weapon_adrenaline",				//2 肾上腺素
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			""
		}
	},
	g_sWeaponModels[][] = {
		"models/w_models/weapons/w_smg_uzi.mdl",
		"models/w_models/weapons/w_smg_mp5.mdl",
		"models/w_models/weapons/w_smg_a.mdl",
		"models/w_models/weapons/w_pumpshotgun_A.mdl",
		"models/w_models/weapons/w_shotgun.mdl",
		"models/w_models/weapons/w_rifle_m16a2.mdl",
		"models/w_models/weapons/w_desert_rifle.mdl",
		"models/w_models/weapons/w_rifle_ak47.mdl",
		"models/w_models/weapons/w_rifle_sg552.mdl",
		"models/w_models/weapons/w_autoshot_m4super.mdl",
		"models/w_models/weapons/w_shotgun_spas.mdl",
		"models/w_models/weapons/w_sniper_mini14.mdl",
		"models/w_models/weapons/w_sniper_military.mdl",
		"models/w_models/weapons/w_sniper_scout.mdl",
		"models/w_models/weapons/w_sniper_awp.mdl",
		"models/w_models/weapons/w_m60.mdl",
		"models/w_models/weapons/w_grenade_launcher.mdl",
	
		"models/w_models/weapons/w_pistol_a.mdl",
		"models/w_models/weapons/w_desert_eagle.mdl",
		"models/weapons/melee/w_chainsaw.mdl",
		"models/weapons/melee/v_fireaxe.mdl",
		"models/weapons/melee/w_fireaxe.mdl",
		"models/weapons/melee/v_frying_pan.mdl",
		"models/weapons/melee/w_frying_pan.mdl",
		"models/weapons/melee/v_machete.mdl",
		"models/weapons/melee/w_machete.mdl",
		"models/weapons/melee/v_bat.mdl",
		"models/weapons/melee/w_bat.mdl",
		"models/weapons/melee/v_crowbar.mdl",
		"models/weapons/melee/w_crowbar.mdl",
		"models/weapons/melee/v_cricket_bat.mdl",
		"models/weapons/melee/w_cricket_bat.mdl",
		"models/weapons/melee/v_tonfa.mdl",
		"models/weapons/melee/w_tonfa.mdl",
		"models/weapons/melee/v_katana.mdl",
		"models/weapons/melee/w_katana.mdl",
		"models/weapons/melee/v_electric_guitar.mdl",
		"models/weapons/melee/w_electric_guitar.mdl",
		"models/v_models/v_knife_t.mdl",
		"models/w_models/weapons/w_knife_t.mdl",
		"models/weapons/melee/v_golfclub.mdl",
		"models/weapons/melee/w_golfclub.mdl",
		"models/weapons/melee/v_shovel.mdl",
		"models/weapons/melee/w_shovel.mdl",
		"models/weapons/melee/v_pitchfork.mdl",
		"models/weapons/melee/w_pitchfork.mdl",
		"models/weapons/melee/v_riotshield.mdl",
		"models/weapons/melee/w_riotshield.mdl",

		"models/w_models/weapons/w_eq_molotov.mdl",
		"models/w_models/weapons/w_eq_pipebomb.mdl",
		"models/w_models/weapons/w_eq_bile_flask.mdl",

		"models/w_models/weapons/w_eq_medkit.mdl",
		"models/w_models/weapons/w_eq_defibrillator.mdl",
		"models/w_models/weapons/w_eq_incendiary_ammopack.mdl",
		"models/w_models/weapons/w_eq_explosive_ammopack.mdl",

		"models/w_models/weapons/w_eq_adrenaline.mdl",
		"models/w_models/weapons/w_eq_painpills.mdl"
	};

// 如果签名失效，请到此处更新 (https://github.com/Psykotikism/L4D1-2_Signatures)
public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	InitData();
	g_smSteamIDs = new StringMap();
	g_aMeleeScripts = new ArrayList(ByteCountToCells(64));

	AddCommandListener(Listener_spec_next, "spec_next");
	HookUserMessage(GetUserMessageId("SayText2"), umSayText2, true);
	CreateConVar("bots_version", PLUGIN_VERSION, "bots(coop) plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_cBotsLimit =				CreateConVar("bots_limit",				"4",		"开局Bot的数量", CVAR_FLAGS, true, 1.0, true, float(MaxClients));
	g_cJoinFlags =				CreateConVar("bots_join_flags",			"3",		"额外玩家加入生还者的方法. \n0=插件不进行处理, 1=输入!join手动加入, 2=进服后插件自动加入, 3=手动+自动", CVAR_FLAGS);
	g_cRespawn =				CreateConVar("bots_join_respawn",		"1",		"玩家第一次进服时如果没有存活的Bot可以接管是否复活. \n0=否, 1=是.", CVAR_FLAGS);
	g_cSpecLimit =				CreateConVar("bots_spec_limit",			"1",		"当完全旁观玩家达到多少个时禁止使用sm_spec命令.", CVAR_FLAGS);
	g_cSpecNotify =				CreateConVar("bots_spec_notify",		"3",		"完全旁观玩家点击鼠标左键时, 提示加入生还者的方式 \n0=不提示, 1=聊天栏, 2=屏幕中央, 3=弹出菜单.", CVAR_FLAGS);
	g_eWeapon[0].cFlags =		CreateConVar("bots_give_slot0",			"131071",	"主武器给什么. \n0=不给, 131071=所有, 7=微冲, 1560=霰弹, 30720=狙击, 31=Tier1, 32736=Tier2, 98304=Tier0.", CVAR_FLAGS);
	g_eWeapon[1].cFlags =		CreateConVar("bots_give_slot1",			"1064",		"副武器给什么. \n0=不给, 131071=所有.(如果选中了近战且该近战在当前地图上未解锁,则会随机给一把).", CVAR_FLAGS);
	g_eWeapon[2].cFlags = 		CreateConVar("bots_give_slot2",			"0",		"投掷物给什么. \n0=不给, 7=所有.", CVAR_FLAGS);
	g_eWeapon[3].cFlags =		CreateConVar("bots_give_slot3",			"1",		"医疗品给什么. \n0=不给, 15=所有.", CVAR_FLAGS);
	g_eWeapon[4].cFlags =		CreateConVar("bots_give_slot4",			"3",		"药品给什么. \n0=不给, 3=所有.", CVAR_FLAGS);
	g_cGiveType =				CreateConVar("bots_give_type",			"2",		"根据什么来给玩家装备. \n0=不给, 1=每个槽位的设置, 2=当前存活生还者的平均装备质量(仅主副武器).", CVAR_FLAGS);
	g_cGiveTime =				CreateConVar("bots_give_time",			"0",		"什么时候给玩家装备. \n0=每次出生时, 1=只在本插件创建Bot和复活玩家时.", CVAR_FLAGS);

	g_cSurvivorLimit = FindConVar("survivor_limit");
	g_cSurvivorLimit.Flags &= ~FCVAR_NOTIFY; // 移除ConVar变动提示
	g_cSurvivorLimit.SetBounds(ConVarBound_Upper, true, float(MaxClients));

	g_cBotsLimit.AddChangeHook(CvarChanged_Limit);
	g_cSurvivorLimit.AddChangeHook(CvarChanged_Limit);

	g_cJoinFlags.AddChangeHook(CvarChanged_General);
	g_cRespawn.AddChangeHook(CvarChanged_General);
	g_cSpecLimit.AddChangeHook(CvarChanged_General);
	g_cSpecNotify.AddChangeHook(CvarChanged_General);

	g_eWeapon[0].cFlags.AddChangeHook(CvarChanged_Weapon);
	g_eWeapon[1].cFlags.AddChangeHook(CvarChanged_Weapon);
	g_eWeapon[2].cFlags.AddChangeHook(CvarChanged_Weapon);
	g_eWeapon[3].cFlags.AddChangeHook(CvarChanged_Weapon);
	g_eWeapon[4].cFlags.AddChangeHook(CvarChanged_Weapon);

	g_cGiveType.AddChangeHook(CvarChanged_Weapon);
	g_cGiveTime.AddChangeHook(CvarChanged_Weapon);
	
	AutoExecConfig(true, "bots");

	RegConsoleCmd("sm_teams",	cmdTeamPanel,	"团队菜单");
	RegConsoleCmd("sm_spec",	cmdJoinTeam1,	"加入旁观者");
	RegConsoleCmd("sm_join",	cmdJoinTeam2,	"加入生还者");
	RegConsoleCmd("sm_tkbot",	cmdTakeOverBot,	"接管指定BOT");

	RegAdminCmd("sm_afk",		cmdGoIdle,	ADMFLAG_CHAT,	"闲置");
	RegAdminCmd("sm_bot",		cmdBotSet,	ADMFLAG_ROOT,	"设置开局Bot的数量");

	HookEvent("round_end",				Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",			Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_spawn",			Event_PlayerSpawn);
	HookEvent("player_death",			Event_PlayerDeath,	EventHookMode_Pre);
	HookEvent("player_team",			Event_PlayerTeam);
	HookEvent("player_bot_replace",		Event_PlayerBotReplace);
	HookEvent("bot_player_replace",		Event_BotPlayerReplace);
	HookEvent("finale_vehicle_leaving",	Event_FinaleVehicleLeaving);

	if (g_bLateLoad)
		g_bRoundStart = !OnEndScenario();
}

public void OnPluginEnd() {
	StatsConditionPatch(false);
}

Action cmdTeamPanel(int client, int args) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	DrawTeamPanel(client, false);
	return Plugin_Handled;
}

Action cmdJoinTeam1(int client, int args) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!g_bRoundStart) {
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	bool idle = !!GetBotOfIdlePlayer(client);
	if (!idle && GetClientTeam(client) == TEAM_SPECTATOR) {
		PrintToChat(client, "你当前已在旁观者队伍.");
		return Plugin_Handled;
	}
	
	if (GetSpectatorCount() >= g_iSpecLimit) {
		PrintToChat(client, "\x05当前旁观者数量已达到限制\x01-> \x04%d\x01.", g_iSpecLimit);
		return Plugin_Handled;
	}

	if (idle)
		TakeOverBot(client);

	ChangeClientTeam(client, TEAM_SPECTATOR);
	return Plugin_Handled;
}

int GetSpectatorCount() {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_SPECTATOR && !GetBotOfIdlePlayer(i))
			count++;
	}
	return count;
}

Action cmdJoinTeam2(int client, int args) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!(g_iJoinFlags & JOIN_MANUAL)) {
		PrintToChat(client, "手动加入已禁用.");
		return Plugin_Handled;
	}

	if (!g_bRoundStart) {
		PrintToChat(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	switch (GetClientTeam(client)) {
		case TEAM_SPECTATOR: {
			if (GetBotOfIdlePlayer(client))
				return Plugin_Handled;
		}

		case TEAM_SURVIVOR: {
			PrintToChat(client, "你当前已在生还者队伍.");
			return Plugin_Handled;
		}

		default:
			ChangeClientTeam(client, TEAM_SPECTATOR);
	}

	return JoinTeam2(client);
}

Action JoinTeam2(int client) {
	int bot = GetClientOfUserId(g_ePlayer[client].bot);
	bool canRespawn = g_bRespawn && IsFirstTime(client);
	if (!bot || !IsValidSurBot(bot))
		bot = FindUselessSurBot(canRespawn);

	bool added;
	if (!bot) {
		if ((bot = SpawnSurBot()) == -1) {
			ChangeClientTeam(client, TEAM_SURVIVOR);
			if (!IsPlayerAlive(client)) {
				if (canRespawn)
					RoundRespawn(client);
				else
					PrintToChat(client, "\x05重复加入默认为\x01-> \x04死亡状态\x01.");
			}
	
			if (IsPlayerAlive(client)) {
				TeleportToSurvivor(client);
				SetInvincibilityTime(client, 1.5);
			}

			return Plugin_Handled;
		}
		added = true;
	}

	bool take;
	if (canRespawn) {
		if (!IsPlayerAlive(bot)) {
			RoundRespawn(bot);
			take = CanTakeOver(bot, TeleportToSurvivor(bot));
		}
		else
			take = CanTakeOver(bot, added ? TeleportToSurvivor(bot) : bot);

		SetHumanSpec(bot, client);
		if (!take)
			SetInvincibilityTime(bot, 1.5);
		else {
			TakeOverBot(client);
			SetInvincibilityTime(client, 1.5);
		}
	}
	else {
		if (IsPlayerAlive(bot)) {
			if (added) {
				TeleportToSurvivor(bot); //传送旁观位置
				State_Transition(bot, 6);
				SetHumanSpec(bot, client);
				TakeOverBot(client);
				PrintToChat(client, "\x05重复加入默认为\x01-> \x04死亡状态\x01.");
			}
			else {
				SetHumanSpec(bot, client);
				if (CanTakeOver(bot, bot))
					TakeOverBot(client);
			}
		}
		else {
			SetHumanSpec(bot, client);
			TakeOverBot(client);
			PrintToChat(client, "\x05重复加入默认为\x01-> \x04死亡状态\x01.");
		}
	}

	return Plugin_Handled;
}

Action cmdTakeOverBot(int client, int args) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!g_bRoundStart) {
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if (!IsAllowedTeam(client)) {
		PrintToChat(client, "不符合接管条件.");
		return Plugin_Handled;
	}

	if (!FindUselessSurBot(true)) {
		PrintToChat(client, "\x01没有 \x05空闲的电脑BOT \x01可以接管\x01.");
		return Plugin_Handled;
	}

	TakeOverBotMenu(client);
	return Plugin_Handled;
}

int IsAllowedTeam(int client) {
	int team = GetClientTeam(client);
	switch (team) {
		case TEAM_SPECTATOR: {
			if (GetBotOfIdlePlayer(client))
				team = 0;
		}

		case TEAM_SURVIVOR: {
			if (IsPlayerAlive(client))
				team = 0;
		}
	}
	return team;
}

void TakeOverBotMenu(int client) {
	char info[12];
	char disp[64];
	Menu menu = new Menu(TakeOverBot_MenuHandler);
	menu.SetTitle("- 请选择接管目标 - [!tkbot]");
	menu.AddItem("o", "当前旁观目标");

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidSurBot(i))
			continue;

		FormatEx(info, sizeof info, "%d", GetClientUserId(i));
		FormatEx(disp, sizeof disp, "%s - %s", IsPlayerAlive(i) ? "存活" : "死亡", GetModelName(i));
		menu.AddItem(info, disp);
	}

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

// L4D2_Adrenaline_Recovery (https://github.com/LuxLuma/L4D2_Adrenaline_Recovery)
char[] GetModelName(int client) {
	int idx;
	char model[31];
	GetClientModel(client, model, sizeof model);
	switch (model[29]) {
		case 'b'://nick
			idx = 0;
		case 'd'://rochelle
			idx = 1;
		case 'c'://coach
			idx = 2;
		case 'h'://ellis
			idx = 3;
		case 'v'://bill
			idx = 4;
		case 'n'://zoey
			idx = 5;
		case 'e'://francis
			idx = 6;
		case 'a'://louis
			idx = 7;
		default:
			idx = 8;
	}

	strcopy(model, sizeof model, idx == 8 ? "未知" : g_sSurvivorNames[idx]);
	return model;
}

int TakeOverBot_MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			int bot;
			char item[12];
			menu.GetItem(param2, item, sizeof item);
			if (item[0] == 'o') {
				bot = GetEntPropEnt(param1, Prop_Send, "m_hObserverTarget");
				if (bot > 0 && IsValidSurBot(bot)) {
					SetHumanSpec(bot, param1);
					TakeOverBot(param1);
				}
				else
					PrintToChat(param1, "当前旁观目标非可接管BOT.");
			}
			else {
				bot = GetClientOfUserId(StringToInt(item));
				if (!bot || !IsValidSurBot(bot))
					PrintToChat(param1, "选定的目标BOT已失效.");
				else {
					int team = IsAllowedTeam(param1);
					if (!team)
						PrintToChat(param1, "不符合接管条件.");
					else {
						if (team != 1)
							ChangeClientTeam(param1, TEAM_SPECTATOR);

						SetHumanSpec(bot, param1);
						TakeOverBot(param1);
					}
				}
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

Action cmdGoIdle(int client, int args) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!g_bRoundStart) {
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
		return Plugin_Handled;

	GoAFKTimer(client, 1.5);
	return Plugin_Handled;
}

void GoAFKTimer(int client, float flDuration) {
	static int m_GoAFKTimer = -1;
	if (m_GoAFKTimer == -1)
		m_GoAFKTimer = FindSendPropInfo("CTerrorPlayer", "m_lookatPlayer") - 12;

	SetEntDataFloat(client, m_GoAFKTimer + 4, flDuration);
	SetEntDataFloat(client, m_GoAFKTimer + 8, GetGameTime() + flDuration);
}

Action cmdBotSet(int client, int args) {
	if (!g_bRoundStart) {
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if (args != 1) {
		ReplyToCommand(client, "\x01!botset/sm_botset <\x05数量\x01>.");
		return Plugin_Handled;
	}

	int arg = GetCmdArgInt(1);
	if (arg < 1 || arg > MaxClients - 1) {
		ReplyToCommand(client, "\x01参数范围 \x051\x01~\x05%d\x01.", MaxClients - 1);
		return Plugin_Handled;
	}

	delete g_hBotsTimer;
	g_cBotsLimit.IntValue = arg;
	g_hBotsTimer = CreateTimer(1.0, tmrBotsUpdate);
	ReplyToCommand(client, "\x05开局BOT数量已设置为\x01-> \x04%d\x01.", arg);
	return Plugin_Handled;
}

Action Listener_spec_next(int client, char[] command, int argc) {
	if (!g_ePlayer[client].notify || !(g_iJoinFlags & JOIN_MANUAL))
		return Plugin_Continue;

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;

	if (GetClientTeam(client) != TEAM_SPECTATOR || GetBotOfIdlePlayer(client))
		return Plugin_Continue;

	if (PrepRestoreBots())
		return Plugin_Continue;

	g_ePlayer[client].notify = false;

	switch (g_iSpecNotify) {
		case 1:
			PrintToChat(client, "\x01聊天栏输入 \x05!join \x01加入游戏.");

		case 2:
			PrintHintText(client, "聊天栏输入 !join 加入游戏");

		case 3:
			JoinTeam2Menu(client);
	}

	return Plugin_Continue;
}

void JoinTeam2Menu(int client) {
	EmitSoundToClient(client, SOUND_SPECMENU, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);

	Menu menu = new Menu(JoinTeam2_MenuHandler);
	menu.SetTitle("加入生还者?");
	menu.AddItem("y", "是");
	menu.AddItem("n", "否");

	if (FindUselessSurBot(true))
		menu.AddItem("t", "接管指定BOT");

	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

int JoinTeam2_MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			switch (param2) {
				case 0:
					cmdJoinTeam2(param1, 0);

				case 2: {
					if (FindUselessSurBot(true))
						TakeOverBotMenu(param1);
					else
						PrintToChat(param1, "\x01没有 \x05空闲的电脑BOT \x01可以接管\x01.");
				}
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

Action umSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	if (!g_bBlockUserMsg)
		return Plugin_Continue;

	msg.ReadByte();
	msg.ReadByte();

	char buffer[254];
	msg.ReadString(buffer, sizeof buffer, true);
	if (strcmp(buffer, "#Cstrike_Name_Change") == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void OnConfigsExecuted() {
	static bool once;
	if (!once) {
		once = true;
		GeCvars_Limit();
	}

	GeCvars_Weapon();
	GeCvars_General();
}

void CvarChanged_Limit(ConVar convar, const char[] oldValue, const char[] newValue) {
	GeCvars_Limit();
}

void GeCvars_Limit() {
	g_iBotsLimit = g_cSurvivorLimit.IntValue = g_cBotsLimit.IntValue;
}

void CvarChanged_General(ConVar convar, const char[] oldValue, const char[] newValue) {
	GeCvars_General();
}

void GeCvars_General() {
	g_iJoinFlags =		g_cJoinFlags.IntValue;
	g_bRespawn =		g_cRespawn.BoolValue;
	g_iSpecLimit =		g_cSpecLimit.IntValue;
	g_iSpecNotify =		g_cSpecNotify.IntValue;
}

void CvarChanged_Weapon(ConVar convar, const char[] oldValue, const char[] newValue) {
	GeCvars_Weapon();
}

void GeCvars_Weapon() {
	int count;
	for (int i; i < MAX_SLOTS; i++) {
		g_eWeapon[i].count = 0;
		if (!g_eWeapon[i].cFlags.BoolValue || !IsNullSlot(i))
			count++;
	}

	g_bGiveType = count < MAX_SLOTS ? g_cGiveType.BoolValue : false;
	g_bGiveTime = g_cGiveTime.BoolValue;
}

bool IsNullSlot(int slot) {
	int flags = g_eWeapon[slot].cFlags.IntValue;
	for (int i; i < sizeof g_sWeaponName[]; i++) {
		if (!g_sWeaponName[slot][i][0])
			break;

		if ((1 << i) & flags)
			g_eWeapon[slot].allowed[g_eWeapon[slot].count++] = i;
	}
	return g_eWeapon[slot].count > 0;
}

public void OnClientDisconnect(int client) {
	if (IsFakeClient(client))
		return;

	g_ePlayer[client].AuthId[0] = '\0';

	if (g_bRoundStart) {
		delete g_hBotsTimer;
		g_hBotsTimer = CreateTimer(1.0, tmrBotsUpdate);
	}
}

Action tmrBotsUpdate(Handle timer) {
	g_hBotsTimer = null;

	if (!PrepRestoreBots())
		SpawnCheck();
	else
		g_hBotsTimer = CreateTimer(1.0, tmrBotsUpdate);

	return Plugin_Continue;
}

void SpawnCheck() {
	if (!g_bRoundStart)
		return;

	int iSurvivor		= GetTeamPlayers(TEAM_SURVIVOR, true);
	int iHumanSurvivor	= GetTeamPlayers(TEAM_SURVIVOR, false);
	int iSurvivorLimit	= g_iBotsLimit;
	int iSurvivorMax	= iHumanSurvivor > iSurvivorLimit ? iHumanSurvivor : iSurvivorLimit;

	if (iSurvivor > iSurvivorMax)
		PrintToConsoleAll("Kicking %d bot(s)", iSurvivor - iSurvivorMax);

	if (iSurvivor < iSurvivorLimit)
		PrintToConsoleAll("Spawning %d bot(s)", iSurvivorLimit - iSurvivor);

	for (; iSurvivorMax < iSurvivor; iSurvivorMax++)
		KickUnusedSurBot();
	
	for (; iSurvivor < iSurvivorLimit; iSurvivor++)
		SpawnExtraSurBot();
}

void KickUnusedSurBot() {
	int bot = FindUnusedSurBot(); // 优先踢出没有对应真实玩家且后生成的Bot
	if (bot) {
		RemoveAllWeapons(bot);
		KickClient(bot, "Kicking Useless Client.");
	}
}

void SpawnExtraSurBot() {
	int bot = SpawnSurBot();
	if (bot != -1) {
		if (!IsPlayerAlive(bot))
			RoundRespawn(bot);

		TeleportToSurvivor(bot);
		SetInvincibilityTime(bot, 1.5);
	}
}

public void OnMapEnd() {
	ResetPlugin();
}

void ResetPlugin() {
	delete g_hBotsTimer;
	g_smSteamIDs.Clear();
	g_bRoundStart = false;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	ResetPlugin();

	int player;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsFakeClient(i) || GetClientTeam(i) != TEAM_SURVIVOR)
			continue;

		player = GetIdlePlayerOfBot(i);
		if (player && IsClientInGame(player) && !IsFakeClient(player) && GetClientTeam(player) == TEAM_SPECTATOR) {
			SetHumanSpec(i, player);
			TakeOverBot(player);
		}
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	g_bRoundStart = true;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR)
		return;

	delete g_hBotsTimer;
	g_hBotsTimer = CreateTimer(2.0, tmrBotsUpdate);

	if (!IsFakeClient(client) && IsFirstTime(client))
		RecordSteamID(client);

	SetEntProp(client, Prop_Send, "m_isGhost", 0);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != TEAM_SURVIVOR)
		return;

	int player = GetIdlePlayerOfBot(client);
	if (player && IsClientInGame(player) && !IsFakeClient(player) && GetClientTeam(player) == TEAM_SPECTATOR) {
		SetHumanSpec(client, player);
		TakeOverBot(player);
	}
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return;

	switch (event.GetInt("team")) {
		case TEAM_SPECTATOR: {
			g_ePlayer[client].notify = true;

			if (g_iJoinFlags & JOIN_AUTOMATIC && event.GetInt("oldteam") == TEAM_NOTEAM)
				CreateTimer(0.1, tmrJoinTeam2, event.GetInt("userid"), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}

		case TEAM_SURVIVOR:
			SetEntProp(client, Prop_Send, "m_isGhost", 0);
	}
}

Action tmrJoinTeam2(Handle timer, int client) {
	if (!(g_iJoinFlags & JOIN_AUTOMATIC) || !(client = GetClientOfUserId(client)) || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) > TEAM_SPECTATOR || GetBotOfIdlePlayer(client)) 
		return Plugin_Stop;

	if (!g_bRoundStart || PrepRestoreBots() || GetClientTeam(client) <= TEAM_NOTEAM)
		return Plugin_Continue;

	JoinTeam2(client);
	return Plugin_Stop;
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast) {
	int playerId = event.GetInt("player");
	int player = GetClientOfUserId(playerId);
	if (!player || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != TEAM_SURVIVOR)
		return;

	int botId = event.GetInt("bot");
	int bot = GetClientOfUserId(botId);

	g_ePlayer[bot].player = playerId;
	g_ePlayer[player].bot = botId;

	if (!g_ePlayer[player].model[0])
		return;

	SetEntProp(bot, Prop_Send, "m_survivorCharacter", GetEntProp(player, Prop_Send, "m_survivorCharacter"));
	SetEntityModel(bot, g_ePlayer[player].model);
	for (int i; i < sizeof g_sSurvivorModels; i++) {
		if (strcmp(g_ePlayer[player].model, g_sSurvivorModels[i], false) == 0) {
			g_bBlockUserMsg = true;
			SetClientInfo(bot, "name", g_sSurvivorNames[i]);
			g_bBlockUserMsg = false;
			break;
		}
	}
}

void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast) {
	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != TEAM_SURVIVOR)
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	SetEntProp(player, Prop_Send, "m_survivorCharacter", GetEntProp(bot, Prop_Send, "m_survivorCharacter"));

	char model[PLATFORM_MAX_PATH];
	GetClientModel(bot, model, sizeof model);
	SetEntityModel(player, model);
}

void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast) {
	int entity = FindEntityByClassname(MaxClients + 1, "info_survivor_position");
	if (entity == -1)
		return;

	float vPos[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);

	int count;
	static const char sOrder[][] = {"1", "2", "3", "4"};
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
			continue;

		if (++count < 4)
			continue;
			
		entity = CreateEntityByName("info_survivor_position");
		if (entity != -1) {
			DispatchKeyValue(entity, "Order", sOrder[count - RoundToFloor(count / 4.0) * 4]);
			TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(entity);
		}
	}
}

bool IsFirstTime(int client) {
	if (!CacheSteamID(client))
		return false;

	bool allow = true;
	g_smSteamIDs.GetValue(g_ePlayer[client].AuthId, allow);
	return allow;
}

void RecordSteamID(int client) {
	if (CacheSteamID(client))
		g_smSteamIDs.SetValue(g_ePlayer[client].AuthId, false, true);
}

bool CacheSteamID(int client) {
	if (g_ePlayer[client].AuthId[0])
		return true;

	if (GetClientAuthId(client, AuthId_Steam2, g_ePlayer[client].AuthId, sizeof Player::AuthId))
		return true;

	g_ePlayer[client].AuthId[0] = '\0';
	return false;
}

int GetBotOfIdlePlayer(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && GetIdlePlayerOfBot(i) == client)
			return i;
	}
	return 0;
}

int GetIdlePlayerOfBot(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

int GetTeamPlayers(int team, bool bIncludeBots) {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != team)
			continue;

		if (!bIncludeBots && IsFakeClient(i) && !GetIdlePlayerOfBot(i))
			continue;

		count++;
	}
	return count;
}

int FindUnusedSurBot() {
	int client = MaxClients;
	ArrayList al_clients = new ArrayList(2);

	for (; client >= 1; client--) {
		if (!IsValidSurBot(client))
			continue;

		al_clients.Set(al_clients.Push(IsSpecInvalid(GetClientOfUserId(g_ePlayer[client].player)) ? 0 : 1), client, 1);
	}

	if (!al_clients.Length)
		client = 0;
	else {
		al_clients.Sort(Sort_Ascending, Sort_Integer);
		client = al_clients.Get(0, 1);
	}

	delete al_clients;
	return client;
}

int FindUselessSurBot(bool bAlive) {
	int client;
	ArrayList al_clients = new ArrayList(2);

	for (int i = MaxClients; i >= 1; i--) {
		if (!IsValidSurBot(i))
			continue;

		client = GetClientOfUserId(g_ePlayer[i].player);
		al_clients.Set(al_clients.Push(IsPlayerAlive(i) == bAlive ? (IsSpecInvalid(client) ? 0 : 1) : (IsSpecInvalid(client) ? 2 : 3)), i, 1);
	}

	if (!al_clients.Length)
		client = 0;
	else {
		al_clients.Sort(Sort_Descending, Sort_Integer);

		client = al_clients.Length - 1;
		client = al_clients.Get(Math_GetRandomInt(al_clients.FindValue(al_clients.Get(client, 0)), client), 1);
	}

	delete al_clients;
	return client;
}

bool IsValidSurBot(int client) {
	return IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR && !GetIdlePlayerOfBot(client);
}

bool IsSpecInvalid(int client) {
	return !client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == TEAM_SURVIVOR;
}

int TeleportToSurvivor(int client) {
	int target = 1;
	ArrayList al_clients = new ArrayList(2);

	for (; target <= MaxClients; target++) {
		if (target == client || !IsClientInGame(target) || GetClientTeam(target) != TEAM_SURVIVOR || !IsPlayerAlive(target))
			continue;
	
		al_clients.Set(al_clients.Push(!GetEntProp(target, Prop_Send, "m_isIncapacitated") ? 0 : !GetEntProp(target, Prop_Send, "m_isHangingFromLedge") ? 1 : 2), target, 1);
	}

	if (!al_clients.Length)
		target = 0;
	else {
		al_clients.Sort(Sort_Descending, Sort_Integer);

		target = al_clients.Length - 1;
		target = al_clients.Get(Math_GetRandomInt(al_clients.FindValue(al_clients.Get(target, 0)), target), 1);
	}

	delete al_clients;

	if (target) {
		SetEntProp(client, Prop_Send, "m_bDucked", 1);
		SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags")|FL_DUCKING);

		float vPos[3];
		GetClientAbsOrigin(target, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
		return target;
	}

	return client;
}

void SetInvincibilityTime(int client, float flDuration) {
	static int m_invulnerabilityTimer = -1;
	if (m_invulnerabilityTimer == -1)
		m_invulnerabilityTimer = FindSendPropInfo("CTerrorPlayer", "m_noAvoidanceTimer") - 12;

	SetEntDataFloat(client, m_invulnerabilityTimer + 4, flDuration);
	SetEntDataFloat(client, m_invulnerabilityTimer + 8, GetGameTime() + flDuration);
}

// 给玩家近战
// L4D2- Melee In The Saferoom (https://forums.alliedmods.net/showpost.php?p=2611529&postcount=484)
public void OnMapStart() {
	GetMeleeStringTable();
	PrecacheSound(SOUND_SPECMENU);

	int i;
	for (; i < sizeof g_sWeaponModels; i++) {
		if (!IsModelPrecached(g_sWeaponModels[i]))
			PrecacheModel(g_sWeaponModels[i], true);
	}

	char buffer[64];
	for (i = 3; i < sizeof g_sWeaponName[]; i++) {
		FormatEx(buffer, sizeof buffer, "scripts/melee/%s.txt", g_sWeaponName[1][i]);
		if (!IsGenericPrecached(buffer))
			PrecacheGeneric(buffer, true);
	}
}

void GetMeleeStringTable() {
	g_aMeleeScripts.Clear();

	int table = FindStringTable("meleeweapons");
	if (table != INVALID_STRING_TABLE) {
		int num = GetStringTableNumStrings(table);
		char str[64];
		for (int i; i < num; i++) {
			ReadStringTable(table, i, str, sizeof str);
			g_aMeleeScripts.PushString(str);
		}
	}
}

void GiveMelee(int client, const char[] meleeName) {
	char buffer[64];
	if (g_aMeleeScripts.FindString(meleeName) != -1)
		strcopy(buffer, sizeof buffer, meleeName);
	else
		g_aMeleeScripts.GetString(Math_GetRandomInt(0, g_aMeleeScripts.Length - 1), buffer, sizeof buffer);
	
	GivePlayerItem(client, buffer);
}

enum struct Zombie {
	int idx;
	int class;
	int client;
}

Handle g_hPanelTimer[MAXPLAYERS + 1];
void DrawTeamPanel(int client, bool autoRefresh) {
	static const char ZombieName[][] = {
		"Smoker",
		"Boomer",
		"Hunter",
		"Spitter",
		"Jockey",
		"Charger",
		"Witch",
		"Tank",
		"None"
	};

	Panel panel = new Panel();
	panel.SetTitle("团队信息");

	static char info[MAX_NAME_LENGTH];
	static char name[MAX_NAME_LENGTH];

	FormatEx(info, sizeof info, "旁观 [%d]", GetTeamPlayers(TEAM_SPECTATOR, false));
	panel.DrawItem(info);

	int i = 1;
	for (; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SPECTATOR)
			continue;

		SplitName(i, name, sizeof name);
		FormatEx(info, sizeof info, "%s - %s", GetBotOfIdlePlayer(i) ? "闲置" : "观众", name);
		panel.DrawText(info);
	}

	FormatEx(info, sizeof info, "生还 [%d/%d] - %d Bot(s)", GetTeamPlayers(TEAM_SURVIVOR, false), g_iBotsLimit, GetSurBotsCount());
	panel.DrawItem(info);

	static ConVar cv;
	if (!cv)
		cv = FindConVar("survivor_max_incapacitated_count");

	int maxInc = cv.IntValue;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
			continue;

		SplitName(i, name, sizeof name);

		if (!IsPlayerAlive(i))
			FormatEx(info, sizeof info, "死亡 - %s", name);
		else {
			if (GetEntProp(i, Prop_Send, "m_isIncapacitated"))
				FormatEx(info, sizeof info, "倒地 - %dHP - %s", GetClientHealth(i) + GetTempHealth(i), name);
			else if (GetEntProp(i, Prop_Send, "m_currentReviveCount") >= maxInc)
				FormatEx(info, sizeof info, "黑白 - %dHP - %s", GetClientHealth(i) + GetTempHealth(i), name);
			else
				FormatEx(info, sizeof info, "%dHP - %s", GetClientHealth(i) + GetTempHealth(i), name);
	
		}

		panel.DrawText(info);
	}

	FormatEx(info, sizeof info, "感染 [%d]", GetTeamPlayers(TEAM_INFECTED, false));
	panel.DrawItem(info);

	Zombie zombie;
	ArrayList al_clients = new ArrayList(sizeof Zombie);
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_INFECTED)
			continue;

		zombie.class = GetEntProp(i, Prop_Send, "m_zombieClass");
		if (zombie.class != 8 && IsFakeClient(i))
			continue;

		zombie.client = i;
		zombie.idx = zombie.class == 8 ? (!IsFakeClient(i) ? 0 : 1) : 2;
		al_clients.PushArray(zombie);
	}

	int count = al_clients.Length;
	if (count) {
		al_clients.Sort(Sort_Ascending, Sort_Integer);
		for (i = 0; i < count; i++) {
			al_clients.GetArray(i, zombie);
			SplitName(zombie.client, name, sizeof name);

			if (IsPlayerAlive(zombie.client)) {
				if (GetEntProp(zombie.client, Prop_Send, "m_isGhost"))
					FormatEx(info, sizeof info, "(%s)鬼魂 - %s", ZombieName[zombie.class - 1], name);
				else
					FormatEx(info, sizeof info, "(%s)%dHP - %s", ZombieName[zombie.class - 1], GetEntProp(zombie.client, Prop_Data, "m_iHealth"), name);
			}
			else
				FormatEx(info, sizeof info, "(%s)死亡 - %s", ZombieName[zombie.class - 1], name);

			panel.DrawText(info);
		}
	}

	delete al_clients;

	FormatEx(info, sizeof info, "刷新 [%s]", autoRefresh ? "●" : "○");
	panel.DrawItem(info);

	panel.Send(client, Panel_Handler, 15);
	delete panel;

	delete g_hPanelTimer[client];
	if (autoRefresh)
		g_hPanelTimer[client] = CreateTimer(1.0, tmrPanel, client);
}

int Panel_Handler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			if (param2 == 4 && !g_hPanelTimer[param1])
				DrawTeamPanel(param1, true);
			else
				delete g_hPanelTimer[param1];
		}

		case MenuAction_Cancel:
			delete g_hPanelTimer[param1];
	}

	return 0;
}

Action tmrPanel(Handle timer, int client) {
	g_hPanelTimer[client] = null;

	DrawTeamPanel(client, true);
	return Plugin_Continue;
}

void SplitName(int client, char[] name, int length) {
	GetClientName(client, name, length);
	if (strlen(name) > 30) {
		name[27] = name[28] = name[29] = '.';
		name[30] = '\0';
	}
}

int GetSurBotsCount() {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidSurBot(i))
			count++;
	}
	return count;
}

int GetTempHealth(int client) {
	static ConVar cvPainPillsDecay;
	if (!cvPainPillsDecay)
		cvPainPillsDecay = FindConVar("pain_pills_decay_rate");

	int tempHealth = RoundToFloor(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * cvPainPillsDecay.FloatValue);
	return tempHealth < 0 ? 0 : tempHealth;
}

void InitData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pDirector = hGameData.GetAddress("CDirector");
	if (!g_pDirector)
		SetFailState("Failed to find address: \"CDirector\" (%s)", PLUGIN_VERSION);

	g_pSavedSurvivorBotsCount = hGameData.GetAddress("SavedSurvivorBotsCount");
	if (!g_pSavedSurvivorBotsCount)
		SetFailState("Failed to find address: \"SavedSurvivorBotsCount\"");

	g_iOff_m_hWeaponHandle = hGameData.GetOffset("m_hWeaponHandle");
	if (g_iOff_m_hWeaponHandle == -1)
		SetFailState("Failed to find offset: \"m_hWeaponHandle\" (%s)", PLUGIN_VERSION);
	
	g_iOff_m_iRestoreAmmo = hGameData.GetOffset("m_iRestoreAmmo");
	if (g_iOff_m_iRestoreAmmo == -1)
		SetFailState("Failed to find offset: \"m_iRestoreAmmo\" (%s)", PLUGIN_VERSION);

	g_iOff_m_restoreWeaponID = hGameData.GetOffset("m_restoreWeaponID");
	if (g_iOff_m_restoreWeaponID == -1)
		SetFailState("Failed to find offset: \"m_restoreWeaponID\" (%s)", PLUGIN_VERSION);

	g_iOff_m_hHiddenWeapon = hGameData.GetOffset("m_hHiddenWeapon");
	if (g_iOff_m_hHiddenWeapon == -1)
		SetFailState("Failed to find offset: \"m_hHiddenWeapon\" (%s)", PLUGIN_VERSION);

	g_iOff_m_isOutOfCheckpoint = hGameData.GetOffset("m_isOutOfCheckpoint");
	if (g_iOff_m_isOutOfCheckpoint == -1)
		SetFailState("Failed to find offset: \"m_isOutOfCheckpoint\" (%s)", PLUGIN_VERSION);

	g_iOff_RestartScenarioTimer = hGameData.GetOffset("RestartScenarioTimer");
	if (g_iOff_RestartScenarioTimer == -1)
		SetFailState("Failed to find offset: \"RestartScenarioTimer\" (%s)", PLUGIN_VERSION);

	StartPrepSDKCall(SDKCall_Static);
	Address addr = hGameData.GetMemSig("NextBotCreatePlayerBot<SurvivorBot>");
	if (!addr)
		SetFailState("Failed to find address: \"NextBotCreatePlayerBot<SurvivorBot>\" in \"CDirector::AddSurvivorBot\" (%s)", PLUGIN_VERSION);
	if (!hGameData.GetOffset("OS")) {
		Address offset = view_as<Address>(LoadFromAddress(addr + view_as<Address>(1), NumberType_Int32));	// (addr+5) + *(addr+1) = call function addr
		if (!offset)
			SetFailState("Failed to find address: \"NextBotCreatePlayerBot<SurvivorBot>\" (%s)", PLUGIN_VERSION);

		addr += offset + view_as<Address>(5); // sizeof(instruction)
	}
	if (!PrepSDKCall_SetAddress(addr))
		SetFailState("Failed to find address: \"NextBotCreatePlayerBot<SurvivorBot>\" (%s)", PLUGIN_VERSION);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	if (!(g_hSDK_NextBotCreatePlayerBot_SurvivorBot = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"NextBotCreatePlayerBot<SurvivorBot>\" (%s)", PLUGIN_VERSION);

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::RoundRespawn"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::RoundRespawn\" (%s)", PLUGIN_VERSION);
	if (!(g_hSDK_CTerrorPlayer_RoundRespawn = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::RoundRespawn\" (%s)", PLUGIN_VERSION);

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CCSPlayer::State_Transition"))
		SetFailState("Failed to find signature: \"CCSPlayer::State_Transition\" (%s)", PLUGIN_VERSION);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if (!(g_hSDK_CCSPlayer_State_Transition = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CCSPlayer::State_Transition\" (%s)", PLUGIN_VERSION);

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "SurvivorBot::SetHumanSpectator"))
		SetFailState("Failed to find signature: \"SurvivorBot::SetHumanSpectator\" (%s)", PLUGIN_VERSION);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	if (!(g_hSDK_SurvivorBot_SetHumanSpectator = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"SurvivorBot::SetHumanSpectator\" (%s)", PLUGIN_VERSION);
	
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::TakeOverBot"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::TakeOverBot\" (%s)", PLUGIN_VERSION);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_CTerrorPlayer_TakeOverBot = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::TakeOverBot\" (%s)", PLUGIN_VERSION);

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::IsInTransition"))
		SetFailState("Failed to find signature: \"CDirector::IsInTransition\" (%s)", PLUGIN_VERSION);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_CDirector_IsInTransition = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CDirector::IsInTransition\" (%s)", PLUGIN_VERSION);

	InitPatchs(hGameData);
	SetupDetours(hGameData);

	delete hGameData;
}

void InitPatchs(GameData hGameData = null) {
	int iOffset = hGameData.GetOffset("RoundRespawn_Offset");
	if (iOffset == -1)
		SetFailState("Failed to find offset: \"RoundRespawn_Offset\" (%s)", PLUGIN_VERSION);

	int iByteMatch = hGameData.GetOffset("RoundRespawn_Byte");
	if (iByteMatch == -1)
		SetFailState("Failed to find byte: \"RoundRespawn_Byte\" (%s)", PLUGIN_VERSION);

	g_pStatsCondition = hGameData.GetMemSig("CTerrorPlayer::RoundRespawn");
	if (!g_pStatsCondition)
		SetFailState("Failed to find address: \"CTerrorPlayer::RoundRespawn\" (%s)", PLUGIN_VERSION);
	
	g_pStatsCondition += view_as<Address>(iOffset);
	int iByteOrigin = LoadFromAddress(g_pStatsCondition, NumberType_Int8);
	if (iByteOrigin != iByteMatch)
		SetFailState("Failed to load \"CTerrorPlayer::RoundRespawn\", byte mis-match @ %d (0x%02X != 0x%02X) (%s)", iOffset, iByteOrigin, iByteMatch, PLUGIN_VERSION);
}

// [L4D1 & L4D2] SM Respawn Improved (https://forums.alliedmods.net/showthread.php?t=323220)
void StatsConditionPatch(bool patch) {
	static bool patched;
	if (!patched && patch) {
		patched = true;
		StoreToAddress(g_pStatsCondition, 0xEB, NumberType_Int8);
	}
	else if (patched && !patch) {
		patched = false;
		StoreToAddress(g_pStatsCondition, 0x75, NumberType_Int8);
	}
}

// Left 4 Dead 2 - CreateSurvivorBot (https://forums.alliedmods.net/showpost.php?p=2729883&postcount=16)
int SpawnSurBot() {
	g_bInSpawnTime = true;
	int bot = SDKCall(g_hSDK_NextBotCreatePlayerBot_SurvivorBot, NULL_STRING);
	if (bot != -1)
		ChangeClientTeam(bot, TEAM_SURVIVOR);

	g_bInSpawnTime = false;
	return bot;
}

void RoundRespawn(int client) {			
	StatsConditionPatch(true);
	g_bInSpawnTime = true;
	SDKCall(g_hSDK_CTerrorPlayer_RoundRespawn, client);
	g_bInSpawnTime = false;
	StatsConditionPatch(false);
}

/**
// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/clients.inc#:~:info=Spectator%20Movement%20modes-,enum%20Obs_Mode,-%7B
// Spectator Movement modes
enum Obs_Mode
{
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_ROAMING,	// free roaming

	NUM_OBSERVER_MODES
};
**/
void SetHumanSpec(int bot, int client) {
	SDKCall(g_hSDK_SurvivorBot_SetHumanSpectator, bot, client);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
}

void TakeOverBot(int client) {
	SDKCall(g_hSDK_CTerrorPlayer_TakeOverBot, client, true);
}

void State_Transition(int client, int state) {
	SDKCall(g_hSDK_CCSPlayer_State_Transition, client, state);
}

bool CanTakeOver(int bot, int target) {
	return !GetEntProp(bot, Prop_Send, "m_isIncapacitated") && !GetEntData(target, g_iOff_m_isOutOfCheckpoint);
}

bool OnEndScenario() {
	return view_as<float>(LoadFromAddress(g_pDirector + view_as<Address>(g_iOff_RestartScenarioTimer + 8), NumberType_Int32)) >= GetGameTime();
}

bool PrepRestoreBots() {
	return SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector) && LoadFromAddress(g_pSavedSurvivorBotsCount, NumberType_Int32);
}

void SetupDetours(GameData hGameData = null) {
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::GoAwayFromKeyboard");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::GoAwayFromKeyboard\" (%s)", PLUGIN_VERSION);

	if (!dDetour.Enable(Hook_Pre, DD_CTerrorPlayer_GoAwayFromKeyboard_Pre))
		SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::GoAwayFromKeyboard\" (%s)", PLUGIN_VERSION);

	if (!dDetour.Enable(Hook_Post, DD_CTerrorPlayer_GoAwayFromKeyboard_Post))
		SetFailState("Failed to detour post: \"DD::CTerrorPlayer::GoAwayFromKeyboard\" (%s)", PLUGIN_VERSION);

	dDetour = DynamicDetour.FromConf(hGameData, "DD::SurvivorBot::SetHumanSpectator");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::SurvivorBot::SetHumanSpectator\" (%s)", PLUGIN_VERSION);
		
	if (!dDetour.Enable(Hook_Pre, DD_SurvivorBot_SetHumanSpectator_Pre))
		SetFailState("Failed to detour pre: \"DD::SurvivorBot::SetHumanSpectator\" (%s)", PLUGIN_VERSION);

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CBasePlayer::SetModel");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CBasePlayer::SetModel\" (%s)", PLUGIN_VERSION);
		
	if (!dDetour.Enable(Hook_Post, DD_CBasePlayer_SetModel_Post))
		SetFailState("Failed to detour post: \"DD::CBasePlayer::SetModel\" (%s)", PLUGIN_VERSION);

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::GiveDefaultItems");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::GiveDefaultItems\" (%s)", PLUGIN_VERSION);

	if (!dDetour.Enable(Hook_Pre, DD_CTerrorPlayer_GiveDefaultItems_Pre))
		SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::GiveDefaultItems\" (%s)", PLUGIN_VERSION);
}

// [L4D1 & L4D2]Survivor_AFK_Fix[Left 4 Fix] (https://forums.alliedmods.net/showthread.php?p=2714236)
public void OnEntityCreated(int entity, const char[] classname) {
	if (!g_bShouldFixAFK)
		return;

	if (entity < 1 || entity > MaxClients)
		return;
	
	if (classname[0] != 's' || strcmp(classname[1], "urvivor_bot", false) != 0)
		return;

	g_iSurvivorBot = entity;
}

MRESReturn DD_CTerrorPlayer_GoAwayFromKeyboard_Pre(int pThis, DHookReturn hReturn) {
	g_bShouldFixAFK = true;
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_GoAwayFromKeyboard_Post(int pThis, DHookReturn hReturn) {
	if (g_bShouldFixAFK && g_iSurvivorBot > 0 && IsFakeClient(g_iSurvivorBot)) {
		g_bShouldIgnore = true;
		SetHumanSpec(g_iSurvivorBot, pThis);
		WriteTakeoverPanel(pThis, g_iSurvivorBot);
		g_bShouldIgnore = false;
	}

	g_iSurvivorBot = 0;
	g_bShouldFixAFK = false;
	return MRES_Ignored;
}

MRESReturn DD_SurvivorBot_SetHumanSpectator_Pre(int pThis, DHookParam hParams) {
	if (!g_bShouldFixAFK)
		return MRES_Ignored;

	if (g_bShouldIgnore)
		return MRES_Ignored;

	if (g_iSurvivorBot < 1)
		return MRES_Ignored;

	return MRES_Supercede;
}

// [L4D(2)] Survivor Identity Fix for 5+ Survivors (https://forums.alliedmods.net/showpost.php?p=2718792&postcount=36)
MRESReturn DD_CBasePlayer_SetModel_Post(int pThis, DHookParam hParams) {
	if (pThis < 1 || pThis > MaxClients || !IsClientInGame(pThis) || IsFakeClient(pThis))
		return MRES_Ignored;

	if (GetClientTeam(pThis) != TEAM_SURVIVOR) {
		g_ePlayer[pThis].model[0] = '\0';
		return MRES_Ignored;
	}
	
	char model[PLATFORM_MAX_PATH];
	hParams.GetString(1, model, sizeof model);
	if (StrContains(model, "models/survivors/survivor_", false) == 0)
		strcopy(g_ePlayer[pThis].model, sizeof Player::model, model);

	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_GiveDefaultItems_Pre(int pThis) {
	if (!g_bGiveType)
		return MRES_Ignored;

	if (g_bShouldFixAFK || g_bGiveTime && !g_bInSpawnTime)
		return MRES_Ignored;

	if (pThis < 1 || pThis > MaxClients || !IsClientInGame(pThis))
		return MRES_Ignored;

	if (GetClientTeam(pThis) != TEAM_SURVIVOR || !IsPlayerAlive(pThis) || ShouldIgnore(pThis))
		return MRES_Ignored;

	GiveDefaultItems(pThis);
	ClearRestoreWeapons(pThis);
	return MRES_Supercede;
}

void WriteTakeoverPanel(int client, int bot) {
	char buf[2];
	IntToString(GetEntProp(bot, Prop_Send, "m_survivorCharacter"), buf, sizeof buf);
	BfWrite bf = view_as<BfWrite>(StartMessageOne("VGUIMenu", client));
	bf.WriteString("takeover_survivor_bar");
	bf.WriteByte(true);
	bf.WriteByte(IN_ATTACK);
	bf.WriteString("character");
	bf.WriteString(buf);
	EndMessage();
}

bool ShouldIgnore(int client) {
	if (IsFakeClient(client))
		return !!GetIdlePlayerOfBot(client);

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SPECTATOR && GetIdlePlayerOfBot(i) == client)
			return true;
	}

	return false;
}

void ClearRestoreWeapons(int client) {
	SetEntData(client, g_iOff_m_hWeaponHandle, 0);
	SetEntData(client, g_iOff_m_iRestoreAmmo, 0);
	SetEntData(client, g_iOff_m_restoreWeaponID, 0);
}

void GiveDefaultItems(int client) {
	RemoveAllWeapons(client);
	for (int i = 4; i >= 2; i--) {
		if (!g_eWeapon[i].count)
			continue;

		GivePlayerItem(client, g_sWeaponName[i][g_eWeapon[i].allowed[Math_GetRandomInt(0, g_eWeapon[i].count - 1)]]);
	}

	GiveSecondary(client);
	switch (g_cGiveType.IntValue) {
		case 1:
			GivePresetPrimary(client);
		
		case 2:
			GiveAveragePrimary(client);
	}
}

void GiveSecondary(int client) {
	if (g_eWeapon[1].count) {
		int val = g_eWeapon[1].allowed[Math_GetRandomInt(0, g_eWeapon[1].count - 1)];
		if (val > 2)
			GiveMelee(client, g_sWeaponName[1][val]);
		else
			GivePlayerItem(client, g_sWeaponName[1][val]);
	}
}

void GivePresetPrimary(int client) {
	if (g_eWeapon[0].count)
		GivePlayerItem(client, g_sWeaponName[0][g_eWeapon[0].allowed[Math_GetRandomInt(0, g_eWeapon[0].count - 1)]]);
}

bool IsWeaponTier1(int weapon) {
	char cls[32];
	GetEntityClassname(weapon, cls, sizeof cls);
	for (int i; i < 5; i++) {
		if (strcmp(cls, g_sWeaponName[0][i], false) == 0)
			return true;
	}
	return false;
}

void GiveAveragePrimary(int client) {
	int i = 1, tier, total, weapon;
	if (g_bRoundStart) {
		for (; i <= MaxClients; i++) {
			if (i == client || !IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i))
				continue;

			total += 1;
			weapon = GetPlayerWeaponSlot(i, 0);
			if (weapon <= MaxClients || !IsValidEntity(weapon))
				continue;

			tier += IsWeaponTier1(weapon) ? 1 : 2;
		}
	}

	switch (total > 0 ? RoundToNearest(float(tier) / float(total)) : 0) {
		case 1:
			GivePlayerItem(client, g_sWeaponName[0][Math_GetRandomInt(0, 4)]);

		case 2:
			GivePlayerItem(client, g_sWeaponName[0][Math_GetRandomInt(5, 14)]);
	}
}

void RemoveAllWeapons(int client) {
	int weapon;
	for (int i; i < MAX_SLOTS; i++) {
		if ((weapon = GetPlayerWeaponSlot(client, i)) <= MaxClients)
			continue;

		RemovePlayerItem(client, weapon);
		RemoveEntity(weapon);
	}

	weapon = GetEntDataEnt2(client, g_iOff_m_hHiddenWeapon);
	SetEntData(client, g_iOff_m_hHiddenWeapon, -1);
	if (weapon > MaxClients && IsValidEntity(weapon) && GetEntPropEnt(weapon, Prop_Data, "m_hOwnerEntity") == client) {
		RemovePlayerItem(client, weapon);
		RemoveEntity(weapon);
	}
}

// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/math.inc
/**
 * Returns a random, uniform Integer number in the specified (inclusive) range.
 * This is safe to use multiple times in a function.
 * The seed is set automatically for each plugin.
 * Rewritten by MatthiasVance, thanks.
 *
 * @param min			Min value used as lower border
 * @param max			Max value used as upper border
 * @return				Random Integer number between min and max
 */
int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0) {
		random++;
	}

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}
