Config = Config or {}

Config.Locale = "en"  -- change to "fr" or "de" as needed
-- Race start delay in seconds (time before race begins after countdown)
-- Default is 3 for testing, but most players prefer 10 seconds or less
Config.RaceStartDelay = 3
-- How often clients report progress to the server (ms). Lower = more responsive positions.
-- Keep between 75 and 200 to balance responsiveness vs. server load.
Config.ProgressTickMs = 150
-- Use front bumper corners (left/right) in addition to center and take the max
-- along-track distance. Helps tiny nose differences decide position on curves.
Config.DistanceUseNoseCorners = true

-- Debug toggles
Config.DebugPrints = false      -- Console [DEBUG] logs (ranking/progress/etc)
Config.ZoneDebug   = false      -- Polyzone/lib.zones visualization (red spheres)

-- If your in-race positions appear reversed (the car behind shows 1/2),
-- set this to true to invert the displayed rank without changing core sorting.
Config.RankingInvert = false

--- Choose your notification provider: "ox_lib", "okokNotify" or "rtx_notify"
Config.NotificationProvider = "okokNotify"

--- Optional if you have Raceway Leaderboard Display by Glitchdetector
Config.Leaderboard = {
    enabled = true,
    -- How often to push updates to AMIR (ms). Too frequent causes flicker.
    updateIntervalMs = 1000,
    -- How often to flip between Names and Times on the board (ms)
    toggleIntervalMs = 2000,
    -- Display mode for AMIR board rows:
    --  - "toggle": alternate Names and Times every toggleIntervalMs
    --  - "names":  always show player names
    viewMode = "toggle",
    -- What time to show on the AMIR toggle (names/times):
    --  - "total": total race time so far per racer (default)
    --  - "lap": current lap time per racer
    timeMode = "total",
}

--- Optional per-segment path hints to better approximate curved track sections
--- Use this to break long chords (e.g., hairpins) into smaller subsegments so
--- distance/ranking stays accurate before reaching the next checkpoint.
--- Indexing:
---   0 = Start/Finish -> CP1
---   i = CPi -> CP(i+1)
---   n = CPn -> Start/Finish
Config.SegmentHints = {
    Short_Track = {
        -- Hairpin into CP1: three hint points to match the actual path
        [0] = {
            vector3(-2481.06, 8167.71, 40.65),
            vector3(-2462.81, 8236.75, 42.85),
            vector3(-2525.66, 8231.02, 38.05),
        },
        -- CP1 -> CP2: short straight, medium right sweeper, then sharp left into CP2
        [1] = {
            -- start of right curve (after a short straight from CP1)
            vector3(-2610.58, 8156.54, 40.77),
            -- center/apex of long right curve
            vector3(-2668.76, 8150.48, 40.85),
            -- end of right curve
            vector3(-2691.44, 8199.16, 40.85),
            -- straight stretch before the sharp left into CP2
            vector3(-2697.72, 8314.08, 40.87),
        },
        -- CP2 to CP3 not needed (straight line of sight)
        -- CP3 -> Finish: long 180° left-hander flowing to the start/finish straight
        [2] = {
            -- start of left-hand curve just after CP3
            vector3(-3115.57, 8307.25, 36.48),
            -- halfway through the curve (apex)
            vector3(-3208.71, 8210.23, 44.61),
            -- end of curve leading onto the straight to the finish line
            vector3(-3133.31, 8121.73, 45.53),
        },
    },
    Drift_Track = {},
    Speed_Track = {},
    Long_Track  = {},
}

--- START / FINISH LINE POLYGON (used for ROSZ detection if you ever need it)
Config.StartLinePoints = {
  vector3(-2762.315, 8079.99, 42.87),
}

