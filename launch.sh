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
if [[ "$(uname -m)" == *"64"* ]]; then
    architecture=arm64
fi

export HOME="$USERDATA_PATH/$PAK_NAME"
export LD_LIBRARY_PATH="$PAK_DIR/lib:$LD_LIBRARY_PATH"
export PATH="$PAK_DIR/bin/$architecture:$PAK_DIR/bin/$PLATFORM:$PAK_DIR/bin:$PATH"

add_game_to_collection() {
    FILEPATH="$1" COLLECTION="$2"

    FILEPATH="${FILEPATH#"$SDCARD_PATH/"}"
    COLLECTIONFILE="$SDCARD_PATH/Collections/$COLLECTION.txt"

    echo "$FILEPATH" >> "$COLLECTIONFILE"
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


        # Get Collections
        collections_list_file="/tmp/collections-list"
        collection_dir="/mnt/SDCARD/Collections"

        find "$collection_dir" -type f -name "*.txt" > "$collections_list_file"
        
        # Display Results
        killall minui-presenter >/dev/null 2>&1 || true
        selection=$(minui-list --file "$collections_list_file" --format text --title "Collections")
        exit_code=$?
            
        if [ "$exit_code" -eq 0 ]; then

        fi
    done
}

main "$@"
