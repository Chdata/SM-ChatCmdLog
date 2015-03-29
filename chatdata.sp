/*
    Chat data logger
    By: Chdata

    Made to have similar options to Chat Logger++, and to suit my preferences for logging.
*/

#pragma semicolon 1
#include <sourcemod>

#define PLUGIN_VERSION          "0x01"

//#define TF_MAX_PLAYERS          34
#define FCVAR_VERSION           FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_CHEAT

public Plugin:myinfo = {
    name = "Chat data logger",
    author = "Chdata",
    description = "Logs chat data",
    version = PLUGIN_VERSION,
    url = "http://steamcommunity.com/groups/tf2data"
};

public OnPluginStart()
{
    RegConsoleCmd("sm_retry", Cmd_Reconnect);
    RegConsoleCmd("sm_rejoin", Cmd_Reconnect);
    RegConsoleCmd("sm_reconnect", Cmd_Reconnect);
    LoadTranslations("core.phrases");
    LoadTranslations("retry.phrases");
    CreateConVar("cv_retry_version", PLUGIN_VERSION, "Retry Version", FCVAR_VERSION);
}

