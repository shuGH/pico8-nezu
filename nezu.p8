pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
------------------------------------------------------------------------------------------------
-- pico system - shuzo iwasaki -
------------------------------------------------------------------------------------------------

g_dbg = true
g_win = {x = 128, y = 128}
g_fps = 30

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
	local n = min(abs(x1-x2), abs(y1-y2)) / d
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

------------------------------------------------------------------------------------------------
-- nezu city
------------------------------------------------------------------------------------------------

s_alphabet = {
"_","*",
"a","b","c","d","e","f","g","h",
"i","j","k","l","m","n","o","p",
"q","r","s","t","u","v","w","x",
"y","z",",",".","+","-","!","?",
}

s_grd = 90
s_letter = 20

s_score = 0
s_name = {1,1,1}
s_ranking_max = 5
-- num: -32768.0 to 32767.99 (overflow in calc is ok.)
s_num_offset = 32767

s_dbg_log = {'','',''}

-- util ------------------------

function to_name_str(name)
	local str = ""
	for i=1, 3 do
		if name[i] and s_alphabet[name[i]] then
			str = str..s_alphabet[name[i]]
		else
			str = str..s_alphabet[1]
		end
	end
	return str
end

function get_null_ranking(max)
	local ranking = {}
	for i=1, max do
		add(ranking, {n={1,1,1}, s=0})
	end
	return ranking
end

function save_name(name)
	dset(0, name[1])
	dset(1, name[2])
	dset(2, name[3])
end
function load_name()
	return {dget(0),dget(1),dget(2)}
end

function save_score(score)
	dset(3, score)
end
function load_score()
	return dget(3)
end

function init_data()
	dset(0, 0)
	dset(1, 0)
	dset(2, 0)
	dset(3, 0)
end

-- fade ------------------------

