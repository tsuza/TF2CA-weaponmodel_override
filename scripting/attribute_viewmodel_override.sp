#include <sourcemod>

#include <sdkhooks>
#include <sdktools>

#include <tf2_stocks>

#include <tf2attributes>
#include <tf_econ_dynamic>
#include <tf2utils>

#pragma newdecls required
#pragma semicolon 1

#define SF_NORESPAWN 1 << 30

public Plugin myinfo =
{
	name        =  "[TF2] Attribute: Viewmodel Override",
	author      =  "Zabaniya001",
	description =  "[TF2] Attributes to modify arms, arms animations, firstperson and thirdparson weapon model.",
	version     =  "2.0.3",
	url         =  "https://github.com/Zabaniya001/TF2CA-weaponmodel_override"
};

enum struct WeaponModel
{
	int m_iArmsRef;
	int m_iViewModelRef;
	int m_iWorldModelRef;

	void Delete(int client)
	{
		int arms = EntRefToEntIndex(this.m_iArmsRef);
		int viewmodel = EntRefToEntIndex(this.m_iViewModelRef);
		int worldmodel = EntRefToEntIndex(this.m_iWorldModelRef);

		if(arms != 0 && arms != -1)
		{
			TF2_RemoveWearable(client, arms);
			RemoveEntity(arms);
		}

		if(viewmodel != 0 && viewmodel != -1)
		{
			TF2_RemoveWearable(client, viewmodel);
			RemoveEntity(viewmodel);
		}

		if(worldmodel != 0 && worldmodel != -1)
		{
			TF2_RemoveWearable(client, worldmodel);
			RemoveEntity(worldmodel);
		}

		return;
	}
}

WeaponModel g_ClientWeaponModels[MAXPLAYERS + 1];

enum
{
	EF_BONEMERGE            = (1 << 0),
	EF_NODRAW               = (1 << 5),
	EF_BONEMERGE_FASTCULL   = (1 << 7),
}

public void OnPluginStart()
{
	RegisterAttributes();

	// Events
	HookEvent("post_inventory_application", Event_OnInventoryApplicationPost);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("player_sapped_object", Event_OnObjectSapped);

	// late-load support
	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client))
			continue;
		
		OnClientPutInServer(client);
	}

	return;
}

public void OnPluginEnd()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client))
			continue;
		
		int active_weapon = TF2_GetActiveWeapon(client);
		
		if(IsValidEntity(active_weapon) && EntRefToEntIndex(g_ClientWeaponModels[client].m_iViewModelRef) != -1)
		{
			SetEntProp(active_weapon, Prop_Send, "m_bBeingRepurposedForTaunt", 0);

			SetEntityRenderMode(active_weapon, RENDER_NORMAL);
			SetEntityRenderColor(active_weapon, 255, 255, 255, 255);
		}

		if(EntRefToEntIndex(g_ClientWeaponModels[client].m_iArmsRef) != -1)
		{
			int viewmodel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");

			SetEntProp(viewmodel, Prop_Send, "m_fEffects", GetEntProp(viewmodel, Prop_Send, "m_fEffects") & ~EF_NODRAW);
		}
		
		g_ClientWeaponModels[client].Delete(client);
	}

	return;
}

void RegisterAttributes()
{
	TF2EconDynAttribute attribute = new TF2EconDynAttribute();

	attribute.SetDescriptionFormat("value_is_additive");
	attribute.SetCustom("attribute_type", "string");


	attribute.SetName("set weapon model");
	attribute.SetClass("set_weapon_model");

	attribute.Register();


	attribute.SetName("set weapon viewmodel");
	attribute.SetClass("set_weapon_viewmodel");

	attribute.Register();


	attribute.SetName("set weapon worldmodel");
	attribute.SetClass("set_weapon_worldmodel");

	attribute.Register();


	attribute.SetName("set viewmodel arms");
	attribute.SetClass("set_viewmodel_animated_arms");

	attribute.Register();


	attribute.SetName("set viewmodel bonemerged arms");
	attribute.SetClass("set_viewmodel_bonemerged_arms");

	attribute.Register();


	delete attribute;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, SDHook_OnWeaponSwitchPost);
	SDKHook(client, SDKHook_WeaponEquipPost, SDHook_OnWeaponEquipPost);

	return;
}

/// TO-DO: This could be replaced with TF2Util_SetWearableAlwaysValid().
public void Event_OnInventoryApplicationPost(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId((event.GetInt("userid")));

	int active_weapon = TF2_GetActiveWeapon(client);

	if(active_weapon <= 0 || active_weapon > 2048)
		return;

	if(!IsValidEntity(active_weapon))
		return;

	OnDrawWeapon(client, active_weapon);

	return;
}

public void OnEntityCreated(int entity, const char[] sClassname)
{
	if(!StrEqual(sClassname, "tf_dropped_weapon"))  // When a weapon gets dropped, it gets deleted and another entity with the same properties (atts etc..) gets created.
		return;

	SDKHook(entity, SDKHook_Spawn, SDKHook_OnEntitySpawn);

	return;
}

