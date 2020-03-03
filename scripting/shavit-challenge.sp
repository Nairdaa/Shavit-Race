#include <sourcemod>
#include <shavit>
#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

float gF_Challenge_RequestTime[MAXPLAYERS + 1];
bool gB_Challenge[MAXPLAYERS + 1];
bool gB_Challenge_Abort[MAXPLAYERS + 1];
bool gB_Challenge_Request[MAXPLAYERS + 1];
int gI_CountdownTime[MAXPLAYERS + 1];
char gS_Challenge_OpponentID[MAXPLAYERS + 1][32];
char gS_SteamID[MAXPLAYERS + 1][32];
bool gB_Late = false;

public Plugin myinfo = 
{
	name = "Shavit Race Mode",
	author = "Evan",
	description = "Allows players to race each other",
	version = "0.3.2"
}

public void OnPluginStart()
{
	LoadTranslations("shavit-challenge.phrases");

	RegConsoleCmd("sm_challenge", Client_Challenge, "[Challenge] allows you to start a race against others");
	RegConsoleCmd("sm_race", Client_Challenge, "[Challenge] allows you to start a race against others");
	RegConsoleCmd("sm_accept", Client_Accept, "[Challenge] allows you to accept a challenge request");
	RegConsoleCmd("sm_surrender", Client_Surrender, "[Challenge] surrender your current challenge");
	RegConsoleCmd("sm_abort", Client_Abort, "[Challenge] abort your current challenge");
	
	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gB_Late = late;

	return APLRes_Success;
}

public void OnClientPutInServer(int client)
{
	GetClientAuthId(client, AuthId_Steam2, gS_SteamID[client], MAX_NAME_LENGTH, true);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			gB_Challenge[i] = false;
			gB_Challenge_Request[i] = false;	
		}
	}
}

public Action Client_Challenge(int client, int args)
{
	if (!gB_Challenge[client] && !gB_Challenge_Request[client])
	{
		if (IsPlayerAlive(client))
		{
			char szPlayerName[MAX_NAME_LENGTH];
			Menu menu = new Menu(ChallengeMenuHandler);
			menu.SetTitle("%T\n", "ChallengeMenuTitle", client);
			int playerCount = 0;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i) && IsPlayerAlive(i) && i != client && !IsFakeClient(i))
				{
					GetClientName(i, szPlayerName, MAX_NAME_LENGTH);
					menu.AddItem(szPlayerName, szPlayerName);
					playerCount++;
				}
			}
			
			if (playerCount > 0)
			{
				menu.ExitButton = true;
				menu.Display(client, 30);
			}
			
			else
			{
				CPrintToChat(client, "%t", "ChallengeNoPlayers");
			}
		}
		
		else
		{
			CPrintToChat(client, "%t", "ChallengeInRace");
		}
	}
	
	return Plugin_Handled;
}

public int ChallengeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		char szPlayerName[MAX_NAME_LENGTH];
		char szTargetName[MAX_NAME_LENGTH];
		GetClientName(param1, szPlayerName, MAX_NAME_LENGTH);
		menu.GetItem(param2, info, sizeof(info));
		for(int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i) && i != param1)
			{
				GetClientName(i, szTargetName, MAX_NAME_LENGTH);

				if (StrEqual(info, szTargetName))
				{
					if (!gB_Challenge[i])
					{
						char szSteamId[32];
						GetClientAuthId(i, AuthId_Steam2, szSteamId, MAX_NAME_LENGTH, true);
						Format(gS_Challenge_OpponentID[param1], 32, szSteamId);
						CPrintToChat(param1, "%t", "ChallengeRequestSent", szTargetName);
						CPrintToChat(i, "%t", "ChallengeRequestReceive", szPlayerName);
						gF_Challenge_RequestTime[param1] = GetGameTime();
						CreateTimer(20.0, Timer_Request, GetClientUserId(param1));
						gB_Challenge_Request[param1] = true;
					}
					
					else
					{
						CPrintToChat(param1, "%t", "ChallengeOpponentInRace", szTargetName);
					}
				}
			}
		}
	}
	
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public Action Client_Abort(int client, int args)
{
	if (gB_Challenge[client])
	{
		if (gB_Challenge_Abort[client])
		{
			gB_Challenge_Abort[client] = false;
			CPrintToChat(client, "%t", "ChallengeDisagreeAbort");
		}
		
		else
		{
			gB_Challenge_Abort[client] = true;
			CPrintToChat(client, "%t", "ChallengeAgreeAbort");		
		}
	}
	
	return Plugin_Handled;
}

