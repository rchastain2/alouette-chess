# Pixel Chess

A pixel-art chess game written in Free Pascal with SDL3. Play against a friend on the same computer, or against any UCI chess engine.

Current version: 0.1.0

## Features

- Full chess rules: castling, en passant, promotion, checkmate, stalemate, fifty-move rule, repetition and insufficient material
- Move list in standard algebraic notation
- Seven graphical themes
- Optional computer opponent: any engine supporting the UCI protocol

## Requirements

- [Free Pascal](https://www.freepascal.org/) 3.2 or later
- [SDL3](https://libsdl.org/) and [SDL3_ttf](https://github.com/libsdl-org/SDL_ttf) libraries
- [SDL3-for-Pascal](https://github.com/PascalGameDevelopment/SDL3-for-Pascal) units, cloned next to this repository (`../sdl3-for-pascal`)

## Building

```sh
git clone https://github.com/PascalGameDevelopment/SDL3-for-Pascal.git ../sdl3-for-pascal
make
```

`make clean` removes the build output.

## Usage

```sh
./pixelchess
```

The theme and the computer opponent are set in `pixelchess.ini`, next to the executable:

```ini
[Display]
Theme=lanea

[Engine]
Path=
```

- `Theme`: one of `lanea` (default), `m484`, `smirf`, `bftc`, `fritz`, `lucas`, `warlord`
- `Path`: the executable of a UCI engine, absolute or relative to the directory of `pixelchess`. Leave it empty to have both sides played by humans.

An unknown theme name prints the list of valid ones. If the file is missing, the default theme is used and there is no computer opponent.

## Controls

| Key / action      | Effect                                  |
|-------------------|-----------------------------------------|
| Click or drag     | Move a piece                            |
| `N`               | New game                                |
| `F`               | Flip the board                          |
| `S`               | Switch sides (when playing the engine)  |
| `Backspace`       | Take back a move                        |
| `Esc`             | Cancel a promotion, or quit             |

## Project layout

```
source/           Pascal sources
  chess/          Chess rules, FEN, SAN, move list
images/           Piece and board graphics, one folder per theme
fonts/            Fonts
```

## Credits

- Fonts: Alagard by Hewett Tsoi, Minecraftia
- Themes:
  - `lanea`: [Boardgame tiles](https://opengameart.org/content/boardgame-tiles) by Lanea Zimmerman
  - `m484`: [M484 chess set](https://opengameart.org/content/m484-chess-set) by Master484 (CC-BY 4.0 / OGA-BY 4.0)
  - `smirf`: [pieces](https://www.chessvariants.com/contests/10/crc.html) by Reinhard Scharnagl
  - `bftc`: pieces from *Bobby Fischer Teaches Chess*
  - `fritz`: pieces and board reproducing those of the Fritz chess program (ChessBase)
  - `lucas`: [Pixel chess pieces](https://opengameart.org/content/pixel-chess-pieces) by Lucas312
  - `warlord`: pieces from the [Warlord](https://chessprogramming.org/Warlord) chess program by William H. Rogers

## License

Pixel Chess is free software, released under the GNU General Public License v3. See [LICENSE](LICENSE).
