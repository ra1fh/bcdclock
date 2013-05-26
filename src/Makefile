
NAME=bcdclock
OBJ=main.o button.o sub.o
ASM=$(NAME).asm
HEX=$(NAME).hex

all: $(HEX)

main.o: main.asm
	gpasm -c main.asm

sub.o: sub.asm
	gpasm -c sub.asm

button.o: button.asm
	gpasm -c button.asm


$(HEX): $(OBJ)
	gplink -c -ainhx32 -m -o $(HEX) $(OBJ)

flash: $(HEX)
	pk2cmd -PPIC16F505 -M -F bcdclock.hex

sim: all
	gpsim bcdclock.stc

clean:
	rm -f $(OBJ) $(HEX) $(NAME).cod $(NAME).map $(NAME).cof *.lst
