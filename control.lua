local initialize_resources=function()
    global.resource_recs={}
    local miner_map={}

    local resources=game.get_filtered_entity_prototypes({{filter = "type", type = "resource"}})
    for name,entity in pairs(resources) do
        local products=entity.mineable_properties.products
        if products and #products>=1 then
            local resource_rec={}
            resource_rec.caption=entity.localised_name
            resource_rec.category=entity.resource_category
            resource_rec.products_and_ingredients={}
            for _,product in ipairs(products) do
                table.insert(resource_rec.products_and_ingredients,{type=product.type,name=product.name})
            end
            if entity.mineable_properties.required_fluid then
                table.insert(resource_rec.products_and_ingredients,{type="fluid",name=entity.mineable_properties.required_fluid})
            end
            global.resource_recs[name]=resource_rec
        end
    end

    local miners=game.get_filtered_entity_prototypes({{filter = "type", type = "mining-drill"}})
    for name,entity in pairs(miners) do
        local items=entity.items_to_place_this
        if items and items[1] then
            for cat,_ in pairs(entity.resource_categories) do
                miner_map[cat]=miner_map[cat] or {}
                table.insert(miner_map[cat],{entity=entity,item=items[1].name,speed=entity.mining_speed})
            end
        end
    end

    global.resource_order={}
    for name,resource_rec in pairs(global.resource_recs) do
        table.insert(global.resource_order,name)
    end
    table.sort(global.resource_order, function(a,b) return a < b end)

    --Code for showing fuel items beside each resource
    --Removed because it looks too cluttered.
    --local fuel_map={}
    --local items=game.get_filtered_item_prototypes({{filter = "fuel"}})
    --for name,item in pairs(items) do
    --    if item.fuel_category and item.fuel_category~="chemical" then
    --        fuel_map[item.fuel_category]=fuel_map[item.fuel_category] or {}
    --        fuel_map[item.fuel_category][name]=item
    --    end
    --end
    --
    --local miner_fuel_map={}
    --for category,miners in pairs(miner_map) do
    --    table.sort(miners, function(a,b) return a.speed < b.speed end)
    --    local fuel_categories={}
    --    for _,miner in pairs(miners) do
    --        if miner.entity.burner_prototype then
    --            for fuel_category,_ in pairs(miner.entity.burner_prototype.fuel_categories or {}) do
    --                fuel_categories[fuel_category]=true
    --            end
    --        end
    --    end
    --    local fuel_items={}
    --    for fuel_category,_ in pairs(fuel_categories) do
    --        for name,item in pairs(fuel_map[fuel_category] or {}) do
    --            fuel_items[name]=item
    --        end
    --    end
    --    miner_fuel_map[category]=fuel_items
    --end

    for _,resource_rec in pairs(global.resource_recs) do
        resource_rec.miners=miner_map[resource_rec.category] or {}
        --for name,item in pairs(miner_fuel_map[resource_rec.category] or {}) do
        --    table.insert(resource_rec.products_and_ingredients,{type="item",name=name})
        --end
    end
end

local function init()
    initialize_resources()

    global.player_recs={}

    global.chunk_recs={}
    global.chunks_to_scan={}

    global.scanned_chunks=0
    global.scanned_resources=0

    for _,surface in pairs(game.surfaces) do
        for chunk in surface.get_chunks() do
            table.insert(global.chunks_to_scan,{surface=surface,position={x=chunk.x,y=chunk.y}})
        end
    end
    global.chunks_to_scan_max = #global.chunks_to_scan
end

script.on_init(function()
    init()
end)

local get_player_rec=function(player_index)
    if global.player_recs[player_index]==nil then
        global.player_recs[player_index]={}
        local player_rec=global.player_recs[player_index]
        player_rec.frame_location=nil
        player_rec.choices={}
        for name,resource_rec in pairs(global.resource_recs) do
            player_rec.choices[name]=false
        end
        player_rec.chart_tags={}
    end
    return global.player_recs[player_index]
