#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <ripext>
#include <base64>
#include <bzip2>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

#define PREFIX		"{default}[{orchid}SQLMatches.com{default}] "
#define TEAM_CT 	0
#define TEAM_T 		1

#define NAME 		"SQLMatches"
#define AUTHORS		"The Doggy, ErikMinekus, WardPearce"
#define DESC		"SQLMatches is a completely free & open source CS:GO match statistics & demo recording tool."
#define VERSION 	"1.1.0"
#define URL			"https://sqlmatches.com"

int g_iCompressionLevel = 9;
int g_iMinPlayersNeeded = 1;

bool g_bPugSetupAvailable;
bool g_bGet5Available;
bool g_bAlreadySwapped;

char g_sMatchId[38];
// If a matchIdBefore is given we'll upload it during the match.
char g_sMatchIdBefore[38];

ConVar g_cvApiUrl;
ConVar g_cvApiKey;
ConVar g_cvEnableAutoConfig;
ConVar g_cvEnableAnnounce;
ConVar g_cvStartRoundUpload;
ConVar g_cvDeleteAfterUpload;

HTTPClient g_Client;

enum struct MatchUpdatePlayer {
	int Index;
	char Username[42];
	char SteamID[64];
	int Team;
	bool Alive;
	int Ping;
	int Kills;
	int Headshots;
	int Assists;
	int Deaths;
	int ShotsFired;
	int ShotsHit;
	int MVPs;
	int Score;
	bool Disconnected;
}

MatchUpdatePlayer g_PlayerStats[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = NAME,
	author = AUTHORS,
	description = DESC,
	version = VERSION,
	url = URL
}

public void OnAllPluginsLoaded() {
	g_bPugSetupAvailable = LibraryExists("pugsetup");
	g_bGet5Available = LibraryExists("get5");
}

public void OnLibraryAdded(const char[] name) {
	if (StrEqual(name, "pugsetup")) g_bPugSetupAvailable = true;
	if (StrEqual(name, "get5")) g_bGet5Available = true;
}

public void OnLibraryRemoved(const char[] name) {
	if (StrEqual(name, "pugsetup")) g_bPugSetupAvailable = false;
	if (StrEqual(name, "get5")) g_bGet5Available = false;
}

void LoadCvarHttp() {
	char sApiKey[40];
	char sApiKeyUser[41];
	char sBase64ApiKey[150];
	char sBasicAuth[156];
	char sApiUrl[512];

	g_cvApiKey.GetString(sApiKey, sizeof(sApiKey));
	g_cvApiUrl.GetString(sApiUrl, sizeof(sApiUrl));

	if (strlen(sApiUrl) == 0) {
		LogError("Error: ConVar sm_sqlmatches_url shouldn't be empty.");
	}

	if (strlen(sApiKey) == 0) {
		LogError("Error: ConVar sm_sqlmatches_key shouldn't be empty.");
	}

	Format(sApiKeyUser, sizeof(sApiKeyUser), ":%s", sApiKey);
	EncodeBase64(sBase64ApiKey, sizeof(sBase64ApiKey), sApiKeyUser);
	Format(sBasicAuth, sizeof(sBasicAuth), "Basic %s", sBase64ApiKey);

	// Create HTTP Client
	g_Client = new HTTPClient(sApiUrl);

	g_Client.SetHeader("Content-Type", "application/json");
	g_Client.SetHeader("Authorization", sBasicAuth);

	g_Client.FollowLocation = true;
	g_Client.ConnectTimeout = 300;
	g_Client.Timeout = 600;
}

public void OnPluginStart() {
	//Hook Events
	HookEvent("round_start", Event_RoundStart);
	HookEvent("weapon_fire", Event_WeaponFired);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("announce_phase_end", Event_HalfTime);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("cs_win_panel_match", Event_MatchEnd);

	// Register ConVars
	g_cvApiKey = CreateConVar("sm_sqlmatches_key", "", "API key for sqlmatches API", FCVAR_PROTECTED);
	g_cvApiUrl = CreateConVar("sm_sqlmatches_url", "https://sqlmatches.com/api", "URL of sqlmatches base API route.", FCVAR_PROTECTED);
	g_cvEnableAutoConfig = CreateConVar("sm_sqlmatches_autoconfig", "1", "Used to auto config.", FCVAR_PROTECTED);
	g_cvEnableAnnounce = CreateConVar("sm_sqlmatches_announce", "1", "Show version announce", FCVAR_PROTECTED);
	g_cvStartRoundUpload = CreateConVar("sm_sqlmatches_start_round_upload", "0", "0 = Upload demo at match end / 1 = Upload demo at start of next match.", FCVAR_PROTECTED);
	g_cvDeleteAfterUpload = CreateConVar("sm_sqlmatches_delete_after_upload", "1", "Delete demo file locally after upload.", FCVAR_PROTECTED);

	g_cvApiUrl.AddChangeHook(OnAPIChanged);
	g_cvApiKey.AddChangeHook(OnAPIChanged);

	AutoExecConfig(true, "sqlmatches");

	LoadCvarHttp();
}

