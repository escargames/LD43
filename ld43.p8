pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

--
-- config
--

config = {
    menu = {tl = "menu"},
    play = {tl = "play"},
    pause = {tl = "pause"},
}

g_sfx_menu = 16
g_sfx_jump = 10
g_sfx_ladder = 13
g_sfx_footstep = 11

g_spr_player = 18
g_spr_follower = 20
g_spr_exit = 26
g_spr_spikes = 36

g_palette = {{ 2, 8 }, { 1, 12 }, { 4, 9 }, { 3, 11 }}

--
-- constructors
--

function new_game()
    score = 0
    saved = 0
    particles = {}
    selectcolor = 1
    selectcolorscreen = false

    color = {1, 2, 3, 4}
    world = {
        w = 23, h = 16,
        player = new_player(16, 80),
        exit = {},
        spikes = {},
        tomatoes = {}
    }
    -- spawn tomatoes (needs to be improved)
    for i=1,32 do
        add(world.tomatoes, new_tomato(crnd(32, 96), crnd(-20,-50)))
    end
    -- analyse level to find where the exit is
    world.exit = {x=0, y=0}
    for y=0,world.h-1 do
        for x=0,world.w-1 do
            if mget(x,y) == g_spr_exit then
                world.exit = {x = 8 * x + 8, y = 8 * y + 12}
            elseif mget(x,y) == g_spr_spikes then
                add(world.spikes, {x = 8 * x + 4, y = 8 * y + 4})
            end
        end
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
        shots = {},
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
    return e
end

function new_tomato(x, y)
    local e = new_entity(x, y)
    e.spd = 0.5
    e.ssize = 1
    e.plan = { call = false }
    e.color = flr(rnd(4))
    e.spr = g_spr_follower + e.color
    e.pcolors = g_palette[e.color + 1]
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

function crnd(min, max)
  return min + rnd(max-min)
end

