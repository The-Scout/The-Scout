--FTD Smart Missile Guidance System
--Author: 6dwavenminer
--Version: 1.1


--User Config Variables

--Launcher vehicle variables
MainFrameID = 0; --Which MainFrame to connect to
WeaponID = 0;
MaxDistanceBetweenLuaTranscieverAndMissileControl = 20; --The maximum distnace between a lua transciever and its corrisponding missile control block.

--Missile variables
IsATorpedo = FALSE; --'false' priotities going to target positions from below, 'true' priotities going to target positions from above.

--Target acquisition variables
MaxRange = 4000; --Targets above this range from the missile launcher will be ignored.
MaxTargetHeight = 10000; --Targets above this height will be ignored.
MinTargetHeight = -20; --Targets below this range will be ignored.

--Safe detonation variables
SafeDetonteAltitude = 500; --If there are no target, goto and detonte at this altitude.

--Cruising variables
DirectEngagementGroundRange = 200000; --Below this ground range to target, head directly to target.
CruisingAltitude = 0; --While en route travel at this altitude.
CruisingAltitudeAboveTerrain = 0; --If terrain nears cruising altitude, travel this heigh above the terrain.
MaxAllowedCruisingAltitude = 10000; --Missile will try and aviod going above this altitude
MinAllowedCruisingAltitude = 0; --Missile will try and aviod going below this altitude

--Anti ally collsion variables
AntiAlliedCollisionPredictionTimeLimit = 8; --Used to prevent missile-allied vessel collisions, number is seconds into the future predicted.
AntiAlliedCollisionPredictionTimeStep = 1; --The time step in seconds used to prevent missile-allied vessel collisions.
AntiAlliedCollisionAdditionalSafetyRange = 5; --Additional range to border of allies to avoid.

--End of User Config Variables

--Global Variables
TargetVelocityArray = {};
PreviousTime = 0;
UseableLuaTransceiverList = {};
UseableLuaTransceiverCount = 0;

function GetUseableLuaTranscivers(I)
 MissileLauncherPos = I:GetWeaponInfo(WeaponID).GlobalPosition;
 UseableLuaTransceiverCount = 0;
 for t=0, I:GetLuaTransceiverCount()-1 do
  if Vector3.Distance(MissileLauncherPos,I:GetLuaTransceiverInfo(t).Position) < MaxDistanceBetweenLuaTranscieverAndMissileControl then
   UseableLuaTransceiverList[UseableLuaTransceiverCount] = t;
   UseableLuaTransceiverCount = UseableLuaTransceiverCount + 1;
  end
 end
end

--Check that the WeaponID corrisponds to a missile launcher
function WeaponsCheck(I)
 if I:GetWeaponInfo(WeaponID).Valid == false then
  I:LogToHud("Invalid WeaponID, change WeaponID in LUA code"); 
 else
  if I:GetWeaponInfo(WeaponID).WeaponType == 4 then --Turret check
   if not I:GetWeaponInfoOnTurretOrSpinner(WeaponID, 0).WeaponType == 5 then --Weapons check, is it a missile launcher?
    I:LogToHud("Weapon is not missile launcher, change WeaponID in LUA code, note this weapon is on a turret or spinner,further debugging maybe required"); 
   else
    GetUseableLuaTranscivers(I);
   end
  else
   if not I:GetWeaponInfo(WeaponID).WeaponType == 5 then --Weapons check, is it a missile launcher?
    I:LogToHud("Weapon is not missile launcher, change WeaponID in LUA code"); 
   else
    GetUseableLuaTranscivers(I);
   end
  end
 end
end

--Creates a list of all targets within range
function GenerateTargetList(I)
 OutputBuffer = {};
 TargetIDList = {};
 NumTargets = 0;
 for n=0,I:GetNumberOfTargets(MainFrameID)-1 do
  TargetPos = I:GetTargetInfo(MainFrameID,n).AimPointPosition;
  TargetRange = Vector3.Distance(I:GetWeaponInfo(WeaponID).GlobalPosition,TargetPos);
  if (TargetRange < MaxRange) and (TargetPos.y < MaxTargetHeight) and (TargetPos.y > MinTargetHeight) then
   TargetIDList[NumTargets] = n;
   NumTargets = NumTargets + 1;
  end
 end
 
 
 OutputBuffer[0] = NumTargets;
 for n=1, NumTargets do
  OutputBuffer[n] = TargetIDList[n -1];
 end

 --return NumTargets,TargetIDList;
 return OutputBuffer;
