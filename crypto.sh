#! /usr/bin/env bash

openssl enc -d -p -aes-256-cbc -pbkdf2 -salt -in htb.tar.gz.enc -out htb.tar.gz -pass env:$DECRYPT_KEY && rm htb.tar.gz.enc

tar -xvzf htb.tar.gz && rm htb.tar.gz