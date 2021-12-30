#pragma newdecls required

#define INCLUDE_RIPJSON
#define INCLUDE_MODULE_PACKAGER

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] Storage",
	author = "rej.chev?",
	description = "...",
	version = "1.0.1",
	url = "discord.gg/ChTyPUG"
};

JSONObject jConfig;
static const char pkgKey[] = "ccp_storage";

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{ 
    CreateNative("ccp_storage_WriteValue",  Native_Write);
    CreateNative("ccp_storage_ReadValue",   Native_Read);
    CreateNative("ccp_storage_RemoveValue", Native_Remove);

    RegPluginLibrary("ccp_storage");
    return APLRes_Success
}

public any Native_Write(Handle h, int a) {
    int iClient = GetNativeCell(1);

    if(!jConfig)
        return false;

    JSON storage;
    if(!(storage = getStorage(iClient))) {
        storage = new JSONObject();
        asJSONO(storage).SetInt("expired", (iClient) ? (GetTime() + jConfig.GetInt("duration")) : -1);
    }
    
    char key[PREFIX_LENGTH];
    GetNativeString(2, key, sizeof(key));

    JSON value = asJSON(GetNativeCell(3));

    asJSONO(storage).Set(key, value);
    storage.ToFile(getClientStoragePath(getAuth(iClient)), 0);

    delete storage;
    return 1;
}

public any Native_Read(Handle h, int a) {
    int iClient = GetNativeCell(1);

    JSON storage;
    if((storage = getStorage(iClient)) == null)
        return storage;
    
    char key[PREFIX_LENGTH];
    GetNativeString(2, key, sizeof(key));

    if(!asJSONO(storage).HasKey(key)) {
        delete storage;
        return storage;
    }

    JSON value;

    value = asJSONO(storage).Get(key);
    delete storage;

    return value;
}

public any Native_Remove(Handle h, int a) {
    int iClient = GetNativeCell(1);

    JSON storage;

    if((storage = getStorage(iClient)) == null)
        return false;
    
    char key[PREFIX_LENGTH];
    GetNativeString(2, key, sizeof(key));

    if(!asJSONO(storage).HasKey(key)) {
        delete storage;
        return false;
    }

    asJSONO(storage).Remove(key);
    storage.ToFile(getClientStoragePath(getAuth(iClient)), 0);
    delete storage;

    return true;
}

public void ccp_OnPackageAvailable(int iClient) {
    
    if(!iClient) {
        
        if(jConfig)
            delete jConfig;
        
        static char obj[MESSAGE_LENGTH]  = "configs/ccprocessor/storage/settings.json";

        if(obj[0] == 'c')
            BuildPath(Path_SM, obj, sizeof(obj), obj);
        
        if(!FileExists(obj))
            SetFailState("Config file is not exists: %s", obj);

        jConfig = JSONObject.FromFile(obj, 0);
        ccp_SetArtifact(iClient, pkgKey, jConfig, CALL_IGNORE);

        if((jConfig.GetFloat("cleanDelay")) != -1.0)
            CreateTimer((jConfig.GetFloat("cleanDelay")), CleanStoragePath, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }

    static char path[MESSAGE_LENGTH];
    path = getClientStoragePath(getAuth(iClient));

    JSON storage;
    if((storage = getStorage(iClient)) == null)
        return;

    asJSONO(storage).SetInt("expired", (iClient) ? (GetTime() + jConfig.GetInt("duration")) : -1);

    storage.ToFile(path, 0);
    delete storage;
}

public void ccp_OnPackageUpdate_Post(Handle ctx, any level) { 
    JSONObject strObject = asJSONO(ctx);
    if(strObject && strObject.HasKey(pkgKey))
        RequestFrame(OnNextFrame);
}

public void OnNextFrame() {
    if(jConfig)
        delete jConfig;

    if(ccp_HasArtifact(0, pkgKey))
        jConfig = asJSONO(ccp_GetArtifact(0, pkgKey));
}

stock char[] getAuth(int iClient) {
    JSONObject obj = asJSONO(ccp_GetPackage(iClient));

    char auth[PREFIX_LENGTH];
    obj.GetString("auth", auth, sizeof(auth));

    delete obj;
    return auth;
}

char[] getClientStoragePath(const char[] auth) {
    static char buffer[PLATFORM_MAX_PATH];
    strcopy(buffer, sizeof(buffer), auth);

    ReplaceString(buffer, sizeof(buffer), ":", "");
    ReplaceString(buffer, sizeof(buffer), "[", "");
    ReplaceString(buffer, sizeof(buffer), "]", "");

    Format(buffer, sizeof(buffer), "%s/%s.json", getLocation(), buffer);

    return buffer;
}

stock JSON getStorage(int iClient) {
    char path[MESSAGE_LENGTH];
    path = getClientStoragePath(getAuth(iClient));

    if(!FileExists(path))
        return null;

    return asJSON(JSONObject.FromFile(path, 0));
}

char[] getLocation() {
    static char location[PLATFORM_MAX_PATH] = "data/ccprocessor/storage";

    if(location[0] == 'd')
        BuildPath(Path_SM, location, sizeof(location), location);

    if(!DirExists(location))
        CreateDirectory(location, 0x1ED);

    return location;
}

Action CleanStoragePath(Handle hTimer, any data) {
    static DirectoryListing dirs;

    if(!dirs)
        if(!(dirs = OpenDirectory(getLocation())))
            return Plugin_Continue;
    
    static FileType type;
    static char path[PLATFORM_MAX_PATH];

    while(ReadDirEntry(dirs, path, sizeof(path), type)) {
        if(type != FileType_File || path[0] == '.')
            continue;

        Format(path, sizeof(path), "%s/%s", getLocation(), path);

        DeleteFile(path);
    }

    return Plugin_Continue;
}