--- TRACK CHECKPOINTS (must drive through these in order)
Config.Checkpoints = {
    Short_Track = {
        vector3(-2519.90, 8237.24, 38.46),
        vector3(-2719.17, 8335.82, 40.43),
        vector3(-3102.41, 8305.79, 35.85),
    },
    Drift_Track = {
        vector3(-2519.90, 8237.24, 38.46),
        vector3(-2802.37, 8546.86, 43.96),
        vector3(-2950.20, 8405.94, 36.45),
    },
    Speed_Track = {
        vector3(-2519.90, 8237.24, 38.46),
        vector3(350.0, 250.0, 102.0),
        vector3(400.0, 300.0, 102.0),
    },
    Long_Track = {
        vector3(-2519.90, 8237.24, 38.46),
        vector3(150.0, 150.0, 102.0),
        vector3(200.0, 200.0, 102.0),
        vector3(250.0, 250.0, 102.0),
    },
}

Config.PitCrewZones = {
    -- Zone #1 (replace coords with your pit‐lane location)
    {  
      coords = vector3(-2865.45, 8113.30, 43.74),   
      heading = 180.0,    -- NPCs will face south
      radius = 6.0  
    },
  
    -- Zone #2
    {  
      coords = vector3(-2840.76, 8109.64, 43.55),   
      heading = 180.0,    -- NPCs will face south
      radius = 6.0  
    },

    -- Server owners can add more:  
    -- Example zone #3 (replace coords with your pit‐lane location)
    -- {  
      -- coords = vector3(x, y, z),   
      -- heading = 180.0,    -- NPCs will face south
      -- radius = 6.0  
    -- },
}

-- Pit-crew settings
Config.PitCrewModel       = 'ig_mechanic_01'  -- ped model for all pit crew
Config.PitCrewIdleOffsets = {
    vector3(-2.0,  0.0,  0.0),  -- two idle spots (left/right)
    vector3( 2.0,  0.0,  0.0),
}
Config.PitCrewCrewOffsets = {
    vector3( 0.0, -2.0,  0.0),  -- refuel spot (rear)
    vector3( 0.0,  2.0,  0.0),  -- hood spot (front)
    vector3( 2.0,  0.0,  0.0),  -- jack spot (side)
}


--- OUT COORDS (where to send you when you finish)
Config.outCoords = vector4(-2896.1172, 8077.2363, 44.4940, 183.6707)

--- LOBBY PED
Config.LobbyPed = {
    model  = 's_m_y_valet_01',
    coords = vector4(-2901.4832, 8076.8525, 44.4985, 246.1840),
}

