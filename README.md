<img width="80" height="80" src="icon1.png" />

# Secure Input Sentry

### What this is

Compact menubar app that monitors for apps enabling (locking) macOS SecureInput. When locked, certain clipboard/snippet operations may fail. Notably things like clipboard/snippet managers (Alfred in my case!) or pasting from password managers. You might experience it as triggering a hotkey or snippet, but having nothing happen.

This app allows you to get a realtime visual indicator of when this condition is present, so you know what's going on, and to assist with troubleshooting.

Inspired by this bug: [macOS Secure Input not released after pressing Enter to submit login form (breaks system-wide hotkey [567613584] - Chromium](https://issues.chromium.org/issues/567613584)

More about SecureInput from Apple: [Technical Note TN2150: Using Secure Event Input Fairly](https://developer.apple.com/library/archive/technotes/tn2150/_index.html)

### Example

Here's an example of what you'll see when the app is running and SecureInput is triggered:

<img src="screen2_menu.png" />

### Run at startup

To keep the code simple, I didn't spend time bundling in automatic Startup Item registration via the normal `ServiceManagement/SMAppService`. To have the app automatically run on every login, simply drag it into your login item settings panel:

<img src="screen1.png" />

### Bugs

Yep, there might be some. Please report any issues!
