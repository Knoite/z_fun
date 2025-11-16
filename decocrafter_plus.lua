-- Deco Crafter Plus para Z-Fun Mod
-- Compatibilidad para escaleras, losas, esquinas y muros

local S = minetest.get_translator("z_fun")

-- Función auxiliar para no repetir código
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

    -- =============================================================================
    -- NUEVO: Se añade dureza y vulnerabilidad a las hachas para las maderas
    -- =============================================================================
    if string.find(node_suffix, "^wood") then
        groups.choppy = 2.5 -- Dureza estándar para madera trabajada, vulnerable a hachas.
        groups.flammable = 2 -- La madera es inflamable.
    end

    -- 1. MUROS (sin cambios)
    if is_brick_or_stone then
        local wall_name = "z_fun:decocrafter_" .. node_suffix .. "_wall"
        local pretty_name = "Decocrafter " .. string.gsub(node_suffix, "(%a)([%w_']*)", function(first, rest) return string.upper(first) .. rest end)
        local wall_desc = S(pretty_name .. " Wall")
        local wall_groups = table.copy(groups); wall_groups.wall = 1
        minetest.register_node(wall_name, { description = wall_desc, drawtype = "nodebox", paramtype = "light", is_ground_content = false, sunlight_propagates = true, tiles = tiles, groups = wall_groups, sounds = sounds, connect_sides = {"left", "right", "front", "back"}, node_box = { type = "connected", fixed = {{-1/4, -1/2, -1/4, 1/4, 1/2, 1/4}}, connect_front = {{-3/16, -1/2, -1/2, 3/16, 3/8, -1/4}}, connect_left = {{-1/2, -1/2, -3/16, -1/4, 3/8, 3/16}}, connect_back = {{-3/16, -1/2, 1/4, 3/16, 3/8, 1/2}}, connect_right = {{1/4, -1/2, -3/16, 1/2, 3/8, 3/16}}, }, selection_box = { type = "connected", fixed = {{-1/4, -1/2, -1/4, 1/4, 1/2, 1/4}}, connect_front = {{-3/16, -1/2, -1/2, 3/16, 3/8, -1/4}}, connect_left = {{-1/2, -1/2, -3/16, -1/4, 3/8, 3/16}}, connect_back = {{-3/16, -1/2, 1/4, 3/16, 3/8, 1/2}}, connect_right = {{1/4, -1/2, -3/16, 1/2, 3/8, 3/16}}, }, })
        minetest.register_craft({ output = wall_name .. " 6", recipe = { {material_node, material_node, material_node}, {material_node, material_node, material_node}, {"", "", ""}, } })
    end

    -- 2. ESCALERAS (sin cambios en la definición, pero ahora hereda los nuevos grupos)
    local stair_name = "z_fun:decocrafter_" .. node_suffix .. "_stair"
    local pretty_name = "Decocrafter " .. string.gsub(node_suffix, "(%a)([%w_']*)", function(first, rest) return string.upper(first) .. rest end)
    local stair_desc = S(pretty_name .. " Stair")
    minetest.register_node(stair_name, { description = stair_desc, drawtype = "nodebox", paramtype = "light", paramtype2 = "facedir", is_ground_content = false, tiles = tiles, groups = groups, sounds = sounds, node_box = { type = "fixed", fixed = { {-0.5, -0.5, -0.5, 0.5, 0, 0.5}, {-0.5, 0, 0, 0.5, 0.5, 0.5} } }, })
    minetest.register_craft({ output = stair_name .. " 8", recipe = { {material_node, "", ""}, {material_node, material_node, ""}, {material_node, material_node, material_node} } })

    -- 3. LOSAS (sin cambios en la definición, pero ahora hereda los nuevos grupos)
    local slab_name = "z_fun:decocrafter_" .. node_suffix .. "_slab"
    local slab_desc = S(pretty_name .. " Slab")
    minetest.register_node(slab_name, { description = slab_desc, drawtype = "nodebox", paramtype = "light", paramtype2 = "facedir", is_ground_content = false, tiles = tiles, groups = groups, sounds = sounds, node_box = { type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5} }, selection_box = { type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5} }, on_place = minetest.rotate_node, on_rotate = function(pos, itemstack, user, mode, new_param2) if mode == screwdriver.ROTATE_FACE then local node = minetest.get_node(pos) node.param2 = (node.param2 + 1) % 4 minetest.swap_node(pos, node) return itemstack end return itemstack end, })
    minetest.register_craft({ output = slab_name .. " 6", recipe = { {material_node, material_node, material_node} } })

    -- 4. ESQUINAS EXTERIORES (CORREGIDO: drop)
    local outer_name = "z_fun:decocrafter_" .. node_suffix .. "_outer"
    local outer_desc = S(pretty_name .. " Outer Corner")
    local outer_groups = table.copy(groups); outer_groups.not_in_creative_inventory = 1
    minetest.register_node(outer_name, { description = outer_desc, drawtype = "nodebox", paramtype = "light", paramtype2 = "facedir", is_ground_content = false, tiles = tiles, groups = outer_groups, sounds = sounds, node_box = { type = "fixed", fixed = { {-0.5, -0.5, -0.5, 0.5, 0, 0.5}, {0, 0, -0.5, 0.5, 0.5, 0} } },
        -- La línea 'drop' ha sido eliminada para que se dropee a sí mismo.
    })
    minetest.register_craft({ output = outer_name .. " 8", recipe = { {"", "", ""}, {"", material_node, ""}, {material_node, material_node, material_node} } })

    -- 5. ESQUINAS INTERIORES (CORREGIDO: drop)
    local inner_name = "z_fun:decocrafter_" .. node_suffix .. "_inner"
    local inner_desc = S(pretty_name .. " Inner Corner")
    local inner_groups = table.copy(groups); inner_groups.not_in_creative_inventory = 1
    minetest.register_node(inner_name, { description = inner_desc, drawtype = "nodebox", paramtype = "light", paramtype2 = "facedir", is_ground_content = false, tiles = tiles, groups = inner_groups, sounds = sounds, node_box = { type = "fixed", fixed = { {-0.5, -0.5, -0.5, 0.5, 0, 0.5}, {-0.5, 0, -0.5, 0, 0.5, 0}, {-0.5, 0, 0, 0, 0.5, 0.5}, {0, 0, -0.5, 0.5, 0.5, 0} } },
        -- La línea 'drop' ha sido eliminada para que se dropee a sí mismo.
    })
    minetest.register_craft({ output = inner_name .. " 8", recipe = { {"", material_node, ""}, {material_node, "", material_node}, {material_node, material_node, material_node} } })

    minetest.log("action", "[Z-Fun] Soporte para " .. material_node .. " añadido.")
