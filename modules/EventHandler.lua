return function(acceptedEvents, objectName)

    local _internal = {
        eventCallbacks = {},
        events = {},
        eventNames = {}
    }

    local EventHandler = {}


    --- EventHandler.logger
    --- Variable
    --- hs.logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
    EventHandler.logger = hs.logger.new('WatchForMeeting.EventHandler')

    if objectName then
        EventHandler.logger.d('Create EventHandler for '..objectName)
    else
        EventHandler.logger.d('Create EventHandler')
    end

    _internal.eventCallbacks = {}
    _internal.events = {}
    for _,v in pairs(acceptedEvents) do
        _internal.events[v]=v
        if objectName then
            _internal.eventNames[v] = objectName..'.'..v
        else
            _internal.eventNames[v] = v
        end
    end

    function EventHandler:emit(event)
        EventHandler.logger.d('Emit '.._internal.eventNames[event])
        
        local fns=_internal.eventCallbacks[event]
        if fns then
            for fn in pairs(fns) do fn() end
        end
        return self
    end


    --- EventHandler:subscribe(event, fn)
    --- Method
    --- Subscribe to one event with one or more functions
    ---
    --- Parameters:
    ---  * event - string of the event to subscribe to (see the `spoon.WatchForMeeting` constants)
    ---  * fn - function or list of functions, the callback(s) to add for the event(s); 
    ---
    --- Returns:
    ---  * The `EventHandler` object for method chaining

    function EventHandler:subscribe(event, fns)
        if not event then error('invalid value for event ',3) end
        if not _internal.events[event] then error('invalid event: '..event,3) end
        if type(fns)~='table' and type(fns)~='function'  then error('fn must be a function or table of functions',3) end

        if type(fns)=='function' then fns = {fns} end
        
        for _,fn in pairs(fns) do
            if type(fn)~='function' then error('fn must be a function or table of functions',3) end
            if not _internal.eventCallbacks[event] then _internal.eventCallbacks[event]={} end
            if not _internal.eventCallbacks[event][fn] then
                _internal.eventCallbacks[event][fn]=true
                EventHandler.logger.df('added callback for event %s', _internal.eventNames[event])
            end
        end
        return self
    end

    --- EventHandler:unsubscribe(event, fn) -> hs.window.filter object
    --- Method
    --- Removes one or more event subscriptions
    ---
    --- Parameters:
    ---  * event - string of the event to unsubscribe;
    ---  * fn - function or list of functions, the callback(s) to remove;
    ---
    --- Returns:
    ---  * The `EventHandler` object for method chaining
    ---
    function EventHandler:unsubscribe(event,fn)
        if _internal.eventCallbacks[event] and _internal.eventCallbacks[event][fn] then
            EventHandler.logger.df('removed callback for event %s', _internal.eventNames[event])
            _internal.eventCallbacks[event][fn]=nil
            if not next(_internal.eventCallbacks[event]) then
                EventHandler.logger.df('no more callbacks for event %s', _internal.eventNames[event])
                _internal.eventCallbacks[event]=nil
            end
        end
        return self
    end

    --- EventHandler:unsubscribeEvent(event) -> hs.window.filter object
    --- Method
    --- Removes all subscriptions from one event
    ---
    --- Parameters:
    ---  * event - string of the event to unsubscribe; ;
    ---
    --- Returns:
    ---  * The `EventHandler` object for method chaining
    ---
    function EventHandler:unsubscribeEvent(event)
        if not _internal.events[event] then error('invalid event: '..event,3) end
        if _internal.eventCallbacks[event] then EventHandler.logger.df('removed all callbacks for event %s', _internal.eventNames[event]) end
        _internal.eventCallbacks[event]=nil
        return self
    end

    -- MetaMethods
    EventHandler = setmetatable(EventHandler, {
        --GET
        __index = function (table, key)
            if(key=="events") then
                return _internal.events
            else
                return rawget( table, key )
            end
        end,
        --SET
        __newindex = function (table, key, value)
            if(key=="events") then --luacheck: ignore 542
                -- skip writing events to EventHandler as it is a read-only field
            else
                return rawset(table, key, value)
            end
        end
    })

    return EventHandler;
end