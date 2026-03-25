z_fun = {}

-- Autor: Knoite
-- Licencia: Creative Commons Attribution 4.0 International (CC BY 4.0)
-- https://creativecommons.org/licenses/by/4.0/

local mod_path = minetest.get_modpath("z_fun")


dofile(mod_path .. "/decocrafter_plus.lua")
dofile(mod_path .. "/buttons.lua")
dofile(mod_path .. "/showcase.lua")
dofile(mod_path .. "/neowalls.lua")
-- dofile(mod_path .. "/autowalls.lua")   Fallo crítico al alejarse, cargar y volver, se rompe.-
print("[z_fun] Mod z_fun cargado correctamente.")
