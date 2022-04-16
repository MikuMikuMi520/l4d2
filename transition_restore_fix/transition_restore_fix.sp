#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <sourcescramble>

#define DEBUG 0

#define GAMEDATA	"transition_restore_fix"

Handle
	g_hSDK_KeyValues_GetString,
	g_hSDK_KeyValues_SetString,
	g_hSDK_CDirector_IsInTransition;

#if DEBUG
Handle
	g_hSDK_CTerrorPlayer_TransitionRestore;
#endif

ConVar
	g_hKeepIdentity;

Address
	g_pDirector,
	g_pSavedPlayerCount,
	g_pSavedSurvivorBotCount;

MemoryPatch
	g_mpRestoreByUserId;

DynamicDetour
	g_ddCDirector_Restart;

bool
	g_bCDirector_Restart,
	g_bCDirectorSessionManager_UpdateNewPlayers;

#if DEBUG
int
	g_iOff_m_isTransitioned;
#endif

enum struct PlayerSaveData
{
	char character[4];
	char modelName[PLATFORM_MAX_PATH];
}

PlayerSaveData
	g_esSavedData;

public Plugin myinfo =
{
	name = "Transition Restore Fix",
	author = "sorallll",
	description = "Restoring transition data by player's UserId instead of character",
	version = "1.1.8",
	url = "https://forums.alliedmods.net/showthread.php?t=336287"
};

public void OnPluginStart()
{
	vInitGameData();

	g_hKeepIdentity = CreateConVar("restart_keep_identity", "1", "Whether to keep the current character and model after the mission lost and restarts? (0=restore to pre-transition identity, 1=game default)", FCVAR_NOTIFY);
	g_hKeepIdentity.AddChangeHook(vConVarChanged);

	AutoExecConfig(true, "transition_restore_fix");

	#if DEBUG
	RegAdminCmd("sm_restore", cmdRestore, ADMFLAG_ROOT);
	#endif
}

#if DEBUG
Action cmdRestore(int client, int args)
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)
		return Plugin_Handled;

	SetEntData(client, g_iOff_m_isTransitioned, 1);
	SDKCall(g_hSDK_CTerrorPlayer_TransitionRestore, client);
	return Plugin_Handled;
}
#endif

public void OnConfigsExecuted()
{
	vToggleDetours(g_hKeepIdentity.BoolValue);
}

void vConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vToggleDetours(g_hKeepIdentity.BoolValue);
}

void vToggleDetours(bool bEnable)
{
	static bool bEnabled;
	if (!bEnabled && bEnable) {
		bEnabled = true;

		if (!g_ddCDirector_Restart.Enable(Hook_Pre, DD_CDirector_Restart_Pre))
			SetFailState("Failed to detour pre: \"DD::CDirector::Restart\"");
		
		if (!g_ddCDirector_Restart.Enable(Hook_Post, DD_CDirector_Restart_Post))
			SetFailState("Failed to detour post: \"DD::CDirector::Restart\"");
	}
	else if (bEnabled && !bEnable) {
		bEnabled = false;

		if (!g_ddCDirector_Restart.Disable(Hook_Pre, DD_CDirector_Restart_Pre))
			SetFailState("Failed to disable detour pre: \"DD::CDirector::Restart\"");

		if (!g_ddCDirector_Restart.Disable(Hook_Post, DD_CDirector_Restart_Post))
			SetFailState("Failed to disable detour post: \"DD::CDirector::Restart\"");
	}
}

void vInitGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pDirector = hGameData.GetAddress("CDirector");
	if (!g_pDirector)
		SetFailState("Failed to find address: \"CDirector\"");

	g_pSavedPlayerCount = hGameData.GetAddress("SavedPlayerCount");
	if (!g_pSavedPlayerCount)
		SetFailState("Failed to find address: \"SavedPlayerCount\"");

	g_pSavedSurvivorBotCount = hGameData.GetAddress("SavedSurvivorBotCount");
	if (!g_pSavedSurvivorBotCount)
		SetFailState("Failed to find address: \"SavedSurvivorBotCount\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetString"))
		SetFailState("Failed to find signature: \"KeyValues::GetString\"");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	if (!(g_hSDK_KeyValues_GetString = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"KeyValues::GetString\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetString"))
		SetFailState("Failed to find signature: \"KeyValues::SetString\"");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if (!(g_hSDK_KeyValues_SetString = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"KeyValues::SetString\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::IsInTransition"))
		SetFailState("Failed to find signature: \"CDirector::IsInTransition\"");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_CDirector_IsInTransition = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CDirector::IsInTransition\"");

	#if DEBUG
	g_iOff_m_isTransitioned = hGameData.GetOffset("CTerrorPlayer::IsTransitioned::m_isTransitioned");
	if (g_iOff_m_isTransitioned == -1)
		SetFailState("Failed to find offset: \"CTerrorPlayer::IsTransitioned::m_isTransitioned\"");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::TransitionRestore"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::TransitionRestore\"");
	if (!(g_hSDK_CTerrorPlayer_TransitionRestore = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::TransitionRestore\"");
	#endif

	vInitPatchs(hGameData);
	vSetupDetours(hGameData);

	delete hGameData;
}

void vInitPatchs(GameData hGameData = null)
{
	g_mpRestoreByUserId = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::TransitionRestore::RestoreByUserId");
	if (!g_mpRestoreByUserId.Validate())
		SetFailState("Failed to verify patch: \"CTerrorPlayer::TransitionRestore::RestoreByUserId\"");

	MemoryPatch patch = MemoryPatch.CreateFromConf(hGameData, "RestoreTransitionedSurvivorBots::MaxRestoreSurvivorBots");
	if (!patch.Validate())
		SetFailState("Failed to verify patch: \"RestoreTransitionedSurvivorBots::MaxRestoreSurvivorBots\"");
	else if (patch.Enable()) {
		PrintToServer("[%s] Enabled patch: \"RestoreTransitionedSurvivorBots::MaxRestoreSurvivorBots\"", GAMEDATA);
		StoreToAddress(patch.Address + view_as<Address>(2), MaxClients, NumberType_Int8);
	}
}

void vSetupDetours(GameData hGameData = null)
{
	g_ddCDirector_Restart = DynamicDetour.FromConf(hGameData, "DD::CDirector::Restart");
	if (!g_ddCDirector_Restart)
		SetFailState("Failed to create DynamicDetour: \"DD::CDirector::Restart\"");

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::TransitionRestore");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::TransitionRestore\"");

	if (!dDetour.Enable(Hook_Pre, DD_CTerrorPlayer_TransitionRestore_Pre))
		SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::TransitionRestore\"");

	if (!dDetour.Enable(Hook_Post, DD_CTerrorPlayer_TransitionRestore_Post))
		SetFailState("Failed to detour post: \"DD::CTerrorPlayer::TransitionRestore\"");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CDirector::IsHumanSpectatorValid");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CDirector::IsHumanSpectatorValid\"");

	if (!dDetour.Enable(Hook_Pre, DD_CDirector_IsHumanSpectatorValid_Pre))
		SetFailState("Failed to detour pre: \"DD::CDirector::IsHumanSpectatorValid\"");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CDirectorSessionManager::UpdateNewPlayers");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CDirectorSessionManager::UpdateNewPlayers\"");

	if (!dDetour.Enable(Hook_Pre, DD_CDirectorSessionManager_UpdateNewPlayers_Pre))
		SetFailState("Failed to detour pre: \"DD::CDirectorSessionManager::UpdateNewPlayers\"");

	if (!dDetour.Enable(Hook_Post, DD_CDirectorSessionManager_UpdateNewPlayers_Post))
		SetFailState("Failed to detour post: \"DD::CDirectorSessionManager::UpdateNewPlayers\"");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CDirectorSessionManager::FillRemainingSurvivorTeamSlotsWithBots");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CDirectorSessionManager::FillRemainingSurvivorTeamSlotsWithBots\"");

	if (!dDetour.Enable(Hook_Pre, DD_CDirectorSessionManager_FillRemainingSurvivorTeamSlotsWithBots_Pre))
		SetFailState("Failed to detour pre: \"DD::CDirectorSessionManager::FillRemainingSurvivorTeamSlotsWithBots\"");
}

