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

g_lives_player_start = 5
g_lives_player_max = 10
g_lives_tomato = 10
g_fish_ammo = 20
g_points_kill = 10
g_spawn_cooldown = 10

--
-- constructors
--

function new_game()
    score = 0
    fish = 0
    lives_x1 = 76
    hidefish = {}
    hidemeat = {}
    background = 0
    particles = {}
    smoke = {}
    fishes, meat = {}, {}
    add_smoke(150)
    player = new_player(16, 80)
    tomatoes = {
        new_tomato(48, -20),
        new_tomato(96, -10),
    }
    spawn_cooldown = g_spawn_cooldown,
    collectibles(fishes, 48)
    collectibles(meat, 49)
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
    e.lives = g_lives_player_start
    e.spd = 1.0
    e.spr = 18
    e.pcolors = { 3, 11 }
    return e
end

function new_tomato(x, y)
    local e = new_entity(x, y)
    e.lives = g_lives_tomato
    e.spd = 0.5
    e.spr = 30
    e.pcolors = { 2, 8 }
    e.plan = { time = 0 }
    return e
end

function add_smoke(n)
    while #smoke < n do
      add(smoke, {x = crnd(0, 128), y = crnd(133, 138), r = crnd(0, 20), col = ccrnd({5, 12})})
    end
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
    cartdata("joe_pickle")
    music(7, 8000)
    state = "menu"
    particles = {}
    player = new_player(64, 150)
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
        collect_fish()
        collect_meat()
        update_smoke()
        lives_handling()
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
        draw_background()
        draw_smoke()
        draw_world()
        draw_collectible(fishes, 25)
        draw_collectible(meat, 24)
        draw_particles()
        draw_tomatoes()
        draw_player()
        draw_ui()
        --draw_debug()
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
        sfx(16)
    elseif btnp(4) and menu.scores then
        menu.scores = false
        menu.high_y = 78
        sfx(16)
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
        sfx(16)
    elseif btnp(2) and menu.rectpos > 1 then
        menu.rectpos -= 1
        sfx(16)
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
    if player.dead then return end
    update_entity(player, btn(0), btn(1), jump(), btn(3))

    -- eating spam?
    player.spam = spam(player.x, player.y)
    if player.spam then
        if player.anim % 16 < 1 then
            score += 1
            sfx(17)
        end
    end

    -- shooting!
    if btn(4) and state == "play" then
        if player.cooldown > 0 then
            player.cooldown -= 1
        elseif #player.shots < 10 and fish > 0 then
            local x = player.x + rnd(8) - 4
            local y = player.y + rnd(4) - 3
            add(player.shots, { x0 = x, y0 = y, x1 = x, y1 = y,
                                exploded = false,
                                dx = (rnd(2) + 3) * (player.dir and -1 or 1),
                                color = rnd() > 0.7 and 9 or 10 })
            sfx(12)
            fish -= 1
            player.cooldown = 2
        end
    end

    -- death
    if player.lives == 0 then
        for i = 0,20 do
            add(particles, { x = player.x + rnd(8) - 4,
                             y = player.y + rnd(8) - 8,
                             age = 20 + rnd(5),
                             color = { 0, 5, 3, 11 },
                             r = { 3, 5, 7 } })
        end
        sfx(18)
        player.dead = true
        player.cooldown = 60
    end
end

