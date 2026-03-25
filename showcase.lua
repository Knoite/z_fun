-- =============================================================================
-- z_fun/showcase.lua - VERSIÓN CORREGIDA (Sin Duplicación)
-- =============================================================================

local core_item = "default:mese_crystal"
if not minetest.registered_items[core_item] then
    core_item = "default:paper"
    print("[z_fun] ⚠️ mese_crystal no disponible. Usando papel.")
end

-- Entidad del item (Mantenemos tu lógica de visual_size y staticdata)
minetest.register_entity("z_fun:showcase_display", {
    initial_properties = {
        visual = "wielditem",
        visual_size = {x = 0.35, y = 0.35},
        textures = {""},
        static_save = true,
        collide_with_objects = false,
        pointable = false,
    },
    on_activate = function(self, staticdata)
        if staticdata and staticdata ~= "" then
            self.object:set_properties({textures = {staticdata}})
            self.item_name = staticdata
        end
    end,
    get_staticdata = function(self)
        return self.item_name or ""
    end
})

local showcase_entities = {}

-- Rotación global (Tu sistema original)
minetest.register_globalstep(function(dtime)
    for pos_key, data in pairs(showcase_entities) do
        if data and data.obj and data.obj:get_pos() then
            data.rotation = (data.rotation + dtime * 90) % 360
            data.obj:set_rotation({x = 0, y = math.rad(data.rotation), z = 0})
        else
            showcase_entities[pos_key] = nil
        end
    end
end)

-- Función de actualización (Mantenemos tu lógica de centrado)
local function update_entity(pos, item_name)
    local key = minetest.pos_to_string(pos)
    
    if showcase_entities[key] then
        if showcase_entities[key].obj then
            showcase_entities[key].obj:remove()
        end
        showcase_entities[key] = nil
    end
    
    local objects = minetest.get_objects_inside_radius(pos, 0.5)
    for _, obj in ipairs(objects) do
        local ent = obj:get_luaentity()
        if ent and ent.name == "z_fun:showcase_display" then
            obj:remove()
        end
    end
    
    if item_name and item_name ~= "" then
        minetest.after(0.05, function()
            local item_pos = {x = pos.x, y = pos.y, z = pos.z}
            local ent = minetest.add_entity(item_pos, "z_fun:showcase_display", item_name)
            if ent then
                local lua_ent = ent:get_luaentity()
                if lua_ent then
                    lua_ent.item_name = item_name
                end
                showcase_entities[key] = {
                    obj = ent,
                    rotation = 0
                }
            end
        end)
    end
end

-- LBM (Persistencia)
minetest.register_lbm({
    label = "Restaurar items de exhibidores",
    name = "z_fun:restore_showcase_items",
    nodenames = {"z_fun:showcase"},
    run_at_every_load = true,
    action = function(pos, node)
        local meta = minetest.get_meta(pos)
        local item_name = meta:get_string("item")
        local objects = minetest.get_objects_inside_radius(pos, 0.5)
        for _, obj in ipairs(objects) do
            local ent = obj:get_luaentity()
            if ent and ent.name == "z_fun:showcase_display" then
                obj:remove()
            end
        end
        if item_name and item_name ~= "" then
            minetest.after(0.1, function()
                update_entity(pos, item_name)
            end)
        end
    end
})

-- On Punch (Extracción manual)
minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
    if node.name ~= "z_fun:showcase" then return end
    local meta = minetest.get_meta(pos)
    local current = meta:get_string("item")
    local wielded_name = puncher:get_wielded_item():get_name()

    if string.find(wielded_name, "pick") or string.find(wielded_name, "pico") then
        return false
    end

    if current ~= "" then
        meta:set_string("item", "")
        meta:set_string("infotext", "Exhibidor (vacío)")
        update_entity(pos, nil)
        local inv = puncher:get_inventory()
        if inv then
            local leftover = inv:add_item("main", ItemStack(current))
            if not leftover:is_empty() then
                minetest.add_item(puncher:get_pos(), leftover)
            end
        else
            minetest.add_item(pos, ItemStack(current))
        end
        minetest.sound_play("default_place_node_hard", {pos = pos, gain = 0.8, max_hear_distance = 10})
        return true
    end
end)

-- DEFINICIÓN DEL NODO
minetest.register_node("z_fun:showcase", {
    description = "Exhibidor de Items",
    tiles = {"z_frame.png"},
    use_texture_alpha = "blend",
    drawtype = "glasslike",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = true,
    pointable = true,
    buildable_to = false,
    groups = {cracky = 3, oddly_breakable_by_hand = 2},
    sounds = default.node_sound_glass_defaults(),

    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string("item", "")
        meta:set_string("infotext", "Exhibidor (vacío)")
    end,

    on_rightclick = function(pos, node, clicker, itemstack)
        if itemstack:is_empty() then return itemstack end
        local meta = minetest.get_meta(pos)
        if meta:get_string("item") ~= "" then return itemstack end
        
        local new_item = itemstack:take_item(1)
        local item_name = new_item:get_name()
        meta:set_string("item", item_name)
        meta:set_string("infotext", "Exhibidor: " .. new_item:get_description())
        update_entity(pos, item_name)
        minetest.sound_play("default_place_node_hard", {pos = pos, gain = 0.8, max_hear_distance = 10})
        return itemstack
    end,

    -- ✅ FIX CRÍTICO: Eliminamos el drop manual del bloque para evitar duplicación.
    -- Luanti ya suelta el bloque z_fun:showcase automáticamente por los 'groups'.
    after_destruct = function(pos, oldnode)
        local key = minetest.pos_to_string(pos)
        
        -- Limpiar entidad del registro
        if showcase_entities[key] then
            if showcase_entities[key].obj then
                showcase_entities[key].obj:remove()
            end
            showcase_entities[key] = nil
        end
        
        -- Limpiar entidades visuales residuales
        local objects = minetest.get_objects_inside_radius(pos, 0.5)
        for _, obj in ipairs(objects) do
            local ent = obj:get_luaentity()
            if ent and ent.name == "z_fun:showcase_display" then
                obj:remove()
            end
        end
        
        -- ✅ Nota: NO agregamos minetest.add_item del bloque.
        -- Dejamos que el motor lo haga solo.
    end,
})

-- Crafting
minetest.register_craft({
    output = "z_fun:showcase",
    recipe = {
        {"default:glass", "default:glass", "default:glass"},
        {"default:glass", core_item, "default:glass"},
        {"default:glass", "default:glass", "default:glass"}
    }
})

print("[z_fun] Exhibidor: Sistema corregido (Anti-Dupe).")
