pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

--
-- config
--

config = {
    menu = {},
    play = {},
    pause = {},
}

g_sfx_menu = 16
g_sfx_jump = 10
g_sfx_ladder = 13
g_sfx_footstep = 11

g_spr_player = 18
g_spr_follower = 20
g_spr_exit = 26
g_spr_spikes = 36

g_fill_amount = 2

g_palette = {{ 6, 5 }, { 2, 8 }, { 1, 12 }, { 4, 9 }, { 3, 11 }}

g_levelmax = 6

--
-- levels
--

function make_world(level)
    local world
    -- initialise world with level information
    if level == 0 then
        world = {
            x = 0, y = 0, w = 0, h = 0,
            player = new_player(64, 150),
        }
    elseif level == 1 then
        world = {
            x = 0, y = 6, w = 16, h = 8,
            player = new_player(100, 40),
        }
    elseif level == 2 then
        world = {
            x = 16, y = 0, w = 23, h = 16,
            player = new_player(144, 80),
        }
    end
    world.spikes = {}
    world.tomatoes = {}
    world.spikes_lut = {} -- fixme: not very nice
    -- analyse level to find where the exit and traps are
    for y=world.y,world.y+world.h-1 do
        for x=world.x,world.x+world.w-1 do
            if mget(x,y) == g_spr_exit then
                world.exit = {x = 8 * x + 8, y = 8 * y + 12}
            elseif mget(x,y) == g_spr_spikes then
                local s = {x = 8 * x + 4, y = 8 * y + 4, fill = 0}
                add(world.spikes, s)
                world.spikes_lut[x + y / 256] = s
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
    numbercats = {0, 0, 0, 0, 0}
    selectcolorscreen = false
    color = {1, 2, 3, 4, 5}
    world = make_world(1)
    -- spawn tomatoes (needs to be improved)
    for i=1,12 do
        add(world.tomatoes, new_tomato(8 * world.x + crnd(8, 24), 8 * world.y + crnd(-20,-50)))
    end
end

function new_entity(x, y)
    return {
        x = x, y = y,
        anim = flr(rnd(10)),
        hit = 0,
        climbspd = 0.5,
        dir = false,
        grounded = false,
        ladder = false,
        jumped = false,
        jump = 0, fall = 0,
        cooldown = 0,
    }
end

function new_player(x, y)
    local e = new_entity(x, y)
    e.can_jump = true
    e.spd = 1.0
    e.spr = g_spr_player
    e.ssize = 2
    e.pcolors = { 3, 11 }
    e.call = 1
    return e
end

function new_tomato(x, y)
    local e = new_entity(x, y)
    e.spd = crnd(0.4, 0.6)
    e.ssize = 1
    e.plan = {}
    e.color = flr(crnd(2, 6))
    numbercats[e.color] += 1
    e.spr = g_spr_follower + e.color - 2
    e.pcolors = g_palette[e.color]
    return e
end

--
-- useful functions
--

function jump()
    if btn(2) or btn(5) then
        return true end
end

-- cool random

function crnd(a, b)
  return min(a, b) + rnd(abs(b - a))
end

