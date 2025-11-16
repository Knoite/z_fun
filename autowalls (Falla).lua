-- =============================================================================
-- autowalls.lua (Versión 7.1 - con Lista Blanca)
-- Descripción: Se corrige la dureza de los bloques, se implementa la
--              conversión a panel y se añade una lista blanca para
--              muros problemáticos.
-- =============================================================================

local modname = minetest.get_current_modname()

-- =============================================================================
-- AÑADIDO: LISTA BLANCA DE MUROS
-- =============================================================================
-- Aquí puedes añadir los nombres de los muros que no son detectados
-- automáticamente por el script. El sistema los forzará a ser procesados.
-- Simplemente añade una nueva línea con el formato ["nombre_del_muro"] = true,
-- =============================================================================
local WALLS_WHITELIST = {
    ["z_fun:decocrafter_brick10_wall"] = true,
    ["z_fun:decocrafter_brick8_wall"] = true,
    ["z_fun:decocrafter_brick9_wall"] = true,
    ["z_fun:decocrafter_brick7_wall"] = true,
    ["z_fun:decocrafter_stone4_wall"] = true,
    ["z_fun:decocrafter_stone9_wall"] = true,
    -- Añade aquí más muros si es necesario en el futuro
}


z_fun.autowalls = {}
z_fun.autowalls.processed = {}

-- Grupos que pueden formar un "muro continuo" con nuestros paneles.
local PANEL_NEIGHBOR_GROUPS = {
    wall = 1, stone = 1, brick = 1, wood = 1, fence = 1,
}

local function is_panel_neighbor(node_name)
    if not minetest.registered_nodes[node_name] then return false end
    for group, _ in pairs(PANEL_NEIGHBOR_GROUPS) do
        if minetest.get_item_group(node_name, group) > 0 then
            return true
        end
    end
    -- MODIFICADO: Comprobar si el vecino está en la lista blanca también puede considerarse un vecino válido
    if WALLS_WHITELIST[node_name] then
        return true
    end
    return false
end

-- El cerebro de la operación (con la nueva lógica de paneles)
function z_fun.autowalls.update_at(pos)
    local node = minetest.get_node(pos)
    -- Si el nodo no es un muro y no está en la lista blanca, no hacemos nada.
    if minetest.get_item_group(node.name, "wall") == 0 and not WALLS_WHITELIST[node.name] then return end
    
    local node_def = minetest.registered_nodes[node.name]
    local base_name = (node_def and node_def._base_wall_name) or node.name
    
    if not z_fun.autowalls.processed[base_name] then return end
    
    local unique_id = minetest.sha1(base_name):sub(1, 12)
    local is_roofed = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name ~= "air"

    -- Analizar vecinos
    local n, s = minetest.get_node({x=pos.x,y=pos.y,z=pos.z-1}).name, minetest.get_node({x=pos.x,y=pos.y,z=pos.z+1}).name
    local e, w = minetest.get_node({x=pos.x+1,y=pos.y,z=pos.z}).name, minetest.get_node({x=pos.x-1,y=pos.y,z=pos.z}).name

    -- ¡NUEVA LÓGICA DE PANEL!
    local n_is_neighbor = is_panel_neighbor(n)
    local s_is_neighbor = is_panel_neighbor(s)
    local e_is_neighbor = is_panel_neighbor(e)
    local w_is_neighbor = is_panel_neighbor(w)

    local connections = (n_is_neighbor and 1 or 0)+(s_is_neighbor and 1 or 0)+(e_is_neighbor and 1 or 0)+(w_is_neighbor and 1 or 0)
    local is_panel_ns = n_is_neighbor and s_is_neighbor and connections == 2
    local is_panel_ew = e_is_neighbor and w_is_neighbor and connections == 2
    local target_name

    if is_panel_ns or is_panel_ew then
        -- Se convierte en panel
        if is_panel_ns then
            target_name = modname .. (is_roofed and ":panel_closed_ns" or ":panel_open_ns") .. unique_id
        else
            target_name = modname .. (is_roofed and ":panel_closed_ew" or ":panel_open_ew") .. unique_id
        end
    else
        -- Se convierte en pilar
        target_name = modname .. (is_roofed and ":pillar_closed" or ":pillar_open") .. unique_id
    end

    if node.name ~= target_name then
        minetest.swap_node(pos, {name = target_name})
    end
end

