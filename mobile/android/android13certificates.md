---
layout: post
permalink: /mobile/android/android13certificates
title: Android 13 or Lower - Certificate Installation
description: >-
  How to intercept and manipulate Android 13 or lower traffic using Burp Suite.
author: richsphinx
date: 2024-12-11
categories: [Android, Offensive Security, Mobile Pentesting]
tags: [Android]
media_subpath: '/assets/img/mobile/android/'
image:
  path: /androidCert.png
  alt: Certificate Installation on Android 13 or lower
---

# Certificate Installation on Android 13 or Lower

Installing custom certificates allow penetration testers to intercept, analyze, and manipulate application and network traffic on Android devices.
This guide focuses on leveraging Burp Suite proxy certificates to facilitate Man-in-the-Middle (MITM) attacks for ethical hacking purposes.

## Prerequisites

Before proceeding, be sure to have:
1. Access to the target Android device (physical or emulated).
2. Root privileges on the target device.
3. `adb` and a file manager with root capabilities.

## Steps to Intercept Encrypted Traffic

### Getting our certificate

1. On Burp Suite got to `proxy` tab and then `Proxy settings`
   ![Burp Suite](burp_suite.png)

2. Go to `Import/Export CA Certificate`

   ![Burp Suite Export Options](proxy_export.png)

3. Export the certificate as `DER` format
   ![Burp Suite Export Certificate](cert_export.png)

4. On the next step name your certificate and select where it will be stored.
5. Now we have to do some magic to our certificate:

   ```console
   ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
   └─$ ls
   burp_cacert.der

   ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
   └─$ openssl x509 -inform DER -in burp_cacert.der -out burp_cacert.pem

   ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
   └─$ openssl x509 -inform PEM -subject_hash_old -in burp_cacert.pem | head -1
   9a5ba575

   ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
   └─$ mv burp_cacert.pem 9a5ba575.0

   ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
   └─$ ls
   9a5ba575.0  burp_cacert.der
   ```

## Delivering our certificate to the target device

1. Using `adb push` we can add the certificate to our Android device/emulator

   ```console
   ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
   └─$ adb devices
   * daemon not running; starting now at tcp:5037
   * daemon started successfully
   List of devices attached
   a8f9c9af        device


   ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
   └─$ adb push 9a5ba575.0 /data/local/tmp
   9a5ba575.0: 1 file pushed, 0 skipped. 0.0 MB/s (1330 bytes in 0.027s)
   ```

2. Using `adb shell` we have to locate the certificate

   ```console
   ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
   └─$ adb root
   restarting adbd as root
   adb                                                                                                                                                                                           
   ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
   └─$ adb remount
   AVB verification is disabled, disabling verity state may have no effect
   Remounted / as RW
   Remounted /system_ext as RW
   Remounted /product as RW
   Remounted /vendor as RW
   Remounted /vendor/dsp as RW
   Remount succeeded

   ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
   └─$ adb shell
   joyeuse:/ # cd /data/local/tmp
   joyeuse:/data/local/tmp # ls
   9a5ba575.0
   ```

3. Since we're root on the device let's copy the certificate to the new location:

   ```console
   joyeuse:/data/local/tmp # cp 9a5ba575.0 /system/etc/security/cacerts/
   joyeuse:/data/local/tmp # chmod 644 /system/etc/security/cacerts/9a5ba575.0
   joyeuse:/data/local/tmp # ls /system/etc/security/cacerts/
   OTHER_CERTS.0 9a5ba575.0 OTHER_CERTS.0
   joyeuse:/data/local/tmp #
   ```

4. Finally reboot

   ```console
   joyeuse:/data/local/tmp # exit

   ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
   └─$ adb reboot
   ```
5. Intercepting traffic

![Burp Suite Traffic Capture](traffic_capture.png)