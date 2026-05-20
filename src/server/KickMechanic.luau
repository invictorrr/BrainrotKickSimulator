--[[
    KickMechanic - Mecánica de disparo encapsulada.

    Este módulo contiene TODA la lógica de "qué pasa cuando el jugador patea":
    cómo se spawnea la pelota, qué trayectoria sigue, cómo se detecta gol/parada,
    y cómo se calcula el resultado final.

    Está pensado para ser INTERCAMBIABLE: si más adelante quieres una mecánica
    distinta (por ejemplo, mini-juego de timing, QTE, etc.), basta con sustituir
    este archivo por otro que exponga la misma API:

        local KickMechanic = require(...)
        KickMechanic.Init({
            createBall      = function(startPos, ballData) -> BasePart,
            onBallSpawned   = function(player, ball) -> (),  -- registro de pelota activa
            clearActiveBall = function(player) -> (),        -- limpieza al volver a patear
            dampBallToRest  = function(ball) -> (),          -- frena la pelota en gol
        })

        local res = KickMechanic.ResolveKick({
            player         = player,
            zoneId         = number,
            distance       = number,
            indicatorZone  = "green" | "yellow" | "red",
            power          = number,
            maxKickDistance= number,
            outOfRange     = boolean,
            ballData       = table,
            goalModel      = Model?,
            goalZone       = BasePart?,
            goalCFrame     = CFrame?,
            revealedGoalkeeperModel = Instance?,
            humanoidRootPart = BasePart?,
        })

        -- res = { result = "goal"|"saved"|"miss", ball = BasePart? }
]]

local KickMechanic = {}

local SHOT_SPREAD_BY_ZONE = {
	green  = 0,
	yellow = 7,
	red    = 18,
}

-- Reach efectivo del tiro según indicador:
--   green: llega justo (potencia óptima)
--   yellow: alcance ligeramente reducido
--   red: alcance muy reducido (se queda corta o desvía)
local SHOT_POWER_MULTIPLIER = {
	green  = 1.00,
	yellow = 0.85,
	red    = 0.55,
}

local deps = {
	createBall      = nil,
	onBallSpawned   = nil,
	clearActiveBall = nil,
	dampBallToRest  = nil,
}

function KickMechanic.Init(dependencies)
	for k, v in pairs(dependencies or {}) do
		deps[k] = v
	end
end

-- ── Helpers internos ──────────────────────────────────────────────────────────

local function isPointInsidePart(point: Vector3, part: BasePart): boolean
	local localPos = part.CFrame:PointToObjectSpace(point)
	local half = part.Size * 0.5
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y
		and math.abs(localPos.Z) <= half.Z
end

local function isBallSaved(goalkeeperModel: Instance?, ballPos: Vector3): boolean
	if not goalkeeperModel then return false end
	local saveRadius = 2.2
	for _, inst in ipairs(goalkeeperModel:GetDescendants()) do
		if inst:IsA("BasePart") then
			local r = (inst.Size.Magnitude * 0.25) + saveRadius
			if (inst.Position - ballPos).Magnitude <= r then
				return true
			end
		end
	end
	return false
end

local function computeAimDirection(hrp: BasePart, goalCenter: Vector3): Vector3
	local dir = Vector3.new(goalCenter.X - hrp.Position.X, 0, goalCenter.Z - hrp.Position.Z)
	if dir.Magnitude < 0.001 then
		local look = hrp.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z)
		if dir.Magnitude < 0.001 then
			dir = Vector3.new(0, 0, -1)
		end
	end
	return dir.Unit
end

