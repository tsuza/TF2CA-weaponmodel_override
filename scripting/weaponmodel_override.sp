#include <sourcemod>

#include <tf2>
#include <tf2_stocks>
#include <tf2wearables>
#include <tf_econ_data>
#include <tf_custom_attributes>

#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME         "[CA] Weapon Model Override"
#define PLUGIN_AUTHOR       "Zabaniya001"
#define PLUGIN_DESCRIPTION  "Custom Attribute that utilizes Nosoop's framework. This plugin lets you have a custom weapon model ( both worldmodel and viewmodel )."
#define PLUGIN_VERSION      "1.0.0"
#define PLUGIN_URL          "https://alliedmods.net"

public Plugin myinfo = {
    name        =   PLUGIN_NAME,
    author      =   PLUGIN_AUTHOR,
    description =   PLUGIN_DESCRIPTION,
    version     =   PLUGIN_VERSION,
    url         =   PLUGIN_URL
}

#define MAX_TF2_PLAYERS 36
#define MAX_ENTITY_LIMIT 2049

// ||──────────────────────────────────────────────────────────────────────────||
// ||                              GLOBAL VARIABLES                            ||
// ||──────────────────────────────────────────────────────────────────────────||

enum struct WeaponModels
{
    int m_iWorldModel;  // Should probably make 'em
    int m_iViewModel;   // into entrefs to avoid any unecessary fuss

    bool m_bHasCustomModel;

    char m_sWeaponModel[PLATFORM_MAX_PATH];

    void SetModel(char[] sModel)
    {
        strcopy(this.m_sWeaponModel, PLATFORM_MAX_PATH, sModel);

        this.m_bHasCustomModel = true;

        return;
    }

    bool HasModel()
    {
        if(!this.m_bHasCustomModel || StrEqual(this.m_sWeaponModel, ""))
            return false;

        return true;
    }

    void ClearModel(int iClient)
    {
        if(!this.m_bHasCustomModel) // We takin' home those performance optimizations.
            return;

        if(this.m_iWorldModel > 0 && this.m_iWorldModel < 2048 && IsValidEntity(this.m_iWorldModel))
        {   
            TF2_RemoveWearable(iClient, this.m_iWorldModel);
            RemoveEntity(this.m_iWorldModel);
        }

        if(this.m_iViewModel > 0 && this.m_iViewModel < 2048 && IsValidEntity(this.m_iViewModel))
        {   
            TF2_RemoveWearable(iClient, this.m_iViewModel);
            RemoveEntity(this.m_iViewModel);
        }

        return;
    }

    void Destroy()
    {
        if(!this.m_bHasCustomModel)
            return;

        strcopy(this.m_sWeaponModel, PLATFORM_MAX_PATH, "");

        if(this.m_iWorldModel > 0 && this.m_iWorldModel < 2048 && IsValidEntity(this.m_iWorldModel))
            RemoveEntity(this.m_iWorldModel);

        if(this.m_iViewModel > 0 && this.m_iViewModel < 2048 && IsValidEntity(this.m_iViewModel))
            RemoveEntity(this.m_iViewModel);

        this.m_iWorldModel      =   0;
        this.m_iViewModel       =   0;
        this.m_bHasCustomModel  =   false;

        return;
    }
}

WeaponModels g_hWeaponModels[MAX_ENTITY_LIMIT + 1];

Handle g_hSdkEquipWearable;

// ||──────────────────────────────────────────────────────────────────────────||
// ||                               SOURCEMOD API                              ||
// ||──────────────────────────────────────────────────────────────────────────||

public void OnPluginStart()
{
    GameData config = new GameData("tf2.customweaponskins");

    if(!config)
        SetFailState("Failed to get gamedata: tf2.customweaponskins");

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CTFPlayer::EquipWearable");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    g_hSdkEquipWearable = EndPrepSDKCall();

    delete config;

    HookEvent("post_inventory_application", Event_InventoryApplicationPost);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

    // In case of late-load
    for(int client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client))
            OnClientPutInServer(client);
    }

    return;
}

