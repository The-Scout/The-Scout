-- Generated from ZerothAngel's FtDScripts version 9931cbd8d954
-- Modules: generalmissilemain, generalmissile, missilecommand, clamp, sign, deepcopy, round, getvectorangle, quadraticintercept, quadraticsolver, missiledriver, weapontypes, commonsweapons, commonstargets, commonsmainframe, componenttypes, namedcomponent, periodic, commons, shallowcopy

-- MIT licensed. See https://github.com/ZerothAngel/FtDScripts for raw code.

-- !!! Leading whitespace stripped to save bytes !!!

-- If you only have a single missile system on your vehicle, this script
-- is fine. But if you have more than one (e.g. anti-air & torpedoes),
-- look at my "multiprofile" script instead. It's a wrapper around this one.

-- CONFIGURATION

-- Generally these should match the settings on your Local Weapon Controller.
-- It will prevent locking onto high-priority targets that are farther
-- than your missiles' max range or re-locking onto targets your missiles
-- can't hit (e.g. torpedoes re-locking onto air targets).
Limits = {
   MinRange = 0,
   MaxRange = 2500,
   MinAltitude = -500,
   MaxAltitude = 9999,
}
-- Optional weapon slot to fire. If non-nil then an LWC is not needed.
-- However, script-fired weapons aren't governed by failsafes, so keep
-- that in mind...
-- Missile controllers on turrets should be assigned the same weapon slot
-- as their turret block.
MissileWeaponSlot = nil

-- Target selection algorithm for newly-launched missiles.
-- 1 = Focus on highest priority target
-- 2 = Pseudo-random split against all targetable targets
MissileTargetSelector = 2

-- See https://github.com/ZerothAngel/FtDScripts/blob/master/missile/generalmissile.md
Config = {
   MinAltitude = 0,
   DetonationRange = nil,
   DetonationAngle = 30,
   LookAheadTime = 2,
   LookAheadResolution = 3,

   AirProfileElevation = 10,
   AntiAir = {
      Phases = {
         {
         },
      },
   },

   Phases = {
      {
         -- Terminal phase
         Distance = 350,
         -- Uncomment the following (the "Change" line) to adjust variable
         -- thrusters for max burn once heading within 10 degrees of aim point.
         -- Recommend you set default thrust in other phases as well (see below).
--         Change = { When = { Angle = 10, }, Thrust = -1, },
      },
      {
         -- Middle phase: hold current altitude
         Distance = 650,
         AboveSeaLevel = true,
         MinElevation = 3,
         Altitude = 0,
         RelativeTo = 4,
         -- Uncomment the following to set default thrust to 1000 (or whatever)
--         Change = { Thrust = 1000, },
      },
      {
         -- Closing phase: climb to 300m absolute
         Distance = 50,
         AboveSeaLevel = true,
         MinElevation = 3,
         Altitude = 300,
         RelativeTo = 0,
         -- Uncomment the following to set default thrust to 300 (or whatever)
--         Change = { Thrust = 300, },
      },
   },
}

-- MISSILE DRIVER SETTINGS

-- Detonate after this many seconds of being out of combat.
-- Set to some large number (e.g. 999) to disable.
DetonateAfter = 10

-- Reset/clear the transceiver cache every so often.
-- Set to some large number (e.g. 9999) to disable.
-- This is mainly important for any scripts that use GetLuaTransceiverInfo
-- to select a guidance instance, such as multiprofile. This is because
-- damage may knock out a launchpad (which is what is normally returned)
-- and instead return the transceiver BlockInfo, which may ultimately lead
-- to a different selection.
TransceiverResetInterval = 1

-- COMMONS TARGETING SETTINGS

CommonsTargetConfig = {
   -- Preferred mainframe indexes for target priority.
   -- Once a mainframe is successfully queried, the rest are ignored.
   -- First mainframe (in "C" screen) = 0, 2nd = 1, etc.
   -- The last one in the list should always be 0.
   -- For example, to query the 2nd, 3rd, and 1st (in that order), set
   -- to { 1, 2, 0 }
   -- Can also use mainframe names (as strings), for example
   -- { "Main", "Backup", 0 }
   PreferredTargetMainframes = { 0 },

   -- Maximum range for an enemy to still be considered a threat.
   MaxEnemyRange = 10000,
}

