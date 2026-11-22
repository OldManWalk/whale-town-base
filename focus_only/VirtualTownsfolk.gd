extends Node2D

const ATLAS := preload("res://art/avatars/open_visitors.png")
const RESIDENTS := [3,8,13,18,27,33,39,46,51,56,64,72,78,83,94,98,103,108,112,121]
const ROAM := [
    Vector2(41,166),Vector2(77,183),Vector2(127,177),Vector2(163,128),
    Vector2(207,143),Vector2(212,198),Vector2(247,214),Vector2(275,161),
    Vector2(311,129),Vector2(341,185),Vector2(394,178),Vector2(437,162),
]
const WALK_SPEED := 36.0

var commons := Vector2(222,177)
var paths: Dictionary = {}
var people: Array[Dictionary] = []
var wanted_site := ""
var focusing := false
var elapsed := 0.0

func setup(center: Array, route_points: Dictionary) -> void:
    commons = Vector2(center[0],center[1])
    for site in route_points:
        var points: Array[Vector2] = []
        for xy in route_points[site]:
            points.append(Vector2(xy[0],xy[1]))
        paths[site] = points
    for index in RESIDENTS.size():
        var spot := rest_spot(index,index)
        people.append({"foot":spot,"target":"","route":[],"waiting":1.0+index%5,"walks":index,"facing":1.0})

func rest_spot(index: int, walks: int) -> Vector2:
    return ROAM[(walks*5+index)%ROAM.size()]+Vector2((index%5-2)*5,(index%3-1)*4)

func aim_for(site: String, working: bool = true) -> void:
    wanted_site = site if paths.has(site) else ""
    focusing = working

func job(index: int) -> String:
    return "logging" if index<6 else ("farming" if index<12 else "building")

func work_target(index: int) -> String:
    if not focusing:
        return ""
    var role := job(index)
    return wanted_site if role=="building" else role

func route_for(resident: Dictionary, target: String, index: int) -> Array[Vector2]:
    var result: Array[Vector2] = [Vector2(resident.foot.x,commons.y+(index%3-1)*4)]
    if target.is_empty():
        var rest := rest_spot(index,resident.walks)
        result.append(Vector2(rest.x,result[0].y))
        result.append(rest)
        return result
    var path: Array[Vector2] = paths[target]
    result.append(commons+Vector2(0,(index%3-1)*4))
    result.append_array(path)
    var group_index := index if index<6 else (index-6 if index<12 else index-12)
    var spread := Vector2((group_index%4-1.5)*13,(group_index/4)*11+(group_index%2)*4)
    result.append(path[-1]+spread)
    return result

func advance(delta: float) -> void:
    elapsed += delta
    for index in people.size():
        var actor: Dictionary = people[index]
        var target := work_target(index)
        if target != actor.target:
            actor.target = target
            actor.route = route_for(actor,target,index)
        elif target.is_empty() and actor.route.is_empty():
            actor.waiting -= delta
            if actor.waiting<=0:
                actor.walks += 1
                actor.waiting = 1.5+(index+actor.walks)%5
                actor.route = route_for(actor,"",index)
        var remaining := delta*(WALK_SPEED+(index%5)*2.2)
        while not actor.route.is_empty() and remaining>0.0:
            var next: Vector2 = actor.route[0]
            var leg: Vector2 = next-actor.foot
            if absf(leg.x)>.1:
                actor.facing = signf(leg.x)
            var distance := leg.length()
            actor.foot = actor.foot.move_toward(next,remaining)
            remaining -= distance
            if actor.foot.is_equal_approx(next):
                actor.route.pop_front()
    queue_redraw()

func pose(index: int) -> Dictionary:
    var actor: Dictionary = people[index]
    var target := work_target(index)
    var action := "rest"
    if target!=actor.target or not actor.route.is_empty():
        action = "carry" if not target.is_empty() and job(index)=="building" else "walk"
    elif not target.is_empty():
        action = job(index)
    return {"foot":actor.foot.round(),"action":action,"role":job(index)}

func _draw() -> void:
    draw_worksites()
    var draw_order: Array[int] = []
    draw_order.assign(range(people.size()))
    draw_order.sort_custom(func(a,b):return people[a].foot.y < people[b].foot.y)
    for index in draw_order:
        var resident := pose(index)
        var foot: Vector2 = resident.foot
        var tile: int = RESIDENTS[index]
        var cell := Rect2(tile%16*24,floori(tile/16.0)*26,24,26)
        var walking: bool = resident.action in ["walk","carry"]
        var bob := 1.0 if walking and sin(elapsed*18.0+index) > 0.0 else 0.0
        draw_shadow(foot)
        draw_set_transform(foot,0,Vector2(people[index].facing,1))
        draw_texture_rect_region(ATLAS,Rect2(-10,-21-bob,20,22),cell)
        draw_set_transform(Vector2.ZERO)
        if resident.action == "carry":
            draw_rect(Rect2(foot+Vector2(1,-10-bob),Vector2(8,3)),Color("#aa7850"))
        elif resident.action in ["logging","farming","building"]:
            draw_tool(foot,index,resident.action)

func draw_worksites() -> void:
    for index in 6:
        var row := Vector2(365+(index%3)*17,133+(index/3)*13)
        draw_rect(Rect2(row,Vector2(15,10)),Color("#846043"))
        for seed in 4:
            var leaf := row+Vector2(2+seed*3,4+(seed%2)*3)
            draw_rect(Rect2(leaf-Vector2(0,2),Vector2(2,3)),Color("#85ad55"))
    for index in 5:
        var log_foot := Vector2(66+index*8,132+(index%2)*4)
        draw_rect(Rect2(log_foot,Vector2(8,3)),Color("#865b3b"))
        draw_rect(Rect2(log_foot,Vector2(3,3)),Color("#ce9c65"))

func draw_tool(foot: Vector2, index: int, role: String) -> void:
    var raised := fposmod(elapsed+index*.27,1.6)<.35
    var hand := foot+Vector2(4,-9)
    var head := hand+Vector2(2,-6) if raised else hand+Vector2(6,1)
    draw_line(hand,head,Color("#74503b"),1.25)
    if role=="farming":
        draw_line(head,head+Vector2(3,-2),Color("#d3c6a4"),1)
    else:
        var blade := Vector2(3,4) if role=="logging" else Vector2(5,2)
        draw_rect(Rect2(head-Vector2(1,1),blade),Color("#d5ccb3"))

func draw_shadow(foot: Vector2) -> void:
    draw_set_transform(foot,0,Vector2(1.4,.4))
    draw_circle(Vector2.ZERO,5,Color("#30453766"))
    draw_set_transform(Vector2.ZERO)