function ccrnd(tab)  -- takes a tab and choose randomly between the elements of the table
  n = flr(crnd(1, #tab+1))
  return tab[n]
end

-- cool print (centered, outlined, scaled)

function csprint(text, y, height, color)
    font_scale(height / 8)
    font_outline(2)
    local x = 64 - (2 * #text - 0.5) * height / 6
    print(text, x, y, color)
    font_scale()
    font_outline()
end

-- cool print (outlined)

function coprint(text, x, y, col)
    print(text, x+1, y+1, 0)
    print(text, x, y, col or 6)
end

-- cool rectfill (centered, outlined)

function corectfill(y0, y1, w, color1, color2)
    local x0 = 64 - ((w / 2))
    local x1 = 64 + ((w / 2) - 1)
    rectfill(x0, y0, x1, y1, color1)
    rect(x0, y0, x1, y1, color2)
end

-- cool rectfill (outlined)

function orectfill(x0, y0, x1, y1, color1, color2)
    rectfill(x0, y0, x1, y1, color1)
    rect(x0, y0, x1, y1, color2)
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
    world = make_world(0)
    menu = {
        doordw = 128,
        doorx = 0,
        doorspd = 1,
        opening = false,
        rectpos = 1,
        rect_y0 = 55,
        rect_y1 = 72,
        scores = false,
        high_y = 78,
        selectlevel = 1
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
    rect_menu()
    update_particles()
    update_player()
end

function config.menu.draw()
    cls(0)
    draw_world()
    draw_menu()
    --draw_debug()
end

function open_door()
    if btnp(4) and not menu.scores then
        if menu.rectpos == 1 then
            menu.opening = true
            music(-7, 5000)
        elseif menu.rectpos == 2 then
            menu.scores = true
        end
        sfx(g_sfx_menu)
    elseif btnp(5) and menu.scores then
        menu.scores = false
        menu.high_y = 78
        sfx(g_sfx_menu)
    end

    if menu.opening == true then
        menu.doordw -= mid(2, menu.doordw / 5, 3) * menu.doorspd
        menu.doorx += mid(2, menu.doordw / 5, 3) * menu.doorspd
    end

    if menu.scores == true then
        if menu.high_y > 30 then
            menu.high_y -= 2
        end
        if btnp(0) and menu.selectlevel > 1 then
            menu.selectlevel -= 1
        elseif btnp(1) and menu.selectlevel < g_levelmax then
            menu.selectlevel += 1
        end   
        if btnp(4) then
            make_world(menu.selectlevel)
        end      
    end

    if menu.doordw < 2 then
        menu.opening = false
        music(0,10000)
        state = "play"
        new_game()
    end
end

function rect_menu()
    if menu.rectpos == 1 then
        menu.rect_y0 = 55
        menu.rect_y1 = 72
    elseif menu.rectpos == 2 then
        menu.rect_y0 = 73
        menu.rect_y1 = 90
    end
end

function choose_menu()
    if btnp(3) and menu.rectpos < 2 then
        menu.rectpos += 1
        sfx(g_sfx_menu)
    elseif btnp(2) and menu.rectpos > 1 then
        menu.rectpos -= 1
        sfx(g_sfx_menu)
    end
end

--
-- play
--

function config.play.update()
    update_particles()
    update_player()
    update_tomatoes()
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
    if state == "play" then
        if e.y > 128 + 16 then
            e.y = 0
        end
    end
end

function update_particles()
    foreach (particles, function(p)
        p.x += rnd(1) - 0.5
        p.y -= rnd(0.5)
        p.age -= 1
        if p.age < 0 then
            del(particles, p)
        end
    end)
end

function update_player()
    if world.player.dead then return end

    if not btn(4) then
        update_entity(world.player, btn(0), btn(1), jump(), btn(3))
        selectcolorscreen = false
    elseif btn(4) and state == "play" then
        selectcolorscreen = true
        if btnp(0) and state == "play" and selectcolor > 1 then
            selectcolor -= 1
        elseif btnp(1) and state == "play" and selectcolor < #color then
            selectcolor += 1
        end
        world.player.call = selectcolor
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
            numbercats[t.color] -= 1
            del(world.tomatoes, t)
        end
        -- did we die in spikes or some other trap?
        if trap(t.x, t.y) then
            s = world.spikes_lut[flr(t.x/8) + flr(t.y/8)/256]
            s.fill = min(s.fill + g_fill_amount, 8)
            numbercats[t.color] -= 1
            del(world.tomatoes, t)
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

    if (old_x != e.x or old_y != e.y) and rnd() > 0.8 then
        add(particles, { x = e.x + (rnd(6) - 3) - rnd(2) * (e.x - old_x),
                         y = e.y + rnd(2) + 2 - rnd(2) * (e.y - old_y),
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
-- pause
--

function config.pause.update()
    if btn(4) then
        keep_score(score)
        state = "menu"
        world = make_world(0)
        sfx(g_sfx_menu)
        music(-0, 5000)
        music(7, 8000)
    end
    update_particles()
    update_player()
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

function draw_menu()

    palt(0, false)
    sspr(96, 8, 16, 16, menu.doorx, 0, menu.doordw, 128)
    palt(0,true)

    if state == "menu" then
        if menu.doordw > 126 then
            if not menu.scores then
                palt(0, false)
                palt(14, true)
                spr(37, 100, 64)
                palt()
                corectfill(menu.rect_y0, menu.rect_y1, 35, 6, 0)
                csprint("ld43     ", 32, 12, 11)
                csprint("     game", 32, 12, 15)
                csprint("play", 60, 9, 9)
                csprint("levels", 78, 9, 9)
            else
                csprint("levels", menu.high_y - 10, 9, 13)
                local select = {4, 4, 4, 4, 4, 4}
                select[menu.selectlevel] = 8
                smoothrectfill(23, 35, 43, 55, 5, 15, select[1])
                smoothrectfill(53, 35, 73, 55, 5, 15, select[2])
                smoothrectfill(83, 35, 103, 55, 5, 15, select[3])
                smoothrectfill(23, 65, 43, 85, 5, 15, select[4])
                smoothrectfill(53, 65, 73, 85, 5, 15, select[5])
                smoothrectfill(83, 65, 103, 85, 5, 15, select[6])
                for i = 1, 3 do
                    print(tostr(i), 3 + i * 29, 38, 5)
                    print(tostr(i+3), 2 + i * 30, 68, 5)
                    --cosprint("★ ", 64 - 23 + (i - 1)*20, 95, 6, 10) 
                end
            end

            camera(0, 14*8)
            draw_particles()
            draw_player()
            camera()
        end
    elseif state == "pause" then
        csprint("game     ", 32, 12, 9)
        csprint("     over", 32, 12, 11)
        csprint("score "..tostr(score), 80, 9, 13)
    end
end

function draw_world()
    -- fill spikes
    foreach(world.spikes, function(s)
        rectfill(s.x - 4, s.y + 4, s.x + 3, s.y + 4 - s.fill, 8)
    end)
    -- draw world
    palt(14, true)
    map(world.x, world.y, 8 * world.x, 8 * world.y, world.w, world.h)
    palt(14, false)
end

function draw_ui()
    csprint(tostr(flr(score).."     "), 2, 9, 13)
    if selectcolor > 1 then
        local palette = g_palette[color[selectcolor]]
        rectfill(6, 3, 16, 13, palette[2])
        rect(5, 2, 17, 14, 6)
        print(tostr(numbercats[selectcolor]), 12 - #tostr(numbercats[selectcolor])*2, 6, palette[1])
    end
end

function draw_entity(e)
    if e.dead then return end
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
        for i = 1, #color do
            local p = mid(world.x * 8 + #color*5, player.x, (world.x + world.w) * 8 - #color*5) - (#color-1)*5 + (i-1)*10
            local palette = g_palette[color[i]]
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
    foreach(world.tomatoes, draw_entity)
end

function draw_debug()
    print("selectlevel "..tostr(menu.selectlevel), 5, 5, 7)
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
  0,0,0,0,0," ",
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
  192,96,32,64,64,32,"~"
}

function load_font(data, height)
    local m = 0x5f25
    local font = {}
    local acc = {}
    local outline = 0
    local scale = 1
    for i=1,#data do
        if type(data[i])=='string' then
            font[data[i]] = acc
            acc = {}
        else
            add(acc, data[i])
        end
    end
    function font_outline(o)
        outline = o or 0
    end
    function font_scale(s)
        scale = s or 1
    end
    function print(str, x, y, col)
        local missing_args = not x or not y
        if missing_args then
            x,y = peek(m+1),peek(m+2)
        else
            poke(m+1,x) poke(m+2,y)
        end
        col = col or peek(m)
        local startx = x
        local pixels = {}
        for i=1,#str+1 do
            local ch=sub(str,i,i)
            local data=font[ch]
            if ch=="\n" or #ch==0 then
                y += height * scale
                x = startx
            elseif data then
                local dx = 0
                while ceil(dx) < #data do
                    for dy=0,height do
                        if band(data[1 + flr(dx)],2^dy)!=0 then
                            pixels[y + dy + (x + dx * scale) / 256] = true
                        end
                    end
                    dx += min(1, 1 / scale)
                end
                x += (#data + 1) * scale
            end
        end
        -- print pixels
        if outline > 0 then
            for p,m in pairs(pixels) do
                circfill(p%1*256, flr(p), outline, 0)
            end
        end
        for p,m in pairs(pixels) do
            pset(p%1*256, flr(p), col)
        end
        poke(m, col)
        if missing_args then
            poke(m+1,x) poke(m+2,y)
        end
    end
end

load_font(double_homicide,14)

__gfx__
00000000424204404444444444450000000054540000000000000000555d55d50000000000004454444500004545000000005444444444544444545445450000
000000002040042044554444544500000000d44400000000000000004454544400000000000054454454000044450000000054454454444445444444444d0000
0000000000200400444444544445000000005454000000000000000044444544000000000000444444440000445d00000000d544444454454445444454450000
000000000000020045444444445d0000000054440000000000000000454544450000000000004454544500005445000000005444454444544444454444550000
0000000000000000444454440000000000002444d55d00000000555d04402424d555d5d500004444445400004445d55d555d544542425444544544240000555d
0000000000000000444444440000000000000442445500000000d444024004024444445400005445444400005454444544444544004054454455040400005544
0000000000000000445444540000000000000420544d0000000054540040020044544444000044444544000044444544444544440020d544444502020000d454
0000000000000000444444440000000000000200454500000000d44500200000454454450000545444450000454544444544445400005444544d000000005444
0000cccc09454490000000000000000000002200000011000000440000003300f880000000000000000000000000000044dddddddddddd550000000000000000
0000c7760a0000a0000000000000000000028e200001c61000049a400003b630f8888000a000bb0000000000000000004d444445445455d50000000000000000
0000c776094445900000000000000000000288200001cc10000499400003bb30f8888800ba0b33b000000045400000004dd6666666666dd50000000000000000
0000c6660a0000a000000000000000000002e82000016c100004a94000036b300f888e800bb3373b0044004d440445004d666666666666d50000000000000000
cccc000009544490000000033000000000288820001ccc1000499940003bbb300f88817803333333054444454444d4404d666666666666d50000000000000000
c77600000a0000a00000003bb30000000288e82001cc6c100499a94003bb6b300f8888883101331004d5455d554454404d666666666666d50000000000000000
c776000009445490000003bbbb30000002e88200016cc10004a99400036bb30000f88887100011000444522112d544004d666666666666d50000000000000000
c66600000a0000a0000003bb7b730000002220000011100000444000003330000007777000000000004d2111111254004d666666666666d50000000000000000
0944459000000000000003bb1b13000000000000e00eeeee0000000000000000000c000000444400044511101011d4404d666666666666d50000000000000000
0a0000a000000000000003bbbbb3000007000700e440eeee0000000000000000000c00000497974044521101010125444d666666666666d50000000000000000
094544900000000000003bbbbbb3300007000700e0040eee000000000000000000cc100047aaaa74d5d11010101115454d666666666666d50000000000000000
0a0000a00000000000033bbb1113000007600760e00040ee00000000000000000c7cd100494a4a944451010101011d544d666666666666d50000000000000000
00000000094445900003bb3bbbb3000007600760e00040ee0000000000000000c7cccd1049aaaa7404521000001125444d666666666666d50000000000000000
000000000a0000a0003bb3bb3b30000067606760e0040eee0000000000000000c7cccd1049a4aa9404510100000115404d666666666666d50000000000000000
0000000009454490003bbbbbbb300000676d676de440eeee00000000000000000c7cd1000499974044d1100000101d4044dddddddddddd550000000000000000
000000000a0000a00003333333000000676d676de00eeeee000000000000000000dd100000444400d451010000011554d44444454454555d0000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333300000000000000000000000000000000
__gff__
00030f01020408030c0a050d0e0b0709061f00000000000f0000000000000000131c000020000f0f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
000000000000000000000000000000000a0000000000000000000000000007070707070707070d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000a000000000000000000000000000000000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000a000000000000000000000000000000000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000a000008082108080000000700000000000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000a0000010111010100000000000000000000000007070d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000a00000000110000000000000000110e070700000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000000000000000090e0700000711070d24240e070000110a000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000000000000000090a00000000110004070703000000110a000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000000707070000090a000707001100000000000000040703000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000000000000000000000000090a0000000011000000000000001a1b00000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a000000000000000000001a1b0000090a0000000011000000000000002a2b00000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a000000000000000000002a2b0000090a000004070707070707071107070707070700000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070707070d240e0707070707070707070a000000000000000000001100000000000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000407030000000000000000000a000707070000000000002000000000000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000a000000000000000000000007070000000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000b0808080808080000080808080808080808080808080c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000a0000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000a0000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000a0000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000a0000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000a0000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000a0000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000a0000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000a0000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000b080808080808080808080c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