public void OnClientPutInServer(int iClient)
{
    SDKHook(iClient, SDKHook_WeaponSwitchPost,  OnWeaponSwitchPost);
    SDKHook(iClient, SDKHook_WeaponEquipPost,   OnWeaponEquipPost);

    return;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                                EVENTS                                    ||
// ||──────────────────────────────────────────────────────────────────────────||

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
    if(!StrEqual(sClassname, "tf_dropped_weapon"))  // When a weapon gets dropped, it gets deleted and another entity with the same properties (atts etc..) gets created.
        return;

    SDKHook(iEntity, SDKHook_Spawn, OnEntitySpawn);

    return;
}

public void OnEntitySpawn(int iEntity)
{
    char sModelName[PLATFORM_MAX_PATH];
    if(!TF2CustAttr_GetString(iEntity, "weaponmodel override", sModelName, sizeof(sModelName)))
        return;

    SetEntityModel(iEntity, sModelName); // Changing the dropped weapon's model

    return;
}

public void OnEntityDestroyed(int iEntity)
{
    if(iEntity < 1 || iEntity > 2048)
        return;

    g_hWeaponModels[iEntity].Destroy();

    return;
}

public void OnWeaponSwitchPost(int iClient, int iWeapon)
{
    static int iLastWeapon[MAX_TF2_PLAYERS] = {0, ...};

    if(!IsValidEntity(iWeapon))
        return;

    if(iLastWeapon[iClient] == iWeapon)
        return;

    g_hWeaponModels[iLastWeapon[iClient]].ClearModel(iClient);

    iLastWeapon[iClient] = iWeapon;

    float fHolsterTime = 0.0;

    if(GetEntPropFloat(iClient, Prop_Send, "m_flHolsterAnimTime") > 0.0)
        fHolsterTime = 0.8;

    if(!g_hWeaponModels[iWeapon].HasModel())
        return;

    DataPack hPack = new DataPack();
    hPack.WriteCell(EntIndexToEntRef(iClient));
    hPack.WriteCell(EntIndexToEntRef(iWeapon));

    if(fHolsterTime == 0.0)
        RequestFrame(Frame_OnDrawWeapon, hPack);
    else
        CreateTimer(fHolsterTime, Timer_OnDrawWeapon, hPack);

    return;
}

public void OnWeaponEquipPost(int iClient, int iWeapon)
{
    char sModelName[PLATFORM_MAX_PATH];
    if(!TF2CustAttr_GetString(iWeapon, "weaponmodel override", sModelName, sizeof(sModelName)))
        return;

    g_hWeaponModels[iWeapon].SetModel(sModelName);

    DataPack hPack = new DataPack();
    hPack.WriteCell(EntIndexToEntRef(iClient));
    hPack.WriteCell(EntIndexToEntRef(iWeapon));

    RequestFrame(Frame_OnDrawWeapon, hPack);

    return;
}

