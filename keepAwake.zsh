#!/bin/zsh

#region Comments
#   Script Name:        keepAwake
#   Script Version:     1.0.1
#   Author:             VARE Consulting
#   Requires:           swiftDialog
#   Purpose:            This script is used to keep the computer awake for a selected amount of time.
#   Returns:            0 - Success
#                       1 - User selected to quit
#endregion Comments

#region Functions
# convertTime: Used to convert seconds into readable-time
function convertTime() {
    local _time=$1
    local _days=$((_time/60/60/24))
    local _hours=$((_time/60/60%24))
    local _minutes=$((_time/60%60))
    local _seconds=$((_time%60))

    [[ $_days -gt 0 ]] && [[ $_days -ge 2 ]] && printf '%d days ' $_days
    [[ $_days -gt 0 ]] && [[ $_days -eq 1 ]] && printf '%d day ' $_days

    [[ $_hours -gt 0 ]] && [[ $_hours -ge 2 ]] && printf '%d hours ' $_hours
    [[ $_hours -gt 0 ]] && [[ $_hours -eq 1 ]] && printf '%d hour ' $_hours

    [[ $_minutes -gt 0 ]] && [[ $_minutes -ge 2 ]] && printf '%d minutes ' $_minutes
    [[ $_minutes -gt 0 ]] && [[ $_minutes -eq 1 ]] && printf '%d minute ' $_minutes

    [[ $_seconds -gt 0 ]] && [[ $_seconds -ge 2 ]] && printf '%d seconds ' $_seconds
    [[ $_seconds -gt 0 ]] && [[ $_seconds -eq 1 ]] && printf '%d second ' $_seconds

    printf '\n'
}
#endregion Functions

#region Variables
# Currently logged on user
loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Name of the script without the zsh extension
scriptName="${$(basename $0)//.zsh}"
scriptVersion="1.0.1"

# LaunchAgent label
serviceIdentifier="com.vare.${scriptName}"

# Setting plist - used to load settings from an MDM
settingsPlist="/Library/Preferences/${serviceIdentifier}"

# LaunchAgent path
launchAgent="/Users/${loggedInUser}/Library/LaunchAgents/${serviceIdentifier}.plist"

# Last exit code
lastExitCode=0
#endregion Variables

#region Load Settings/Defaults
#region Read values from preferences
# Read the durationOptions key, sort and split string using "," as the delim
durationOptions=(${(@Os;,;)$(defaults read "${settingsPlist}" durationOptions 2>&1)})
button1text=$(defaults read "${settingsPlist}" button1text 2>&1)
button2text=$(defaults read "${settingsPlist}" button2text 2>&1)
icon=$(defaults read "${settingsPlist}" icon 2>&1)
message=$(defaults read "${settingsPlist}" message 2>&1)
width=$(defaults read "${settingsPlist}" height 2>&1)
height=$(defaults read "${settingsPlist}" width 2>&1)
noValidation=$(defaults read "${settingsPlist}" noValidation 2>&1)
#endregion Read values from preferences

