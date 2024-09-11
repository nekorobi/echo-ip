#!/bin/bash
# echo-ip.sh
# MIT License © 2024 Nekorobi
version='1.0.0'
set -o pipefail
unset debug cmd check
ipv=-4  re='[0-9.]+'  run=dns  proto=tcp

help() {
  cat << END
Usage: ./echo-ip.sh [Option]...

Show public or private IP address.

Options:
  -4, --ipv4, -6, --ipv6
      IP version. Default: IPv4
  -D, --dns  (Default)
      Use DNS to show public IP.
      Default TCP. Use --dns-udp for UDP.
      Depends: dig or host command
  -g, --gateway
      Show default gateway address.
      Depends: \`ip route show default\`
  -H, --http
      Use HTTPS to show public IP.
      Depends: curl or wget command
  -s, --src
      Show IP to be routed to the Internet side.
      If VPN is enabled, the IP may differ from --src-gateway.
      Depends: \`ip route get PUBLIC_IP\`
  -S, --src-gateway
      Show IP to be routed to the --gateway.
      Depends: \`ip route get DEFAULT_GATEWAY\`

  -h, --help     Show help.
  -V, --version  Show version.

echo-ip.sh v$version
MIT License © 2024 Nekorobi
END
}

error() { echo -e "\e[1;31mError:\e[m $1" 1>&2; [[ $2 ]] && exit $2 || exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
  -c|--check)     [[ $# = 1 || $2 =~ ^- ]] && error "$1: requires an argument";;&
  -4|--ipv4)      ipv=-4  re='[0-9.]+'; shift 1;;
  -6|--ipv6)      ipv=-6  re='[0-9a-f:]+'; shift 1;;
  -D|--dns)       run=dns  cmd=dig; shift 1;;
  --dns-udp)      run=dns  cmd=dig  proto=notcp; shift 1;;
  -g|--gateway)   run=gateway; shift 1;;
  -H|--http)      run=http  cmd=curl; shift 1;;
  -s|--src)       run=src; shift 1;;
  -S|--src-gateway) run=srcGateway; shift 1;;
  #
  --debug)        debug=on; shift 1;;
  -c|--check)     run=checkIP  check=$2; shift 2;;
  --host)         cmd=host; shift 1;;
  --wget)         cmd=wget; shift 1;;
  -h|--help)      help; exit 0;;
  -V|--version)   echo echo-ip.sh $version; exit 0;;
  # ignore
  "") shift 1;;
  # invalid
  -*) error "$1: unknown option";;
  # Operand
  *) error "$1: unknown argument";;
  esac
done

dig=(
  "dig $ipv @ns1.google.com  o-o.myaddr.l.google.com TXT +short +$proto"
  "dig $ipv @resolver1.opendns.com  myip.opendns.com +short +$proto"
)

[[ $proto = tcp ]] && proto=T || proto=U
host=(
  "host $ipv -$proto -t txt o-o.myaddr.l.google.com  ns1.google.com"
  "host $ipv -$proto myip.opendns.com  resolver1.opendns.com"
)
api=(
  https://checkip.amazonaws.com  https://whatismyip.akamai.com
  https://api.ipify.org  https://ipinfo.io/ip
)
[[ $ipv = -6 ]] && api=(
  https://ipv6.whatismyip.akamai.com/  https://api6.ipify.org  https://v6.ipinfo.io/ip
)

isInt() { [[ $1 =~ ^(0|[1-9][0-9]*)$ && $1 -ge $2 && $1 -le $3 ]]; }
isIPv4() {
  [[ $1 =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
  for e in ${1//./ }; do isInt $e 0 255 || return 1; done
}
isIPv6() {
  [[ $1 =~ ^[0-9a-f:]+$ && ! $1 =~ ::[^:]+::|::: ]] || return 1
  if [[ $1 =~ :: ]]; then
    [[ $1 =~ ^(::[^:]{1,4}(:[^:]{1,4}){0,5}|([^:]{1,4}:){0,5}[^:]{1,4}::|[^:]{1,4}(::?[^:]{1,4}){1,6})$ ]]
  else
    [[ $1 =~ ^([^:]{1,4}:){7}[^:]{1,4}$ ]]
  fi
}
checkIP() {
  if [[ $ipv = -4 ]]; then isIPv4 "$1"; else isIPv6 "$1"; fi
  [[ $? = 0 ]] || return 1; echo $1
}

gateway() {
  checkIP "$(ip $ipv route show default | head -1 | sed -r 's/^.+ via ('$re') .+$/\1/')"
}
src() {
  local dest=1.1.1.1; [[ $ipv = -4 ]] || dest=2001:db8::
  checkIP "$(ip $ipv route get $dest | head -1 | sed -r 's/^.+ src ('$re') .+$/\1/')"  
}
srcGateway() {
  local dest; dest=$(gateway) || return 1
  checkIP "$(ip $ipv route get $dest | head -1 | sed -r 's/^.+ src ('$re') .+$/\1/')"
}
dns() {
  { type dig || type host; } >/dev/null 2>&1 || error 'require dig or host command' 3
  local cmdLine=("${dig[@]}")
  { type dig >/dev/null 2>&1 && [[ $cmd != host ]]; } || cmdLine=("${host[@]}")
  for e in "${cmdLine[@]}"; do
    [[ $debug ]] && echo -e "\n# $e"
    # example: o-o.myaddr.1.google.com descriptive text "1.2.3.4"
    #          myip.opendns.com has address 1.2.3.4
    checkIP "$(timeout 3 $e | tail -1 | sed -r 's/^(.+ )?\"?('$re')\"?$/\2/')" && [[ ! $debug ]] && return
  done
  [[ $debug ]] && return 0
}
http() {
  { type curl || type wget; } >/dev/null 2>&1 || error 'require curl or wget command' 3
  local args="$ipv --disable --fail --silent"
  { type curl >/dev/null 2>&1 && [[ $cmd != wget ]]; } || args="$ipv --quiet -O -"
  for e in "${api[@]}"; do
    [[ $debug ]] && echo -e "\n# $cmd $args $e"
    checkIP "$(timeout 3 $cmd $args $e)" && [[ ! $debug ]] && return
  done
  [[ $debug ]] && return 0
}

if [[ $run = checkIP ]]; then
  checkIP "$check" || exit 99
else
  if [[ $run =~ ^(gateway|src|srcGateway)$ ]]; then
    type ip >/dev/null 2>&1 || error 'require ip command' 3
  fi
  $run || error 'IP address not found' 9
fi
# error status: option 1, dependency 3, not found 9, --check 99
