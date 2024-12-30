---
layout: post
permalink: /mobile/android/android14certificates
title: Android 14+ certificate intallation
description: >-
  How to install burpsuite certificate on Android 14+
author: richsphinx
date: 2024-12-11
media_subpath: '/assets/img/mobile/android/'
image:
  path: /android14Cert.png
  alt: Android Certificate install on Android 14+
---

# Android 14+ certificate installation

Installing custom certificates allow penetration testers to intercept, analyze, and manipulate application and network traffic on Android devices.
This guide focuses on leveraging Burp Suite proxy certificates to facilitate Man-in-the-Middle (MITM) attacks for ethical hacking purposes.

Android 14 changes the state of the game, there was a missconception thata Google tried to prevent users from installing custom certificates on Android 14, but this is not the case, what really happeneded is that Google wanted to improve the overall security of Android system, this led to some modifications that prevented custom certificates from being used the same way it did on previous Android versions. Let's dive in.

## Prerequisites

Before proceeding, be sure to have:
1. Access to the target Android device (physical or emulated).
2. Root privileges on the target device.
3. `adb` or a file manager with root capabilities.

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

    5.1 First, change our `DER` certificate to `PEM` since this is the type Android uses

    ```console
    ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
    └─$ ls
    burp_cacert.der

    ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
    └─$ openssl x509 -inform DER -in burp_cacert.der -out burp_cacert.pem
    ```
    
    5.2 Second, get the certificate hash and rename it.

    ```console
    ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
    └─$ openssl x509 -inform PEM -subject_hash_old -in burp_cacert.pem | head -1
    9a5ba575

    ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
    └─$ mv burp_cacert.pem 9a5ba575.0

    ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
    └─$ ls
    9a5ba575.0  burp_cacert.der
    ```

## Uploading our certificate to the target device

1. Using `adb push` we can upload the certificate to our Android device/emulator

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

    2.1 Restart `ADB` as root.

    ```console
    ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
    └─$ adb root
    restarting adbd as root
    adb                          
    ```

    2.2 Remount the system as `RW`
    
    ```console 
    ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
    └─$ adb remount
    AVB verification is disabled, disabling verity state may have no effect
    Remounted / as RW
    Remounted /system_ext as RW
    Remounted /product as RW
    Remounted /vendor as RW
    Remounted /vendor/dsp as RW
    Remount succeeded
    ```

    2.3 Get into the phone/emulator by using `adb shell`

    ```console
    ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
    └─$ adb shell
    joyeuse:/ # cd /data/local/tmp
    joyeuse:/data/local/tmp # ls
    9a5ba575.0
    ```

