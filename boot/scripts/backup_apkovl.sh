#!/bin/sh
set -e

LIVE="/srv/http/apkovl"
BACKUP="/var/lib/infrastructure/boot/apkovl"
RECIPIENT="internet@csc.tcd.ie"
PATTERN="*.*.tar.*"

echo "Starting backup..."

for path in $(find "$BACKUP" -name "$PATTERN"); do
	f="$(basename $path | sed 's/\.gpg//')"
	if [ -z $(find "$LIVE" -name "$f") ]; then
		echo "Deleting old backup $f.gpg"
		rm "$path"
	fi
done

for path in $(find "$LIVE" -name "$PATTERN"); do
	f="$(basename $path)"

	if [ -f "$BACKUP/$f.gpg" ] && gpg -q --decrypt "$BACKUP/$f.gpg" 2>/dev/null | cmp --silent "$path"; then
		echo "$f is up to date, skipping..."
		continue
	fi

	echo "Encrypting and backing up $f"
	rm -f "$BACKUP/$f.gpg"

	gpg -o "$BACKUP/$f.gpg" -r "$RECIPIENT" --sign --encrypt "$path"
done

cd "$BACKUP"
echo "Committing changes..."
git add .
git commit -m "boot/apkovl backup @ $(date)"
git push
