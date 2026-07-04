# CliDeck macOS Tray Plugin

A lightweight, native macOS menu bar integration for [CliDeck](https://clideck.dev/). Keep an eye on your AI coding agents without leaving your current window.

![CliDeck Logo](icon.png)

## Features

- **Menu Bar Icon:** The CliDeck logo sits right in your Mac's menu bar.
- **Live Status:** Click the icon to see exactly which agents are working (🟢) and which are idle (⚪).
- **Quick Access:** Open the CliDeck dashboard in your default browser with one click.
- **Native Notifications:** Get a macOS desktop notification when an agent finishes its work and becomes idle.
- **Quit CliDeck:** Easily shut down the CliDeck server directly from the tray.

## Installation

### Option 1: Via CliDeck Plugins Directory (Recommended)
1. Open your CliDeck dashboard (`http://localhost:4000`).
2. Go to the **Plugins** panel (circuit icon in the sidebar).
3. Find **macOS Menu Bar** in the community directory and click **Install**.

### Option 2: Manual Installation
1. Clone this repository into your CliDeck plugins directory:
   ```bash
   cd ~/.clideck/plugins
   git clone https://github.com/mohith-das/clideck-macos-tray.git macos-tray
   ```
2. Install the dependencies:
   ```bash
   cd macos-tray
   npm install
   ```
3. Restart CliDeck.

## Settings

You can configure the plugin directly from the CliDeck Plugins panel:
- **Show Menu Bar Icon (Toggle):** Enable or disable the menu bar tray icon at any time without restarting the server.

## Requirements

- macOS
- Node.js (running CliDeck)

## How it works

This plugin uses the standard CliDeck Plugin API. It runs entirely on the backend using `systray` and `node-notifier` to render native UI components without requiring a heavy Electron wrapper.
