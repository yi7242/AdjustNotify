import { Slider, SliderFilledTrack, SliderThumb, SliderTrack } from "@chakra-ui/react";

const MIN_DISPLAY_SECONDS = 0.1;
const MAX_DISPLAY_SECONDS = 10;

export default function NotificationMotion() {
    const displaySeconds = GetDisplaySeconds();

    return (
        <div className="flexy fillx gap10">
            <div className="flexx facenter fillx gap20">
                <label>Display Time ({displaySeconds.toFixed(1)}s)</label>
            </div>
            {
                (Config.Location < 0) ?
                    (<></>) :
                    (
                        <Slider
                            size="lg"
                            min={MIN_DISPLAY_SECONDS}
                            max={MAX_DISPLAY_SECONDS}
                            step={0.1}
                            defaultValue={displaySeconds}
                            onChangeEnd={(seconds) => window.ChangeValue("NotificationDisplayDurationMs", Math.round(seconds * 1000))}
                        >
                            <SliderTrack>
                                <SliderFilledTrack />
                            </SliderTrack>
                            <SliderThumb />
                        </Slider>
                    )
            }
        </div>
    );
}

function GetDisplaySeconds() {
    var configuredMs = Number(Config.NotificationDisplayDurationMs);
    if (Number.isNaN(configuredMs) || configuredMs <= 0) {
        return 2;
    }

    return Math.max(MIN_DISPLAY_SECONDS, Math.min(MAX_DISPLAY_SECONDS, configuredMs / 1000));
}