end

--If theres no targets go up to safe distance to detonte the missle
function NoTargetSafelyDetonte(I)
 --for t=0, I:GetLuaTransceiverCount()-1 do
 for i=0, UseableLuaTransceiverCount-1 do
  t=UseableLuaTransceiverList[i];
  for m=0, I:GetLuaControlledMissileCount(t)-1 do
   Missile = I:GetLuaControlledMissileInfo(t,m);
   MissilePos = Missile.Position;
   AimPoint = Vector3(MissilePos.x,SafeDetonteAltitude + 10,MissilePos.z);
   AimPoint = AllyCollisionAviodance(I,Missile,MissilePos,AimPoint);
   I:SetLuaControlledMissileAimPoint(t,m,AimPoint.x, AimPoint.y, AimPoint.z);
   if ((MissilePos.y > SafeDetonteAltitude) and (IsATorpedo == false)) or ((MissilePos.y < SafeDetonteAltitude) and (IsATorpedo == true)) then ---------------------------
    I:DetonateLuaControlledMissile(t,m);
   end
  end
 end
end

function CountActiveMissiles(I)
 NumMissiles = 0;
 --for t=0, I:GetLuaTransceiverCount()-1 do
 for i=0, UseableLuaTransceiverCount-1 do
 t=UseableLuaTransceiverList[i];
  for m=0, I:GetLuaControlledMissileCount(t)-1 do
   NumMissiles = NumMissiles + 1;
  end
 end
 return NumMissiles;
end

function CalculateEnemyFleetScore(I,NumTargets,TargetIDList)
 --Find lowest enemy score
 EnemyFleetTotalScore = 0;
 LowestScore = 100000;
 for n=0, NumTargets-1, 1 do
  if (I:GetTargetInfo(MainFrameID,TargetIDList[n]).Score) < LowestScore then
   LowestScore = I:GetTargetInfo(MainFrameID,TargetIDList[n]).Score;
  end
 end
 
 --Calculate score offset
 ScoreOffset = -100000;
 for n=0, NumTargets-1, 1 do
  if (I:GetTargetInfo(MainFrameID,TargetIDList[n]).Score) > ScoreOffset then
   ScoreOffset = I:GetTargetInfo(MainFrameID,TargetIDList[n]).Score;
  end
 end
 ScoreOffset = ScoreOffset / 2;
 ScoreOffset = ScoreOffset - LowestScore;

 --Calculate enemy fleet score
 for n=0, NumTargets-1, 1 do
  EnemyFleetTotalScore = EnemyFleetTotalScore + I:GetTargetInfo(MainFrameID,TargetIDList[n]).Score + ScoreOffset;
 end
 return EnemyFleetTotalScore,ScoreOffset;
end


--Calculate how many to missiles each target
function CalculateMissilesPerTarget(I,NumTargets,TargetIDList,NumMissiles,EnemyFleetTotalScore,ScoreOffset)
 MissilesPerTarget = {};
 for n=0, NumTargets-1, 1 do
  if NumTargets == 1 then
   MissilesPerTarget[n] = NumMissiles;
  else
   MissilesPerTarget[n] = ((I:GetTargetInfo(MainFrameID,TargetIDList[n]).Score + ScoreOffset) / EnemyFleetTotalScore) * NumMissiles;
   MissilesPerTarget[n] = math.floor(MissilesPerTarget[n] + 0.5);
  end
 end
 return MissilesPerTarget;
end

 --Calculate acceleration of enemy targets
function CalculateAccelerationOfTargets(I,NumTargets,TargetIDList)
 for n=0, NumTargets-1 do
  if TargetVelocityArray[TargetIDList[n]] == nil then
   Target = I:GetTargetInfo(MainFrameID,TargetIDList[n]);
   TargetVelocityArray[TargetIDList[n]] = Target.Velocity;
  else
   Target = I:GetTargetInfo(MainFrameID,TargetIDList[n]);
   TargetAcceleration = (Target.Velocity - TargetVelocityArray[TargetIDList[n]]) / (I:GetTime() - PreviousTime);
   TargetVelocityArray[TargetIDList[n]] = Target.Velocity;
  end
 end
 PreviousTime = I:GetTime() 
 return TargetAcceleration;
