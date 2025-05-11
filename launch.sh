#!/bin/sh
PAK_DIR="$(dirname "$0")"
PAK_NAME="$(basename "$PAK_DIR")"
PAK_NAME="${PAK_NAME%.*}"
 set -x

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

get_rom_alias() {
    filepath="$1"
    filename="$(basename "$filepath")"
    filename="${filename%.*}"
    filename="$(echo "$filename" | sed -e 's/([^)]*)//g' -e 's/\[[^]]*\]//g' -e 's/[[:space:]]*$//')"
    echo "$filename"
}

add_new_collection() {
    # Add new collection
    minui-keyboard --title "Add new collection" --show-hardware-group --write-location "$minui_output_file" --disable-auto-sleep
    exit_code=$?
    if [ "$exit_code" -eq 0 ]; then
        output=$(cat "$minui_output_file" 2>/dev/null)
        filename=$(echo "$output" | sed 's/[^a-zA-Z0-9_]//g')
        new_collection_file="$collections_dir"/"$filename".txt

        if [ -z "$filename" ]; then
            show_message "Invalid collection name!" 2
        else
            if [ -f "$new_collection_file" ]; then
                show_message "Collection already exists" 2
            else
                touch "$new_collection_file"
                show_message "Collection $filename created" 2
            fi
        fi
    fi
}

select_game_to_add() {
    # Display list of games to add and get selection
    sed "$search_list_file" \
        -e 's/^[^(]*(/(/' \
        -e 's/)[^/]*\//) /' \
        -e 's/[[:space:]]*$//' \
        | jq -R -s 'split("\n")[:-1]' > "$results_list_file"

    minui-list --file "$results_list_file" --format json --write-location "$minui_output_file" --write-value state --disable-auto-sleep --title "Search: $search_term ($total results)"
    exit_code=$?
    if [ "$exit_code" -eq 0 ]; then
        output=$(cat "$minui_output_file" 2>/dev/null)
        selected_index4="$(echo "$output" | jq -r '.selected')"
        file=$(sed -n "$((selected_index4 + 1))p" "$search_list_file")

        filepath="${file#"$SDCARD_PATH"}"
        rom_alias=$(get_rom_alias "$file")

        if grep -q "$filepath" "$collection_file"; then
            show_message "Game already in collection" 2
        else

            echo "$filepath" >> "$collection_file"
            show_message "Added $rom_alias to $collection" 2
        fi
    else
        >"$results_list_file"
        >"$search_list_file"
    fi
}

search_game_to_collection() {
    # Add game to collection
    search_list_file="/tmp/search-list"
    results_list_file="/tmp/results-list"

    # Get search term
    minui-keyboard --title "Search" --initial-value "$search_term" --show-hardware-group --write-location "$minui_output_file" --disable-auto-sleep 
    exit_code=$?
    if [ "$exit_code" -eq 2 ] || [ "$exit_code" -eq 3 ]; then
        >"$previous_search_file"
        break
    fi
    if [ "$exit_code" -ne 0 ]; then
        show_message "Error entering search term" 2
        break
    fi
    search_term=$(cat "$minui_output_file" 2>/dev/null)

    # Perform search
    show_message "Searching..."

    find "/mnt/SDCARD/Roms" -type f ! -path '*/\.*' -iname "*$search_term*" ! -name '*.txt' ! -name '*.log' > "$search_list_file"
    total=$(cat "$search_list_file" 2>/dev/null | wc -l)

    if [ "$total" -eq 0 ]; then
        show_message "Could not find any games." 2
    else
        select_game_to_add
    fi
}

