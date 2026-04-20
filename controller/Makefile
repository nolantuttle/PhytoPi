CC = gcc
CFLAGS = -Wall -O2 -Ilib -Ilib/bme680
LDFLAGS = -lgpiod -lpthread -lrt -lsqlite3 -lcurl -ljson-c

# Ensure BME680 submodule is initialized
$(if $(wildcard lib/BME68x_SensorAPI/bme68x.h),,$(error BME68x library missing. Run: git submodule update --init --recursive))
BINDIR = bin

SRC = src/main.c src/gpio.c src/state.c src/sql.c src/supabase.c src/commands.c src/bme680.c lib/BME68x_SensorAPI/bme68x.c
OBJ = $(SRC:.c=.o)

TARGET = $(BINDIR)/phytopi

all: $(TARGET)

$(TARGET): $(OBJ)
	mkdir -p $(BINDIR)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJ) $(TARGET) ${BINDIR}/*
