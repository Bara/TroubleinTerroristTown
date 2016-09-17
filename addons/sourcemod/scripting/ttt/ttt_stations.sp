#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <multicolors>
#include <emitsoundany>

#include <ttt_shop>
#include <ttt>
#include <config_loader>

#define HEALTH_ITEM_SHORT "hlthstat"
#define HURT_ITEM_SHORT "hurtstat"

#define SND_WARNING "resource/warning.wav"

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Health/Hurt Stations"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

int g_iHealthStationCharges[MAXPLAYERS + 1] =  { 0, ... };
int g_iHealthStationHealth[MAXPLAYERS + 1] =  { 0, ... };
bool g_bHasActiveHealthStation[MAXPLAYERS + 1] =  { false, ... };
bool g_bOnHealingCoolDown[MAXPLAYERS + 1] =  { false, ... };
Handle g_hRemoveCoolDownTimer[MAXPLAYERS + 1] =  { null, ... };

int g_iHealthPrice = 0;
int g_iHealthPrio = 0;
int g_iHealthHeal = 0;
int g_iHealthCharges = 0;
int g_iHurtPrice = 0;
int g_iHurtPrio = 0;
int g_iHurtDamage = 0;
int g_iHurtCharges = 0;

float g_fHurtDistance = 0.0;
float g_fHealthDistance = 0.0;

bool g_bHurtTraitors = false;

// bool g_bHurtStationGlow = true;

char g_cHurt[64];
char g_cHealth[64];
char g_cConfigFile[PLATFORM_MAX_PATH];

char g_sPluginTag[64];

public void OnPluginStart()
{
	TTT_IsGameCSGO();
	LoadTranslations("ttt.phrases");
	
	BuildPath(Path_SM, g_cConfigFile, sizeof(g_cConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_cConfigFile);
	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));
	Config_Done();

	BuildPath(Path_SM, g_cConfigFile, sizeof(g_cConfigFile), "configs/ttt/stations.cfg");
	Config_Setup("TTT-Stations", g_cConfigFile);
	g_iHealthPrice = Config_LoadInt("health_station_price", 3000, "The price of the Health Station in the shop for traitors. 0 to disable.");
	g_iHurtPrice = Config_LoadInt("hurt_station_price", 0, "The price of the Hurt Station in the shop for traitors. 0 to disable. Recommended is double health price.");
	
	g_iHealthPrio = Config_LoadInt("health_sort_prio", 0, "The sorting priority of the Health Station in the shop menu.");
	g_iHurtPrio = Config_LoadInt("hurt_sort_prio", 0, "The sorting priority of the Hurt Station in the shop menu.");

	g_iHealthHeal = Config_LoadInt("health_station_heal", 15, "The amount of health the health station should heal each second.");
	g_iHurtDamage = Config_LoadInt("hurt_station_damage", 25, "The damage the hurt station should do each second.");

	g_iHealthCharges = Config_LoadInt("health_station_charges", 10, "The amount of charges that the health station should start off with.");
	g_iHurtCharges = Config_LoadInt("hurt_station_charges", 15, "The amount of charges that the hurt station should start off with.");

	g_fHealthDistance = Config_LoadFloat("health_station_distance", 200.0, "The distance that the health station should reach.");
	g_fHurtDistance = Config_LoadFloat("hurt_station_distance", 200.0, "The distance that the hurt station should reach.");
	
	g_bHurtTraitors = Config_LoadBool("hurt_station_hurt_other_traitors", false, "Hurt other traitors with a hurtstation?");
	
	// g_bHurtStationGlow = Config_LoadBool("hurt_station_glow", true, "Enable the glow effect for hurt stations");

	Config_LoadString("health_station_name", "Health Station", "The name of the health station in the menu.", g_cHealth, sizeof(g_cHealth));
	Config_LoadString("hurt_station_name", "Hurt Station", "The name of the hurt station in the menu.", g_cHurt, sizeof(g_cHurt));
	
	Config_Done();

	HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);
}

