local REALM_SIZE = 1000

local YMIN = 19000 -- Approx bottom.
local YMAX = 20000 -- Approx top.

local SEEDDIFF1 = 46894686546
local OCTAVES1 = 6
local PERSISTENCE1 = 0.55
local SCALE1 = 256

local SEEDDIFF2 = 9294207
local OCTAVES2 = 6
local PERSISTENCE2 = 0.5
local SCALE2 = 256

local yminq = (80 * math.floor((YMIN + 32) / 80)) - 32
local ymaxq = (80 * math.floor((YMAX + 32) / 80)) + 47

minetest.register_node("realms:barrier", {
	drawtype = "normal",
	tiles = {"realms_barrier"},
	paramtype = "light",
	sunlight_propagates = true,
	pointable = false,
	diggable = false,
	on_destruct = function(pos)
		minetest.after(0, minetest.set_node, {x=pos.x,y=pos.y,z=pos.z}, {name="realms:barrier"})
	end
})

local function spawntree(a, data, pos, treeparams)
	local lradius = math.ceil(treeparams.lradius)
	local lr2 = treeparams.lradius*treeparams.lradius
	local leaves = treeparams.leaves
	for x = -lradius, lradius do
	for y = -lradius, lradius do
	for z = -lradius, lradius do
		if x*x+y*y+z*z<=lr2 then
			data[a:index(x+pos.x, y+pos.y+treeparams.height, z+pos.z)] = leaves
		end
	end
	end
	end

	local radius = math.ceil(treeparams.radius)
	local r2 = treeparams.radius*treeparams.radius
	local trunk = treeparams.trunk
	for y = pos.y, pos.y+treeparams.height-1 do
		for x = -radius, radius do
		for z = -radius, radius do
			if x*x+z*z<=r2 then
				data[a:index(x+pos.x, y, z+pos.z)] = trunk
			end
		end
		end
	end
end

minetest.register_on_generated(function(minp, maxp, seed)
	if maxp.y == ymaxq then
		math.randomseed(seed)
		
		local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
		
		local a = VoxelArea:new{
			MinEdge={x=emin.x, y=emin.y, z=emin.z},
			MaxEdge={x=emax.x, y=emax.y, z=emax.z},
		}
		
		local ex = emax.x-emin.x+1
		local exy = (emax.x-emin.x+1)*(emax.y-emin.y+1)
		local index = function(self, x, y, z)
			return (x-emin.x)+(y-emin.y)*ex+(z-emin.z)*exy
		end
		local a={}
		a.index = index
		
		local perlin1 = minetest.get_perlin(SEEDDIFF1, OCTAVES1, PERSISTENCE1, SCALE1)
		local perlin2 = minetest.get_perlin(SEEDDIFF2, OCTAVES2, PERSISTENCE2, SCALE2)
		
		local water_level = minp.y+math.random(20,60)
		local sea, treeparams
		if math.random()<=0.05 then
			sea=minetest.get_content_id("default:lava_source")
			treeparams = {proba=0}
		else
			sea=minetest.get_content_id("default:water_source")
			treeparams = {proba=(math.exp(2*math.random())-1)/50, height=math.exp(3*math.random()-1)+4}
			if math.random()<=0.1 then
				treeparams.radius = math.random(2, 6)/2
			else
				treeparams.radius = 0.5
			end
			treeparams.proba = treeparams.proba/(treeparams.radius*treeparams.radius*math.pi)
			treeparams.lradius = treeparams.radius+1.5+3*math.random()
			treeparams.height = math.floor(math.max(treeparams.height, treeparams.lradius+1))
		end
		if math.random()<=0.05 then
			treeparams.trunk = minetest.get_content_id("default:mese")
			treeparams.leaves = minetest.get_content_id("default:coalblock")
		else
			treeparams.trunk = minetest.get_content_id("default:tree")
			treeparams.leaves = minetest.get_content_id("default:leaves")
		end
		
		local c_stone = minetest.get_content_id("default:stone")
		local c_dirt = minetest.get_content_id("default:dirt")
		local c_dirt_with_grass = minetest.get_content_id("default:dirt_with_grass")
		
		local data = vm:get_data()
		local vi
		
		for x=minp.x+1,maxp.x-1 do
		for z=minp.z+1,maxp.z-1 do
			local surf=minp.y+math.floor(40+25*perlin1:get2d({x=x,y=z}))
			local top=math.floor(3+2*perlin2:get2d({x=x,y=z}))
			if surf>maxp.y then surf=maxp.y end
			if top+minp.y>=surf then top=surf-1-minp.y end
			for y=minp.y, surf-top do
				vi = a:index(x, y, z)
				data[vi] = c_stone
			end
			for y=surf-top, surf-1 do
				vi = a:index(x, y, z)
				data[vi] = c_dirt
			end
			data[a:index(x, surf, z)] = c_dirt_with_grass
			if surf<water_level then
				for yw=surf+1,water_level do
					data[a:index(x,yw,z)] = sea
				end
			else
				if math.random()<=treeparams.proba then
					spawntree(a, data, {x=x,y=surf+1,z=z}, treeparams)
				end
			end
		end
		end
		
		local c_barrier = minetest.get_content_id("realms:barrier")
		for y=minp.y,maxp.y do
			for x=minp.x,maxp.x do
				data[a:index(x,y,minp.z)]=c_barrier
				data[a:index(x,y,maxp.z)]=c_barrier
			end
			for z=minp.z,maxp.z do
				data[a:index(minp.x,y,z)]=c_barrier
				data[a:index(maxp.x,y,z)]=c_barrier
			end
		end
		vm:set_data(data)
	
		vm:calc_lighting(minp, maxp)
		vm:write_to_map(data)
	end
end)
