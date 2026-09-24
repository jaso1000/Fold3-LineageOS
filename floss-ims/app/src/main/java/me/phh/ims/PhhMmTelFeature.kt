//SPDX-License-Identifier: GPL-2.0
package me.phh.ims

import android.os.Bundle
import android.os.Message
import android.telephony.Rlog
import android.telephony.ims.ImsCallProfile
import android.telephony.ims.ImsCallSessionListener
import android.telephony.ims.ImsReasonInfo
import android.telephony.ims.ImsStreamMediaProfile
import android.telephony.ims.feature.ImsFeature
import android.telephony.ims.stub.ImsCallSessionImplBase
import android.telephony.ims.stub.ImsMultiEndpointImplBase
import android.telephony.ims.stub.ImsRegistrationImplBase.REGISTRATION_TECH_LTE
import android.telephony.ims.stub.ImsSmsImplBase
import android.telephony.ims.stub.ImsUtImplBase
import me.phh.sip.SipHandler
import me.phh.sip.randomBytes
import me.phh.sip.toHex

// frameworks/base/telephony/java/android/telephony/ims/feature/MmTelFeature.java
// We extend it through java once because kotlin cannot override
// changeEnabledCapabilities that has a protected (CapabilityCallbackProxy)
// argument. See this stackoverflow link for why we cannot do it directly:
// https://stackoverflow.com/questions/49284094/inheritance-from-java-class-with-a-public-method-accepting-a-protected-class-in/49287402#49287402
class PhhMmTelFeature(val slotId: Int) : PhhMmTelFeatureProtected(slotId) {
    companion object {
        private const val TAG = "PHH MmTelFeature"
    }

    val imsSms = PhhImsSms(slotId)
    lateinit var sipHandler: SipHandler

    override fun createCallProfile(callSessionType: Int, callType: Int): ImsCallProfile {
        Rlog.d(TAG, "$slotId createCallProfile $callSessionType $callType")
        // check why not called
        // figure out RilHolder.INSTANCE.getRadios(mSlotId).setImsCfg ? Probably only required
        // if we leave ims to the radio...
        return ImsCallProfile(callSessionType, callType)
    }
    // Listener of whichever call (incoming or outgoing) is currently active
    @Volatile var activeCallListener: ImsCallSessionListener? = null

    override fun createCallSession(profile: ImsCallProfile): ImsCallSessionImplBase {
        Rlog.d(TAG, "$slotId createCallSession")
        return object: ImsCallSessionImplBase() {
            private val mCallId = randomBytes(12).toHex()
            lateinit var mListener: ImsCallSessionListener
            override fun getCallId(): String {
                return mCallId
            }

            override fun close() {
                Rlog.d(TAG, "Closing call")
            }

            override fun accept(callType: Int, profile: ImsStreamMediaProfile) {
                Rlog.d(TAG, "Accepting call with callType $callType profile $profile")
            }

            override fun isInCall(): Boolean {
                return true
            }

            override fun start(callee: String, profile: ImsCallProfile) {
                Rlog.d(TAG, "Starting call with $callee profile $profile")
                activeCallListener = mListener
                setAudioHandlerAndroid()
                sipHandler.onCallConnected = {
                    Rlog.d(TAG, "Outgoing call connected")
                    mListener.callSessionInitiated(profile)
                    setAudioHandlerAndroid()
                }
                sipHandler.call(callee)
            }

            override fun getState(): Int {
                return State.ESTABLISHED
            }

            override fun setListener(listener: ImsCallSessionListener) {
                Rlog.d(TAG, "Setting CallListener to $listener")
                mListener = listener
            }

            override fun reject(reason: Int) {
                Rlog.d(TAG, "Rejecting call with reason $reason")
            }

            override fun terminate(reason: Int) {
                Rlog.d(TAG, "Terminating call with reason $reason")
                sipHandler.hangupOutgoingCall()
                mListener.callSessionTerminated(ImsReasonInfo(ImsReasonInfo.CODE_USER_TERMINATED, 0, "Kikoo"))
            }

            override fun sendDtmf(c: Char, result: android.os.Message?) {
                sipHandler.sendDtmf(c)
                result?.sendToTarget()
            }

            override fun startDtmf(c: Char) {
                sipHandler.sendDtmf(c)
            }

            override fun stopDtmf() {
                // Each digit is sent as a fixed 100 ms event
            }
        }
    }

