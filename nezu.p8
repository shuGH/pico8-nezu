pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--------------------------------
-- pico system - shuzo iwasaki -
--------------------------------
g_dbg = false
g_win = {x = 128, y = 128}

-- util ------------------------

function printl(s,x,y,c)
	print(s,x,y,c)
end
function printr(s,x,y,c)
	x -= (#s*4)-1
	print(s,x,y,c)
end
function printm(s,x,y,c)
	x -= ((#s*4)/2)-1
	print(s,x,y,c)
end

function rndr(l,u)
	return rnd(abs(u-l))+min(l,u)
end

function rndi(u)
	return flr(rnd(u+1))
end

function rndir(l,u)
	return rndi(abs(u-l))+min(l,u)
end

function isort(list,fnc)
	for i=1,#list do
		local j=i
		while j>1 and fnc(list[j-1], list[j]) do
			list[j-1],list[j] = list[j],list[j-1]
			j-=1
		end
	end
end

function dist(x1,y1,x2,y2)
	-- anti overflow
	local d = max(abs(x1-x2), abs(y1-y2))
	local n = max(abs(x1-x2), abs(y1-y2)) / d
	return sqrt(n*n + 1)*d
end

function is_collide(x1,y1,r1,x2,y2,r2)
	return dist(x1,y1,x2,y2) <= (r1 + r2)
end

function inherit(sub, super)
	sub._super = super
	return setmetatable(
		sub, {__index = super}
	)
end

function instance(cls)
	return setmetatable(
		{}, {__index = cls}
	)
end

-- pico system ------------------------
-- default: x0 > x128, y128 ^ y0
-- p-sys:   x0 > x128, y0 ^ y128

p = {
	object = {},
	scene = {},

	scns = {},
	current = nil,
	next = nil,

	objs = {
		update = {},
		draw = {}
	}
}

p._comp_obj_update = function(a,b)
	return a._p.u > b._p.u
end

p._comp_obj_draw = function(a,b)
	return a._p.d > b._p.d
end

-- main loop

p.init = function()
end

p.update = function(delta)
	p._pre_update(delta)
	p._update_objs(delta)
	p._post_update(delta)
end

p._pre_update = function(delta)
	if p.next then
		p.current = p.next
		p.current:_init()
		p.current:init()
		p.next = nil
	end

	if p.current then
		p.current:_update(delta)
		p.current:pre_update(delta)
	end
end

p._update_objs = function(delta)
	foreach(p.objs.update,
		function(obj) obj:update(delta) end
	)
end

p._post_update = function(delta)
	if p.current then
		p.current:post_update(delta)
	end

	if p.next then
		p.current:fin()
		-- destroy all objs
		foreach(p.objs.update,
			function(obj) obj:destroy() end
		)
		p.current.objs = nil
	end
end

p.draw = function()
	p._pre_draw()
	p._draw_objs()
	p._post_draw()
end

p._pre_draw = function()
	if not p.current then return end
	p.current:pre_draw()
end

p._draw_objs = function()
	foreach(p.objs.draw,
		function(obj) obj:draw() end
	)
end

p._post_draw = function()
	if not p.current then return end
	p.current:post_draw()
end

-- scene

p.scene = {
	const = function(self,name)
		self.name = name
		self.cnt = 0
	end,

	_init = function(self)
		self.cnt = 0
	end,
	init = function(self) end,
	fin = function(self) end,

	_update = function(self,delta)
		self.cnt += 1
	end,
	pre_update = function(self,delta) end,
	post_update = function(self,delta) end,
	pre_draw = function(self) end,
	post_draw = function(self) end
}

-- add scene
p.add = function(name)
	local scn = inherit({},p.scene)
	scn:const(name)
	-- register
	p.scns[name] = scn
	return scn
end

-- move scene
p.move = function(name)
	if not p.scns[name] then return end
	p.next = p.scns[name]
end

-- object

p.object = {
	const = function(self,px,py,vx,vy,ax,ay,pu,pd)
		self._p  = {u=pu or 0, d=pd or pu or 0}
		self.pos = {x=px or 0, y=py or 0}
		self.vel = {x=vx or 0, y=vy or 0}
		self.acc = {x=ax or 0, y=ay or 0}

		self.size = 1
	end,
	dest = function(self)
	end,

	update = function(self,delta)
		self.vel.x += delta*self.acc.x
		self.vel.y += delta*self.acc.y
		self.pos.x += delta*self.vel.x
		self.pos.y += delta*self.vel.y
	end,
	draw = function(self)
		pset(self.pos.x,self.pos.y,7)
	end,

	set_priority = function(self,pu,pd)
		self._p.u = pu or 0
		self._p.d = pd or pu or 0
		isort(p.objs.update, p._comp_obj_update)
		isort(p.objs.draw, p._comp_obj_draw)
	end,
	is_collide = function(self,obj)
		return is_collide(self.pos.x,self.pos.y,self.size,obj.pos.x,obj.pos.y,obj.size)
	end
}

-- define object class
p.define = function(sub,super)
	super = super or p.object
	return inherit(sub, super)
end

-- create object
p.create = function(cls, ...)
	local obj = instance(cls)
	obj:const(...)
	-- register
	add(p.objs.update, obj)
	isort(p.objs.update, p._comp_obj_update)
	add(p.objs.draw, obj)
	isort(p.objs.draw, p._comp_obj_draw)
	return obj
end

-- destroy object
p.destroy = function(obj)
	obj:dest()
	-- unregister
	del(p.objs.update, obj)
	del(p.objs.draw, obj)
end

-- debug
p.draw_grid = function(num)
	for i=1,num-1 do
		line((128/num)*i,0, (128/num)*i,127, 2)
		line(0,(128/num)*i, 127,(128/num)*i, 2)
	end
end

-- debug
p.draw_debug = function()
	print("",0,0,11)
	print("scn: "..p.current.name.." "..p.current.cnt)
	print("obj: "..#p.objs.update)

	local str=""
	for i=1,#p.objs.update do
		str = str..p.objs.update[i]._p.u
		if i<#p.objs.update then str = str.."," end
	end
	print("ord: "..str)
end

-- nezu city ------------------------

nezumi = p.define({
	const = function(self,px,py,vx,vy)
		nezumi._super.const(self,px,py,vx,vy,0,15)
		self.color = 7
	end,
	dest = function(self)
	end,

	update = function(self,delta)
		nezumi._super.update(self,delta)

		if self.pos.x < 0 then
			self.pos.x = 0
			self.vel.x = abs(self.vel.x)
		end
		if self.pos.x > 127 then
			self.pos.x = 127
			self.vel.x = -abs(self.vel.x)
		end
		if self.pos.y > 127 then
			self.pos.y = 127
			self.vel.x =  0.8*self.vel.x
			self.vel.y = -0.8*abs(self.vel.y)
		end
	end,
	draw = function(self)
		circ(self.pos.x,self.pos.y,3,self.color)
	end
})

big_nezumi = p.define({
	const = function(self,px,py,vx,vy)
		big_nezumi._super.const(self,px,py,vx,vy)
	end,
	draw = function(self)
		circ(self.pos.x,self.pos.y,5,self.color)
	end
}, nezumi)

-- title ------------------------

scn_title = p.add("title")

function scn_title:init()
end

function scn_title:fin()
end

function scn_title:pre_update(delta)
	if btnp(🅾️) then
		p.move("ingame")
	end
end

function scn_title:post_update(delta)
end

function scn_title:pre_draw()
	printm("[title]",64,62,3)
end

function scn_title:post_draw()
end

-- ingame ------------------------

scn_ingame = p.add("ingame")

function scn_ingame:init()
	self.nezumis = {}
	self:add_nezumi()
end

function scn_ingame:fin()
	foreach(self.nezumis,
		function(nezumi) p.destroy(nezumi) end
	)
	self.nezumis = {}
end

function scn_ingame:pre_update(delta)
		if btnp(🅾️) then
		p.move("result")
	end
	if btnp(❎) then
		self:add_nezumi()
	end
end

function scn_ingame:post_update(delta)
	self:del_nezumi()
end

function scn_ingame:pre_draw()
end

function scn_ingame:add_nezumi()
	local cls = nezumi
	if rnd(100)>80 then cls = big_nezumi end
	local obj = p.create(
		cls,
		rndr(0,128),128,
		rndr(-30,30),rndr(-80,-20)
	)
	obj.color = rndir(1,15)
	obj:set_priority(rndir(0,10))
	add(self.nezumis, obj)
end

function scn_ingame:del_nezumi()
	if #self.nezumis > 10 then
		p.destroy(self.nezumis[1])
		del(self.nezumis, self.nezumis[1])
		self:del_nezumi()
	end
end

-- result ------------------------

scn_result = p.add("result")

function scn_result:init()
end

function scn_result:fin()
end

function scn_result:pre_update(delta)
	if btnp(🅾️) then
		p.move("title")
	end
	if btnp(❎) then
	end
end

function scn_result:pre_draw()
	printm("result",64,62,3)
end

-- init ------------------------

function _init()
	p.init()
	p.move("title")
end

-- update ----------------------

function _update()
	local delta = 1/30
	p.update(delta)
end

-- draw ------------------------

function _draw()
	cls()
	if g_dbg then p.draw_grid(8) end
	p.draw()
	if g_dbg then p.draw_debug() end
end