public void OnMapStart()
{
	PrecacheSoundAny(SND_WARNING, true);
}

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(HEALTH_ITEM_SHORT, g_cHealth, g_iHealthPrice, TTT_TEAM_DETECTIVE, g_iHealthPrio);
	TTT_RegisterCustomItem(HURT_ITEM_SHORT, g_cHurt, g_iHurtPrice, TTT_TEAM_TRAITOR, g_iHurtPrio);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		bool hurt = (strcmp(itemshort, HURT_ITEM_SHORT, false) == 0);
		bool health = (strcmp(itemshort, HEALTH_ITEM_SHORT, false) == 0);
		
		if(hurt || health)
		{
			if(g_bHasActiveHealthStation[client])
			{
				CPrintToChat(client, g_sPluginTag, "You already have an active Health Station", client);
				return Plugin_Stop;
			}

			if(health && (TTT_GetClientRole(client) != TTT_TEAM_DETECTIVE))
				return Plugin_Stop;

			if(hurt && (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR))
				return Plugin_Stop;

			spawnHealthStation(client);
		}
	}

	return Plugin_Continue;
}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
	healthStation_cleanUp();
}

public void TTT_OnUpdate1(int i)
{
	if (i < 1 || !IsPlayerAlive(i) || TTT_GetClientRole(i) < TTT_TEAM_INNOCENT)
		return;

	checkDistanceFromHealthStation(i);
}

public void TTT_OnUpdate5(int i)
{
	if (i < 1 || !IsPlayerAlive(i))
		return;

	if (g_bHasActiveHealthStation[i] && g_iHealthStationCharges[i] < 9)
		g_iHealthStationCharges[i]++;
}

public void OnClientDisconnect(int client)
{
	ClearTimer(g_hRemoveCoolDownTimer[client]);
}

stock void ClearTimer(Handle &timer)
{
	if (timer != null)
	{
		KillTimer(timer);
		timer = null;
	}
}

public Action removeCoolDown(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	g_bOnHealingCoolDown[client] = false;
	g_hRemoveCoolDownTimer[client] = null;
	return Plugin_Stop;
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	healthStation_cleanUp();

	return Plugin_Continue;
}

public Action OnTakeDamageHealthStation(int stationIndex, int &iAttacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsValidEntity(stationIndex) || stationIndex == INVALID_ENT_REFERENCE || stationIndex <= MaxClients || iAttacker < 1 || iAttacker > MaxClients || !IsClientInGame(iAttacker))
		return Plugin_Continue;

	int owner = GetEntProp(stationIndex, Prop_Send, "m_hOwnerEntity");
	if (owner < 1 || owner > MaxClients || !IsClientInGame(owner))
		return Plugin_Continue;

	g_iHealthStationHealth[owner]--;

	if (g_iHealthStationHealth[owner] <= 0)
	{
		AcceptEntityInput(stationIndex, "Kill");
		// SDKUnhook(stationIndex, SDKHook_SetTransmit, OnSetTransmit_GlowSkin);
		g_bHasActiveHealthStation[owner] = false;
	}
	return Plugin_Continue;
}