end

function AssignTargetForMissile(I,NumTargets,TargetNum,MissileNum,MissilesPerTarget)
 --Increment MissileID
 MissileNum = MissileNum + 1;
 if MissileNum > MissilesPerTarget[TargetNum] then
  if TargetNum < NumTargets - 1 then 
   TargetNum = TargetNum + 1;
   MissileNum = 0;
  end
 end
 return TargetNum,MissileNum
end

--Calculate distance ignoring vertical component
function CalculateGroundDistanceToTarget(I,t,m,TargetNum)
  TwoDMissilePos = I:GetLuaControlledMissileInfo(t,m).Position;
  TwoDTargetPos =  I:GetTargetInfo(MainFrameID,TargetNum).Position;
  TwoDMissilePos.y = 0;
  TwoDTargetPos.y = 0;
  GroundDistanceToTarget = Vector3.Distance(TwoDMissilePos,TwoDTargetPos);
  return GroundDistanceToTarget;
end

--En route go to attlitude till near target
function TravelTowardsTarget(I,t,m,MissileHeightAboveTerrain,MissilePos,TargetPos)
 CruisingHeight = CruisingAltitude;
 if MissileHeightAboveTerrain > CruisingAltitude - 20 then
  CruisingHeight = MissileHeightAboveTerrain + CruisingAltitudeAboveTerrain;
 end
 if ((MissilePos.y < CruisingHeight) and (IsATorpedo == false)) or ((MissilePos.y > CruisingHeight) and (IsATorpedo == true)) then ---------------------------
  --Get to the correct height
  I:SetLuaControlledMissileAimPoint(t,m,MissilePos.x, CruisingHeight+1, MissilePos.z);
  AimPoint = Vector3(MissilePos.x, CruisingHeight+1, MissilePos.z);
 else
  --Now head to target
  --I:SetLuaControlledMissileAimPoint(t,m,TargetPos.x, CruisingHeight, TargetPos.z);
  AimPoint = Vector3(TargetPos.x, CruisingHeight, TargetPos.z);
 end 
 return AimPoint;
end

function PredictInterceptPosition(I,t,m,MissilePos,TargetPos,MissileSpeed,TargetSpeed,TargetVelocity,TargetAcceleration)
 Range = Vector3.Distance(MissilePos,TargetPos);
 MinInterceptionTime = Range / (MissileSpeed + TargetSpeed);
 InterceptionAimPos = TargetPos + (TargetVelocity * MinInterceptionTime);
 for i=0, 12 do
  IntecpetionRange = Vector3.Distance(MissilePos,InterceptionAimPos);
  IntecpetionTime = IntecpetionRange / MissileSpeed;
  InterceptionAimPos = TargetPos + (TargetVelocity * IntecpetionTime) + (TargetAcceleration * 0.5 *(IntecpetionTime * IntecpetionTime));
 end 
 AimPoint = Vector3(InterceptionAimPos.x,InterceptionAimPos.y,InterceptionAimPos.z);
 return AimPoint;
end

