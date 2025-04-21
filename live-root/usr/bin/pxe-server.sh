#! /bin/bash

SERVERSTARTED=""
SLEEP="10"

# initialize the /srv/tftpboot content
download-pxe-image.sh -i

while :; do
  echo "Reading NetworkManager configuration..."
  NMDATA=$(nmcli -t d)
  [ -n "$NMDATA" ] && break
  sleep 1
done

while read -r line; do
  DEVICE=$(echo "$line" | cut -d: -f1)
  TYPE=$(echo "$line" | cut -d: -f2)
  STATUS=$(echo "$line" | cut -d: -f3)
  CONNECTION=$(echo "$line" | cut -d: -f4-)

  # ignore loopback
  if [ "$TYPE" == "loopback" ]; then
    continue
  fi

  if [ "$TYPE" == "ethernet" ]; then
    if [ "$STATUS" == "connected" ]; then
      echo "$DEVICE - skipping, already connected"
    elif [ "$STATUS" == "unavailable" ]; then
      echo "$DEVICE - skipping, cable not connected"
    elif [[ "$STATUS" == connecting* ]]; then
      echo "$DEVICE - is connecting"
      # wait a bit, the DHCP server might be just slow to respond
      if [ "$SLEEP" -gt "0" ]; then
        echo "Waiting for possible DHCP reply..."
        sleep "$SLEEP"
        # sleep only once for all interfaces
        SLEEP="0"
      fi

      STATE=$(nmcli -t -f GENERAL.STATE device show "$DEVICE")
      if echo "$STATE" | grep -q \\bconnecting\\b; then
        # still not connected, switch the connection to the "shared" mode
        nmcli connection down "$CONNECTION" > /dev/null 2>&1
        nmcli connection modify "$CONNECTION" ipv4.method shared
        nmcli connection up "$CONNECTION" > /dev/null 2>&1

        if [ -z "$SERVERSTARTED" ]; then
          SERVERSTARTED="$DEVICE"
        else
          SERVERSTARTED="$SERVERSTARTED, $DEVICE"
        fi

        echo "PXE boot server started (device $DEVICE)"
      else
        # TODO: handle disconnected state, it is a temporary state before trying DHCP again
        echo "$DEVICE - skipping, not in connecting state anymore ($STATE)"
      fi
    elif [ "$STATUS" == "disconnected" ]; then
      echo "$DEVICE - skipping, disconnected device"
    else
      echo "$DEVICE - skipping, unknown status: $STATUS"
    fi
  else
    echo "$DEVICE - skipping, unsupported device type $TYPE"
  fi
done < <(echo "$NMDATA")

echo

if [ -z "$SERVERSTARTED" ]; then
  MSG="The PXE boot server was not started, see /srv/tftboot/README"
  echo "$MSG"
  printf "\\\\e{red}%s\\\\e{reset}\n" "$MSG" > /run/issue.d/80-pxe-server.issue
  exit 1
else
  MSG="The PXE boot server is running at $SERVERSTARTED"
  printf "\\\\e{green}%s\\\\e{reset}\n" "$MSG" > /run/issue.d/80-pxe-server.issue
  exit 0
fi
