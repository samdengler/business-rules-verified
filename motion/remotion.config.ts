// Settings for `remotion render` and `remotion still`; scripts/render-motion.sh
// runs both.  See https://www.remotion.dev/docs/config.
import { Config } from "@remotion/cli/config";

// Frames are captured as PNG so thin rims and small text are not compressed
// twice; the video is H.264 in BT.709, which browsers show in the site's colors.
Config.setVideoImageFormat("png");
Config.setCodec("h264");
Config.setPixelFormat("yuv420p");
Config.setColorSpace("bt709");
Config.setX264Preset("slow");
Config.setCrf(20);