public Action Client_Accept(int client, int args)
{
	char szSteamId[32];
	GetClientAuthId(client, AuthId_Steam2, szSteamId, MAX_NAME_LENGTH, true);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && i != client && gB_Challenge_Request[i])
		{
			if (StrEqual(szSteamId, gS_Challenge_OpponentID[i]))
			{
				GetClientAuthId(i, AuthId_Steam2, gS_Challenge_OpponentID[client], MAX_NAME_LENGTH, true);
				gB_Challenge_Request[i] = false;
				
				gB_Challenge[i] = true;
				gB_Challenge[client] = true;
				
				gB_Challenge_Abort[client] = false;
				gB_Challenge_Abort[i] = false;

				Shavit_ChangeClientStyle(client, 0);
				Shavit_ChangeClientStyle(i, 0);
				
				Shavit_RestartTimer(client, Track_Main);
				Shavit_RestartTimer(i, Track_Main);
				
				SetEntityMoveType(client, MOVETYPE_NONE);
				SetEntityMoveType(i, MOVETYPE_NONE);
				
				Shavit_StopTimer(client);
				Shavit_StopTimer(i);
				
				gI_CountdownTime[i] = 10;
				gI_CountdownTime[client] = 10;
				
				CreateTimer(1.0, Timer_Countdown, i, TIMER_REPEAT);
				CreateTimer(1.0, Timer_Countdown, client, TIMER_REPEAT);
				
				CPrintToChat(client, "%t", "ChallengeAccept");
				CPrintToChat(i, "%t", "ChallengeAccept");
				
				char szPlayer1[MAX_NAME_LENGTH];
				char szPlayer2[MAX_NAME_LENGTH];
				
				GetClientName(i, szPlayer1, MAX_NAME_LENGTH);
				GetClientName(client, szPlayer2, MAX_NAME_LENGTH);

				CPrintToChatAll("%t", "ChallengeAnnounce", szPlayer1, szPlayer2);
				
				CreateTimer(1.0, CheckChallenge, i, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
				CreateTimer(1.0, CheckChallenge, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Client_Surrender(int client, int args)
{
	char szSteamIdOpponent[32];
	char szNameOpponent[MAX_NAME_LENGTH];
	char szName[MAX_NAME_LENGTH];
	if (gB_Challenge[client])
	{
		GetClientName(client, szName, MAX_NAME_LENGTH);
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != client)
			{
				GetClientAuthId(i, AuthId_Steam2, szSteamIdOpponent, MAX_NAME_LENGTH, true);
				if (StrEqual(szSteamIdOpponent, gS_Challenge_OpponentID[client]))
				{
					GetClientName(i, szNameOpponent, MAX_NAME_LENGTH);
					gB_Challenge[i] = false;
					gB_Challenge[client] = false;

					for (int j = 1; j <= MaxClients; j++)
					{
						if (IsValidClient(j) && IsValidEntity(j))
						{
							CPrintToChat(j, "%t", "ChallengeSurrenderAnnounce", szNameOpponent, szName);
						}
					}

					SetEntityMoveType(client, MOVETYPE_WALK);
					SetEntityMoveType(i, MOVETYPE_WALK);
					
					i = MaxClients + 1;
				}
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Timer_Countdown(Handle timer, any client)
{		
	if (IsValidClient(client) && gB_Challenge[client] && !IsFakeClient(client))
	{
		CPrintToChat(client, "%t", "ChallengeCountdown", gI_CountdownTime[client]);
		gI_CountdownTime[client]--;
		
		if (gI_CountdownTime[client] < 1)
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
			CPrintToChat(client, "%t", "ChallengeStarted1");
			CPrintToChat(client, "%t", "ChallengeStarted2");
			CPrintToChat(client, "%t", "ChallengeStarted3");
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_Request(Handle timer, any data)
{	
	int client = GetClientOfUserId(data);
	
	if(!gB_Challenge[client])
	{
		CPrintToChat(client, "%t", "ChallengeExpire");
		gB_Challenge_Request[client] = false;
	}
}

public Action CheckChallenge(Handle timer, any client)
{
	bool oppenent = false;
	char szName[32];
	char szNameTarget[32];
	if (gB_Challenge[client] && IsValidClient(client) && !IsFakeClient(client))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != client)
			{
				if (StrEqual(gS_SteamID[i], gS_Challenge_OpponentID[client]))
				{
					oppenent = true;
					if (gB_Challenge_Abort[i] && gB_Challenge_Abort[client])
					{
						GetClientName(i, szNameTarget, 32);
						GetClientName(client, szName, 32);
						
						gB_Challenge[client] = false;
						gB_Challenge[i] = false;
						
						CPrintToChat(client, "%t", "ChallengeAborted", szNameTarget);
						CPrintToChat(i, "%t", "ChallengeAborted", szName);
						
						SetEntityMoveType(client, MOVETYPE_WALK);
						SetEntityMoveType(i, MOVETYPE_WALK);
					}
				}
			}
		}
		
		if (!oppenent)
		{
			gB_Challenge[client] = false;

			if (IsValidClient(client))
			{
				CPrintToChat(client, "%t", "ChallengeWon", client);
			}
			
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

public void Shavit_OnFinish(int client, int track)
{
	if(gB_Challenge[client] && (track = Track_Main))
	{
		char szNameOpponent[MAX_NAME_LENGTH];
		char szName[MAX_NAME_LENGTH];
		GetClientName(client, szName, MAX_NAME_LENGTH);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != client)
			{
				if (StrEqual(gS_SteamID[i], gS_Challenge_OpponentID[client]))
				{
					gB_Challenge[client] = false;
					gB_Challenge[i] = false;
					GetClientName(i, szNameOpponent, MAX_NAME_LENGTH);
					for (int k = 1; k <= MaxClients; k++)
					{
						if (IsValidClient(k))
						{
							CPrintToChat(k, "%t", "ChallengeFinishAnnounce", szName, szNameOpponent);
						}
					}
					
					break;
				}
			}
		}
	}
}