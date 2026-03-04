import { Slider, SliderFilledTrack, SliderThumb, SliderTrack, Switch } from "@chakra-ui/react";

export default function NotificationMotion() {
    const displaySeconds = GetDisplaySeconds();
    const animationEnabled = Config.EnableSlideAnimation != false;

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
                            min={1}
                            max={10}
                            step={0.5}
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

            <div className="flexx facenter fillx gap20">
                <label>Slide Animation</label>
                <Switch onChange={(e) => ChangeSwitch("EnableSlideAnimation", e)} isChecked={animationEnabled} style={{ marginLeft: "auto" }} size='lg' />
            </div>
        </div>
    );
}

function GetDisplaySeconds() {
    var configuredMs = Number(Config.NotificationDisplayDurationMs);
    if (Number.isNaN(configuredMs) || configuredMs <= 0) {
        return 2;
    }

    return Math.max(1, Math.min(10, configuredMs / 1000));
}
