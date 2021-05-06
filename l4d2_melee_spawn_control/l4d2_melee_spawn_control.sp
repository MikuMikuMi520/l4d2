/*====================================================
1.3
	- Fixed the meleeweapons list if some 3rd party map mission do not declare the "meleeweapons".
	- Save the initial meleeweapons list. After changing the new mission, the "meleeweapons" will be restored and redeclared.

1.2
	- Fixed didn't take effect in time if added Cvars to server.cfg. Thanks to "Target_7" for reporting.

1.1
	- Fixed broken windows signatures.
	- Not forces map to reload any more.
	- Thanks to "Silvers" for reporting and help.

1.0
	- Initial release
======================================================*/
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define GAMEDATA 	   "l4d2_melee_spawn_control"
#define FILE_PATH 	   "scripts\\melee\\melee_manifest.txt"
#define DEFAULT_MELEES "fireaxe;frying_pan;machete;baseball_bat;crowbar;cricket_bat;tonfa;katana;electric_guitar;knife;golfclub;shovel;pitchfork"

DynamicDetour g_dDetourMeleeWeaponAllowedToExist;
DynamicDetour g_dDetourGameRulesGetMissionInfo;

StringMap g_aMapSetMelees;
StringMap g_aMapInitMelees;

Handle g_hSDK_Call_KvGetString; 
Handle g_hSDK_Call_KvSetString; 
Handle g_hSDK_Call_KvFindKey;

ConVar g_hCvarMeleeSpawn;
ConVar g_hCvarAddMelee;

public Plugin myinfo=
{
	name = "l4d2 melee spawn control",
	author = "IA/NanaNana",
	description = "Unlock melee weapons",
	version = "1.3",
	url = "https://forums.alliedmods.net/showthread.php?p=2719531"
}

public void OnPluginStart()
{
	LoadGameData();

	g_aMapSetMelees = new StringMap();
	g_aMapInitMelees = new StringMap();

	g_hCvarMeleeSpawn = CreateConVar("l4d2_melee_spawn", "", "Melee weapon list for unlock, use ';' to separate between names, e.g: pitchfork;shovel. Empty for no change");
	g_hCvarAddMelee = CreateConVar("l4d2_add_melee", "", "Add melee weapons to map basis melee spawn or l4d2_melee_spawn, use ';' to separate between names. Empty for don't add");
}

public void OnPluginEnd()
{
	if(!g_dDetourMeleeWeaponAllowedToExist.Disable(Hook_Post, MeleeWeaponAllowedToExistPost))
		SetFailState("Failed to disable detour: CDirectorItemManager::IsMeleeWeaponAllowedToExist");

	if(!g_dDetourGameRulesGetMissionInfo.Disable(Hook_Post, GameRulesGetMissionInfoPost))
		SetFailState("Failed to disable detour: CTerrorGameRules::GetMissionInfo");
}

public void OnMapEnd()
{
	g_aMapSetMelees.Clear();
}

public MRESReturn MeleeWeaponAllowedToExistPost(DHookReturn hReturn, DHookParam hParams)
{
	/*char sScriptName[32];
	hParams.GetString(1, sScriptName, sizeof(sScriptName));
	if(strcmp(sScriptName, "knife") == 0)
	{
		hReturn.Value = true;
		return MRES_Override;
	}
	
	return MRES_Ignored;*/

	hReturn.Value = true;
	return MRES_Override;
}

public MRESReturn GameRulesGetMissionInfoPost(DHookReturn hReturn)
{
	int pThis = hReturn.Value;
	if(pThis == 0)
		return MRES_Ignored;
		
	char sMapCurrentMelees[512];
	SDKCall(g_hSDK_Call_KvGetString, pThis, sMapCurrentMelees, sizeof(sMapCurrentMelees), "meleeweapons", "");

	char sMap[64], sMapBaseMelees[512];
	FindConVar("mp_gamemode").GetString(sMap, sizeof(sMap));
	SDKCall(g_hSDK_Call_KvGetString, SDKCall(g_hSDK_Call_KvFindKey, SDKCall(g_hSDK_Call_KvFindKey, SDKCall(g_hSDK_Call_KvFindKey, pThis, "modes", false), sMap, false), "1", false), sMap, sizeof(sMap), "Map", "N/A");

	if(strcmp(sMap, "N/A") == 0)
		return MRES_Ignored;

	if(g_aMapInitMelees.GetString(sMap, sMapBaseMelees, sizeof(sMapBaseMelees)) == false)
	{
		if(sMapCurrentMelees[0] != 0)
			strcopy(sMapBaseMelees, sizeof(sMapBaseMelees), sMapCurrentMelees);
		else
			ReadMeleeManifest(sMapBaseMelees, sizeof(sMapBaseMelees)); //darkwood
			
		if(sMapBaseMelees[0] == 0)
			strcopy(sMapBaseMelees, sizeof(sMapBaseMelees), DEFAULT_MELEES);
	
		g_aMapInitMelees.SetString(sMap, sMapBaseMelees, false);
	}

	char sMapSetMelees[512];
	if(g_aMapSetMelees.GetString(sMap, sMapSetMelees, sizeof(sMapSetMelees)) == false)
		GetMapSetMelees(sMap, sMapBaseMelees, sMapSetMelees, sizeof(sMapSetMelees));

	if(sMapSetMelees[0] == 0)
		return MRES_Ignored;

	if(strcmp(sMapSetMelees, sMapCurrentMelees) == 0)
		return MRES_Ignored;

	SDKCall(g_hSDK_Call_KvSetString, pThis, "meleeweapons", sMapSetMelees);
	return MRES_Ignored;
}

