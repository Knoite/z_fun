-- =============================================================================
-- neowalls.lua (v39.0) - FIXED: MTG_PLUS INTEGRATION
-- =============================================================================

local modname = minetest.get_current_modname()
local neowalls = {}

neowalls.processed = {}
neowalls.is_neowalls_node = {}
neowalls.wall_data = {}

print("[neowalls] v39.0 - Iniciando carga...")

-- =============================================================================
-- LISTA BLANCA
-- =============================================================================
local WALL_WHITELIST = {
    -- === MUROS DEFAULT ===
    "walls:cobble",
    "walls:mossycobble",
    "walls:desertcobble",
    "walls:stonebrick",
    "walls:desert_stonebrick",
    "walls:sandstone",
    "walls:desertsandstone",
    "walls:silver_sandstone",
}

-- === MUROS DE MTG+ (mtg_plus) ===
local MTG_PLUS_WALLS = {
    "mtg_plus:wall_desert_sandstone_cobble",
    "mtg_plus:wall_gravel_cobble",
    "mtg_plus:wall_ice_tile16",
    "mtg_plus:wall_jungle_cobble",
    "mtg_plus:wall_sandstone_cobble",
    "mtg_plus:wall_silver_sandstone_cobble",
}

-- === MUROS DE DARKAGE ===
local DARKAGE_WALLS = {
    "darkage:basalt_rubble_wall",
    "darkage:ors_rubble_wall",
    "darkage:stone_brick_wall",
    "darkage:slate_rubble_wall",
    "darkage:tuff_bricks_wall",
    "darkage:old_tuff_bricks_wall",
    "darkage:rhyolitic_tuff_bricks_wall",
}

-- === MUROS DE WALLY ===
local WALLY_WALLS = {
    "wally:darkage_ors_brick_wall",
    "wally:darkage_basalt_brick_wall",
    "wally:darkage_gneiss_brick_wall",
    "wally:darkage_chalked_bricks_wall",
    "wally:darkage_slate_brick_wall",
}

-- Inserción dinámica según mods activos
if minetest.get_modpath("mtg_plus") then
    for _, wall in ipairs(MTG_PLUS_WALLS) do table.insert(WALL_WHITELIST, wall) end
    print("[neowalls] MTG+ detectado, preparando muros...")
end

if minetest.get_modpath("darkage") then
    for _, wall in ipairs(DARKAGE_WALLS) do table.insert(WALL_WHITELIST, wall) end
end

if minetest.get_modpath("wally") then
    for _, wall in ipairs(WALLY_WALLS) do table.insert(WALL_WHITELIST, wall) end
end

-- =============================================================================
-- UTILIDADES
-- =============================================================================
local function merge_tables(base, new)
    local merged = table.copy(base)
    for k, v in pairs(new) do merged[k] = v end
    return merged
end

local function get_wall_config(wall_name)
    local registered = minetest.registered_nodes[wall_name]
    if not registered then return nil end
    
    local subname
    if wall_name:match("^walls:") then
        subname = wall_name:gsub("^walls:", "")
    elseif wall_name:match("^mtg_plus:") then
        subname = wall_name:gsub("^mtg_plus:wall_", ""):gsub("^mtg_plus:", "")
    elseif wall_name:match("^darkage:") then
        subname = wall_name:gsub("^darkage:", ""):gsub("_wall$", "")
    elseif wall_name:match("^wally:") then
        subname = wall_name:gsub("^wally:", ""):gsub("_wall$", "")
    else
        subname = wall_name:gsub(".*:", "")
    end
    
    return {
        subname = subname,
        texture = registered.tiles and registered.tiles[1] or "default_stone.png",
        sounds = registered.sounds or default.node_sound_stone_defaults(),
    }
end

-- =============================================================================
-- MOTOR DE ACTUALIZACIÓN
-- =============================================================================
function neowalls.update_wall(pos)
    local node = minetest.get_node(pos)
    local base_name = neowalls.is_neowalls_node[node.name]
    if not base_name then return end

    local subname = neowalls.processed[base_name]
    if not subname then return end
    
    local is_roofed = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name ~= "air"
    
    local function is_neighbor(p)
        local n_name = minetest.get_node(p).name
        local n_def = minetest.registered_nodes[n_name]
        if neowalls.is_neowalls_node[n_name] then return true end
        if n_def and n_def.groups and (n_def.groups.stone or n_def.groups.brick or n_def.groups.cobble or n_def.groups.cracky) then
            return true
        end
        return false
    end
    
    local n = is_neighbor({x=pos.x, y=pos.y, z=pos.z-1})
    local s = is_neighbor({x=pos.x, y=pos.y, z=pos.z+1})
    local e = is_neighbor({x=pos.x+1, y=pos.y, z=pos.z})
    local w = is_neighbor({x=pos.x-1, y=pos.y, z=pos.z})

    local is_panel_ns = (n and s and not e and not w)
    local is_panel_ew = (e and w and not n and not s)
    
    local target_name
    local roof_state = is_roofed and "c" or "o"
    if is_panel_ns or is_panel_ew then
        local panel_dir = is_panel_ns and "ns" or "ew"
        target_name = "z_fun:nw_panel_" .. roof_state .. "_" .. panel_dir .. "_" .. subname
    else
        target_name = "z_fun:nw_pillar_" .. roof_state .. "_" .. subname
    end

    if node.name ~= target_name and minetest.registered_nodes[target_name] then
        minetest.swap_node(pos, {name = target_name})
    end
end

