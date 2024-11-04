Config = {}

Config.interactionDistance = 2 -- Distance to see drawtext and prompt for wagon

-- Command to remove the bucket from the player's hand
Config.removebucketcommand = "cbucket"

-- Define watercan items for empty, clean, and dirty states
Config.filledCan = "wateringcan"
Config.emptycan = "wateringcan_empty"

-- Define water wagons and how many buckets each can store
Config.waterwagons = {
    -- ["oilWagon01x"] = 60,
	-- ["oilWagon02x"] = 60,
	["cart05"] = 20
}

-- Key mappings for actions
Config.keys = {
    ["G"] = 0x760A9C6F,      -- Key for filling water
    ["ENTER"] = 0xC7B5340A   -- Key for taking water from wagon
}