--Checks missiles curret appoximate trajectory for any possible collisions with predicted allied postions and attempts to aviod them
function AllyCollisionAviodance(I,Missile,MissilePos,AimPoint)
 --Find all possible allied collsions
 AlliedCollsionTimeArray = {};
 AlliedCollsionFriendlyIndexArray = {};
 NearestTimeCollsion = AntiAlliedCollisionPredictionTimeLimit;
 NumOfPossibleAlliedCollision = 0;
 NumOfFriendlies = I:GetFriendlyCount();
 MissileSpeed = Vector3.Magnitude(Missile.Velocity);
 for n=0, NumOfFriendlies-1 do
  FriendlyInfo = I:GetFriendlyInfo(n);
  if FriendlyInfo.Valid == true then
   MissileTimeToReachAimPos = Vector3.Distance(MissilePos,AimPoint) / MissileSpeed;
   for t=0, AntiAlliedCollisionPredictionTimeLimit-1,AntiAlliedCollisionPredictionTimeStep do
    if MissileTimeToReachAimPos > t then --Don't care is the ally is behind the enemy target
     MissileFuturePos = MissilePos + ((AimPoint - MissilePos) / t); 
	 FutureAllyReferencePosition = FriendlyInfo.ReferencePosition + (FriendlyInfo.Velocity * t);
	 FutureAllyReferencePositionPositiveSize = FutureAllyReferencePosition + FriendlyInfo.PositiveSize + Vector3(AntiAlliedCollisionAdditionalSafetyRange,AntiAlliedCollisionAdditionalSafetyRange,AntiAlliedCollisionAdditionalSafetyRange);
     FutureAllyReferencePositionNegativeSize = FutureAllyReferencePosition + FriendlyInfo.NegativeSize - Vector3(AntiAlliedCollisionAdditionalSafetyRange,AntiAlliedCollisionAdditionalSafetyRange,AntiAlliedCollisionAdditionalSafetyRange);
	 if  (MissileFuturePos.x <= FutureAllyReferencePositionPositiveSize.x)
	 and (MissileFuturePos.x >= FutureAllyReferencePositionNegativeSize.x)
	 and (MissileFuturePos.y <= FutureAllyReferencePositionPositiveSize.y)
	 and (MissileFuturePos.y >= FutureAllyReferencePositionNegativeSize.y)
     and (MissileFuturePos.z <= FutureAllyReferencePositionPositiveSize.z)
 	 and (MissileFuturePos.z >= FutureAllyReferencePositionNegativeSize.z)
	 then
	  --Will probably collide with ally, record time and friendly Index
	  if t < NearestTimeCollsion then
	   NearestTimeCollsion = t;
	  end
	  AlliedCollsionTimeArray[0] = t;
	  AlliedCollsionFriendlyIndexArray[0] = n;
	  NumOfPossibleAlliedCollision = NumOfPossibleAlliedCollision + 1;
	  break
     end
    end
   end
  end
 end

 --Calculate where the missile can't go 
 PositiveAviodCoOrdinates = Vector3(-100000,100000,-100000);
 NegativeAviodCoOrdinates = Vector3(100000,100000,100000);
 for n=0, NumOfPossibleAlliedCollision-1 do
  t = AlliedCollsionTimeArray[n];
  if NearestTimeCollsion == t then --Only care about the nearest time possible collsions
   FriendlyInfo = I:GetFriendlyInfo(n);
  
   FutureAllyReferencePosition = FriendlyInfo.ReferencePosition + (FriendlyInfo.Velocity * t);
   FutureAllyReferencePositionPositiveSize = FutureAllyReferencePosition + FriendlyInfo.PositiveSize + Vector3(AntiAlliedCollisionAdditionalSafetyRange,AntiAlliedCollisionAdditionalSafetyRange,AntiAlliedCollisionAdditionalSafetyRange);
   FutureAllyReferencePositionNegativeSize = FutureAllyReferencePosition + FriendlyInfo.NegativeSize - Vector3(AntiAlliedCollisionAdditionalSafetyRange,AntiAlliedCollisionAdditionalSafetyRange,AntiAlliedCollisionAdditionalSafetyRange);
  
   if (PositiveAviodCoOrdinates.x <= FutureAllyReferencePositionPositiveSize.x) then
    PositiveAviodCoOrdinates.x = FutureAllyReferencePositionPositiveSize.x;
   end
   if (NegativeAviodCoOrdinates.x >= FutureAllyReferencePositionPositiveSize.x) then
    NegativeAviodCoOrdinates.x = FutureAllyReferencePositionNegativeSize.x;
   end
   if (PositiveAviodCoOrdinates.y <= FutureAllyReferencePositionPositiveSize.y) then
    PositiveAviodCoOrdinates.y = FutureAllyReferencePositionPositiveSize.y;
   end
   if (NegativeAviodCoOrdinates.y >= FutureAllyReferencePositionPositiveSize.y) then
    NegativeAviodCoOrdinates.y = FutureAllyReferencePositionNegativeSize.y;
   end
   if (PositiveAviodCoOrdinates.z <= FutureAllyReferencePositionPositiveSize.z) then
    PositiveAviodCoOrdinates.z = FutureAllyReferencePositionPositiveSize.z;
   end
   if (NegativeAviodCoOrdinates.z >= FutureAllyReferencePositionPositiveSize.z) then
    NegativeAviodCoOrdinates.z = FutureAllyReferencePositionNegativeSize.z;
   end
  end
 end

 --Find the nearest non-collsion point while trying to maintain route to target
 if NumOfPossibleAlliedCollision > 0 then
  MissileFutureCollisionPos = MissilePos + ((AimPoint - MissilePos) / NearestTimeCollsion); 
  PositiveEvadeDistance = Vector3.Magnitude(MissileFutureCollisionPos - PositiveAviodCoOrdinates);
  NegativeEvadeDistance = Vector3.Magnitude(MissileFutureCollisionPos - NegativeAviodCoOrdinates);
  --Now we try and steer the missile away from the possible collisions
  if PositiveEvadeDistance < NegativeEvadeDistance  then
   AimPoint = PositiveAviodCoOrdinates;
   if PositiveEvadeDistance.y > MaxAllowedCruisingAltitude then
    AimPoint.y = MaxAllowedCruisingAltitude.y;
   end
  else
   AimPoint = NegativeAviodCoOrdinates;
   if NegativeAviodCoOrdinates.y < MinAllowedCruisingAltitude then
    AimPoint.y = MinAllowedCruisingAltitude.y;
   else
   end
  end
 end
 return AimPoint;