void checkDistanceFromHealthStation(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;
	
	float clientPos[3];
	float stationPos[3];
	int curHealth;
	int newHealth;
	int iEnt;
	char sModelName[PLATFORM_MAX_PATH];
	
	while ((iEnt = FindEntityByClassname(iEnt, "prop_physics_multiplayer")) != -1)
	{
		int owner = GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity");
		if (owner < 1 || owner > MaxClients || !IsClientInGame(owner))
			continue;

		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

		if (StrContains(sModelName, "microwave") == -1)
			continue;

		bool hurt = (TTT_GetClientRole(owner) == TTT_TEAM_TRAITOR);

		GetClientEyePosition(client, clientPos);
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", stationPos);

		if (GetVectorDistance(clientPos, stationPos) > (hurt ? g_fHurtDistance : g_fHealthDistance))
			continue;

		if (g_bOnHealingCoolDown[client])
			continue;
		
		curHealth = GetClientHealth(client);
		
		if(!g_bHurtTraitors && hurt && TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
			continue;
		
		if ((!hurt) && (curHealth >= 125)) // TODO: Add cvar for max health
			continue;

		if (g_iHealthStationCharges[owner] > 0 && ((hurt == false) || (client != owner)))
		{
			newHealth = (hurt ? (curHealth - g_iHurtDamage) : (curHealth + g_iHealthHeal));
			if (newHealth >= 125)
				SetEntityHealth(client, 125);
			else if (newHealth <= 0)
				ForcePlayerSuicide(client);
			else
				SetEntityHealth(client, newHealth);

			if(!hurt)
				CPrintToChat(client, g_sPluginTag, "Healing From", client, owner);

			EmitSoundToClientAny(client, SND_WARNING);
			g_iHealthStationCharges[owner]--;
			g_bOnHealingCoolDown[client] = true;
			g_hRemoveCoolDownTimer[client] = CreateTimer(1.0, removeCoolDown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			if(!hurt)
			{
				CPrintToChat(client, g_sPluginTag, "Health Station Out Of Charges", client);
				g_bOnHealingCoolDown[client] = true;
				g_hRemoveCoolDownTimer[client] = CreateTimer(1.0, removeCoolDown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

void spawnHealthStation(int client)
{
	if (!IsPlayerAlive(client))
		return;

	int healthStationIndex = CreateEntityByName("prop_physics_multiplayer");
	if (healthStationIndex != -1)
	{
		int role = TTT_GetClientRole(client);
		float clientPos[3];
		GetClientAbsOrigin(client, clientPos);
		SetEntProp(healthStationIndex, Prop_Send, "m_hOwnerEntity", client);
		DispatchKeyValue(healthStationIndex, "model", "models/props/cs_office/microwave.mdl");
		DispatchSpawn(healthStationIndex);
		SDKHook(healthStationIndex, SDKHook_OnTakeDamage, OnTakeDamageHealthStation);
		TeleportEntity(healthStationIndex, clientPos, NULL_VECTOR, NULL_VECTOR);
		g_iHealthStationHealth[client] = 10;
		g_bHasActiveHealthStation[client] = true;
		g_iHealthStationCharges[client] = ((role == TTT_TEAM_TRAITOR) ? g_iHurtCharges : g_iHealthCharges);
		CPrintToChat(client, g_sPluginTag, ((role == TTT_TEAM_TRAITOR) ? "Health Station Deployed" : "Hurt Station Deployed"), client);
		
		/* if(g_bHurtStationGlow && role == TTT_TEAM_TRAITOR)
		{
			if (SDKHookEx(healthStationIndex, SDKHook_SetTransmit, OnSetTransmit_GlowSkin))
					SetupGlow(healthStationIndex);
		} */
	}
}

/* void SetupGlow(int entity)
{
	int iOffset;
	
	if (!iOffset && (iOffset = GetEntSendPropOffs(entity, "m_clrGlow")) == -1)
		return;
	
	SetEntProp(entity, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(entity, Prop_Send, "m_nGlowStyle", 0);
	SetEntPropFloat(entity, Prop_Send, "m_flGlowMaxDist", 10000000.0);
	
	SetEntData(entity, iOffset, 255, _, true);
	SetEntData(entity, iOffset + 1, 0, _, true);
	SetEntData(entity, iOffset + 2, 0, _, true);
	SetEntData(entity, iOffset + 3, 255, _, true);
}

public Action OnSetTransmit_GlowSkin(int entity, int client)
{
	if(!TTT_IsRoundActive())
		return Plugin_Handled;
	
	if(client == 0 || IsFakeClient(client))
		return Plugin_Handled;
		
	if(!IsPlayerAlive(client))
		return Plugin_Handled;
	
	if(!IsValidEntity(entity))
		return Plugin_Handled;
	
	if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
		return Plugin_Continue;
	
	return Plugin_Handled;
} */

void healthStation_cleanUp()
{
	LoopValidClients(i)
	{
		g_iHealthStationCharges[i] = 0;
		g_bHasActiveHealthStation[i] = false;
		g_bOnHealingCoolDown[i] = false;

		ClearTimer(g_hRemoveCoolDownTimer[i]);
	}
}
