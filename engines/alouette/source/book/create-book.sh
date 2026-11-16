
COMMONFLAGS="--nosetuptags --nomovenumbers --noresults --notags -Wlalg --nochecks -C -N -V -w1000"

pgn-extract -ow1.txt --plylimit 15 $COMMONFLAGS -TwFischer "games/fischer/*.pgn"
pgn-extract -ob1.txt --plylimit 16 $COMMONFLAGS -TbFischer "games/fischer/*.pgn"
pgn-extract -ow2.txt --plylimit 15 $COMMONFLAGS -TwCapablanca "games/capablanca/*.pgn"
pgn-extract -ob2.txt --plylimit 16 $COMMONFLAGS -TbCapablanca "games/capablanca/*.pgn"
pgn-extract -ow3.txt --plylimit 15 $COMMONFLAGS -TwLabourdonnais "games/labourdonnais/*.pgn"
pgn-extract -ob3.txt --plylimit 16 $COMMONFLAGS -TbLabourdonnais "games/labourdonnais/*.pgn"
pgn-extract -ow4.txt --plylimit 15 $COMMONFLAGS -TwPhilidor "games/philidor/*.pgn"
pgn-extract -ob4.txt --plylimit 16 $COMMONFLAGS -TbPhilidor "games/philidor/*.pgn"
pgn-extract -ow5.txt --plylimit 15 $COMMONFLAGS -TwSpassky "games/spassky/*.pgn"
pgn-extract -ob5.txt --plylimit 16 $COMMONFLAGS -TbSpassky "games/spassky/*.pgn"

cat w?.txt | sort -u > white-lines.txt
cat b?.txt | sort -u > black-lines.txt

rm -fv w?.txt b?.txt

fpc clean.pas

./clean white-lines.txt
./clean black-lines.txt

rm -fv clean clean.o
