#!/bin/sh
PAK_DIR="$(dirname "$0")"
PAK_NAME="$(basename "$PAK_DIR")"
PAK_NAME="${PAK_NAME%.*}"
[ -f "$USERDATA_PATH/$PAK_NAME/debug" ] && set -x

rm -f "$LOGS_PATH/$PAK_NAME.txt"
exec >>"$LOGS_PATH/$PAK_NAME.txt"
exec 2>&1

echo "$0" "$@"
cd "$PAK_DIR" || exit 1
mkdir -p "$USERDATA_PATH/$PAK_NAME"

architecture=arm
if [ uname -m | grep -q '64' ]; then
    architecture=arm64
fi

export HOME="$USERDATA_PATH/$PAK_NAME"
export LD_LIBRARY_PATH="$PAK_DIR/lib:$LD_LIBRARY_PATH"
export PATH="$PAK_DIR/bin/$architecture:$PAK_DIR/bin/$PLATFORM:$PAK_DIR/bin:$PATH"

add_game_to_recents() {
    FILEPATH="$1" GAME_ALIAS="$2"

    FILEPATH="${FILEPATH#"$SDCARD_PATH/"}"
    RECENTS="$SDCARD_PATH/.userdata/shared/.minui/recent.txt"
    if [ -f "$RECENTS" ]; then
        sed -i "#/$FILEPATH\t$GAME_ALIAS#d" "$RECENTS"
    fi

    rm -f "/tmp/recent.txt"
    printf "%s\t%s\n" "/$FILEPATH" "$GAME_ALIAS" >"/tmp/recent.txt"
    cat "$RECENTS" >>"/tmp/recent.txt"
    mv "/tmp/recent.txt" "$RECENTS"
}

get_rom_alias() {
    FILEPATH="$1"
    filename="$(basename "$FILEPATH")"
    filename="${filename%.*}"
    filename="$(echo "$filename" | sed 's/([^)]*)//g' | sed 's/\[[^]]*\]//g' | sed 's/[[:space:]]*$//')"
    echo "$filename"
}

get_emu_folder() {
    FILEPATH="$1"
    ROMS="$SDCARD_PATH/Roms"

    echo "${FILEPATH#"$ROMS/"}" | cut -d'/' -f1
}

get_emu_name() {
    EMU_FOLDER="$1"

    echo "$EMU_FOLDER" | sed 's/.*(\([^)]*\)).*/\1/'
}

get_emu_path() {
    EMU_NAME="$1"
    platform_emu="$SDCARD_PATH/Emus/$PLATFORM/${EMU_NAME}.pak/launch.sh"
    if [ -f "$platform_emu" ]; then
        echo "$platform_emu"
        return
    fi

    pak_emu="$SDCARD_PATH/.system/$PLATFORM/paks/Emus/${EMU_NAME}.pak/launch.sh"
    if [ -f "$pak_emu" ]; then
        echo "$pak_emu"
        return
    fi

    return 1
}

show_message() {
    message="$1"
    seconds="$2"

    if [ -z "$seconds" ]; then
        seconds="forever"
    fi

    killall minui-presenter >/dev/null 2>&1 || true
    echo "$message" 1>&2
    if [ "$seconds" = "forever" ]; then
        minui-presenter --message "$message" --timeout -1 &
    else
        minui-presenter --message "$message" --timeout "$seconds"
    fi
}

cleanup() {
    rm -f /tmp/stay_awake
    killall minui-presenter >/dev/null 2>&1 || true
}

main() {
    echo "1" >/tmp/stay_awake
    trap "cleanup" EXIT INT TERM HUP QUIT

    while true; do

        recents_list_file="/mnt/SDCARD/recents-list"
        display_list_file="/tmp/display-list"
        
        # Parse the recents list
        RECENTS="$SDCARD_PATH/.userdata/shared/.minui/recent.txt"
        cut -f2 "$RECENTS" > "$results_list_file"

        # Display Results

        total=$(cat "$results_list_file" | wc -l)
        if [ "$total" -gt 0 ]; then
            killall minui-presenter >/dev/null 2>&1 || true
            selection=$(minui-list --file "$results_list_file" --format text --title "Search: $SEARCH_TERM ($total results)")

            exit_code=$?
            
            if [ "$exit_code" -eq 0 ]; then

                linenum=$(grep -n "$selection" "$results_list_file" | cut -d: -f1)
                FILE=$(cat "$search_list_file" | head -n "$linenum" | tail -1)

                EMU_FOLDER=$(get_emu_folder "$FILE")
                EMU_NAME=$(get_emu_name "$EMU_FOLDER")
                EMU_PATH=$(get_emu_path "$EMU_NAME")
                ROM_ALIAS=$(get_rom_alias "$FILE")
                rm -f /tmp/stay_awake

                add_game_to_recents "$FILE" "$ROM_ALIAS"
                killall minui-presenter >/dev/null 2>&1 || true
                exec "$EMU_PATH" "$FILE"
            else
                >"$results_list_file"
                >"$search_list_file"
            fi
        else
            # No results found
            killall minui-presenter >/dev/null 2>&1 || true
            show_message "No recently played games found" 3
            break
        fi
    done
}

main "$@"
