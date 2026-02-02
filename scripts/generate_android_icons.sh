#!/bin/bash

# Configuration
SOURCE_LOGO="/Users/copernicus/Documents/synapsai/synapse/public/logo_backup.png"
FOREGROUND_SOURCE="/Users/copernicus/Documents/synapsai/synapse/public/android_foreground_master.png"
RES_DIR="/Users/copernicus/Documents/synapsai/saber/android/app/src/main/res"

# Densities and sizes (Legacy Launcher, Foreground)
# Format: density:launcher_size:foreground_size
DENSITIES=(
    "mdpi:48:108"
    "hdpi:72:162"
    "xhdpi:96:216"
    "xxhdpi:144:324"
    "xxxhdpi:192:432"
)

echo "Generating Android app icons from sources..."
echo "Legacy Source: $SOURCE_LOGO"
echo "Foreground Source: $FOREGROUND_SOURCE"

for entry in "${DENSITIES[@]}"; do
    IFS=":" read -r density l_size f_size <<< "$entry"
    DIR="$RES_DIR/mipmap-$density"
    
    echo "Processing $density..."
    
    # 1. Generate Legacy Launcher Icon (Full-bleed)
    sips -z $l_size $l_size "$SOURCE_LOGO" --out "$DIR/ic_launcher.png" > /dev/null
    
    # 2. Generate Round Launcher Icon
    cp "$DIR/ic_launcher.png" "$DIR/ic_launcher_round.png"
    
    # 3. Generate Adaptive Foreground Icon (Padded)
    # The FOREGROUND_SOURCE already has the correct padding built-in.
    sips -z $f_size $f_size "$FOREGROUND_SOURCE" --out "$DIR/ic_launcher_foreground.png" > /dev/null
    
    # 4. Generate Monochrome Icon (Foreground copy)
    cp "$DIR/ic_launcher_foreground.png" "$DIR/ic_launcher_monochrome.png"
done

echo "Done! Icons refreshed."
