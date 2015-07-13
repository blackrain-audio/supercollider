
Server.default = Server.local;
Server.default.boot;

thisProcess.recvOSCfunc = { arg ...args; args[2].postln; };
thisProcess.recvOSCfunc = { arg ...args; if (args[2][0] != '/status.reply') { args[2].postln; }; };
thisProcess.recvOSCfunc = nil;

// -----------------------------------------------------------------------------------------------
// trigger tests

(
	var maxblk = 2.pow(32);

	SynthDef("listener", { arg bus=7, id=2121;
		var blk, offset;
		blk		= Phasor.kr(0, 1, 0, maxblk);
		offset	= Phasor.ar(0, 1, 0, Server.default.options.blockSize);
		SendReply.ar(In.ar(bus) > 0.1, '/position', [ blk, offset ], id);
	}, ['ir', 'ir']).add;

	SynthDef("one_impulse", { arg bus=0, amp=1.0;
		var u = Impulse.ar(0);
		FreeSelf.kr(u);
		OffsetOut.ar(bus, u * amp);
	}, [\ir, \ir] ).add;

	SynthDef("ping", { arg bus=0, freq=1.0;
		OffsetOut.ar(bus, Impulse.ar(freq));
	}, [\ir, \ir] ).add;
)

(
	var prevpos = 0;
	r.free;
	p = false;

	r = OSCFunc({ arg msg, ett, addr, recvPort;
		var time, delta, pos;
		pos = msg[3] * s.options.blockSize + msg[4];
		delta = pos - prevpos;
		time = pos / 44100;
		if (delta != 44100  or:{ p }) {
			[msg, pos, delta, time, time / 60].postln;
		};
		prevpos = pos;
	}, '/position').permanent_(true);
)

s.sendMsg(\s_new, "listener", s.nextNodeID, 0, 1, \bus, 100);

s.sendMsg(\s_new, "one_impulse", s.nextNodeID, 0, 1, \bus, 100);

s.sendMsg(\s_new, "ping", n = s.nextNodeID, 0, 1, \bus, 100);

p = true;

p = false;


s.sendMsg(\n_free, n);

r.remove;

/*
[ [ /ping, 1000, 2121, 852921, 18 ], 54586962, 44101, 1237.7995918367, 20.629993197278 ]
[ [ /ping, 1000, 2121, 1704602, 35 ], 109094563, 44101, 2473.7996145125, 41.229993575208 ]
[ [ /ping, 1000, 2121, 2556283, 52 ], 163602164, 44101, 3709.7996371882, 61.829993953137 ]
[ [ /ping, 1000, 2121, 3407276, 1 ], 218065665, 44101, 4944.7996598639, 82.413327664398 ]
[ [ /ping, 1000, 2121, 4258957, 18 ], 272573266, 44101, 6180.7996825397, 103.01332804233 ]
[ [ /ping, 1000, 2121, 5110638, 35 ], 327080867, 44101, 7416.7997052154, 123.61332842026]
[ [ /ping, 1000, 2121, 5962319, 52 ], 381588468, 44101, 8652.7997278912, 144.21332879819 ]
[ [ /ping, 1000, 2121, 6813312, 1 ], 436051969, 44101, 9887.7997505669, 164.79666250945 ]
[ [ /ping, 1000, 2121, 7664993, 18 ], 490559570, 44101, 11123.799773243, 185.39666288738 ]
*/

// -----------------------------------------------------------------------------------------------
// sample sched ugens version

(
	SynthDef("listener", { arg bus=7, id=2121;
		SendReply.ar(In.ar(bus) > 0.1, '/position', [ BlockCount.kr, BlockOffset.ar ], id);
	}, ['ir', 'ir']).add;

	SynthDef("ping", { arg bus=0, freq=1.0, amp=1.0;
		OffsetOut.ar(bus, Impulse.ar(freq) * amp);
	}, [\ir, \ir, \ir] ).add;
)

(
	var prevpos = 0;
	r.free;
	p = false;

	r = OSCFunc({ arg msg, ett, addr, recvPort;
		var delta, pos = msg[3] * s.options.blockSize + msg[4];
		delta = pos - prevpos;
		if (delta != 44100 or: { p }) {
			[msg, pos, delta].postln;
		};
		prevpos = pos;
	}, '/position').permanent_(true);
)

s.sendMsg(\s_new, "listener", s.nextNodeID, 0, 1, \bus, 100);

s.sendMsg(\s_new, "ping", n = s.nextNodeID, 0, 1, \bus, 100);

p = true;

p = false;

s.sendMsg(\n_free, n);

r.free;
