local m = {}
m.data = { -- example structure, should be overwritten by you
    [hash('animation_set')] = { -- completely arbitrary, name how you like
        animation = {0,0} -- key names should match animation_id from atlas
    }
}


function m.install(animation_set, data)
    pprint('Installing Annie for '..msg.url())
    local data = data or m.data
    local annie = {objects = {}, sprites = {}}
    annie.animation_set = animation_set 
	annie.current_animation = ''
    annie.last_animation = ''
	annie.locked = false
	annie.linked_timers = {}
    annie.cursor = 0

    local function verify_data(animation)
        local function keys(t)
            local keys = {}
            for k, v in pairs(t) do
                keys[#keys+1] = k
            end
            return keys
        end

        local exists = false

        for _, v in ipairs(keys(data)) do
            if v == annie.animation_set then
                exists = true
                break
            end
        end

        if not exists then 
            data[annie.animation_set] = {}
            if animation then 
                data[annie.animation_set][animation] = {0,0}
            end
        elseif not data[annie.animation_set][animation] then
            data[annie.animation_set][animation] = {0,0}
        end
    end

	function annie.offset(x, y)
		if type(x) == 'table' and not y then
			for _, url in ipairs(annie.objects) do
				go.set(url, 'position', vmath.vector3(x[1], x[2], 0))
			end
			return vmath.vector3(x[1], x[2], 0)
		elseif x and y then
			for _, url in ipairs(annie.objects) do
				go.set(url, 'position', vmath.vector3(x, y, 0))
			end
			return vmath.vector3(x, y, 0)
		end
	end

	function annie.play_anim(animation, mode, ...)
		if annie.locked then return end
        annie.cursor = go.get(annie.sprites[1], 'cursor') -- store cursor before animation change
		assert(type(animation) == 'string', '[Annie]: Animation name must be a string value!')
		if annie.current_animation ~= animation or mode == hash('force_replay') then
            annie.last_animation = annie.current_animation
			for _, url in ipairs(annie.sprites) do
				msg.post(url, 'play_animation', { id = hash(animation) })
				-- sprite.play_flipbook(url, hash(animation)) -- does the same thing as prev line
			end
			annie.current_animation = animation
            if annie.animation_set then
                verify_data(animation) -- can be removed if all animations are known and configured
                annie.offset(data[annie.animation_set][animation]) -- must use a string key due to serialization limits on hash()
            end
            ----------------------------------------------------
            -- cursor linking between animations
            if mode == hash('keep_cursor') then
                local linked = ... and {...} or nil

                if not linked then -- try to link using animation data
                    if annie.animation_set then
                        if data[annie.animation_set][animation] then
                            linked = data[annie.animation_set][animation]['keep_cursor']
                        end
                    else
                        print('[Annie]: Can\'t retain cursor for '..tostring(msg.url())..' -> animation_set is missing.')
                    end
                else
                    if type(linked[1]) == 'table' then
                        -- handling when the linked animations need to be provided as a single table
                        linked = linked[1]
                    end
                end

                if linked then
                    for _, v in ipairs(linked) do
                        if annie.last_animation == v then
                            annie.set_cursor(annie.cursor)
                            annie.last_animation = nil
                            break
                        end
                    end
                end
            end
		end
	end

    function annie.play(animation, mode, ...)
		annie.play_anim(animation, mode, ...)
		-- this function can be overwritten by the script with annie installed,
		-- to call play_anim() and flip_offset() to use locally scoped parameters,
		-- such as whether or not the object is facing to the left or not
	end

	function annie.set_cursor(cursor)
		if cursor then
			for _, url in ipairs(annie.sprites) do
				go.animate(url, 'cursor', go.PLAYBACK_ONCE_FORWARD, cursor, go.EASING_LINEAR, 0)
			end
		end
	end

	function annie.flip_offset(flip_x, flip_y)
		if annie.locked or (not flip_x and not flip_y) then return end

        if not annie.animation_set then
            local err = flip_x and 'X' or ''
            local err = flip_y and err..'Y' or err
            print('[Annie]: Can\'t flip '..err..' offset(s) for '..tostring(msg.url())..' -> animation_set is missing.')
            return
        end

        local c = go.get_position(annie.objects[1])
        local offset = data[annie.animation_set][annie.current_animation] or c
		local position = vmath.vector3()
        position.x = offset[1] or offset.x
        position.y = offset[2] or offset.y
		position.x = flip_x and position.x * -1 or position.x
		position.y = flip_y and position.y * -1 or position.y
		for _, url in ipairs(annie.objects) do
			go.set(url, 'position', position)
		end
	end

	function annie.lock(animation, mode, ...)
		if animation then
            annie.play(animation, mode, ...)
        end
		annie.locked = true
	end

	function annie.unlock(animation, mode, ...)
		annie.locked = false
        if animation then
            annie.play(animation, mode, ...)
        end
	end

	-- links a display gameobject to this annie instance
	-- the linked objects should all have the same animation groups!
	function annie.link(urlstring, sprite_name)
        local c = sprite_name or '#sprite'
		annie.objects[#annie.objects + 1] = msg.url(urlstring)
        annie.sprites[#annie.sprites + 1] = msg.url(urlstring..c)
	end

    -- links multiple gameobjects to this annie instance
    function annie.mlink(...)
        if not type(...) == 'table' then -- use default component name 'sprite'
            for i, v in ipairs({...}) do
                annie.objects[i] = msg.url(v)
                annie.sprites[i] = msg.url(v..'#sprite')
            end
        else -- use component name provided as a value where the key matches a gameobject urlstring
            local i = 1
            for k, v in pairs (...) do
                annie.objects[i] = msg.url(k)
                annie.sprites[i] = msg.url(k..v)
                i = i + 1
            end
        end
    end

	function annie.add_linked_timer(handle)
		table.add_new(annie.linked_timers, handle)
	end

	function annie.cancel_linked_timers()
		for _, t in ipairs(annie.linked_timers) do
			timer.cancel(t)
		end
		annie.timers = {}
	end

	function annie.animation_done()
		annie.unlock()
        annie.cancel_linked_timers()
	end
	
	return annie
end

return m