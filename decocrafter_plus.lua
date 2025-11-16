-- =============================================================================
-- decocrafter_plus.lua - Deco Crafter Plus para Z-Fun Mod con Neowalls
-- =============================================================================

local S = minetest.get_translator("z_fun")
local modname = minetest.get_current_modname()

-- =============================================================================
-- LISTA BLANCA: Materiales de decocrafter que tendrán muros dinámicos
-- =============================================================================
local DECOCRAFTER_WALL_WHITELIST = {
    -- Ladrillos
    {node = "decocrafter:brick1", suffix = "brick1"},
    {node = "decocrafter:brick2", suffix = "brick2"},
    {node = "decocrafter:brick3", suffix = "brick3"},
    {node = "decocrafter:brick4", suffix = "brick4"},
    {node = "decocrafter:brick5", suffix = "brick5"},
    {node = "decocrafter:brick6", suffix = "brick6"},
    {node = "decocrafter:brick7", suffix = "brick7"},
    {node = "decocrafter:brick8", suffix = "brick8"},
    {node = "decocrafter:brick9", suffix = "brick9"},
    {node = "decocrafter:brick10", suffix = "brick10"},
    {node = "decocrafter:brick11", suffix = "brick11"},
    {node = "decocrafter:brick12", suffix = "brick12"},
    {node = "decocrafter:brick13", suffix = "brick13"},
    {node = "decocrafter:brick14", suffix = "brick14"},
    {node = "decocrafter:brick15", suffix = "brick15"},
    
    -- Piedras
    {node = "decocrafter:stone1", suffix = "stone1"},
    {node = "decocrafter:stone2", suffix = "stone2"},
    {node = "decocrafter:stone3", suffix = "stone3"},
    {node = "decocrafter:stone4", suffix = "stone4"},
    {node = "decocrafter:stone5", suffix = "stone5"},
    {node = "decocrafter:stone6", suffix = "stone6"},
    {node = "decocrafter:stone7", suffix = "stone7"},
    {node = "decocrafter:stone8", suffix = "stone8"},
    {node = "decocrafter:stone9", suffix = "stone9"},
    {node = "decocrafter:stone10", suffix = "stone10"},
    {node = "decocrafter:stone11", suffix = "stone11"},
    {node = "decocrafter:stone12", suffix = "stone12"},
    
    -- Azulejos
    {node = "decocrafter:tile1", suffix = "tile1"},
    {node = "decocrafter:tile2", suffix = "tile2"},
    {node = "decocrafter:tile3", suffix = "tile3"},
    {node = "decocrafter:tile4", suffix = "tile4"},
    {node = "decocrafter:tile5", suffix = "tile5"},
}

-- =============================================================================
-- SISTEMA NEOWALLS PARA DECOCRAFTER
-- =============================================================================
local decocrafter_neowalls = {
    processed = {},
    is_neowalls_node = {}
}

local function merge_tables(base, new)
    local merged = table.copy(base)
    for k, v in pairs(new) do
        merged[k] = v
    end
    return merged
end

function decocrafter_neowalls.update_wall(pos)
    local node = minetest.get_node(pos)
    local base_name = decocrafter_neowalls.is_neowalls_node[node.name]
    if not base_name then return end

    local subname = decocrafter_neowalls.processed[base_name]
    if not subname then return end
    
    local is_roofed = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name ~= "air"
    
    local function is_neighbor(p)
        local n_name = minetest.get_node(p).name
        local n_def = minetest.registered_nodes[n_name]
        
        if decocrafter_neowalls.is_neowalls_node[n_name] then
            return true
        end
        
        if n_def and n_def.groups then
            if n_def.groups.stone or 
               n_def.groups.brick or 
               n_def.groups.cobble or
               n_def.groups.cracky then
                return true
            end
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
    if is_panel_ns or is_panel_ew then
        local panel_dir = is_panel_ns and "ns" or "ew"
        local roof_state = is_roofed and "c" or "o"
        target_name = "z_fun:dc_panel_" .. roof_state .. "_" .. panel_dir .. "_" .. subname
    else
        local roof_state = is_roofed and "c" or "o"
        target_name = "z_fun:dc_pillar_" .. roof_state .. "_" .. subname
    end

    if node.name ~= target_name then
        minetest.swap_node(pos, {name = target_name})
    end
end

