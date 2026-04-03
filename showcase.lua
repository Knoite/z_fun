-- =============================================================================
-- z_fun/showcase.lua - VERSIÓN FINAL: COLORES INTERCAMBIABLES
-- =============================================================================

local core_item = "default:mese_crystal"
if not minetest.registered_items[core_item] then
    core_item = "default:paper"
end

-- 1. ENTIDAD DEL ITEM (VISUALIZACIÓN)
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

-- 2. ROTACIÓN GLOBAL
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

-- 3. FUNCIÓN DE ACTUALIZACIÓN DE ENTIDAD
local function update_entity(pos, item_name)
    local key = minetest.pos_to_string(pos)
    
    if showcase_entities[key] and showcase_entities[key].obj then
        showcase_entities[key].obj:remove()
    end
    showcase_entities[key] = nil
    
    local objects = minetest.get_objects_inside_radius(pos, 0.5)
    for _, obj in ipairs(objects) do
        local ent = obj:get_luaentity()
        if ent and ent.name == "z_fun:showcase_display" then
            obj:remove()
        end
    end
    
    if item_name and item_name ~= "" then
        minetest.after(0.05, function()
            local ent = minetest.add_entity(pos, "z_fun:showcase_display", item_name)
            if ent then
                local lua_ent = ent:get_luaentity()
                if lua_ent then lua_ent.item_name = item_name end
                showcase_entities[key] = { obj = ent, rotation = 0 }
            end
        end)
    end
end

-- 4. LBM Y EXTRACCIÓN (PUNCH)
minetest.register_lbm({
    label = "Restaurar items de exhibidores teñidos",
    name = "z_fun:restore_showcase_colored",
    nodenames = {"group:showcase"},
    run_at_every_load = true,
    action = function(pos, node)
        local meta = minetest.get_meta(pos)
        local item_name = meta:get_string("item")
        if item_name and item_name ~= "" then
            update_entity(pos, item_name)
        end
    end
})

minetest.register_on_punchnode(function(pos, node, puncher)
    if minetest.get_item_group(node.name, "showcase") == 0 then return end
    local meta = minetest.get_meta(pos)
    local current = meta:get_string("item")
    if current == "" then return end

    local wielded_name = puncher:get_wielded_item():get_name()
    if string.find(wielded_name, "pick") or string.find(wielded_name, "pico") then return false end

    meta:set_string("item", "")
    meta:set_string("infotext", "Exhibidor (vacío)")
    update_entity(pos, nil)
    
    local inv = puncher:get_inventory()
    if inv and inv:room_for_item("main", ItemStack(current)) then
        inv:add_item("main", ItemStack(current))
    else
        minetest.add_item(pos, ItemStack(current))
    end
    minetest.sound_play("default_place_node_hard", {pos = pos, gain = 0.8})
    return true
end)

-- 5. REGISTRO DINÁMICO Y COLORES
local colors = {
    {"black", "Negro"}, {"blue", "Azul"}, {"brown", "Marrón"}, {"cyan", "Cian"},
    {"dark_green", "Verde Oscuro"}, {"dark_grey", "Gris Oscuro"}, {"green", "Verde"},
    {"grey", "Gris"}, {"magenta", "Magenta"}, {"orange", "Naranja"}, {"pink", "Rosa"},
    {"red", "Rojo"}, {"violet", "Violeta"}, {"white", "Blanco"}, {"yellow", "Amarillo"}
}

local function register_showcase_node(suffix, color_hex, desc_suffix)
    local name = "z_fun:showcase" .. (suffix or "")
    local texture = "z_frame.png"
    if color_hex then
        texture = "z_frame.png^[multiply:" .. color_hex
    end

    minetest.register_node(name, {
        description = "Exhibidor de Items " .. (desc_suffix or ""),
        tiles = {texture},
        use_texture_alpha = "blend",
        drawtype = "glasslike",
        paramtype = "light",
        sunlight_propagates = true,
        -- Añadimos 'showcase = 1' para que todos pertenezcan al mismo grupo
        groups = {cracky = 3, oddly_breakable_by_hand = 2, showcase = 1},
        sounds = default.node_sound_glass_defaults(),

        on_construct = function(pos)
            local meta = minetest.get_meta(pos)
            meta:set_string("infotext", "Exhibidor (vacío)")
        end,

        on_rightclick = function(pos, node, clicker, itemstack)
            if itemstack:is_empty() then return itemstack end
            local meta = minetest.get_meta(pos)
            if meta:get_string("item") ~= "" then return itemstack end
            
            local new_item = itemstack:take_item(1)
            meta:set_string("item", new_item:get_name())
            meta:set_string("infotext", "Exhibidor: " .. new_item:get_description())
            update_entity(pos, new_item:get_name())
            minetest.sound_play("default_place_node_hard", {pos = pos, gain = 0.8})
            return itemstack
        end,

        after_destruct = function(pos, oldnode)
            update_entity(pos, nil)
        end,
    })
end

-- Registrar nodo base
register_showcase_node(nil, nil, "")

-- Registrar variantes y crafteos circulares
for _, data in ipairs(colors) do
    local c_name = data[1]
    local c_desc = data[2]
    
    register_showcase_node("_" .. c_name, c_name, "(" .. c_desc .. ")")
    
    -- CRAFTEO CLAVE: Usamos 'group:showcase' en lugar del nombre del nodo base.
    -- Esto permite que CUALQUIER exhibidor (incluso uno ya teñido) se pueda volver a teñir.
    minetest.register_craft({
        output = "z_fun:showcase_" .. c_name,
        type = "shapeless", -- Sin forma fija para que sea más cómodo
        recipe = {
            "group:showcase", 
            "dye:" .. c_name
        },
    })
end

-- Receta original
minetest.register_craft({
    output = "z_fun:showcase",
    recipe = {
        {"default:glass", "default:glass", "default:glass"},
        {"default:glass", core_item, "default:glass"},
        {"default:glass", "default:glass", "default:glass"}
    }
})
