#!/bin/bash
cd ${0%/*}; set -e
echo test.sh:
script=../echo-ip.sh

if [[ $1 != -6 ]]; then
  echo '--ipv4 --check'
  err=(10.1.1.1. 01.1.1.1 10.0.0.256 +1.1.1.1  1.1.1  1.1.1.1.1 a.a.a.a 1:1:1:1)
  for e in "${err[@]}"; do $script --check "$e" || continue; echo "$e"; false; done
  ok=(0.0.0.0 255.255.255.255)
  for e in "${ok[@]}"; do $script --check "$e" >/dev/null && continue; echo "$e"; false; done

  echo '--ipv4'
  $script --ipv4
  echo '--ipv4 --dns'
  $script --ipv4 --dns
  $script --ipv4 --dns --host
  echo '--ipv4 --dns-udp'
  $script --ipv4 --dns-udp
  $script --ipv4 --dns-udp --host
  echo '--ipv4 --http'
  $script --ipv4 --http
  $script --ipv4 --http --wget
  echo '--ipv4 --gateway'
  $script --ipv4 --gateway
  echo '--ipv4 --src'
  $script --ipv4 --src
  echo '--ipv4 --src-gateway'
  $script --ipv4 --src-gateway
fi

if [[ $1 != -4 ]]; then
  echo '-6 --check'
  err=(:: ::: 1::2:: :1: :1 1:  1:2:3:4:5:6:7 1:2:3:4:5:6:7:8:9 1:2:3:4:5:6:7::8 ffff1:: g:)
  for e in "${err[@]}"; do $script -6 --check "$e" || continue; echo "$e"; false; done
  ok=(1:2:3:4:5:6:7:8 1:2:3:4:5:6::7 1:2:3:4:5::6f 1::2 1:: ::1 ffff:: 2001:db8::)
  for e in "${ok[@]}"; do $script -6 --check "$e" >/dev/null && continue; echo "$e"; false; done

  echo '--ipv6'
  $script --ipv6
  echo '--ipv6 --dns'
  $script --ipv6 --dns
  $script --ipv6 --dns --host
  echo '--ipv6 --dns-udp'
  $script --ipv6 --dns-udp
  $script --ipv6 --dns-udp --host
  echo '--ipv6 --http'
  $script --ipv6 --http
  $script --ipv6 --http --wget
  echo '--ipv6 --gateway'
  $script --ipv6 --gateway 2>/dev/null || echo 'default gateway not found'
  echo '--ipv6 --src'
  $script --ipv6 --src
  echo '--ipv6 --src-gateway'
  $script --ipv6 --src-gateway 2>/dev/null || echo 'default gateway not found'
fi

echo success: test.sh
