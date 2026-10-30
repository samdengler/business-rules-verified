import React from "react";
import { Composition, Still } from "remotion";
import { History, type HistoryProps } from "./History";
import { DURATION, FPS, HEIGHT, WIDTH } from "./story";

// History is the video; Poster is its last frame, the final state, as a still.
export const Root: React.FC = () => (
  <>
    <Composition
      id="History"
      component={History}
      durationInFrames={DURATION}
      fps={FPS}
      width={WIDTH}
      height={HEIGHT}
      defaultProps={{ theme: "light" } satisfies HistoryProps}
    />
    <Still id="Poster" component={History} width={WIDTH} height={HEIGHT} defaultProps={{ theme: "light", at: DURATION - 1 } satisfies HistoryProps} />
  </>
);