function update_tomatoes()
    spawn_cooldown -= 1 / 60
    if spawn_cooldown < 0 then
        add(tomatoes, new_tomato(64, -20))
        spawn_cooldown = g_spawn_cooldown
    end

    foreach(tomatoes, function(t)
        local old_x, old_y = t.x, t.y
        update_entity(t, t.plan[0], t.plan[1], t.plan[2], t.plan[3])
        -- check collision with player
        if abs(t.x - player.x) <= 6 and abs(t.y - player.y) <= 8 then
            if player.hit == 0 then
                player.lives -= 1
                player.hit = 10
                sfx(19)
            end
        end
        -- update move plan if necessary
        t.plan.time -= 1
        if t.plan.time <= 0 or (old_x == t.x and old_y == t.y) then
            t.plan = { time = crnd(80, 100) }
            t.plan[flr(rnd(2))] = true -- go left or right
            t.plan[2] = rnd() > 0.8 -- jump
        end
        -- die in an explosion if necessary
        if t.lives <= 0 then
            del(tomatoes, t)
            for i = 0,10 do
                add(particles, { x = t.x + rnd(8) - 4,
                                 y = t.y + rnd(8) - 8,
                                 age = 20 + rnd(5),
                                 color = { 0, 5, 2, 8 },
                                 r = { 3, 5, 7 } })
            end
            score += g_points_kill
            sfx(18)
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
            ladder_middle()
        elseif grounded and not e.jumped then
            e.jump = 20
            e.jumped = true
            if state == "play" then
                sfx(10)
            end
        end
    elseif go_down then
        -- down button
        if ladder or ladder_below then
            move_y(e, e.climbspd)
            ladder_middle()
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
                sfx(11)
            end
        end
    end

    if ladder and old_y != e.y then
        if last_move == nil or time() > last_move + 0.25 then
            last_move = time()
            sfx(13)
        end
    end

    e.grounded = grounded
    e.ladder = ladder

    if old_x != e.x or old_y != e.y then
        add(particles, { x = e.x + (rnd(6) - 3) - rnd(2) * (e.x - old_x),
                         y = e.y + rnd(2) + 2 - rnd(2) * (e.y - old_y),
                         age = 20 + rnd(5), color = e.pcolors,
                         r = { 0.5, 1, 0.5 } })
    end

    foreach (e.shots, function(s)
        -- always advance tail
        s.x0 += s.dx * 0.75
        -- only advance head if not already exploded
        if not s.exploded then
            foreach(tomatoes, function(t)
                -- bounding box is a bit larger than ours
                if (abs(s.x1 - t.x) <= 6) and (abs(s.y1 - 2 - t.y) <= 6) then
                    t.lives -= 1
                    s.exploded = true
                    t.hit = 5
                end
            end)
            if wall(s.x1, s.y1) or wall(s.x1 + s.dx / 2, s.y1) then
                s.exploded = true
            end
            if s.exploded then
                add(particles, { x = s.x1 + (rnd(4) - 2),
                                 y = s.y1 + (rnd(4) - 2),
                                 age = 20 + rnd(5), color = { 10, 9, 8 },
                                 r = { 0.5, 1, 0.5 } })
                sfx(14)
            end
            s.x1 += s.dx
        end
        -- delete if lost in the void or finished exploding
        if s.x0 > 128 or s.x0 < 0 or (s.x1 - s.x0) * s.dx <= 0 then
            del(e.shots, s)
        end
    end)
end

-- collectibles

function collectibles(table, n)
    for j=0, 15 do
        for i=0, 15 do
            local tile = mget(i,j)
            if tile == n then
                add(table, { cx = i, cy = j })
            end
        end
    end
end

function collect_fish()
    foreach(fishes, function(f)
        if flr(player.x / 8) == f.cx and flr(player.y / 8) == f.cy then
            add(hidefish, {cx = f.cx, cy = f.cy, date = time()})
            fish += g_fish_ammo
            del(fishes, f)
            sfx(15)
        end
    end)
    foreach(hidefish, function(f)
        if f.date + 20 < time() then
            add(fishes, f)
            del(hidefish, f)
        end
    end)
end

function collect_meat()
    foreach(meat, function(m)
        if flr(player.x / 8) == m.cx and flr(player.y / 8) == m.cy then
            add(hidemeat, {cx = m.cx, cy = m.cy, date = time()})
            if player.lives < g_lives_player_max then
                player.lives += 1
            end
            del(meat, m)
            sfx(15)
        end
    end)
    foreach(hidemeat, function(f)
        if f.date + 20 < time() then
            add(meat, f)
            del(hidemeat, f)
        end
    end)
end

-- spam

function spam(x,y)
    local tile = mget(x / 8, y / 8)
    if tile == 20 or tile == 21 or tile == 36 or tile == 37 then -- this is spam
        return true
    end  
end

-- lives

function lives_handling()
    local l = 40 / g_lives_player_max
    lives_x1 = 80 + player.lives * l

    -- if dead, switch to pause state after 60 frames
    if player.dead then
        player.cooldown -= 1
        if player.cooldown <= 0 then
            state = "pause"
            player.lives = 5
            menu.doordw = 128
            menu.doorx = 0
            player = new_player(64, 150)
        end
    end
end

-- smoke

function update_smoke()
    foreach(smoke, function(circle)
        if circle.r < 20 then
            circle.r += 0.5
        elseif circle.r >= 20 then
            circle.x = crnd(0, 128)
            circle.y = crnd(133, 138)
            circle.r = crnd(0, 7)
            circle.col = ccrnd({5, 12})
        end 
    end)
end

-- walls and ladders

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

function ladder_middle()
    local ladder_x = flr(player.x / 8) * 8
    if player.x < ladder_x + 4 then
        move_x(player, 1)
    elseif player.x > ladder_x + 4 then
        move_x(player, -1)
    end
end

--
-- pause
--

function update_pause()
    if fish > 0 then
        if fish % 10 == 0 then
            score += 1
        end
        fish -= 1
        return
    end

    if btn(4) then
        keep_score(score)
        state = "menu"
        player = new_player(64, 150)
        sfx(16)
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
                csprint("joe       ", 32, 12, 11)
                csprint("    pickle", 32, 12, 9)
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
        cosprint(tostr(fish), 68, 60, 6, 9)
        spr(25, 54, 58)

        camera(0, 14*8)
        draw_particles()
        draw_player()
        camera()
    end
end

function draw_world()
    palt(14, true)
    map(0, 0, 0, 0, 16, 16)
    palt(14, false)
end

function draw_ui()
    csprint(tostr(flr(score).."     "), 2, 9, 13)
    cosprint(tostr(fish), 19, 4, 6, 9)
    spr(25, 7, 3)
    palt(0, false)
    orectfill(80, 4, 120, 8, 1, 0)
    orectfill(80, 4, lives_x1, 8, 8, 0)
    palt(0, true)
    spr(24, 68, 2)
    if player.spam then
        local px = player.x - sin(player.anim / 20)
        cosprint("miom", px - 20, player.y - 22 + 4 * cos(player.anim / 20), 6, crnd(6, 10))
        cosprint("miom", px -  5, player.y - 22 + 3 * cos(player.anim / 16), 6, crnd(6, 10))
        cosprint("miom", px + 10, player.y - 22 + 4 * cos(player.anim / 24), 6, crnd(6, 10))
    end
end

function draw_entity(e)
    if e.dead then return end
    if e.hit > 0 then for i = 1,15 do pal(i, 6 + rnd(2)) end end
    --spr(e.spr, e.x - 8, e.y - 12, 2, 2, e.dir)
    local dy = 2 * cos(e.anim / 32)
    sspr(e.spr % 16 * 8, flr(e.spr / 16) * 8, 16, 16, e.x - 8, e.y - 12 + dy, 16, 16 - dy, e.dir)
    pal()
end

function draw_player()
    foreach (player.shots, function(s)
        line(s.x0, s.y0, s.x1, s.y1, s.color)
    end)
    draw_entity(player)
end

function draw_particles()
    foreach (particles, function(p)
        local t = p.age / 20
        circfill(p.x, p.y, p.r[1 + flr(t * #p.r)], p.color[1 + flr(t * #p.color)])
    end)
end

function draw_tomatoes()
    foreach(tomatoes, draw_entity)
end

function draw_collectible(table, n)
    foreach(table, function(c)
        spr(n, c.cx * 8, c.cy * 8)
    end)
end

function draw_background()
    local x1 = 64 * sin(background)
    local y1 = 96 * cos(background)
    local x2 = 96 * sin(background * 2)
    local y2 = 64 * cos(background * 2)
    fillp(0xfafa.8)
    for i = 0,14 do
        circfill(64 + x1, 64 + y1, 160 - 12 * i, i % 2)
    end
    fillp(0x5f5f.8)
    for i = 0,14 do
        circfill(64 - x2, 64 - y2, 160 - 12 * i, i % 2)
    end
    fillp()
    background += 1/256
end

function draw_smoke()
    foreach(smoke, function(circle)
        if circle.col == 5 then
            local p={0x0, 0x0, 0x5050, 0x5050, 0x5a5a, 0xfafa}
            fillp(p[flr(circle.r * (#p - 1) / 20) + 1] + 0x.8)
            circfill(circle.x, circle.y - 4, circle.r, circle.col)
            fillp()
        end 
    end)

    foreach(smoke, function(circle)
        if circle.col == 12 then
            local p={0x0, 0x0, 0x5050, 0x5050, 0x5a5a, 0xfafa}
            fillp(p[flr(circle.r * (#p - 1) / 20) + 1] + 0x.8)
            circfill(circle.x, circle.y + 2, circle.r, circle.col)
            fillp()
        end 
    end)
end

function draw_debug()
    print("player.xy "..player.x.." "..player.y, 5, 118, 6)
    print("jump "..player.jump.."  fall "..player.fall, 5, 111, 6)
    print("grounded "..(player.grounded and 1 or 0).."  ladder "..(player.ladder and 1 or 0), 5, 104, 6)
     -- debug collisions
    fillp(0xa5a5.8)
    rect(player.x - 4, player.y - 4, player.x + 3, player.y + 3, 8)
    fillp()
end

__gfx__
000000000000330077777777777c00000000c7770000000000000000cccccccc000000000000c777777c0000777c00000000c7777777777777777777777c0000
000000000003b63077777777777c00000000c777000000000000000077777777000000000000c777777c0000777c00000000c7777777777777777777777c0000
000000000003bb3077777777777c00000000c777000000000000000077777777000000000000c777777c0000777c00000000c7777777777777777777777c0000
0000000000036b3077777777777c00000000c777000000000000000077777777000000000000c777777c0000777c00000000c7777777777777777777777c0000
00000000003bbb30777777770000000000000000cccc00000000cccc00000000cccccccc0000c777777c0000777cccccccccc7770000c777777c00000000cccc
0000000003bb6b30777777770000000000000000777c00000000c77700000000777777770000c777777c000077777777777777770000c777777c00000000c777
00000000036bb300777777770000000000000000777c00000000c77700000000777777770000c777777c000077777777777777770000c777777c00000000c777
0000000000333000777777770000000000000000777c00000000c77700000000777777770000c777777c000077777777777777770000c777777c00000000c777
0000cccc04ffff40000000003300000000dddddddddddd000000000000000000f880000000000000000000000000000055666666666666000000000000000000
0000c7760400004000000003bb300000dd666666666666dd0000000000000000f8888000a000bb00000000000000000056555550550500600000000000000000
0000c77604ffff400000003bbbb300001dddddddddddddd10000000000000000f8888800ba0b33b0000000000000000056677777777776600000000000000000
0000c666040000400000033bb7b73000111111111111111100087878787880000f888e800bb3373b00000000000000005677777777777760000003b300000000
cccc000004ffff400000003bb1b1300011a11aa11a11a1a100878787878788000f8881780333333300000003300000005677777777777760000b3bb222200000
c7760000040000400000003bbbbb30001a1a1a1a1a11aaa10077cccccccc77000f888888310133100000003bb30000005677777777777760000bbb3b88822000
c776000004ffff40000003bbbbbb330011a11aa1a1a1a1a107cccccccccccc6000f8888710001100000003bbbb300000567777777777776000b3bb8888888700
c666000004000040000033bbbb113000111a1a11aaa1a1a107cccccccccc6d600007777000000000000003bb7b730000560077777777776000388b3888788120
04ffff4000000000000003bbbbbb30001a1a1a1a11a1a1a107cccccccccc6c60000c000000444400000003bb1b13000056667777777777600028883888188882
040000400000000000003bb3bbbb300011a11a1a11a1a1a107cccccccccc6d60000c000004979740000003bbbbb3000056777777777777600288888888888882
04ffff40000000000003bb3bb3b30000111111111111111107cccccccccc6c6000cc100047aaaa7400003bbbbbb33000567777777777776002e8888888888882
0400004000000000003bbbbbbbb33000111199a9a999111107cccccccccc6d600c7cd100494a4a9400033bbb11130000567777777777776002e8888888887882
0000000004ffff40003bbb3bbb300000199a9a9a9a9a999107cccccccccc6c60c7cccd1049aaaa740003bb3bbbb30000567777777777776002ee88888888e820
0000000004000040003bb3bbbb30000011a9a8888889a91107c6666666666d60c7cccd1049a4aa94003bb3bb3b3000005677777777777760002eee8888882200
0000000004ffff400003bbbbb3300000199444eefef44991007cdcdcdcdcd6000c7cd10004999740003bbbbbbb300000556666666666660000022eeee8220000
00000000040000400000333330000000119a9444e9899911000766666666600000dd100000444400000333333300000065555550550500060000022222000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000e000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
eeee0000ee0ee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0000000e0e0e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
eee00000e000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0000000e000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333300000000000000000000000000000000
__gff__
000f0f01020408030c0a050d0e0b0709061f000000000c0c0000000000000000131c000000000f0f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0a00000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000808210808000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000110000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a30000000110000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e07070707110707070707000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000110000000000000000310900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000110000000000000004070d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000110014150000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000110024250000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000407070707070707110707070d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000000000110000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000000000200000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b08080808080000000008080808080c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
__sfx__
011000001f2002420000000000002420023200212001f2001d200000001f200242001d2001f200242001f200242002320021200242001d2001d2001d2001d2001d20023200232001d2001d2001d2001d20021200
011000000e42009420024200e42009420004200c42007420004200c42007420004200c42007420004200c420074220742207422134220e420074201342005420114200c42005420114200c420024200e42007420
01100000024200e42009420024200e4200942004420104200b4200942015420104200942015420104200c420074220742207422134220e420074201342005420114200c42005420114200c420024200e42007420
01100000024200e42009420024200e4200942004420104200b4200942015420104200942015420104200b42017420114200b42017420114221142211422114220c4201842013420094200c420024200e42007420
011000000000000000000000000000000000000000000000000000000000000000001f5201f520000001d5201f5201c5201f5201c52023520215201c5201d5201f5201f520000001f5201f5201c5201f52023520
01100000000001f5201c520005001d5201a5200050023520215222152221522215222152221522215222152200000000000000000000000000000000000000001d5001d5001c5001d5001d500215001f5001c500
011000000000000000000000000000000000000000000000000000000000000000001352018520000001152013520185201352018520175201552018520115201352013520000001352013520175201352017520
0110000000000135201752011520175200000017520155201c5301a53018530185301a530185301753015530155301353011530135301a5301d52013520105201352010520175201552010520115201352013520
011000001f5001f5201f500115001f520215202152021520235222352223522235222352226520245202452024520245202352021520235200000000000285201d52000000215201d52000000215202152021520
01100000115001352000000000001352015520155201552017522175221752217522175221a5201852018520185201852017520155201752000000000001c5201152000000155201152000000155201552015520
000400001c7501f750217532120023200252002620027200292002a2002c2002e2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000090400b0400d0400130001300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000f33317333213332a333343333d333133030f403093030730300003000030000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100001e52022520255202750000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000e43013430174301442011420000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000014220192301d23023230272302c2400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000191501b1501c1500310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001222015320172201b32024600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000357742f7732b7732777323773207731d7731b773197731777316775147731377313773137600000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200001535413356113560e3560c3560b3560a35608356073560635604356033560135601356013560135601355021000110001100011000110001100011000000000000000000000000000000000000000000
__music__
00 01444644
00 02444644
00 03444644
00 01040644
00 02050744
00 03080944
02 02050744
01 01424344
00 02424344
02 03424344

