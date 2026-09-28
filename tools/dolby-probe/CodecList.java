import android.media.MediaCodecInfo;
import android.media.MediaCodecList;

/** List audio decoders whose name or type matches a regex (default: Dolby formats), as apps see them. */
public class CodecList {
    public static void main(String[] args) {
        String re = args.length > 0 ? args[0] : "(?i).*(ac3|ac4|eac3|dolby).*";
        for (MediaCodecInfo i : new MediaCodecList(MediaCodecList.ALL_CODECS).getCodecInfos()) {
            if (i.isEncoder()) continue;
            String types = String.join(",", i.getSupportedTypes());
            if (i.getName().matches(re) || types.matches(re)) System.out.println(i.getName() + "  " + types);
        }
        System.out.println("done");
    }
}
