
NAME=bcdclock
OBJ=main.o button.o sub.o
ASM=$(NAME).asm
HEX=$(NAME).hex
DEMUX=demux.so.0

all: $(HEX)

main.o: main.asm
	gpasm -c main.asm

sub.o: sub.asm
	gpasm -c sub.asm

button.o: button.asm
	gpasm -c button.asm

$(DEMUX): demux.o
	c++ -shared -fPIC -DPIC demux.o -o $(DEMUX)

demux.o: demux.cc
	c++ -O2 -DPIC -fPIC -pipe -DHAVE_GUI -c demux.cc -o demux.o $$(pkg-config --cflags gtk+-2.0)

$(HEX): $(OBJ)
	gplink -c -ainhx32 -m -o $(HEX) $(OBJ)

flash: $(HEX)
	pk2cmd -PPIC16F505 -M -F bcdclock.hex

sim: all demux.so.0
	gpsim bcdclock.stc

clean:
	rm -f $(OBJ) $(HEX) $(NAME).cod $(NAME).map $(NAME).cof $(DEMUX) demux.o *.lst
