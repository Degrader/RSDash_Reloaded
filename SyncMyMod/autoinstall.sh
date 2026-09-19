#!/bin/sh
#####################################################################################################################################################################
#                                                                  Installation Script for RSdash                                                                   #
######################################################################################################################################################################
#                                                                                                                                                                    #
#                                                                                                                                                                    #
#                                         JJJJJJJJJJ                 BBBBBBBBBB                                                                                      #
#                                         JJJJJJJJJJ                 BB      BBB                                                                                     #
#                                         JJJJJJJJJJ                 BB       BBB                                                                                    #
#                                              JJ JJ                 BB        BB                                                                                    #
#                                              JJ JJ                 BB        BB                                                                                    #
#                                              JJ JJ                 BB       BBB                                                                                    #
#                                              JJ JJ                 BB      BB       ooooooo      nn        nn    eeeeeeee                                          #
#                                              JJ JJ  ------------   BBBBBBBBBB      ooo   ooo     nnn       nn   ee      eee                                        #
#                                              JJ JJ  ------------   BB      BBB    oo       oo    nnnn      nn   ee       ee                                        #
#                                              JJ JJ                 BB       BBB   oo       oo    nn nn     nn   eeeeeeeeeee                                        #
#                                              JJ JJ                 BB        BB   oo       oo    nn  nn    nn   ee                                                 #
#                                      JJ      JJ JJ                 BB        BB   oo       oo    nn   nn   nn   ee                                                 #
#                                      JJJ     JJJJJ                 BB       BBB   oo       oo    nn    nn  nn   ee       ee                                        #
#                                      JJJJ   JJJJJ                  BB      BBB    oo       oo    nn     nn nn   eee     ee                                         #
#                                       JJJJJJJJJJ                   BBBBBBBBBB      ooo   ooo     nn      nnnn    eeeeeeee                                          #
#                                        JJJJJJJ                                      ooooooo      nn       nnn                                                      #
#                                                                                                                                                                    #
######################################################################################################################################################################

# App Name      : RSdash
# Author        : Au{R}oN (www.fmods.net)
# Creation date : 2025-10-03
# Version       : 2.3

#########################################################################################################################################################
#                                                                 Custom App Variables                                                                  #
#########################################################################################################################################################

APP_AUTHOR="auron89"             # FOLDER NAME USED TO GROUP APPS OF THE SAME DEVELOPER. NO SPACE OR SPECIAL CHARS ALLOWED!!
APP_NAME="RSdash"                # VISIBLE DURING INSTALLATION PROCESS AND FROM APPS LOADER. ALL CHARS ALLOWED BUT SOME SPECIAL CHARS MAY CAUSE ISSUES
APP_FOLDER="rsdash"              # APP FOLDER. NO SPACE OR SPECIAL CHARS ALLOWED!!
APP_FILE="Nutron.qml"            # MAIN APP FILE. NO SPACE OR SPECIAL CHARS ALLOWED, FIRST LETTER MUST BE IN UPPERCASE!!
APP_HIDETITLE="true"             # USED TO DEFINE IF TITLEBAR MUST REMAIN VISIBLE OR NOT. ONLY TRUE OR FALSE ALLOWED!!

AUTHOR="Au{R}oN - www.fmods.net" # DEVELOPER NAME VISIBLE DURING THE INSTALLATION PROCESS. ALL CHARS ALLOWED BUT SOME SPECIAL CHARS MAY CAUSE ISSUES

#########################################################################################################################################################
#                                                                 Environment variables                                                                 #
#########################################################################################################################################################

PATH=/fs/rwdata/dev:$PATH

APIM_APPS_PATH=/fs/mp/fordhmi/qml/hmicustomapps/apps
APIM_JSON_PATH=/fs/mp/fordhmi/qml/hmicustomapps/apps.json
LOCAL_APP_PATH=/fs/usb0/SyncMyMod/app/

DISPLAY=/fs/tmpfs/status
POPUP=/tmp/popup.txt

FILES_DIR="/fs/usb0/SyncMyMod/files"
OTHER_DIR="${FILES_DIR}/other"

# FMods Tools entries
MODTOOLS="FMODS_TOOLS"
MIN_MODTOOLS_VERSION="2.8"

DEPENDENCY="CUSTOM_APPS_LOADER"

VERSION=$(cat "${LOCAL_APP_PATH}"/version.txt)
PREV_VERSION=$(cat "${APIM_APPS_PATH}"/"${APP_AUTHOR}"/"${APP_FOLDER}"/version.txt)