end

--MinAllowedCruisingAltitude
--MaxAllowedCruisingAltitude

--Main
function Update(I)
--Startup
WeaponsCheck(I);
TargetListBuffer = {};
TargetIDList = {};
TargetListBuffer = unpack{GenerateTargetList(I)};
NumTargets = TargetListBuffer[0];
if NumTargets > 0 then
 for n=0, NumTargets-1 do
  TargetIDList[n] = TargetListBuffer[n+1];
 end 
end      

NumMissiles = 0;
EnemyFleetTotalScore = 0;
MissilesPerTarget = {};
ScoreOffset = 0;

if NumTargets<=0 then
 NoTargetSafelyDetonte(I);
else
 NumMissiles = CountActiveMissiles(I);
 EnemyFleetTotalScore,ScoreOffset = unpack{CalculateEnemyFleetScore(I,NumTargets,TargetIDList)};
 MissilesPerTarget = CalculateMissilesPerTarget(I,NumTargets,TargetIDList,NumMissiles,EnemyFleetTotalScore,ScoreOffset);
 
 TargetAcceleration = CalculateAccelerationOfTargets(I,NumTargets,TargetIDList);
 
 MissileNum = 0;
 TargetNum = 0;
  
  --for t=0, I:GetLuaTransceiverCount()-1 do
  for i=0, UseableLuaTransceiverCount-1 do
   t=UseableLuaTransceiverList[i];
   for m=0, I:GetLuaControlledMissileCount(t)-1 do
    TargetNum,MissileNum = unpack{AssignTargetForMissile(I,NumTargets,TargetNum,MissileNum,MissilesPerTarget)};
    TargetAcceleration = Vector3(0,0,0);
    Target = I:GetTargetInfo(MainFrameID,TargetNum);
    TargetPos = Target.AimPointPosition;
    TargetVelocity = Target.Velocity;
    TargetSpeed = Vector3.Magnitude(TargetVelocity);
   
    Missile = I:GetLuaControlledMissileInfo(t,m);
    MissilePos = Missile.Position;
    MissileSpeed = Vector3.Magnitude(Missile.Velocity);
    MissileHeightAboveTerrain = I:GetTerrainAltitudeForPosition(MissilePos);
    if MissileHeightAboveTerrain < 0 then 
     MissileHeightAboveTerrain = 0;
    end 

    GroundDistanceToTarget = CalculateGroundDistanceToTarget(I,t,m,TargetNum);
    if GroundDistanceToTarget > DirectEngagementGroundRange then
     AimPoint = TravelTowardsTarget(I,t,m,MissileHeightAboveTerrain,MissilePos,TargetPos);
    else
     AimPoint = PredictInterceptPosition(I,t,m,MissilePos,TargetPos,MissileSpeed,TargetSpeed,TargetVelocity,TargetAcceleration);
    end
	--Check to make sure we don't blow up any allies
	AimPoint = AllyCollisionAviodance(I,Missile,MissilePos,AimPoint);
	--Now aim at target
	I:SetLuaControlledMissileAimPoint(t,m,AimPoint.x,AimPoint.y,AimPoint.z);


   end
  end
 end
end