void SDKHook_OnEntitySpawn(int entity)
{
	char model[PLATFORM_MAX_PATH];

	// tf_dropped_weapon entities don't have CAttributeList::m_pManager, so that's why we can't use TF2Attrib_HookValueString
	if(Util_GetAttributeStringValueFromNonWeapons(entity, "set weapon model", model, sizeof(model))
			|| Util_GetAttributeStringValueFromNonWeapons(entity, "set weapon worldmodel", model, sizeof(model)))
	{
		PrecacheModel(model);
		
		SetEntityModel(entity, model);
	}

	return;
}

void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	g_ClientWeaponModels[client].Delete(client);

	return;
}

// The placed sapper doesn't inherit the model of the sapper weapon.
// Changing "CObjectSapper::m_szPlacementModel" is the only way on a first glance, but that'd be unnecessary gamedata ¯\_(ツ)_/¯
void Event_OnObjectSapped(Event event, const char[] name, bool bDontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(!IsValidEntity(client))
		return;
	
	int sapper = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);

	if(!IsValidEntity(sapper))
		return;

	int attached_sapper = event.GetInt("sapperid");

	if(!IsValidEntity(attached_sapper))
		return;
	
	char model[PLATFORM_MAX_PATH];

	if(!TF2Attrib_HookValueString("", "set_weapon_model", sapper, model, sizeof(model)) 
			&& !TF2Attrib_HookValueString("", "set_weapon_worldmodel", sapper, model, sizeof(model)))
		return;

	SetEntityModel(attached_sapper, model);

	return;
}

// Checking if the client is taunting so we can add / remove the weapon model so it doesn't look weird.
public void TF2_OnConditionAdded(int client, TFCond cond)
{
	if(cond != TFCond_Taunting)
		return;

	if(!EntRefToEntIndex(g_ClientWeaponModels[client].m_iViewModelRef))
		return;

	int taunt = GetEntProp(client, Prop_Send, "m_iTauntItemDefIndex");
	
	// Default taunt. We're keeping the model in case it uses the weapon ( ex: sniper's sniperrifle default taunt )
	if(taunt <= 0)
		return;
	
	// Battin' a Thousand taunt
	if(taunt == 1117)
		return;
	
	int weapon = TF2_GetActiveWeapon(client);

	if(weapon > MaxClients && IsValidEntity(weapon))
	{
		SetEntityRenderMode(weapon, RENDER_NORMAL);
		SetEntityRenderColor(weapon, 255, 255, 255, 255);
	}

	g_ClientWeaponModels[client].Delete(client);

	return;
}

public void TF2_OnConditionRemoved(int client, TFCond cond)
{
	if(cond != TFCond_Taunting)
		return;
	
	if(!IsClientInGame(client))
		return;

	int weapon = TF2_GetActiveWeapon(client);

	if(weapon <= 0 || !IsValidEntity(weapon))
		return;

	OnDrawWeapon(client, weapon);

	return;
}

void SDHook_OnWeaponEquipPost(int client, int weapon)
{
	char model_path[PLATFORM_MAX_PATH];

	if(!TF2Attrib_HookValueString("", "set_viewmodel_animated_arms", weapon, model_path, sizeof(model_path)))
		return;

	SetViewmodelAnims(client, weapon, model_path);

	return;
}

void SDHook_OnWeaponSwitchPost(int client, int weapon)
{
	static int last_weapon_list[36] = {-1, ...};

	if(!IsValidEntity(weapon))
		return;

	int last_weapon = EntRefToEntIndex(last_weapon_list[client]);

	if(last_weapon == weapon)
		return;

	last_weapon_list[client] = EntIndexToEntRef(weapon);
	
	DataPack hPack = new DataPack();
	hPack.WriteCell(EntIndexToEntRef(client));
	hPack.WriteCell(EntIndexToEntRef(weapon));
	
	RequestFrame(Frame_OnDrawWeapon, hPack);

	return;
}

void Frame_OnDrawWeapon(DataPack hPack)
{
	hPack.Reset();

	int client = EntRefToEntIndex(hPack.ReadCell());
	int weapon = EntRefToEntIndex(hPack.ReadCell());

	delete hPack;

	if(client == -1 || weapon == -1)
		return;

	if(weapon != TF2_GetActiveWeapon(client))
		return;

	OnDrawWeapon(client, weapon);

	return;
}

