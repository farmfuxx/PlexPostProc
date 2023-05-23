# PlexPostProc

Plex PostProcessing Script for DVR(Beta), tested on Debian bullseye

This is a full re-write based on the most useful plex post-processing script I
found and tweaked or my own purposes.

Things I wanted:
- Detect and extract Closed Captions from Recordings
- Keep original resolution and framerate in transcodes

Things I did along the way:
- Remove lockfile workaround I don't think is needed any longer
- Refactored logging, reducing complexity
- Use ffprobe to automatically gather data about the input file

## Prereqs
- ccextractor
- ffmpeg
- jq


## Installation

First you will need to get the script onto your machine.  You can do this by cloning my git repository or simply downloading and placing in a directory of your choice.  

```
sudo apt-get update
sudo apt-get install git
git clone https://github.com/farmfuxx/PlexPostProc
cd PlexPostProc
cp PlexPostProc.sh /var/lib/plexmediaserver/Library/Application\ Support/Plex\ Media\ Server/Scripts/
```

Move the script inside `/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Scripts/`.
(Your destination may vary depending on platform)
[who names directories and files with spaces and punctuation...]
