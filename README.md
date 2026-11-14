# Pixel Chess

A pixel-art chess game written in Free Pascal with SDL3. Play against a friend on the same computer, or against the Rodent II engine and its many personalities.

Current version: 0.1.0

## Features

- Full chess rules: castling, en passant, promotion, checkmate, stalemate, fifty-move rule, repetition and insufficient material
- Move list in standard algebraic notation
- Eight graphical themes
- Optional computer opponent (Rodent II, UCI protocol) with more than 40 personalities

## Requirements

- [Free Pascal](https://www.freepascal.org/) 3.2 or later
- [SDL3](https://libsdl.org/) and [SDL3_ttf](https://github.com/libsdl-org/SDL_ttf) libraries
- [SDL3-for-Pascal](https://github.com/PascalGameDevelopment/SDL3-for-Pascal) units, cloned next to this repository (`../sdl3-for-pascal`)
- `g++` to build the Rodent II engine

## Building

```sh
git clone https://github.com/PascalGameDevelopment/SDL3-for-Pascal.git ../sdl3-for-pascal
make
cd engines/rodent-ii/sources && make build
```

`make clean` removes the build output.

## Usage

```sh
./pixelchess [theme] [personality]
```

- `theme`: one of `lanea` (default), `m484`, `smirf`, `bftc`, `drummy`, `fritz`, `lucas`, `warlord`
- `personality`: a Rodent II personality, for example `fischer`, `amy` or `kinghunter`. Without this argument, both sides are played by humans.

The available personalities are the files in `engines/rodent-ii/personalities/`. An unknown theme or personality name prints the list of valid ones.

Examples:

```sh
./pixelchess
./pixelchess drummy
./pixelchess lucas petrosian
```

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
  engine/         UCI engine interface
  themes/         Theme definitions
images/           Piece and board graphics, one folder per theme
fonts/            Fonts
engines/rodent-ii Rodent II engine sources, personalities and guide books
```

## Credits

- Chess engine: Rodent II by Pawel Koziol, derived from Sungorus by Pablo Vazquez (GPL v3)
- Fonts: Alagard by Hewett Tsoi, Minecraftia
- Themes:
  - `lanea`: [Boardgame tiles](https://opengameart.org/content/boardgame-tiles) by Lanea Zimmerman
  - `m484`: [M484 chess set](https://opengameart.org/content/m484-chess-set) by Master484 (CC-BY 4.0 / OGA-BY 4.0)
  - `smirf`: [pieces](https://www.chessvariants.com/contests/10/crc.html) by Reinhard Scharnagl
  - `bftc`: pieces from *Bobby Fischer Teaches Chess*
  - `drummy`: [Chess pieces and a board](https://opengameart.org/content/chess-pieces-and-a-board) by drummyfish
  - `fritz`: pieces and board reproducing those of the Fritz chess program (ChessBase)
  - `lucas`: [Pixel chess pieces](https://opengameart.org/content/pixel-chess-pieces) by Lucas312
  - `warlord`: pieces from the [Warlord](https://chessprogramming.org/Warlord) chess program by William H. Rogers

## License

Pixel Chess is free software, released under the GNU General Public License v3. See [LICENSE](LICENSE).