public void OnMapStart() {
	if (!StrEqual(g_sMatchId, "")) {
		// Format request
		char sUrl[1024];
		Format(sUrl, sizeof(sUrl), "match/%s/", g_sMatchId);

		// Send request
		g_Client.Delete(sUrl, HTTP_OnEndMatch);
	}

	if (g_cvStartRoundUpload.IntValue == 1 && !StrEqual(g_sMatchIdBefore, "")) {
		UploadDemo(g_sMatchIdBefore);
	}

	if (g_cvEnableAutoConfig.IntValue == 1) {
		ServerCommand("tv_enable 1");
		ServerCommand("tv_autorecord 0");
		ServerCommand("sv_hibernate_when_empty 0");
		if (g_cvStartRoundUpload.IntValue == 0) {
			ServerCommand("mp_endmatch_votenextmap 20");
		}
	}

	if (g_cvEnableAnnounce.IntValue == 1) {
		char versions[3][20];
		ExplodeString(VERSION, ".", versions, sizeof(versions), sizeof(versions[]));

		char sUrl[1024];
		Format(sUrl, sizeof(sUrl), "version/%s/%s/%s/", versions[0], versions[1], versions[2]);

		g_Client.Get(sUrl, HTTP_OnMapLoad);
	}
}

void HTTP_OnMapLoad(HTTPResponse response, any value, const char[] error) {
	if (strlen(error) > 0) {
		LogError("HTTP_OnMapLoad - Error string - Failed! Error: %s", error);
		return;
	}

	if (response.Data == null) {
		// Invalid JSON response
		return;
	}

	// Get response data
	JSONObject responseData = view_as<JSONObject>(response.Data);

	// Log errors if any occurred
	if (response.Status != HTTPStatus_OK) {
		// Error string
		char errorInfo[1024];
		responseData.GetString("error", errorInfo, sizeof(errorInfo));
		LogError("HTTP_OnMapLoad - Invalid status code - Failed! Error: %s", errorInfo);
		return;
	}

	JSONObject data = view_as<JSONObject>(responseData.Get("data"));

	char sVersionMessage[66];
	data.GetString("message", sVersionMessage, sizeof(sVersionMessage));

	CreateTimer(15.0, Timer_PrintVersionMessage, sVersionMessage)
}

public Action Timer_PrintVersionMessage(Handle timer, const char[] sVersionMessage) {
	CPrintToChatAll("%s{lightred}%s", PREFIX, sVersionMessage);
}

void HTTP_OnEndMatch(HTTPResponse response, any value, const char[] error) {
	if (strlen(error) > 0) {
		LogError("HTTP_OnEndMatch - Error string - Failed! Error: %s", error);
		return;
	}

	// Get response data
	JSONObject responseData = view_as<JSONObject>(response.Data);

	// Log errors if any occurred
	if (response.Status != HTTPStatus_OK) {
		// Error string
		char errorInfo[1024];
		responseData.GetString("error", errorInfo, sizeof(errorInfo));
		LogError("HTTP_OnEndMatch - Invalid status code - Failed! Error: %s", errorInfo);
		return;
	}

	g_sMatchId = "";
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (InMatch()) {
		UpdateMatch();
	} else if (!InWarmup()) {
		CreateMatch();
	}
}

public void OnAPIChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	LoadCvarHttp();
}

public void OnConfigsExecuted() {
	LoadCvarHttp();
}

public void OnClientPutInServer(int Client) {
	ResetVars(Client);
	g_PlayerStats[Client].Index = Client;
}

