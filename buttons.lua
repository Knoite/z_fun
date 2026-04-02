-- =============================================================================
-- z_fun/buttons.lua - VERSIÓN FINAL: CIERRE DE SINTAXIS CORREGIDO
-- =============================================================================

local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)

-- 1. HERRAMIENTAS AUXILIARES
local function merge_tables(base, new)
    local merged = table.copy(base)
    for k, v in pairs(new) do
        merged[k] = v
    end
    return merged
end

-- 2. CONFIGURACIÓN DE MEDIDAS (Posición Horizontal Universal)
local length = 6/16
local width = 4/16
local height_normal = 2/16
local height_pressed = 1/16

local nodebox_normal = {type = "fixed", fixed = {-width/2, -0.5, -length/2, width/2, -0.5 + height_normal, length/2}}
local nodebox_pressed = {type = "fixed", fixed = {-width/2, -0.5, -length/2, width/2, -0.5 + height_pressed, length/2}}

-- 3. FUNCIÓN DE REGISTRO PROCEDURAL
local function register_zfun_button(data, extra_props)
    extra_props = extra_props or {}
    local subname = data.subname
    local material = data.material
    local basename = modname .. ":" .. subname .. "_button"
    local pressed_name = basename .. "_pressed"

    local node_def = minetest.registered_nodes[material]
    if not node_def then return end

    local common_props = {
        paramtype = "light",
        paramtype2 = "facedir",
        drawtype = "nodebox",
        sunlight_propagates = true,
        walkable = false,
        groups = {choppy = 2, oddly_breakable_by_hand = 2},
        sounds = node_def.sounds or default.node_sound_stone_defaults(),
        
        on_place = function(itemstack, placer, pointed_thing)
            if pointed_thing.type ~= "node" then return itemstack end
            local node_under = minetest.get_node(pointed_thing.under)
            local def_under = minetest.registered_nodes[node_under.name]
            if def_under and (node_under.name:find("fence") or node_under.name:find("wall")) then
                return itemstack
            end
            return minetest.rotate_node(itemstack, placer, pointed_thing)
        end,
    }

    -- Registro del Nodo Normal
    minetest.register_node(basename, merge_tables(common_props, {
        description = S(data.description .. " Button"),
        tiles = extra_props.tiles or node_def.tiles,
        node_box = nodebox_normal,
        selection_box = nodebox_normal,
        on_rightclick = extra_props.on_rightclick or function(pos, node, clicker)
            minetest.sound_play("z_fun_button_" .. subname, {pos = pos, gain = 0.5, max_hear_distance = 10})
            minetest.swap_node(pos, {name = pressed_name, param2 = node.param2})
            minetest.get_node_timer(pos):start(1.0)
        end,
    }))

    -- Registro del Nodo Presionado
    minetest.register_node(pressed_name, merge_tables(common_props, {
        tiles = extra_props.tiles or node_def.tiles,
        node_box = nodebox_pressed,
        selection_box = nodebox_pressed,
        groups = {not_in_creative_inventory = 1},
        drop = basename,
        on_timer = function(pos, elapsed)
            local node = minetest.get_node_or_nil(pos)
            if node and node.name == pressed_name then
                minetest.swap_node(pos, {name = basename, param2 = node.param2})
            end
            return false
        end,
    }))
end

-- 4. LISTA DE MATERIALES ESTÁNDAR
local BUTTON_MATERIALS = {
    { subname="stone",           material="default:stone",           description="Stone" },
    { subname="desert_stone",    material="default:desert_stone",    description="Desert Stone" },
    { subname="obsidian",        material="default:obsidian",        description="Obsidian" },
    { subname="pine_wood",       material="default:pine_wood",       description="Pine Wood" },
    { subname="aspen_wood",      material="default:aspen_wood",      description="Aspen Wood" },
    { subname="jungle_wood",     material="default:junglewood",      description="Jungle Wood" },
    { subname="acacia_wood",     material="default:acacia_wood",     description="Acacia Wood" },
    { subname="sandstone",       material="default:sandstone",       description="Sandstone" },
    { subname="desert_sandstone", material="default:desert_sandstone", description="Desert Sandstone" },
    { subname="silver_sandstone", material="default:silver_sandstone", description="Silver Sandstone" },
    { subname="ice",             material="default:ice",             description="Ice" },
}

-- 5. EJECUCIÓN DEL BUCLE DE REGISTRO
for _, data in ipairs(BUTTON_MATERIALS) do
    register_zfun_button(data)
    minetest.register_craft({
        output = modname .. ":" .. data.subname .. "_button",
        recipe = {{data.material, data.material}},
    })
end

-- 6. EL BOTÓN ROJO ESPECIAL (TEXTURA ICE + ROJO ALARMA)
register_zfun_button(
    { subname="red_special", material="default:obsidian", description="Red Special" },
    {
        tiles = {"default_ice.png^[brighten^[colorize:#ff0000:200"}, 
        on_rightclick = function(pos, node, clicker)
            local basename = modname .. ":red_special_button"
            local pressed_name = basename .. "_pressed"
            
            minetest.swap_node(pos, {name = pressed_name, param2 = node.param2})
            minetest.sound_play("default_button_troll", {pos = pos, gain = 0.8, max_hear_distance = 15})

            if clicker and clicker:is_player() then
                local name = clicker:get_player_name()
                minetest.chat_send_player(name, "¡Ups!")
                minetest.after(0.5, function()
                    if minetest.get_player_by_name(name) then
                        minetest.kick_player(name, "¡Expulsado por lagarto!")
                    end
                end)
            end
            minetest.get_node_timer(pos):start(1.0)
        end,
    }
)

minetest.register_craft({
    output = modname .. ":red_special_button",
    recipe = {{"default:obsidian", "default:torch", "default:obsidian"}},
})

print("[z_fun/buttons] MOD CARGADO: Rojo Brillante y Sintaxis blindada.")