local fade_table={
	{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
	{1,1,1,1,1,1,1,0,0,0,0,0,0,0,0},
	{2,2,2,2,2,2,1,1,1,0,0,0,0,0,0},
	{3,3,3,3,3,3,1,1,1,0,0,0,0,0,0},
	{4,4,4,2,2,2,2,2,1,1,0,0,0,0,0},
	{5,5,5,5,5,1,1,1,1,1,0,0,0,0,0},
	{6,6,13,13,13,13,5,5,5,5,1,1,1,0,0},
	{7,6,6,6,6,13,13,13,5,5,5,1,1,0,0},
	{8,8,8,8,2,2,2,2,2,2,0,0,0,0,0},
	{9,9,9,4,4,4,4,4,4,5,5,0,0,0,0},
	{10,10,9,9,9,4,4,4,5,5,5,5,0,0,0},
	{11,11,11,3,3,3,3,3,3,3,0,0,0,0,0},
	{12,12,12,12,12,3,3,1,1,1,1,1,1,0,0},
	{13,13,13,5,5,5,5,1,1,1,1,1,0,0,0},
	{14,14,14,13,4,4,2,2,2,2,2,1,1,0,0},
	{15,15,6,13,13,13,5,5,5,5,5,1,1,0,0}
}

-- rate: [0.0,1.0]
function fade_scr(rate)
	for c=0,15 do
		local i = mid(0,flr(rate * 15),15) + 1
		pal(c,fade_table[c+1][i])
	end
end

-- gpio ------------------------

-- name: 36*36*36 = 46656
-- num: -32768.0 to 32767.99
-- gpio: 255*255 = 65025

s_gpio_cnt_idx = 10
s_gpio_ope_idx = 11
s_gpio_post_idx = 12
s_gpio_pull_idx = 12

function peek_gpio(idx)
	return peek(0x5f80 + idx)
end
function poke_gpio(idx, n)
	poke(0x5f80 + idx, n)
end

function to_gpio2(num16, is_offset)
	is_offset = is_offset or false
	if is_offset then
		return {(num16 + s_num_offset) % 256, flr((num16 + s_num_offset) / 256)}
	end
	return {num16 % 256, flr(num16 / 256)}
end
function from_gpio2(gpio2, is_offset)
	is_offset = is_offset or false
	if is_offset then
		return gpio2[1] + (gpio2[2] * 256) - s_num_offset
	end
	return gpio2[1] + (gpio2[2] * 256)
end

function to_name_offset16(arr)
	local num16o = -s_num_offset
	local n = 1
	for i=1, 3 do
		num16o += arr[i] * n
		n *= 40
	end
	return num16o
end
function from_name_offset16(num16o)
	local arr = {}
	local n = 1
	local mod = s_num_offset % 40
	local num = num16o + mod
	local off = s_num_offset - mod
	for i=1, 3 do
		-- over 32767/40 is not work
		mod = off % 40
		num += mod
		off -= mod
		if num < 0 then
			arr[i] = (num + off) % 40
		else
			arr[i] = ((num % 40) + (off % 40)) % 40
		end
		num = (num - arr[i])/40
		off = off/40
	end
	return arr
end

function increment_gpio_cnt()
	if (peek_gpio(s_gpio_cnt_idx) >= 256) then
		poke_gpio(s_gpio_cnt_idx, 0)
	else
		poke_gpio(s_gpio_cnt_idx, peek_gpio(s_gpio_cnt_idx) + 1)
	end
end
function set_gpio_ope(idx)
	-- 1:post, 2:pull, 3:post done, 4:pull ok
	poke_gpio(s_gpio_ope_idx, idx)
end

-- web api ------------------------

s_api = {
	init = function(self,max)
		self.cnt = 0
		self.elasped = -1.0
		self.max = max
		self.wait_max = 4.0
		self.callback_post = nil
		self.callback_pull = nil

		poke_gpio(s_gpio_cnt_idx, 0)
		poke_gpio(s_gpio_ope_idx, 0)
	end,
	update = function(self,delta)
		if self.elasped >= 0 then self.elasped += delta end
		if self.elasped >= self.wait_max then
			if self.callback_post ~= nil then self.callback_post() end
			if self.callback_pull ~= nil then self.callback_pull(get_null_ranking(self.max)) end
			self.elasped = -1.0
		end

		if self.cnt == peek_gpio(s_gpio_cnt_idx) then return end
		self.cnt = peek_gpio(s_gpio_cnt_idx)

		if peek_gpio(s_gpio_ope_idx) == 3 then
			if self.callback_post ~= nil then
				self.callback_post()
				self.callback_post = nil
			end
			self.elasped = -1.0
		elseif peek_gpio(s_gpio_ope_idx) == 4 then
			if self.callback_pull ~= nil then
				local ranking = get_null_ranking(self.max)
				for i=1, #ranking do
					local idx = s_gpio_pull_idx + (i-1) * 4
					if peek_gpio(idx) ~= 0 then
						ranking[i]["n"] = from_name_offset16(
							from_gpio2({peek_gpio(idx+0), peek_gpio(idx+1)}, true)
						)
						ranking[i]["s"] = from_gpio2({peek_gpio(idx+2), peek_gpio(idx+3)})
					end
				end
				self.callback_pull(ranking)
				self.callback_pull = nil
			end
			self.elasped = -1.0
		end
	end,

	post = function(self,name,score,callback)
		if self.elasped >= 0 then return end
		local name_gpio2 = to_gpio2(to_name_offset16(name), true)
		local score_gpio2 = to_gpio2(score)
		poke_gpio(s_gpio_post_idx + 0, name_gpio2[1])
		poke_gpio(s_gpio_post_idx + 1, name_gpio2[2])
		poke_gpio(s_gpio_post_idx + 2, score_gpio2[1])
		poke_gpio(s_gpio_post_idx + 3, score_gpio2[2])
		set_gpio_ope(1)
		increment_gpio_cnt()
		self.callback_post = callback
		self.elasped = 0
	end,
	pull = function(self,callback)
		if self.elasped >= 0 then return end
		set_gpio_ope(2)
		increment_gpio_cnt()
		self.callback_pull = callback
		self.elasped = 0
	end,
	exit = function(self)
		self.callback_post = nil
		self.callback_pull = nil
		self.elasped = -1
	end,
	draw_debug = function(self)
		printr(
			""..self.elasped..","..self.cnt.." ["..peek_gpio(s_gpio_cnt_idx)..","..peek_gpio(s_gpio_ope_idx).."]",
			g_win.y,0,11
		)
		printr(
			"["..peek_gpio(s_gpio_post_idx+0)..","..peek_gpio(s_gpio_post_idx+1)..","..peek_gpio(s_gpio_post_idx+2)..","..peek_gpio(s_gpio_post_idx+3).."]",
			g_win.x,6,11
		)
		local n = from_gpio2({peek_gpio(s_gpio_post_idx+0), peek_gpio(s_gpio_post_idx+1)}, true)
		local s = from_gpio2({peek_gpio(s_gpio_post_idx+2), peek_gpio(s_gpio_post_idx+3)})
		printr(
			"("..n..","..s..")",
			g_win.x,12,11
		)
	end
}

-- name reel ------------------------

char_reel = p.define({
	const = function(self, px, py, num, color)
		char_reel._super.const(self,px,py)
		self.chars = {}
		for i = 1, num do
			self.chars[i] = 1
		end

		self.index = 1
		self.color = color

		self.fixed = false
		self.decided = false
		self.duration = 0.4
		self.elasped = 0
	end,
	dest = function(self)
	end,

	update = function(self,delta)
		char_reel._super.update(self,delta)
		self.elasped = (self.elasped < self.duration * 2) and (self.elasped + delta) or (0)
	end,
	draw = function(self)
		-- blink after decided
		if self.decided then
			if self.elasped > self.duration then return end
		end

		local x = 0
		local y = 0
		color(self.color)
		print("[", self.pos.x + (-0 * 4), self.pos.y)
		for i = 1, #self.chars do
			local char = s_alphabet[self.chars[i]]
			if self.fixed then
				print(char, self.pos.x + (i * 4), self.pos.y)
			elseif (i ~= self.index) or (self.elasped > self.duration) then
				-- blink
				print(char, self.pos.x + (i * 4), self.pos.y)
			end
		end
		print("]", self.pos.x + ((#self.chars+1) * 4), self.pos.y)
	end,
	is_fixed = function(self)
		return self.fixed
	end,
	is_decided = function(self)
		return self.decided
	end,
	is_first = function(self)
		return (self.index == 1)
	end,
	is_last = function(self)
		return (self.index == #self.chars)
	end,
	decide = function(self)
		self.duration = 0.1
		self.decided = true
	end,
	fix = function(self)
		self.fixed = true
	end,
	cancel = function(self)
		self.fixed = false
		self.elasped = 0
	end,
	set_index = function(self, idx)
		self.index = mid(1, idx, #self.chars)
		if self.chars[self.index] == 1 then
			self.chars[self.index] = 2
		end
	end,
	next = function(self)
		self:set_index((self.index < #self.chars) and (self.index + 1) or (1))
		self.elasped = 0
	end,
	back = function(self)
		self:set_index((self.index > 1) and (self.index - 1) or (#self.chars))
		self.elasped = 0
	end,
	roll_up = function(self)
		self.chars[self.index] = (self.chars[self.index] < #s_alphabet) and (self.chars[self.index] + 1) or (2)
		self.elasped = self.duration
	end,
	roll_down = function(self)
		self.chars[self.index] = (self.chars[self.index] > 2) and (self.chars[self.index] - 1) or (#s_alphabet)
		self.elasped = self.duration
	end,

	set_name = function(self, name)
		for i=1, #self.chars do
			self.chars[i] = (name[i] == nil or name[i] <= 0 or name[i] > #s_alphabet) and 1 or name[i]
		end
	end,
	get_name = function(self)
		return self.chars
	end
})

-- ranking ------------------------

ranking_manager = p.define({
	const = function(self,px,py,max)
		ranking_manager._super.const(self,px,py)
		self.max = max
		self.ranking = get_null_ranking(self.max)
		self.marks = {128,129,130}
		self.loading = false
		self.cnt = 0
		self.anim = 0
		self.anim_d = 4
	end,
	dest = function(self)
		self.ranking = {}
	end,

	update = function(self,delta)
		ranking_manager._super.update(self,delta)
	end,
	draw = function(self)
		for i=1, self.max do
			local x = self.pos.x
			local y = self.pos.y + (10*(i-1))
			local name = "---"
			local score = 0
			if self.ranking[i] then
				name = to_name_str(self.ranking[i]["n"])
				score = self.ranking[i]["s"]
			 end
			printl(""..i..". ", x, y, 11)
			printl(""..name,    x+10, y, 11)
			printr(""..score,   x+64, y, 11)
			if self.marks[i] then
				spr(self.marks[i],x-12,y-2)
			end
		end

		if self.loading then
			self.cnt += 1
			if self.cnt % self.anim_d == 0 then self.anim += 1 end
			if self.anim >= 4 then self.anim = 0 end
			spr(144 + self.anim, g_win.x/2-4, g_win.x/2-4)
		end
	end,
	activate_loading = function(self, is_active)
		self.loading = is_active
		self.cnt = 0
	end,
	set_ranking = function(self, ranking)
		self.ranking = ranking
	end
})

-- score ------------------------

score_manager = p.define({
})

-- point ------------------------

char_point = p.define({
	const = function(self, pt, px, py)
		char_point._super.const(self,px,py,0,-12,0,2)
		self:set_priority(10,10)
		self.pt = pt
		self.remaining = 0.8
	end,
	dest = function(self)
	end,

	update = function(self,delta)
		char_point._super.update(self,delta)
		self.remaining -= delta
		if (self.remaining < 0) then
			p.destroy(self)
		end
	end,
	draw = function(self)
		local s = self.pt >= 0 and "+"..self.pt or ""..self.pt
		printm(s, self.pos.x, self.pos.y,11)
	end
})

-- effect ------------------------

effect_manager = p.define({
	const = function(self)
		effect_manager._super.const(self)
		self:set_priority(8,8)

		-- ptcl list {px,py,vx,vy,ax,ay,size,line,clr,life}
		self.ptcls = {}
		-- ptcl setting
		self.impact = {
			vx = 22,
			vy = 14,
			ax = 0,
			ay = 10,
			size = 2,
			life = 0.4,
			rect = 6,
			clrs = {9,9,9,10},
			num = 8,
			line = false
		}
		self.explosion = {
			vx = 30,
			vy = 18,
			ax = 0,
			ay = 14,
			size = 2.4,
			life = 0.6,
			rect = 8,
			clrs = {10,9,9,8,2},
			num = 10,
			line = false
		}
		self.dash = {
			vx = 6,
			vy = 0,
			ax = 0,
			ay = 0,
			size = 4,
			life = 0.4,
			rect = 10,
			clrs = {6,7,7},
			num = 8,
			line = true
		}
		self.jump = {
			vx = 22,
			vy = 4,
			ax = 0,
			ay = 15,
			size = 2,
			life = 0.4,
			rect = 4,
			clrs = {6,7,7},
			num = 4,
			line = false
		}

		-- fade
		self.fade_duration = 0.0
		self.fade_from = 0.0
		self.fade_to = 1.0
		self.fade_elasped = -1.0
	end,
	dest = function(self)
		for i=1, #self.ptcls do
			self.ptcls[i] = {}
		end
		self.ptcls = {}
		-- fade_scr(0.0)
	end,

	update = function(self,delta)
		effect_manager._super.update(self,delta)
		-- ptcl
		for i=#self.ptcls, 1, -1 do
			for j=#self.ptcls[i], 1, -1 do
				local ptcl = self.ptcls[i][j]
				ptcl.vx += ptcl.ax * delta
				ptcl.px += ptcl.vx * delta
				ptcl.vy += ptcl.ay * delta
				ptcl.py += ptcl.vy * delta
				ptcl.life -= delta
				if ptcl.life < 0.0 then
					del(self.ptcls[i], ptcl)
				end
			end
			if #self.ptcls[i] == 0 then
				del(self.ptcls, self.ptcls[i])
			end
		end
		-- fade
		if self.fade_elasped >= 0.0 then
			self.fade_elasped += delta
			if (self.fade_elasped > self.fade_duration) then
				fade_scr(self.fade_from)
				self.fade_elasped = -1.0
			else
				local r = self.fade_to + ((self.fade_from - self.fade_to) * (self.fade_elasped/self.fade_duration))
				fade_scr(r)
			end
		end
	end,
	draw = function(self)
		for i=1, #self.ptcls do
			for j=1, #self.ptcls[i] do
				local ptcl = self.ptcls[i][j]
				if ptcl.line then
					line(ptcl.px, ptcl.py, ptcl.px-ptcl.size, ptcl.py, ptcl.clr)
				else
					circfill(ptcl.px, ptcl.py, ptcl.size, ptcl.clr)
				end
			end
		end
	end,

	spawn_ptcl = function(self, setting, x,y, dx,dy)
		dx = dx or 0
		dy = dy or 0
		local ptcls = {}
		for i=1, setting.num do
			add(ptcls, {
				px = x + rndr(-setting.rect/2.0, setting.rect/2.0),
				py = y + rndr(-setting.rect/2.0, setting.rect/2.0),
				vx = rndr(-setting.vx, setting.vx) + dx,
				vy = rndr(-setting.vy, setting.vy) + dy,
				ax = setting.ax,
				ay = setting.ay,
				size = rndr(1,setting.size),
				clr = setting.clrs[rndir(1,#setting.clrs)],
				life = setting.life,
				line = setting.line
			})
		end
		add(self.ptcls, ptcls)
	end,
	fade_in = function(self,sec)
		self.fade_duration = sec
		self.fade_from = 0.0
		self.fade_to = 1.0
		self.fade_elasped = 0.0
	end,
	fade_out = function(self,sec)
		self.fade_duration = sec
		self.fade_from = 1.0
		self.fade_to = 0.0
		self.fade_elasped = 0.0
	end
})

-- cheese ------------------------

char_cheese = p.define({
	const = function(self, px, py, effect)
		char_cheese._super.const(self,px,py,0,0,0,0)
		self:set_priority(1,1)
		self.effect = effect
		self.size = 3
	end,
	dest = function(self)
	end,

	update = function(self,delta)
		char_cheese._super.update(self,delta)
	end,
	draw = function(self)
		spr(32,self.pos.x-4,self.pos.y-4,1,1)

		if g_dbg then circ(self.pos.x,self.pos.y,self.size,12) end
	end,
})

-- char ------------------------

char_base = p.define({
	const = function(self, px, py, v, dir, effect)
		self.effect = effect
		self.v = v
		-- dir (up, down, left, right)
		self.dir = dir

		char_base._super.const(self,px,py,0,0,0,0)
		self.color = 7
		self.cnt = 0
		self.anim = 0
		self.anim_base = 0
		self.anim_itvl = 8
		self.size = 3

		-- state (idling, moving, damaged, dead)
		self.state = "idling"
		self.prev = nil
		self.next = nil

		-- turn interval
		self.turn_itvl = 0
		self.turn_remaining = 0
	end,
	dest = function(self)
	end,

	update = function(self,delta)
		char_base._super.update(self,delta)

		-- turn interval
		if self.turn_remaining > 0 then
			self.turn_remaining -= delta
		end

		-- anim
		self.cnt += 1
		if self.cnt % self.anim_itvl == 0 then self.anim += 1 end
		if self.anim >= 2 then self.anim = 0 end

		-- dir
		self.vel.x = 0
		self.vel.y = 0
		if self.state == 'moving' then
			if self.dir == 'up'    then self.vel.y = -self.v end
			if self.dir == 'down'  then self.vel.y =  self.v end
			if self.dir == 'left'  then self.vel.x = -self.v end
			if self.dir == 'right' then self.vel.x =  self.v end
		end
	end,
	draw = function(self)
		local n = self.anim_base + self.anim
		if self.dir == 'up'    then n += 0 end
		if self.dir == 'down'  then n += 2 end
		if self.dir == 'left'  then n += 4 end
		if self.dir == 'right' then n += 6 end
		-- local f = self.stun_remaining > 0.0 or self.state == "dead"
		spr(n,self.pos.x-4,self.pos.y-4,1,1)

		if g_dbg then circ(self.pos.x,self.pos.y,self.size,11) end
	end,

	start = function(self)
		self.state = "moving"
	end,
	damage = function(self, d)
	end,
	turn = function(self, lr)
		if lr == 'left' then
			if     self.dir == 'up'    then self.dir = 'left'
			elseif self.dir == 'down'  then self.dir = 'right'
			elseif self.dir == 'left'  then self.dir = 'down'
			elseif self.dir == 'right' then self.dir = 'up' end
		elseif lr == 'right' then
			if     self.dir == 'up'    then self.dir = 'right'
			elseif self.dir == 'down'  then self.dir = 'left'
			elseif self.dir == 'left'  then self.dir = 'up'
			elseif self.dir == 'right' then self.dir = 'down' end
		end
		self.turn_remaining = self.turn_itvl
	end,

	is_alive = function(self)
		return self.state == "idling" or self.state == "moving"
	end
})

char_nezu = p.define({
	const = function(self, px, py, v, dir, effect)
		char_nezu._super.const(self, px, py, v, dir, effect)
		self:set_priority(3,3)

		self.anim_base = 0
		self.delay = 8 / v
		-- { lr = 'left', elasped = 0, dir = 'up', px = 0, py = 0 }
		self.cmds = {}
		self.turn_itvl = self.delay
		self.last_cmd = nil
		self.mem_cmd = nil
	end,
	pre_update = function(self, delta)
		-- call next turn
		for i = #self.cmds, 1, -1 do
			local cmd = self.cmds[i]
			if cmd.elasped >= self.delay then
				if self.next != nil then
					if self.next.state != 'idling' then
						self.next.pos.x = cmd.px
						self.next.pos.y = cmd.py
						self.next.dir = cmd.dir
						self.next:turn(cmd.lr)
					end
				end
				del(self.cmds, cmd)
			end
		end
	end,
	update = function(self,delta)
		char_nezu._super.update(self,delta)
		-- cmd
		foreach(self.cmds,
			function(cmd) cmd.elasped += delta end
		)
		-- turn interval
		if self.mem_cmd != nil then
			if self.turn_remaining <= 0 then
				self:turn(self.mem_cmd)
				self.mem_cmd = nil
			end
		end
	end,
	draw = function(self)
		char_nezu._super.draw(self)
		-- if g_dbg then printm(""..#self.cmds,self.pos.x,self.pos.y,11) end
		-- if g_dbg then printm(""..self.delay,self.pos.x,self.pos.y,11) end
	end,
	turn = function(self, lr)
		-- turn interval
		if self.turn_itvl > 0 and self.turn_remaining > 0 then
			if self.turn_remaining >= self.turn_itvl * 0.8 then
				return
			end
			-- ll or rr only
			if self.next != nil and self.last_cmd == lr then
				self.mem_cmd = lr
				return
			end
		end

		add(self.cmds, { lr = lr, elasped = 0.0, dir = self.dir, px = self.pos.x, py = self.pos.y })
		char_nezu._super.turn(self, lr)
		self.last_cmd = lr
	end,
	follow = function(self, target)
		self.prev = target
		target.next = self
	end
}, char_base)

char_konezu = p.define({
	const = function(self, px, py, v, dir, wait, effect)
		char_konezu._super.const(self, px, py, v, dir, effect)
		self:set_priority(2,2)

		self.anim_base = 8
		self.turn_itvl = 0
		self.wait = wait - (1/g_fps)
	end,
	pre_update = function(self, delta)
		char_konezu._super.pre_update(self, delta)
		if self.wait <= 0 then self:start() end
	end,
	update = function(self,delta)
		char_konezu._super.update(self,delta)
		if self.wait > 0 then self.wait = max(self.wait - delta, 0) end
	end,
	draw = function(self)
		char_konezu._super.draw(self)
	end,
}, char_nezu)

char_neko = p.define({
	const = function(self, px, py, v, dir, nezu, city, neffect)
		char_neko._super.const(self, px, py, v, dir, effect)
		self:set_priority(4,4)

		self.anim_base = 16
		self.nezu = nezu
		self.city = city
		self.turn_itvl = (8 / v)
	end,
	update = function(self,delta)
		-- chase (right higher priority)
		if self.turn_remaining - delta <= 0 then
			local p = self.city:get_fixed_pos(self.pos.x, self.pos.y)
			self.pos.x = p.x
			self.pos.y = p.y
			self.turn_remaining = 0

			local dx = self.nezu.pos.x - self.pos.x
			local dy = self.nezu.pos.y - self.pos.y
			if abs(dx) > abs(dy) then
				if     self.dir == 'up'    then self:turn(dx > 0 and 'right' or 'left')
				elseif self.dir == 'down'  then self:turn(dx > 0 and 'left' or 'right')
				elseif self.dir == 'left'  then self:turn(dx > 0 and 'right' or 'none')
				elseif self.dir == 'right' then self:turn(dx > 0 and 'none' or 'right') end
			else
				if     self.dir == 'up'    then self:turn(dy > 0 and 'right' or 'none')
				elseif self.dir == 'down'  then self:turn(dy > 0 and 'none' or 'right')
				elseif self.dir == 'left'  then self:turn(dy > 0 and 'left' or 'right')
				elseif self.dir == 'right' then self:turn(dy > 0 and 'right' or 'left') end
			end
		end

		char_neko._super.update(self,delta)
	end,
	draw = function(self)
		char_neko._super.draw(self)
	end
}, char_base)

-- letter box ------------------------

draw_letter_box = function()
	-- rectfill(0,0,128,s_letter,1)
	-- rectfill(0,128-s_letter,128,128,1)
	rectfill(0,0,s_letter,128,1)
	rectfill(128-s_letter,0,128,128,1)
end

-- background ------------------------

view_city = p.define({
	const = function(self, px, py, w, h)
		view_city._super.const(self,px,py)

		self.w = w
		self.h = h
		self.unit = { x = 8, y = 8 }
		self.scrl_vel = 1.2

		-- obj: { px, py, s }
		self.objs = {}
		self:create_objs(0)
	end,
	dest = function(self)
	end,
	update = function(self,delta)
	end,
	draw = function(self)
		foreach(self.objs,
			function(obj)
				spr(obj.s, obj.px, obj.py)
			end
		)

		if g_dbg then
			for i=0, self.w do
				local x = self.pos.x + (self.unit.x * i)
				line(x, self.pos.y, x, self.pos.y+(self.unit.y*self.h), 3)
			end
			for i=0, self.h do
				local y = self.pos.y + (self.unit.y * i)
				line(self.pos.x, y, self.pos.x+(self.unit.x*self.w), y, 3)
			end
		end
	end,

	scroll = function(self, delta)
	end,
	create_objs = function(self, offset)
	end,
	destroy_objs = function(self, offset)
	end,
	get_grid_pos = function(self, xi_min, xi_max, yi_min, yi_max)
		local xi_min = xi_min or 1
		local xi_max = xi_max or self.w
		local yi_min = yi_min or 1
		local yi_max = yi_max or self.h

		local xi = rndir(xi_min,xi_max)
		local yi = rndir(yi_min,yi_max)
		return {
			x = self.pos.x + (xi-0.5)*self.unit.x,
			y = self.pos.y + (yi-0.5)*self.unit.y
		}
	end,
	get_fixed_pos = function(self, px, py)
		local px = px - self.pos.x
		local py = py - self.pos.y
		local xi = ceil(px / self.unit.x)
		local yi = ceil(py / self.unit.y)
		-- adjust dot shift
		return {
			x = self.pos.x + (xi-0.5)*self.unit.x + 0.5,
			y = self.pos.y + (yi-0.5)*self.unit.y + 0.5
		}
	end
})

------------------------------------------------------------------------------------------------
-- title
------------------------------------------------------------------------------------------------

scn_title = p.add("title")

function scn_title:init()
	s_dbg_log = {'','',''}
	if g_dbg then
		-- init_data()
		local n = load_name()
		local s = load_score()
		s_dbg_log[3] = "["..n[1]..","..n[2]..","..n[3].."] "..s
	end

	self.effect = p.create(effect_manager)
	-- self.nezu = p.create(char_nezu, 65, 68, self.effect)
	-- self.neko = p.create(char_neko, 65, 68, self.effect)
	self.next = ""
	self.duration = 0.16
	self.elasped = -1.0

	-- self.nezu:start()
	-- self.neko:start()
	fade_scr(0.0)
end

function scn_title:fin()
	-- p.destroy(self.nezu)
	-- p.destroy(self.neko)
	p.destroy(self.effect)
end

function scn_title:pre_update(delta)
	if self.elasped >= 0.0 then
		self.elasped += delta
		if self.elasped > 1.2 then
			-- self.nezu:dash()
		end
		-- go to
		-- if self.elasped > 1.6 then
		if self.elasped > 0 then
			p.move(self.next)
		end
		-- button disable
		return
	end

	if btnp(🅾️) then
		self.next = "ingame"
		self.elasped = 0.0
		-- self.nezu.min_pos -= 16
		-- self.nezu.vel.x = -2

		-- local n = {rndir(3,#s_alphabet),rndir(3,#s_alphabet),rndir(3,#s_alphabet)}
		-- local s = rndir(1,12345)
		-- s_dbg_log[2] = ""..to_name_str(n).." "..s
		-- s_dbg_log[3] = "posting.."
		-- s_api:post(n,s,function()
		-- 	s_dbg_log[3] = "ok"
		-- end)
	end
	if btnp(❎) then
		if s_api.elasped < 0 then
			p.move("ranking")
		end
		-- local name = {1,2,3}
		-- s_api:pull(function(ranking)
		-- 	s_dbg_log[3] = ranking[1]["s"]
		-- end)
		-- s_dbg_log[3] = "pulling.."
	end
end

function scn_title:post_update(delta)
end

function scn_title:pre_draw()
	local px = 34
	local col = 10
	if self.elasped < 0 then
		print("press 🅾️ start",px,88,col)
		print("press ❎ ranking",px,98,col)
	else
		local d = self.duration * 2.0
		local f = (self.elasped % d > self.duration)
		if self.next ~= "ingame" or f then
			print("press 🅾️ start",px,88,col)
		end
		if self.next ~= "ranking" or f then
			print("press ❎ ranking",px,98,col)
		end
	end

	spr(192,32,20,8,2)
end

function scn_title:post_draw()
end

------------------------------------------------------------------------------------------------
-- ingame
------------------------------------------------------------------------------------------------

scn_ingame = p.add("ingame")

function scn_ingame:init()
	s_score = 0
	self.city = p.create(view_city, 32, 16, 8, 12)
	self.effect = p.create(effect_manager)

	self.nezu = p.create(char_nezu, 40, 40, 10, 'right', self.effect)
	self.konezu_list = {}
	self.neko = p.create(char_neko, 80, 80, 4, 'left', self.nezu, self.city, self.effect)
	self.cheese_list = {}
	-- self.score = p.create(score_manager, self.nezu, self.effect)

	self.started = false
	self.elasped = -1.0
	self.stage = 0

	self.msg = {
		str = "",
		life = 0.0,
		blink = false
	}
	self.duration = 0.16

	-- start demo
	-- self.nezu.pos.x = 44
	-- self.neko.pos.x = 44
	self.elasped = 0.0
	self.effect:fade_in(0.8)

	self:start()
end

function scn_ingame:start()
	local p = self.city:get_grid_pos()
	self.neko.pos.x = p.x
	self.neko.pos.y = p.y
	self.nezu:start()
	self.neko:start()
end

function scn_ingame:fin()

	-- s_score = self.score:get_score()
	-- p.destroy(self.score)
	p.destroy(self.effect)
	p.destroy(self.nezu)
	foreach(self.konezu_list,
		function(konezu) p.destroy(konezu) end
	)
	self.konezu_list = {}
	p.destroy(self.neko)
	foreach(self.cheese_list,
		function(cheese) p.destroy(cheese) end
	)
	self.cheese_list = {}

	p.destroy(self.city)
end

function scn_ingame:pre_update(delta)
	s_dbg_log[1] = self.nezu.dir
	s_dbg_log[2] = self.cnt

	-- pre
	self.nezu:pre_update(delta)
	foreach(self.konezu_list,
		function(konezu) konezu:pre_update(delta) end
	)

	-- check cheese
	foreach(self.cheese_list,
		function(c)
			if self.nezu:is_collide(c) then
				self:add_konezu()
				self:remove_cheese(c)
				self:add_cheese()
			end
		end
	)

	-- test
	if self.cnt == 30 then
		self:add_cheese()
	end

	if btnp(🅾️) then
		self.nezu:turn('left')
	end
	if btnp(❎) then
		self.nezu:turn('right')
	end
end

function scn_ingame:post_update(delta)
end

function scn_ingame:pre_draw()
end

function scn_ingame:post_draw()
	if self.elasped >= 0 then
		if not self.started then
			printm("[ready..]",64,48,12)
		else
			printm("[game over]",64,48,12)
		end
	else
		if self.msg.life > 0.0 then
		end
	end

	if self.cnt < 30*4.2 then
		printm("press 🅾️ left, ❎ right",60,98,12)
	end
end

function scn_ingame:add_konezu()
	local target = self.nezu
	local wait = target.delay
	if #self.konezu_list > 0 then
		target = self.konezu_list[#self.konezu_list]
		wait = target.delay
		-- tekito delay
		if target.wait > 0 then wait += target.wait + ((1/g_fps) * 1.6) end
	end
	local dir = target.dir
	local konezu = p.create(char_konezu, target.pos.x, target.pos.y, target.v, target.dir, wait, self.effect)
	konezu:follow(target)
	add(self.konezu_list, konezu)
end

-- function scn_ingame:del_nezumi()
-- 	if #self.nezumis > 10 then
-- 		p.destroy(self.nezumis[1])
-- 		del(self.nezumis, self.nezumis[1])
-- 		self:del_nezumi()
-- 	end
-- end

function scn_ingame:add_cheese()
	local pos = nil
	for i=1, 20 do
		local p = self.city:get_grid_pos()
		if self:check_cheese(p) then
			pos = p
			break
		end
	end
	if pos != nil then
		local cheese = p.create(char_cheese, pos.x, pos.y, self.effect)
		add(self.cheese_list, cheese)
	end
end

function scn_ingame:remove_cheese(cheese)
	del(self.cheese_list, cheese)
	p.destroy(cheese)
end

function scn_ingame:check_cheese(pos)
	local obj = {
		pos = pos,
		size = 4
	}
	if self.nezu:is_collide(obj) then
		return false
	end

	local f = true
	foreach(self.konezu_list,
		function(kn)
			if kn:is_collide(obj) then f = false end
		end
	)
	if f == false then return false end
	foreach(self.cheese_list,
		function(c)
			if c:is_collide(obj) then f = false end
		end
	)
	if f == false then return false end
	return true
end

------------------------------------------------------------------------------------------------
-- result
------------------------------------------------------------------------------------------------

scn_result = p.add("result")

function scn_result:init()
	self.reel = p.create(
		char_reel, g_win.x/2 - 10, g_win.y/2 + 8, 3, 7
	)
	self.reel:set_name(load_name())
	self.reel:set_index(1)
	self.is_new = s_score > load_score()
	self.elasped = -1.0

	fade_scr(0.0)
end

function scn_result:fin()
	p.destroy(self.reel)
end

function scn_result:pre_update(delta)
	if self.elasped >= 0 then
		self.elasped += delta
		-- goto title after decided
		if self.elasped >= 2.0 then
			p.move("title")
		end
		-- button disable
		return
	end

	if btnp(⬆️) or btnp(➡️) then
		if not self.reel:is_fixed() then
			self.reel:roll_up()
		end
	end
	if btnp(⬇️) or btnp(⬅️) then
		if not self.reel:is_fixed() then
			self.reel:roll_down()
		end
	end
	if btnp(🅾️) then
		if self.reel:is_fixed() then
			if s_api.elasped < 0 then
				self.reel:decide()
				self.elasped = 0.0

				-- update and post result
				s_name = self.reel:get_name()
				save_name(s_name)
				if self.is_new then save_score(s_score) end
				s_api:post(s_name, s_score, function()
				end)
			end
		else
			if not self.reel:is_last() then
				self.reel:next()
			else
				self.reel:fix()
			end
		end
	end
	if btnp(❎) then
		if self.reel:is_fixed() then
			self.reel:cancel()
		else
			if not self.reel:is_first() then
				self.reel:back()
			end
		end
	end
end

function scn_result:pre_draw()
	printm("thank you for playing!",64,26,3)
	printm("and",64,36,3)
	printm("yoi toshi de arimasuyouni.",64,46,3)

	print("score: ",   34,   60,11)
	printr(""..s_score,34+56,60,11)

	if self.is_new then
		printl("new!!",34+56+4,60,9)
	end
	if (self.reel:is_fixed() and self.elasped < 0) then
		printl("ok?",82,72,6)
	end

	print("press ⬇️ down, ⬆️ up",26,88,12)
	print("press ❎ back, 🅾️ ok",26,98,12)
end

------------------------------------------------------------------------------------------------
-- ranking
------------------------------------------------------------------------------------------------

scn_ranking = p.add("ranking")

function scn_ranking:init()
	self.ranking = p.create(
		ranking_manager, 34, 42, s_ranking_max
	)
	-- get ranking
	s_api:pull(function(ranking)
		self.ranking:set_ranking(ranking)
		self.ranking:activate_loading(false)
	end)
	self.ranking:activate_loading(true)
end

function scn_ranking:fin()
	s_api:exit()
	p.destroy(self.ranking)
end

function scn_ranking:pre_update(delta)
	if btnp(🅾️) then
	end
	if btnp(❎) then
		p.move("title")
	end
end

function scn_ranking:pre_draw()
	printm("[ranking]",64,26,3)
	print("press ❎ title",37,98,12)
end

------------------------------------------------------------------------------------------------
-- main
------------------------------------------------------------------------------------------------

-- init ------------------------

function _init()
	p.init()
	p.move("title")
	cartdata("nezu_city")
	s_api:init(s_ranking_max)
end

-- update ----------------------

function _update()
	local delta = 1/g_fps
	p.update(delta)
	s_api:update(delta)
end

-- draw ------------------------

function _draw()
	cls()
	if g_dbg then p.draw_grid(8) end
	p.draw()
	draw_letter_box()
	if p.current.name == "title" then
		printm("(c) shuzo.i 2020", g_win.x / 2, g_win.y-7, 13)
	end
	if g_dbg then
		for i=1, #s_dbg_log do
			print(s_dbg_log[i], 0, (g_win.y-18)+6*(i-1),11)
		end
		p.draw_debug()
		s_api:draw_debug()
	end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00055000000550000055550000555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00555500005555000055550000555500005555500055555005555500055555000005500000055000005555000055550000000000000000000000000000000000
00555500005555000055550000555500005555500055555005555500055555000055550000555500005555000055550000555500005555000055550000555500
00555500005555000055550000555500055555500555555005555550055555500055550000555500005555000055550005555500055555000055555000555550
00555500005555000055550000555500005555500055555005555500055555000055550000555500000550000005500000555500005555000055550000555500
00555500005555000005500000055000000500500050050005005000005005000000000000000000000000000000000000050500005050000050500000050500
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09000090090000900099990000999900090000900900909009009000090090000000000000000000000000000000000000000000000000000000000000000000
09999990099999900099990000999900999900909999909999099990990999900000000000000000000000000000000000000000000000000000000000000000
09999990099999900099990000999900999990099999900990099999900999990000000000000000000000000000000000000000000000000000000000000000
00999900009999000009900000099000999999099999990990999990909999900000000000000000000000000000000000000000000000000000000000000000
00099000000990000909909009099090999999999999999999999990999999900000000000000000000000000000000000000000000000000000000000000000
00999900009999000999999009999990099999900999999009999990099999900000000000000000000000000000000000000000000000000000000000000000
00999900009999000099990000999900099909900999099009990990099909900000000000000000000000000000000000000000000000000000000000000000
00099000000990000099990000999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
555555556666666622222222dddddddd8888888899999999ccccccccdddddddd33333333bbbbbbbb33333333bbbbbbbb00000000000000000000000000000000
555555556666666622222222dddddddd8888888899999999ccccccccdddddddd33333333bbbbbbbb33333333bbbbbbbb00000000055500000000000000099000
555555556666666622222222dddddddd8888888899999999ccccccccdddddddd33333333bbbbbbbb33333333bbbbbbbb00888880055500007777777700099000
555555556666666622222222dddddddd8888888899999999ccccccccdddddddd33333333bbbbbbbb33333333bbbbbbbb00888880055500000707070000009000
555555556666666622222222dddddddd8888888899999999ccccccccdddddddd33333333bbbbbbbb33333333bbbbbbbb08888888050000000707070000099000
555555556666666622222222dddddddd8888888899999999ccccccccdddddddd33333333bbbbbbbb33333333bbbbbbbb08888888050000007777777700999990
555555556666666622222222dddddddd8888888899999999ccccccccdddddddd33333333bbbbbbbb33333333bbbbbbbb00550550050000000000000000999990
555555556666666622222222dddddddd8888888899999999ccccccccdddddddd33333333bbbbbbbb33333333bbbbbbbb00000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a00a00006666000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0aaaa0a006666000004440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
aaaaaaaa006666000044244000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
aaaaaaaa000550000004440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a9999a0000550000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09999990006666000044444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000660000005500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000070070000600600005005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000006700000056000000050000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000006700000056000000050000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05000060000000500700000006000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00055000000000000007700000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000770000000000000000000000000000000000000000000770000000000000000000000000000000000000000000000000000000000000000000000000
00077000770000000000000000000000000000000000000000000770000000000000000000000000000000000000000000000000000000000000000000000000
00077007770000000000000000000077000007777700000000007770000000000000000000000000000000000000000000000000000000000000000000000000
00777007770000000000000000000077000777777700000007777777000000000000000000000000000000000000000000000000000000000000000000000000
00777007700000000000077770000777000777000000000007777777000000000000000000000000000000000000000000000000000000000000000000000000
00777777700777000777777770770777007770000007770000007700000000000000000000000000000000000000000000000000000000000000000000000000
07777777777777000777777700770777007700000007770000007700770000770000000000000000000000000000000000000000000000000000000000000000
07777777077777000000777000777777007700000000000000077700770007770000000000000000000000000000000000000000000000000000000000000000
07707770077777000007777000777770007700770007700000077000770077700000000000000000000000000000000000000000000000000000000000000000
07707770077770000007777770077770007777770007700000077000770777000000000000000000000000000000000000000000000000000000000000000000
77707700077000000077777770000770007777770007770000077700077770000000000000000000000000000000000000000000000000000000000000000000
77000000077770000077700000000770000777700007770000077700777700000000000000000000000000000000000000000000000000000000000000000000
77000000077770000000000000000000000000000000000000000007770000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000077770000000000000000000000000000000000000000000000000000000000000000000000