void ResetVars(int Client) {
	g_PlayerStats[Client].Index = 0;
	g_PlayerStats[Client].Username = "";
	g_PlayerStats[Client].SteamID = "";
	g_PlayerStats[Client].Team = 0;
	g_PlayerStats[Client].Alive = false;
	g_PlayerStats[Client].Ping = 0;
	g_PlayerStats[Client].Kills = 0;
	g_PlayerStats[Client].Headshots = 0;
	g_PlayerStats[Client].Assists = 0;
	g_PlayerStats[Client].Deaths = 0;
	g_PlayerStats[Client].ShotsFired = 0;
	g_PlayerStats[Client].ShotsHit = 0;
	g_PlayerStats[Client].MVPs = 0;
	g_PlayerStats[Client].Score = 0;
	g_PlayerStats[Client].Disconnected = false;
}

void CreateMatch() {
	if (InMatch()) return;

	int realClientCount = GetRealClientCount();
	if (realClientCount < g_iMinPlayersNeeded) {
		CPrintToChatAll("%s{red}%i{default} more player(s) needed in order for the match to start recording.", PREFIX, g_iMinPlayersNeeded - realClientCount);
		return;
	}

	// Setup JSON data
	char sTeamNameCT[64];
	char sTeamNameT[64];
	char sMap[24];
	JSONObject json = new JSONObject();

	// Set names if pugsetup or get5 are available
	if (g_bGet5Available || g_bPugSetupAvailable) {
		FindConVar("mp_teamname_1").GetString(sTeamNameCT, sizeof(sTeamNameCT));
		FindConVar("mp_teamname_2").GetString(sTeamNameT, sizeof(sTeamNameT));
	} else {
		GetTeamName(CS_TEAM_CT, sTeamNameCT, sizeof(sTeamNameCT));
		GetTeamName(CS_TEAM_T, sTeamNameT, sizeof(sTeamNameT));
	}

	json.SetString("team_1_name", sTeamNameCT);
	json.SetString("team_2_name", sTeamNameT);

	// Set team sides
	json.SetInt("team_1_side", 0);
	json.SetInt("team_2_side", 1);

	// Set team score
	json.SetInt("team_1_score", 0);
	json.SetInt("team_2_score", 0);

	// Set map
	GetCurrentMap(sMap, sizeof(sMap));
	json.SetString("map_name", sMap);

	// Send request
	g_Client.Post("match/create/", json, HTTP_OnCreateMatch);

	// Delete handle
	delete json;
}

void HTTP_OnCreateMatch(HTTPResponse response, any value, const char[] error) {
	if (strlen(error) > 0) {
		LogError("HTTP_OnCreateMatch - Error string - Failed! Error: %s", error);
		return;
	}

	if (response.Data == null) {
		// Invalid JSON response
		return;
	}

	// Get response data
	JSONObject responseData = view_as<JSONObject>(response.Data);

	// Log errors if any occurred
	if (response.Status != HTTPStatus_OK) {
		char errorInfo[1024];
		responseData.GetString("error", errorInfo, sizeof(errorInfo));
		LogError("HTTP_OnCreateMatch - Invalid status code - Failed! Error: %s", errorInfo);
		return;
	}

	// Match waas created successfully, store match id and restart game
	JSONObject data = view_as<JSONObject>(responseData.Get("data"));
	data.GetString("match_id", g_sMatchId, sizeof(g_sMatchId));
	PrintToServer("%s Match %s created successfully.", PREFIX, g_sMatchId);
	CPrintToChatAll("%sMatch has been {green}created", PREFIX);
	ServerCommand("tv_record \"%s\"", g_sMatchId);
}

void UpdateMatch(int team_1_score = -1, int team_2_score = -1, bool dontUpdate = false, int team_1_side = -1, int team_2_side = -1, bool end = false) {
	if (!InMatch() && end == false) return;

	// Set scores if not passed in manually
	if (team_1_score == -1) {
		team_1_score = CS_GetTeamScore(CS_TEAM_CT);
	}

	if (team_2_score == -1) {
		team_2_score = CS_GetTeamScore(CS_TEAM_T);
	}

	// Create and set json data
	JSONObject json = new JSONObject();
	json.SetInt("team_1_score", team_1_score);
	json.SetInt("team_2_score", team_2_score);
	json.SetBool("end", end);

	// Format and set players data
	if (!dontUpdate) {
		UpdatePlayerStats(g_PlayerStats, sizeof(g_PlayerStats));

		JSONArray playersArray = GetPlayersJson(g_PlayerStats, sizeof(g_PlayerStats));
		json.Set("players", playersArray);
		delete playersArray;
	}

	// Set optional data
	if (team_1_side != -1) {
		json.SetInt("team_1_side", team_1_side);
	}
	if (team_2_side != -1) {
		json.SetInt("team_2_side", team_2_side);
	}

	// Format request
	char sUrl[1024];
	Format(sUrl, sizeof(sUrl), "match/%s/", g_sMatchId);

	// Send request
	g_Client.Post(sUrl, json, HTTP_OnUpdateMatch);
	delete json;
}

