#!/bin/bash

INTERFACE=$(ip route | grep default | awk '{print $5}')
GATEWAY=$(ip route | grep default | awk '{print $3}')


echo 
echo "-=-=- Network Information -=-=-"
echo
echo "-Network Interface-"
echo "$INTERFACE"
echo

echo "-Local IP-"
ip addr show "$INTERFACE" | grep inet | awk '{print $2}'
echo

echo "-Default Gateway-"
echo "$GATEWAY"
echo

echo "-Pinging Gateway-"
ping -c 3 "$GATEWAY"
echo

echo "-DNS Resolution Test (google.com)-"
host google.com
echo

echo "-Ports and Services-"
# switch to ss below if lsof unavailable (may need adjustments)
lsof -i -P -n | grep -E 'LISTEN|UDP' | awk '{
    # This regex removes everything up to the LAST colon or bracket-colon
    port=$9; sub(/.*[:\]]/, "", port);
    printf "%-8s %-10s %-20s\n", $8, port, $1
}' | sort -u | column -t

# ss -luntp | grep -v "Netid" | awk '{
#     # Target the local address field and extract the port
#     split($4, a, ":"); port=a[length(a)];
#     
#     # Hunt for the column containing "users:" to handle shifted columns
#     process="Unknown";
#     for(i=5; i<=NF; i++) if($i ~ /users:/) process=$i;
#     
#     printf "%-8s %-10s %-20s\n", $1, port, process
# }' | sort -V | column -t
echo