local function computeShotTarget(ctx, toGoalDir: Vector3, startPos: Vector3)
	local indicatorZone   = ctx.indicatorZone
	local goalCFrame      = ctx.goalCFrame
	local goalModel       = ctx.goalModel
	local goalCenter      = ctx.goalCenter
	local distance        = ctx.distance
	local maxKickDistance = ctx.maxKickDistance
	local outOfRange      = ctx.outOfRange

	if indicatorZone == "green" and goalCFrame then
		local goalWidth  = (goalModel and goalModel:GetAttribute("GoalWidth")) or 20
		local goalHeight = (goalModel and goalModel:GetAttribute("GoalHeight")) or 12
		local goalDepth  = (goalModel and goalModel:GetAttribute("GoalDepth")) or 4
		local side = (math.random() < 0.5) and -1 or 1
		local cornerLocal = Vector3.new(
			side * (goalWidth / 2 - 1.8),
			goalHeight - 1.8,
			goalDepth * 0.75
		)
		local target = goalCFrame:PointToWorldSpace(cornerLocal)
		local flightTime = math.clamp(distance / 130, 0.32, 0.55)
		return target, flightTime
	end

	-- Yellow / Red: dispersión horizontal + alcance limitado por potencia
	local spreadDeg = SHOT_SPREAD_BY_ZONE[indicatorZone] or SHOT_SPREAD_BY_ZONE.red
	local spreadRad = math.rad((math.random() * 2 - 1) * spreadDeg)
	local shotDir = (CFrame.fromAxisAngle(Vector3.new(0, 1, 0), spreadRad)
		:VectorToWorldSpace(toGoalDir)).Unit

	local reachMultiplier = SHOT_POWER_MULTIPLIER[indicatorZone] or 0.55
	local powerReach = maxKickDistance * reachMultiplier
	local reach = math.min(distance, powerReach)
	if outOfRange then
		reach = powerReach
	end
	reach = math.max(reach, 5)

	local targetXZ = Vector3.new(startPos.X, 0, startPos.Z) + shotDir * reach
	local targetY = (reach >= distance - 1 and goalCenter)
		and math.clamp(goalCenter.Y, 2, goalCenter.Y)
		or 1
	local target = Vector3.new(targetXZ.X, targetY, targetXZ.Z)
	local flightTime = math.clamp(reach / 42, 0.5, 1.4)
	return target, flightTime
end

-- ── API pública ───────────────────────────────────────────────────────────────

function KickMechanic.ResolveKick(ctx)
	assert(deps.createBall, "[KickMechanic] no inicializado: falta createBall")

	local indicatorZone = ctx.indicatorZone
	if indicatorZone ~= "green" and indicatorZone ~= "yellow" and indicatorZone ~= "red" then
		indicatorZone = "red"
	end
	ctx.indicatorZone = indicatorZone

	local hrp        = ctx.humanoidRootPart
	local goalModel  = ctx.goalModel
	local goalZone   = ctx.goalZone
	local goalCFrame = ctx.goalCFrame
	local revealed   = ctx.revealedGoalkeeperModel
	local outOfRange = ctx.outOfRange

	local result = "miss"
	local spawnedBall = nil

	if hrp then
		-- Centro del arco para apuntar (la zona invisible si existe, o el pivote +4y)
		local goalCenter
		if goalZone then
			goalCenter = goalZone.Position
		elseif goalCFrame then
			goalCenter = goalCFrame.Position + Vector3.new(0, 4, 0)
		else
			goalCenter = hrp.Position + (hrp.CFrame.LookVector * 30) + Vector3.new(0, 4, 0)
		end
		ctx.goalCenter = goalCenter

		local toGoalDir = computeAimDirection(hrp, goalCenter)

		-- Spawn 3 studs delante del jugador, ligeramente arriba (evita choque
		-- con el propio cuerpo al salir el balón).
		local startPos = hrp.Position + (toGoalDir * 3) + Vector3.new(0, 1.5, 0)

		local targetWorldPos, flightTime = computeShotTarget(ctx, toGoalDir, startPos)
		local gravity = workspace.Gravity
		local velocity = (targetWorldPos - startPos
			+ Vector3.new(0, 0.5 * gravity * flightTime * flightTime, 0)) / flightTime

		-- Limpiar pelota previa y crear la nueva
		if deps.clearActiveBall then deps.clearActiveBall(ctx.player) end
		local ball = deps.createBall(startPos, ctx.ballData)
		ball.Parent = workspace
		ball:SetNetworkOwner(nil)
		ball.AssemblyLinearVelocity = velocity
		ball.AssemblyAngularVelocity = Vector3.new(
			(math.random() * 2 - 1) * 4,
			(math.random() * 2 - 1) * 4,
			(math.random() * 2 - 1) * 4
		)
		if deps.onBallSpawned then deps.onBallSpawned(ctx.player, ball) end
		spawnedBall = ball

		task.delay(0.12, function()
			if ball.Parent then ball.CanCollide = true end
		end)

		-- Loop de observación (no controla la pelota, sólo decide el resultado)
		local elapsed = 0
		while ball.Parent and elapsed < 2.8 do
			elapsed += task.wait(0.04)
			local pos = ball.Position

			if goalZone and isPointInsidePart(pos, goalZone) then
				result = "goal"
				if deps.dampBallToRest then deps.dampBallToRest(ball) end
				break
			end

			if indicatorZone ~= "green" and isBallSaved(revealed, pos) then
				result = "saved"
				break
			end
		end
	end

	-- Garantía verde: con indicador verde y alcance suficiente, gol seguro.
	if indicatorZone == "green" and not outOfRange and result ~= "goal" then
		result = "goal"
		if spawnedBall and deps.dampBallToRest then
			deps.dampBallToRest(spawnedBall)
		end
	end

	return {
		result = result,
		ball   = spawnedBall,
	}
end

return KickMechanic
