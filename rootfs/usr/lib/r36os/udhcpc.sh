#!/bin/sh
prefix() {
  n=0
  ancien=$IFS
  IFS=.
  for o in $1; do
    case $o in
      255) n=$((n + 8)) ;;
      254) n=$((n + 7)) ;;
      252) n=$((n + 6)) ;;
      248) n=$((n + 5)) ;;
      240) n=$((n + 4)) ;;
      224) n=$((n + 3)) ;;
      192) n=$((n + 2)) ;;
      128) n=$((n + 1)) ;;
      0) ;;
    esac
  done
  IFS=$ancien
  echo "$n"
}

case "$1" in
  bound|renew)
    masque=$(prefix "$subnet")
    ip addr flush dev "$interface" 2>/dev/null || true
    ip addr add "$ip/$masque" dev "$interface"
    ip link set "$interface" up
    if [ -n "$router" ]; then
      ip route add default via "$router" 2>/dev/null || true
    fi
    : > /etc/resolv.conf
    for s in $dns; do
      echo "nameserver $s" >> /etc/resolv.conf
    done
    ;;
esac