void HTTP_OnUpdateMatch(HTTPResponse response, any value, const char[] error) {
	if (strlen(error) > 0) {
		LogError("HTTP_OnUpdateMatch - Error string - Failed! Error: %s", error);
		return;
	}

	// Get response data
	JSONObject responseData = view_as<JSONObject>(response.Data);

	// Log errors if any occurred
	if (response.Status != HTTPStatus_OK) {
		// Error string
		char errorInfo[1024];
		responseData.GetString("error", errorInfo, sizeof(errorInfo));
		LogError("HTTP_OnUpdateMatch - Invalid status code - Failed! Error: %s", errorInfo);
		return;
	}

	CPrintToChatAll("%sMatch updated {green}successfully.", PREFIX);
}

void UploadDemo(const char[] matchId) {
	char demoPathway[PLATFORM_MAX_PATH];
	Format(demoPathway, sizeof(demoPathway), "%s.dem", matchId);
	if (!FileExists(demoPathway)) {
		LogError("Failed to upload demo. Error: File \"%s\" does not exist.", demoPathway);
		return;
	}

	DataPack data = new DataPack();
	data.WriteString(matchId);

	char bzipDemoPathway[PLATFORM_MAX_PATH];
	Format(bzipDemoPathway, sizeof(bzipDemoPathway), "%s.bz2", demoPathway);
	BZ2_CompressFile(demoPathway, bzipDemoPathway, g_iCompressionLevel, CompressedDemo, data);
}

void CompressedDemo(BZ_Error iError, const char[] sIn, const char[] sOut, DataPack data) {
	if (iError != BZ_OK) {
		LogBZ2Error(iError);
		return;
	}

	CPrintToChatAll("%sUploading compressed demo...", PREFIX);

	char matchId[38];
	data.Reset();
	data.ReadString(matchId, sizeof(matchId));

	// Format request
	char sUrl[1024];
	Format(sUrl, sizeof(sUrl), "match/%s/upload/", matchId);

	// Send request
	g_Client.UploadFile(sUrl, sOut, HTTP_OnUploadDemo, data);
}

void HTTP_OnUploadDemo(HTTPStatus status, DataPack pack, const char[] error) {
	if (strlen(error) > 0 || status != HTTPStatus_OK) {
		LogError("HTTP_OnUploadDemo Failed! Error: %s", error);
		return;
	}

	char matchId[38];
	pack.Reset();
	pack.ReadString(matchId, sizeof(matchId));

	char demoPathway[PLATFORM_MAX_PATH];
	Format(demoPathway, sizeof(demoPathway), "%s.dem", matchId);

	char bzipDemoPathway[PLATFORM_MAX_PATH];
	Format(bzipDemoPathway, sizeof(bzipDemoPathway), "%s.bz2", demoPathway);

	DeleteFile(bzipDemoPathway);

	if (g_cvDeleteAfterUpload.IntValue == 1) {
		DeleteFile(demoPathway);
	}

	CPrintToChatAll("%sDemo uploaded {green}successfully{default}.", PREFIX);
}

public void Event_WeaponFired(Event event, const char[] name, bool dontBroadcast) {
	int Client = GetClientOfUserId(event.GetInt("userid"));
	if (!InMatch() || !IsValidClient(Client)) return;

	int iWeapon = GetEntPropEnt(Client, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(iWeapon)) return;

	if (GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType") != -1 && GetEntProp(iWeapon, Prop_Send, "m_iClip1") != 255) g_PlayerStats[Client].ShotsFired++; //should filter knife and grenades
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	int Client = GetClientOfUserId(event.GetInt("attacker"));
	if (!InMatch() || !IsValidClient(Client)) return;

	if (event.GetInt("hitgroup") >= 0) {
		g_PlayerStats[Client].ShotsHit++;
		if(event.GetInt("hitgroup") == 1) g_PlayerStats[Client].Headshots++;
	}
}

public void Event_HalfTime(Event event, const char[] name, bool dontBroadcast) {
	if (!InMatch()) return;

	if (!g_bAlreadySwapped) {
		LogMessage("Event_HalfTime(): Starting team swap...");

		UpdateMatch(.team_1_side = 1, .team_2_side = 0, .dontUpdate = false);

		g_bAlreadySwapped = true;
	} else {
		LogError("Event_HalfTime(): Teams have already been swapped!");
	}
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	if (!InMatch()) return Plugin_Continue;

	// If the client isn't valid or isn't currently in a match return
	int Client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(Client)) return Plugin_Handled;

	// If the client's steamid isn't valid return
	char sSteamID[64];
	event.GetString("networkid", sSteamID, sizeof(sSteamID));
	if (sSteamID[7] != ':') return Plugin_Handled;
	if (!GetClientAuthId(Client, AuthId_SteamID64, sSteamID, sizeof(sSteamID))) return Plugin_Handled;

	UpdateMatch();

	// Reset client vars
	ResetVars(Client);

	return Plugin_Continue;
}

