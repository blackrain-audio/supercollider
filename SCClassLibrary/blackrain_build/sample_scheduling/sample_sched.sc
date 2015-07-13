
// blackrain - sample poition based osc bundle scheduling
// 2008

+NetAddr {
	sendPosBundle { arg position ... args; // a 64 bit (double) position value
		_NetAddr_SendPosBundle
		^this.primitiveFailed;
	}
}

+Server {
	sendPosBundle { arg position ... msgs;
		addr.sendPosBundle(position, *msgs)
	}

	listSendPosBundle { arg position, msgs;
		addr.sendPosBundle(position, *msgs)
	}

	sampleCount { arg delta=0.1, actionFunc;
		var oscFunc, c, ett, node;

		oscFunc = OSCFunc.new({ arg msg, time, addr, recvPort;
			var position, block, offset;
			if (msg[1] == node) {
				block = msg[3];
				offset = msg[4];
				position = block * this.options.blockSize +  offset;
				actionFunc.value(this, position, ett);
			}
		}, '/count_ping').oneShot;

		c = Condition.new;
		Routine.run {
			SynthDef("sample-count-ping", {
				var z = Impulse.ar(0);
				FreeSelf.kr(z);
				SendReply.ar(z, '/count_ping', [ BlockCount.kr, BlockOffset.ar ], 41020);
			}).send(this);
			this.sync(c);
			node = this.nextNodeID;
			ett = Main.elapsedTime + delta;
			this.sendBundle(delta, [ "/s_new", "sample-count-ping", node, 1, 1 ]);
		};

		// remove responder - just in case I fail to receive a trigger
		SystemClock.sched(delta + 0.5, { oscFunc.free; nil });
	}
}
