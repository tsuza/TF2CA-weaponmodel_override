#include <sourcemod>

#include <tf2>
#include <tf2_stocks>
#include <tf2utils>
#include <tf_custom_attributes>

#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME         "[CA] Weapon Model Override"
#define PLUGIN_AUTHOR       "Zabaniya001"
#define PLUGIN_DESCRIPTION  "Custom Attribute that utilizes Nosoop's framework. This plugin lets you have a custom weapon model ( both worldmodel and viewmodel )."
#define PLUGIN_VERSION      "1.1.1"
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
		if(!this.m_bHasCustomModel)
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

// ||──────────────────────────────────────────────────────────────────────────||
// ||                               SOURCEMOD API                              ||
// ||──────────────────────────────────────────────────────────────────────────||

public void OnPluginStart()
{
	HookEvent("post_inventory_application", Event_InventoryApplicationPost);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_sapped_object", Event_OnObjectSapped);

	// In case of late-load
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
			OnClientPutInServer(client);
	}

	return;
}

public void OnPluginEnd()
{
	int iWeapon = 0;

	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;

		for(int iSlot = 0; iSlot < 9; iSlot++)
		{
			iWeapon = TF2Util_GetPlayerLoadoutEntity(iClient, iSlot);

			if(iWeapon < 0 || iWeapon > 2048)
				continue;

			if(!IsValidEntity(iWeapon))
				continue;

			if(!g_hWeaponModels[iWeapon].HasModel())
				continue;

			// Cleaning them up in case you unload the plugin since the custom models 
			// will stay and stack on top of the other weapons.
			g_hWeaponModels[iWeapon].ClearModel(iClient);
			g_hWeaponModels[iWeapon].Destroy();

			// Making the original weapons re-appear. However, only the worldmodel will come back 
			// and the viewmodel will stay invisible, unless you taunt. Weird, could force the client to taunt 
			// or find some events to force the reload of the viewmodel but too bad!
			SetEntityRenderMode(iWeapon, RENDER_NORMAL);
			SetEntityRenderColor(iWeapon, 255, 255, 255, 255);
		}
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

	char sModelName[PLATFORM_MAX_PATH];
	if(!TF2CustAttr_GetString(iWeapon, "weaponmodel override", sModelName, sizeof(sModelName)))
		return;

	g_hWeaponModels[iWeapon].SetModel(sModelName);

	// CheckPlayerShield(iClient, iWeapon);

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
	int iClient = GetClientOfUserId((event.GetInt("userid")));

	int iActiveWeapon = TF2_GetActiveWeapon(iClient);

	if(iActiveWeapon <= 0 || iActiveWeapon > 2048)
		return;

	if(!IsValidEntity(iActiveWeapon))
		return;

	char sModelName[PLATFORM_MAX_PATH];
	if(!TF2CustAttr_GetString(iActiveWeapon, "weaponmodel override", sModelName, sizeof(sModelName)))
		return;

	g_hWeaponModels[iActiveWeapon].SetModel(sModelName);

	OnDrawWeapon(iClient, iActiveWeapon);

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
	if(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
		return Plugin_Continue;

	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iWeapon = TF2_GetActiveWeapon(iClient);

	g_hWeaponModels[iWeapon].ClearModel(iClient);

	return Plugin_Continue;
}

// You know... I might be using too many unnecessary sanity checks. But I'd rather not get a random error so I'll just do that. 
public void Event_OnObjectSapped(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));

	if(iClient <= 0 || iClient > MaxClients)
		return;

	if(!IsClientInGame(iClient))
		return;

	int iSapper = GetPlayerWeaponSlot(iClient, 1);
	if(!IsValidEntity(iSapper))
		return;

	char sModelName[PLATFORM_MAX_PATH];
	if(!TF2CustAttr_GetString(iSapper, "weaponmodel override", sModelName, sizeof(sModelName)))
		return;

	int iAttachedSapper = event.GetInt("sapperid");

	if(!IsValidEntity(iAttachedSapper))
		return;

	SetEntityModel(iAttachedSapper, sModelName);

	return;
}

// Checking if the client is taunting so we can add / remove the weapon model so it doesn't look weird.

