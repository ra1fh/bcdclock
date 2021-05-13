/*  demux.hh - 4051-like multiplexer/demultiplexer
 *
 *  Copyright (C) 2015 Ralf Horstmann
 * 
 *  Permission to use, copy, modify, and distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 * 
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 * 
 */

#ifndef __DEMUX_H__
#define __DEMUX_H__

#define IN_MODULE

#include <gpsim/stimuli.h>
#include <gpsim/ioports.h>
#include <gpsim/symbol.h>
#include <gpsim/modules.h>

class Demux;

class Logic_Input : public IOPIN
{
	private:
	Demux *Parent;
	unsigned int m_iobit;
	
	public:
	virtual void setDrivenState( bool new_state);
	Logic_Input (Demux *parent, unsigned int b, const char *opt_name=nullptr)
		: IOPIN(opt_name), Parent(parent), m_iobit(b)
    {
    }
};

class Logic_Output : public IO_bi_directional
{
	private:
	Demux *Parent;
	unsigned int m_iobit;
	
	public:
	Logic_Output (Demux *parent, unsigned int b,const char *opt_name=nullptr)
		: IO_bi_directional(opt_name), Parent(parent), m_iobit(b)
    {
    }
};

class Demux : public Module
{
	public:
	int number_of_pins;
	unsigned int input_state;

	Demux(const char *_name);
	~Demux(void);
	static Module *construct(const char *new_name=NULL);

	virtual void create_iopin_map(void);
	virtual void update_state();
	virtual int get_num_of_pins(void) {return number_of_pins;};
	void set_number_of_pins(int npins){number_of_pins=npins;};
	void update_input_pin(unsigned int pin, bool bValue);
	
	protected:
	Logic_Input  **m_IN;
	Logic_Output **m_OUT;
};

#endif //  __DEMUX_H__