-- =============================================================================
-- FUNCIÓN PRINCIPAL DE REGISTRO
-- =============================================================================
local function register_decocrafter_variants(material_node, node_suffix)
    if not minetest.registered_nodes[material_node] then
        minetest.log("warning", "[Z-Fun] El nodo de decocrafter no se encontró: " .. material_node)
        return
    end

    local node_def = minetest.registered_nodes[material_node]
    local tiles = node_def.tiles
    local sounds = node_def.sounds
    local groups = table.copy(node_def.groups or {})
    local is_brick_or_stone = (string.find(node_suffix, "^brick") or string.find(node_suffix, "^stone") or string.find(node_suffix, "^tile"))

    if string.find(node_suffix, "^wood") then
        groups.choppy = 2.5
        groups.flammable = 2
    end

    -- =============================================================================
    -- MUROS DINÁMICOS CON NEOWALLS
    -- =============================================================================
    if is_brick_or_stone then
        local wall_name = "z_fun:decocrafter_" .. node_suffix .. "_wall"
        local pretty_name = "Decocrafter " .. string.gsub(node_suffix, "(%a)([%w_']*)", function(first, rest) return string.upper(first) .. rest end)
        local wall_desc = S(pretty_name .. " Wall")
        
        decocrafter_neowalls.processed[wall_name] = node_suffix
        
        local wall_groups = table.copy(groups)
        wall_groups.wall = 1
        wall_groups.not_in_creative_inventory = 1
        
        local p_box_o = {
            type = "connected",
            fixed = {{-4/16, -8/16, -4/16, 4/16, 8/16, 4/16}},
            connect_front = {{-3/16, -8/16, -8/16, 3/16, 6/16, -4/16}},
            connect_back  = {{-3/16, -8/16, 4/16, 3/16, 6/16, 8/16}},
            connect_left  = {{-8/16, -8/16, -3/16, -4/16, 6/16, 3/16}},
            connect_right = {{4/16, -8/16, -3/16, 8/16, 6/16, 3/16}}
        }
        
        local p_box_c = {
            type = "connected",
            fixed = {{-4/16, -8/16, -4/16, 4/16, 8/16, 4/16}},
            connect_front = {{-3/16, -8/16, -8/16, 3/16, 8/16, -4/16}},
            connect_back  = {{-3/16, -8/16, 4/16, 3/16, 8/16, 8/16}},
            connect_left  = {{-8/16, -8/16, -3/16, -4/16, 8/16, 3/16}},
            connect_right = {{4/16, -8/16, -3/16, 8/16, 8/16, 3/16}}
        }
        
        local panel_box_ons = {type = "fixed", fixed = {-3/16, -8/16, -8/16, 3/16, 6/16, 8/16}}
        local panel_box_oew = {type = "fixed", fixed = {-8/16, -8/16, -3/16, 8/16, 6/16, 3/16}}
        local panel_box_cns = {type = "fixed", fixed = {-3/16, -8/16, -8/16, 3/16, 8/16, 8/16}}
        local panel_box_cew = {type = "fixed", fixed = {-8/16, -8/16, -3/16, 8/16, 8/16, 3/16}}
        
        local common_props = {
            paramtype = "light",
            sunlight_propagates = true,
            walkable = true,
            sounds = sounds,
            groups = wall_groups,
            tiles = tiles,
            drop = wall_name,
            _base_wall_name = wall_name,
        }
        
        local pillar_o_name = ":z_fun:dc_pillar_o_" .. node_suffix
        local pillar_c_name = ":z_fun:dc_pillar_c_" .. node_suffix
        local panel_o_ns_name = ":z_fun:dc_panel_o_ns_" .. node_suffix
        local panel_o_ew_name = ":z_fun:dc_panel_o_ew_" .. node_suffix
        local panel_c_ns_name = ":z_fun:dc_panel_c_ns_" .. node_suffix
        local panel_c_ew_name = ":z_fun:dc_panel_c_ew_" .. node_suffix
        
        minetest.register_node(pillar_o_name, merge_tables(common_props, {
            description = wall_desc .. " (pilar 14px)",
            drawtype = "nodebox",
            node_box = p_box_o,
            connects_to = {"group:wall", "group:stone", "group:brick", "group:cobble", "group:cracky"}
        }))
        
        minetest.register_node(pillar_c_name, merge_tables(common_props, {
            description = wall_desc .. " (pilar 16px)",
            drawtype = "nodebox",
            node_box = p_box_c,
            connects_to = {"group:wall", "group:stone", "group:brick", "group:cobble", "group:cracky"}
        }))
        
        minetest.register_node(panel_o_ns_name, merge_tables(common_props, {
            description = wall_desc .. " (panel NS 14px)",
            drawtype = "nodebox",
            node_box = panel_box_ons
        }))
        
        minetest.register_node(panel_o_ew_name, merge_tables(common_props, {
            description = wall_desc .. " (panel EW 14px)",
            drawtype = "nodebox",
            node_box = panel_box_oew
        }))
        
        minetest.register_node(panel_c_ns_name, merge_tables(common_props, {
            description = wall_desc .. " (panel NS 16px)",
            drawtype = "nodebox",
            node_box = panel_box_cns
        }))
        
        minetest.register_node(panel_c_ew_name, merge_tables(common_props, {
            description = wall_desc .. " (panel EW 16px)",
            drawtype = "nodebox",
            node_box = panel_box_cew
        }))
        
        decocrafter_neowalls.is_neowalls_node["z_fun:dc_pillar_o_" .. node_suffix] = wall_name
        decocrafter_neowalls.is_neowalls_node["z_fun:dc_pillar_c_" .. node_suffix] = wall_name
        decocrafter_neowalls.is_neowalls_node["z_fun:dc_panel_o_ns_" .. node_suffix] = wall_name
        decocrafter_neowalls.is_neowalls_node["z_fun:dc_panel_o_ew_" .. node_suffix] = wall_name
        decocrafter_neowalls.is_neowalls_node["z_fun:dc_panel_c_ns_" .. node_suffix] = wall_name
        decocrafter_neowalls.is_neowalls_node["z_fun:dc_panel_c_ew_" .. node_suffix] = wall_name
        decocrafter_neowalls.is_neowalls_node[wall_name] = wall_name
        
        local visible_groups = table.copy(groups)
        visible_groups.wall = 1
        
        minetest.register_node(wall_name, {
            description = wall_desc,
            drawtype = "nodebox",
            paramtype = "light",
            sunlight_propagates = true,
            tiles = tiles,
            groups = visible_groups,
            sounds = sounds,
            node_box = p_box_o,
            connects_to = {"group:wall", "group:stone", "group:brick", "group:cobble", "group:cracky"},
            
            on_place = function(itemstack, placer, pointed_thing)
                if pointed_thing.type ~= "node" then return itemstack end
                
                local pos = pointed_thing.above
                local player_name = placer:get_player_name()
                
                if minetest.is_protected(pos, player_name) then
                    minetest.record_protection_violation(pos, player_name)
                    return itemstack
                end

                local node_above = minetest.get_node(pos)
                if not minetest.registered_nodes[node_above.name].buildable_to then
                    return itemstack
                end
                
                if not minetest.is_creative_enabled(player_name) then
                    itemstack:take_item()
                end

                minetest.set_node(pos, {name = "z_fun:dc_pillar_o_" .. node_suffix})
                
                for _, offset in ipairs({
                    {x=0,y=0,z=-1}, {x=0,y=0,z=1},
                    {x=-1,y=0,z=0}, {x=1,y=0,z=0}
                }) do
                    decocrafter_neowalls.update_wall(vector.add(pos, offset))
                end
                
                minetest.after(0.1, function()
                    decocrafter_neowalls.update_wall(pos)
                end)
                
                if sounds and sounds.place then
                    minetest.sound_play(sounds.place, {pos = pos, gain = 1.0}, true)
                end
                
                return itemstack
            end
        })
        
        minetest.register_craft({
            output = wall_name .. " 6",
            recipe = {
                {material_node, material_node, material_node},
                {material_node, material_node, material_node},
                {"", "", ""},
            }
        })
    end

    -- =============================================================================
    -- ESCALERAS
    -- =============================================================================
    local stair_name = "z_fun:decocrafter_" .. node_suffix .. "_stair"
    local pretty_name = "Decocrafter " .. string.gsub(node_suffix, "(%a)([%w_']*)", function(first, rest) return string.upper(first) .. rest end)
    local stair_desc = S(pretty_name .. " Stair")
    minetest.register_node(stair_name, {
        description = stair_desc,
        drawtype = "nodebox",
        paramtype = "light",
        paramtype2 = "facedir",
        is_ground_content = false,
        tiles = tiles,
        groups = groups,
        sounds = sounds,
        node_box = {
            type = "fixed",
            fixed = {
                {-0.5, -0.5, -0.5, 0.5, 0, 0.5},
                {-0.5, 0, 0, 0.5, 0.5, 0.5}
            }
        },
    })
    minetest.register_craft({
        output = stair_name .. " 8",
        recipe = {
            {material_node, "", ""},
            {material_node, material_node, ""},
            {material_node, material_node, material_node}
        }
    })

    -- =============================================================================
    -- LOSAS
    -- =============================================================================
    local slab_name = "z_fun:decocrafter_" .. node_suffix .. "_slab"
    local slab_desc = S(pretty_name .. " Slab")
    minetest.register_node(slab_name, {
        description = slab_desc,
        drawtype = "nodebox",
        paramtype = "light",
        paramtype2 = "facedir",
        is_ground_content = false,
        tiles = tiles,
        groups = groups,
        sounds = sounds,
        node_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5}
        },
        selection_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5}
        },
        on_place = minetest.rotate_node,
    })
    minetest.register_craft({
        output = slab_name .. " 6",
        recipe = {{material_node, material_node, material_node}}
    })

    -- =============================================================================
    -- ESQUINAS EXTERIORES
    -- =============================================================================
    local outer_name = "z_fun:decocrafter_" .. node_suffix .. "_outer"
    local outer_desc = S(pretty_name .. " Outer Corner")
    local outer_groups = table.copy(groups)
    outer_groups.not_in_creative_inventory = 1
    minetest.register_node(outer_name, {
        description = outer_desc,
        drawtype = "nodebox",
        paramtype = "light",
        paramtype2 = "facedir",
        is_ground_content = false,
        tiles = tiles,
        groups = outer_groups,
        sounds = sounds,
        node_box = {
            type = "fixed",
            fixed = {
                {-0.5, -0.5, -0.5, 0.5, 0, 0.5},
                {0, 0, -0.5, 0.5, 0.5, 0}
            }
        },
    })
    minetest.register_craft({
        output = outer_name .. " 8",
        recipe = {
            {"", "", ""},
            {"", material_node, ""},
            {material_node, material_node, material_node}
        }
    })

    -- =============================================================================
    -- ESQUINAS INTERIORES
    -- =============================================================================
    local inner_name = "z_fun:decocrafter_" .. node_suffix .. "_inner"
    local inner_desc = S(pretty_name .. " Inner Corner")
    local inner_groups = table.copy(groups)
    inner_groups.not_in_creative_inventory = 1
    minetest.register_node(inner_name, {
        description = inner_desc,
        drawtype = "nodebox",
        paramtype = "light",
        paramtype2 = "facedir",
        is_ground_content = false,
        tiles = tiles,
        groups = inner_groups,
        sounds = sounds,
        node_box = {
            type = "fixed",
            fixed = {
                {-0.5, -0.5, -0.5, 0.5, 0, 0.5},
                {-0.5, 0, -0.5, 0, 0.5, 0},
                {-0.5, 0, 0, 0, 0.5, 0.5},
                {0, 0, -0.5, 0.5, 0.5, 0}
            }
        },
    })
    minetest.register_craft({
        output = inner_name .. " 8",
        recipe = {
            {"", material_node, ""},
            {material_node, "", material_node},
            {material_node, material_node, material_node}
        }
    })

    minetest.log("action", "[Z-Fun] Soporte para " .. material_node .. " añadido.")
