-- =============================================================================
-- z_fun/showcase.lua
-- Comportamiento mejorado del exhibidor
-- =============================================================================
local core_item = "default:mese_crystal"
if not minetest.registered_items[core_item] then
    core_item = "default:paper"
    print("[z_fun] ⚠️ mese_crystal no disponible. Usando papel.")
end

-- Entidad del item
minetest.register_entity("z_fun:showcase_display", {
    initial_properties = {
        visual = "wielditem",
        visual_size = {x = 0.35, y = 0.35},
        textures = {""},
        static_save = false,
        collide_with_objects = false,
        pointable = false,
    },
    on_activate = function(self, staticdata)
        if staticdata and staticdata ~= "" then
            self.object:set_properties({textures = {staticdata}})
        end
    end
})

-- Almacenar entidades
local showcase_entities = {}

-- Rotación global (eficiente)
minetest.register_globalstep(function(dtime)
    for pos_key, data in pairs(showcase_entities) do
        if data and data.obj and data.obj:get_pos() then
            data.rotation = (data.rotation + dtime * 90) % 360
            data.obj:set_rotation({x = 0, y = math.rad(data.rotation), z = 0})
        end
    end
end)

-- Función para actualizar la entidad visual
local function update_entity(pos, item_name)
    local key = minetest.pos_to_string(pos)
    
    -- Eliminar entidad existente
    if showcase_entities[key] then
        showcase_entities[key].obj:remove()
        showcase_entities[key] = nil
    end
    
    if item_name and item_name ~= "" then
        -- ✅ CORRECCIÓN 1: Posición EXACTA 0,0,0 relativa al nodo
        local item_pos = {x = pos.x, y = pos.y, z = pos.z}
        local ent = minetest.add_entity(item_pos, "z_fun:showcase_display", item_name)
        if ent then
            showcase_entities[key] = {
                obj = ent,
                rotation = 0
            }
        end
    end
end

-- Sistema de extracción con register_on_punchnode
minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
    if node.name ~= "z_fun:showcase" then return end
    
    local meta = minetest.get_meta(pos)
    local current = meta:get_string("item")
    local player_name = puncher:get_player_name()
    local wielded_item = puncher:get_wielded_item()
    local wielded_name = wielded_item:get_name()

    -- ✅ 4. Romper con pico (cualquier tipo)
    if string.find(wielded_name, "pick") or string.find(wielded_name, "pico") then
        -- Dejar que el sistema normal de minería maneje la destrucción
        return false
    end

    -- Verificar si el jugador está usando LMB (puncher no es nil)
    if current ~= "" then
        -- ✅ 3. LMB con item: extraer item
        -- 1. Eliminar entidad
        update_entity(pos, nil)
        
        -- 2. ✅ DEVOLVER ITEM AL INVENTARIO
        local inv = puncher:get_inventory()
        if inv then
            local leftover = inv:add_item("main", ItemStack(current))
            if not leftover:is_empty() then
                minetest.add_item(puncher:get_pos(), leftover)
            end
        else
            minetest.add_item(pos, ItemStack(current))
        end

        -- 3. Limpiar metadatos
        meta:set_string("item", "")
        meta:set_string("infotext", "Exhibidor (vacío)")

        minetest.sound_play("default_place_node_hard", {pos = pos, gain = 0.8, max_hear_distance = 10})
        return true
    else
        -- ✅ 3. LMB con cubo vacío: romper cubo
        -- Permitir la destrucción normal del nodo vacío
        return false
    end
end)

minetest.register_node("z_fun:showcase", {
    description = "Exhibidor de Items",
    -- ===================================================================
    -- MODIFICADO: Se cambia la textura de vidrio por la del marco.
    -- ===================================================================
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

    -- ✅ 1. RMB: Colocar items
    on_rightclick = function(pos, node, clicker, itemstack)
        if itemstack:is_empty() then return itemstack end
        
        local meta = minetest.get_meta(pos)
        local current = meta:get_string("item")
        
        if current ~= "" then
            -- Ya hay un item, no hacer nada
            return itemstack
        end
        
        -- Colocar nuevo item
        local new_item = itemstack:take_item(1)
        local item_name = new_item:get_name()
        
        meta:set_string("item", item_name)
        meta:set_string("infotext", "Exhibidor: " .. new_item:get_description())
        
        -- ✅ CORRECCIÓN 1: Actualizar entidad en posición exacta 0,0,0
        update_entity(pos, item_name)
        
        minetest.sound_play("default_place_node_hard", {pos = pos, gain = 0.8, max_hear_distance = 10})
        return itemstack
    end,

    -- ✅ CORRECCIÓN 2: Remover on_dig personalizado para permitir minería normal
    -- Al romper el cubo con pico (con o sin item)
    after_destruct = function(pos, oldnode)
        local meta = minetest.get_meta(pos)
        local item_str = meta:get_string("item")
        
        -- Eliminar entidad visual
        update_entity(pos, nil)
        
        -- ✅ CORRECCIÓN 2: Soltar el cubo manualmente (porque el drop no funciona como esperábamos)
        minetest.add_item({x = pos.x + 0.5, y = pos.y, z = pos.z + 0.5}, ItemStack("z_fun:showcase"))
        
        -- Si tenía item, soltarlo también
        if item_str ~= "" then
            minetest.add_item({x = pos.x + 0.5, y = pos.y, z = pos.z + 0.5}, ItemStack(item_str))
        end
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

print("[z_fun] Exhibidor: Posición 0,0,0 exacta y drop manual del cubo corregido.")
