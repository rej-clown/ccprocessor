#pragma newdecls required

#include <ccprocessor>

#define MAX_PARAMS 4

#define SZ(%0) %0, sizeof(%0)

public Plugin myinfo = 
{
    name        = "[CCP] SayText2 handler",
    author      = "nyood",
    description = "...",
    version     = "1.0.3",
    url         = "discord.gg/ChTyPUG"
};

UserMessageType umType;

ArrayList g_aThread;

static const char indent_def[][] = {"STP", "STA", "CN"};
static const char templates[][] = {"#Game_Chat_Team", "#Game_Chat_Public", "#Game_Chat_CUsername"};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{    
    umType = GetUserMessageType();
    HookUserMessage(GetUserMessageId("SayText2"), UserMessage_SayText2, true, SayText2_Completed);

    return APLRes_Success;
}

public void OnPluginStart() {
    g_aThread = new ArrayList(36, 0);
}

public Action UserMessage_SayText2(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
    StringMap mMap = ReadUserMessage(msg);
    if(!mMap) {
        return Plugin_Handled;
    }

    // PrintToConsoleAll("Recipient: %d | %N", playersNum, players[0]);

    int sender;
    mMap.GetValue("ent_idx", sender);

    mMap.SetValue("recipient", players[0]);

    int chatType;
    mMap.GetValue("chatType", chatType);

    char szName[NAME_LENGTH];
    mMap.GetString("params[0]", szName, sizeof(szName));

    char szMessage[MESSAGE_LENGTH];
    mMap.GetString("params[1]", szMessage, sizeof(szMessage));
    
    ccp_replaceColors(szName, true);
    mMap.SetString("params[0]", szName, true);

    if(!ccp_SkipColors(indent_def[chatType], sender)) {
        ccp_replaceColors(szMessage, true);
        mMap.SetString("params[1]", szMessage, true);
    }
    
    // PrintToConsoleAll("Map: %x", mMap);
    g_aThread.Push(mMap);
    return Plugin_Handled;
}

public void SayText2_Completed(UserMsg msgid, bool send)
{
    if(!send || !g_aThread.Length) {
        return;
    }

    StringMap mMessage;
    mMessage = view_as<StringMap>(g_aThread.Get(0));
    g_aThread.Erase(0);

    if(!mMessage) {
        return;
    }

    int sender;
    mMessage.GetValue("ent_idx", sender);

    int recipient;
    mMessage.GetValue("recipient", recipient);
    
    char 
        params[MAX_PARAMS][MESSAGE_LENGTH], 
        szBuffer[MAX_LENGTH];

    for(int i; i < MAX_PARAMS; i++) {
        FormatEx(szBuffer, sizeof(szBuffer), "params[%i]", i);
        mMessage.GetString(szBuffer, params[i], sizeof(params[]));
    }

    int chatType;
    mMessage.GetValue("chatType", chatType);

    delete mMessage;

    if(!IsClientConnected(recipient)) {
        return;
    }

    int team;
    team = (sender) ? GetClientTeam(sender) : 1;

    bool alive;
    alive = (sender) ? IsPlayerAlive(sender) : false;

    ArrayList arr = new ArrayList(MAX_LENGTH, 0);

    char szIndent[NAME_LENGTH];
    strcopy(SZ(szIndent), indent_def[chatType]);

    int id;
    if((id = stock_NewMessage(arr, sender, recipient, templates[chatType], params[1], SZ(szIndent))) == -1)
    {
        delete arr;
        return;
    }

    if(!szIndent[0]) {
        stock_EndMsg(arr, id, sender, indent_def[chatType]);
        delete arr;
        return;
    }

    ccp_ChangeMode(recipient, "0");

    szBuffer = NULL_STRING;

    int j = (sender << 3|team << 1|view_as<int>(alive));

    if(stock_RebuildMsg(arr, id, j, recipient, szIndent, templates[chatType], params[0], params[1], szBuffer) <= Proc_Change) {
        // Rendering the final result 
        stock_RenderEngineCtx(arr, sender, recipient, MAX_PARAMS, SZ(szBuffer));
        ccp_replaceColors(szBuffer, false);

        Handle uMessage;
        if((uMessage = StartMessageOne("SayText2", recipient, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS)) != null) {
            j = 0;
            if(!umType) {
                BfWriteByte(uMessage, sender);
                BfWriteByte(uMessage, true);
                BfWriteString(uMessage, szBuffer);
                while(j < MAX_PARAMS) {
                    BfWriteString(uMessage, params[j++]);
                }
            } else {
                PbSetInt(uMessage, "ent_idx", sender);
                PbSetBool(uMessage, "chat", true);
                PbSetString(uMessage, "msg_name", szBuffer);
                while(j < MAX_PARAMS) {
                    PbAddString(uMessage, "params", params[j++]);
                }
            }
            
            EndMessage();
        }
    }

    ccp_ChangeMode(recipient); 
    stock_EndMsg(arr, id, sender, szIndent);

    delete arr;
}

StringMap ReadUserMessage(Handle msg) {
    StringMap params = new StringMap();

    int sender = (!umType) 
                    ? BfReadByte(msg) 
                    : PbReadInt(msg, "ent_idx");
    params.SetValue("ent_idx", sender);

    char szMsgName[MESSAGE_LENGTH];
    if(!umType) {
        BfReadString(msg, szMsgName, sizeof(szMsgName));
    } else {
        PbReadString(msg, "msg_name", szMsgName, sizeof(szMsgName));
    }

    // params.SetString("msg_name", szMsgName, true);
    params.SetValue("chatType", 
        (StrContains(szMsgName, "_Name_Change", false) != -1) 
            ? 2
            : (StrContains(szMsgName, "_All", false) != -1) 
                ? 1 
                : 0, 
        true
    );

    char szParams[MAX_PARAMS][MESSAGE_LENGTH];
    int i;

    while(((!umType) ? BfGetNumBytesLeft(msg) > 1 : i < PbGetRepeatedFieldCount(msg, "params")) && i < MAX_PARAMS) {
        if(!umType) BfReadString(msg, szParams[i], sizeof(szParams[]));
        else PbReadString(msg, "params", szParams[i], sizeof(szParams[]), i);

        FormatEx(szMsgName, sizeof(szMsgName), "params[%i]", i);
        params.SetString(szMsgName, szParams[i], true);

        i++;
    }

    return params;
}