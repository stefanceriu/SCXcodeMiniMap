# SCXcodeMiniMap

SCXcodeMiniMap is a plugin that adds a source editor MiniMap to Xcode.

![SCXcodeMiniMap](https://dl.dropboxusercontent.com/u/12748201/SCXcodeMiniMap.png)

## Features
- It works with an unlimited number of opened editors, including the assistant and version editors
- The minimap and its selection view scroll seamlessly with the editor and provide a nice way of figuring out the current position in the document
- Full syntax highlighting
- It blends with the currently selected theme 
- Size configurable via the kDefaultZoomLevel parameter (defaults to 10% out of the editor's size)

- Tested on OS X 10.7.5 Xcode 4.6(4H127) and OS X 1.8.3 Xcode 4.6.2(4H1003)

## Installation
- Build the project and restart Xcode

- If you encounter any issues you can uninstall it by removing the ~/Library/Application Support/Developer/Shared/Xcode/Plug-ins/SCXcodeMinimap.xcplugin folder

##Known issues
- Line breaks don't match between the normal editor and the minimap
- It doesn't update automatically on theme changes (switching between sources fixes it) 
 
## License
SCXcodeMiniMap is released under the GNU GENERAL PUBLIC LICENSE (see the LICENSE file)

## Contact
Any suggestions or improvements are more than welcome. Feel free to contact me at [stefan.ceriu@yahoo.com](mailto:stefan.ceriu@yahoo.com) or [@stefanceriu](https://twitter.com/stefanceriu).