MRESReturn DD_CDirector_Restart_Pre(Address pThis)
{
	g_bCDirector_Restart = true;
	return MRES_Ignored;
}

MRESReturn DD_CDirector_Restart_Post(Address pThis)
{
	g_bCDirector_Restart = false;
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_TransitionRestore_Pre(int pThis)
{
	if (IsFakeClient(pThis))
		return MRES_Ignored;

	int iTeam = GetClientTeam(pThis);
	if (iTeam > 2)
		return MRES_Ignored;

	Address pSavedData = pFindSavedDataByUserId(GetClientUserId(pThis));
	if (!pSavedData)
		return MRES_Ignored;

	char teamNumber[4];
	SDKCall(g_hSDK_KeyValues_GetString, pSavedData, teamNumber, sizeof teamNumber, "teamNumber", "0");
	if (StringToInt(teamNumber) != 2)
		return MRES_Ignored;

	if (g_bCDirector_Restart && iTeam == 2) {
		char character[4];
		SDKCall(g_hSDK_KeyValues_GetString, pSavedData, character, sizeof character, "character", "");
		if (character[0]) {
			char modelName[PLATFORM_MAX_PATH];
			SDKCall(g_hSDK_KeyValues_GetString, pSavedData, modelName, sizeof modelName, "modelName", "");
			if (modelName[0]) {
				strcopy(g_esSavedData.character, sizeof PlayerSaveData::character, character);
				strcopy(g_esSavedData.modelName, sizeof PlayerSaveData::modelName, modelName);

				IntToString(GetEntProp(pThis, Prop_Send, "m_survivorCharacter"), character, sizeof character);
				SDKCall(g_hSDK_KeyValues_SetString, pSavedData, "character", character);

				GetEntPropString(pThis, Prop_Data, "m_ModelName", modelName, sizeof modelName);
				SDKCall(g_hSDK_KeyValues_SetString, pSavedData, "modelName", modelName);
			}
		}
	}

	g_mpRestoreByUserId.Enable();
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_TransitionRestore_Post(int pThis)
{
	if (g_esSavedData.character[0] && g_esSavedData.modelName[0]) {
		g_esSavedData.character[0] = '\0';
		g_esSavedData.modelName[0] = '\0';

		Address pSavedData = pFindSavedDataByUserId(GetClientUserId(pThis));
		if (pSavedData) {
			SDKCall(g_hSDK_KeyValues_SetString, pSavedData, "character", g_esSavedData.character);
			SDKCall(g_hSDK_KeyValues_SetString, pSavedData, "modelName", g_esSavedData.modelName);
		}
	}

	g_mpRestoreByUserId.Disable();
	return MRES_Ignored;
}

/**
* Prevents players joining the game during transition from taking over the Survivor Bot of transitioning players
**/
MRESReturn DD_CDirector_IsHumanSpectatorValid_Pre(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
	if (!g_bCDirectorSessionManager_UpdateNewPlayers)
		return MRES_Ignored;

	if (!SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector))
		return MRES_Ignored;

	int m_humanSpectatorUserID = GetEntProp(hParams.Get(1), Prop_Send, "m_humanSpectatorUserID");
	if (!GetClientOfUserId(m_humanSpectatorUserID))
		return MRES_Ignored;

	Address pSavedData = pFindSavedDataByUserId(m_humanSpectatorUserID);
	if (!pSavedData)
		return MRES_Ignored;

	char restoreState[4];
	SDKCall(g_hSDK_KeyValues_GetString, pSavedData, restoreState, sizeof restoreState, "restoreState", "0");
	if (StringToInt(restoreState) == 2)
		return MRES_Ignored;

	#if DEBUG
	static const char sSurvivorNames[][] =
	{
		"Nick",
		"Rochelle",
		"Coach",
		"Ellis",
		"Bill",
		"Zoey",
		"Francis",
		"Louis",
	};

	int iSurvivorBot = hParams.Get(1);
	int iIdlePlayer = GetClientOfUserId(m_humanSpectatorUserID);
	vLogCustom("logs/transition_restore_fix.log", "[SurvivorBot]->%d %s [IdlePlayer]->%d %N restoreState->%d m_humanSpectatorUserID->%d", iSurvivorBot, sSurvivorNames[GetEntProp(iSurvivorBot, Prop_Send, "m_survivorCharacter")], iIdlePlayer, iIdlePlayer, StringToInt(restoreState), m_humanSpectatorUserID);
	#endif

	hReturn.Value = 1;
	return MRES_Supercede;
}

MRESReturn DD_CDirectorSessionManager_UpdateNewPlayers_Pre(Address pThis)
{
	g_bCDirectorSessionManager_UpdateNewPlayers = true;
	return MRES_Ignored;
}

MRESReturn DD_CDirectorSessionManager_UpdateNewPlayers_Post(Address pThis)
{
	g_bCDirectorSessionManager_UpdateNewPlayers = false;
	return MRES_Ignored;
}

/**
* Prevent CDirectorSessionManager::FillRemainingSurvivorTeamSlotsWithBots from triggering before RestoreTransitionedSurvivorBots(void) during transition
**/
MRESReturn DD_CDirectorSessionManager_FillRemainingSurvivorTeamSlotsWithBots_Pre(Address pThis)
{
	if (!g_bCDirectorSessionManager_UpdateNewPlayers)
		return MRES_Ignored;

	if (!SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector))
		return MRES_Ignored;

	if (!LoadFromAddress(g_pSavedSurvivorBotCount, NumberType_Int32))
		return MRES_Ignored;

	#if DEBUG
	vLogCustom("logs/transition_restore_fix.log", "SavedSurvivorBotCount->%d", LoadFromAddress(g_pSavedSurvivorBotCount, NumberType_Int32));
	#endif
	return MRES_Supercede;
}

