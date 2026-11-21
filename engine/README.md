# Alouette

## Overview

*Alouette* is a UCI chess engine able to play Fischer Random Chess. It was initially a programming exercise around *bitboards*.

It is not a very formidable opponent. You should manage to beat it easily.

## Opening book

Since version 0.1.0, the engine uses an opening book. The book is in the [format described by Kathe Spracklen](https://content.iospress.com/articles/icga-journal/icg6-1-04).

    (e4(e5(d4))(c5))(d4(d5))

This format has been previously used by Marc-Philippe Huget in his engine [La Dame Blanche](http://www.quarkchess.de/ladameblanche/).

## Protocol

*Alouette* understands (a part of) the UCI protocol, plus some custom commands. To see a list of all available commands, run *Alouette* and type `help`.

## Random mode

If you call the engine with the option `-r` or `--random`, it will play pure random moves.

## Settings

If it does not exist, *Alouette* creates a file `alouette.cfg` next to the executable when it exits.

    [main]
    usebook=1

    [factors]
    protectedpawns=2
    mobility=1
    castling=5
    enpassant=0
    check=1
    newpos=10

`usebook` enables the opening book. The factors weight the criteria used to choose between moves of equal value.

Since version 0.2.1, some keys have been renamed or removed. If you have an older file, delete it and let the engine create a new one.

## Author

*Alouette* is free software, released under the [GNU General Public License](LICENSE), version 3 or any later version, and written for the Free Pascal Compiler by Roland Chastain.

## Name

> ALOUETTE : Oiseau de l'ordre des passereaux ; il fait son nid dans les plaines.
>
> — Littré ([full entry](docs/alouette-littre.md))

## Logo

![Alouette logo](logo/alouette-400x200.png)

## Links

- [Discussion](https://talkchess.com/viewtopic.php?t=70347)

