/*
    Chat data logger
    By: Chdata

    Made to have similar options to Chat Logger++, and to suit my preferences for logging.
*/

#pragma semicolon 1
#include <sourcemod>

#define PLUGIN_VERSION          "0x01"

//#define TF_MAX_PLAYERS          34
#define MAX_SAY_LENGTH          130            // Input box [127] + '\0' [128] + "quotes" [130]
#define MAX_STEAMAUTH_LENGTH    21
#define FCVAR_VERSION           FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_CHEAT

#if !defined _colors_included
#define MAX_MESSAGE_LENGTH      256            //  This is based upon the SDK and the length of the entire message, including tags, name, : etc.
#endif

public Plugin:myinfo = {
    name = "Chat data logger",
    author = "Chdata",
    description = "Logs chat data",
    version = PLUGIN_VERSION,
    url = "http://steamcommunity.com/groups/tf2data"
};

static String:s_szChatDate[PLATFORM_MAX_PATH];

static String:s_szChatFile[MAXPLAYERS + 1][PLATFORM_MAX_PATH];  // Index 0 is used for a single file encompassing everyone's logs
static String:s_szCmdFile[MAXPLAYERS + 1][PLATFORM_MAX_PATH];   // Note: These strings should start out initialized
//static String:s_szComboFile[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

/*
    Convars

    Log preference:
    Log chat.
    Log cmd usage.
    Log all to single file.
    Log all to player specific files.
    Split chat + cmd logs.
*/

static Handle:s_hCvar[3] = {INVALID_HANDLE,...};

public OnPluginStart()
{
    CreateConVar("cv_chatdata_version", PLUGIN_VERSION, "Chat Data Version", FCVAR_VERSION);
    AddCommandListener(ChatMsg, "say");
    AddCommandListener(ChatMsg, "say_team");

    s_hCvar[0] = CreateConVar(
        "cv_chatdata_steam", "3",
        "0 = PEOPLE CAN TYPE IN FULL CAPS | 1 = Automagically lowercase other letters",
        FCVAR_NOTIFY,
        true, 2.0, true, 4.0
    );

    s_hCvar[1] = CreateConVar(
        "cv_chatdata_replacer", "_",
        "Invalid file name character replacer",
        FCVAR_NOTIFY
    );

    s_hCvar[2] = CreateConVar(
        "cv_chatdata_singlename", "1",
        "0 = Player specific filename changes as much as their username does | 1 = Uses first username they're logged with only [avoids redunduplicates]",
        FCVAR_NOTIFY,
        true, 0.0, true, 1.0
    );

    AutoExecConfig(true, "ch.chatdata");
}

public OnMapStart()
{
    FormatTime(s_szChatDate, sizeof(s_szChatDate), "%m-%d-%Y", GetTime());

    decl String:szBasePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szBasePath, sizeof(szBasePath), "logs/plyr/");
    CreateDirectory(szBasePath, 493);

    BuildPath(Path_SM, s_szChatFile[0], sizeof(s_szChatFile[]), "logs/chat-%s.log", s_szChatDate);
    BuildPath(Path_SM, s_szCmdFile[0], sizeof(s_szCmdFile[]), "logs/cmd-%s.log", s_szChatDate);

    static String:szCurrentmap[99];
    GetCurrentMap(szCurrentmap, sizeof(szCurrentmap));

    for (new i = 0; i <= MaxClients; i++)
    {
        if (i)
        {
            OnClientDisconnect(i);

            if (IsClientInGame(i))
            {
                OnClientPostAdminCheck(i);
            }
        }

        if (GetGameTime() <= 5.0) // Prevents late plugin loads from spamming the log with this
        {
            if (s_szChatFile[i][0] != '\0')
            {
                LogToFileEx(s_szChatFile[i], "-------- Mapchange to %s --------", szCurrentmap);
            }

            if (s_szCmdFile[i][0] != '\0')
            {
                LogToFileEx(s_szCmdFile[i], "-------- Mapchange to %s --------", szCurrentmap);
            }
        }
    }
}

public OnClientDisconnect(iClient)
{
    s_szChatFile[iClient][0] = '\0';
    s_szCmdFile[iClient][0] = '\0';
}

public OnClientPostAdminCheck(iClient)
{
    decl String:szAuthId[MAX_STEAMAUTH_LENGTH];
    GetClientAuthId(iClient, AuthIdType:(GetConVarInt(s_hCvar[0])-1), szAuthId, sizeof(szAuthId));

    decl String:szReplacer[2];
    GetConVarString(s_hCvar[1], szReplacer, sizeof(szReplacer));
    ReplaceString(szAuthId, sizeof(szAuthId), ":", "_");

    if (GetConVarBool(s_hCvar[2]))
    {
        decl FileType:iType;
        decl String:szDirectory[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, szDirectory, sizeof(szDirectory), "logs/plyr/");
        new Handle:hDir = OpenDirectory(szDirectory);
        if (hDir != INVALID_HANDLE)
        {
            while(ReadDirEntry(hDir, szDirectory, sizeof(szDirectory), iType))
            {
                switch (iType)
                {
                    case FileType_File:
                    {
                        if (StrContains(szDirectory, szAuthId) != -1)
                        {
                            if (StrContains(szDirectory, "-chat-") != -1)
                            {
                                strcopy(s_szChatFile[iClient], sizeof(s_szChatFile[]), szDirectory);
                            }
                            else if (StrContains(szDirectory, "-cmd-") != -1)
                            {
                                strcopy(s_szCmdFile[iClient], sizeof(s_szCmdFile[]), szDirectory);
                            }
                        }
                    }
                }
            }
            CloseHandle(hDir);
        }
    }

    if (s_szChatFile[iClient][0] == '\0')
    {
        BuildPath(Path_SM, s_szChatFile[iClient], sizeof(s_szChatFile[]), "logs/plyr/%s-%N-chat-%s.log", szAuthId, iClient, s_szChatDate);
    }

    if (s_szCmdFile[iClient][0] == '\0')
    {
        BuildPath(Path_SM, s_szCmdFile[iClient], sizeof(s_szCmdFile[]), "logs/plyr/%s-%N-cmd-%s.log", szAuthId, iClient, s_szChatDate);
    }
}

public Action:ChatMsg(iClient, const String:szCommand[], iArgc)
{
    decl String:szMessage[MAX_SAY_LENGTH];
    GetCmdArgString(szMessage, sizeof(szMessage));
    StripQuotes(szMessage);

    if (IsChatTrigger())
    {
        CmdLog(iClient, "%N(#%i): %s", iClient, GetClientUserId(iClient), szMessage);
    }
    else
    {
        ChatLog(iClient, "%N(#%i): %s", iClient, GetClientUserId(iClient), szMessage);
    }

    return Plugin_Continue;
}

ChatLog(iAuthor, const String:szMsg[], any:...)
{
    decl String:szOutput[MAX_MESSAGE_LENGTH];
    VFormat(szOutput, sizeof(szOutput), szMsg, 3);

    LogToFileEx(s_szChatFile[0], szOutput);
    LogToFileEx(s_szChatFile[iAuthor], szOutput);
}

CmdLog(iAuthor, const String:szMsg[], any:...)
{
    decl String:szOutput[MAX_MESSAGE_LENGTH];
    VFormat(szOutput, sizeof(szOutput), szMsg, 3);

    LogToFileEx(s_szCmdFile[0], szOutput);
    LogToFileEx(s_szCmdFile[iAuthor], szOutput);
}
