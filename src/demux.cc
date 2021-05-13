/*  demux.cc - 4051-like multiplexer/demultiplexer
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

#define IN_MODULE

#include <errno.h>
#include <iostream>
#include <stdlib.h>
#include <string>

#include <gpsim/packages.h>
#include <gpsim/gpsim_interface.h>
#include <gpsim/attributes.h>

#include "demux.hh"

Module_Types available_modules[] =
{
	{ {"demux", "demux"}, Demux::construct},
	{ {NULL, NULL}, NULL}
};

extern "C"
{
	Module_Types * get_mod_list(void)
	{
		return available_modules;
	}
};

void Logic_Input::setDrivenState( bool new_state)
{

	if (verbose) {
		std::cout << name()<< " setDrivenState= "
				  << (new_state ? "high" : "low") << std::endl;
	}

	if (new_state != getDrivenState()) {
		bDrivingState = new_state;
		bDrivenState  = new_state;
		if(Parent) {
			Parent->update_input_pin(m_iobit, new_state);
			Parent->update_state();
		}
	}
}

Module *Demux::construct(const char *_new_name)
{
	Demux *pDemux = new Demux(_new_name);

	pDemux->new_name(_new_name);
	pDemux->create_iopin_map();

	return pDemux;
}

Demux::Demux(const char *_name)
	: Module(_name, "Demux - 8-channel multiplexer"),
	  number_of_pins(0),
	  input_state(0)
{
}

Demux::~Demux()
{
}

void Demux::update_state()
{
	int i;
	unsigned int val=0;

	if (m_IN[0]->getDrivenState())
		val += 1;
	if (m_IN[1]->getDrivenState())
		val += 2;
	if (m_IN[2]->getDrivenState())
		val += 4;

	for (i=0; i<8; i++) {
		if (val == i)
			m_OUT[i]->putState(true);
		else
			m_OUT[i]->putState(false);
	}
}

void Demux::create_iopin_map()
{
	int i;

	create_pkg(11);

	m_IN  = new Logic_Input *[3];
	m_OUT = new Logic_Output *[8];

	m_IN[0] = new Logic_Input(this, 0, "S0");
	m_IN[1] = new Logic_Input(this, 1, "S1");
	m_IN[2] = new Logic_Input(this, 2, "S2");

	for (i = 0; i <= 2; ++i) {
		addSymbol(m_IN[i]);
	}

	m_OUT[0] = new Logic_Output(this, 3, "Y0");
	m_OUT[1] = new Logic_Output(this, 4, "Y1");
	m_OUT[2] = new Logic_Output(this, 5, "Y2");
	m_OUT[3] = new Logic_Output(this, 6, "Y3");
	m_OUT[4] = new Logic_Output(this, 7, "Y4");
	m_OUT[5] = new Logic_Output(this, 8, "Y5");
	m_OUT[6] = new Logic_Output(this, 9, "Y6");
	m_OUT[7] = new Logic_Output(this,10, "Y7");

	for (i=0; i<=7; i++) {
		addSymbol(m_OUT[i]);
		m_OUT[i]->update_direction(1,true);  // make the bidirectional an output
	}

	package->assign_pin( 1, m_IN[0]);
	package->assign_pin( 2, m_IN[1]);
	package->assign_pin( 3, m_IN[2]);
	package->assign_pin( 4, m_OUT[0]);
	package->assign_pin( 5, m_OUT[1]);
	package->assign_pin( 6, m_OUT[2]);
	package->assign_pin( 7, m_OUT[3]);
	package->assign_pin( 8, m_OUT[4]);
	package->assign_pin( 9, m_OUT[5]);
	package->assign_pin(10, m_OUT[6]);
	package->assign_pin(11, m_OUT[7]);

}

void Demux::update_input_pin(unsigned int pin, bool bValue)
{
	unsigned int mask = 1<<pin;
	input_state &= ~mask;
	input_state |= bValue ? mask : 0;
}
