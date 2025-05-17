# minui-collections-editor
A utility for editing MinUI game collections

## Requirements

This pak is designed for and tested with the following MinUI Platforms and devices:

- `tg5040`: Trimui Brick (formerly `tg3040`)

## Installation

1. Mount your MinUI SD card.
2. Download the latest [release](https://github.com/laesetuc/minui-collections-editor/releases) from GitHub.
3. Copy the zip file to the correct platform folder in the "/Tools" directory on the SD card.
4. Extract the zip in place, then delete the zip file.
5. Confirm that there is a `/Tools/$PLATFORM/Collections Editor.pak/launch.sh` file on your SD card.
6. Unmount your SD Card and insert it into your MinUI device.

Note: The platform folder name is based on the name of your device. For example, if you are using a TrimUI Brick, the folder is "tg5040". Alternatively, if you're not sure which folder to use, you can copy the .pak folders to all the platform folders.

## Usage

### Main Screen

The list of collections is displayed.
- Press X to add a new collection.
- Press A to edit the selected collection.

### Collection Screen

The list of games in the collection is displayed.
- Press X to edit the selected collection.
- Press A to edit the selected game.

### Edit Collection

A list of options is displayed.
- Add game to collection: find games to add to the collection.
- Add recents game to collection: add a recently played game to the collection.
- Sort collection: sort games in the collection alphabetically.
- Rename collection: change the name of the collection.
- Delete collection: remove the collection (collection will be named <collection.disabled>)

### Edit Game

A list of options is displayed.
- Remove game from collection: removes selected game from the collection.
- Copy game to other collection: copies selected game to another collection.


## Acknowledgements

- [MinUI](https://github.com/shauninman/MinUI) by Shaun Inman
- [minui-keyboard](https://github.com/josegonzalez/minui-keyboard), [minui-list](https://github.com/josegonzalez/minui-list) and [minui-presenter](https://github.com/josegonzalez/minui-presenter) by Jose Diaz-Gonzalez
- Also, thank you, Jose Diaz-Gonzalez, for your pak repositories, which this project is based on.

## License

This project is released under the MIT License. For more information, see the [LICENSE](LICENSE) file.