-- =============================================================================
-- REGISTRO DE VARIANTES
-- =============================================================================
local function register_wall_variants(wall_name, data)
    local subname = data.subname
    local base_wall_name = wall_name
    neowalls.processed[base_wall_name] = subname
    neowalls.wall_data[base_wall_name] = data
    
    local common_props = {
        paramtype = "light", sunlight_propagates = true, walkable = true,
        sounds = data.sounds or default.node_sound_stone_defaults(),
        groups = {not_in_creative_inventory = 1, wall = 1, cracky = 2}, 
        tiles = {data.texture},
        drop = base_wall_name, 
        _base_wall_name = base_wall_name,
    }
    
    local names = {
        pillar_o   = ":z_fun:nw_pillar_o_"..subname,   
        pillar_c   = ":z_fun:nw_pillar_c_"..subname,
        panel_o_ns = ":z_fun:nw_panel_o_ns_"..subname, 
        panel_o_ew = ":z_fun:nw_panel_o_ew_"..subname,
        panel_c_ns = ":z_fun:nw_panel_c_ns_"..subname, 
        panel_c_ew = ":z_fun:nw_panel_c_ew_"..subname,
    }

    local p_box_o = { type = "connected", fixed = {{-4/16, -8/16, -4/16, 4/16, 8/16, 4/16}},
        connect_front = {{-3/16, -8/16, -8/16, 3/16, 6/16, -4/16}}, connect_back = {{-3/16, -8/16, 4/16, 3/16, 6/16, 8/16}},
        connect_left = {{-8/16, -8/16, -3/16, -4/16, 6/16, 3/16}}, connect_right = {{4/16, -8/16, -3/16, 8/16, 6/16, 3/16}} }
    
    local p_box_c = { type = "connected", fixed = {{-4/16, -8/16, -4/16, 4/16, 8/16, 4/16}},
        connect_front = {{-3/16, -8/16, -8/16, 3/16, 8/16, -4/16}}, connect_back = {{-3/16, -8/16, 4/16, 3/16, 8/16, 8/16}},
        connect_left = {{-8/16, -8/16, -3/16, -4/16, 8/16, 3/16}}, connect_right = {{4/16, -8/16, -3/16, 8/16, 8/16, 3/16}} }

    minetest.register_node(names.pillar_o, merge_tables(common_props, {drawtype = "nodebox", node_box = p_box_o, connects_to = {"group:wall", "group:stone", "group:brick", "group:cobble", "group:cracky"}}))
    minetest.register_node(names.pillar_c, merge_tables(common_props, {drawtype = "nodebox", node_box = p_box_c, connects_to = {"group:wall", "group:stone", "group:brick", "group:cobble", "group:cracky"}}))
    minetest.register_node(names.panel_o_ns, merge_tables(common_props, {drawtype = "nodebox", node_box = {type = "fixed", fixed = {-3/16, -8/16, -8/16, 3/16, 6/16, 8/16}}}))
    minetest.register_node(names.panel_o_ew, merge_tables(common_props, {drawtype = "nodebox", node_box = {type = "fixed", fixed = {-8/16, -8/16, -3/16, 8/16, 6/16, 3/16}}}))
    minetest.register_node(names.panel_c_ns, merge_tables(common_props, {drawtype = "nodebox", node_box = {type = "fixed", fixed = {-3/16, -8/16, -8/16, 3/16, 8/16, 8/16}}}))
    minetest.register_node(names.panel_c_ew, merge_tables(common_props, {drawtype = "nodebox", node_box = {type = "fixed", fixed = {-8/16, -8/16, -3/16, 8/16, 8/16, 3/16}}}))

    for _, n in pairs(names) do neowalls.is_neowalls_node[n:gsub("^:", "")] = base_wall_name end
    neowalls.is_neowalls_node[base_wall_name] = base_wall_name
end

-- =============================================================================
-- CICLOS DE REGISTRO (Fase 1 y Fase 2)
-- =============================================================================
for _, wall_name in ipairs(WALL_WHITELIST) do
    if wall_name:match("^walls:") and minetest.registered_nodes[wall_name] then
        local data = get_wall_config(wall_name)
        if data then register_wall_variants(wall_name, data) end
    end
end

minetest.register_on_mods_loaded(function()
    print("[neowalls] Fase 2: Registrando muros de mods externos...")
    for _, wall_name in ipairs(WALL_WHITELIST) do
        -- AGREGADO mtg_plus AQUÍ:
        if (wall_name:match("^darkage:") or wall_name:match("^wally:") or wall_name:match("^mtg_plus:")) and minetest.registered_nodes[wall_name] then
            local data = get_wall_config(wall_name)
            if data then register_wall_variants(wall_name, data) end
        end
    end
    
    for wall_name, data in pairs(neowalls.wall_data) do
        local subname = data.subname
        minetest.override_item(wall_name, {
            on_place = function(itemstack, placer, pointed_thing)
                if pointed_thing.type ~= "node" then return itemstack end
                local pos = pointed_thing.above
                if minetest.is_protected(pos, placer:get_player_name()) then return itemstack end
                if not minetest.registered_nodes[minetest.get_node(pos).name].buildable_to then return itemstack end
                if not minetest.is_creative_enabled(placer:get_player_name()) then itemstack:take_item() end

                minetest.set_node(pos, {name = "z_fun:nw_pillar_o_"..subname})
                for _, offset in ipairs({{x=0,y=0,z=-1},{x=0,y=0,z=1},{x=-1,y=0,z=0},{x=1,y=0,z=0}}) do
                    neowalls.update_wall(vector.add(pos, offset))
                end
                minetest.after(0.1, function() neowalls.update_wall(pos) end)
                return itemstack
            end
        })
    end
end)

minetest.register_abm({
    label = "neowalls updater", nodenames = {"group:wall"}, interval = 1.0, chance = 1,
    action = function(pos, node) if neowalls.is_neowalls_node[node.name] then neowalls.update_wall(pos) end end
})
