pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

--
-- config
--

config = {
    intro = {},
    menu = {},
    help = {},
    levels = {},
    ready = {},
    play = {},
    finished = {},
    pause = {},
}

g_btn_confirm = 4
g_btn_back = 5
g_btn_jump = 4
g_btn_call = 5

-- menu navigation sfx
g_sfx_navigate = 38
g_sfx_confirm = 39

-- gameplay sfx
g_sfx_death = 37
g_sfx_happy = 36
g_sfx_saved = 32
g_sfx_jump = 35
g_sfx_ladder = 34
g_sfx_footstep = 33

-- sprites
g_spr_player = 18
g_spr_follower = 20
g_spr_exit = 26
g_spr_spikes = 36
g_spr_count = 48

g_fill_amount = 2

g_palette = {
    { 5, 13,  6 }, -- no color
    { 2,  8, 14 }, -- red
    { 1, 12,  6 }, -- blue
    { 4,  9, 10 }, -- yellow
    { 3, 11,  6 }, -- green
}

g_intro = {
    "episode 43",
    "<sacrifices must be made",
    "",
    "a long time ago,",
    "in a garden far,",
    "far away. . .",
    "",
    "the cats escaped!",
    "",
    "grandma must return",
    "them home safe. but",
    "<the journey is perilous",
    "and cats don't listen.",
    "",
    ". . . will she succeed",
    "eventually? it's only",
    "up to you. good luck!",
}

g_levels = {
    {  0,  0, 16,  7, "hello world!" }, -- level 1
    {  0,  7, 16,  9, "first sacrifice" }, -- level 2
    {  0, 16, 16, 13, "you control the\nplayer, not the\n  environment" }, -- level 3
    { 32,  0,  7, 16, "death is useful" }, -- level 4
    { 16,  0, 16, 16, "" }, -- test level
    --{ 16, 0, 23, 16, "" }, -- test level
}

g_ong_level = 0

--
-- levels
--

function make_world(level)
    local world = { x = 0, y = 0, w = 0, h = 0 }
    -- initialise world with level information
    if level > 0 and level <= #g_levels then
        world.x = g_levels[level][1]
        world.y = g_levels[level][2]
        world.w = g_levels[level][3]
        world.h = g_levels[level][4]
        world.name = g_levels[level][5]
    end
    world.spikes = {}
    world.cats = {}
    world.spikes_lut = {} -- fixme: not very nice
    world.goal = {}
    world.saved = { 0, 0, 0, 0, 0 }
    world.numbercats = { 0, 0, 0, 0, 0 }
    -- analyse level to find where the exit and traps are
    for y=world.y,world.y+world.h-1 do
        for x=world.x,world.x+world.w-1 do
            local sprite = mget(x, y)
            if sprite == g_spr_exit then
                world.exit = {x = 8 * x + 8, y = 8 * y + 12}
            elseif sprite == g_spr_spikes then
                local s = {x = 8 * x + 4, y = 8 * y + 4, fill = 0}
                add(world.spikes, s)
                world.spikes_lut[x + y / 256] = s
            elseif sprite >= g_spr_follower and sprite < g_spr_follower + 5 then
                local color = sprite - g_spr_follower + 1
                local spawn_count = mget(x, y - 1) - g_spr_count + 1
                local save_count = mget(x + 1, y) - g_spr_count + 1
                -- if count is above, it's a spawner
                if spawn_count > 0 and spawn_count < 16 then
                    local dir = x > world.x + world.w/2
                    for i=1,spawn_count do
                        local dx = i * (i % 2 * 2 - 1)
                        add(world.cats, new_cat(8 * x + 4 + dx, 8 * y - rnd(4), color, dir))
                    end
                    world.numbercats[color] += spawn_count
                -- otherwise, if count is on the right, it's a save goal
                elseif save_count > 0 and save_count < 16 then
                    world.goal[color] = (world.goal[color] or 0) + save_count
                end
            elseif sprite == g_spr_player then
                local dir = x > world.x + world.w/2
                world.player = new_player(8 * x + 8, 8 * y, dir)
            end
        end
    end
    -- detect walls for grass
    for y=0,world.h-1 do
        for x=0,world.w-1 do
            local wx = 8 * (world.x + x)
            local wy = 8 * (world.y + y)
            local sprite = 0
            local b1 = wall(wx, wy) and not wall(wx, wy - 4)
            local b2 = wall(wx + 4, wy) and not wall(wx + 4, wy - 4)
            local b3 = wall(wx, wy + 4) and not wall(wx, wy)
            local b4 = wall(wx + 4, wy + 4) and not wall(wx + 4, wy)
            if b1 and b2 then sprite = 28
            elseif b3 and b4 then sprite = 29
            elseif b1 then sprite = 44
            elseif b2 then sprite = 45
            elseif b3 then sprite = 30
            elseif b4 then sprite = 31
            end
            mset(128 - world.w + x, 64 - world.h + y, sprite)
        end
    end
    return world
end

--
-- constructors
--

function new_game()
    score = 0
    saved = 0
    particles = {}
    selectcolor = 1
    selectcolorscreen = false
    color = {1, 2, 3, 4, 5}
    world = make_world(level)
end

function new_entity(x, y, dir)
    return {
        x = x, y = y,
        dir = dir,
        anim = rnd(128),
        walk = rnd(128),
        climbspd = 0.5,
        grounded = false,
        ladder = false,
        jumped = false,
        jump = 0, fall = 0,
        cooldown = 0,
    }
end

function new_player(x, y, dir)
    local e = new_entity(x, y, dir)
    e.can_jump = true
    e.spd = 1.0
    e.spr = g_spr_player
    e.pcolors = { 5, 6 }
    e.call = 1
    return e
end

function new_cat(x, y, color, dir)
    local e = new_entity(x, y, dir)
    e.spd = crnd(0.4, 0.6)
    e.plan = {}
    e.color = color
    e.spr = g_spr_follower + e.color - 1
    e.pcolors = g_palette[e.color]
    return e
end

--
-- useful functions
--

function jump()
    if btn(2) or btn(g_btn_jump) then
        return true end
