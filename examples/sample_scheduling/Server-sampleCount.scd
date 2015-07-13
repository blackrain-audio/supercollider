
// sampleCount(delta, doneAction);
// completion func arguments:
//	server - server instance from which the async command has completed
//	position	- server's sample count.
//	ett - the System's elapsed time of trigger.

s.quit;
s.boot;

(
	s.sampleCount(0.05, { arg server, position, ett;
		[ server, position, ett ].postln;
	});
)

s.queryAllNodes;
