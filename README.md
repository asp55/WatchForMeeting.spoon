# WatchForMeeting
A Spoon for [Hammerspoon](http://hammerspoon.org) to answer the question
> Are you in a meeting?

Watches to see if:
1) A supported application is running
2) Are you on a call
3) Are you on mute, is your camera on, and/or are you screen sharing

And then lets you share that information.

# Installation & Basic Usage
Download the [Latest Release](https://github.com/asp55/WatchForMeeting/releases/latest) and unzip to `~/.hammerspoon/Spoons/`

To get going right out of the box, in your `~/.hammerspoon/init.lua` add these lines:
```
hs.loadSpoon("WatchForMeeting")
spoon.WatchForMeeting:start()
```

This will start the spoon monitoring for zoom calls, and come with the default status page, and menubar configurations.

# Supported Applications & Configuration
Currently this spoon supports:
1) Zoom
2) Microsoft Teams (v2)

## Configuration
Because this spoon originally only supported Zoom meetings, it is configured by default to watch for zoom. You can change that via the `.apps` table

WatchForMeeting.apps
Variable
A Table controlling which meeting apps are monitored in automatic mode.

| Key | Description | Default |
| --- | ----------- | ------- |
| zoom | Monitor Zoom meetings via menu item polling | _true_ |
| teams | Monitor Microsoft Teams meetings via local WebSocket API | _false_ |

# Sharing Status To A Webpage