end

-- cool btnp(): ignores autorepeat

do
    local ub = _update_buttons
    local oldstate, state = 0, btn()
    function _update_buttons()
        ub()
        oldstate, state = state, btn()
    end
    function cbtnp(i)
        local bitfield = band(btnp(), bnot(oldstate))
        return not i and bitfield or band(bitfield, 2^i) != 0
    end
end

-- cool random

function crnd(a, b)
  return min(a, b) + rnd(abs(b - a))
end

function ccrnd(tab)  -- takes a tab and choose randomly between the elements of the table
  n = flr(crnd(1, #tab+1))
  return tab[n]
end

-- rect with smooth sides

function smoothrect(x0, y0, x1, y1, r, col)
    line(x0, y0 + r, x0, y1 - r, col)
    line(x1, y0 + r, x1, y1 - r, col)
    line(x0 + r, y0, x1 - r, y0, col)
    line(x0 + r, y1, x1 - r, y1, col)
    clip(x0, y0, r, r)
    circ(x0 + r, y0 + r, r, col)
    clip(x0, y1 - r, r, r + 1)
    circ(x0 + r, y1 - r, r, col)
    clip(x1 - r, y0, r + 1, r)
    circ(x1 - r, y0 + r, r, col)
    clip(x1 - r, y1 - r, r + 1, r + 1)
    circ(x1 - r, y1 - r, r, col)
    clip()
end

-- rect filled with smooth sides

function smoothrectfill(x0, y0, x1, y1, r, col1, col2)
    circfill(x0 + r, y0 + r, r, col1)
    circfill(x0 + r, y1 - r, r, col1)
    circfill(x1 - r, y0 + r, r, col1)
    circfill(x1 - r, y1 - r, r, col1)
    rectfill(x0 + r, y0, x1 - r, y1, col1)
    rectfill(x0, y0 + r, x1, y1 -r, col1)
    smoothrect(x0, y0, x1, y1, r, col2)
end

--
-- standard pico-8 workflow
--

function _init()
    poke(0x5f34, 1)
    cartdata("ld43_escargames")
    state = "intro"
    music(0)
    scroll = 0
    particles = {}
    num = {1}
    menu = {
        doordw = 128,
        doorx = 0,
        doorspd = 1,
        opening = false,
        rectpos = 1,
        high_y = 78,
        selectlevel = 1,
    }
    jump_speed = 1
    fall_speed = 1
    -- create sin/cos table
    st, ct = {}, {}
    for i=1,128 do
        st[i] = sin(i / 128)
        ct[i] = cos(i / 128)
    end
end

function _update60()
    config[state].update()
end

function _draw()
    config[state].draw()
end

--
-- intro
--

function config.intro.update()
    scroll += 1 / 4
    if cbtnp(g_btn_confirm) or scroll > #g_intro * 16 + 160 then
        state = "menu"
    end
end

function config.intro.draw()
    cls(0)
    camera(-64,-64)
    for x=1,128,2 do
        local m = 3 + ((2+x%3) * scroll + 1450*sin(x/73)) % 200
        pset(m * ct[x], m * st[x], x%3+5)
        pset(m * -st[x], m * ct[x], x%3+5)
    end
    camera()
    font_outline(1)
    if scroll > 130 then
        --print("🅾️ skip", 74, 112 - 8.5 * abs(sin(t()/2)), 9)
        --pico8_print("🅾️ skip", 101, 121 - 3.5 * abs(sin(t()/2)), 0)
        pico8_print("🅾️ skip", 100, 120 - 3.5 * abs(sin(t()/2)), 9)
    end
    font_center(true)
    for i=1,#g_intro do
        local line = 128 + i * 16 - scroll
        if line >= -20 and line < 128 then
            local str = g_intro[i]
            if sub(str,1,1) == "<" then
                font_scale(0.9)
                str = sub(str, 2, #str)
            end
            print(str, 64, line, 10)
            font_scale()
        end
    end
    font_center()
    font_outline()
end

--
-- menu
--

function config.menu.update()
    open_door()
    choose_menu()
end

function config.menu.draw()
    cls(0)
    draw_background()
    draw_menu()
    --draw_debug()
end

function open_door()
    if cbtnp(g_btn_confirm) then
        sfx(g_sfx_confirm)
        if menu.rectpos == 1 then
            menu.opening = true
        elseif menu.rectpos == 2 then
            state = "levels"
        elseif menu.rectpos == 3 then
            state = "help"
        end
    end

    if menu.opening == true then
        menu.doordw -= mid(2, menu.doordw / 5, 3) * menu.doorspd
        menu.doorx += mid(2, menu.doordw / 5, 3) * menu.doorspd
    end

    if menu.doordw < 2 then
        menu.opening = false
        level = menu.selectlevel
        new_game()
        state = "ready"
    end
end

function choose_menu()
    if btnp(3) and menu.rectpos < 3 then
        sfx(g_sfx_navigate)
        menu.rectpos += 1
    elseif btnp(2) and menu.rectpos > 1 then
        sfx(g_sfx_navigate)
        menu.rectpos -= 1
    end
end

--
-- get ready screen
--

function config.ready.update()
    if cbtnp(g_btn_confirm) then
        sfx(g_sfx_confirm)
        state = "play"
    end
end

function config.ready.draw()
    cls(0) fillp(0x1414) rectfill(0,0,128,128,1) fillp()
    font_outline(1)
    font_center(true)
    print("level "..level..":", 64, 20, 7)
    print(g_levels[level][5], 64, 40, 14)
    font_center()
    print("🅾️ play", 74, 112 - 8.5 * abs(sin(t()/2)), 9)
    font_outline()
end

--
-- level finished screen
--

function config.finished.update()
    if cbtnp(g_btn_confirm) then
        sfx(g_sfx_confirm)
        level += 1
        if level > #g_levels then
            -- beat the game...
            state = "menu"
        else
            new_game()
            state = "ready"
        end
    end
end

function config.finished.draw()
    cls(0) fillp(0x1414) rectfill(0,0,128,128,1) fillp()
    font_outline(1)
    font_center(true)
    print("congratulations!", 64, 20, 7)
    font_center()
    print("🅾️ continue", 54, 112 - 8.5 * abs(sin(t()/2)), 9)
    font_outline()
end

--
-- play
--

function config.play.update()
    update_particles()
    update_player()
    update_numbercats()
    update_cats()
    update_spikes()
    -- did we win?
    if world.win then
        world.win -= 1
        if world.win < 0 then
            state = "finished"
        end
    else
        local win = true
        for i, num in pairs(world.goal) do
            if world.saved[i] < num then
                win = false
            end
        end
        if win then
            world.win = 40
        end
    end
end

function config.play.draw()
    cls(0)
    -- player-centered camera if map is larger than screen, otherwise fixed camera
    camera(world.x * 8 + (world.w > 16 and mid(0, world.player.x - world.x * 8 - 64, world.w * 8 - 128) or 4 * world.w - 64),
           world.y * 8 + (world.h > 16 and mid(0, world.player.y - world.y * 8 - 64, world.h * 8 - 128) or 4 * world.h - 64))
    draw_world()
    draw_particles()
    draw_cats()
    draw_player()
    draw_grass()
    camera()
    draw_ui()
    --draw_debug()
end

function move_x(e, dx)
    if not wall_area(e.x + dx, e.y, 4, 4) then
        e.x += dx
    end
end

function move_y(e, dy)
    while wall_area(e.x, e.y + dy, 4, 4) do
        dy *= 7 / 8
        if abs(dy) < 0.00625 then return end
    end
    e.y += dy
    -- wrap around when falling
    if e.y > (world.y + world.h) * 8 + 16 then
        e.y = world.y * 8
    end
end

function update_particles()
    foreach (particles, function(p)
        p.x += p.vx or 0
        p.y += p.vy or 0
        p.vy = (p.vy or 0) + (p.gravity or 0)
        p.age -= 1
        if p.age < 0 then
            del(particles, p)
        end
    end)
end

function update_player()
    if not btn(g_btn_call) then
        selectcolor = 1
        update_entity(world.player, btn(0), btn(1), jump(), btn(3))
        selectcolorscreen = false
    elseif btn(g_btn_call) then
        update_entity(world.player)
        selectcolorscreen = true
        if btnp(0) and selectcolor > 1 then
            sfx(g_sfx_navigate)
            selectcolor -= 1
        elseif btnp(1) and selectcolor < #num then
            sfx(g_sfx_navigate)
            selectcolor += 1
        end
        world.player.call = num[selectcolor]
    end
     -- did we die in spikes or some other trap?
    if trap(world.player.x, world.player.y) then
        sfx(g_sfx_death)
        state = "finished"
    death_particles(world.player.x, world.player.y)
    end
end

function update_numbercats()
    if selectcolorscreen then
        num = {1}
        for i = 2, #world.numbercats do
            if world.numbercats[i] != 0 then
                add(num, i)
            end
        end
    end
end

function update_cats()
    foreach(world.cats, function(t)
        local old_x, old_y = t.x, t.y
        update_entity(t, t.plan[0], t.plan[1], t.plan[2], t.plan[3])
        for i = 0, 3 do
            t.plan[i] = false
        end
        -- update move plan if necessary
        if world.player.call == t.color and not selectcolorscreen then -- go left or right or up or down
            if rnd(2) > 1.99 then
                sfx(g_sfx_happy)
                t.happy = 20
            end
            if t.happy then
                t.happy -= 1
            end
            if t.x < world.player.x - 1 then
                t.plan[1] = true
            elseif t.x > world.player.x + 1 then
                t.plan[0] = true
            elseif t.y < world.player.y - 4 then
                t.plan[3] = true
            elseif t.y > world.player.y + 4 then
                t.plan[2] = true
            end
        end
        -- did we reach the exit?
        if world.exit and
           abs(t.x - world.exit.x) < 2 and
           abs(t.y - world.exit.y) < 2 then
            sfx(g_sfx_saved)
            saved += 1
            world.numbercats[t.color] -= 1
            world.saved[t.color] += 1
            world.saved[1] += 1
            del(world.cats, t)
            -- save particles!
            for i=1,crnd(20,30) do
                add(particles, { x = t.x, y = t.y,
                                 vx = crnd(-.75,.75),
                                 vy = crnd(-.75,.75),
                                 gravity = -1/8,
                                 age = 20 + rnd(5), color = {6,15,7},
                                 r = { 0.5, 1, 1.5 } })
            end
        end
        -- did we die in spikes or some other trap?
        if trap(t.x, t.y) then
            sfx(g_sfx_death)
            s = world.spikes_lut[flr(t.x/8) + flr(t.y/8)/256]
            s.fill = min(s.fill + g_fill_amount, 8)
            world.numbercats[t.color] -= 1
            del(world.cats, t)
            death_particles(t.x, t.y)
        end
    end)
end

function update_entity(e, go_left, go_right, go_up, go_down)
    -- update some variables
    e.anim += 1

    local old_x, old_y = e.x, e.y

    -- check x movement (easy)
    if go_left then
        e.dir = true
        e.walk += 1
        move_x(e, -e.spd)
    elseif go_right then
        e.dir = false
        e.walk += 1
        move_x(e, e.spd)
    end

    -- check for ladders and ground below
    local ladder = ladder_area(e.x, e.y, 0, 4)
    local ladder_below = ladder_area_down(e.x, e.y + 0.0125, 4)
    local ground_below = wall_area(e.x, e.y + 0.0125, 4, 4)
    local grounded = ladder or ladder_below or ground_below

    -- if inside a ladder, stop jumping
    if ladder then
        e.jump = 0
    end

    -- if grounded, stop falling
    if grounded then
        e.fall = 0
    end

    -- allow jumping again
    if e.jumped and not go_up then
        e.jumped = false
    end

    if go_up then
        -- up/jump button
        if ladder then
            move_y(e, -e.climbspd)
            ladder_middle(e)
        elseif grounded and e.can_jump and not e.jumped then
            e.jump = 20
            e.jumped = true
            e.walk = 8
            if state == "play" then
                sfx(g_sfx_jump)
            end
        end
    elseif go_down then
        -- down button
        if ladder or ladder_below then
            move_y(e, e.climbspd)
            ladder_middle(e)
        end
    end

    if e.jump > 0 then
        move_y(e, -mid(1, e.jump / 5, 2) * jump_speed)
        e.jump -= 1
        if old_y == e.y then
            e.jump = 0 -- bumped into something!
        end
    elseif not grounded then
        move_y(e, mid(1, e.fall / 5, 2) * fall_speed)
        e.fall += 1
    end

    if grounded and old_x != e.x then
        if last_move == nil or time() > last_move + 0.25 then
            last_move = time()
            sfx(g_sfx_footstep)
        end
    end

    if ladder and old_y != e.y then
        if last_move == nil or time() > last_move + 0.25 then
            last_move = time()
            sfx(g_sfx_ladder)
        end
    end

    e.grounded = grounded
    e.ladder = ladder

    -- footstep particles
    if (old_x != e.x or old_y != e.y) and rnd() > 0.5 then
        add(particles, { x = e.x + crnd(-3, 3),
                         y = e.y + crnd(2, 4),
                         vx = rnd(0.5) * (old_x - e.x),
                         vy = rnd(0.5) * (old_y - e.y) - 0.125,
                         age = 20 + rnd(5), color = e.pcolors,
                         r = { 0.5, 1, 0.5 } })
    end
end

function update_spikes()
    foreach(world.spikes, function(s)
        local cx, cy = (s.x - 4) / 8, (s.y - 4) / 8
        local left = world.spikes_lut[cx - 1 + cy / 256]
        local right = world.spikes_lut[cx + 1 + cy / 256]
        if left and left.fill < s.fill then
            left.fill += 1
            s.fill -= 1
        end
        if right and right.fill < s.fill then
            right.fill += 1
            s.fill -= 1
        end
    end)
end

-- walls, traps and ladders

function wall(x,y)
    local m = mget(x/8, y/8)
    return not fget(m, 4) and wall_or_ladder(x, y)
end

function wall_area(x,y,w,h)
    return wall(x-w,y-h) or wall(x-1+w,y-h) or
           wall(x-w,y-1+h) or wall(x-1+w,y-1+h) or
           wall(x-w,y) or wall(x-1+w,y) or
           wall(x,y-1+h) or wall(x,y-h)
end

function wall_or_ladder(x,y)
    local m = mget(x/8,y/8)
    if fget(m,5) and world then
        local spike = world.spikes_lut[flr(x/8) + flr(y/8)/256]
        if spike and spike.fill >= 8 then
            return true
        end
    end
    if ((x%8<4) and (y%8<4)) return fget(m,0)
    if ((x%8>=4) and (y%8<4)) return fget(m,1)
    if ((x%8<4) and (y%8>=4)) return fget(m,2)
    if ((x%8>=4) and (y%8>=4)) return fget(m,3)
    return true
end

function wall_or_ladder_area(x,y,w,h)
    return wall_or_ladder(x-w,y-h) or wall_or_ladder(x-1+w,y-h) or
           wall_or_ladder(x-w,y-1+h) or wall_or_ladder(x-1+w,y-1+h) or
           wall_or_ladder(x-w,y) or wall_or_ladder(x-1+w,y) or
           wall_or_ladder(x,y-1+h) or wall_or_ladder(x,y-h)
end

function trap(x,y)
    local m = mget(x/8, y/8)
    return fget(m, 5)
end

function death_particles(x, y)
    for i=1,crnd(20,30) do
        add(particles, { x = x, y = y,
                            vx = crnd(-.75,.75),
                            vy = crnd(-.75,.75),
                            gravity = 1/32,
                            age = 20 + rnd(5), color = {2,8,14},
                            r = { 0.5, 1.5, 0.5 } })
    end
end

function ladder(x,y)
    local m = mget(x/8, y/8)
    return fget(m, 4) and wall_or_ladder(x,y)
end

function ladder_area_up(x,y,h)
    return ladder(x,y-h)
end

function ladder_area_down(x,y,h)
    return ladder(x,y-1+h)
end

function ladder_area(x,y,w,h)
    return ladder(x-w,y-h) or ladder(x-1+w,y-h) or
           ladder(x-w,y-1+h) or ladder(x-1+w,y-1+h)
end

function ladder_middle(e)
    local ladder_x = flr(e.x / 8) * 8
    if e.x < ladder_x + 4 then
        move_x(e, 1)
    elseif e.x > ladder_x + 4 then
        move_x(e, -1)
    end
end

--
-- help
--

function config.help.update()
    if cbtnp(g_btn_back) then
        sfx(g_sfx_confirm)
        state = "menu"
    end
end

function config.help.draw()
    cls(0) fillp(0x1414) rectfill(0,0,128,128,1) fillp()
    font_outline(1)
    font_center(true)
    print("help", 64, 10, 7)
    font_center()
    print("❎ back", 74, 112 - 8.5 * abs(sin(t()/2)), 9)
    font_outline()
end

--
-- level selection screen
--

function config.levels.update()
    if menu.high_y > 15 then
        menu.high_y -= 2
    end
    if btnp(0) and menu.selectlevel > 1 then
        menu.selectlevel -= 1
        sfx(g_sfx_menu)
    elseif btnp(1) and menu.selectlevel < #g_levels then
        menu.selectlevel += 1
        sfx(g_sfx_menu)
    end
    if cbtnp(g_btn_confirm) then
        state = "menu"
        menu.opening = true
        g_ong_level = menu.selectlevel
        sfx(g_sfx_menu)
    end
    if cbtnp(g_btn_back) then
        state = "menu"
    end
end

function config.levels.draw()
    cls(0)
    draw_background()
    font_outline(1)
    print("❎ back", 74, 112 - 8.5 * abs(sin(t()/2)), 9)
    font_outline()
    draw_level_selector()
end

function draw_level_selector()
    font_center(true)
    font_outline(1)
    print("levels", 64, menu.high_y - 10, 13)
    font_center()
    font_outline()
    local select = {}
    if menu.selectlevel < 7 then
        for i = 1, min(6, #g_levels) do
            select[i] = {15, 9}
            select[menu.selectlevel] = {14, 8}
            smoothrectfill(-7 + 30*((i-1)%3 + 1), 25 + 30*flr((i-1)/3), 13 + 30*((i-1)%3 + 1), 45 + 30*flr((i-1)/3), 5, select[i][1], select[i][2])
            font_center(true)
            print(tostr(i), 5 + 29*((i-1)%3 + 1), 28 + 30*flr((i-1)/3), 5)
            font_center()
        end
    elseif menu.selectlevel < 13 then
        for i = 7, min(12, #g_levels) do
            select[i] = {15, 9}
            select[menu.selectlevel] = {14, 8}
            smoothrectfill(-7 + 30*((i-7)%3 + 1), 25 + 30*flr((i-7)/3), 13 + 30*((i-7)%3 + 1), 45 + 30*flr((i-7)/3), 5, select[i][1], select[i][2])
            font_center(true)
            print(tostr(i), 5 + 29*((i-7)%3 + 1), 28 + 30*flr((i-7)/3), 5)
            font_center()
        end
    elseif menu.selectlevel < 19 then
        for i = 13, min(19, #g_levels) do
            select[i] = {15, 9}
            select[menu.selectlevel] = {14, 8}
            smoothrectfill(-7 + 30*((i-13)%3 + 1), 25 + 30*flr((i-13)/3), 13 + 30*((i-13)%3 + 1), 45 + 30*flr((i-13)/3), 5, select[i][1], select[i][2])
            font_center(true)
            print(tostr(i), 5 + 29*((i-13)%3 + 1), 28 + 30*flr((i-13)/3), 5)
            font_center()
        end
    end
    for i = 1, 3 do
        font_outline(0.5, 0.5)
        print("★ ", 59 - 23 + (i - 1)*20, 85, 6, 10)
        font_outline()
    end
end

--
-- pause
--

function config.pause.update()
    if cbtnp(g_btn_confirm) then
        keep_score(score)
        state = "menu"
        world = make_world(g_ong_level)
        sfx(g_sfx_menu)
    end
end

function config.pause.draw()
    cls(0)
    draw_menu()
end

-- keeping scores

function keep_score(sc)
    for i = 5,1,-1 do
        if dget(i) < sc then
            dset(i+1,dget(i))
            dset(i, sc)
        end
    end
end

--
-- drawing
--

function draw_background()
    palt(0, false)
    sspr(80, 8, 16, 16, menu.doorx, 0, menu.doordw, 128)
    palt(0,true)
end

function draw_menu()
    if state == "menu" then
        if menu.doordw > 126 then
            palt(0, false)
            palt(14, true)
            palt()
            local rect_y0 = 35 + 20 * menu.rectpos
            local rect_y1 = 52 + 20 * menu.rectpos
            smoothrectfill(38, rect_y0, 90, rect_y1, 7, 6, 0)
            font_center(true)
            font_outline(1.5, 0.5, 0.5)
            font_scale(1.5)
            print("ld43        ", 64, 24, 11)
            print("        game", 64, 24, 15)
            font_scale()
            font_outline(1, 0.5, 0.5)
            print("play", 64, 57, 9)
            print("levels", 64, 77, 9)
            print("help", 64, 97, 9)
            font_outline()
            font_center(false)
        end
    elseif state == "pause" then
        font_scale(1.5)
        font_center(true)
        font_outline(1.5, 0.5, 0.5)
        print("game      ", 64, 32, 9)
        print("     over", 64, 32, 11)
        print("level "..g_ong_level, 64, 52, 3)
        font_outline(0.5, 0.5)
        for i = 1,3 do
            print("★ ", 64 - 30 + (i - 1)*20, 80, 10)
        end
        font_outline()
        font_scale()
        font_center()
    end
end

function draw_world()
    -- fill spikes
    foreach(world.spikes, function(s)
        rectfill(s.x - 4, s.y + 4, s.x + 3, s.y + 4 - s.fill, 8)
    end)
    -- draw world
    palt(14, true)
    map(world.x, world.y, 8 * world.x, 8 * world.y, world.w, world.h, 128)
    palt(14, false)
end

function draw_grass()
    map(128 - world.w, 64 - world.h, 8 * world.x, 8 * world.y - 2, world.w, world.h)
end

function draw_ui()
    font_outline(1)
    local cell = 0
    for color = 5, 1, -1 do
        if world.goal[color] and world.goal[color] > 0 then
            local x = 106 - 35 * cell
            for i=1,3 do pal(g_palette[3][i], g_palette[color][i]) end
            circfill(x - 6, 6, 4, 0)
            spr(66, x - 9, 3)
            pal()
            local c = world.saved[color] >= world.goal[color] and 11 or 14
            print(world.saved[color].."/"..world.goal[color], x, 2, c)
            cell += 1
        end
    end
    --if selectcolor > 1 then
        --local palette = g_palette[num[selectcolor]]
        --smoothrectfill(6, 3, 22, 17, 5, palette[2], 6)
        --print(world.numbercats[num[selectcolor]], 14, 4, palette[1])
    --end
    font_outline()
end

function draw_player()
    local player = world.player
    spr(68 + 2 * flr(player.walk / 8 % 4), player.x - 8, player.y - 4, 2, 1, player.dir)
    spr(80 + 2 * flr(player.anim / 16 % 2), player.x - 8, player.y - 11, 2, 2, player.dir)
    if selectcolorscreen then
        for i = 1, #num do
            local p = mid(world.x * 8 + #num*5, player.x, (world.x + world.w) * 8 - #num*5) - (#num-1)*7 + (i-1)*14
            local palette = g_palette[num[i]]
            rectfill((p - 4), player.y - 20, (p + 4), player.y - 12, palette[2])
            if i == 1 then
                line((p - 4), player.y - 20, (p + 4), player.y - 12, 7)
                line((p + 4), player.y - 20, (p - 4), player.y - 12, 7)
            else
                pico8_print(world.numbercats[num[i]], p - 1, player.y - 18, palette[1])
            end
            if i == selectcolor then
                rect((p - 5), player.y - 21, (p + 5), player.y - 11, 6)
            end
        end
    end
end

function draw_particles()
    foreach (particles, function(p)
        local t = p.age / 20
        circfill(p.x, p.y, p.r[1 + flr(t * #p.r)], p.color[1 + flr(t * #p.color)])
    end)
end

function draw_cats()
    foreach(world.cats, function(t)
        for i=1,3 do pal(g_palette[3][i], g_palette[t.color][i]) end
        spr(64 + flr(t.anim / 16 % 2), t.x - 4, t.y - 4, 1, 1, t.dir)
        spr(66, t.x - 4 + (t.dir and -2 or 2), t.y - 4 - flr(t.anim / 24 % 2), 1, 1, t.dir)
        pal()
        if t.happy and t.happy > 0 then
            palt(0,false)
            palt(15, true)
            spr(38, t.x - 4, t.y - 13)
            palt()
        end
    end)
end

function draw_debug()
    pico8_print("selectlevel "..tostr(menu.selectlevel), 5, 5, 7)
    --local j = 12
    --foreach(world.cats, function(t)
        --j += 6
        --print("cat "..t.x.." "..t.y, 5, j)
    --end)
end

--
-- font
--

double_homicide = {
  3568,1084,"!",
  12,24,0,28,"\"",
  288,3872,496,300,1952,508,288,32,"#",
  608,1656,3212,16382,1928,912,"$",
  24,52,7196,904,224,796,1156,1920,384,"%",
  3600,4024,1124,636,964,896,1600,1056,"&",
  24,12,"'",
  992,3128,4108,2,"(",
  2,8204,6192,1984,")",
  88,48,252,48,40,"*",
  0,0,0," ",
  7168,1536,",",
  128,128,192,64,"-",
  1536,512,".",
  6144,1792,192,48,12,2,"/",
  992,3128,6156,3612,1008,"0",
  16,3992,508,14,"1",
  1024,1584,1816,3468,2252,2168,"2",
  512,3608,3144,1764,956,272,"3",
  384,496,156,3968,480,128,"4",
  864,1656,3148,1612,968,392,"5",
  992,1784,3276,1664,896,"6",
  8,3848,492,60,12,"7",
  776,1948,3308,6392,1936,768,"8",
  32,112,88,4040,252,76,"9",
  1600,608,":",
  3136,1632,";",
  128,192,192,416,288,272,"<",
  288,288,160,160,128,"=",
  32,288,352,448,192,128,128,">",
  24,3532,1126,31,"?",
  8064,12384,10032,3224,1740,780,1816,496,"@",
  7424,3968,496,204,504,1984,64,"a",
  3584,2044,1132,1656,984,384,128,"b",
  1792,3552,3128,1548,796,"c",
  3840,4092,1052,568,480,192,"d",
  8136,4092,3292,1096,1096,8,"e",
  124,4092,204,72,72,8,"f",
  3968,4080,3128,1164,1676,8088,"g",
  1016,8160,128,192,8176,4092,64,"h",
  8176,252,"i",
  520,3080,7692,2044,12,4,"j",
  4032,1020,1632,3120,4104,"k",
  4064,4092,1024,1536,512,512,"l",
  3968,1008,60,496,96,1016,8128,"m",
  8128,1008,120,480,3968,1020,"n",
  2016,3128,1548,792,496,"o",
  316,8168,200,104,56,16,"p",
  480,1848,3084,1928,3856,6624,"q",
  60,4072,456,360,824,528,"r",
  1632,3312,6360,3980,816,"s",
  24,3992,508,8,4,"t",
  508,2016,1536,1792,960,252,"u",
  60,480,3840,960,224,24,"v",
  60,1008,7680,3840,448,384,3840,992,56,"w",
  2060,1848,480,1008,3608,4096,"x",
  24,48,7776,1008,28,"y",
  2064,3608,3464,1132,1564,516,"z",
  8190,6146,3078,1028,"[",
  4100,4102,8190,"]",
  24,12,6,12,48,"^",
  4096,4096,2048,2048,2048,"`",
  4,12,16,"_",
  128,3804,7014,8193,8193,"{",
  16352,254,"\\",
  8193,12342,8108,1600,64,"}",
  192,96,32,64,64,32,"~",
  128,384,384,12736,8128,8160,4092,2047,2046,4088,4064,4064,8032,7792,14384,8208,"★",
  448,2032,2032,4088,3544,3224,3644,3900,3900,3612,3788,3308,3580,2044,2040,1016,496,"❎",
  448,2032,2032,4088,3896,3608,3292,3532,3564,3564,3276,3612,3900,2044,2040,1016,496,"🅾️",
}

function load_font(data, height)
    pico8_print = pico8_print or print
    local m = 0x5f25
    local cache = {}
    local font = {}
    local acc = {}
    local outline = 0
    local ocol = 0
    local ox, oy = 0, 0
    local scale = 1
    local center = false
    for i=1,#data do
        if type(data[i])=='string' then
            font[data[i]] = acc
            acc = {}
        else
            add(acc, data[i])
        end
    end
    function font_outline(o, x, y, c)
        outline = o or 0
        ox, oy = x or 0, y or 0
        ocol = c or 0
    end
    function font_scale(s)
        scale = s or 1
    end
    function font_center(x)
        center = x or false
    end
    function print(str, x, y, col)
        local missing_args = not x or not y
        if missing_args then
            x,y = peek(m+1),peek(m+2)
        else
            poke(m+1,x) poke(m+2,y)
        end
        col = col or peek(m)
        str = tostr(str)
        local key = tostr(scale)..""..str
        local delta = min(1, 1/scale)
        local startx,starty = x,y
        local pixels = {}
        local xmax = 16
        if cache[key] then
            pixels = cache[key][1]
            xmax = cache[key][2]
        else
            x,y = 16,16
            for i=1,#str+1 do
                local ch=sub(str,i,i)
                local data=font[ch]
                if ch=="\n" or #ch==0 then
                    y += height * scale
                    x = 16
                elseif data then
                    for dx=0,#data,delta do
                        for dy=0,height,delta do
                            if band(data[1 + flr(dx)],2^flr(dy))!=0 then
                                pixels[flr(x + dx * scale) + flr(y + dy * scale) / 256] = true
                            end
                        end
                    end
                    x += (#data + 1) * scale
                    xmax = max(x - scale, xmax)
                end
            end
            -- count elements in the cache
            local count = 0
            for _,_ in pairs(cache) do
                count += 1
            end
            -- if cache is full, remove one argument at random
            if count > 16 then
                count = flr(rnd(count))
                for _,v in pairs(cache) do
                    count -= 1
                    if count == 0 then
                        del(cache, v)
                    end
                end
            end
            cache[key] = { pixels, xmax }
        end
        -- print outline
        local dx = startx - 16
        local dy = starty - 16
        if center then dx += flr((16 - xmax + 0.5) / 2) end
        if outline > 0 or ox != 0 or oy != 0 then
            for p,m in pairs(pixels) do
                local x,y = dx + ox + flr(p), dy + oy + p%1*256
                rectfill(x-outline,y-outline,x+outline,y+outline,ocol)
                --circfill(x, y, outline, ocol)
            end
        end
        -- print actual text
        for p,_ in pairs(pixels) do
            pset(dx + flr(p), dy + p%1*256, col)
        end
        -- save state
        poke(m, col)
        if missing_args then
            poke(m+1,startx - 16 + x) poke(m+2,starty - 16 + y)
        end
    end
end

load_font(double_homicide,14)

__gfx__
00000000424204404444444444450000000054540000000000000000544445440000000000004454444500004545000000005444444444544444545445440000
000000002040042044554444544400000000444400000000000000004454544400000000000054454454000044440000000044454454444445444444444d0000
00000000002004004444445444440000000044540000000000000000444445440000000000004444444400004454000000004544444454454445444454440000
000000000000020045444444445d0000000054440000000000000000454544450000000000004454544500005444000000005444454444544444454444540000
0000000000000000444454444442000000002444454400000000544d044024244544454400004444445400004445d4544544444542425444544544240000445d
00000000000000004444444440400000000004424454000000004444024004024444445400005445444400005454444544444544004054454455040400004544
0000000000000000445444542040000000000420544d0000000044540040020044544444000044444544000044444544444544440020d544444502020000d454
0000000000000000444444440020000000000200454400000000d44500200000454454450000545444450000454544444544445400005444544d000000004444
0000cccc09454490066666000000000000005500000022000000110000004400000033000000000000000000000000000a000000000000000000000000000000
0000c7760a0000a0677777600eeeee000005d65000028e200001c61000049a400003b63000000000000000000000000003b0bf0b000000000000000000000000
0000c7760944459067f1f1000eeeee000005dd50000288200001cc10000499400003bb30000000000000004540000000333b33b3000000000000000000000000
0000c6660a0000a006ffff000eeeee0000056d500002e82000016c100004a94000036b30000000000044004d4404450003b03033000000000000000000000000
cccc000009544490008ff8000eeeee00005ddd5000288820001ccc1000499940003bbb3000000000054444454444d4400000000000f0000000a00000000000a0
c77600000a0000a00888888f0eeeee0005dd6d500288e82001cc6c100499a94003bb6b300000000004d5455d5544544000000000b03b0ba0003b000000000b30
c7760000094454900ff888ff0eeeee00056dd50002e88200016cc10004a99400036bb300000000000444522112d544000000000033b3b3b3b3b3b0000003b33b
c66600000a0000a000cc0cc000000000005550000022200000111000004440000033300000000000004d21111112540000000000030303300303b00000030b30
0944459000000000000000000000000000000000e00eeeeef00f00ff000000000000000000000000044511101011d44000a00000000000a00000000000000000
0a0000a000000000eeeeee00eeeeee0007000700e440eeee07e0820f0000000000000000000000004452110101012544003b000000000b300000000000000000
0945449000000000eeeeee00eeeeee0007000700e0040eee0e88820f000000000000000000000000d5d11010101115453bb3b0000003b3330000000000000000
0a0000a000000000eeeeee00eeeeee0007600760e00040eef08820ff0000000000000000000000004451010101011d54030300000003030b0000000000000000
0000000009444590eeeeee00eeeeee0007600760e00040eeff020fff000000000000000000000000045210000011254400000000000000000000000000000000
000000000a0000a0eeeeee00eeeeee0067606760e0040eeefff0ffff000000000000000000000000045101000001154000000000000000000000000000000000
00000000094544900eeeee0000000000676d676de440eeeeffffffff00000000000000000000000044d1100000101d4000000000000000000000000000000000
000000000a0000a00000000000000000676d676de00eeeeeffffffff000000000000000000000000d45101000001155400000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007000000770000007770000070000000777000000770000077700000070000000700000700700007007000070770000000000000000000000000000000000
00077000000007000000070000070700000700000007000000000700000707000007070007707070077077000770007000000000000000000000000000000000
00007000000070000000700000077700000770000007700000007000000070000000770000707070007007000070070000000000000000000000000000000000
00007000000700000000070000000700000007000007070000007000000707000000070000707070007007000070700000000000000000000000000000000000
00007000000777000007700000000700000770000000700000007000000070000007700000700700007007000070777000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000010010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000160161000000000000022200000000000000000000000000000222000000000000000000000000000000000000000000000000000000000
000000000000000016cccc1000000000000028822800000000002220000000000002888228000000000022200000000000000000000000000000000000000000
11000000000000001cc7c710000000000002886ff820000000008882282e00000028886ff8200000000e28822820000000000000000000000000000000000000
cc1111001111110001c7c71000000000000286fff820000000066ff8882e0000002886fff8200000000e28886fff000000000000000000000000000000000000
01cc6c10cc6c6c1001cccc10000000000000286f882000000006ff8882c100000002286f880000000001128886ff100000000000000000000000000000000000
016cc1000cccc1000011110000000000000001c1ccc10000001cf2882cc10000000001ccc1c10000001cc12222c1000000000000000000000000000000000000
0c1c10c001c1c1000000000000000000000000111110000000011000111000000000001111100000000110001110000000000000000000000000000000000000
00000666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006777777600000000006666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00067777777760000000667777660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00677777766660000006777777776000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
006776676fff00000067777776676000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00676ff6ff1f0000006776676ff60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0088fff6ff15500000866ff6ff1f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0678ffffeefff0000688fff6ff155000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06776fffeeff000006776fffeefff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0066000ffff0000000660fffeeff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000ffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
00838f81828488838c8a858d8e8b8789869f0000000000000000808000000000939c0000a000000000008080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0e07070707070707070707070707070d0e07070707070707070707070707070d0e07070707070d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a3000000000000000000000000000090a3232000000000000000000000000090a0000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000016300000000000090a1615000000000000000000000000090a0000000035090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000017300000000000090e0707070707070707111107070300020a0000000016090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a303000000000001a1b0000000000090a0000000000000000111100000000020a00000007070d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a161700000000002a2b0000120000090a0000000000000000111100000000020e0700000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070707070707070707070707070707070e00040707070707070707070d0000020a0016350000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e07070707070707070707070707070d0a0000000000000000000000092424020a001a1b0000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a3100000000000000000000000000090a0000000000000000000000090202020a002a2b0000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000000012000000090e07070707070707070703000707070d0e07070707070d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000000007070000090a0000000000000000000000000000090a0000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000143100000000090a0000000000000000000000000000090a0000000012090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a33310000000000001a1b00000000090a0000000000000000000000000000090a00000000070d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a16150000000000002a2b00000000090a000014351a1b0000000000000000090a0000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070707070d240e0707070707070707070a000000002a2b0000000000001200090a2424242424090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000004070300000000000000000007070707070707070707070707070707070707070707070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e07070707070707070707070707070d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a32000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000707070000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00120000000000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00070700000000000000000707000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b24242424242424242424242424240c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e07070707070707070707070707070d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000001431000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a33310000000000001a1b000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a15160000000000002a2b000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070707070d240e07070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000004070300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
011e0000250002500025000250002500025000250002500025000250002500025000240002400024000240001a000130001c00011000000001100000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011800002502425022250222502225022250222502225022250222502225022250252402424022240222402225022250222502225022250222502225022250222502225022250222502524024240222402224025
011800001612419120161201912016120191201612019120161201912016120191201612019120161201612012120161201212016120121201612012120161201212016120121201612012120161201212012120
011800002502425022250222502225022250222502225022250222502225022250252902429022290222902527024270222702227022270222702227022270222702227022270222702227022270222702227025
01180000191201d120191201d120191201d120191201d120191201d120191201d120191201d1201912019120181201b120181201b120181201b120181201b120181201b120181201b120181201b120181201b120
011800002402025020240202502022022220222402025024250222502522022220222402025020220222202224020250202402025020220222202224020250202202222022200242002220022200222002220025
013000001612019120161201912016120191201612019120121201912012120191201212019120121201212000000000000000000000000000000000000000000000000000000000000000000000000000000000
011800002902429022290222902229022290222902229022290222902229022290252002420022200222002527024270222702227022270222702227022270222702227022270222702227022270222702227025
0130000019120191201b120191201b120191201b120191201b120181201b120181201b120181201b120181201a100180001800000000000000000000000000000000000000000000000000000000000000000000
0118000000020000200002000020290202c0222c022290202c0242c0222c0222c0252902429022290252702025024250222502225025290202c0222c0222902029020290202c020290202c0222c022290202e020
0118000018120181201b1201b12018120181201b1201b1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201d1201212012120121201212012120121201212012120
011800002e0242e0222e025290202c0222c022290202c02029022290222c02029022290222c02029022290222c02029022290222c020290202702025020270242702227025250202702227022250202902429022
011800001212012120121201212012120121201212019120191201912019120191201912019120191201912019120191201912019120191201912019120191201912019120191201912019120191201912019120
011800002902229025270202902027020250202202422022220252502027024270222702529020270202502022024220222202525020270242702227025290202702025020200242002220025250202702427022
011800001912019120191201912019120191201d1201d1201d1201d1201d1201d1201d1201d1201d1201d120191201912019120191201912019120191201912019120191201d1201d1201d1201d1201d1201d120
01180000270252902027020250202c0242c0222c02529020270202c02031022310223002430022300223002531024310223102231022310223102231022310223102231022310223102530024300223002230025
011800001d1201d1201d1201d12020120201202012020120201202012020120201202012020120201202012016120191201612019120161201912016120191201612019120161201912019120161201612016120
011800003102431022310223102231022310223102231022310223102231022310253002430022300223002531024310223102231022310223102231022310223102231022310223102535024350223502235025
0118000012120161201212016120121201612012120161201212016120121201612012120161201212012120191201d120191201d120191201d120191201d120191201d120191201d120191201d1201912019120
011800003302433022330223302233022330223302233022330223302233022330253002430022300223002500000000000000000000000000000000000000000000000000000000000000000000000000000000
01180000181201b120181201b120181201b120181201b120181201b12018120181201212016120121201212000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c00003070030700307003070030700307003070030700307003070030700307003070030700307003070030700307003070030700307003070030700307003070030700307003070030700307003070030700
010c00001057410572105721057210572105721057210575000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01030000187301a7301c730187301a7301c730187301a730000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01050000222471e2471d2471a247222471e2471d2471a247000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a00001a0431c0430e1001010013100111000e10010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600003654638546395463a54600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c00002d7472b74729747287472c7472a7472974728745017050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01020000245442654327543285432a5432e5433154334545000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200002d5442f5402c5402d540305402e5450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 0c0b4344
00 0d0e4344
01 0f104344
00 11124344
00 0f104344
00 11124344
00 13145556
00 15164344
00 17184344
00 191a4344
00 1b1c4344
02 1f1e1d44

