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

add_new_collection() {
    # Add new collection
    SEARCH_TERM="$(minui-keyboard --title "Name" --show-hardware-group)"
    exit_code=$?
    if [ "$exit_code" -eq 2 ]; then
        >"$previous_search_file"
        return 2
    fi
    if [ "$exit_code" -eq 3 ]; then
        >"$previous_search_file"
        return 3
    fi
    if [ "$exit_code" -ne 0 ]; then
        show_message "Error entering search term" 2
        return 1
    fi
    echo "$SEARCH_TERM" > "$previous_search_file"
}

get_rom_alias() {
    file_path="$1"

    echo $file_path | sed \
        -e 's/^[^()]*(//' \
        -e 's/)[^/]*\//) /' \
        -e 's/\[[^]]*\]//g' \
        -e 's/([^)]*)//g' \
        -e 's/^/(/' \
        -e 's/\.[^.]*$//' \
        -e 's/[[:space:]]*$//'
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

get_input () {
    title="$1"
    initial_value="$2"

    result="$(minui-keyboard --title "$title" --show-hardware-group --initial-value "$initial_value")"
    exit_code=$?
    if [ "$exit_code" -eq 2 ]; then
        >"$previous_search_file"
        return 2
    fi
    if [ "$exit_code" -eq 3 ]; then
        >"$previous_search_file"
        return 3
    fi
    if [ "$exit_code" -ne 0 ]; then
        show_message "Error entering search term" 2
        return 1
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
        collections_dir="/mnt/SDCARD/Collections"
        menu_file="/tmp/collections-menu"

        find "$collections_dir" -type f -name "*txt" ! -name "map.txt" | sed -e "s|^$collections_dir/||" -e "s|\.txt$||" | jq -R -s 'split("\n")[:-1]' > "$collections_list_file"
   
        # Display Results
        selection=$(minui-list --file "$collections_list_file" --format json --write-value state --title "Collections" --action-button "X" --action-text "ADD NEW")
        exit_code=$?

        if [ "$exit_code" -eq 2 ] || [ "$exit_code" -eq 3 ]; then
            # User pressed B or MENU button
            return "$exit_code"
        elif [ "$exit_code" -eq 4 ]; then
            # Add new collection
            result="$(minui-keyboard --title "Add new collection" --show-hardware-group --disable-auto-sleep)"
            exit_code=$?
            if [ "$exit_code" -eq 0 ]; then
                filename=$(echo "$result" | sed 's/[^a-zA-Z0-9_]//g')
                if [ -z "$filename" ]; then
                    show_message "Invalid collection name!" 2
                else
                    if [ -f "$collections_dir"/"$filename".txt ]; then
                        show_message "Collection already exists" 2
                    else
                        touch "$collections_dir/$filename.txt"
                        show_message "Collection $filename created" 2
                    fi
                fi
            fi
        elif [ "$exit_code" -eq 0 ]; then
            # User selected item to edit
            selected_index="$(echo "$selection" | jq -r '.selected')"
            collection=$(echo "$selection" | jq -r '.""['"$selected_index"'].name')

            echo -e "Add game to collection|Add last played game to collection|Edit games in collection|Rename collection|Remove collection" | jq -R -s 'split("|")' > "$menu_file"
            selection=$(minui-list --file "$menu_file" --format json --write-value state --title "$collection" --disable-auto-sleep)
            exit_code=$?

            if [ "$exit_code" -eq 0 ]; then
                # User selected item to edit
                selected_index="$(echo "$selection" | jq -r '.selected')"

                case "$selected_index" in
                    0)
                        # Add game to collection
                        show_message "Add game to collection" 2
                        ;;
                    1)
                        # Add last played game to collection
                        recents_file="/mnt/SDCARD/.userdata/shared/.minui/recent.txt"
                        if [ -s "$recents_file" ]; then
                            show_message "No recent games" 2
                        else
                            # Get last played game
                            rom_path=$(head -n 1 "$recents_file" | cut -d$'\t' -f1)
                            rom_alias=$(head -n 1 "$recents_file"| cut -d$'\t' -f2)
                            
                            echo $rom_path >> "$collections_dir"/"$collection".txt
                            show_message "Added $rom_alias to collection $collection" 2
                        fi
                        ;;
                    2)
                        # Edit games in collection

                        while true; do
                            # Get ROMs
                            collections_games_list="/tmp/collection-games-list"
                            collections_dir="/mnt/SDCARD/Collections"

                            sed "$collections_dir"/"$collection".txt \
                                -e 's/^[^()]*(//' \
                                -e 's/)[^/]*\//) /' \
                                -e 's/\[[^]]*\]//g' \
                                -e 's/([^)]*)//g' \
                                -e 's/^/(/' \
                                -e 's/\.[^.]*$//' \
                                -e 's/[[:space:]]*$//' \
                                | jq -R -s 'split("\n")[:-1]' > "$collections_games_list"
                            
                            if [ ! -s "$collections_games_list" ]; then
                                show_message "No games in collection" 2
                                return 1
                            else                                
                                # Display Results
                                selection=$(minui-list --file "$collections_games_list" --format json --write-value state --title "$collection" --disable-auto-sleep)
                                exit_code=$?

                                if [ "$exit_code" -eq 2 ] || [ "$exit_code" -eq 3 ]; then
                                    # User pressed B or MENU button
                                    return "$exit_code"
                                elif [ "$exit_code" -eq 0 ]; then
                                    # User selected item to edit
                                    selected_index="$(echo "$selection" | jq -r '.selected')"

                                    echo -e "Remove game from collection" | jq -R -s 'split("|")' > "$menu_file"
                                    selection=$(minui-list --file "$menu_file" --format json --write-value state --title "$collection" --disable-auto-sleep)
                                    exit_code=$?

                                    if [ "$exit_code" -eq 0 ]; then
                                        # User selected item to edit
                                        selected_index2="$(echo "$selection" | jq -r '.selected')"

                                        case "$selected_index2" in
                                            0)
                                                # Remove game from collection
                                                selected_game=$(sed -n "$((selected_index + 1))p" "$collections_dir/$collection.txt")
                                                cp "$collections_dir"/"$collection".txt "$collections_dir"/"$collection".txt.bak
                                                sed -i "$(($selected_index + 1))d" "$collections_dir"/"$collection".txt
                                                show_message "Removed $selected_game" 2
                                                ;;
                                        esac 
                                    fi
                                fi
                            fi
                        done
                        ;;
                    3)
                        # Rename collection
                        result="$(minui-keyboard --title "Rename collection" --initial-value "$collection" --show-hardware-group --disable-auto-sleep)"
                        exit_code=$?
                        if [ "$exit_code" -eq 0 ]; then
                            filename=$(echo "$result" | sed 's/[^a-zA-Z0-9_]//g')
                            if [ -z "$filename" ]; then
                                show_message "Invalid collection name!" 2
                            else
                                if [ -f "$collections_dir"/"$filename".txt ]; then
                                    show_message "Collection already exists" 2
                                else
                                    mv "$collections_dir"/"$collection".txt "$collections_dir"/"$filename".txt
                                    show_message "Collection $collection renamed to $filename" 2
                                fi
                            fi
                        fi 
                        ;;
                    4)
                        # Delete collection
                        mv "$collections_dir"/"$collection".txt "$collections_dir"/"$collection".txt.bak
                        show_message "Collection renamed to $collection.txt.bak" 2
                        ;;
                esac 
            fi
        fi
    done
}

main "$@"