// 读取玩家过关时保存的userID
Address pFindSavedDataByUserId(int userid)
{
	int iSavedPlayerCount = LoadFromAddress(g_pSavedPlayerCount, NumberType_Int32);
	if (!iSavedPlayerCount)
		return Address_Null;

	Address pSavedPlayers = view_as<Address>(LoadFromAddress(g_pSavedPlayerCount + view_as<Address>(4), NumberType_Int32));
	if (!pSavedPlayers)
		return Address_Null;

	Address pThis;
	char userID[12];
	for (int i; i < iSavedPlayerCount; i++) {
		pThis = view_as<Address>(LoadFromAddress(pSavedPlayers + view_as<Address>(4 * i), NumberType_Int32));
		if (!pThis)
			continue;

		SDKCall(g_hSDK_KeyValues_GetString, pThis, userID, sizeof userID, "userID", "0");
		if (StringToInt(userID) == userid)
			return pThis;
	}

	return Address_Null;
}

#if DEBUG
void vLogCustom(const char[] path, const char[] sMessage, any ...)
{
	char sTime[32];
	FormatTime(sTime, sizeof sTime, "%x %X");

	char sMap[64];
	GetCurrentMap(sMap, sizeof sMap);

	char sBuffer[255];
	VFormat(sBuffer, sizeof sBuffer, sMessage, 3);

	Format(sBuffer, sizeof sBuffer, "[%s] [%s] %s", sTime, sMap, sBuffer);

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, path);
	File file = OpenFile(sPath, "a+");
	file.WriteLine("%s", sBuffer);
	file.Flush();
	delete file;
}
#endif