end

-- =============================================================================
-- ↓↓↓ AQUÍ EMPIEZA LO QUE DEBES REEMPLAZAR ↓↓↓
-- Borra desde "register_decocrafter_variants("decocrafter:brick1"..." 
-- hasta "...register_decocrafter_variants("decocrafter:tile5", "tile5")"
-- Y reemplázalo con esto:
-- =============================================================================

-- Procesamiento de la lista blanca
for _, entry in ipairs(DECOCRAFTER_WALL_WHITELIST) do
    register_decocrafter_variants(entry.node, entry.suffix)
end

-- =============================================================================
-- MADERAS (sin cambios, esto ya estaba bien)
-- =============================================================================
local WOODS_TO_REGISTER = { "wood1", "wood2", "wood3", "wood4", "wood5", "wood6", "wood7", "wood8", "wood9" }
for _, suffix in ipairs(WOODS_TO_REGISTER) do
    register_decocrafter_variants("decocrafter:" .. suffix, suffix)
end

-- =============================================================================
-- ABM PARA ACTUALIZACIÓN
-- =============================================================================
minetest.register_abm({
    label = "decocrafter neowalls updater",
    nodenames = {"group:wall"},
    interval = 1.0,
    chance = 1,
    action = function(pos, node)
        if decocrafter_neowalls.is_neowalls_node[node.name] then
            decocrafter_neowalls.update_wall(pos)
        end
    end
})

print("[Z-Fun] Decocrafter Plus con Neowalls cargado!")