end

-- --- Llamadas manuales para cada bloque ---
-- (Sin cambios aquí)
register_decocrafter_variants("decocrafter:brick1", "brick1")
register_decocrafter_variants("decocrafter:brick2", "brick2")
register_decocrafter_variants("decocrafter:brick3", "brick3")
register_decocrafter_variants("decocrafter:brick4", "brick4")
register_decocrafter_variants("decocrafter:brick5", "brick5")
register_decocrafter_variants("decocrafter:brick6", "brick6")
register_decocrafter_variants("decocrafter:brick7", "brick7")
register_decocrafter_variants("decocrafter:brick8", "brick8")
register_decocrafter_variants("decocrafter:brick9", "brick9")
register_decocrafter_variants("decocrafter:brick10", "brick10")
register_decocrafter_variants("decocrafter:brick11", "brick11")
register_decocrafter_variants("decocrafter:brick12", "brick12")
register_decocrafter_variants("decocrafter:brick13", "brick13")
register_decocrafter_variants("decocrafter:brick14", "brick14")
register_decocrafter_variants("decocrafter:brick15", "brick15")
register_decocrafter_variants("decocrafter:stone1", "stone1")
register_decocrafter_variants("decocrafter:stone2", "stone2")
register_decocrafter_variants("decocrafter:stone3", "stone3")
register_decocrafter_variants("decocrafter:stone4", "stone4")
register_decocrafter_variants("decocrafter:stone5", "stone5")
register_decocrafter_variants("decocrafter:stone6", "stone6")
register_decocrafter_variants("decocrafter:stone7", "stone7")
register_decocrafter_variants("decocrafter:stone8", "stone8")
register_decocrafter_variants("decocrafter:stone9", "stone9")
register_decocrafter_variants("decocrafter:stone10", "stone10")
register_decocrafter_variants("decocrafter:stone11", "stone11")
register_decocrafter_variants("decocrafter:stone12", "stone12")
register_decocrafter_variants("decocrafter:tile1", "tile1")
register_decocrafter_variants("decocrafter:tile2", "tile2")
register_decocrafter_variants("decocrafter:tile3", "tile3")
register_decocrafter_variants("decocrafter:tile4", "tile4")
register_decocrafter_variants("decocrafter:tile5", "tile5")

-- =============================================================================
-- NUEVO: LISTA BLANCA Y BUCLE PARA MADERAS
-- =============================================================================
local WOODS_TO_REGISTER = { "wood1", "wood2", "wood3", "wood4", "wood5", "wood6", "wood7", "wood8", "wood9" }
for _, suffix in ipairs(WOODS_TO_REGISTER) do
    register_decocrafter_variants("decocrafter:" .. suffix, suffix)
end
