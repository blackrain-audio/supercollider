//------------------------------------------------------------------------------------------------
// Sample position based scheduling examples

// ------------------------------------------------------------------------------------------------
// Sample position based scheduling Information UGens:
//     SpawnBlock.ir  - processing block count at wich this synth node was spawned, instrument rate.
//     SpawnOffset.ir - sample offset within the block at wich this synth node was spawned.
//     BlockCount.kr  - processing block count at the time of poll.
//     BlockOffset.ar - offset within a processing block at the time of poll.

// ------------------------------------------------------------------------------------------------
// The use of OffsetOut.ar in SynthDefs thru this document is because OffsetOut.ar spawns synth
// nodes at precise sample positions while Out.ar aligns spawn positions to process block starts.
//
// SpawnOffset.ir is always zero for:
//    1. Nodes whose SynthDef uses Out.ar (or its control rate method - kr).
//    2. Nodes spawned via OSC message. OSC messages don't provide a time of execution tag. Thus,
//    OSC Messages are always scheduled at offset zero of the next (soonest) processing block.
//    3. Nodes spawned via OSC bundle with an "ASAP" time tag (an osc time tag value of 1),
//    nil in sclang.
//

// ------------------------------------------------------------------------------------------------
// SynthDefs

s.boot;

(
	SynthDef("sine", { arg out=0, freq=80.0, phase=0.0, amp=0.1;
		OffsetOut.ar(out, SinOsc.ar(freq, phase, amp));
	}).add;

	SynthDef("sine+trigger", { arg out=0, freq=80.0, phase=0.0, amp=0.1;
		SendReply.ar(Impulse.ar(0), '/reply', [ SpawnBlock.ir, SpawnOffset.ir ], 1010);
		OffsetOut.ar(out, SinOsc.ar(freq, phase, amp));
	}).add;

	SynthDef("PositionReport", { arg id=1010;
		var u;
		u = Impulse.ar(0);
		FreeSelf.kr(u);
		SendReply.ar(u, '/reply', [ SpawnBlock.ir, SpawnOffset.ir ], 1010);
	},[\ir]).add;
)

// ------------------------------------------------------------------------------------------------
// nodes spawn sample position
//

(
	// listener
	// reply is [ cmd, nodeID, triggerID, block, offset]
	OSCdef('position_listener', { arg msg, time, addr, recvPort;
		var block, offset, position;
		block = msg[3];
		offset = msg[4];
		position = block * s.options.blockSize + offset;
		postf("reply: %\nblock: % offset: % position: %\n", msg, block, offset, position);
    }, '/reply').permanent_(true);
)

s.sendBundle(0.1, [ "/s_new", "PositionReport", 2000, 1, 1 ]);
s.sendBundle(0.1, [ "/s_new", "PositionReport", 2000, 1, 1 ]);

// OSC messages or bundles with nil time stamps align spawn positions to the next IOProc block start
// (block offset == 0)
s.sendMsg("/s_new", "PositionReport", 2000, 1, 1);
s.sendMsg("/s_new", "PositionReport", 2000, 1, 1);
s.sendBundle(nil, [ "/s_new", "PositionReport", 2000, 1, 1 ]);
s.sendBundle(nil, [ "/s_new", "PositionReport", 2000, 1, 1 ]);

// ------------------------------------------------------------------------------------------------
// Server sample position count
//    Server:sampleCount(delta, actionFunc);
//	  actionFunc { arg server, position, elapsedTime; };

(
    s.sampleCount(0.1, { arg server, pos, ett;
	    postf("server: % -> position: % elapsedTime: %\n", server, pos, ett);
    });
)

(
    s.sampleCount(0.1, { arg server, position, ett;
	    var delta;
	    delta = server.sampleRate * 1; // one second ahead from last poll position
	    postf("server: % -> position: % elapsedTime: %\n", server, position, ett);
	    server.sendPosBundle(position + delta, ["/s_new", "sine+trigger", 2000, 1, 1, \freq, 440]);
    });
)

// stop via Cmd-period

// ------------------------------------------------------------------------------------------------
// Schedule sample positioned OSC bundles
// Server:sendPosBundle(samplePosition, bundle)

