/*  SM Franug Sprint with Animation
 *
 *  Copyright (C) 2021 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <CustomPlayerSkins>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION	 "0.1"

Handle _bSprint[MAXPLAYERS + 1];
int g_iEmoteEnt[MAXPLAYERS+1];

ConVar g_cvThirdperson;

public Plugin myinfo =
{
	name = "SM Franug Sprint with Animation",
	author = "Franc1sco franug",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/franug"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_sprint", Command_Sprint, "Toggles sprinting mode for clients");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", 	Event_PlayerDeath, 	EventHookMode_Pre);
	
	g_cvThirdperson = FindConVar("sv_allow_thirdperson");
	if (!g_cvThirdperson) SetFailState("sv_allow_thirdperson not found!");

	g_cvThirdperson.AddChangeHook(OnConVarChanged);
	g_cvThirdperson.BoolValue = true;
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvThirdperson)
	{
		if(newValue[0] != '1') convar.BoolValue = true;
	}
}

public void OnMapStart()
{
	AddFileToDownloadsTable("models/pvb/running.mdl");
	AddFileToDownloadsTable("models/pvb/running.vvd");
	AddFileToDownloadsTable("models/pvb/running.dx90.vtx");
	
	PrecacheModel("models/pvb/running.mdl", true);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	delete _bSprint[client];
	ResetCam(client);
	StopEmote(client);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	delete _bSprint[client];
	ResetCam(client);
	StopEmote(client);
}

public void OnClientDisconnect(int client)
{
	delete _bSprint[client];
	ResetCam(client);
	StopEmote(client);
}

public Action Command_Sprint(int client,int args)
{
    if (IsClientInGame(client) && IsPlayerAlive(client))
    {
        if (_bSprint[client] == null)
        {
            StartSprint(client);
        }
    }
    
    return Plugin_Handled;
}

void StartSprint(int client)
{
	PrintToChat(client, " \x04Sprint started!");
	
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.5);	
	
	_bSprint[client] = CreateTimer(5.0, Timer_EndSprint, client);
	
	setAnimation(client);
}

public Action Timer_EndSprint(Handle timer, int client)
{
	_bSprint[client] = null;
	
	ResetCam(client);
	StopEmote(client);
	PrintToChat(client, " \x04Sprint ended!");
	
	SetEntityMoveType(client, MOVETYPE_WALK);
	
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);	
}

void setAnimation(int client)
{
	int EmoteEnt = CreateEntityByName("prop_dynamic");
	
	if (!IsValidEntity(EmoteEnt))return;
	
	char model[128];
	
	GetClientModel(client, model, 128);
	
	int clone = CPS_SetSkin(client, model, CPS_TRANSMIT);

	float vec[3], ang[3];
	GetClientAbsOrigin(client, vec);
	GetClientAbsAngles(client, ang);
	char emoteEntName[16];
	FormatEx(emoteEntName, sizeof(emoteEntName), "emoteEnt%i", GetRandomInt(1000000, 9999999));
	
	DispatchKeyValue(EmoteEnt, "targetname", emoteEntName);
	DispatchKeyValue(EmoteEnt, "model", "models/pvb/running.mdl");
	DispatchKeyValue(EmoteEnt, "solid", "0");
	DispatchKeyValue(EmoteEnt, "rendermode", "10");

	ActivateEntity(EmoteEnt);
	DispatchSpawn(EmoteEnt);

	TeleportEntity(EmoteEnt, vec, ang, NULL_VECTOR);
	
	SetVariantString(emoteEntName);
	
	AcceptEntityInput(clone, "SetParent", clone, clone, 0);

	g_iEmoteEnt[client] = EntIndexToEntRef(EmoteEnt);

	int enteffects = GetEntProp(client, Prop_Send, "m_fEffects");
	enteffects |= 1; /* This is EF_BONEMERGE */
	enteffects |= 16; /* This is EF_NOSHADOW */
	enteffects |= 64; /* This is EF_NORECEIVESHADOW */
	enteffects |= 128; /* This is EF_BONEMERGE_FASTCULL */
	enteffects |= 512; /* This is EF_PARENT_ANIMATES */
	SetEntProp(client, Prop_Send, "m_fEffects", enteffects);	
	
	//HookSingleEntityOutput(EmoteEnt, "OnAnimationDone", EndAnimation, true);
	
	SetVariantString("run");
	AcceptEntityInput(EmoteEnt, "SetAnimation", -1, -1, 0);
	
	SetCam(client);
}

void SetCam(int client)
{
	ClientCommand(client, "cam_collision 0");
	ClientCommand(client, "cam_idealdist 100");
	ClientCommand(client, "cam_idealpitch 0");
	ClientCommand(client, "cam_idealyaw 0");
	ClientCommand(client, "thirdperson");
}

void ResetCam(int client)
{
	ClientCommand(client, "firstperson");
	ClientCommand(client, "cam_collision 1");
	ClientCommand(client, "cam_idealdist 150");
}

void StopEmote(int client)
{
	CPS_RemoveSkin(client);
	
	if (!g_iEmoteEnt[client])
		return;
	
	int iEmoteEnt = EntRefToEntIndex(g_iEmoteEnt[client]);
	if (iEmoteEnt && iEmoteEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEmoteEnt))
	{
		char emoteEntName[50];
		GetEntPropString(iEmoteEnt, Prop_Data, "m_iName", emoteEntName, sizeof(emoteEntName));
		SetVariantString(emoteEntName);
		AcceptEntityInput(client, "ClearParent", iEmoteEnt, iEmoteEnt, 0);
		DispatchKeyValue(iEmoteEnt, "OnUser1", "!self,Kill,,1.0,-1");
		AcceptEntityInput(iEmoteEnt, "FireUser1");
		

		g_iEmoteEnt[client] = 0;
	} else
	{
		g_iEmoteEnt[client] = 0;
	}
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
	if (!g_iEmoteEnt[client])
		return;
		
	float vec[3], ang[3];
	GetClientAbsOrigin(client, vec);
	GetClientAbsAngles(client, ang);
	
	TeleportEntity(g_iEmoteEnt[client], vec, ang, NULL_VECTOR);
}