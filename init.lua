--- === WatchForMeeting ===
---
--- A Spoon to answer the question
--- > Are you in a meeting?
---
--- Watches to see if:
--- 1) A supported application is running
--- 2) Are you on a call
--- 3) Are you on mute, is your camera on, and/or are you screen sharing
---
--- And then lets you share that information.
---
--- # Installation & Basic Usage
--- Download the [Latest Release](https://github.com/asp55/WatchForMeeting.spoon/releases/latest) and unzip to `~/.hammerspoon/Spoons/`
---
--- To get going right out of the box, in your `~/.hammerspoon/init.lua` add these lines:
--- ```
--- hs.loadSpoon("WatchForMeeting")
--- spoon.WatchForMeeting:start()
--- ```
---
--- This will start the spoon monitoring for zoom calls, and come with the default status page, and menubar configurations.
---
--We'll store some stuff in an internal table
local _internal = {}

-- create a namespace
local WatchForMeeting={}
-- Metadata
WatchForMeeting.name = "WatchForMeeting"
WatchForMeeting.version = "3.0.0"
WatchForMeeting.author = "Andrew Parnell <aparnell@gmail.com>"
WatchForMeeting.homepage = "https://github.com/asp55/WatchForMeeting.spoon"
WatchForMeeting.license = "MIT - https://opensource.org/licenses/MIT"



--Monitors
-------------------------------------------
-- Zoom Monitor
-------------------------------------------
local ZoomMonitor = dofile(hs.spoons.resourcePath("modules/ZoomMonitor.lua"))
-------------------------------------------
-- End of Zoom Monitor
-------------------------------------------

-------------------------------------------
-- Teams Monitor
-------------------------------------------
local TeamsMonitor = dofile(hs.spoons.resourcePath("modules/TeamsMonitor.lua"))
TeamsMonitor.version = WatchForMeeting.version
-------------------------------------------
-- End of Teams Monitor
-------------------------------------------


-- Event callbacks

-------------------------------------------
-- Declare Event Constants
-------------------------------------------
--- WatchForMeeting.events.meetingChange
--- Constant
--- Pseudo-event for `WatchForMeeting:subscribe()`: The meeting state has changed
--- 
--- WatchForMeeting.events.meetingStarted
--- Constant
--- Pseudo-event for `WatchForMeeting:subscribe()`: A meeting has started
--- 
--- WatchForMeeting.events.meetingStopped
--- Constant
--- Pseudo-event for `WatchForMeeting:subscribe()`: A meeting has ended
--- 
--- WatchForMeeting.events.micChange
--- Constant
--- Pseudo-event for `WatchForMeeting:subscribe()`: The state of the microphone has changed
--- 
--- WatchForMeeting.events.micOn
--- Constant
--- Pseudo-event for `WatchForMeeting:subscribe()`: The microphone is live
--- 
--- WatchForMeeting.events.micOff
--- Constant
--- Pseudo-event for `WatchForMeeting:subscribe()`: The microphone has been muted
--- 
--- WatchForMeeting.events.videoChange
--- Constant
--- Pseudo-event for `WatchForMeeting:subscribe()`: The state of the camera has changed
--- 
--- WatchForMeeting.events.videoOn
--- Constant
--- Pseudo-event for `WatchForMeeting:subscribe()`: The camera is on
--- 
--- WatchForMeeting.events.videoOff
--- Constant
--- Pseudo-event for `WatchForMeeting:subscribe()`: The camera is off
--- 
--- WatchForMeeting.events.screensharingChange
--- Constant
--- Pseudo-event for `WatchForMeeting:subscribe()`: The state of the screen sharing has changed
--- 
--- WatchForMeeting.events.screensharingOn
--- Constant
--- Pseudo-event for `WatchForMeeting:subscribe()`: The screen sharing is on
--- 
--- WatchForMeeting.events.screensharingOff
--- Constant
--- Pseudo-event for `WatchForMeeting:subscribe()`: The screen sharing is off
--- 
local events = {
   "meetingChange",
   "meetingStarted",
   "meetingStopped",
   "micChange",
   "micOn",
   "micOff",
   "videoChange",
   "videoOn",
   "videoOff",
   "screensharingChange",
   "screensharingOn",
   "screensharingOff",
}

local EventHandler = dofile(hs.spoons.resourcePath("modules/EventHandler.lua"))(events, WatchForMeeting.name)


-------------------------------------------
-- End Declare Event Constants
-------------------------------------------

-------------------------------------------
-- Declare Variables
-------------------------------------------

-- private variable to track if spoon is already running or not. (Makes it easier to find local variables)
local running = false

-------------------------------------------
-- Special Variables 
-- Stored in _internal or submodules and
-- accessed through metamethods defined below
-------------------------------------------

--- WatchForMeeting.logger
--- Variable
--- hs.logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
local log = hs.logger.new('WatchMeeting')

local logSetter = function (_, key, value)
   if(key=="level") then
      print("Update all logger levels")
      EventHandler.logger.level = value
      TeamsMonitor.logger.level = value
      ZoomMonitor.logger.level = value
   end
   log[key] = value
end

--Meta table for logger so it applies to submodules as well
_internal.logger = setmetatable(log, { __newindex = logSetter })


--- WatchForMeeting.sharing
--- Variable
--- A Table containing the settings that control sharing.
---
--- | Key | Description | Default |
--- | --- | ----------- | ------- |
--- | enabled | Whether or not sharing is enabled.<br/><br/>When false, the spoon will still monitor meeting status to [meetingState](#meetingState), but you will need to write your own automations for what to do with that info. | _true_ |
--- | useServer | Do you want to use an external server? (See *Configuration Options* below) | _false_ |
--- | | ↓ _required info when `useServer=false`_ | |
--- | port | What port to run the self hosted server when WatchForMeeting.sharing.useServer is false. | _8080_ |
--- | | ↓ _required info when `useServer=true`_ | |
--- | serverURL | The complete url for the external server, including port. IE: `http://localhost:8080` | _nil_ |
--- | key | UUID to identify the room. Value is provided when the room is added on the server side. | _nil_ |
--- | maxConnectionAttempts | Maximum number of connection attempts when using an external server. When less than 0, infinite retrys | _-1_ |
--- | waitBeforeRetry | Time, in seconds, between connection attempts when using an external server | _5_ |
---
--- # Configuration Options
--- ## Default
--- In order to minimize dependencies, by default this spoon uses a [hs.httpserver](https://www.hammerspoon.org/docs/hs.httpserver.html) to host the status page. This comes with a significant downside of: only the last client to load the page will receive status updates. Any previously connected clients will remain stuck at the last update they received before that client connected.
---
--- Once you are running the spoon, assuming you haven't changed the port (and nothing else is running at that location) you can reach your status page at http://localhost:8080
---
--- ## Better - MeetingStatusServer
--- For a better experience I recommend utilizing an external server to receive updates via websockets, and broadcast them to as many clients as you wish to connect.
---
--- For that purpose I've built [http://github.com/asp55/MeetingStatusServer](http://github.com/asp55/MeetingStatusServer) which runs on node.js and can either be run locally as its own thing, or hosted remotely.
---
--- If using the external server, you will to create a key to identify your "room" and then provide that information to the spoon.
--- In that case, before `spoon.WatchForMeeting:start()` add the following to your `~/.hammerspoon/init.lua`
---
--- ```
--- spoon.WatchForMeeting.sharing.useServer = true
--- spoon.WatchForMeeting.sharing.serverURL="[YOUR SERVER URL]"
--- spoon.WatchForMeeting.sharing.key="[YOUR KEY]"
--- ```
---
--- or
---
--- ```
--- spoon.WatchForMeeting.sharing = {
---   useServer = true,
---   serverURL = "[YOUR SERVER URL]",
---   key="[YOUR KEY]"
--- }
--- ```
---
--- ## Disable
--- If you don't want to broadcast your status to a webpage, simply disable sharing
--- ```
---   spoon.WatchForMeeting.sharing = {
---     enabled = false
---   }
--- ```
---
local sharingDefaults = {
   enabled = true,
   useServer = false,
   port = 8080,
   serverURL = nil,
   key = nil,
   maxConnectionAttempts = -1,  --when less than 0, infinite retrys
   waitBeforeRetry = 5,
}
_internal.sharing = setmetatable({}, {__index=sharingDefaults})

--- WatchForMeeting.menubar
--- Variable
--- A Table containing the settings that control sharing.
---
--- | Key | Description | Default |
--- | --- | ----------- | ------- |
--- | enabled | Whether or not to show the menu bar. | _true_ |
--- | color | Whether or not to use color icons. | _true_ |
--- | detailed | Whether or not to use the detailed icon set. | _true_ |
--- | showFullState | Whether the menubar icon should represent the full state<br/>(IE: Mic On/Off, Video On/Off, & Screen Sharing) | _true_ |
---
---
--- ## Icons
---
--- <table>
---   <thead>
---   <tr>
---   <th>
---     <code>WatchForMeeting.menuBar = {...}</code> &#8594;
---   </th>
---   <th><code>color=true,</code><br/><code>detailed=true,</code></th>
---   <th><code>color=true,</code><br/><code>detailed=false,</code></th>
---   <th><code>color=false,</code><br/><code>detailed=true,</code></th>
---   <th><code>color=false,</code><br/><code>detailed=false,</code></th>
---   </tr>
---   <tr>
---   <th>State (See: <a href="#meetingState">WatchForMeeting.meetingState</a>) &#8595;
---   </th>
---   <th colspan="4"><code>showFullState=true</code> or <code>showFullState=false</code></th>
---   </tr>
---   </thead>
---   <tbody>
---     <tr>
---       <td>Available</td>
---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Free.png" alt="Free slash Available" height="16" /></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Free.png" alt="Free slash Available" height="16" /></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Free.png" alt="Free slash Available" height="16" /></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Free.png" alt="Free slash Available" height="16" /></td>
---     </tr>
---     <tr>
---       <td>Busy</td>
---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting.png" alt="In meeting, no additional status" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting.png" alt="In meeting, no additional status" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting.png" alt="In meeting, no additional status" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting.png" alt="In meeting, no additional status" height="16"></td>
---     </tr>
---   <tr>
---   <td></td>
---   <th colspan="4"><code>showFullState=true</code> only</th>
---   </tr>
---     <tr>
---       <td>Busy + Mic On</td>
---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Mic.png" alt="In meeting, mic:on, video:off, screensharing:off" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Mic.png" alt="In meeting, mic:on, video:off, screensharing:off" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Mic.png" alt="In meeting, mic:on, video:off, screensharing:off" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Mic.png" alt="In meeting, mic:on, video:off, screensharing:off" height="16"></td>
---     </tr>
---     <tr>
---       <td>Busy + Video On</td>
---     <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Vid.png" alt="In meeting, mic:off, video:on, screensharing:off" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Vid.png" alt="In meeting, mic:off, video:on, screensharing:off" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Vid.png" alt="In meeting, mic:off, video:on, screensharing:off" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Vid.png" alt="In meeting, mic:off, video:on, screensharing:off" height="16"></td>
---     </tr>
---     <tr>
---       <td>Busy + Screen Sharing</td>
---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Screen.png" alt="In meeting, mic:off, video:off, screensharing:on" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Screen.png" alt="In meeting, mic:off, video:off, screensharing:on" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Screen.png" alt="In meeting, mic:off, video:off, screensharing:on" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Screen.png" alt="In meeting, mic:off, video:off, screensharing:on" height="16"></td>
---     </tr>
---     <tr>
---       <td>Busy + Mic On + Video On</td>
---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Mic-Vid.png" alt="In meeting, mic:on, video:on, screensharing:off" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Mic-Vid.png" alt="In meeting, mic:on, video:on, screensharing:off" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Mic-Vid.png" alt="In meeting, mic:on, video:on, screensharing:off" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Mic-Vid.png" alt="In meeting, mic:on, video:on, screensharing:off" height="16"></td>
---     </tr>
---     <tr>
---       <td>Busy + Mic On + Screen Sharing</td>
---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Mic-Screen.png" alt="In meeting, mic:on, video:off, screensharing:on" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Mic-Screen.png" alt="In meeting, mic:on, video:off, screensharing:on" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Mic-Screen.png" alt="In meeting, mic:on, video:off, screensharing:on" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Mic-Screen.png" alt="In meeting, mic:on, video:off, screensharing:on" height="16"></td>
---     </tr>
---     <tr>
---       <td>Busy + Video On + Screen Sharing</td>
---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Vid-Screen.png" alt="In meeting, mic:off, video:on, screensharing:on" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Vid-Screen.png" alt="In meeting, mic:off, video:on, screensharing:on" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Vid-Screen.png" alt="In meeting, mic:off, video:on, screensharing:on" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Vid-Screen.png" alt="In meeting, mic:off, video:on, screensharing:on" height="16"></td>
---     </tr>
---     <tr>
---       <td>Busy + Mic On + Video On + Screen Sharing</td>
---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Mic-Vid-Screen.png" alt="In meeting, mic:on, video:on, screensharing:on" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Mic-Vid-Screen.png" alt="In meeting, mic:on, video:on, screensharing:on" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Mic-Vid-Screen.png" alt="In meeting, mic:on, video:on, screensharing:on" height="16"></td>
--- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Mic-Vid-Screen.png" alt="In meeting, mic:on, video:on, screensharing:on" height="16"></td>
---     </tr>
---   </tbody>
--- </table>
local menubarDefaults = {
   enabled = true,
   color = true,
   detailed = true,
   showFullState = true
}
local menubarSetter = function (_, key, value)
   if(key=="enabled") then
      if(value) then
         _internal.meetingMenuBar:returnToMenuBar()
         _internal.updateMenuIcon(_internal.meetingState, _internal.faking)
      else
         _internal.meetingMenuBar:removeFromMenuBar()
      end
   else
      _internal.updateMenuIcon(_internal.meetingState, _internal.faking)
   end
end

_internal.menubar = setmetatable({}, {__index=menubarDefaults, __newindex=menubarSetter})

--- WatchForMeeting.mode
--- Variable
--- Number representing which mode WatchForMeeting should be running
---
--- - *0* - Automatic (default)
--- -- Monitors configured apps (see [apps](#apps)) and updates status accordingly
--- - *1* - Busy
--- -- Fakes a meeting. (Marks as in meeting, and signals that the mic is live, camera is on, and screen is sharing.) Useful when meeting type is not supported.
_internal.mode = 0

--- WatchForMeeting.apps
--- Variable
--- A Table controlling which meeting apps are monitored in automatic mode.
---
--- | Key | Description | Default |
--- | --- | ----------- | ------- |
--- | zoom | Monitor Zoom meetings via menu item polling | _true_ |
--- | teams | Monitor Microsoft Teams meetings via local WebSocket API | _false_ |
---
--- Changes take effect on the next call to `:start()` or `:restart()`.
local appsDefaults = { zoom = true, teams = false }
_internal.apps = setmetatable({}, {__index=appsDefaults})


--- WatchForMeeting.zoom
--- Variable
--- (Read-only) The hs.application for zoom if it is running, otherwise nil
-- Comes from ZoomMonitor.zoom

--- WatchForMeeting.meetingState
--- Variable
--- (Read-only) Either false (when not in a meeting) or a table (when in a meeting)
---
--- | Value                                                                   | Description  |
--- | ----------------------------------------------------------------------- | -----------  |
--- | `false`                                                                 | Available    |
--- | `{mic_open = [Boolean],  video_on = [Boolean], sharing = [Boolean] }`   | Busy         |
_internal.meetingState = false
_internal.lastMeetingState = nil;

--- WatchForMeeting.meetingApp
--- Variable
--- (Read-only) string representing the name of the application providing the meeting state. Empty when not in a meeting.
_internal.meetingApp = ""

--- WatchForMeeting.faking
--- Variable
--- (Read-only) Boolean representing if the meeting is real or faked
_internal.faking = false


-- MetaMethods
WatchForMeeting = setmetatable(WatchForMeeting, {
   --GET
   __index = function (table, key)
      if(key=="zoom" or key=="meetingState" or key=="meetingApp" or key=="faking" or key=="menubar" or key=="mode" or key=="sharing" or key=="apps" or key=="logger") then
         return _internal[key]
      elseif(key=="zoom") then
         return ZoomMonitor.zoom
      elseif(key=="events") then
         return EventHandler.events
      else
         return rawget( table, key )
      end
   end,
   --SET
   __newindex = function (table, key, value)
      if(key=="zoom" or key=="meetingState" or key=="meetingApp" or key=="faking" or key=="events") then --luacheck: ignore 542
         --skip read-only fields
      elseif(key=="menubar") then
         _internal.menubar = setmetatable(value, {__index=menubarDefaults, __newindex=menubarSetter})
         if(_internal.menubar.enabled) then
            _internal.meetingMenuBar:returnToMenuBar()
            _internal.updateMenuIcon(_internal.meetingState, _internal.faking)
         else
            _internal.meetingMenuBar:removeFromMenuBar()
         end
      elseif(key=="mode") then
         if(value == 1) then
            table:fake()
         else
            table:auto()
         end
      elseif(key=="logger") then
         log = value
         _internal.logger = setmetatable(value, { __newindex = logSetter })
      elseif(key=="sharing") then
         _internal.sharing = setmetatable(value, {__index=sharingDefaults})
      elseif(key=="apps") then
         _internal.apps = setmetatable(value, {__index=appsDefaults})
      else
         return rawset(table, key, value)
      end
   end
})

-------------------------------------------
-- End Special Variables 
-------------------------------------------

-------------------------------------------
-- End of Declare Variables
-------------------------------------------
-------------------------------------------
-- Menu Bar
-------------------------------------------
_internal.meetingMenuBar = hs.menubar.new(false)
function _internal.updateMenuIcon(status, faking)
   if(_internal.menubar.enabled) then
      local iconPath = 'menubar-icons/'
      if(_internal.menubar.color) then
         iconPath = iconPath..'Color/'
      else
         iconPath = iconPath..'Template/'
      end
      if(_internal.menubar.detailed) then
         iconPath = iconPath..'Detailed/'
      else
         iconPath = iconPath..'Minimal/'
      end
      local iconFile = "Free.pdf"
      if(status) then
         iconFile = "Meeting"
         if(_internal.menubar.showFullState and (status.mic_open or status.video_on or status.sharing)) then
            if(status.mic_open) then iconFile = iconFile.."-Mic" end
            if(status.video_on) then iconFile = iconFile.."-Vid" end
            if(status.sharing) then iconFile = iconFile.."-Screen" end
         end
         if(faking) then iconFile = iconFile.."-Faking" end
         iconFile = iconFile..".pdf"
      end
      _internal.meetingMenuBar:setIcon(hs.spoons.resourcePath(iconPath..iconFile),not _internal.menubar.color)
   end
end
-------------------------------------------
-- End of Menu Bar
-------------------------------------------


-------------------------------------------
-- Web Server
-------------------------------------------
_internal.server = nil
_internal.websocketStatus = "closed"
local function composeJsonUpdate(meetingState)
   local message = {action="update", inMeeting=meetingState}
   return hs.json.encode(message)
end
local monitorfile = io.open(hs.spoons.resourcePath("monitor.html"), "r")
local htmlContent = monitorfile:read("*a")
monitorfile:close()
local function selfhostHttpCallback()
   local websocketPath = "ws://"..hs.network.interfaceDetails(hs.network.primaryInterfaces())["IPv4"]["Addresses"][1]..":"..WatchForMeeting.sharing.port.."/ws"
   htmlContent = string.gsub(htmlContent,"%%websocketpath%%",websocketPath)
   return htmlContent, 200, {}
end
local function selfhostWebsocketCallback(_)
   return composeJsonUpdate(_internal.meetingState)
end
-------------------------------------------
-- End Web Server
-------------------------------------------


-------------------------------------------
-- Event Emitter
-------------------------------------------
local function updateCallbacks()
   if(_internal.server and _internal.websocketStatus == "open") then _internal.server:send(composeJsonUpdate(_internal.meetingState)) end
   
   -- Emit appropriate events
   local newState = _internal.meetingState or {}
   local oldState = _internal.lastMeetingState or {}

   if _internal.meetingState and not _internal.lastMeetingState then
      -- Meeting just started
      EventHandler:emit(WatchForMeeting.events.meetingStarted)
   end


   if oldState.mic_open~=newState.mic_open then
      EventHandler:emit(WatchForMeeting.events.micChange)
      if newState.mic_open then
         EventHandler:emit(WatchForMeeting.events.micOn)
      else
         EventHandler:emit(WatchForMeeting.events.micOff)
      end
   end

   if oldState.video_on~=newState.video_on then
      EventHandler:emit(WatchForMeeting.events.videoChange)
      if newState.video_on then
         EventHandler:emit(WatchForMeeting.events.videoOn)
      else
         EventHandler:emit(WatchForMeeting.events.videoOff)
      end
   end

   if oldState.sharing~=newState.sharing then
      EventHandler:emit(WatchForMeeting.events.screensharingChange)
      if newState.sharing then
         EventHandler:emit(WatchForMeeting.events.screensharingOn)
      else
         EventHandler:emit(WatchForMeeting.events.screensharingOff)
      end
   end


   if not _internal.meetingState and _internal.lastMeetingState then
      -- Meeting just started
      EventHandler:emit(WatchForMeeting.events.meetingStopped)
   end

   _internal.lastMeetingState = _internal.meetingState
end

-------------------------------------------
-- End Event Emitter
-------------------------------------------


_internal.connectionAttempts = 0
_internal.connectionError = false
-- forward declare reconnectToSharing so onSharingMessage can reference it for reconnects
local reconnectToSharing = function() end

local function disconnectFromSharing()
   if(_internal.server) then
      if(getmetatable(_internal.server).stop) then _internal.server:stop() end
      if(getmetatable(_internal.server).close) then _internal.server:close() end
   end
end
local function onSharingMessage(type, message)
   if(type=="open") then
      _internal.websocketStatus = "open"
      _internal.connectionAttempts = 0
      local draft = {action="identify", key=WatchForMeeting.sharing.key, type="room", status={inMeeting=_internal.meetingState}}
      _internal.server:send(hs.json.encode(draft))
   elseif(type == "closed" and running) then
      _internal.websocketStatus = "closed"
      if(_internal.connectionError) then
         log.d("Lost connection to sharing websocket, will not reattempt due to error")
      else
         log.d("Lost connection to sharing websocket, attempting to reconnect in "..WatchForMeeting.sharing.waitBeforeRetry.." seconds")
         reconnectToSharing()
      end
   elseif(type == "fail") then
      _internal.websocketStatus = "fail"
      if(WatchForMeeting.sharing.maxConnectionAttempts > 0) then
         log.d("Could not connect to sharing websocket server. attempting to reconnect in "..WatchForMeeting.sharing.waitBeforeRetry.." seconds. (Attempt ".._internal.connectionAttempts.."/"..WatchForMeeting.sharing.maxConnectionAttempts..")")
      else
         log.d("Could not connect to sharing websocket server. attempting to reconnect in "..WatchForMeeting.sharing.waitBeforeRetry.." seconds. (Attempt ".._internal.connectionAttempts..")")
      end
      reconnectToSharing()
   elseif(type == "received") then
      local parsed = hs.json.decode(message);
      if(parsed.error) then
         _internal.connectionError = true;
         if(parsed.errorType == "badkey") then
            disconnectFromSharing()
            hs.showError("")
            log.e("WatchForMeeting.sharing.key not valid. Make sure that key has been established on the server.")
         end
      else
         log.d("Sharing Websocket Message received: ", hs.inspect.inspect(parsed));
      end
   else
      log.d("Sharing Websocket Callback "..type, message)
   end
end

local function connectToSharing()
   if(WatchForMeeting.sharing) then
      if(WatchForMeeting.sharing.useServer) then
         log.d("Connecting to server at "..WatchForMeeting.sharing.serverURL)
         _internal.connectionAttempts = _internal.connectionAttempts + 1
         _internal.websocketStatus = "connecting"
         _internal.server = hs.websocket.new(WatchForMeeting.sharing.serverURL, onSharingMessage);
      else
         log.d("Starting Self Hosted Server on port "..WatchForMeeting.sharing.port)
         _internal.server = hs.httpserver.new()
         _internal.server:websocket("/ws", selfhostWebsocketCallback)
         _internal.websocketStatus = "open"
         _internal.server:setPort(WatchForMeeting.sharing.port)
         _internal.server:setCallback(selfhostHttpCallback)
         _internal.server:start()
      end
   end
end

--redefine reconnectToSharing now that connectToSharing & disconnectFromSharing exist.
reconnectToSharing = function()
   if(WatchForMeeting.sharing.maxConnectionAttempts > 0 and _internal.connectionAttempts >= WatchForMeeting.sharing.maxConnectionAttempts) then
      log.e("Maximum Connection Attempts failed")
      disconnectFromSharing()
   elseif(_internal.connectionError) then
      disconnectFromSharing()
   else
      hs.timer.doAfter(WatchForMeeting.sharing.waitBeforeRetry, connectToSharing)
   end
end

local function validateShareSettings()
   log.d("validateShareSettings")
   if(WatchForMeeting.sharing.useServer and (WatchForMeeting.sharing.serverURL==nil or WatchForMeeting.sharing.key==nil)) then
      hs.showError("")
      if(WatchForMeeting.sharing.serverURL==nil) then log.e("WatchForMeeting.sharing.serverURL required when using a server") end
      if(WatchForMeeting.sharing.key==nil) then log.e("WatchForMeeting.sharing.key required when using a server") end
      return false
   elseif(not WatchForMeeting.sharing.useServer and WatchForMeeting.sharing.port==nil) then
      hs.showError("")
      log.e("WatchForMeeting.sharing.port required when self hosting")
      return false
   else
      return true
   end
end

-------------------------------------------
-- Methods
-------------------------------------------


local function startMonitors()
   log.d("startMonitors")
   if(WatchForMeeting.apps.zoom) then
      ZoomMonitor:start()
   end

   if(WatchForMeeting.apps.teams) then
      TeamsMonitor:start()
   end
end

local function stopMonitors(except)
   log.d("stopMonitors("..(function() if(except) then return except.name else return "" end end)()..")")
   local monitors = {TeamsMonitor, ZoomMonitor}
   for _,v in pairs(monitors) do
      if v ~= except then v:stop() end
   end
end

--- WatchForMeeting:start() -> WatchForMeeting
--- Method
--- Starts a WatchForMeeting object
---
--- Parameters:
---  * None
---
--- Returns:
---  * The spoon.WatchForMeeting object
function WatchForMeeting:start()
   log.d("WatchForMeeting:start()")

   if(not running) then
      running = true
      if(self.sharing.enabled and validateShareSettings()) then
         connectToSharing()
      end

      if(self.menubar.enabled) then
         _internal.meetingMenuBar:returnToMenuBar()
      end

      if(_internal.mode == 1 ) then
         self:fake()
      else
         self:auto()
      end
   end
   return self
end
--- WatchForMeeting:stop()
--- Method
--- Stops a WatchForMeeting object
---
--- Parameters:
---  * None
---
--- Returns:
---  * The spoon.WatchForMeeting object
function WatchForMeeting:stop()
   log.d("WatchForMeeting:stop()")
   running = false
   disconnectFromSharing()
   _internal.lastMeetingState = nil
   _internal.meetingMenuBar:removeFromMenuBar()

   stopMonitors()
   return self
end
--- WatchForMeeting:restart()
--- Method
--- Restarts a WatchForMeeting object
---
--- Parameters:
---  * None
---
--- Returns:
---  * The spoon.WatchForMeeting object
function WatchForMeeting:restart()
   self:stop()
   return self:start()
end

local function HandleAppChange(appMonitor)
   log.d("HandleAppChange("..appMonitor.name..")")

   if appMonitor.meetingState then
      stopMonitors(appMonitor)
      _internal.meetingApp = appMonitor.appName
   end

   _internal.meetingState = appMonitor.meetingState

   _internal.updateMenuIcon(_internal.meetingState, _internal.faking)
   updateCallbacks()
   
   if not appMonitor.meetingState then
      _internal.meetingApp = ""
      startMonitors()
   end
end

local function HandleZoomChange()
   HandleAppChange(ZoomMonitor)
end

local function HandleTeamsChange()
   HandleAppChange(TeamsMonitor)
end

ZoomMonitor:subscribe(ZoomMonitor.events.meetingChange, HandleZoomChange)
TeamsMonitor:subscribe(TeamsMonitor.events.meetingChange, HandleTeamsChange)

--- WatchForMeeting:auto()
--- Method
--- Monitors meetings and updates status accordingly
---
--- Parameters:
---  * None
---
--- Returns:
---  * The spoon.WatchForMeeting object
function WatchForMeeting:auto()
   _internal.mode = 0
   if(running) then
      _internal.faking = false
      _internal.meetingState = false

      startMonitors()

      _internal.meetingMenuBar:setMenu({
         { title = "Meeting Status:", disabled = true },
         { title = "Automatic", checked = true  },
         { title = "Busy", checked = false, fn=function() WatchForMeeting:fake() end }
      })
      --Update everything
      _internal.updateMenuIcon(_internal.meetingState, _internal.faking)
      updateCallbacks()

   end
   return self
end





--- WatchForMeeting:fake(mic_open, video_on, sharing)
--- Method
--- Disables monitoring and reports as being in a meeting. Useful when meeting type is not supported.
---
--- Parameters:
---  * mic_open - A boolean indicating if the mic is open
---  * video_on - A boolean indicating if the video camera is on
---  * sharing - A boolean indicating if screen sharing is on
---
--- Returns:
---  * The spoon.WatchForMeeting object
function WatchForMeeting:fake(_mic_open, _video_on, _sharing)
   _internal.mode = 1
   if(running) then
      _internal.faking = true
      _internal.meetingApp = "fake"
      _internal.meetingState = {mic_open = _mic_open, video_on = _video_on, sharing = _sharing}

      stopMonitors()

      local meetingMenu = {
         { title = "Meeting Status:", disabled = true },
         { title = "Automatic", checked = false, fn=function() WatchForMeeting:auto() end  },
         { title = "Busy", checked = true },
         { title = "-"}
      }
      if(not (_mic_open and _video_on and _sharing)) then
         table.insert(meetingMenu, { title = "Select All", fn=function() WatchForMeeting:fake(true, true, true) end })
      else
         table.insert(meetingMenu, { title = "Select None", fn=function() WatchForMeeting:fake(false, false, false) end })
      end
      table.insert(meetingMenu, { title = "Mic On", indent=1, checked = _internal.meetingState.mic_open, fn=function() WatchForMeeting:fake(not _mic_open, _video_on, _sharing) end})
      table.insert(meetingMenu, { title = "Video On", indent=1, checked = _internal.meetingState.video_on, fn=function() WatchForMeeting:fake(_mic_open, not _video_on, _sharing) end })
      table.insert(meetingMenu, { title = "Sharing Screen", indent=1, checked = _internal.meetingState.sharing, fn=function() WatchForMeeting:fake(_mic_open, _video_on, not _sharing) end })
      if(_mic_open or _video_on or _sharing) then
         table.insert(meetingMenu, { title = "Clear", fn=function() WatchForMeeting:fake(false, false, false) end })
      end
      _internal.meetingMenuBar:setMenu(meetingMenu)
      updateCallbacks()
      _internal.updateMenuIcon(_internal.meetingState, _internal.faking)
   end
   return self
end

--- WatchForMeeting:subscribe(event, fn)
--- Method
--- Subscribe to one event with one or more functions
---
--- Parameters:
---  * event - string of the event to subscribe to (see the `spoon.WatchForMeeting` constants)
---  * fn - function or list of functions, the callback(s) to add for the event(s);
---
--- Returns:
---  * The `spoon.WatchForMeeting` object for method chaining
function WatchForMeeting:subscribe(event, fns)
   EventHandler:subscribe(event, fns)
   return self
end

--- WatchForMeeting:unsubscribe(event, fn) -> hs.window.filter object
--- Method
--- Removes one or more event subscriptions
---
--- Parameters:
---  * event - string of the event to unsubscribe;
---  * fn - function or list of functions, the callback(s) to remove; if omitted, all callbacks will be unsubscribed from `event`(s)
---
--- Returns:
---  * The `spoon.WatchForMeeting` object for method chaining
---
function WatchForMeeting:unsubscribe(event,fn)
   EventHandler:unsubscribe(event, fn)
   return self
end

--- WatchForMeeting:unsubscribeEvent(event) -> hs.window.filter object
--- Method
--- Removes all subscriptions from one event
---
--- Parameters:
---  * event - string of the event to unsubscribe; ;
---
--- Returns:
---  * The `spoon.WatchForMeeting` object for method chaining
---
function WatchForMeeting:unsubscribeEvent(event)
   EventHandler:unsubscribeEvent(event)
   return self
 end

-------------------------------------------
-- End of Methods
-------------------------------------------

return WatchForMeeting