public Action Event_MatchEnd(Event event, const char[] name, bool dontBroadcast) {
	if (!InMatch()) return;

	UpdateMatch(.end = true);
	if (g_cvStartRoundUpload.IntValue == 0) {
		if(FindConVar("tv_enable").IntValue == 1) {
			UploadDemo(g_sMatchId);
		}
	} else {
		g_sMatchIdBefore = g_sMatchId;
	}

	g_sMatchId = "";
}

stock bool InWarmup() {
  return GameRules_GetProp("m_bWarmupPeriod") != 0;
}

stock bool InMatch() {
	return !StrEqual(g_sMatchId, "") && !InWarmup();
}

stock void UpdatePlayerStats(MatchUpdatePlayer[] players, int size) {
	int ent = FindEntityByClassname(-1, "cs_player_manager");

	// Iterate over players array and update values for every client
	for (int i = 0; i < size; i++) {
		int Client = players[i].Index;
		if (!IsValidClient(Client)) continue;

		if (GetClientTeam(Client) == CS_TEAM_CT) {
			players[Client].Team = 0;
		} else if(GetClientTeam(Client) == CS_TEAM_T) {
			players[Client].Team = 1;
		}

		players[Client].Alive = view_as<bool>(GetEntProp(ent, Prop_Send, "m_bAlive", _, Client));
		players[Client].Ping = GetEntProp(ent, Prop_Send, "m_iPing", _, Client);
		players[Client].Kills = GetEntProp(ent, Prop_Send, "m_iKills", _, Client);
		players[Client].Assists = GetEntProp(ent, Prop_Send, "m_iAssists", _, Client);
		players[Client].Deaths = GetEntProp(ent, Prop_Send, "m_iDeaths", _, Client);
		players[Client].MVPs = GetEntProp(ent, Prop_Send, "m_iMVPs", _, Client);
		players[Client].Score = GetEntProp(ent, Prop_Send, "m_iScore", _, Client);

		GetClientName(Client, players[Client].Username, sizeof(MatchUpdatePlayer::Username));
		GetClientAuthId(Client, AuthId_SteamID64, players[Client].SteamID, sizeof(MatchUpdatePlayer::SteamID));
	}
}

stock JSONArray GetPlayersJson(const MatchUpdatePlayer[] players, int size) {
	JSONArray json = new JSONArray();

	for(int i = 0; i < size; i++) {
		if(!IsValidClient(players[i].Index)) continue;
		JSONObject player = new JSONObject();

		player.SetString("name", players[i].Username);
		player.SetString("steam_id", players[i].SteamID);
		player.SetInt("team", players[i].Team);
		player.SetBool("alive", players[i].Alive);
		player.SetInt("ping", players[i].Ping);
		player.SetInt("kills", players[i].Kills);
		player.SetInt("headshots", players[i].Headshots);
		player.SetInt("assists", players[i].Assists);
		player.SetInt("deaths", players[i].Deaths);
		player.SetInt("shots_fired", players[i].ShotsFired);
		player.SetInt("shots_hit", players[i].ShotsHit);
		player.SetInt("mvps", players[i].MVPs);
		player.SetInt("score", players[i].Score);
		player.SetBool("disconnected", IsClientInGame(players[i].Index));

		json.Push(player);
		delete player;
	}

	return json;
}

stock bool IsValidClient(int client) {
	if (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) &&
		!IsFakeClient(client) && (GetClientTeam(client) == CS_TEAM_CT || GetClientTeam(client) == CS_TEAM_T)) {
		return true;
	}

	return false;
}

stock int GetRealClientCount() {
    int iClients = 0;

    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i)) {
            iClients++;
        }
    }

    return iClients;
}
