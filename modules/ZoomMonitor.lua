

local ZoomMonitor={}
ZoomMonitor.name = 'WatchForMeeting.ZoomMonitor'
ZoomMonitor.appName = "zoom"

ZoomMonitor.logger = hs.logger.new(ZoomMonitor.name, 5)

local running = false

-------------------------------------------
-- BEGIN EVENT HANDLER
-------------------------------------------


-- Events
local EventHandler = dofile(hs.spoons.resourcePath("EventHandler.lua"))({"meetingChange"}, ZoomMonitor.name)


--- ZoomMonitor:subscribe(event, fn) -> ZoomMonitor object
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

--- ZoomMonitor:unsubscribe(event, fn) -> ZoomMonitor object
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

--- ZoomMonitor:unsubscribeEvent(event) -> ZoomMonitor object
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


--- ZoomMonitor:unsubscribeAll() -> ZoomMonitor object
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

local zoom = nil
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
      EventHandler:emit(EventHandler.events.meetingChange)
      return
    else
      --Watch for zoom menu items
      local _mic_open = zoom:findMenuItem({"Meeting", "Unmute audio"})==nil
      local _video_on = zoom:findMenuItem({"Meeting", "Start video"})==nil
      local _sharing = zoom:findMenuItem({"Meeting", "Start share"})==nil
      if((meetingState.mic_open ~= _mic_open) or (meetingState.video_on ~= _video_on) or (meetingState.sharing ~= _sharing)) then
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

local zoomWindowFilter = hs.window.filter.new(false,"ZoomWindowFilterLog",0):setAppFilter('zoom.us')
zoomWindowFilter:subscribe(hs.window.filter.hasWindow,checkZoom,true)
zoomWindowFilter:subscribe(hs.window.filter.hasNoWindows,checkZoom)
zoomWindowFilter:subscribe(hs.window.filter.windowDestroyed,checkZoom)
zoomWindowFilter:subscribe(hs.window.filter.windowTitleChanged,checkZoom)
zoomWindowFilter:pause()
-------------------------------------------
-- End of Zoom Monitor
-------------------------------------------


function ZoomMonitor:start()
    ZoomMonitor.logger.d("ZoomMonitor:start()"..((running and " - skipping") or " - starting"))
    if not running then
        running = true
        zoomWindowFilter:resume()
    end
    return self
end

function ZoomMonitor:stop()
    ZoomMonitor.logger.d("ZoomMonitor:stop()")
    zoomWindowFilter:pause()
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
            -- skip writing events to EventHandler as it is a read-only field
        else
            return rawset(table, key, value)
        end
    end
})

return ZoomMonitor