public void TF2_OnConditionAdded(int iClient, TFCond cond)
{
	if(cond != TFCond_Taunting)
		return;

	int iWeapon = TF2_GetActiveWeapon(iClient);

	int iTaunt = GetEntProp(iClient, Prop_Send, "m_iTauntItemDefIndex");
	
	// Default taunt. We're keeping the model in case it uses the weapon ( ex: sniper's sniperrifle default taunt )
	if(iTaunt < 0 || !g_hWeaponModels[iWeapon].HasModel())
		return;
 
	if(iTaunt == 1117) {  // Battin' a Thousand taunt
		OnDrawWeapon(iClient, iWeapon);
		return;
	}

	// Fun fact: Taunt props are somehow bound to weapons. You gotta unhide them 
	// or otherwise the taunt props will be invisible.
	SetEntityRenderMode(iWeapon, RENDER_NORMAL);
	SetEntityRenderColor(iWeapon, 255, 255, 255, 255);

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

/*
// Okay so, it kinda applies the custom model. However, it hides the sword and the worldmodel stays ( on top of the custom one ).
// There is definitely a way to do it but I'm lazy and a bit stupid so y'all will have to wait until God appears in front of me and blesses me with infinite knowledge.
public void CheckPlayerShield(int iClient, int iWeapon)
{
	if(!(TF2_GetPlayerClass(iClient) == TFClass_DemoMan && GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee) == iWeapon))
		return;

	int iShield = TF2_GetPlayerLoadoutSlot(iClient, TF2LoadoutSlot_Secondary);

	if(iShield <= 0 || iShield > 2048)
		return;

	if(!IsValidEntity(iShield))
		return;

	if(!TF2_IsWearable(iShield))
		return;
	
	char sModelName[PLATFORM_MAX_PATH];
	if(!TF2CustAttr_GetString(iShield, "weaponmodel override", sModelName, sizeof(sModelName)))
		return;
	
	g_hWeaponModels[iWeapon].SetModel(sModelName);

	g_hWeaponModels[iWeapon].m_iWorldModel  =   ApplyWeaponModel(iClient, g_hWeaponModels[iWeapon].m_sWeaponModel, false, iWeapon);
	g_hWeaponModels[iWeapon].m_iViewModel   =   ApplyWeaponModel(iClient, g_hWeaponModels[iWeapon].m_sWeaponModel, true, iWeapon);

	return;
}
*/

public Action Timer_OnDrawWeapon(Handle timer, DataPack hPack)
{
	Frame_OnDrawWeapon(hPack);

	return Plugin_Handled;
}

public void Frame_OnDrawWeapon(DataPack hPack)
{
	hPack.Reset();

	int iClient = EntRefToEntIndex(hPack.ReadCell());
	int iWeapon = EntRefToEntIndex(hPack.ReadCell());

	delete hPack;

	if(iWeapon != TF2_GetActiveWeapon(iClient))
		return;

	OnDrawWeapon(iClient, iWeapon);

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

	SetEntityRenderMode(iWeapon, RENDER_TRANSALPHA);
	SetEntityRenderColor(iWeapon, 0, 0, 0, 0);

	SetEntProp(iWeapon, Prop_Send, "m_bBeingRepurposedForTaunt", 1);

	g_hWeaponModels[iWeapon].m_iWorldModel  =   ApplyWeaponModel(iClient, g_hWeaponModels[iWeapon].m_sWeaponModel, false, iWeapon);
	g_hWeaponModels[iWeapon].m_iViewModel   =   ApplyWeaponModel(iClient, g_hWeaponModels[iWeapon].m_sWeaponModel, true, iWeapon);
	
	/*
	// Debugging purposes
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
	SetEntProp(iEntity, Prop_Send, "m_bInitialized", 1);
	SetEntProp(iEntity, Prop_Send, "m_iAccountID", GetSteamAccountID(iClient));
	SetEntProp(iEntity, Prop_Send, "m_bValidatedAttachedEntity", 1);

	SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", iClient);

	DispatchSpawn(iEntity);
	SetVariantString("!activator");
	ActivateEntity(iEntity);

	TF2Util_EquipPlayerWearable(iClient, iEntity);

	return iEntity;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                           Internal Functions                             ||
// ||──────────────────────────────────────────────────────────────────────────||

stock int TF2_GetActiveWeapon(int iClient)
{
	return GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}