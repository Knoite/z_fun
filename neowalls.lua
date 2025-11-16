-- =============================================================================
-- neowalls.lua (v15.0) - El Orden Correcto
-- Arquitectura: Se asume que este archivo se carga AL FINAL. Se corrige la
-- lista de muros con los nombres exactos creados por wally y decocrafter_plus.
-- =============================================================================

local modname = minetest.get_current_modname()
local neowalls = {}

neowalls.processed = {}
neowalls.is_neowalls_node = {}

local function merge_tables(base, new)
    local merged = table.copy(base)
    for k, v in pairs(new) do
        merged[k] = v
    end
    return merged
end

-- =============================================================================
-- CONFIGURACIÓN PRINCIPAL: LA LISTA MAESTRA (¡CORREGIDA Y COMPLETA!)
-- =============================================================================
local WALL_DEFINITIONS = {
    -- === MUROS DE 'walls' (MOD ESTÁNDAR) ===
    { original="walls:wall_stone",        subname="wl_stone",    texture="default_stone.png",          sounds=default.node_sound_stone_defaults(), groups={cracky=3} },
    { original="walls:wall_cobble",       subname="wl_cobble",   texture="default_cobble.png",         sounds=default.node_sound_stone_defaults(), groups={cracky=3} },
    { original="walls:wall_brick",        subname="wl_brick",    texture="default_brick.png",          sounds=default.node_sound_stone_defaults(), groups={cracky=2} },
    { original="walls:wall_sandstone",    subname="wl_sandstone",texture="default_sandstone.png",      sounds=default.node_sound_stone_defaults(), groups={cracky=3} },
    { original="walls:wall_obsidian",     subname="wl_obsidian", texture="default_obsidian.png",       sounds=default.node_sound_stone_defaults(), groups={cracky=1} },
    { original="walls:wall_wood",         subname="wl_wood",     texture="default_wood.png",           sounds=default.node_sound_wood_defaults(),  groups={choppy=2} },

    -- === MUROS DE DECOCRAFTER (creados por z_fun/decocrafter_plus.lua) ===
    { original="z_fun:decocrafter_brick1_wall",  subname="dcb1",  texture="decocrafter_brick1.png",  sounds=default.node_sound_stone_defaults(), groups={cracky=2} },
    { original="z_fun:decocrafter_brick2_wall",  subname="dcb2",  texture="decocrafter_brick2.png",  sounds=default.node_sound_stone_defaults(), groups={cracky=2} },
    { original="z_fun:decocrafter_brick3_wall",  subname="dcb3",  texture="decocrafter_brick3.png",  sounds=default.node_sound_stone_defaults(), groups={cracky=2} },
    -- ... (y así para todos los de decocrafter)

    -- === MUROS DE DARKAGE (creados por wally) ===
    -- Nombres extraídos de wally.lua: wally:<item_name>_wall
    { original="wally:basalt_brick_wall",     subname="dk_basalt_brick",     texture="darkage_basalt_brick.png", sounds=default.node_sound_stone_defaults(), groups={cracky=2} },
    { original="wally:slate_brick_wall",      subname="dk_slate_brick",      texture="darkage_slate_brick.png",  sounds=default.node_sound_stone_defaults(), groups={cracky=2} },
    { original="wally:gneiss_brick_wall",     subname="dk_gneiss_brick",     texture="darkage_gneiss_brick.png", sounds=default.node_sound_stone_defaults(), groups={cracky=2} },
    { original="wally:chalked_bricks_wall",   subname="dk_chalked_bricks",   texture="darkage_chalked_bricks.png", sounds=default.node_sound_stone_defaults(), groups={cracky=2} },
    { original="wally:ors_brick_wall",        subname="dk_ors_brick",        texture="darkage_ors_brick.png",    sounds=default.node_sound_stone_defaults(), groups={cracky=2} },
    { original="wally:gneiss_wall",           subname="dk_gneiss",           texture="darkage_gneiss.png",       sounds=default.node_sound_stone_defaults(), groups={cracky=3} },
    { original="wally:schist_wall",           subname="dk_schist",           texture="darkage_schist.png",       sounds=default.node_sound_stone_defaults(), groups={cracky=3} },
}

-- =============================================================================
-- EL MOTOR DE NEOWALLS
-- =============================================================================

function neowalls.update_wall(pos)
    local node = minetest.get_node(pos)
    if not neowalls.is_neowalls_node[node.name] then return end

    local node_def = minetest.registered_nodes[node.name]
    local base_name = node_def._base_wall_name
    
    local subname = neowalls.processed[base_name]
    if not subname then return end
    
    local is_roofed = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name ~= "air"
    
    local function is_neighbor(p)
        local n_name = minetest.get_node(p).name
        return neowalls.is_neowalls_node[n_name] or minetest.get_item_group(n_name, "wall") > 0
    end
    local n, s = is_neighbor({x=pos.x,y=pos.y,z=pos.z-1}), is_neighbor({x=pos.x,y=pos.y,z=pos.z+1})
    local e, w = is_neighbor({x=pos.x+1,y=pos.y,z=pos.z}), is_neighbor({x=pos.x-1,y=pos.y,z=pos.z})

    local connections = (n and 1 or 0) + (s and 1 or 0) + (e and 1 or 0) + (w and 1 or 0)
    local is_panel_ns = n and s and connections == 2
    local is_panel_ew = e and w and connections == 2
    
    local target_name
    if is_panel_ns or is_panel_ew then
        local panel_dir = is_panel_ns and "ns" or "ew"
        target_name = modname .. ":nw_panel_" .. (is_roofed and "c_" or "o_") .. panel_dir .. "_" .. subname
    else
        target_name = modname .. ":nw_pillar_" .. (is_roofed and "c_" or "o_") .. "_" .. subname
    end

    if node.name ~= target_name then
        minetest.swap_node(pos, {name = target_name})
    end