void OnDrawWeapon(int client, int weapon)
{
	g_ClientWeaponModels[client].Delete(client);

	char model[PLATFORM_MAX_PATH];

	if(TF2Attrib_HookValueString("", "set_weapon_model", weapon, model, sizeof(model)))
	{
		SetWeaponViewmodel(client, weapon, model);
		SetWeaponWorldmodel(client, weapon, model);
	}

	if(TF2Attrib_HookValueString("", "set_weapon_viewmodel", weapon, model, sizeof(model)))
	{
		SetWeaponViewmodel(client, weapon, model);
	}
	
	if(TF2Attrib_HookValueString("", "set_weapon_worldmodel", weapon, model, sizeof(model)))
	{
		SetWeaponWorldmodel(client, weapon, model);
	}

	if(TF2Attrib_HookValueString("", "set_viewmodel_bonemerged_arms", weapon, model, sizeof(model)))
	{
		SetViewmodelArms(client, weapon, model);
	}

	return;
}

stock void SetWeaponViewmodel(int client, int weapon, char[] model_path = "", int model_id = 0)
{
	SetEntityRenderMode(weapon, RENDER_TRANSALPHA);
	SetEntityRenderColor(weapon, 0, 0, 0, 0);

	// This hides the weapon and makes the arms appear.
	// Either we do this or we manually create the arms and attach them to the weapon ( + 1 entity ).
	SetEntProp(weapon, Prop_Send, "m_bBeingRepurposedForTaunt", 1);
	
	g_ClientWeaponModels[client].m_iViewModelRef = EntIndexToEntRef(ApplyModel(client, model_path, model_id, true, weapon));

	return;
}

stock void SetWeaponWorldmodel(int client, int weapon, char[] model_path = "", int model_id = 0)
{
	g_ClientWeaponModels[client].m_iWorldModelRef = EntIndexToEntRef(ApplyModel(client, model_path, model_id,  false, weapon));

	SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", model_path ? PrecacheModel("model_path") : model_id);

	return;
}

stock void SetViewmodelArms(int client, int weapon, char[] model_path = "", int model_id = 0)
{
	int viewmodel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");

	SetEntProp(viewmodel, Prop_Send, "m_fEffects", EF_NODRAW);

	g_ClientWeaponModels[client].m_iArmsRef = EntIndexToEntRef(ApplyModel(client, model_path, model_id, true, weapon));

	return;
}

stock void SetViewmodelAnims(int client, int weapon, char[] model_path = "", int model_id = 0)
{
	PrecacheModel(model_path);

	SetEntityModel(weapon, model_path);
	SetEntProp(weapon, Prop_Send, "m_nCustomViewmodelModelIndex", GetEntProp(weapon, Prop_Send, "m_nModelIndex"));
	SetEntProp(weapon, Prop_Send, "m_iViewModelIndex", GetEntProp(weapon, Prop_Send, "m_nModelIndex"));

	return;
}

stock static int ApplyModel(int client, char[] model_path = "", int model_id = 0, bool isViewmodel, int weapon = -1)
{
	int entity = CreateWearable(client, model_path, model_id, isViewmodel);

	//if(entity != -1 && weapon != -1 && !isViewmodel)
	//	AcceptEntityInput(entity, "SetParent", weapon);
		
	//SetEntPropEnt(entity, Prop_Send, "m_hWeaponAssociatedWith", weapon);

	return entity;
}

stock static int CreateWearable(int client, char[] model_path = "", int model_id = 0, bool isViewmodel)
{
	int entity = CreateEntityByName(isViewmodel ? "tf_wearable_vm" : "tf_wearable");

	if(!IsValidEntity(entity))
		return -1;

	SetEntProp(entity, Prop_Send, "m_nModelIndex", model_path ? PrecacheModel(model_path) : model_id);
	SetEntProp(entity, Prop_Send, "m_fEffects",  EF_BONEMERGE | EF_BONEMERGE_FASTCULL);
	SetEntProp(entity, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(entity, Prop_Send, "m_nSkin", GetClientTeam(client));
	SetEntProp(entity, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 11);
	SetEntProp(entity, Prop_Send, "m_iEntityQuality", 1);
	SetEntProp(entity, Prop_Send, "m_iEntityLevel", -1);
	SetEntProp(entity, Prop_Send, "m_iItemIDLow", 2048);
	SetEntProp(entity, Prop_Send, "m_iItemIDHigh", 0);
	SetEntProp(entity, Prop_Send, "m_bInitialized", 1);
	SetEntProp(entity, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
	//SetEntProp(entity, Prop_Send, "m_spawnflags", GetEntProp(entity, Prop_Send, "m_spawnflags") | SF_NORESPAWN);
	SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", 1);

	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);

	DispatchSpawn(entity);

	SetVariantString("!activator");
	ActivateEntity(entity);

	TF2Util_EquipPlayerWearable(client, entity);

	return entity;
}

static int TF2_GetActiveWeapon(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}

static int Util_GetAttributeStringValueFromNonWeapons(int entity, char[] attribute_name, char[] attribute_value, int attribute_value_length)
{
	Address pAttribute = TF2Attrib_GetByName(entity, attribute_name);

	return pAttribute ? TF2Attrib_UnsafeGetStringValue(TF2Attrib_GetValue(pAttribute), attribute_value, attribute_value_length) : 0;
}