    fun getInstance(slotId: Int): PhhMmTelFeature {
        Rlog.d(TAG, "$slotId getInstance")
        return PhhMmTelFeature(slotId)
    }

    override fun getFeatureState(): Int {
        Rlog.d(TAG, "$slotId getFeatureState")
        // always ready for now... Also STATE_INITIALIZING, STATE_UNAVAILABLE
        return ImsFeature.STATE_READY
    }

    override fun getMultiEndpoint(): ImsMultiEndpointImplBase {
        Rlog.d(TAG, "$slotId getMultiEndpoint")
        return ImsMultiEndpointImplBase()
    }

    override fun getSmsImplementation(): ImsSmsImplBase {
        Rlog.d(TAG, "$slotId getSmsImplementation")
        return imsSms
    }

    override fun getUt(): ImsUtImplBase {
        Rlog.d(TAG, "$slotId getUt")
        return ImsUtImplBase()
    }

    override fun onFeatureReady() {
        Rlog.d(TAG, "$slotId onFeatureReady")
        if(this::sipHandler.isInitialized) return

        // call onRegistering first then
        // register SIP here and call onRegistered after .. register.
        val imsService = PhhImsService.Companion.instance!!
        sipHandler = SipHandler(imsService)
        sipHandler.imsFailureCallback = { imsService.getRegistration(slotId).onDeregistered(null) }
        sipHandler.imsReadyCallback = {
            imsService.getRegistration(slotId).onRegistered(REGISTRATION_TECH_LTE)
        }
        imsSms.sipHandler = sipHandler
        sipHandler.onSmsReceived = imsSms::onSmsReceived
        sipHandler.onSmsStatusReportReceived = imsSms::onSmsStatusReportReceived

        var callListener: ImsCallSessionListener? = null
        sipHandler.onIncomingCall = { handle: Object, from: String, extras: Map<String, String> -> 
            val callProfile = ImsCallProfile(ImsCallProfile.SERVICE_TYPE_NORMAL, ImsCallProfile.CALL_TYPE_VOICE,
                Bundle(),
                ImsStreamMediaProfile(
                    ImsStreamMediaProfile.AUDIO_QUALITY_EVS_FB,
                    ImsStreamMediaProfile.DIRECTION_SEND_RECEIVE,
                    ImsStreamMediaProfile.VIDEO_QUALITY_NONE,
                    ImsStreamMediaProfile.DIRECTION_INACTIVE,
                    ImsStreamMediaProfile.RTT_MODE_DISABLED,
                ))

            callProfile.setCallExtra(ImsCallProfile.EXTRA_OI, from)
            callProfile.setCallExtra(ImsCallProfile.EXTRA_DISPLAY_TEXT, from)
            // Without OIR telephony treats the presentation as unknown and the dialer hides the number
            val withheld = from.isEmpty() || from.contains("anonymous", ignoreCase = true)
            callProfile.setCallExtraInt(ImsCallProfile.EXTRA_OIR,
                if (withheld) ImsCallProfile.OIR_PRESENTATION_RESTRICTED
                else ImsCallProfile.OIR_PRESENTATION_NOT_RESTRICTED)
            callProfile.setCallExtraInt(ImsCallProfile.EXTRA_CNAP,
                if (withheld) ImsCallProfile.OIR_PRESENTATION_RESTRICTED
                else ImsCallProfile.OIR_PRESENTATION_NOT_RESTRICTED)
            notifyIncomingCall(object: ImsCallSessionImplBase() {
                var mState = State.IDLE
                override fun getCallProfile(): ImsCallProfile {
                    return callProfile
                }
                override fun setListener(listener: ImsCallSessionListener) {
                    Rlog.d(TAG, "Setting CallListener to $listener")
                    callListener = listener
                    activeCallListener = listener
                }

                override fun getCallId(): String {
                    return extras["call-id"]!!
                }

                override fun getLocalCallProfile(): ImsCallProfile {
                    return callProfile
                }
                override fun getRemoteCallProfile(): ImsCallProfile {
                    return callProfile
                }
                override fun getProperty(name: String): String {
                    Rlog.d(TAG, "ImsCallSession.getProperty " + name)
                    return ""
                }

                override fun getState(): Int {
                    return mState
                }

                override fun start(callee: String, profile: ImsCallProfile) {
                    Rlog.d(TAG, "Starting call with $callee")
                }

                override fun accept(callType: Int, profile: ImsStreamMediaProfile) {
                    Rlog.d(TAG, "Accepting call with profile $profile")
                    sipHandler.acceptCall()
                    mState = State.ESTABLISHED
                    callListener?.callSessionInitiated(callProfile)
                    setAudioHandlerAndroid()
                }

                override fun deflect(deflectNumber: String?) {
                    Rlog.d(TAG, "Deflecting call to $deflectNumber")
                }

                override fun reject(reason: Int) {
                    sipHandler.rejectCall()
                    Rlog.d(TAG, "Rejecting call $reason")
                }

                override fun terminate(reason: Int) {
                    sipHandler.terminateCall()
                    Rlog.d(TAG, "Terminating call")
                }
                override fun sendDtmf(c: Char, result: android.os.Message?) {
                    sipHandler.sendDtmf(c)
                    result?.sendToTarget()
                }

                override fun startDtmf(c: Char) {
                    sipHandler.sendDtmf(c)
                }

                override fun stopDtmf() {
                    // Each digit is sent as a fixed 100 ms event
                }

            }, Bundle())
            // Mark it VoIP-audio before it's answered, so Telecom never enters MODE_IN_CALL
            setAudioHandlerAndroid()
        }
        sipHandler.onCancelledCall = { param: Object, s: String, map: Map<String, String> ->
            Rlog.d(TAG, "Cancelling call")
            val callListener = activeCallListener ?: callListener
            val statusCode = map["statusCode"]?.toInt() ?: -1
            if (statusCode >= 400) {
                val statusMessage = map["statusString"] ?: "Kikoo"
                callListener?.callSessionTerminated(ImsReasonInfo(ImsReasonInfo.CODE_NETWORK_REJECT, 0, statusMessage))
            } else {
                callListener?.callSessionTerminated(
                    ImsReasonInfo(
                        ImsReasonInfo.CODE_USER_TERMINATED_BY_REMOTE,
                        0,
                        "Kikoo"
                    )
                )
            }
        }

        setAudioHandlerAndroid()
        imsService.getRegistration(slotId).onRegistering(REGISTRATION_TECH_LTE)
        sipHandler.getVolteNetwork()
    }