-- =============================================================================
-- REGISTRO DE NODOS (CON HERENCIA DE GRUPOS CORREGIDA)
-- =============================================================================
print(string.format("[%s] [autowalls v7.1] Registrando variantes de muros...", modname))
for name, def in pairs(minetest.registered_nodes) do
    
    -- =============================================================================
    -- MODIFICADO: Se añade la comprobación de la lista blanca
    -- =============================================================================
    -- Un nodo se procesará si:
    -- 1. Es un muro normal (tiene el grupo 'wall' y no es uno de nuestros muros dinámicos).
    -- O
    -- 2. Está explícitamente en nuestra lista blanca 'WALLS_WHITELIST'.
    local is_normal_wall = minetest.get_item_group(name, "wall") > 0 and not def._is_dynamic_wall
    local is_whitelisted = WALLS_WHITELIST[name]

    if is_normal_wall or is_whitelisted then
        local unique_id = minetest.sha1(name):sub(1, 12)
        local base_texture = def.tiles and def.tiles[1]
        if not base_texture then goto continue end

        -- ¡CORRECCIÓN DE GRUPOS!
        -- Copiamos TODOS los grupos del nodo original para heredar la dureza.
        local inherited_groups = table.copy(def.groups)
        inherited_groups.not_in_creative_inventory = 1 -- Ocultamos el nuestro
        inherited_groups.wall = 1 -- Nos aseguramos de que siga siendo un muro

        local common_props = {
            paramtype = "light", sunlight_propagates = true, walkable = true,
            sounds = def.sounds, groups = inherited_groups, -- Usamos los grupos heredados
            drop = name, _is_dynamic_wall = true, _base_wall_name = name,
            tiles = {base_texture},
        }
        
        -- El registro ahora es seguro y hereda la dureza.
        local p_open_props = table.copy(common_props); p_open_props.connects_to = {"group:wall","group:stone","group:brick","group:wood","group:fence"}; p_open_props.drawtype = "nodebox"; p_open_props.node_box = {type="connected",fixed={{-4/16,-8/16,-4/16,4/16,8/16,4/16}},connect_front={{-3/16,-8/16,-8/16,3/16,6/16,-4/16}},connect_back={{-3/16,-8/16,4/16,3/16,6/16,8/16}},connect_left={{-8/16,-8/16,-3/16,-4/16,6/16,3/16}},connect_right={{4/16,-8/16,-3/16,8/16,6/16,3/16}}}; minetest.register_node(modname..":pillar_open"..unique_id, p_open_props)
        local p_closed_props = table.copy(common_props); p_closed_props.connects_to = p_open_props.connects_to; p_closed_props.drawtype = "nodebox"; p_closed_props.node_box = {type="connected",fixed={{-4/16,-8/16,-4/16,4/16,8/16,4/16}},connect_front={{-3/16,-8/16,-8/16,3/16,8/16,-4/16}},connect_back={{-3/16,-8/16,4/16,3/16,8/16,8/16}},connect_left={{-8/16,-8/16,-3/16,-4/16,8/16,3/16}},connect_right={{4/16,-8/16,-3/16,8/16,8/16,3/16}}}; minetest.register_node(modname..":pillar_closed"..unique_id, p_closed_props)
        local panel_ons_props = table.copy(common_props); panel_ons_props.drawtype="nodebox"; panel_ons_props.node_box={type="fixed",fixed={-3/16,-8/16,-8/16,3/16,6/16,8/16}}; minetest.register_node(modname..":panel_open_ns"..unique_id, panel_ons_props)
        local panel_oew_props = table.copy(common_props); panel_oew_props.drawtype="nodebox"; panel_oew_props.node_box={type="fixed",fixed={-8/16,-8/16,-3/16,8/16,6/16,3/16}}; minetest.register_node(modname..":panel_open_ew"..unique_id, panel_oew_props)
        local panel_cns_props = table.copy(common_props); panel_cns_props.drawtype="nodebox"; panel_cns_props.node_box={type="fixed",fixed={-3/16,-8/16,-8/16,3/16,8/16,8/16}}; minetest.register_node(modname..":panel_closed_ns"..unique_id, panel_cns_props)
        local panel_cew_props = table.copy(common_props); panel_cew_props.drawtype="nodebox"; panel_cew_props.node_box={type="fixed",fixed={-8/16,-8/16,-3/16,8/16,8/16,3/16}}; minetest.register_node(modname..":panel_closed_ew"..unique_id, panel_cew_props)

        z_fun.autowalls.processed[name] = true
    end
    ::continue::
end

-- =============================================================================
-- DISPARADORES DE EVENTOS (CON LÓGICA DE DESTRUCCIÓN LIMPIA)
-- =============================================================================

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    -- Al colocar CUALQUIER bloque, actualizamos todo a su alrededor.
    z_fun.autowalls.update_at(pos)
    z_fun.autowalls.update_at({x=pos.x, y=pos.y, z=pos.z-1}); z_fun.autowalls.update_at({x=pos.x, y=pos.y, z=pos.z+1})
    z_fun.autowalls.update_at({x=pos.x-1, y=pos.y, z=pos.z}); z_fun.autowalls.update_at({x=pos.x+1, y=pos.y, z=pos.z})
    z_fun.autowalls.update_at({x=pos.x, y=pos.y-1, z=pos.z}); z_fun.autowalls.update_at({x=pos.x, y=pos.y+1, z=pos.z})
end)

minetest.register_on_dignode(function(pos, oldnode, digger)
    -- Al quitar CUALQUIER bloque, actualizamos todo a su alrededor.
    z_fun.autowalls.update_at({x=pos.x, y=pos.y, z=pos.z-1}); z_fun.autowalls.update_at({x=pos.x, y=pos.y, z=pos.z+1})
    z_fun.autowalls.update_at({x=pos.x-1, y=pos.y, z=pos.z}); z_fun.autowalls.update_at({x=pos.x+1, y=pos.y, z=pos.z})
    z_fun.autowalls.update_at({x=pos.x, y=pos.y-1, z=pos.z}); z_fun.autowalls.update_at({x=pos.x, y=pos.y+1, z=pos.z})
end)

print(string.format("[%s] [autowalls v7.1] Sistema de muros FINAL (con lista blanca) cargado.", modname))

