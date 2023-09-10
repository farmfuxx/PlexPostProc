#!/bin/bash

#******************************************************************************
#******************************************************************************
#
#            Plex DVR Post Processing Script
#
#******************************************************************************
#******************************************************************************
#
#  Version: 2023.5.22 (forked by farmfuxx)
#
#  Pre-requisites:
#     ccextractor
#     ffmpeg (required) with libx265
#     jq
#
#  Usage:
#     'PlexPostProc.sh %1'
#
#  Log:
#     Single log is generated with timestamped transcodes.

#     Note: Logs are not deleted, so some cleanup of the temp directory may be
#       required, or a server reboot should clear this folder.
#
#******************************************************************************

VIDEO_CODEC="libx265"
PRESET="medium"

#******************************************************************************
#  Do not edit below this line
#******************************************************************************

set -x
set -e
set -o pipefail

TMPDIR="/tmp"
LOGFILE="$TMPDIR/plex_DVR_post_processing_log"
FILENAME=$1  # %FILE% - Filename of original file

function usage
{
  echo
  echo "Usage: $0 <INPUT_FILE>"
  echo
}

if [ ! -x "$(which jq)" ]; then
  echo "Error: no jq executable available in path"
  exit 1
fi

if [ ! -x "$(which ccextractor)" ]; then
  echo "Error: no ccextractor executable available in path"
  exit 1
fi

if [ -z "$FILENAME" ]; then
  echo "Error: File argument missing"
  usage
  exit 2
fi

if [ ! -r "$FILENAME" ]; then
  echo "Error: input file ($FILENAME) is unreadable"
  usage
  exit 1
fi

FILESIZE="$(ls -lh "$FILENAME" | awk '{ print $5 }')"

function cleanup
{
  set +e # turn off 'exit on error' during cleanup.
  if [ -f "$WORKDIR"/video_stream.json ]; then rm "$WORKDIR"/video_stream.json; fi
  if [ -f "$TEMPFILENAMESRT" ]; then rm "$TEMPFILENAMESRT"; fi
  if [ -f "$TEMPFILENAME" ]; then rm "$TEMPFILENAME"; fi
  if [ -d "$WORKDIR" ]; then rmdir $WORKDIR; fi
}
trap cleanup EXIT

function log_line
{
  echo "$(date +"%Y%m%d-%H%M%S"): $$ $1" | tee -a "$LOGFILE"
}

WORKDIR="$(mktemp -d "$TMPDIR"/ppp.work.XXXXXXX)"
TEMPFILENAME="$WORKDIR"/output.mkv
TEMPFILENAMESRT="$WORKDIR"/sub.srt

log_line "querying input $FILENAME (in_size=$FILESIZE)"

ffprobe "$FILENAME" -loglevel quiet -print_format json \
    -select_streams v:0 -show_streams > "$WORKDIR"/video_stream.json

CLOSED_CAPTIONS="$(cat "$WORKDIR"/video_stream.json | jq -r '.["streams"][0]["closed_captions"]')"

log_line "input details: CC=$CLOSED_CAPTIONS"

# Extract Closed Captions:
if [[ "$CLOSED_CAPTIONS" -eq "1" ]]; then
  ccextractor "$FILENAME" -o "$TEMPFILENAMESRT" --no_progress_bar
  CC_OPTS="-i $TEMPFILENAMESRT"
fi

ffmpeg -loglevel warning -nostats -i "$FILENAME" -map 0 $CC_OPTS \
    -c:v "$VIDEO_CODEC" -preset $PRESET -vf yadif \
    -c:a copy \
    "$TEMPFILENAME"

log_line "finished writing $TEMPFILENAME (out_size=$(ls -lh $TEMPFILENAME | awk '{ print $5 }'))"

# ********************************************************"
# Encode Done. Performing Cleanup
# ********************************************************"

rm -f "$FILENAME" # Delete original in .grab folder

mv -f "$TEMPFILENAME" "${FILENAME%.ts}.mkv" # Move completed tempfile to .grab folder/filename