add_game_to_collection() {
    emu_raw_file="/tmp/emu-raw"
    emu_list_file="/tmp/emu-list"
    search_list_file="/tmp/search-list"
    results_list_file="/tmp/results-list"

    find "/mnt/SDCARD/Roms" -type f ! -path '*/\.*' ! -name '*.txt' ! -name '*.log' | awk -F "/" '{print $5}' | sort -u > "$emu_raw_file"
    cat "$emu_raw_file" | jq -R -s 'split("\n")[:-1]' > "$emu_list_file"
    total=$(cat "$emu_list_file" 2>/dev/null | wc -l)

    if [ "$total" -eq 0 ]; then
        show_message "Could not find any games." 2
    else
        while true; do
            minui-list --file "$emu_list_file" --format json --write-location "$minui_output_file" --write-value state --title "Add Games" --disable-auto-sleep
            exit_code=$?

            if [ "$exit_code" -eq 2 ] || [ "$exit_code" -eq 3 ]; then
                # User pressed B or MENU button
                break
            elif [ "$exit_code" -eq 0 ]; then
                # User selected item to edit
                output=$(cat "$minui_output_file")
                selected_index="$(echo "$output" | jq -r '.selected')"
                selected_emu=$(sed -n "$((selected_index + 1))p" "$emu_raw_file")

                find "/mnt/SDCARD/Roms/$selected_emu" -type f ! -path '*/\.*' ! -name '*.txt' ! -name '*.log' > "$search_list_file"
                total=$(cat "$search_list_file" 2>/dev/null | wc -l)

                if [ "$total" -eq 0 ]; then
                    show_message "Could not find any games." 2
                else
                    select_game_to_add
                fi
            fi
        done
    fi
}

add_recents_to_collection() {
    # Add game from recents list to collection
    recents_file="/mnt/SDCARD/.userdata/shared/.minui/recent.txt"
    search_list_file="/tmp/search-list"
    results_list_file="/tmp/results-list"

    if [ ! -s "$recents_file" ]; then
        show_message "No recent games" 2
    else
        search_term="Recents"
        cut -d$'\t' -f1 "$recents_file" > "$search_list_file"
        total=$(cat "$search_list_file" 2>/dev/null | wc -l)

        if [ "$total" -eq 0 ]; then
            show_message "Could not find any games." 2
        else
            select_game_to_add
        fi
    fi
}

edit_games_in_collection() {
    # Edit games in collection
    while true; do
        # Get ROMs
        collections_games_list="/tmp/collection-games-list"
        
        if [ ! -s "$collection_file" ]; then
            show_message "Collection is empty" 2
            break
        else
            # Get games in collection
            sed "$collection_file" \
                -e 's/^[^()]*(//' \
                -e 's/)[^/]*\//) /' \
                -e 's/\[[^]]*\]//g' \
                -e 's/([^)]*)//g' \
                -e 's/^/(/' \
                -e 's/\.[^.]*$//' \
                -e 's/[[:space:]]*$//' \
                | jq -R -s 'split("\n")[:-1]' > "$collections_games_list"
                                        
            # Display Games List
            minui-list --file "$collections_games_list" --format json --write-location "$minui_output_file" --write-value state --title "$collection" --disable-auto-sleep
            exit_code=$?

            if [ "$exit_code" -eq 2 ] || [ "$exit_code" -eq 3 ]; then
                # User pressed B or MENU button
                break
            elif [ "$exit_code" -eq 0 ]; then
                # User selected item to edit
                output=$(cat "$minui_output_file")
                selected_index="$(echo "$output" | jq -r '.selected')"
                selected_game=$(sed -n "$((selected_index + 1))p" "$collection_file")

                # Display Sub Menu
                echo -e "Remove game from collection|Copy game to other collection" | jq -R -s 'split("|")' > "$menu_file"
                minui-list --file "$menu_file" --format json --write-location "$minui_output_file" --write-value state --title "$collection" --disable-auto-sleep
                exit_code=$?

                if [ "$exit_code" -eq 0 ]; then
                    # User selected item to edit
                    output=$(cat "$minui_output_file" 2>/dev/null)
                    selected_index2="$(echo "$output" | jq -r '.selected')"

                    case "$selected_index2" in
                        0)
                            # Remove game from collection
                            cp "$collection_file" "$collection_file".disabled
                            grep -v "$selected_game" "$collection_file".disabled > "$collection_file"
                            rom_alias=$(get_rom_alias "$selected_game")
                            show_message "Removed $rom_alias from $collection" 2
                            ;;
                        1)
                            # Copy game to other collection
                            select_collection
                            exit_code=$?
                            if [ "$exit_code" -eq 0 ]; then
                                output=$(cat "$minui_output_file" 2>/dev/null)
                                selected_index3="$(echo "$output" | jq -r '.selected')"
                                new_collection=$(echo "$output" | jq -r '.""['"$selected_index3"'].name')

                                echo "$selected_game" >> "$collections_dir"/"$new_collection".txt
                                rom_alias=$(get_rom_alias "$selected_game")
                                show_message "Added $rom_alias to collection $new_collection" 2
                            fi
                            ;;
                    esac
                fi
            fi
        fi
    done
}

