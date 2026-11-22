package io.github.rchastain2.alouette_chess;

import org.libsdl.app.SDLActivity;

public class AlouetteChessActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] {
            "SDL3",
            "SDL3_ttf",
            "main"
        };
    }
}
