#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <sourcescramble>

#define PLUGIN_NAME						"Versus Coop Mode"
#define PLUGIN_AUTHOR					"sorallll"
#define PLUGIN_DESCRIPTION				""
#define PLUGIN_VERSION					"1.0.2"
#define PLUGIN_URL						""

#define GAMEDATA						"versus_coop_mode"

#define OFFSET_RESTARTSCENARIOTIMER		"RestartScenarioTimer"
#define OFFSET_ISFIRSTROUNDFINISHED		"m_bIsFirstRoundFinished"
#define OFFSET_ISSECONDROUNDFINISHED	"m_bIsSecondRoundFinished"

#define PATCH_SWAPTEAMS_PATCH1			"SwapTeams::Patch1"
#define PATCH_SWAPTEAMS_PATCH2			"SwapTeams::Patch2"
#define PATCH_CLEANUPMAP_PATCH			"CleanUpMap::ShouldCreateEntity::Patch"

#define DETOUR_RESTARTVSMODE			"DD::CDirectorVersusMode::RestartVsMode"

Address
	g_pDirector;

bool
	g_bTransitionFired;

int
	RestartScenarioTimer,
	m_bIsFirstRoundFinished,
	m_bIsSecondRoundFinished;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	InitGameData();
	CreateConVar("versus_coop_mode_version", PLUGIN_VERSION, "Versus Coop Mode plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	HookUserMessage(GetUserMessageId("VGUIMenu"), umVGUIMenu, true);
	HookEvent("round_start",	Event_RoundStart,		EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_MapTransition,	EventHookMode_Pre);
}

void InitGameData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pDirector = hGameData.GetAddress("CDirector");
	if (!g_pDirector)
		SetFailState("Failed to find address: \"CDirector\"");

	GetOffsets(hGameData);
	InitPatchs(hGameData);
	SetupDetours(hGameData);

	delete hGameData;
}

void GetOffsets(GameData hGameData = null) {
	RestartScenarioTimer = hGameData.GetOffset(OFFSET_RESTARTSCENARIOTIMER);
	if (RestartScenarioTimer == -1)
		SetFailState("Failed to find offset: \"%s\"", OFFSET_RESTARTSCENARIOTIMER);

	m_bIsFirstRoundFinished = hGameData.GetOffset(OFFSET_ISFIRSTROUNDFINISHED);
	if (m_bIsFirstRoundFinished == -1)
		SetFailState("Failed to find offset: \"%s\"", OFFSET_ISFIRSTROUNDFINISHED);

	m_bIsSecondRoundFinished = hGameData.GetOffset(OFFSET_ISSECONDROUNDFINISHED);
	if (m_bIsSecondRoundFinished == -1)
		SetFailState("Failed to find offset: \"%s\"", OFFSET_ISSECONDROUNDFINISHED);
}

void InitPatchs(GameData hGameData = null) {
	MemoryPatch patch = MemoryPatch.CreateFromConf(hGameData, PATCH_SWAPTEAMS_PATCH1);
	if (!patch.Validate())
		SetFailState("Failed to verify patch: \"%s\"", PATCH_SWAPTEAMS_PATCH1);
	else if (patch.Enable())
		PrintToServer("Enabled patch: \"%s\"", PATCH_SWAPTEAMS_PATCH1);

	patch = MemoryPatch.CreateFromConf(hGameData, PATCH_SWAPTEAMS_PATCH2);
	if (!patch.Validate())
		SetFailState("Failed to verify patch: \"%s\"", PATCH_SWAPTEAMS_PATCH2);
	else if (patch.Enable())
		PrintToServer("Enabled patch: \"%s\"", PATCH_SWAPTEAMS_PATCH2);

	patch = MemoryPatch.CreateFromConf(hGameData, PATCH_CLEANUPMAP_PATCH);
	if (!patch.Validate())
		SetFailState("Failed to verify patch: \"%s\"", PATCH_CLEANUPMAP_PATCH);
	else if (patch.Enable())
		PrintToServer("Enabled patch: \"%s\"", PATCH_CLEANUPMAP_PATCH);
}

void SetupDetours(GameData hGameData = null) {
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, DETOUR_RESTARTVSMODE);
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"%s\"", DETOUR_RESTARTVSMODE);

	if (!dDetour.Enable(Hook_Pre, DD_CDirectorVersusMode_RestartVsMode_Pre))
		SetFailState("Failed to detour pre: \"%s\"", DETOUR_RESTARTVSMODE);
		
	if (!dDetour.Enable(Hook_Post, DD_CDirectorVersusMode_RestartVsMode_Post))
		SetFailState("Failed to detour post: \"%s\"", DETOUR_RESTARTVSMODE);
}

MRESReturn DD_CDirectorVersusMode_RestartVsMode_Pre(Address pThis, DHookReturn hReturn) {
	StoreToAddress(g_pDirector + view_as<Address>(m_bIsFirstRoundFinished), g_bTransitionFired ? 1 : 0, NumberType_Int32);
	return MRES_Ignored;
}

MRESReturn DD_CDirectorVersusMode_RestartVsMode_Post(Address pThis, DHookReturn hReturn) {
	if (!g_bTransitionFired) {
		StoreToAddress(g_pDirector + view_as<Address>(m_bIsFirstRoundFinished), 0, NumberType_Int32);
		StoreToAddress(g_pDirector + view_as<Address>(m_bIsSecondRoundFinished), 0, NumberType_Int32);
	}

	g_bTransitionFired = false;
	return MRES_Ignored;
}

bool OnEndScenario() {
	return view_as<float>(LoadFromAddress(g_pDirector + view_as<Address>(RestartScenarioTimer + 8), NumberType_Int32)) > 0.0;
}

Action umVGUIMenu(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	static char buffer[26];
	msg.ReadString(buffer, sizeof buffer, true);
	if (strcmp(buffer, "fullscreen_vs_scoreboard") == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	g_bTransitionFired = false;
}

Action Event_MapTransition(Event event, const char[] name, bool dontBroadcast) {
	if (!OnEndScenario())
		return Plugin_Handled;

	g_bTransitionFired = true;
	return Plugin_Continue;
}
