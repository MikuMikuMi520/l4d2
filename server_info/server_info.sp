#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#include <l4d2_ems_hud>

#define PLUGIN_NAME				"Server Info Hud"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.3"
#define PLUGIN_URL				""

enum struct KillData {
	int TotalSI;
	int TotalCI;

	void Clean() {
		this.TotalSI = 0;
		this.TotalCI = 0;
	}
}

KillData
	g_eData;

Handle
	g_hTimer;

bool
	g_bLateLoad;

float
	g_fMapRunTime,
	g_fMapMaxFlow;

int
	g_iMaxChapters,
	g_iCurrentChapter;

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
	CreateConVar("server_info_version", PLUGIN_VERSION, "Server Info Hud plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	HookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",	Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_death",	Event_PlayerDeath,	EventHookMode_Pre);
	HookEvent("infected_death",	Event_InfectedDeath);

	if (g_bLateLoad) {
		delete g_hTimer;
		g_hTimer = CreateTimer(1.0, tmrUpdate, _, TIMER_REPEAT);
	}
}

public void OnConfigsExecuted() {
	g_fMapRunTime = GetEngineTime();
	g_fMapMaxFlow = L4D2Direct_GetMapMaxFlowDistance();

	g_iMaxChapters = L4D_GetMaxChapters();
	g_iCurrentChapter = L4D_GetCurrentChapter();
}

public void OnMapStart() {
	EnableHUD();
}

public void OnMapEnd() {
	delete g_hTimer;
	g_eData.Clean();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	delete g_hTimer;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	delete g_hTimer;
	g_hTimer = CreateTimer(1.0, tmrUpdate, _, TIMER_REPEAT);
}

Action tmrUpdate(Handle timer) {
	static int client;
	static float highestFlow;
	highestFlow = (client = L4D_GetHighestFlowSurvivor()) != -1 ? L4D2Direct_GetFlowDistance(client) : L4D2_GetFurthestSurvivorFlow();
	if (highestFlow)
		highestFlow = highestFlow / g_fMapMaxFlow * 100;

	static char buffer[128];
	FormatEx(buffer, sizeof buffer, "➣路程: %d％", RoundToCeil(highestFlow));

	int len;
	int round = GameRules_GetProp("m_bInSecondHalfOfRound");
	if (L4D2Direct_GetVSTankToSpawnThisRound(round)) {
		len = strlen(buffer);
		Format(buffer[len], sizeof buffer - len, " [Tank]: %d％", RoundToNearest(L4D2Direct_GetVSTankFlowPercent(round) * 100.0));
	}
		
	if (L4D2Direct_GetVSWitchToSpawnThisRound(round)) {
		len = strlen(buffer);
		Format(buffer[len], sizeof buffer - len, " [Witch]: %d％", RoundToNearest(L4D2Direct_GetVSWitchFlowPercent(round) * 100.0));
	}

	HUDSetLayout(HUD_SCORE_1, HUD_FLAG_BLINK|HUD_FLAG_NOBG|HUD_FLAG_ALIGN_LEFT|HUD_FLAG_TEXT, "%s", buffer);
	HUDPlace(HUD_SCORE_1, 0.70, 0.86, 1.0, 0.03);

	HUDSetLayout(HUD_SCORE_2, HUD_FLAG_NOBG|HUD_FLAG_ALIGN_LEFT|HUD_FLAG_TEXT, "➣地图: %d/%d", g_iCurrentChapter, g_iMaxChapters);
	HUDPlace(HUD_SCORE_2, 0.70, 0.89, 1.0, 0.03);

	HUDSetLayout(HUD_SCORE_3, HUD_FLAG_NOBG|HUD_FLAG_ALIGN_LEFT|HUD_FLAG_TEXT, "➣运行: %dm | %dm", RoundToFloor((GetEngineTime() - g_fMapRunTime) / 60.0), RoundToFloor(GetEntProp(L4D_GetResourceEntity(), Prop_Send, "m_missionDuration") / 60.0));
	HUDPlace(HUD_SCORE_3, 0.70, 0.92, 1.0, 0.03);

	HUDSetLayout(HUD_SCORE_4, HUD_FLAG_NOBG|HUD_FLAG_ALIGN_LEFT|HUD_FLAG_TEXT, "➣统计: %d特感 %d僵尸", g_eData.TotalSI, g_eData.TotalCI);
	HUDPlace(HUD_SCORE_4, 0.70, 0.95, 1.0, 0.03);

	return Plugin_Continue;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 3)
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;
	
	g_eData.TotalSI++;
}

void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;

	g_eData.TotalCI++;
}