3. This is where things get interesting, in order for Android to accept and use our new certificate we have to mess around with `Zygote` and `APEX` processes, thankfully our good friends at [HTTPToolkit](https://httptoolkit.com/blog/android-14-install-system-ca-certificate/#how-to-install-system-ca-certificates-in-android-14) developed an script that will do this for us.

    ``` bash
    # Create a separate temp directory, to hold the current certificates
    # Otherwise, when we add the mount we can't read the current certs anymore.
    mkdir -p -m 700 /data/local/tmp/tmp-ca-copy

    # Copy out the existing certificates
    cp /apex/com.android.conscrypt/cacerts/* /data/local/tmp/tmp-ca-copy/

    # Create the in-memory mount on top of the system certs folder
    mount -t tmpfs tmpfs /system/etc/security/cacerts

    # Copy the existing certs back into the tmpfs, so we keep trusting them
    mv /data/local/tmp/tmp-ca-copy/* /system/etc/security/cacerts/

    # Copy our new cert in, so we trust that too
    mv $CERTIFICATE_PATH /system/etc/security/cacerts/

    # Update the perms & selinux context labels
    chown root:root /system/etc/security/cacerts/*
    chmod 644 /system/etc/security/cacerts/*
    chcon u:object_r:system_file:s0 /system/etc/security/cacerts/*

    # Deal with the APEX overrides, which need injecting into each namespace:

    # First we get the Zygote process(es), which launch each app
    ZYGOTE_PID=$(pidof zygote || true)
    ZYGOTE64_PID=$(pidof zygote64 || true)
    # N.b. some devices appear to have both!

    # Apps inherit the Zygote's mounts at startup, so we inject here to ensure
    # all newly started apps will see these certs straight away:
    for Z_PID in "$ZYGOTE_PID" "$ZYGOTE64_PID"; do
        if [ -n "$Z_PID" ]; then
            nsenter --mount=/proc/$Z_PID/ns/mnt -- \
                /bin/mount --bind /system/etc/security/cacerts /apex/com.android.conscrypt/cacerts
        fi
    done

    # Then we inject the mount into all already running apps, so they
    # too see these CA certs immediately:

    # Get the PID of every process whose parent is one of the Zygotes:
    APP_PIDS=$(
        echo "$ZYGOTE_PID $ZYGOTE64_PID" | \
        xargs -n1 ps -o 'PID' -P | \
        grep -v PID
    )

    # Inject into the mount namespace of each of those apps:
    for PID in $APP_PIDS; do
        nsenter --mount=/proc/$PID/ns/mnt -- \
            /bin/mount --bind /system/etc/security/cacerts /apex/com.android.conscrypt/cacerts &
    done
    wait # Launched in parallel - wait for completion here

    echo "System certificate injected"
    ```

4. For ease of use I'm gonna change `$CERTIFICATE_PATH` by directly inputing the path where I have my certificate.

    ```bash
        # Create a separate temp directory, to hold the current certificates
        # Otherwise, when we add the mount we can't read the current certs anymore.
        mkdir -p -m 700 /data/local/tmp/tmp-ca-copy

        # Copy out the existing certificates
        cp /apex/com.android.conscrypt/cacerts/* /data/local/tmp/tmp-ca-copy/

        # Create the in-memory mount on top of the system certs folder
        mount -t tmpfs tmpfs /system/etc/security/cacerts

        # Copy the existing certs back into the tmpfs, so we keep trusting them
        mv /data/local/tmp/tmp-ca-copy/* /system/etc/security/cacerts/

        # Copy our new cert in, so we trust that too
        mv /data/local/tmp/9a5ba575.0 /system/etc/security/cacerts/

        # Update the perms & selinux context labels
        chown root:root /system/etc/security/cacerts/*
        chmod 644 /system/etc/security/cacerts/*
        chcon u:object_r:system_file:s0 /system/etc/security/cacerts/*

        # Deal with the APEX overrides, which need injecting into each namespace:

        # First we get the Zygote process(es), which launch each app
        ZYGOTE_PID=$(pidof zygote || true)
        ZYGOTE64_PID=$(pidof zygote64 || true)
        # N.b. some devices appear to have both!

        # Apps inherit the Zygote's mounts at startup, so we inject here to ensure
        # all newly started apps will see these certs straight away:
        for Z_PID in "$ZYGOTE_PID" "$ZYGOTE64_PID"; do
            if [ -n "$Z_PID" ]; then
                nsenter --mount=/proc/$Z_PID/ns/mnt -- \
                    /bin/mount --bind /system/etc/security/cacerts /apex/com.android.conscrypt/cacerts
            fi
        done

        # Then we inject the mount into all already running apps, so they
        # too see these CA certs immediately:

        # Get the PID of every process whose parent is one of the Zygotes:
        APP_PIDS=$(
            echo "$ZYGOTE_PID $ZYGOTE64_PID" | \
            xargs -n1 ps -o 'PID' -P | \
            grep -v PID
        )

        # Inject into the mount namespace of each of those apps:
        for PID in $APP_PIDS; do
            nsenter --mount=/proc/$PID/ns/mnt -- \
                /bin/mount --bind /system/etc/security/cacerts /apex/com.android.conscrypt/cacerts &
        done
        wait # Launched in parallel - wait for completion here

        echo "System certificate injected"
    ```
5. Let's upload this new script into our phone/emulator

    ```console
   ┌──(richsphinx㉿parrot)-[~/workspace/mobile]
   └─$ adb push certInstall.sh /data/local/tmp
   certInstall.sh: 1 file pushed, 0 skipped. 0.0 MB/s (2330 bytes in 0.047s)
    ```

6. Finally, we have to execute it.

    ```console
    ┌──(charlie㉿parrot)-[~]
    └─$ adb root
    restarting adbd as root

    ┌──(charlie㉿parrot)-[~]
    └─$ adb shell
    joyeuse:/ # cd /data/local/tmp
    joyeuse:/data/local/tmp # ls
    9a5ba575.0  install_cert.sh
    joyeuse:/data/local/tmp # chmod +x install_cert.sh
    joyeuse:/data/local/tmp # ./install_cert.sh
    System certificate injected
    joyeuse:/data/local/tmp #
    ```

7. Intercepting traffic

![Burp Suite Traffic Capture](traffic_capture_android14.png)