-- COMPONENT TYPES (don't change)

-- luacheck: push ignore 131
BALLOON = 0 -- boolean
DRIVEMAINTAINER = 1 -- float
AIRPUMP = 2 -- float/bool
RESOURCEGATHERER = 3 -- boolean
OILDRILL = 4 -- boolean
AMMOPROCESSOR = 5 -- boolean
OILPROCESSOR = 6 -- boolean
TRACTORBEAM = 7 -- boolean
HYDROFOIL = 8 -- float
PROPULSION = 9 -- float
SHIELDPROJECTOR = 10 -- float/int
HELIUMPUMP = 11 -- float/bool
MAINFRAME = 26
-- luacheck: pop

-- WEAPON TYPES (don't change)

-- luacheck: push ignore 131
CANNON = 0
MISSILE = 1
LASER = 2
HARPOON = 3
TURRET = 4
MISSILECONTROL = 5
FIRECONTROLCOMPUTER = 6
-- luacheck: pop

-- MISSILE CONSTANTS

-- luacheck: push ignore 131
MissileConst_VarThrust = "Variable Thruster"
MissileConst_FuelTank = "Fuel Tank"
MissileConst_FuelAmount = 12500
MissileConst_Regulator = "Regulator"
MissileConst_LifetimeStart = 20 -- Is this really constant?
MissileConst_LifetimeAdd = 20
MissileConst_ShortRange = "Short Range Thruster"
MissileConst_ShortRangeFuelRate = 6000
MissileConst_Magnet = "Magnet (for mines)"
MissileConst_BallastTank = "Ballast Tanks"

MissileUpdateData = {
   {
      MissileConst_VarThrust,
      {
         VarThrust = { 2, 300, 3000 },
      },
   },
   {
      MissileConst_ShortRange,
      {
         ThrustDelay = { 1, 0, 20 },
         ThrustDuration = { 2, .1, 5 },
      },
   },
   {
      MissileConst_Magnet,
      {
         MagnetRange = { 1, 5, 200 },
         MagnetDelay = { 2, 3, 30 },
      },
   },
   {
      MissileConst_BallastTank,
      {
         BallastDepth = { 1, 0, 500 },
         BallastBuoyancy = { 2, -.5, .5 },
      },
   },
}
-- luacheck: pop

-- MISCELLANEOUS

-- The update rate, i.e. run every UpdateRate calls to Update method.
-- Set to 1 to update every call.
-- Setting to e.g. 10 means to run every 10th call.
-- Smaller means more responsive, but also means more processor usage.
UpdateRate = 1

-- !!! CODE BEGINS HERE, EDIT AT YOUR OWN RISK !!!

function shallowcopy(orig)
local orig_type = type(orig)
local copy
if orig_type == 'table' then
copy = {}
for orig_key, orig_value in pairs(orig) do
copy[orig_key] = orig_value
end
else
copy = orig
end
return copy
end

C = nil
Commons = {}
function Commons.new(I, AttackSalvage)
local self = shallowcopy(Commons)
self.I = I
self.AttackSalvage = AttackSalvage
self._FriendliesById = {}
return self
end
function Commons:Now()
if not self._Now then
self._Now = self.I:GetTimeSinceSpawn()
end
return self._Now
end
function Commons:IsDocked()
if not self._IsDocked then
self._IsDocked = self.I:IsDocked()
end
return self._IsDocked
end
function Commons:Position()
if not self._Position then
self._Position = self.I:GetConstructPosition()
end
return self._Position
end
function Commons:CoM()
if not self._CoM then
self._CoM = self.I:GetConstructCenterOfMass()
end
return self._CoM
end
function Commons:Altitude()
return self:CoM().y
end
function Commons:Yaw()
if not self._Yaw then
self._Yaw = self.I:GetConstructYaw()
end
return self._Yaw
end
function Commons:Pitch()
if not self._Pitch then
self._Pitch = -self.I:GetConstructPitch()
end
return self._Pitch
end
function Commons:Roll()
if not self._Roll then
local Roll = self.I:GetConstructRoll()
if Roll > 180 then
Roll = Roll - 360
end
self._Roll = Roll
end
return self._Roll
end
function Commons:Velocity()
if not self._Velocity then
self._Velocity = self.I:GetVelocityVector()
end
return self._Velocity
end
function Commons:ForwardSpeed()
if not self._ForwardSpeed then
self._ForwardSpeed = self.I:GetForwardsVelocityMagnitude()
end
return self._ForwardSpeed
end
function Commons:ForwardVector()
if not self._ForwardVector then
self._ForwardVector = self.I:GetConstructForwardVector()
end
return self._ForwardVector
end
function Commons:UpVector()
if not self._UpVector then
self._UpVector = self.I:GetConstructUpVector()
end
return self._UpVector
end
function Commons:RightVector()
if not self._RightVector then
self._RightVector = self.I:GetConstructRightVector()
end
return self._RightVector
end
function Commons:ToWorld()
if not self._ToWorld then
self._ToWorld = Quaternion.LookRotation(self:ForwardVector(), self:UpVector())
end
return self._ToWorld
end
function Commons:ToLocal()
if not self._ToLocal then
self._ToLocal = Quaternion.Inverse(self:ToWorld())
end
return self._ToLocal
end
function Commons:Ground()
if not self._Ground then
self._Ground = math.max(0, self.I:GetTerrainAltitudeForPosition(self:CoM()))
end
return self._Ground
end
function Commons:MovementMode()
if not self._MovementMode then
self._MovementMode = self.I:GetAIMovementMode(0)
end
return self._MovementMode
end
function Commons:FiringMode()
if not self._FiringMode then
self._FiringMode = self.I:GetAIFiringMode(0)
end
return self._FiringMode
end

Periodic = {}
function Periodic.new(Period, Function, Start)
local self = {}
self.Ticks = Start and Start or Period
self.Period = Period
self.Function = Function
if Period then
self.Tick = Periodic.Tick
else
self.Tick = function (_, _) end
end
return self
end
function Periodic:Tick(I)
local Ticks = self.Ticks
Ticks = Ticks + 1
if Ticks >= self.Period then
self.Ticks = 0
self.Function(I)
else
self.Ticks = Ticks
end
end

NamedComponent = {}
function NamedComponent.new(Type)
local self = {}
self.Type = Type
self.LastCount = 0
self.IndexCache = {}
self.AllIndexCache = {}
self.Gather = NamedComponent.Gather
self.GetIndex = NamedComponent.GetIndex
self.GetIndices = NamedComponent.GetIndices
return self
end
function NamedComponent:Gather(I)
local CountCache = C._NamedComponentCounts
if not CountCache then
CountCache = {}
C._NamedComponentCounts = CountCache
end
local Type = self.Type
local ComponentCount = CountCache[Type]
if not ComponentCount then
ComponentCount = I:Component_GetCount(Type)
CountCache[Type] = ComponentCount
end
if ComponentCount ~= self.LastCount then
self.LastCount = ComponentCount
local IndexCache = {}
self.IndexCache = IndexCache
local AllIndexCache = {}
self.AllIndexCache = AllIndexCache
for i = 0,ComponentCount-1 do
local BlockInfo = I:Component_GetBlockInfo(Type, i)
local CustomName = BlockInfo.CustomName
if CustomName and CustomName ~= "" then
if not IndexCache[CustomName] then
IndexCache[CustomName] = i
end
local Indices = AllIndexCache[CustomName]
if not Indices then
Indices = {}
AllIndexCache[CustomName] = Indices
end
table.insert(Indices, i)
end
end
end
end
function NamedComponent:GetIndex(I, Name, Default)
if not Default then Default = -1 end
self:Gather(I)
local Index = self.IndexCache[Name]
if Index then
return Index
else
return Default
end
end
function NamedComponent:GetIndices(I, Name)
self:Gather(I)
local Indices = self.AllIndexCache[Name]
if Indices then
return { unpack(Indices) }
else
return {}
end
end

Commons_MainframeNamedComponent = NamedComponent.new(MAINFRAME)
function Commons:MainframeIndex(Specifier)
if type(Specifier) == "number" then
return Specifier
end
return Commons_MainframeNamedComponent:GetIndex(self.I, Specifier, 0)
end

function CommonsTarget_Ground(self, I)
if not self._Ground then
self._Ground = math.max(0, I:GetTerrainAltitudeForPosition(self.AimPoint))
end
return self._Ground
end
function CommonsTarget_Elevation(self, I)
if not self._Elevation then
self._Elevation = self.AimPoint.y - self:Ground(I)
end
return self._Elevation
end
function Commons.ConvertTarget(Index, TargetInfo, Offset, Range)
local Target = {
Id = TargetInfo.Id,
Index = Index,
Position = TargetInfo.Position,
Offset = Offset,
Range = Range,
SqrRange = Range * Range,
AimPoint = TargetInfo.AimPointPosition,
Velocity = TargetInfo.Velocity,
Ground = CommonsTarget_Ground,
Elevation = CommonsTarget_Elevation,
}
return Target
end
function Commons:GatherTargets(Targets, StartIndex, MaxTargets)
local CoM = self:CoM()
local AttackSalvage = self.AttackSalvage
for _,mspec in ipairs(CommonsTargetConfig.PreferredTargetMainframes) do
local mindex = self:MainframeIndex(mspec)
local TargetCount = self.I:GetNumberOfTargets(mindex)
if TargetCount > 0 then
if not StartIndex then StartIndex = 0 end
if not MaxTargets then MaxTargets = math.huge end
for tindex = StartIndex,TargetCount-1 do
if #Targets >= MaxTargets then break end
local TargetInfo = self.I:GetTargetInfo(mindex, tindex)
if TargetInfo.Valid and (TargetInfo.Protected or AttackSalvage) then
local Offset = TargetInfo.Position - CoM
local Range = Offset.magnitude
if Range <= CommonsTargetConfig.MaxEnemyRange then
table.insert(Targets, Commons.ConvertTarget(tindex, TargetInfo, Offset, Range))
end
end
end
break
end
end
end
function Commons:FirstTarget()
if not self._FirstTarget then
if self._Targets then
local Target = self._Targets[1]
self._FirstTarget = Target and { Target } or {}
else
local Targets = {}
self:GatherTargets(Targets, 0, 1)
self._FirstTarget = Targets
end
end
return self._FirstTarget[1]
end
function Commons:Targets()
if not self._Targets then
local Targets = {}
if self._FirstTarget then
local Target = self._FirstTarget[1]
if not Target then
self._Targets = {}
return self._Targets
end
table.insert(Targets, Target)
self:GatherTargets(Targets, Target.Index+1)
else
self:GatherTargets(Targets, 0)
end
self._Targets = Targets
end
return self._Targets
end

function CommonsWeapons_CustomName(self, I)
if not self._CustomName then
self._CustomName = I:GetWeaponBlockInfoOnSubConstruct(self.SubConstructId, self.Index).CustomName
end
return self._CustomName
end
function Commons.AddWeapon(Weapons, WeaponInfo, SubConstructId, WeaponIndex)
local Weapon = {
SubConstructId = SubConstructId,
Index = WeaponIndex,
Type = WeaponInfo.WeaponType,
Slot = WeaponInfo.WeaponSlot,
Position = WeaponInfo.GlobalPosition,
FirePoint = WeaponInfo.GlobalFirePoint,
Speed = WeaponInfo.Speed,
PlayerControl = WeaponInfo.PlayerCurrentlyControllingIt,
CustomName = CommonsWeapons_CustomName
}
table.insert(Weapons, Weapon)
end
function Commons:WeaponControllers()
if not self._WeaponControllers then
local Weapons = {}
for windex = 0,self.I:GetWeaponCount()-1 do
local Info = self.I:GetWeaponInfo(windex)
Commons.AddWeapon(Weapons, Info, 0, windex)
end
local subids = self.I:GetAllSubConstructs()
for sindex = 1,#subids do
local subid = subids[sindex]
for windex = 0,self.I:GetWeaponCountOnSubConstruct(subid)-1 do
local Info = self.I:GetWeaponInfoOnSubConstruct(subid, windex)
Commons.AddWeapon(Weapons, Info, subid, windex)
end
end
self._WeaponControllers = Weapons
end
return self._WeaponControllers
end

LastTransceiverCount = 0
TransceiverGuidances = {}
LastTransceiverResetTime = 0
MissileStates = {}
LastTimeTargetSeen = nil
function MissileDriver_GatherTargets(GuidanceInfos)
local TargetsByPriority = {}
local TargetsById = {}
local Targets = C:Targets()
for _,Target in ipairs(Targets) do
local CanTarget = {}
local InRange = {}
local Altitude = Target.AimPoint.y
local Range = Target.SqrRange
for _,GuidanceInfo in ipairs(GuidanceInfos) do
table.insert(CanTarget, Altitude >= GuidanceInfo.MinAltitude and Altitude <= GuidanceInfo.MaxAltitude)
table.insert(InRange, Range >= GuidanceInfo.MinRange and Range <= GuidanceInfo.MaxRange)
end
Target.CanTarget = CanTarget
Target.InRange = InRange
table.insert(TargetsByPriority, Target)
TargetsById[Target.Id] = Target
end
return TargetsByPriority, TargetsById
end
function MissileDriver_FireControl(I, GuidanceInfos, TargetsByPriority)
local SlotsToFire = {}
local Fire = false
for i,Guidance in ipairs(GuidanceInfos) do
local WeaponSlot = Guidance.WeaponSlot
if WeaponSlot then
for _,Target in ipairs(TargetsByPriority) do
if Target.CanTarget[i] and Target.InRange[i] then
if not SlotsToFire[WeaponSlot] then
SlotsToFire[WeaponSlot] = Target.AimPoint
Fire = true
end
break
end
end
end
end
if Fire then
for _,Weapon in pairs(C:WeaponControllers()) do
local WeaponSlot = Weapon.Slot
local AimPoint = SlotsToFire[WeaponSlot]
if AimPoint and not Weapon.PlayerControl then
local WeaponType = Weapon.Type
if WeaponType == TURRET or WeaponType == MISSILECONTROL then
local Offset = AimPoint - Weapon.Position
if I:AimWeaponInDirectionOnSubConstruct(Weapon.SubConstructId, Weapon.Index, Offset.x, Offset.y, Offset.z, WeaponSlot) > 0 and WeaponType == MISSILECONTROL then
I:FireWeaponOnSubConstruct(Weapon.SubConstructId, Weapon.Index, WeaponSlot)
end
end
end
end
end
end
MissileDriver_TargetSelectors = {
function (I, TransceiverIndex, MissileIndex, Targets) -- luacheck: ignore 212
return Targets[1]
end,
function (I, TransceiverIndex, MissileIndex, Targets) -- luacheck: ignore 212
if #Targets > 0 then
return Targets[math.random(#Targets)]
else
return nil
end
end
}
function MissileDriver_Update(I, GuidanceInfos, SelectGuidance)
local Now = C:Now()
local TargetsByPriority, TargetsById = MissileDriver_GatherTargets(GuidanceInfos)
if #TargetsByPriority > 0 then
LastTimeTargetSeen = Now
if C:FiringMode() ~= "Off" then
MissileDriver_FireControl(I, GuidanceInfos, TargetsByPriority)
end
local TransceiverCount = I:GetLuaTransceiverCount()
if TransceiverCount ~= LastTransceiverCount or (LastTransceiverResetTime+TransceiverResetInterval) < Now then
TransceiverGuidances = {}
LastTransceiverCount = TransceiverCount
LastTransceiverResetTime = Now
end
local NewMissileStates = {}
local GuidanceQueue = {}
local FilteredTargetsByGuidance = {}
local FilterTargets = function (GuidanceIndex)
local FilteredTargets = FilteredTargetsByGuidance[GuidanceIndex]
if not FilteredTargets then
FilteredTargets = {}
for _,Target in ipairs(TargetsByPriority) do
if Target.CanTarget[GuidanceIndex] and Target.InRange[GuidanceIndex] then
table.insert(FilteredTargets, Target)
end
end
FilteredTargetsByGuidance[GuidanceIndex] = FilteredTargets
end
return FilteredTargets
end
for tindex = 0,TransceiverCount-1 do
local GuidanceIndex = TransceiverGuidances[tindex]
if not GuidanceIndex then
GuidanceIndex = SelectGuidance(I, tindex)
TransceiverGuidances[tindex] = GuidanceIndex
end
if GuidanceIndex > 0 then
local TargetSelector = MissileDriver_TargetSelectors[GuidanceInfos[GuidanceIndex].TargetSelector]
for mindex = 0,I:GetLuaControlledMissileCount(tindex)-1 do
if not I:IsLuaControlledMissileAnInterceptor(tindex, mindex) then
local Missile = I:GetLuaControlledMissileInfo(tindex, mindex)
if Missile.Valid then
local MissileId = Missile.Id
local MissileState = MissileStates[MissileId]
if not MissileState then MissileState = {} end
local MissileTargetId = MissileState.TargetId
if not MissileTargetId then
local Target = TargetSelector(I, tindex, mindex, FilterTargets(GuidanceIndex))
if Target then
MissileTargetId = Target.Id
MissileState.TargetId = MissileTargetId
NewMissileStates[MissileId] = MissileState
end
end
local Target = nil
if MissileTargetId then
Target = TargetsById[MissileTargetId]
if not Target then
local MissilePosition = Missile.Position
local ClosestDistance = math.huge
for _,T in ipairs(TargetsByPriority) do
if T.CanTarget[GuidanceIndex] then
local Offset = T.Position - MissilePosition
local Distance = Offset.sqrMagnitude
if Distance < ClosestDistance then
MissileTargetId = T.Id
MissileState.TargetId = MissileTargetId
NewMissileStates[MissileId] = MissileState
Target = T
ClosestDistance = Distance
end
end
end
else
NewMissileStates[MissileId] = MissileState
end
end
if Target then
local QueueMissiles = GuidanceQueue[Target.Id]
if not QueueMissiles then
QueueMissiles = {}
GuidanceQueue[Target.Id] = QueueMissiles
end
local QueueMissile = {
TransceiverIndex = tindex,
MissileIndex = mindex,
GuidanceIndex = GuidanceIndex,
Missile = Missile,
MissileState = MissileState,
}
table.insert(QueueMissiles, QueueMissile)
end
end
end
end
end
end
local BeginUpdateCalled = {}
for TargetId,QueueMissiles in pairs(GuidanceQueue) do
local Target = TargetsById[TargetId]
local SetTargetCalled = {}
for _,QueueMissile in pairs(QueueMissiles) do
local GuidanceIndex = QueueMissile.GuidanceIndex
local Guidance = GuidanceInfos[GuidanceIndex]
local Controller = Guidance.Controller
if not BeginUpdateCalled[GuidanceIndex] then
local BeginUpdate = Controller.BeginUpdate
if BeginUpdate then
BeginUpdate(Controller, I, FilterTargets(GuidanceIndex))
end
BeginUpdateCalled[GuidanceIndex] = true
end
if not SetTargetCalled[GuidanceIndex] then
local SetTarget = Controller.SetTarget
if SetTarget then
SetTarget(Controller, I, Target)
end
SetTargetCalled[GuidanceIndex] = true
end
local tindex,mindex = QueueMissile.TransceiverIndex,QueueMissile.MissileIndex
local AimPoint = Controller:Guide(I, tindex, mindex, Target, QueueMissile.Missile, QueueMissile.MissileState)
if AimPoint then
I:SetLuaControlledMissileAimPoint(tindex, mindex, AimPoint.x, AimPoint.y, AimPoint.z)
end
end
end
MissileStates = NewMissileStates
elseif LastTimeTargetSeen and (LastTimeTargetSeen+DetonateAfter) < Now then
LastTimeTargetSeen = nil
for tindex = 0,I:GetLuaTransceiverCount()-1 do
for mindex = 0,I:GetLuaControlledMissileCount(tindex)-1 do
I:DetonateLuaControlledMissile(tindex, mindex)
end
end
end
end

function QuadraticSolver(a, b, c)
if a == 0 then
if b ~= 0 then
return { -c / b }
else
return {}
end
else
local disc = b * b - 4 * a * c
if disc < 0 then
return {}
elseif disc == 0 then
return { -.5 * b / a }
else
local q = (b > 0) and (-.5 * (b + math.sqrt(disc))) or (-.5 * (b - math.sqrt(disc)))
local t1 = q / a
local t2 = c / q
if t1 > t2 then
return { t2, t1 }
else
return { t1, t2 }
end
end
end
end

function QuadraticIntercept(Position, SpeedSquared, Target, TargetVelocity, DefaultInterceptTime)
if not DefaultInterceptTime then DefaultInterceptTime = 1 end
local Offset = Target - Position
local a = Vector3.Dot(TargetVelocity, TargetVelocity) - SpeedSquared
local b = 2 * Vector3.Dot(Offset, TargetVelocity)
local c = Vector3.Dot(Offset, Offset)
local Solutions = QuadraticSolver(a, b, c)
local InterceptTime = DefaultInterceptTime
if #Solutions == 1 then
local t = Solutions[1]
if t > 0 then InterceptTime = t end
elseif #Solutions == 2 then
local t1 = Solutions[1]
local t2 = Solutions[2]
if t1 > 0 then
InterceptTime = t1
elseif t2 > 0 then
InterceptTime = t2
end
end
return Target + TargetVelocity * InterceptTime,InterceptTime
end

function GetVectorAngle(v)
return math.deg(math.atan2(v.x, v.z))
end

function Round(num, idp)
local mult = 10^(idp or 0)
return math.floor(num * mult + 0.5) / mult
end

function deepcopy(orig)
local orig_type = type(orig)
local copy
if orig_type == 'table' then
copy = {}
for orig_key, orig_value in next, orig, nil do
copy[deepcopy(orig_key)] = deepcopy(orig_value)
end
else
copy = orig
end
return copy
end

function Sign(n, ZeroSign, Eps)
Eps = Eps or 0
if n > Eps then
return 1
elseif n < -Eps then
return -1
else
return ZeroSign or 0
end
end

function Clamp(n, Min, Max)
if n < Min then return Min elseif n > Max then return Max else return n end
end

MissileCommand = {}
function MissileCommand.new(I, TransceiverIndex, MissileIndex)
local self = {}
local Fuel,Lifetime,VarThrustCount,VarThrust,ThrustCount = 0,MissileConst_LifetimeStart,0,0,0
local switch = {}
switch[MissileConst_VarThrust] = function (Part)
VarThrustCount = VarThrustCount + 1
VarThrust = VarThrust + Part.Registers[2]
end
switch[MissileConst_FuelTank] = function (_)
Fuel = Fuel + MissileConst_FuelAmount
end
switch[MissileConst_Regulator] = function (_)
Lifetime = Lifetime + MissileConst_LifetimeAdd
end
switch[MissileConst_ShortRange] = function (Part)
ThrustCount = ThrustCount + 1
self.ThrustDelay = Part.Registers[1]
self.ThrustDuration = Part.Registers[2]
end
switch[MissileConst_ShortRange] = function (Part)
self.MagnetRange = Part.Registers[1]
self.MagnetDelay = Part.Registers[2]
end
switch[MissileConst_BallastTank] = function (Part)
self.BallastDepth = Part.Registers[1]
self.BallastBuoyancy = Part.Registers[2]
end
local MissileInfo = I:GetMissileInfo(TransceiverIndex, MissileIndex)
local parts = MissileInfo.Parts
for i = 1,#parts do
local Part = parts[i]
local f = switch[Part.Name]
if f then f(Part) end
end
self.Fuel = Fuel
self.Lifetime = Lifetime
if VarThrustCount > 0 then
self.VarThrustCount = VarThrustCount
self.VarThrust = VarThrust
end
if ThrustCount > 0 then
self.ThrustCount = ThrustCount
end
self.SendUpdate = MissileCommand.SendUpdate
return self
end
function MissileCommand:SendUpdate(I, TransceiverIndex, MissileIndex, Command)
local switch = {}
local DoUpdate = false
for _,Spec in pairs(MissileUpdateData) do
local Queue = {}
for RegName,RegInfo in pairs(Spec[2]) do
local CommandVal = Command[RegName]
local CurrentVal = self[RegName]
if CommandVal and CurrentVal and (CommandVal ~= CurrentVal) then
local RegNo,RegMin,RegMax = unpack(RegInfo)
local NewVal = Clamp(CommandVal, RegMin, RegMax)
table.insert(Queue, { RegNo, NewVal })
self[RegName] = NewVal
end
end
if #Queue == 1 then
switch[Spec[1]] = function (Part)
Part:SendRegister(Queue[1][1], Queue[1][2])
end
DoUpdate = true
elseif #Queue == 2 then
switch[Spec[1]] = function (Part)
Part:SendRegister(Queue[1][1], Queue[1][2])
Part:SendRegister(Queue[2][1], Queue[2][2])
end
DoUpdate = true
end
end
if DoUpdate then
local MissileInfo = I:GetMissileInfo(TransceiverIndex, MissileIndex)
local parts = MissileInfo.Parts
for i = 1,#parts do
local Part = parts[i]
local f = switch[Part.Name]
if f then f(Part) end
end
end
end

GeneralMissile = {}
function GeneralMissile_PrepareAngle(Angle, Default)
return Angle and math.cos(math.rad(Angle)) or Default
end
function GeneralMissile_MinTerminal(TurnRadius, AltitudeDelta)
if TurnRadius <= AltitudeDelta then
return 25 * math.ceil(TurnRadius / 25)
else
local MinTerminal = math.sqrt(AltitudeDelta * (2 * TurnRadius - AltitudeDelta))
return 25 * math.ceil(MinTerminal / 25)
end
end
function GeneralMissile_DynamicDistances(Config)
local Velocity,TurnRate = Config.Velocity,Config.TurnRate
if not Velocity or not TurnRate then return end
local TurnRadius = Velocity / math.rad(TurnRate)
local MinTerminal = function (AltitudeDelta)
return GeneralMissile_MinTerminal(TurnRadius, math.abs(AltitudeDelta))
end
for _,Phase in pairs(Config.Phases) do
if type(Phase.Distance) == "function" then
local NewDistance = Phase.Distance(MinTerminal, TurnRadius)
Phase.Distance = NewDistance
end
end
end
function GeneralMissile.new(Config)
local self = deepcopy(Config)
if not self.AntiAir then
self.AirProfileElevation = math.huge
self.AntiAir = {
Phases = {
{
},
},
}
elseif not self.Phases then
self.AirProfileElevation = -math.huge
self.Phases = {
{
Distance = 150,
},
{
Distance = 50,
AboveSeaLevel = false,
MinElevation = 0,
},
}
end
self.DetonationAngle = GeneralMissile_PrepareAngle(self.DetonationAngle, 1)
for _,Phase in pairs(self.AntiAir.Phases) do
if Phase.Change and Phase.Change.When then
Phase.Change.When.Angle = GeneralMissile_PrepareAngle(Phase.Change.When.Angle)
end
end
for _,Phase in pairs(self.Phases) do
if Phase.Change and Phase.Change.When then
Phase.Change.When.Angle = GeneralMissile_PrepareAngle(Phase.Change.When.Angle)
end
end
if not self.DetonationRange then self.DetonationRange = -1 end
if #self.AntiAir.Phases == 1 then
self.AntiAir.Phases[1].Range = math.huge
table.insert(self.AntiAir.Phases, {})
end
self.AntiAir.Phases[#self.AntiAir.Phases].Range = math.huge
GeneralMissile_DynamicDistances(self)
self.GetTerrainHeight = GeneralMissile.GetTerrainHeight
self.ModifyAltitude = GeneralMissile.ModifyAltitude
self.GetPhaseAltitude2D = GeneralMissile.GetPhaseAltitude2D
self.ExecuteProfile2D = GeneralMissile.ExecuteProfile2D
self.ExecuteProfile3D = GeneralMissile.ExecuteProfile3D
self.SetTarget = GeneralMissile.SetTarget
self.Guide = GeneralMissile.Guide
return self
end
function GeneralMissile_UpdateMissileState(I, TransceiverIndex, MissileIndex, Position, Missile, MissileState)
local Command = MissileState.Command
if not Command then
MissileState.Command = MissileCommand.new(I, TransceiverIndex, MissileIndex)
Command = MissileState.Command
MissileState.Fuel = Command.Fuel
end
local Fuel = MissileState.Fuel
local LastTime = MissileState.LastTime
if not LastTime then LastTime = 0 end
local Now = Missile.TimeSinceLaunch
local TimeStep = Now - LastTime
MissileState.LastTime = Now
MissileState.Now = Now
MissileState.TimeStep = TimeStep
if Position.y >= 0 then
local CurrentThrust = Command.VarThrust or 0
if Command.ThrustCount and Now > Command.ThrustDelay and (Command.ThrustDelay + Command.ThrustDuration) > Now then
CurrentThrust = CurrentThrust + MissileConst_ShortRangeFuelRate
end
Fuel = Fuel - CurrentThrust * TimeStep
end
MissileState.Fuel = math.max(Fuel, 0)
end
function GeneralMissile_HandleMissileChange(I, TransceiverIndex, MissileIndex, Position, MissileState, ImpactTime, Change)
if not Change then return end
if Change.When then
if Change.When.Angle and MissileState.TargetCosAngle < Change.When.Angle then return end
if Change.When.Range and MissileState.TargetRange > Change.When.Range then return end
if Change.When.AltitudeGT and Position.y <= Change.When.AltitudeGT then return end
if Change.When.AltitudeLT and Position.y >= Change.When.AltitudeLT then return end
end
Change.VarThrust = Change.Thrust
if Change.VarThrust and Change.VarThrust < 0 then
local Remaining = math.max(MissileState.Command.Lifetime - MissileState.Now, 0)
ImpactTime = math.min(Remaining, ImpactTime)
Change.VarThrust = (ImpactTime > 0) and Round(MissileState.Fuel / ImpactTime, 1) or math.huge
end
MissileState.Command:SendUpdate(I, TransceiverIndex, MissileIndex, Change)
end
function GeneralMissile:GetTerrainHeight(I, Position, Velocity, MaxDistance)
if not MaxDistance then MaxDistance = math.huge end
local LookAheadTime,LookAheadResolution = self.LookAheadTime,self.LookAheadResolution
if not LookAheadTime or LookAheadResolution <= 0 then return -500 end
local Height = -500
local PlanarVelocity = Vector3(Velocity.x, 0, Velocity.z)
local Speed = PlanarVelocity.magnitude
local Direction = PlanarVelocity / Speed
local Distance = math.min(Speed * LookAheadTime, MaxDistance)
for d = 0,Distance-1,LookAheadResolution do
Height = math.max(Height, I:GetTerrainAltitudeForPosition(Position + Direction * d))
end
Height = math.max(Height, I:GetTerrainAltitudeForPosition(Position + Direction * Distance))
return Height
end
function GeneralMissile:ModifyAltitude(Position, AimPoint, Altitude, RelativeTo)
if not AimPoint then
if RelativeTo == 1 then
return self.TargetAltitude + Altitude
elseif RelativeTo == 2 then
return self.TargetDepth + Altitude
elseif RelativeTo == 3 then
return self.TargetGround + Altitude
elseif RelativeTo == 4 then
return Position.y + Altitude
elseif RelativeTo == 5 then
return math.max(self.TargetAltitude, Altitude)
elseif RelativeTo == 6 then
return math.min(self.TargetAltitude, Altitude)
else
return Altitude
end
else
if RelativeTo == 1 then
return AimPoint.y + Altitude
elseif RelativeTo == 2 then
return math.min(AimPoint.y, 0) + Altitude
elseif RelativeTo == 3 then
return math.max(AimPoint.y, 0) + Altitude
elseif RelativeTo == 4 then
return Position.y + Altitude
elseif RelativeTo == 5 then
return math.max(AimPoint.y, Altitude)
elseif RelativeTo == 6 then
return math.min(AimPoint.y, Altitude)
else
return Altitude
end
end
end
function GeneralMissile:GetPhaseAltitude2D(I, Position, Velocity, Phase, MaxDistance)
local Height = self:GetTerrainHeight(I, Position, Velocity, MaxDistance)
if Phase.AboveSeaLevel then
Height = math.max(Height, 0)
end
Height = Height + Phase.MinElevation
local Altitude = Phase.Altitude
if not Altitude then
return Height
else
return math.max(self:ModifyAltitude(Position, nil, Altitude, Phase.RelativeTo), Height)
end
end
function GeneralMissile:ExecuteProfile2D(I, TransceiverIndex, MissileIndex, Position, Velocity, AimPoint, TargetVelocity, MissileState)
local ImpactTime
AimPoint,ImpactTime = QuadraticIntercept(Position, Vector3.Dot(Velocity, Velocity), AimPoint, TargetVelocity, 9999)
local NewTarget = Vector3(AimPoint.x, Position.y, AimPoint.z)
local GroundOffset = NewTarget - Position
local GroundDistance = GroundOffset.magnitude
local TerminalPhase = self.Phases[1]
if GroundDistance < TerminalPhase.Distance then
local Altitude = TerminalPhase.Altitude
if Altitude then
AimPoint = Vector3(AimPoint.x, self:ModifyAltitude(Position, AimPoint, Altitude, TerminalPhase.RelativeTo), AimPoint.z)
end
GeneralMissile_HandleMissileChange(I, TransceiverIndex, MissileIndex, Position, MissileState, ImpactTime, TerminalPhase.Change)
return AimPoint
end
local PreviousPhase,IsClosing
local Phase = TerminalPhase
for i = 2,#self.Phases do
PreviousPhase = Phase
Phase = self.Phases[i]
IsClosing = i == #self.Phases
if GroundDistance < Phase.Distance then break end
end
local GroundDirection,ToNextPhase
local ApproachAngle = Phase.ApproachAngle
if ApproachAngle then
local TargetYaw = GetVectorAngle(TargetVelocity)
local MissileBearing = Mathf.DeltaAngle(TargetYaw, GetVectorAngle(Position - AimPoint))
local AimPointBearing = (TargetYaw + Sign(MissileBearing, 1) * ApproachAngle) % 360
local ModifiedAimPoint = AimPoint + Quaternion.Euler(0, AimPointBearing, 0) * (Vector3.forward * PreviousPhase.Distance)
ModifiedAimPoint.y = Position.y
local Offset = ModifiedAimPoint - Position
ToNextPhase = Offset.magnitude
GroundDirection = Offset / ToNextPhase
else
GroundDirection = GroundOffset / GroundDistance
ToNextPhase = GroundDistance - PreviousPhase.Distance
end
local AimDistance = IsClosing and Phase.Distance or ToNextPhase
local NewAimPoint = Position + GroundDirection * AimDistance
NewAimPoint.y = self:GetPhaseAltitude2D(I, Position, Velocity, Phase, ToNextPhase)
GeneralMissile_HandleMissileChange(I, TransceiverIndex, MissileIndex, Position, MissileState, ImpactTime, Phase.Change)
local Evasion = Phase.Evasion
if Evasion then
local Perp = Vector3.Cross(GroundDirection, Vector3.up)
NewAimPoint = NewAimPoint + Perp * Evasion[1] * (2 * Mathf.PerlinNoise(Evasion[2] * C:Now(), TransceiverIndex * 37 + MissileIndex) - 1)
end
return NewAimPoint
end
function GeneralMissile:ExecuteProfile3D(I, TransceiverIndex, MissileIndex, Position, Velocity, AimPoint, TargetVelocity, MissileState)
local ImpactTime
AimPoint,ImpactTime = QuadraticIntercept(Position, Vector3.Dot(Velocity, Velocity), AimPoint, TargetVelocity, 9999)
local TargetOffset = AimPoint - Position
local TargetRange = TargetOffset.magnitude
local TerminalPhase = self.AntiAir.Phases[1]
if TargetRange < TerminalPhase.Range then
local Altitude = TerminalPhase.Altitude
if Altitude then
AimPoint = Vector3(AimPoint.x, self:ModifyAltitude(Position, AimPoint, Altitude, TerminalPhase.RelativeTo), AimPoint.z)
end
GeneralMissile_HandleMissileChange(I, TransceiverIndex, MissileIndex, Position, MissileState, ImpactTime, TerminalPhase.Change)
return AimPoint
end
local PreviousPhase
local Phase = TerminalPhase
for i = 2,#self.AntiAir.Phases do
PreviousPhase = Phase
Phase = self.AntiAir.Phases[i]
if TargetRange < Phase.Range then break end
end
local TargetDirection,ToNextPhase
TargetDirection = TargetOffset / TargetRange
ToNextPhase = TargetRange - PreviousPhase.Range
local NewAimPoint = Position + TargetDirection * ToNextPhase
local Altitude = Phase.Altitude
if Altitude then
NewAimPoint.y = self:ModifyAltitude(Position, nil, Altitude, Phase.RelativeTo)
end
GeneralMissile_HandleMissileChange(I, TransceiverIndex, MissileIndex, Position, MissileState, ImpactTime, Phase.Change)
return NewAimPoint
end
function GeneralMissile:SetTarget(I, Target)
local TargetAimPoint = Target.AimPoint
local TargetAltitude = TargetAimPoint.y
self.TargetAltitude = TargetAltitude
self.TargetDepth = math.min(TargetAltitude, 0)
self.TargetGround = Target:Ground(I)
self.Use2DProfile = (TargetAltitude - self.TargetGround) <= self.AirProfileElevation
end
function GeneralMissile:Guide(I, TransceiverIndex, MissileIndex, Target, Missile, MissileState)
local TargetAimPoint = Target.AimPoint
local MissilePosition = Missile.Position
local MissileVelocity = Missile.Velocity
local MissileSpeed = MissileVelocity.magnitude
GeneralMissile_UpdateMissileState(I, TransceiverIndex, MissileIndex, MissilePosition, Missile, MissileState)
local TargetVector = TargetAimPoint - MissilePosition
local TargetRange = TargetVector.magnitude
local CosAngle = Vector3.Dot(TargetVector / TargetRange, MissileVelocity / MissileSpeed)
MissileState.TargetVector = TargetVector
MissileState.TargetRange = TargetRange
MissileState.TargetCosAngle = CosAngle
if TargetRange <= self.DetonationRange and CosAngle <= self.DetonationAngle then
I:DetonateLuaControlledMissile(TransceiverIndex, MissileIndex)
return TargetAimPoint
end
local AimPoint
local MinAltitude = self.MinAltitude
if MissilePosition.y < MinAltitude then
AimPoint = Vector3(MissilePosition.x, MinAltitude+1000, MissilePosition.z)
elseif self.Use2DProfile then
AimPoint = self:ExecuteProfile2D(I, TransceiverIndex, MissileIndex, MissilePosition, MissileVelocity, TargetAimPoint, Target.Velocity, MissileState)
else
AimPoint = self:ExecuteProfile3D(I, TransceiverIndex, MissileIndex, MissilePosition, MissileVelocity, TargetAimPoint, Target.Velocity, MissileState)
end
return AimPoint
end

MyMissile = GeneralMissile.new(Config)
GuidanceInfos = {
{
Controller = MyMissile,
MinAltitude = Limits.MinAltitude,
MaxAltitude = Limits.MaxAltitude,
MinRange = Limits.MinRange * Limits.MinRange,
MaxRange = Limits.MaxRange * Limits.MaxRange,
WeaponSlot = MissileWeaponSlot,
TargetSelector = MissileTargetSelector,
}
}
function SelectGuidance(_, _)
return 1
end
function MissileMain_Update(I)
MissileDriver_Update(I, GuidanceInfos, SelectGuidance)
end
MissileMain = Periodic.new(UpdateRate, MissileMain_Update)
function Update(I) -- luacheck: ignore 131
C = Commons.new(I)
if not C:IsDocked() then
MissileMain:Tick(I)
end
end
