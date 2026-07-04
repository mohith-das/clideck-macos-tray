#!/bin/bash

# Ensure we are in the script's directory
cd "$(dirname "$0")"

APP_NAME="CliDeck.app"
BUILD_DIR="./build"
APP_PATH="$BUILD_DIR/$APP_NAME"

echo "Building CliDeck launcher app..."

# Create app bundle structure
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Compile Swift code
swiftc launcher.swift -o "$APP_PATH/Contents/MacOS/CliDeck"

# Copy metadata and icon
cp Info.plist "$APP_PATH/Contents/Info.plist"
cp icon.icns "$APP_PATH/Contents/Resources/icon.icns"

# Invalidate icon cache for the built app
touch "$APP_PATH"

echo "✅ Built $APP_PATH successfully!"
echo "You can now drag this to your /Applications folder."