end
local get_player_resource_order=function(player_rec)
    if player_rec.translations then
        if not player_rec.resource_order then
            player_rec.resource_order={}
            for name,resource_rec in pairs(global.resource_recs) do
                table.insert(player_rec.resource_order,name)
            end
            table.sort(player_rec.resource_order, function(a,b) return (player_rec.translations[a] or a) < (player_rec.translations[b] or b) end)
        end
        return player_rec.resource_order
    else
        return global.resource_order
    end
end

local function init_player(player)
    local player_rec=get_player_rec(player.index)

    if not player_rec.translations then
        player_rec.translations={}
        for name,resource_rec in pairs(global.resource_recs) do
            player.request_translation({"resourcehighlighter-request-translation",name,resource_rec.caption})
        end
    end
end
script.on_event(defines.events.on_player_joined_game, function(event)
    init_player(game.players[event.player_index])
end)

script.on_event(defines.events.on_string_translated, function(event)
    local player=game.players[event.player_index]
    local player_rec=get_player_rec(event.player_index)

    if player_rec.translations and event.translated and event.localised_string[1]=="resourcehighlighter-request-translation" and
        event.localised_string[2] then
        player_rec.translations[event.localised_string[2]]=event.result
        player_rec.resource_order=nil --Remake resource_order since the order has changed
    end
end)

local scan_chunk=function(surface,position)
    if (not surface) or (not surface.valid) then
        return
    end

    global.scanned_chunks=global.scanned_chunks+1

    local chunk_rec={}
    local resources=surface.find_entities_filtered{
        area={left_top={x=position.x*32,y=position.y*32}, right_bottom={x=(position.x+1)*32,y=(position.y+1)*32}}, type="resource"}
    for _,resource in pairs(resources) do

        global.scanned_resources=global.scanned_resources+1

        -- Chunk generation centers all resources between tile boundaries (e.g., 0.5, 1.5, etc.)
        -- even for resources with even widths (e.g., 2, 4, etc.)
        -- find_entities_filtered() tests the intersection of the closed area provided with the closed collision_box
        -- A script can place a resource anywhere, including on the boundary between two chunks, so we arbitrarily make
        -- a chunk closed on two sides and open on two sides.

        if resource.position.x>=position.x   *32 and resource.position.y>=position.y   *32 and
           resource.position.x<(position.x+1)*32 and resource.position.y<(position.y+1)*32 then
            chunk_rec[resource.name]=chunk_rec[resource.name] or {currentCount=0,originalCount=0,originalAmount=0,centroid={x=0,y=0}}
            local chunk_res=chunk_rec[resource.name]
            chunk_res.currentCount=chunk_res.currentCount+1
            chunk_res.originalCount=chunk_res.currentCount
            chunk_res.originalAmount=chunk_res.originalAmount+resource.amount
            chunk_res.centroid.x=chunk_res.centroid.x+resource.position.x
            chunk_res.centroid.y=chunk_res.centroid.y+resource.position.y
            chunk_res.marked=false
        end
    end

    global.chunk_recs[surface.index]=global.chunk_recs[surface.index] or {}
    global.chunk_recs[surface.index][position.x]=global.chunk_recs[surface.index][position.x] or {}
    global.chunk_recs[surface.index][position.x][position.y]=chunk_rec

end

local delete_chunk=function(surface,position)
    if global.chunk_recs[surface.index] and
       global.chunk_recs[surface.index][position.x] and
       global.chunk_recs[surface.index][position.x][position.y] then
           global.chunk_recs[surface.index][position.x][position.y]=nil
    end
end

local get_chunk_rec=function(surface,position)
    if global.chunk_recs[surface.index] and
       global.chunk_recs[surface.index][position.x] and
       global.chunk_recs[surface.index][position.x][position.y] then
           return global.chunk_recs[surface.index][position.x][position.y]
    end
end

local get_chunk_res=function(params)
    local player_rec=get_player_rec(params.player.index)
    if not player_rec.choices[params.name] or not params.player.force.is_chunk_charted(params.surface,{x=params.x,y=params.y}) then
        return nil
    end

    local chunk_layer=global.chunk_recs[params.surface.index]
    if chunk_layer then
        local chunk_col=chunk_layer[params.x]
        if chunk_col then
            local chunk_rec=chunk_col[params.y]
            if chunk_rec then
                local chunk_res=chunk_rec[params.name]
                if chunk_res then
                    return chunk_res
                end
            end
        end
    end
    return nil