(
	s.sampleCount(0.1, { arg server, position, ett;
		var position1, position2, delta;

		delta = server.sampleRate * 1; // one sec ahead from last poll

		position1 = position + delta;
		position2 = position + delta + 1; // one sample later

		postf("schedule for sample position % and %\nactual positions from synth replies:\n",
			position1, position2);

		server.sendPosBundle(position1, [ "/s_new", "PositionReport", s.nextNodeID, 1, 1 ]);
		server.sendPosBundle(position2, [ "/s_new", "PositionReport", s.nextNodeID, 1, 1 ]);
	});
)

(
	s.sampleCount(0.1, { arg serv, pos, time;
		var delta;
		delta = serv.sampleRate; // one sec ahead from last poll position
		n = s.nextNodeID;
		serv.sendPosBundle((pos + delta).postln, [ "/s_new", "sine+trigger", n, 1, 1 ]);

		[serv, pos, time].postln;
	});
)

s.sendMsg("/n_free", n);

// ------------------------------------------------------------------------------------------------
// hybrid scheduling - TempoClock wait times, target sample positions

(
	l=0;
    OSCdef('position_listener', { arg msg, time, addr, recvPort;
		var block, offset, pos;
		block = msg[3];
		offset = msg[4];
		pos = block * s.options.blockSize + offset;
		[ msg, pos, pos - l].postln;
		l = pos;
    }, '/reply').permanent_(true);
)

(
	s.sampleCount(0.05, { arg server, position, time;
		Routine {
			var delta, deltaSamples, node = server.nextNodeID;
			delta = 1.0;
			deltaSamples = server.sampleRate * delta;
			position = position + deltaSamples; // schedule initial bundle 'delta' secs ahead

			loop {
				server.sendPosBundle(position, [ "/s_new", "PositionReport", node, 1, 1 ]);

				// next bundle, one sec appart.
				position = position + deltaSamples;
				delta.wait;
			}
		}.play;
	});
)

// stop via Cmd-period

OSCdef('position_listener').free;

// ------------------------------------------------------------------------------------------------
// UGen phase cancellation
(
	s.sampleCount(0.1, { arg serv, pos, time;

		s.sendPosBundle(pos + serv.sampleRate, // one sec ahead
			[ "/s_new", "sine", 2000, 1, 1, 'freq', 440, 'amp', 0.25 ]);

		s.sendPosBundle(pos + (serv.sampleRate * 4), // 4 secs ahead
			[ "/s_new", "sine", 2001, 1, 1, 'freq', 440, 'amp', 0.25, 'phase', pi ]);

	});
)

s.sendMsg("/n_free", 2001);

s.sendMsg("/n_free", 2000);

// ------------------------------------------------------------------------------------------------
// buffer playback phase cancellation

(
	SynthDef("SampleTrig1x2", { arg out=0, buffer, rate=1.0, startPos=0, amp=1.0, cycle=0;
		var audio = PlayBuf.ar(1,
					buffer,
					BufRateScale.kr(buffer) * rate,
					startPos: startPos,
					loop:cycle);
		FreeSelfWhenDone.kr(audio);
		OffsetOut.ar(out, (audio * amp).dup);
	},['kr', 'ir', 'kr', 'kr', 'kr', 'ir']).add;
)

b = Buffer.read(s, Document.current.path.dirname +/+ "ncfdh_loop_107m.aiff".standardizePath);
b

(
	s.sampleCount(0.1, { arg serv, pos, time;
		var position = pos + serv.sampleRate;

		s.sendPosBundle(position, [ "/s_new", "SampleTrig1x2", s.nextNodeID, 0, 1, 'buffer',
			b.bufnum, 'amp', 1.0, 'cycle', 1 ]);

		// start 2nd sample one cycle late - inverse phase
		s.sendPosBundle(position + b.numFrames, [ "/s_new", "SampleTrig1x2", s.nextNodeID, 0, 1,
			'buffer', b.bufnum, 'amp', -1.0, 'cycle', 0 ]);
	});
)

b.free;

// blackrain
