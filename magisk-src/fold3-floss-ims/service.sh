#!/system/bin/sh
# Floss (now a privileged app, not android.uid.system) reflects on these to get socket fds
# for Network.bindSocket()/IPsec. Exempt exactly these hidden methods, nothing broader.
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 1; done
settings put global hidden_api_blacklist_exemptions 'Ljava/net/ServerSocket;->getFileDescriptor$,Ljava/net/DatagramSocket;->getFileDescriptor$,Ljava/net/Socket;->getFileDescriptor$'
