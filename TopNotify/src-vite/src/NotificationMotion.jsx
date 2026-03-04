import { Slider, SliderFilledTrack, SliderThumb, SliderTrack, Switch } from "@chakra-ui/react";

export default function NotificationMotion() {
    const displaySeconds = GetDisplaySeconds();
    const animationDurationMs = GetAnimationDurationMs();
    const animationOffsetPx = GetAnimationOffsetPx();
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
                <label>Slide-In Animation</label>
                <Switch onChange={(e) => ChangeSwitch("EnableSlideAnimation", e)} isChecked={animationEnabled} style={{ marginLeft: "auto" }} size='lg' />
            </div>

            <div data-greyed-out={(!animationEnabled).toString()} className="flexy fillx gap10">
                <div className="flexx facenter fillx gap20">
                    <label>Animation Speed ({animationDurationMs} ms)</label>
                </div>
                {
                    (Config.Location < 0) ?
                        (<></>) :
                        (
                            <Slider
                                size="lg"
                                min={60}
                                max={1200}
                                step={20}
                                defaultValue={animationDurationMs}
                                onChangeEnd={(ms) => window.ChangeValue("SlideAnimationDurationMs", Math.round(ms))}
                            >
                                <SliderTrack>
                                    <SliderFilledTrack />
                                </SliderTrack>
                                <SliderThumb />
                            </Slider>
                        )
                }

                <div className="flexx facenter fillx gap20">
                    <label>Slide Distance ({animationOffsetPx} px)</label>
                </div>
                {
                    (Config.Location < 0) ?
                        (<></>) :
                        (
                            <Slider
                                size="lg"
                                min={0}
                                max={120}
                                step={2}
                                defaultValue={animationOffsetPx}
                                onChangeEnd={(px) => window.ChangeValue("SlideAnimationStartOffsetPx", Math.round(px))}
                            >
                                <SliderTrack>
                                    <SliderFilledTrack />
                                </SliderTrack>
                                <SliderThumb />
                            </Slider>
                        )
                }
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

function GetAnimationDurationMs() {
    var configuredMs = Number(Config.SlideAnimationDurationMs);
    if (Number.isNaN(configuredMs) || configuredMs <= 0) {
        return 260;
    }

    return Math.max(60, Math.min(1200, configuredMs));
}

function GetAnimationOffsetPx() {
    var configuredPx = Number(Config.SlideAnimationStartOffsetPx);
    if (Number.isNaN(configuredPx) || configuredPx < 0) {
        return 24;
    }

    return Math.max(0, Math.min(120, configuredPx));
}
