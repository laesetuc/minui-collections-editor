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

add_new_collection() {
    # Add new collection
    result="$(minui-keyboard --title "Add new collection" --show-hardware-group)"
    exit_code=$?
    if [ "$exit_code" -eq 0 ]; then
        filename=$(echo "$result" | sed 's/[^a-zA-Z0-9_]//g')
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

add_game_to_collection() {
    # Add game to collection
    show_message "Add game to collection" 2
}

add_recent_to_collection() {
    # Add last played game to collection
    recents_file="/mnt/SDCARD/.userdata/shared/.minui/recent.txt"
    if [ ! -s "$recents_file" ]; then
        show_message "No recent games" 2
    else
        # Get last played game
        rom_path=$(head -n 1 "$recents_file" | cut -d$'\t' -f1)
        rom_alias=$(head -n 1 "$recents_file"| cut -d$'\t' -f2)
        
        echo $rom_path >> "$collection_file"
        show_message "Added $rom_alias to collection $collection" 2
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
                                        
            # Display Results
            selection=$(minui-list --file "$collections_games_list" --format json --write-value state --title "$collection")
            exit_code=$?

            if [ "$exit_code" -eq 2 ] || [ "$exit_code" -eq 3 ]; then
                # User pressed B or MENU button
                break
            elif [ "$exit_code" -eq 0 ]; then
                # User selected item to edit
                selected_index="$(echo "$selection" | jq -r '.selected')"

                # Display Sub Menu
                echo -e "Remove game from collection" | jq -R -s 'split("|")' > "$menu_file"
                selection=$(minui-list --file "$menu_file" --format json --write-value state --title "$collection")
                exit_code=$?

                if [ "$exit_code" -eq 0 ]; then
                    # User selected item to edit
                    selected_index2="$(echo "$selection" | jq -r '.selected')"

                    case "$selected_index2" in
                        0)
                            # Remove game from collection
                            selected_game=$(sed -n "$((selected_index + 1))p" "$collection_file")
                            cp "$collection_file" "$collections_dir"/"$collection".disabled
                            sed -i "$(($selected_index + 1))d" "$collection_file"
                            show_message "Removed $selected_game" 2
                            ;;
                    esac
                fi
            fi
        fi
    done
}

rename_collection() {
    # Rename collection
    result="$(minui-keyboard --title "Rename collection" --initial-value "$collection" --show-hardware-group)"
    exit_code=$?
    if [ "$exit_code" -eq 0 ]; then
        filename=$(echo "$result" | sed 's/[^a-zA-Z0-9_]//g')
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
    mv "$collection_file" "$collections_dir"/"$collection".disabled
    show_message "Collection renamed to $collection.disabled" 2
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
        collections_dir="/mnt/SDCARD/Collections"
        menu_file="/tmp/collections-menu"

        find "$collections_dir" -type f -name "*txt" ! -name "map.txt" | sed -e "s|^$collections_dir/||" -e "s|\.txt$||" | jq -R -s 'split("\n")[:-1]' > "$collections_list_file"
   
        # Display List of Collections
        selection=$(minui-list --file "$collections_list_file" --format json --write-value state --title "Collections" --action-button "X" --action-text "ADD NEW")
        exit_code=$?

        if [ "$exit_code" -eq 2 ] || [ "$exit_code" -eq 3 ]; then
            # User pressed B or MENU button
            break
        elif [ "$exit_code" -eq 4 ]; then
            # Add new collection
            add_new_collection

        elif [ "$exit_code" -eq 0 ]; then
            # User selected item to edit
            selected_index="$(echo "$selection" | jq -r '.selected')"
            collection=$(echo "$selection" | jq -r '.""['"$selected_index"'].name')
            collection_file="$collections_dir"/"$collection".txt

            while true; do
                echo -e "Add game to collection|Add last played game to collection|Edit games in collection|Rename collection|Remove collection" | jq -R -s 'split("|")' > "$menu_file"
                selection=$(minui-list --file "$menu_file" --format json --write-value state --title "$collection")
                exit_code=$?

                if [ "$exit_code" -eq 2 ] || [ "$exit_code" -eq 3 ]; then
                    # User pressed B or MENU button
                    break
                elif [ "$exit_code" -eq 0 ]; then
                    # User selected item to edit
                    selected_index="$(echo "$selection" | jq -r '.selected')"

                    case "$selected_index" in
                        0)
                            # Add game to collection
                            add_game_to_collection
                            ;;
                        1)
                            # Add last played game to collection
                            add_recent_to_collection
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
