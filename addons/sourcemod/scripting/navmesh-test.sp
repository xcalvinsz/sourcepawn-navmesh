#include <sourcemod>
#include <sdktools>
#include <profiler>
#include <navmesh>

#define PLUGIN_VERSION "1.0.0"

public Plugin:myinfo = 
{
    name = "SP-Readable Navigation Mesh Test",
    author	= "KitRifty",
    description	= "Testing plugin of the SP-Readable Navigation Mesh plugin.",
    version = PLUGIN_VERSION,
    url = ""
}

public OnPluginStart()
{
	RegConsoleCmd("sm_navmesh_collectsurroundingareas", Command_NavMeshCollectSurroundingAreas);
	RegConsoleCmd("sm_navmesh_buildpath", Command_NavMeshBuildPath);
	RegConsoleCmd("sm_navmesh_getnearestarea", Command_GetNearestArea);
	RegConsoleCmd("sm_navmesh_getadjacentareas", Command_GetAdjacentNavAreas);
}

public Action:Command_GetNearestArea(client, args)
{
	if (!NavMesh_Exists()) return Plugin_Handled;

	decl Float:flEyePos[3], Float:flEyeDir[3], Float:flEndPos[3];
	GetClientEyePosition(client, flEyePos);
	GetClientEyeAngles(client, flEyeDir);
	GetAngleVectors(flEyeDir, flEyeDir, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(flEyeDir, flEyeDir);
	ScaleVector(flEyeDir, 1000.0);
	AddVectors(flEyePos, flEyeDir, flEndPos);
	
	new Handle:hTrace = TR_TraceRayFilterEx(flEyePos,
		flEndPos,
		MASK_PLAYERSOLID_BRUSHONLY,
		RayType_EndPoint,
		TraceRayDontHitEntity,
		client);
	
	TR_GetEndPosition(flEndPos, hTrace);
	CloseHandle(hTrace);
	
	new iAreaIndex = NavMesh_GetNearestArea(flEndPos);
	new Handle:hAreas = NavMesh_GetAreas();
	new iAreaID = GetArrayCell(hAreas, iAreaIndex, NavMeshArea_ID);
	
	PrintToChat(client, "Nearest area ID: %d", iAreaID);
	
	return Plugin_Handled;
}

public Action:Command_GetAdjacentNavAreas(client, args)
{
	if (!NavMesh_Exists()) return Plugin_Handled;
	
	if (args < 2)
	{
		ReplyToCommand(client, "Usage: sm_navmesh_getadjacentareas <area ID>");
		return Plugin_Handled;
	}
	
	new Handle:hAreas = NavMesh_GetAreas();
	if (hAreas == INVALID_HANDLE) return Plugin_Handled;
	
	decl String:sAreaID[64];
	GetCmdArg(1, sAreaID, sizeof(sAreaID));
	
	new iAreaID = StringToInt(sAreaID);
	
	new iStartAreaIndex = FindValueInArray(hAreas, iAreaID);
	if (iStartAreaIndex == -1) return Plugin_Handled;
	
	decl String:sNavDirection[64];
	GetCmdArg(2, sNavDirection, sizeof(sNavDirection));
	
	new iNavDirection = StringToInt(sNavDirection);
	if (iNavDirection >= NAV_DIR_COUNT)
	{
		ReplyToCommand(client, "Invalid direction! Direction cannot reach %d!", NAV_DIR_COUNT);
		return Plugin_Handled;
	}
	
	new Handle:hAdjacentAreas = NavMeshArea_GetAdjacentList(iStartAreaIndex, iNavDirection);
	if (hAdjacentAreas != INVALID_HANDLE && !IsStackEmpty(hAdjacentAreas))
	{
		while (!IsStackEmpty(hAdjacentAreas))
		{
			new iAreaIndex = -1;
			PopStackCell(hAdjacentAreas, iAreaIndex);
			PrintToChat(client, "Found adjacent area (ID: %d) for area ID %d", GetArrayCell(hAreas, iAreaIndex), iAreaID);
		}
		
		CloseHandle(hAdjacentAreas);
	}
	else
	{
		if (hAdjacentAreas != INVALID_HANDLE) CloseHandle(hAdjacentAreas);
		
		PrintToChat(client, "Found no adjacent areas for area ID %d", iAreaID);
	}
	
	return Plugin_Handled;
}

public Action:Command_NavMeshCollectSurroundingAreas(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "Usage: sm_navmesh_collectsurroundingareas <area ID> <max dist>");
		return Plugin_Handled;
	}
	
	if (!NavMesh_Exists()) return Plugin_Handled;
	
	new Handle:hAreas = NavMesh_GetAreas();
	if (hAreas == INVALID_HANDLE) return Plugin_Handled;
	
	decl String:sAreaID[64];
	GetCmdArg(1, sAreaID, sizeof(sAreaID));
	
	new iAreaIndex = FindValueInArray(hAreas, StringToInt(sAreaID));
	
	if (iAreaIndex == -1 || iAreaIndex == -1) return Plugin_Handled;
	
	decl String:sMaxDist[64];
	GetCmdArg(2, sMaxDist, sizeof(sMaxDist));
	
	new Float:flMaxDist = StringToFloat(sMaxDist);
	
	new Handle:hProfiler = CreateProfiler();
	StartProfiling(hProfiler);
	
	new Handle:hNearAreas = NavMesh_CollectSurroundingAreas(iAreaIndex, flMaxDist);
	
	StopProfiling(hProfiler);
	
	new Float:flProfileTime = GetProfilerTime(hProfiler);
	
	CloseHandle(hProfiler);
	
	if (hNearAreas != INVALID_HANDLE)
	{
		new iAreaCount;
		while (!IsStackEmpty(hNearAreas))
		{
			new iSomething;
			PopStackCell(hNearAreas, iSomething);
			iAreaCount++;
		}
		
		CloseHandle(hNearAreas);
		
		if (client > 0) 
		{
			PrintToChat(client, "Collected %d areas in %f seconds.", iAreaCount, flProfileTime);
		}
		else
		{
			PrintToServer("Collected %d areas in %f seconds.", iAreaCount, flProfileTime);
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_NavMeshBuildPath(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "Usage: sm_navmesh_buildpath <start area ID> <goal area ID>");
		return Plugin_Handled;
	}
	
	if (!NavMesh_Exists()) return Plugin_Handled;
	
	new Handle:hAreas = NavMesh_GetAreas();
	if (hAreas == INVALID_HANDLE) return Plugin_Handled;
	
	decl String:sStartAreaID[64], String:sGoalAreaID[64];
	GetCmdArg(1, sStartAreaID, sizeof(sStartAreaID));
	GetCmdArg(2, sGoalAreaID, sizeof(sGoalAreaID));
	
	new iStartAreaIndex = FindValueInArray(hAreas, StringToInt(sStartAreaID));
	new iGoalAreaIndex = FindValueInArray(hAreas, StringToInt(sGoalAreaID));
	
	if (iStartAreaIndex == -1 || iGoalAreaIndex == -1) return Plugin_Handled;
	
	decl Float:flGoalPos[3];
	NavMeshArea_GetCenter(iGoalAreaIndex, flGoalPos);
	
	new iColor[4] = { 0, 255, 0, 255 };
	
	new Float:flMaxPathLength = 0.0;
	if (args > 2)
	{
		decl String:sMaxPathLength[64];
		GetCmdArg(3, sMaxPathLength, sizeof(sMaxPathLength));
		flMaxPathLength = StringToFloat(sMaxPathLength);
		
		if (flMaxPathLength < 0.0) return Plugin_Handled;
	}
	
	new iClosestAreaIndex = 0;
	
	new Handle:hProfiler = CreateProfiler();
	StartProfiling(hProfiler);
	
	new bool:bBuiltPath = NavMesh_BuildPath(iStartAreaIndex, 
		iGoalAreaIndex,
		flGoalPos,
		NavMeshShortestPathCost,
		_,
		iClosestAreaIndex,
		flMaxPathLength);
	
	StopProfiling(hProfiler);
	
	new Float:flProfileTime = GetProfilerTime(hProfiler);
	
	CloseHandle(hProfiler);
	
	if (client > 0) 
	{
		PrintToChat(client, "Path built!\nBuild path time: %f\nReached goal: %d", flProfileTime, bBuiltPath);
		
		static iModelIndex = -1;
		if (iModelIndex == -1) iModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
		
		new iTempAreaIndex = iClosestAreaIndex;
		new iParentAreaIndex = NavMeshArea_GetParent(iTempAreaIndex);
		new iNavDirection;
		new Float:flHalfWidth;
		
		decl Float:flCenterPortal[3], Float:flClosestPoint[3];
		
		while (iParentAreaIndex != -1)
		{
			decl Float:flTempAreaCenter[3], Float:flParentAreaCenter[3];
			NavMeshArea_GetCenter(iTempAreaIndex, flTempAreaCenter);
			NavMeshArea_GetCenter(iParentAreaIndex, flParentAreaCenter);
			
			iNavDirection = NavMeshArea_ComputeDirection(iTempAreaIndex, flParentAreaCenter);
			NavMeshArea_ComputePortal(iTempAreaIndex, iParentAreaIndex, iNavDirection, flCenterPortal, flHalfWidth);
			NavMeshArea_ComputeClosestPointInPortal(iTempAreaIndex, iParentAreaIndex, iNavDirection, flCenterPortal, flClosestPoint);
			
			flClosestPoint[2] = NavMeshArea_GetZ(iTempAreaIndex, flClosestPoint);
			
			/*
			TE_SetupBeamPoints(flTempAreaCenter,
				flParentAreaCenter,
				iModelIndex,
				iModelIndex,
				0,
				30,
				5.0,
				5.0,
				5.0,
				5, 
				0.0,
				iColor,
				30);
			*/
			
			TE_SetupSparks(flClosestPoint, Float:{ -90.0, 0.0, 0.0 }, 5, 5);
			TE_SendToClient(client);
			
			PrintToChat(client, "Connected ID: %d (%f %f %f)", iParentAreaIndex, flClosestPoint[0], flClosestPoint[1], flClosestPoint[2]);
			
			iTempAreaIndex = iParentAreaIndex;
			iParentAreaIndex = NavMeshArea_GetParent(iTempAreaIndex);
		}
	}
	else 
	{
		PrintToServer("Path built!\nBuild path time: %f\nReached goal: %d", flProfileTime, bBuiltPath);
	}
	
	return Plugin_Handled;
}

public bool:TraceRayDontHitEntity(entity, mask, any:data)
{
	if (entity == data) return false;
	return true;
}