end

local directions={
    {x= 1,y= 0},
    {x= 0,y= 1},
    {x=-1,y= 0},
    {x= 0,y=-1},
}

function amount_to_str(amount)
    local amount_str = tostring(amount);

    if (amount >= 1000000) then
        amount_str = tostring(math.floor(amount / 100000) / 10).."M";
    elseif (amount >= 1000) then
        amount_str = tostring(math.floor(amount / 1000)).."k";
    end
    return amount_str
end

local search_chunk_res=function(params,markedStack)

    local currentCount=0
    local originalCount=0
    local originalAmount=0
    local centroid={x=0,y=0}
    local openStack={}

    local chunk_res=get_chunk_res(params)
    if chunk_res and chunk_res.marked==false then
        chunk_res.marked=true
        table.insert(openStack,{x=params.x,y=params.y,cr=chunk_res})
        table.insert(markedStack,chunk_res)

        while #openStack>0 do

            local x,y,cr=openStack[#openStack].x,openStack[#openStack].y,openStack[#openStack].cr
            openStack[#openStack]=nil
            currentCount=currentCount+cr.currentCount
            originalCount=originalCount+cr.originalCount
            originalAmount=originalAmount+cr.originalAmount
            centroid.x=centroid.x+cr.centroid.x
            centroid.y=centroid.y+cr.centroid.y

            for _,direction in pairs(directions) do
                params.x=x+direction.x
                params.y=y+direction.y
                local cr2=get_chunk_res(params)
                if cr2 and cr2.marked==false then
                    cr2.marked=true
                    table.insert(openStack,{x=params.x,y=params.y,cr=cr2})
                    table.insert(markedStack,cr2)
                end
            end

        end

        local amount = originalAmount*currentCount/originalCount;
        local amount_str = amount_to_str(amount);

        if game.item_prototypes["resourcehighlighter-treasure-"..params.name] == nil then
            return;
        end

        -- This formula is a very rough approximation of how much ore is left in the ore patch.
        -- Since the goal is to make the ore patch disappear after it's mostly mined out, the approximation is good enough.
        if originalAmount*currentCount/originalCount>=settings.global["resourcehighlighter-minimum-size"].value then
            local cx,cy=centroid.x/currentCount,centroid.y/currentCount
            local player_rec=get_player_rec(params.player.index)
            local chart_tag=params.player.force.add_chart_tag(params.surface,{
                icon={type="item",name="resourcehighlighter-treasure-"..params.name},
                position={x=cx, y=cy},
                text=amount_str,
                last_user=params.player
            })
            table.insert(player_rec.chart_tags,chart_tag)
        end
    end
end

local destroy_labels=function(player)
    local player_rec=get_player_rec(player.index)
    for _,chart_tag in pairs(player_rec.chart_tags) do
        if chart_tag.valid then
            chart_tag.destroy()
        end
    end
    player_rec.chart_tags={}
end

local update_labels=function(player)
    local player_rec=get_player_rec(player.index)

    destroy_labels(player)

    local markedStack={}
    for s,chunk_layer in pairs(global.chunk_recs) do
        local surface=game.surfaces[s]
        if surface and surface.valid then
            for x,chunk_col in pairs(chunk_layer) do
                for y,chunk_rec in pairs(chunk_col) do
                    for name,chunk_res in pairs(chunk_rec) do
                        search_chunk_res({player=player,surface=surface,x=x,y=y,name=name},markedStack)
                    end
                end
            end
        end
    end
    for _,cr in pairs(markedStack) do
        cr.marked=false
    end

end

local update_player_boxes=function(player)
    local top=player.gui.screen.resourcehighlighter_top
    if top then
        local table_children=top.scroller.table.children
        local player_rec=get_player_rec(player.index)
        for _,child in pairs(table_children) do
            if string.sub(child.name,1,26)=="resourcehighlighter_check_" then
                child.state=player_rec.choices[string.sub(child.name,27)]
            end
        end
    end
end

local set_all_check_boxes=function(player,state)
    local player_rec=get_player_rec(player.index)
    for name,resource_rec in pairs(global.resource_recs) do
        player_rec.choices[name]=state
    end
    update_player_boxes(player)
    update_labels(player)
end

local open_gui=function(player)
    local screen=player.gui.screen
    if not screen.resourcehighlighter_top then
        local player_rec=get_player_rec(player.index)

        screen.add({type="frame",name="resourcehighlighter_top",direction="vertical"})
        local top=screen.resourcehighlighter_top
        local height=500
        top.style.height=height
        top.add({type="flow",name="title_bar",direction="horizontal"})
        top.title_bar.add({type="frame",name="title_frame",direction="horizontal",caption={"resourcehighlighter_title"}})
        top.title_bar.title_frame.style.use_header_filler=true
        top.title_bar.title_frame.drag_target=top
        top.title_bar.title_frame.style.height=36
        top.title_bar.title_frame.style.top_padding=0
        top.title_bar.title_frame.style.bottom_padding=0
        top.title_bar.add({type="sprite-button",sprite="utility/close_white",hovered_sprite="utility/close_black",
            name="resourcehighlighter_close"})
        top.add({type="scroll-pane",name="scroller"})
        top.scroller.style.vertically_stretchable=true
        top.scroller.add({type="table",name="table",column_count=4})
        local table=top.scroller.table
        for _,name in ipairs(get_player_resource_order(player_rec)) do
            if name:find("^se%-core%-fragment") ~= nil then -- Hide SpaceExploration core fragments
                goto skip_to_next;
            end
            if name:find("^creative%-mod") ~= nil then -- Hide creative mod ores
                goto skip_to_next;
            end
            if settings.global["resourcehighlighter-highlight-all"].value then
                player_rec.choices[name]=true
            end
            local resource_rec=global.resource_recs[name]
            table.add({type="checkbox",name="resourcehighlighter_check_"..name,state=player_rec.choices[name]})

            local f=table.add({type="flow",direction="horizontal"})
            for _,pi in ipairs(resource_rec.products_and_ingredients) do
                local b=f.add({type="choose-elem-button",elem_type=pi.type,item=pi.name,fluid=pi.name})
                b.locked=true
            end

            table.add({type="label",caption=resource_rec.caption})

            f=table.add({type="flow",direction="horizontal"})
            for _,miner in ipairs(resource_rec.miners) do
                local b=f.add({type="choose-elem-button",elem_type="item",item=miner.item})
                b.locked=true
            end
            ::skip_to_next::
        end
        top.add({type="flow",name="button_bar",direction="horizontal"})
        local check_all=top.button_bar.add({type="button",name="resourcehighlighter_check_all",caption={"resourcehighlighter_check_all"}})
        check_all.style.horizontally_stretchable=true
        check_all.style.minimal_width=72
        local check_none=top.button_bar.add({type="button",name="resourcehighlighter_check_none",caption={"resourcehighlighter_check_none"}})
        check_none.style.horizontally_stretchable=true
        check_none.style.minimal_width=72
        if player_rec.frame_location then
            top.location=player_rec.frame_location
        else
            top.location={x=0, y=(player.display_resolution.height-height)/2}
        end

        update_labels(player)
    end
end

local close_gui=function(player)
    local screen=player.gui.screen
    if screen.resourcehighlighter_top then
        local player_rec=get_player_rec(player.index)
        player_rec.frame_location=screen.resourcehighlighter_top.location
        screen.resourcehighlighter_top.destroy()

        for name,resource_rec in pairs(global.resource_recs) do
            player_rec.choices[name]=false
        end
        destroy_labels(player)
    end
end

local is_gui_open=function(player)
    local screen=player.gui.screen
    return screen.resourcehighlighter_top~=nil
end

script.on_event("resourcehighlighter-toggle", function(event)
    local player=game.players[event.player_index]
    if is_gui_open(player) then
        close_gui(player)
    else
        open_gui(player)
    end
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == "resourcehighlighter-toggle" then
        local player=game.players[event.player_index]
        if is_gui_open(player) then
            close_gui(player)
        else
            open_gui(player)
        end
    end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    local player=game.players[event.player_index]
    local player_rec=get_player_rec(player.index)
    if string.sub(event.element.name,1,26)=="resourcehighlighter_check_" then
        player_rec.choices[string.sub(event.element.name,27)]=event.element.state
    end
    update_labels(player)
end)

script.on_event(defines.events.on_gui_click, function(event)
    local player=game.players[event.player_index]
    if event.element.name=="resourcehighlighter_close" then
        close_gui(player)
    elseif event.element.name=="resourcehighlighter_check_all" then
        set_all_check_boxes(player,true)
    elseif event.element.name=="resourcehighlighter_check_none" then
        set_all_check_boxes(player,false)
    end
end)

script.on_event(defines.events.on_tick, function(event)
    while #global.chunks_to_scan>0 and global.scanned_chunks<64 and global.scanned_resources<1024 do
        local chunk_to_scan=global.chunks_to_scan[#global.chunks_to_scan]
        global.chunks_to_scan[#global.chunks_to_scan]=nil
        scan_chunk(chunk_to_scan.surface,chunk_to_scan.position)
    end
    global.scanned_chunks=0
    global.scanned_resources=0

    if global.chunks_to_scan_max > 0 then
        if global.chunks_to_scan_time == nil then
            global.chunks_to_scan_time = 0
        end
        global.chunks_to_scan_time = global.chunks_to_scan_time + 1
        if global.chunks_to_scan_time > 60 * 15 then
            global.chunks_to_scan_time = 0
            local percent = math.floor((global.chunks_to_scan_max - #global.chunks_to_scan) / global.chunks_to_scan_max * 100)
            game.print({"resourcehighlighter_scan_percent", percent})
        end
        if #global.chunks_to_scan == 0 then
            game.print({"resourcehighlighter_scan_complete"})
            global.chunks_to_scan_max = 0
        end
    end
end)

script.on_event(defines.events.on_player_changed_force, function(event)
    -- 1. The player's chart tags need to update (because the set of charted chunks changed)
    -- 2. The player's chart tags need to transfer to the new force
    local player=game.players[event.player_index]
    if is_gui_open(player) then
        update_labels(player)
    end
end)

script.on_event(defines.events.on_player_left_game, function(event)
    -- The player's chart tags should no longer appear to teammates after he leaves the game.
    local player=game.players[event.player_index]
    destroy_labels(player)
end)

script.on_event(defines.events.on_chunk_generated, function(event)
    table.insert(global.chunks_to_scan,{surface=event.surface,position=event.position})
end)

script.on_event(defines.events.on_chunk_deleted, function(event)
    for _,position in pairs(event.positions) do
        delete_chunk(game.surfaces[event.surface_index],position)
    end
end)

script.on_event(defines.events.on_resource_depleted, function(event)
    local resource=event.entity
    local chunk_rec=get_chunk_rec(resource.surface,{x=math.floor(resource.position.x/32),y=math.floor(resource.position.y/32)})
    -- This method will work as long as resources are not created/destroyed via scripting
    if chunk_rec then
        local chunk_res=chunk_rec[resource.name]
        if chunk_res and chunk_res.currentCount>0 then
            chunk_res.currentCount=chunk_res.currentCount-1
            chunk_res.centroid.x=chunk_res.centroid.x-resource.position.x
            chunk_res.centroid.y=chunk_res.centroid.y-resource.position.y
            if chunk_res.currentCount==0 then
                chunk_rec[resource.name]=nil
            end
        end
    end
end)

local function reset()
    game.print({"resourcehighlighter_scan_started"})
    init()
    for _,player in pairs(game.players) do
        init_player(player)
    end
end

commands.add_command("rh_reset", {"resourcehighlighter_rescan_reset"}, function(event)
    reset()
end)

script.on_configuration_changed(function(configuration_changed_data)
    for _,player in pairs(game.players) do
        if is_gui_open(player) then
            close_gui(player)
        end
    end

    reset()
end)

