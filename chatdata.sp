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

//MAX_NAME_LENGTH

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

    BuildPath(Path_SM, s_szChatFile[0], sizeof(s_szChatFile[]), "logs/chat-%s.log", s_szChatDate);
    BuildPath(Path_SM, s_szCmdFile[0], sizeof(s_szCmdFile[]), "logs/cmd-%s.log", s_szChatDate);

    decl String:szDatetime[32];
    FormatTime(szDatetime, sizeof(szDatetime), "L %x - %X: ", GetTime()); // %m/%d/%Y - %H:%M:%S:

    static String:szCurrentmap[99];
    GetCurrentMap(szCurrentmap, sizeof(szCurrentmap));
    
    for (new i = 0; i <= MaxClients; i++)
    {
        if (i == 0 || FileExists(s_szChatFile[i])) // I'm not sure how to do this so it doesn't log on late plugin loads
        {
            LogToFile(s_szChatFile[i], "%s-------- Mapchange to %s --------", szDatetime, szCurrentmap);
        }

        if (i == 0 || FileExists(s_szCmdFile[i]))
        {
            LogToFile(s_szCmdFile[i], "%s-------- Mapchange to %s --------", szDatetime, szCurrentmap);
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
    GetClientAuthId(iClient, AuthIdType:GetConVarInt(s_hCvar[0]), szAuthId, sizeof(szAuthId));

    decl String:szReplacer[2];
    GetConVarString(s_hCvar[1], szReplacer, sizeof(szReplacer));
    ReplaceString(szAuthId, sizeof(szAuthId), ":", szReplacer);

    if (GetConVarBool(s_hCvar[2]))
    {
        decl FileType:iType;
        decl String:szDirectory[PLATFORM_MAX_PATH], String:szFileId[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, szDirectory, sizeof(szDirectory), "logs/plyr/");
        new Handle:hDir = OpenDirectory(szDirectory);
        while(ReadDirEntry(hDir, szDirectory, sizeof(szDirectory), iType))
        {
            switch (iType)
            {
                case FileType_File:
                {
                    SplitString(szDirectory, "-", szFileId, sizeof(szFileId));
                    if (StrEqual(szAuthId, szFileId))
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
        CmdLog(iClient, "%s", szMessage);
    }
    else
    {
        ChatLog(iClient, "%s", szMessage);
    }

    return Plugin_Continue;
}

ChatLog(iAuthor, const String:szMsg[], any:...)
{
    decl String:szOutput[MAX_MESSAGE_LENGTH], String:szTemp[MAX_MESSAGE_LENGTH];
    VFormat(szTemp, sizeof(szTemp), szMsg, 2);

    decl String:szChatTime[PLATFORM_MAX_PATH];
    FormatTime(szChatTime, sizeof(szChatTime), "[%X]", GetTime());

    Format(szOutput, sizeof(szOutput), "%s %N(#%i): %s", szChatTime, iAuthor, GetClientUserId(iAuthor), szTemp);
    LogToFile(s_szChatFile[0], szOutput);
    LogToFile(s_szChatFile[iAuthor], szOutput);
}

CmdLog(iAuthor, const String:szMsg[], any:...)
{
    decl String:szOutput[MAX_MESSAGE_LENGTH], String:szTemp[MAX_MESSAGE_LENGTH];
    VFormat(szTemp, sizeof(szTemp), szMsg, 2);

    decl String:szChatTime[PLATFORM_MAX_PATH];
    FormatTime(szChatTime, sizeof(szChatTime), "[%X]", GetTime());

    Format(szOutput, sizeof(szOutput), "%s %N(#%i): %s", szChatTime, iAuthor, GetClientUserId(iAuthor), szTemp);
    LogToFile(s_szCmdFile[0], szOutput);
    LogToFile(s_szCmdFile[iAuthor], szOutput);
}

/*
    GetUserFlagBits(client)

#define AdminFlags_TOTAL    21

#define ADMFLAG_RESERVATION         (1<<0)      /< Convenience macro for Admin_Reservation as a FlagBit /
#define ADMFLAG_GENERIC             (1<<1)      /< Convenience macro for Admin_Generic as a FlagBit /
#define ADMFLAG_KICK                (1<<2)      /< Convenience macro for Admin_Kick as a FlagBit /
#define ADMFLAG_BAN                 (1<<3)      /< Convenience macro for Admin_Ban as a FlagBit /
#define ADMFLAG_UNBAN               (1<<4)      /< Convenience macro for Admin_Unban as a FlagBit /
#define ADMFLAG_SLAY                (1<<5)      /< Convenience macro for Admin_Slay as a FlagBit /
#define ADMFLAG_CHANGEMAP           (1<<6)      /< Convenience macro for Admin_Changemap as a FlagBit /
#define ADMFLAG_CONVARS             (1<<7)      /< Convenience macro for Admin_Convars as a FlagBit /
#define ADMFLAG_CONFIG              (1<<8)      /< Convenience macro for Admin_Config as a FlagBit /
#define ADMFLAG_CHAT                (1<<9)      /< Convenience macro for Admin_Chat as a FlagBit /
#define ADMFLAG_VOTE                (1<<10)     /< Convenience macro for Admin_Vote as a FlagBit /
#define ADMFLAG_PASSWORD            (1<<11)     /< Convenience macro for Admin_Password as a FlagBit /
#define ADMFLAG_RCON                (1<<12)     /< Convenience macro for Admin_RCON as a FlagBit /
#define ADMFLAG_CHEATS              (1<<13)     /< Convenience macro for Admin_Cheats as a FlagBit /
#define ADMFLAG_ROOT                (1<<14)     /< Convenience macro for Admin_Root as a FlagBit /
#define ADMFLAG_CUSTOM1             (1<<15)     /< Convenience macro for Admin_Custom1 as a FlagBit /
#define ADMFLAG_CUSTOM2             (1<<16)     /< Convenience macro for Admin_Custom2 as a FlagBit /
#define ADMFLAG_CUSTOM3             (1<<17)     /< Convenience macro for Admin_Custom3 as a FlagBit /
#define ADMFLAG_CUSTOM4             (1<<18)     /< Convenience macro for Admin_Custom4 as a FlagBit /
#define ADMFLAG_CUSTOM5             (1<<19)     /< Convenience macro for Admin_Custom5 as a FlagBit /
#define ADMFLAG_CUSTOM6             (1<<20)     /< Convenience macro for Admin_Custom6 as a FlagBit /
*/
