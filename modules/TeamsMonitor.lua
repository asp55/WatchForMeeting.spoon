-------------------------------------------
-- Teams Monitor
-------------------------------------------

local TeamsMonitor={}
TeamsMonitor.name = 'WatchForMeeting.TeamsMonitor'
TeamsMonitor.appName = "teams"
TeamsMonitor.version = "0"

TeamsMonitor.logger = hs.logger.new(TeamsMonitor.name, 5)





local meetingState = false

local teamsWebsocket = nil
local teamsConnectionId = 0
local teamsPairing = false
local running = false


--------
-- BEGIN EVENT HANDLER
-------


-- Events
local EventHandler = dofile(hs.spoons.resourcePath("EventHandler.lua"))({"meetingChange"}, TeamsMonitor.name)


--- TeamsMonitor:subscribe(event, fn) -> TeamsMonitor object
--- Method
--- Subscribe to one event with one or more functions
---
--- Parameters:
---  * event - string of the event to subscribe to
---  * fn - function or list of functions, the callback(s) to add for the event(s); 
---
--- Returns:
---  * The `TeamsMonitor` object for method chaining

function TeamsMonitor:subscribe(event, fns)
    TeamsMonitor.logger.d("TeamsMonitor:subscribe("..event..")")
    EventHandler:subscribe(event, fns)
    return self
end

--- TeamsMonitor:unsubscribe(event, fn) -> TeamsMonitor object
--- Method
--- Removes one or more event subscriptions
---
--- Parameters:
---  * event - string of the event to unsubscribe;
---  * fn - function or list of functions, the callback(s) to remove
---
--- Returns:
---  * The `TeamsMonitor` object for method chaining
---
function TeamsMonitor:unsubscribe(event,fn)
    TeamsMonitor.logger.d("TeamsMonitor:unsubscribe("..event..")")
    EventHandler:unsubscribe(event, fn)
    return self
end

--- TeamsMonitor:unsubscribeEvent(event) -> TeamsMonitor object
--- Method
--- Removes all subscriptions from one event
---
--- Parameters:
---  * event - string of the event to unsubscribe
---
--- Returns:
---  * The `TeamsMonitor` object for method chaining
---
function TeamsMonitor:unsubscribeEvent(event)
    TeamsMonitor.logger.d("TeamsMonitor:unsubscribeEvent("..event..")")
    EventHandler:unsubscribeEvent(event)
    return self
end



--- TeamsMonitor:unsubscribeAll() -> TeamsMonitor object
--- Method
--- Removes all subscriptions from one event
---
--- Returns:
---  * The `TeamsMonitor` object for method chaining
---
function TeamsMonitor:unsubscribeAll()
    TeamsMonitor.logger.d("TeamsMonitor:unsubscribeAll()")
    EventHandler:unsubscribeAll()
    return self
 end


--------
-- END EVENT HANDLER
-------

local function disconnectFromTeams()
    TeamsMonitor.logger.d("disconnectFromTeams()")
    if teamsWebsocket then
        teamsWebsocket:close()
        teamsWebsocket = nil
    end
end

-- forward declare connectToTeams so onTeamsMessage can reference it for reconnects
local connectToTeams = function() end

