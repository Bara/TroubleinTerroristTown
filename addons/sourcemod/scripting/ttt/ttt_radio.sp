#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <ttt>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Template"

ConVar g_cPluginTag = null;
char g_sPluginTag[64];


public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	LoadTranslations("ttt.phrases");
	
	TTT_StartConfig("radio");
	CreateConVar("ttt2_radio_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	TTT_EndConfig();
	
	RegConsoleCmd("sm_radio", Command_Radio);
}

public void OnConfigsExecuted()
{
	g_cPluginTag = FindConVar("ttt_plugin_tag");
	g_cPluginTag.AddChangeHook(OnConVarChanged);
	g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}
public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cPluginTag)
	{
		g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	}
}

public Action Command_Radio(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}
	
	if (args == 0)
	{
		ShowRadioMenu(client);
		return Plugin_Handled;
	}
	
	char sMessage[MAX_MESSAGE_LENGTH];
	GetCmdArgString(sMessage, sizeof(sMessage));
	
	char sColor[16];
	int role = TTT_GetClientRole(client);
	
	if (role == TTT_TEAM_INNOCENT)
	{
		Format(sColor, sizeof(sColor), "green");
	}
	else if (role == TTT_TEAM_TRAITOR)
	{
		Format(sColor, sizeof(sColor), "green");
	}
	else if (role == TTT_TEAM_DETECTIVE)
	{
		Format(sColor, sizeof(sColor), "darkblue");
	}
	
	if (strlen(sColor) < 3)
	{
		return Plugin_Handled;
	}
	
	if (StrEqual(sMessage, "yes", false))
	{
		LoopValidClients(i)
		{
			CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Yes", i);
		}
	}
	
	if (StrEqual(sMessage, "no", false))
	{
		LoopValidClients(i)
		{
			CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: No", i);
		}
	}
	
	if (StrEqual(sMessage, "maybe", false))
	{
		LoopValidClients(i)
		{
			CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Maybe", i);
		}
	}
	
	if (StrEqual(sMessage, "help", false))
	{
		LoopValidClients(i)
		{
			CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Help", i);
		}
	}
	
	if (StrEqual(sMessage, "check", false))
	{
		LoopValidClients(i)
		{
			CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Check", i);
		}
	}
	
	int iTarget = TraceClientViewEntity(client);
	
	if (!TTT_IsClientValid(iTarget))
	{
		return Plugin_Handled;
	}
	
	if (StrEqual(sMessage, "imwith", false))
	{
		LoopValidClients(i)
		{
			CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Im With", i, iTarget);
		}
	}
	
	if (StrEqual(sMessage, "suspect", false))
	{
		LoopValidClients(i)
		{
			CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Suspect", i, iTarget);
		}
	}
	
	if (StrEqual(sMessage, "traitor", false))
	{
		LoopValidClients(i)
		{
			CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Traitor", i, iTarget);
		}
	}
	
	if (StrEqual(sMessage, "innocent", false))
	{
		LoopValidClients(i)
		{
			CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Innocent", i, iTarget);
		}
	}
	
	if (StrEqual(sMessage, "see", false))
	{
		LoopValidClients(i)
		{
			CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: See", i, iTarget);
		}
	}
	
	return Plugin_Continue;
}

void ShowRadioMenu(int client)
{
	Menu menu = new Menu(Menu_RadioHandler);
	menu.SetTitle("%T", "TTT Radio Menu: Commands", client);
	
	// yes
	// no
	// maybe
	// help
	// Check
	// Im with
	// Acts suspicious
	// Traitor
	// Innocent
	// See
	
	char sBuffer[64];
	
	Format(sBuffer, sizeof(sBuffer), "%T", "TTT Radio Menu: Yes", client);
	menu.AddItem("yes", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "TTT Radio Menu: No", client);
	menu.AddItem("no", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "TTT Radio Menu: Maybe", client);
	menu.AddItem("maybe", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "TTT Radio Menu: Help", client);
	menu.AddItem("help", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "TTT Radio Menu: Check", client);
	menu.AddItem("check", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "TTT Radio Menu: Im With", client);
	menu.AddItem("imwith", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "TTT Radio Menu: Suspect", client);
	menu.AddItem("suspect", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "TTT Radio Menu: Traitor", client);
	menu.AddItem("traitor", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "TTT Radio Menu: Innocent", client);
	menu.AddItem("innocent", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "TTT Radio Menu: See", client);
	menu.AddItem("see", sBuffer);
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
}

public int Menu_RadioHandler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		char sCommand[32];
		menu.GetItem(param, sCommand, sizeof(sCommand));
		FakeClientCommand(client, "sm_radio %s", sCommand);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

stock int TraceClientViewEntity(int client)
{
	float m_vecOrigin[3];
	float m_angRotation[3];

	GetClientEyePosition(client, m_vecOrigin);
	GetClientEyeAngles(client, m_angRotation);

	Handle tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_SOLID, RayType_Infinite, TRDontHitSelf, client);
	int pEntity = -1;

	if (TR_DidHit(tr))
	{
		pEntity = TR_GetEntityIndex(tr);
		delete(tr);
		return pEntity;
	}

	if (tr != null)
	{
		delete(tr);
	}

	return -1;
}



public bool TRDontHitSelf(int entity, int mask, int data)
{
	return (entity != data);
}

