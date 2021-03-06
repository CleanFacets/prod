/**
 * Integrates the Send, Receive and Power paths to provide consistent access to the underlying radio.
 */
module SendReceiveP {
	provides {
		interface StdControl;
		interface Send;
		interface Receive;
	}
	
	uses {
		interface StdControl as SubControl;
		interface Send as SubSend;
		interface Receive as SubReceive;
		interface ChipconPacket;
	}
}

implementation {
	
	bool on = FALSE;		// tracks whether the radio is on or off
	message_t* rxBuffer;	// helps detect buffer swapping bugs
	
	/**
	 * Turn the radio on if it is not already on.
	 * @return SUCCESS
	 */
	command error_t StdControl.start() {
		if (!on) call SubControl.start();
		on = TRUE;
		return SUCCESS;
	}
	
	/**
	 * Turn the radio off if it is not already off.
	 * @return SUCCESS
	 */
	command error_t StdControl.stop() {
		if (on) {
			call SubControl.stop();
		}

		on = FALSE;
		return SUCCESS;
	}
	
#ifdef DEBUG_CHIPCON_RXTX
	void print(message_t* msg, uint8_t len, char* s) {
		uint8_t* data = (uint8_t*) call ChipconPacket.getHeader(msg);
		uint8_t i;
		
		platform_printf("SR: %s:", s);
		for (i = 0; i < len + sizeof(chipcon_header_t); i++) {
			platform_printf(" %02X", data[i]);
		}
		
		platform_printf("\n");
	}
#endif
	
	/**
	 * @see SendP.send()
	 * @return EOFF if the radio is off.
	 */
	command error_t Send.send(message_t* msg, uint8_t len) {
#ifdef DEBUG_CHIPCON_RXTX
		print(msg, len, "TX");
#endif
		
		// we can't detect all buffer swap errors, but someone using
		// the current receive buffer for sending is definitely a problem
		assert(msg != rxBuffer, ASSERT_CC_RXTX_BAD_TX_POINTER);
		
		if (!on) return EOFF;
		return call SubSend.send(msg, len);
	}
	
	/**
	 * Packet sent, radio is now in RX mode, so just deliver packet up the stack.
	 */
	event void SubSend.sendDone(message_t* msg, error_t error) {
		signal Send.sendDone(msg, error);
	}
	
	/**
	 * Packet received, radio is now in RX mode. Just pass the pointer up and back down the stack.
	 */
	event message_t* SubReceive.receive(message_t* msg, void* payload, uint8_t len) {
#ifdef DEBUG_CHIPCON_RXTX
		print(msg, len, "RX");
#endif
		
		rxBuffer = signal Receive.receive(msg, payload, len);
		return rxBuffer;
	}
	
	/**
	 * Wire through.
	 */
	command error_t Send.cancel(message_t* msg) {
		return call SubSend.cancel(msg);
	}
	
	/**
	 * Wire through.
	 */	
	command uint8_t Send.maxPayloadLength() {
		return call SubSend.maxPayloadLength();
	}
	
	/**
	 * Wire through.
	 */		
	command void* Send.getPayload(message_t* msg, uint8_t len) {
		return call SubSend.getPayload(msg, len);
	}

}
