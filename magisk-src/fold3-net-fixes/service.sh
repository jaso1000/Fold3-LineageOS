#!/system/bin/sh
# Wi-Fi hotspot DNS. DHCP hands tethered clients the phone's own IP as DNS server, but nothing
# listens on port 53 (TetheringNext always starts netd with usingLegacyDnsProxy=false and no
# dnsmasq). Redirect their DNS straight to a public resolver; the tethering NAT carries it out.
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 1; done
DNS=8.8.8.8
for proto in udp tcp; do
    iptables -t nat -C PREROUTING -i swlan0 -p $proto --dport 53 -j DNAT --to-destination $DNS 2>/dev/null ||
        iptables -t nat -I PREROUTING 1 -i swlan0 -p $proto --dport 53 -j DNAT --to-destination $DNS
done
# Hardware tethering offload doesn't help on this GSI; keep it off (harmless either way)
settings put global tether_offload_disabled 1