#########################################################################################################################################################
#                                                                       Functions                                                                       #
#########################################################################################################################################################

output() {
    echo "${1}" > "$DISPLAY"
	sleep "${2}"
}

progress() {
    echo "PROGRESS ${1}" > "$DISPLAY"
}

displayMessage() {
    echo "${1}" >> "$POPUP"
    utserviceutility popup "$POPUP"
	
	exit 0
}

installationTerminated() {
	while [ -e /fs/usb0 ]; do
		sleep 1
	done

	output "REBOOT" 3
	exit 0
}

#########################################################################################################################################################
#                                                           Check if FMods Tools are installed                                                          #
#########################################################################################################################################################

if ! grep -q "${MODTOOLS}" /fs/rwdata/dev/mods_tools.txt; then
    displayMessage "FMods Tools not found. Installation aborted."
else
    LINE=$(grep "$MODTOOLS" /fs/rwdata/dev/mods_tools.txt)
    MODS_TOOLS_VERSION=$(echo "$LINE" | awk -F'_' '{print $NF}')
    
    if ! awk 'BEGIN {exit !('"$MODS_TOOLS_VERSION"' >= '"$MIN_MODTOOLS_VERSION"') }'; then
        displayMessage "FMods Tools ${MIN_MODTOOLS_VERSION} or higher not found. Installation aborted."
    fi
fi

#########################################################################################################################################################
#                                                                Launch Installer Utility                                                               #
#########################################################################################################################################################

cp -r ${OTHER_DIR}/images/* /tmp
sleep 1

instutility &
sleep 2

output "DEV ${APP_NAME} v${VERSION} - Developed by ${AUTHOR}" 2

#########################################################################################################################################################
#                                                       Check if Custom Apps Loader is installed                                                        #
#########################################################################################################################################################

progress 5
output "Checking if Custom Apps Loader is installed..." 2

if ! grep -q ${DEPENDENCY} /fs/mp/etc/installed_mods.txt; then
	output "ERROR Custom Apps Loader not installed. Please install it."
	installationTerminated
fi

#########################################################################################################################################################
#                                                                    Remount FS as RW                                                                   #
#########################################################################################################################################################

progress 15
output "Setting RW permissions to FS..." 1
remount_rw.sh
sleep 1

#########################################################################################################################################################
#                                                                    Adding APP entry                                                                   #
#########################################################################################################################################################

progress 20
output "Detecting previous ${APP_NAME} installation..." 2

if [ -z "$(jq -r --arg appName "${APP_NAME}" '.apps[] | select(.appName == $appName) | .appName' "$APIM_JSON_PATH")" ]; then
    progress 35
    output "Previous installation not detected. Adding JSON entry for Apps Launcher..." 2
    mkdir -p "${APIM_APPS_PATH}"/"${APP_AUTHOR}"/"${APP_FOLDER}"

    jq --arg appName "${APP_NAME}" \
       --arg appAuthor "${APP_AUTHOR}" \
       --arg appFolder "${APP_FOLDER}" \
       --arg appFile "${APP_FILE}" \
       --arg appIcon "${APP_AUTHOR}"/"${APP_FOLDER}"/Icon \
       --argjson appHideTitle "${APP_HIDETITLE}" \
       '.apps += [{"appName": $appName, "appFile": "\($appAuthor)/\($appFolder)/\($appFile)", "appIcon": $appIcon, "appHideTitle": $appHideTitle}]' \
       "$APIM_JSON_PATH" > /tmp/tmp.json
    mv /tmp/tmp.json "$APIM_JSON_PATH"
else
    progress 45
    output "Previous ${APP_NAME} version ${PREV_VERSION} detected." 2
fi

#########################################################################################################################################################
#                                                                    Copying new files                                                                  #
#########################################################################################################################################################

progress 60
output "Copying files..." 2
cp -R "${LOCAL_APP_PATH}"/*	"${APIM_APPS_PATH}"/"${APP_AUTHOR}"/"${APP_FOLDER}"
progress 62
mkdir -p /fs/rwdata/fmods
mv "${APIM_APPS_PATH}"/"${APP_AUTHOR}"/"${APP_FOLDER}"/NutronConfig.ini /fs/rwdata/fmods

#########################################################################################################################################################
#                                                                   Remount FS as RO                                                                    #
#########################################################################################################################################################

progress 80
output "Setting RO permissions to FS..." 1
remount_ro.sh
sync
sync
sync

#########################################################################################################################################################
#                                                           Display success image and reboot                                                            #
#########################################################################################################################################################

progress 100
output "Installation completed. Please remove the USB stick to reboot."
installationTerminated
