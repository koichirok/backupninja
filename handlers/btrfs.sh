#!/bin/bash -e

# remove old snapshots if one does alredy exists
if [ -e /media/volume-fsn1-1/snapshots/files ]; then
   echo "Clearing out /media/volume-fsn1-1/snapshots..."
   btrfs subvolume delete -C /media/volume-fsn1-1/snapshots/*
fi

echo "Starting snapshot of files at subvolume 'files'..."
btrfs subvolume snapshot -r /media/volume-fsn1-1/files /media/volume-fsn1-1/snapshots/