void GetMapSetMelees(const char[] sMap, const char[] sMapBaseMelees, char[] sMapSetMelees, int maxlength)
{
	char sBaseMelees[512], sExtraMelees[512];
	g_hCvarMeleeSpawn.GetString(sBaseMelees, sizeof(sBaseMelees));
	g_hCvarAddMelee.GetString(sExtraMelees, sizeof(sExtraMelees));
	ReplaceString(sBaseMelees, sizeof(sBaseMelees), " ", "");
	ReplaceString(sExtraMelees, sizeof(sExtraMelees), " ", "");

	if(sBaseMelees[0] == 0)
	{
		if(sExtraMelees[0] == 0)
		{
			g_aMapSetMelees.SetString(sMap, "", true);
			return;
		}

		strcopy(sBaseMelees, sizeof(sBaseMelees), sMapBaseMelees);
	}

	if(sExtraMelees[0] != 0)
	{
		Format(sBaseMelees, sizeof(sBaseMelees), ";%s;", sBaseMelees);
		int iCount = ReplaceString(sExtraMelees, sizeof(sExtraMelees), ";", ";") + 1;
		char[][] sBuffer = new char[iCount][32];
		ExplodeString(sExtraMelees, ";", sBuffer, iCount, 32);
		sExtraMelees[0] = 0;

		for(int i; i < iCount; i++)
		{
			if(sBuffer[i][0] == 0)
				continue;
				
			Format(sBuffer[i], 32, ";%s;", sBuffer[i]);
			if(StrContains(sBaseMelees, sBuffer[i]) == -1)
				StrCat(sExtraMelees, sizeof(sExtraMelees), sBuffer[i][1]);
		}

		if(sExtraMelees[0] != 0)
			StrCat(sBaseMelees, sizeof(sBaseMelees), sExtraMelees);

		strcopy(sBaseMelees, sizeof(sBaseMelees), sBaseMelees[1]);
		
		sBaseMelees[strlen(sBaseMelees) - 1] = 0;
	}
	
	int pos = GetCharPosInString(sBaseMelees , ';', 16);
	if(pos != -1)
		sBaseMelees[pos] = 0;
		
	strcopy(sMapSetMelees, maxlength, sBaseMelees);
	g_aMapSetMelees.SetString(sMap, sBaseMelees, true);
}

stock int GetCharPosInString(const char[] str, char c, int which)
{
	int len = strlen(str);
	if(which > len)
		return -1;

	int total;
	for(int i; i < len; i++)
	{
		if(str[i] == c)
		{
			total++;
			if(total == which)
				return i;
		}
	}
	return -1;
}

void ReadMeleeManifest(char[] sManifest, int maxlength)
{
	File file = OpenFile(FILE_PATH, "r");
	if(file == null)
		file = OpenFile(FILE_PATH, "r", true, NULL_STRING);

	if(file == null)
		return;

	while(!file.EndOfFile())
	{
		char sLine[255];
		if(!file.ReadLine(sLine, sizeof(sLine)))
			break;

		ReplaceString(sLine, sizeof(sLine), " ", "");

		if(strlen(sLine) < 27)
			continue;

		if(SplitStringRight(sLine, "scripts/melee/", sLine, sizeof(sLine)) && SplitString(sLine, ".txt", sLine, sizeof(sLine)) != -1)
			Format(sManifest, maxlength, "%s;%s", sManifest, sLine);
	}
	
	if(sManifest[0] != 0)
		strcopy(sManifest, maxlength, sManifest[1]);

	delete file;
}

stock bool SplitStringRight(const char[] source, const char[] split, char[] part, int partLen)
{
	int index = StrContains(source, split); // get start index of split string 
	
	if(index == -1) // split string not found.. 
		return false;
	
	index += strlen(split); // get end index of split string
	
	if(index == strlen(source) - 1) // no right side exist
		return false;
	
	strcopy(part, partLen, source[index]); // copy everything after source[ index ] to part 
	return true;
}

void LoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetString");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	if((g_hSDK_Call_KvGetString = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: KeyValues::GetString");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetString");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if((g_hSDK_Call_KvSetString = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: KeyValues::SetString");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::FindKey");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hSDK_Call_KvFindKey = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: KeyValues::FindKey");

	SetupDetours(hGameData);

	delete hGameData;
}

void SetupDetours(GameData hGameData = null)
{
	g_dDetourMeleeWeaponAllowedToExist = DynamicDetour.FromConf(hGameData, "CDirectorItemManager::IsMeleeWeaponAllowedToExist");
	if(g_dDetourMeleeWeaponAllowedToExist == null)
		SetFailState("Failed to find signature: CDirectorItemManager::IsMeleeWeaponAllowedToExist");
		
	if(!g_dDetourMeleeWeaponAllowedToExist.Enable(Hook_Post, MeleeWeaponAllowedToExistPost))
		SetFailState("Failed to detour post: CDirectorItemManager::IsMeleeWeaponAllowedToExist");

	g_dDetourGameRulesGetMissionInfo = DynamicDetour.FromConf(hGameData, "CTerrorGameRules::GetMissionInfo");
	if(g_dDetourGameRulesGetMissionInfo == null)
		SetFailState("Failed to find signature: CTerrorGameRules::GetMissionInfo");
		
	if(!g_dDetourGameRulesGetMissionInfo.Enable(Hook_Post, GameRulesGetMissionInfoPost))
		SetFailState("Failed to detour post: CTerrorGameRules::GetMissionInfo");
}