#!/bin/bash
set -euo pipefail

driverName="Saraswati"  # <- Update this if your custom driver base name changes
devTeamID="" # ⚠️ Replace if signing, else leave blank
notarize=false # To skip notarization, set this to false
notarizeProfile="notarize" # ⚠️ Only used if notarizing

# Basic Validation
if [ ! -d BlackHole.xcodeproj ]; then
    echo "This script must be run from the BlackHole repo root folder."
    echo "For example:"
    echo "  cd /path/to/BlackHole"
    echo "  ./Uninstaller/create_uninstaller.sh"
    exit 1
fi

mkdir -p Uninstaller/Scripts

for channels in 2 16 64 128 256; do

    variantName="${driverName}${channels}ch"
    driverPath="/Library/Audio/Plug-Ins/HAL/${variantName}.driver"

    # create postinstall script to remove driver
    cat <<EOF > Uninstaller/Scripts/postinstall
#!/bin/bash

file="${driverPath}"

if [ -d "\$file" ] ; then
    sudo rm -R "\$file"
    sudo killall coreaudiod
fi
EOF

    chmod 755 Uninstaller/Scripts/postinstall

    # Build .pkg
    packageName="Uninstaller/${variantName}-Uninstaller.pkg"
    pkgbuild --nopayload --scripts Uninstaller/Scripts \
      --identifier "audio.existential.${variantName}.Uninstaller" \
      $packageName

    # Notarize and Staple if needed
    if [ "$notarize" = true ]; then
        output=$(xcrun notarytool submit "$packageName" --progress --wait --keychain-profile "$notarizeProfile" 2>&1 | tee /dev/tty)
        submission_id=$(echo "$output" | grep -o -E 'id: [a-f0-9-]+' | awk '{print $2}' | head -n1)
        if [ -z "$submission_id" ]; then
            echo "Failed to extract submission ID. ❌"
            exit 1
        fi
        if echo "$output" | grep -q "status: Invalid"; then
            echo "Error detected during notarization: Submission Invalid ❌"
            echo -e "\nFetching logs for submission ID: $submission_id"
            xcrun notarytool log --keychain-profile "$notarizeProfile" "$submission_id"
            exit 1
        else
            echo "Notarization submitted successfully ✅"
        fi
        xcrun stapler staple "$packageName"
    fi

done

rm -f Uninstaller/Scripts/postinstall
