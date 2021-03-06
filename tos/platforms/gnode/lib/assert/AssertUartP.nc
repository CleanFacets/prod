module AssertUartP {
	uses {
		interface AsyncStdControl as UartControl;
		interface UartByte;
		interface UartStream;
		interface BusyWait<TMicro, uint16_t>;
		interface PrintfFlush;
		interface Leds;
		interface Reboot;
	}
}
implementation {

	#define COUNTDOWN_FROM 10
	
	extern int sprintf (char * str, const char * format, ...) @C();
	
	void print(const char* s) {
		uint16_t i;
		for (i = 0; i < strlen(s); i++) {
			call UartByte.send(s[i]);
		}
	}
	
	void assertOutput(uint16_t errorCode, const char* strCondition, const char* description, const char* location) {
		atomic {
			uint8_t countdown = COUNTDOWN_FROM;
			
			char nodeID[8];
			sprintf(nodeID, "%u", TOS_NODE_ID);
			
			call Leds.led0On();
			call UartControl.start();
			call PrintfFlush.flush();
			
			while (1) {
				uint16_t i;
				print("Assert failed on node ");
				print(nodeID);
				print("! ");
				print(location);
				print(": ");
				print(description);
				print(": ");
				print(strCondition);
				print("\r\n");
				for (i = 0; i < 1000; i++) {
#ifdef _H_msp430hardware_h
					// reset the MSP430 watchdog since StackGuard can't
					atomic WDTCTL = WDT_ARST_1000;
#endif
					call Leds.led0Toggle();
					call BusyWait.wait(3000);
				}
				
				countdown--;
				if (countdown == 0) {
#ifdef ASSERT_UART_NO_REBOOT
					#warning AssertUart will not reboot!
#else
					print("Rebooting\n\n");
					call BusyWait.wait(10000);	// allow last character to leave the UART
					call Reboot.reboot();
#endif
				}
			}
		}
	}
	
	/**
	 * Assert a condition is true.
	 */
	void doAssert(bool condition, uint16_t errorCode, const char* strCondition, const char* description, const char* location) @C() {
		if (!condition) assertOutput(errorCode, strCondition, description, location);
	}
	
	/**
	 * Assert a condition is false.
	 */
	void doAssertNot(bool condition, uint16_t errorCode, const char* strCondition, const char* description, const char* location) @C() {
		doAssert(!condition, errorCode, strCondition, description, location);
	}
	
	/**
	 * Assert an error code is SUCCESS.
	 */
	void doAssertSuccess(error_t error, uint16_t errorCode, const char* strCondition, const char* description, const char* location) @C() {
		if (error != SUCCESS) {
			char buffer[80];
			char* errors[] = {
					"SUCCESS",
					"FAIL",
					"ESIZE",
					"ECANCEL",
					"EOFF",
					"EBUSY",
					"EINVAL",
					"ERETRY",
					"ERESERVE",
					"EALREADY",
			};
			
			sprintf(buffer, "%s (%s) != SUCCESS", strCondition, errors[error]);
			assertOutput(errorCode, buffer, description, location);
		}
	}
	
	/**
	 * Assert that a equals b.
	 */
	void doAssertEquals(uint32_t a, uint32_t b, uint16_t errorCode, const char* strA, const char* strB, const char* description, const char* location) @C() {
		if (a != b) {
			char buffer[80];
			sprintf(buffer, "%s (%lu) != %s (%lu)", strA, a, strB, b);
			assertOutput(errorCode, buffer, description, location);
		}
	}
	
	async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t error) {}
	async event void UartStream.receivedByte(uint8_t byte) {}
	async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t error) {}
	
	default async command void PrintfFlush.flush() {
		print("\n+++\nflush not connected\n+++\n");
	}
}