local function onTeamsMessage(wsType, message)
    TeamsMonitor.logger.v("onTeamsMessage("..wsType, message,")")

    if wsType == "open" then
        TeamsMonitor.logger.d("Connected to Teams local API")

    elseif wsType == "received" then
        local ok, parsed = pcall(hs.json.decode, message)
        if not ok then
            TeamsMonitor.logger.w("Failed to parse Teams message: "..message)
            return
        end

        if parsed.tokenRefresh then
            TeamsMonitor.logger.d("Teams token refreshed")
            hs.settings.set("WatchForMeeting.teamsToken", parsed.tokenRefresh)
        end

        if parsed.meetingUpdate and parsed.meetingUpdate.meetingPermissions and parsed.meetingUpdate.meetingPermissions.canPair and not teamsPairing then

            TeamsMonitor.logger.d("Sending pairing request")
            teamsPairing = true
            teamsWebsocket:send('{"action":"toggle-mute","parameters":{},"requestId":1}')
        end

        if parsed.response and parsed.response == "Pairing response resulted in no action" then
            TeamsMonitor.logger.d("Didn't pair. Will try again next meeting.")
            teamsPairing = false
        end

        if parsed.meetingUpdate and parsed.meetingUpdate.meetingState then
            local ms = parsed.meetingUpdate.meetingState
            if ms.isInMeeting then
                local newState = {
                    mic_open = not ms.isMuted,
                    video_on = ms.isVideoOn,
                    sharing = ms.isSharing
                }
                if
                    (not meetingState) or
                    (meetingState.mic_open ~= newState.mic_open) or
                    (meetingState.video_on ~= newState.video_on) or
                    (meetingState.sharing ~= newState.sharing)
                then
                    meetingState = newState
                    EventHandler:emit(EventHandler.events.meetingChange)
                end
            else
                if meetingState then
                    meetingState = false
                    EventHandler:emit(EventHandler.events.meetingChange)
                end
            end
        end

    elseif wsType == "closed" then
        teamsWebsocket = nil
        teamsPairing = false
        if running then
            TeamsMonitor.logger.d("Teams WebSocket closed, probably because this app was blocked from the Third-party app API in teams.")
            TeamsMonitor.logger.d("Go to Settings > Privacy > Third-party app API > Manage API and remove the application from block.")
        end

    elseif wsType == "fail" then
        teamsWebsocket = nil
        TeamsMonitor.logger.d("Teams not available, retrying in 30 seconds")
        hs.timer.doAfter(30, connectToTeams)
    end
end

connectToTeams = function()
    TeamsMonitor.logger.d("connectToTeams()")

    -- Increment the connection ID before closing, so any callbacks from the
    -- previous connection are ignored even if close() fires synchronously.
    teamsConnectionId = teamsConnectionId + 1
    local myId = teamsConnectionId
    if teamsWebsocket then
        teamsWebsocket:close()
        teamsWebsocket = nil
    end
    local token = hs.settings.get("WatchForMeeting.teamsToken") or ""

    local manufacturer = "Hammerspoon"
    local device = "WatchForMeeting.spoon"
    local app = "WatchForMeeting.spoon"
    local url = "ws://localhost:8124?token="..token.."&protocol-version=2.0.0&manufacturer="..manufacturer.."&device="..device.."&app="..app.."&app-version="..TeamsMonitor.version
    TeamsMonitor.logger.d("Connecting to Teams")
    teamsWebsocket = hs.websocket.new(url, function(wsType, message)
        if myId == teamsConnectionId then
            onTeamsMessage(wsType, message)
        end
    end)
end

function TeamsMonitor:start()
    TeamsMonitor.logger.d("TeamsMonitor:start()"..((teamsWebsocket and " - skipping") or " - starting"))
    if not teamsWebsocket then
        running = true
        connectToTeams()
    end
    return self
end

function TeamsMonitor:stop()
    TeamsMonitor.logger.d("TeamsMonitor:stop()")
    running = false
    disconnectFromTeams()
    return self
end

-------------------------------------------
-- End of Teams Monitor
-------------------------------------------


-- MetaMethods
TeamsMonitor = setmetatable(TeamsMonitor, {
    --GET
    __index = function (table, key)
        if key=="events" then
            return EventHandler.events
        elseif key=="meetingState" then
            return meetingState
        else
            return rawget( table, key )
        end
    end,
    --SET
    __newindex = function (table, key, value)
        if key=="events" or key=="meetingState" then --luacheck: ignore 542
            -- skip writing events to EventHandler as it is a read-only field
        else
            return rawset(table, key, value)
        end
    end
})

return TeamsMonitor
