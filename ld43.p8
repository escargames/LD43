pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

--
-- config
--

config = {
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

g_sfx_menu = 16
g_sfx_jump = 10
g_sfx_ladder = 13
g_sfx_footstep = 11

g_spr_player = 18
g_spr_follower = 20
g_spr_exit = 26
g_spr_spikes = 36
g_spr_count = 48

g_fill_amount = 2

g_palette = {{ 6, 5 }, { 2, 8 }, { 1, 12 }, { 4, 9 }, { 3, 11 }}

g_levels = {
    { 0,  0, 16,  7, "hello world!" }, -- level 1
    { 0,  7, 16,  9, "first sacrifice" }, -- level 2
    { 0, 16, 16, 13, "" }, -- level 3
    { 16, 0, 16, 16, "" }, -- test level
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
    world.tomatoes = {}
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
                        add(world.tomatoes, new_tomato(8 * x + 4 + dx, 8 * y - rnd(4), color, dir))
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
        anim = flr(rnd(10)),
        hit = 0,
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
    e.ssize = 2
    e.pcolors = { 3, 11 }
    e.call = 1
    return e
end

function new_tomato(x, y, color, dir)
    local e = new_entity(x, y, dir)
    e.spd = crnd(0.4, 0.6)
    e.ssize = 1
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
    cartdata("ld43_escargames")
    music(7, 8000)
    state = "menu"
    particles = {}
    num = {1}
    world = make_world(g_ong_level)
    menu = {
        doordw = 128,
        doorx = 0,
        doorspd = 1,
        opening = false,
        rectpos = 1,
        high_y = 78,
        selectlevel = 1,
        wait = 0
    }
    jump_speed = 1
    fall_speed = 1
end

function _update60()
    config[state].update()
end

function _draw()
    config[state].draw()
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
    if menu.wait > 0 then
        menu.wait -= 1
    end
    if cbtnp(g_btn_confirm) then
        if menu.rectpos == 1 then
            menu.opening = true
            music(-7, 5000)
        elseif menu.rectpos == 2 then
            state = "levels"
        elseif menu.rectpos == 3 then
            state = "help"
        end
        sfx(g_sfx_menu)
    end

    if menu.opening == true then
        menu.doordw -= mid(2, menu.doordw / 5, 3) * menu.doorspd
        menu.doorx += mid(2, menu.doordw / 5, 3) * menu.doorspd
    end

    if menu.doordw < 2 then
        menu.opening = false
        music(0,10000)
        level = menu.selectlevel
        new_game()
        state = "ready"
    end
end

function choose_menu()
    if btnp(3) and menu.rectpos < 3 then
        menu.rectpos += 1
        sfx(g_sfx_menu)
    elseif btnp(2) and menu.rectpos > 1 then
        menu.rectpos -= 1
        sfx(g_sfx_menu)
    end
end

--
-- get ready screen
--

function config.ready.update()
    if cbtnp(g_btn_confirm) then
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
    update_tomatoes()
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
    draw_tomatoes()
    draw_player()
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
            selectcolor -= 1
        elseif btnp(1) and selectcolor < #num then
            selectcolor += 1
        end
        world.player.call = num[selectcolor]
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

function update_tomatoes()
    foreach(world.tomatoes, function(t)
        local old_x, old_y = t.x, t.y
        update_entity(t, t.plan[0], t.plan[1], t.plan[2], t.plan[3])
        for i = 0, 3 do
            t.plan[i] = false
        end
        -- update move plan if necessary
        if world.player.call == t.color and not selectcolorscreen then -- go left or right or up or down
            if rnd(2) > 1.99 then
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
            saved += 1
            world.numbercats[t.color] -= 1
            world.saved[t.color] += 1
            world.saved[1] += 1
            del(world.tomatoes, t)
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
            s = world.spikes_lut[flr(t.x/8) + flr(t.y/8)/256]
            s.fill = min(s.fill + g_fill_amount, 8)
            world.numbercats[t.color] -= 1
            del(world.tomatoes, t)
            -- death particles!
            for i=1,crnd(20,30) do
                add(particles, { x = t.x, y = t.y,
                                 vx = crnd(-.75,.75),
                                 vy = crnd(-.75,.75),
                                 gravity = 1/32,
                                 age = 20 + rnd(5), color = {2,8,14},
                                 r = { 0.5, 1.5, 0.5 } })
            end
        end
    end)
end

function update_entity(e, go_left, go_right, go_up, go_down)
    -- update some variables
    e.anim += 1
    e.hit = max(0, e.hit - 1)

    local old_x, old_y = e.x, e.y

    -- check x movement (easy)
    if go_left then
        e.dir = true
        move_x(e, -e.spd)
    elseif go_right then
        e.dir = false
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
            if state == "play" then
                sfx(g_sfx_footstep)
            end
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
    if fget(m,5) and world.spikes_lut[flr(x/8) + flr(y/8)/256].fill >= 8 then
        return true
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
    if menu.high_y > 30 then
        menu.high_y -= 2
    end
    if btnp(0) and menu.selectlevel > 1 then
        menu.selectlevel -= 1
        sfx(g_sfx_menu)
    elseif btnp(1) and menu.selectlevel < #g_levels then
        menu.selectlevel += 1
        sfx(g_sfx_menu)
    end
    if cbtnp(g_btn_confirm) and menu.wait < 1 then
        state = "menu"
        menu.opening = true
        g_ong_level = menu.selectlevel
        sfx(g_sfx_menu)
    end
end

function config.levels.draw()
    cls(0)
    draw_background()
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
        smoothrectfill(-7 + 30*((i-1)%3 + 1), 40 + 30*flr((i-1)/3), 13 + 30*((i-1)%3 + 1), 60 + 30*flr((i-1)/3), 5, select[i][1], select[i][2])
        font_center(true)
        print(tostr(i), 5 + 29*((i-1)%3 + 1), 43 + 30*flr((i-1)/3), 5)
        font_center()
        end
    elseif menu.selectlevel < 13 then
        for i = 7, min(12, #g_levels) do
            select[i] = {15, 9}
            select[menu.selectlevel] = {14, 8}
            smoothrectfill(-7 + 30*((i-7)%3 + 1), 40 + 30*flr((i-7)/3), 13 + 30*((i-7)%3 + 1), 60 + 30*flr((i-7)/3), 5, select[i][1], select[i][2])
            font_center(true)
            print(tostr(i), 5 + 29*((i-7)%3 + 1), 43 + 30*flr((i-7)/3), 5)
            font_center()
        end
    elseif menu.selectlevel < 19 then
        for i = 13, min(19, #g_levels) do
            select[i] = {15, 9}
            select[menu.selectlevel] = {14, 8}
            smoothrectfill(-7 + 30*((i-13)%3 + 1), 40 + 30*flr((i-13)/3), 13 + 30*((i-13)%3 + 1), 60 + 30*flr((i-13)/3), 5, select[i][1], select[i][2])
            font_center(true)
            print(tostr(i), 5 + 29*((i-13)%3 + 1), 43 + 30*flr((i-13)/3), 5)
            font_center()
        end
    end
    for i = 1, 3 do
        font_outline(0.5, 0.5)
        print("★ ", 59 - 23 + (i - 1)*20, 100, 6, 10)
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
        music(-0, 5000)
        music(7, 8000)
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

function draw_ui()
    local cell = 5
    for color = 5, 1, -1 do
        if world.goal[color] and world.goal[color] > 0 then
            smoothrectfill(30 + 15*cell, 3, 40 + 15*cell, 13, 3, g_palette[color][2], 13)
            cell -= 1
        end
    end
    font_scale(0.8)
    print("goal", 20 + 15 * cell, 3, 7)
    font_scale()
    if selectcolor > 1 then
        local palette = g_palette[num[selectcolor]]
        smoothrectfill(6, 3, 22, 17, 5, palette[2], 6)
        font_center(true)
        print(world.numbercats[num[selectcolor]], 14, 4, palette[1])
        font_center(false)
    end
end

function draw_entity(e)
    if e.hit > 0 then for i = 1,15 do pal(i, 6 + rnd(2)) end end
    --spr(e.spr, e.x - 8, e.y - 12, 2, 2, e.dir)
    local dy = 2 * cos(e.anim / 32)
    local w = 8 * e.ssize
    sspr(e.spr % 16 * 8, flr(e.spr / 16) * 8, w, w, e.x - w / 2, e.y + 4 - w + dy, w, w - dy, e.dir)
    pal()
end

function draw_player()
    local player = world.player
    draw_entity(player)
    if selectcolorscreen then
        for i = 1, #num do
            local p = mid(world.x * 8 + #num*5, player.x, (world.x + world.w) * 8 - #num*5) - (#num-1)*5 + (i-1)*10
            local palette = g_palette[num[i]]
            rectfill((p - 2), player.y - 16, (p + 2), player.y - 12, palette[2])
            if i == 1 then
                line((p - 2), player.y - 16, (p + 2), player.y - 12, 7)
                line((p + 2), player.y - 16, (p - 2), player.y - 12, 7)
            end
            if i == selectcolor then
                rect((p - 3), player.y - 17, (p + 3), player.y - 11, 6)
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

function draw_tomatoes()
    foreach(world.tomatoes, function(t)
        draw_entity(t)
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
    --foreach(world.tomatoes, function(t)
        --j += 6
        --print("tomato "..t.x.." "..t.y, 5, j)
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
        local delta = min(1, 1/scale)
        local startx,starty = x,y
        local pixels = {}
        x,xmax,y = 16,16,16
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
                            pixels[flr(y + dy * scale) + flr(x + dx * scale) / 256] = true
                        end
                    end
                end
                x += (#data + 1) * scale
                xmax = max(x - scale, xmax)
            end
        end
        -- print outline
        local dx = startx - 16
        local dy = starty - 16
        if center then dx += flr((16 - xmax + 0.5) / 2) end
        if outline > 0 or ox != 0 or oy != 0 then
            for p,m in pairs(pixels) do
                local x,y = dx + ox + p%1*256, dy + oy + flr(p)
                rectfill(x-outline,y-outline,x+outline,y+outline,ocol)
                --circfill(x, y, outline, ocol)
            end
        end
        -- print actual text
        for p,_ in pairs(pixels) do
            pset(dx + p%1*256, dy + flr(p), col)
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
00000000424204404444444444450000000054540000000000000000555d55d50000000000004454444500004545000000005444444444544444545445450000
000000002040042044554444544500000000d44400000000000000004454544400000000000054454454000044450000000054454454444445444444444d0000
0000000000200400444444544445000000005454000000000000000044444544000000000000444444440000445d00000000d544444454454445444454450000
000000000000020045444444445d0000000054440000000000000000454544450000000000004454544500005445000000005444454444544444454444550000
0000000000000000444454444442000000002444d55d00000000555d04402424d555d5d500004444445400004445d55d555d544542425444544544240000555d
0000000000000000444444444040000000000442445500000000d444024004024444445400005445444400005454444544444544004054454455040400005544
0000000000000000445444542040000000000420544d0000000054540040020044544444000044444544000044444544444544440020d544444502020000d454
0000000000000000444444440020000000000200454500000000d44500200000454454450000545444450000454544444544445400005444544d000000005444
0000cccc09454490000000000000000000005500000022000000110000004400000033000000000000000000000000000a00030a000000000000000000000000
0000c7760a0000a000000000000000000005d65000028e200001c61000049a400003b630000000000000000000000000b3b0b30b000000000000000000000000
0000c7760944459000000000000000000005dd50000288200001cc10000499400003bb30000000000000004540000000333b3b53000000000000000000000000
0000c6660a0000a0000000000000000000056d500002e82000016c100004a94000036b30000000000044004d4404450000503030000000000000000000000000
cccc0000095444900000000330000000005ddd5000288820001ccc1000499940003bbb3000000000054444454444d44000000000a03000a00000000000000000
c77600000a0000a00000003bb300000005dd6d500288e82001cc6c100499a94003bb6b300000000004d5455d5544544000000000b03b0b3b0000000000000000
c776000009445490000003bbbb300000056dd50002e88200016cc10004a99400036bb300000000000444522112d544000000000035b3b3330000000000000000
c66600000a0000a0000003bb7b730000005550000022200000111000004440000033300000000000004d21111112540000000000030305000000000000000000
0944459000000000000003bb1b13000000000000e00eeeeef00f00ff000000000000000000000000044511101011d44000000000000000000000000000000000
0a0000a000000000000003bbbbb3000007000700e440eeee07e0820f000000000000000000000000445211010101254400000000000000000000000000000000
094544900000000000003bbbbbb3300007000700e0040eee0e88820f000000000000000000000000d5d110101011154500000000000000000000000000000000
0a0000a00000000000033bbb1113000007600760e00040eef08820ff0000000000000000000000004451010101011d5400000000000000000000000000000000
00000000094445900003bb3bbbb3000007600760e00040eeff020fff000000000000000000000000045210000011254400000000000000000000000000000000
000000000a0000a0003bb3bb3b30000067606760e0040eeefff0ffff000000000000000000000000045101000001154000000000000000000000000000000000
0000000009454490003bbbbbbb300000676d676de440eeeeffffffff00000000000000000000000044d1100000101d4000000000000000000000000000000000
000000000a0000a00003333333000000676d676de00eeeeeffffffff000000000000000000000000d45101000001155400000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007000000770000007770000070000000777000000770000077700000070000000700000700700007007000070770000000000000000000000000000000000
00077000000007000000070000070700000700000007000000000700000707000007070007707070077077000770007000000000000000000000000000000000
00007000000070000000700000077700000770000007700000007000000070000000770000707070007007000070070000000000000000000000000000000000
00007000000700000000070000000700000007000007070000007000000707000000070000707070007007000070700000000000000000000000000000000000
00007000000777000007700000000700000770000000700000007000000070000007700000700700007007000070777000000000000000000000000000000000
__gff__
00838f81828488838c8a858d8e8b8789869f0000000000000000808000000000939c0000a000000000008080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0e07070707070707070707070707070d0e07070707070707070707070707070d0707070707070d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a3000000000000000000000000000090a323200000000000000000000000009000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000000000000000090a161500000000000000000000000009000000000035090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000014310000000000090e070707070707070711110707030002130000000016090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a303000000000001a1b0000121300090a0000000000000000111100000000022300000007070d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a161600000000002a2b0000222300090a000000000000000011110000000002070700000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070707070707070707070707070707070a00040707070707070707070d000002000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e07070707070707070707070707070d0a000000000000000000000009242402000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a3100000000000000000012130000090a000000000000000000000009020202000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000000022230000090e07070707070707070703000407070d000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000000007070000090a1a1b14350000000000000000000009000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000143100000000090a2a2b00000000000000000000000009070700000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a33310000000000001a1b00000000090e07070707070707070707070707070d000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a15160000000000002a2b00000000090a121300000000000000000000000009000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070707070d240e0707070707070707070a222300000000000000000000000009000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000407030000000000000000000b08080808080808080808080808080c0808080808080c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e07070707070707070707070707070d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a32000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00121300000707070000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00222300000000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00070700000000000000000707000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b24242424242424242424242424240c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e07070707070707070707070707070d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000001431000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a33310000000000001a1b000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a15160000000000002a2b000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070707070d240e07070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000004070300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