public void Event_InventoryApplicationPost(Event event, const char[] name, bool dontBroadcast)
{
    int iClient                 =   GetClientOfUserId((event.GetInt("userid")));
    int iWeaponInCurrentSlot    =   0;

    for(eTF2LoadoutSlot iSlot = TF2LoadoutSlot_Primary; iSlot < TF2LoadoutSlot_PDA2; iSlot++)
    {
        iWeaponInCurrentSlot = TF2_GetPlayerLoadoutSlot(iClient, iSlot);

        if(!IsValidEntity(iWeaponInCurrentSlot))
            continue;

        char sModelName[PLATFORM_MAX_PATH];
        if(!TF2CustAttr_GetString(iWeaponInCurrentSlot, "weaponmodel override", sModelName, sizeof(sModelName)))
            continue;

        if(StrEqual(sModelName, ""))
            continue;

        int item_slot = TF2Econ_GetItemLoadoutSlot(iWeaponInCurrentSlot, TF2_GetPlayerClass(iClient));

        // Removing all wearables that take up the same slot as this weapon.

        int iEntity;
        while((iEntity = FindEntityByClassname(iEntity, "tf_wearable*")) != -1)
        {
            if(iEntity == iWeaponInCurrentSlot)
                continue;

            if(GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") != iClient) 
                continue;

            int idx = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
            int iSlotTwo = TF2Econ_GetItemLoadoutSlot(idx, TF2_GetPlayerClass(iClient));

            if (iSlotTwo == item_slot)
            {
                TF2_RemoveWearable(iClient, iEntity);
                RemoveEntity(iEntity);
            }
        }

        g_hWeaponModels[iWeaponInCurrentSlot].SetModel(sModelName);

        // Secret <3
    }

    int iActiveWeapon = TF2_GetActiveWeapon(iClient);

    DataPack hPack = new DataPack();
    hPack.WriteCell(EntIndexToEntRef(iClient));
    hPack.WriteCell(EntIndexToEntRef(iActiveWeapon));

    RequestFrame(Frame_OnDrawWeapon, hPack);

    return;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int iClient = GetClientOfUserId(event.GetInt("userid"));
    int iWeapon = TF2_GetActiveWeapon(iClient);

    OnDrawWeapon(iClient, iWeapon);

    return;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int iClient = GetClientOfUserId(event.GetInt("userid"));
    int iWeapon = TF2_GetActiveWeapon(iClient);

    g_hWeaponModels[iWeapon].ClearModel(iClient);

    return Plugin_Continue;
}

// Checking if the client is taunting so we can add / remove the weapon model so it doesn't look weird.

public void TF2_OnConditionAdded(int iClient, TFCond cond)
{
    if(cond != TFCond_Taunting)
        return;

    int iWeapon = TF2_GetActiveWeapon(iClient);

    int iTaunt = GetEntProp(iClient, Prop_Send, "m_iTauntItemDefIndex");
    
    if(iTaunt < 0) // Default taunt. We're keeping the model in case it uses the weapon ( ex: sniper's sniperrifle default taunt )
        return;

    SetEntityRenderMode(iWeapon, RENDER_NORMAL);
    SetEntityRenderColor(iWeapon, 255, 255, 255, 255);

    if(!g_hWeaponModels[iWeapon].HasModel())
        return;

    g_hWeaponModels[iWeapon].ClearModel(iClient);

    return;
}

public void TF2_OnConditionRemoved(int iClient, TFCond cond)
{
    if(cond != TFCond_Taunting)
        return;

    int iWeapon = TF2_GetActiveWeapon(iClient);

    OnDrawWeapon(iClient, iWeapon);

    return;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                               Functions                                  ||
// ||──────────────────────────────────────────────────────────────────────────||

public Action Timer_OnDrawWeapon(Handle timer, DataPack hPack)
{
    Frame_OnDrawWeapon(hPack);

    return Plugin_Handled;
}

public void Frame_OnDrawWeapon(DataPack hPack)
{
    hPack.Reset();

    int client = EntRefToEntIndex(hPack.ReadCell());
    int weapon = EntRefToEntIndex(hPack.ReadCell());

    delete hPack;

    OnDrawWeapon(client, weapon);

    return;
}

public void OnDrawWeapon(int iClient, int iWeapon)
{
    if(iWeapon <= 0 || iWeapon > 2048)
        return;

    if(iClient <= 0 || iClient > MaxClients)
        return;

    if(!IsClientInGame(iClient) || !IsValidEntity(iWeapon))
        return;

    g_hWeaponModels[iWeapon].ClearModel(iClient);
    
    if(!g_hWeaponModels[iWeapon].HasModel())
        return;

    if(iWeapon != TF2_GetActiveWeapon(iClient))
        return;

    SetEntityRenderMode(iWeapon, RENDER_TRANSALPHA);
    SetEntityRenderColor(iWeapon, 0, 0, 0, 0);

    SetEntProp(iWeapon, Prop_Send, "m_bBeingRepurposedForTaunt", 1);

    g_hWeaponModels[iWeapon].m_iWorldModel  =   ApplyWeaponModel(iClient, g_hWeaponModels[iWeapon].m_sWeaponModel, false, iWeapon);
    g_hWeaponModels[iWeapon].m_iViewModel   =   ApplyWeaponModel(iClient, g_hWeaponModels[iWeapon].m_sWeaponModel, true, iWeapon);
    
    /*
    PrintToConsole(iClient, "======================================================================================");
    PrintToConsole(iClient, "sModel: %s", g_hWeaponModels[iWeapon].m_sWeaponModel);
    PrintToConsole(iClient, "g_hWeaponModels[iWeapon].m_iWorldModel: %i", g_hWeaponModels[iWeapon].m_iWorldModel);
    PrintToConsole(iClient, "g_hWeaponModels[iWeapon].m_iViewModel: %i", g_hWeaponModels[iWeapon].m_iViewModel);
    PrintToConsole(iClient, "======================================================================================");
    */

    return;
}

public int ApplyWeaponModel(int iClient, char[] sModel, bool bIsWearable, int iWeapon)
{
    int iEntity = CreateWearable(iClient, sModel, bIsWearable, 1);

    if(!IsValidEntity(iEntity))
        return -1;

    if(HasEntProp(iWeapon, Prop_Send, "m_flPoseParameter"))
        SetEntPropFloat(iEntity, Prop_Send, "m_flPoseParameter", GetEntPropFloat(iWeapon, Prop_Send, "m_flPoseParameter"));

    return iEntity;
}

public int CreateWearable(int iClient, char[] sModel, bool bIsViewmodel, int iQuality)
{
    int iEntity = CreateEntityByName(bIsViewmodel ? "tf_wearable_vm" : "tf_wearable");

    if(!IsValidEntity(iEntity))
        return -1;

    if(StrEqual(sModel, ""))
        return -1;
    
    SetEntProp(iEntity, Prop_Send, "m_nModelIndex", PrecacheModel(sModel, false));

    SetEntProp(iEntity, Prop_Send, "m_fEffects", 129);
    SetEntProp(iEntity, Prop_Send, "m_iTeamNum", GetClientTeam(iClient));
    SetEntProp(iEntity, Prop_Send, "m_nSkin", GetClientTeam(iClient));
    SetEntProp(iEntity, Prop_Send, "m_usSolidFlags", 4);
    SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 11);
    SetEntProp(iEntity, Prop_Send, "m_iEntityQuality", iQuality);
    SetEntProp(iEntity, Prop_Send, "m_iEntityLevel", -1);
    SetEntProp(iEntity, Prop_Send, "m_iItemIDLow", 2048);
    SetEntProp(iEntity, Prop_Send, "m_iItemIDHigh", 0);
    // Secret <3
    SetEntProp(iEntity, Prop_Send, "m_bInitialized", 1);
    SetEntProp(iEntity, Prop_Send, "m_iAccountID", GetSteamAccountID(iClient));

    SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", iClient);

    DispatchSpawn(iEntity);
    SetVariantString("!activator");
    ActivateEntity(iEntity);

    TF2_EquipWearable(iClient, iEntity);

    return iEntity;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                           Internal Functions                             ||
// ||──────────────────────────────────────────────────────────────────────────||

stock int TF2_GetActiveWeapon(int iClient)
{
    return GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}

stock void TF2_EquipWearable(int iClient, int iEntity)
{
    if(!g_hSdkEquipWearable)
    {
        LogMessage("Error: Can't call EquipWearable, SDK functions not loaded!");

        return;
    }

    SDKCall(g_hSdkEquipWearable, iClient, iEntity);

    return;
}