#!/bin/bash

#******************************************************************************
#******************************************************************************
#
#            Plex DVR Post Processing Script
#
#******************************************************************************
#******************************************************************************
#
#  Version: 2022.2.7 (forked by apassiou)
#
#  Pre-requisites:
#     ffmpeg (required) with libx265
#
#  Usage:
#     'PlexPostProc.sh %1'
#
#  Description:
#      My script is currently pretty simple.  Here's the general flow:
#
#      1. Creates a temporary directory in the /tmp directory for
#      the show it is about to transcode.
#
#      2. Uses the selected encoder to transcode the original, very
#      large MPEG2 format file to a smaller, more manageable x265 mkv file
#      (which can be streamed to various devices more easily).
#
#      3. Copies the file back to the original location for final processing
#
#  Log:
#     Single log is generated with timestamped transcodes.

#     Note: Logs are not deleted, so some cleanup of the temp directory may be
#       required, or a server reboot should clear this folder.
#
#******************************************************************************

TMPFOLDER="/tmp"
RES="720"         # Resolution to convert to:
                  # "480" = 480 Vertical Resolution
                  # "720" = 720 Vertical Resolution
                  # "1080" = 1080 Vertical Resolution


AUDIO_CODEC="ac3" # From best to worst: libfdk_aac > libmp3lame/eac3/ac3 > aac. But libfdk_acc requires manual compilaton of ffmpeg. For OTA DVR standard acc should be enough.
AUDIO_BITRATE=96
VIDEO_CODEC="libx265" # Will need Ubuntu 18.04 LTS or later. Otherwise change to "libx264". On average libx265 should produce files half in size of libx264  without losing quality. It is more compute intensive, so transcoding will take longer.
VIDEO_QUALITY=26 #Lower values produce better quality. It is not recommended going lower than 18. 26 produces around 1Mbps video, 23 around 1.5Mbps.
VIDEO_FRAMERATE="24000/1001" #Standard US movie framerate, most US TV shows run at this framerate as well

DOWNMIX_AUDIO=2 #Number of channels to downmix to, set to 0 to turn off (leave source number of channels, but make sure to increase audio bitrate to accomodate all the needed bitrate. For 5.1 Id set no lower than 320). 1 == mono, 2 == stereo, 6 == 5.1

#******************************************************************************
#  Do not edit below this line
#******************************************************************************
check_errs()
{
        # Function. Parameter 1 is the return code
        # Para. 2 is text to display on failure
        if [ "${1}" -ne "0" ]; then
           echo "ERROR # ${1} : ${2}" | tee -a $LOGFILE
           exit ${1}
        fi
}

   FILENAME=$1  # %FILE% - Filename of original file

function usage
{
  echo
  echo "Usage: $0 <INPUT_FILE>"
  echo
}

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

   RANDFILENAME="$(mktemp)"  # Base random name, will be used for cleanup
   rm -f "$RANDFILENAME" #Cleanup mktemp artifact
   TEMPFILENAME="$RANDFILENAME.mkv"  # Temporary File Name for transcoding

   LOGFILE="$TMPFOLDER/plex_DVR_post_processing_log"
   touch $LOGFILE # Create the log file

   # Uncomment if you want to adjust the bandwidth for this thread
   #MYPID=$$    # Process ID for current script
   # Adjust niceness of CPU priority for the current process
   #renice 19 $MYPID

   # ********************************************************
   # Starting Transcoding
   # ********************************************************

   LOG_STRING_1="\n$(date +"%Y%m%d-%H%M%S"): Transcoding $FILENAME to $TEMPFILENAME\n"
   if [[ PPP_CHECK -eq 0 ]]; then
     printf "$LOG_STRING_1" | tee -a $LOGFILE
   fi
     LOG_STRING_2="Using FFMPEG"
     LOG_STRING_3=" [$FILESIZE -> "
     if [[ PPP_CHECK -eq 0 ]]; then
         printf "$LOG_STRING_2$LOG_STRING_3" | tee -a $LOGFILE
     fi
     start_time=$(date +%s)
     if [[ $DOWNMIX_AUDIO -ne  0 ]]; then
         ffmpeg -i "$FILENAME" -s hd$RES -c:v "$VIDEO_CODEC" -r "$VIDEO_FRAMERATE"  -preset veryfast -crf "$VIDEO_QUALITY" -vf yadif -codec:a "$AUDIO_CODEC" -ac "$DOWNMIX_AUDIO" -b:a "$AUDIO_BITRATE"k -async 1 "$TEMPFILENAME"
     else
         ffmpeg -i "$FILENAME" -s hd$RES -c:v "$VIDEO_CODEC" -r "$VIDEO_FRAMERATE"  -preset veryfast -crf "$VIDEO_QUALITY" -vf yadif -codec:a "$AUDIO_CODEC" -b:a "$AUDIO_BITRATE"k -async 1 "$TEMPFILENAME"
     fi
     end_time=$(date +%s)
     seconds="$(( end_time - start_time ))"
     minutes_taken="$(( seconds / 60 ))"
     seconds_taken="$(( $seconds - (minutes_taken * 60) ))"
     LOG_STRING_4="$(ls -lh $TEMPFILENAME | awk ' { print $5 }')] - [$minutes_taken min $seconds_taken sec]\n"
     check_errs $? "Failed to convert using FFMPEG."

   # ********************************************************"
   # Encode Done. Performing Cleanup
   # ********************************************************"

   LOG_STRING_5="$(date +"%Y%m%d-%H%M%S"): Finished transcode,"
   printf "$LOG_STRING_4$LOG_STRING_5" | tee -a $LOGFILE

   rm -f "$FILENAME" # Delete original in .grab folder
   check_errs $? "Failed to remove original file: $FILENAME"

   mv -f "$TEMPFILENAME" "${FILENAME%.ts}.mkv" # Move completed tempfile to .grab folder/filename
   check_errs $? "Failed to move converted file: $TEMPFILENAME"
