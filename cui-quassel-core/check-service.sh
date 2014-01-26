#!/bin/bash
# ----------------------------------------------------------------------------
# To use the script, create a link with the following schema:
# <service>.[start|stop|status]

scriptName=$0
service=${scriptName%.*}
service=${service##*/}
parameter=${scriptName##*.}

echo "'$scriptName' -> '$service' '$parameter'"

rc-service ${service} ${parameter}