function ccrnd(tab)  -- takes a tab and choose randomly between the elements of the table
  n = flr(crnd(1, #tab+1))
  return tab[n]
end

-- cool print (outlined, scaled)

function cosprint(text, x, y, height, color)
    -- save first line of image
    local save={}
    for i=1,96 do save[i]=peek4(0x6000+(i-1)*4) end
    memset(0x6000,0,384)
    print(text, 0, 0, 7)
    -- restore image and save first line of sprites
    for i=1,96 do local p=save[i] save[i]=peek4((i-1)*4) poke4((i-1)*4,peek4(0x6000+(i-1)*4)) poke4(0x6000+(i-1)*4, p) end
    -- cool blit
    pal() pal(7,0)
    for i=-1,1 do for j=-1,1 do sspr(0, 0, 128, 6, x+i, y+j, 128 * height / 6, height) end end
    pal(7,color)
    sspr(0, 0, 128, 6, x, y, 128 * height / 6, height)
    -- restore first line of sprites
    for i=1,96 do poke4(0x0000+(i-1)*4, save[i]) end
    pal()
end

-- cool print (centered, outlined, scaled)

function csprint(text, y, height, color)
    local x = 64 - (2 * #text - 0.5) * height / 6
    cosprint(text, x, y, height, color)
end

-- cool print (outlined)

function coprint(text, x, y)
    for i = -1,1 do
        for j = -1,1 do
            print(text, x+i, y+j, 0)
        end
    end
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

--
-- standard pico-8 workflow
--

function _init()
    cartdata("ld43_escargames")
    music(7, 8000)
    state = "menu"
    particles = {}
    world = {
        player = new_player(64, 150),
        tomatoes = {}
    }
    menu = {
        doordw = 128,
        doorx = 0,
        doorspd = 1,
        opening = false,
        rectpos = 1,
        rect_y0 = 55,
        rect_y1 = 72,
        scores = false,
        high_y = 78
    }
    jump_speed = 1
    fall_speed = 1
end

function _update60()
    if state == "menu" then
        update_menu()
        update_particles()
        update_player()
    elseif state == "play" then
        update_particles()
        update_player()
        update_tomatoes()
    elseif state == "pause" then
        update_pause()
        update_particles()
        update_player()
    end
end

function _draw()
    if state == "menu" then
        cls(0)
        draw_world()
        draw_menu()
    elseif state == "play" then
        cls(0)
        -- player-centered camera if map is larger than screen, otherwise fixed camera
        camera(world.w > 16 and mid(0, world.player.x - 64, world.w * 8 - 128) or 4 * world.w - 64,
               world.h > 16 and mid(0, world.player.y - 64, world.h * 8 - 128) or 4 * world.h - 64)
        draw_world()
        draw_particles()
        draw_tomatoes()
        draw_player()
        camera()
        draw_ui()
        draw_debug()
    elseif state == "pause" then
        cls(0)
        draw_menu()
    end
end 

--
-- menu
--

function update_menu()
    open_door()
    choose_menu()
    rect_menu()
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
    elseif btnp(4) and menu.scores then
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
    end

    -- calling and stop calling
    foreach(world.tomatoes, function(t)
        if btnp(4) and state == "play" and t.plan.call == false then
            t.plan.call = true
        elseif btnp(4) and state == "play" and t.plan.call == true then
            t.plan.call = false
        end
    end)
end

function update_tomatoes()
    foreach(world.tomatoes, function(t)
        local old_x, old_y = t.x, t.y
        update_entity(t, t.plan[0], t.plan[1], t.plan[2], t.plan[3])
        -- update move plan if necessary
        if t.plan.call == true then -- go left or right 
            if t.x < world.player.x + 1 then 
                t.plan[0] = false
                t.plan[1] = true 
            elseif t.x > world.player.x - 1 then
                t.plan[1] = false
                t.plan[0] = true
            end
        else 
            for i = 0, 3 do
                t.plan[i] = false
            end
        end
        -- did we reach the exit?
        if abs(t.x - world.exit.x) < 2 and
           abs(t.y - world.exit.y) < 2 then
            saved += 1
            del(world.tomatoes, t)
        end
        -- did we die in spikes or some other trap?
        if trap(t.x, t.y) then
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

function update_pause()
    if btn(4) then
        keep_score(score)
        state = "menu"
        world = {
            player = new_player(64, 150)
        }
        sfx(g_sfx_menu)
        music(-0, 5000)
        music(7, 8000)
    end
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
                corectfill(menu.rect_y0, menu.rect_y1, 35, 6, 0)
                csprint("ld43     ", 32, 12, 11)
                csprint("     game", 32, 12, 9)
                csprint("play", 60, 9, 13)
                csprint("high", 78, 9, 13)
            else
                csprint("high", menu.high_y, 9, 13)
                csprint("1 ...... "..dget(1), 45, 6, 13)
                csprint("2 ...... "..dget(2), 55, 6, 13)
                csprint("3 ...... "..dget(3), 65, 6, 13)
                csprint("4 ...... "..dget(4), 75, 6, 13)
                csprint("5 ...... "..dget(5), 85, 6, 13)
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

        camera(0, 14*8)
        draw_particles()
        draw_player()
        camera()
    end
end

function draw_world()
    palt(14, true)
    map(0, 0, 0, 0, world.w, world.h)
    palt(14, false)
end

function draw_ui()
    csprint(tostr(flr(score).."     "), 2, 9, 13)
    if selectcolorscreen then
        local player = world.player
        for i = 1, #color do
            local p = mid(20, player.x, 108) - (#color-1)*5 + (i-1)*10
            local palette = g_palette[color[i]]
            rectfill((p - 2), player.y - 16, (p + 2), player.y - 12, palette[2])
        end
            rect((mid(20, player.x, 108) - (#color-1)*5 + (selectcolor-1)*10 - 3), player.y - 17, (mid(20, player.x, 108) - (#color-1)*5 + (selectcolor-1)*10 + 3), player.y - 11, 6)
        
            --for i = 1,3 do
            --local colr = 5
                --if i <= dget(selectlevel) then
                    --colr = 10
                --end
            --cosprint("★ ", 64 - 23 + (i - 1)*20, 60, 6, colr) 
            --end
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
    foreach (world.player.shots, function(s)
        line(s.x0, s.y0, s.x1, s.y1, s.color)
    end)
    draw_entity(world.player)
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
    print("selectcolor "..selectcolor, 5, 5, 7)
end

__gfx__
00000000424204404444444444450000000054540000000000000000555d55d50000000000004454444500004545000000005444444444544444545445450000
000000002040042044554444544500000000d44400000000000000004454544400000000000054454454000044450000000054454454444445444444444d0000
0000000000200400444444544445000000005454000000000000000044444544000000000000444444440000445d00000000d544444454454445444454450000
000000000000020045444444445d0000000054440000000000000000454544450000000000004454544500005445000000005444454444544444454444550000
0000000000000000444454440000000000002444d55d00000000555d04402424d555d5d500004444445400004445d55d555d544542425444544544240000555d
0000000000000000444444440000000000000442445500000000d444024004024444445400005445444400005454444544444544004054454455040400005544
0000000000000000445444540000000000000420544d0000000054540040020044544444000044444544000044444544444544440020d544444502020000d454
0000000000000000444444440000000000000200454500000000d44500200000454454450000545444450000454544444544445400005444544d000000005444
0000cccc09454490000000000000000000002200000011000000440000003300f880000000000000000000000000000055666666666666000000000000000000
0000c7760a0000a0000000000000000000028e200001c61000049a400003b630f8888000a000bb00000000000000000056555550550500600000000000000000
0000c776094445900000000000000000000288200001cc10000499400003bb30f8888800ba0b33b0000000454000000056677777777776600000000000000000
0000c6660a0000a000000000000000000002e82000016c100004a94000036b300f888e800bb3373b0044004d4404450056777777777777600000000000000000
cccc000009544490000000033000000000288820001ccc1000499940003bbb300f88817803333333054444454444d44056777777777777600000000000000000
c77600000a0000a00000003bb30000000288e82001cc6c100499a94003bb6b300f8888883101331004d5455d5544544056777777777777600000000000000000
c776000009445490000003bbbb30000002e88200016cc10004a99400036bb30000f88887100011000444522112d5440056777777777777600000000000000000
c66600000a0000a0000003bb7b730000002220000011100000444000003330000007777000000000004d21111112540056007777777777600000000000000000
0944459000000000000003bb1b13000000000000000000000000000000000000000c000000444400044511101011d44056667777777777600000000000000000
0a0000a000000000000003bbbbb3000007000700000000000000000000000000000c000004979740445211010101254456777777777777600000000000000000
094544900000000000003bbbbbb330000700070000000000000000000000000000cc100047aaaa74d5d110101011154556777777777777600000000000000000
0a0000a00000000000033bbb11130000076007600000000000000000000000000c7cd100494a4a944451010101011d5456777777777777600000000000000000
00000000094445900003bb3bbbb3000007600760000000000000000000000000c7cccd1049aaaa74045210000011254456777777777777600000000000000000
000000000a0000a0003bb3bb3b30000067606760000000000000000000000000c7cccd1049a4aa94045101000001154056777777777777600000000000000000
0000000009454490003bbbbbbb300000676d676d0000000000000000000000000c7cd1000499974044d1100000101d4055666666666666000000000000000000
000000000a0000a00003333333000000676d676d00000000000000000000000000dd100000444400d45101000001155465555550550500060000000000000000
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
0a0000000000000000000000000007070707070707070d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000808210808000000070000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000010111010100000000000000000000000007070d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000110000000000000000110e07070000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0700000711070d00000e070000110a00000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000011000924240a000000110a00000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00070700110004070703000004070300000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000011000000000000001a1b0000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000000011000000000000002a2b0000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000407070707070707110707070707070000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000000000110000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00070707000000000000200000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000000000000707000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0808080808080000080808080808080808080808080c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
