--[[----------------------------------------------------------------------------
    AzaathUI - Modules/MapRegions.lua
    Pontos de nascimento agrupados em regiões suaves (as áreas dos objetivos de missão no mapa,
    Modules/WorldMap.lua), a pedido do usuário "idêntico ao Polestar" (2026-11-17).

    Copiado do Polestar (Nav/Regions.lua, versão 0.4.0.1), com a licença dele:
      Copyright (c) 2026 The Polestar authors
      Polestar is free software: you can redistribute it and/or modify it under the terms of the
      GNU General Public License as published by the Free Software Foundation, version 3
      (GPL-3.0-only). Distributed WITHOUT ANY WARRANTY.
    Mudanças: o namespace (Azaath.MapRegions no lugar de ns.Regions).

    Regions.Of(cs, xs, ys, raios [, work]) -> regiões | nil
      cs, xs, ys, raios: um por ponto: a instância, jardas do mundo (X norte, Y oeste) e o raio (jardas)
      regiões = { { c, wx, wy (centro), hull = { wx1, wy1, ... }, members = { i, ... } }, ... }
    Cada região é o fecho convexo dos discos dos pontos (um polígono de 8 ou 16 lados); pontos a até
    LINK jardas se juntam, enquanto a região tiver no máximo MAX_SPAN jardas.
------------------------------------------------------------------------------]]
local _, Azaath = ...

local sqrt, floor, ceil, min, max, abs = math.sqrt, math.floor, math.ceil, math.min, math.max, math.abs
local ipairs, pairs = ipairs, pairs

local Regions = {}
Azaath.MapRegions = Regions

local SIDES, SMALL = 16, 200
local LINK = 90
local MAX_SPAN = 700
local PAD = 10
local MIN_RADIUS = 15
local WORK = 50000
Regions.LINK, Regions.MAX_SPAN, Regions.PAD, Regions.MIN_RADIUS, Regions.WORK = LINK, MAX_SPAN, PAD, MIN_RADIUS, WORK

local sides = {}
for _, k in ipairs({ 8, SIDES }) do
	local t = { n = k, cos = {}, sin = {}, det = math.sin(2 * math.pi / k) }
	for i = 1, k do
		local a = 2 * math.pi * (i - 1) / k
		t.cos[i], t.sin[i] = math.cos(a), math.sin(a)
	end
	sides[k] = t
end

-- The polygon whose sides touch the hull of the discs (members of cs, xs,
-- ys, rs listed in group, span yards across) from outside.
local function regionOf(group, span, cs, xs, ys, rs)
	local t = sides[span < SMALL and 8 or SIDES]
	local K, cosK, sinK = t.n, t.cos, t.sin
	local h = {}
	for k = 1, K do
		local ux, uy, best = cosK[k], sinK[k], -math.huge
		for _, i in ipairs(group) do
			local v = xs[i] * ux + ys[i] * uy + rs[i]
			if v > best then best = v end
		end
		h[k] = best
	end
	-- Corner k: where side k meets side k + 1.
	local hull, sx, sy, m = {}, 0, 0, 0
	for k = 1, K do
		local j = k % K + 1
		local x = (h[k] * sinK[j] - h[j] * sinK[k]) / t.det
		local y = (h[j] * cosK[k] - h[k] * cosK[j]) / t.det
		if m == 0 or abs(x - hull[2 * m - 1]) > 0.5 or abs(y - hull[2 * m]) > 0.5 then
			m = m + 1
			hull[2 * m - 1], hull[2 * m] = x, y
			sx, sy = sx + x, sy + y
		end
	end
	return { c = cs[group[1]], wx = sx / m, wy = sy / m, hull = hull, members = group }
end

function Regions.Of(cs, xs, ys, radii, work)
	local n = #cs
	local done, limit = 0, work or WORK
	local rs, groupOf, members, span = {}, {}, {}, {}
	for i = 1, n do
		rs[i] = max(radii[i] or 0, MIN_RADIUS) + PAD
		groupOf[i], members[i], span[i] = i, { i }, 2 * rs[i]
	end
	-- Pairs close enough to join, nearest (smallest gap between discs) first:
	-- a sweep along wx within each continent (no pair further apart along wx
	-- than LINK plus both radii, the widest of them for the one still to come),
	-- each pair one number (the gap in hundredths of a yard, then i, then j),
	-- so the sort compares plain numbers. Distances are compared squared and
	-- a square root taken only for a pair that joins.
	local order, maxR = {}, 0
	for i = 1, n do
		order[i] = i
		if rs[i] > maxR then maxR = rs[i] end
	end
	table.sort(order, function(a, b)
		if cs[a] ~= cs[b] then return cs[a] < cs[b] end
		if xs[a] ~= xs[b] then return xs[a] < xs[b] end
		return a < b
	end)
	local B, bias = n + 1, ceil(2 * maxR * 100) + 1
	local near = {}
	for a = 1, n do
		local i = order[a]
		local ci, xi, yi, ri = cs[i], xs[i], ys[i], rs[i]
		local reach = LINK + ri + maxR
		for b = a + 1, n do
			local j = order[b]
			local dx = xs[j] - xi
			if cs[j] ~= ci or dx > reach then break end
			done = done + 1
			if done > limit then return nil end
			local dy, t = ys[j] - yi, LINK + ri + rs[j]
			local d2 = dx * dx + dy * dy
			if d2 <= t * t then
				local gap = sqrt(d2) - ri - rs[j]
				if gap <= LINK then
					local lo, hi = min(i, j), max(i, j)
					near[#near + 1] = (floor(gap * 100 + 0.5) + bias) * B * B + lo * B + hi
				end
			end
		end
	end
	table.sort(near)
	-- Groups found too wide together stay apart: groups only grow.
	local apart = {}
	local function keepApart(a, b)
		apart[a] = apart[a] or {}
		apart[b] = apart[b] or {}
		apart[a][b], apart[b][a] = true, true
	end
	for _, key in ipairs(near) do
		local a, b = groupOf[floor(key / B) % B], groupOf[key % B]
		if a ~= b and not (apart[a] and apart[a][b]) then
			-- The joined group's span: the widest of the two, or a pair across
			-- them further apart (centre distance plus both radii); a pair whose
			-- centres are closer than the span so far less its radii cannot be.
			local s = max(span[a], span[b])
			local mb = members[b]
			for _, i in ipairs(members[a]) do
				local xi, yi, ri = xs[i], ys[i], rs[i]
				for k = 1, #mb do
					local j = mb[k]
					done = done + 1
					if done > limit then return nil end
					local dx, dy, rr = xs[j] - xi, ys[j] - yi, ri + rs[j]
					local d2, lim = dx * dx + dy * dy, s - rr
					if lim < 0 or d2 > lim * lim then
						local d = sqrt(d2) + rr
						if d > s then s = d end
					end
				end
				if s > MAX_SPAN then break end
			end
			if s <= MAX_SPAN then
				if a > b then a, b = b, a end
				for _, j in ipairs(members[b]) do
					groupOf[j] = a
					table.insert(members[a], j)
				end
				members[b], span[a] = nil, s
				for c in pairs(apart[b] or {}) do keepApart(a, c) end
			else
				keepApart(a, b)
			end
		end
	end
	local regions = {}
	for i = 1, n do
		local group = members[i]
		if group then
			table.sort(group)
			regions[#regions + 1] = regionOf(group, span[i], cs, xs, ys, rs)
		end
	end
	return regions
end

