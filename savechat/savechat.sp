#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <geoip>

#define PLUGIN_VERSION "1.3"

StringMap
	g_aCommands;

ConVar
	g_cvHostport;

int
	g_iRoundCount;

char
	g_sMap[64],
	g_sMsg[PLATFORM_MAX_PATH],
	g_sLogPath[PLATFORM_MAX_PATH];

static const char
	g_sCommands[][] = {
		"say",
		"say_team",
		"callvote",
		"unpause",
		"setpause",
		"choose_opendoor",
		"choose_closedoor",
		"go_away_from_keyboard"
	};

public Plugin myinfo = {
	name = "SaveChat",
	author = "citkabuto, sorallll",
	description = "Records player chat messages to a file",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=117116"
}

public void OnPluginStart() {
	InitCommands();
	g_cvHostport = FindConVar("hostport");

	FormatTime(g_sMsg, sizeof g_sMsg, "%d%m%y", -1);
	BuildPath(Path_SM, g_sLogPath, sizeof g_sLogPath, "/logs/chat%s-%i.log", g_sMsg, g_cvHostport.IntValue);

	HookEvent("round_end",			Event_RoundEnd,			EventHookMode_PostNoCopy);
	HookEvent("round_start",		Event_RoundStart,		EventHookMode_PostNoCopy);
	HookEvent("player_disconnect",	Event_PlayerDisconnect,	EventHookMode_Pre);

	AddCommandListener(CommandListener, "");
}

void InitCommands() {
	g_aCommands = new StringMap();
	for(int i; i < sizeof g_sCommands; i++)
		g_aCommands.SetValue(g_sCommands[i], i);
}

Action CommandListener(int client, char[] command, int argc) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;

	if (strncmp(command, "sm", 2) != 0) {
		static int value;
		StringToLowerCase(command);
		if (!g_aCommands.GetValue(command, value))
			return Plugin_Continue;
	}
	
	static char time[16];
	static char team[12];
	FormatTime(time, sizeof time, "%H:%M:%S", -1);
	GetTeamName(GetClientTeam(client), team, sizeof team);
	GetCmdArgString(g_sMsg, sizeof g_sMsg);
	StripQuotes(g_sMsg);

	LogTo("[%s] [%s] %N: %s %s", time, team, client, command, g_sMsg);
	return Plugin_Continue;
}

/**
 * Converts the given string to lower case
 *
 * @param szString     Input string for conversion and also the output
 * @return             void
 */
void StringToLowerCase(char[] szInput) {
	int iIterator;
	while (szInput[iIterator] != EOS) {
		szInput[iIterator] = CharToLower(szInput[iIterator]);
		++iIterator;
	}
}

public void OnMapEnd() {
	g_iRoundCount = 0;

	char time[32];
	FormatTime(time, sizeof time, "%d/%m/%Y %H:%M:%S", -1);

	LogTo("+-------------------------------------------+");
	LogTo("|                  地图结束                  |");
	LogTo("+-------------------------------------------+");
	LogTo("[%s] \"%s\"", time, g_sMap);
}

public void OnMapStart() {
	FormatTime(g_sMsg, sizeof g_sMsg, "%d%m%y", -1);
	BuildPath(Path_SM, g_sLogPath, sizeof g_sLogPath, "/logs/chat%s-%i.log", g_sMsg, g_cvHostport.IntValue);

	char time[32];
	GetCurrentMap(g_sMap, sizeof g_sMap);
	FormatTime(time, sizeof time, "%d/%m/%Y %H:%M:%S", -1);

	LogTo("+-------------------------------------------+");
	LogTo("|                  地图开始                  |");
	LogTo("+-------------------------------------------+");
	LogTo("[%s] \"%s\"", time, g_sMap);
}

public void OnClientPostAdminCheck(int client) {
	if (IsFakeClient(client))
		return;

	char ip[32];
	char time[16];
	char ccode[3];

	if (!GetClientIP(client, ip, sizeof ip, true)) 
		strcopy(ccode, sizeof ccode, "  ");
	else {
		if (!GeoipCode2(ip, ccode)) 
			strcopy(ccode, sizeof ccode, "  ");
	}

	FormatTime(time, sizeof time, "%H:%M:%S", -1);
	LogTo("[%s] [%s] %L 加入游戏 (%s)", time, ccode, client, ip);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	char time[32];
	FormatTime(time, sizeof time, "%d/%m/%Y %H:%M:%S", -1);
	LogTo("[%s] 第 %d 回合结束", time, g_iRoundCount);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	g_iRoundCount++;

	char time[32];
	FormatTime(time, sizeof time, "%d/%m/%Y %H:%M:%S", -1);
	LogTo("[%s] 第 %d 回合开始", time, g_iRoundCount);
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || IsFakeClient(client))
		return;

	char time[16];
	FormatTime(time, sizeof time, "%H:%M:%S", -1);
	event.GetString("reason", g_sMsg, sizeof g_sMsg);
	LogTo("[%s] %L 离开游戏 (reason: %s)", time, client, g_sMsg);
}

void LogTo(const char[] format, any ...) {
	static char buffer[512];
	VFormat(buffer, sizeof buffer, format, 2);

	File file = OpenFile(g_sLogPath, "a+");
	file.WriteLine("%s", buffer);
	file.Flush();
	delete file;
}