rename_collection() {
    # Rename collection
    minui-keyboard --title "Rename collection" --initial-value "$collection" --show-hardware-group --write-location "$minui_output_file" --disable-auto-sleep
    exit_code=$?
    if [ "$exit_code" -eq 0 ]; then
        output=$(cat "$minui_output_file" 2>/dev/null)
        filename=$(echo "$output" | sed 's/[^a-zA-Z0-9_]//g')
        new_collection_file="$collections_dir"/"$filename".txt

        if [ -z "$filename" ]; then
            show_message "Invalid collection name!" 2
        else
            if [ -f "$new_collection_file" ]; then
                show_message "Collection already exists" 2
            else
                mv "$collection_file" "$new_collection_file"
                show_message "Collection $collection renamed to $filename" 2
            fi
        fi
    fi    
}

delete_collection() {
    # Delete collection
    mv "$collection_file" "$collection_file".disabled
    show_message "Collection renamed to $collection.disabled" 2
}

select_collection() {
    # Display list of collections and get selection
    show_add_button="$1"
    find "$collections_dir" -type f -name "*txt" ! -name "map.txt" | sort -f > "$collections_raw_file" 
    sed -e "s|^$collections_dir/||" -e "s|\.txt$||" "$collections_raw_file" | jq -R -s 'split("\n")[:-1]' > "$collections_list_file"

    if [ "$show_add_button" = "add" ]; then
        minui-list --file "$collections_list_file" --format json --write-location "$minui_output_file" --write-value state --title "Collections" --disable-auto-sleep --action-button "X" --action-text "ADD NEW" 
    else
        minui-list --file "$collections_list_file" --format json --write-location "$minui_output_file" --write-value state --title "Collections" --disable-auto-sleep
    fi    
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
    rm -f "$collections_list_file"
    rm -f "$collections_raw_file"
    rm -f "$menu_file"
    rm -f "$collections_games_list"
    rm -f "$minui_output_file"

    killall minui-presenter >/dev/null 2>&1 || true
}

main() {
    echo "1" >/tmp/stay_awake
    trap "cleanup" EXIT INT TERM HUP QUIT

    collections_list_file="/tmp/collections-list"
    collections_raw_file="/tmp/collections-raw"
    collections_dir="/mnt/SDCARD/Collections"
    menu_file="/tmp/collections-menu"
    minui_output_file="/tmp/minui-output"

    while true; do
        # Get Collections
        select_collection "add"
        exit_code=$?

        if [ "$exit_code" -eq 2 ] || [ "$exit_code" -eq 3 ]; then
            # User pressed B or MENU button
            break
        elif [ "$exit_code" -eq 4 ]; then
            # Add new collection
            add_new_collection

        elif [ "$exit_code" -eq 0 ]; then
            # User selected item to edit
            output=$(cat "$minui_output_file" 2>/dev/null)
            selected_index="$(echo "$output" | jq -r '.selected')"
            collection=$(echo "$output" | jq -r '.""['"$selected_index"'].name')
            collection_file=$(sed -n "$((selected_index + 1))p" "$collections_raw_file")

            while true; do
                echo -e "Add game to collection|Add from recents to collection|Edit games in collection|Rename collection|Remove collection" | jq -R -s 'split("|")' > "$menu_file"
                minui-list --file "$menu_file" --format json --write-location "$minui_output_file" --write-value state --title "$collection" --disable-auto-sleep
                exit_code=$?

                if [ "$exit_code" -eq 2 ] || [ "$exit_code" -eq 3 ]; then
                    # User pressed B or MENU button
                    break
                elif [ "$exit_code" -eq 0 ]; then
                    # User selected item to edit
                    output=$(cat "$minui_output_file" 2>/dev/null)
                    selected_index="$(echo "$output" | jq -r '.selected')"

                    case "$selected_index" in
                        0)
                            # Add game to collection
                            add_game_to_collection
                            ;;
                        1)
                            # Add last played game to collection
                            add_recents_to_collection
                            ;;
                        2)
                            # Edit games in collection
                            edit_games_in_collection
                            ;;
                        3)
                            # Rename collection
                            rename_collection
                            break
                            ;;
                        4)
                            # Delete collection
                            delete_collection
                            break
                            ;;
                    esac 
                fi
            done
        fi
    done
}

main "$@"
