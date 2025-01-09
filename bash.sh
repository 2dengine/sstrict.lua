#!/bin/bash
clear

sudo apt install lua5.3
lua validate.lua

exit $?