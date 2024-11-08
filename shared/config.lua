return {
    debug = true, -- Enable or Disable debug mode
    standalone = false,  -- Set to true for standalone mode without inventory checks
    oxTarget = false, -- Set true to use ox_target. Set false to use prompts
    
    interactionDistance = 2, -- Distance to see drawtext and prompt for wagon

    notify = 'ox', -- Notification system | 'ox' , 'vorp' or custom.

    filledCan = 'wateringcan', -- Filled watercan item.
    emptyCan = 'wateringcan_empty', -- Empty watercan item.

    waterWagons = { -- Water wagon models and their maximum water levels.
        ["cart05"] = 3,
    },

    keys = {  -- Prompt keys. Didn't have a time to test prompts.  But eh...
        ["G"] = 0x760A9C6F,
        ["ENTER"] = 0xC7B5340A,
    }
}
