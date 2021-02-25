#!/bin/sh
set -e

LIVE="/srv/http/apkovl"
BACKUP="/var/lib/infrastructure/boot/apkovl"
RECIPIENT="internet@csc.tcd.ie"
PATTERN="*.*.tar.*"

echo "Starting backup..."
find "$BACKUP" -name "$PATTERN" -exec rm {} \;

for path in $(find "$LIVE" -name "$PATTERN"); do
	f="$(basename $path)"
	echo "Encrypting and backing up $f"

	gpg -o "$BACKUP/$f.gpg" -r "$RECIPIENT" --sign --encrypt "$path"
done

cd "$BACKUP"
echo "Committing changes..."
git add .
git commit -m "boot/apkovl backup @ $(date)"
git push
