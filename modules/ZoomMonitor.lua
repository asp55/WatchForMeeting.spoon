

local ZoomMonitor={}
ZoomMonitor.name = 'WatchForMeeting.ZoomMonitor'
ZoomMonitor.appName = "zoom"

ZoomMonitor.logger = hs.logger.new(ZoomMonitor.name)

local running = false

-------------------------------------------
-- BEGIN EVENT HANDLER
-------------------------------------------


-- Events
--- ZoomMonitor.events.meetingChange
--- Constant
--- Pseudo-event for `ZoomMonitor:subscribe()`: The meeting state has changed
local EventHandler = dofile(hs.spoons.resourcePath("EventHandler.lua"))({"meetingChange"}, ZoomMonitor.name)


--- ZoomMonitor:subscribe(event, fn) -> ZoomMonitor
--- Method
--- Subscribe to one event with one or more functions
---
--- Parameters:
---  * event - string of the event to subscribe to
---  * fn - function or list of functions, the callback(s) to add for the event(s); 
---
--- Returns:
---  * The `ZoomMonitor` object for method chaining

function ZoomMonitor:subscribe(event, fns)
    ZoomMonitor.logger.d("ZoomMonitor:subscribe("..event..")")
    EventHandler:subscribe(event, fns)
    return self
end

--- ZoomMonitor:unsubscribe(event, fn) -> ZoomMonitor
--- Method
--- Removes one or more event subscriptions
---
--- Parameters:
---  * event - string of the event to unsubscribe;
---  * fn - function or list of functions, the callback(s) to remove
---
--- Returns:
---  * The `ZoomMonitor` object for method chaining
---
function ZoomMonitor:unsubscribe(event,fn)
    ZoomMonitor.logger.d("ZoomMonitor:unsubscribe("..event..")")
    EventHandler:unsubscribe(event, fn)
    return self
end

--- ZoomMonitor:unsubscribeEvent(event) -> ZoomMonitor
--- Method
--- Removes all subscriptions from one event
---
--- Parameters:
---  * event - string of the event to unsubscribe
---
--- Returns:
---  * The `ZoomMonitor` object for method chaining
---
function ZoomMonitor:unsubscribeEvent(event)
    ZoomMonitor.logger.d("ZoomMonitor:unsubscribeEvent("..event..")")
    EventHandler:unsubscribeEvent(event)
    return self
 end


--- ZoomMonitor:unsubscribeAll() -> ZoomMonitor
--- Method
--- Removes all subscriptions from one event
---
--- Returns:
---  * The `ZoomMonitor` object for method chaining
---
function ZoomMonitor:unsubscribeAll()
    ZoomMonitor.logger.d("ZoomMonitor:unsubscribeAll()")
    EventHandler:unsubscribeAll()
    return self
 end


-------------------------------------------
-- END EVENT HANDLER
-------------------------------------------


-------------------------------------------
-- Zoom Monitor
-------------------------------------------


--- ZoomMonitor.zoom
--- Variable
--- (Read-only) The hs.application for zoom if it is running, otherwise nil
local zoom = nil

--- ZoomMonitor.meetingState
--- Variable
--- (Read-only) Either false (when not in a meeting) or a table (when in a meeting)
---@type boolean | table
local meetingState = false


local function currentlyInMeeting()
   --If zoom is running and the second menu in zoom's menu bar is "Meeting" then we're in a meeting
   local inMeetingState = (zoom ~= nil and zoom:getMenuItems()[2].AXTitle == "Meeting")
   return inMeetingState
end

--declare startStopWatchMeeting before watchMeeting, define it after.
local startStopWatchMeeting = function() end

local checkMeetingStatus = hs.timer.new(0.5, function()
    if(currentlyInMeeting() == false) then
      -- No longer in a meeting, stop watching the meeting
      startStopWatchMeeting()
      return
    elseif(zoom) then
      --Watch for zoom menu items
      local _mic_open = zoom:findMenuItem({"Meeting", "Unmute audio"})==nil
      local _video_on = zoom:findMenuItem({"Meeting", "Start video"})==nil
      local _sharing = zoom:findMenuItem({"Meeting", "Start share"})==nil
      if(not meetingState or (meetingState.mic_open ~= _mic_open) or (meetingState.video_on ~= _video_on) or (meetingState.sharing ~= _sharing)) then
        meetingState = {mic_open = _mic_open, video_on = _video_on, sharing = _sharing}
        ZoomMonitor.logger.d("In Meeting: ", (meetingState and true)," Open Mic: ",meetingState.mic_open," Video-ing:",meetingState.video_on," Sharing",meetingState.sharing)
        EventHandler:emit(EventHandler.events.meetingChange)
      end
   end
end)

startStopWatchMeeting = function()
    if(meetingState == false and currentlyInMeeting() == true) then
        ZoomMonitor.logger.d("Start Meeting")
        meetingState = {}
        checkMeetingStatus:start()
        checkMeetingStatus:fire()
    elseif(meetingState and currentlyInMeeting() == false) then
        ZoomMonitor.logger.d("End Meeting")
        checkMeetingStatus:stop()
        meetingState = false
        EventHandler:emit(EventHandler.events.meetingChange)
    end
end

local function checkZoom(window, name, event)
    ZoomMonitor.logger.d("Check Meeting Status",window,name,event)
    zoom = window:application()
    startStopWatchMeeting()
end
-- Monitor zoom for running meeting
hs.application.enableSpotlightForNameSearches(true)

-- filters - table, every element will set an application filter; these elements must: 
-- - have a key of type string, denoting an application name as per hs.application:name() 
--  - if the value is a boolean, the app will be allowed or rejected accordingly 
--      - see hs.window.filter:allowApp() and hs.window.filter:rejectApp() 
--  - if the value is a table, it must contain the accept/reject rules for the app as key/value pairs; valid keys and values are described in hs.window.filter:setAppFilter() 
-- - the key can be one of the special strings "default" and "override", which will set the default and override filter respectively 
-- - the key can be the special string "sortOrder"; the value must be one of the sortBy... constants as per hs.window.filter:setSortOrder()

-- local zoomWindowFilter = hs.window.filter.new(false,"ZoomWindowFilterLog",0):setAppFilter('zoom.us')
local zoomWindowFilter = hs.window.filter.new({["zoom.us"]={}},"ZoomWindowFilterLog",0):pause()

-------------------------------------------
-- End of Zoom Monitor
-------------------------------------------


function ZoomMonitor:start()
    ZoomMonitor.logger.d("ZoomMonitor:start()"..((running and " - skipping") or " - starting"))
    if not running then
        running = true
        zoomWindowFilter:resume():subscribe(
            {
                hs.window.filter.hasWindow,
                hs.window.filter.windowDestroyed,
                hs.window.filter.windowTitleChanged
            },
            checkZoom,
            true
        )
    end
    return self
end

function ZoomMonitor:stop()
    ZoomMonitor.logger.d("ZoomMonitor:stop()")
    zoomWindowFilter:unsubscribeAll():pause()
    running = false
    return self
end



-- MetaMethods
ZoomMonitor = setmetatable(ZoomMonitor, {
    --GET
    __index = function (table, key)
        if key=="events" then
            return EventHandler.events
        elseif key=="zoom" then
            return zoom
        elseif key=="meetingState" then
            return meetingState
        else
            return rawget( table, key )
        end
    end,
    --SET
    __newindex = function (table, key, value)
        if key=="events" or key=="meetingState" or "zoom" then --luacheck: ignore 542
            -- skip read-only fields
        else
            rawset(table, key, value)
        end
    end
})

return ZoomMonitor