--- TRACK PROPS / BARRIERS
Config.TrackProps = {
    ["Short_Track"] = {
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0l1',
            cords = {
                vector4(-2705.38, 8340.52, 41.36, 338.00),
                vector4(-2700.06, 8335.04, 41.48, 338.00),
                vector4(-2694.68, 8328.46, 41.47, 338.00),
                vector4(-2689.42, 8323.68, 41.47, 338.00),
                vector4(-2683.45, 8320.36, 41.47, 338.00),
                vector4(-2679.92, 8315.29, 41.47, 338.00),
                vector4(-2674.74, 8310.80, 41.47, 338.00),
                vector4(-2905.52, 8346.46, 36.11,  81.12),
            }
        }
    },
    ["Drift_Track"] = {
        -- first barrier set (left side)
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0r1',
            cords = {
                vector4(-2723.00, 8316.50, 40.83,  45),
                vector4(-2719.01, 8320.02, 40.83,  45),
                vector4(-2714.72, 8323.96, 40.84,  45),
                vector4(-2711.34, 8327.73, 40.81,  45),
                vector4(-2707.65, 8330.18, 40.85,  45),
                vector4(-2705.53, 8332.99, 41.49,  45),
                vector4(-2702.49, 8336.08, 40.84,  45),
            }
        },
        -- second barrier set (right side)
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0l1',
            cords = {
                vector4(-2666.57, 8443.34, 40.95, 310),
                vector4(-2663.85, 8440.70, 40.91, 310),
                vector4(-2662.02, 8438.67, 40.93, 310),
                vector4(-2660.13, 8436.43, 40.93, 310),
                vector4(-2658.33, 8434.17, 40.95, 310),
                vector4(-2656.33, 8431.84, 40.96, 310),
                vector4(-2654.59, 8429.54, 40.95, 308),
                vector4(-2652.68, 8427.03, 40.94, 305),
                vector4(-2650.67, 8424.33, 40.94, 303),
                vector4(-2649.04, 8421.65, 40.92, 300),
                vector4(-2647.47, 8419.16, 40.91, 298),
                vector4(-2646.40, 8416.86, 40.90, 299),
            }
        },
        -- third barrier set (right side)
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0l1',
            cords = {
                vector4(-2896.81, 8681.33, 33.38, 317),
                vector4(-2894.57, 8679.58, 33.14, 318),
                vector4(-2892.14, 8677.52, 32.87, 316),
                vector4(-2889.84, 8675.16, 32.61, 319),
                vector4(-2887.58, 8673.02, 32.37, 315),
                vector4(-2885.14, 8670.61, 32.15, 311),
                vector4(-2883.17, 8668.10, 31.97, 307),
                vector4(-2881.19, 8665.45, 31.81, 309),
                vector4(-2879.21, 8662.79, 31.65, 303),
                vector4(-2877.65, 8660.39, 31.52, 300),
                vector4(-2875.98, 8657.30, 31.38, 295),
                vector4(-2874.64, 8654.42, 31.29, 292),
                vector4(-2873.57, 8651.52, 31.31, 287),
                vector4(-2872.55, 8648.54, 31.37, 284),
                vector4(-2871.91, 8645.62, 31.46, 281),
                vector4(-2871.27, 8642.35, 31.60, 277),
                vector4(-2870.78, 8639.22, 31.88, 277),
                vector4(-2870.23, 8636.04, 32.30, 274),
                vector4(-2869.95, 8633.11, 32.72, 273),
                vector4(-2869.88, 8630.21, 33.13, 273),
            }
        },
        -- fourth barrier set (right side)
        {
            prop  = 'sum_prop_ac_tyre_wall_lit_0r1',
            cords = {
                vector4(-2878.40, 8363.62, 36.45, 270),
                vector4(-2878.41, 8360.70, 36.44, 268),
                vector4(-2878.48, 8357.19, 36.44, 266),
                vector4(-2878.68, 8353.91, 36.44, 264),
                vector4(-2878.95, 8350.83, 36.44, 263),
                vector4(-2879.32, 8347.71, 36.43, 261),
                vector4(-2879.78, 8344.50, 36.44, 259),
                vector4(-2880.28, 8341.33, 36.44, 258),
                vector4(-2881.02, 8338.01, 36.44, 254),
                vector4(-2881.92, 8334.65, 36.44, 253),
                vector4(-2882.65, 8331.82, 36.44, 252),
            }
        },
    },
    ["Speed_Track"] = {},
    ["Long_Track"]  = {},
}

--- VEHICLE OPTIONS
Config.RaceVehicles = {
    { label = "Sultan RS",       model = "sultanrs"    },
    { label = "Elegy RH8",       model = "elegy"      },
    { label = "Buffalo",         model = "buffalo"    },
    { label = "Kuruma",          model = "kuruma"     },
    { label = "2023WRCI20",      model = "2023WRCI20" },
    { label = "WRC2006",         model = "WRC2006"    },
    { label = "YarisWRC",        model = "YarisWRC"   },
}

--- GRID SPAWN POINTS
Config.GridSpawnPoints = {
    vector4(-2762.9260, 8076.5244, 42.6784, 264.5850),
    vector4(-2764.9563, 8079.9731, 42.6893, 266.6010),
    vector4(-2767.7869, 8083.4434, 42.7054, 266.2213),
}

--- ADJUSTABLE FINISH‐LINE SPHERE (separate from checkpoints)
Config.FinishLine = {
    coords = Config.StartLinePoints[1],  -- uses the first point of your StartLinePoints
    radius = 15.0,
}

return Config
