-- =============================================================================
-- z_fun/buttons.lua
-- Sistema procedural y mejorado para generar botones.
-- =============================================================================

local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)

-- =============================================================================
-- FUNCIÓN AUXILIAR
-- =============================================================================
local function merge_tables(base, new)
    local merged = table.copy(base)
    for k, v in pairs(new) do
        merged[k] = v
    end
    return merged
end

-- =============================================================================
-- CONFIGURACIÓN CENTRAL
-- =============================================================================
local length = 6/16
local width = 4/16
local height_normal = 2/16
local height_pressed = 1/16

-- Nodebox para un botón horizontal (en el suelo)
local nodebox_normal = {type = "fixed", fixed = {-length/2, -0.5, -width/2, length/2, -0.5 + height_normal, width/2}}
local nodebox_pressed = {type = "fixed", fixed = {-length/2, -0.5, -width/2, length/2, -0.5 + height_pressed, width/2}}


-- =============================================================================
-- LISTA DE BOTONES A GENERAR
-- =============================================================================
-- SOLUCIÓN ERROR CONSOLA: Los nombres ya no se pre-traducen aquí.
local BUTTON_MATERIALS = {
    { subname="stone",          material="default:stone",          description="Stone" },
    { subname="desert_stone",   material="default:desert_stone",   description="Desert Stone" },
    { subname="obsidian",       material="default:obsidian",       description="Obsidian" },
    { subname="pine_wood",      material="default:pine_wood",      description="Pine Wood" },
    { subname="aspen_wood",     material="default:aspen_wood",     description="Aspen Wood" },
    { subname="jungle_wood",    material="default:junglewood",     description="Jungle Wood" },
    { subname="acacia_wood",    material="default:acacia_wood",    description="Acacia Wood" },
    { subname="sandstone",      material="default:sandstone",      description="Sandstone" },
    { subname="desert_sandstone", material="default:desert_sandstone", description="Desert Sandstone" },
    { subname="silver_sandstone", material="default:silver_sandstone", description="Silver Sandstone" },
    { subname="ice",            material="default:ice",            description="Ice" },
}

-- =============================================================================
-- FUNCIÓN DE REGISTRO PROCEDURAL (El Cerebro del Mod)
-- =============================================================================
local function register_zfun_button(data, extra_props)
    extra_props = extra_props or {}
    local subname = data.subname
    local material = data.material
    local description = data.description

    local basename = modname .. ":" .. subname .. "_button"
    local pressed_name = basename .. "_pressed"

    local node_def = minetest.registered_nodes[material]
    if not node_def then return end

    local tiles = extra_props.tiles or node_def.tiles
    local sounds = node_def.sounds or default.node_sound_stone_defaults()

    local common_props = {
        paramtype = "light",
        -- SOLUCIÓN ROTACIÓN: Usar "facedir" para FORZAR el botón al suelo y evitar que se levante.
        paramtype2 = "facedir",
        drawtype = "nodebox",
        selection_box = nodebox_normal, -- La caja de selección siempre es la normal.
        groups = {choppy = 2, oddly_breakable_by_hand = 2, attached_node = 1},
        sounds = sounds,
        on_place = minetest.rotate_node, -- Orienta el botón hacia el jugador al colocarlo.
        on_rotate = function(pos, itemstack, user, mode, new_param2)
            -- Esta función se asegura de que con CUALQUIER click del destornillador,
            -- el botón simplemente rote 90 grados en su sitio.
            local node = minetest.get_node(pos)
            node.param2 = (node.param2 + 1) % 4
            minetest.swap_node(pos, node)
            return itemstack
        end,
    }

    if extra_props.color then
        common_props.color = extra_props.color
    end

    -- 1. Registrar el botón normal (no presionado)
    minetest.register_node(basename, merge_tables(common_props, {
        -- SOLUCIÓN ERROR CONSOLA: Se traduce la descripción completa aquí.
        description = S(description .. " Button"),
        tiles = tiles,
        node_box = nodebox_normal,
        on_rightclick = extra_props.on_rightclick or function(pos, node, clicker)
            minetest.sound_play("z_fun_button_" .. subname, {pos = pos, gain = 0.5, max_hear_distance = 10})
            minetest.swap_node(pos, {name = pressed_name, param2 = node.param2})
            minetest.get_node_timer(pos):start(1.0)
        end,
    }))

    -- 2. Registrar el botón presionado (hundido y oculto)
    minetest.register_node(pressed_name, merge_tables(common_props, {
        tiles = tiles,
        node_box = nodebox_pressed,
        groups = {not_in_creative_inventory = 1, attached_node = 1},
        drop = basename,
        pointable = false,
        on_timer = function(pos, elapsed)
            local node = minetest.get_node_or_nil(pos)
            if node and node.name == pressed_name then
                minetest.swap_node(pos, {name = basename, param2 = node.param2})
            end
            return false
        end,
    }))
end

-- =============================================================================
-- EJECUCIÓN DEL REGISTRO
-- =============================================================================

print("[z_fun/buttons] Registrando " .. #BUTTON_MATERIALS .. " botones procedimentales...")

for _, data in ipairs(BUTTON_MATERIALS) do
    register_zfun_button(data)
    minetest.register_craft({
        output = modname .. ":" .. data.subname .. "_button",
        recipe = {{data.material, data.material}},
    })
end

-- --- Registro del BOTÓN ROJO ESPECIAL ---
register_zfun_button(
    { subname="red_special", material="default:obsidian", description="Red Special" },
    {
        tiles = {""},
        color = "red",
        on_rightclick = function(pos, node, clicker)
            local basename = modname .. ":red_special_button"
            local pressed_name = basename .. "_pressed"
            
            minetest.swap_node(pos, {name = pressed_name, param2 = node.param2})
            minetest.sound_play("default_button_troll", {pos = pos, gain = 0.8})

            if clicker and clicker:is_player() then
                local name = clicker:get_player_name()
                minetest.chat_send_player(name, "¡Ups! 😇")
                minetest.after(0.5, function()
                    if minetest.get_player_by_name(name) then
                        minetest.kick_player(name, "¡Expulsado por curioso! 😉")
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

print("[z_fun/buttons] Sistema de botones cargado con éxito.")
