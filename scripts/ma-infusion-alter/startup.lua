local alter = peripheral.wrap("mysticalagriculture:infusion_altar_0")
local pedestals = {
	["mysticalagriculture:infusion_pedestal_1"] = peripheral.wrap("mysticalagriculture:infusion_pedestal_1"),
	["mysticalagriculture:infusion_pedestal_2"] = peripheral.wrap("mysticalagriculture:infusion_pedestal_2"),
	["mysticalagriculture:infusion_pedestal_3"] = peripheral.wrap("mysticalagriculture:infusion_pedestal_3"),
	["mysticalagriculture:infusion_pedestal_4"] = peripheral.wrap("mysticalagriculture:infusion_pedestal_4"),
	["mysticalagriculture:infusion_pedestal_5"] = peripheral.wrap("mysticalagriculture:infusion_pedestal_5"),
	["mysticalagriculture:infusion_pedestal_6"] = peripheral.wrap("mysticalagriculture:infusion_pedestal_6"),
	["mysticalagriculture:infusion_pedestal_7"] = peripheral.wrap("mysticalagriculture:infusion_pedestal_7"),
	["mysticalagriculture:infusion_pedestal_8"] = peripheral.wrap("mysticalagriculture:infusion_pedestal_8")
}

local inputChest = peripheral.wrap("chest_0")
local outputChest = peripheral.wrap("chest_1")

--- @class InfusionRecipe
--- @field alter string The item to be placed in the infusion alter
--- @field pedestals table<string, string> A mapping of pedestal names to the items they should hold

local recipes = {
	["mysticalagriculture:diamond_seeds"] = {
		alter = "mysticalagriculture:prosperity_seed_base",
		pedestals = {
			"mysticalagriculture:supremium_essence",
			"minecraft:diamond",
			"mysticalagriculture:supremium_essence",
			"minecraft:diamond",
			"mysticalagriculture:supremium_essence",
			"minecraft:diamond",
			"mysticalagriculture:supremium_essence",
			"minecraft:diamond",
		}
	}
}

local function findInventoryItemIndex(chest, itemName)
	local items = chest.list()
	for slot, item in pairs(items) do
		if item.name == itemName then
			return slot
		end
	end
	return nil
end

local function craft(recipe)
	local itemSlot = findInventoryItemIndex(inputChest, recipe.alter)

	alter.pullItems(peripheral.getName(inputChest), itemSlot)
end

craft(recipes["mysticalagriculture:diamond_seeds"])