    // Call audio is ours (RTP on the AP), not the modem's: with AUDIO_HANDLER_ANDROID telephony
    // marks calls as VoIP audio mode, so Telecom uses MODE_IN_COMMUNICATION instead of
    // MODE_IN_CALL. In MODE_IN_CALL Samsung's audio HAL routes the mic to the modem voice
    // path (voicemmode1-call) and our AudioRecord hears nothing. Telephony applies this to the
    // current call, so it's (re)sent whenever a call starts.
    fun setAudioHandlerAndroid() {
        // (Android 16 names it setCallAudioHandler; earlier previews used notifyAudioHandlerChanged)
        val audioHandlerSet = listOf("setCallAudioHandler", "notifyAudioHandlerChanged").any { name ->
            try {
                android.telephony.ims.feature.MmTelFeature::class.java.getMethod(name, Int::class.javaPrimitiveType)
                    .invoke(this, 0 /* MmTelFeature.AUDIO_HANDLER_ANDROID */)
                Rlog.d(TAG, "Audio handler set to AUDIO_HANDLER_ANDROID via $name")
                true
            } catch (t: Throwable) {
                false
            }
        }
        if (!audioHandlerSet) Rlog.w(TAG, "Could not set audio handler")
    }

    override fun onFeatureRemoved() {
        Rlog.d(TAG, "$slotId onFeatureRemoved")
    }

    // ints are @MmTelCapabilities.MmTelCapability and @ImsRegistrationImplBase.ImsRegistrationTech
    override fun queryCapabilityConfiguration(capability: Int, radioTech: Int): Boolean {
        Rlog.d(TAG, "$slotId queryCapabilityConfiguration $capability $radioTech")
        return capability == MmTelCapabilities.CAPABILITY_TYPE_SMS || capability == MmTelCapabilities.CAPABILITY_TYPE_VOICE
    }

    override fun setUiTtyMode(mode: Int, onCompleteMessage: Message?) {
        Rlog.d(TAG, "$slotId setUiTtyMode $onCompleteMessage")
    }

    override fun shouldProcessCall(numbers: Array<out String>): Int {
        Rlog.d(TAG, "Should process call? ${numbers.toList()}")
        return PROCESS_CALL_IMS
    }
}