## Default
In order to minimize dependencies, by default this spoon uses a [hs.httpserver](https://www.hammerspoon.org/docs/hs.httpserver.html) to host the status page. This comes with a significant downside of: only the last client to load the page will receive status updates. Any previously connected clients will remain stuck at the last update they received before that client connected.

Once you are running the spoon, assuming you haven't changed the port (and nothing else is running at that location) you can reach your status page at http://localhost:8080

## Better - MeetingStatusServer
For a better experience I recommend utilizing an external server to receive updates via websockets, and broadcast them to as many clients as you wish to connect.

For that purpose I've built [http://github.com/asp55/MeetingStatusServer](http://github.com/asp55/MeetingStatusServer) which runs on node.js and can either be run locally as its own thing, or hosted remotely.

If using the external server, you will to create a key to identify your "room" and then provide that information to the spoon. 
In that case, before `spoon.WatchForMeeting:start()` add the following to your `~/.hammerspoon/init.lua`

```
spoon.WatchForMeeting.sharing.useServer = true
spoon.WatchForMeeting.sharing.serverURL="[YOUR SERVER URL]"
spoon.WatchForMeeting.sharing.key="[YOUR KEY]"
```

or 

```
spoon.WatchForMeeting.sharing = {
  useServer = true,
  serverURL = "[YOUR SERVER URL]",
  key="[YOUR KEY]"
}
```

## Disable Sharing
If you don't want to broadcast your status to a webpage, simply disable sharing
```
  spoon.WatchForMeeting.sharing.enabled = false
```
or
```
  spoon.WatchForMeeting.sharing = {
    enabled = false
  }
```

# Menubar Icons
<table>
  <thead>
  <tr>
  <th rowspan="3">
    Configuration&#8594;<br/><br/>
    State&#8595;
  </th>
  <th colspan="4"><code>WatchForMeeting.menuBar={...}</code></th>
  </tr>
  <tr>
  <th><code>color=true,</code><br/><code>detailed=true,</code></th>
  <th><code>color=true,</code><br/><code>detailed=false,</code></th>
  <th><code>color=false,</code><br/><code>detailed=true,</code></th>
  <th><code>color=false,</code><br/><code>detailed=false,</code></th>
  </tr>
  <tr>
  <th colspan="4"><code>showFullState=true</code> or <code>showFullState=false</code></th>
  </tr>
  </thead>
  <tbody>
    <tr>
      <td>Available</td>
      <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Free.png" alt="Free slash Available" height="16" /></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Free.png" alt="Free slash Available" height="16" /></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Free.png" alt="Free slash Available" height="16" /></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Free.png" alt="Free slash Available" height="16" /></td>
    </tr>
    <tr>
      <td>Busy</td>
      <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting.png" alt="In meeting, no additional status" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting.png" alt="In meeting, no additional status" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting.png" alt="In meeting, no additional status" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting.png" alt="In meeting, no additional status" height="16"></td>
    </tr>
  <tr>
  <td></td>
  <th colspan="4"><code>showFullState=true</code> only</th>
  </tr>
    <tr>
      <td>Busy + Mic On</td>
      <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Mic.png" alt="In meeting, mic:on, video:off, screensharing:off" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Mic.png" alt="In meeting, mic:on, video:off, screensharing:off" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Mic.png" alt="In meeting, mic:on, video:off, screensharing:off" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Mic.png" alt="In meeting, mic:on, video:off, screensharing:off" height="16"></td>
    </tr>
    <tr>
      <td>Busy + Video On</td>
    <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Vid.png" alt="In meeting, mic:off, video:on, screensharing:off" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Vid.png" alt="In meeting, mic:off, video:on, screensharing:off" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Vid.png" alt="In meeting, mic:off, video:on, screensharing:off" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Vid.png" alt="In meeting, mic:off, video:on, screensharing:off" height="16"></td>
    </tr>
    <tr>
      <td>Busy + Screen Sharing</td>
      <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Screen.png" alt="In meeting, mic:off, video:off, screensharing:on" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Screen.png" alt="In meeting, mic:off, video:off, screensharing:on" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Screen.png" alt="In meeting, mic:off, video:off, screensharing:on" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Screen.png" alt="In meeting, mic:off, video:off, screensharing:on" height="16"></td>
    </tr>
    <tr>
      <td>Busy + Mic On + Video On</td>
      <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Mic-Vid.png" alt="In meeting, mic:on, video:on, screensharing:off" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Mic-Vid.png" alt="In meeting, mic:on, video:on, screensharing:off" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Mic-Vid.png" alt="In meeting, mic:on, video:on, screensharing:off" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Mic-Vid.png" alt="In meeting, mic:on, video:on, screensharing:off" height="16"></td>
    </tr>
    <tr>
      <td>Busy + Mic On + Screen Sharing</td>
      <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Mic-Screen.png" alt="In meeting, mic:on, video:off, screensharing:on" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Mic-Screen.png" alt="In meeting, mic:on, video:off, screensharing:on" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Mic-Screen.png" alt="In meeting, mic:on, video:off, screensharing:on" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Mic-Screen.png" alt="In meeting, mic:on, video:off, screensharing:on" height="16"></td>
    </tr>
    <tr>
      <td>Busy + Video On + Screen Sharing</td>
      <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Vid-Screen.png" alt="In meeting, mic:off, video:on, screensharing:on" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Vid-Screen.png" alt="In meeting, mic:off, video:on, screensharing:on" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Vid-Screen.png" alt="In meeting, mic:off, video:on, screensharing:on" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Vid-Screen.png" alt="In meeting, mic:off, video:on, screensharing:on" height="16"></td>
    </tr>
    <tr>
      <td>Busy + Mic On + Video On + Screen Sharing</td>
      <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Mic-Vid-Screen.png" alt="In meeting, mic:on, video:on, screensharing:on" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Mic-Vid-Screen.png" alt="In meeting, mic:on, video:on, screensharing:on" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Mic-Vid-Screen.png" alt="In meeting, mic:on, video:on, screensharing:on" height="16"></td>
<td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Mic-Vid-Screen.png" alt="In meeting, mic:on, video:on, screensharing:on" height="16"></td>
    </tr>
  </tbody>
</table>

# Credits
Microsoft Teams support was able to be added thanks to the [documentation of the local websocket api](https://github.com/svrooij/teams-monitor?tab=readme-ov-file#teams-has-a-local-api) by [@svrooij](https://github.com/svrooij)