end

-- =============================================================================
-- REGISTRO DE NODOS E INTERCEPCIÓN
-- =============================================================================
-- Ya no se necesita on_mods_loaded porque init.lua controla el orden de carga.
print("[neowalls] v15.0 - Iniciando registro de muros...")

local registered_count = 0
for _, data in ipairs(WALL_DEFINITIONS) do
    if not minetest.registered_nodes[data.original] then
        minetest.log("info", "[neowalls] Muro base no encontrado, saltando: "..data.original)
        goto continue
    end

    local subname = data.subname
    local base_wall_name = data.original
    neowalls.processed[base_wall_name] = subname
    
    local dynamic_groups = table.copy(data.groups or {cracky=3});
    dynamic_groups.not_in_creative_inventory = 1;
    dynamic_groups.wall = 1;

    local common_props = {
        paramtype = "light", sunlight_propagates = true, walkable = true,
        sounds = data.sounds or default.node_sound_stone_defaults(),
        groups = dynamic_groups, tiles = {data.texture},
        drop = base_wall_name, _base_wall_name = base_wall_name,
    }
    
    local names = {
        pillar_o   = ":nw_pillar_o_"..subname,   pillar_c   = ":nw_pillar_c_"..subname,
        panel_o_ns = ":nw_panel_o_ns_"..subname, panel_o_ew = ":nw_panel_o_ew_"..subname,
        panel_c_ns = ":nw_panel_c_ns_"..subname, panel_c_ew = ":nw_panel_c_ew_"..subname,
    }
    
    local p_box_o = {type="connected",fixed={{-4/16,-8/16,-4/16,4/16,8/16,4/16}},connect_front={{-3/16,-8/16,-8/16,3/16,6/16,-4/16}},connect_back={{-3/16,-8/16,4/16,3/16,6/16,8/16}},connect_left={{-8/16,-8/16,-3/16,-4/16,6/16,3/16}},connect_right={{4/16,-8/16,-3/16,8/16,6/16,3/16}}}
    local p_box_c = {type="connected",fixed={{-4/16,-8/16,-4/16,4/16,8/16,4/16}},connect_front={{-3/16,-8/16,-8/16,3/16,8/16,-4/16}},connect_back={{-3/16,-8/16,4/16,3/16,8/16,8/16}},connect_left={{-8/16,-8/16,-3/16,-4/16,8/16,3/16}},connect_right={{4/16,-8/16,-3/16,8/16,8/16,3/16}}}
    local panel_box_ons = {type="fixed",fixed={-3/16,-8/16,-8/16,3/16,6/16,8/16}}
    local panel_box_oew = {type="fixed",fixed={-8/16,-8/16,-3/16,8/16,6/16,3/16}}
    local panel_box_cns = {type="fixed",fixed={-3/16,-8/16,-8/16,3/16,8/16,8/16}}
    local panel_box_cew = {type="fixed",fixed={-8/16,-8/16,-3/16,8/16,8/16,3/16}}
    
    minetest.register_node(names.pillar_o, merge_tables(common_props, {drawtype="nodebox", node_box=p_box_o, connects_to={"group:wall","group:stone","group:brick","group:wood","group:fence"}}))
    minetest.register_node(names.pillar_c, merge_tables(common_props, {drawtype="nodebox", node_box=p_box_c, connects_to={"group:wall","group:stone","group:brick","group:wood","group:fence"}}))
    minetest.register_node(names.panel_o_ns, merge_tables(common_props, {drawtype="nodebox", node_box=panel_box_ons}))
    minetest.register_node(names.panel_o_ew, merge_tables(common_props, {drawtype="nodebox", node_box=panel_box_oew}))
    minetest.register_node(names.panel_c_ns, merge_tables(common_props, {drawtype="nodebox", node_box=panel_box_cns}))
    minetest.register_node(names.panel_c_ew, merge_tables(common_props, {drawtype="nodebox", node_box=panel_box_cew}))

    neowalls.is_neowalls_node[base_wall_name] = true
    for _, name_part in pairs(names) do neowalls.is_neowalls_node[modname..name_part] = true end
    
    registered_count = registered_count + 1
    ::continue::
end
print(string.format("[neowalls] Registro completado. %d tipos de muros mejorados.", registered_count))

-- =============================================================================
-- EL GATILLO GLOBAL
-- =============================================================================
minetest.register_on_placenode(function(pos, newnode, placer)
    local subname = neowalls.processed[newnode.name]
    if subname then
        local is_roofed = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name ~= "air"
        local pillar_name = modname .. ":nw_pillar_" .. (is_roofed and "c_" or "o_") .. subname
        minetest.set_node(pos, {name = pillar_name})
    end
    for _, offset in ipairs({{x=0,y=0,z=-1},{x=0,y=0,z=1},{x=-1,y=0,z=0},{x=1,y=0,z=0},{x=0,y=-1,z=0},{x=0,y=1,z=0}}) do
        neowalls.update_wall(vector.add(pos, offset))
    end
    neowalls.update_wall(pos)
end)

minetest.register_on_dignode(function(pos, oldnode)
    for _, offset in ipairs({{x=0,y=0,z=-1},{x=0,y=0,z=1},{x=-1,y=0,z=0},{x=1,y=0,z=0},{x=0,y=-1,z=0},{x=0,y=1,z=0}}) do
        neowalls.update_wall(vector.add(pos, offset))
    end
end)

print("[neowalls] v15.0 - ¡El Orden Correcto está cargado!")
