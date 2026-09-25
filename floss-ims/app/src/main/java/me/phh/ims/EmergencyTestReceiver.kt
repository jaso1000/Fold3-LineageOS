package me.phh.ims

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log
import kotlin.concurrent.thread

/**
 * Test-only hooks for building emergency (IMS SOS) support without ever placing an emergency call.
 * Protected by android.permission.DUMP, so only shell/root can trigger it:
 *   am broadcast -a me.phh.ims.EMERGENCY_TEST --es step pdn -n me.phh.ims/.EmergencyTestReceiver
 *
 * step=pdn: bring up the emergency IMS PDN (NET_CAPABILITY_EIMS), log what the network gives us
 *           (interface, addresses, emergency P-CSCFs), then release it. No SIP traffic.
 * step=register: emergency REGISTER (sos) on that PDN, then immediately de-REGISTER and release.
 *           No INVITE, no number, nothing reaches an emergency centre.
 */
class EmergencyTestReceiver : BroadcastReceiver() {
    companion object { const val TAG = "PHH EmergencyTest" }

    override fun onReceive(context: Context, intent: Intent) {
        val step = intent.getStringExtra("step") ?: "pdn"
        Log.w(TAG, "Emergency test step=$step (no call is placed)")
        when (step) {
            "pdn" -> probePdn(context.applicationContext)
            "register" -> testRegister(context.applicationContext)
            else -> Log.w(TAG, "Unknown step $step")
        }
    }

    private fun probePdn(ctxt: Context) {
        val cm = ctxt.getSystemService(ConnectivityManager::class.java)
        val req = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_EIMS)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            .build()
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                Log.w(TAG, "EIMS network available: $network")
            }
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                Log.w(TAG, "EIMS caps: $caps")
            }
            override fun onLinkPropertiesChanged(network: Network, lp: LinkProperties) {
                val pcscfs = try {
                    lp.javaClass.getMethod("getPcscfServers").invoke(lp)
                } catch (t: Throwable) { "?" }
                Log.w(TAG, "EIMS link: iface=${lp.interfaceName} addrs=${lp.linkAddresses} pcscf=$pcscfs dns=${lp.dnsServers} mtu=${lp.mtu}")
            }
            override fun onUnavailable() { Log.w(TAG, "EIMS network unavailable (timeout/refused)") }
            override fun onLost(network: Network) { Log.w(TAG, "EIMS network lost") }
        }
        Log.w(TAG, "Requesting EIMS network")
        cm.requestNetwork(req, cb, 30_000)
        thread {
            Thread.sleep(50_000)
            try { cm.unregisterNetworkCallback(cb) } catch (t: Throwable) {}
            Log.w(TAG, "EIMS request released")
        }
    }

    private fun testRegister(ctxt: Context) {
        val sip = me.phh.sip.SipHandler(ctxt, emergency = true)
        val okFlag = java.util.concurrent.atomic.AtomicBoolean(false)
        val failFlag = java.util.concurrent.atomic.AtomicBoolean(false)
        sip.imsReadyCallback = { okFlag.set(true); Log.w(TAG, "EMERGENCY REGISTER: 200 OK") }
        sip.imsFailureCallback = { failFlag.set(true); Log.w(TAG, "EMERGENCY REGISTER: failed (see PHH SipHandler log)") }
        sip.getVolteNetwork()
        thread {
            var waited = 0
            while (!okFlag.get() && !failFlag.get() && waited < 60) { Thread.sleep(1000); waited++ }
            Log.w(TAG, "Emergency register result: ok=${okFlag.get()} failed=${failFlag.get()} after ${waited}s")
            if (okFlag.get()) {
                Thread.sleep(3000)
                try { sip.deregister() } catch (t: Throwable) { Log.w(TAG, "deregister failed", t) }
                Thread.sleep(5000)
            }
            sip.shutdown()
            Log.w(TAG, "Emergency register test finished")
        }
    }
}
