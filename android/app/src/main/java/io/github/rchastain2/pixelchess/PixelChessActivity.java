package io.github.rchastain2.pixelchess;

import org.libsdl.app.SDLActivity;

public class PixelChessActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] {
            "SDL3",
            "SDL3_ttf",
            "main"
        };
    }
}