#region durationOptions
# Ensure pause time options are present
if [[ ${#durationOptions[@]} -ge 1 ]] && [[ ${durationOptions[@]} != *"not exist"* ]]; then
    # Declare the pauseTimes associative array to store the pause times
    declare -A pauseTimes

    # Iterate through durationOptions, converting duration values from seconds to a read-able
    # format and storing them in the pauseTimes associative array using the current option as the key
    for opt in ${durationOptions[@]}; do; pauseTimes[$opt]="$(convertTime $opt)"; done

    echo "Detected the \"durationOptions\" key, using \"${(vj;, ;)pauseTimes}\" as duration options."
else
    declare -A pauseTimes=(
        [900]="15 Minutes" [3600]="1 Hour" [7200]="2 Hours"
        [14400]="4 Hours" [10800]="8 Hours" [86400]="1 day"
    )
    echo "Using the default duration values \"${(vj;, ;)pauseTimes}\"."
fi
#endregion durationOptions

#region button1text
if [[ "${button1text}" != *"not exist"* ]]; then
    echo "Detected the \"button1text\" key, using \"${button1text}\" as the value for the primary button."
else
    button1text="Enter to Proceed"
    echo "Using \"${button1text}\" for the primary button."
fi
#endregion button1text

#region button2text
if [[ "${button2text}" != *"not exist"* ]]; then
    echo "Detected the \"button2text\" key, using \"${button2text}\" as the value for the secondary button."
else
    button2text="Quit"
    echo "Using \"${button2text}\" for the primary button."
fi
#endregion button2text

#region icon
if [[ "${icon}" != *"not exist"* ]]; then
    echo "Detected the \"icon\" key, using \"${icon}\" for the displayed icon."
else
    icon="SF=clock,palette=yellow,white,none"
    echo "Using the default value \"${icon}\" for the displayed icon."
fi
#endregion icon

#region message
if [[ "${message}" != *"not exist"* ]]; then
    echo "Detected the \"message\" key, using \"${message}\" for the displayed message."
else
    message="Please select a duration from the drop-down menu below."
    echo "Using the default value \"${message}\" for the displayed message."
fi
#endregion message

#region width
if [[ "${width}" != *"not exist"* ]]; then
    echo "Detected the \"width\" key, setting the prompt width to ${width}."
else
    width=300
    echo "Using the default value \"${message}\" for the prompt width."
fi
#endregion width

#region height
if [[ "${height}" != *"not exist"* ]]; then
    echo "Detected the \"height\" key, setting the prompt height to ${height}."
else
    height=300
    echo "Using the default value \"${height}\" for the prompt height."
fi
#endregion height

#endregion Load Settings/Defaults

#region Main

#region Prompt

# Sort values for drop-down maneu by using time in seconds
sortedValues=()
for key in ${(kon)pauseTimes}; do sortedValues+=("$pauseTimes[$key]"); done
defaultValue="$(echo "${sortedValues[1]}" | xargs)"

echo "Prompting \"${loggedInUser}\" to select a duration from the drop-down menu (default option: \"${defaultValue}\") ..."
# Prompt user and capture input and return code 300X300
durationChosen=$( 
    /usr/local/bin/dialog \
    --ontop \
    --moveable \
    --height ${height} \
    --width ${width} \
    --title none \
    --icon "${icon}" \
    --iconsize 200 \
    --centreicon \
    --messagealignment center \
    --messageposition center \
    --message "${message}" \
    --button1text "${button1text}" \
    --button2text "${button2text}" \
    --selecttitle "Duration,required" \
    --selectvalues "${(j;,;)sortedValues}" \
    --selectdefault "${defaultValue}" \
    --buttonstyle "center" \
    --infotext "${scriptVersion}" \
    | grep "SelectedOption" | awk -F ": " '{print $NF}' | sed 's/\"//g'
)
promptResult=$?
#endregion Prompt

if [[ $promptResult -eq 0 ]] && [[ -n $durationChosen ]]; then
    echo "\"${loggedInUser}\" selected \"${durationChosen}\" from the drop-down menu !!!"
    # Get time in seconds using the selected time
    for key value in ${(kv)pauseTimes}; do [[ $durationChosen == $value ]] && durationInSeconds=$key; done

    #region LaunchAgent
    # Create user launchagent path
    if [[ ! -d "$(dirname $launchAgent)" ]]; then
        echo "The \"$(dirname $launchAgent)\" path does not exist, creating path !!!"
        mkdir -p "$(dirname $launchAgent)"
    fi

    # Remove any previous LaunchAgents
    if [[ -f "${launchAgent}" ]]; then
        echo "Removing the previous ${serviceIdentifier} service !!!"
        launchctl bootout gui/$(id -u $loggedInUser)/${serviceIdentifier} 2> /dev/null
        launchctl disable gui/$(id -u $loggedInUser)/${serviceIdentifier} 2> /dev/null
        echo "Removing the previous LaunchAgent from \"${launchAgent}\" !!!"
        rm -rf "${launchAgent}"
    fi

    # Create a LaunchAgent to run the caffeinate command using the selected duration
    echo "Creating the \"${launchAgent}\" LaunchAgent  ..."
    /usr/libexec/PlistBuddy -c "Add :Label string '${serviceIdentifier}'" "${launchAgent}" 1> /dev/null
    /usr/libexec/PlistBuddy -c "Add :LaunchOnlyOnce bool 1" "${launchAgent}"
    /usr/libexec/PlistBuddy -c "Add :UserName string '${loggedInUser}'" "${launchAgent}"
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments array" "${launchAgent}"
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments:0 string '/bin/zsh'" "${launchAgent}"
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments:1 string '-c'" "${launchAgent}"
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments:2 string '/usr/bin/caffeinate -disu -t ${durationInSeconds}'" "${launchAgent}"
    [[ -f "${launchAgent}" ]] && echo "Created the \"${launchAgent}\" LaunchAgent  !!!"

    # Set the permissions for the LaunchAgent
    echo "Setting the LaunchAgent permissions ..."
    chown $(id -u $loggedInUser):$(id -g $loggedInUser) "${launchAgent}"
    chmod 755 "${launchAgent}"

    # Enable and start the LaunchAgent service
    echo "Creating the ${serviceIdentifier} service ..."
    launchctl enable gui/$(id -u $loggedInUser)/${serviceIdentifier}
    launchctl bootstrap gui/$(id -u $loggedInUser) "${launchAgent}"
    launchctl kickstart -kp gui/$(id -u $loggedInUser)/${serviceIdentifier} 1> /dev/null

    #endregion LaunchAgent

    #region Validation
    # Validate caffeinate command is in background and display success message
    if ps aux | grep "caffeinate -disu -t ${durationInSeconds}" -q; then
        echo "Successfully created ${serviceIdentifier} service !!!"
        /usr/local/bin/dialog \
        --ontop \
        --moveable \
        --height 300 \
        --width 300 \
        --title none \
        --icon "SF=clock.badge.checkmark,palette=green,white,none" \
        --iconsize 200 \
        --centreicon \
        --messagealignment center \
        --messageposition center \
        --message "Computer will stay awake for *${durationChosen}* !!!" \
        --button1text "OK" \
        --buttonstyle "center" \
        --timer 30 \
        --hidetimerbar
        echo "Keeping computer awake for ${durationChosen} !!!"
        lastExitCode=0
    else
        lastExitCode=1
    fi
    #endregion Validation
else
    echo "User selected to quit!"
    lastExitCode=2
fi

exit $lastExitCode
#endregion Main